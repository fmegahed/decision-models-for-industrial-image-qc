# Pixel study of Box (D340 to D344) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get pixel score maps and masks of defects from Jev, alone and with local models, and score every method at three separate levels (image, detection, pixel) on the development pool. Then choose one pure-Jev and one hybrid candidate for a final test that runs only after fmm's go.

**Architecture:** One evaluation module (pixel truth, R port of AutoVI sPRO, checked against the official code). Methods write one row and one full-size map per image. Free stages (saved answers, local SAM/DINOv2 on the GPU) come before paid stages. Each paid stage runs a smoke run first, under the cap and replay pattern of D336.

**Tech Stack:** R (httr2, tidyverse style, testthat), `box/R/typesafe.R`. Python 3.12 from the conda env `eagerprep` (torch 2.11+cu128, transformers 4.57.6), with no installs, called with `system2(..., "-I")`. The official AutoVI evaluation code (BSD-3) runs in its own small conda env.

**Spec:** `replication_materials/plans/2026-11-25-box-pixel-design.md` (approved in plan mode; D340 to D344).

## Global Constraints

- Code on branch `m7-box` (worktree `C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev-box`). Records on `main` of the main checkout.
- Paid calls only with the purpose prefix `box px dev`. The cap is 5,000 calls and USD 4, checked before each request (as `d336_check_cap()`). At most USD 0.01 for each image. The key comes from the main `.Renviron` and is never printed.
- No image of the final test is drawn or sent in this plan (Stage 5 has its own plan after fmm's go).
- Development pool: `box/results/sets/sets.csv` split `dev` (65) and `box/results/d336_test/sets.csv` (158) = 223 images.
- Nominal images (registered references, DINOv2 banks) come from AutoVI `train/good` only. Exclude any image whose MD5 equals an image of the pool.
- Maps: single-channel 16-bit PNG at full image size, value = round(65535 × s), s in [0, 1]. Path: `C:/Users/megahefm/box_data/maps/<method>/<dataset>/test/<type>/<stem>.png`, outside git.
- One row per image and method: `tibble(id, dataset, method, map_file, image_score, boxes = list(tibble(left, top, right, bottom, score)), calls, input_tokens, usd, error)`.
- Dev rule "keep": paired bootstrap over images (2,000 resamples, seed 2031). The 95% interval of the pooled AU-sPRO@0.05 gain lies above 0. No dataset falls by more than 0.03. Image AUROC falls by at most 0.02.

## Review Focus

1. A mask PNG whose pixel value is not in `defects_config.json` (a typo or 254 vs 255): the truth must stop with the file named, not fall back to a default saturation.
2. A map with a different size from its image (a crop pasted at the wrong scale): `map_write()` must stop.
3. A nominal image that is byte-identical to a pool image (60 engine-wiring test images equal train/good images): the bank must drop it.
4. A paid stage stopped by an error in the middle of an image: the rerun must replay the answers it has, and send only the rest.
5. A good image with a map of all zeros, or a defective image whose truth channel is a few pixels (blue_hoop 800 px absolute): sPRO must not divide by zero.

---

### Task 1: Pixel truth and the three-level evaluation (Stage 0, no calls)

**Files:** Create `box/R/evaluate.R`, `box/scripts/px_00_truth.R`, `box/scripts/px_01_validate.R`, `box/tests/test-evaluate.R`, `box/results/px/truth/` (channel index CSV and FabriD config).

**Interfaces:**
- Produces:
  - `truth_masks(id, dataset, path)` → `list(width, height, channels = list(logical H×W), defect = chr, saturation = dbl, relative = lgl)`. AutoVI: one channel per mask file, with the defect type from its pixel value via `defects_config.json`. FabriD: one channel per polygon, type "fabric", relative saturation 1.
  - `map_write(map, file)` and `map_read(file)` (numeric H×W in [0, 1]).
  - `boxes_to_map(boxes, width, height, kind = c("max", "vote"), n_requests = 1)`.
  - `map_to_boxes(map, threshold)` (8-connected parts; score = maximum of the part).
  - `pixel_hist(map, truth, bins = 4096)`: per image, counts of negative pixels and of each channel's pixels by bin.
  - `eval_pixels(hists, limits = c(.01, .05, .1, .3, 1))` → AU-sPRO at each limit, pixel AUROC, pixel F1-max.
  - `eval_image(score, defective)` → AUROC, AP, F1-max.
  - `eval_boxes(boxes, truth, iou = c(.1, .3, .5))` → AP at each IoU (greedy matching, COCO 101 points), false boxes per good image at a given threshold, pointing game against the mask (15 px).
  - `boot_compare(a, b, metric_fun, seed = 2031, R = 2000)`.

- [ ] **Step 1:** Write `box/tests/test-evaluate.R`:
  - a perfect map gives AU-sPRO 1 at each limit;
  - a constant map gives 0.5 at each limit;
  - a map of zeros on a good image gives no NaN;
  - an absolute saturation of 800 px on a channel of 300 px saturates at 300;
  - a 3×3 example with known TP and FP gives a hand-computed sPRO;
  - `boxes_to_map(kind = "max")` of one box covers exactly its pixels;
  - AP of perfect boxes is 1.
- [ ] **Step 2:** Run `Rscript -e 'testthat::test_file("box/tests/test-evaluate.R")'`. Expected: it fails (functions missing).
- [ ] **Step 3:** Implement `box/R/evaluate.R`. FabriD polygons are filled with the scan-line fill of the offline analysis (pixel centers). AutoVI masks are read with magick by value.
- [ ] **Step 4:** Run the tests. Expected: all pass.
- [ ] **Step 5:** `px_00_truth.R`: build the truth of the 223 pool images. Write `box/results/px/truth/channels.csv` (id, channel, defect, pixels) and `fabrid_defects_config.json`. Check that the tight-box ceiling reproduces the medians .42 / .37 / .61 / .50 on the D336 images (± 0.01). Expected: prints the ceiling table.
- [ ] **Step 6:** `px_01_validate.R`:
  1. Clone `github.com/phcarval/autovi_evaluation_code` at a pinned commit into `C:/Users/megahefm/box_data/autovi_eval`, and make the conda env `autovi_eval` with its requirements.
  2. Write check maps for tank screw and engine wiring (L box-as-mask, perfect, constant, seeded random) and for FabriD with the generated config.
  3. Run the official code with `python -I`, and compare.
  
  Expected: R and official agree within 0.005 at each limit, and image AUROC agrees exactly. Record the commit hash and `conda list` in `box/results/px/validate/`.
- [ ] **Step 7:** Commit on `m7-box`.

### Task 2: Post hoc re-scoring and free maps from saved answers (Stage 0, H0, no calls)

**Files:** Create `box/R/maps.R`, `box/scripts/px_02_rescore.R`, `box/scripts/px_10_free_maps.R`, `box/results/px/{rescore,h0}/`.

**Interfaces:**
- Consumes: Task 1.
- Produces: `spread_windows(windows, width, height, rule = c("mean", "min_scale"))`, `vote_map()`, `tile_map(tile_probs, width, height)`, `gaussian_map(boxes, width, height)`; method rows and maps for:
  - `L_box`, `TD_box`, `Z_box` (D336);
  - `T_box`, `TD_box`, `Z_box` (D303 dev);
  - `L_tiles`;
  - `TD_windows` (from `TD/per_image/*.rds$asked`);
  - `G4_windows` (D278 dev);
  - `truth_box` and `constant` reference rows.

- [ ] **Step 1:** Add tests to `test-evaluate.R` for `spread_windows()` (one window of score 1 gives 1 inside it and 0 outside; two equal windows give the same map in both rules) and for `tile_map()`. Run them; they fail. Implement `maps.R`. Run them; they pass.
- [ ] **Step 2:** `px_02_rescore.R`: three-level tables for D336 (L, TD, Z) and D303 dev (T, TD, Z), plus the reference rows. Every output header says "post hoc, measures chosen after the D336 results; no verdict". Expected: the box IoUs of D336 match `box/results/d336_test/per_image.csv`; the image AUROCs match `measures.csv`.
- [ ] **Step 3:** `px_10_free_maps.R`: the H0 maps on the 223 images. Spreading rules "mean" and "min_scale" for the window maps. Check the Choice lean toward t1: the share of L's top tile = t1 against the share of truth centers in t1. Expected: `box/results/px/h0/summary.md`, with AU-sPRO@0.05 per method and dataset and the bootstrap of the best window map against `L_box`.
- [ ] **Step 4:** Look at a contact sheet of maps for 8 images (`box/results/px/h0/sheet.jpg`), drawn with composites. Rule on the spreading rule (ledger). Commit.

### Task 3: Local models (Stage 1, H1 to H4a, no calls)

**Files:** Create `box/python/boxseg.py`, `box/python/requirements-boxseg.txt`, `box/R/hyb_python.R`, `box/R/register.R`, `box/scripts/px_11_local.R`, `box/results/px/local/`, `replication_materials/environment/python-boxseg-environment.txt` (main).

**Interfaces:**
- Produces:
  - `boxseg.py` subcommands `fetch` (download the weights at pinned revisions to `HF_HOME=C:/Users/megahefm/box_data/hf` and print their sha256), `sam` (manifest of box and point prompts → masks plus `results.csv` with iou_score), and `dino` (k-NN patch map against a bank → float32 map).
  - `run_boxseg(task, manifest)` in R.
  - `nearest_good(path, bank)`, by the mean absolute difference of 64 px thumbnails, with the MD5 exclusion.
  - Method rows: `SAM_truthbox`, `SAM_truthbox_noisy`, `SAM_Lbox_*`, `SAM_Lcenter`, `SAM_transfer` (tank), `DINO_k{1,4,16}{,_local}`, `DINO_gatedL`.

- [ ] **Step 1:** `fetch`: `facebook/sam-vit-base`, `facebook/sam2.1-hiera-tiny`, `syscv-community/sam-hq-vit-base`, `facebook/dinov2-small`, `facebook/dinov2-base`. Write `box/results/px/local/weights.csv` (repo, revision, file, sha256). The script asserts the versions of torch and transformers first. Expected: 5 rows.
- [ ] **Step 2:** Smoke on 4 pool images: SAM with the truth box returns masks of the right size; DINO returns a map of the right size. Write the env record with `conda list -n eagerprep --export`.
- [ ] **Step 3:** H1: SAM oracle on all defective pool images. Go on with a mask step only for datasets where the gain over the box ceiling is ≥ 0.10 (rule in the ledger).
- [ ] **Step 4:** H2: L boxes and centers as prompts, and the tank mask transfer. Compare with `L_box`.
- [ ] **Step 5:** H3: DINO maps (k = 1, 4, 16; global and local) on the 223 images. Banks from train/good with the MD5 exclusion. FabriD uses patches of the same image.
- [ ] **Step 6:** H4a: the DINO map × L `.pred_defect`. Write `box/results/px/local/summary.md` with the dev rule applied to each H. Commit.

### Task 4: Paid stage infrastructure and localization with pure Jev (Stage 2, H5, H6)

**Files:** Create `box/scripts/px_common.R`, `box/scripts/px_12_gate.R`, `box/scripts/px_13_windows.R`, `box/results/px/jev/`.

**Interfaces:**
- Consumes: `register.R` (Task 3), `maps.R` (Task 2), `jev_ask` of `box/R/typesafe.R`, and the replay wrapper of `d336_02_run.R` (by request name).
- Produces: method rows `G_gate` and `W_reg` (registered windows; G^γ variants with γ in {0, ½, 1}).

- [ ] **Step 1:** `px_common.R`: the prefix `box px dev`, the caps (5,000 calls, USD 4; stop USD 0.002 below), the per-image cost check (USD 0.01), and the replay wrapper.
- [ ] **Step 2:** Smoke both scripts on 4 pool images with `BOX_PX_SMOKE=1`. Expected: call-log rows with the prefix; a rerun sends 0 calls.
- [ ] **Step 3:** H5: the gate G on the 223 images (1 request each).
- [ ] **Step 4:** H6:
  1. Pilot on the 40 AutoVI images of D278 dev (registered windows at 5 sizes, 280 px crops, ±8 px shift search).
  2. Run all 223 images only if the pilot improves tank and is not worse on pipe (rule in the ledger).
- [ ] **Step 5:** Summary with the dev rule, spend so far. Commit.

### Task 5: Teach Jev with a box to segment (Stage 3, H7 to H9)

**Files:** Create `box/R/superpixels.R`, `box/scripts/px_14_segments.R`, `box/scripts/px_15_pick.R`, `box/scripts/px_16_verify.R`.

**Interfaces:**
- Produces: `slic_lite(img, n = 30, seed)` (kmeans on x, y and Lab), `outline_image()`, `som_image()`; method rows `SEG_outline`, `SEG_numbered`, `PICK_sam`, `DINO_verified`.

- [ ] **Step 1:** Test `slic_lite()`: it returns n labels that cover the crop, and the same seed gives the same labels. Implement it.
- [ ] **Step 2:** H7 (outlined and numbered segments around the best map peak or L box). Smoke run, then the 223 images.
- [ ] **Step 3:** H8: the free pre-check (best SAM candidate IoU minus SAM top IoU ≥ 0.08), then the Choice among outlined SAM masks with a reference crop that has its truth mask outlined.
- [ ] **Step 4:** H9: Noul check of the top 3 DINO regions against the registered nominal crop.
- [ ] **Step 5:** Summary with the dev rule. Commit.

### Task 6: Boxes and fusion, and the choice of the candidates (Stage 4, H10 to H13)

**Files:** Create `box/scripts/px_17_boxes.R`, `box/scripts/px_18_fusion.R`, `box/scripts/px_19_dev_results.R`, `box/results/px/dev_summary.md`.

- [ ] **Step 1:** H10: box TTA (8 crops, 2 wordings, WBF, vote map).
- [ ] **Step 2:** H11: boxes from the best map at the F1-max threshold, plus the zoom cascade. Judge on box AP@0.3 and false boxes per good image against L.
- [ ] **Step 3:** H12: Score against Noul on 60 images.
- [ ] **Step 4:** H13: ClipSAM-style fusion against the best single map.
- [ ] **Step 5:** `px_19_dev_results.R`: one table of all methods at three levels, with calls and USD per image. Name the best pure-Jev and the best hybrid candidate by the dev rule, with their frozen settings. Commit.
- [ ] **Step 6:** Records on main: results row H17 (post hoc baselines and dev results, Release "-"), process rows, the ledger copy. Then stop and report to fmm for the go of Stage 5.
