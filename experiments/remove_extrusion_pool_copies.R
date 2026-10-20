# Remove the extrusion pool frames that are byte-identical to test frames
# (user decision, 2026-10-20). The test set does not change. The files and their
# manifest rows go; copies stay in Y:/My Drive/Miami/Code/GitHub/imagejev/imgs.
# Run once from the project root.

manifest_file <- "results/image_split_manifest.csv"
splits <- readr::read_csv(manifest_file, show_col_types = FALSE)
extrusion <- splits |>
  dplyr::filter(.data$dataset == "extrusion") |>
  dplyr::mutate(md5 = unname(tools::md5sum(.data$image_path)))
test_md5 <- extrusion$md5[extrusion$split == "test"]
remove <- dplyr::filter(extrusion, .data$split != "test", .data$md5 %in% test_md5)

used <- c(
  readr::read_csv("results/optimization/extrusion/validation_images.csv", show_col_types = FALSE)$image_path,
  readr::read_csv("results/reference_manifest_seed202610_by_dataset.csv", show_col_types = FALSE)$image_path,
  readr::read_csv("results/clip_paper/learning_sets.csv", show_col_types = FALSE)$image_path
)
stopifnot(nrow(remove) == 3L, !any(remove$image_path %in% used))
print(dplyr::select(remove, "image_path", "defect_type", "md5"))

stopifnot(all(file.remove(remove$image_path)))
splits |>
  dplyr::filter(!.data$image_path %in% remove$image_path) |>
  readr::write_csv(manifest_file)
cat("Removed", nrow(remove), "pool frames. Extrusion rows now:",
    sum(readr::read_csv(manifest_file, show_col_types = FALSE)$dataset == "extrusion"), "\n")
