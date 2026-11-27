# Pixel study, Stage 6: better boxes from the same Jev answers, and full-shot references

**Goal:** find out how much the boxes and masks improve when we change only the step after Jev, and compare TTA_vote_G1 with two full-shot methods on the same final images.

**Request:** fmm, 2026-11-27: "Run the next steps and see if we can improve the boxes rather than JEV's reasoning" (D348, D349).

**Base:** branch m7-box at 88d4d8d2 (worktree `fine_tuned_jev-box`). Stage 5 result: H18.

**Spend:** no paid call. Jev is not called in this stage. Only local GPU models run.

## Protocol (D350)

1. Jev's saved answers stay fixed. For each image, these answers are:
   - the 4 boxes of locate();
   - the 16 TTA boxes;
   - the gate G.
   They come from `box/results/px/boxes/h10` and the H5 gate on the development pool, and from `box/results/px_final/per_image/*.rds` on the final test.
2. All choices use the development pool only: 223 images, 4 datasets. The pool is described in `box/results/px/dev_summary.md`.
3. The chosen methods and their constants are written to `box/results/px_refine/frozen_refine.json` and committed. Only after that commit are the final test images scored. They are scored once.
4. The final numbers of this stage are post hoc and descriptive. They carry no verdict, and H18 does not change. underbody_pipes and underbody_screw are not in the development pool, so they stay unseen until the final scoring.
5. Do not change, move or rerun the files of the one-time run: `done.json`, `started.json`, `prereg.json`, `rows.rds`, `per_image/`, `replay/` and `responses/` in `box/results/px_final/`. Do not run `px_21_final_run.R`.

## Track A: full-shot references (PatchCore, EfficientAD)

- **Environment:** a new conda env at `C:/Users/megahefm/box_data/envs/anomalib`, made with `conda create --prefix` and `C:/ProgramData/anaconda3/Scripts/conda.exe`. It uses anomalib 2.x and a CUDA build of torch for the RTX 5000 Ada. Write `conda list --export` to `box/results/px_fullshot/env-anomalib.txt`. Do not change the env `eagerprep`.
- **Models:** PatchCore (wide_resnet50_2, layers 2 and 3, coreset ratio 0.1) and EfficientAD-S, both with the anomalib defaults, at 256 × 256. Write the settings and the training steps to the summary.
- **Training images:**
  - For each AutoVI class (engine_wiring, pipe_clip, tank_screw, underbody_pipes, underbody_screw), use its `train/good` images.
  - For FabriD, use the defect-free images, minus these:
    - the final test images;
    - the development pool images;
    - the images within 30 s of a final test image (`fabrid_time()`).
  - No training image is a test image (MD5 check).
- **Maps:**
  - Resize each anomaly map to the full image size.
  - Make each map lie in [0, 1] with the monotone function m / (m + c), where c is the 99th percentile of the map values on 10% of the training images. Hold those images out of the training.
  - Write the maps with `map_write()` into `C:/Users/megahefm/box_data/maps_final/<method>/` (the layout of `map_file()`).
  - Image score: the map maximum.
  - The method names are `PatchCore_full` and `EfficientAD_full`.
- **Check 1 (our setup against the published level):** score PatchCore_full on the full official test split of the 5 AutoVI classes with our R AU-sPRO port. Show it next to the published macro mean (PatchCore 0.58 ± 0.11 at FPR 0.05, over 6 classes with pipe_staple).
- **Check 2 (same images):** score both methods on the 546 final images with `three_levels()`, as `px_22_final_results.R` does. Compare each one with TTA_vote_G1 by `final_compare()` (seed 2043, 5,000 draws), with the p values not adjusted and the label "post hoc".
- **Outputs:** `box/scripts/px_30_fullshot.R`, `box/python/fullshot.py`, and `box/results/px_fullshot/`, which holds `fullshot_three_levels.csv`, `fullshot_compare.csv`, `fullshot_check1.csv` and `fullshot_summary.md`.

## Track B: box refinement (Jev answers fixed)

V is the TTA_vote_G1 map, as `tta_vote_map()` makes it. D is the DINO_k16_local_S map, which exists for the pool and for the final images. Every refined method keeps the image score of TTA_vote_G1, which is max(V). So image AUROC does not change, and the measures show only the effect of the boxes and masks.

| Name | Map | Boxes |
|---|---|---|
| REF_peak_q | V | the 8-connected parts of V ≥ q · max(V), q in {0.25, 0.5, 0.75}; score = G × the part maximum |
| REF_dino_l | V × ((1 − l) + l × D̃), l in {0.5, 1} | as REF_peak_q at q = 0.5, on the refined map |
| REF_sam_m | V × ((1 − m) + m × S), m in {0.5, 1} | the box of S, score as REF_peak_q |
| REF_samdino | V × S' with S' = the mean of S and D̃ | as REF_peak_q at q = 0.5 |

- **D̃:** min(D / d, 1), where d is the 99.9th percentile of D on the good images of the dataset.
  - On the pool, d comes from the dev good images.
  - For a new class, d comes from the same images as the FUSE constants of that class.
- **S:** the SAM 2.1 mask of `boxseg.py sam`. Its prompt is the REF_peak_q box at q = 0.5, with the peak of V as a positive point. Each part above q gets its own prompt. S is 0 outside the boxes.
- **Development rule:**
  - Maps: `dev_keep()` against TTA_vote_G1.
  - Boxes: the 95% interval of the dataset-mean gain in AP@0.3 lies above 0, and the false boxes per good image (score ≥ 0.5) are at most those of TTA_vote_G1 plus 0.05.
  - Choose at most one map method and one box method. Each is the highest development mean among the methods that keep. If none keeps, choose the highest and flag it.
- **Final scoring:** the frozen choice, once, on the 546 final images. Compare it with TTA_vote_G1 and DINO_k16_local_S, as in Track A.
- **Outputs:**
  - code: `box/R/refine.R` with tests in `box/tests/test-refine.R`, `box/scripts/px_31_refine_dev.R` and `box/scripts/px_32_refine_final.R`;
  - development files in `box/results/px_refine/`: `dev_refine_three_levels.csv`, `dev_refine_keep.csv` and `frozen_refine.json`;
  - final files in `box/results/px_refine/`: `final_refine_three_levels.csv`, `final_refine_compare.csv` and `refine_summary.md`.

## Verification

- The test suite passes before and after each track: `box/tests`, together with the rest of the suite.
- A replay of TTA_vote_G1 from the saved answers gives the same maps as `maps_final/TTA_vote_G1` (MD5) on 20 final images. Run it before any final scoring.
- The final scoring of Track B starts only after `frozen_refine.json` is committed.
- No line of the call logs changes (`replication_materials/calls/`).

## Records

- **Decisions:** D348, D349 and D350.
- **Process rows:**
  - one at the start (plan);
  - one at the end (evaluate).
- **Result row:** H19, post hoc. It cites H18.
- **Ledger:** the stage ledger, copied at the end.
