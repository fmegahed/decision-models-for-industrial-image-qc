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
| M2 | Full MSEC 2027 paper | planned | - | - |
| M3 | R package decisionqc | planned | - | - |
| M4 | Record additions: releases, results, timeline and contributions (replication-materials 1.2.0) | now | plans/2026-10-20-record-additions-plan.md | - |
| M5 | Fair comparison: shared label budget, blind description loop, calibration of all methods (v0.1.0) | next | plans/2026-10-20-fair-comparison-plan.md | - |

## Open items

| ID | Item | Blocks | Owner |
|---|---|---|---|
| O1 | Test the refinement step (criteria and references) with smaller validation sets; test balanced accuracy settled at 10 to 20 validation images per class, but the ECE kept falling up to 50 (figure F7). | M2 | fmm |
| O2 | The client now logs each paid call (time, request ID, tokens, cost) when JEV_CALL_LOG is set; the past 4,654 JEV calls have no per-call log. | M3 | fmm |
| O3 | Extrusion frames come from video: consider a time-based split, because near-identical frames help methods with large learning sets. | M2 | fmm |
| O4 | Report the labeled images of each method (references plus validation images, against CLIP learning sets) in the full paper; table T5 of beyond_clip_analysis.qmd has the counts. | M2 | fmm |
