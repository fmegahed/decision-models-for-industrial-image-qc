source(file.path(repo_root, "R", "fair_runner.R"))

rscript_bin <- file.path(R.home("bin"), "Rscript")

# A loop folder with a clean audit of jev / extrusion.
clean_loop <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  write_audit(dir)
  dir
}

check <- function(..., out = withr::local_tempdir(.local_envir = parent.frame()),
                  record = make_record(), descriptions = withr::local_tempdir(.local_envir = parent.frame()),
                  loop = clean_loop(parent.frame())) {
  args <- list(model = "jev", dataset = "extrusion", description = "final",
               k = 2, split = "calibration", out = out, n_images = 10,
               record_root = record, description_dir = descriptions, loop_dir = loop)
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
  expect_output(expect_error(check(n_images = 50, record = make_record(40), descriptions = desc),
                             "40"), "Budget README")
  expect_output(expect_no_error(check(n_images = 40, record = make_record(40), descriptions = desc)),
                "40 calls left of 40")
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

# A client log row, as log_call() writes it, for a stub that logs its call.
client_row <- function(log, status = 200, purpose = Sys.getenv("JEV_CALL_PURPOSE"),
                       input_tokens = NA, cost_usd = NA) {
  tibble::tibble(time_utc = "t", call_id = "c", purpose = purpose, model = "jev-1.13.0",
                 request_id = "r", status = status, latency_ms = 900,
                 input_tokens = input_tokens, output_tokens = 30, cost_usd = cost_usd) |>
    readr::write_csv(log, append = file.exists(log), na = "")
}

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

test_that("a bad probability stops the run after three attempts and leaves no file", {
  out <- withr::local_tempdir()
  tim <- withr::local_tempdir()
  withr::local_envvar(JEV_CALL_LOG = NA)
  for (bad in c(NA_real_, Inf)) {
    answer_with(bad)
    expect_error(
      score_and_write(stub_images, NULL, generic_description(), model_settings("clef"),
                      "clef", "generic", 0, "calibration", out, "extrusion", timing_dir = tim,
                      backoff = c(0, 0)),
      "Invalid defect probability"
    )
    expect_length(rec$calls, 3)
  }
  expect_length(list.files(out), 0)
  expect_length(list.files(tim), 0)
})

test_that("score_images retries a failed image and counts the retries in elapsed_ms", {
  log <- withr::local_tempfile(fileext = ".csv")
  withr::local_envvar(JEV_CALL_LOG = log, JEV_CALL_PURPOSE = "fair calibration jev generic k0 extrusion")
  rec$calls <- list()
  n <- 0
  # Two connection errors (the client logs nothing), then an answer.
  rec$answer <- function() {
    n <<- n + 1
    if (n <= 2) stop("Failed to perform HTTP request. Caused by error: Could not connect")
    tibble::tibble(class = c("nominal", "defective"), probability = c(0.4, 0.6))
  }
  expect_message(
    scores <- score_images(stub_images[1, ], NULL, generic_description(), model_settings("jev"),
                           "jev", "generic", 0, "calibration", backoff = c(0.2, 0.3)),
    "attempt 1 failed"
  )
  expect_length(rec$calls, 3)
  expect_equal(scores$prob_defective, 0.6)
  expect_gte(scores$elapsed_ms, 500) # the waits of 0.2 s and 0.3 s are in the time
  logged <- readr::read_csv(log, show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  expect_named(logged, call_log_columns)
  expect_equal(logged$status, c("error", "error"))
  expect_equal(unique(logged$purpose), "fair calibration jev generic k0 extrusion")
  expect_equal(unique(logged$model), "jev-1.13.0")
})

test_that("an error that the client logged is not logged twice, and three failures stop", {
  log <- withr::local_tempfile(fileext = ".csv")
  withr::local_envvar(JEV_CALL_LOG = log, JEV_CALL_PURPOSE = "fair test jev final k2 extrusion")
  rec$calls <- list()
  rec$answer <- function() {
    client_row(log, status = 429)
    stop("TypeSafe HTTP 429:\nslow down")
  }
  expect_error(
    suppressMessages(score_images(stub_images, NULL, generic_description(), model_settings("jev"),
                                  "jev", "final", 2, "test", backoff = c(0, 0))),
    "TypeSafe HTTP 429"
  )
  expect_length(rec$calls, 3) # the first image only: the run stops there
  logged <- readr::read_csv(log, show_col_types = FALSE)
  expect_equal(logged$status, c(429, 429, 429))
})

test_that("the default back-off waits 2 s and then 8 s, for 3 attempts in all", {
  expect_equal(formals(score_images)$attempts, 3L)
  expect_equal(eval(formals(score_images)$backoff), c(2, 8))
})

test_that("the failed-attempt row has the columns of the client log", {
  cl <- new.env()
  sys.source(file.path(repo_root, "R", "industrial_defect_classifier.R"), envir = cl)
  log <- withr::local_tempfile(fileext = ".csv")
  withr::local_envvar(JEV_CALL_LOG = log, JEV_CALL_PURPOSE = "p")
  resp <- httr2::response(status_code = 200,
                          headers = list(`Content-Type` = "application/json", `x-request-id` = "r1"),
                          body = charToRaw("{\"usage\": {\"input_tokens\": 10, \"output_tokens\": 2}}"))
  cl$log_call(resp, Sys.time(), "jev-1.13.0", "https://api.typesafe.ai/v1/systemone", "a.jpg")
  expect_named(readr::read_csv(log, show_col_types = FALSE), call_log_columns)
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
                       "n_images", "start_utc", "end_utc", "seconds", "hardware",
                       "audit_decision"))
  expect_equal(nrow(runs), 1)
  expect_equal(runs$n_images, 2)
  expect_equal(runs$model, "clef")
  expect_true(is.na(runs$candidate))
  expect_true(is.na(runs$audit_decision))
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

test_that("runs.csv records the audit decision and keeps the rows of an older file", {
  tim <- withr::local_tempdir()
  old <- c("model,description,k,dataset,split,candidate,n_images,start_utc,end_utc,seconds,hardware",
           "clip,baseline,50,extrusion,test,NA,200,2026-10-21T05:36:44Z,2026-10-21T05:36:48Z,3.734,NVIDIA X")
  writeLines(old, file.path(tim, "runs.csv"))
  t0 <- Sys.time()
  append_run(tim, "jev", "final", 2, "extrusion", "calibration", 50, t0, t0 + 1,
             audit_decision = "D82")
  runs <- readr::read_csv(file.path(tim, "runs.csv"), show_col_types = FALSE)
  expect_equal(nrow(runs), 2)
  expect_equal(runs$audit_decision, c(NA, "D82"))
  expect_equal(runs$seconds[[1]], 3.734)
  expect_equal(runs$hardware[[1]], "NVIDIA X")
  expect_equal(readLines(file.path(tim, "runs.csv"))[[2]], paste0(old[[2]], ",NA"))
})

test_that("static guards give clear messages before sets load", {
  cand <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("normal,defective", "a,b"), cand)
  expect_error(check_config("clef", "pan_images", cand, 2, "design", tempdir()),
               "The design split has no pan images")
  expect_error(check_config("clef", "extrusion", cand, 4, "design", tempdir()),
               "The design split needs k = 2")
})

test_that("check_config accepts only the configurations of design section 5.6", {
  out <- withr::local_tempdir()
  desc <- withr::local_tempdir()
  loop <- withr::local_tempdir()
  cand <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("normal,defective", "a,b"), cand)
  loop_sets <- c("extrusion", "microstructure", "pipe_staple", "textiles")
  for (m in c("jev", "clef")) {
    for (d in loop_sets) {
      freeze(desc, paste0(m, "_", d, ".csv"))
      write_audit(loop, m, d)
    }
  }
  ok <- dplyr::bind_rows(
    tidyr::expand_grid(dataset = loop_sets, description = "final", k = c(0, 1, 2, 4)),
    tidyr::expand_grid(dataset = loop_sets, description = "generic", k = c(0, 2)),
    tidyr::expand_grid(dataset = "pan_images", description = "generic", k = c(0, 1, 2, 4))
  )
  for (m in c("jev", "clef")) {
    purrr::pwalk(ok, \(dataset, description, k) {
      expect_no_error(check_config(m, dataset, description, k, "calibration", out, desc, loop))
    })
  }
  expect_no_error(check_config("jev", "textiles", cand, 2, "design", out, desc, loop))
  expect_error(check_config("jev", "extrusion", "generic", 1, "calibration", out, desc, loop),
               "generic description runs at k = 0 and k = 2")
  expect_error(check_config("jev", "textiles", "generic", 4, "test", out, desc, loop),
               "generic description runs at k = 0 and k = 2")
  expect_error(check_config("jev", "pan_images", "final", 2, "calibration", out, desc, loop),
               "Pans have no final description")
  expect_error(check_config("jev", "other", "generic", 2, "calibration", out, desc, loop),
               "FAIR_DATASET")
  expect_error(check_config("jev", "extrusion", "generic", 2, "design", out, desc, loop),
               "The design split needs a candidate description file")
  expect_error(check_config("jev", "extrusion", "final", 2, "design", out, desc, loop),
               "The design split needs a candidate description file")
})

