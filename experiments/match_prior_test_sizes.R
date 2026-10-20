# Match the prior CLIP study's test sets (user decisions, 2026-10-20). Run once.
# 1. pan_images: delete test/nominal/21.JPG, which the prior study's test folder
#    (github.com/fmegahed/qe_genai, data/pan_images/test) does not have. A copy
#    stays in Y:/My Drive/Miami/Code/GitHub/imagejev/imgs.
# 2. textiles_real: add the 100 real textile images as a TEST-only dataset
#    (icImgs = nominal, ocImgs = defective), as in the prior study's transfer test.

manifest_file <- "results/image_split_manifest.csv"
splits <- readr::read_csv(manifest_file, show_col_types = FALSE)

extra <- "imgs/pan_images/test/nominal/21.JPG"
stopifnot(extra %in% splits$image_path)
if (file.exists(extra)) stopifnot(file.remove(extra)) # a first, failed run already deleted it
splits <- dplyr::filter(splits, .data$image_path != extra)

real <- purrr::imap_dfr(c(icImgs = "nominal", ocImgs = "defective"), function(class, folder) {
  paths <- sort(list.files(file.path("imgs", "textile_images", folder),
                           pattern = "\\.(jpg|jpeg|png)$", full.names = TRUE, ignore.case = TRUE))
  tibble::tibble(dataset = "textiles_real", image_name = basename(paths), image_path = paths,
                 defect_type = folder, actual_class = class, split = "test")
})
stopifnot(nrow(real) == 100L, !any(real$image_path %in% splits$image_path))
splits <- dplyr::bind_rows(splits, real)
stopifnot(!anyDuplicated(splits$image_path), all(file.exists(splits$image_path)))
readr::write_csv(splits, manifest_file)

print(splits |> dplyr::filter(.data$split == "test") |> dplyr::count(.data$dataset, .data$actual_class), n = 20)
