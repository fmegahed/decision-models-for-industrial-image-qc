# Evaluate every configuration of the fair comparison (no API call).
# Platt (main) and isotonic (sensitivity) are fitted on the calibration file of
# the same configuration; the decision is at 0.5. Paired comparisons P1 to P3
# and the k-curve use the Platt probabilities. Writes metrics.csv, paired.csv
# and k_curve.csv. A comparison runs only when both of its sides exist.
#
# Rscript scripts/fair_evaluate.R
# FAIR_SCORES (default results/fair/scores), FAIR_SUMMARY (default
# results/fair/summary) and FAIR_BOOT (default 2000 resamples) change the defaults.

source("R/evaluation.R")
source("R/calibration_functions.R")
source("R/fair_evaluate.R")

env <- \(name, default) Sys.getenv(name, unset = default)
out <- run_fair_evaluation(
  env("FAIR_SCORES", "results/fair/scores"),
  env("FAIR_SUMMARY", "results/fair/summary"),
  times = as.integer(env("FAIR_BOOT", "2000"))
)
cat("metrics rows:", nrow(out$metrics), "\npaired rows:", nrow(out$paired),
    "\nk-curve rows:", nrow(out$k_curve), "\n")