test_that("JEV_CHECK_ONLY is on only for true and stops on any other value", {
  expect_true(check_only_mode("true"))
  expect_true(check_only_mode(" TRUE "))
  expect_false(check_only_mode(""))
  expect_false(check_only_mode("false"))
  expect_false(check_only_mode(" False"))
  for (bad in c("yes", "1", "ture", "on", "T")) {
    expect_error(check_only_mode(bad), "JEV_CHECK_ONLY must be true or false", info = bad)
  }
})

test_that("a bad JEV_CHECK_ONLY stops the script before any other step", {
  # An unknown dataset and a record root with no budget row: an old script
  # stops before any call too.
  withr::local_dir(repo_root)
  out <- withr::with_envvar(
    c(FAIR_MODEL = "jev", FAIR_DATASET = "no_such_dataset", FAIR_DESCRIPTION = "generic",
      FAIR_K = "0", FAIR_SPLIT = "calibration", FAIR_OUT = withr::local_tempdir(),
      FAIR_TIMING_DIR = withr::local_tempdir(), FAIR_RECORD_ROOT = withr::local_tempdir(),
      JEV_CHECK_ONLY = "yes", JEV_CALL_LOG = NA),
    suppressWarnings(system2(rscript_bin, "scripts/fair_score.R", stdout = TRUE, stderr = TRUE))
  )
  expect_match(paste(out, collapse = "\n"), "JEV_CHECK_ONLY must be true or false")
})

