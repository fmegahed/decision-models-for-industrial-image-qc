# Roadmap

## People

| ID | Name | Role | Link |
|---|---|---|---|
| fmm | Fadel M. Megahed | Owner | https://github.com/fmegahed |
| yjc | Ying-Ju (Tessa) Chen | Co-author | https://github.com/ying-ju |

## Milestones

| ID | Milestone | State | Plan | Ledger |
|---|---|---|---|---|
| M1 | Tune JEV on validation, test once, compare with CLIP and Clef-Flash (MSEC 2027 abstract) | done | - | - |
| M2 | Full MSEC 2027 paper: fmm and yjc write the text and make the method figure (D93, D106). Claude Code makes the data figures and the LaTeX tables in the style of fmm (D96, D97, D107), helps with the literature search and gives each reference in the .bib file a doi field (D93). Following the ASME position statement on AI, Claude Code writes no text of the paper and no observations (D105), and the paper discloses how AI tools were used. The paper is in the private repository fmegahed/decision-models-paper, linked to Overleaf (D94) | now | - | - |
| M3 | R package decisionqc | next | - | - |
| M4 | Record additions: releases, results, timeline and contributions (replication-materials 1.2.0) | done | plans/2026-10-20-record-additions-plan.md | plans/2026-10-20-record-additions-ledger.md |
| M5 | Fair comparison: shared label budget, blind description loop, calibration of all methods (v0.0.2) | done | plans/2026-10-20-fair-comparison-plan.md | plans/2026-10-20-fair-comparison-ledger.md |

## Open items

| ID | Item | Blocks | Owner |
|---|---|---|---|
| O1 | Test the refinement step (criteria and references) with smaller validation sets; test balanced accuracy settled at 10 to 20 validation images per class, but the ECE kept falling up to 50 (figure F7). | M2 | fmm |
| O2 | The client now logs each paid call (time, request ID, tokens, cost) when JEV_CALL_LOG is set; the past 4,654 JEV calls have no per-call log. | M3 | fmm |
| O3 | Extrusion frames come from video: consider a time-based split, because near-identical frames help methods with large learning sets. | M2 | fmm |
| O4 | Report the labeled images of each method (references plus validation images, against CLIP learning sets) in the full paper; table T5 of beyond_clip_analysis.qmd has the counts. | M2 | fmm |
| O5 | State in the paper that the audit of the description loop finds plausible reads outside the sandbox, not deliberate evasion: an interpreter one-liner (python -c, Rscript -e) can name a parent folder without a slash or '..', and the audit does not see it (ledger of M5, Task 4). | M2 | fmm |
| O6 | Write the AI-use disclosure that ASME asks for (position statement, section B): tools, versions, maker, access, dates and uses in the Acknowledgements, and how AI was used in the Methods. Claude Code collects the facts from the record; fmm and yjc write the text. | M2 | fmm |
