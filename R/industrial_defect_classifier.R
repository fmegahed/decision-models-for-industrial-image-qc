# TypeSafe/JEV industrial image classification
# Packages: httr2, magick, base64enc, tibble, purrr

#' Default defect definitions
#' @return Named character vector of defect descriptions.
#' @export
defect_labels <- function() {
  c(
    scratch = "An unwanted linear mark, abrasion, or gouge on the surface.",
    crack = "A visible fracture, split, or break in the material.",
    dent = "An unintended indentation or localized deformation.",
    contamination = "Unwanted dirt, residue, foreign matter, or staining.",
    missing_component = "A component that should be present is absent."
  )
}

#' Log one API call for the replication record
#' @param response httr2 response.
#' @param started Time the request started.
#' @param model,base_url Model identifier and endpoint of the call.
#' @param image_path The inspected image.
#' @return Nothing. Appends one row to the CSV named in `JEV_CALL_LOG`
#'   (columns of `replication_materials/calls/`); does nothing when it is unset.
#' @details The cost is input tokens times USD 0.042 per million for the
#'   TypeSafe endpoint, and empty for a failed call or a local server. The
#'   purpose comes from `JEV_CALL_PURPOSE` (the runner sets the trial ID).
log_call <- function(response, started, model, base_url, image_path) {
  log_file <- Sys.getenv("JEV_CALL_LOG")
  if (!nzchar(log_file)) return(invisible(NULL))
  ok <- !httr2::resp_is_error(response)
  usage <- if (ok) {
    httr2::resp_body_json(response, simplifyVector = FALSE)$usage
  }
  token_count <- function(x) if (is.null(x)) NA_real_ else x
  input_tokens <- token_count(usage$input_tokens)
  paid <- ok && grepl("api.typesafe.ai", base_url, fixed = TRUE)
  seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  row <- tibble::tibble(
    time_utc = format(started, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    call_id = paste0(format(started, "%Y%m%dT%H%M%OS3", tz = "UTC"), "-",
                     basename(image_path)),
    purpose = Sys.getenv("JEV_CALL_PURPOSE", unset = "unspecified"),
    model = model,
    request_id = httr2::resp_header(response, "x-request-id", default = ""),
    status = httr2::resp_status(response),
    latency_ms = round(seconds * 1000),
    input_tokens = input_tokens,
    output_tokens = token_count(usage$output_tokens),
    cost_usd = if (paid && !is.na(input_tokens)) {
      input_tokens * 0.042 / 1e6
    } else {
      NA_real_
    }
  )
  readr::write_csv(row, log_file, append = file.exists(log_file), na = "")
  invisible(NULL)
}

#' Prepare an image for TypeSafe
#' @param image_path Path to a JPEG or PNG image.
#' @param crop Either `"none"` or `"center"` for a centered square crop.
#' @param max_size Maximum image dimension (280 to 1568 pixels).
#' @param upscale If `TRUE`, enlarge smaller images so the longest side equals
#'   `max_size`. If `FALSE` (default), never enlarge; pad small images to 280.
#' @param rgb If `TRUE`, always write three color channels. Gray images are
#'   otherwise written with one channel, which some servers (SGLang with
#'   Clef-Flash) cannot read. The default keeps the bytes sent to TypeSafe.
#' @return List containing temporary JPEG `path` and final `width` and `height`.
#'   Delete the temporary file with `unlink()` after use.
#' @export
prepare_image <- function(image_path, crop = c("none", "center"),
                          max_size = 1568L, upscale = FALSE, rgb = FALSE) {
  crop <- match.arg(crop)
  if (!file.exists(image_path)) stop("Image not found: ", image_path)
  if (length(max_size) != 1L || is.na(max_size) ||
      max_size < 280 || max_size > 1568) {
    stop("`max_size` must be between 280 and 1568.")
  }
  
  image <- magick::image_orient(magick::image_read(image_path))
  info <- magick::image_info(image)
  
  if (crop == "center") {
    side <- min(info$width, info$height)
    image <- magick::image_crop(
      image, sprintf("%dx%d+0+0", side, side),
      gravity = "center", repage = TRUE
    )
  }
  
  info <- magick::image_info(image)
  scale <- max_size / max(info$width, info$height)
  if (!upscale) scale <- min(1, scale)
  width <- max(1L, floor(info$width * scale))
  height <- max(1L, floor(info$height * scale))
  if (scale != 1) {
    image <- magick::image_resize(image, sprintf("%dx%d!", width, height))
  }
  # Extreme aspect ratios may have a dimension below the API minimum.
  if (width < 280 || height < 280) {
    image <- magick::image_extent(
      image, sprintf("%dx%d", max(280, width), max(280, height)),
      gravity = "center", color = "white"
    )
  }
  
  image <- magick::image_convert(image, colorspace = "sRGB")
  if (rgb) image <- magick::image_convert(image, type = "TrueColor")
  path <- tempfile(fileext = ".jpg")
  magick::image_write(image, path, format = "jpeg", quality = 90)
  if (file.info(path)$size > 16 * 1024^2) {
    unlink(path)
    stop("Prepared image exceeds the 16 MiB image limit.")
  }
  info <- magick::image_info(image)
  list(path = path, width = info$width[[1]], height = info$height[[1]])
}

#' Select reproducible, nested reference images
#' @param train_dir Folder containing `nominal/` and `defective/`.
#' @param n_per_class Number of examples to use from each class.
#' @param seed Seed controlling the full ordering within each class.
#' @return Named list with `normal` and `defective` paths.
#' @details For an unchanged folder and seed, selecting the first 1, 3, or
#'   10 images produces nested sets. The class `nominal` maps to `normal`.
#' @export
select_reference_images <- function(train_dir = "pan_images/train",
                                    n_per_class = 1L, seed = 42L) {
  if (length(n_per_class) != 1L || is.na(n_per_class) ||
      n_per_class < 1 || n_per_class != as.integer(n_per_class)) {
    stop("`n_per_class` must be a positive integer.")
  }
  choose <- function(folder) {
    paths <- sort(list.files(
      file.path(train_dir, folder),
      pattern = "\\.(jpg|jpeg|png)$", full.names = TRUE,
      ignore.case = TRUE
    ))
    if (length(paths) < n_per_class) {
      stop("Not enough images in train/", folder)
    }
    set.seed(seed)
    ordered_paths <- sample(paths, size = length(paths))
    normalizePath(ordered_paths[seq_len(n_per_class)],
                  winslash = "/", mustWork = TRUE)
  }
  list(normal = choose("nominal"), defective = choose("defective"))
}

#' Classify an industrial inspection image with JEV
#' @param image_path Image to classify.
#' @param mode `"binary"`, `"multiclass"`, or `"multilabel"`.
#' @param defects Named vector of defect descriptions for nonbinary modes.
#' @param criteria Optional named list with `normal` and `defective` descriptions.
#'   When omitted, generic manufacturing criteria are used.
#' @param reference_images Optional list from [select_reference_images()].
#'   Reference guidance is supported for binary mode only.
#' @param threshold Cutoff for independent multilabel probabilities.
#' @param crop Whether to preserve the image or center-crop to a square.
#' @param max_size Maximum dimension in pixels.
#' @param upscale Passed to [prepare_image()] for the inspected and reference
#'   images.
#' @param api_key TypeSafe API key (defaults to environment variable).
#' @param model Model identifier.
#' @param base_url SystemOne endpoint. Change it only for a self-hosted,
#'   compatible model (for example Clef-Flash at
#'   `"http://localhost:30000/v1/systemone"`).
#' @param image_format `"assets"` (TypeSafe: named image assets, with reference
#'   examples linked to each criterion) or `"images"` (SGLang SystemOne servers
#'   such as Clef-Flash: an ordered image list, which ignores `assets`; the
#'   state text then says which image is which).
#' @return Tibble with one row per class: `image`, `mode`, `class`,
#'   `probability`, `predicted`, `confidence`, and `decision`.
#' @export
classify_image <- function(image_path,
                           mode = c("binary", "multiclass", "multilabel"),
                           defects = defect_labels(), reference_images = NULL,
                           criteria = NULL, threshold = 0.5,
                           crop = c("none", "center"),
                           max_size = 1568L, upscale = FALSE,
                           api_key = Sys.getenv("TYPESAFE_API_KEY"),
                           model = "jev-latest",
                           base_url = "https://api.typesafe.ai/v1/systemone",
                           image_format = c("assets", "images")) {
  mode <- match.arg(mode)
  crop <- match.arg(crop)
  image_format <- match.arg(image_format)
  if (!nzchar(api_key)) stop("Set the TYPESAFE_API_KEY environment variable.")
  if (!is.null(reference_images) && mode != "binary") {
    stop("Reference images currently support binary mode only.")
  }
  if (mode != "binary" && (is.null(names(defects)) ||
                           any(!nzchar(names(defects))) ||
                           "normal" %in% names(defects))) {
    stop("`defects` must be a named vector without a `normal` entry.")
  }
  if (mode == "multilabel" && (threshold < 0 || threshold > 1)) {
    stop("`threshold` must be between 0 and 1.")
  }
  
  # Add the test image to the asset map.
  rgb <- image_format == "images" # SGLang servers fail on gray JPEGs
  prepared <- prepare_image(image_path, crop, max_size, upscale, rgb = rgb)
  on.exit(unlink(prepared$path), add = TRUE)
  image_id <- "inspection_image_1"
  assets <- list()
  assets[[image_id]] <- list(
    type = "image", format = "jpg",
    data_base64 = base64enc::base64encode(prepared$path)
  )
  
  if (is.null(criteria)) {
    criteria <- list(
      normal = "No visible manufacturing defects; the part appears conforming.",
      defective = "At least one visible manufacturing defect or anomaly."
    )
  }
  if (!is.list(criteria) ||
      !all(c("normal", "defective") %in% names(criteria)) ||
      !all(vapply(criteria[c("normal", "defective")],
                  function(x) is.character(x) && length(x) == 1L && nzchar(x),
                  logical(1)))) {
    stop("`criteria` must be a list with nonempty `normal` and `defective` text.")
  }
  
  # Attach the fixed, labeled training references to the corresponding criteria.
  if (!is.null(reference_images)) {
    if (!all(c("normal", "defective") %in% names(reference_images))) {
      stop("`reference_images` needs `normal` and `defective` entries.")
    }
    for (label in c("normal", "defective")) {
      if (length(reference_images[[label]]) == 0L) {
        stop("No reference images for class: ", label)
      }
      ids <- character()
      for (path in reference_images[[label]]) {
        ref <- prepare_image(path, crop, max_size, upscale, rgb = rgb)
        id <- paste0("reference_", length(assets) + 1L)
        assets[[id]] <- list(
          type = "image", format = "jpg",
          data_base64 = base64enc::base64encode(ref$path)
        )
        unlink(ref$path)
        ids <- c(ids, id)
      }
      criteria[[label]] <- list(
        description = criteria[[label]],
        examples = as.list(ids)
      )
    }
  }
  
  if (mode == "binary") {
    questions <- list(quality = list(
      type = "choice",
      instructions = paste(
        "Inspect `inspection_image` for manufacturing defects.",
        "Select exactly one category."
      ),
      criteria = criteria
    ))
  } else if (mode == "multiclass") {
    questions <- list(quality = list(
      type = "choice",
      instructions = paste(
        "Identify the single primary defect in `inspection_image`.",
        "Choose normal if no listed defect is visible."
      ),
      criteria = as.list(c(normal = criteria$normal, defects))
    ))
  } else {
    questions <- lapply(defects, function(description) {
      list(type = "noul", instructions = paste(
        "Does `inspection_image` visibly contain this defect:", description
      ))
    })
  }
  
  request_body <- list(
    model = model,
    state = list(inspection_image = image_id),
    assets = assets,
    questions = questions
  )

  # SGLang SystemOne servers (for example Clef-Flash) ignore `assets`. They take
  # an ordered image list, so the state text says which image is which.
  if (image_format == "images") {
    legend <- "Image 1 is `inspection_image`, the image to inspect."
    if (!is.null(reference_images)) {
      position <- stats::setNames(seq_along(assets), names(assets))
      for (label in c("normal", "defective")) {
        ids <- unlist(criteria[[label]]$examples)
        legend <- c(legend, sprintf(
          "Reference images of the %s category: %s.", label,
          paste("image", position[ids], collapse = ", ")
        ))
        criteria[[label]] <- criteria[[label]]$description
      }
      questions$quality$criteria <- criteria
    }
    request_body <- list(
      model = model,
      state = paste(legend, collapse = " "),
      images = unname(lapply(assets, function(asset) {
        paste0("data:image/jpeg;base64,", asset$data_base64)
      })),
      questions = questions
    )
  }
  
  started <- Sys.time()
  response <- httr2::request(base_url) |>
    httr2::req_auth_bearer_token(api_key) |>
    httr2::req_headers("TypeSafe-Danger-Zone-Images" = "true") |>
    httr2::req_body_json(request_body, auto_unbox = TRUE) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()
  log_call(response, started, model, base_url, image_path)

  if (httr2::resp_is_error(response)) {
    stop("TypeSafe HTTP ", httr2::resp_status(response), ":\n",
         httr2::resp_body_string(response), call. = FALSE)
  }
  answers <- httr2::resp_body_json(response, simplifyVector = FALSE)$answers
  
  if (mode %in% c("binary", "multiclass")) {
    answer <- answers$quality
    if (is.null(answer$probabilities) || is.null(answer$choice)) {
      stop("Unexpected choice response from TypeSafe.")
    }
    probabilities <- unlist(answer$probabilities, use.names = TRUE)
    predicted <- names(probabilities) == answer$choice
    confidence <- if (is.null(answer$confidence)) NA_real_ else
      as.numeric(answer$confidence)
    decision <- if (answer$choice == "normal") "normal" else "defective"
  } else {
    probabilities <- vapply(names(defects), function(label) {
      value <- answers[[label]]$noul
      if (is.null(value)) stop("Missing answer for ", label)
      as.numeric(value)
    }, numeric(1))
    predicted <- probabilities >= threshold
    confidence <- NA_real_
    decision <- if (any(predicted)) "defective" else "normal"
  }
  
  tibble::tibble(
    image = basename(image_path), mode = mode,
    class = names(probabilities),
    probability = as.numeric(probabilities),
    predicted = as.logical(predicted),
    confidence = confidence, decision = decision
  )
}

#' Classify multiple images
#' @param image_paths Paths of test images.
#' @param ... Passed to [classify_image()].
#' @return Combined long-format prediction tibble.
#' @export
classify_images <- function(image_paths, ...) {
  purrr::map_dfr(image_paths, classify_image, ...)
}
