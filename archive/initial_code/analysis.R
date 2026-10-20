# Industrial image classification: zero-shot vs. labeled references
# Run from the project root (the folder containing pan_images/).
# Install once: install.packages(c("httr2", "magick", "base64enc", "tibble",
#   "purrr", "dplyr", "tidyr", "yardstick", "readr", "ggplot2"))

source("industrial_defect_classifier.R")

# * Settings --------------------------------------------------------------
train_dir <- "imgs/pan_images/train"
test_dir <- "imgs/pan_images/test"
n_per_class <- 2L  # Increase to 3, 5, or 10 for nested reference sets
seed <- 20261020
crop <- "center"
max_size <- 1568L

# * Test images and ground truth ------------------------------------------
image_paths <- list.files(
  test_dir, pattern = "\\.(jpg|jpeg|png)$",
  recursive = TRUE, full.names = TRUE, ignore.case = TRUE
)
image_paths <- image_paths[
  basename(dirname(image_paths)) %in% c("nominal", "defective")
]
if (length(image_paths) == 0L) stop("No test images found.")

test_data <- tibble::tibble(
  image_name = basename(image_paths),
  image_path = normalizePath(image_paths, winslash = "/", mustWork = TRUE),
  actual_class = basename(dirname(image_paths))
)

# * Training reference images ---------------------------------------------
references <- select_reference_images(
  train_dir = train_dir, n_per_class = n_per_class, seed = seed
)
print(references)

# * Classify the same test images two ways --------------------------------
# API calls are made once per image per method.
# For a quick check, first use: test_data <- dplyr::slice_head(test_data, n = 5)

results <- purrr::map2_dfr(
  test_data$image_path, test_data$actual_class,
  function(image_path, actual_class) {
    classify_image(
      image_path = image_path, mode = "binary",
      crop = crop, max_size = max_size
    ) |>
      dplyr::mutate(image_path = image_path,
                    actual_class = actual_class, .before = 1)
  }
)

results_reference <- purrr::map2_dfr(
  test_data$image_path, test_data$actual_class,
  function(image_path, actual_class) {
    classify_image(
      image_path = image_path, mode = "binary",
      reference_images = references,
      crop = crop, max_size = max_size
    ) |>
      dplyr::mutate(image_path = image_path,
                    actual_class = actual_class, .before = 1)
  }
)

# * Convert to one row per image ------------------------------------------
# Explicit id_cols avoids treating `predicted` as a row identifier.
as_wide <- function(data) {
  data |>
    dplyr::select(image_path, actual_class, class, probability) |>
    tidyr::pivot_wider(
      id_cols = c(image_path, actual_class),
      names_from = class, values_from = probability,
      names_prefix = "prob_"
    ) |>
    dplyr::rename(prob_nominal = prob_normal) |>
    dplyr::mutate(
      predicted_class = dplyr::if_else(
        prob_defective >= prob_nominal, "defective", "nominal"
      ),
      correct = predicted_class == actual_class
    ) |>
    dplyr::relocate(
      image_path, actual_class, predicted_class, correct,
      prob_nominal, prob_defective
    )
}

results_wide <- as_wide(results)
results_wide_reference <- as_wide(results_reference)

# * Yardstick evaluation --------------------------------------------------
evaluate <- function(data, method) {
  data <- data |>
    dplyr::mutate(
      actual_class = factor(actual_class, levels = c("defective", "nominal")),
      predicted_class = factor(predicted_class,  levels = c("defective", "nominal"))
    )
  
  class_metrics <- yardstick::metric_set(
    yardstick::accuracy, yardstick::bal_accuracy,
    yardstick::sens, yardstick::spec, yardstick::precision,
    yardstick::f_meas, yardstick::mcc, yardstick::kap
  )(
    data, truth = actual_class, estimate = predicted_class,
    event_level = "first"
  )
  
  probability_metrics <- yardstick::metric_set(
    yardstick::roc_auc, yardstick::pr_auc
  )(
    data, truth = actual_class, prob_defective,
    event_level = "first"
  )
  
  dplyr::bind_rows(class_metrics, probability_metrics) |>
    dplyr::mutate(method = method, .before = 1)
}

metrics <- dplyr::bind_rows(
  evaluate(results_wide, "Zero-shot"),
  evaluate(results_wide_reference, "Reference-guided")
)
metrics_wide <- metrics |>
  dplyr::select(method, .metric, .estimate) |>
  tidyr::pivot_wider(names_from = method, values_from = .estimate)
print(metrics_wide)

# False acceptance = defective classified nominal.
# False rejection = nominal classified defective.
error_rates <- dplyr::bind_rows(
  dplyr::mutate(results_wide, method = "Zero-shot"),
  dplyr::mutate(results_wide_reference, method = "Reference-guided")
) |>
  dplyr::group_by(method) |>
  dplyr::summarise(
    false_acceptance_rate = sum(actual_class == "defective" &
                                  predicted_class == "nominal") /
      sum(actual_class == "defective"),
    false_rejection_rate = sum(actual_class == "nominal" &
                                 predicted_class == "defective") /
      sum(actual_class == "nominal"),
    .groups = "drop"
  )
print(error_rates)

# * Compare decisions on the same images ---------------------------------
paired_results <- results_wide |>
  dplyr::select(image_path, actual_class,
                zero_prediction = predicted_class,
                zero_correct = correct,
                zero_prob_defective = prob_defective) |>
  dplyr::inner_join(
    results_wide_reference |>
      dplyr::select(image_path,
                    reference_prediction = predicted_class,
                    reference_correct = correct,
                    reference_prob_defective = prob_defective),
    by = "image_path"
  ) |>
  dplyr::mutate(
    # Was the zero-shot prediction incorrect but the reference-guided prediction correct?
    improved = !zero_correct & reference_correct,
    worsened = zero_correct & !reference_correct
  )

# * Save results ----------------------------------------------------------
dir.create("pan_images/results", recursive = TRUE, showWarnings = FALSE)
readr::write_csv(results_wide, "pan_images/results/zero_shot.csv")
readr::write_csv(
  results_wide_reference,
  sprintf("pan_images/results/references_seed%s_n%s.csv", seed, n_per_class)
)
readr::write_csv(metrics_wide, "pan_images/results/metrics_comparison.csv")
readr::write_csv(error_rates, "pan_images/results/error_rates.csv")
readr::write_csv(paired_results, "pan_images/results/paired_results.csv")
