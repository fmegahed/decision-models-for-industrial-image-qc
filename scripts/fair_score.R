# Score one configuration of the fair comparison (JEV or Clef-Flash).
#
# FAIR_MODEL=clef FAIR_DATASET=extrusion FAIR_DESCRIPTION=generic FAIR_K=2 \
#   FAIR_SPLIT=calibration JEV_CHECK_ONLY=true Rscript scripts/fair_score.R
#
# FAIR_DESCRIPTION: generic, final, or a CSV path (design split only).
# FAIR_OUT: output folder (default results/fair/scores).
# FAIR_RECORD_ROOT: folder of calls/README.md and calls/typesafe-calls.csv.

source("R/industrial_defect_classifier.R")
source("R/fair_runner.R")

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

if (!nzchar(env("JEV_CALL_LOG"))) {
  Sys.setenv(JEV_CALL_LOG = file.path(fair_record_root(), "calls", "typesafe-calls.csv"))
}
Sys.setenv(JEV_CALL_PURPOSE = paste("fair", split, model, description_label(description),
                                    paste0("k", k), dataset))
if (model == "jev" && !check_only && !nzchar(env("TYPESAFE_API_KEY"))) {
  stop("Set TYPESAFE_API_KEY")
}

check_config(model, dataset, description, k, split, out) # clear messages first
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
criteria <- fair_criteria(description, model, dataset)
cat(model, description_label(description), paste0("k", k), dataset, split,
    "| images", nrow(images), "| references", length(unlist(references)),
    "| checks passed\n")
if (check_only) quit(save = "no")

scores <- score_and_write(images, references, criteria, settings, model, description,
                          k, split, out, dataset)
cat("Wrote", nrow(scores), "scores\n")
