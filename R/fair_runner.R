# Scoring runner for the fair comparison: settings, image and reference
# sets, guards, the budget, and the scoring core. scripts/fair_score.R and
# scripts/fair_check_call.R call these.

# Folder of calls/README.md and calls/typesafe-calls.csv. The fallback to the
# branch copy is only for check-only and Clef-Flash runs (see run_record_root).
fair_record_root <- function() {
  Sys.getenv("FAIR_RECORD_ROOT", unset = "replication_materials")
}

# Folder of the timing files: runs.csv and the Clef-Flash call log.
fair_timing_dir <- function() {
  Sys.getenv("FAIR_TIMING_DIR", unset = "results/fair/timing")
}

# The datasets of the description loop (pans have no loop).
loop_datasets <- c("extrusion", "microstructure", "pipe_staple", "textiles")

# Columns of the call log, as log_call() of the client writes them.
call_log_columns <- c("time_utc", "call_id", "purpose", "model", "request_id", "status",
                      "latency_ms", "input_tokens", "output_tokens", "cost_usd")

# Purpose prefixes of the call log and their budget rows. "rerun" is for the
# re-runs from the analysis document.
budget_rows <- c(fair = "Fair comparison", rerun = "Re-run")

purpose_prefix <- function(value = Sys.getenv("FAIR_PURPOSE_PREFIX")) {
  value <- stringr::str_trim(value)
  if (!nzchar(value)) return("fair")
  if (!value %in% names(budget_rows)) stop("FAIR_PURPOSE_PREFIX must be fair or rerun")
  value
}

# JEV_CHECK_ONLY: "true" (any case, spaces trimmed) turns check-only mode on;
# empty or "false" turns it off; any other value stops the run.
check_only_mode <- function(value = Sys.getenv("JEV_CHECK_ONLY")) {
  value <- stringr::str_to_lower(stringr::str_trim(value))
  if (value %in% c("", "false")) return(FALSE)
  if (value == "true") return(TRUE)
  stop("JEV_CHECK_ONLY must be true or false, not '", value, "'")
}

# Call log of a run. Only JEV runs use the TypeSafe log, which the budget
# counts. Clef-Flash calls go to their own log.
call_log_path <- function(model, record_root = fair_record_root(),
                          timing_dir = fair_timing_dir()) {
  if (model == "jev") {
    file.path(record_root, "calls", "typesafe-calls.csv")
  } else {
    file.path(timing_dir, "clef-calls.csv")
  }
}

same_file <- function(a, b) {
  norm <- \(p) stringr::str_to_lower(normalizePath(p, winslash = "/", mustWork = FALSE))
  norm(a) == norm(b)
}

# The log file of a run. A JEV run always logs to the record log that the
# budget counts; another JEV_CALL_LOG stops it. A non-JEV run always gets its
# own log, whatever JEV_CALL_LOG holds.
select_call_log <- function(model, current = Sys.getenv("JEV_CALL_LOG"),
                            record_root = fair_record_root(),
                            timing_dir = fair_timing_dir()) {
  path <- call_log_path(model, record_root, timing_dir)
  if (model == "jev" && nzchar(current) && !same_file(current, path)) {
    stop("JEV_CALL_LOG names ", current, ", but a JEV run logs only to ", path,
         ", the log that the budget counts. Unset JEV_CALL_LOG.")
  }
  path
}

