# Score the CLIP variants on the shared sets of the fair comparison (local GPU,
# CLIP ViT-L/14, no API call, no cost). Same score files as the decision models.
#
# RETICULATE_PYTHON=<env>/python.exe Rscript scripts/fair_clip.R
#   baseline (k 50; pans 10), refs (k 1, 2, 4) and zero (k 0), for the
#   calibration and test splits of the five datasets.
# FAIR_CLIP_TEXT=final: the zero_final variant only (text prompts from
#   results/fair/descriptions/jev_<dataset>.csv, cut at 77 tokens). It needs the
#   frozen descriptions.
# FAIR_OUT (default results/fair/scores), FAIR_DESC_DIR, FAIR_DATASETS and
# FAIR_SPLITS (comma-separated) narrow a run; the defaults are the full run.
# Run the script when no other process uses the GPU. A score file is never
# overwritten: a second run stops with a message.

source("R/fair_runner.R")
source("R/fair_clip.R")
reticulate::source_python("python/clip_functions.py")

env <- \(name, default) Sys.getenv(name, unset = default)
out <- env("FAIR_OUT", "results/fair/scores")
desc_dir <- env("FAIR_DESC_DIR", "results/fair/descriptions")
all_datasets <- c("extrusion", "microstructure", "pan_images", "pipe_staple", "textiles")
datasets <- stringr::str_split_1(env("FAIR_DATASETS", paste(all_datasets, collapse = ",")), ",")
splits <- stringr::str_split_1(env("FAIR_SPLITS", "calibration,test"), ",")
final_text <- identical(env("FAIR_CLIP_TEXT", ""), "final")
stopifnot(all(datasets %in% all_datasets), all(splits %in% c("calibration", "test")))

# The v0.0.1 zero-shot prompts, copied from scripts/run_clip.R (nominal first).
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

# One row per file to write. The baseline k is the size of L per class; the
# baseline scores the whole of C or of the test set (k_images 0: no references).
variants <- if (final_text) {
  tibble::tibble(description = "zero_final", k = 0)
} else {
  tibble::tibble(description = c("baseline", "refs", "refs", "refs", "zero"),
                 k = c(NA, 1, 2, 4, 0))
}
plan <- tidyr::expand_grid(variants, dataset = datasets, split = splits) |>
  dplyr::mutate(
    k = dplyr::if_else(.data$description == "baseline",
                       dplyr::if_else(.data$dataset == "pan_images", 10, 50), .data$k),
    k_images = dplyr::if_else(.data$description == "baseline", 0, .data$k),
    file = file.path(out, purrr::pmap_chr(
      list("clip", .data$description, .data$k, .data$dataset, .data$split), score_file_name
    ))
  )
truncation_file <- file.path(out, "clip_truncation.csv")
existing <- c(plan$file, if (final_text) truncation_file)
existing <- existing[file.exists(existing)]
if (length(existing)) {
  stop("Score files already exist (the CLIP run is one-time): ",
       paste(existing, collapse = ", "))
}
dir.create(out, recursive = TRUE, showWarnings = FALSE)

# Text prompts of the zero_final variant, and whether CLIP has to cut them:
# clip.tokenize() stops on a text of more than 77 tokens.
text_is_cut <- \(text) inherits(try(reticulate::import("clip")$tokenize(text), silent = TRUE), "try-error")
final_labels <- \(dataset) {
  d <- readr::read_csv(file.path(desc_dir, paste0("jev_", dataset, ".csv")), show_col_types = FALSE)
  c(d$normal[[1]], d$defective[[1]])
}

if (final_text) {
  purrr::map(datasets, \(d) {
    tibble::tibble(dataset = d, class = c("normal", "defective"),
                   truncated = purrr::map_lgl(final_labels(d), text_is_cut))
  }) |>
    purrr::list_rbind() |>
    readr::write_csv(truncation_file)
}

score_dataset <- function(dataset) {
  rows <- dplyr::filter(plan, .data$dataset == .env$dataset)
  learning <- read_set("learning", "results/fair/sets") |>
    dplyr::filter(.data$dataset == .env$dataset)
  scored_sets <- purrr::pmap(rows, \(split, k_images, ...) fair_images(dataset, split, k_images))
  # Each image once; as.list() keeps a single path a list for Python.
  paths <- unique(c(unlist(purrr::map(scored_sets, "image_path")), learning$image_path))
  features <- clip_encode_images(as.list(paths))
  rownames(features) <- paths
  cat(dataset, ":", length(paths), "images encoded\n")

  purrr::walk(seq_len(nrow(rows)), function(i) {
    row <- rows[i, ]
    scored <- scored_sets[[i]]
    f <- features[scored$image_path, , drop = FALSE]
    p <- if (row$description == "zero") {
      clip_zero_scores(f, prompts[[dataset]])[, 2]
    } else if (row$description == "zero_final") {
      clip_zero_scores_truncated(f, final_labels(dataset))[, 2]
    } else if (row$description == "baseline" && dataset == "pan_images" && row$split == "calibration") {
      # Pans have no C: leave-one-out on L, and the scored images are L.
      md5 <- unname(tools::md5sum(scored$image_path))
      clip_loo_probability(f, scored$actual_class, md5)
    } else {
      prototypes <- if (row$description == "baseline") {
        list(normal = learning$image_path[learning$actual_class == "nominal"],
             defective = learning$image_path[learning$actual_class == "defective"])
      } else {
        fair_references(dataset, row$k)
      }
      stopifnot(!any(scored$image_path %in% unlist(prototypes)))
      clip_few_scores(f, features[prototypes$normal, , drop = FALSE],
                      features[prototypes$defective, , drop = FALSE])[, 2]
    }
    scored |>
      dplyr::mutate(prob_defective = as.numeric(p), model = "clip",
                    description = row$description, k = row$k, split = row$split) |>
      readr::write_csv(row$file)
    cat("Wrote", nrow(scored), "scores to", row$file, "\n")
  })
}

purrr::walk(datasets, score_dataset)
