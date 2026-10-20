# Build alternative reference manifests for reference trials (no API calls).
# Same selection rule as the qmd: sort the paths, set the seed, take the first
# draw. The pool excludes test images AND the frozen validation images.
# Run from the project root.

seed <- 202610L
splits <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE)
start_refs <- readr::read_csv("results/reference_manifest_seed202610_by_dataset.csv",
                              show_col_types = FALSE)

choose_one <- function(dataset, folder, exclude = character()) {
  validation <- readr::read_csv(
    file.path("results", "optimization", dataset, "validation_images.csv"),
    show_col_types = FALSE
  )
  paths <- splits |>
    dplyr::filter(.data$dataset == .env$dataset, .data$split != "test",
                  .data$defect_type == .env$folder,
                  !.data$image_path %in% validation$image_path,
                  !.data$image_path %in% .env$exclude) |>
    dplyr::pull("image_path") |>
    sort()
  set.seed(seed)
  sample(paths)[[1]]
}

# Keep the starting nominal reference; give one defective reference per folder.
make_set <- function(dataset, folders, file) {
  nominal <- start_refs |>
    dplyr::filter(.data$dataset == .env$dataset, .data$reference_class == "normal")
  # Choose outside tibble(): inside it, `dataset` would be the new column.
  paths <- purrr::map_chr(folders, \(folder) choose_one(dataset, folder))
  defective <- tibble::tibble(
    dataset = dataset, reference_class = "defective",
    reference_rank = seq_along(folders), image_path = paths
  )
  refs <- dplyr::bind_rows(nominal, defective)
  readr::write_csv(refs, file)
  print(refs)
}

make_set("microstructure", c("Band_low", "Bimodal_low", "SingleCrystal_low"),
         "experiments/microstructure_refs_low.csv")
make_set("microstructure",
         c("Band_low", "Band_medium", "Band_high", "Bimodal_low", "Bimodal_medium",
           "Bimodal_high", "SingleCrystal_low", "SingleCrystal_medium", "SingleCrystal_high"),
         "experiments/microstructure_refs_all9.csv")

# Textiles: keep the starting references and add one nominal and one global
# image, because the global defect is the one the model misses.
textile_start <- dplyr::filter(start_refs, .data$dataset == "textiles")
extra <- c(choose_one("textiles", "nominal", exclude = textile_start$image_path),
           choose_one("textiles", "global", exclude = textile_start$image_path))
textile_refs <- dplyr::bind_rows(textile_start, tibble::tibble(
  dataset = "textiles", reference_class = c("normal", "defective"),
  reference_rank = c(2, 3), image_path = extra
))
readr::write_csv(textile_refs, "experiments/textiles_refs_global2.csv")
print(textile_refs)
