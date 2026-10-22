# Word diffs of the candidate descriptions of the description loop, for the
# paper table (LaTeX) and the page of all loops (HTML).

split_words <- function(text) stringr::str_split_1(stringr::str_squish(text), " ")
# Words match when they are equal without case and punctuation.
word_key <- function(words) stringr::str_to_lower(stringr::str_remove_all(words, "[[:punct:]]"))

# Table of the longest common subsequence of two word vectors.
lcs_table <- function(ka, kb) {
  m <- matrix(0L, length(ka) + 1, length(kb) + 1)
  for (i in rev(seq_along(ka))) for (j in rev(seq_along(kb))) {
    m[i, j] <- if (ka[i] == kb[j]) m[i + 1, j + 1] + 1L else max(m[i + 1, j], m[i, j + 1])
  }
  m
}

# Share of the words of `new` that `old` had, in the same order.
kept_share <- function(old, new) {
  m <- lcs_table(word_key(split_words(old)), word_key(split_words(new)))
  m[1, 1] / length(split_words(new))
}

# The diff of two texts as runs: op ("same", "cut" or "add") and text.
# A match of one or two words between two changes is part of the change,
# and in each changed passage the cut words come before the added ones, so
# that each change reads as the old text, then the new text. "same" runs
# show the new words.
word_diff <- function(old, new) {
  a <- split_words(old)
  b <- split_words(new)
  ka <- word_key(a)
  kb <- word_key(b)
  m <- lcs_table(ka, kb)
  op <- character()
  old_word <- character()
  new_word <- character()
  i <- 1
  j <- 1
  while (i <= length(a) || j <= length(b)) {
    if (i <= length(a) && j <= length(b) && ka[i] == kb[j]) {
      op <- c(op, "same"); old_word <- c(old_word, a[i]); new_word <- c(new_word, b[j])
      i <- i + 1
      j <- j + 1
    } else if (j <= length(b) && (i > length(a) || m[i, j + 1] >= m[i + 1, j])) {
      op <- c(op, "add"); old_word <- c(old_word, NA); new_word <- c(new_word, b[j])
      j <- j + 1
    } else {
      op <- c(op, "cut"); old_word <- c(old_word, a[i]); new_word <- c(new_word, NA)
      i <- i + 1
    }
  }
  same <- rle(op == "same")
  ends <- cumsum(same$lengths)
  starts <- ends - same$lengths + 1
  for (r in which(same$values & same$lengths <= 2)) {
    if (r > 1 && r < length(same$values)) op[starts[r]:ends[r]] <- "both"
  }
  change <- rle(op != "same")
  ends <- cumsum(change$lengths)
  starts <- ends - change$lengths + 1
  purrr::map(seq_along(change$values), \(r) {
    k <- starts[r]:ends[r]
    if (!change$values[r]) {
      return(tibble::tibble(op = "same", text = stringr::str_c(new_word[k], collapse = " ")))
    }
    cut <- k[op[k] %in% c("cut", "both")]
    add <- k[op[k] %in% c("add", "both")]
    tibble::tibble(
      op = c(if (length(cut) > 0) "cut", if (length(add) > 0) "add"),
      text = c(if (length(cut) > 0) stringr::str_c(old_word[cut], collapse = " "),
               if (length(add) > 0) stringr::str_c(new_word[add], collapse = " "))
    )
  }) |>
    dplyr::bind_rows()
}

latex_escape <- function(text) {
  text |>
    stringr::str_replace_all("\\\\", "\\\\textbackslash{}") |>
    stringr::str_replace_all("([&%$#_{}])", "\\\\\\1") |>
    stringr::str_replace_all("~", "\\\\textasciitilde{}") |>
    stringr::str_replace_all("\\^", "\\\\textasciicircum{}")
}
html_escape <- function(text) {
  text |>
    stringr::str_replace_all("&", "&amp;") |>
    stringr::str_replace_all("<", "&lt;") |>
    stringr::str_replace_all(">", "&gt;") |>
    stringr::str_replace_all('"', "&quot;")
}

# `new` against `old` in LaTeX (added words bold in the xcolor `color`, cut
# words struck through in grey; needs xcolor and ulem) or HTML (<ins> and
# <del>). With no `old`, the text of `new` alone.
diff_markup <- function(old, new, format = c("latex", "html"), color = "model") {
  format <- match.arg(format)
  escape <- if (format == "latex") latex_escape else html_escape
  if (is.na(old)) return(escape(new))
  d <- word_diff(old, new)
  marked <- purrr::map2_chr(d$op, escape(d$text), \(op, text) {
    if (format == "latex") {
      switch(op, same = text,
             add = stringr::str_c("\\textcolor{", color, "}{\\textbf{", text, "}}"),
             cut = stringr::str_c("\\textcolor{black!60}{\\sout{", text, "}}"))
    } else {
      switch(op, same = text,
             add = stringr::str_c("<ins>", text, "</ins>"),
             cut = stringr::str_c("<del>", text, "</del>"))
    }
  })
  stringr::str_c(marked, collapse = " ")
}
