# CLIP variants on the shared sets. Skipped without the CLIP environment.
source(file.path(repo_root, "R", "fair_clip.R"))
source(file.path(repo_root, "R", "fair_runner.R"))

skip_without_clip <- function() {
  testthat::skip_if(!nzchar(Sys.getenv("RETICULATE_PYTHON")), "RETICULATE_PYTHON is not set")
}
scores_dir <- file.path(repo_root, "results", "fair", "scores")
sets_dir <- file.path(repo_root, "results", "fair", "sets")
datasets <- c("extrusion", "microstructure", "pan_images", "pipe_staple", "textiles")
paper_setting <- c(extrusion = "extrusion_50", microstructure = "microstructure_50",
                   pan_images = "pan_10", pipe_staple = "pipe_staple_50", textiles = "textiles_50")
read_scores <- function(name) readr::read_csv(file.path(scores_dir, name), show_col_types = FALSE)

test_that("leave-one-out never scores an image against itself or its MD5 twin", {
  skip_without_clip()
  # a and a2 are twins (same MD5). a2 would be the nearest defective image of a.
  f <- rbind(a = c(1, 0), a2 = c(1, 0), n = c(0, 1), d = c(0.6, 0.8))
  labels <- c("defective", "defective", "nominal", "defective")
  md5 <- c("x", "x", "y", "z")
  p <- clip_loo_probability(f, labels, md5)
  # a: nominal max = 0 (n), defective max = 0.6 (d only; a and a2 excluded)
  expect_equal(unname(p[1]), stats::plogis(0.6 - 0))
  expect_equal(unname(p[1]), unname(p[2]))
  # n: nominal max = -Inf is not used because n is the only nominal: its own
  # similarity is removed, so the nominal maximum is -Inf and the score is 1.
  expect_equal(unname(p[3]), 1)
})

test_that("the baseline test scores equal the saved CLIP baseline predictions", {
  skip_without_clip()
  for (d in datasets) {
    k <- if (d == "pan_images") 10 else 50
    mine <- read_scores(paste0("clip_baseline_k", k, "_", d, "_test.csv"))
    saved <- readr::read_csv(
      file.path(repo_root, "results", "clip_paper", paste0(paper_setting[[d]], "_test_predictions.csv")),
      show_col_types = FALSE)
    joined <- dplyr::inner_join(mine, saved, by = "image_path", suffix = c("", "_saved"))
    expect_equal(nrow(joined), nrow(saved), info = d)
    expect_lt(max(abs(joined$prob_defective - joined$prob_defective_saved)), 1e-5, label = d)
  }
})

test_that("the pan baseline calibration scores are the leave-one-out scores of L", {
  skip_without_clip()
  mine <- read_scores("clip_baseline_k10_pan_images_calibration.csv")
  saved <- readr::read_csv(file.path(repo_root, "results", "clip_paper", "pan_10_learning_loo_scores.csv"),
                           show_col_types = FALSE)
  joined <- dplyr::inner_join(mine, saved, by = "image_path")
  expect_equal(nrow(joined), 20)
  expect_lt(max(abs(joined$prob_defective - joined$prob_defective_loo)), 1e-5)
})

test_that("row counts equal the set sizes and the schema is the score schema", {
  skip_without_clip()
  columns <- c("dataset", "image_path", "defect_type", "actual_class", "prob_defective",
               "model", "description", "k", "split")
  test_n <- readr::read_csv(file.path(repo_root, "results", "image_split_manifest.csv"),
                            show_col_types = FALSE) |>
    dplyr::filter(.data$split == "test") |>
    dplyr::count(.data$dataset)
  for (d in datasets) {
    n_test <- test_n$n[test_n$dataset == d]
    variants <- list(list("baseline", if (d == "pan_images") 10 else 50),
                     list("refs", 1), list("refs", 2), list("refs", 4), list("zero", 0))
    for (v in variants) {
      for (split in c("calibration", "test")) {
        s <- read_scores(score_file_name("clip", v[[1]], v[[2]], d, split))
        expected <- if (split == "test") n_test else nrow(fair_images(
          d, "calibration", if (v[[1]] == "baseline") 0 else v[[2]], sets_dir = sets_dir))
        expect_equal(nrow(s), expected, info = paste(d, v[[1]], v[[2]], split))
        expect_equal(names(s), columns)
        expect_true(all(s$prob_defective >= 0 & s$prob_defective <= 1))
        expect_equal(unique(s$model), "clip")
        expect_equal(unique(s$description), v[[1]])
        expect_equal(unique(s$k), v[[2]])
        expect_equal(unique(s$split), split)
      }
    }
  }
})

test_that("a pan refs calibration set holds L without the references", {
  skip_without_clip()
  s <- read_scores("clip_refs_k2_pan_images_calibration.csv")
  refs <- readr::read_csv(file.path(sets_dir, "references.csv"), show_col_types = FALSE) |>
    dplyr::filter(.data$dataset == "pan_images", .data$rank <= 2)
  expect_equal(nrow(s), 16)
  expect_false(any(s$image_path %in% refs$image_path))
})

