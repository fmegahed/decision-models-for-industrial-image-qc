source(file.path(repo_root, "R", "evaluation.R"))

# TP 4, FN 1, TN 3, FP 2
toy <- tibble::tibble(
  actual_class = rep(c("defective", "nominal"), c(5, 5)),
  prob_defective = c(0.9, 0.8, 0.7, 0.6, 0.2, 0.1, 0.2, 0.3, 0.7, 0.8)
)

test_that("class_metrics() gives the known counts", {
  m <- class_metrics(toy)
  expect_equal(m$accuracy, 0.7)
  expect_equal(m$sens, 0.8)
  expect_equal(m$spec, 0.6)
  expect_equal(m$precision, 4 / 6)
  expect_equal(m$bal_accuracy, 0.7)
})

test_that("the event is defective whatever the input order", {
  flipped <- toy |>
    dplyr::mutate(actual_class = factor(actual_class,
                                        levels = c("nominal", "defective")))
  expect_equal(class_metrics(flipped), class_metrics(toy))
})

test_that("a perfect classifier has Brier 0 and AUC 1", {
  perfect <- tibble::tibble(
    actual_class = rep(c("defective", "nominal"), each = 4),
    prob_defective = rep(c(1, 0), each = 4)
  )
  m <- class_metrics(perfect)
  expect_equal(m$brier_class, 0)
  expect_equal(m$roc_auc, 1)
  expect_equal(m$ece, 0)
})

test_that("ece() matches calibration_metrics()", {
  source(file.path(repo_root, "R", "calibration_functions.R"))
  d <- readr::read_csv(
    file.path(repo_root, "results", "final_test", "microstructure_predictions.csv"),
    show_col_types = FALSE
  )
  y <- as.integer(d$actual_class == "defective")
  expect_equal(ece(d$prob_defective, y), calibration_metrics(d$prob_defective, y)$ece)
})

test_that("mcnemar_exact() uses the discordant counts", {
  a <- c(rep(TRUE, 8), rep(FALSE, 2), rep(TRUE, 5))
  b <- c(rep(FALSE, 8), rep(TRUE, 2), rep(TRUE, 5))
  expect_equal(mcnemar_exact(a, b), 0.109375)
  expect_equal(mcnemar_exact(c(TRUE, FALSE), c(TRUE, FALSE)), 1)
})

test_that("paired_bootstrap() is reproducible and sane", {
  set.seed(1)
  a <- tibble::tibble(
    actual_class = rep(c("defective", "nominal"), each = 30),
    prob_defective = c(stats::runif(30, 0.3, 1), stats::runif(30, 0, 0.7))
  )
  b <- dplyr::mutate(a, prob_defective = stats::runif(60))
  r1 <- paired_bootstrap(a, b, "mcc", times = 200)
  r2 <- paired_bootstrap(a, b, "mcc", times = 200)
  expect_equal(r1, r2)
  expect_named(r1, c("difference", "low", "high"))
  expect_lte(r1$low, r1$high)
  same <- paired_bootstrap(a, a, "bal_accuracy", times = 200)
  expect_equal(unlist(same), c(difference = 0, low = 0, high = 0))
  auc <- paired_bootstrap(a, b, "roc_auc", times = 200)
  expect_gt(auc$difference, 0)
})

test_that("undefined MCC counts as 0 and the bootstrap does not fail", {
  d <- tibble::tibble(
    actual_class = rep(c("defective", "nominal"), each = 10),
    prob_defective = rep(0.1, 20) # predicts nominal only
  )
  # yardstick warns that precision is undefined when nothing is predicted defective
  expect_equal(suppressWarnings(class_metrics(d))$mcc, 0)
  r <- paired_bootstrap(d, d, "mcc", times = 50)
  expect_false(anyNA(r))
  expect_equal(r$difference, 0)
})

test_that("paired_bootstrap() leaves the global random state alone", {
  set.seed(5)
  before <- .Random.seed
  d <- toy
  paired_bootstrap(d, d, "bal_accuracy", times = 20)
  expect_identical(.Random.seed, before)
})
