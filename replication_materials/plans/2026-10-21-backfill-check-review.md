# Back-fill check: D2 to D38

| Item | Value |
|---|---|
| Status | open |
| Decision | D75 |

Claude Code wrote these 37 decision rows from the transcript after the work (How `classified`). No person checked them yet. For each row, write `ok` or a correction in the Check column. Claude Code then adds one row to `## Checks` (for `ok`) or to `## Corrections` (for a correction) in `project/decisions.md`. The original rows do not change.

## Rows to check

| Decision | Text | Proposed by | Decided by | Evidence | Check | Note |
|---|---|---|---|---|---|---|
| D2 | Make all manifest paths relative to the local imgs/ folder. | fmm | fmm | "The path should be based on our current imgs/ -- update since I moved these from another repo" (2026-10-20) |  |  |
| D3 | Pin the model to jev-1.13.0 in the runner, because jev-latest can change. | claude | claude | "pinned: jev-latest can move" (2026-10-20) |  |  |
| D4 | Run batch 1: a baseline and a repeat baseline for microstructure, textiles and extrusion. | claude | fmm | "Yes, run batch 1 (Recommended)" (2026-10-20) |  |  |
| D5 | Freeze 50 validation images per class. | claude | fmm | "50 per class (Recommended)" (2026-10-20) |  |  |
| D6 | Add an opt-in upscale argument (default FALSE) to the JEV client. | claude | fmm | "Yes, add it (Recommended)" (2026-10-20) |  |  |
| D7 | Set up the replication record after the experiments. | claude | fmm | "Later, after the experiments" (2026-10-20) |  |  |
| D8 | Make a panelled progress chart like the autoresearch chart. | fmm | fmm | "It would be awesome if you can create a panelled chart similar to this" (2026-10-20) |  |  |
| D9 | Include center crop and downsizing as experiments to reduce tokens. | fmm | fmm | "you can potentially center crop that image or downsize it a bit to reduce token usage -- these can be part of your experiments" (2026-10-20) |  |  |
| D10 | Run the rest of the queue for the three priority datasets, with a cap of 1,000 calls. | claude | fmm | "Approve rest of queue (Recommended)" (2026-10-20) |  |  |
| D11 | Judge criteria, reference and size changes by AUC (+0.02) and tune the threshold last. | claude | fmm | "AUC, threshold last (Recommended)" (2026-10-20) |  |  |
| D12 | Choose each threshold as the midpoint of the widest run of thresholds with the maximum validation BA. | claude | claude | "on a 0.01 grid, take the midpoint of the widest run of thresholds that all reach the maximum validation BA" (2026-10-20) |  |  |
| D13 | Tune pipe_staple and pan before one final test of all datasets. | claude | fmm | "Tune pipe_staple + pan first (Recommended)" (2026-10-20) |  |  |
| D14 | Stop pan tuning while its validation images have copies in the test set. | claude | claude | "stopping all pan tuning" (2026-10-20) |  |  |
| D15 | Delete the duplicate pan images from the test folder. | fmm | fmm | "For the pan images delete those duplicates from the test folder." (2026-10-20) |  |  |
| D16 | Raise the paid-call cap to 5,000. | fmm | fmm | "Raise the cap to 5000 API calls." (2026-10-20) |  |  |
| D17 | Delete all files with the word copy in their names. | fmm | fmm | "Also delete all the files that had the word copy in them." (2026-10-20) |  |  |
| D18 | Keep a smaller pan image size when it is no worse, because the aim is to save tokens. | claude | claude | "keep if AUC does not fall by 0.02 and BA at t=0.50 does not fall" (2026-10-20) |  |  |
| D19 | Use the bright-clip wording for pipe_staple; at the AUC ceiling, compare BA at tuned thresholds. | claude | fmm | "Specific wording (criteria_staple)" (2026-10-20) |  |  |
| D20 | Match the test sizes of the prior CLIP study, not its few-shot learning sizes. | fmm | fmm | "We do not want to do the same number of few-shot images here. The prior study was CLIP" (2026-10-20) |  |  |
| D21 | Delete pan test image 21.JPG, which the prior test folder does not have. | claude | fmm | "Delete 21.JPG (Recommended)" (2026-10-20) |  |  |
| D22 | Add the real textile images as a transfer test. | claude | fmm | "Yes, add it (Recommended)" (2026-10-20) |  |  |
| D23 | Run the one-time final test for the frozen configurations. | claude | fmm | "Yes, run it after the changes" (2026-10-20) |  |  |
| D24 | Run CLIP on the same partition, a zero-shot JEV ablation and a calibration check. | fmm | fmm | "run CLIP on the same partition" (2026-10-20) |  |  |
| D25 | Give the zero-shot ablation its own validation threshold, with the same rule. | claude | claude | "Same plateau rule as the main condition, so the zero-shot test comparison is fair." (2026-10-20) |  |  |
| D26 | Raise the paid-call cap to 7,000 if needed. | fmm | fmm | "You can increase the API calls to 7000 if its needed." (2026-10-20) |  |  |
| D27 | Run CLIP in a separate, pinned conda environment. | claude | claude | "torch 2.8.0+cu128, OpenAI CLIP commit d05afc4" (2026-10-20) |  |  |
| D28 | Replicate CLIP with the learning-set size that the CLIP paper reports for each experiment. | fmm | fmm | "Replicate CLIP with the recommended cutoff for each experiment from our CLIP paper" (2026-10-20) |  |  |
| D29 | Compare Platt scaling with isotonic regression. | fmm | fmm | "Compare Platt Scaling with Isotonic Regression for Calibration" (2026-10-20) |  |  |
| D30 | Drop the real-textile transfer example. | fmm | fmm | "Drop the real textile transfer example since this also did not work for the CLIP method." (2026-10-20) |  |  |
| D31 | Exclude copies of test images from the CLIP learning pool. | claude | claude | "Learning images come from the non-test pool without copies of test images." (2026-10-20) |  |  |
| D32 | Wait with the repository, because the scope and name can change with Clef-Flash. | fmm | fmm | "Let us wait on this since if we include clef-flash, we might want to rename the repo" (2026-10-20) |  |  |
| D33 | Back-fill the decisions of this session into the record. | claude | fmm | "Yes, back-fill (Recommended)" (2026-10-20) |  |  |
| D34 | Run Clef-Flash locally with the same protocol. | claude | fmm | "Yes, run it locally" (2026-10-20) |  |  |
| D35 | Delete only the extrusion pool frames that copy test frames. | claude | fmm | "Delete the pool copies only" (2026-10-20) |  |  |
| D36 | Send images to Clef-Flash as an ordered list with a text legend, because its SystemOne server ignores TypeSafe assets. | claude | claude | "images in order (inspection image first, then references), and the state text says which image is which" (2026-10-20) |  |  |
| D37 | Submit the MSEC 2027 title and abstract in the rewrite of the owner. | fmm | fmm | "Here is what I submitted to MSEC: (I rewrote this)" (2026-10-20) |  |  |
| D38 | Add Ying-Ju (Tessa) Chen as a co-author. | fmm | fmm | "Also ying-ju (Tessa) Chen will be a co-author on this." (2026-10-20) |  |  |
