source(file.path(repo_root, "R", "fair_runner.R"))
source(file.path(repo_root, "R", "fair_loop.R"))

rscript <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"

tool_line <- function(time, name, input, cwd = NULL, type = "tool_use") {
  entry <- list(type = "assistant", timestamp = time,
                message = list(role = "assistant",
                               content = list(list(type = type, id = "x", name = name,
                                                   input = input))))
  if (!is.null(cwd)) entry$cwd <- cwd
  as.character(jsonlite::toJSON(entry, auto_unbox = TRUE))
}

bash_line <- function(time, command, name = "Bash") {
  tool_line(time, name, list(command = command))
}


# One real sandbox for jev / extrusion, in temporary folders only.
make_test_sandbox <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  map_dir <- withr::local_tempdir(.local_envir = env)
  record <- make_record(env = env)
  sandbox <- make_sandbox("jev", "extrusion", root, repo = repo_root,
                          map_dir = map_dir, record_root = record)
  list(sandbox = sandbox, map_dir = map_dir, record = record)
}

test_that("the keep rule keeps candidates 1, 3 and 5", {
  log <- tibble::tibble(candidate = 1:5, auc = c(0.80, 0.81, 0.83, 0.82, 0.86))
  out <- apply_keep_rule(log)
  expect_equal(out$kept, c(TRUE, FALSE, TRUE, FALSE, TRUE))
  expect_equal(out$best, 5L)
})

test_that("the keep rule needs a gain of at least 0.02 and is exact at the edge", {
  out <- apply_keep_rule(tibble::tibble(candidate = 1:3, auc = c(0.80, 0.82, 0.839)))
  expect_equal(out$kept, c(TRUE, TRUE, FALSE))
  expect_equal(out$best, 2L)
  one <- apply_keep_rule(tibble::tibble(candidate = 1L, auc = 0.7))
  expect_equal(one$best, 1L)
})

test_that("the sandbox maker refuses a folder inside the repository", {
  expect_error(make_sandbox("jev", "extrusion", file.path(repo_root, "tmp-sandbox"),
                            repo = repo_root), "inside the repository")
})

test_that("the sandbox holds only the allowed files and no hidden paths", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  s <- make_test_sandbox()$sandbox
  files <- list.files(s, recursive = TRUE, include.dirs = FALSE)
  allowed <- c("labels.csv", "generic_description.csv", "LOOP.md", "score.sh",
               "loop_log.csv", "candidates/1.csv")
  other <- setdiff(files, allowed)
  expect_true(all(stringr::str_detect(
    other, "^(images/img_\\d{3}|references/(normal|defective)_[12])\\.[A-Za-z]+$")))
  expect_equal(sum(stringr::str_starts(files, "images/")), 96)
  expect_equal(sum(stringr::str_starts(files, "references/")), 4)
  expect_equal(sort(list.files(s, include.dirs = TRUE)),
               sort(c("images", "references", "candidates", "scores", "labels.csv",
                      "generic_description.csv", "LOOP.md", "score.sh", "loop_log.csv")))
  test_paths <- readr::read_csv(file.path(repo_root, "results", "image_split_manifest.csv"),
                                show_col_types = FALSE) |>
    dplyr::filter(split == "test") |>
    dplyr::pull(image_path)
  design <- readr::read_csv(file.path(repo_root, "results", "fair", "sets", "design.csv"),
                            show_col_types = FALSE)
  text_files <- file.path(s, c("labels.csv", "generic_description.csv", "LOOP.md",
                               "loop_log.csv", "candidates/1.csv"))
  text <- purrr::map(text_files, readLines, warn = FALSE) |> unlist() |> paste(collapse = "\n")
  # score.sh holds the repository root and the sandbox path. Drop those two.
  sh <- readLines(file.path(s, "score.sh"), warn = FALSE) |> paste(collapse = "\n")
  sh <- stringr::str_remove_all(sh, stringr::fixed(normalizePath(repo_root, winslash = "/")))
  sh <- stringr::str_remove_all(sh, stringr::fixed(normalizePath(s, winslash = "/")))
  everything <- c(text, sh, basename(files), dirname(files))
  for (bad in c("test", "results/", "calibration")) {
    expect_false(any(stringr::str_detect(stringr::str_to_lower(everything), bad)),
                 info = bad)
  }
  for (p in c(test_paths, design$image_path)) {
    expect_false(any(stringr::str_detect(everything, stringr::fixed(p))), info = p)
  }
  expect_false(stringr::str_detect(text, stringr::fixed("{{")))
})

test_that("the labels match design.csv and the map points to the originals", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  made <- make_test_sandbox()
  labels <- readr::read_csv(file.path(made$sandbox, "labels.csv"), show_col_types = FALSE)
  map <- readr::read_csv(file.path(made$map_dir, "jev-extrusion_image_map.csv"),
                         show_col_types = FALSE)
  design <- readr::read_csv(file.path(repo_root, "results", "fair", "sets", "design.csv"),
                            show_col_types = FALSE) |>
    dplyr::filter(dataset == "extrusion")
  expect_named(labels, c("image", "class", "defect_type"))
  joined <- dplyr::inner_join(labels, map, by = "image") |>
    dplyr::inner_join(design, by = "image_path")
  expect_equal(nrow(joined), 96)
  expect_equal(joined$class, joined$actual_class)
  expect_equal(joined$defect_type.x, joined$defect_type.y)
  expect_true(all(labels$class %in% c("nominal", "defective")))
  loop <- readLines(file.path(made$sandbox, "LOOP.md"))
  expect_true(any(stringr::str_detect(loop, "over")))
  expect_true(any(stringr::str_detect(loop, "score.sh")))
})

