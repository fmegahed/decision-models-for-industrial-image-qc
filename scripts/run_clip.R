# CLIP ViT-L/14 on the same test partition and the same reference images as
# JEV (local model, no API calls). Method and prompts are those of
# clip_image_inspection.qmd (Y: project, unchanged): zero-shot image-text
# softmax, and reference-guided softmax over the maximum cosine similarity to
# each class's reference images.
# Two decision rules: the qmd's rule (defect score > normal score, i.e. 0.5) and
# a threshold tuned on the same validation images as JEV (midpoint of the
# widest run of cut points that reach the maximum validation BA). The test
# images are scored once and never used to choose anything.
#
# RETICULATE_PYTHON=<env>/python.exe Rscript scripts/run_clip.R

reticulate::source_python("python/clip_functions.py") # the qmd's CLIP functions
cat("CLIP device:", reticulate::py$clip_device, "\n")

# Prompts copied from clip_image_inspection.qmd (nominal first, defective second).
prompts <- list(
  pan_images = c(
    "A metallic pan free of black scuff marks",
    "A metallic pan with a simulated scuff mark drawn by a black marker"
  ),
  extrusion = c(
    "An image of a normal extrusion profile from an additive manufacturing process",
    "An image of an over-extruded or under-extruded profile from an additive manufacturing process"
  ),
  textiles = c(
    "An image of a textile material with consistent weave patterns, showing no visible defects or irregularities.",
    "A woven textile, featuring a visible tear, defect, or a disruption in the material's weave structure."
  ),
  pipe_staple = c(
    "A close-up of an automotive assembly process showing a flexible cable secured by a metallic rectangular clamp with rounded edges.",
    "A close-up of an automotive assembly process focusing on a flexible cable, where the clamp that typically secures the pipe during assembly is notably absent."
  ),
  microstructure = c(
    "A microstructure image showing a uniform microstructure.",
    "A microstructure image showing a non-uniform microstructure with banding, bimodality, or single-crystal features."
  )
)

tune_threshold <- function(p, y) {
  cuts <- sort(unique(p))
  candidates <- c(cuts[1] - 1e-9, (utils::head(cuts, -1) + utils::tail(cuts, -1)) / 2, utils::tail(cuts, 1) + 1e-9)
  ba <- vapply(candidates, function(t) (mean(p[y == 1] >= t) + mean(p[y == 0] < t)) / 2, numeric(1))
  runs <- rle(abs(ba - max(ba)) < 1e-12)
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1
  k <- which(runs$values)[which.max(runs$lengths[runs$values])]
  (candidates[starts[k]] + candidates[ends[k]]) / 2
}

score <- function(p, y, t) {
  sens <- mean(p[y == 1] >= t)
  spec <- mean(p[y == 0] < t)
  tibble::tibble(threshold = t, balanced_accuracy = (sens + spec) / 2, sensitivity = sens, specificity = spec)
}

auc <- function(p, y) { # Mann-Whitney form, ties count one half
  pos <- p[y == 1]
  neg <- p[y == 0]
  mean(outer(pos, neg, ">") + 0.5 * outer(pos, neg, "=="))
}

splits <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE)
references <- readr::read_csv("results/reference_manifest_seed202610_by_dataset.csv", show_col_types = FALSE)
frozen <- readr::read_csv("results/optimization/frozen_configs.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$condition == "references")
results_root <- Sys.getenv("JEV_RESULTS_ROOT", unset = "results") # outputs only; inputs stay in results/
output_dir <- file.path(results_root, "clip")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

summary <- list()
for (i in seq_len(nrow(frozen))) {
  dataset <- frozen$dataset[[i]]
  tuned_on <- frozen$tuned_on[[i]]
  test <- dplyr::filter(splits, .data$dataset == .env$dataset, .data$split == "test")
  validation <- readr::read_csv(file.path("results", "optimization", tuned_on, "validation_images.csv"),
                                show_col_types = FALSE)
  refs <- dplyr::filter(references, .data$dataset == .env$tuned_on)
  stopifnot(!any(tools::md5sum(refs$image_path) %in% tools::md5sum(test$image_path)),
            !any(validation$image_path %in% test$image_path))

  # as.list(): a length-1 character vector would reach Python as a string, not a list.
  encode <- function(paths) reticulate::py$clip_encode_images(as.list(paths))
  normal <- encode(refs$image_path[refs$reference_class == "normal"])
  defective <- encode(refs$image_path[refs$reference_class == "defective"])
  test_features <- encode(test$image_path)
  validation_features <- encode(validation$image_path)
  y_test <- as.integer(test$actual_class == "defective")
  y_validation <- as.integer(validation$actual_class == "defective")

  conditions <- list(
    zero_shot = function(features) reticulate::py$clip_zero_scores(features, prompts[[tuned_on]])[, 2],
    references = function(features) reticulate::py$clip_few_scores(features, normal, defective)[, 2]
  )
  for (condition in names(conditions)) {
    p_test <- as.numeric(conditions[[condition]](test_features))
    p_validation <- as.numeric(conditions[[condition]](validation_features))
    tuned <- tune_threshold(p_validation, y_validation)

    test |>
      dplyr::select("dataset", "image_path", "defect_type", "actual_class") |>
      dplyr::mutate(prob_defective = p_test,
                    predicted_050 = dplyr::if_else(p_test > 0.5, "defective", "nominal"),
                    predicted_tuned = dplyr::if_else(p_test >= tuned, "defective", "nominal")) |>
      readr::write_csv(file.path(output_dir, paste0(dataset, "_", condition, "_test_predictions.csv")))

    summary[[paste(dataset, condition)]] <- dplyr::bind_rows(
      dplyr::mutate(score(p_test, y_test, 0.5 + 1e-12), rule = "qmd rule (0.5)"),
      dplyr::mutate(score(p_test, y_test, tuned), rule = "tuned on validation")
    ) |>
      dplyr::mutate(dataset = dataset, model = "CLIP ViT-L/14", condition = condition,
                    n_test = length(y_test), roc_auc = auc(p_test, y_test),
                    validation_auc = auc(p_validation, y_validation), .before = 1)
  }
  cat(dataset, "done\n")
}

summary <- dplyr::bind_rows(summary)
readr::write_csv(summary, file.path(output_dir, "summary.csv"))
print(as.data.frame(summary), digits = 3)
