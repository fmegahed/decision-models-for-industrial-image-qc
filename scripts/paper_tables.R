# LaTeX versions of the main tables of beyond_clip_analysis.qmd, for the ASME
# class asmeconf, in one standalone document (tables.tex). The authors copy
# the tables they want into the paper. The tables come from the CSV files that
# the analysis document writes to tables/.
#
# Rscript scripts/paper_tables.R [output folder]   (default: tables/paper)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) > 0) args[[1]] else "tables/paper"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_table <- function(name) {
  readr::read_csv(file.path("tables", stringr::str_c(name, ".csv")),
                  col_types = readr::cols(.default = readr::col_character()))
}

# LaTeX for the marks and symbols of the CSV text (the tables are not
# escaped): the dagger, "<", a minus sign before a number, and k in math.
latex_text <- function(x) {
  x |>
    stringr::str_replace_all(stringr::fixed(" †"), "\\textsuperscript{\\dag}") |>
    stringr::str_replace_all(stringr::fixed("< "), "$<$\\,") |>
    stringr::str_replace_all("(?<![A-Za-z])-(?=\\d)", "$-$") |>
    stringr::str_replace_all("k = (\\d)", "$k = \\1$")
}
# Three decimals, as in the analysis document (the CSV files drop trailing zeros).
three <- function(x) formatC(as.numeric(x), format = "f", digits = 3)
# Three decimals, in bold for the best value: the highest, or the lowest with
# `lower`. Tied values are all bold.
bold_best <- function(x, lower = FALSE) {
  v <- as.numeric(x)
  best <- if (lower) min(v) else max(v)
  dplyr::if_else(v == best, stringr::str_c("\\textbf{", three(v), "}"), three(v))
}
dagger_note <- "\\textsuperscript{\\dag}Negative Platt slope: Platt scaling reverses the order of the raw scores."

# One table at the text width, in the 8 pt type of the paper. With `group`,
# the rows of each dataset go under a bold line with the dataset name.
# `col_names` replaces the column names in print (they may repeat there).
paper_table <- function(d, caption, label, align, group = FALSE, header = NULL,
                        widths = NULL, col_names = NULL) {
  d <- dplyr::mutate(d, dplyr::across(dplyr::everything(), latex_text))
  names(d) <- latex_text(names(d))
  shown <- if (group) dplyr::select(d, -Dataset) else d
  table <- kableExtra::kbl(shown, format = "latex", booktabs = TRUE,
                           escape = FALSE, caption = caption, label = label,
                           col.names = col_names %||% names(shown),
                           align = align, linesep = "", table.envir = "table*") |>
    kableExtra::kable_styling(font_size = 8)
  if (!is.null(header)) table <- kableExtra::add_header_above(table, header)
  for (column in names(widths)) {
    table <- kableExtra::column_spec(table, match(column, names(shown)),
                                     width = widths[[column]])
  }
  if (group) {
    runs <- rle(d$Dataset)
    table <- kableExtra::pack_rows(table, index = stats::setNames(runs$lengths, runs$values))
  }
  as.character(table)
}

# The paper reports accuracy, sensitivity, specificity, AUC, ECE and Brier
# (D99); the analysis document keeps all metrics. On the balanced test sets,
# accuracy equals balanced accuracy, also in each bootstrap sample (the
# bootstrap resamples within class), so the balanced-accuracy column of T6
# is the accuracy difference.
tables <- list(
  paper_table(
    read_table("T1_sets"),
    "Datasets and sets (images, nominal + defective).",
    "sets", align = "llrrrrr", widths = c(`Defect types` = "4.2cm")
  ),
  paper_table(
    read_table("T2_label_budget"),
    "Label budget: labeled images per class that each method needs ($k = 2$).",
    "budget", align = "lllcrrrrr",
    header = c(" " = 4, "Labeled images per class" = 5),
    widths = c(Learning = "3cm", `Images seen per test image, per class` = "2cm")
  ),
  paper_table(
    read_table("T5_main_results") |>
      dplyr::select(Dataset, Method, Accuracy, Sensitivity, Specificity, AUC, ECE, Brier) |>
      dplyr::mutate(dplyr::across(c(Accuracy, Sensitivity, Specificity, AUC), bold_best),
                    dplyr::across(c(ECE, Brier), \(x) bold_best(x, lower = TRUE)),
                    .by = Dataset),
    stringr::str_c("Main results on the test sets, after Platt scaling on C. Bold: the ",
                   "best value of each metric on each dataset (the lowest for ECE and ",
                   "Brier). ", dagger_note),
    "main", align = "lrrrrrr", group = TRUE
  ),
  paper_table(
    read_table("T6_paired_comparisons") |>
      dplyr::select(Dataset, Comparison, Model, Accuracy = `Balanced accuracy`, AUC,
                    `McNemar p`, `Holm p`),
    stringr::str_c("Paired comparisons on the test sets: difference (decision model ",
                   "minus the other side) and paired 95\\% bootstrap interval. The ",
                   "p-values test the accuracy: McNemar p is the exact McNemar test of ",
                   "the decisions at 0.5, and Holm p adjusts it over the 14 tests of each ",
                   "model. AUC has an interval and no test. A mark on a comparison ",
                   "applies to one of its two sides. ", dagger_note),
    "paired", align = "llrrrr", group = TRUE
  ),
  paper_table(
    read_table("T7_calibration") |>
      dplyr::select(Dataset, Method, `ECE raw`, `ECE Platt`, `Brier raw`, `Brier Platt`) |>
      dplyr::mutate(dplyr::across(-c(Dataset, Method), three)),
    stringr::str_c("Calibration on the test sets, before (raw) and after Platt scaling on C. ",
                   dagger_note),
    "calibration", align = "lrrrr", group = TRUE,
    header = c(" " = 1, "ECE" = 2, "Brier" = 2),
    col_names = c("Method", rep(c("Raw", "Platt"), 2))
  )
)

document <- c(
  "% Generated by scripts/paper_tables.R in fmegahed/decision-models-for-industrial-image-qc",
  "% from the CSV files in tables/. Do not edit this file: run the script again.",
  "% To use a table, copy it (from \\begin{table*} to \\end{table*}) into main.tex.",
  "% The captions are those of the analysis document; replace them with your own.",
  "\\documentclass[nohead,nofoot]{asmeconf}",
  "\\begin{document}",
  stringr::str_c(tables, collapse = "\n\n"),
  "",
  "\\end{document}"
)
writeLines(document, file.path(out_dir, "tables.tex"))
cat("Wrote", file.path(out_dir, "tables.tex"), "\n")
