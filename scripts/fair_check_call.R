# One check call before the paid runs (plan Task 8): does the model accept
# k references per class in one call (k = 4: 9 images)?
#
# JEV_CHECK_ONLY=true Rscript scripts/fair_check_call.R jev 4
#
# MODEL: jev or clef. K: 0, 1, 2 or 4. The script makes ONE classify_image()
# call on one design image of extrusion (not a reference at k), with the
# generic description and k references per class. The purpose of the call is
# "fair check <model> k<k>". A JEV call goes to
# <FAIR_RECORD_ROOT>/calls/typesafe-calls.csv and counts against the "Fair
# comparison" budget row (a paid call needs FAIR_RECORD_ROOT); a Clef-Flash
# call goes to FAIR_TIMING_DIR/clef-calls.csv. The script writes nothing else:
# no score file, no runs.csv row and no loop file. It prints the probability,
# the latency and, for JEV, the tokens and the estimated cost.
# JEV_CHECK_ONLY=true runs the checks only (no call).

source("R/industrial_defect_classifier.R")
source("R/fair_runner.R")

check_only <- check_only_mode() # a bad value stops here, first
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript scripts/fair_check_call.R MODEL K")
check_call(args[[1]], suppressWarnings(as.integer(args[[2]])), check_only = check_only)
