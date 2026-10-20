# Are the JEV defect probabilities calibrated, and which recalibration works
# better: Platt scaling or isotonic regression? (no API calls)
# Each calibrator is fitted on the VALIDATION predictions of the source trial
# and applied unchanged to the test predictions.
# - Platt: logistic regression on logit(p) with Platt's soft targets
#   (N+ + 1)/(N+ + 2) and 1/(N- + 2), which keep the fit finite when the
#   validation scores are perfectly separated.
# - Isotonic: pool-adjacent-violators fit of y on p (stats::isoreg), linear
#   interpolation between knots, constant beyond the validation range.
# Metrics on test: Brier score, expected calibration error (ECE, 10 bins),
# log loss, calibration in the large, and BA at the 0.5 cutoff.
# Validation and test are balanced (50% defective), so "calibrated" means
# calibrated at that prevalence.

source("R/calibration_functions.R") # clamp(), calibration_metrics(), platt(), isotonic()

frozen <- readr::read_csv("results/optimization/frozen_configs.csv", show_col_types = FALSE)
results <- list()
curves <- list()
per_image <- list()
for (i in seq_len(nrow(frozen))) {
  row <- frozen[i, ]
  stem <- if (row$condition == "references") row$dataset else paste0(row$dataset, "_", row$condition)
  test_file <- file.path("results", "final_test", paste0(stem, "_predictions.csv"))
  if (!file.exists(test_file)) next
  # The source trial of a threshold trial has the same probabilities.
  source_score <- readr::read_csv(file.path("results", "optimization", row$tuned_on,
                                            paste0(row$source_trial, "_score.csv")), show_col_types = FALSE)
  probability_trial <- if ("source_trial" %in% names(source_score)) source_score$source_trial else row$source_trial
  validation <- readr::read_csv(file.path("results", "optimization", row$tuned_on,
                                          paste0(probability_trial, "_predictions.csv")), show_col_types = FALSE)
  test <- readr::read_csv(test_file, show_col_types = FALSE)
  y_val <- as.integer(validation$actual_class == "defective")
  y_test <- as.integer(test$actual_class == "defective")

  calibrated <- list(
    "raw JEV" = test$prob_defective,
    "Platt" = platt(validation$prob_defective, y_val)(test$prob_defective),
    "isotonic" = isotonic(validation$prob_defective, y_val)(test$prob_defective)
  )
  key <- paste(row$dataset, row$condition)
  per_image[[key]] <- tibble::tibble(dataset = row$dataset, condition = row$condition, y = y_test,
                                     platt = calibrated$Platt, isotonic = calibrated$isotonic)
  results[[key]] <- purrr::imap_dfr(calibrated, function(p, method) {
    dplyr::mutate(calibration_metrics(p, y_test), probabilities = method, .before = 1)
  }) |>
    dplyr::mutate(dataset = row$dataset, condition = row$condition, n_validation = length(y_val),
                  n_test = length(y_test), .before = 1)

  if (row$condition != "references") next # the chart shows the main condition only
  curves[[key]] <- purrr::imap_dfr(calibrated, function(p, method) {
    tibble::tibble(p = p, y = y_test, probabilities = method)
  }) |>
    dplyr::mutate(dataset = row$dataset, bin = cut(.data$p, seq(0, 1, 0.1), include.lowest = TRUE)) |>
    dplyr::group_by(.data$dataset, .data$probabilities, .data$bin) |>
    dplyr::summarise(mean_p = mean(.data$p), observed = mean(.data$y), n = dplyr::n(), .groups = "drop")
}

summary <- dplyr::bind_rows(results)
readr::write_csv(summary, file.path("results", "final_test", "calibration.csv"))
summary |>
  dplyr::select("dataset", "condition", "probabilities", "ece", "brier", "log_loss", "ba_at_050") |>
  as.data.frame() |>
  print(digits = 2)

# Is isotonic better than Platt beyond test-set noise? Paired bootstrap over
# test images (2,000 resamples): 95% interval of (isotonic - Platt).
# Negative = isotonic better. An interval that covers 0 = no clear winner.
set.seed(202610)
bootstrap <- purrr::map_dfr(per_image, function(d) {
  draws <- replicate(2000, {
    b <- d[sample.int(nrow(d), replace = TRUE), ]
    c(ece = calibration_metrics(b$isotonic, b$y)$ece - calibration_metrics(b$platt, b$y)$ece,
      log_loss = calibration_metrics(b$isotonic, b$y)$log_loss - calibration_metrics(b$platt, b$y)$log_loss)
  })
  tibble::tibble(
    dataset = d$dataset[[1]], condition = d$condition[[1]],
    ece_diff_low = stats::quantile(draws["ece", ], 0.025), ece_diff_high = stats::quantile(draws["ece", ], 0.975),
    log_loss_diff_low = stats::quantile(draws["log_loss", ], 0.025),
    log_loss_diff_high = stats::quantile(draws["log_loss", ], 0.975)
  )
})
readr::write_csv(bootstrap, file.path("results", "final_test", "calibration_bootstrap.csv"))
print(as.data.frame(bootstrap), digits = 2)

# Reliability diagram: a calibrated model lies on the diagonal.
methods <- c("raw JEV", "Platt", "isotonic")
plot <- dplyr::bind_rows(curves) |>
  dplyr::mutate(dataset = factor(.data$dataset, levels = unique(frozen$dataset)),
                probabilities = factor(.data$probabilities, levels = methods)) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$mean_p, y = .data$observed,
                               colour = .data$probabilities, shape = .data$probabilities)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, colour = "#666666", linewidth = 0.3) +
  ggplot2::geom_line(linewidth = 0.6) +
  ggplot2::geom_point(ggplot2::aes(size = .data$n), stroke = 0.8, fill = "white") +
  ggplot2::facet_wrap(ggplot2::vars(.data$dataset), nrow = 2) +
  ggplot2::scale_colour_manual(values = c("raw JEV" = "#70685C", "Platt" = "#C41230", "isotonic" = "#3E5468"),
                               name = NULL) +
  ggplot2::scale_shape_manual(values = c("raw JEV" = 21, "Platt" = 16, "isotonic" = 17), name = NULL) +
  ggplot2::scale_size_area(max_size = 4, name = "Test images in bin") +
  ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
  ggplot2::labs(
    title = "Calibration of JEV defect probabilities on the test sets",
    subtitle = "Points on the gray diagonal are calibrated. Platt and isotonic were fitted on validation only.",
    x = "Mean predicted defect probability (10 bins)", y = "Observed defect rate"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", colour = NA),
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_line(colour = "#EDECE2", linewidth = 0.3),
    strip.text = ggplot2::element_text(face = "bold", hjust = 0),
    plot.subtitle = ggplot2::element_text(colour = "#666666"),
    legend.position = "top"
  )
ggplot2::ggsave(file.path("results", "final_test", "calibration.png"), plot, width = 11, height = 7.5, dpi = 200)
message("Wrote results/final_test/calibration.csv and calibration.png")
