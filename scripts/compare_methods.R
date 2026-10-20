# One table for the four methods on the same test partition (no API calls):
# JEV with references, JEV zero-shot, CLIP with references, CLIP zero-shot.
# Every method uses a threshold chosen on the same validation images; AUC needs
# no threshold. Writes results/final_test/method_comparison.csv.

# summary.csv holds JEV (references, zero_shot) and Clef-Flash (clef_refs, clef_zero).
jev <- readr::read_csv("results/final_test/summary.csv", show_col_types = FALSE) |>
  dplyr::transmute(
    .data$dataset,
    model = dplyr::if_else(startsWith(.data$condition, "clef_"), "Clef-Flash", "JEV"),
    condition = dplyr::recode(.data$condition, clef_refs = "references", clef_zero = "zero_shot"),
    balanced_accuracy = .data$test_ba, sensitivity = .data$test_sens,
    specificity = .data$test_spec, roc_auc = .data$test_auc
  )
clip <- readr::read_csv("results/clip/summary.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$rule == "tuned on validation") |>
  dplyr::transmute(.data$dataset, model = "CLIP", .data$condition, .data$balanced_accuracy,
                   .data$sensitivity, .data$specificity, .data$roc_auc)

comparison <- dplyr::bind_rows(jev, clip) |>
  dplyr::mutate(method = paste(.data$model, .data$condition))
readr::write_csv(comparison, "results/final_test/method_comparison.csv")

comparison |>
  dplyr::select("dataset", "method", "balanced_accuracy", "roc_auc") |>
  tidyr::pivot_wider(names_from = "method", values_from = c("balanced_accuracy", "roc_auc")) |>
  as.data.frame() |>
  print(digits = 2)