test_that("a JEV run logs only to the record log and stops on another JEV_CALL_LOG", {
  rec_log <- file.path("rec", "calls", "typesafe-calls.csv")
  expect_equal(select_call_log("jev", "", "rec", "tim"), rec_log)
  expect_equal(select_call_log("jev", rec_log, "rec", "tim"), rec_log)
  expect_equal(select_call_log("jev", normalizePath(rec_log, mustWork = FALSE), "rec", "tim"), rec_log)
  expect_error(select_call_log("jev", "other.csv", "rec", "tim"), "JEV_CALL_LOG names")
  # A non-JEV run ignores a stale JEV_CALL_LOG.
  expect_equal(select_call_log("clef", rec_log, "rec", "tim"), file.path("tim", "clef-calls.csv"))
  expect_equal(select_call_log("clef", "", "rec", "tim"), file.path("tim", "clef-calls.csv"))
})

test_that("a paid JEV run needs FAIR_RECORD_ROOT with the budget row of its purpose", {
  expect_error(paid_record_root(""), "Set FAIR_RECORD_ROOT")
  expect_error(paid_record_root(file.path(tempdir(), "no-such-record-folder")), "does not exist")
  bare <- withr::local_tempdir()
  dir.create(file.path(bare, "calls"))
  writeLines(c("| Date | Service | Purpose | Max calls |", "| x | y | All JEV calls | 99 |"),
             file.path(bare, "calls", "README.md"))
  expect_error(paid_record_root(bare), "Fair comparison")
  root <- make_record()
  expect_error(paid_record_root(root, "rerun"), "Re-run")
  expect_equal(paid_record_root(root), normalizePath(root, winslash = "/"))
  # The fallback holds only for check-only and Clef-Flash runs.
  expect_error(run_record_root("jev", FALSE, value = ""), "Set FAIR_RECORD_ROOT")
  expect_equal(run_record_root("jev", TRUE, value = ""), "replication_materials")
  expect_equal(run_record_root("clef", FALSE, value = ""), "replication_materials")
  expect_equal(run_record_root("jev", FALSE, value = root), normalizePath(root, winslash = "/"))
  # check_run: a paid JEV run with no record root stops; check-only goes on.
  expect_error(check(description = "generic", record = ""), "Set FAIR_RECORD_ROOT")
  expect_error(check(description = "generic", record = bare), "Fair comparison")
  expect_output(check(description = "generic", record = "", check_only = TRUE), "calls left")
})

