# Close a blind description loop: audit the agent transcript, copy the loop
# log and freeze the best description.
#
# Rscript scripts/fair_close_loop.R jev extrusion path/to/transcript.jsonl
#
# FAIR_SANDBOX: folder that holds the sandboxes (default ../fair-loop-sandbox).
# Writes results/fair/loop/<model>-<dataset>_log.csv and _audit.csv, and
# results/fair/descriptions/<model>_<dataset>.csv. It refuses to overwrite a
# frozen description.

source("R/fair_runner.R")
source("R/fair_loop.R")

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 3L, file.exists(args[[3]]))
sandbox <- file.path(Sys.getenv("FAIR_SANDBOX", unset = "../fair-loop-sandbox"),
                     paste0(args[[1]], "-", args[[2]]))
stopifnot(dir.exists(sandbox))
res <- close_loop(args[[1]], args[[2]], args[[3]], sandbox)
cat("Frozen candidate", res$best, "with design AUC", round(res$best_auc, 3), "\n")
if (res$audit_rows == 0L) {
  cat("Audit: no call outside the sandbox. The loop was blind.\n")
} else {
  cat("Audit:", res$audit_rows, "call(s) outside the sandbox. See the audit file.\n")
}
