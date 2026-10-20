# JEV validation runner for Claude Code / loop engineering.
# Run from the imagejev project root. This script never uses test images.
# Requires industrial_defect_classifier.R and results/image_split_manifest.csv.

source("R/industrial_defect_classifier.R")

# ---- Trial settings (set with environment variables) ---------------------
setting <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else as.character(default)
}

dataset <- setting("JEV_DATASET", "microstructure")
trial_id <- setting("JEV_TRIAL", "baseline")
Sys.setenv(JEV_CALL_PURPOSE = paste(dataset, trial_id)) # for the call log (JEV_CALL_LOG)
seed <- 202610L
n_validation <- as.integer(setting("JEV_N_VALIDATION", 20)) # per binary class
crop <- setting("JEV_CROP", "center")
max_size <- as.integer(setting("JEV_MAX_SIZE", 768))
upscale <- identical(tolower(setting("JEV_UPSCALE", "false")), "true")
model <- setting("JEV_MODEL", "jev-1.13.0") # pinned: jev-latest can move
typesafe_url <- "https://api.typesafe.ai/v1/systemone"
base_url <- setting("JEV_BASE_URL", typesafe_url) # a self-hosted SystemOne model, e.g. Clef-Flash
# Never send the TypeSafe key to another service, even a local one.
api_key <- if (base_url == typesafe_url) Sys.getenv("TYPESAFE_API_KEY") else "local"
image_format <- setting("JEV_IMAGE_FORMAT", "assets") # "images" for SGLang servers such as Clef-Flash
threshold <- as.numeric(setting("JEV_THRESHOLD", 0.5))
use_references <- identical(tolower(setting("JEV_USE_REFERENCES", "true")), "true")
criteria_file <- setting("JEV_CRITERIA_FILE", "")
reference_file <- setting("JEV_REFERENCE_FILE", file.path(
  "results", sprintf("reference_manifest_seed%s_by_dataset.csv", seed)
))
results_root <- Sys.getenv("JEV_RESULTS_ROOT", unset = "results") # outputs only; inputs stay in results/
output_dir <- file.path(results_root, "optimization", dataset)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

if (!grepl("^[A-Za-z0-9_-]+$", trial_id)) stop("Invalid trial ID")
if (!nzchar(Sys.getenv("TYPESAFE_API_KEY"))) stop("Set TYPESAFE_API_KEY")
if (!is.finite(threshold) || threshold < 0 || threshold > 1) stop("Invalid threshold")
if (is.na(n_validation) || n_validation < 1L) stop("Invalid validation count")
if (!crop %in% c("center", "none")) stop("Invalid crop")
if (is.na(max_size) || max_size < 280 || max_size > 1568) stop("Invalid max_size")

# ---- Fixed validation images ---------------------------------------------
# The first run selects validation images from the non-test pool. All later
# trials reuse precisely these images. Never tune on the test partition.
splits <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE)
if (!dataset %in% unique(splits$dataset)) stop("Unknown dataset: ", dataset)
validation_file <- file.path(output_dir, "validation_images.csv")
# A re-run in another results root uses the frozen validation set, never a new one.
frozen_validation <- file.path("results", "optimization", dataset, "validation_images.csv")
if (results_root != "results" && !file.exists(validation_file) && file.exists(frozen_validation)) {
  file.copy(frozen_validation, validation_file)
}

if (file.exists(validation_file)) {
  validation <- readr::read_csv(validation_file, show_col_types = FALSE)
} else {
  pool <- splits |>
    dplyr::filter(.data$dataset == .env$dataset, .data$split != "test") |>
    dplyr::arrange(.data$image_path)
  if (file.exists(reference_file)) {
    initial_refs <- readr::read_csv(reference_file, show_col_types = FALSE) |>
      dplyr::filter(.data$dataset == .env$dataset)
    pool <- dplyr::filter(pool, !.data$image_path %in% initial_refs$image_path)
  }
  set.seed(seed)
  validation <- pool |>
    dplyr::group_by(.data$actual_class) |>
    dplyr::group_modify(~ .x[sample.int(nrow(.x), min(n_validation, nrow(.x))), , drop = FALSE]) |>
    dplyr::ungroup()
  if (!setequal(validation$actual_class, c("defective", "nominal"))) {
    stop("Validation pool must contain both classes")
  }
  readr::write_csv(validation, validation_file)
}