test_that("a candidate with a comma, quotes, a pipe and a line break survives", {
  path <- withr::local_tempfile(fileext = ".csv")
  x <- list(normal = "Clean, \"smooth\" | part\nno marks", defective = "Cut, \"gap\" | x\ny",
            reason = "Because, \"so\" | yes\nand more")
  write_candidate(path, x$normal, x$defective, x$reason)
  back <- read_candidate(path)
  expect_equal(back$normal, x$normal)
  expect_equal(back$defective, x$defective)
  expect_equal(back$reason, x$reason)
})

test_that("candidate numbers: next number only, at most 6, no repeat", {
  s <- withr::local_tempdir()
  m <- file.path(withr::local_tempdir(), "mirror.csv")
  dir.create(file.path(s, "scores"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  expect_silent(check_candidate_slot(s, 1, m))
  expect_error(check_candidate_slot(s, 2, m), "next candidate")
  log <- tibble::tibble(candidate = 1:6, time_utc = "t", normal = "n", defective = "d",
                        auc = 0.5, mean_score_by_type = "a=1", reason = "r", kept = TRUE)
  write_loop_log(log, file.path(s, "loop_log.csv"))
  write_loop_log(log, m)
  expect_error(check_candidate_slot(s, 7, m), "at most 6")
  write_loop_log(log[1:2, ], file.path(s, "loop_log.csv"))
  write_loop_log(log[1:2, ], m)
  file.create(file.path(s, "scores", "3.csv"))
  expect_error(check_candidate_slot(s, 3, m), "already exists")
})

test_that("the mirror is the record: a rewound or edited sandbox log stops the scoring", {
  s <- withr::local_tempdir()
  m <- file.path(withr::local_tempdir(), "mirror.csv")
  dir.create(file.path(s, "scores"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  map <- tibble::tibble(image = sprintf("img_%03d.png", 1:6),
                        image_path = sprintf("orig/%d.png", 1:6))
  images <- tibble::tibble(
    dataset = "d", image_path = map$image_path,
    defect_type = c("a", "a", "b", "good", "good", "good"),
    actual_class = c("defective", "defective", "defective", "nominal", "nominal", "nominal"),
    prob_defective = c(.9, .8, .7, .3, .2, .1))
  cand <- list(normal = "n", defective = "d", reason = "r")
  for (n in 1:3) finish_candidate(s, n, images, map, cand, mirror = m)
  expect_equal(nrow(read_loop_log(m)), 3L)
  # Rewind: cut the sandbox log to 2 rows and remove scores/3.csv.
  log_file <- file.path(s, "loop_log.csv")
  full <- read_loop_log(log_file)
  write_loop_log(full[1:2, ], log_file)
  unlink(file.path(s, "scores", "3.csv"))
  expect_error(check_candidate_slot(s, 3, m), "differs from the mirror")
  expect_error(finish_candidate(s, 3, images, map, cand, mirror = m), "differs from the mirror")
  expect_equal(nrow(read_loop_log(m)), 3L) # the record did not change
  # The slot is counted in the mirror: 4 is next, and 3 is not free.
  write_loop_log(full, log_file)
  expect_error(check_candidate_slot(s, 3, m), "next candidate is number 4")
  expect_silent(check_candidate_slot(s, 4, m))
  # No mirror, but rows in the sandbox log.
  unlink(m)
  expect_error(check_candidate_slot(s, 1, m), "no mirror")
})

test_that("a repeated scoring call shows in the audit", {
  s <- withr::local_tempdir()
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(bash_line("a1", "bash score.sh 1"), bash_line("a2", "bash score.sh 2"),
               bash_line("a3", "bash score.sh 2")), tr)
  audit <- audit_transcript(tr, s)
  expect_equal(audit$time, "a3")
  expect_equal(audit$target, "repeated scoring call for candidate 2")
})

test_that("ordinary scoring forms count and chains do not", {
  s <- normalizePath(withr::local_tempdir(), winslash = "/")
  counted <- c("bash score.sh 1 2>&1", "bash score.sh 2 2>&1 | tail -20",
               "bash score.sh 2 | head -n 40", "timeout 900 bash score.sh 3",
               "timeout 900 bash score.sh 4 2>&1 | tail -n 5",
               paste0("cd ", s, " && timeout 60 bash score.sh 5 2>&1"),
               "bash score.sh 6 | tail -3")
  expect_equal(purrr::map_int(counted, score_command_number, sandbox = s), c(1L, 2L, 2L, 3L, 4L, 5L, 6L))
  chains <- c("bash score.sh 1; echo done", "bash score.sh 1 && echo done",
              "bash score.sh 1 | cat", "bash score.sh 1 | grep x", "bash score.sh 7")
  expect_true(all(is.na(purrr::map_int(chains, score_command_number, sandbox = s))))
  # The audit agrees: a counted form gives no row.
  tr <- withr::local_tempfile(fileext = ".jsonl")
  dir.create(file.path(s, "images"))
  writeLines(purrr::imap_chr(counted, \(cmd, i) bash_line(paste0("c", i), cmd)), tr)
  audit <- audit_transcript(tr, s)
  expect_equal(audit$time, "c3") # score.sh 2 appears twice: the repeat is the 3rd line
  expect_match(audit$target, "repeated scoring call for candidate 2")
  expect_equal(sort(scoring_calls(tr, s)), c(1L, 2L, 2L, 3L, 4L, 5L, 6L))
})

test_that("scoring_calls skips odd lines, and powershell, pwsh and cmd are denied", {
  s <- withr::local_tempdir()
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c("42", "[1, 2]", "\"text\"", "{\"message\": \"x\"}",
               "{\"message\": {\"content\": [\"plain\", 1]}}",
               bash_line("a1", "bash score.sh 1")), tr)
  expect_equal(scoring_calls(tr, s), 1L)
  expect_gte(nrow(audit_transcript(tr, s)), 3L)
  denied <- c("powershell -Command ls", "pwsh -c ls", "cmd /c dir", "powershell.exe ls")
  tr2 <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(purrr::imap_chr(denied, \(cmd, i) bash_line(paste0("d", i), cmd)), tr2)
  expect_equal(nrow(audit_transcript(tr2, s)), length(denied))
})

test_that("a mirror from an earlier attempt blocks a new sandbox", {
  root <- withr::local_tempdir()
  map_dir <- withr::local_tempdir()
  writeLines("x", file.path(map_dir, "jev-extrusion_loop_log.csv"))
  expect_error(make_sandbox("jev", "extrusion", root, repo = repo_root, map_dir = map_dir,
                            record_root = make_record()),
               "earlier attempt")
  expect_false(dir.exists(file.path(root, "jev-extrusion")))
})

test_that("finishing a candidate scores, logs and recomputes the kept column", {
  s <- withr::local_tempdir()
  m <- file.path(withr::local_tempdir(), "mirror.csv")
  dir.create(file.path(s, "scores"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  map <- tibble::tibble(image = sprintf("img_%03d.png", 1:6),
                        image_path = sprintf("orig/%d.png", 1:6))
  images <- tibble::tibble(
    dataset = "d", image_path = map$image_path,
    defect_type = c("a", "a", "b", "good", "good", "good"),
    actual_class = c("defective", "defective", "defective", "nominal", "nominal", "nominal"))
  mk <- function(p) dplyr::mutate(images, prob_defective = p)
  cand <- list(normal = "n", defective = "d", reason = "r")
  out1 <- finish_candidate(s, 1, mk(c(.6, .6, .4, .5, .5, .5)), map, cand, mirror = m)
  expect_equal(out1$auc, 6 / 9)
  out2 <- finish_candidate(s, 2, mk(c(.9, .8, .7, .3, .2, .1)), map, cand, mirror = m)
  expect_equal(out2$auc, 1)
  log <- read_loop_log(file.path(s, "loop_log.csv"))
  expect_equal(log, read_loop_log(m))
  expect_equal(nrow(log), 2L)
  expect_named(log, c("candidate", "time_utc", "normal", "defective", "auc",
                      "mean_score_by_type", "reason", "kept"))
  expect_equal(log$kept, c(TRUE, TRUE))
  expect_match(log$mean_score_by_type[[2]], "a=0.85")
  scores <- readr::read_csv(file.path(s, "scores", "2.csv"), show_col_types = FALSE)
  expect_false(any(stringr::str_detect(unlist(scores), "orig/")))
  expect_equal(out2$best, 2L)
})

test_that("a second run of the same slot stops at the finish and logs nothing", {
  s <- withr::local_tempdir()
  m <- file.path(withr::local_tempdir(), "mirror.csv")
  dir.create(file.path(s, "scores"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  map <- tibble::tibble(image = sprintf("img_%03d.png", 1:6),
                        image_path = sprintf("orig/%d.png", 1:6))
  images <- tibble::tibble(
    dataset = "d", image_path = map$image_path,
    defect_type = c("a", "a", "b", "good", "good", "good"),
    actual_class = c("defective", "defective", "defective", "nominal", "nominal", "nominal"))
  mk <- function(p) dplyr::mutate(images, prob_defective = p)
  cand <- list(normal = "n", defective = "d", reason = "r")
  for (n in 1:5) finish_candidate(s, n, mk(c(.6, .6, .4, .5, .5, .5)), map, cand, mirror = m)
  # Two runs of slot 6 at once: both pass the check at the start.
  expect_silent(check_candidate_slot(s, 6, m))
  expect_silent(check_candidate_slot(s, 6, m))
  finish_candidate(s, 6, mk(c(.6, .6, .4, .5, .5, .5)), map,
                   list(normal = "TEXT A", defective = "d", reason = "r"), mirror = m)
  expect_error(finish_candidate(s, 6, mk(c(.9, .8, .7, .3, .2, .1)), map,
                                list(normal = "TEXT B", defective = "d", reason = "r"),
                                mirror = m),
               "not the next row")
  record <- read_loop_log(m)
  expect_equal(record$candidate, 1:6)
  expect_equal(record$normal[[6]], "TEXT A")
  expect_equal(read_loop_log(file.path(s, "loop_log.csv")), record)
  scores <- readr::read_csv(file.path(s, "scores", "6.csv"), show_col_types = FALSE)
  expect_equal(scores$prob_defective, c(.6, .6, .4, .5, .5, .5))
})

test_that("the keep rule gives the row of the best candidate", {
  # The log of the review: slot 6 logged twice, the second with TEXT B.
  log <- tibble::tibble(candidate = c(1:6, 6L), auc = c(rep(0.6, 5), 0.667, 1),
                        normal = c(paste0("n", 1:5), "TEXT A", "TEXT B"))
  rule <- apply_keep_rule(log)
  expect_equal(rule$best, 6L)
  expect_equal(rule$best_row, 7L)
  expect_equal(log$normal[[rule$best_row]], "TEXT B")
  expect_true(rule$kept[[rule$best_row]])
})

test_that("scoring forms that are not counted give an audit row and do not count", {
  s <- normalizePath(withr::local_tempdir(), winslash = "/")
  dir.create(file.path(s, "images"))
  forms <- c("bash score.sh 3 &", "nohup bash score.sh 3", "bash score.sh 3 > out.txt",
             "bash score.sh 3 | tee out.txt", "timeout -s KILL 900 bash score.sh 3",
             "JEV_CHECK_ONLY=true bash score.sh 3", "FAIR_MAP_DIR=fake bash score.sh 3",
             "bash score.sh 6 & bash score.sh 6", "./score.sh 3 &", "bash sc*.sh 3",
             ". sc*.sh 3", "ls images; source sc*.sh 3", "cat score.sh")
  expect_true(all(is.na(purrr::map_int(forms, score_command_number, sandbox = s))))
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(purrr::imap_chr(forms, \(cmd, i) bash_line(paste0("f", i), cmd)),
               tool_line("bg", "Bash", list(command = "bash score.sh 3",
                                            run_in_background = TRUE))), tr)
  audit <- audit_transcript(tr, s)
  expect_equal(audit$time, c(paste0("f", seq_along(forms)), "bg"))
  expect_equal(scoring_calls(tr, s), integer())
  # The clean audit of the review: a double run of slot 6, then a plain call.
  tr2 <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(purrr::map_chr(1:5, \(n) bash_line(paste0("c", n), paste("bash score.sh", n))),
               bash_line("x", "bash score.sh 6 & bash score.sh 6"),
               bash_line("c6", "bash score.sh 6")), tr2)
  audit2 <- audit_transcript(tr2, s)
  expect_equal(audit2$time, "x")
  expect_equal(audit2$target, "bash score.sh 6 & bash score.sh 6")
  expect_equal(scoring_calls(tr2, s), 1:6)
})

test_that("ordinary read commands stay unflagged", {
  s <- normalizePath(withr::local_tempdir(), winslash = "/")
  for (d in c("images", "scores")) dir.create(file.path(s, d))
  ok <- c("ls .", "ls -la", "cat labels.csv", "head -5 scores/1.csv", "wc -l labels.csv",
          "grep -c defective labels.csv", "ls images | head -3")
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(purrr::imap_chr(ok, \(cmd, i) bash_line(paste0("o", i), cmd)), tr)
  expect_equal(nrow(audit_transcript(tr, s)), 0L)
})

test_that("LOOP.md gives one rule for a failed scoring run", {
  text <- readLines(file.path(repo_root, "scripts", "fair_loop_instructions.md")) |>
    paste(collapse = "\n")
  expect_match(text, "run the same command once more", fixed = TRUE)
  expect_match(text, "If it fails again, stop", fixed = TRUE)
  expect_false(stringr::str_detect(text, "Do not retry"))
  # The one retry is allowed, and the audit shows it for a person to review.
  expect_match(text, "This one retry is allowed", fixed = TRUE)
  expect_match(text, "\"repeated scoring call\" row", fixed = TRUE)
  expect_match(text, "a person reviews it", fixed = TRUE)
})

test_that("LOOP.md bans the dollar sign in commands", {
  text <- readLines(file.path(repo_root, "scripts", "fair_loop_instructions.md")) |>
    paste(collapse = "\n")
  expect_match(text, "Do not use `$` in a command (for example in awk or R one-liners).",
               fixed = TRUE)
})

test_that("the audit flags a read of score.sh", {
  s <- withr::local_tempdir()
  sb <- normalizePath(s, winslash = "/")
  writeLines("x", file.path(s, "score.sh"))
  writeLines("x", file.path(s, "labels.csv"))
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(
    tool_line("r1", "Read", list(file_path = file.path(sb, "score.sh"))),
    tool_line("r2", "Read", list(file_path = "score.sh")),
    tool_line("r3", "Read", list(file_path = "./SCORE.SH")),
    tool_line("r4", "Grep", list(pattern = "FAIR", path = "score.sh")),
    tool_line("r5", "Read", list(file_path = file.path(sb, "labels.csv"))),
    tool_line("r6", "Read", list(file_path = "labels.csv")),
    bash_line("r7", "bash score.sh 1")
  ), tr)
  audit <- audit_transcript(tr, s)
  expect_equal(audit$time, c("r1", "r2", "r3", "r4"))
  expect_equal(audit$tool, c("Read", "Read", "Read", "Grep"))
})

test_that("the sandbox of a JEV loop needs FAIR_RECORD_ROOT with a Fair comparison row", {
  root <- withr::local_tempdir()
  map_dir <- withr::local_tempdir()
  withr::local_envvar(FAIR_RECORD_ROOT = NA)
  expect_error(make_sandbox("jev", "extrusion", root, repo = repo_root, map_dir = map_dir),
               "Set FAIR_RECORD_ROOT")
  expect_error(make_sandbox("jev", "extrusion", root, repo = repo_root, map_dir = map_dir,
                            record_root = file.path(root, "no-such-record")),
               "does not exist")
  bare <- withr::local_tempdir()
  dir.create(file.path(bare, "calls"))
  writeLines("| Date | Service | Purpose | Max calls |", file.path(bare, "calls", "README.md"))
  expect_error(make_sandbox("jev", "extrusion", root, repo = repo_root, map_dir = map_dir,
                            record_root = bare),
               "Fair comparison")
  expect_false(dir.exists(file.path(root, "jev-extrusion")))
  expect_length(list.files(map_dir), 0)
})

test_that("score.sh bakes the checked record root", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  made <- make_test_sandbox()
  sh <- readLines(file.path(made$sandbox, "score.sh"))
  expect_true(any(stringr::str_detect(sh, stringr::fixed(
    paste0("FAIR_RECORD_ROOT=\"", normalizePath(made$record, winslash = "/"), "\"")))))
})

test_that("the audit flags a planted read and ignores the scoring command", {
  s <- withr::local_tempdir()
  dir.create(file.path(s, "candidates"))
  sb <- normalizePath(s, winslash = "/")
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(
    tool_line("t1", "Read", list(file_path = file.path(sb, "labels.csv"))),
    tool_line("t2", "Read", list(file_path = "results/final_test/x.csv")),
    bash_line("t3", "bash score.sh 2"),
    bash_line("t4", "./score.sh 3"),
    bash_line("t5", paste0("bash ", file.path(sb, "score.sh"), " 4")),
    bash_line("t6", "cat ../experiment_log.md"),
    tool_line("t7", "Glob", list(pattern = "*.png", path = "C:/Users/someone/imgs")),
    tool_line("t8", "Grep", list(pattern = "x", path = ".")),
    tool_line("t9", "Write", list(file_path = file.path(dirname(sb), "other.csv"), content = "x")),
    tool_line("t10", "Write", list(file_path = file.path(sb, "candidates", "2.csv"), content = "x")),
    bash_line("t11", "ls images"),
    bash_line("t12", paste("Get-Content", file.path(repo_root, "experiment_log.md")), "PowerShell"),
    bash_line("t13", "Get-ChildItem ..", "PowerShell"),
    bash_line("t14", "bash score.sh 5", "PowerShell"),
    tool_line("t15", "Agent", list(prompt = "look around")),
    tool_line("t16", "WebFetch", list(url = "https://example.com")),
    tool_line("t17", "mcp__x__read_file", list(path = "a.txt")),
    tool_line("t18", "Read", list(file_path = file.path(repo_root, "R", "fair_runner.R"))),
    bash_line("t19", "cat $HOME/x.txt"),
    bash_line("t20", "cat ~/x.txt"),
    bash_line("t21", "Get-Content $env:USERPROFILE\\x.txt", "PowerShell"),
    tool_line("t22", "Write", list(file_path = file.path(sb, "score.sh"), content = "x")),
    tool_line("t23", "Edit", list(file_path = "labels.csv", old_string = "a", new_string = "b")),
    tool_line("t24", "TodoWrite", list(todos = list())),
    tool_line("t25", "Write", list(file_path = "candidates/3.csv", content = "x")),
    tool_line("t26", "Write", list(file_path = "candidates/1.csv", content = "x")),
    bash_line("t27", paste0("cd ", sb, " && bash score.sh 2")),
    bash_line("t28", "cd . && ./score.sh 6"),
    bash_line("t29", "cat labels.csv | head -5")
  ), tr)
  audit <- audit_transcript(tr, s)
  expect_named(audit, c("time", "tool", "target"))
  expect_setequal(audit$time, c("t2", "t6", "t7", "t9", "t12", "t13", "t14", "t15", "t16",
                                "t17", "t18", "t19", "t20", "t21", "t22", "t23", "t26", "t27"))
  expect_true("results/final_test/x.csv" %in% audit$target)
  empty <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(tool_line("t1", "Read", list(file_path = file.path(sb, "labels.csv"))), empty)
  expect_equal(nrow(audit_transcript(empty, s)), 0L)
  expect_named(audit_transcript(empty, s), c("time", "tool", "target"))
})

test_that("the audit denies commands that change folder or compute a path", {
  s <- withr::local_tempdir()
  sb <- normalizePath(s, winslash = "/")
  planted <- c(
    "Set-Location (Split-Path (Split-Path $PWD)); Set-Location fine_tuned_jev; Get-Content experiment_log.md",
    "Get-Content ([IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.gitconfig'))",
    "Get-ChildItem Y:",
    "Get-Content Y:notes.txt",
    "cd \"$(dirname \"$(dirname \"$PWD\")\")\" && cd fine_tuned_jev && cat experiment_log.md",
    "cd && cat .bashrc",
    "ls $APPDATA", "ls $TEMP", "ls $LOCALAPPDATA", "ls C:", "cd -", "pushd ..", "chdir x",
    "sl ..", "realpath .", "dirname x", "ls %APPDATA%", "cd /c/Users")
  for (tool in c("Bash", "PowerShell")) {
    tr <- withr::local_tempfile(fileext = ".jsonl")
    writeLines(purrr::imap_chr(planted, \(cmd, i) bash_line(paste0("p", i), cmd, tool)), tr)
    audit <- audit_transcript(tr, s)
    expect_equal(nrow(audit), length(planted), info = tool)
  }
  ok <- c("bash score.sh 1", "sh score.sh 2", "./score.sh 3", paste0(sb, "/score.sh 4"),
          paste0("bash \"", sb, "/score.sh\" 5"), paste0("cd ", sb, " && bash score.sh 6"),
          paste0("cd \"", sb, "\" && ./score.sh 2"), "cd . && bash score.sh 3",
          "ls images", "cat labels.csv", paste0("ls ", sb, "/images"))
  tr <- withr::local_tempfile(fileext = ".jsonl")
  dir.create(file.path(s, "images"))
  writeLines(purrr::imap_chr(ok, \(cmd, i) bash_line(paste0("o", i), cmd)), tr)
  expect_false(any(!stringr::str_detect(audit_transcript(tr, s)$target, "^repeated scoring call")))
})

test_that("the audit denies a bad line, a server tool block and a foreign cwd", {
  s <- withr::local_tempdir()
  sb <- normalizePath(s, winslash = "/")
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(
    "this is not json {",
    tool_line("a1", "web_search", list(query = "x"), type = "server_tool_use"),
    tool_line("a2", "Read", list(file_path = file.path(sb, "labels.csv")), cwd = sb),
    tool_line("a3", "Read", list(file_path = file.path(sb, "labels.csv")),
              cwd = dirname(sb))
  ), tr)
  audit <- audit_transcript(tr, s)
  expect_setequal(audit$tool, c("transcript", "server_tool_use", "cwd"))
  expect_equal(nrow(audit), 3L)
})

