| Item | Value |
|---|---|
| Status | Closed |
| Version | 1.0 (2026-11-27) |
| Written by | Claude Code |

This ledger is a copy of the working ledger for the plan `replication_materials/plans/2026-11-27-box-refine-plan.md`. It was copied on 2026-11-27 at the end of the work. Internal agent IDs are removed.

# SDD ledger — plan: replication_materials/plans/2026-11-27-box-refine-plan.md

Base: m7-box at 88d4d8d2. Spec: the plan itself (Stage 6, D348 to D350); rulings are provisional against it.
Execution: two background agents in parallel (Track A, Track B); they do not commit; the controller commits and reviews.

Records on main: 9ee29125 (D348 to D350, plan, process row).
Track A dispatched (full-shot references; report track-a-report.md).
Track B Phase 1 dispatched (dev pool and frozen_refine.json only; report track-b-report.md). Phase 2 (final scoring) starts after the controller commits frozen_refine.json.
Ruling: the box score of a REF method is the part maximum of its map, not G times it — V already carries gate_g(G), and the plan text "G × the part maximum" would apply the gate twice — if wrong, box scores on gated images are lower, which changes AP ranks only through G squared.
Track B Phase 1: complete (commit c13b98d2; controller rerun of px_31 dev gave byte-identical CSVs and JSON; test-refine.R 14 tests / 66 expectations pass). Agent rulings: track-b-report.md, section Rulings (copied at the end).
Ruling: Phase 2 compares the boxes with the boxes of TTA_vote_G1 in the final rows (frozen threshold 0.012, as H18 scored them), not with per-set F1-max boxes — the final test froze that threshold — if wrong, the box gain is measured against a stronger baseline than on the pool (pool: 0.312 at the frozen threshold against 0.241 at per-set thresholds).
Ruling: Phase 2 scores only the frozen choice (REF_dino_l100 map, REF_dino_l50 boxes, flagged) on the final images, not all 8 REF methods — Protocol item 3; scoring the others would invite a choice on the test — if wrong, less descriptive detail.
Track B Phase 2: complete (commit after c13b98d2; test-refine-final.R passes; box suite 154 tests per the agent). Only the frozen choice was scored on the final images.
Final: minor (deferred): refine_sheet.png uses the default font (not Outfit/Cabin), PNG only, and a strip label reads "1 boxes".
Track A: complete (PatchCore_full and EfficientAD_full; controller check: the TTA_vote_G1 rows of fullshot_three_levels.csv equal final_three_levels.csv, difference 0; PatchCore full-split image AUROC from the raw map maxima equals Check 1; box suite 1196 expectations, 0 failed). Agent rulings: track-a-report.md, section Rulings (copied at the end).
Ruling: EfficientAD_full is reported as a weak reference below the published level, not as the published EfficientAD — its full-split image AUROC (raw map maxima) is 0.646 / 0.794 / 0.507 / 0.631 / 0.933, 5-class mean 0.702, against a published macro mean of about 0.94; the likely cause is the 35,000-step ruling of Track A — if wrong, the TTA_vote_G1 gains over EfficientAD_full overstate the gap to a fully trained EfficientAD.
Root suite in the worktree: 633 expectations, 5 failed in test-fair-loop.R, test-fair-runner.R and test-fair-sets.R; the cause is the untracked imgs/ and data/ folders, which only the main checkout has (the same tests pass on main, 0 failed); Stage 6 changed no file outside box/.
Final review: a fresh reviewer read the code diff 88d4d8d2..68a4a757: 0 Critical, 3 Important, 12 Minor (final-review.md). Protocol checks passed: freeze before score, no final data in a development constant, one-time files untouched, image score = max(V), G applied once, Track A training images clean (path, file MD5 and pixel MD5).
Final: fixed I1 (the dev box rule compared with the h10 TTA_vote_G1 boxes, not with the frozen boxes of Stage 5) — px_33_refine_addendum.R writes refine_addendum.md: against the frozen boxes (0.312), REF_dino_l50 loses 0.072 (95% interval -0.138 to -0.010), not a near tie; frozen_refine.json unchanged; the choice does not change — test-refine-addendum.R "frozen_tta_boxes keeps a part whose maximum equals the frozen threshold" RED→GREEN, suite 1221/1221.
Final: fixed I2 (fullshot_summary.md had no EfficientAD caveat) — Check 1 now covers both methods (EfficientAD_full macro image AUROC 0.703 against 0.94 published; PatchCore rows unchanged to the last digit), a caveat section, the exact commands with BOX_EAD_STEPS=35000, and a reference_note on each EfficientAD compare row — test-fullshot.R "fullshot_note marks a reference trained with fewer than the default steps", "fullshot_published holds the published levels of both references", "check1_macro adds a macro row and the published levels for each method" RED→GREEN, suite 1221/1221.
Final: fixed I3 (the family-mean gain comes mostly from underbody_pipes, and the candidates were written with the Stage 5 final results known) — refine_addendum.md gives the 4-dataset pool mean (+0.035) next to the 5-dataset family mean (+0.095), the FUSE reference (family mean 0.519) and the disclosure — test-refine-addendum.R "group_means gives the mean of each group of datasets by method" and "group_means stops when a method lacks a dataset of a group" RED→GREEN, suite 1221/1221.
Final: Ruling: the plan text of item 4 ("stay unseen") is not edited — a plan file records what was planned at the time; the limitation is in refine_addendum.md and H19 — if wrong, a reader of the plan alone misses it.
Final: Ruling: the cause of the weak EfficientAD_full is not searched in this stage — it is reported as an under-trained reference (I2) — if wrong, a defect other than the step count stays hidden in fullshot.py.
Final: Ruling: PatchCore Check 1 above the published level (0.750 against 0.58) stands — the plan asks only to show the two side by side; a stronger PatchCore makes the comparison harder for TTA_vote_G1, not easier — if wrong, PatchCore_full is not the published PatchCore.
Final: Ruling: the R AU-sPRO port is not checked again — px_01_validate.R checked it against the official code in Stage 0 (within 0.005) — if wrong, every pixel number of the study moves together.
Final: Ruling: the 5 root-suite failures stand as an environment fact — they need imgs/ and data/, which only the main checkout has, and they pass there — if wrong, a real failure hides behind the missing data.
Final: Ruling: the method grids (q, l, m) and the SAM rank-1 masks stand — plan design, chosen before any final scoring — if wrong, a better refinement was not tried.
Final: Ruling: the Stage 5 rows that Stage 6 copies stand — the TTA_vote_G1 rows equal final_three_levels.csv (difference 0) — if wrong, both tracks compare with a wrong baseline.
Final: Ruling: p values stay unadjusted — the plan says so, and the numbers are post hoc with no verdict — if wrong, a reader takes a single p as a test.
Final: Ruling: PatchCore and EfficientAD were fitted once — GPU nondeterminism is not measured — if wrong, a refit moves the full-shot numbers a little.
Final: Ruling: the call logs on main are unchanged (last write 2026-11-26T11:46, Stage 5; git shows no change) and eagerprep is unchanged per Track A — if wrong, a call or an env change is not recorded.
Final: Ruling: no dHash guard for AutoVI training images — with a fixed camera, dHash <= 4 matches most images; the pixel-MD5 check found 0 twins — if wrong, a near-copy that is not a byte or pixel copy trains a model.
Final: minor (deferred): M1 REF_dino boxes come from the unrounded map, not the stored 16-bit map (AP change at most 0.0002 on dev).
Final: minor (deferred): M2 the test fixtures cannot detect a change from max(V) to max of the refined map.
Final: minor (deferred): M3 fabrid_train_pool() tests do not run the final, md5_final, dhash_final and no_time branches.
Final: minor (deferred): M4 sample(k, replace = TRUE) in box_rule() fails on a dataset with one image.
Final: minor (deferred): M5 the saved SAM masks are reused on a row count only.
Final: minor (deferred): M6 px_32 has no one-time guard and saves no per-image final rows (the two runs are stated in refine_addendum.md).
Final: minor (deferred): M7 the scripts default to 70,000 EfficientAD steps; the reported model used 35,000 (the exact command is now in fullshot_summary.md).
Final: minor (deferred): M8 the full-shot rows of fullshot_three_levels.csv show 0 for detection measures that were not computed.
Final: minor (deferred): M9 `score <one method>` overwrites the files of both methods.
Final: minor (deferred): M10 Track A and Track B report gains in opposite directions (H19 gives "X against Y" values).
Final: minor (deferred): M11 the false-box guard at score >= 0.5 can never apply (stated in refine_addendum.md with all-box counts).
Final: minor (deferred): M12 the map of REF_dino_l50 has no final_compare() rows.
Agent rulings, copied from the agent reports (track-a-report.md and track-b-report.md):
Track A: Ruling: EfficientAD-S at 35,000 steps for all 6 classes (half of the 70,000 of the EfficientAD paper and the anomalib configuration) — the 70,000-step trial took 39 min on fabrid and over 53 min on tank_screw (larger images, CPU-bound loader, parallel load), over the 45-min limit; 35,000 steps took 19 to 31 min — it costs accuracy if EfficientAD-S is still under-trained at 35,000 steps (see concerns; the reference may be weaker than the published level).
Track A: Ruling: drop the 60 engine_wiring train/good images that are byte-identical to test images — the plan says no training image is a test image (MD5 check) — it costs a training set of 203 images for engine_wiring (22 more held out); Check 1 of that class is slightly pessimistic against the official split.
Track A: Ruling: hold-out = 10% of the (MD5-clean) training images, drawn with seed 2051, at least 1; the same images are the validation set of EfficientAD — the plan holds them out of training and uses them for c — it costs nothing for PatchCore; for EfficientAD the quantile normalization and c use the same images.
Track A: Ruling: c is computed on the raw 256 x 256 maps, before the resize to full size — the plan says "the 99th percentile of the map values", and the bilinear resize does not change the value range materially — it costs a small shift of c if the resize mattered.
Track A: Ruling: raw eval-mode maps only (post_processor=False, evaluator=False), no anomalib min-max normalization — the plan defines its own monotone normalization — it costs nothing.
Track A: Ruling: FabriD extra guard (MD5 and dHash <= 4 to a final image) on top of the three exclusions of the plan — a near-twin of a test image must not train — it costs nothing (it dropped no image).
Track A: Ruling: predict all test images of the 5 AutoVI classes once (Check 1 and Check 2 share the raw maps; the final images are read from them by path) — saves a second run — it costs nothing (same model).
Track A: Ruling: compare direction a = TTA_vote_G1, b = full-shot (gain = TTA minus full-shot), per dataset (6), as compare() of px_22_final_results.R — the plan says compare each one with TTA_vote_G1 — it costs nothing.
Track A: Ruling: Check 1 shows the 5-class macro mean next to the published 6-class 0.58 +- 0.11, with no adjustment — pipe_staple is not in the data folder — it costs a comparison that is not like for like.
Track B Phase 1: Ruling: part rule is "V >= q x max(V)" (>=, via map > q x max - 1e-9) — the plan says >=; peak_part() uses > — only a plateau exactly at q x max differs.
Track B Phase 1: Ruling: V and D are the stored 16-bit maps (maps/TTA_vote_G1, maps/DINO_k16_local_S), as FUSE does — dev scoring uses stored maps, and the replay shows they equal a rebuild — none if wrong.
Track B Phase 1: Ruling: REF_peak_q* keep map V (write a copy per method) — spec says the map is V — costs only disk.
Track B Phase 1: Ruling: image score of every REF method = max(stored V) — plan; AUROC identical to TTA_vote_G1 (0.784 all).
Track B Phase 1: Ruling: REF_sam_m* boxes = bounding box of each 8-connected part of S, score = max of the method map in the part, score-0 parts dropped — plan says "the box of S" and does not say how many; if one box per prompt were meant, fewer, larger boxes — would change the sam AP only (already worst).
Track B Phase 1: Ruling: peak point for a prompt = centroid of the plateau of the part maximum (nearest plateau pixel if off the plateau), as peak_part(point="centroid") — "the V peak inside it"; costs a few pixels in the SAM point.
Track B Phase 1: Ruling: d = smallest stored 16-bit value whose pixel share reaches 0.999, pooled over all pixels (counts of 65,536 levels) — "99.9th percentile"; differs from a type 7 quantile by < 1 level.
Track B Phase 1: Ruling: d for pool datasets from the pool good images (15/15/15/10 images, as the FUSE constants); for the new classes from the 20 zcal images' stored D maps in maps_final_zcal — as the plan says.
Track B Phase 1: Ruling: map choice is among the methods that change the map (REF_dino_*, REF_sam_*, REF_samdino); REF_peak_* have gain exactly 0 and cannot keep — if none kept, a peak method would be "the highest" by tie.
Track B Phase 1: Ruling: box rule baseline = the saved boxes of TTA_vote_G1 (h10 rows, F1-max threshold boxes) — "AP@0.3 gain vs TTA_vote_G1"; paired bootstrap within datasets, 2,000 draws, seed 2031 (as px_19 det_compare); mean for choice = dataset-mean AP@0.3.
Track B Phase 1: Ruling: replay sample = 20 of the 546 final images, withr::with_seed(2050, sample(...)) — plan gives no choice; a failed-request image would expect a zero map (none in the sample).
Track B Phase 2: Ruling: REF_dino_l100's boxes are also reported (parts >= 0.5 max) in the false-box table — only to show the count; it is not the frozen box method.
Track B Phase 2: Ruling: the box comparison runs box_rule() once per dataset (6) and once on the 5 primary datasets (mean of the 5 dataset gains); the stratification of final_compare() is not used because box_rule() resamples images within a dataset, as in dev — costs nothing in the point estimates.
Track B Phase 2: Ruling: the "keep" column of box_rule() is dropped from the final compare file (dev rule, not a final verdict).
Track B Phase 2: Ruling: the second run of the script rewrote the outputs after I found a missing `source("tta.R")` (the first run stopped before scoring boxes); the pixel numbers are deterministic and the same.
Stage 6: complete (m7-box commits c13b98d2, ce9fd696, 68a4a757, e9d1db87; final review fixed I1 to I3; box suite 1221 expectations, 0 failed; no paid call).
