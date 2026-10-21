# Blind description loop: sandbox maker, keep rule, loop log, audit of the
# agent transcript, and freeze. scripts/fair_make_sandbox.R,
# scripts/fair_close_loop.R and the design branch of scripts/fair_score.R
# call these. Needs R/fair_runner.R (generic_description, fair_references).

max_candidates <- 6L
keep_gain <- 0.02

loop_columns <- c("candidate", "time_utc", "normal", "defective", "auc",
                  "mean_score_by_type", "reason", "kept")

# --- keep rule ---------------------------------------------------------------

# log has candidate and auc, in order. Candidate 1 is always kept. A later
# candidate is kept when its AUC is at least 0.02 above the current best.
apply_keep_rule <- function(log, gain = keep_gain) {
  kept <- logical(nrow(log))
  best_auc <- NA_real_
  best <- NA_integer_
  for (i in seq_len(nrow(log))) {
    if (i == 1L || round(log$auc[[i]] - best_auc, 10) >= gain) {
      kept[[i]] <- TRUE
      best_auc <- log$auc[[i]]
      best <- as.integer(log$candidate[[i]])
    }
  }
  list(kept = kept, best = best, best_auc = best_auc)
}

# --- candidate and log files ---------------------------------------------------

write_candidate <- function(path, normal, defective, reason) {
  tibble::tibble(normal = normal, defective = defective, reason = reason) |>
    readr::write_csv(path)
}

# Strict read. A bad file stops the run before any paid call.
read_candidate <- function(path) {
  d <- suppressWarnings(readr::read_csv(path, show_col_types = FALSE,
                                       col_types = readr::cols(.default = "c")))
  if (nrow(readr::problems(d)) > 0L) stop("The candidate file has parsing problems: ", path)
  if (!setequal(names(d), c("normal", "defective", "reason"))) {
    stop("The candidate file needs the columns normal, defective and reason")
  }
  if (nrow(d) != 1L) stop("The candidate file needs exactly one data row")
  for (col in c("normal", "defective", "reason")) {
    if (is.na(d[[col]][[1]]) || !nzchar(stringr::str_trim(d[[col]][[1]]))) {
      stop("The candidate text '", col, "' is empty")
    }
  }
  list(normal = d$normal[[1]], defective = d$defective[[1]], reason = d$reason[[1]])
}

empty_loop_log <- function() {
  tibble::tibble(candidate = integer(), time_utc = character(), normal = character(),
                 defective = character(), auc = double(), mean_score_by_type = character(),
                 reason = character(), kept = logical())
}

read_loop_log <- function(path) {
  readr::read_csv(path, show_col_types = FALSE, col_types = readr::cols(
    candidate = "i", time_utc = "c", normal = "c", defective = "c", auc = "d",
    mean_score_by_type = "c", reason = "c", kept = "l"))
}

write_loop_log <- function(log, path) {
  readr::write_csv(dplyr::select(log, dplyr::all_of(loop_columns)), path)
}

# Stops when candidate n may not run now: at most 6, the next number only,
# and the scores file must not exist.
check_candidate_slot <- function(sandbox, n) {
  if (is.na(n) || n < 1L) stop("The candidate number must be 1 or more")
  if (n > max_candidates) stop("Use at most ", max_candidates, " candidates, including the generic one")
  log <- read_loop_log(file.path(sandbox, "loop_log.csv"))
  if (n != nrow(log) + 1L) {
    stop("The next candidate is number ", nrow(log) + 1L, ", not ", n)
  }
  if (file.exists(file.path(sandbox, "scores", paste0(n, ".csv")))) {
    stop("The scores file for candidate ", n, " already exists. Each candidate is scored once.")
  }
  invisible(TRUE)
}

