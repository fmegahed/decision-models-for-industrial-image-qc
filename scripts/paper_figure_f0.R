# Figure F0 of the paper (introduction): the defect probabilities of the CLIP
# baseline on the test sets of the fair comparison. The baseline is the
# few-shot protocol of Megahed et al. (2026): 10 reference images per class for
# pans, 50 for the other datasets, and the text of no description. Reads the
# score files and metrics.csv only (no API call, no GPU). The style is that of
# the figures of beyond_clip_analysis.qmd; F1 to F8 are not touched.
#
# Rscript scripts/paper_figure_f0.R
#   F0_clip_compression: two panels, the full 0 to 1 scale and a zoom from
#   0.48 to 0.52 (D256). As PNG (600 dpi), PDF and SVG in figs/{one,two}-column/,
#   and as the paper PDF in figs/paper/{one,two}-column/.

figs_dir <- "figs"
scores_dir <- "results/fair/scores"

# Fonts: register the files in fonts/ for ragg (PNG) and showtext (PDF, SVG).
body_font <- "Cabin"
fonts <- list(
  Outfit = c(plain = "fonts/Outfit-SemiBold.ttf", bold = "fonts/Outfit-Bold.ttf",
             italic = "fonts/Outfit-SemiBold.ttf"),
  Cabin = c(plain = "fonts/Cabin-Regular.ttf", bold = "fonts/Cabin-Bold.ttf",
            italic = "fonts/Cabin-Italic.ttf")
)
known <- c(systemfonts::system_fonts()$family, systemfonts::registry_fonts()$family)
purrr::iwalk(fonts, \(f, family) {
  if (!family %in% known) {
    systemfonts::register_font(family, plain = f[["plain"]], bold = f[["bold"]],
                               italic = f[["italic"]], bolditalic = f[["bold"]])
  }
  sysfonts::font_add(family, regular = f[["plain"]], bold = f[["bold"]],
                     italic = f[["italic"]], bolditalic = f[["bold"]])
})

# Classes: grey45 for nominal (grey30 of F1 is too close to the red under
# protan vision: OKLab distance 5.8; grey45 gives 10.3), the Accent Red of
# Miami University for defective. Both reach 4.5:1 on white. The shapes (open
# circle, filled triangle) and the places of the strips (nominal above) keep
# the classes apart in grayscale.
class_colors <- c(nominal = "#737373", defective = "#AD102A")
class_shapes <- c(nominal = 1, defective = 17)
class_offset <- c(nominal = 0.17, defective = -0.17)

layouts <- list(
  "one-column" = list(width = 3.4, paper_width = 3.56, height = 2.7,
                      base_size = 8, label_size = 5.5, point_size = 0.8),
  "two-column" = list(width = 7.0, paper_width = 7.5, height = 2.9,
                      base_size = 9, label_size = 6, point_size = 1.1)
)

# Datasets from top to bottom, in the order of the other figures.
dataset_order <- c("pan_images", "extrusion", "textiles", "pipe_staple", "microstructure")
dataset_labels <- c(pan_images = "Metallic pans", extrusion = "Extrusion",
                    textiles = "Textiles", pipe_staple = "Pipe staple",
                    microstructure = "Microstructure")
row_of <- rlang::set_names(rev(seq_along(dataset_order)), dataset_order)

scores <- Sys.glob(file.path(scores_dir, "clip_baseline_k*_test.csv")) |>
  purrr::map(readr::read_csv, show_col_types = FALSE) |>
  purrr::list_rbind()
stopifnot(setequal(unique(scores$dataset), dataset_order))

# Accuracy (decision at 0.5) and AUC of the raw scores, as in Table 3.
metrics <- readr::read_csv("results/fair/summary/metrics.csv", show_col_types = FALSE) |>
  dplyr::filter(.data$model == "clip", .data$description == "baseline",
                .data$split == "test", .data$calibration == "raw",
                .data$metric %in% c("accuracy", "roc_auc")) |>
  dplyr::select("dataset", "metric", "value") |>
  tidyr::pivot_wider(names_from = "metric", values_from = "value")
stopifnot(nrow(metrics) == length(dataset_order))

# Two decimals, half up (0.695 gives 0.70).
fmt <- \(x) sprintf("%.2f", round(x + 1e-9, 2))
row_label <- function(dataset, layout) {
  m <- dplyr::filter(metrics, .data$dataset == .env$dataset)
  values <- stringr::str_c("Acc ", fmt(m$accuracy), ", AUC ", fmt(m$roc_auc))
  if (layout == "one-column") {
    stringr::str_c("**", dataset_labels[[dataset]], "**<br>", values)
  } else {
    stringr::str_c("**", dataset_labels[[dataset]], "** (", values, ")")
  }
}

# Each image once, at its strip; the vertical jitter is the same in every size.
points <- scores |>
  dplyr::mutate(
    class = factor(.data$actual_class, levels = names(class_colors)),
    jitter = withr::with_seed(2026, stats::runif(dplyr::n(), -0.08, 0.08)),
    y = row_of[.data$dataset] + class_offset[as.character(.data$class)] + .data$jitter
  )

