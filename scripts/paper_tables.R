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
# A number in LaTeX: with thousands separators, or as m x 10^e.
big <- function(x) formatC(round(x), format = "d", big.mark = ",")
sci <- function(x, digits = 1) {
  x <- signif(x, digits + 1)
  e <- floor(log10(x))
  sprintf("$%.*f \\times 10^{%d}$", digits, x / 10^e, e)
}

# The latency glyph of Table 3 (D113): whiskers from P5 to P95, a box from Q1
# to Q3 and a tick at the median, on one log axis from 5 to 2,000 ms.
# \lataxis draws the axis in the header.
glyph_macros <- c(
  "\\newcommand{\\latx}[1]{\\fpeval{(ln(#1)/ln(10) - 0.69897)*0.38}in}",
  "\\newcommand{\\latglyph}[5]{\\begin{tikzpicture}[baseline=-0.6ex]",
  "  \\foreach \\t in {10,100,1000} \\draw[black!15, line width=0.3pt] (\\latx{\\t},-3.6pt) -- (\\latx{\\t},3.6pt);",
  "  \\draw[black!55, line width=0.4pt] (\\latx{#1},0) -- (\\latx{#2},0) (\\latx{#4},0) -- (\\latx{#5},0);",
  "  \\fill[black!25] (\\latx{#2},-2.3pt) rectangle (\\latx{#4},2.3pt);",
  "  \\draw[black, line width=0.9pt] (\\latx{#3},-3pt) -- (\\latx{#3},3pt);",
  "  \\path (0,0) (\\latx{2000},0);",
  "\\end{tikzpicture}}",
  "\\newcommand{\\lataxis}{\\begin{tikzpicture}[baseline=0pt, font=\\fontsize{6}{7}\\selectfont]",
  "  \\draw[black!50, line width=0.3pt] (0,0) -- (\\latx{2000},0);",
  "  \\foreach \\t in {10,100,1000} {\\draw[black!50, line width=0.3pt] (\\latx{\\t},0) -- (\\latx{\\t},-2pt);",
  "    \\node[anchor=north, inner sep=1pt] at (\\latx{\\t},-2pt) {\\t};}",
  "\\end{tikzpicture}}"
)