test_that("each purpose prefix counts against its own budget row", {
  root <- make_record(100, 5, rerun_calls = 50)
  log <- file.path(root, "calls", "typesafe-calls.csv")
  tibble::tibble(purpose = "rerun test jev final k2 extrusion", model = "jev-1.13.0",
                 status = 200, cost_usd = 0.002) |>
    dplyr::slice(rep(1, 2)) |>
    readr::write_csv(log, append = TRUE)
  expect_equal(remaining_calls("fair", root), 95)
  expect_equal(remaining_calls("rerun", root), 48)
  expect_equal(budget_status("rerun", root)$spent_usd, 0.004)
  expect_equal(remaining_calls("rerun", make_record(100, 5)), 0)
  expect_equal(purpose_prefix("fair"), "fair")
  expect_equal(purpose_prefix("rerun"), "rerun")
  expect_equal(purpose_prefix(""), "fair")
  expect_error(purpose_prefix("other"), "FAIR_PURPOSE_PREFIX must be fair or rerun")
})

test_that("the budget reports the spent cost of the fair rows and the Max cost of the row", {
  s <- budget_status("fair", make_record(100, 4, max_cost = 2))
  expect_equal(s$spent_usd, 0.004) # the JEV row of another purpose (USD 0.5) does not count
  expect_equal(s$max_cost, 2)
  expect_equal(s$max_calls, 100)
  expect_equal(s$used, 4)
  expect_equal(s$left, 96)
  expect_true(s$found)
  for (only in c(FALSE, TRUE)) {
    expect_output(check(description = "generic", record = make_record(100, 4, max_cost = 2),
                        check_only = only),
                  "spent USD 0.004 of max USD 2", fixed = TRUE)
  }
  expect_output(check(description = "generic", record = make_record(100, 4)),
                "Budget README: .*calls/README.md")
})

test_that("a check-only JEV script run prints the budget README, the call log and the cost", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  withr::local_dir(repo_root)
  record <- make_record(100, 0, max_cost = 2)
  out <- withr::with_envvar(
    c(FAIR_MODEL = "jev", FAIR_DATASET = "extrusion", FAIR_DESCRIPTION = "generic",
      FAIR_K = "0", FAIR_SPLIT = "calibration", FAIR_OUT = withr::local_tempdir(),
      FAIR_TIMING_DIR = withr::local_tempdir(), FAIR_RECORD_ROOT = record,
      JEV_CHECK_ONLY = "true", JEV_CALL_LOG = NA),
    system2(rscript_bin, "scripts/fair_score.R", stdout = TRUE, stderr = TRUE)
  )
  text <- paste(out, collapse = "\n")
  expect_match(text, paste("Budget README:", file.path(record, "calls", "README.md")), fixed = TRUE)
  expect_match(text, paste("Call log:", file.path(record, "calls", "typesafe-calls.csv")), fixed = TRUE)
  expect_match(text, "spent USD 0 of max USD 2", fixed = TRUE)
  expect_match(text, "checks passed")
  expect_equal(list.files(file.path(record, "calls")), "README.md")
  # Another JEV_CALL_LOG stops the run, also in check-only mode.
  out2 <- withr::with_envvar(
    c(FAIR_MODEL = "jev", FAIR_DATASET = "extrusion", FAIR_DESCRIPTION = "generic",
      FAIR_K = "0", FAIR_SPLIT = "calibration", FAIR_OUT = withr::local_tempdir(),
      FAIR_TIMING_DIR = withr::local_tempdir(), FAIR_RECORD_ROOT = record,
      JEV_CHECK_ONLY = "true", JEV_CALL_LOG = file.path(withr::local_tempdir(), "other.csv")),
    suppressWarnings(system2(rscript_bin, "scripts/fair_score.R", stdout = TRUE, stderr = TRUE))
  )
  expect_match(paste(out2, collapse = "\n"), "JEV_CALL_LOG names")
})

test_that("a check-only Clef-Flash script run leaves no TypeSafe log in the environment", {
  withr::local_dir(repo_root)
  tim <- withr::local_tempdir()
  # Run the real script in check-only mode; .Last prints the variable at exit.
  out <- withr::with_envvar(
    c(JEV_CALL_LOG = "x/calls/typesafe-calls.csv", FAIR_MODEL = "clef",
      FAIR_DATASET = "extrusion", FAIR_DESCRIPTION = "generic", FAIR_K = "0",
      FAIR_SPLIT = "calibration", FAIR_OUT = withr::local_tempdir(),
      FAIR_TIMING_DIR = tim, JEV_CHECK_ONLY = "true"),
    system2(rscript_bin,
            c("-e", shQuote('.Last <- function() cat("LOG=", Sys.getenv("JEV_CALL_LOG"), "\n"); source("scripts/fair_score.R")')),
            stdout = TRUE,
            stderr = FALSE)
  )
  expect_true(any(grepl("LOG= .*clef-calls.csv", out)))
  expect_false(any(grepl("typesafe-calls", out)))
})

