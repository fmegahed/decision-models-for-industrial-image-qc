# Evaluation of the fair comparison (no API calls). Needs R/evaluation.R and
# R/calibration_functions.R. Source from the project root.

headline <- c("bal_accuracy", "mcc", "roc_auc")
config_keys <- c("model", "description", "k", "dataset")

#' Read every score file of a folder into one tibble
#' @details Only files that end in _calibration.csv or _test.csv count. A file
#'   may or may not have the column elapsed_ms (CLIP files have none).
read_fair_scores <- function(dir) {
  list.files(dir, pattern = "_(calibration|test)\\.csv$", full.names = TRUE) |>
    purrr::map(readr::read_csv, show_col_types = FALSE) |>
    purrr::list_rbind()
}

#' Add Platt and isotonic probabilities to the scores of each configuration
#' @details Both calibrators are fitted on the calibration rows of the same
#'   configuration only. A configuration without test rows, or with one class
#'   in its calibration rows, is dropped, and a message names it. Test rows
#'   never enter a fit.
calibrate_all <- function(scores) {
  # The configurations that cannot be calibrated.
  dropped <- scores |>
    dplyr::summarise(
      has_test = any(split == "test"),
      n_classes = dplyr::n_distinct(actual_class[split == "calibration"]),
      .by = dplyr::all_of(config_keys)
    ) |>
    dplyr::filter(!has_test | n_classes < 2) |>
    dplyr::mutate(
      label = paste(model, description, paste0("k", k), dataset),
      reason = dplyr::if_else(has_test, "one calibration class", "no test rows")
    )
  if (nrow(dropped) > 0) {
    message("calibrate_all drops ", nrow(dropped), " configuration(s): ",
            paste0(dropped$label, " (", dropped$reason, ")", collapse = "; "))
  }
  scores |>
    dplyr::group_by(dplyr::across(dplyr::all_of(config_keys))) |>
    dplyr::group_modify(\(d, key) {
      cal <- dplyr::filter(d, split == "calibration")
      y <- as.integer(cal$actual_class == "defective")
      if (!any(d$split == "test") || length(unique(y)) < 2) return(d[0, ])
      dplyr::mutate(d,
        raw = prob_defective,
        platt = platt(cal$prob_defective, y)(prob_defective),
        isotonic = isotonic(cal$prob_defective, y)(prob_defective)
      )
    }) |>
    dplyr::ungroup()
}

#' Long metrics table: raw, Platt and isotonic, on both splits
#' @details Platt and isotonic rows of the calibration split are in sample.
metrics_table <- function(calibrated) {
  calibrated |>
    tidyr::pivot_longer(c(raw, platt, isotonic), names_to = "calibration",
                        values_to = "prob") |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(config_keys, "split",
                                                  "calibration")))) |>
    dplyr::group_modify(\(d, key) {
      class_metrics(dplyr::mutate(d, prob_defective = prob))
    }) |>
    dplyr::ungroup() |>
    dplyr::mutate(in_sample = split == "calibration" & calibration != "raw") |>
    tidyr::pivot_longer(accuracy:ece, names_to = "metric", values_to = "value") |>
    dplyr::select(model, description, k, dataset, split, calibration,
                  in_sample, metric, value)
}

# Platt-calibrated test predictions of one configuration (NA k: any k).
test_side <- function(calibrated, model, description, k = NA, dataset) {
  out <- calibrated |>
    dplyr::filter(split == "test", .data$model == .env$model,
                  .data$description == .env$description,
                  .data$dataset == .env$dataset)
  if (!is.na(k)) out <- dplyr::filter(out, .data$k == .env$k)
  dplyr::transmute(out, image_path, actual_class, prob_defective = platt)
}

# Both sides on the same images, in the same order.
align_sides <- function(a, b, label = "") {
  if (!setequal(a$image_path, b$image_path)) {
    stop("The two test files do not hold the same images: ", label, call. = FALSE)
  }
  b <- dplyr::arrange(b, match(image_path, a$image_path))
  stopifnot(identical(a$actual_class, b$actual_class))
  list(a = a, b = b)
}

#' Pre-specified comparisons P1 to P3 of one model on every dataset
comparison_plan <- function(model, datasets) {
  tidyr::expand_grid(dataset = datasets, comparison = c("P1", "P2", "P3")) |>
    dplyr::mutate(
      final = dplyr::if_else(dataset == "pan_images", "generic", "final"),
      b_model = dplyr::if_else(comparison == "P1", "clip", model),
      b_desc = dplyr::case_when(comparison == "P1" ~ "baseline",
                                comparison == "P2" ~ "generic", .default = final),
      b_k = dplyr::case_when(comparison == "P1" ~ NA_real_,
                             comparison == "P2" ~ 2, .default = 0)
    ) |>
    dplyr::filter(!(comparison == "P2" & dataset == "pan_images"))
}