test_that("candidate 1 must be the generic description", {
  g <- generic_description()
  expect_silent(check_candidate_text(1L, list(normal = g$normal, defective = g$defective)))
  expect_error(check_candidate_text(1L, list(normal = "x", defective = g$defective)),
               "generic")
  expect_silent(check_candidate_text(2L, list(normal = "x", defective = "y")))
})

# A fake loop: sandbox with a log, the outside records, and a transcript.
fake_loop <- function(calls = 1:3, log = NULL, env = parent.frame()) {
  s <- withr::local_tempdir(.local_envir = env)
  out <- withr::local_tempdir(.local_envir = env)
  dir.create(file.path(out, "loop"))
  if (is.null(log)) {
    log <- tibble::tibble(candidate = 1:3, time_utc = "t", normal = c("n1", "n2", "n3"),
                          defective = c("d1", "d2", "d3"), auc = c(.8, .85, .86),
                          mean_score_by_type = "a=1", reason = "r", kept = NA)
  }
  write_loop_log(log, file.path(s, "loop_log.csv"))
  write_loop_log(log, file.path(out, "loop", "jev-extrusion_loop_log.csv"))
  writeLines("#!/usr/bin/env bash", file.path(s, "score.sh"))
  writeLines(unname(tools::md5sum(file.path(s, "score.sh"))),
             file.path(out, "loop", "jev-extrusion_score_sh.md5"))
  tr <- withr::local_tempfile(fileext = ".jsonl", .local_envir = env)
  writeLines(purrr::map_chr(calls, \(n) bash_line(paste0("c", n), paste("bash score.sh", n))), tr)
  list(s = s, out = out, tr = tr)
}

