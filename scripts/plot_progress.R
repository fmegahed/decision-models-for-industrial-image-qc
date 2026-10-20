# Progress chart for the JEV validation trials: one panel per dataset.
# Run from the project root after logging a trial in experiment_log.md.
# Decisions come from the experiment_log.md table; metrics come from the
# results/optimization/<dataset>/<trial>_score.csv files. No test data is read.

miami_red <- "#C41230"
dark_tan <- "#70685C"
light_tan <- "#EDECE2"
muted <- "#666666"
dataset_order <- c("microstructure", "textiles", "extrusion", "pipe_staple", "pan_images")
output_file <- file.path("results", "optimization", "progress.png")

# ---- Decisions: the markdown table in experiment_log.md ------------------
# Columns used: #, Dataset, Trial, Change, Decision (baseline/kept/discarded/replicate/failed).
# Do not put a "|" character inside a table cell.
lines <- readLines("experiment_log.md", warn = FALSE)
rows <- lines[grepl("^\\|", lines) & !grepl("^\\|\\s*:?-", lines)]
cells <- lapply(strsplit(sub("^\\|(.*)\\|\\s*$", "\\1", rows), "|", fixed = TRUE), trimws)
if (length(cells) < 2L) stop("No trials in experiment_log.md yet.")
log <- as.data.frame(do.call(rbind, cells[-1])) |>
  stats::setNames(cells[[1]]) |>
  tibble::as_tibble() |>
  dplyr::transmute(
    order = as.integer(.data[["#"]]), dataset = .data$Dataset,
    trial_id = .data$Trial, change = .data$Change,
    decision = tolower(.data$Decision)
  )

# ---- Metrics: every scored trial -----------------------------------------
score_files <- list.files(file.path("results", "optimization"),
                          pattern = "_score\\.csv$", recursive = TRUE, full.names = TRUE)
scores <- purrr::map_dfr(score_files, function(file) {
  predictions <- readr::read_csv(sub("_score\\.csv$", "_predictions.csv", file),
                                 show_col_types = FALSE)
  readr::read_csv(file, show_col_types = FALSE) |>
    dplyr::mutate(n_defective = sum(predictions$actual_class == "defective"),
                  n_nominal = sum(predictions$actual_class == "nominal"))
})
if (!nrow(scores)) stop("No scored trials yet.")

unlogged <- dplyr::anti_join(scores, log, by = c("dataset", "trial_id"))
if (nrow(unlogged)) {
  message("Scored but not in experiment_log.md (not plotted): ",
          paste(unlogged$dataset, unlogged$trial_id, sep = "/", collapse = ", "))
}
n_failed <- sum(log$decision == "failed")

# Two metrics per trial, one column each. ROC AUC decides criteria, reference
# and size changes (the threshold is tuned last). Balanced accuracy at the
# trial's threshold is the objective. Bands: Hanley-McNeil SE for AUC,
# binomial SE for balanced accuracy.
metric_names <- c(auc = "ROC AUC (decides each trial)",
                  ba = "Balanced accuracy at the trial threshold (objective)")
# Other models (decision "comparison") are logged but are not JEV progress.
trials <- dplyr::inner_join(dplyr::filter(log, .data$decision != "comparison"), scores,
                            by = c("dataset", "trial_id")) |>
  dplyr::arrange(.data$dataset, .data$order) |>
  dplyr::group_by(.data$dataset) |>
  dplyr::mutate(
    step = as.numeric(dplyr::row_number()),
    next_step = dplyr::lead(.data$step, default = max(.data$step) + 0.6)
  ) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    status = dplyr::if_else(.data$decision %in% c("baseline", "kept"), "Kept", "Not kept"),
    q1 = .data$roc_auc / (2 - .data$roc_auc),
    q2 = 2 * .data$roc_auc^2 / (1 + .data$roc_auc),
    se_auc = sqrt((.data$roc_auc * (1 - .data$roc_auc) +
                     (.data$n_defective - 1) * (.data$q1 - .data$roc_auc^2) +
                     (.data$n_nominal - 1) * (.data$q2 - .data$roc_auc^2)) /
                    (.data$n_defective * .data$n_nominal)),
    se_ba = 0.5 * sqrt(.data$sensitivity * (1 - .data$sensitivity) / .data$n_defective +
                         .data$specificity * (1 - .data$specificity) / .data$n_nominal)
  )

# Current best = the last baseline or kept trial, carried forward.
long <- dplyr::bind_rows(
  dplyr::mutate(trials, metric = metric_names[["auc"]], value = .data$roc_auc, se = .data$se_auc),
  dplyr::mutate(trials, metric = metric_names[["ba"]], value = .data$balanced_accuracy, se = .data$se_ba)
) |>
  dplyr::arrange(.data$dataset, .data$metric, .data$step) |>
  dplyr::group_by(.data$dataset, .data$metric) |>
  dplyr::mutate(
    best = dplyr::if_else(.data$status == "Kept", .data$value, NA_real_),
    best_se = dplyr::if_else(.data$status == "Kept", .data$se, NA_real_)
  ) |>
  tidyr::fill("best", "best_se", .direction = "down") |>
  dplyr::ungroup() |>
  dplyr::mutate(
    dataset = factor(.data$dataset, levels = union(dataset_order, sort(unique(.data$dataset)))),
    metric = factor(.data$metric, levels = metric_names),
    label = sprintf("%s  %.2f", .data$trial_id, .data$value)
  )