# Writes the scores file (neutral image names), appends the log row, and
# recomputes the kept column over all rows. scores has the original paths.
finish_candidate <- function(sandbox, n, scores, map, text) {
  scores <- dplyr::left_join(scores, map, by = "image_path")
  stopifnot(!anyNA(scores$image))
  truth <- factor(scores$actual_class, levels = c("defective", "nominal"))
  auc <- yardstick::roc_auc_vec(truth, scores$prob_defective, event_level = "first")
  by_type <- scores |>
    dplyr::summarise(mean = mean(.data$prob_defective), .by = "defect_type") |>
    dplyr::mutate(text = paste0(.data$defect_type, "=", round(.data$mean, 3)))
  type_text <- paste(by_type$text, collapse = "; ")
  log_file <- file.path(sandbox, "loop_log.csv")
  log <- read_loop_log(log_file) |>
    dplyr::bind_rows(tibble::tibble(
      candidate = as.integer(n),
      time_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      normal = text$normal, defective = text$defective, auc = auc,
      mean_score_by_type = type_text, reason = text$reason, kept = NA))
  rule <- apply_keep_rule(log)
  log$kept <- rule$kept
  write_loop_log(log, log_file)
  # The scores file comes after the log row: a failure leaves the slot free.
  scores |>
    dplyr::transmute(image = .data$image, class = .data$actual_class,
                     defect_type = .data$defect_type, prob_defective = .data$prob_defective) |>
    readr::write_csv(file.path(sandbox, "scores", paste0(n, ".csv")))
  list(auc = auc, mean_score_by_type = type_text, best = rule$best,
       best_auc = rule$best_auc, kept = rule$kept[[nrow(log)]])
}

# --- sandbox ---------------------------------------------------------------------

clean_path <- function(p) {
  p <- stringr::str_replace_all(p, "\\\\", "/")
  p <- stringr::str_replace(p, "^/([A-Za-z])/", "\\1:/") # Git Bash form of a drive
  drive <- stringr::str_extract(p, "^[A-Za-z]:")
  rest <- stringr::str_remove(p, "^[A-Za-z]:")
  lead <- if (stringr::str_starts(rest, "/")) "/" else ""
  parts <- stringr::str_split(rest, "/")[[1]]
  out <- character()
  for (part in parts[nzchar(parts) & parts != "."]) {
    if (part == "..") {
      out <- if (length(out) > 0L && out[[length(out)]] != "..") out[-length(out)] else c(out, "..")
    } else {
      out <- c(out, part)
    }
  }
  paste0(dplyr::coalesce(drive, ""), lead, paste(out, collapse = "/"))
}

is_absolute_path <- function(p) {
  stringr::str_detect(p, "^([A-Za-z]:[/\\\\]|/|\\\\\\\\|~)")
}

# TRUE when path is the folder or lies below it.
path_inside <- function(path, folder) {
  path <- stringr::str_to_lower(clean_path(path))
  folder <- stringr::str_to_lower(clean_path(folder))
  path == folder || stringr::str_starts(path, paste0(folder, "/"))
}

fair_default_rscript <- "C:/Program Files/R/R-4.6.1/bin/Rscript.exe"

