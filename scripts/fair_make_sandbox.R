# Make the sandbox for one blind description loop.
#
# Rscript scripts/fair_make_sandbox.R jev extrusion
#
# FAIR_SANDBOX: folder that holds the sandboxes (default ../fair-loop-sandbox).
# The folder must be outside the repository. FAIR_RECORD_ROOT is baked into
# score.sh. A JEV loop makes paid calls, so it needs FAIR_RECORD_ROOT (no
# fallback), with the "Fair comparison" budget row in its calls/README.md. A
# Clef-Flash loop falls back to replication_materials.

source("R/fair_runner.R")
source("R/fair_loop.R")

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
sandbox_root <- Sys.getenv("FAIR_SANDBOX", unset = "../fair-loop-sandbox")
sandbox <- make_sandbox(args[[1]], args[[2]], sandbox_root, repo = ".",
                        record_root = Sys.getenv("FAIR_RECORD_ROOT"))
cat("Sandbox made:", sandbox, "\n")
cat("Files:", length(list.files(sandbox, recursive = TRUE)), "\n")
cat("Start the loop agent with: bash scripts/fair_run_loop.sh", args[[1]], args[[2]], "\n")