theme_f0 <- function(spec) {
  ggplot2::theme_bw(base_size = spec$base_size, base_family = body_font) +
    ggplot2::theme(
      legend.position = "none",
      # The subtitle is one line, centered over the two panels.
      plot.title.position = "panel",
      plot.subtitle = ggtext::element_markdown(face = "bold", colour = "grey10", hjust = 0.5,
                                               margin = ggplot2::margin(0, 0, 6, 0)),
      panel.grid = ggplot2::element_blank(),
      strip.background = ggplot2::element_rect(fill = "grey95", colour = "grey70"),
      strip.text = ggplot2::element_text(face = "bold", colour = "grey10",
                                         size = ggplot2::rel(0.9)),
      axis.title = ggplot2::element_text(face = "bold", colour = "grey15"),
      axis.title.y = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(face = "bold", colour = "grey15"),
      axis.text.y = ggtext::element_markdown(face = "plain", hjust = 1, lineheight = 1.15),
      axis.ticks = ggplot2::element_line(colour = "grey15", linewidth = ggplot2::rel(1.6)),
      axis.ticks.length = ggplot2::unit(3, "pt")
    )
}

subtitle <- stringr::str_c(
  "CLIP baseline: <span style='color:", class_colors[["nominal"]], "'>nominal</span> and ",
  "<span style='color:", class_colors[["defective"]], "'>defective</span> test images"
)

# Two panels: the full scale, and a zoom from 0.48 to 0.52 (all scores lie
# between 0.482 and 0.517).
make_plot <- function(layout) {
  spec <- layouts[[layout]]
  views <- c(full = "Full scale", zoom = "0.48 to 0.52")
  data <- tidyr::expand_grid(view = factor(views, levels = views), points)
  limits <- tibble::tibble(view = factor(rep(views, each = 2), levels = views),
                           x = c(0, 1, 0.48, 0.52))
  # Direct labels of the two strips, right of the top row, in the full panel.
  key <- tibble::tibble(
    view = factor(views[["full"]], levels = views),
    class = factor(names(class_colors), levels = names(class_colors)),
    x = 0.56, y = max(row_of) + class_offset,
    label = c("Nominal", "Defective")
  )
  labels <- purrr::map_chr(dataset_order, row_label, layout = layout)

  ggplot2::ggplot(data, ggplot2::aes(.data$prob_defective, .data$y)) +
    ggplot2::geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey40",
                        linewidth = 0.4) +
    ggplot2::geom_blank(ggplot2::aes(x = .data$x), data = limits, inherit.aes = FALSE) +
    ggplot2::geom_point(ggplot2::aes(colour = .data$class, shape = .data$class),
                        size = spec$point_size, stroke = 0.35) +
    ggplot2::geom_text(ggplot2::aes(.data$x, .data$y, label = .data$label, colour = .data$class),
                       data = key, hjust = 0, family = body_font, fontface = "bold",
                       size = spec$label_size / ggplot2::.pt, inherit.aes = FALSE) +
    ggplot2::scale_colour_manual(values = class_colors) +
    ggplot2::scale_shape_manual(values = class_shapes) +
    ggplot2::scale_x_continuous(
      "Predicted defect probability",
      # Ticks away from the panel edges, so that the labels of the two panels
      # do not meet.
      breaks = \(lim) if (diff(lim) > 0.5) c(0, 0.5, 1) else c(0.49, 0.5, 0.51),
      labels = \(x) sub("\\.?0+$", "", sprintf("%.2f", x)),
      expand = ggplot2::expansion(mult = 0.03)
    ) +
    ggplot2::scale_y_continuous(breaks = row_of[dataset_order], labels = labels,
                                limits = c(0.6, max(row_of) + 0.4), expand = c(0, 0)) +
    ggplot2::facet_grid(cols = ggplot2::vars(.data$view), scales = "free_x") +
    ggplot2::labs(subtitle = subtitle) +
    theme_f0(spec) +
    ggplot2::theme(panel.spacing.x = ggplot2::unit(8, "pt"))
}

# Text as outlines in a PDF or SVG file (showtext).
save_outlined <- function(plot, file, open, width, height) {
  open(file, width = width, height = height)
  showtext::showtext_begin()
  print(plot)
  showtext::showtext_end()
  grDevices::dev.off()
}

save_f0 <- function(name) {
  purrr::iwalk(layouts, \(spec, layout) {
    plot <- make_plot(layout)
    dir.create(file.path(figs_dir, layout), recursive = TRUE, showWarnings = FALSE)
    stem <- file.path(figs_dir, layout, name)
    ragg::agg_png(stringr::str_c(stem, ".png"), width = spec$width, height = spec$height,
                  units = "in", res = 600)
    print(plot)
    grDevices::dev.off()
    devices <- list(pdf = grDevices::cairo_pdf, svg = grDevices::svg)
    purrr::iwalk(devices, \(open, extension) {
      save_outlined(plot, stringr::str_c(stem, ".", extension), open, spec$width, spec$height)
    })
    dir.create(file.path(figs_dir, "paper", layout), recursive = TRUE, showWarnings = FALSE)
    save_outlined(plot, stringr::str_c(file.path(figs_dir, "paper", layout, name), ".pdf"),
                  grDevices::cairo_pdf, spec$paper_width, spec$height)
  })
}

save_f0("F0_clip_compression")
print(dplyr::mutate(metrics, label = purrr::map_chr(.data$dataset, row_label, layout = "two-column")))
