source(file.path(repo_root, "R", "fair_runner.R"))
source(file.path(repo_root, "R", "fair_loop.R"))

rscript <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"

# One real sandbox for jev / extrusion, in temporary folders only.
make_test_sandbox <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  map_dir <- withr::local_tempdir(.local_envir = env)
  sandbox <- make_sandbox("jev", "extrusion", root, repo = repo_root,
                          map_dir = map_dir)
  list(sandbox = sandbox, map_dir = map_dir)
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
  dir.create(file.path(s, "scores"))
  write_loop_log(empty_loop_log(), file.path(s, "loop_log.csv"))
  expect_silent(check_candidate_slot(s, 1))
  expect_error(check_candidate_slot(s, 2), "next candidate")
  log <- tibble::tibble(candidate = 1:6, time_utc = "t", normal = "n", defective = "d",
                        auc = 0.5, mean_score_by_type = "a=1", reason = "r", kept = TRUE)
  write_loop_log(log, file.path(s, "loop_log.csv"))
  expect_error(check_candidate_slot(s, 7), "at most 6")
  write_loop_log(log[1:2, ], file.path(s, "loop_log.csv"))
  file.create(file.path(s, "scores", "3.csv"))
  expect_error(check_candidate_slot(s, 3), "already exists")
})

test_that("finishing a candidate scores, logs and recomputes the kept column", {
  s <- withr::local_tempdir()
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
  out1 <- finish_candidate(s, 1, mk(c(.6, .6, .4, .5, .5, .5)), map, cand)
  expect_equal(out1$auc, 6 / 9)
  out2 <- finish_candidate(s, 2, mk(c(.9, .8, .7, .3, .2, .1)), map, cand)
  expect_equal(out2$auc, 1)
  log <- read_loop_log(file.path(s, "loop_log.csv"))
  expect_equal(nrow(log), 2L)
  expect_named(log, c("candidate", "time_utc", "normal", "defective", "auc",
                      "mean_score_by_type", "reason", "kept"))
  expect_equal(log$kept, c(TRUE, TRUE))
  expect_match(log$mean_score_by_type[[2]], "a=0.85")
  scores <- readr::read_csv(file.path(s, "scores", "2.csv"), show_col_types = FALSE)
  expect_false(any(stringr::str_detect(unlist(scores), "orig/")))
  expect_equal(out2$best, 2L)
})

test_that("the audit flags a planted read and ignores the scoring command", {
  s <- withr::local_tempdir()
  sb <- normalizePath(s, winslash = "/")
  tr <- withr::local_tempfile(fileext = ".jsonl")
  line <- function(time, name, input) {
    as.character(jsonlite::toJSON(list(
      type = "assistant", timestamp = time,
      message = list(role = "assistant",
                     content = list(list(type = "tool_use", id = "x", name = name,
                                         input = input)))), auto_unbox = TRUE))
  }
  writeLines(c(
    line("t1", "Read", list(file_path = file.path(sb, "labels.csv"))),
    line("t2", "Read", list(file_path = "results/final_test/x.csv")),
    line("t3", "Bash", list(command = "bash score.sh 2")),
    line("t4", "Bash", list(command = "./score.sh 3")),
    line("t5", "Bash", list(command = paste0("bash ", file.path(sb, "score.sh"), " 4"))),
    line("t6", "Bash", list(command = "cat ../experiment_log.md")),
    line("t7", "Glob", list(pattern = "*.png", path = "C:/Users/someone/imgs")),
    line("t8", "Grep", list(pattern = "x", path = ".")),
    line("t9", "Write", list(file_path = file.path(dirname(sb), "other.csv"), content = "x")),
    line("t10", "Write", list(file_path = file.path(sb, "candidates", "2.csv"), content = "x")),
    line("t11", "Bash", list(command = "ls images"))
  ), tr)
  audit <- audit_transcript(tr, s)
  expect_named(audit, c("time", "tool", "target"))
  expect_setequal(audit$time, c("t2", "t6", "t7", "t9"))
  expect_true("results/final_test/x.csv" %in% audit$target)
  empty <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(line("t1", "Read", list(file_path = file.path(sb, "labels.csv"))), empty)
  expect_equal(nrow(audit_transcript(empty, s)), 0L)
  expect_named(audit_transcript(empty, s), c("time", "tool", "target"))
})

test_that("closing the loop copies the log, writes the audit and freezes once", {
  s <- withr::local_tempdir()
  out <- withr::local_tempdir()
  log <- tibble::tibble(candidate = 1:3, time_utc = "t", normal = c("n1", "n2", "n3"),
                        defective = c("d1", "d2", "d3"), auc = c(.8, .85, .86),
                        mean_score_by_type = "a=1", reason = "r", kept = NA)
  write_loop_log(log, file.path(s, "loop_log.csv"))
  tr <- withr::local_tempfile(fileext = ".jsonl")
  writeLines("", tr)
  res <- close_loop("jev", "extrusion", tr, s, loop_dir = file.path(out, "loop"),
                    description_dir = file.path(out, "descriptions"))
  frozen <- readr::read_csv(file.path(out, "descriptions", "jev_extrusion.csv"),
                            show_col_types = FALSE)
  expect_equal(frozen$normal, "n2")
  expect_equal(frozen$defective, "d2")
  expect_equal(res$best, 2L)
  expect_true(file.exists(file.path(out, "loop", "jev-extrusion_log.csv")))
  expect_equal(nrow(readr::read_csv(file.path(out, "loop", "jev-extrusion_audit.csv"),
                                    show_col_types = FALSE)), 0L)
  expect_error(close_loop("jev", "extrusion", tr, s, loop_dir = file.path(out, "loop"),
                          description_dir = file.path(out, "descriptions")),
               "already frozen")
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
