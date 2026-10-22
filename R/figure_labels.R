# Value labels for the figures that never overlap. Each label tries its
# candidate places in order and takes the first one that stays inside its
# panel and touches no mark (point, line, interval) and no label placed
# before it. A label with no free place is left out. A reference line
# (geom_hline, geom_vline, geom_abline) does not block a label: a white box
# under the label hides the line there. The geometry works in inches, at
# the size of the saved figure.

# TRUE for each segment (x1, y1)-(x2, y2) that comes within r of the box
# c(xmin, xmax, ymin, ymax): the segment is clipped to the box grown by r
# (Liang-Barsky). A point is a segment of length 0.
segments_hit_box <- function(x1, y1, x2, y2, r, box) {
  n <- length(x1)
  r <- rep_len(r, n)
  dx <- x2 - x1
  dy <- y2 - y1
  edges <- list(
    list(p = -dx, q = x1 - (box[[1]] - r)), list(p = dx, q = (box[[2]] + r) - x1),
    list(p = -dy, q = y1 - (box[[3]] - r)), list(p = dy, q = (box[[4]] + r) - y1)
  )
  inside <- rep(TRUE, n)
  t_in <- rep(0, n)
  t_out <- rep(1, n)
  for (edge in edges) {
    parallel <- edge$p == 0
    inside <- inside & !(parallel & edge$q < 0)
    t <- edge$q / edge$p
    t_in <- ifelse(!parallel & edge$p < 0, pmax(t_in, t), t_in)
    t_out <- ifelse(!parallel & edge$p > 0, pmin(t_out, t), t_out)
  }
  inside & t_in <= t_out
}

# Greedy placement in one panel. `candidates`: one row per candidate box
# (id, xmin, xmax, ymin, ymax), the candidates of a label in their order of
# preference, the labels in their order of priority. `obstacles`: segments
# (x1, y1, x2, y2) with their half width r. `bounds`: the panel as
# c(xmin, xmax, ymin, ymax). `pad`: the free space around each label.
# Returns the chosen rows and the number of the chosen candidate (`choice`).
place_labels <- function(candidates, obstacles, bounds, pad = 0) {
  placed <- matrix(numeric(), 0, 4)
  chosen <- list()
  for (label in unique(candidates$id)) {
    rows <- which(candidates$id == label)
    for (k in seq_along(rows)) {
      b <- unlist(candidates[rows[k], c("xmin", "xmax", "ymin", "ymax")], use.names = FALSE)
      if (b[1] < bounds[1] || b[2] > bounds[2] || b[3] < bounds[3] || b[4] > bounds[4]) next
      grown <- b + c(-pad, pad, -pad, pad)
      if (any(segments_hit_box(obstacles$x1, obstacles$y1, obstacles$x2, obstacles$y2,
                               obstacles$r, grown))) next
      if (any(placed[, 1] < grown[2] & placed[, 2] > grown[1] &
              placed[, 3] < grown[4] & placed[, 4] > grown[3])) next
      placed <- rbind(placed, b)
      row <- candidates[rows[k], ]
      row$choice <- k
      chosen[[length(chosen) + 1]] <- row
      break
    }
  }
  if (length(chosen) == 0) {
    none <- candidates[0, ]
    none$choice <- integer()
    return(none)
  }
  do.call(rbind, chosen)
}

# The marks of a built plot as segments in data units (after the scale
# transformation), with their half width in inches. Reference lines and
# other geoms are not marks here.
plot_obstacles <- function(built) {
  pt_in <- \(x) x / 72
  purrr::map2(built$plot$layers, built$data, \(layer, d) {
    geom <- class(layer$geom)[1]
    half <- \(lw) pt_in(dplyr::coalesce(lw, 0.5) * ggplot2::.pt / 2)
    segs <- function(x1, y1, x2, y2, r) {
      tibble::tibble(PANEL = d$PANEL, x1 = x1, y1 = y1, x2 = x2, y2 = y2, r = r)
    }
    switch(
      geom,
      GeomPoint = segs(d$x, d$y, d$x, d$y,
                       pt_in((d$size * ggplot2::.pt + dplyr::coalesce(d$stroke, 0) *
                                ggplot2::.stroke / 2) / 2)),
      GeomLinerange = if (isTRUE(d$flipped_aes[1])) {
        segs(d$xmin, d$y, d$xmax, d$y, half(d$linewidth))
      } else {
        segs(d$x, d$ymin, d$x, d$ymax, half(d$linewidth))
      },
      GeomLine = , GeomPath = , GeomStep = {
        d <- d[order(d$PANEL, d$group, if (geom == "GeomPath") seq_len(nrow(d)) else d$x), ]
        step <- geom == "GeomStep"
        purrr::map(split(d, list(d$PANEL, d$group), drop = TRUE), \(g) {
          n <- nrow(g)
          if (n < 2) return(NULL)
          i <- seq_len(n - 1)
          ends_y <- if (step) g$y[i] else g$y[i + 1]
          out <- tibble::tibble(PANEL = g$PANEL[i], x1 = g$x[i], y1 = g$y[i],
                                x2 = g$x[i + 1], y2 = ends_y, r = half(g$linewidth[i]))
          if (step) {
            out <- dplyr::bind_rows(out, tibble::tibble(
              PANEL = g$PANEL[i], x1 = g$x[i + 1], y1 = g$y[i], x2 = g$x[i + 1],
              y2 = g$y[i + 1], r = half(g$linewidth[i])
            ))
          }
          out
        }) |> dplyr::bind_rows()
      },
      NULL
    )
  }) |>
    dplyr::bind_rows() |>
    dplyr::filter(!is.na(PANEL))
}