stopifnot(!any(validation$image_path %in% splits$image_path[splits$split == "test"]))
stopifnot(all(file.exists(validation$image_path)))

# ---- Candidate: references and defect descriptions -----------------------
references <- NULL
if (use_references) {
  refs <- readr::read_csv(reference_file, show_col_types = FALSE) |>
    dplyr::filter(.data$dataset == .env$dataset)
  if (!setequal(refs$reference_class, c("normal", "defective"))) {
    stop("Reference manifest must contain normal and defective examples")
  }
  if (any(refs$image_path %in% validation$image_path) ||
      any(refs$image_path %in% splits$image_path[splits$split == "test"])) {
    stop("Reference leakage into validation or test data")
  }
  if (!all(refs$image_path %in% splits$image_path[splits$dataset == dataset & splits$split != "test"])) {
    stop("Reference paths must come from this dataset's non-test pool")
  }
  references <- split(refs$image_path, refs$reference_class)
}

criteria <- NULL
if (nzchar(criteria_file)) {
  descriptions <- readr::read_csv(criteria_file, show_col_types = FALSE)
  if (!all(c("normal", "defective") %in% names(descriptions)) || nrow(descriptions) != 1L) {
    stop("Criteria CSV must have exactly one row and normal, defective columns")
  }
  criteria <- list(normal = descriptions$normal[[1]], defective = descriptions$defective[[1]])
}

# ---- Run one trial -------------------------------------------------------
result_file <- file.path(output_dir, paste0(trial_id, "_predictions.csv"))
score_file <- file.path(output_dir, paste0(trial_id, "_score.csv"))
if (file.exists(result_file) || file.exists(score_file)) {
  stop("Trial ID already exists. Choose a new JEV_TRIAL to avoid overwriting results.")
}

predictions <- purrr::map_dfr(seq_len(nrow(validation)), function(i) {
  item <- validation[i, ]
  answer <- classify_image(
    image_path = item$image_path, mode = "binary",
    reference_images = references, criteria = criteria,
    crop = crop, max_size = max_size, upscale = upscale, model = model,
    base_url = base_url, api_key = api_key, image_format = image_format
  )
  probability <- answer$probability[answer$class == "defective"]
  if (length(probability) != 1L || !is.finite(probability)) stop("Invalid defect probability")
  tibble::tibble(
    dataset = dataset, image_path = item$image_path,
    defect_type = item$defect_type, actual_class = item$actual_class,
    prob_defective = probability
  )
})

predictions <- predictions |>
  dplyr::mutate(predicted_class = dplyr::if_else(
    .data$prob_defective >= threshold, "defective", "nominal"
  ))

scores <- predictions |>
  dplyr::mutate(
    actual_class = factor(.data$actual_class, levels = c("defective", "nominal")),
    predicted_class = factor(.data$predicted_class, levels = c("defective", "nominal"))
  )

# Balanced accuracy = (defect sensitivity + nominal specificity) / 2.
score <- yardstick::bal_accuracy(scores, truth = actual_class, estimate = predicted_class)$.estimate
sensitivity <- yardstick::sens(scores, truth = actual_class, estimate = predicted_class)$.estimate
specificity <- yardstick::spec(scores, truth = actual_class, estimate = predicted_class)$.estimate
auc <- yardstick::roc_auc(scores, truth = actual_class, prob_defective, event_level = "first")$.estimate

summary <- tibble::tibble(
  trial_id = trial_id, dataset = dataset, seed = seed,
  n_images = nrow(predictions), use_references = use_references,
  reference_file = if (use_references) reference_file else NA_character_,
  criteria_file = if (nzchar(criteria_file)) criteria_file else NA_character_,
  crop = crop, max_size = max_size, upscale = upscale, model = model, base_url = base_url,
  image_format = image_format,
  threshold = threshold,
  balanced_accuracy = score, sensitivity = sensitivity,
  specificity = specificity, roc_auc = auc
)

readr::write_csv(predictions, result_file)
readr::write_csv(summary, score_file)
print(summary)
