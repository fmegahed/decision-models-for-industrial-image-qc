# Time per image of the CLIP variants on the test images (local GPU, CLIP
# ViT-L/14, no API call, no cost). It does not touch the CLIP score files.
#
# RETICULATE_PYTHON=<env>/python.exe Rscript scripts/fair_clip_timing.R
#   Variants: baseline (k 50; pans 10), refs (k 1, 2, 4) and zero (k 0).
#   For each test image and variant, it measures
#   - encode_ms: load the image, prepare it and encode it (clip_encode_images),
#   - score_ms: score the encoded image (clip_few_scores or clip_zero_scores).
#   The features of the reference and learning images are encoded once before
#   the timing and do not count. The zero-shot score includes the encoding of
#   the two text prompts, as in the scoring run. One warm-up image runs once first
#   (the first GPU call is slower). The seconds in runs.csv are the wall time of
#   the whole pass of a variant, with the encoding of its prototypes.
# Writes clip_timing.csv (variant, k, dataset, image_path, encode_ms, score_ms)
# and one row per variant and dataset to runs.csv, both in FAIR_TIMING_DIR
# (default results/fair/timing). FAIR_DATASETS (comma-separated) and FAIR_TIMING_N
# (images per dataset; default all) narrow a run. A second run stops: delete
# clip_timing.csv and its rows of runs.csv first.
# Run the script when no other process uses the GPU.

source("R/fair_runner.R")
source("R/fair_clip.R")
reticulate::source_python("python/clip_functions.py")

env <- \(name, default) Sys.getenv(name, unset = default)
timing_dir <- fair_timing_dir()
all_datasets <- c("extrusion", "microstructure", "pan_images", "pipe_staple", "textiles")
datasets <- stringr::str_split_1(env("FAIR_DATASETS", paste(all_datasets, collapse = ",")), ",")
n_max <- as.integer(env("FAIR_TIMING_N", "0"))
stopifnot(all(datasets %in% all_datasets))
timing_file <- file.path(timing_dir, "clip_timing.csv")
if (file.exists(timing_file)) {
  stop("The timing file exists: ", timing_file, ". Delete it and its rows in runs.csv first.")
}
dir.create(timing_dir, recursive = TRUE, showWarnings = FALSE)

# Milliseconds of one expression.
time_ms <- function(expr) {
  start <- as.numeric(Sys.time())
  value <- expr
  list(ms = (as.numeric(Sys.time()) - start) * 1000, value = value)
}

variants <- tibble::tibble(variant = c("baseline", "refs", "refs", "refs", "zero"),
                           k = c(NA, 1, 2, 4, 0))
hardware <- gpu_name()
learning <- read_set("learning", "results/fair/sets")

# One variant on one dataset: one row per test image.
time_variant <- function(variant, k, dataset, images, prompts_text) {
  prototypes <- if (variant == "baseline") {
    l <- dplyr::filter(learning, .data$dataset == .env$dataset)
    list(normal = l$image_path[l$actual_class == "nominal"],
         defective = l$image_path[l$actual_class == "defective"])
  } else if (variant == "refs") {
    fair_references(dataset, k)
  }
  # The prototype features are encoded once and do not count.
  proto_features <- purrr::map(prototypes, \(p) clip_encode_images(as.list(p)))
  score <- function(f) {
    if (variant == "zero") {
      clip_zero_scores(f, prompts_text)
    } else {
      clip_few_scores(f, proto_features$normal, proto_features$defective)
    }
  }
  purrr::map(images$image_path, \(path) {
    encoded <- time_ms(clip_encode_images(as.list(path)))
    scored <- time_ms(score(encoded$value))
    tibble::tibble(image_path = path, encode_ms = round(encoded$ms, 2),
                   score_ms = round(scored$ms, 2))
  }) |>
    purrr::list_rbind()
}

# Warm-up, once: the first encoding and the first scoring on the GPU are slower.
first <- fair_images(datasets[[1]], "test", 0)$image_path[[1]]
warm <- clip_encode_images(as.list(first))
invisible(clip_zero_scores(warm, clip_prompts[[datasets[[1]]]]))

timings <- purrr::map(datasets, \(dataset) {
  # The images are the test images of the CLIP scoring run (k 0: no references).
  images <- fair_images(dataset, "test", 0)
  if (n_max > 0) images <- utils::head(images, n_max)
  purrr::pmap(variants, \(variant, k) {
    k <- if (variant == "baseline") (if (dataset == "pan_images") 10 else 50) else k
    start <- Sys.time()
    rows <- time_variant(variant, k, dataset, images, clip_prompts[[dataset]])
    end <- Sys.time()
    append_run(timing_dir, "clip", variant, k, dataset, "test", nrow(rows), start, end,
               hardware = hardware)
    cat(dataset, variant, paste0("k", k), ":", nrow(rows), "images, median",
        stats::median(rows$encode_ms + rows$score_ms), "ms\n")
    dplyr::mutate(rows, variant = variant, k = k, dataset = dataset, .before = 1)
  }) |>
    purrr::list_rbind()
}) |>
  purrr::list_rbind()

timings |>
  dplyr::select("variant", "k", "dataset", "image_path", "encode_ms", "score_ms") |>
  readr::write_csv(timing_file)
cat("Wrote", nrow(timings), "rows to", timing_file, "\n")