# The width and height of one panel in inches, for a figure of `width` x
# `height` inches (all panels have the same size). Call it with a device open.
panel_size <- function(gtable, width, height) {
  size <- function(units, total, convert) {
    fixed <- convert(units, "in", valueOnly = TRUE)
    null <- ifelse(grid::unitType(units) == "null", as.numeric(units), 0)
    (total - sum(fixed[null == 0])) / sum(null)
  }
  panel <- gtable$layout[grepl("^panel", gtable$layout$name), ][1, ]
  null_w <- as.numeric(gtable$widths)[panel$l]
  null_h <- as.numeric(gtable$heights)[panel$t]
  c(width = size(gtable$widths, width, grid::convertWidth) * null_w,
    height = size(gtable$heights, height, grid::convertHeight) * null_h)
}

# Add the labels of `spec` to `plot` for a figure of `width` x `height`
# inches. `spec`: one row per candidate place, in order of priority, with
# id, x, y (data units: the anchor), side ("right", "left", "above",
# "below"), label, colour, an optional gap_pt (distance from the anchor; more
# than the radius of a point or the half width of a line at the anchor) and
# the facet columns of the plot. The labels are drawn in npc units (I()), so
# they never change the scales.
annotate_plot <- function(plot, spec, width, height, size_pt, family,
                          gap_pt = 3, pad_pt = 1) {
  file <- tempfile(fileext = ".png")
  ragg::agg_png(file, width = width, height = height, units = "in", res = 72)
  on.exit({
    grDevices::dev.off()
    unlink(file)
  }, add = TRUE)
  built <- ggplot2::ggplot_build(plot)
  panel <- panel_size(ggplot2::ggplot_gtable(built), width, height)
  layout <- built$layout$layout
  facets <- setdiff(intersect(names(spec), names(layout)), "PANEL")
  key <- \(d) if (length(facets) == 0) rep("", nrow(d)) else
    do.call(paste, c(lapply(d[facets], as.character), sep = "\r"))
  spec$PANEL <- layout$PANEL[match(key(spec), key(layout))]
  if (is.null(spec$gap_pt)) spec$gap_pt <- gap_pt

  transform <- function(axis, v) {
    scale <- built$plot$scales$get_scales(axis)
    if (is.null(scale)) v else scale$get_transformation()$transform(v)
  }
  obstacles <- plot_obstacles(built)
  w <- systemfonts::string_width(spec$label, family = family, size = size_pt, res = 7200) / 7200
  h <- size_pt * 0.95 / 72

  placed <- purrr::map(split(seq_len(nrow(spec)), spec$PANEL, drop = TRUE), \(rows) {
    s <- spec[rows, ]
    p <- as.integer(as.character(s$PANEL[1]))
    params <- built$layout$panel_params[[p]]
    to_x <- \(v) (v - params$x.range[1]) / diff(params$x.range) * panel[["width"]]
    to_y <- \(v) (v - params$y.range[1]) / diff(params$y.range) * panel[["height"]]
    ax <- to_x(transform("x", s$x))
    ay <- to_y(transform("y", s$y))
    gap <- s$gap_pt / 72 + pad_pt / 72 # the padding never blocks the own anchor
    sw <- w[rows]
    xmin <- dplyr::case_when(s$side == "right" ~ ax + gap, s$side == "left" ~ ax - gap - sw,
                             .default = ax - sw / 2)
    ymin <- dplyr::case_when(s$side == "above" ~ ay + gap, s$side == "below" ~ ay - gap - h,
                             .default = ay - h / 2)
    candidates <- data.frame(id = s$id, xmin = xmin, xmax = xmin + sw, ymin = ymin,
                             ymax = ymin + h, row = rows)

    o <- obstacles[as.integer(as.character(obstacles$PANEL)) == p, ] |>
      dplyr::filter(!is.na(x1), !is.na(x2), !is.na(y1), !is.na(y2)) |>
      dplyr::mutate(x1 = to_x(x1), x2 = to_x(x2), y1 = to_y(y1), y2 = to_y(y2))
    chosen <- place_labels(candidates, o, c(0, panel[["width"]], 0, panel[["height"]]),
                           pad = pad_pt / 72)
    out <- spec[chosen$row, ]
    out$npc_xmin <- chosen$xmin / panel[["width"]]
    out$npc_xmax <- chosen$xmax / panel[["width"]]
    out$npc_ymin <- chosen$ymin / panel[["height"]]
    out$npc_ymax <- chosen$ymax / panel[["height"]]
    out
  }) |>
    dplyr::bind_rows() |>
    dplyr::select(-"PANEL") # ggplot sets the panel from the facet columns

  plot +
    ggplot2::geom_rect(
      data = placed,
      ggplot2::aes(xmin = I(npc_xmin), xmax = I(npc_xmax), ymin = I(npc_ymin), ymax = I(npc_ymax)),
      inherit.aes = FALSE, fill = "white", colour = NA, show.legend = FALSE
    ) +
    ggplot2::geom_text(
      data = placed,
      ggplot2::aes(x = I((npc_xmin + npc_xmax) / 2), y = I((npc_ymin + npc_ymax) / 2),
                   label = label, colour = I(colour)),
      inherit.aes = FALSE, family = family, size = size_pt / ggplot2::.pt,
      show.legend = FALSE
    )
}