close_fake <- function(f, ...) {
  close_loop("jev", "extrusion", f$tr, f$s, loop_dir = file.path(f$out, "loop"),
             description_dir = file.path(f$out, "descriptions"), ...)
}

test_that("closing the loop copies the log, writes the audit and freezes once", {
  f <- fake_loop()
  res <- close_fake(f)
  frozen <- readr::read_csv(file.path(f$out, "descriptions", "jev_extrusion.csv"),
                            show_col_types = FALSE)
  expect_equal(frozen$normal, "n2")
  expect_equal(frozen$defective, "d2")
  expect_equal(res$best, 2L)
  logcopy <- readr::read_csv(file.path(f$out, "loop", "jev-extrusion_log.csv"),
                             show_col_types = FALSE)
  expect_equal(logcopy$transcript, rep(basename(f$tr), 3))
  expect_equal(logcopy$transcript_md5, rep(unname(tools::md5sum(f$tr)), 3))
  audit <- readr::read_csv(file.path(f$out, "loop", "jev-extrusion_audit.csv"),
                           show_col_types = FALSE)
  expect_named(audit, c("time", "tool", "target", "transcript", "transcript_md5"))
  expect_equal(audit$tool, "none")
  expect_equal(audit$transcript, basename(f$tr))
  expect_equal(res$audit_rows, 0L)
  expect_error(close_fake(f), "already frozen")
})

