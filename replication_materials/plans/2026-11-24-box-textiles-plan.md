# Box test on the textiles of decisions (D307) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A yes or no, by the gate of D312, for Box in decisions, from the strategies T and Z of D303 on the 46 textile inputs of the package.

**Architecture:** Truth boxes first (from the simulation if it reproduces the files, else drawn), then the inputs of the strategies, fixed and shown to fmm before any call, then one run of T and Z with the measures of D303 and the gate.

**Tech Stack:** R (httr2, magick), the D303 code in `fine_tuned_jev-box/box/scripts/d303_*.R`, TypeSafe `jev-1.14.0`, spc4sts 0.6.5.

**Spec:** `replication_materials/plans/2026-11-24-decisions-0.2.0-design.md` (approved, D313), section 4; gate D312.

Paths: `box/` is `C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev-box/box` (branch `m7-box`); `pkg/` is `C:/Users/megahefm/Dropbox/Miami/Code/claude/decisions`; `study/` is the main checkout of the study. Results go to `box/results/d307_textiles/`.

## Global Constraints

- The data: the 50 rows of `pkg/data/textiles.rda`; images in `pkg/inst/extdata/textiles/`, 250 x 250 px. Inputs: 46 (23 nominal, 14 local, 9 global). References: 4 (2 nominal, `local_textile_0471.jpg`, 1 global).
- Gate (D312): Box goes into decisions if the better of T and Z puts the center of its box in the truth box (2% margin) for at least 12 of the 14 local-defect inputs.
- "Nothing is changed after the first call, because the 46 images are both the data and the gate."
- Budget row of D307: at most 400 calls and USD 0.10, model `jev-1.14.0`; each call logged in `study/replication_materials/calls/typesafe-calls.csv` (`BOX_CALL_LOG`) with the purpose prefix `box d307`.
- The key comes from `study/.Renviron` (`readRenviron()`); never printed or written.
- Records on `main` of the study: build check, record-only commits. Code on `m7-box` of the worktree (no push).

## Review Focus

1. A truth box from the simulation that is in the wrong frame (row and column swapped, or flipped in y, because R image matrices and JPEG pixels differ): Task 1 draws the box on the image of the package and fmm checks it on the contact sheet.
2. A strategy that always returns a box near the center would point to many central defects by chance: Task 3 reports the share of local defects whose truth box holds the image center, next to the result.
3. The 250 px images are below the 280 px limit of TypeSafe: every request enlarges the image or the crop first (T: tiles at 560 px, Box at 1024 px; Z: 1568 px, then 1024 px). Task 3 fails a call with "Invalid image dimensions" loudly, not silently.
4. A reference crop that is not square or that leaves the image: Task 2 clamps the crop to the image and checks its size before the contact sheet.
5. A rerun of a request gives another box (D303: 7% to 27% of pairs below IoU 0.5): Task 3 runs each request once and reports this limit with the result.

---

### Task 1: Truth boxes

**Files:**
- Create: `box/scripts/d307_01_truth.R`
- Create: `box/results/d307_textiles/truth.csv` (columns `file`, `x0`, `y0`, `x1`, `y1` in pixels of the 250 x 250 image, `source` = `simulation` or `drawn`)

- [ ] **Step 1: Try to make the textiles again**

Install spc4sts 0.6.5 in a scratch library. Run the code of `study/imgs/textile_images/extract_textile_images_from_r_textile_pkg.R` (with `set.seed(2024)`) into a scratch folder, and keep the location of the defect that `spc4sts::imposeDefect()` returns for each local image. Compare the MD5 of each new file with the file of the same name in `pkg/inst/extdata/textiles/` (the package names have the prefix `local_`, `global_` or `nominal_`).
Expected: either all 50 files match (use the simulation boxes, `source = simulation`), or not (go to Step 2). Write the result in the ledger.

- [ ] **Step 2: Draw the boxes when the files do not match**

For each of the 14 local inputs and the local reference, find the defect: the largest connected area where the image differs from a local median of its texture by more than a threshold, then a box around it, padded by 2 px. Look at each one; correct a box by hand when the area is wrong. `source = drawn`.

- [ ] **Step 3: Check the frame**

Draw each box on its image (from the package folder). Expected: each box sits on the visible defect.

### Task 2: Inputs fixed before any call, and the contact sheet for fmm

**Files:**
- Create: `box/scripts/d307_02_inputs.R`
- Create: `box/results/d307_textiles/inputs.json` (the reference crops as file names and pixel boxes, the two Box wordings, the score of the image decision of each strategy) and `box/results/d307_textiles/contact_sheet.png`

- [ ] **Step 1: Fix the inputs** as the spec says: the references of T are the two nominal references (as nominal crops, the tile size of T) and a square crop around the truth box of `local_textile_0471.jpg`, clamped to the image; the two Box wordings are "the defect" and one sentence for the textiles, written now; the score of the image decision is 1 minus P("none") of the tile Choice for T and the whole-image Noul for Z.

- [ ] **Step 2: Make the contact sheet**: the 14 local inputs and the local reference with their truth boxes, the reference crops, and the two wordings as text.

- [ ] **Step 3: Show it to fmm and wait.** fmm accepts or corrects the boxes and the wording. Record fmm's answer as a decision row (How `chat` or `question`), build check, record-only commit. No call before this step is done.

### Task 3: One run of T and Z, the measures and the gate

**Files:**
- Create: `box/scripts/d307_03_run.R` (reuses `d303_common.R`, `d303_live.R`, `d303_eval.R`) and `box/scripts/d307_04_results.R`
- Create: `box/results/d307_textiles/boxes.csv`, `image_scores.csv`, `summary.md`, `sheet.jpg`

- [ ] **Step 1: Check the cost first**: count the planned calls (T: 2 to 3 for each input; Z: 2 for each input; 46 inputs). Expected: at most 400 calls; the estimate in USD (input tokens times USD 0.042 per million) is below USD 0.10. Stop if not.

- [ ] **Step 2: Run** with `BOX_CALL_LOG` set and `BOX_MAX_CALLS=400`. Expected: no failed call; the purpose of each row starts with `box d307`.

- [ ] **Step 3: Measure** for each strategy: local inputs pointed (out of 14), IoU 0.3 and 0.5, the AUC of the image decision (23 nominal against 23 defective), boxes on nominal inputs, calls and USD for each image; and the share of local truth boxes that hold the image center (Review Focus 2).

- [ ] **Step 4: Apply the gate** (D312) and write `summary.md`: the table, the gate result in one line, the limits (one run; a rerun gives other boxes; 14 images).

- [ ] **Step 5: Record**: a decision row (How `measurement`, Evidence: the gate line of `summary.md`, quoted, at most 25 words) that says if Box passes; the summary of the calls in `calls/README.md` (as for D303); a process row (stage `evaluate`); build check; record-only commit and push. Commit `box/scripts/d307_*.R` and `summary.md` on `m7-box` (no push).