# The budget row of a purpose prefix in <record_root>/calls/README.md, and
# what the call log has used of it: the JEV rows whose purpose starts with
# the prefix. Clef-Flash rows never count. No row means no calls left.
budget_status <- function(prefix = "fair", record_root = fair_record_root()) {
  readme <- file.path(record_root, "calls", "README.md")
  log_file <- file.path(record_root, "calls", "typesafe-calls.csv")
  row_name <- budget_rows[[prefix]]
  rows <- if (file.exists(readme)) {
    stringr::str_subset(readLines(readme, warn = FALSE), "^\\|")
  } else {
    character()
  }
  cells <- stringr::str_split(rows, "\\|")
  budget <- purrr::keep(cells, \(x) length(x) >= 5 &&
                          stringr::str_starts(stringr::str_trim(x[4]), stringr::fixed(row_name)))
  number <- \(x) suppressWarnings(as.numeric(stringr::str_remove_all(x, "[ ,$]")))
  found <- length(budget) > 0L
  used <- 0L
  spent <- 0
  if (file.exists(log_file)) {
    calls <- readr::read_csv(log_file, show_col_types = FALSE,
                             col_types = readr::cols(.default = "c"))
    if (!"model" %in% names(calls)) {
      stop("The call log has no model column: ", log_file, ". The budget cannot tell JEV calls from others.")
    }
    counted <- calls |>
      dplyr::filter(.data$model == model_settings("jev")$model,
                    stringr::str_starts(.data$purpose, paste0(prefix, " ")))
    used <- nrow(counted)
    if ("cost_usd" %in% names(counted)) spent <- sum(number(counted$cost_usd), na.rm = TRUE)
  }
  max_calls <- if (found) number(budget[[1]][5]) else NA_real_
  max_cost <- if (found && length(budget[[1]]) >= 7) number(budget[[1]][6]) else NA_real_
  list(readme = readme, log = log_file, row = row_name, found = found,
       max_calls = max_calls, used = used, left = if (found) max_calls - used else 0,
       max_cost = max_cost, spent_usd = spent)
}

# Calls left in the budget row of a purpose prefix (0 when there is no row).
remaining_calls <- function(purpose_prefix = "fair", record_root = fair_record_root()) {
  budget_status(purpose_prefix, record_root)$left
}

# The record root of a paid JEV run: FAIR_RECORD_ROOT with no fallback. It
# must exist and have the budget row of the purpose prefix.
paid_record_root <- function(record_root = Sys.getenv("FAIR_RECORD_ROOT"), prefix = "fair") {
  if (!nzchar(record_root)) {
    stop("Set FAIR_RECORD_ROOT to the replication_materials folder of the record (on main). ",
         "A paid JEV run does not fall back to the copy on this branch.")
  }
  if (!dir.exists(record_root)) stop("FAIR_RECORD_ROOT does not exist: ", record_root)
  status <- budget_status(prefix, record_root)
  if (!status$found) {
    stop("No \"", status$row, "\" budget row in ", status$readme, ". Add the row first.")
  }
  normalizePath(record_root, winslash = "/")
}

# The record root of a run: checked for a paid JEV run; for a check-only or
# a Clef-Flash run, FAIR_RECORD_ROOT or the default.
run_record_root <- function(model, check_only, prefix = "fair",
                            value = Sys.getenv("FAIR_RECORD_ROOT")) {
  if (model == "jev" && !check_only) return(paid_record_root(value, prefix))
  if (nzchar(value)) value else "replication_materials"
}

# Prints the budget of a JEV run: README, calls left, spent and maximum cost.
print_budget <- function(status, n_images, check_only = FALSE) {
  cat("Budget README:", status$readme, "\n")
  if (!status$found) {
    cat("Budget row \"", status$row, "\": not found, so 0 calls left; ", n_images, " planned\n",
        sep = "")
    return(invisible(status))
  }
  cat("Budget row \"", status$row, "\": ", status$left, " calls left of ", status$max_calls,
      "; ", n_images, " planned; spent USD ", format(round(status$spent_usd, 6)),
      " of max USD ", status$max_cost, "\n", sep = "")
  if (check_only) {
    cat(if (n_images <= status$left) "The run would be allowed\n" else "The run would be stopped\n")
  }
  invisible(status)
}

# Name of the local GPU, or "local GPU" when nvidia-smi fails.
gpu_name <- function() {
  name <- tryCatch(
    suppressWarnings(system2("nvidia-smi", c("--query-gpu=name", "--format=csv,noheader"),
                             stdout = TRUE, stderr = FALSE)),
    error = \(e) character()
  )
  name <- stringr::str_trim(name)
  if (length(name) == 0L || !nzchar(name[[1]])) "local GPU" else name[[1]]
}

run_hardware <- function(model) {
  if (model == "jev") "TypeSafe API" else gpu_name()
}