test_that("closing stops on an edited score.sh, a changed log or a missing call", {
  f <- fake_loop()
  writeLines(c("#!/usr/bin/env bash", "echo changed"), file.path(f$s, "score.sh"))
  expect_error(close_fake(f), "score.sh changed")
  expect_false(file.exists(file.path(f$out, "descriptions", "jev_extrusion.csv")))

  f <- fake_loop()
  log <- read_loop_log(file.path(f$s, "loop_log.csv"))
  log$auc[[3]] <- 0.99
  write_loop_log(log, file.path(f$s, "loop_log.csv"))
  expect_error(close_fake(f), "differs from the mirror")

  f <- fake_loop()
  unlink(file.path(f$out, "loop", "jev-extrusion_loop_log.csv"))
  expect_error(close_fake(f), "No mirror")

  f <- fake_loop(calls = c(1, 3))
  expect_error(close_fake(f), "no scoring call for candidate 2")
  expect_false(file.exists(file.path(f$out, "loop", "jev-extrusion_audit.csv")))

  f <- fake_loop()
  unlink(file.path(f$out, "loop", "jev-extrusion_score_sh.md5"))
  expect_error(close_fake(f), "No md5")
})

fake_log <- function(candidate, auc = seq(0.6, by = 0.03, length.out = length(candidate)),
                     normal = paste0("n", seq_along(candidate))) {
  tibble::tibble(candidate = as.integer(candidate), time_utc = "t", normal = normal,
                 defective = paste0("d", seq_along(candidate)), auc = auc,
                 mean_score_by_type = "a=1", reason = "r", kept = NA)
}