# Builds <sandbox_root>/<model>-<dataset>/ and the image map outside it.
# Returns the sandbox folder. All paths in design.csv are relative to repo.
make_sandbox <- function(model, dataset, sandbox_root, repo = ".",
                         sets_dir = file.path(repo, "results", "fair", "sets"),
                         map_dir = file.path(repo, "results", "fair", "loop"),
                         instructions = file.path(repo, "scripts", "fair_loop_instructions.md"),
                         record_root = file.path(repo, "replication_materials"),
                         rscript = fair_default_rscript) {
  repo <- normalizePath(repo, winslash = "/", mustWork = TRUE)
  sandbox_root <- normalizePath(sandbox_root, winslash = "/", mustWork = FALSE)
  if (path_inside(sandbox_root, repo)) {
    stop("The sandbox must not be inside the repository: ", sandbox_root)
  }
  if (dataset == "pan_images") stop("The loop has no pan images")
  sandbox <- file.path(sandbox_root, paste0(model, "-", dataset))
  if (dir.exists(sandbox)) stop("The sandbox folder already exists: ", sandbox)
  settings <- model_settings(model)
  record_root <- normalizePath(record_root, winslash = "/", mustWork = FALSE)

  design <- readr::read_csv(file.path(sets_dir, "design.csv"), show_col_types = FALSE) |>
    dplyr::filter(.data$dataset == .env$dataset)
  stopifnot(nrow(design) > 0L)
  refs <- fair_references(dataset, 2, sets_dir)

  for (d in c("images", "references", "candidates", "scores")) {
    dir.create(file.path(sandbox, d), recursive = TRUE)
  }
  # Shuffle with a fixed seed, so the image number does not show the class.
  design <- withr::with_seed(202610, dplyr::slice_sample(design, prop = 1)) |>
    dplyr::mutate(image = sprintf("img_%03d.%s", dplyr::row_number(),
                                  tools::file_ext(.data$image_path)))
  ok <- file.copy(file.path(repo, design$image_path), file.path(sandbox, "images", design$image))
  stopifnot(all(ok))
  design |>
    dplyr::transmute(image = .data$image, class = .data$actual_class,
                     defect_type = .data$defect_type) |>
    readr::write_csv(file.path(sandbox, "labels.csv"))
  dir.create(map_dir, recursive = TRUE, showWarnings = FALSE)
  design |>
    dplyr::select("image", "image_path") |>
    readr::write_csv(file.path(map_dir, paste0(model, "-", dataset, "_image_map.csv")))

  for (cls in c("normal", "defective")) {
    for (i in seq_along(refs[[cls]])) {
      from <- file.path(repo, refs[[cls]][[i]])
      ok <- file.copy(from, file.path(sandbox, "references",
                                      paste0(cls, "_", i, ".", tools::file_ext(from))))
      stopifnot(ok)
    }
  }
  generic <- generic_description()
  write_candidate(file.path(sandbox, "candidates", "1.csv"), generic$normal,
                  generic$defective, "Start: the generic description.")
  tibble::tibble(normal = generic$normal, defective = generic$defective) |>
    readr::write_csv(file.path(sandbox, "generic_description.csv"))
  write_loop_log(empty_loop_log(), file.path(sandbox, "loop_log.csv"))

  sandbox_abs <- normalizePath(sandbox, winslash = "/")
  default_map <- file.path(repo, "results", "fair", "loop")
  map_line <- if (identical(clean_path(normalizePath(map_dir, winslash = "/")),
                            clean_path(default_map))) {
    ""
  } else {
    paste0(" FAIR_MAP_DIR=\"", normalizePath(map_dir, winslash = "/"), "\"")
  }
  readr::write_lines(c(
    "#!/usr/bin/env bash",
    "# Scores one candidate on the design images. Usage: bash score.sh N",
    "set -e",
    "case \"$1\" in [1-6]) ;; *) echo \"Usage: bash score.sh N (N from 1 to 6)\"; exit 1 ;; esac",
    paste0("cd \"", repo, "\""),
    paste0("FAIR_MODEL=", model, " FAIR_DATASET=", dataset,
           " FAIR_K=2 FAIR_SPLIT=design",
           " FAIR_DESCRIPTION=\"", sandbox_abs, "/candidates/$1.csv\"",
           " FAIR_OUT=\"", sandbox_abs, "\"",
           " FAIR_RECORD_ROOT=\"", record_root, "\"",
           map_line,
           " \"", rscript, "\" scripts/fair_score.R")
  ), file.path(sandbox, "score.sh"))
  # The md5 of score.sh goes outside the sandbox. close_loop() checks it.
  writeLines(unname(tools::md5sum(file.path(sandbox, "score.sh"))),
             file.path(map_dir, paste0(model, "-", dataset, "_score_sh.md5")))

  defect_types <- design |>
    dplyr::filter(.data$actual_class == "defective") |>
    dplyr::distinct(.data$defect_type) |>
    dplyr::pull(.data$defect_type) |>
    sort() |>
    paste(collapse = ", ")
  text <- readLines(instructions, warn = FALSE) |>
    stringr::str_replace_all(stringr::fixed("{{dataset}}"), dataset) |>
    stringr::str_replace_all(stringr::fixed("{{defect_types}}"), defect_types) |>
    stringr::str_replace_all(stringr::fixed("{{model}}"),
                             if (model == "jev") "JEV" else "Clef-Flash") |>
    stringr::str_replace_all(stringr::fixed("{{score_command}}"), "bash score.sh N")
  readr::write_lines(text, file.path(sandbox, "LOOP.md"))
  sandbox
}

