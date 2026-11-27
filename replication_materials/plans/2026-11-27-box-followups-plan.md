# Pixel study of Box, the two follow-ups of Stage 6: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (C) Train EfficientAD-S with its 70,000 default steps as a fair second full-shot reference. (D) Test once, on fresh images and with a rule written before the first call, whether the frozen refined map of Stage 6 (REF_dino_l100) gives better masks than TTA_vote_G1.

**Architecture:** Track C adds a third method key to `box/scripts/px_30_fullshot.R` (`efficientad70k`, its own run folder), so the 35,000-step runs stay. Track D adds `box/R/confirm.R` and the scripts `px_40_confirm_inputs.R`, `px_41_confirm_run.R` and `px_42_confirm_results.R` with their own folder `box/results/px_confirm/`, purpose prefix `box px confirm` and cap. They reuse the frozen recipe of Stage 5 (`px_final_common.R`, `box/R/final.R`) and the frozen choice of Stage 6 (`frozen_refine.json`, `refine_final_rows()`). They only read the files of `box/results/px_final/`.

**Tech Stack:** R (tidyverse, testthat, withr), the pinned `decisions` library (jev-1.14.0), DINOv2-S in the env `eagerprep`, anomalib 2.7.1 in `box_data/envs/anomalib`.

**Spec:** fmm, 2026-11-27: "Do the two follow ups" (D351), on the two follow-ups that the end-of-Stage-6 report offered. Background: H19, D350, `plans/2026-11-27-box-refine-plan.md`, `plans/2026-11-26-box-pixel-final-plan.md` (the Stage 5 rule that Track D copies).

## Global Constraints

- Work in the worktree `fine_tuned_jev-box`, branch `m7-box`. Do not push the branch without fmm.
- Never run `box/scripts/px_21_final_run.R`. Never write, move or delete a file of `box/results/px_final/`. Read them only.
- No paid call before fmm approves a budget row for the prefix `box px confirm` in `replication_materials/calls/README.md`. The code cap equals that row. All the requests of one image: at most USD 0.01.
- The run of Track D is one-time: `run_guard("box/results/px_confirm")` stops after `done.json`, and on any change of `box/R`, `box/scripts` or `box/python` since the code commit of the pre-registration.
- The pre-registration (`box/results/px_confirm/prereg.json`) is committed before the first call.
- Frozen, not changed: the TTA_vote_G1 recipe (`box/results/px/frozen.json`), the words and references of `box/results/px_final/inputs.json`, the choice and the constants d of `box/results/px_refine/frozen_refine.json`.
- Seeds: the draw 2061; the bootstrap 2063; 5,000 resamples.
- Rscript with `--no-environ`. Never print or log the key.
- Records in 80% ASD-STE100.

## Track C: EfficientAD-S with 70,000 steps

### Task C1: helpers of the 70,000-step reference

**Files:** Modify `box/R/fullshot.R`; test `box/tests/test-fullshot.R`.

- [ ] Test: `fullshot_note("EfficientAD_full_70k", 70000)` is `""`; `fullshot_note("EfficientAD_full_70k", 35000)` gives the under-trained note; `fullshot_published` has the row `EfficientAD_full_70k`, `image_auroc`, 0.94, 0.04.
- [ ] Watch the tests fail; change `fullshot_note()` to apply to every method that starts with `EfficientAD_full`; add the row; watch them pass.

### Task C2: run, score and summary

**Files:** Modify `box/scripts/px_30_fullshot.R`.

- [ ] `run efficientad70k` (the key trains with 70,000 steps and stops on another `BOX_EAD_STEPS`).
- [ ] `score patchcore efficientad efficientad70k`, then `summary`. The summary shows both EfficientAD rows and a section on the 70,000-step model.
- [ ] Expected: the 6 runs have `max_steps` 70000; the PatchCore and 35,000-step rows do not change.

### Task C3: the record

