# A temporary record root: calls/README.md with the budget rows, and a call
# log with `used` fair JEV rows (plus rows that must not count).
make_record <- function(max_calls = 100, used = 0, max_cost = 1, rerun_calls = NA,
                        env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(root, "calls"))
  rows <- c(
    "| Date | Service | Purpose | Max calls | Max cost (USD) | Approved by |",
    "|---|---|---|---|---|---|",
    "| 2026-10-20 | TypeSafe | All JEV calls of the study | 2446 | 5 | fmm |",
    paste0("| 2026-10-21 | TypeSafe | Fair comparison, JEV | ", max_calls, " | ", max_cost, " | fmm |")
  )
  if (!is.na(rerun_calls)) {
    rows <- c(rows, paste0("| 2026-10-22 | TypeSafe | Re-run of the fair comparison | ",
                           rerun_calls, " | 1 | fmm |"))
  }
  writeLines(rows, file.path(root, "calls", "README.md"))
  if (used > 0) {
    tibble::tibble(
      purpose = c(rep("fair test jev final k2 extrusion", used), "test other",
                  "fair test clef final k2 extrusion", "fair test clef final k2 extrusion"),
      model = c(rep("jev-1.13.0", used), "jev-1.13.0",
                "Cloudflare/clef-flash", "Cloudflare/clef-flash"),
      status = 200,
      cost_usd = c(rep(0.001, used), 0.5, NA, NA)
    ) |>
      readr::write_csv(file.path(root, "calls", "typesafe-calls.csv"))
  }
  root
}

# A loop audit file: "none" for a blind loop, otherwise one row per flag.
write_audit <- function(loop_dir, model = "jev", dataset = "extrusion", flagged = character()) {
  dir.create(loop_dir, recursive = TRUE, showWarnings = FALSE)
  audit <- if (length(flagged) == 0L) {
    tibble::tibble(time = NA_character_, tool = "none",
                   target = "No call outside the sandbox. The loop was blind.")
  } else {
    tibble::tibble(time = "t", tool = "Bash", target = flagged)
  }
  audit |>
    dplyr::mutate(transcript = "x.jsonl", transcript_md5 = "abc") |>
    readr::write_csv(file.path(loop_dir, paste0(model, "-", dataset, "_audit.csv")))
}

# Git Bash, for the tests of the loop launcher.
git_bash <- "C:/Program Files/Git/bin/bash.exe"