#' Paired comparisons of one model (difference = decision model minus other)
#' @details A comparison runs only when both sides exist. Holm adjusts the
#'   McNemar p-values of the tests that ran; `holm_family_size` counts them.
paired_for_model <- function(calibrated, model, datasets, times = 2000) {
  right <- \(d) (d$prob_defective >= 0.5) == (d$actual_class == "defective")
  rows <- purrr::pmap(comparison_plan(model, datasets),
    \(dataset, comparison, final, b_model, b_desc, b_k) {
      a <- test_side(calibrated, model, final, 2, dataset)
      b <- test_side(calibrated, b_model, b_desc, b_k, dataset)
      if (nrow(a) == 0 || nrow(b) == 0) return(NULL)
      s <- align_sides(a, b, paste(model, comparison, dataset))
      p <- mcnemar_exact(right(s$a), right(s$b))
      purrr::map(headline, \(m) {
        dplyr::bind_cols(
          tibble::tibble(comparison = comparison, model = model,
                         dataset = dataset, metric = m),
          paired_bootstrap(s$a, s$b, m, times = times),
          tibble::tibble(mcnemar_p = p)
        )
      }) |> purrr::list_rbind()
    }) |> purrr::list_rbind()
  if (nrow(rows) == 0) return(rows)
  tests <- dplyr::distinct(rows, comparison, dataset, mcnemar_p) |>
    dplyr::mutate(holm_p = stats::p.adjust(mcnemar_p, "holm"),
                  holm_family_size = dplyr::n())
  dplyr::left_join(rows, tests, by = c("comparison", "dataset", "mcnemar_p"))
}

#' k-curve of one model on one dataset, with differences against k = 0
#' @details Decision models use the final description (pans: generic). CLIP
#'   uses the same-reference variant at k 1, 2, 4 and zero-shot as k 0.
curve_for <- function(calibrated, model, dataset, times = 2000) {
  desc <- dplyr::if_else(dataset == "pan_images", "generic", "final")
  spec <- tibble::tibble(k = c(0, 1, 2, 4)) |>
    dplyr::mutate(description = dplyr::case_when(
      model != "clip" ~ desc, k == 0 ~ "zero", .default = "refs"))
  sides <- purrr::map2(spec$description, spec$k, \(d, k) {
    test_side(calibrated, model, d, if (model == "clip" && k == 0) NA else k,
              dataset)
  })
  base <- sides[[1]]
  if (nrow(base) == 0) return(NULL)
  purrr::map(seq_len(nrow(spec)), \(i) {
    if (nrow(sides[[i]]) == 0) return(NULL)
    s <- align_sides(sides[[i]], base, paste(model, dataset, "k", spec$k[i]))
    purrr::map(headline, \(m) {
      diff <- tibble::tibble(difference_vs_k0 = NA_real_, low = NA_real_,
                             high = NA_real_)
      if (spec$k[i] > 0) {
        diff <- paired_bootstrap(s$a, s$b, m, times = times) |>
          dplyr::rename(difference_vs_k0 = difference)
      }
      dplyr::bind_cols(
        tibble::tibble(model = model, dataset = dataset, k = spec$k[i],
                       metric = m,
                       value = dplyr::pull(class_metrics(s$a), dplyr::all_of(m))),
        diff)
    }) |> purrr::list_rbind()
  }) |> purrr::list_rbind()
}

k_curve_table <- function(calibrated, datasets, times = 2000) {
  tidyr::expand_grid(model = c("jev", "clef", "clip"), dataset = datasets) |>
    purrr::pmap(\(model, dataset) curve_for(calibrated, model, dataset, times)) |>
    purrr::list_rbind()
}

