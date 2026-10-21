#!/usr/bin/env bash
# Start ONE blind description loop: a fresh, isolated Claude Code agent in
# the sandbox of one model and one dataset (decision D81: 8 loops, 8 agents).
#
# From the repository root, in Git Bash:
#   bash scripts/fair_run_loop.sh MODEL DATASET            # starts the agent
#   bash scripts/fair_run_loop.sh --dry-run MODEL DATASET  # prints the command only
#
# MODEL: jev or clef. DATASET: extrusion, microstructure, pipe_staple or textiles.
# FAIR_SANDBOX: folder of the sandboxes (default ../fair-loop-sandbox).
# FAIR_MAP_DIR: folder of the loop log mirrors (default results/fair/loop).
# FAIR_DESC_DIR: folder of the frozen descriptions (default results/fair/descriptions).
# JEV_CHECK_ONLY=true: a rehearsal. The agent gets the variable, so score.sh
#   runs the checks only and makes no paid call.
#
# The script refuses to start when the sandbox does not exist, when a mirror
# of the loop log from an earlier attempt exists, or when the description is
# already frozen. The agent runs with the sandbox as its working folder:
#   --restricted: no user, project or local settings; the file tools stay in
#     the working folder; no code-running tool unless --tools names it.
#   --safe-mode: no CLAUDE.md, skills, plugins, hooks, MCP servers or agents.
#   --strict-mcp-config (with no --mcp-config): no MCP server.
#   --tools: only Read, Write, Edit, Glob, Grep, Bash and TodoWrite.
#   --allowedTools: the file tools, and Bash only for the scoring command and
#     simple read commands. --permission-prompts none denies any other call.
#   --disable-slash-commands, the pinned model, and a new session ID, so the
#     path of the transcript is known. The script prints that path at the end
#     (for scripts/fair_close_loop.R).
set -euo pipefail

usage="Usage: bash scripts/fair_run_loop.sh [--dry-run] MODEL DATASET"
refuse() { echo "Refused: $*" >&2; exit 1; }

dry_run=false
if [ "${1:-}" = "--dry-run" ]; then dry_run=true; shift; fi
if [ "$#" -ne 2 ]; then echo "$usage" >&2; exit 2; fi
model=$1
dataset=$2
case "$model" in jev|clef) ;; *) refuse "MODEL must be jev or clef. $usage" ;; esac
case "$dataset" in
  extrusion|microstructure|pipe_staple|textiles) ;;
  pan_images) refuse "Pans have no loop." ;;
  *) refuse "DATASET must be extrusion, microstructure, pipe_staple or textiles." ;;
esac

# JEV_CHECK_ONLY: "true" (any case, spaces trimmed), "false" or empty.
check_only=$(printf '%s' "${JEV_CHECK_ONLY:-}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
case "$check_only" in ""|false|true) ;; *) refuse "JEV_CHECK_ONLY must be true or false." ;; esac

# Windows form of a path (C:/...), which Claude Code and R use.
win_path() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
unix_path() { if command -v cygpath > /dev/null; then cygpath -u "$1"; else printf '%s' "$1"; fi; }

repo=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo"
sandbox_dir="$(unix_path "${FAIR_SANDBOX:-../fair-loop-sandbox}")/$model-$dataset"
mirror="$(unix_path "${FAIR_MAP_DIR:-results/fair/loop}")/$model-${dataset}_loop_log.csv"
frozen="$(unix_path "${FAIR_DESC_DIR:-results/fair/descriptions}")/${model}_${dataset}.csv"
[ -d "$sandbox_dir" ] || refuse "The sandbox does not exist: $sandbox_dir. Run scripts/fair_make_sandbox.R first."
[ ! -e "$mirror" ] || refuse "A loop log mirror from an earlier attempt exists: $mirror"
[ ! -e "$frozen" ] || refuse "The description is already frozen: $frozen"

sandbox=$(win_path "$(cd "$sandbox_dir" && pwd)")
# A version 4 UUID from 16 random bytes.
hex=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
variant=$(printf '%x' $(( (0x${hex:16:2} & 0x3f) | 0x80 )))
session_id="${hex:0:8}-${hex:8:4}-4${hex:13:3}-${variant}${hex:18:2}-${hex:20:12}"
# Claude Code names the project folder of a working folder by its path, with
# each character that is not a letter or a digit replaced by "-".
slug=$(printf '%s' "$sandbox" | sed 's/[^A-Za-z0-9]/-/g')
config_dir=$(win_path "${CLAUDE_CONFIG_DIR:-${USERPROFILE:-$HOME}/.claude}")
transcript="$config_dir/projects/$slug/$session_id.jsonl"

cmd=(claude -p "Read LOOP.md and follow it."
  --restricted --safe-mode --strict-mcp-config
  --tools "Read,Write,Edit,Glob,Grep,Bash,TodoWrite"
  --allowedTools Read Glob Grep TodoWrite Write Edit
  "Bash(bash score.sh:*)" "Bash(./score.sh:*)" "Bash(ls:*)" "Bash(head:*)" "Bash(tail:*)"
  "Bash(cat:*)" "Bash(wc:*)" "Bash(sort:*)" "Bash(cut:*)" "Bash(grep:*)"
  --disable-slash-commands --permission-prompts none
  --model claude-opus-5-5
  --session-id "$session_id")

# Print an argument as a shell word: in double quotes when it needs them.
quote() {
  case "$1" in
    *[!A-Za-z0-9_./:=,@%+-]*) printf '"%s"' "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}
line=""
for arg in "${cmd[@]}"; do line="$line${line:+ }$(quote "$arg")"; done

echo "Model: $model | Dataset: $dataset"
echo "Sandbox: $sandbox"
echo "Session ID: $session_id"
if [ "$check_only" = "true" ]; then
  echo "Rehearsal: JEV_CHECK_ONLY=true goes to the agent. score.sh runs the checks only (no paid call)."
fi
echo "Command:"
echo "cd \"$sandbox\""
echo "$line"

if [ "$dry_run" = "true" ]; then
  echo "Transcript: $transcript"
  echo "Dry run: claude was not started."
  exit 0
fi

command -v claude > /dev/null || refuse "claude is not on the PATH."
echo "Claude Code version: $(claude --version)"
# Variables that must not reach score.sh from this shell: the call log and
# the purpose are set by scripts/fair_score.R.
unset JEV_CALL_LOG JEV_CALL_PURPOSE FAIR_PURPOSE_PREFIX
if [ -n "$check_only" ]; then export JEV_CHECK_ONLY="$check_only"; fi
status=0
(cd "$sandbox_dir" && "${cmd[@]}") || status=$?
echo "Exit status of claude: $status"
echo "Transcript: $transcript"
echo "Close the loop with: Rscript scripts/fair_close_loop.R $model $dataset \"$transcript\""
exit "$status"
