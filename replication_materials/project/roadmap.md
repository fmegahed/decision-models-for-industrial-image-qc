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
| M2 | Full MSEC 2027 paper | next | - | - |
| M3 | R package decisionqc | planned | - | - |

## Open items

| ID | Item | Blocks | Owner |
|---|---|---|---|
| O1 | Test the refinement step (criteria and references) with smaller validation sets; the calibration step needed only 10 to 20 images per class. | M2 | fmm |
| O2 | Log each paid call (time, request ID, tokens, cost) in calls/; the past 4,554 JEV calls have no per-call log. | M3 | fmm |
| O3 | Extrusion frames come from video: consider a time-based split, because near-identical frames help methods with large learning sets. | M2 | fmm |
| O4 | Report the labeled images of each method (references plus validation images, against CLIP learning sets) in the full paper. | M2 | fmm |