- [ ] A result row H20 (post hoc, no verdict): Check 1 of EfficientAD_full_70k against the published level, and the Check 2 rows against TTA_vote_G1.

## Track D: the confirmatory test of REF_dino_l100

### The rule (pre-registered; written before any call of Track D)

1. **Methods.** Candidate: REF_dino_l100 of `frozen_refine.json` (the vote map V of TTA_vote_G1 times D~ = min(D / d, 1), with D the DINO_k16_local_S map and d the frozen constant of the dataset). Reference: TTA_vote_G1 (the frozen recipe of Stage 5). Both maps come from the same Jev answers of each image. The image score of both is max(V), so their image AUROC is the same by construction; it is reported, not tested.
2. **Datasets.** `fabrid`, `pipe_clip`, `engine_wiring`, `underbody_pipes`, in this order. `tank_screw` and `underbody_screw` have no fresh defective image.
3. **Gain of a dataset.** AU-sPRO at FPR 0.05 of REF_dino_l100 minus that of TTA_vote_G1 on the images of the dataset (`spro_curves()` and `spro_at()`, as `final_compare()`).
4. **Two tests.**
   - C1: the mean gain over the 4 datasets.
   - C2: the mean gain over `fabrid`, `pipe_clip` and `engine_wiring`, without `underbody_pipes`. The candidates of Stage 6 were written after the Stage 5 results of `underbody_pipes` were known (H19), so C2 asks if the gain holds without that class.
5. **Bootstrap.** 5,000 resamples in one `withr::with_seed(2063, ...)`. In each resample, for each dataset in the order of item 2, `strata_sample()` of its images (good and defective drawn apart, with replacement); the gain of each dataset; the means of C1 and C2. The 95% percentile interval. The two-sided p value of `final_pvalue()`.
6. **Holm** over the 2 p values (C1, C2), at alpha 0.05.
7. **Guard** (the development rule of D342: no dataset falls by more than 0.03). No dataset of the test has a gain below -0.03.
8. **Verdicts.**
   - C1 is *confirmed* when its Holm p is below 0.05, its mean gain is above 0, and the guard holds on the 4 datasets.
   - C2 is *confirmed* when its Holm p is below 0.05, its mean gain is above 0, and the guard holds on its 3 datasets.
9. **Descriptive only.** The gain of each dataset with its interval and p (no verdict); AU-sPRO at 0.01, 0.1, 0.3 and 1; pixel AUROC and F1-max; box AP at IoU 0.3 of the REF_dino_l50 boxes against the frozen TTA_vote_G1 boxes; boxes per good image; the rows of L_box, DINO_k16_local_S and FUSE.
10. **Failures.** Item 7 of the Stage 5 rule, unchanged. A failed TTA_vote_G1 gives V = 0 everywhere, so REF_dino_l100 is 0 too. No image is dropped.

### Fresh images and sizes

- The fresh pool: the eligible images of Stage 5 (`candidates.csv` minus `dropped.csv`), minus the 546 Stage 5 final images, minus every image with the file MD5, or (AutoVI) the pixel MD5, of an image that Stage 5 sent (the final images, the 40 z-calibration images, the gate references). FabriD also: a dHash distance of 4 or less to, or a file time within 30 s of, a Stage 5 final FabriD image.
- Counts (pool of 2026-11-27): engine_wiring 228 defective / 183 good; underbody_pipes 122 / 121; fabrid 96 / 14; pipe_clip 24 / 140.
- The draw (`draw_final()`, seed 2061): fabrid all / all; pipe_clip all / 60; engine_wiring 100 / 60; underbody_pipes 100 / 60. About 514 images.
- Gate references and DINO banks: `bank_rule()` of Stage 5 (`good_bank()`, `nearest_good()`); FabriD the D336 nominal example. No bank image has the MD5 of a test image.

### Cost

About 3.7 calls and USD 0.002 per image at Stage 5, so about 1,900 calls and USD 1.0. The budget row asks for 3,000 calls and USD 2.