test_that("remaining_calls stops with a clear message when the log has no model column", {
  root <- make_record(100, 0)
  tibble::tibble(purpose = "fair test jev final k2 extrusion", status = 200) |>
    readr::write_csv(file.path(root, "calls", "typesafe-calls.csv"))
  expect_error(remaining_calls(record_root = root), "no model column")
})

test_that("a final run records the md5 of the frozen description; a changed file stops the test run", {
  out <- withr::local_tempdir()
  tim <- withr::local_tempdir()
  desc <- withr::local_tempdir()
  freeze(desc)
  md5 <- frozen_md5("jev", "extrusion", desc)
  expect_equal(md5, unname(tools::md5sum(file.path(desc, "jev_extrusion.csv"))))
  answer_with(0.7)
  score_and_write(stub_images, NULL, generic_description(), model_settings("jev"), "jev",
                  "final", 2, "calibration", out, "extrusion", timing_dir = tim,
                  description_md5 = md5)
  cal <- readr::read_csv(file.path(out, "jev_final_k2_extrusion_calibration.csv"),
                         show_col_types = FALSE)
  expect_equal(unique(cal$description_md5), md5)
  expect_output(expect_no_error(check(split = "test", out = out, descriptions = desc)),
                "Budget README")
  writeLines(c("normal,defective", "a,changed"), file.path(desc, "jev_extrusion.csv"))
  expect_error(check(split = "test", out = out, descriptions = desc), "md5")
  # A generic run has no md5 column.
  out2 <- withr::local_tempdir()
  score_and_write(stub_images, NULL, generic_description(), model_settings("jev"), "jev",
                  "generic", 2, "calibration", out2, "extrusion", timing_dir = tim)
  expect_false("description_md5" %in% names(readr::read_csv(
    file.path(out2, "jev_generic_k2_extrusion_calibration.csv"), show_col_types = FALSE)))
})

test_that("a final test run stops when its calibration file has no md5 column", {
  out <- withr::local_tempdir()
  desc <- withr::local_tempdir()
  freeze(desc)
  writeLines(c("dataset,image_path,prob_defective", "extrusion,a.jpg,0.5"),
             file.path(out, "jev_final_k2_extrusion_calibration.csv"))
  expect_error(check(split = "test", out = out, descriptions = desc), "no description_md5")
})

test_that("a final run stops on a flagged loop audit unless a decision ID accepts it", {
  out <- withr::local_tempdir()
  desc <- withr::local_tempdir()
  freeze(desc)
  loop <- withr::local_tempdir()
  expect_error(check(descriptions = desc, loop = loop), "No loop audit")
  write_audit(loop, flagged = c("cat ../x", "repeated scoring call for candidate 2"))
  expect_error(check(descriptions = desc, loop = loop), "FAIR_AUDIT_DECISION")
  expect_equal(check_config("jev", "extrusion", "final", 2, "calibration", out, desc, loop,
                            audit_decision = " D82 "), "D82")
  expect_error(check_config("jev", "extrusion", "final", 2, "calibration", out, desc, loop,
                            audit_decision = "yes"), "decision ID")
  write_audit(loop)
  expect_true(is.na(check_config("jev", "extrusion", "final", 2, "calibration", out, desc, loop)))
  # A generic run needs no audit.
  expect_true(is.na(check_config("jev", "extrusion", "generic", 2, "calibration", out, desc,
                                 withr::local_tempdir(), audit_decision = "D82")))
})

