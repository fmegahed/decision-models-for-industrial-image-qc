repo_root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(repo_root, "R", "description_diff.R"))

test_that("word_diff() gives the same, cut and added runs in order", {
  d <- word_diff("a smooth layer that lies flat", "a smooth layer with clean edges")
  expect_equal(d$op, c("same", "cut", "add"))
  expect_equal(d$text, c("a smooth layer", "that lies flat", "with clean edges"))
  expect_equal(word_diff("one two", "one two")$op, "same")
})

test_that("word_diff() folds a match of one or two words between changes into the change", {
  # Without the cleanup: cut x, add p, same the, cut y, add q.
  d <- word_diff("start x the y end", "start p the q end")
  expect_equal(d$op, c("same", "cut", "add", "same"))
  expect_equal(d$text, c("start", "x the y", "p the q", "end"))
})

test_that("word_diff() matches words without case and punctuation and shows the new words", {
  d <- word_diff("on the print surface.", "On the print Surface")
  expect_equal(d$op, "same")
  expect_equal(d$text, "On the print Surface")
})

test_that("kept_share() is the share of the new words that the old text had", {
  expect_equal(kept_share("a b c d", "a b c d"), 1)
  expect_equal(kept_share("a b", "a b c d"), 0.5)
  expect_lt(kept_share("No visible defects; the part conforms.",
                       "A close-up of a nozzle and freshly extruded plastic in a layer"), 0.25)
})

test_that("diff_markup() marks the runs in LaTeX and in HTML, and escapes the text", {
  latex <- diff_markup("width 5% & flat", "width 5% & edges", "latex")
  expect_equal(latex, "width 5\\% \\& \\textcolor{black!60}{\\sout{flat}} \\textcolor{model}{\\textbf{edges}}")
  html <- diff_markup("a <b> old", "a <b> new", "html")
  expect_equal(html, "a &lt;b&gt; <del>old</del> <ins>new</ins>")
  expect_equal(diff_markup(NA, "first & only", "latex"), "first \\& only")
  expect_match(diff_markup("a", "a b", "latex", color = "jev"), "\\textcolor{jev}{\\textbf{b}}",
               fixed = TRUE)
})