### Task D1: `box/R/confirm.R`

**Files:** Create `box/R/confirm.R`; test `box/tests/test-confirm.R`.

**Interfaces (produces):**
- `confirm_fresh(eligible, drawn, sent_md5, sent_pixel_md5, fabrid_sent)`: the rows of `eligible` (columns of `candidates.csv`) that are not in `drawn$path`, whose `md5` is not in `sent_md5`, whose `pixel_md5` (AutoVI) is not in `sent_pixel_md5`, and (FabriD) whose dHash distance to each `fabrid_sent$dhash` is above 4 and whose file time is more than 30 s from each `fabrid_sent$file_time`. Adds nothing; keeps the columns.
- `confirm_draws(hists_a, hists_b, defective)`: one stratified resample of one dataset; the gain (AU-sPRO at 0.05 of a minus b). The caller holds the seed.
- `confirm_test(data, groups, R = 5000, seed = 2063)`: `data` is a named list (dataset order of item 2) of lists `hists_a`, `hists_b`, `defective`; `groups` a named list of dataset vectors. Returns one row per group: `group`, `gain`, `lower`, `upper`, `p`, and one row per dataset (`group` = the dataset) with the same columns.
- `confirm_verdict(tab, groups, guard = -0.03, alpha = 0.05)`: Holm over the group rows; `confirmed` by item 8.

- [ ] Tests first: `confirm_fresh` drops each rule once (MD5, pixel MD5, dHash 4, 30 s, drawn) and keeps a clean image; `confirm_test` with equal maps gives gain 0 and p 1; with a constant gain it gives that gain in the mean; the same seed gives the same draws; `confirm_verdict` fails a group on the guard and on Holm.

### Task D2: `px_40_confirm_inputs.R`

- [ ] Steps `inputs` (fresh pool, draw, checks as Stage 5 step 5, banks, `sets.csv`, `gate_refs.csv`, `dino_banks.csv`, `fresh_counts.csv`) and `prereg` (`prereg.json`: the rule text of this plan, the code commit, the input blobs, the thresholds, the d constants, the cap).

### Task D3: `px_41_confirm_run.R`

- [ ] The per-image steps of `px_21_final_run.R` (test mode), copied without change, with the folder, prefix and cap of Track D; then the DINO maps, the rows of `final_methods`, the rows of REF_dino_l100 and REF_dino_l50 (`refine_final_rows()`), `rows.rds`, `hists.rds`, `done.json`.
- [ ] Mode `replay-check` (no key, `BOX_MAX_CALLS=0`): the 546 Stage 5 final images from a copy of their saved answers, with the stored DINO maps. Expected: 0 calls; the TTA_vote_G1 and L_box maps equal the stored final maps on all 546; the REF_dino_l100 AU-sPRO equals `final_refine_three_levels.csv`.

### Task D4: `px_42_confirm_results.R`

- [ ] The rule (items 3 to 9) on the rows of the run: `confirm_primary.csv`, `confirm_descriptive.csv`, `confirm_summary.md`.
- [ ] Before the run: on the Stage 5 rows of the replay check, it gives the Stage 6 gains.

### Task D5: the run and the record

- [ ] A fresh reviewer reads the Track D code and the pre-registration before the run.
- [ ] After the approval of the budget row: `run_guard`, the run, the results.
- [ ] A result row H21 with the verdicts of C1 and C2.

## Review Focus

- A fresh image that is a byte or pixel copy of an image Stage 5 sent (engine_wiring has train/test copies).
- A DINO bank image with the MD5 of a test image (a perfect neighbour hides a defect).
- The copied per-image code drifts from `px_21_final_run.R` (the replay check must show identical maps).
- A replay or failure file written into `box/results/px_final/` (the replay check uses a copy).
- A failed TTA_vote_G1 image must give a 0 map for REF_dino_l100 too, not a DINO-only map.
