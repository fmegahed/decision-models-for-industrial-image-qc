# Draw the shared learning (L), calibration (C), reference and design sets.
# Run from the repository root: Rscript scripts/fair_draw_sets.R
source("R/image_hash.R")
source("R/fair_sets.R")

# Near-copy rule of each dataset. dhash6 (dHash distance <= 6) only fits
# extrusion, whose frames come from video. The other datasets show one fixed
# scene, so dHash flags the scene; they exclude byte-identical copies only.
rules <- c(
  extrusion = "dhash6", textiles = "md5", pipe_staple = "md5",
  microstructure = "md5"
)

out_dir <- file.path("results", "fair", "sets")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cols <- c("dataset", "image_path", "defect_type", "actual_class")

manifest <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE)
learning <- readr::read_csv("results/clip_paper/learning_sets.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$setting %in% c(
    "pan_10", "extrusion_50", "textiles_50", "pipe_staple_50", "microstructure_50"
  )) |>
  dplyr::select(dplyr::all_of(cols)) |>
  dplyr::arrange(.data$dataset, .data$actual_class, .data$image_path)

# Calibration: non-test images outside L, without near-copies of L or test.
draw_dataset <- function(name) {
  images <- dplyr::filter(manifest, .data$dataset == name)
  in_learning <- learning$image_path[learning$dataset == name]
  test <- images$image_path[images$split == "test"]
  pool <- images |>
    dplyr::filter(.data$split != "test", !.data$image_path %in% in_learning) |>
    dplyr::select(dplyr::all_of(cols))
  rule <- rules[[name]]
  exclude <- if (rule == "dhash6") {
    near_copies(pool$image_path, c(in_learning, test))
  } else {
    md5_copies(pool$image_path, c(in_learning, test))
  }
  drawn <- draw_calibration(pool, n_per_class = 25, seed = 202611, exclude = exclude)
  list(
    drawn = drawn,
    report = draw_report(pool, drawn, exclude = exclude, n_per_class = 25,
                         rule = rule)
  )
}

datasets <- names(rules)
results <- purrr::map(datasets, draw_dataset)
calibration <- purrr::map(results, "drawn") |> purrr::list_rbind()
report <- purrr::map(results, "report") |> purrr::list_rbind()

references <- draw_references(learning, k_max = 4, seed = 202610)
design <- learning |>
  dplyr::filter(.data$dataset != "pan_images") |>
  dplyr::anti_join(dplyr::filter(references, .data$rank <= 2), by = "image_path")

readr::write_csv(learning, file.path(out_dir, "learning.csv"))
readr::write_csv(calibration, file.path(out_dir, "calibration.csv"))
readr::write_csv(references, file.path(out_dir, "references.csv"))
readr::write_csv(design, file.path(out_dir, "design.csv"))
readr::write_csv(report, file.path(out_dir, "draw_report.csv"))

print(report, n = Inf)
print(dplyr::count(calibration, .data$dataset, .data$actual_class, .data$defect_type), n = Inf)
