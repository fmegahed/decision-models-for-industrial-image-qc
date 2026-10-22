source(file.path(repo_root, "R", "calibration_functions.R"))

preds <- readr::read_csv(
  file.path(repo_root, "results", "final_test", "microstructure_predictions.csv"),
  show_col_types = FALSE
)
p <- preds$prob_defective
y <- as.integer(preds$actual_class == "defective")
grid <- c(0.05, 0.3, 0.5, 0.8, 0.95)

test_that("calibration_metrics() keeps its v0.0.1 values", {
  m <- calibration_metrics(p, y)
  expect_equal(m$brier, 0.135412666666667)
  expect_equal(m$ece, 0.178733333333333)
  expect_equal(m$log_loss, 0.427931207369738)
  expect_equal(m$mean_p_minus_rate, -0.178733333333333)
  expect_equal(m$ba_at_050, 0.815555555555556)
})

test_that("platt(), isotonic() and tune_threshold() keep their values", {
  expect_equal(platt(p, y)(grid),
               c(0.1137104202978, 0.943360637239297, 0.991663867799336,
                 0.999663135871792, 0.999990933891928))
  expect_equal(isotonic(p, y)(grid),
               c(0.0902255639097744, 1, 1, 1, 1))
  expect_equal(tune_threshold(p, y), 0.11)
})

test_that("platt() is finite and inside (0, 1) for separated scores", {
  out <- platt(c(0.01, 0.02, 0.98, 0.99), c(0, 0, 1, 1))(c(0, 0.5, 1))
  expect_true(all(is.finite(out)))
  expect_true(all(out > 0 & out < 1))
})
