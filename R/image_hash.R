# 64-bit difference hash (dHash) of an image: same algorithm as
# experiments/check_leakage.R. Near-copy = Hamming distance <= 6.
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

# One row of 64 bits for each path.
hash_matrix <- function(paths) {
  do.call(rbind, purrr::map(paths, dhash))
}

# Paths with a Hamming distance <= max_distance to any image of `others`.
near_copies <- function(paths, others, max_distance = 6) {
  if (length(paths) == 0 || length(others) == 0) {
    return(character())
  }
  x <- hash_matrix(paths) * 1
  y <- hash_matrix(others) * 1
  # Hamming distance = bits that differ, for all pairs at once.
  distance <- x %*% (1 - t(y)) + (1 - x) %*% t(y)
  paths[apply(distance, 1, min) <= max_distance]
}
