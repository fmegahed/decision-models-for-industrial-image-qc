# Evaluate every configuration of the fair comparison (no API call).
# Platt (main) and isotonic (sensitivity) are fitted on the calibration file of
# the same configuration; the decision is at 0.5. Paired comparisons P1 to P3
# and the k-curve use the Platt probabilities. Writes metrics.csv, paired.csv
# and k_curve.csv, plus timing.csv (time per image, total time and JEV cost).
# A comparison runs only when both of its sides exist.
#
# Rscript scripts/fair_evaluate.R
# FAIR_SCORES (default results/fair/scores), FAIR_SUMMARY (default
# results/fair/summary) and FAIR_BOOT (default 2000 resamples) change the defaults.
# FAIR_TIMING_DIR (default results/fair/timing) holds runs.csv and
# clip_timing.csv; FAIR_RECORD_ROOT holds calls/typesafe-calls.csv.

source("R/evaluation.R")
source("R/calibration_functions.R")
source("R/fair_evaluate.R")
source("R/fair_runner.R") # fair_record_root(), fair_timing_dir()

env <- \(name, default) Sys.getenv(name, unset = default)
out <- run_fair_evaluation(
  env("FAIR_SCORES", "results/fair/scores"),
  env("FAIR_SUMMARY", "results/fair/summary"),
  times = as.integer(env("FAIR_BOOT", "2000")),
  timing_dir = fair_timing_dir(),
  record_root = fair_record_root()
)
cat("metrics rows:", nrow(out$metrics), "\npaired rows:", nrow(out$paired),
    "\nk-curve rows:", nrow(out$k_curve), "\ntiming rows:", nrow(out$timing), "\n")