# Table 3: the six metrics of D99 (bold: D100), the latency glyph and median,
# the cost per 1,000 images and the GPU memory of the weights, in four groups
# (D113). The notes give the latency, the cost and the compute of each model;
# they are drafts until the authors decide how the paper reports compute.
main_table <- function() {
  # The row of T13 for each method of T5 and T8 (key): its method and k.
  keys <- tibble::tribble(
    ~key,                           ~Method,                 ~work_k,
    "JEV, k = 2",                   "JEV",                   2,
    "Clef-Flash, k = 2",            "Clef-Flash",            2,
    "CLIP baseline",                "CLIP baseline",         NA,
    "CLIP, same references, k = 2", "CLIP, same references", 2,
    "CLIP, zero-shot",              "CLIP, zero-shot",       0
  )
  num <- \(d) dplyr::mutate(d, dplyr::across(-dplyr::any_of(c("Dataset", "Method", "Hardware",
                                                                "Model", "Weight type")), as.numeric))
  time <- num(read_table("T8_time_per_image"))
  work <- num(read_table("T13_compute_work"))
  size <- num(read_table("T12_compute_size"))
  main_work <- work |>
    dplyr::inner_join(keys, by = "Method") |>
    dplyr::filter(is.na(work_k) | k == work_k) |>
    dplyr::select(Dataset, key, cost = `Cost per 1,000 images (USD)`, sd = `SD (USD)`)
  model_of <- \(m) dplyr::case_when(stringr::str_starts(m, "JEV") ~ "JEV",
                                    stringr::str_starts(m, "Clef") ~ "Clef-Flash",
                                    .default = "CLIP ViT-L/14")
  gpu <- stats::setNames(sprintf("%.1f", size$`Weights (GB)`), size$Model)
  gpu["JEV"] <- "API"

  d <- read_table("T5_main_results") |>
    dplyr::select(Dataset, Method, Accuracy, Sensitivity, Specificity, AUC, ECE, Brier) |>
    dplyr::mutate(dplyr::across(c(Accuracy, Sensitivity, Specificity, AUC), bold_best),
                  dplyr::across(c(ECE, Brier), \(x) bold_best(x, lower = TRUE)),
                  .by = Dataset) |>
    dplyr::mutate(key = stringr::str_remove(Method, " †$")) |>
    dplyr::left_join(dplyr::rename(time, key = Method), by = c("Dataset", "key")) |>
    dplyr::left_join(main_work, by = c("Dataset", "key"))
  stopifnot(nrow(d) == 25, !anyNA(d$Median), !anyNA(d$cost))
  # The standard deviation goes in the cells only when it is not 0.
  sd_zero <- all(d$sd == 0)
  cost_cell <- dplyr::case_when(d$cost == 0 ~ "0",
                                sd_zero ~ three(d$cost),
                                .default = stringr::str_c(three(d$cost), " $\\pm$ ", three(d$sd)))
  ms <- \(v) sprintf("%.1f", pmin(pmax(v, 5), 2000)) # inside the axis
  row <- stringr::str_c(
    "\\hspace{1em}", latex_text(d$Method), " & ",
    d$Accuracy, " & ", d$Sensitivity, " & ", d$Specificity, " & ", d$AUC, " & ", d$ECE, " & ",
    d$Brier, " & \\latglyph{", ms(d$P5), "}{", ms(d$Q1), "}{", ms(d$Median), "}{", ms(d$Q3),
    "}{", ms(d$P95), "} & ", big(d$Median), " & ", cost_cell, " & ",
    gpu[model_of(d$key)], " \\\\")
  body <- purrr::map(unique(d$Dataset), \(ds) {
    c(stringr::str_c("\\multicolumn{11}{@{}l}{\\textbf{", ds, "}}\\\\"),
      row[d$Dataset == ds],
      if (ds != dplyr::last(d$Dataset)) "\\addlinespace[2pt]")
  }) |> unlist()

  # Numbers of the notes.
  w <- \(method, ds, kk) dplyr::filter(work, Method == method, Dataset == ds, k == kk)
  clef <- dplyr::filter(size, Model == "Clef-Flash")
  clip <- dplyr::filter(size, Model == "CLIP ViT-L/14")
  hardware <- unique(time$Hardware[time$Method != "JEV, k = 2"])
  stopifnot(length(hardware) == 1)
  pans_tokens <- purrr::map_dbl(c(0, 1, 2, 4), \(kk) w("JEV", "Metallic pans", kk)$`Input tokens per call`)
  clef_k2 <- dplyr::filter(work, Method == "Clef-Flash", k == 2)$`GFLOPs per test image` * 1e9
  base_n <- range(dplyr::filter(work, Method == "CLIP baseline")$References)
  d_feat <- clip$`Feature length`
  encode <- clip$`GFLOPs, one image encoding` * 1e9
  latency_note <- stringr::str_c(
    "Box: Q1 to Q3; whiskers: 5th to 95th percentile; tick and number: median; log scale. ",
    "JEV: wall time of the call to the TypeSafe API, with the network. Clef-Flash and CLIP: one ",
    hardware, " GPU; CLIP after one warm-up call, without the one-time encoding of its references (see c).")
  cost_note <- stringr::str_c(
    "JEV: input tokens times USD 0.042 per million (the output tokens have no price in this estimate). ",
    if (sd_zero) "Every JEV call on a dataset had the same number of input tokens, so the standard deviation of the cost per image is 0. "
    else "The cells give the mean and the standard deviation of the cost per image. ",
    "Clef-Flash and CLIP run on a local GPU: no cost per image (the hardware and the energy are not counted).")
  compute_note <- stringr::str_c(
    "GPU memory: the weights of the model. ",
    "JEV runs on the servers of TypeSafe; its size and hardware are not public, and it needs no local GPU. ",
    "Each JEV call holds the test image and the $2k$ reference images, so the input tokens per call grow with $k$ ",
    "(pans: ", stringr::str_c(big(pans_tokens[1:3]), collapse = ", "), " and ", big(pans_tokens[4]),
    " tokens at $k = 0$, 1, 2 and 4), and so does the median time per image (pans: ",
    big(w("JEV", "Metallic pans", 0)$`Median (ms)`), " ms at $k = 0$, ",
    big(w("JEV", "Metallic pans", 4)$`Median (ms)`), " ms at $k = 4$). ",
    "Clef-Flash is a dense model with ", sprintf("%.2f", clef$`Parameters (billions)`),
    " billion parameters in ", clef$`Weight type`, " (2 bytes each): ",
    sprintf("%.1f", clef$`Weights (GB)`), " GB of weights. On one ", hardware, ", its SGLang server held ",
    sprintf("%.1f", clef$`GPU memory, measured (GB)`), " GB, with a reserve for its cache. ",
    "Like JEV, it reads the references in each call. At about 2 FLOPs per parameter and input token ",
    "(Kaplan et al., 2020), one test image at $k = 2$ needs ", sci(min(clef_k2)), " to ", sci(max(clef_k2)),
    " FLOPs, and its median time on pans grows from ", big(w("Clef-Flash", "Metallic pans", 0)$`Median (ms)`),
    " ms at $k = 0$ to ", big(w("Clef-Flash", "Metallic pans", 4)$`Median (ms)`), " ms at $k = 4$. ",
    "CLIP ViT-L/14 has ", sprintf("%.2f", clip$`Parameters (billions)`), " billion parameters, mostly in ",
    clip$`Weight type`, ": ", sprintf("%.2f", clip$`Weights (GB)`), " GB of weights on the GPU, and a peak of ",
    sprintf("%.2f", clip$`GPU memory, measured (GB)`), " GB while it encodes one image. ",
    "One test image needs one image encoding (", sci(encode), " FLOPs) and one comparison with the $n$ stored ",
    "features of the references, each of ", d_feat, " numbers ($2 \\times ", d_feat, " \\times n$ FLOPs): ",
    sci(2 * d_feat * base_n[2]), " FLOPs for the baseline ($n = ", base_n[2], "$; pans: ", base_n[1], ") and ",
    sci(2 * d_feat * 4), " FLOPs at $k = 2$ ($n = 4$), about ", sci(2 * d_feat * base_n[2] / encode, 0),
    " of the encoding. CLIP zero-shot also encodes its two prompts for each image (",
    sci(clip$`GFLOPs, two prompts` * 1e9), " FLOPs). CLIP encodes the references once, before the test images ",
    "($n$ encodings: ", sci(base_n[2] * encode), " FLOPs for the baseline); the latency does not include this. ",
    "Thus the latency of CLIP does not grow with $n$ until $n$ is near ", sci(0.01 * encode / (2 * d_feat), 0),
    ", where the comparison reaches 1\\% of the encoding, while the latency of JEV and Clef-Flash grows with $k$.")

  c("\\begin{table*}",
    stringr::str_c("\\caption{Main results on the test sets, after Platt scaling on C: predictive ",
                   "performance, latency, cost and compute. Bold: the best value of each metric on ",
                   "each dataset (the lowest for ECE and Brier); bold does not mark a significant ",
                   "difference (see the paired comparisons).}"),
    "\\label{tab:main}",
    "\\centering\\fontsize{8}{10}\\selectfont",
    "\\begin{threeparttable}",
    "\\setlength{\\tabcolsep}{3.2pt}",
    "\\begin{tabular}{@{}l rrrrrr @{\\hspace{14pt}} cr @{\\hspace{14pt}} r @{\\hspace{14pt}} r@{}}",
    "\\toprule",
    stringr::str_c(" & \\multicolumn{6}{c}{Predictive performance} & ",
                   "\\multicolumn{2}{c}{Latency per image (ms)\\tnote{a}} & ",
                   "\\multicolumn{1}{c}{Cost\\tnote{b}} & \\multicolumn{1}{c}{Compute\\tnote{c}}\\\\"),
    "\\cmidrule(r{6pt}){2-7}\\cmidrule(lr{6pt}){8-9}\\cmidrule(lr{6pt}){10-10}\\cmidrule(l){11-11}",
    stringr::str_c("Method & Acc. & Sens. & Spec. & AUC & ECE\\tnote{\\ddag} & Brier & \\lataxis & ",
                   "Median & \\makecell[r]{USD per\\\\1,000 images} & \\makecell[r]{GPU\\\\memory (GB)}\\\\"),
    "\\midrule",
    body,
    "\\bottomrule",
    "\\end{tabular}",
    "\\begin{tablenotes}[flushleft]\\footnotesize",
    "\\item[\\dag] Negative Platt slope: Platt scaling reverses the order of the raw scores.",
    # D101: ECE stays bold, with this note.
    stringr::str_c("\\item[\\ddag] ECE measures calibration only. Probabilities that stay near 0.5 ",
                   "can reach a low ECE while they separate the classes poorly; their Brier score then ",
                   "stays near 0.25, the score of a constant 0.5 (for example, the lowest ECE on ",
                   "extrusion, textiles and pipe staple). Read ECE with AUC and Brier."),
    stringr::str_c("\\item[a] ", latency_note),
    stringr::str_c("\\item[b] ", cost_note),
    stringr::str_c("\\item[c] ", compute_note),
    "\\end{tablenotes}",
    "\\end{threeparttable}",
    "\\end{table*}") |>
    stringr::str_c(collapse = "\n")
}

