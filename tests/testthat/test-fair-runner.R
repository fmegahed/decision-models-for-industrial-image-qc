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
      purpose = c(rep("fair test jev final k2 extrusion", used), "test other",
                  "fair test clef final k2 extrusion", "fair test clef final k2 extrusion"),
      model = c(rep("jev-1.13.0", used), "jev-1.13.0",
                "Cloudflare/clef-flash", "Cloudflare/clef-flash"),
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

test_that("remaining_calls counts only JEV rows whose purpose starts with fair", {
  # make_record adds one JEV row with another purpose and two Clef-Flash fair rows.
  expect_equal(remaining_calls(record_root = make_record(100, 5)), 95)
})

test_that("only JEV runs log to the TypeSafe call log", {
  expect_equal(call_log_path("jev", "rec", "tim"), file.path("rec", "calls", "typesafe-calls.csv"))
  expect_equal(call_log_path("clef", "rec", "tim"), file.path("tim", "clef-calls.csv"))
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

# ---- score_images and the write path, with a stub for classify_image ------
rec <- new.env()
assign("classify_image", function(...) {
  rec$calls <- c(rec$calls, list(list(...)))
  rec$answer()
}, envir = globalenv())
withr::defer(rm("classify_image", envir = globalenv()), teardown_env())
answer_with <- function(p) {
  rec$calls <- list()
  rec$answer <- function() tibble::tibble(class = c("nominal", "defective"), probability = c(1 - p, p))
}
stub_images <- tibble::tibble(dataset = "extrusion", image_path = c("a.jpg", "b.jpg"),
                              defect_type = c("x", "y"), actual_class = c("nominal", "defective"))
stub_refs <- list(normal = "n1.jpg", defective = "d1.jpg")

test_that("score_images passes references unchanged and uses the local key for clef", {
  answer_with(0.3)
  withr::local_envvar(TYPESAFE_API_KEY = "secret-key")
  scores <- score_images(stub_images, stub_refs, generic_description(),
                         model_settings("clef"), "clef", "generic", 2, "calibration")
  call <- rec$calls[[1]]
  expect_identical(call$reference_images, stub_refs)
  expect_equal(call$api_key, "local")
  expect_equal(call$image_format, "images")
  expect_equal(call$max_size, 768)
  expect_equal(scores$prob_defective, c(0.3, 0.3))
  expect_named(scores, c("dataset", "image_path", "defect_type", "actual_class",
                         "prob_defective", "model", "description", "k", "split", "elapsed_ms"))
})

test_that("score_images sends the TypeSafe key only to the TypeSafe URL", {
  answer_with(0.6)
  withr::local_envvar(TYPESAFE_API_KEY = "secret-key")
  score_images(stub_images[1, ], NULL, generic_description(), model_settings("jev"),
               "jev", "generic", 0, "calibration")
  expect_equal(rec$calls[[1]]$api_key, "secret-key")
  expect_equal(rec$calls[[1]]$image_format, "assets")
})

test_that("a bad probability stops the run and leaves no file", {
  out <- withr::local_tempdir()
  tim <- withr::local_tempdir()
  for (bad in c(NA_real_, Inf)) {
    answer_with(bad)
    expect_error(
      score_and_write(stub_images, NULL, generic_description(), model_settings("clef"),
                      "clef", "generic", 0, "calibration", out, "extrusion", timing_dir = tim),
      "Invalid defect probability"
    )
  }
  expect_length(list.files(out), 0)
  expect_length(list.files(tim), 0)
})

test_that("score_and_write writes after all images are scored", {
  out <- withr::local_tempdir()
  tim <- withr::local_tempdir()
  answer_with(0.8)
  score_and_write(stub_images, NULL, generic_description(), model_settings("clef"),
                  "clef", "generic", 0, "calibration", out, "extrusion", timing_dir = tim)
  expect_equal(list.files(out), "clef_generic_k0_extrusion_calibration.csv")
})

test_that("a run writes elapsed_ms for each image and one row to runs.csv", {
  out <- withr::local_tempdir()
  tim <- withr::local_tempdir()
  answer_with(0.8)
  score_and_write(stub_images, NULL, generic_description(), model_settings("clef"),
                  "clef", "generic", 0, "calibration", out, "extrusion", timing_dir = tim)
  written <- readr::read_csv(file.path(out, "clef_generic_k0_extrusion_calibration.csv"),
                             show_col_types = FALSE)
  expect_true("elapsed_ms" %in% names(written))
  expect_length(written$elapsed_ms, 2)
  expect_true(all(written$elapsed_ms >= 0))
  runs <- readr::read_csv(file.path(tim, "runs.csv"), show_col_types = FALSE)
  expect_named(runs, c("model", "description", "k", "dataset", "split", "candidate",
                       "n_images", "start_utc", "end_utc", "seconds", "hardware"))
  expect_equal(nrow(runs), 1)
  expect_equal(runs$n_images, 2)
  expect_equal(runs$model, "clef")
  expect_true(is.na(runs$candidate))
  expect_gte(runs$seconds, 0)
  expect_false(runs$hardware == "TypeSafe API")
  # a second run adds a row
  out2 <- withr::local_tempdir()
  score_and_write(stub_images, NULL, generic_description(), model_settings("jev"),
                  "jev", "generic", 0, "calibration", out2, "extrusion", timing_dir = tim)
  runs <- readr::read_csv(file.path(tim, "runs.csv"), show_col_types = FALSE)
  expect_equal(nrow(runs), 2)
  expect_equal(runs$hardware[2], "TypeSafe API")
})

test_that("append_run records the candidate number of a design run", {
  tim <- withr::local_tempdir()
  t0 <- Sys.time()
  append_run(tim, "jev", "3", 2, "extrusion", "design", 40, t0, t0 + 5, candidate = 3)
  runs <- readr::read_csv(file.path(tim, "runs.csv"), show_col_types = FALSE)
  expect_equal(runs$candidate, 3)
  expect_equal(runs$seconds, 5)
  expect_equal(runs$hardware, "TypeSafe API")
})

test_that("static guards give clear messages before sets load", {
  cand <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("normal,defective", "a,b"), cand)
  expect_error(check_config("clef", "pan_images", cand, 2, "design", tempdir()),
               "The design split has no pan images")
  expect_error(check_config("clef", "extrusion", cand, 4, "design", tempdir()),
               "The design split needs k = 2")
})
