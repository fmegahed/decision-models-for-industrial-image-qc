source(file.path(repo_root, "R", "image_hash.R"))
source(file.path(repo_root, "R", "fair_sets.R"))

toy_pool <- function(nominal, defective_by_type, dataset = "toy") {
  nom <- tibble::tibble(
    dataset = dataset,
    image_path = sprintf("nom/%03d.png", seq_len(nominal)),
    defect_type = "nominal", actual_class = "nominal"
  )
  def <- purrr::imap(defective_by_type, \(n, type) {
    tibble::tibble(
      dataset = dataset,
      image_path = sprintf("def/%s_%03d.png", type, seq_len(n)),
      defect_type = type, actual_class = "defective"
    )
  }) |>
    purrr::list_rbind()
  dplyr::bind_rows(nom, def)
}

count_by <- function(x) dplyr::count(x, .data$actual_class, .data$defect_type)

test_that("C has 13 + 12 for two types", {
  cal <- draw_calibration(toy_pool(60, c(over = 40, under = 40)))
  expect_equal(sum(cal$actual_class == "nominal"), 25)
  expect_equal(sum(cal$actual_class == "defective"), 25)
  expect_equal(sum(cal$defect_type == "over"), 13)
  expect_equal(sum(cal$defect_type == "under"), 12)
})

test_that("C has 3 x 7 + 2 x 2 for nine types", {
  types <- stats::setNames(rep(20, 9), c(
    "Band_high", "Band_low", "Band_medium", "Bimodal_high", "Bimodal_low",
    "Bimodal_medium", "SingleCrystal_high", "SingleCrystal_low",
    "SingleCrystal_medium"
  ))
  cal <- draw_calibration(toy_pool(25, types))
  per_type <- cal |>
    dplyr::filter(.data$actual_class == "defective") |>
    dplyr::count(.data$defect_type) |>
    dplyr::arrange(.data$defect_type)
  expect_equal(per_type$n, c(rep(3, 7), 2, 2))
  expect_equal(sum(cal$actual_class == "nominal"), 25)
})

test_that("C is 17 + 17 when only 17 defective images are left", {
  cal <- draw_calibration(toy_pool(88, c(missing = 17)))
  expect_equal(sum(cal$actual_class == "nominal"), 17)
  expect_equal(sum(cal$actual_class == "defective"), 17)
})

test_that("excluded near-copies shrink C and the report shows the shortfall", {
  pool <- toy_pool(25, c(over = 40, under = 40))
  excluded <- pool$image_path[1:2]
  cal <- draw_calibration(pool, exclude = excluded)
  expect_equal(sum(cal$actual_class == "nominal"), 23)
  expect_equal(sum(cal$actual_class == "defective"), 23)
  expect_false(any(cal$image_path %in% excluded))
  report <- draw_report(pool, cal, exclude = excluded)
  nominal <- dplyr::filter(report, .data$actual_class == "nominal")
  expect_equal(nominal$available, 23)
  expect_equal(nominal$excluded_near_copies, 2)
  expect_equal(nominal$drawn, 23)
  expect_equal(nominal$shortfall, 2)
  expect_named(report, c(
    "dataset", "actual_class", "available", "excluded_near_copies",
    "drawn", "shortfall"
  ))
})

test_that("reference ranks are nested and round-robin over types", {
  learning <- toy_pool(10, c(a = 5, b = 5, c = 5, d = 5, e = 5))
  refs <- draw_references(learning)
  expect_equal(sort(unique(refs$rank)), 1:4)
  expect_equal(nrow(refs), 8)
  def <- dplyr::filter(refs, .data$actual_class == "defective")
  expect_equal(dplyr::n_distinct(def$defect_type[def$rank <= 2]), 2)
  expect_equal(dplyr::n_distinct(def$defect_type[def$rank <= 4]), 4)
  expect_true(all(refs$image_path %in% learning$image_path))
  expect_false(any(duplicated(refs$image_path)))
  expect_true(all(c("dataset", "image_path", "defect_type", "actual_class", "rank") %in% names(refs)))
})

