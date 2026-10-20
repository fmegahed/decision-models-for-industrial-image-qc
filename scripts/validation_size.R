# How many labeled validation images does the calibration step need?
# (no API calls; uses the saved validation and test predictions)
# For each frozen configuration, draw B random validation subsets with n images
# per class, then (a) tune a threshold on the raw probabilities, (b) fit Platt
# scaling, (c) fit isotonic regression, and score each on the full test set.
# Caveat: the criteria and references were chosen on the full validation set,
# so this measures the threshold/calibration step only, not the refinement step.
# Writes results/final_test/validation_size.csv and validation_size.png.

source("R/calibration_functions.R")
set.seed(202610)
B <- 200L
sizes <- c(5L, 10L, 20L, 30L, 50L)

frozen <- readr::read_csv("results/optimization/frozen_configs.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$condition %in% c("references", "clef_refs"))

ba_at <- function(p, y, t) (mean(p[y == 1] >= t) + mean(p[y == 0] < t)) / 2

draws <- purrr::map_dfr(seq_len(nrow(frozen)), function(i) {
  row <- frozen[i, ]
  stem <- if (row$condition == "references") row$dataset else paste0(row$dataset, "_", row$condition)
  source_score <- readr::read_csv(file.path("results", "optimization", row$tuned_on,
                                            paste0(row$source_trial, "_score.csv")), show_col_types = FALSE)
  validation <- readr::read_csv(file.path("results", "optimization", row$tuned_on,
                                          paste0(source_score$source_trial, "_predictions.csv")), show_col_types = FALSE)
  test <- readr::read_csv(file.path("results", "final_test", paste0(stem, "_predictions.csv")), show_col_types = FALSE)
  y_val <- as.integer(validation$actual_class == "defective")
  y_test <- as.integer(test$actual_class == "defective")
  available <- min(table(y_val))
  model <- if (row$condition == "clef_refs") "Clef-Flash" else "JEV"

  purrr::map_dfr(unique(pmin(sizes, available)), function(n) {
    purrr::map_dfr(seq_len(B), function(b) {
      pick <- c(sample(which(y_val == 1), n), sample(which(y_val == 0), n))
      p <- validation$prob_defective[pick]
      y <- y_val[pick]
      p_platt <- platt(p, y)(test$prob_defective)
      p_iso <- isotonic(p, y)(test$prob_defective)
      tibble::tibble(
        model = model, dataset = row$dataset, n_per_class = n, draw = b,
        method = c("threshold only", "Platt", "isotonic"),
        test_ba = c(ba_at(test$prob_defective, y_test, tune_threshold(p, y)),
                    ba_at(p_platt, y_test, 0.5), ba_at(p_iso, y_test, 0.5)),
        test_ece = c(calibration_metrics(test$prob_defective, y_test)$ece,
                     calibration_metrics(p_platt, y_test)$ece, calibration_metrics(p_iso, y_test)$ece)
      )
    })
  })
})

summary <- draws |>
  tidyr::pivot_longer(c("test_ba", "test_ece"), names_to = "metric") |>
  dplyr::group_by(.data$model, .data$dataset, .data$n_per_class, .data$method, .data$metric) |>
  dplyr::summarise(mean = mean(.data$value), p10 = stats::quantile(.data$value, 0.1),
                   p90 = stats::quantile(.data$value, 0.9), .groups = "drop")
readr::write_csv(summary, file.path("results", "final_test", "validation_size.csv"))

summary |>
  dplyr::filter(.data$model == "JEV", .data$method != "threshold only" | .data$metric == "test_ba") |>
  dplyr::mutate(cell = sprintf("%.2f [%.2f, %.2f]", .data$mean, .data$p10, .data$p90)) |>
  dplyr::select("dataset", "metric", "method", "n_per_class", "cell") |>
  tidyr::pivot_wider(names_from = "n_per_class", values_from = "cell", names_prefix = "n=") |>
  dplyr::arrange(.data$metric, .data$dataset, .data$method) |>
  as.data.frame() |>
  print(right = FALSE)

# Chart (JEV): one column per dataset; test BA on top, test ECE below.
# "threshold only" has no calibration, so its ECE line is the raw ECE.
methods <- c("threshold only", "isotonic", "Platt")
plot_data <- summary |>
  dplyr::filter(.data$model == "JEV") |>
  dplyr::mutate(
    method = factor(.data$method, levels = methods),
    metric = factor(dplyr::recode(.data$metric, test_ba = "Test balanced accuracy",
                                  test_ece = "Test calibration error (ECE)"),
                    levels = c("Test balanced accuracy", "Test calibration error (ECE)")),
    dataset = factor(.data$dataset, levels = unique(frozen$dataset))
  )
plot <- ggplot2::ggplot(plot_data, ggplot2::aes(x = .data$n_per_class, y = .data$mean,
                                                colour = .data$method, fill = .data$method)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$p10, ymax = .data$p90), alpha = 0.12, colour = NA) +
  ggplot2::geom_line(linewidth = 0.7) +
  ggplot2::geom_point(ggplot2::aes(shape = .data$method), size = 2.2) +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$metric), cols = ggplot2::vars(.data$dataset),
                      scales = "free_y", switch = "y") +
  ggplot2::scale_colour_manual(values = c("threshold only" = "#666666", isotonic = "#C41230", Platt = "#3E5468"), name = NULL) +
  ggplot2::scale_fill_manual(values = c("threshold only" = "#666666", isotonic = "#C41230", Platt = "#3E5468"), name = NULL) +
  ggplot2::scale_shape_manual(values = c("threshold only" = 15, isotonic = 16, Platt = 17), name = NULL) +
  ggplot2::scale_x_continuous(breaks = sizes) +
  ggplot2::labs(
    title = "How many validation images does calibration need? (JEV with references)",
    subtitle = "Mean over 200 random validation subsets; band = 10th to 90th percentile. Scored on the full test sets.",
    x = "Validation images per class (pan has only 8)", y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", colour = NA),
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_line(colour = "#EDECE2", linewidth = 0.3),
    strip.text = ggplot2::element_text(face = "bold"),
    strip.placement = "outside",
    plot.subtitle = ggplot2::element_text(colour = "#666666"),
    legend.position = "top"
  )
ggplot2::ggsave(file.path("results", "final_test", "validation_size.png"), plot, width = 13, height = 6.5, dpi = 200)
message("Wrote results/final_test/validation_size.csv and validation_size.png")
