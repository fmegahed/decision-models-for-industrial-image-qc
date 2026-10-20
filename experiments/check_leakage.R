# Near-duplicate check between test and non-test images (no API calls).
# Uses a 64-bit difference hash (dHash) per image: resize to 9x8 gray, compare
# neighbor pixels. Hamming distance <= 6 of 64 bits = likely near-duplicate.
# Only pixels are compared; no labels or predictions are used.
# Run from the project root: Rscript experiments/check_leakage.R pan_images pipe_staple

datasets <- commandArgs(trailingOnly = TRUE)
splits <- readr::read_csv("results/image_split_manifest.csv", show_col_types = FALSE)
refs <- readr::read_csv("results/reference_manifest_seed202610_by_dataset.csv",
                        show_col_types = FALSE)

dhash <- function(path) {
  pixels <- magick::image_read(path) |>
    magick::image_orient() |>
    magick::image_convert(colorspace = "gray") |>
    magick::image_resize("9x8!") |>
    magick::image_data(channels = "gray") |>
    as.integer()
  pixels <- matrix(pixels, nrow = 8, ncol = 9)
  as.vector(pixels[, 2:9] > pixels[, 1:8])
}

for (dataset in datasets) {
  images <- dplyr::filter(splits, .data$dataset == .env$dataset)
  hashes <- do.call(rbind, purrr::map(images$image_path, dhash))
  test <- which(images$split == "test")
  other <- which(images$split != "test")
  # Hamming distance from every test image to every non-test image.
  distance <- outer(test, other, Vectorize(function(i, j) sum(hashes[i, ] != hashes[j, ])))
  nearest <- apply(distance, 1, min)
  pairs <- which(distance <= 6, arr.ind = TRUE)
  cat("\n==", dataset, ":", length(test), "test vs", length(other), "non-test images\n")
  cat("Nearest non-test distance per test image (quantiles):\n")
  print(stats::quantile(nearest, c(0, 0.05, 0.25, 0.5)))
  cat("Pairs with distance <= 6:", nrow(pairs), "\n")
  if (nrow(pairs)) {
    found <- tibble::tibble(
      test_image = images$image_path[test[pairs[, 1]]],
      other_image = images$image_path[other[pairs[, 2]]],
      other_is_reference = images$image_path[other[pairs[, 2]]] %in% refs$image_path,
      distance = distance[pairs]
    ) |>
      dplyr::arrange(.data$distance)
    print(found, n = 30, width = Inf)
  }
}