test_that("one-type datasets and other datasets draw independently", {
  a <- toy_pool(10, c(missing = 10), dataset = "a")
  b <- toy_pool(10, c(x = 5, y = 5), dataset = "b")
  only_a <- draw_references(a)
  both <- draw_references(dplyr::bind_rows(a, b))
  expect_equal(dplyr::filter(both, .data$dataset == "a"), only_a)
})

test_that("draws are reproducible and leave the global RNG alone", {
  pool <- toy_pool(60, c(over = 40, under = 40))
  set.seed(1)
  before <- stats::runif(1)
  set.seed(1)
  c1 <- draw_calibration(pool)
  after <- stats::runif(1)
  expect_equal(before, after)
  expect_identical(c1, draw_calibration(pool))
  expect_identical(draw_references(pool), draw_references(pool))
  expect_false(identical(c1, draw_calibration(pool, seed = 1)))
})

test_that("near_copies() finds near-identical images only", {
  skip_if_not_installed("magick")
  dir <- withr::local_tempdir()
  set.seed(7)
  make <- function(name, img) {
    path <- file.path(dir, name)
    magick::image_write(img, path, format = "png")
    path
  }
  noise <- magick::image_read(as.raster(matrix(stats::runif(64 * 64), 64, 64)))
  other <- magick::image_read(as.raster(matrix(stats::runif(64 * 64), 64, 64)))
  a <- make("a.png", noise)
  a_copy <- make("a_copy.png", magick::image_resize(noise, "63x63!"))
  b <- make("b.png", other)
  found <- near_copies(c(a_copy, b), others = a)
  expect_equal(found, a_copy)
  expect_equal(near_copies(character(), others = a), character())
})

fair_files <- file.path(repo_root, "results", "fair", "sets")
real <- file.path(fair_files, "learning.csv")

test_that("real sets are disjoint, nested and complete", {
  skip_if_not(file.exists(real), "run scripts/fair_draw_sets.R first")
  read <- \(f) readr::read_csv(file.path(fair_files, f), show_col_types = FALSE)
  learning <- read("learning.csv")
  cal <- read("calibration.csv")
  refs <- read("references.csv")
  design <- read("design.csv")
  report <- read("draw_report.csv")
  manifest <- readr::read_csv(
    file.path(repo_root, "results", "image_split_manifest.csv"),
    show_col_types = FALSE
  )
  test_paths <- manifest$image_path[manifest$split == "test"]
  cols <- c("dataset", "image_path", "defect_type", "actual_class")
  for (d in list(learning, cal, refs, design)) expect_true(all(cols %in% names(d)))
  expect_false(any(cal$image_path %in% learning$image_path))
  expect_false(any(cal$image_path %in% test_paths))
  md5 <- \(p) unname(tools::md5sum(file.path(repo_root, p)))
  expect_false(any(md5(cal$image_path) %in% md5(learning$image_path)))
  expect_false(any(md5(cal$image_path) %in% md5(test_paths)))
  expect_true(all(refs$image_path %in% learning$image_path))
  expected_design <- learning |>
    dplyr::filter(.data$dataset != "pan_images") |>
    dplyr::anti_join(dplyr::filter(refs, .data$rank <= 2), by = "image_path")
  expect_setequal(design$image_path, expected_design$image_path)
  expect_false("pan_images" %in% cal$dataset)
  # Counts of design table 4.3, minus the near-copies named in the report.
  target <- tibble::tribble(
    ~dataset, ~target,
    "extrusion", 25, "textiles", 25, "pipe_staple", 17, "microstructure", 25
  )
  drawn <- dplyr::count(cal, .data$dataset, .data$actual_class, name = "n")
  checked <- drawn |>
    dplyr::inner_join(target, by = "dataset") |>
    dplyr::inner_join(report, by = c("dataset", "actual_class"))
  expect_equal(checked$n, checked$drawn)
  expect_true(all(checked$n <= checked$target))
  expect_true(all(checked$n == checked$target | checked$excluded_near_copies > 0))
  expect_equal(dplyr::n_distinct(drawn$n[drawn$dataset == "extrusion"]), 1)
})
