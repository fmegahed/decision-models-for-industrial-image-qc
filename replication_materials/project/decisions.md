# Decisions

## Decisions

| ID | Date | Decision | Proposed by | Decided by | How | Evidence | Source |
|---|---|---|---|---|---|---|---|
| D1 | 2026-10-20 | Keep a replication record with the replication-materials skill. | fmm | fmm | chat | "Are you capturing the decisions and the experiments as we discussed?" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D2 | 2026-10-20 | Make all manifest paths relative to the local imgs/ folder. | fmm | fmm | classified | "The path should be based on our current imgs/ -- update since I moved these from another repo" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D3 | 2026-10-20 | Pin the model to jev-1.13.0 in the runner, because jev-latest can change. | claude | claude | classified | "pinned: jev-latest can move" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D4 | 2026-10-20 | Run batch 1: a baseline and a repeat baseline for microstructure, textiles and extrusion. | claude | fmm | classified | "Yes, run batch 1 (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D5 | 2026-10-20 | Freeze 50 validation images per class. | claude | fmm | classified | "50 per class (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D6 | 2026-10-20 | Add an opt-in upscale argument (default FALSE) to the JEV client. | claude | fmm | classified | "Yes, add it (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D7 | 2026-10-20 | Set up the replication record after the experiments. | claude | fmm | classified | "Later, after the experiments" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D8 | 2026-10-20 | Make a panelled progress chart like the autoresearch chart. | fmm | fmm | classified | "It would be awesome if you can create a panelled chart similar to this" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D9 | 2026-10-20 | Include center crop and downsizing as experiments to reduce tokens. | fmm | fmm | classified | "you can potentially center crop that image or downsize it a bit to reduce token usage -- these can be part of your experiments" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D10 | 2026-10-20 | Run the rest of the queue for the three priority datasets, with a cap of 1,000 calls. | claude | fmm | classified | "Approve rest of queue (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D11 | 2026-10-20 | Judge criteria, reference and size changes by AUC (+0.02) and tune the threshold last. | claude | fmm | classified | "AUC, threshold last (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D12 | 2026-10-20 | Choose each threshold as the midpoint of the widest run of thresholds with the maximum validation BA. | claude | claude | classified | "on a 0.01 grid, take the midpoint of the widest run of thresholds that all reach the maximum validation BA" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D13 | 2026-10-20 | Tune pipe_staple and pan before one final test of all datasets. | claude | fmm | classified | "Tune pipe_staple + pan first (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D14 | 2026-10-20 | Stop pan tuning while its validation images have copies in the test set. | claude | claude | classified | "stopping all pan tuning" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D15 | 2026-10-20 | Delete the duplicate pan images from the test folder. | fmm | fmm | classified | "For the pan images delete those duplicates from the test folder." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D16 | 2026-10-20 | Raise the paid-call cap to 5,000. | fmm | fmm | classified | "Raise the cap to 5000 API calls." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D17 | 2026-10-20 | Delete all files with the word copy in their names. | fmm | fmm | classified | "Also delete all the files that had the word copy in them." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D18 | 2026-10-20 | Keep a smaller pan image size when it is no worse, because the aim is to save tokens. | claude | claude | classified | "keep if AUC does not fall by 0.02 and BA at t=0.50 does not fall" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D19 | 2026-10-20 | Use the bright-clip wording for pipe_staple; at the AUC ceiling, compare BA at tuned thresholds. | claude | fmm | classified | "Specific wording (criteria_staple)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D20 | 2026-10-20 | Match the test sizes of the prior CLIP study, not its few-shot learning sizes. | fmm | fmm | classified | "We do not want to do the same number of few-shot images here. The prior study was CLIP" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D21 | 2026-10-20 | Delete pan test image 21.JPG, which the prior test folder does not have. | claude | fmm | classified | "Delete 21.JPG (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D22 | 2026-10-20 | Add the real textile images as a transfer test. | claude | fmm | classified | "Yes, add it (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D23 | 2026-10-20 | Run the one-time final test for the frozen configurations. | claude | fmm | classified | "Yes, run it after the changes" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D24 | 2026-10-20 | Run CLIP on the same partition, a zero-shot JEV ablation and a calibration check. | fmm | fmm | classified | "run CLIP on the same partition" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D25 | 2026-10-20 | Give the zero-shot ablation its own validation threshold, with the same rule. | claude | claude | classified | "Same plateau rule as the main condition, so the zero-shot test comparison is fair." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D26 | 2026-10-20 | Raise the paid-call cap to 7,000 if needed. | fmm | fmm | classified | "You can increase the API calls to 7000 if its needed." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D27 | 2026-10-20 | Run CLIP in a separate, pinned conda environment. | claude | claude | classified | "torch 2.8.0+cu128, OpenAI CLIP commit d05afc4" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D28 | 2026-10-20 | Replicate CLIP with the learning-set size that the CLIP paper reports for each experiment. | fmm | fmm | classified | "Replicate CLIP with the recommended cutoff for each experiment from our CLIP paper" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D29 | 2026-10-20 | Compare Platt scaling with isotonic regression. | fmm | fmm | classified | "Compare Platt Scaling with Isotonic Regression for Calibration" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D30 | 2026-10-20 | Drop the real-textile transfer example. | fmm | fmm | classified | "Drop the real textile transfer example since this also did not work for the CLIP method." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D31 | 2026-10-20 | Exclude copies of test images from the CLIP learning pool. | claude | claude | classified | "Learning images come from the non-test pool without copies of test images." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D32 | 2026-10-20 | Wait with the repository, because the scope and name can change with Clef-Flash. | fmm | fmm | classified | "Let us wait on this since if we include clef-flash, we might want to rename the repo" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D33 | 2026-10-20 | Back-fill the decisions of this session into the record. | claude | fmm | classified | "Yes, back-fill (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D34 | 2026-10-20 | Run Clef-Flash locally with the same protocol. | claude | fmm | classified | "Yes, run it locally" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D35 | 2026-10-20 | Delete only the extrusion pool frames that copy test frames. | claude | fmm | classified | "Delete the pool copies only" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D36 | 2026-10-20 | Send images to Clef-Flash as an ordered list with a text legend, because its SystemOne server ignores TypeSafe assets. | claude | claude | classified | "images in order (inspection image first, then references), and the state text says which image is which" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D37 | 2026-10-20 | Submit the MSEC 2027 title and abstract in the rewrite of the owner. | fmm | fmm | classified | "Here is what I submitted to MSEC: (I rewrote this)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D38 | 2026-10-20 | Add Ying-Ju (Tessa) Chen as a co-author. | fmm | fmm | classified | "Also ying-ju (Tessa) Chen will be a co-author on this." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58; not checked by a person |
| D39 | 2026-10-20 | Name the R package decisionqc and the research repository decision-models-for-industrial-image-qc. | claude | fmm | chat | "Sure the suggsted names for the package and GitHub are acceptable by me." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D40 | 2026-10-20 | Organize the repository before the first push. | fmm | fmm | chat | "before pushing things into GitHub, ensure that the repo is organized." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D41 | 2026-10-20 | Make the research repository public, so the record website works on the free plan. | claude | fmm | question | "Yes, public (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D42 | 2026-10-20 | License the repository under MIT. | claude | fmm | question | "MIT (Recommended)" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D43 | 2026-10-20 | Cite the CLIP study as the 2026 Journal of Quality Technology article, which is open access. | fmm | fmm | chat | "For the CLIP reference, put Megahed, Fadel Mounir, et al." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D44 | 2026-10-20 | Set the JEV budget to about USD 5, the free credit for a new user. | fmm | fmm | chat | "For JEV set the budget to ~$5, which is what they provide for free for any new user." (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D45 | 2026-10-20 | Use APA 7 style for citations, with the published metadata of each work. | fmm | fmm | chat | "I like APA style citations" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |
| D46 | 2026-10-20 | Use short, direct section headers in all documents. | fmm | fmm | chat | "I like straight to the point headers" (2026-10-20) | b36ad167-66f5-45af-9d6c-bf3f817c6f58 |

## Corrections

To correct a decision, add one row to this table. Name the person who checked it. The original row stays above.

| Decision | Field | New value | Checked by | Date | Note |
|---|---|---|---|---|---|
