# Score one configuration of the fair comparison (JEV or Clef-Flash).
#
# FAIR_MODEL=clef FAIR_DATASET=extrusion FAIR_DESCRIPTION=generic FAIR_K=2 \
#   FAIR_SPLIT=calibration JEV_CHECK_ONLY=true Rscript scripts/fair_score.R
#
# FAIR_DESCRIPTION: generic, final, or a CSV path (design split only).
# FAIR_OUT: output folder (default results/fair/scores). With a candidate CSV,
# FAIR_OUT is the loop sandbox: candidates/<n>.csv is scored into scores/<n>.csv
# and one row goes to loop_log.csv (see R/fair_loop.R). FAIR_MAP_DIR: folder of
# the image map (default results/fair/loop).
# FAIR_RECORD_ROOT: folder of calls/README.md and calls/typesafe-calls.csv.
# FAIR_TIMING_DIR (default results/fair/timing): runs.csv and clef-calls.csv.

source("R/industrial_defect_classifier.R")
source("R/fair_runner.R")
source("R/fair_loop.R")

env <- \(name, default = "") Sys.getenv(name, unset = default)
model <- env("FAIR_MODEL")
dataset <- env("FAIR_DATASET")
description <- env("FAIR_DESCRIPTION")
k <- as.integer(env("FAIR_K"))
split <- env("FAIR_SPLIT")
out <- env("FAIR_OUT", "results/fair/scores")
check_only <- identical(tolower(env("JEV_CHECK_ONLY")), "true")
settings <- model_settings(model)
stopifnot(nzchar(dataset), nzchar(description), !is.na(k))

# Only JEV runs log to the TypeSafe call log, which the budget counts.
# Clef-Flash calls go to results/fair/timing/clef-calls.csv.
if (!nzchar(env("JEV_CALL_LOG"))) {
  Sys.setenv(JEV_CALL_LOG = call_log_path(model))
}
Sys.setenv(JEV_CALL_PURPOSE = paste("fair", split, model, description_label(description),
                                    paste0("k", k), dataset))
if (model == "jev" && !check_only && !nzchar(env("TYPESAFE_API_KEY"))) {
  stop("Set TYPESAFE_API_KEY")
}

check_config(model, dataset, description, k, split, out) # clear messages first
loop_mode <- split == "design" && !description %in% c("generic", "final")
if (loop_mode) {
  n <- suppressWarnings(as.integer(tools::file_path_sans_ext(basename(description))))
  map_dir <- env("FAIR_MAP_DIR", "results/fair/loop")
  # The mirror outside the sandbox is the record of the loop.
  mirror <- file.path(map_dir, paste0(basename(normalizePath(out)), "_loop_log.csv"))
  check_candidate_slot(out, n, mirror)
  candidate <- read_candidate(description) # a bad file stops here, before any call
  check_candidate_text(n, candidate) # candidate 1 is the generic description
}
images <- fair_images(dataset, split, k)
stopifnot(nrow(images) > 0L, all(file.exists(images$image_path)))
references <- fair_references(dataset, k)
if (!is.null(references)) {
  ref_paths <- unlist(references)
  stopifnot(all(file.exists(ref_paths)))
  # Check by path AND by content: the pan copies had different paths.
  test_paths <- fair_images(dataset, "test", k)$image_path
  if (any(ref_paths %in% test_paths) ||
      any(tools::md5sum(ref_paths) %in% tools::md5sum(test_paths))) {
    stop("A reference image is also a test image")
  }
  if (any(ref_paths %in% images$image_path)) stop("A reference image is also a scored image")
}

check_run(model, dataset, description, k, split, out, n_images = nrow(images),
          check_only = check_only)
criteria <- if (loop_mode) {
  candidate[c("normal", "defective")] # the scored text is the logged text
} else {
  fair_criteria(description, model, dataset)
}
cat(model, description_label(description), paste0("k", k), dataset, split,
    "| images", nrow(images), "| references", length(unlist(references)),
    "| checks passed\n")
if (check_only) quit(save = "no")

if (loop_mode) {
  map <- readr::read_csv(file.path(map_dir, paste0(basename(normalizePath(out)), "_image_map.csv")),
                         show_col_types = FALSE)
  start <- Sys.time()
  scores <- score_images(images, references, criteria, settings, model, description, k, split)
  end <- Sys.time()
  result <- finish_candidate(out, n, scores, map, candidate, mirror = mirror)
  append_run(fair_timing_dir(), model, description, k, dataset, split, nrow(scores),
             start, end, candidate = n)
  cat("Candidate", n, "design AUC:", round(result$auc, 3), "\n")
  cat("Mean score by defect type:", result$mean_score_by_type, "\n")
  cat("Kept:", result$kept, "| current best: candidate", result$best,
      "with AUC", round(result$best_auc, 3), "\n")
  quit(save = "no")
}

scores <- score_and_write(images, references, criteria, settings, model, description,
                          k, split, out, dataset)
cat("Wrote", nrow(scores), "scores\n")