# One table at the text width (envir "table*") or the column width ("table"),
# in the 8 pt type of the paper. With `group`, the rows of each dataset go
# under a bold line with the dataset name. `col_names` replaces the column
# names in print (they may repeat there). `note` goes under the table, as
# wide as the table (threeparttable).
paper_table <- function(d, caption, label, align, group = FALSE, header = NULL,
                        widths = NULL, col_names = NULL, note = NULL,
                        envir = "table*") {
  d <- dplyr::mutate(d, dplyr::across(dplyr::everything(), latex_text))
  names(d) <- latex_text(names(d))
  shown <- if (group) dplyr::select(d, -Dataset) else d
  table <- kableExtra::kbl(shown, format = "latex", booktabs = TRUE,
                           escape = FALSE, caption = caption, label = label,
                           col.names = col_names %||% names(shown),
                           align = align, linesep = "", table.envir = envir) |>
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
  if (!is.null(note)) {
    # footnote() puts the note in through a regex replacement, which drops
    # single backslashes, so they go in doubled.
    table <- kableExtra::footnote(table,
                                  general = stringr::str_replace_all(note, stringr::fixed("\\"), "\\\\"),
                                  general_title = "", threeparttable = TRUE, escape = FALSE)
  }
  as.character(table)
}

# The descriptions that one description loop kept, each against the text it
# revised (R/description_diff.R): added words bold in the model color, cut
# words struck through. A text that keeps less than a quarter of the words
# of the text it revised is shown in full, with a dagger. The page of all
# loops, with the candidates that were not kept, is description_loops.html.
source("R/description_diff.R")
loops_page <- "https://fmegahed.github.io/decision-models-for-industrial-image-qc/pages/description_loops.html"
description_table <- function(model, dataset) {
  log <- readr::read_csv(file.path("results/fair/loop", stringr::str_c(model, "-", dataset, "_log.csv")),
                         col_types = readr::cols(candidate = "i", auc = "d", kept = "l", .default = "c")) |>
    dplyr::filter(kept)
  cell <- function(old, new) {
    if (is.na(old)) return(latex_escape(new))
    if (kept_share(old, new) < 0.25) return(stringr::str_c(latex_escape(new), "\\textsuperscript{\\dag}"))
    diff_markup(old, new, "latex", color = model)
  }
  rows <- purrr::map_chr(seq_len(nrow(log)), \(i) {
    stringr::str_c(
      log$candidate[i], " & ", formatC(log$auc[i], format = "f", digits = 2), " & ",
      cell(if (i == 1) NA else log$normal[i - 1], log$normal[i]), " & ",
      cell(if (i == 1) NA else log$defective[i - 1], log$defective[i]), " \\\\"
    )
  })
  names <- c(jev = "JEV", clef = "Clef-Flash")
  c(
    "\\begin{table*}",
    stringr::str_c(
      "\\caption{\\label{tab:description-", model, "-", dataset, "}The descriptions that the ",
      names[[model]], " description loop kept for ", stringr::str_replace_all(dataset, "_", " "),
      " (Fig.~F2), each against the text it revised: added words in color and bold, removed ",
      "words struck through. Design AUC: on the design set of the loop. \\dag\\ Written anew ",
      "(keeps less than a quarter of the words of the text it revised). All eight loops, with ",
      "the candidates that the loops did not keep: \\url{", loops_page, "}.}"
    ),
    "\\centering",
    "\\fontsize{8}{10}\\selectfont",
    "\\begin{tabularx}{\\textwidth}{@{}cc>{\\raggedright\\arraybackslash}X>{\\raggedright\\arraybackslash}X@{}}",
    "\\toprule",
    "Candidate & Design AUC & Nominal description & Defective description \\\\",
    "\\midrule",
    rows,
    "\\bottomrule",
    "\\end{tabularx}",
    "\\end{table*}"
  ) |>
    stringr::str_c(collapse = "\n")
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
  main_table(),
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
  ),
  # D103: precision at lower defect rates (T11), one column wide.
  paper_table(
    read_table("T11_precision_defect_rate") |>
      dplyr::select(Dataset, Method, `Precision at 50%`, `Precision at 5%`, `Precision at 1%`) |>
      dplyr::mutate(dplyr::across(-c(Dataset, Method), three)),
    stringr::str_c("Precision at lower defect rates, from the test sensitivity and ",
                   "specificity after Platt scaling on C (decision at 0.5), if the ",
                   "scores of each class keep their distribution. ", dagger_note),
    "prevalence", align = "lrrr", group = TRUE, envir = "table",
    header = c(" " = 1, "Defect rate" = 3),
    col_names = c("Method", "50\\%", "5\\%", "1\\%")
  ),
  # D124: one loop in the paper; all loops on description_loops.html.
  description_table("jev", "extrusion")
)

