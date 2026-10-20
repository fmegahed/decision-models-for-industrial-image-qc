# Replicate the few-shot CLIP protocol of Megahed et al. (2025, arXiv:2501.12596)
# on our test partition, with the learning-set size the paper reports for each
# experiment (local model, no API calls).
# Decision rule as in the paper: the class with the higher maximum cosine
# similarity (defect score > 0.5). Learning images come from the non-test pool
# only. pan uses all 20 train images and pipe_staple the first 50 sorted images
# of each class, exactly as in the paper. The other datasets sample the paper's
# counts from our non-test pool with seed 202610 (the paper sampled with Python's
# random.seed(2024), so the images differ but the sizes match).
#
# RETICULATE_PYTHON=<env>/python.exe Rscript scripts/run_clip_paper.R

reticulate::source_python("python/clip_functions.py") # the qmd's CLIP functions
seed <- 202610L

# One row per (setting, defect type). The paper's results are for reference only:
# for extrusion, textiles and microstructure the paper's test images differ.
plan <- tibble::tribble(
  ~setting,          ~dataset,         ~defect_type,           ~n,
  "pan_10",          "pan_images",     "nominal",              10,
  "pan_10",          "pan_images",     "defective",            10,
  "pipe_staple_50",  "pipe_staple",    "good",                 50,
  "pipe_staple_50",  "pipe_staple",    "missing",              50,
  "textiles_50",     "textiles",       "nominal",              50,
  "textiles_50",     "textiles",       "global",               25,
  "textiles_50",     "textiles",       "local",                25,
  "extrusion_200",   "extrusion",      "normal",              200,
  "extrusion_200",   "extrusion",      "over",                100,
  "extrusion_200",   "extrusion",      "under",               100,
  "extrusion_350",   "extrusion",      "normal",              350,
  "extrusion_350",   "extrusion",      "over",                175,
  "extrusion_350",   "extrusion",      "under",               175,
  "microstructure_72", "microstructure", "Uniform",            72
) |>
  dplyr::bind_rows(tibble::tibble(
    setting = "microstructure_72", dataset = "microstructure",
    defect_type = paste0(rep(c("Band", "Bimodal", "SingleCrystal"), each = 3), "_",
                         c("high", "low", "medium")),
    n = 8
  ))

paper <- tibble::tribble(
  ~setting,            ~paper_learning,                         ~paper_accuracy, ~paper_sensitivity, ~paper_specificity, ~paper_auc,
  "pan_10",            "10 per class (Section 4)",              0.910,           0.821,              1.000,              0.998,
  "pipe_staple_50",    "first 50 per class (Section 7)",        0.580,           0.560,              0.600,              0.608,
  "textiles_50",       "50 per class: 97% accuracy (Sec. 9.1)",  0.97,            NA,                 NA,                 NA,
  "extrusion_200",     "plateau beyond 200 per class (Sec. 5)", NA,              NA,                 NA,                 NA,
  "extrusion_350",     "350 per class: 80% accuracy (Sec. 5)",  0.80,            0.78,               0.81,               NA,
  "microstructure_72", "72 nominal, 8 per defect type (Sec. 8)", 0.898,          0.987,              0.809,              0.952
)

splits <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE) |>
  dplyr::mutate(md5 = unname(tools::md5sum(.data$image_path)))
# Extrusion video frames include byte-identical copies across splits (3 test
# frames have a copy in the pool), so the pool also drops copies of test images.
pool <- dplyr::filter(splits, .data$split != "test", !.data$md5 %in% .data$md5[.data$split == "test"])

learning <- purrr::pmap_dfr(plan, function(setting, dataset, defect_type, n) {
  candidates <- pool |>
    dplyr::filter(.data$dataset == .env$dataset, .data$defect_type == .env$defect_type) |>
    dplyr::arrange(.data$image_name)
  if (nrow(candidates) < n) stop("Not enough non-test images for ", setting, " ", defect_type)
  chosen <- if (dataset %in% c("pan_images", "pipe_staple")) {
    candidates$image_path[seq_len(n)] # pan: all train images; pipe: first n sorted
  } else {
    set.seed(seed)
    sample(candidates$image_path)[seq_len(n)]
  }
  tibble::tibble(setting = setting, dataset = dataset, defect_type = defect_type,
                 actual_class = candidates$actual_class[[1]], image_path = chosen)
})

output_dir <- file.path("results", "clip_paper")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(learning, file.path(output_dir, "learning_sets.csv"))

auc <- function(p, y) mean(outer(p[y == 1], p[y == 0], ">") + 0.5 * outer(p[y == 1], p[y == 0], "=="))
# as.list(): a length-1 character vector would reach Python as a string, not a list.
encode <- function(paths) clip_encode_images(as.list(paths))

summary <- purrr::map_dfr(unique(plan$setting), function(setting) {
  learn <- dplyr::filter(learning, .data$setting == .env$setting)
  dataset <- learn$dataset[[1]]
  test <- dplyr::filter(splits, .data$dataset == .env$dataset, .data$split == "test")
  stopifnot(!any(learn$image_path %in% test$image_path),
            !any(tools::md5sum(learn$image_path) %in% tools::md5sum(test$image_path)))

  scores <- clip_few_scores(encode(test$image_path),
                            encode(learn$image_path[learn$actual_class == "nominal"]),
                            encode(learn$image_path[learn$actual_class == "defective"]))
  p <- as.numeric(scores[, 2])
  y <- as.integer(test$actual_class == "defective")
  test |>
    dplyr::select("dataset", "image_path", "defect_type", "actual_class") |>
    dplyr::mutate(prob_defective = p, predicted_class = dplyr::if_else(p > 0.5, "defective", "nominal")) |>
    readr::write_csv(file.path(output_dir, paste0(setting, "_test_predictions.csv")))
  cat(setting, "done\n")
  sens <- mean(p[y == 1] > 0.5)
  spec <- mean(p[y == 0] <= 0.5)
  tibble::tibble(
    setting = setting, dataset = dataset,
    n_learning_nominal = sum(learn$actual_class == "nominal"),
    n_learning_defective = sum(learn$actual_class == "defective"),
    n_test = length(y), accuracy = mean((p > 0.5) == (y == 1)),
    balanced_accuracy = (sens + spec) / 2, sensitivity = sens, specificity = spec, roc_auc = auc(p, y)
  )
}) |>
  dplyr::left_join(paper, by = "setting")

readr::write_csv(summary, file.path(output_dir, "summary.csv"))
print(as.data.frame(summary), digits = 3)
