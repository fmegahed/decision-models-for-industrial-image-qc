# Tests of five-color palettes for the figures (no API call, no cost). The
# five roles: JEV, Clef-Flash, CLIP, Platt and the defective class.
#
# Rscript scripts/palette_check.R
#   Each palette is tested on white:
#   - text contrast (WCAG 2.2): the colored words of the subtitles are text,
#     so AA needs 4.5:1;
#   - the separation of each pair of colors: the OKLab distance (x100) under
#     normal vision and under simulated protan, deutan and tritan vision
#     (Machado et al., 2009, severity 1.0). The dataviz validator asks for 8
#     or more under protan and deutan vision and 15 or more under normal
#     vision;
#   - the pairs that share a figure: the three models (F6), Platt and the
#     grey of the raw scores (F7), the defective class and the grey of the
#     nominal class (F1).
#   The key of a palette is its worst pair of min(protan, deutan, tritan,
#   normal / 2), with Platt also against the grey of the raw scores.
#   Published palettes are tested as they are and darkened to 4.5:1 (same
#   OKLCH hue), with the Miami Red or the Accent Red of Miami University for
#   the defective class; the other four roles take the colors with the best
#   key. A search on a 5-step sRGB grid (4.5:1 to 7.5:1, OKLCH chroma 0.10 to
#   0.20) shows the key that text-safe colors can reach. The palette of the
#   figures came from a search of the same kind on 2026-10-22; its key is
#   above the best key of this search.
# Writes palette_check.csv to results/palette/.

out_file <- "results/palette/palette_check.csv"
roles <- c("jev", "clef", "clip", "platt", "defective")
reds <- c("Miami Red" = "#C41230", "Accent Red" = "#AD102A")
greys <- c(raw = "#737373", nominal = "#4D4D4D") # grey45 and grey30
figure_palette <- c("#00829B", "#917300", "#0A4BC3", "#872D91", "#AD102A")

# Color math: sRGB, linear RGB, OKLab (Ottosson, 2020), WCAG contrast.
to_linear <- \(x) ifelse(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055)^2.4)
to_gamma <- \(x) ifelse(x <= 0.0031308, 12.92 * x, 1.055 * x^(1 / 2.4) - 0.055)
lms <- matrix(c(0.4122214708, 0.5363325363, 0.0514459929,
                0.2119034982, 0.6806995451, 0.1073969566,
                0.0883024619, 0.2817188376, 0.6299787005), 3, byrow = TRUE)
lab <- matrix(c(0.2104542553, 0.7936177850, -0.0040720468,
                1.9779984951, -2.4285922050, 0.4505937099,
                0.0259040371, 0.7827717662, -0.8086757660), 3, byrow = TRUE)
linear_oklab <- \(rgb) (rgb %*% t(lms))^(1 / 3) %*% t(lab)
oklab_linear <- \(x) ((x %*% t(solve(lab)))^3) %*% t(solve(lms))
# Machado, Oliveira and Fernandes (2009), severity 1.0, on linear RGB.
machado <- list(
  protan = matrix(c(0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216,
                    -0.003882, -0.048116, 1.051998), 3, byrow = TRUE),
  deutan = matrix(c(0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413,
                    -0.011820, 0.042940, 0.968881), 3, byrow = TRUE),
  tritan = matrix(c(1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602,
                    0.004733, 0.691367, 0.303900), 3, byrow = TRUE)
)
oklab <- function(hex, vision = "normal") {
  rgb <- to_linear(t(grDevices::col2rgb(hex)) / 255)
  if (vision != "normal") rgb <- pmin(pmax(rgb %*% t(machado[[vision]]), 0), 1)
  linear_oklab(rgb)
}
luminance <- \(hex) drop(to_linear(t(grDevices::col2rgb(hex)) / 255) %*% c(0.2126, 0.7152, 0.0722))
contrast <- function(hex, background = "#FFFFFF") {
  a <- luminance(hex)
  b <- luminance(background)
  (pmax(a, b) + 0.05) / (pmin(a, b) + 0.05)
}
visions <- c("normal", "protan", "deutan", "tritan")
distances <- \(hex, vision) 100 * as.matrix(stats::dist(oklab(hex, vision)))

# Darken one color in OKLCH (same hue, chroma cut to the sRGB gamut) until
# it reaches 4.5:1 on white.
darken <- function(hex, target = 4.5) {
  if (contrast(hex) >= target) return(hex)
  start <- oklab(hex)
  chroma <- sqrt(sum(start[2:3]^2))
  hue <- atan2(start[3], start[2])
  for (l in seq(start[1], 0.2, by = -0.002)) {
    for (ch in seq(chroma, 0, by = -0.002)) {
      rgb <- oklab_linear(matrix(c(l, ch * cos(hue), ch * sin(hue)), 1))
      if (all(rgb >= -1e-4 & rgb <= 1 + 1e-4)) break
    }
    out <- grDevices::rgb(pmin(pmax(to_gamma(rgb), 0), 1))
    if (contrast(out) >= target) return(out)
  }
  hex
}

# All measures of one palette (five colors in the order of `roles`).
score <- function(colors, name) {
  d <- purrr::map(rlang::set_names(visions), \(v) distances(c(colors, greys), v))
  cvd <- pmin(d$protan, d$deutan, d$tritan)
  worst <- purrr::map_dbl(d, \(m) min(m[1:5, 1:5][upper.tri(diag(5))]))
  key <- min(pmin(cvd, d$normal / 2)[1:5, 1:5][upper.tri(diag(5))],
             min(cvd[4, 6], d$normal[4, 6] / 2))
  tibble::tibble(
    palette = name, !!!rlang::set_names(as.list(colors), roles),
    min_contrast = min(contrast(colors)), !!!as.list(worst),
    models = min(cvd[1:3, 1:3][upper.tri(diag(3))]),
    platt_raw = cvd[4, 6], defective_nominal = cvd[5, 7], key = key
  )
}

