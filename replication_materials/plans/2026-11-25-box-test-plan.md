# Box test on FabriD and AutoVI (D335 to D337) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find out, on images that no strategy saw, if `locate()` (strategy T of D317) finds defects better than the two older strategies of the Box study.

**Architecture:** One set of fixed inputs (the test sets of D278 and one held-out AutoVI class), three strategies, each run once on each image with an answer cache for each image (a crash resumes and sends no image twice), every call in the call log of the record, and the measures of D303 with a paired bootstrap.

**Tech Stack:** R; `decisions` at tag v0.1.1.9000 in a separate library (`BOX_DATA/rlib`); the Box study code of branch `m7-box` (`box/R/`, `box/scripts/01_scan_spike.R`, `04_top_down_live.R`, `d303_eval.R`); `jev-1.14.0`.

**Spec:** `plans/2026-10-28-box-agentic-plan.md` (stage 4, with `locate()` as the frozen strategy) and the decisions D335 to D337.

## Global Constraints

- Model `jev-1.14.0` for all three strategies.
- Cap of this work: 3,000 calls and USD 2 (purpose prefix `box d336`), under the budget row of 2026-11-25 (6,000 calls, USD 20, D335).
- Each test image goes to each strategy once. Nothing is tuned on the test images. A rerun reads the cache and sends nothing.
- No test image went to Jev before this run. The references are not test images.
- The words, the references, the held-out class and its images are fixed in files before the first call of the test run.
- The key comes from `.Renviron` of the main checkout and is never written or printed.
- Code on branch `m7-box` (worktree `fine_tuned_jev-box`), results in `box/results/d336_test/`. Records on `main`.

## Design

**Images.** The test split of `box/results/sets/sets.csv`: FabriD, tank screw and pipe clip, each 30 defective and 10 defect-free (120 images), with the truth of `sets/truth.csv`. The held-out class: one of engine wiring, underbody pipes and underbody screw. Rule, fixed now: the class with the smallest median area of the truth boxes (as a share of the image) over all defective images of its test split. From it, 30 defective images (spread over the defect types as evenly as the counts allow) and 10 good images of `test/`, seed 2030, none of them a reference. Truth boxes from the AutoVI masks (`mask_truth()`, one box for each mask file).

**References.** FabriD, tank screw, pipe clip: the references of D303 (`make_refs()` of `01_scan_spike.R`, seed 2027), the crops for the region questions and for `locate()`. Held-out class: the same rule (`train/good` for the nominal image; for each defect type one image of `test/<type>` that is not in the test set, seed 2027; square crops of `square_around()`), with notes written from `defects_config.json` before any call.

**Strategies** (each once on each image):

- **L, `locate()`**: `decisions::locate(decider_typesafe("jev-1.14.0"), image, defect = words$one, references = list(nominal = <the nominal crop>, defective = <the defective crops>))`, one image at a time.
- **TD, top-down with Box** (round 3, D277): `search_image()` of `04_top_down_live.R`, with its parameters unchanged. The boxes are the Box answers in the final regions (at most 5).
- **Z, one Box on the whole image** (Z1 of D303, the one request of D273): the image at 1568 px, a Noul "Is there {words$one} in `inspection_image`?" and a Box "the defect in `inspection_image`", no references. The box counts only when the Noul is 0.5 or more.

**Measures** (`d303_measure()`, with the held-out class added): pointing recall and precision (box center in a truth box, 2% margin) and their F1, the share of defects with a box of IoU 0.3 and 0.5, images pointed, boxes for each defect-free image, the image AUC (L: `.pred_defect`; TD: the highest Noul of a final region, 0 with none; Z: the Noul), calls and USD for each image.

**Rule for "does better", fixed now:** on a dataset, L does better than another strategy when its pointing F1 is higher and the 95% interval of the paired bootstrap of the difference (2,000 resamples of the images, seed 2031) lies above 0. The cost limit of D278 is USD 0.01 for each image.

## Review Focus

1. A test image that is also a reference, a development image or a spike image: the run must stop before any call.
2. A crash in the middle of the run: the rerun must send no request for an image with a cached answer.
3. An image of the held-out class with a size outside 280 to 1568 px after the resize rules, or a mask file with no white pixel: stop before any call, with the file named.
4. The call log: each request of the three strategies has one row with purpose prefix `box d336`, also a failed request.
5. FabriD images with several defects: a strategy with one box cannot reach a pointing recall of 1; the summary must give images pointed next to recall.