test_that("closing stops on a duplicated or gapped candidate list and on more than 6 rows", {
  # The log of the review: slot 6 twice, the second row (TEXT B) has the best AUC.
  review <- fake_log(c(1:6, 6L), auc = c(rep(0.6, 5), 0.667, 1),
                     normal = c(paste0("n", 1:5), "TEXT A", "TEXT B"))
  cases <- list(duplicated = list(log = review, error = "each once"),
                gapped = list(log = fake_log(c(1, 2, 4)), error = "each once"),
                seven = list(log = fake_log(1:7), error = "more than 6"))
  for (name in names(cases)) {
    log <- cases[[name]]$log
    f <- fake_loop(calls = unique(log$candidate), log = log)
    expect_error(close_fake(f), cases[[name]]$error, info = name)
    expect_false(file.exists(file.path(f$out, "descriptions", "jev_extrusion.csv")))
    expect_false(file.exists(file.path(f$out, "loop", "jev-extrusion_audit.csv")))
    expect_false(file.exists(file.path(f$out, "loop", "jev-extrusion_log.csv")))
  }
})

test_that("the freeze takes the text of the last kept row", {
  log <- fake_log(1:5, auc = c(.80, .83, .84, .86, .87))
  f <- fake_loop(calls = 1:5, log = log)
  res <- close_fake(f)
  logcopy <- readr::read_csv(file.path(f$out, "loop", "jev-extrusion_log.csv"),
                             show_col_types = FALSE)
  expect_equal(logcopy$kept, c(TRUE, TRUE, FALSE, TRUE, FALSE))
  frozen <- readr::read_csv(file.path(f$out, "descriptions", "jev_extrusion.csv"),
                            show_col_types = FALSE)
  last_kept <- max(which(logcopy$kept))
  expect_equal(frozen$normal, logcopy$normal[[last_kept]])
  expect_equal(frozen$defective, logcopy$defective[[last_kept]])
  expect_equal(res$best, 4L)
})