# The best choice of four colors of a palette for the four roles.
best_roles <- function(colors, red, name) {
  colors <- setdiff(unique(colors), red)
  all <- c(colors, red, greys[["raw"]])
  d <- purrr::map(rlang::set_names(visions), \(v) distances(all, v))
  sep <- pmin(d$protan, d$deutan, d$tritan, d$normal / 2)
  red_i <- length(colors) + 1
  picks <- expand.grid(rep(list(seq_along(colors)), 4))
  picks <- picks[apply(picks, 1, \(p) !anyDuplicated(p)), , drop = FALSE]
  keys <- apply(picks, 1, \(p) {
    i <- c(p, red_i)
    min(sep[t(utils::combn(i, 2))], sep[p[4], red_i + 1])
  })
  score(c(colors[unlist(picks[which.max(keys), ])], red), name)
}

published <- list(
  "Dark2" = c("#1B9E77", "#D95F02", "#7570B3", "#66A61E", "#E6AB02", "#A6761D", "#666666"),
  "Okabe-Ito" = c("#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7"),
  "Tol bright" = c("#4477AA", "#228833", "#CCBB44", "#66CCEE", "#AA3377"),
  "Tol vibrant" = c("#EE7733", "#0077BB", "#33BBEE", "#EE3377", "#009988"),
  "Tol muted" = c("#332288", "#DDCC77", "#117733", "#88CCEE", "#882255", "#44AA99",
                  "#999933", "#AA4499"),
  "Brewer Set1" = c("#377EB8", "#4DAF4A", "#984EA3", "#FF7F00", "#A65628", "#F781BF"),
  "Tableau 10" = c("#4E79A7", "#F28E2B", "#76B7B2", "#59A14F", "#EDC948", "#B07AA1", "#9C755F"),
  "IBM" = c("#648FFF", "#785EF0", "#FE6100", "#FFB000")
)

# The search: the best four colors with one red, from several random starts.
# Each step puts the best color of the pool in one role.
search_palette <- function(red, name, starts = 40, seed = 202610) {
  steps <- seq(0, 255, by = 5)
  grid <- expand.grid(r = steps, g = steps, b = steps)
  hex <- grDevices::rgb(grid$r, grid$g, grid$b, maxColorValue = 255)
  chroma <- sqrt(rowSums(oklab(hex)[, 2:3]^2))
  ratio <- contrast(hex)
  pool <- hex[ratio >= 4.5 & ratio <= 7.5 & chroma >= 0.10 & chroma <= 0.20]
  n <- length(pool)
  labs <- purrr::map(rlang::set_names(visions), \(v) oklab(c(pool, red, greys[["raw"]]), v))
  sep <- function(i, j) {
    d <- purrr::map(labs, \(m) 100 * sqrt(colSums((t(m[i, , drop = FALSE]) - m[j, ])^2)))
    pmin(d$protan, d$deutan, d$tritan, d$normal / 2)
  }
  key_of <- \(i) min(apply(utils::combn(i, 2), 2, \(p) sep(p[1], p[2])), sep(i[4], n + 2))
  set.seed(seed)
  found <- purrr::map(seq_len(starts), \(start) {
    i <- c(sample(n, 4), n + 1)
    key <- key_of(i)
    repeat {
      better <- FALSE
      for (s in 1:4) {
        others <- i[-s]
        fixed <- min(apply(utils::combn(others, 2), 2, \(p) sep(p[1], p[2])))
        if (s != 4) fixed <- min(fixed, sep(i[4], n + 2))
        trial <- Reduce(pmin, purrr::map(others, \(o) sep(seq_len(n), o)))
        if (s == 4) trial <- pmin(trial, sep(seq_len(n), n + 2))
        trial <- pmin(trial, fixed)
        if (max(trial) > key + 1e-9) {
          i[s] <- which.max(trial)
          key <- max(trial)
          better <- TRUE
        }
      }
      if (!better) break
    }
    c(pool, red)[i]
  })
  best <- found[[which.max(purrr::map_dbl(found, \(colors) score(colors, "")$key))]]
  score(best, name)
}

results <- dplyr::bind_rows(
  score(c("#1B9E77", "#7570B3", "#D95F02", "#A6761D", "#E7298A"), "Dark2 as used until now"),
  purrr::imap(published, \(colors, name) purrr::imap(reds, \(red, red_name) dplyr::bind_rows(
    best_roles(colors, red, stringr::str_c(name, " + ", red_name)),
    best_roles(purrr::map_chr(colors, darken), red, stringr::str_c(name, " at 4.5:1 + ", red_name))
  )) |> dplyr::bind_rows()) |> dplyr::bind_rows(),
  purrr::imap(reds, \(red, red_name) search_palette(red, stringr::str_c("Search + ", red_name))) |>
    dplyr::bind_rows(),
  score(figure_palette, "Figures (chosen)")
)
dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(dplyr::mutate(results, dplyr::across(dplyr::where(is.double), \(x) round(x, 2))),
                 out_file)
print(dplyr::select(results, palette, min_contrast, normal:key), n = Inf, width = Inf)
