# Calibration and threshold functions shared by calibration.R and
# validation_size.R (no API calls). Source from the project root.

clamp <- function(p) pmin(pmax(p, 0.005), 0.995) # scores can be 0 or 1; avoid logit(0)

#' Measure calibration of defect probabilities
#' @param p Defect probabilities.
#' @param y 1 for defective, 0 for nominal.
#' @return Tibble with `brier`, `ece` (10 equal-width bins), `log_loss`,
#'   `mean_p_minus_rate`, and `ba_at_050`.
calibration_metrics <- function(p, y) {
  bins <- cut(p, seq(0, 1, 0.1), include.lowest = TRUE)
  gaps <- tapply(seq_along(p), bins, function(i) length(i) * abs(mean(p[i]) - mean(y[i])))
  tibble::tibble(
    brier = mean((p - y)^2),
    ece = sum(gaps, na.rm = TRUE) / length(p),
    log_loss = -mean(y * log(clamp(p)) + (1 - y) * log(1 - clamp(p))),
    mean_p_minus_rate = mean(p) - mean(y),
    ba_at_050 = (mean(p[y == 1] >= 0.5) + mean(p[y == 0] < 0.5)) / 2
  )
}

#' Fit Platt scaling
#' @details Logistic regression on logit(p) with Platt's soft targets
#'   (N+ + 1)/(N+ + 2) and 1/(N- + 2), which keep the fit finite when the
#'   scores are perfectly separated.
#' @return A function that maps new probabilities to calibrated ones.
platt <- function(p, y) {
  target <- dplyr::if_else(y == 1, (sum(y) + 1) / (sum(y) + 2), 1 / (sum(1 - y) + 2))
  fit <- stats::glm(target ~ x, family = stats::quasibinomial(),
                    data = data.frame(target = target, x = stats::qlogis(clamp(p))))
  function(new_p) unname(stats::predict(fit, data.frame(x = stats::qlogis(clamp(new_p))), type = "response"))
}

#' Fit isotonic regression
#' @details Pool-adjacent-violators fit of y on p (stats::isoreg), linear
#'   interpolation between knots, constant beyond the fitted range.
#' @return A function that maps new probabilities to calibrated ones.
isotonic <- function(p, y) {
  o <- order(p)
  fit <- stats::isoreg(p[o], y[o])
  # One fitted value per distinct score (tied scores share the pooled value).
  knots <- stats::aggregate(fitted ~ score, data = data.frame(score = p[o], fitted = fit$yf), FUN = mean)
  if (nrow(knots) == 1L) return(function(new_p) rep(knots$fitted, length(new_p)))
  function(new_p) stats::approx(knots$score, knots$fitted, xout = new_p, rule = 2, ties = mean)$y
}

#' Tune a decision threshold (the rule of the experiment)
#' @details On an exact 2-decimal grid, the midpoint of the widest run of
#'   thresholds that all reach the maximum balanced accuracy.
#' @return The threshold.
tune_threshold <- function(p, y) {
  t <- round(seq(0.01, 0.99, 0.01), 2) # exact grid: seq() alone drifts
  ba <- vapply(t, function(x) (mean(p[y == 1] >= x) + mean(p[y == 0] < x)) / 2, numeric(1))
  runs <- rle(abs(ba - max(ba)) < 1e-9)
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1
  k <- which(runs$values)[which.max(runs$lengths[runs$values])]
  round((t[starts[k]] + t[ends[k]]) / 2, 2)
}
