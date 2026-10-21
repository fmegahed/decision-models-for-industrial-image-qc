source(file.path(repo_root, "R", "fair_runner.R"))

make_record <- function(max_calls = 100, used = 0) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  dir.create(file.path(root, "calls"))
  writeLines(c(
    "| Date | Service | Purpose | Max calls | Max cost (USD) | Approved by |",
    "|---|---|---|---|---|---|",
    "| 2026-10-20 | TypeSafe | All JEV calls of the study | 2446 | 5 | fmm |",
    paste0("| 2026-10-21 | TypeSafe | Fair comparison, JEV | ", max_calls, " | 1 | fmm |")
  ), file.path(root, "calls", "README.md"))
  if (used > 0) {
    tibble::tibble(
      purpose = c(rep("fair test jev final k2 extrusion", used), "test other"),
      status = 200
    ) |>
      readr::write_csv(file.path(root, "calls", "typesafe-calls.csv"))
  }
  root
}

check <- function(..., out = withr::local_tempdir(.local_envir = parent.frame()),
                  record = make_record(), descriptions = withr::local_tempdir(.local_envir = parent.frame())) {
  args <- list(model = "jev", dataset = "extrusion", description = "final",
               k = 2, split = "calibration", out = out, n_images = 10,
               record_root = record, description_dir = descriptions)
  args <- utils::modifyList(args, list(...))
  do.call(check_run, args)
}

freeze <- function(dir, name = "jev_extrusion.csv") {
  writeLines(c("normal,defective", "a,b"), file.path(dir, name))
}

test_that("remaining_calls reads the Fair comparison row and fair log rows", {
  expect_equal(remaining_calls(record_root = make_record(100, 30)), 70)
  expect_equal(remaining_calls(record_root = make_record(100, 0)), 100)
})

test_that("remaining_calls is 0 without a Fair comparison row", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "calls"))
  writeLines(c("| Date | Service | Purpose | Max calls |", "|---|---|---|---|",
               "| x | y | All JEV calls | 99 |"), file.path(root, "calls", "README.md"))
  expect_equal(remaining_calls(record_root = root), 0)
})

test_that("a second test run stops", {
  out <- withr::local_tempdir()
  desc <- withr::local_tempdir()
  freeze(desc)
  file.create(file.path(out, "jev_final_k2_extrusion_calibration.csv"))
  file.create(file.path(out, "jev_final_k2_extrusion_test.csv"))
  expect_error(
    check(split = "test", out = out, descriptions = desc),
    "Test results already exist for jev_final_k2_extrusion. The test run is one-time.",
    fixed = TRUE
  )
})

test_that("a second calibration run stops", {
  out <- withr::local_tempdir()
  desc <- withr::local_tempdir()
  freeze(desc)
  file.create(file.path(out, "jev_final_k2_extrusion_calibration.csv"))
  expect_error(check(out = out, descriptions = desc), "Calibration results already exist")
})

test_that("a test run without a calibration file stops", {
  desc <- withr::local_tempdir()
  freeze(desc)
  expect_error(check(split = "test", descriptions = desc), "calibration")
})

test_that("a final run without a frozen description stops", {
  expect_error(check(), "No frozen description")
})

test_that("design runs for pans or with k other than 2 stop", {
  cand <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("normal,defective", "a,b"), cand)
  expect_error(check(split = "design", description = cand, dataset = "pan_images"), "pan")
  expect_error(check(split = "design", description = cand, k = 4), "k = 2")
  expect_silent(check(split = "design", description = cand, model = "clef"))
})

test_that("a path description is only for the design split", {
  cand <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("normal,defective", "a,b"), cand)
  expect_error(check(split = "calibration", description = cand), "design")
})

test_that("a JEV run of 50 images with 40 calls left stops", {
  desc <- withr::local_tempdir()
  freeze(desc)
  expect_error(check(n_images = 50, record = make_record(40), descriptions = desc), "40")
  expect_no_error(check(n_images = 40, record = make_record(40), descriptions = desc))
})

test_that("check-only mode reports the budget and does not stop", {
  desc <- withr::local_tempdir()
  freeze(desc)
  expect_output(
    check(n_images = 50, record = make_record(40), descriptions = desc, check_only = TRUE),
    "40 calls left"
  )
})

test_that("clef runs need no budget", {
  expect_no_error(check(model = "clef", n_images = 5000, description = "generic",
                        record = make_record(0)))
})

test_that("model settings follow the plan", {
  expect_equal(model_settings("jev")$model, "jev-1.13.0")
  expect_equal(model_settings("clef")$image_format, "images")
  expect_equal(model_settings("clef")$base_url, "http://localhost:30000/v1/systemone")
})

test_that("pan calibration drops the references at k", {
  sets <- file.path(repo_root, "results", "fair", "sets")
  images <- fair_images("pan_images", "calibration", k = 1, sets_dir = sets)
  refs <- fair_references("pan_images", k = 1, sets_dir = sets)
  expect_false(any(images$image_path %in% unlist(refs)))
  expect_equal(nrow(fair_images("pan_images", "calibration", k = 0, sets_dir = sets)),
               nrow(images) + 2)
  expect_named(refs, c("normal", "defective"), ignore.order = TRUE)
})
