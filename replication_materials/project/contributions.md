# Contributions

The researchers write this account. Claude Code can draft it. It is not complete until a researcher approves it.

| Item | Value |
|---|---|
| Status | approved |
| Written by | Claude Code (draft) |
| Approved by | fmm (2026-10-22); section "R package decisions": fmm (2026-10-24) |

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

## R package decisions

Ying-Ju (Tessa) Chen is an author of the package decisions (milestone M3). The ideas of the package came from discussions between Fadel M. Megahed and Tessa Chen, and the package builds on their joint work:

- the adaptation of CLIP for few-shot image inspection in manufacturing quality control (Megahed et al., 2026);
- the working paper of this project, Beyond CLIP (Megahed & Chen, 2026a);
- the Python packages conformal-clip and conformal-clip-data (Megahed & Chen, 2025, 2026b).

These discussions took place outside the Claude Code sessions. So the decisions of this record show fmm as the person who proposed most of them. The package website shows the part of this record about the package at https://fmegahed.github.io/decisions/record/ (D224).

References:

- Megahed, F. M., & Chen, Y.-J. (2025). *conformal-clip-data* (Version 0.1.4) [Data set]. Python Package Index. https://pypi.org/project/conformal-clip-data/
- Megahed, F. M., & Chen, Y.-J. (2026a). *Beyond CLIP: Calibrated few-shot defect detection with structured decision models* [Manuscript in preparation]. https://github.com/fmegahed/decision-models-for-industrial-image-qc
- Megahed, F. M., & Chen, Y.-J. (2026b). *conformal-clip* (Version 0.2.2) [Computer software]. Python Package Index. https://pypi.org/project/conformal-clip/
- Megahed, F. M., Chen, Y.-J., Colosimo, B. M., Grasso, M., Jones-Farmer, L. A., Knoth, S., Sun, H., & Zwetsloot, I. M. (2026). Adapting OpenAI's CLIP model for few-shot image inspection in manufacturing quality control: An expository case study with multiple application examples. *Journal of Quality Technology, 58*(4), 415–441. https://doi.org/10.1080/00224065.2026.2640171
