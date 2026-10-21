# Metrics and paired tests for the fair comparison (no API calls).
# Source from the project root.

#' Expected calibration error
#' @param prob Defect probabilities.
#' @param y 1 for defective, 0 for nominal.
#' @param bins Number of equal-width bins on [0, 1].
#' @return The ECE (weighted mean gap between mean prob and defect rate).
ece <- function(prob, y, bins = 10) {
  tibble::tibble(prob = prob, y = y) |>
    dplyr::mutate(bin = cut(prob, seq(0, 1, length.out = bins + 1),
                            include.lowest = TRUE)) |>
    dplyr::summarise(gap = dplyr::n() * abs(mean(prob) - mean(y)), .by = bin) |>
    dplyr::pull(gap) |>
    sum() / length(prob)
}

# Add the two factors yardstick needs. The first level is the event.
add_classes <- function(data, threshold) {
  lvl <- c("defective", "nominal")
  data |>
    dplyr::mutate(
      truth = factor(as.character(actual_class), levels = lvl),
      estimate = factor(dplyr::if_else(prob_defective >= threshold,
                                       "defective", "nominal"), levels = lvl)
    )
}

#' All common metrics at one threshold
#' @param data Tibble with `actual_class` and `prob_defective`.
#' @param threshold Decision threshold (default 0.5).
#' @return One-row tibble. The event is "defective".
class_metrics <- function(data, threshold = 0.5) {
  data <- add_classes(data, threshold)
  hard <- yardstick::metric_set(
    yardstick::accuracy, yardstick::bal_accuracy, yardstick::sens,
    yardstick::spec, yardstick::precision, yardstick::f_meas, yardstick::mcc
  )
  soft <- yardstick::metric_set(
    yardstick::roc_auc, yardstick::brier_class, yardstick::mn_log_loss
  )
  out <- dplyr::bind_rows(
    hard(data, truth = truth, estimate = estimate),
    soft(data, truth = truth, prob_defective)
  ) |>
    dplyr::select(.metric, .estimate) |>
    tidyr::pivot_wider(names_from = .metric, values_from = .estimate)
  # MCC is NaN when a class is never predicted or present: count it as 0.
  out |>
    dplyr::mutate(mcc = tidyr::replace_na(mcc, 0)) |>
    dplyr::mutate(ece = ece(data$prob_defective,
                            as.integer(data$truth == "defective")))
}

#' Exact McNemar test
#' @param correct_a,correct_b Logical: was each method right on each image?
#' @return Two-sided exact p-value from the discordant pairs.
mcnemar_exact <- function(correct_a, correct_b) {
  only_a <- sum(correct_a & !correct_b)
  only_b <- sum(!correct_a & correct_b)
  if (only_a + only_b == 0) return(1)
  stats::binom.test(only_a, only_a + only_b, p = 0.5)$p.value
}

#' Paired bootstrap of a metric difference (a minus b)
#' @param a,b Prediction tibbles on the same images, in the same order.
#' @param metric "bal_accuracy", "mcc" or "roc_auc".
#' @return Tibble with `difference`, `low`, `high` (95% percentile interval).
#'   Images are resampled within class; a and b share the indices.
paired_bootstrap <- function(a, b, metric, times = 2000, seed = 202612) {
  metric <- rlang::arg_match(metric, c("bal_accuracy", "mcc", "roc_auc"))
  score <- function(d, i) {
    d <- add_classes(d[i, ], 0.5)
    switch(metric,
      bal_accuracy = yardstick::bal_accuracy_vec(d$truth, d$estimate),
      mcc = tidyr::replace_na(yardstick::mcc_vec(d$truth, d$estimate), 0),
      roc_auc = yardstick::roc_auc_vec(d$truth, d$prob_defective)
    )
  }
  diff_at <- function(i) score(a, i) - score(b, i)
  by_class <- split(seq_len(nrow(a)), a$actual_class)
  # with_seed leaves the global random state untouched.
  boot <- withr::with_seed(seed, purrr::map_dbl(seq_len(times), \(r) {
    diff_at(unlist(purrr::map(by_class, \(i) sample(i, length(i), replace = TRUE))))
  }))
  ci <- stats::quantile(boot, c(0.025, 0.975), names = FALSE)
  tibble::tibble(difference = diff_at(seq_len(nrow(a))), low = ci[1], high = ci[2])
}
