# Contributions

The researchers write this account. Claude Code can draft it. It is not complete until a researcher approves it.

| Item | Value |
|---|---|
| Status | draft, not approved |
| Written by | Claude Code (draft) |
| Approved by | - |

This draft lists only decisions that a researcher proposed (Proposed by fmm or yjc in `decisions.md`). The researchers can rewrite it, add what the record does not show, and remove what is wrong.

## Questions and design of the study

- Compare with the CLIP study on its own test sizes, and replicate CLIP with the learning-set sizes of that paper (D20, D28).
- Run CLIP on the same partition, a zero-shot ablation of JEV and a calibration check (D24).
- Compare Platt scaling with isotonic regression (D29).
- Report CLIP at a tuned threshold too, and use a CLIP baseline of 50 learning images per class as the benchmark (D58, D62).
- Calibrate CLIP as well, report all common metrics, and give every method the same learning set and the same calibration set (D67, D68, D69).

## Data

- Keep the image paths relative to the local `imgs/` folder (D2).
- Delete the duplicate pan images and the files with "copy" in their names (D15, D17).
- Test crop and smaller image sizes to reduce tokens (D9).
- Drop the real-textile transfer example (D30).

## Budget and scope

- Raise the paid-call cap, and later set the JEV budget to the free credit for a new user (D16, D26, D44).
- Wait with the repository until the scope is clear, and organize it before the first push (D32, D40).

## Paper and authorship

- Write the title and abstract of the MSEC 2027 submission, and add Ying-Ju (Tessa) Chen as a co-author (D37, D38).
- Put "(Few-Shot)" in parentheses in the title (D57).
- Cite the CLIP study as the 2026 journal article, use APA 7, and use short, direct headers (D43, D45, D46).

## Presentation

- A panelled progress chart (D8).
- Outfit and Cabin fonts, and group names in color in the subtitles instead of legends (D50, D51).
- Interactive tables, clearer method rows in figures F3 and F4, and figure F1 with its image sources (D53, D54, D55).
- The rendered analysis document on the record website (D56).
- Glyphs against the benchmark and a dot-chart column in table T4 (D60, D63).
- An renv lockfile for the R packages (D61).

## Record and code

- Keep a replication record (D1), and make it an honest guide that shows the contributions of the researchers, with a timeline, tags and results (D72, D73).
- Tag v0.0.1 before the redesign, and do the redesign on a branch (D64, D65).
- Write R code in tidyverse style with yardstick (D66).