# Adds one row to runs.csv: one scoring run. `candidate` is the loop
# candidate for a design run, NA otherwise. `audit_decision` is the decision
# ID that accepted a flagged loop audit (final runs), NA otherwise. A file
# without the newer columns gets them, and its rows stay as they were.
append_run <- function(timing_dir, model, description, k, dataset, split, n_images,
                       start, end, candidate = NA_integer_, hardware = run_hardware(model),
                       audit_decision = NA_character_) {
  utc <- \(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  dir.create(timing_dir, recursive = TRUE, showWarnings = FALSE)
  file <- file.path(timing_dir, "runs.csv")
  row <- tibble::tibble(
    model = model, description = description_label(description), k = k,
    dataset = dataset, split = split, candidate = as.integer(candidate),
    n_images = n_images, start_utc = utc(start), end_utc = utc(end),
    seconds = round(as.numeric(difftime(end, start, units = "secs")), 3),
    hardware = hardware, audit_decision = as.character(audit_decision)
  )
  header <- if (file.exists(file)) names(readr::read_csv(file, n_max = 0, show_col_types = FALSE))
  if (is.null(header) || identical(header, names(row))) {
    return(readr::write_csv(row, file, append = !is.null(header)))
  }
  readr::read_csv(file, show_col_types = FALSE, col_types = readr::cols(.default = "c")) |>
    dplyr::bind_rows(dplyr::mutate(row, dplyr::across(dplyr::everything(), as.character))) |>
    dplyr::select(dplyr::all_of(names(row))) |>
    readr::write_csv(file)
}

# Model settings, verbatim from the plan.
model_settings <- function(model) {
  switch(model,
    jev = list(model = "jev-1.13.0", base_url = "https://api.typesafe.ai/v1/systemone",
               image_format = "assets"),
    clef = list(model = "Cloudflare/clef-flash", base_url = "http://localhost:30000/v1/systemone",
                image_format = "images"),
    stop("FAIR_MODEL must be jev or clef")
  )
}

# The TypeSafe key goes only to the TypeSafe URL.
run_api_key <- function(settings) {
  if (settings$base_url == "https://api.typesafe.ai/v1/systemone") Sys.getenv("TYPESAFE_API_KEY") else "local"
}

generic_description <- function() {
  list(normal = "No visible manufacturing defects; the part appears conforming.",
       defective = "At least one visible manufacturing defect or anomaly.")
}

# Label of the description in file names: generic, final, or a CSV's name.
description_label <- function(description) {
  if (description %in% c("generic", "final")) {
    description
  } else {
    tools::file_path_sans_ext(basename(description))
  }
}

run_stem <- function(model, description, k, dataset) {
  paste0(model, "_", description_label(description), "_k", k, "_", dataset)
}

score_file_name <- function(model, description, k, dataset, split) {
  paste0(run_stem(model, description, k, dataset), "_", split, ".csv")
}

frozen_description_file <- function(model, dataset, description_dir) {
  file.path(description_dir, paste0(model, "_", dataset, ".csv"))
}

# md5 of the frozen description file of a model and dataset.
frozen_md5 <- function(model, dataset, description_dir = "results/fair/descriptions") {
  unname(tools::md5sum(frozen_description_file(model, dataset, description_dir)))
}

read_set <- function(name, sets_dir) {
  readr::read_csv(file.path(sets_dir, paste0(name, ".csv")), show_col_types = FALSE)
}

# References at k as list(normal = , defective = ); NULL for k = 0.
fair_references <- function(dataset, k, sets_dir = "results/fair/sets") {
  if (k == 0) return(NULL)
  refs <- read_set("references", sets_dir) |>
    dplyr::filter(.data$dataset == .env$dataset, .data$rank <= k)
  stopifnot(nrow(refs) == 2 * k)
  list(normal = refs$image_path[refs$actual_class == "nominal"],
       defective = refs$image_path[refs$actual_class == "defective"])
}

# Images of one split. Pans have no calibration file: their calibration set
# is L without the references at k (design section 4.4).
fair_images <- function(dataset, split, k, sets_dir = "results/fair/sets",
                        manifest = "results/image_split_manifest.csv") {
  ref_paths <- unlist(fair_references(dataset, k, sets_dir))
  images <- switch(split,
    design = read_set("design", sets_dir),
    calibration = if (dataset == "pan_images") {
      read_set("learning", sets_dir) |>
        dplyr::filter(!.data$image_path %in% ref_paths)
    } else {
      read_set("calibration", sets_dir)
    },
    test = readr::read_csv(manifest, show_col_types = FALSE) |>
      dplyr::filter(.data$split == "test"),
    stop("FAIR_SPLIT must be design, calibration or test")
  )
  images |>
    dplyr::filter(.data$dataset == .env$dataset) |>
    dplyr::select("dataset", "image_path", "defect_type", "actual_class")
}

# Criteria for the run: generic, a frozen file, or a candidate CSV.
fair_criteria <- function(description, model, dataset,
                          description_dir = "results/fair/descriptions") {
  if (description == "generic") return(generic_description())
  file <- if (description == "final") {
    frozen_description_file(model, dataset, description_dir)
  } else {
    description
  }
  d <- readr::read_csv(file, show_col_types = FALSE)
  list(normal = d$normal[[1]], defective = d$defective[[1]])
}

# The audit gate of a final run: the loop audit of the model and dataset must
# be clean ("none"), or a decision ID (for example D82) must accept its
# flagged rows. Returns the decision ID, or NA when the audit is clean.
check_audit <- function(model, dataset, loop_dir = "results/fair/loop", audit_decision = "") {
  audit_decision <- stringr::str_trim(audit_decision)
  file <- file.path(loop_dir, paste0(model, "-", dataset, "_audit.csv"))
  if (!file.exists(file)) {
    stop("No loop audit for ", model, " and ", dataset, ": ", file, ". Close the loop first.")
  }
  audit <- readr::read_csv(file, show_col_types = FALSE, col_types = readr::cols(.default = "c"))
  flagged <- sum(audit$tool != "none")
  if (flagged == 0L) return(NA_character_)
  if (!nzchar(audit_decision)) {
    stop("The loop audit of ", model, " and ", dataset, " has ", flagged, " flagged row(s): ",
         file, ". A person reviews them. Set FAIR_AUDIT_DECISION to the ID of the decision ",
         "that accepts them (for example D82).")
  }
  if (!stringr::str_detect(audit_decision, "^D[0-9]+$")) {
    stop("FAIR_AUDIT_DECISION must be a decision ID such as D82, not '", audit_decision, "'")
  }
  audit_decision
}

# Static guards: they need no image list, so the script runs them first.
# Only the configurations of design section 5.6 run, and the design split
# only with a candidate file at k = 2. Returns the audit decision of a final
# run (NA when the audit is clean or the run is not final).
check_config <- function(model, dataset, description, k, split, out,
                         description_dir = "results/fair/descriptions",
                         loop_dir = "results/fair/loop", audit_decision = "") {
  model_settings(model)
  if (!dataset %in% c(loop_datasets, "pan_images")) {
    stop("FAIR_DATASET must be one of ", paste(c(loop_datasets, "pan_images"), collapse = ", "))
  }
  if (!k %in% c(0, 1, 2, 4)) stop("FAIR_K must be 0, 1, 2 or 4")
  if (!split %in% c("design", "calibration", "test")) {
    stop("FAIR_SPLIT must be design, calibration or test")
  }
  is_path <- !description %in% c("generic", "final")
  if (is_path && split != "design") {
    stop("A candidate description file is only for the design split")
  }
  if (split == "design") {
    if (dataset == "pan_images") stop("The design split has no pan images")
    if (k != 2) stop("The design split needs k = 2")
    if (!is_path) stop("The design split needs a candidate description file")
  }
  if (description == "final" && dataset == "pan_images") {
    stop("Pans have no final description (they have no loop): use the generic description")
  }
  if (description == "generic" && dataset != "pan_images" && !k %in% c(0, 2)) {
    stop("The generic description runs at k = 0 and k = 2 only on ", dataset,
         " (design section 5.6)")
  }
  decision <- NA_character_
  if (description == "final") {
    frozen <- frozen_description_file(model, dataset, description_dir)
    if (!file.exists(frozen)) {
      stop("No frozen description for ", model, " and ", dataset, ": ", frozen)
    }
    decision <- check_audit(model, dataset, loop_dir, audit_decision)
  }
  if (is_path && !file.exists(description)) stop("Description file not found: ", description)
  stem <- run_stem(model, description, k, dataset)
  calibration_file <- file.path(out, score_file_name(model, description, k, dataset, "calibration"))
  test_file <- file.path(out, score_file_name(model, description, k, dataset, "test"))
  if (split == "calibration" && file.exists(calibration_file)) {
    stop("Calibration results already exist for ", stem, ". The calibration run is one-time.")
  }
  if (split == "test") {
    if (file.exists(test_file)) {
      stop("Test results already exist for ", stem, ". The test run is one-time.")
    }
    if (!file.exists(calibration_file)) {
      stop("No calibration file for ", stem, ". Run the calibration split first.")
    }
    if (description == "final") {
      calibration <- readr::read_csv(calibration_file, show_col_types = FALSE,
                                     col_types = readr::cols(.default = "c"))
      if (!"description_md5" %in% names(calibration)) {
        stop("The calibration file of ", stem, " has no description_md5 column")
      }
      if (!all(calibration$description_md5 == frozen_md5(model, dataset, description_dir))) {
        stop("The frozen description of ", model, " and ", dataset, " changed after the ",
             "calibration run (its md5 differs). The test run stops.")
      }
    }
  }
  invisible(decision)
}

# All guards. Stops with a clear message; in check-only mode the budget check
# prints and does not stop. A paid JEV run needs a checked record root. Every
# JEV run prints its budget. Returns the calls left (NA for clef) invisibly.
check_run <- function(model, dataset, description, k, split, out, n_images = 0,
                      record_root = fair_record_root(),
                      description_dir = "results/fair/descriptions",
                      loop_dir = "results/fair/loop", audit_decision = "",
                      check_only = FALSE, prefix = "fair") {
  check_config(model, dataset, description, k, split, out, description_dir, loop_dir,
               audit_decision)
  left <- NA_real_
  if (model == "jev") {
    if (!check_only) record_root <- paid_record_root(record_root, prefix)
    status <- budget_status(prefix, record_root)
    print_budget(status, n_images, check_only)
    left <- status$left
    if (!check_only && n_images > left) {
      stop("The run needs ", n_images, " calls. The budget row has ", left, " left.")
    }
  }
  invisible(left)
}

# Appends a row for a failed attempt that the client did not log (a
# connection error, for example), so that the call count stays honest.
log_failed_attempt <- function(log_file, started, model, image_path) {
  tibble::tibble(
    time_utc = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    call_id = paste0(format(started, "%Y%m%dT%H%M%OS3", tz = "UTC"), "-", basename(image_path)),
    purpose = Sys.getenv("JEV_CALL_PURPOSE", unset = "unspecified"),
    model = model, request_id = "", status = "error",
    latency_ms = round(as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000),
    input_tokens = NA_real_, output_tokens = NA_real_, cost_usd = NA_real_
  ) |>
    readr::write_csv(log_file, append = file.exists(log_file), na = "")
}

# One attempt at one image: the defect probability, or the error. An error
# that left no row in the call log goes to the log with status "error".
score_attempt <- function(image_path, references, criteria, settings, api_key,
                          log_file = Sys.getenv("JEV_CALL_LOG")) {
  size_before <- if (nzchar(log_file)) file.size(log_file) else NA
  started <- Sys.time()
  result <- tryCatch({
    answer <- classify_image(
      image_path = image_path, mode = "binary",
      reference_images = references, criteria = criteria,
      crop = "center", max_size = 768, upscale = FALSE,
      model = settings$model, base_url = settings$base_url,
      api_key = api_key, image_format = settings$image_format
    )
    probability <- answer$probability[answer$class == "defective"]
    if (length(probability) != 1L || !is.finite(probability)) stop("Invalid defect probability")
    probability
  }, error = identity)
  if (inherits(result, "error") && nzchar(log_file) && identical(file.size(log_file), size_before)) {
    log_failed_attempt(log_file, started, settings$model, image_path)
  }
  result
}

# Scores images one at a time and returns the table. The caller writes it.
# An image gets up to `attempts` attempts (an error or an invalid
# probability starts the next one, after the wait in `backoff`); the run
# stops after the last failed attempt. elapsed_ms is the wall time of all
# attempts for one image, with the image preparation and the waits.
score_images <- function(images, references, criteria, settings, model, description,
                         k, split, attempts = 3L, backoff = c(2, 8)) {
  api_key <- run_api_key(settings)
  purrr::map_dfr(seq_len(nrow(images)), function(i) {
    item <- images[i, ]
    started <- as.numeric(Sys.time())
    for (attempt in seq_len(attempts)) {
      probability <- score_attempt(item$image_path, references, criteria, settings, api_key)
      if (!inherits(probability, "error")) break
      if (attempt == attempts) stop(conditionMessage(probability), call. = FALSE)
      message("Image ", basename(item$image_path), ": attempt ", attempt, " failed (",
              conditionMessage(probability), "). Next attempt in ", backoff[[attempt]], " s.")
      Sys.sleep(backoff[[attempt]])
    }
    elapsed_ms <- round((as.numeric(Sys.time()) - started) * 1000, 1)
    tibble::tibble(
      dataset = item$dataset, image_path = item$image_path,
      defect_type = item$defect_type, actual_class = item$actual_class,
      prob_defective = probability, model = model,
      description = description_label(description), k = k, split = split,
      elapsed_ms = elapsed_ms
    )
  })
}

# Scores every image, then writes the file and one row to runs.csv. A
# failure leaves no file. A final run adds the md5 of its frozen description
# (description_md5); the test run checks it against the calibration file.
score_and_write <- function(images, references, criteria, settings, model,
                            description, k, split, out, dataset,
                            timing_dir = fair_timing_dir(), description_md5 = NA_character_,
                            audit_decision = NA_character_, ...) {
  start <- Sys.time()
  scores <- score_images(images, references, criteria, settings, model,
                         description, k, split, ...)
  end <- Sys.time()
  if (!is.na(description_md5)) scores$description_md5 <- description_md5
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(scores, file.path(out, score_file_name(model, description, k, dataset, split)))
  append_run(timing_dir, model, description, k, dataset, split, nrow(scores), start, end,
             audit_decision = audit_decision)
  invisible(scores)
}

# One check call before the paid runs (plan Task 8): one design image of
# extrusion, the generic description and k references per class (k = 4: 9
# images in the call). Purpose "fair check <model> k<k>": a JEV call goes to
# the record log and counts against the "Fair comparison" row; a Clef-Flash
# call goes to its own log. It writes nothing else.
check_call <- function(model, k, check_only = FALSE, sets_dir = "results/fair/sets",
                       record_root = run_record_root(model, check_only),
                       timing_dir = fair_timing_dir()) {
  settings <- model_settings(model)
  if (length(k) != 1L || is.na(k) || !k %in% c(0, 1, 2, 4)) stop("K must be 0, 1, 2 or 4")
  references <- fair_references("extrusion", k, sets_dir)
  image <- read_set("design", sets_dir) |>
    dplyr::filter(.data$dataset == "extrusion", !.data$image_path %in% unlist(references)) |>
    dplyr::slice(1)
  stopifnot(nrow(image) == 1L, all(file.exists(c(image$image_path, unlist(references)))))
  call_log <- select_call_log(model, Sys.getenv("JEV_CALL_LOG"), record_root, timing_dir)
  purpose <- paste("fair check", model, paste0("k", k))
  cat("Check call:", model, "| image", image$image_path, "|", k, "references per class |",
      2 * k + 1, "images in the call\n")
  cat("Purpose:", purpose, "\n")
  cat("Call log:", call_log, "\n")
  if (model == "jev") {
    status <- budget_status("fair", record_root)
    print_budget(status, 1, check_only)
    if (!check_only && status$left < 1) stop("No call is left in the budget row")
  }
  if (check_only) {
    cat("Check-only: no call.\n")
    return(invisible(NULL))
  }
  api_key <- run_api_key(settings)
  if (!nzchar(api_key)) stop("Set TYPESAFE_API_KEY")
  withr::local_envvar(JEV_CALL_LOG = call_log, JEV_CALL_PURPOSE = purpose)
  started <- Sys.time()
  probability <- score_attempt(image$image_path, references, generic_description(), settings,
                               api_key, call_log)
  latency_ms <- round(as.numeric(difftime(Sys.time(), started, units = "secs")) * 1000)
  if (inherits(probability, "error")) {
    stop("The check call failed: ", conditionMessage(probability), call. = FALSE)
  }
  cat("Probability (defective): ", probability, " | latency ", latency_ms, " ms\n", sep = "")
  if (model == "jev" && file.exists(call_log)) {
    last <- readr::read_csv(call_log, show_col_types = FALSE,
                            col_types = readr::cols(.default = "c")) |>
      utils::tail(1)
    cat("JEV: input tokens ", last$input_tokens, " | output tokens ", last$output_tokens,
        " | estimated cost USD ", format(as.numeric(last$cost_usd)), "\n", sep = "")
  }
  invisible(list(probability = probability, latency_ms = latency_ms))
}