# --- audit and freeze -----------------------------------------------------------------

# TRUE when a path stays inside the sandbox. A relative path counts only when
# its first part is something that the sandbox holds.
inside_sandbox <- function(p, sandbox, top) {
  if (stringr::str_starts(p, "~")) return(FALSE)
  if (identical(p, "/dev/null")) return(TRUE)
  if (is_absolute_path(p)) return(path_inside(p, sandbox))
  cleaned <- clean_path(p)
  if (cleaned == "") return(TRUE)
  if (stringr::str_starts(cleaned, "\\.\\.")) return(FALSE)
  stringr::str_extract(cleaned, "^[^/]+") %in% top
}

# Tools that the loop agent may use. Any other tool is flagged (default deny).
# PowerShell goes through the same checks as Bash. TodoWrite reads no file.
allowed_tools <- c("Read", "Write", "Edit", "Glob", "Grep", "Bash", "PowerShell", "TodoWrite")

home_token <- "^(\\$\\{?(HOME|USERPROFILE|OLDPWD|HOMEPATH)|\\$env:|~|%(USERPROFILE|HOMEPATH|HOMEDRIVE)%)"

bash_flagged <- function(command, sandbox, top) {
  # The only allowed command: bash score.sh N (also ./score.sh N, or the absolute path).
  plain <- stringr::str_replace_all(command, "\\\\", "/") |>
    stringr::str_remove(stringr::fixed(paste0(clean_path(sandbox), "/")))
  pattern <- "^\\s*(bash\\s+|sh\\s+)?[\"']?(\\./)?score\\.sh[\"']?\\s+[1-6]\\s*$"
  if (stringr::str_detect(plain, pattern)) {
    return(FALSE)
  }
  tokens <- stringr::str_split(command, "[\\s\"'`;|&<>=()]+")[[1]]
  tokens <- tokens[nzchar(tokens)]
  if (any(stringr::str_detect(tokens, stringr::regex(home_token, ignore_case = TRUE)))) {
    return(TRUE)
  }
  paths <- tokens[is_absolute_path(tokens) | stringr::str_detect(tokens, "\\.\\.") |
                    stringr::str_detect(tokens, "[/\\\\]")]
  !all(purrr::map_lgl(paths, inside_sandbox, sandbox = sandbox, top = top))
}

# A write is allowed only to candidates/<n>.csv in the sandbox.
write_flagged <- function(p, sandbox, top) {
  if (!inside_sandbox(p, sandbox, top)) return(TRUE)
  resolved <- if (is_absolute_path(p)) clean_path(p) else clean_path(file.path(sandbox, p))
  relative <- substring(resolved, nchar(clean_path(sandbox)) + 2L)
  !stringr::str_detect(relative, "^candidates/[1-6]\\.csv$")
}

