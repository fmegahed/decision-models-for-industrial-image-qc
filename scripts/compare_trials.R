# Compare trials on the same validation images (no API calls).
# Prints accuracy and mean defect score per subtype, then the images that
# flipped between the first and the last trial (as in initial_code/analysis.R).
#
# JEV_DATASET=microstructure JEV_TRIALS=baseline,baseline_rep Rscript scripts/compare_trials.R

dataset <- Sys.getenv("JEV_DATASET")
trials <- strsplit(Sys.getenv("JEV_TRIALS"), ",", fixed = TRUE)[[1]]
if (length(trials) < 1L) stop("Set JEV_TRIALS, for example baseline,criteria_color")

predictions <- purrr::map_dfr(trials, function(trial) {
  file.path("results", "optimization", dataset, paste0(trial, "_predictions.csv")) |>
    readr::read_csv(show_col_types = FALSE) |>
    dplyr::mutate(trial = trial)
}) |>
  dplyr::mutate(
    trial = factor(.data$trial, levels = trials),
    correct = .data$predicted_class == .data$actual_class
  )

# Accuracy within a subtype = recall for defect types, specificity for nominal.
predictions |>
  dplyr::group_by(.data$actual_class, .data$defect_type, .data$trial) |>
  dplyr::summarise(n = dplyr::n(), accuracy = mean(.data$correct),
                   mean_prob = mean(.data$prob_defective), .groups = "drop") |>
  tidyr::pivot_wider(names_from = "trial", values_from = c("accuracy", "mean_prob")) |>
  print(n = 50, width = Inf)

if (length(trials) >= 2L) {
  first <- dplyr::filter(predictions, .data$trial == trials[[1]])
  last <- dplyr::filter(predictions, .data$trial == trials[[length(trials)]])
  flips <- dplyr::inner_join(first, last, by = c("image_path", "defect_type", "actual_class"),
                             suffix = c("_first", "_last")) |>
    dplyr::mutate(change = dplyr::case_when(
      !.data$correct_first & .data$correct_last ~ "improved",
      .data$correct_first & !.data$correct_last ~ "worsened",
      .default = "same"
    ))
  cat("\n", trials[[1]], "->", trials[[length(trials)]], ": mean |score change| =",
      round(mean(abs(flips$prob_defective_last - flips$prob_defective_first)), 3), "\n")
  print(dplyr::count(flips, .data$actual_class, .data$change))
  flips |>
    dplyr::filter(.data$change != "same") |>
    dplyr::select("defect_type", "change", "prob_defective_first", "prob_defective_last", "image_path") |>
    print(n = 50, width = Inf)
}
