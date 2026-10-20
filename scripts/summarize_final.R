# Final results table: the frozen configuration's validation score (selection)
# next to its one-time test score (evaluation). No API calls.
# Writes results/final_test/summary.csv and results/final_test/subtypes.csv.

frozen <- readr::read_csv("results/optimization/frozen_configs.csv", show_col_types = FALSE)

summary <- purrr::map_dfr(seq_len(nrow(frozen)), function(i) {
  row <- frozen[i, ]
  validation <- file.path("results", "optimization", row$tuned_on,
                          paste0(row$source_trial, "_score.csv")) |>
    readr::read_csv(show_col_types = FALSE)
  stem <- if (row$condition == "references") row$dataset else paste0(row$dataset, "_", row$condition)
  test_file <- file.path("results", "final_test", paste0(stem, "_score.csv"))
  test <- if (file.exists(test_file)) readr::read_csv(test_file, show_col_types = FALSE) else NULL
  tibble::tibble(
    dataset = row$dataset, condition = row$condition, tuned_on = row$tuned_on,
    source_trial = row$source_trial,
    criteria_file = row$criteria_file, max_size = row$max_size, threshold = row$threshold,
    validation_n = validation$n_images, validation_ba = validation$balanced_accuracy,
    validation_sens = validation$sensitivity, validation_spec = validation$specificity,
    validation_auc = validation$roc_auc,
    test_n = if (is.null(test)) NA else test$n_images,
    test_ba = if (is.null(test)) NA else test$balanced_accuracy,
    test_sens = if (is.null(test)) NA else test$sensitivity,
    test_spec = if (is.null(test)) NA else test$specificity,
    test_auc = if (is.null(test)) NA else test$roc_auc
  )
})

# Accuracy per subtype on the test set: recall for defect types, specificity for nominal.
prediction_files <- list.files(file.path("results", "final_test"), pattern = "_predictions\\.csv$",
                               full.names = TRUE)
subtypes <- purrr::map_dfr(prediction_files, function(file) {
  readr::read_csv(file, show_col_types = FALSE) |>
    dplyr::mutate(condition = dplyr::if_else(grepl("_zero_shot_predictions", file), "zero_shot", "references"))
}) |>
  dplyr::group_by(.data$dataset, .data$condition, .data$actual_class, .data$defect_type) |>
  dplyr::summarise(n = dplyr::n(), accuracy = mean(.data$predicted_class == .data$actual_class),
                   mean_prob = mean(.data$prob_defective), .groups = "drop")

readr::write_csv(summary, file.path("results", "final_test", "summary.csv"))
readr::write_csv(subtypes, file.path("results", "final_test", "subtypes.csv"))
print(as.data.frame(dplyr::select(summary, "dataset", "condition", "threshold", "validation_ba", "test_n",
                                  "test_ba", "test_sens", "test_spec", "test_auc")), digits = 3)
print(as.data.frame(subtypes), digits = 3)
