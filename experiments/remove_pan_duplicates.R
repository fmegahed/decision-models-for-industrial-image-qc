# Remove duplicate pan images from the test folder (user request, 2026-10-20).
# A test file is removed when it is byte-identical (same MD5) to a train file,
# or to another test file that is kept. The manifest rows go with the files.
# Copies of the originals remain in Y:/My Drive/Miami/Code/GitHub/imagejev/imgs.
# Run once from the project root.

manifest_file <- "results/image_split_manifest.csv"
splits <- readr::read_csv(manifest_file, show_col_types = FALSE)
pan <- splits |>
  dplyr::filter(.data$dataset == "pan_images") |>
  dplyr::mutate(md5 = unname(tools::md5sum(.data$image_path)))

train_md5 <- pan$md5[pan$split == "train"]
test <- pan |>
  dplyr::filter(.data$split == "test") |>
  # Within a group of identical test files, keep the first name without " - Copy".
  dplyr::arrange(grepl(" - Copy", .data$image_path, fixed = TRUE), .data$image_path) |>
  dplyr::mutate(
    copy_of_train = .data$md5 %in% train_md5,
    repeat_in_test = duplicated(.data$md5),
    remove = .data$copy_of_train | .data$repeat_in_test
  )

remove <- dplyr::filter(test, .data$remove)
kept_md5 <- c(train_md5, test$md5[!test$remove])
stopifnot(nrow(remove) == 23L, all(remove$md5 %in% kept_md5))
print(dplyr::select(remove, "image_path", "copy_of_train", "repeat_in_test"), n = 30, width = Inf)

stopifnot(all(file.remove(remove$image_path)))
splits |>
  dplyr::filter(!.data$image_path %in% remove$image_path) |>
  readr::write_csv(manifest_file)

after <- readr::read_csv(manifest_file, show_col_types = FALSE) |>
  dplyr::filter(.data$dataset == "pan_images")
on_disk <- list.files("imgs/pan_images", pattern = "\\.(jpg|jpeg|png)$",
                      recursive = TRUE, ignore.case = TRUE)
cat("Removed", nrow(remove), "files. Pan manifest rows:", nrow(after),
    "| image files on disk:", length(on_disk), "\n")
print(dplyr::count(after, .data$split, .data$actual_class))
md5_after <- unname(tools::md5sum(after$image_path))
cat("Remaining duplicate MD5s:", sum(duplicated(md5_after)), "\n")