#' Time per image, total time and JEV cost of each configuration
#' @details Time per image comes from elapsed_ms (decision models) or from
#'   encode_ms + score_ms in clip_timing.csv (CLIP, test split). The total
#'   time comes from runs.csv. The calls, tokens and cost of JEV come from the
#'   TypeSafe call log, grouped by the configuration in the purpose
#'   ("fair <split> <model> <description> k<k> <dataset>"). A column that does
#'   not apply is NA. Missing timing files give NA, not an error.
timing_table <- function(scores, timing_dir, record_root) {
  keys <- c(config_keys, "split")
  read_if <- \(file, ...) {
    if (file.exists(file)) readr::read_csv(file, show_col_types = FALSE, ...) else NULL
  }
  if (!"elapsed_ms" %in% names(scores)) scores$elapsed_ms <- NA_real_
  clip <- read_if(file.path(timing_dir, "clip_timing.csv"))
  if (is.null(clip)) {
    clip <- tibble::tibble(variant = character(), k = double(), dataset = character(),
                           encode_ms = double(), score_ms = double())
  }
  per_image <- clip |>
    dplyr::transmute(model = "clip", description = variant, k, dataset, split = "test",
                     elapsed_ms = encode_ms + score_ms) |>
    dplyr::bind_rows(dplyr::select(scores, dplyr::all_of(c(keys, "elapsed_ms")))) |>
    dplyr::filter(!is.na(elapsed_ms)) |>
    dplyr::summarise(
      n_images = dplyr::n(),
      median_ms = stats::median(elapsed_ms),
      q25_ms = stats::quantile(elapsed_ms, 0.25, names = FALSE),
      q75_ms = stats::quantile(elapsed_ms, 0.75, names = FALSE),
      .by = dplyr::all_of(keys)
    )

  runs <- read_if(file.path(timing_dir, "runs.csv"),
                  col_types = readr::cols(.default = "c", k = "d", n_images = "d", seconds = "d"))
  if (is.null(runs)) {
    runs <- tibble::tibble(model = character(), description = character(), k = double(),
                           dataset = character(), split = character(),
                           n_images = double(), seconds = double())
  }
  totals <- runs |>
    dplyr::summarise(runs_images = sum(n_images), total_seconds = sum(seconds),
                     .by = dplyr::all_of(keys))

  calls <- read_if(file.path(record_root, "calls", "typesafe-calls.csv"),
                   col_types = readr::cols(.default = "c"))
  jev_cost <- tibble::tibble(model = character(), description = character(), k = double(),
                             dataset = character(), split = character(), n_calls = integer(),
                             input_tokens = double(), output_tokens = double(),
                             cost_usd = double())
  if (!is.null(calls)) {
    pattern <- "^fair (\\S+) jev (\\S+) k(\\d+) (\\S+)$"
    parsed <- calls |>
      dplyr::filter(model == "jev-1.13.0", stringr::str_detect(.data$purpose, .env$pattern)) |>
      dplyr::mutate(
        parts = stringr::str_match(.data$purpose, .env$pattern),
        model = "jev", split = parts[, 2], description = parts[, 3],
        k = as.numeric(parts[, 4]), dataset = parts[, 5]
      )
    jev_cost <- parsed |>
      dplyr::summarise(
        n_calls = dplyr::n(),
        input_tokens = sum(as.numeric(input_tokens), na.rm = TRUE),
        output_tokens = sum(as.numeric(output_tokens), na.rm = TRUE),
        cost_usd = sum(as.numeric(cost_usd), na.rm = TRUE),
        .by = dplyr::all_of(keys)
      )
  }

  per_image |>
    dplyr::full_join(totals, by = keys) |>
    dplyr::left_join(jev_cost, by = keys) |>
    dplyr::mutate(n_images = dplyr::coalesce(n_images, runs_images)) |>
    dplyr::select(dplyr::all_of(keys), n_images, median_ms, q25_ms, q75_ms,
                  total_seconds, n_calls, input_tokens, output_tokens, cost_usd) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(keys)))
}

#' Run the whole evaluation and write the summaries
run_fair_evaluation <- function(scores_dir, out_dir, times = 2000,
                                timing_dir = "results/fair/timing",
                                record_root = Sys.getenv("FAIR_RECORD_ROOT",
                                                         unset = "replication_materials")) {
  scores <- read_fair_scores(scores_dir)
  calibrated <- calibrate_all(scores)
  datasets <- sort(unique(calibrated$dataset))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  paired <- purrr::map(c("jev", "clef"), \(m) {
    paired_for_model(calibrated, m, datasets, times)
  }) |> purrr::list_rbind()
  if (nrow(paired) == 0) {
    paired <- tibble::tibble(
      comparison = character(), model = character(), dataset = character(),
      metric = character(), difference = double(), low = double(),
      high = double(), mcnemar_p = double(), holm_p = double(),
      holm_family_size = integer())
  }
  out <- list(metrics = metrics_table(calibrated), paired = paired,
              k_curve = k_curve_table(calibrated, datasets, times),
              timing = timing_table(scores, timing_dir, record_root))
  purrr::iwalk(out, \(d, name) {
    readr::write_csv(d, file.path(out_dir, paste0(name, ".csv")))
  })
  invisible(out)
}
