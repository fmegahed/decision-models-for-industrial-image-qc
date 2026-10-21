# The launcher of one loop agent (scripts/fair_run_loop.sh). The tests never
# start claude: they use --dry-run, or a refusal that stops the script first.

skip_without_bash <- function() testthat::skip_if_not(file.exists(git_bash), "Git Bash not found")

# Folders of one launch: sandboxes, mirrors, frozen descriptions, config.
launch_dirs <- function(env = parent.frame()) {
  dirs <- purrr::map(c(root = "root", map = "map", desc = "desc", config = "config"),
                     \(x) normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/"))
  dirs
}

run_launcher <- function(args, dirs, vars = character()) {
  withr::local_dir(repo_root)
  base <- c(FAIR_SANDBOX = dirs$root, FAIR_MAP_DIR = dirs$map, FAIR_DESC_DIR = dirs$desc,
            CLAUDE_CONFIG_DIR = dirs$config, JEV_CHECK_ONLY = NA)
  out <- withr::with_envvar(utils::modifyList(as.list(base), as.list(vars)) |> unlist(),
    suppressWarnings(system2(git_bash, c("scripts/fair_run_loop.sh", args),
                             stdout = TRUE, stderr = TRUE)))
  list(text = paste(out, collapse = "\n"), lines = out,
       status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"))
}

uuid_pattern <- "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"

# The flags of decision D81 (brief item I1).
expected_command <- paste(
  "claude -p \"Read LOOP.md and follow it.\" --restricted --safe-mode --strict-mcp-config",
  "--tools Read,Write,Edit,Glob,Grep,Bash,TodoWrite",
  "--allowedTools Read Glob Grep TodoWrite Write Edit \"Bash(bash score.sh:*)\"",
  "\"Bash(./score.sh:*)\" \"Bash(ls:*)\" \"Bash(head:*)\" \"Bash(tail:*)\" \"Bash(cat:*)\"",
  "\"Bash(wc:*)\" \"Bash(sort:*)\" \"Bash(cut:*)\" \"Bash(grep:*)\"",
  "--disable-slash-commands --permission-prompts none --model claude-opus-5-5",
  "--session-id <new UUID>"
)

test_that("the launcher refuses a bad model, pans, a wrong number of arguments and a bad JEV_CHECK_ONLY", {
  skip_without_bash()
  dirs <- launch_dirs()
  dir.create(file.path(dirs$root, "jev-extrusion"))
  cases <- list(
    list(args = c("--dry-run", "gpt", "extrusion"), error = "MODEL must be jev or clef"),
    list(args = c("--dry-run", "jev", "pan_images"), error = "Pans have no loop"),
    list(args = c("--dry-run", "jev"), error = "Usage"),
    list(args = c("jev", "extrusion", "more"), error = "Usage")
  )
  for (case in cases) {
    res <- run_launcher(case$args, dirs)
    expect_false(res$status == 0, info = paste(case$args, collapse = " "))
    expect_match(res$text, case$error, fixed = TRUE)
  }
  res <- run_launcher(c("--dry-run", "jev", "extrusion"), dirs, c(JEV_CHECK_ONLY = "yes"))
  expect_false(res$status == 0)
  expect_match(res$text, "JEV_CHECK_ONLY must be true or false", fixed = TRUE)
})

test_that("the launcher refuses a missing sandbox, an earlier mirror and a frozen description", {
  skip_without_bash()
  dirs <- launch_dirs()
  # No sandbox. The same refusal holds without --dry-run: the script stops
  # before it starts claude.
  for (args in list(c("--dry-run", "jev", "extrusion"), c("jev", "extrusion"))) {
    res <- run_launcher(args, dirs)
    expect_false(res$status == 0)
    expect_match(res$text, "The sandbox does not exist", fixed = TRUE)
    expect_false(stringr::str_detect(res$text, "claude -p"))
  }
  dir.create(file.path(dirs$root, "jev-extrusion"))
  writeLines("x", file.path(dirs$map, "jev-extrusion_loop_log.csv"))
  res <- run_launcher(c("jev", "extrusion"), dirs)
  expect_false(res$status == 0)
  expect_match(res$text, "A loop log mirror from an earlier attempt exists", fixed = TRUE)
  unlink(file.path(dirs$map, "jev-extrusion_loop_log.csv"))
  writeLines(c("normal,defective", "a,b"), file.path(dirs$desc, "jev_extrusion.csv"))
  res <- run_launcher(c("jev", "extrusion"), dirs)
  expect_false(res$status == 0)
  expect_match(res$text, "The description is already frozen", fixed = TRUE)
})

test_that("the dry run prints the exact command, the session ID and the transcript path", {
  skip_without_bash()
  dirs <- launch_dirs()
  sandbox <- file.path(dirs$root, "clef-textiles")
  dir.create(sandbox)
  res <- run_launcher(c("--dry-run", "clef", "textiles"), dirs)
  expect_equal(res$status, 0L)
  expect_match(res$text, "Dry run: claude was not started.", fixed = TRUE)
  get <- \(label) stringr::str_remove(stringr::str_subset(res$lines, paste0("^", label, ": ")),
                                      paste0("^", label, ": "))
  expect_equal(stringr::str_to_lower(get("Sandbox")), stringr::str_to_lower(sandbox))
  id <- get("Session ID")
  expect_match(id, paste0("^", uuid_pattern, "$"))
  command <- stringr::str_subset(res$lines, "^claude -p ")
  expect_length(command, 1)
  expect_equal(stringr::str_replace(command, stringr::fixed(id), "<new UUID>"), expected_command)
  expect_true(any(res$lines == paste0("cd \"", get("Sandbox"), "\"")))
  slug <- stringr::str_replace_all(get("Sandbox"), "[^A-Za-z0-9]", "-")
  expect_equal(stringr::str_to_lower(get("Transcript")),
               stringr::str_to_lower(paste0(dirs$config, "/projects/", slug, "/", id, ".jsonl")))
  # Each launch has a new session ID.
  expect_false(identical(get("Session ID"),
                         stringr::str_remove(stringr::str_subset(
                           run_launcher(c("--dry-run", "clef", "textiles"), dirs)$lines,
                           "^Session ID: "), "^Session ID: ")))
})

test_that("without CLAUDE_CONFIG_DIR the transcript is under the home .claude folder", {
  skip_without_bash()
  dirs <- launch_dirs()
  dir.create(file.path(dirs$root, "jev-pipe_staple"))
  res <- run_launcher(c("--dry-run", "jev", "pipe_staple"), dirs, c(CLAUDE_CONFIG_DIR = NA))
  expect_equal(res$status, 0L)
  home <- normalizePath(Sys.getenv("USERPROFILE"), winslash = "/")
  expect_match(stringr::str_to_lower(res$text),
               stringr::str_to_lower(paste0("Transcript: ", home, "/.claude/projects/")),
               fixed = TRUE)
})

test_that("a rehearsal passes JEV_CHECK_ONLY=true to the agent", {
  skip_without_bash()
  dirs <- launch_dirs()
  dir.create(file.path(dirs$root, "jev-microstructure"))
  res <- run_launcher(c("--dry-run", "jev", "microstructure"), dirs, c(JEV_CHECK_ONLY = " TRUE "))
  expect_equal(res$status, 0L)
  expect_match(res$text, "Rehearsal: JEV_CHECK_ONLY=true", fixed = TRUE)
  plain <- run_launcher(c("--dry-run", "jev", "microstructure"), dirs)
  expect_false(stringr::str_detect(plain$text, "Rehearsal"))
})

test_that("LOOP.md and the analysis document give the same command as the launcher", {
  template <- readLines(file.path(repo_root, "scripts", "fair_loop_instructions.md"))
  qmd <- readLines(file.path(repo_root, "beyond_clip_analysis.qmd"))
  expect_true(any(template == expected_command))
  expect_true(any(qmd == expected_command))
  # The command is in a comment at the top of LOOP.md, for the reader.
  expect_equal(template[[1]], "<!--")
  expect_lt(which(template == expected_command)[[1]], which(template == "-->")[[1]])
})

test_that("the analysis document says one fresh agent for each model and dataset", {
  qmd <- paste(readLines(file.path(repo_root, "beyond_clip_analysis.qmd")), collapse = "\n")
  expect_match(qmd, "one fresh agent for each model and dataset", fixed = TRUE)
  expect_false(stringr::str_detect(qmd, "one agent for each model\\."))
  expect_false(stringr::str_detect(qmd, "one agent per model"))
})