run_clip_script <- function() {
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), "scripts/fair_clip.R",
                                  stdout = TRUE, stderr = TRUE))
  list(text = paste(out, collapse = "
"),
       status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"))
}

test_that("zero_final skips pans and datasets with no frozen JEV description", {
  skip_without_clip()
  desc <- withr::local_tempdir()
  out <- withr::local_tempdir()
  long <- paste(rep("a bright metallic clamp with fine scratches", 20), collapse = " ")
  readr::write_csv(tibble::tibble(normal = "A clamp holds the pipe.", defective = long),
                   file.path(desc, "jev_pipe_staple.csv"))
  readr::write_csv(tibble::tibble(normal = "A clean pan.", defective = "A marked pan."),
                   file.path(desc, "jev_pan_images.csv"))
  withr::local_dir(repo_root)
  withr::local_envvar(FAIR_CLIP_TEXT = "final", FAIR_DATASETS = "pan_images,pipe_staple,textiles",
                      FAIR_SPLITS = "calibration", FAIR_OUT = out, FAIR_DESC_DIR = desc)
  res <- run_clip_script()
  expect_equal(res$status, 0L)
  expect_match(res$text, "zero_final skips pan_images", fixed = TRUE)
  expect_match(res$text, "zero_final skips textiles", fixed = TRUE)
  expect_setequal(list.files(out), c("clip_truncation.csv",
                                     "clip_zero_final_k0_pipe_staple_calibration.csv"))
  trunc <- readr::read_csv(file.path(out, "clip_truncation.csv"), show_col_types = FALSE)
  expect_equal(trunc$dataset, c("pipe_staple", "pipe_staple"))
  expect_equal(trunc$class, c("normal", "defective"))
  expect_equal(trunc$truncated, c(FALSE, TRUE))
  s <- readr::read_csv(file.path(out, "clip_zero_final_k0_pipe_staple_calibration.csv"),
                       show_col_types = FALSE)
  expect_equal(nrow(s), 34)
  expect_equal(unique(s$description), "zero_final")
  # The test split comes after the calibration split, in a second run. The
  # truncation file of the first run does not block it.
  withr::local_envvar(FAIR_SPLITS = "test", FAIR_DATASETS = "pipe_staple")
  expect_equal(run_clip_script()$status, 0L)
  expect_equal(nrow(readr::read_csv(file.path(out, "clip_zero_final_k0_pipe_staple_test.csv"),
                                    show_col_types = FALSE)), 100)
  # One-time: a second run of a split stops and keeps the files.
  withr::local_envvar(FAIR_SPLITS = "calibration")
  expect_false(run_clip_script()$status == 0L)
  expect_equal(nrow(readr::read_csv(file.path(out, "clip_truncation.csv"), show_col_types = FALSE)), 2)
})

test_that("a zero_final test run needs its calibration run first", {
  skip_without_clip()
  desc <- withr::local_tempdir()
  out <- withr::local_tempdir()
  readr::write_csv(tibble::tibble(normal = "A clamp holds the pipe.", defective = "No clamp."),
                   file.path(desc, "jev_pipe_staple.csv"))
  withr::local_dir(repo_root)
  withr::local_envvar(FAIR_CLIP_TEXT = "final", FAIR_DATASETS = "pipe_staple",
                      FAIR_SPLITS = "test", FAIR_OUT = out, FAIR_DESC_DIR = desc)
  res <- run_clip_script()
  expect_false(res$status == 0L)
  expect_match(res$text, "Run the calibration split first", fixed = TRUE)
  expect_length(list.files(out), 0)
})

test_that("zero_final with no frozen description at all writes nothing and says so", {
  skip_without_clip()
  out <- withr::local_tempdir()
  withr::local_dir(repo_root)
  withr::local_envvar(FAIR_CLIP_TEXT = "final", FAIR_DATASETS = NA, FAIR_SPLITS = NA,
                      FAIR_OUT = out, FAIR_DESC_DIR = withr::local_tempdir())
  res <- run_clip_script()
  expect_equal(res$status, 0L)
  expect_match(res$text, "No dataset has a frozen JEV description", fixed = TRUE)
  expect_length(list.files(out), 0)
})

test_that("the timing pass writes per-image times and one run row per variant", {
  skip_without_clip()
  tim <- withr::local_tempdir()
  withr::local_dir(repo_root)
  withr::local_envvar(FAIR_DATASETS = "pan_images", FAIR_TIMING_N = "3", FAIR_TIMING_DIR = tim)
  run <- \() system2(file.path(R.home("bin"), "Rscript"), "scripts/fair_clip_timing.R",
                     stdout = FALSE, stderr = FALSE)
  expect_equal(run(), 0)
  timing <- readr::read_csv(file.path(tim, "clip_timing.csv"), show_col_types = FALSE)
  expect_named(timing, c("variant", "k", "dataset", "image_path", "encode_ms", "score_ms"))
  expect_equal(nrow(timing), 3 * 5)
  expect_true(all(timing$encode_ms > 0 & timing$score_ms >= 0))
  expect_setequal(timing$k[timing$variant == "baseline"], 10)
  runs <- readr::read_csv(file.path(tim, "runs.csv"), show_col_types = FALSE)
  expect_equal(nrow(runs), 5)
  expect_equal(unique(runs$model), "clip")
  expect_equal(unique(runs$split), "test")
  # the CLIP score files are not touched, and a second run stops
  expect_false(run() == 0)
})