---

### Task 1: Inputs, fixed before any call

**Files:**
- Create: `box/scripts/d336_01_inputs.R`
- Create: `box/results/d336_test/{sets.csv,truth.csv,inputs.json,heldout_pick.csv,contact_sheet.png}`

**Interfaces:**
- Produces: `sets.csv` (dataset, path, defective, split = "test", id, width, height) for the four datasets; `truth.csv` (id, class, left, top, right, bottom); `inputs.json` (for each dataset: words one/many/the, reference files, reference notes, crop squares); `heldout_pick.csv` (class, images, median truth area).

- [ ] **Step 1:** Install `decisions` v0.1.1.9000 into `BOX_DATA/rlib` (`git archive v0.1.1.9000` and `R CMD INSTALL --library`). Check: `packageVersion("decisions", lib.loc = rlib) == "0.1.1.9000"` and `locate` is exported.
- [ ] **Step 2:** Unzip the three candidate classes (MD5 checked against the Zenodo record) and write `heldout_pick.csv` by the rule of the Design. Expected: one class picked, its row first.
- [ ] **Step 3:** Write the words and the reference notes of the held-out class from its `defects_config.json` and its `defect_example.png`, before any call; build its test set, truth and references.
- [ ] **Step 4:** Run the checks (Review Focus 1 and 3): no test path among the reference files, the development set or the spike images; no test id in any file name under `box/results/` but `d336_test/`; each defective image has at least one truth box; each mask has white pixels; all sizes legal. Expected: `inputs: 160 test images, 4 datasets, all checks pass`.
- [ ] **Step 5:** Draw `contact_sheet.png`: the references of each dataset and 4 test images with their truth boxes; look at it.
- [ ] **Step 6:** Commit on `m7-box`.

### Task 2: Runner and smoke run on non-test images

**Files:**
- Create: `box/scripts/d336_common.R` (key, call log, caps, `d336_spent()`), `box/scripts/d336_02_run.R`

**Interfaces:**
- Consumes: the files of Task 1.
- Produces: `run_one(strategy, id, dataset, path, out)` that returns the cached result or makes the calls; per-image files `box/results/d336_test/<strategy>/<id>.rds`; responses under `responses/`.

- [ ] **Step 1:** `d336_common.R`: as `d303_common.R`, with the purpose prefix `box d336` and the caps of the Global Constraints. `jev_ask()` of `box/R/typesafe.R` is wrapped so that each purpose gets the prefix; `locate()` runs inside `with_logged_calls()` of `decisions/data-raw/vignette_results.R`, with `log_call()` of `data-raw/log_call.R` in its own environment (the box code has a function of the same name).
- [ ] **Step 2:** `d336_02_run.R`: for each dataset, strategy and image, `run_one()`; `BOX_D336_SMOKE=1` runs one defective development image of each study dataset and one `train/good` image of the held-out class into `d336_smoke/`, purpose `box d336 smoke`.
- [ ] **Step 3:** Smoke run. Expected: 4 images x 3 strategies with answers, rows in the call log with the prefix, under USD 0.05; a second run sends no call (Review Focus 2).
- [ ] **Step 4:** Commit.

### Task 3: The test run, once, and the results

**Files:**
- Create: `box/scripts/d336_03_results.R`, `box/results/d336_test/{measures.csv,bootstrap.csv,summary.md,sheet_<dataset>.jpg}`

- [ ] **Step 1:** Before the run, a fresh reviewer reads Task 1 and Task 2 (inputs, contact sheet, runner, smoke output) against this plan. Fix each Critical or Important finding first.
- [ ] **Step 2:** Run `d336_02_run.R` on the 160 test images. Expected: no error rows, calls and USD under the caps.
- [ ] **Step 3:** `d336_03_results.R`: the measures, the bootstrap of the rule, a sheet of the boxes for each dataset, `summary.md`. Expected: one row for each strategy and dataset; the verdict for each dataset by the rule.
- [ ] **Step 4:** Commit; record a results row, a decision row for the outcome, a process row and the ledger.