# The step line runs to the end of each panel.
best_path <- dplyr::bind_rows(
  dplyr::select(long, "dataset", "metric", "step", "best"),
  long |>
    dplyr::group_by(.data$dataset, .data$metric) |>
    dplyr::slice_max(.data$step, n = 1) |>
    dplyr::ungroup() |>
    dplyr::transmute(.data$dataset, .data$metric, step = .data$next_step, .data$best)
)

n_kept <- sum(trials$decision == "kept")
y_low <- min(0.5, floor(10 * min(long$value - long$se, na.rm = TRUE)) / 10)

plot <- ggplot2::ggplot(long, ggplot2::aes(x = .data$step)) +
  ggplot2::geom_hline(yintercept = 0.5, colour = muted, linewidth = 0.3) +
  ggplot2::geom_rect(
    ggplot2::aes(xmin = .data$step, xmax = .data$next_step,
                 ymin = .data$best - .data$best_se, ymax = .data$best + .data$best_se,
                 alpha = "\u00b11 SE of current best"),
    fill = light_tan
  ) +
  ggplot2::geom_step(data = best_path, ggplot2::aes(y = .data$best, linetype = "Current best (last kept)"),
                     colour = miami_red, linewidth = 0.7, direction = "hv") +
  ggplot2::geom_point(
    ggplot2::aes(y = .data$value, shape = .data$status, fill = .data$status,
                 colour = .data$status, size = .data$status),
    stroke = 0.9
  ) +
  ggplot2::geom_text(
    data = dplyr::filter(long, .data$status == "Kept"),
    ggplot2::aes(y = .data$value, label = .data$label),
    angle = 25, hjust = 0, vjust = 0, nudge_x = 0.08, nudge_y = 0.012,
    size = 2.8, colour = "black"
  ) +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$dataset), cols = ggplot2::vars(.data$metric)) +
  ggplot2::scale_x_continuous(
    # Ticks stop at the last trial; the right margin is room for labels.
    breaks = function(limits) seq(1, floor(limits[2] - 3)),
    expand = ggplot2::expansion(add = c(0.4, 2.5))
  ) +
  ggplot2::scale_y_continuous(breaks = seq(0, 1, 0.1), limits = c(y_low, 1.1)) +
  ggplot2::scale_shape_manual(values = c("Kept" = 21, "Not kept" = 21), name = NULL) +
  ggplot2::scale_fill_manual(values = c("Kept" = miami_red, "Not kept" = "white"), name = NULL) +
  ggplot2::scale_colour_manual(values = c("Kept" = "white", "Not kept" = dark_tan), name = NULL) +
  ggplot2::scale_size_manual(values = c("Kept" = 3.4, "Not kept" = 2.2), name = NULL) +
  ggplot2::scale_linetype_manual(values = c("Current best (last kept)" = "solid"), name = NULL) +
  ggplot2::scale_alpha_manual(values = 1, name = NULL) +
  ggplot2::annotate("text", x = 0.6, y = 0.5, label = "chance", colour = muted,
                    size = 2.8, hjust = 0, vjust = -0.4) +
  ggplot2::coord_cartesian(clip = "off") +
  ggplot2::labs(
    title = sprintf("JEV validation progress: %d trials, %d kept changes", nrow(trials), n_kept),
    subtitle = paste("ROC AUC decides criteria, reference and size changes; the threshold is tuned last.",
                     "Higher is better. A change inside the tan band may be noise. Test images were not used."),
    x = "Trial # (within dataset)", y = "Validation score",
    caption = sprintf("Failed trials (no score): %d. Source: experiment_log.md and results/optimization/. %s",
                      n_failed, format(Sys.Date()))
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", colour = NA),
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_line(colour = light_tan, linewidth = 0.3),
    panel.spacing.x = ggplot2::unit(1.2, "lines"),
    strip.text = ggplot2::element_text(face = "bold", hjust = 0),
    strip.text.y = ggplot2::element_text(face = "bold", angle = 0, hjust = 0),
    plot.subtitle = ggplot2::element_text(colour = muted),
    plot.caption = ggplot2::element_text(colour = muted),
    legend.position = "top", legend.justification = "right"
  )

n_panels <- length(unique(trials$dataset))
ggplot2::ggsave(output_file, plot, width = 14, height = 1.8 + 2.6 * n_panels, dpi = 200)
message("Wrote ", output_file)
