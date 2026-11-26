# Pixel study of Box, Stage 5: the one-time final test (D346) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the frozen candidate TTA_vote_G1 and its reference, the box of locate(), once on a fresh test set of about 550 images. Score both at three levels, and give the verdict of the rule below. FUSE and DINOv2 alone are scored on the same images as descriptive results.

**Architecture:**
- First close the items that the development review carried to this stage, with no call.
- Then draw the fresh test set, write the run and the analysis code, and commit them with a pre-registration file before the first final call.
- A paid z-calibration of the two new classes (train/good images, never test images) is the live smoke run.
- The test run is guarded so that it runs once, with the committed code only. Then the results script gives the verdict.

**Tech Stack:**
- R (httr2, tidyverse style, testthat), with `box/R/*.R` of branch `m7-box`.
- decisions v0.1.1.9000 in `C:/Users/megahefm/box_data/rlib` (pinned, `check_decisions_pin()`).
- Python of the conda env `eagerprep` for DINOv2 (`box/python/boxseg.py dino`), called with `-I`.

**Spec:**
- `replication_materials/plans/2026-11-25-box-pixel-design.md`: sections B (images), D (the rule) and E (budget).
- D346 in `replication_materials/project/decisions.md`: one formal candidate, a family of 5 tests.
- The `Ruling` and `carried to the Stage 5 plan` lines of `replication_materials/plans/2026-11-25-box-pixel-ledger.md`.
- The frozen recipe: `box/results/px/frozen.json` of branch `m7-box`.

## Global Constraints

- Code goes on branch `m7-box`, in the worktree `C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev-box`. Records go on `main` of the main checkout. Do not push `m7-box`.
- **Paid calls:**
  - Use the purpose prefix `box px final` only.
  - The cap is 7,000 calls and USD 6. Stop when USD 6 - 0.002 is reached. Check the cap before each request, from the call log `replication_materials/calls/typesafe-calls.csv` of the main checkout.
  - All requests of one image may cost at most USD 0.01 together.
  - The key comes from the main `.Renviron`. Never print or write it.
- **Outputs:**
  - Results go to `box/results/px_final/`.
  - Maps go to `C:/Users/megahefm/box_data/maps_final/<method>/<dataset>/test/<type>/<stem>.png`, outside git. Use `map_file(..., root = "C:/Users/megahefm/box_data/maps_final")`.
  - Each map is a 16-bit PNG holding round(65535 × s).
- **Seeds:**
  - test-set draw 2041;
  - references and z-calibration images of a new class 2042;
  - final bootstrap 2043, with 5,000 resamples.
- The recipe is the one in `frozen.json` (Task 1 rewrites it with a new commit, with no change in recipe or number). Do not change a word, a crop, a threshold or a bank rule.
- Datasets in this fixed order: `fabrid`, `tank_screw`, `pipe_clip`, `engine_wiring`, `underbody_pipes` (held-out), `underbody_screw` (descriptive only).
- Methods on the test images:
  - `L_box`: the reference; the box of locate() as a mask, with the image score 1 − P(none).
  - `TTA_vote_G1`: the candidate.
  - Descriptive only: `FUSE`, `DINO_k16_local_S`, `truth_box` (the ceiling) and `constant` (chance).
- No image of the development pool, and no image sent to Jev before, may be in the test set.
- Write all records in 80% ASD-STE100. Do not add a contraction.

## The rule (pre-registered; written before any final call)