document <- c(
  "% Generated by scripts/paper_tables.R in fmegahed/decision-models-for-industrial-image-qc",
  "% from the CSV files in tables/. Do not edit this file: run the script again.",
  "% To use a table, copy it (from \\begin{table*} to \\end{table*}) into main.tex.",
  "% The captions and the notes are drafts; replace them with your own.",
  "% Table 3 has notes under it and needs \\usepackage{threeparttable}. It",
  "% also needs makecell and tikz, and the three macros below (\\latx,",
  "% \\latglyph and \\lataxis): copy them into the preamble of main.tex.",
  "% The description table needs tabularx, xcolor, ulem (normalem) and the",
  "% color jev below.",
  "\\documentclass[nohead,nofoot]{asmeconf}",
  "\\usepackage{threeparttable,makecell,tikz,tabularx,xcolor}",
  "\\usepackage[normalem]{ulem}",
  "\\definecolor{jev}{HTML}{00829B}",
  glyph_macros,
  "\\begin{document}",
  "\\twocolumn % as in the paper (asmeconf starts two columns in \\maketitle)",
  stringr::str_c(tables, collapse = "\n\n"),
  "",
  "\\end{document}"
)
writeLines(document, file.path(out_dir, "tables.tex"))
cat("Wrote", file.path(out_dir, "tables.tex"), "\n")
