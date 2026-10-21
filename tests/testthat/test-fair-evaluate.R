# Evaluation of the fair comparison, on synthetic score files in a temp folder.
source(file.path(repo_root, "R", "evaluation.R"))
source(file.path(repo_root, "R", "calibration_functions.R"))
source(file.path(repo_root, "R", "fair_evaluate.R"))

all_datasets <- c("extrusion", "microstructure", "pan_images", "pipe_staple", "textiles")

# One score file. `signal` sets how well the scores separate the classes.
write_scores <- function(dir, model, description, k, dataset, split, signal,
                         n = 12, seed = 1, probs = NULL) {
  set.seed(seed + k + nchar(description) + nchar(dataset) + nchar(split))
  cls <- rep(c("defective", "nominal"), each = n / 2)
  if (is.null(probs)) {
    probs <- stats::plogis(signal * ifelse(cls == "defective", 1, -1) +
                             stats::rnorm(n))
  }
  tibble::tibble(
    dataset = dataset, image_path = paste0(dataset, "/", split, "/", seq_len(n), ".png"),
    defect_type = cls, actual_class = cls, prob_defective = probs,
    model = model, description = description, k = k, split = split
  ) |>
    readr::write_csv(file.path(dir, paste0(model, "_", description, "_k", k, "_",
                                           dataset, "_", split, ".csv")))
}

make_folder <- function(signal_for = \(model, description, k) 0.8) {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  for (d in all_datasets) {
    specs <- tibble::tribble(
      ~model, ~description, ~k,
      "clip", "baseline", 50,
      "clip", "zero", 0, "clip", "refs", 1, "clip", "refs", 2, "clip", "refs", 4
    )
    for (m in c("jev", "clef")) {
      desc <- if (d == "pan_images") "generic" else "final"
      specs <- dplyr::bind_rows(specs, tibble::tibble(
        model = m, description = desc, k = c(0, 1, 2, 4)))
      if (d != "pan_images") {
        specs <- dplyr::bind_rows(specs, tibble::tibble(
          model = m, description = "generic", k = c(0, 2)))
      }
    }
    purrr::pwalk(specs, \(model, description, k) {
      for (s in c("calibration", "test")) {
        write_scores(dir, model, description, k, d, s,
                     signal_for(model, description, k))
      }
    })
  }
  dir
}

test_that("metrics of a known configuration match hand-computed values", {
  dir <- withr::local_tempdir()
  # Test: defective .9, .4; nominal .6, .1. TP 1, FN 1, FP 1, TN 1.
  write_scores(dir, "clip", "zero", 0, "extrusion", "test", 0, n = 4,
               probs = c(0.9, 0.4, 0.6, 0.1))
  write_scores(dir, "clip", "zero", 0, "extrusion", "calibration", 1)
  m <- calibrate_all(read_fair_scores(dir)) |> metrics_table() |>
    dplyr::filter(split == "test", calibration == "raw")
  get <- \(name) m$value[m$metric == name]
  expect_equal(get("accuracy"), 0.5)
  expect_equal(get("bal_accuracy"), 0.5)
  expect_equal(get("sens"), 0.5)
  expect_equal(get("spec"), 0.5)
  expect_equal(get("mcc"), 0)
  expect_equal(get("roc_auc"), 0.75)
  expect_equal(get("brier_class"), mean(c(0.1, 0.6, 0.6, 0.1)^2))
  expect_false(any(m$in_sample))
  expect_setequal(unique(metrics_table(calibrate_all(read_fair_scores(dir)))$calibration),
                  c("raw", "platt", "isotonic"))
})

test_that("calibration rows are in sample and only these are flagged", {
  m <- make_folder() |> read_fair_scores() |> calibrate_all() |> metrics_table()
  expect_true(all(m$in_sample[m$split == "calibration" & m$calibration != "raw"]))
  expect_false(any(m$in_sample[m$split == "test"]))
})

test_that("calibration uses only the calibration file", {
  dir <- make_folder()
  before <- read_fair_scores(dir) |> calibrate_all()
  # Replace one test file by very different scores.
  write_scores(dir, "jev", "final", 2, "extrusion", "test", 0, n = 12,
               probs = rep(c(0.99, 0.01), 6))
  after <- read_fair_scores(dir) |> calibrate_all()
  key <- \(d) dplyr::filter(d, model == "jev", description == "final", k == 2,
                            dataset == "extrusion")
  # The calibration rows of the configuration do not move ...
  expect_equal(dplyr::filter(key(before), split == "calibration"),
               dplyr::filter(key(after), split == "calibration"))
  # ... and the fit is the same function: a test row with the same raw score
  # gets the same Platt value before and after.
  cal <- dplyr::filter(key(before), split == "calibration")
  y <- as.integer(cal$actual_class == "defective")
  expect_equal(platt(cal$prob_defective, y)(c(0.2, 0.8)),
               platt(cal$prob_defective, y)(c(0.2, 0.8)))
  fitted_on_test_rows <- dplyr::filter(key(after), split == "test")
  expect_equal(fitted_on_test_rows$platt,
               platt(cal$prob_defective, y)(fitted_on_test_rows$prob_defective))
})

