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
  run_fair_evaluation(dir, out, times = 20, timing_dir = withr::local_tempdir(),
                      record_root = withr::local_tempdir())
  expect_setequal(list.files(out), c("metrics.csv", "paired.csv", "k_curve.csv", "timing.csv"))
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
  res <- run_fair_evaluation(dir, out, times = 20, timing_dir = withr::local_tempdir(),
                             record_root = withr::local_tempdir())
  expect_equal(nrow(res$paired), 0)
  expect_gt(nrow(res$metrics), 0)
})

test_that("read_fair_scores reads only calibration and test score files", {
  dir <- withr::local_tempdir()
  write_scores(dir, "clip", "zero", 0, "extrusion", "test", 1)
  write_scores(dir, "clip", "zero", 0, "extrusion", "calibration", 1)
  writeLines(c("a,b", "1,2"), file.path(dir, "clip_truncation.csv"))
  writeLines(c("a,b", "1,2"), file.path(dir, "notes.csv"))
  scores <- read_fair_scores(dir)
  expect_false("a" %in% names(scores))
  expect_equal(nrow(scores), 24)
})

test_that("calibrate_all names every configuration that it drops", {
  dir <- withr::local_tempdir()
  write_scores(dir, "clip", "zero", 0, "extrusion", "test", 1)
  write_scores(dir, "clip", "zero", 0, "extrusion", "calibration", 1)
  write_scores(dir, "clip", "refs", 1, "extrusion", "calibration", 1) # no test rows
  write_scores(dir, "clip", "refs", 2, "extrusion", "test", 1)
  write_scores(dir, "clip", "refs", 2, "extrusion", "calibration", 1)
  scores <- read_fair_scores(dir)
  # one class in the calibration rows of k = 2
  scores$actual_class[scores$k == 2 & scores$split == "calibration"] <- "defective"
  expect_message(calibrated <- calibrate_all(scores), "clip refs k1 extrusion")
  expect_message(calibrate_all(scores), "clip refs k2 extrusion")
  expect_equal(unique(calibrated$k), 0)
})

# A timing folder, a call log and score files with and without elapsed_ms.
make_timing <- function() {
  scores <- withr::local_tempdir(.local_envir = parent.frame())
  timing <- withr::local_tempdir(.local_envir = parent.frame())
  record <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(record, "calls"))
  write_scores(scores, "clip", "zero", 0, "extrusion", "test", 1, n = 4)
  write_scores(scores, "jev", "final", 2, "extrusion", "test", 1, n = 4)
  write_scores(scores, "clip", "zero", 0, "extrusion", "calibration", 1, n = 4)
  write_scores(scores, "jev", "final", 2, "extrusion", "calibration", 1, n = 4)
  f <- file.path(scores, "jev_final_k2_extrusion_test.csv")
  readr::read_csv(f, show_col_types = FALSE) |>
    dplyr::mutate(elapsed_ms = c(1000, 2000, 3000, 4000)) |>
    readr::write_csv(f)
  tibble::tibble(variant = "zero", k = 0, dataset = "extrusion",
                 image_path = paste0("e/", 1:4), encode_ms = c(10, 20, 30, 40),
                 score_ms = c(1, 1, 1, 1)) |>
    readr::write_csv(file.path(timing, "clip_timing.csv"))
  tibble::tibble(
    model = c("jev", "clip"), description = c("final", "zero"), k = c(2, 0),
    dataset = "extrusion", split = "test", candidate = NA_real_, n_images = 4,
    start_utc = "2026-10-21T10:00:00Z", end_utc = "2026-10-21T10:00:10Z",
    seconds = c(10, 2), hardware = c("TypeSafe API", "NVIDIA X")) |>
    readr::write_csv(file.path(timing, "runs.csv"))
  tibble::tibble(
    purpose = c(rep("fair test jev final k2 extrusion", 4), "fair test clef final k2 extrusion"),
    model = c(rep("jev-1.13.0", 4), "Cloudflare/clef-flash"),
    input_tokens = c(100, 200, 300, 400, 999), output_tokens = 10,
    cost_usd = c(100, 200, 300, 400, NA) * 0.042 / 1e6) |>
    readr::write_csv(file.path(record, "calls", "typesafe-calls.csv"))
  list(scores = scores, timing = timing, record = record)
}

test_that("timing_table reads files with and without elapsed_ms", {
  f <- make_timing()
  tab <- timing_table(read_fair_scores(f$scores), f$timing, f$record)
  jev <- dplyr::filter(tab, model == "jev")
  expect_equal(jev$median_ms, 2500)
  expect_equal(jev$q25_ms, stats::quantile(c(1000, 2000, 3000, 4000), 0.25, names = FALSE))
  expect_equal(jev$total_seconds, 10)
  expect_equal(jev$n_calls, 4)
  expect_equal(jev$input_tokens, 1000)
  expect_equal(jev$output_tokens, 40)
  expect_equal(jev$cost_usd, 1000 * 0.042 / 1e6)
  clip <- dplyr::filter(tab, model == "clip")
  expect_equal(clip$median_ms, 26) # encode + score: 11, 21, 31, 41
  expect_equal(clip$total_seconds, 2)
  expect_true(is.na(clip$n_calls))
  expect_named(tab, c("model", "description", "k", "dataset", "split", "n_images",
                      "median_ms", "q25_ms", "q75_ms", "total_seconds", "n_calls",
                      "input_tokens", "output_tokens", "cost_usd"))
})

test_that("the evaluation writes timing.csv and works without timing files", {
  f <- make_timing()
  out <- withr::local_tempdir()
  run_fair_evaluation(f$scores, out, times = 20, timing_dir = f$timing, record_root = f$record)
  expect_true(file.exists(file.path(out, "timing.csv")))
  none <- withr::local_tempdir()
  out2 <- withr::local_tempdir()
  run_fair_evaluation(f$scores, out2, times = 20, timing_dir = none, record_root = none)
  tab <- readr::read_csv(file.path(out2, "timing.csv"), show_col_types = FALSE)
  expect_true(all(is.na(tab$total_seconds)))
})