test_that("a retry after a failed run closes with one repeat row", {
  f <- fake_loop(calls = c(1, 2, 2, 3))
  res <- close_fake(f)
  audit <- readr::read_csv(file.path(f$out, "loop", "jev-extrusion_audit.csv"),
                           show_col_types = FALSE)
  expect_equal(audit$target, "repeated scoring call for candidate 2")
  expect_equal(res$audit_rows, 1L)
  expect_equal(res$best, 2L)
})

test_that("the audit file lists a flagged call with the transcript name", {
  f <- fake_loop()
  writeLines(c(readLines(f$tr), tool_line("x1", "Agent", list(prompt = "hi"))), f$tr)
  res <- close_fake(f)
  audit <- readr::read_csv(file.path(f$out, "loop", "jev-extrusion_audit.csv"),
                           show_col_types = FALSE)
  expect_equal(audit$tool, "Agent")
  expect_equal(audit$transcript, basename(f$tr))
  expect_equal(res$audit_rows, 1L)
})

test_that("special characters go from a candidate through the log into the frozen file", {
  s <- withr::local_tempdir()
  out <- withr::local_tempdir()
  dir.create(file.path(s, "scores"))
  dir.create(file.path(out, "loop"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  writeLines("x", file.path(s, "score.sh"))
  writeLines(unname(tools::md5sum(file.path(s, "score.sh"))),
             file.path(out, "loop", "jev-extrusion_score_sh.md5"))
  cand_file <- file.path(s, "cand.csv")
  write_candidate(cand_file, "Clean, \"smooth\" | part\nline two", "Cut, \"gap\" | x\ny",
                  "why, \"so\"")
  cand <- read_candidate(cand_file)
  map <- tibble::tibble(image = c("img_001.png", "img_002.png"),
                        image_path = c("o/1.png", "o/2.png"))
  scores <- tibble::tibble(dataset = "d", image_path = map$image_path,
                           defect_type = c("a", "good"),
                           actual_class = c("defective", "nominal"),
                           prob_defective = c(.9, .1))
  finish_candidate(s, 1, scores, map, cand,
                   mirror = file.path(out, "loop", "jev-extrusion_loop_log.csv"))
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(bash_line("c1", "bash score.sh 1"), tr)
  close_loop("jev", "extrusion", tr, s, loop_dir = file.path(out, "loop"),
             description_dir = file.path(out, "descriptions"))
  frozen <- readr::read_csv(file.path(out, "descriptions", "jev_extrusion.csv"),
                            show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  expect_equal(frozen$normal, cand$normal)
  expect_equal(frozen$defective, cand$defective)
})

test_that("a bad candidate file is refused before any call", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("normal,defective", "a,b"), f)
  expect_error(read_candidate(f), "columns normal, defective and reason")
  writeLines(c("normal,defective,reason", "a,,why"), f)
  expect_error(read_candidate(f), "empty")
  writeLines(c("normal,defective,reason", "a,b,why", "c,d,why"), f)
  expect_error(read_candidate(f), "exactly one")
  writeLines(c("normal,defective,reason", "\"a,b,why"), f)
  expect_error(read_candidate(f))
})

test_that("score.sh names only the repository root, sandbox, record root and Rscript", {
  # The pure helper writes nothing, so this test touches no record.
  repo <- normalizePath(repo_root, winslash = "/")
  sandbox <- "C:/fake/box/jev-extrusion"
  record <- file.path(repo, "replication_materials")
  sh <- score_script_lines(repo, "jev", "extrusion", sandbox, record,
                           file.path(repo, "results", "fair", "loop"), rscript)
  expect_false(any(stringr::str_detect(sh, "FAIR_MAP_DIR")))
  expect_false(any(stringr::str_detect(sh, "results/")))
  other <- score_script_lines(repo, "jev", "extrusion", sandbox, record, "C:/elsewhere/maps",
                              rscript)
  expect_true(any(stringr::str_detect(other, "FAIR_MAP_DIR")))
  paths <- unlist(stringr::str_extract_all(paste(sh, collapse = " "),
                                           "(?<=\")[A-Za-z]:/[^\"]+"))
  allowed <- c(repo, sandbox, record, rscript)
  ok <- purrr::map_lgl(paths, \(p) any(stringr::str_starts(p, stringr::fixed(allowed))))
  expect_true(all(ok))
})

test_that("score.sh and LOOP.md use LF line endings", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  s <- make_test_sandbox()$sandbox
  for (f in c("score.sh", "LOOP.md")) {
    bytes <- readBin(file.path(s, f), "raw", 100000)
    expect_false(as.raw(13) %in% bytes, info = f)
  }
})