1. **Primary family:** AU-sPRO at FPR 0.05 of TTA_vote_G1 minus that of L_box, on each of the 5 datasets `fabrid`, `tank_screw`, `pipe_clip`, `engine_wiring` and `underbody_pipes` (5 tests).
2. **Test of one dataset:**
   - Use a paired bootstrap over its images, stratified by good and defective: each resample draws the good images and the defective images apart, with replacement, with the dataset's own counts.
   - Use 5,000 resamples and `withr::with_seed(2043, ...)` for each dataset.
   - The two-sided p value is min(1, 2 × min((1 + #{Δ* ≤ 0}) / 5001, (1 + #{Δ* ≥ 0}) / 5001)), where Δ* is the difference in a resample.
   - The 95% interval is the percentile interval.
3. **Holm:** `stats::p.adjust(p, "holm")` over the 5 p values of the family, at α 0.05.
   - A dataset is *significantly better* when its Holm p is below 0.05 and the gain is above 0.
   - It is *significantly worse* when its Holm p is below 0.05 and the gain is below 0.
4. **Secondary family:** image AUROC of TTA_vote_G1 (the map maximum) minus that of L_box (1 − P(none)), on the same 5 datasets.
   - Use the same bootstrap (the same resamples) and the same p rule, with Holm over these 5.
   - An *image-AUROC loss* is a Holm p below 0.05 with a change below 0.
   - Ties count one half.
5. **Verdict:** TTA_vote_G1 *does better than locate()* when all three are true:
   - it is significantly better on 3 or more of the 5 datasets;
   - it is significantly worse on none;
   - it has no image-AUROC loss.
6. **Descriptive only (no verdict):**
   - FUSE, DINO_k16_local_S, FUSE against DINO alone (what Jev adds);
   - box AP at IoU 0.1, 0.3 and 0.5, and false boxes per good image;
   - AU-sPRO at 0.01, 0.1, 0.3 and 1, and pixel F1-max;
   - the dataset means;
   - all of `underbody_screw`.
7. **Failures:**
   - An attempt is one `jev_ask()` call, which itself repeats once after HTTP 429 or 503 (a rate limit). A request fails after 3 attempts without HTTP 200, that is, 2 retries.
   - A method fails on an image when a request that it uses fails. It then gets a map of 0 everywhere and an image score of 0.
   - No image is dropped.
   - Two failed requests in a row are an outage, not a failure of the images. The run stops and deletes those two failure records, and a later run sends them again.

## Review Focus

1. **A fresh image that is a byte twin or a near twin of an image sent before**, or of a development bank image: the draw drops it, and `dropped.csv` names the reason. The cases are:
   - the same MD5;
   - dHash distance 4 or less;
   - a FabriD file time within 30 s;
   - the 60 engine_wiring test images that are twins of train/good images.
2. **A request that fails 3 times:** the image keeps its row, the methods that use the request get a map of 0 and a score of 0, and the run goes on. Two failures in a row stop the run with no failure record.
3. **A run that stops in the middle (cap, outage, Ctrl-C):** the rerun replays every saved answer and sends only the rest. A rerun after a change in `box/R`, `box/scripts` or `box/python` stops before it sends anything.
4. **locate() step 1 answers "none":**
   - L_box has a map of 0 and the image score 1 − P(none);
   - the TTA request is still sent, and only its 16 boxes vote, divided by 20;
   - the gate is still sent.
5. **A new-class image:**
   - an `underbody_pipes/test/multiple` image with several mask files gets one channel for each file, with the saturation of its pixel value;
   - an `underbody_screw` image with a very small mask gives a finite sPRO;
   - a good image has no channel.

---

### Task 1: Close the items carried from the development review (no calls)

**Files:**
- Modify:
  - `box/R/recipe.R`: add `gate_g()`; tighten `check_decisions_pin()`; add `dino_items()` and `dino_maps()`;
  - `box/R/maps.R` (`vote_map()`);
  - `box/R/frozen.R`: the gate text, `stage5_functions()`, and the text of the pure_jev map;
  - `box/scripts/px_11_local.R:316-330`: call `dino_items()` and `dino_maps()`;
  - `box/scripts/px_19_recipe_check.R`.
- Test: `box/tests/test-stage5.R` (new).

**Interfaces:**
- Consumes: `vote_map()`, `map_write()`/`map_read()`, `locate_crop()` of `box/R/pool.R`, `run_boxseg()` and `read_f32()` of `box/R/hyb_python.R`, `nearest_good()` of `box/R/register.R`.
- Produces:
  - `gate_g(noul) -> numeric`: round(65535 × noul) / 65535.
  - `check_decisions_pin(rlib, pin = decisions_pin, ns_path = function() getNamespaceInfo("decisions", "path"))`: it also stops when the loaded decisions namespace does not come from `file.path(rlib, "decisions")`. Load the namespace with `loadNamespace("decisions", lib.loc = rlib)` first when it is not loaded.
  - `dino_items(sets, nn) -> tibble(key, image, mode, bank)`: FabriD rows are `self` mode; AutoVI rows are `bank` mode with the 16 paths of `nn`, joined with `|`.
  - `dino_maps(items, out_dir) -> tibble(key, file, height, width)`, for DINO_k16_local_S only. It uses the settings of `px_11_local.R:322-323`: dinov2-small at the pinned revision of `box/results/px/local/weights.csv`, short side 448, local radius 2, self window 2, self rank 3, k 16, sigma 4.
  - `vote_map()` gives a warning that contains "no confidence" and sets `attr(map, "na_boxes")` when a box has an NA score. The map stays the same.

- [ ] **Step 1: Write the failing tests** in `box/tests/test-stage5.R`:
```r
test_that("gate_g stores the Noul in 16 bits", {
  expect_identical(gate_g(c(0, 1, 0.5)), round(65535 * c(0, 1, 0.5)) / 65535)
  f <- withr::local_tempfile(fileext = ".png")
  map_write(matrix(0.123456, 4, 5), f, 5, 4)
  expect_equal(map_read(f)[1, 1], gate_g(0.123456), tolerance = 0)
})
test_that("vote_map warns on a box with no confidence", {
  b <- tibble::tibble(left = 0, top = 0, right = 1, bottom = 1, score = NA_real_)
  expect_warning(m <- vote_map(b, 5, 4, n_requests = 20), "no confidence")
  expect_identical(attr(m, "na_boxes"), 1L)
  expect_true(all(m == 0))
})
test_that("locate_crop of pool.R equals the copy in decisions", {
  skip_if_not(dir.exists("C:/Users/megahefm/box_data/rlib/decisions"))
  # a grid: 6 boxes (inside, at each edge, a corner, tiny) x grow c(1, 1.2, 1.5) x min_frac c(0, 0.25) x sizes c(1920x1080, 400x2400)
  # each case: expect_identical(locate_crop(...), decisions:::locate_crop(...)) with the argument names of the decisions function
})
test_that("check_decisions_pin stops when decisions comes from another library", {
  skip_if_not(dir.exists("C:/Users/megahefm/box_data/rlib/decisions"))
  rlib <- "C:/Users/megahefm/box_data/rlib"
  expect_error(check_decisions_pin(rlib, ns_path = \() "C:/R/library/decisions"), "not loaded from")
  expect_true(check_decisions_pin(rlib, ns_path = \() file.path(rlib, "decisions")))
})
```
- [ ] **Step 2:** Run `Rscript -e 'testthat::test_file("box/tests/test-stage5.R")'` from the worktree root. Expected: the 4 tests FAIL (gate_g and the ns_path argument do not exist, and vote_map gives no warning). The locate_crop test may pass on the first run; that is its purpose (the copy has not drifted). Write that in the report.
- [ ] **Step 3:** Implement the functions of the Interfaces block.
  - `dino_items()` and `dino_maps()` replace the inline code of `px_11_local.R:316-330`. px_11 keeps its other backbones and k values: call `run_boxseg()` with its own lists there, and use `dino_maps()` only for the S / k 16 / local variant. If that split is awkward, `dino_maps()` may take the backbones and ks as arguments, with the Stage 5 values as defaults.
  - In `frozen.R`, the gate `output` becomes "G = gate_g(Noul) = round(65535 x Noul) / 65535, the stored gate value (development ran so; ruling N1)".
  - The pure_jev map text becomes "... still divided by 20; then the map is multiplied by G (gamma 1)".
  - Add `gate_g`, `dino_items` and `dino_maps` to `stage5_functions()`.
- [ ] **Step 4:** Run the test file again. Expected: all pass. Then run the whole suite: `Rscript -e 'testthat::test_dir("box/tests")'`. Expected: 0 failures (555 or more tests).
- [ ] **Step 5: Make the recipe check exact** (`px_19_recipe_check.R`, carried item N2). Add 3 checks for each of the 223 images:
  - (a) `gate_g()` of the replayed gate Noul equals the G of `box/results/px/jev/rows_gate.rds`, exactly;
  - (b) the TTA_vote_G1 map that `tta_vote_map(..., gate_g(noul))` rebuilds, written with `map_write()` to a temporary PNG and read back, is `identical()` to `map_read()` of the stored PNG;
  - (c) `fuse_map()` of the rebuilt J PNG and the stored D PNG is identical to the stored FUSE PNG.

  Add a DINO rebuild check for 12 pool images: the first 3 of each dataset in `pool_sets()` order. `dino_maps()` rebuilds them, and the largest absolute difference against the stored DINO_k16_local_S PNG must be 2/65535 or less. Write the share of images with identical PNGs.
- [ ] **Step 6:** Run `Rscript --no-environ box/scripts/px_19_recipe_check.R > .superpowers/sdd/2026-11-26-box-pixel-final-plan/recipe_check_run.log 2>&1`. Expected:
  - every check is 223/223, the new checks a, b and c too;
  - the DINO check passes on 12/12.

  If check b or c fails on an image, stop and report it: the frozen convention does not hold.
- [ ] **Step 7:** Commit the code, then run `Rscript --no-environ box/scripts/px_19_dev_results.R` on the clean tree.
  - Expected: `frozen.json` names the new commit.
  - `git diff --stat` shows no change in `dev_three_levels.csv`, `dev_keep.csv`, `dev_detection.csv` or `dev_means.csv`.
  - Commit the results: `git commit -m "Pixel study, Stage 5 Task 1: gate_g, exact recipe check, DINO step in box/R; frozen.json on the new commit"`.

### Task 2: The fresh test set and the new-class inputs (no calls)

**Files:**
- Create: `box/R/final.R` (draw functions), `box/scripts/px_20_final_inputs.R`.
- Test: `box/tests/test-final.R` (new).
- Writes to `box/results/px_final/`:
  - `sent_md5.csv`, `candidates.csv`, `dropped.csv`, `sets.csv`;
  - `refs/<class>/*.jpg`, `inputs.json`;
  - `zcal_images.csv`, `gate_refs.csv`, `dino_banks.csv`;
  - `contact_sheet.png`.

**Interfaces:**
- Consumes:
  - `autovi_good_paths()`, `good_bank()` and `nearest_good()` of `box/R/register.R`;
  - `new_class_z_images()`, `loc_references()` and `check_decisions_pin()` of `box/R/recipe.R`;
  - `new_class_words()` and `bank_rule()` of `box/R/frozen.R`;
  - `truth_masks()` of `box/R/evaluate.R`;
  - `load_img()`, `crop_sent()`, `square_around()` and `fit_limits()` of `box/scripts/01_scan_spike.R` (sourced as `d336_01_inputs.R` does);
  - `box/results/px/dev_images_md5.csv`.
- Produces:
  - `dhash64(path) -> logical(64)`: the image as grey at 9 × 8 px; a bit is TRUE when a pixel is brighter than its right neighbour.
  - `dhash_dist(a, b) -> integer`: the number of differing bits.
  - `fabrid_time(path) -> POSIXct`, from `IMG_YYYYMMDD_HHMMSS` in the file name (UTC).
  - `new_class_refs(held, seed) -> list(files, crop)`: lines 100-141 of `d336_01_inputs.R` as one function, with `withr::with_seed(seed, ...)`.
  - `draw_final(candidates, n_def, n_good, seed = 2041) -> tibble(dataset, id, path, defective, type, width, height)`.
  - `sets.csv` has the columns of `pool_sets()`: id, dataset, path, defective, width, height, and set = "final".

- [ ] **Step 1: Write the failing tests** in `box/tests/test-final.R`:
```r
test_that("dhash is 0 for the same image and small for a copy at a new size", {
  # a 64x48 image from a fixed seed, written as PNG; a resized copy (60%) as JPEG
  # expect_identical(dhash_dist(dhash64(a), dhash64(a)), 0L); expect_lte(dhash_dist(dhash64(a), dhash64(b)), 4L)
  # a different seeded image: expect_gt(dhash_dist(...), 4L)
})
test_that("fabrid_time reads the time in the file name", {
  expect_equal(fabrid_time("x/IMG_20260714_182503_jpg.rf.e92a.jpg"),
               as.POSIXct("2026-07-14 18:25:03", tz = "UTC"))
})
test_that("new_class_refs with seed 2027 rebuilds the D336 references of engine_wiring", {
  skip_if_not(dir.exists("C:/Users/megahefm/box_data/engine_wiring"))
  r <- new_class_refs("engine_wiring", 2027)
  # write the crops as d336_01_inputs.R lines 246-254 do, to a temporary folder;
  # expect_identical(unname(tools::md5sum(<written>)), unname(tools::md5sum(<box/results/d336_test/refs/engine_wiring/*.jpg, same names>)))
  # expect_setequal(unname(r$files), unlist(jsonlite::read_json("box/results/d336_test/inputs.json")$engine_wiring$ref_files))
})
test_that("draw_final gives the same sets for the same seed and draws no image twice", {
  # a toy candidates tibble of 2 datasets; two calls give identical(); no duplicated path; counts min(n, available)
})
```
- [ ] **Step 2:** Run `Rscript -e 'testthat::test_file("box/tests/test-final.R")'`. Expected: FAIL (the functions do not exist).
- [ ] **Step 3:** Implement `box/R/final.R`. `draw_final()` does this for each dataset, in the fixed order of the Global Constraints, inside one `withr::with_seed(seed, ...)`:
  1. sort the eligible defective paths with `sort(method = "radix")`;
  2. `sample(paths, min(n_def, length(paths)))`;
  3. do the same with the good paths.
- [ ] **Step 4:** Run the test file. Expected: PASS.
- [ ] **Step 5: Write `px_20_final_inputs.R`.** It runs from the worktree root, with no call. Start with `check_decisions_pin(rlib)`.
  1. **Sent images.** `sent_md5.csv` is the union of these, with a `source` column:
     - the 915 MD5s of `dev_images_md5.csv`;
     - the `sent` vector of `d336_01_inputs.R` lines 191-200, rebuilt in the same way (dev split, spike images, D303 references, smoke files, the 3 pilot files);
     - every path of `box/results/sets/sets.csv` and of `box/results/d336_test/sets.csv`.
  2. **Candidates** (`candidates.csv`):
     - FabriD: `test/images`. An image is defective when its label file has a polygon, and good when the file has none.
     - AutoVI: `test/<type>/*.png`. The type is the folder; `good` is good.
     - Then make the new-class references with `new_class_refs(class, 2042)` for `underbody_pipes` and `underbody_screw`. Write their crops to `refs/<class>/<name>.jpg`, as `d336_01_inputs.R` lines 246-254 do, and remove their source images from the candidates.
  3. **Drop rules** (`dropped.csv`: path, dataset, reason, matched):
     - the MD5 is in `sent_md5`;
     - the dHash distance to any sent image file is 4 or less;
     - FabriD only: the file time is within 30 s of a sent FabriD image;
     - the dHash distance to an earlier kept candidate of the same dataset is 4 or less (go in radix-sorted path order);
     - the image has no mask file (AutoVI defective) or no polygon (FabriD defective).
  4. **Draw:** `draw_final(kept, n_def, n_good, 2041)` with these counts:

     | Dataset | Defective | Good |
     |---|---|---|
     | fabrid | 60 | 40 |
     | tank_screw | all | 40 |
     | pipe_clip | 60 | 40 |
     | engine_wiring | 60 | 40 |
     | underbody_pipes | 60 | 40 |
     | underbody_screw | all | 40 |

     Ids are `<dataset>_<d|g>_<type>_<stem>`, as in `d336_01_inputs.R:171`.
  5. **Checks** (`stopifnot`):
     - no final MD5 in `sent_md5`;
     - no two final images within dHash 4;
     - no final path among the reference sources;
     - `truth_masks()` gives channels for each defective image and none for each good image;
     - the name check of `d336_01_inputs.R` lines 227-239 over `box/results` (except `px_final/`) finds no final id or FabriD stem.
  6. **Banks** (`bank_rule()`, Stage 5): the bank of each AutoVI class is train/good minus the MD5s of the final images and of the 223 pool images.
     - `gate_refs.csv`: id, ref_path, ref_md5, from `nearest_good(path, bank, 1)`. A FabriD image uses the D336 `nominal_example` crop.
     - `dino_banks.csv`: id, rank 1-16, path, from `nearest_good(path, bank, 16)`.
  7. **z-calibration images** (`zcal_images.csv`): `new_class_z_images()` for each new class. Exclude the MD5s of the final images, of `dev_images_md5.csv` and of the class's reference sources.
     - Add their gate reference and their 16 DINO neighbours from the same bank. `nearest_good()` drops the image itself.
     - Stop if a z-calibration MD5 equals a final image MD5.
  8. **`inputs.json`**, for each dataset:
     - `words`: D336 `inputs.json` for the 4 development datasets, and `new_class_words()` for the new classes;
     - `crop_files`, `ref_files`;
     - `images`, `defective`;
     - `decisions` = `decisions_pin`.
  9. **`contact_sheet.png`**: the reference crops of each new class, and 4 test images of each dataset with their truth outlined.
- [ ] **Step 6:** Run `Rscript --no-environ box/scripts/px_20_final_inputs.R > .superpowers/sdd/2026-11-26-box-pixel-final-plan/inputs_run.log 2>&1`. Expected: "all checks pass", and the counts of each dataset are printed. The expected total is about 547; if a dataset has fewer eligible images than its count, all are taken and the log says so. Look at `contact_sheet.png`.
- [ ] **Step 7:** Run the whole suite (0 failures), then commit the code and `box/results/px_final/`: `git commit -m "Pixel study, Stage 5 Task 2: the fresh test set, new-class references and banks (no call)"`.

### Task 3: The run code, the analysis code and the pre-registration (no paid calls)

**Files:**
- Create:
  - `box/scripts/px_final_common.R` (key, log, cap, retries, failures, guard);
  - `box/scripts/px_21_final_run.R`, with modes `replay-check`, `zcal` and `test`;
  - `box/scripts/px_22_final_results.R`.
- Modify:
  - `box/R/final.R`: the analysis functions;
  - `box/R/pool.R`: move the locate parsing of `d336_answers()` into `locate_parts()`; `d336_answers()` then calls it.
- Test: `box/tests/test-final.R`.

**Interfaces:**
- Consumes:
  - the Task 1 functions;
  - `tta_request()`, `tta_answers()`, `tta_vote_map()`, `gate_request()`, `fuse_map()`, `new_class_z_constants()` and `loc_references()` (recipe.R);
  - `replay_ask()`, `cap_check()`, `calls_allowed()` and `image_check()` (requests.R);
  - `jev_ask()` (typesafe.R);
  - `method_row()`, `three_levels()`, `spro_curves()`, `spro_at()` and `auroc_rank()`;
  - the Task 2 files.
- Produces:
  - `locate_parts(t1, t2, row, width, height) -> tibble(tiles, choice, loc_box, loc_boxes4, loc_score)`. `t1` and `t2` are the parsed step-1 and step-2 response bodies, or NULL.
  - `with_retries(send, tries = 3, wait = 10) -> answer | structure(list(error = <message>), class = "px_failed")`.
  - `final_ask(questions, assets, state, purpose, name, out_dir)`: `replay_ask()` + `with_retries()` + the cap check before each attempt. A `px_failed` result is saved in `<out_dir>/failed/<name>.rds` and returned on a rerun without a call.
  - `run_guard(dir, commit_file = "prereg.json")`. It stops when:
    - `done.json` exists in `dir`;
    - `git status --porcelain -- box/R box/scripts box/python` is not empty;
    - `git diff --quiet <prereg code commit> HEAD -- box/R box/scripts box/python` fails.

    It writes `started.json` (time, HEAD) at the first call.
  - `strata_sample(defective) -> integer`: one stratified resample of the indices.
  - `final_pvalue(draws) -> numeric`: the p rule of "The rule", item 2.
  - `final_compare(hists_a, hists_b, score_a, score_b, defective, seed = 2043, R = 5000) -> tibble(spro_a, spro_b, gain, lower, upper, p_spro, auroc_a, auroc_b, change, image_lower, image_upper, p_auroc)`.
  - `final_verdict(tab) -> list(table, does_better)`: it adds `holm_spro`, `holm_auroc`, `better`, `worse` and `image_loss`.

- [ ] **Step 1: Write the failing tests** (append to `box/tests/test-final.R`):
```r
test_that("strata_sample keeps the good and defective counts", {
  d <- c(rep(TRUE, 7), rep(FALSE, 3))
  for (i in 1:50) { k <- strata_sample(d); expect_identical(sum(d[k]), 7L); expect_length(k, 10) }
})
test_that("final_pvalue is two-sided with the +1 rule", {
  expect_equal(final_pvalue(c(rep(1, 4999), -1)), 2 * 2 / 5001)
  expect_equal(final_pvalue(rep(0, 5000)), 1)
})
test_that("final_compare of a method with itself gives gain 0 and p 1", {
  # hists of 6 toy images (3 defective) from pixel_hist(); expect gain == 0, change == 0, p_spro == 1, p_auroc == 1
})
test_that("final_verdict follows the rule", {
  tab <- tibble::tibble(dataset = letters[1:5], gain = c(.2, .2, .2, .1, .1), p_spro = c(.001, .001, .001, .5, .5),
                        change = 0, p_auroc = 1)
  expect_true(final_verdict(tab)$does_better)
  expect_false(final_verdict(dplyr::mutate(tab, p_spro = c(.001, .001, .5, .5, .5)))$does_better)
  expect_false(final_verdict(dplyr::mutate(tab, gain = c(.2, .2, .2, -.1, .1), p_spro = c(.001, .001, .001, .001, .5)))$does_better)
  expect_false(final_verdict(dplyr::mutate(tab, change = c(-.2, 0, 0, 0, 0), p_auroc = c(.001, 1, 1, 1, 1)))$does_better)
})
test_that("with_retries tries 3 times, then gives a px_failed", {
  n <- 0; ok <- with_retries(\() { n <<- n + 1; if (n < 3) stop("HTTP 500") else "answer" }, wait = 0)
  expect_identical(ok, "answer"); expect_identical(n, 3)
  n <- 0; bad <- with_retries(\() { n <<- n + 1; stop("HTTP 500") }, wait = 0)
  expect_s3_class(bad, "px_failed"); expect_identical(n, 3)
})
test_that("run_guard stops after done.json and on a changed code tree", {
  # a temporary dir with done.json: expect_error(run_guard(dir), "runs once")
  # inject the git outputs through arguments (porcelain, diff_ok) as check_clean_tree() does: expect_error(..., "changed")
})
```
- [ ] **Step 2:** Run the test file. Expected: the new tests FAIL.
- [ ] **Step 3: Implement the functions.** `final_compare()` follows `dev_keep()` (`spro_curves()` and `spro_at()` with weights, `auroc_rank()`), with `strata_sample()` for the resamples.

  **`px_21_final_run.R`, per image** (one `per_image/<id>.rds` with `recipe_hash = rlang::hash(frozen$candidates$pure_jev)`; stop when a saved file has another hash):
  1. **L:** `decisions::locate(decisions::decider_typesafe("jev-1.14.0"), image = path, defect = words$one, references = <crop files as d336_02_run.R:113-117>)`, inside the `logged()` mock of `d336_02_run.R:85-106`.
     - Purpose `box px final locate <dataset>`.
     - Replay by body hash.
     - Up to 3 attempts for each request.
     - Then `locate_parts()`.
  2. **TTA** (when step 1 has an answer): `tta_request()`, then `final_ask(name = "<id>_TTA")`.
     - Before sending, estimate the cost as `px_17_boxes.R:133-135` does. Stop when the image would pass USD 0.01.
  3. **Gate:** `gate_request(id, path, ref_path from gate_refs.csv, one)`, then `final_ask(name = "<id>_G")`, then `G = gate_g(noul)`.
  4. **Outage:** two failed requests in a row stop the run and delete their `failed/` files.

  **After all images (local):**
  - make the DINO maps with `dino_items()` and `dino_maps()`;
  - write the maps and rows of L_box, TTA_vote_G1, DINO_k16_local_S, FUSE, truth_box and constant, with `method_row(..., root maps_final)`;
  - for FUSE, use the z constants of `box/results/px/fusion/z_constants.csv` for the 4 development datasets and `zcal/z_constants_new.csv` for the new classes;
  - make the boxes with `map_to_boxes()` at the frozen thresholds;
  - apply the failure rule of "The rule", item 7;
  - write `rows.rds`, `hists.rds`, `rows.csv` and `done.json`.

  **Modes:**
  - `replay-check`: the 158 D336 images, with `BOX_MAX_CALLS=0` and these replay folders: `box/results/d336_test/L/replay`, `box/results/px/boxes/h10/replay` and `box/results/px/jev/replay`. Gate references come from `box/results/px/jev/refs.csv`. Maps go to a temporary root.
  - `zcal`: the 40 z-calibration images. Write `zcal/per_image`, then `zcal/z_constants_new.csv` with `new_class_z_constants()`.
  - `test`: `run_guard()` first, then the final images.

  **`px_22_final_results.R`:**
  - `three_levels()` of all methods;
  - `final_compare()` for each dataset of the families, then `final_verdict()`;
  - the descriptive comparisons;
  - the files `final_three_levels.csv`, `final_primary.csv`, `final_descriptive.csv`, `final_summary.md` and `final_sheet.png` (3 defective images of each dataset: the image with its truth, L_box, TTA_vote_G1).
  - `BOX_PX_FINAL_DRY=1` runs it on the development rows of TTA_vote_G1 and L_box (the 4 datasets, with `underbody_pipes` missing). It writes to `px_final/dry_run/` with the post hoc line.
- [ ] **Step 4:** Run the test file and the whole suite. Expected: 0 failures.
- [ ] **Step 5:** Run `BOX_MAX_CALLS=0 Rscript --no-environ box/scripts/px_21_final_run.R replay-check`. Expected:
  - 0 calls;
  - 158/158 L_box and TTA_vote_G1 maps identical (`identical()` of `map_read()`) to the stored development maps of `box_data/maps`.

  A mismatch stops the task: report it.
- [ ] **Step 6:** Run `BOX_PX_FINAL_DRY=1 Rscript --no-environ box/scripts/px_22_final_results.R`. The dry run must use the same development rows as `dev_keep.csv`, with the same pool labels of the reference. Expected: the dry-run gains and AUROC changes of the 4 datasets equal those of `dev_keep.csv` (TTA_vote_G1 against L_box) within 1e-9.
- [ ] **Step 7: Pre-registration.** Commit the code. Then write `box/results/px_final/prereg.json` with:
  - `code_commit` (that commit);
  - `frozen_commit` (from `frozen.json`);
  - the rule of this plan, items 1-7, as text;
  - the counts of `sets.csv`;
  - the MD5 of `sets.csv`, `inputs.json`, `gate_refs.csv` and `dino_banks.csv`.

  Commit it: `git commit -m "Pixel study, Stage 5 Task 3: run and analysis code, replay check 158/158, pre-registration"`.

### Task 4: The z-calibration and the one-time test run (paid: about 2,300 calls, about USD 1.2)

**Files:**
- Writes to `box/results/px_final/`: `zcal/`, `per_image/`, `replay/`, `responses/`, `failed/`, `started.json`, `done.json`, `rows.*`, `hists.rds`.
- Call-log rows go to the main checkout.

**Interfaces:**
- Consumes: `px_21_final_run.R` of Task 3, with no change.
- Produces: `rows.rds` (one row per image and method, the columns of `method_row()` plus `calls`, `input_tokens`, `usd`, `failed`), `zcal/z_constants_new.csv`.

- [ ] **Step 1: Smoke run.** Run `BOX_PX_MAX_CALLS=4 Rscript --no-environ box/scripts/px_21_final_run.R zcal`. Expected:
  - it stops at the run cap;
  - the new call-log rows have purposes that start with `box px final`;
  - no key appears in any file;
  - the cost per image is below USD 0.01.

  Then run with `BOX_MAX_CALLS=0`. Expected: 0 calls (replay).
- [ ] **Step 2:** Run `Rscript --no-environ box/scripts/px_21_final_run.R zcal`. Expected:
  - about 160 calls;
  - `z_constants_new.csv` has J and D for both new classes, and the `from` column says which sd is the fallback.

  Commit `zcal/` and the run code state (the code does not change).
- [ ] **Step 3:** Run `BOX_PX_MAX_CALLS=12 Rscript --no-environ box/scripts/px_21_final_run.R test`. This is the first part of the one run. Check:
  - the rows of 3 images (requests, boxes, G, cost);
  - one TTA picture against its tile.
- [ ] **Step 4:** Run `Rscript --no-environ box/scripts/px_21_final_run.R test > .superpowers/sdd/2026-11-26-box-pixel-final-plan/final_run.log 2>&1`.
  - When it stops (an outage), run it again; it replays.
  - Expected: `done.json` exists, the run printed its call count and USD, and the spend under `box px final` is below 7,000 calls and USD 6.
- [ ] **Step 5:** Commit the results with `git add -f` where `.gitignore` blocks them, as the development stages did: `git commit -m "Pixel study, Stage 5 Task 4: the one-time final run"`.

### Task 5: The results, the records and the report (no calls)

**Files:**
- Writes `box/results/px_final/final_*` (on `m7-box`).
- Main checkout:
  - `replication_materials/calls/typesafe-calls.csv` (rows written by the run);
  - `project/results.md` (H18);
  - `project/process.md`;
  - `plans/2026-11-26-box-pixel-final-ledger.md`;
  - `project/roadmap.md`.

**Interfaces:**
- Consumes: `px_22_final_results.R` of Task 3, with no change; the rows of Task 4.
- Produces: `final_summary.md`, with the verdict line "TTA_vote_G1 does better than locate(): TRUE|FALSE".

- [ ] **Step 1:** Run `Rscript --no-environ box/scripts/px_22_final_results.R`. Expected:
  - it prints the 5 rows of each family with their Holm p values, and the verdict;
  - `final_summary.md` lists the descriptive results and the spend.

  Look at `final_sheet.png`. Commit it on `m7-box`.
- [ ] **Step 2: Records on `main`** (record-only commits, pushed):
  - the call-log rows;
  - H18 (Release "-", Source the ledger copy, Decisions D341, D344, D345 and D346): the verdict and the AU-sPRO and image AUROC numbers of each dataset;
  - a process row (stage `evaluate`);
  - the ledger copy (end-of-milestone procedure of the replication-materials skill);
  - the Plan and Ledger cells of M7 in the roadmap. M7 stays `now`.

  Run the build check, then push, then check the site run.
- [ ] **Step 3:** Report to fmm:
  - the verdict and its table;
  - the descriptive results;
  - the spend;
  - the rulings and the deferred minors.

  Ask fmm whether to push and merge `m7-box` (superpowers:finishing-a-development-branch).