# ---- the check call of Task 8 --------------------------------------------------
test_that("check_call makes one JEV call with 2k references and writes only the log row", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  withr::local_dir(repo_root)
  record <- make_record(100, 0)
  tim <- withr::local_tempdir()
  withr::local_envvar(TYPESAFE_API_KEY = "stub-key", JEV_CALL_LOG = NA, JEV_CALL_PURPOSE = NA)
  seen <- new.env()
  rec$calls <- list()
  rec$answer <- function() {
    seen$purpose <- Sys.getenv("JEV_CALL_PURPOSE")
    seen$log <- Sys.getenv("JEV_CALL_LOG")
    client_row(seen$log, input_tokens = 12000, cost_usd = 12000 * 0.042 / 1e6)
    tibble::tibble(class = c("normal", "defective"), probability = c(0.3, 0.7))
  }
  printed <- capture.output(res <- check_call("jev", 4, record_root = record, timing_dir = tim))
  text <- paste(printed, collapse = "\n")
  expect_length(rec$calls, 1)
  call <- rec$calls[[1]]
  expect_length(call$reference_images$normal, 4)
  expect_length(call$reference_images$defective, 4)
  expect_false(call$image_path %in% unlist(call$reference_images))
  expect_equal(call$api_key, "stub-key")
  expect_equal(seen$purpose, "fair check jev k4")
  expect_equal(seen$log, file.path(record, "calls", "typesafe-calls.csv"))
  expect_equal(remaining_calls(record_root = record), 99)
  expect_equal(sort(list.files(file.path(record, "calls"))), c("README.md", "typesafe-calls.csv"))
  expect_length(list.files(tim), 0)
  expect_equal(res$probability, 0.7)
  expect_match(text, "9 images in the call", fixed = TRUE)
  expect_match(text, "Probability (defective): 0.7", fixed = TRUE)
  expect_match(text, "input tokens 12000", fixed = TRUE)
  expect_match(text, "estimated cost USD 0.000504", fixed = TRUE)
  expect_equal(Sys.getenv("JEV_CALL_PURPOSE"), "") # the variables come back
  # The timing table of the evaluation does not count the check call.
  ev <- new.env()
  sys.source(file.path(repo_root, "R", "fair_evaluate.R"), envir = ev)
  no_scores <- tibble::tibble(model = character(), description = character(), k = double(),
                              dataset = character(), split = character(), elapsed_ms = double())
  expect_equal(nrow(ev$timing_table(no_scores, tim, record)), 0)
})

test_that("check_call of Clef-Flash logs to the Clef-Flash log only", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  withr::local_dir(repo_root)
  record <- make_record(100, 0)
  tim <- withr::local_tempdir()
  withr::local_envvar(JEV_CALL_LOG = "x/calls/typesafe-calls.csv")
  seen <- new.env()
  rec$calls <- list()
  rec$answer <- function() {
    seen$log <- Sys.getenv("JEV_CALL_LOG")
    tibble::tibble(class = c("normal", "defective"), probability = c(0.4, 0.6))
  }
  capture.output(check_call("clef", 2, record_root = record, timing_dir = tim))
  expect_length(rec$calls, 1)
  expect_equal(rec$calls[[1]]$api_key, "local")
  expect_length(rec$calls[[1]]$reference_images$normal, 2)
  expect_equal(seen$log, file.path(tim, "clef-calls.csv"))
  expect_equal(list.files(file.path(record, "calls")), "README.md")
})

test_that("check_call in check-only mode makes no call", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  withr::local_dir(repo_root)
  rec$calls <- list()
  record <- make_record(100, 0)
  printed <- capture.output(check_call("jev", 1, check_only = TRUE, record_root = record,
                                       timing_dir = withr::local_tempdir()))
  expect_length(rec$calls, 0)
  expect_match(paste(printed, collapse = "\n"), "Check-only")
  expect_error(capture.output(check_call("jev", 3, check_only = TRUE, record_root = record)), "K must be")
})

test_that("the check-call script in check-only mode makes no call and writes nothing", {
  skip_if_not(file.exists(file.path(repo_root, "imgs")))
  withr::local_dir(repo_root)
  record <- make_record(100, 0)
  tim <- withr::local_tempdir()
  out <- withr::with_envvar(
    c(JEV_CHECK_ONLY = "true", FAIR_RECORD_ROOT = record, FAIR_TIMING_DIR = tim, JEV_CALL_LOG = NA),
    suppressWarnings(system2(rscript_bin, c("scripts/fair_check_call.R", "jev", "4"),
                             stdout = TRUE, stderr = TRUE))
  )
  text <- paste(out, collapse = "\n")
  expect_match(text, "9 images in the call", fixed = TRUE)
  expect_match(text, "fair check jev k4", fixed = TRUE)
  expect_match(text, "Check-only")
  expect_equal(list.files(file.path(record, "calls")), "README.md")
  expect_length(list.files(tim), 0)
})
