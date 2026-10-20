# A tuned threshold for CLIP with the learning sets of the CLIP paper (local
# model, no API calls). The other methods tune their threshold on our
# validation images (midpoint of the widest run of cut points that reach the
# maximum balanced accuracy). These learning sets hold most of our validation
# images (all 16 for pans), so the threshold is tuned on leave-one-out scores
# of the learning set instead: each learning image is scored against the other
# learning images, as a test image is scored against all of them. CLIP gets no
# extra labels. Images with the same MD5 (identical video frames) are left out
# together, so a copy cannot score its twin.
#
# The test scores are not computed again: the threshold is applied to the
# saved test predictions of scripts/run_clip_paper.R.
#
# RETICULATE_PYTHON=<env>/python.exe Rscript scripts/run_clip_paper_threshold.R

reticulate::source_python("python/clip_functions.py") # the qmd's CLIP functions
cat("CLIP device:", reticulate::py$clip_device, "\n")

# Same rule as scripts/run_clip.R.
tune_threshold <- function(p, y) {
  cuts <- sort(unique(p))
  candidates <- c(cuts[1] - 1e-9, (utils::head(cuts, -1) + utils::tail(cuts, -1)) / 2,
                  utils::tail(cuts, 1) + 1e-9)
  ba <- vapply(candidates, function(t) (mean(p[y == 1] >= t) + mean(p[y == 0] < t)) / 2,
               numeric(1))
  runs <- rle(abs(ba - max(ba)) < 1e-12)
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1
  k <- which(runs$values)[which.max(runs$lengths[runs$values])]
  (candidates[starts[k]] + candidates[ends[k]]) / 2
}
balanced_accuracy <- function(p, y, t) (mean(p[y == 1] >= t) + mean(p[y == 0] < t)) / 2
auc <- function(p, y) mean(outer(p[y == 1], p[y == 0], ">") + 0.5 * outer(p[y == 1], p[y == 0], "=="))

# Inputs are the outputs of scripts/run_clip_paper.R in the same results root.
results_root <- Sys.getenv("JEV_RESULTS_ROOT", unset = "results")
output_dir <- file.path(results_root, "clip_paper")
input_dir <- output_dir
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

learning <- readr::read_csv(file.path(input_dir, "learning_sets.csv"), show_col_types = FALSE)

# Encode each learning image once (extrusion_200 is part of extrusion_350).
# as.list(): a length-1 character vector would reach Python as a string.
paths <- unique(learning$image_path)
features <- clip_encode_images(as.list(paths))
rownames(features) <- paths
md5 <- unname(tools::md5sum(paths))
names(md5) <- paths

summary <- purrr::map_dfr(unique(learning$setting), function(setting) {
  learn <- dplyr::filter(learning, .data$setting == .env$setting)
  f <- features[learn$image_path, , drop = FALSE]
  y <- as.integer(learn$actual_class == "defective")

  # Leave-one-out: no image is compared with itself or with a copy of itself.
  sims <- f %*% t(f)
  same <- outer(md5[learn$image_path], md5[learn$image_path], "==")
  sims[same] <- -Inf
  normal_max <- apply(sims[, y == 0, drop = FALSE], 1, max)
  defective_max <- apply(sims[, y == 1, drop = FALSE], 1, max)
  # The score of clip_few_scores(): softmax of the two maximum similarities.
  p_loo <- stats::plogis(defective_max - normal_max)
  threshold <- tune_threshold(p_loo, y)

  learn |>
    dplyr::select("setting", "image_path", "actual_class") |>
    dplyr::mutate(prob_defective_loo = p_loo) |>
    readr::write_csv(file.path(output_dir, paste0(setting, "_learning_loo_scores.csv")))

  test <- readr::read_csv(file.path(input_dir, paste0(setting, "_test_predictions.csv")),
                          show_col_types = FALSE)
  y_test <- as.integer(test$actual_class == "defective")
  cat(setting, "done\n")
  tibble::tibble(
    setting = setting,
    dataset = learn$dataset[[1]],
    n_learning = nrow(learn),
    threshold = threshold,
    rule = "leave-one-out on the learning set",
    loo_auc = auc(p_loo, y),
    loo_balanced_accuracy = balanced_accuracy(p_loo, y, threshold),
    test_balanced_accuracy = balanced_accuracy(test$prob_defective, y_test, threshold),
    test_balanced_accuracy_paper_rule = balanced_accuracy(test$prob_defective, y_test, 0.5 + 1e-12)
  )
})

readr::write_csv(summary, file.path(output_dir, "tuned_thresholds.csv"))
print(as.data.frame(summary), digits = 3)