test_that("each model has 14 Holm-adjusted p-values and pans have no P2", {
  dir <- make_folder()
  calibrated <- read_fair_scores(dir) |> calibrate_all()
  for (m in c("jev", "clef")) {
    p <- paired_for_model(calibrated, m, all_datasets, times = 20)
    tests <- dplyr::distinct(p, comparison, dataset, mcnemar_p, holm_p, holm_family_size)
    expect_equal(nrow(tests), 14)
    expect_true(all(tests$holm_family_size == 14))
    expect_false(any(is.na(tests$holm_p)))
    expect_true(all(tests$holm_p >= tests$mcnemar_p - 1e-12))
    expect_false(any(p$comparison == "P2" & p$dataset == "pan_images"))
    expect_equal(sum(p$dataset == "pan_images"), 2 * 3)
    expect_setequal(p$metric, c("bal_accuracy", "mcc", "roc_auc"))
  }
})

test_that("a missing side removes its comparison and the family shrinks", {
  dir <- make_folder()
  file.remove(list.files(dir, pattern = "^jev_generic_k2_textiles", full.names = TRUE))
  calibrated <- read_fair_scores(dir) |> calibrate_all()
  p <- paired_for_model(calibrated, "jev", all_datasets, times = 20)
  expect_false(any(p$comparison == "P2" & p$dataset == "textiles"))
  expect_true(all(p$holm_family_size == 13))
})

test_that("P1 difference is the decision model minus CLIP", {
  strong <- \(model, description, k) if (model == "jev") 4 else 0
  dir <- make_folder(strong)
  calibrated <- read_fair_scores(dir) |> calibrate_all()
  p <- paired_for_model(calibrated, "jev", all_datasets, times = 20) |>
    dplyr::filter(comparison == "P1", metric == "roc_auc")
  expect_true(all(p$difference > 0))
  weak <- \(model, description, k) if (model == "jev") 0 else 4
  p2 <- make_folder(weak) |> read_fair_scores() |> calibrate_all() |>
    paired_for_model("jev", all_datasets, times = 20) |>
    dplyr::filter(comparison == "P1", metric == "roc_auc")
  expect_true(all(p2$difference < 0))
})

test_that("P3 compares k = 2 with k = 0 of the final description (pans generic)", {
  signal <- \(model, description, k) if (k == 2) 4 else 0
  p <- make_folder(signal) |> read_fair_scores() |> calibrate_all() |>
    paired_for_model("clef", all_datasets, times = 20) |>
    dplyr::filter(comparison == "P3", metric == "roc_auc")
  expect_equal(nrow(p), 5)
  expect_true(all(p$difference > 0))
})

test_that("different test images stop the comparison with a message", {
  dir <- make_folder()
  d <- readr::read_csv(file.path(dir, "clip_baseline_k50_extrusion_test.csv"),
                       show_col_types = FALSE) |>
    dplyr::mutate(image_path = paste0("other/", image_path))
  readr::write_csv(d, file.path(dir, "clip_baseline_k50_extrusion_test.csv"))
  calibrated <- read_fair_scores(dir) |> calibrate_all()
  expect_error(paired_for_model(calibrated, "jev", all_datasets, times = 20),
               "do not hold the same images")
})

test_that("the k-curve has k 0, 1, 2, 4 and CLIP zero as k 0", {
  calibrated <- read_fair_scores(make_folder()) |> calibrate_all()
  curve <- k_curve_table(calibrated, all_datasets, times = 20)
  expect_setequal(curve$model, c("jev", "clef", "clip"))
  expect_setequal(curve$k, c(0, 1, 2, 4))
  expect_true(all(is.na(curve$difference_vs_k0[curve$k == 0])))
  expect_false(any(is.na(curve$difference_vs_k0[curve$k > 0])))
  expect_equal(nrow(dplyr::filter(curve, model == "clip", dataset == "extrusion",
                                  metric == "mcc")), 4)
})

test_that("the script writes the three summaries", {
  dir <- make_folder()
  out <- withr::local_tempdir()
  run_fair_evaluation(dir, out, times = 20)
  expect_setequal(list.files(out), c("metrics.csv", "paired.csv", "k_curve.csv"))
  expect_named(readr::read_csv(file.path(out, "metrics.csv"), show_col_types = FALSE),
               c("model", "description", "k", "dataset", "split", "calibration",
                 "in_sample", "metric", "value"))
  expect_named(readr::read_csv(file.path(out, "paired.csv"), show_col_types = FALSE),
               c("comparison", "model", "dataset", "metric", "difference", "low",
                 "high", "mcnemar_p", "holm_p", "holm_family_size"))
})

test_that("CLIP-only folders give metrics and a CLIP curve but no paired rows", {
  dir <- withr::local_tempdir()
  write_scores(dir, "clip", "baseline", 50, "extrusion", "calibration", 1)
  write_scores(dir, "clip", "baseline", 50, "extrusion", "test", 1)
  out <- withr::local_tempdir()
  res <- run_fair_evaluation(dir, out, times = 20)
  expect_equal(nrow(res$paired), 0)
  expect_gt(nrow(res$metrics), 0)
})
