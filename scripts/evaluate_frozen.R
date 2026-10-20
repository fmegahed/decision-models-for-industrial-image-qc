# Final, one-time evaluation of a frozen configuration on the TEST images.
# Run from the project root only after the user approves the test run.
# Settings come from results/optimization/frozen_configs.csv, never from
# environment variables, so the test run cannot drift from the frozen choice.
#
# JEV_DATASET=microstructure Rscript scripts/evaluate_frozen.R
# JEV_DATASET=microstructure JEV_CHECK_ONLY=true Rscript scripts/evaluate_frozen.R  # checks only, no API calls
# JEV_DATASET=microstructure JEV_CONDITION=zero_shot Rscript scripts/evaluate_frozen.R  # ablation: no references

source("R/industrial_defect_classifier.R")

dataset <- Sys.getenv("JEV_DATASET")
condition <- Sys.getenv("JEV_CONDITION", unset = "references")
check_only <- identical(tolower(Sys.getenv("JEV_CHECK_ONLY")), "true")
if (!nzchar(Sys.getenv("TYPESAFE_API_KEY"))) stop("Set TYPESAFE_API_KEY")

frozen <- readr::read_csv("results/optimization/frozen_configs.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$dataset == .env$dataset, .data$condition == .env$condition)
if (nrow(frozen) != 1L) stop("Need exactly one frozen configuration for ", dataset, ", ", condition)
# The dataset whose validation trials chose this configuration. It differs only
# for a transfer test (textiles_real uses the textiles configuration unchanged).
tuned_on <- frozen$tuned_on

# ---- The frozen row must match what its source trial recorded ------------
source_score <- file.path("results", "optimization", tuned_on,
                          paste0(frozen$source_trial, "_score.csv")) |>
  readr::read_csv(show_col_types = FALSE)
as_text <- function(x) if (is.null(x) || is.na(x)) "" else as.character(x)
fields <- c("use_references", "criteria_file", "reference_file", "crop", "max_size",
            "upscale", "model", "base_url", "image_format", "threshold")
differs <- fields[vapply(fields, function(f) {
  as_text(frozen[[f]]) != as_text(source_score[[f]]) # a missing column counts as empty
}, logical(1))]

typesafe_url <- "https://api.typesafe.ai/v1/systemone"
base_url <- if (nzchar(as_text(frozen$base_url))) frozen$base_url else typesafe_url
# Never send the TypeSafe key to another service, even a local one.
api_key <- if (base_url == typesafe_url) Sys.getenv("TYPESAFE_API_KEY") else "local"
image_format <- if (nzchar(as_text(frozen$image_format))) frozen$image_format else "assets"
if (length(differs)) stop("Frozen configuration differs from its source trial: ", toString(differs))

# ---- Test images, references and criteria ---------------------------------
test <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$dataset == .env$dataset, .data$split == "test")
stopifnot(nrow(test) > 0L, all(file.exists(test$image_path)))
refs <- tibble::tibble(image_path = character(), reference_class = character())
references <- NULL
if (frozen$use_references) {
  refs <- readr::read_csv(frozen$reference_file, show_col_types = FALSE) |>
    dplyr::filter(.data$dataset == .env$tuned_on)
  stopifnot(all(file.exists(refs$image_path)))
  # Check by path AND by content: the pan copies had different paths.
  if (any(refs$image_path %in% test$image_path) ||
      any(tools::md5sum(refs$image_path) %in% tools::md5sum(test$image_path))) {
    stop("A reference image is also a test image")
  }
  references <- split(refs$image_path, refs$reference_class)
}

criteria <- NULL
if (nzchar(as_text(frozen$criteria_file))) {
  descriptions <- readr::read_csv(frozen$criteria_file, show_col_types = FALSE)
  criteria <- list(normal = descriptions$normal[[1]], defective = descriptions$defective[[1]])
}

output_dir <- file.path("results", "final_test")
# The main condition keeps its original file names; others add a suffix.
stem <- if (condition == "references") dataset else paste0(dataset, "_", condition)
result_file <- file.path(output_dir, paste0(stem, "_predictions.csv"))
score_file <- file.path(output_dir, paste0(stem, "_score.csv"))
if (file.exists(result_file) || file.exists(score_file)) {
  stop("Test results already exist for ", stem, ". The test run is one-time.")
}

cat(dataset, condition, ": frozen", frozen$source_trial, "| test images", nrow(test),
    "| references", nrow(refs), "| checks passed\n")
if (check_only) quit(save = "no")

# ---- One pass over the test images ----------------------------------------
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
predictions <- purrr::map_dfr(seq_len(nrow(test)), function(i) {
  item <- test[i, ]
  answer <- classify_image(
    image_path = item$image_path, mode = "binary",
    reference_images = references, criteria = criteria,
    crop = frozen$crop, max_size = frozen$max_size,
    upscale = frozen$upscale, model = frozen$model,
    base_url = base_url, api_key = api_key, image_format = image_format
  )
  probability <- answer$probability[answer$class == "defective"]
  if (length(probability) != 1L || !is.finite(probability)) stop("Invalid defect probability")
  tibble::tibble(
    dataset = dataset, image_path = item$image_path,
    defect_type = item$defect_type, actual_class = item$actual_class,
    prob_defective = probability
  )
}) |>
  dplyr::mutate(predicted_class = dplyr::if_else(
    .data$prob_defective >= frozen$threshold, "defective", "nominal"
  ))

scores <- predictions |>
  dplyr::mutate(
    actual_class = factor(.data$actual_class, levels = c("defective", "nominal")),
    predicted_class = factor(.data$predicted_class, levels = c("defective", "nominal"))
  )
summary <- frozen |>
  dplyr::mutate(
    split = "test", n_images = nrow(predictions),
    balanced_accuracy = yardstick::bal_accuracy(scores, truth = actual_class, estimate = predicted_class)$.estimate,
    sensitivity = yardstick::sens(scores, truth = actual_class, estimate = predicted_class)$.estimate,
    specificity = yardstick::spec(scores, truth = actual_class, estimate = predicted_class)$.estimate,
    roc_auc = yardstick::roc_auc(scores, truth = actual_class, prob_defective, event_level = "first")$.estimate
  )

readr::write_csv(predictions, result_file)
readr::write_csv(summary, score_file)
print(summary)
