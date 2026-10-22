repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(repo_root, "R", "figure_labels.R"))

box <- c(xmin = 0, xmax = 2, ymin = 0, ymax = 1)

test_that("segments_hit_box() finds segments that cross, enter or miss a box", {
  hits <- segments_hit_box(
    x1 = c(-1, 1, 3, -1, 2.5), y1 = c(0.5, 0.5, 3, 1.6, 2),
    x2 = c(3, 5, 4, 0.5, 2.5), y2 = c(0.5, 0.5, 4, 3, 2),
    r = 0, box = box
  )
  # across, one end inside, far away, diagonal past the corner, a point outside
  expect_equal(hits, c(TRUE, TRUE, FALSE, FALSE, FALSE))
})

test_that("segments_hit_box() counts the half width of a line or a point", {
  # A point 0.2 to the right of the box: a miss with r = 0.1, a hit with 0.3.
  expect_false(segments_hit_box(2.2, 0.5, 2.2, 0.5, r = 0.1, box = box))
  expect_true(segments_hit_box(2.2, 0.5, 2.2, 0.5, r = 0.3, box = box))
})

test_that("place_labels() takes the first candidate that is free", {
  candidates <- data.frame(
    id = c(1, 1), xmin = c(1, 3), xmax = c(2, 4), ymin = c(1, 1), ymax = c(2, 2)
  )
  free <- data.frame(x1 = numeric(), y1 = numeric(), x2 = numeric(), y2 = numeric(), r = numeric())
  blocked <- data.frame(x1 = 0, y1 = 1.5, x2 = 2.5, y2 = 1.5, r = 0)
  bounds <- c(0, 10, 0, 10)
  expect_equal(place_labels(candidates, free, bounds)$choice, 1)
  expect_equal(place_labels(candidates, blocked, bounds)$choice, 2)
})

test_that("place_labels() keeps labels inside the panel", {
  candidates <- data.frame(
    id = c(1, 1), xmin = c(9, 5), xmax = c(11, 7), ymin = c(1, 1), ymax = c(2, 2)
  )
  free <- data.frame(x1 = numeric(), y1 = numeric(), x2 = numeric(), y2 = numeric(), r = numeric())
  expect_equal(place_labels(candidates, free, c(0, 10, 0, 10))$choice, 2)
})

test_that("place_labels() drops a label that has no free candidate", {
  # Label 2 wants the place of label 1, then a place outside the panel.
  candidates <- data.frame(
    id = c(1, 2, 2), xmin = c(1, 1.5, 20), xmax = c(3, 3.5, 22),
    ymin = c(1, 1.2, 1), ymax = c(2, 2.2, 2)
  )
  free <- data.frame(x1 = numeric(), y1 = numeric(), x2 = numeric(), y2 = numeric(), r = numeric())
  placed <- place_labels(candidates, free, c(0, 10, 0, 10))
  expect_equal(placed$id, 1)
  # With padding, two boxes that only touch also collide.
  touching <- data.frame(id = c(1, 2), xmin = c(1, 3), xmax = c(3, 5), ymin = 1, ymax = 2)
  expect_equal(place_labels(touching, free, c(0, 10, 0, 10))$id, c(1, 2))
  expect_equal(place_labels(touching, free, c(0, 10, 0, 10), pad = 0.1)$id, 1)
})

test_that("annotate_plot() lets a label cross a reference line, on a white box", {
  d <- data.frame(x = 1, y = 3)
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y)) +
    ggplot2::geom_hline(yintercept = 3) +
    ggplot2::geom_vline(xintercept = 2) +
    ggplot2::geom_point(size = 1) +
    ggplot2::coord_cartesian(xlim = c(0, 7), ylim = c(0, 7))
  spec <- data.frame(id = 1, x = 1, y = 3, label = "a long label", colour = "black",
                     side = "right")
  out <- annotate_plot(p, spec, width = 4, height = 3, size_pt = 7, family = "sans")
  n <- length(out$layers)
  expect_equal(ggplot2::layer_data(out, n)$label, "a long label")
  box <- ggplot2::layer_data(out, n - 1)
  expect_s3_class(out$layers[[n - 1]]$geom, "GeomRect")
  expect_equal(box$fill, "white")
  expect_equal(nrow(box), 1)
})

test_that("annotate_plot() labels separate points and drops a label that would overlap", {
  d <- data.frame(x = c(1, 5, 5.02), y = c(1, 5, 5.02))
  p <- ggplot2::ggplot(d, ggplot2::aes(x, y)) +
    ggplot2::geom_point(size = 1) +
    ggplot2::coord_cartesian(xlim = c(0, 7), ylim = c(0, 7))
  # Two close points, both labeled on the right: the second label would
  # cover the first, so it is left out.
  spec <- data.frame(id = 1:3, x = d$x, y = d$y, label = c("first", "second", "third"),
                     colour = "black", side = "right")
  out <- annotate_plot(p, spec, width = 4, height = 3, size_pt = 7, family = "sans")
  shown <- ggplot2::layer_data(out, length(out$layers))
  expect_equal(sort(shown$label), c("first", "second"))
  # With a free place on the left, the third label is shown there.
  spec <- rbind(spec, transform(spec[3, ], side = "left"))
  out <- annotate_plot(p, spec, width = 4, height = 3, size_pt = 7, family = "sans")
  shown <- ggplot2::layer_data(out, length(out$layers))
  expect_equal(sort(shown$label), c("first", "second", "third"))
  third <- shown[shown$label == "third", ]
  second <- shown[shown$label == "second", ]
  expect_lt(as.numeric(third$x), as.numeric(second$x))
})
