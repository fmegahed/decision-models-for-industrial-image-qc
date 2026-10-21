# Scoring runner for the fair comparison: settings, image and reference
# sets, guards, and the scoring core. scripts/fair_score.R calls these.

fair_record_root <- function() {
  Sys.getenv("FAIR_RECORD_ROOT", unset = "replication_materials")
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

# Calls left in the "Fair comparison" budget row. The log rows whose purpose
# starts with the prefix count as used. No such row means no calls left.
remaining_calls <- function(purpose_prefix = "fair", record_root = fair_record_root()) {
  readme <- file.path(record_root, "calls", "README.md")
  rows <- if (file.exists(readme)) {
    stringr::str_subset(readLines(readme, warn = FALSE), "^\\|")
  } else {
    character()
  }
  cells <- stringr::str_split(rows, "\\|")
  budget <- purrr::keep(cells, \(x) length(x) >= 5 &&
                          stringr::str_starts(stringr::str_trim(x[4]), "Fair comparison"))
  if (length(budget) == 0L) return(0)
  max_calls <- as.numeric(stringr::str_remove_all(budget[[1]][5], "[ ,]"))
  log_file <- file.path(record_root, "calls", "typesafe-calls.csv")
  used <- 0L
  if (file.exists(log_file)) {
    used <- readr::read_csv(log_file, show_col_types = FALSE,
                            col_types = readr::cols(.default = "c")) |>
      dplyr::filter(stringr::str_starts(.data$purpose, purpose_prefix)) |>
      nrow()
  }
  max_calls - used
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

# Guards. Stops with a clear message; in check-only mode the budget check
# prints and does not stop. Returns the calls left (NA for clef) invisibly.
check_run <- function(model, dataset, description, k, split, out, n_images = 0,
                      record_root = fair_record_root(),
                      description_dir = "results/fair/descriptions",
                      check_only = FALSE) {
  model_settings(model)
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
  }
  if (description == "final") {
    frozen <- frozen_description_file(model, dataset, description_dir)
    if (!file.exists(frozen)) {
      stop("No frozen description for ", model, " and ", dataset, ": ", frozen)
    }
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
  }
  left <- NA_real_
  if (model == "jev") {
    left <- remaining_calls(record_root = record_root)
    if (check_only) {
      cat("Budget:", left, "calls left;", n_images, "planned;",
          if (n_images <= left) "the run would be allowed\n" else "the run would be stopped\n")
    } else if (n_images > left) {
      stop("The run needs ", n_images, " calls. The budget row has ", left, " left.")
    }
  }
  invisible(left)
}

# Scores images one at a time and returns the table. The caller writes it.
# The TypeSafe key goes only to the TypeSafe URL.
score_images <- function(images, references, criteria, settings, model, description,
                         k, split) {
  typesafe_url <- "https://api.typesafe.ai/v1/systemone"
  api_key <- if (settings$base_url == typesafe_url) Sys.getenv("TYPESAFE_API_KEY") else "local"
  purrr::map_dfr(seq_len(nrow(images)), function(i) {
    item <- images[i, ]
    answer <- classify_image(
      image_path = item$image_path, mode = "binary",
      reference_images = references, criteria = criteria,
      crop = "center", max_size = 768, upscale = FALSE,
      model = settings$model, base_url = settings$base_url,
      api_key = api_key, image_format = settings$image_format
    )
    probability <- answer$probability[answer$class == "defective"]
    if (length(probability) != 1L || !is.finite(probability)) stop("Invalid defect probability")
    tibble::tibble(
      dataset = item$dataset, image_path = item$image_path,
      defect_type = item$defect_type, actual_class = item$actual_class,
      prob_defective = probability, model = model,
      description = description_label(description), k = k, split = split
    )
  })
}
