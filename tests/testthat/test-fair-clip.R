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

test_that("zero_final cuts long descriptions at 77 tokens and reports the cut", {
  skip_without_clip()
  desc <- withr::local_tempdir()
  out <- withr::local_tempdir()
  long <- paste(rep("a bright metallic surface with fine scratches", 20), collapse = " ")
  readr::write_csv(tibble::tibble(normal = "A clean pan.", defective = long),
                   file.path(desc, "jev_pan_images.csv"))
  withr::local_dir(repo_root)
  withr::local_envvar(FAIR_CLIP_TEXT = "final", FAIR_DATASETS = "pan_images",
                      FAIR_SPLITS = "calibration", FAIR_OUT = out, FAIR_DESC_DIR = desc)
  run <- \() system2(file.path(R.home("bin"), "Rscript"), "scripts/fair_clip.R",
                     stdout = FALSE, stderr = FALSE)
  expect_equal(run(), 0)
  trunc <- readr::read_csv(file.path(out, "clip_truncation.csv"), show_col_types = FALSE)
  expect_equal(trunc$class, c("normal", "defective"))
  expect_equal(trunc$truncated, c(FALSE, TRUE))
  s <- readr::read_csv(file.path(out, "clip_zero_final_k0_pan_images_calibration.csv"),
                       show_col_types = FALSE)
  expect_equal(nrow(s), 20)
  expect_equal(unique(s$description), "zero_final")
  # one-time: a second run stops and keeps the file
  expect_false(run() == 0)
})