# Flags every tool call of a Claude Code JSONL transcript that uses a tool
# off the allow-list, names a path outside the sandbox, or writes any file
# other than a candidate file. An empty table means the loop was blind.
audit_transcript <- function(transcript, sandbox) {
  sandbox <- normalizePath(sandbox, winslash = "/", mustWork = TRUE)
  top <- c(".", list.files(sandbox, all.files = FALSE))
  empty <- tibble::tibble(time = character(), tool = character(), target = character())
  lines <- readLines(transcript, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(stringr::str_trim(lines))]
  rows <- purrr::map(lines, function(line) {
    entry <- tryCatch(jsonlite::fromJSON(line, simplifyVector = FALSE), error = \(e) NULL)
    content <- entry$message$content
    if (!is.list(content)) return(NULL)
    time <- as.character(entry$timestamp %||% NA_character_)
    purrr::map(content, function(block) {
      if (!identical(block$type, "tool_use")) return(NULL)
      input <- block$input
      tool <- as.character(block$name %||% "unknown")
      reads <- switch(tool,
        Read = input$file_path,
        Grep = input$path,
        Glob = c(input$path, glob_prefix(input$pattern)),
        NULL)
      flagged <- if (!tool %in% allowed_tools) {
        paste(tool, as.character(jsonlite::toJSON(input, auto_unbox = TRUE)))
      } else if (tool %in% c("Bash", "PowerShell")) {
        if (bash_flagged(input$command %||% "", sandbox, top)) input$command else character()
      } else if (tool %in% c("Write", "Edit")) {
        p <- input$file_path %||% ""
        if (!nzchar(p) || write_flagged(p, sandbox, top)) p else character()
      } else {
        reads <- reads[!is.na(reads) & nzchar(reads)]
        reads[!purrr::map_lgl(reads, inside_sandbox, sandbox = sandbox, top = top)]
      }
      if (length(flagged) == 0L) return(NULL)
      tibble::tibble(time = time, tool = tool, target = flagged)
    })
  })
  out <- dplyr::bind_rows(purrr::list_flatten(rows))
  if (nrow(out) == 0L) empty else out
}

# The part of a glob pattern before the first wildcard, when it names a path.
glob_prefix <- function(pattern) {
  if (is.null(pattern)) return(character())
  prefix <- stringr::str_extract(pattern, "^[^*?\\[{]*")
  if (is_absolute_path(prefix) || stringr::str_detect(prefix, "\\.\\.")) prefix else character()
}

# Closing step: audit, copy of the log, freeze of the best candidate.
# Refuses to overwrite a frozen file, and stops when score.sh changed; it
# checks both first so nothing is half done. map_dir holds the md5 of score.sh.
close_loop <- function(model, dataset, transcript, sandbox,
                       loop_dir = "results/fair/loop",
                       description_dir = "results/fair/descriptions",
                       map_dir = loop_dir) {
  frozen <- frozen_description_file(model, dataset, description_dir)
  if (file.exists(frozen)) stop("The description is already frozen: ", frozen)
  md5_file <- file.path(map_dir, paste0(model, "-", dataset, "_score_sh.md5"))
  if (!file.exists(md5_file)) stop("No md5 record of score.sh: ", md5_file)
  md5_now <- unname(tools::md5sum(file.path(sandbox, "score.sh")))
  if (!identical(md5_now, readLines(md5_file, warn = FALSE)[[1]])) {
    stop("score.sh changed after the sandbox was made. The loop is not valid.")
  }
  log <- read_loop_log(file.path(sandbox, "loop_log.csv"))
  if (nrow(log) == 0L) stop("The loop log has no candidate")
  rule <- apply_keep_rule(log)
  log$kept <- rule$kept
  audit <- audit_transcript(transcript, sandbox) |>
    dplyr::mutate(transcript = basename(transcript))
  dir.create(loop_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(description_dir, recursive = TRUE, showWarnings = FALSE)
  stem <- file.path(loop_dir, paste0(model, "-", dataset))
  log |>
    dplyr::select(dplyr::all_of(loop_columns)) |>
    dplyr::mutate(transcript = basename(transcript)) |>
    readr::write_csv(paste0(stem, "_log.csv"))
  readr::write_csv(audit, paste0(stem, "_audit.csv"))
  best <- log[log$candidate == rule$best, ]
  tibble::tibble(normal = best$normal[[1]], defective = best$defective[[1]]) |>
    readr::write_csv(frozen)
  list(best = rule$best, best_auc = rule$best_auc, audit_rows = nrow(audit))
}
