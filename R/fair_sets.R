# Helpers for the shared learning, calibration, reference and design sets.
# Draws use withr::with_seed(), so they do not depend on call order and
# leave the global RNG unchanged.

# Images per defect type: floor(n / T) each, and one more for the first
# n %% T types (alphabetical). A type with too few images gives its
# remainder to the types that still have images.
type_quota <- function(available, n) {
  types <- sort(names(available))
  quota <- stats::setNames(rep(0L, length(types)), types)
  left <- min(n, sum(available))
  while (left > 0) {
    open <- types[quota[types] < available[types]]
    base <- left %/% length(open)
    extra <- left %% length(open)
    add <- base + (seq_along(open) <= extra)
    add <- pmin(add, available[open] - quota[open])
    quota[open] <- quota[open] + add
    left <- left - sum(add)
  }
  quota
}

# Calibration set C for one dataset. `pool` holds the candidates (columns
# dataset, image_path, defect_type, actual_class); `exclude` holds the
# near-copy paths to drop. Both classes get the same number of images.
draw_calibration <- function(pool, n_per_class = 25, seed = 202611,
                             exclude = character()) {
  pool <- pool |>
    dplyr::filter(!.data$image_path %in% exclude) |>
    dplyr::arrange(.data$image_path)
  nominal <- dplyr::filter(pool, .data$actual_class == "nominal")
  defective <- dplyr::filter(pool, .data$actual_class == "defective")
  n <- min(n_per_class, nrow(nominal), nrow(defective))
  withr::with_seed(seed, {
    drawn_nominal <- dplyr::slice_sample(nominal, n = n)
    quota <- type_quota(table(defective$defect_type), n)
    drawn_defective <- defective |>
      dplyr::group_split(.data$defect_type) |>
      purrr::map(\(x) dplyr::slice_sample(x, n = quota[[x$defect_type[1]]])) |>
      purrr::list_rbind()
  })
  dplyr::bind_rows(drawn_nominal, drawn_defective)
}

# One row for each dataset and class: available, excluded, drawn, shortfall.
# shortfall = n_per_class - drawn, so it is positive by design when a class
# has fewer images than n_per_class (pipe staple: 17 drawn, shortfall 8).
draw_report <- function(pool, drawn, exclude = character(), n_per_class = 25,
                        rule = NA_character_) {
  excluded <- pool |>
    dplyr::filter(.data$image_path %in% exclude) |>
    dplyr::count(.data$dataset, .data$actual_class, name = "excluded_near_copies")
  pool |>
    dplyr::filter(!.data$image_path %in% exclude) |>
    dplyr::count(.data$dataset, .data$actual_class, name = "available") |>
    dplyr::left_join(excluded, by = c("dataset", "actual_class")) |>
    dplyr::left_join(
      dplyr::count(drawn, .data$dataset, .data$actual_class, name = "drawn"),
      by = c("dataset", "actual_class")
    ) |>
    dplyr::mutate(
      excluded_near_copies = tidyr::replace_na(.data$excluded_near_copies, 0L),
      drawn = tidyr::replace_na(.data$drawn, 0L),
      shortfall = n_per_class - .data$drawn,
      rule = rule
    ) |>
    dplyr::select("dataset", "actual_class", "rule", "available",
                  "excluded_near_copies", "drawn", "shortfall")
}

# References of one dataset and class, ranks 1 to k_max.
draw_references_class <- function(x, k_max, seed) {
  x <- dplyr::arrange(x, .data$image_path)
  withr::with_seed(seed, {
    if (x$actual_class[1] == "nominal" || dplyr::n_distinct(x$defect_type) == 1) {
      picked <- dplyr::slice_sample(x, n = k_max)
    } else {
      types <- sample(sort(unique(x$defect_type)))
      shuffled <- x |>
        dplyr::group_split(.data$defect_type) |>
        purrr::set_names(purrr::map_chr(
          dplyr::group_split(x, .data$defect_type), \(g) g$defect_type[1]
        )) |>
        purrr::map(\(g) dplyr::slice_sample(g, prop = 1))
      type_for_rank <- types[(seq_len(k_max) - 1) %% length(types) + 1]
      occurrence <- stats::ave(seq_len(k_max), type_for_rank, FUN = seq_along)
      picked <- purrr::map2(type_for_rank, occurrence, \(t, j) shuffled[[t]][j, ]) |>
        purrr::list_rbind()
    }
  })
  dplyr::mutate(picked, rank = seq_len(nrow(picked)))
}

# References for every dataset and class; each has its own seeded call.
draw_references <- function(learning, k_max = 4, seed = 202610) {
  learning |>
    dplyr::group_split(.data$dataset, .data$actual_class) |>
    purrr::map(\(x) draw_references_class(x, k_max, seed)) |>
    purrr::list_rbind() |>
    dplyr::arrange(.data$dataset, .data$actual_class, .data$rank)
}