test_that("the scorer refuses candidate 7 and a skipped number in check-only mode", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  made <- make_test_sandbox()
  record <- withr::local_tempdir()
  run <- function(n) {
    cand <- file.path(made$sandbox, "candidates", paste0(n, ".csv"))
    if (!file.exists(cand)) {
      file.copy(file.path(made$sandbox, "candidates", "1.csv"), cand)
    }
    out <- withr::with_envvar(
      c(FAIR_MODEL = "jev", FAIR_DATASET = "extrusion", FAIR_K = "2",
        FAIR_SPLIT = "design", FAIR_DESCRIPTION = cand, FAIR_OUT = made$sandbox,
        JEV_CHECK_ONLY = "true", FAIR_MAP_DIR = made$map_dir, FAIR_RECORD_ROOT = record),
      suppressWarnings(system2(rscript, "scripts/fair_score.R", stdout = TRUE, stderr = TRUE)))
    paste(out, collapse = "\n")
  }
  withr::local_dir(repo_root)
  expect_match(run(7), "at most 6")
  expect_match(run(3), "next candidate")
  expect_match(run(1), "checks passed")
})

test_that("the design score file keeps elapsed_ms when the scores have it", {
  s <- withr::local_tempdir()
  m <- file.path(withr::local_tempdir(), "mirror_loop_log.csv")
  dir.create(file.path(s, "scores"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  map <- tibble::tibble(image = c("img_001.png", "img_002.png"), image_path = c("o/1.png", "o/2.png"))
  scores <- tibble::tibble(dataset = "d", image_path = map$image_path,
                           defect_type = c("a", "good"),
                           actual_class = c("defective", "nominal"),
                           prob_defective = c(.9, .1), elapsed_ms = c(1200, 1300))
  finish_candidate(s, 1, scores, map, list(normal = "n", defective = "d", reason = "r"), mirror = m)
  written <- readr::read_csv(file.path(s, "scores", "1.csv"), show_col_types = FALSE)
  expect_equal(written$elapsed_ms, c(1200, 1300))
})
