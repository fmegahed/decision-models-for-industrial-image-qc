# Threshold trial without API calls: apply a new threshold to the saved
# validation predictions of an earlier trial. Run from the project root.
# JEV is not deterministic, so re-running the API would change two things
# at once (threshold and API noise). This script changes only the threshold.
#
# JEV_DATASET=microstructure JEV_FROM_TRIAL=criteria_color \
#   JEV_TRIAL=criteria_color_t040 JEV_THRESHOLD=0.40 Rscript scripts/rescore_threshold.R

dataset <- Sys.getenv("JEV_DATASET")
from_trial <- Sys.getenv("JEV_FROM_TRIAL")
trial_id <- Sys.getenv("JEV_TRIAL")
threshold <- as.numeric(Sys.getenv("JEV_THRESHOLD"))

if (!grepl("^[A-Za-z0-9_-]+$", trial_id)) stop("Invalid trial ID")
if (!is.finite(threshold) || threshold < 0 || threshold > 1) stop("Invalid threshold")
output_dir <- file.path("results", "optimization", dataset)
source_predictions <- file.path(output_dir, paste0(from_trial, "_predictions.csv"))
source_score <- file.path(output_dir, paste0(from_trial, "_score.csv"))
result_file <- file.path(output_dir, paste0(trial_id, "_predictions.csv"))
score_file <- file.path(output_dir, paste0(trial_id, "_score.csv"))
if (!file.exists(source_predictions) || !file.exists(source_score)) stop("Source trial not found")
if (file.exists(result_file) || file.exists(score_file)) {
  stop("Trial ID already exists. Choose a new JEV_TRIAL to avoid overwriting results.")
}

score_at <- function(predictions, threshold) {
  scores <- predictions |>
    dplyr::mutate(
      actual_class = factor(.data$actual_class, levels = c("defective", "nominal")),
      predicted_class = factor(
        dplyr::if_else(.data$prob_defective >= .env$threshold, "defective", "nominal"),
        levels = c("defective", "nominal")
      )
    )
  tibble::tibble(
    threshold = threshold,
    balanced_accuracy = yardstick::bal_accuracy(scores, truth = actual_class, estimate = predicted_class)$.estimate,
    sensitivity = yardstick::sens(scores, truth = actual_class, estimate = predicted_class)$.estimate,
    specificity = yardstick::spec(scores, truth = actual_class, estimate = predicted_class)$.estimate
  )
}

predictions <- readr::read_csv(source_predictions, show_col_types = FALSE)

# For reference only: the validation curve over a grid of thresholds.
# A threshold picked from this grid is fitted to validation, so its score is
# optimistic; only the final test evaluation is unbiased.
# round(): scores have 2 decimals, and seq() drifts (0.41 becomes 0.41000000000000003).
print(purrr::map_dfr(round(seq(0.10, 0.90, by = 0.05), 2), \(t) score_at(predictions, t)), n = 20)

predictions <- predictions |>
  dplyr::mutate(predicted_class = dplyr::if_else(
    .data$prob_defective >= .env$threshold, "defective", "nominal"
  ))
new_score <- score_at(predictions, threshold)
summary <- readr::read_csv(source_score, show_col_types = FALSE) |>
  dplyr::mutate(
    # .env: the summary already has trial_id and threshold columns.
    trial_id = .env$trial_id, threshold = .env$threshold,
    balanced_accuracy = new_score$balanced_accuracy,
    sensitivity = new_score$sensitivity, specificity = new_score$specificity,
    source_trial = .env$from_trial
  )

readr::write_csv(predictions, result_file)
readr::write_csv(summary, score_file)
print(summary)
