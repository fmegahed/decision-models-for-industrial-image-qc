# Fair comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-run the comparison of JEV, Clef-Flash and CLIP with one shared label budget, a blind description loop, calibration of every method, all common metrics and paired tests. Then rewrite the analysis document around it.

**Architecture:** Small R helpers in `R/` (sets, metrics, runner, loop rules) and one script for each step in `scripts/fair_*.R`. Every output goes to `results/fair/`. Each score file has one schema, so one evaluation script reads JEV, Clef-Flash and CLIP alike. The paid and GPU steps are gated: Tasks 1 to 7 make no paid call, and Tasks 8 to 10 run only after the gates of fmm.

**Tech Stack:** R 4.6.1 (tidyverse, yardstick 1.4.0, testthat 3.3.2, httr2, magick, reticulate), Python 3.12 with OpenAI CLIP for CLIP, Quarto 1.9 for the analysis document.

**Spec:** `replication_materials/plans/2026-10-20-fair-comparison-design.md`, Part A (sections 1 to 9) and the order of work and git rules (section 11).

## Global Constraints

- Branch `fair-comparison` for code. Record-only commits go to `main` (push without asking). The branch merges `main` to get them.
- R style (D66): 80 to 90% tidyverse, native pipe `|>`, `pkg::fun()` calls with no `library()`, `stringr` for text, `yardstick` for metrics, simple code. Comments in the style of the existing scripts.
- Run every script from the repository root: `Rscript scripts/<name>.R`. Rscript: `C:/Program Files/R/R-4.6.1/bin/Rscript.exe`.
- Tests: `Rscript -e "testthat::test_dir('tests/testthat')"`. No test makes a paid call. To test a paid path, use `JEV_CHECK_ONLY=true`, or `R_ENVIRON_USER` that points to an empty file. Never blank the key: R reloads `.Renviron`.
- Never print, log or commit `TYPESAFE_API_KEY` or `JEV_API_KEY`. Never send the TypeSafe key to a non-TypeSafe URL.
- No paid JEV call before fmm approves the budget row of X17 in `replication_materials/calls/README.md`. Log each call in `replication_materials/calls/typesafe-calls.csv` through `JEV_CALL_LOG`.
- Seeds: references 202610, calibration set 202611, bootstrap 202612.
- Models: JEV `jev-1.13.0` at `https://api.typesafe.ai/v1/systemone`, image format `assets`. Clef-Flash `Cloudflare/clef-flash` at `http://localhost:30000/v1/systemone`, image format `images`. CLIP ViT-L/14 through `python/clip_functions.py`. All: crop `center`, `max_size` 768, `upscale` FALSE.
- Generic description: normal "No visible manufacturing defects; the part appears conforming."; defective "At least one visible manufacturing defect or anomaly."
- The test sets are one-time for each configuration. Do not change the v0.0.1 scripts or results; they reproduce tag `v0.0.1`.
- The test images and their results never go into the loop sandbox.
- Records and the log: 80% ASD-STE100.

## Review Focus

- A second calibration or test run of the same configuration: `scripts/fair_score.R` refuses, and the existing file stays unchanged. Task 3 tests it.
- A test run before the calibration run of the same configuration, or a `final` description that is not frozen yet: refuse. Task 3 tests it.
- A design-split run for pans, or with k other than 2: refuse. Task 3 tests it.
- The near-copy exclusion leaves fewer than 25 images in one class of C: C shrinks in both classes to stay balanced, and the draw report names the shortfall. Task 2 tests it.
- A candidate description with a comma, quotes, a `|` or a line break: the CSV keeps it, and the request sends it unchanged. Task 4 tests it.

---

### Task 1: Metrics, calibration and paired tests

**Files:**
- Create: `R/evaluation.R`
- Modify: `R/calibration_functions.R` (tidy style only; the same outputs)
- Test: `tests/testthat/test-evaluation.R`, `tests/testthat/test-calibration.R`

**Interfaces:**
- Produces: `class_metrics(data, threshold = 0.5)`. `data` has `actual_class` and `prob_defective`. It returns a one-row tibble: `accuracy`, `bal_accuracy`, `sens`, `spec`, `precision`, `f_meas`, `mcc`, `roc_auc`, `brier_class`, `mn_log_loss`, `ece`. The factor levels are `c("defective", "nominal")`, so the event is `defective`.
- Produces: `ece(prob, y, bins = 10)` (equal-width bins, as in `calibration_metrics()` now).
- Produces: `paired_bootstrap(a, b, metric, times = 2000, seed = 202612)`. `a` and `b` are prediction tibbles on the same images, in the same order. `metric` is `"bal_accuracy"`, `"mcc"` or `"roc_auc"`. It returns a tibble with `difference` (a minus b), `low` and `high` (95% percentile interval). Resamples are stratified by class.
- Produces: `mcnemar_exact(correct_a, correct_b)` returns the two-sided exact p-value from the discordant counts (`stats::binom.test`).
- Keeps: `platt()`, `isotonic()`, `tune_threshold()`, `calibration_metrics()` with the same results.

- [ ] **Step 1: Write the failing tests**

- `class_metrics()` on a fixed 10-row tibble with known counts (TP 4, FN 1, TN 3, FP 2) gives accuracy 0.7, sens 0.8, spec 0.6, precision 4/6, bal_accuracy 0.7.
- The event is defective: swap the factor order in the input and check that the result does not change.
- `mcnemar_exact()` with 8 and 2 discordant images gives p = 0.109375.
- `paired_bootstrap()` gives the same numbers twice with the same seed. For identical `a` and `b`, it gives difference 0 and an interval of [0, 0].
- `platt()` on perfectly separated scores gives finite outputs in (0, 1).
- `platt()`, `isotonic()` and `calibration_metrics()` give the same numbers as before on `results/final_test/microstructure_predictions.csv`. Save the old outputs in the test as fixed values.

- [ ] **Step 2: Run the tests to see them fail**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: FAIL (the functions do not exist).

- [ ] **Step 3: Implement `R/evaluation.R` and restyle `R/calibration_functions.R`**

Use a `yardstick::metric_set()` for the class metrics and the probability metrics. Write `ece()` by hand: yardstick has none.

- [ ] **Step 4: Run the tests to see them pass**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/evaluation.R R/calibration_functions.R tests/testthat
git commit -m "Add yardstick metrics and paired tests for the fair comparison"
```

### Task 2: Learning, calibration, reference and design sets

**Files:**
- Create: `R/image_hash.R` (the `dhash()` of `experiments/check_leakage.R`, with the same algorithm)
- Create: `R/fair_sets.R`
- Create: `scripts/fair_draw_sets.R`
- Test: `tests/testthat/test-fair-sets.R`
- Output: `results/fair/sets/learning.csv`, `calibration.csv`, `references.csv`, `design.csv`, `draw_report.csv`

**Interfaces:**
- Consumes: `results/image_split_manifest.csv`, `results/clip_paper/learning_sets.csv` (settings `pan_10`, `extrusion_50`, `textiles_50`, `pipe_staple_50`, `microstructure_50`).
- Produces: `draw_calibration(pool, n_per_class = 25, seed = 202611)`.
  - The defective images are stratified over the defect types in alphabetical order. Each type gets `floor(n / T)` images, and the first `n %% T` types get one more.
  - It returns the same number of images in both classes: the smaller class sets the size.
- Produces: `draw_references(learning, k_max = 4, seed = 202610)` returns one row for each reference, with `rank` 1 to 4 in each class.
  - Nominal: a seeded shuffle of the sorted paths.
  - Defective: the defect types in a seeded random order, one image for each type, round-robin.
  - The references at k are the rows with `rank <= k`.
- Produces: `near_copies(paths, others, max_distance = 6)` returns the paths with a dHash Hamming distance of 6 or less to any of `others`.
- Files: all of them have the columns `dataset, image_path, defect_type, actual_class`. `references.csv` adds `rank`. `design.csv` is the learning set minus the references at k = 2, for every dataset except pans.

- [ ] **Step 1: Write the failing tests**

On a toy manifest built in the test:
- C has 13 + 12 for a dataset with 2 types (alphabetical), and 3 x 7 + 2 x 2 for 9 types.
- When only 17 defective images are left, C is 17 + 17.
- When near-copies remove 2 nominal images from 25, C is 23 + 23, and the report has the row `shortfall`.
- The reference ranks are nested, and round-robin covers 2 types at k = 2 and 4 types at k = 4.
- Two draws with the same seed are identical.

On the real files, after the script runs:
- C does not meet L or the test set, by path or by MD5.
- All references are in L.
- `design.csv` is L minus the references at k = 2.
- The C counts are those of the design table, section 4.3, with fewer images only where the report names near-copies.

- [ ] **Step 2: Run the tests to see them fail**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: FAIL.

- [ ] **Step 3: Implement the helpers and `scripts/fair_draw_sets.R`**

- [ ] **Step 4: Run the script and the tests**

Run: `Rscript scripts/fair_draw_sets.R`, then the tests.
Expected: the script prints the counts for each dataset and class. All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add R/image_hash.R R/fair_sets.R scripts/fair_draw_sets.R tests/testthat results/fair/sets
git commit -m "Draw the shared learning, calibration, reference and design sets"
```

### Task 3: Scoring runner with guards

**Files:**
- Create: `R/fair_runner.R`
- Create: `scripts/fair_score.R`
- Test: `tests/testthat/test-fair-runner.R`

**Interfaces:**
- Consumes: the sets of Task 2, `R/industrial_defect_classifier.R` (`classify_image()`).
- Produces: `scripts/fair_score.R`, driven by environment variables:
  - `FAIR_MODEL`: `jev` or `clef`.
  - `FAIR_DATASET`.
  - `FAIR_DESCRIPTION`: `generic`, `final`, or the path of a candidate CSV with columns `normal, defective` (a path only with `FAIR_SPLIT=design`).
  - `FAIR_K`: 0, 1, 2 or 4.
  - `FAIR_SPLIT`: `design`, `calibration` or `test`.
  - `FAIR_OUT`: the output folder. The default is `results/fair/scores`; for the design split, it is the sandbox folder.
  - `JEV_CHECK_ONLY=true` runs the checks only.
- Produces: score files `<model>_<description>_k<k>_<dataset>_<split>.csv`. Columns: `dataset, image_path, defect_type, actual_class, prob_defective, model, description, k, split`.
- The images of each split: `design` is `design.csv`; `calibration` is `calibration.csv`, except for pans, where it is the images of L that are not references at the k of the run (design section 4.4); `test` is the test split of the manifest.
- Produces: `check_run(model, dataset, description, k, split, out)`. It stops with a clear message when:
  - the calibration or test file of the configuration already exists;
  - a test run has no calibration file of the same configuration;
  - `final` has no frozen file `results/fair/descriptions/<model>_<dataset>.csv`;
  - a design run is for pans, or its k is not 2;
  - a JEV run needs more calls than the budget row has left.
- Produces: `remaining_calls(purpose_prefix = "fair")`. It reads the max calls of the budget row whose Purpose starts with "Fair comparison" in `calls/README.md`, and subtracts the rows of `calls/typesafe-calls.csv` whose purpose starts with "fair".

- [ ] **Step 1: Write the failing tests**

Test `check_run()` and `remaining_calls()` as pure functions, with temp folders for `out` and a temp copy of the budget table:
- A second test run stops: `Test results already exist for jev_final_k2_extrusion. The test run is one-time.`
- A test run with no calibration file stops.
- A `final` run with no frozen description stops.
- A design run for `pan_images`, or with k = 4, stops.
- A JEV run of 50 images with 40 calls left stops.

Then run the script end to end with `JEV_CHECK_ONLY=true` for one configuration. It must print the checks, the number of images and the number of references, and then stop before any call.

- [ ] **Step 2: Run the tests to see them fail**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: FAIL.

- [ ] **Step 3: Implement**

Base the script on `scripts/evaluate_frozen.R`:
- the same key rule (the TypeSafe key only for the TypeSafe URL);
- the same reference/test MD5 check;
- the same `JEV_CALL_PURPOSE` and `JEV_CALL_LOG` use, with the purpose `fair <split> <model> <description> k<k> <dataset>`.

Write the output file only after all images are scored.

- [ ] **Step 4: Run the tests to see them pass**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`, and then the check-only run.
Expected: PASS, and the check-only run makes no call (the call log has no new row).

- [ ] **Step 5: Commit**

```bash
git add R/fair_runner.R scripts/fair_score.R tests/testthat
git commit -m "Add the scoring runner with one-time and budget guards"
```

### Task 4: Blind loop sandbox, keep rule, audit and freeze

**Files:**
- Create: `R/fair_loop.R`
- Create: `scripts/fair_make_sandbox.R`, `scripts/fair_close_loop.R`
- Create: `scripts/fair_loop_instructions.md` (the text that the loop agent reads; fmm approves it in Task 8)
- Test: `tests/testthat/test-fair-loop.R`

**Interfaces:**
- Consumes: `results/fair/sets/design.csv` and `references.csv`, and `scripts/fair_score.R` with `FAIR_SPLIT=design`.
- Produces: `scripts/fair_make_sandbox.R MODEL DATASET`. It makes `<FAIR_SANDBOX>/<model>-<dataset>/`. The default is `../fair-loop-sandbox`. It refuses a folder inside the repository. The folder holds:
  - `images/`: copies of the design images, with neutral names (`img_001.png` and so on);
  - `labels.csv`: `image, class, defect_type`;
  - `references/`: copies of the references at k = 2;
  - `generic_description.csv`;
  - `LOOP.md`: from `scripts/fair_loop_instructions.md`, filled in with the dataset name, the defect-type names and the scoring command;
  - `score.sh`: one command that runs `scripts/fair_score.R` from the repository root, with the design split, k = 2 and the candidate file. Its output goes into the sandbox.
- Produces: `apply_keep_rule(log)`. `log` has `candidate, auc` in order. It returns `kept` (TRUE/FALSE for each candidate) and `best` (the ID of the last kept candidate). Candidate 1 (generic) is always kept. A later candidate is kept when its AUC is at least 0.02 above the current best.
- Produces: the scorer refuses candidate 7 (at most 6, including the generic one).
- Produces: `loop_log.csv` in the sandbox: `candidate, time_utc, normal, defective, auc, mean_score_by_type, reason, kept`.
- Produces: `scripts/fair_close_loop.R MODEL DATASET TRANSCRIPT`. It:
  - copies `loop_log.csv` to `results/fair/loop/<model>-<dataset>_log.csv`;
  - writes the best candidate to `results/fair/descriptions/<model>_<dataset>.csv`, which freezes it;
  - writes `results/fair/loop/<model>-<dataset>_audit.csv`: every file path in a Read, Glob, Grep or Bash tool call of the agent transcript that is outside the sandbox, except the fixed scoring command.

- [ ] **Step 1: Write the failing tests**

- `apply_keep_rule()` on AUC 0.80, 0.81, 0.83, 0.82, 0.86 keeps candidates 1, 3 and 5. The best is 5.
- The sandbox has no file whose name or content holds `test`, `results/`, `calibration` or a test image path. Check its file list against the allowed list.
- The image count is 96, and the labels match `design.csv`.
- A candidate with a comma, quotes, `|` and a line break survives a write and a read of the CSV unchanged.
- The audit finds a planted `Read` of `results/final_test/x.csv` in a fake transcript, and it ignores the scoring command.

- [ ] **Step 2: Run the tests to see them fail**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: FAIL.

- [ ] **Step 3: Implement the helpers, the two scripts and the instructions**

The instructions follow `docs/GOAL.md` in style, with no dataset hypotheses (D74). They state:
- the goal (raise the AUC on the design images by changing only the two descriptions);
- the limit of 6 candidates;
- the keep rule;
- the files that the agent may read (the sandbox only);
- the log line to write for each candidate (the reason in one or two sentences);
- that the agent stops after candidate 6 or when it has no further idea.

- [ ] **Step 4: Run the tests to see them pass**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add R/fair_loop.R scripts/fair_make_sandbox.R scripts/fair_close_loop.R scripts/fair_loop_instructions.md tests/testthat
git commit -m "Add the blind description loop: sandbox, keep rule, audit and freeze"
```

### Task 5: CLIP variants

**Files:**
- Create: `scripts/fair_clip.R`
- Modify: `python/clip_functions.py` (add `clip_zero_scores_truncated()`; the old functions stay unchanged)
- Test: `tests/testthat/test-fair-clip.R` (skipped when `RETICULATE_PYTHON` is not set)

**Interfaces:**
- Consumes: the sets of Task 2, and `results/fair/descriptions/jev_<dataset>.csv` for the optional variant.
- Produces: score files in the schema of Task 3, with `model = "clip"`, `description` set to `baseline`, `refs`, `zero` or `zero_final`, and these `k` values:
  - baseline: k = 50 (pans: 10);
  - refs: k = 1, 2, 4;
  - zero-shot: k = 0.
- Calibration split: the scores on C. For pans:
  - the baseline uses leave-one-out on L, with the image itself and its MD5 twins set to `-Inf`, as `scripts/run_clip_paper_threshold.R` does;
  - refs uses the images of L that are not references;
  - zero-shot uses all of L.
- `FAIR_CLIP_TEXT=final` runs the `zero_final` variant only. It cuts each description at the 77 tokens of the CLIP text encoder (`clip.tokenize(..., truncate=True)`). It writes `results/fair/scores/clip_truncation.csv` with the dataset, the class and whether the text was cut.

- [ ] **Step 1: Write the failing tests**

- The baseline test scores equal `results/clip_paper/<setting>_test_predictions.csv` within 1e-5.
- Pans baseline leave-one-out: no image scores against itself or an MD5 twin.
- The row counts equal the set sizes.

- [ ] **Step 2: Run the tests to see them fail**

Run: `RETICULATE_PYTHON=C:/Users/megahefm/.conda-envs/imagejev-clip/python.exe Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: FAIL.

- [ ] **Step 3: Implement `scripts/fair_clip.R`**

Stop the Clef-Flash server first: two CUDA processes on one GPU made CLIP crash in v0.0.1.

- [ ] **Step 4: Run the script and the tests**

Run: `RETICULATE_PYTHON=... Rscript scripts/fair_clip.R`, then the tests.
Expected: PASS. No API call.

- [ ] **Step 5: Commit**

```bash
git add scripts/fair_clip.R python/clip_functions.py tests/testthat results/fair/scores/clip_*
git commit -m "Score the CLIP variants on the shared sets"
```

### Task 6: Evaluation

**Files:**
- Create: `scripts/fair_evaluate.R`
- Test: `tests/testthat/test-fair-evaluate.R`

**Interfaces:**
- Consumes: all score files, `R/evaluation.R`.
- Produces:
  - `results/fair/summary/metrics.csv`: `model, description, k, dataset, split, calibration, metric, value`. Calibration is `raw`, `platt` or `isotonic`; the decision is at 0.5 for each.
  - `results/fair/summary/paired.csv`: `comparison, model, dataset, metric, difference, low, high, mcnemar_p, holm_p`, for P1, P2 and P3.
  - `results/fair/summary/k_curve.csv`: `model, dataset, k, metric, value, difference_vs_k0, low, high`.
- Rules:
  - Platt and isotonic are fitted on the calibration file of the same configuration only.
  - P1 compares `<model>_final_k2` (pans: `generic_k2`) with `clip_baseline`, both Platt.
  - P2 compares `final_k2` with `generic_k2`, both Platt.
  - P3 compares `final_k2` with `final_k0`, both Platt.
  - Pans have no P2.
  - Holm adjusts the 14 McNemar p-values of each model together.

- [ ] **Step 1: Write the failing tests**

On synthetic score files in a temp folder:
- The metrics of a known configuration match hand-computed values.
- The calibration uses only the calibration file. Change the test file and check that the fitted parameters do not change.
- Each model has 14 Holm-adjusted p-values, and pans have no P2 row.
- The sign convention: P1 difference is the decision model minus CLIP.

- [ ] **Step 2: Run the tests to see them fail**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: FAIL.

- [ ] **Step 3: Implement `scripts/fair_evaluate.R`**

- [ ] **Step 4: Run the tests to see them pass**

Run: `Rscript -e "testthat::test_dir('tests/testthat')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fair_evaluate.R tests/testthat
git commit -m "Evaluate all configurations with calibration and paired tests"
```

### Task 7: Analysis document skeleton

**Files:**
- Modify: `beyond_clip_analysis.qmd` (the version of tag `v0.0.1` stays in git)
- Modify: `README.md` (structure and reproduction: the new scripts; the v0.0.1 scripts reproduce the tag)

**Interfaces:**
- Consumes: `results/fair/sets/*`, and the summaries of Task 6 when they exist.

- [ ] **Step 1: Restructure the document**

Use the order of design section 9. Write every chunk in the style of D66, and keep the figure and table style. Sections that need results read `results/fair/summary/` with `#| eval: !expr file.exists(...)`. Before the runs, those sections say: "Results appear after the runs of Task 10."

- [ ] **Step 2: Render**

Run: `QUARTO_R="C:/Program Files/R/R-4.6.1/bin" quarto render beyond_clip_analysis.qmd`
Expected: the render completes. The data, methods and label-budget sections show the counts of Task 2. A cleanup error about the Dropbox lock on `beyond_clip_analysis_files` after the HTML is written is harmless.

- [ ] **Step 3: Commit**

```bash
git add beyond_clip_analysis.qmd README.md
git commit -m "Restructure the analysis document for the fair comparison"
```

### Task 7b: Execution time (design section 14, D78)

**Files:**
- Modify: `R/fair_runner.R`, `scripts/fair_score.R`, `R/fair_loop.R` (if it writes score files), `scripts/fair_clip.R` or a new `scripts/fair_clip_timing.R`, `R/fair_evaluate.R`, `scripts/fair_evaluate.R`, `beyond_clip_analysis.qmd`
- Test: `tests/testthat/test-fair-runner.R`, `tests/testthat/test-fair-evaluate.R`, and a test for the CLIP timing (skipped without RETICULATE_PYTHON)

**Interfaces:**
- Produces: an `elapsed_ms` column in every new decision-model score file (design, calibration and test); `results/fair/timing/runs.csv` (model, description, k, dataset, split, n_images, start_utc, end_utc, seconds, hardware); `results/fair/timing/clef-calls.csv` for Clef-Flash calls; `results/fair/timing/clip_timing.csv` (variant, k, dataset, image_path, encode_ms, score_ms); `results/fair/summary/timing.csv` (model, description, k, dataset, split, median_ms, q25_ms, q75_ms, n_images, total_seconds).
- Changes: `JEV_CALL_LOG` is set to the TypeSafe call log only for JEV runs; Clef-Flash runs log to `results/fair/timing/clef-calls.csv`; `remaining_calls()` counts only rows whose model is `jev-1.13.0` and whose purpose starts with "fair".

- [ ] **Step 1: Write the failing tests**

- A stubbed scoring run writes `elapsed_ms` (non-negative) for each image and one row to runs.csv.
- A Clef-Flash run never writes to the TypeSafe call log, and `remaining_calls()` ignores Clef-Flash rows.
- The evaluation reads score files with and without `elapsed_ms` (the CLIP files have none) and writes timing.csv.

- [ ] **Step 2: Run the tests to see them fail**

- [ ] **Step 3: Implement**, then run the CLIP timing on the local GPU (no API call).

- [ ] **Step 4: Run the full test suite and render the document**

- [ ] **Step 5: Commit**

### Task 8: Gates before any paid call (controller with fmm)

This task needs fmm. A subagent does not do it.

- [ ] **Step 1: Loop instructions**

Show fmm `scripts/fair_loop_instructions.md` as it will appear in `LOOP.md`. Record the approval as a decision row (How `plan-approval`).

- [ ] **Step 2: Budget row**

Propose the row "Fair comparison: description loops, calibration and test runs (design X17)": max calls 10,500, max cost USD 3. Write it in `calls/README.md` only after fmm approves it, with Approved by `fmm`. Record a decision row. This is a record-only commit.

- [ ] **Step 3: Nine-image check**

Make one JEV call and one Clef-Flash call at k = 4 on one design image, with the call log. Expected: both return a defect probability. If Clef-Flash refuses 9 images, record that its curve stops at k = 2 (design section 5.6).

### Task 9: Description loops (controller)

- [ ] **Step 1: Make the sandboxes**

Run `Rscript scripts/fair_make_sandbox.R <model> <dataset>` for jev and clef, for extrusion, textiles, pipe_staple and microstructure.

- [ ] **Step 2: Run the loops**

For each model, dispatch one fresh agent. Give it only the sandbox path and the order "Read LOOP.md and follow it." Its working folder is the sandbox. It works through the four datasets in turn. The Clef-Flash server must run for the clef agent, and CLIP must not run at the same time.

- [ ] **Step 3: Close the loops**

For each model and dataset, run `Rscript scripts/fair_close_loop.R <model> <dataset> <transcript>`. If an audit file has a row, stop and tell fmm before any further run.

- [ ] **Step 4: Record**

Add a section to `experiment_log.md`: the candidates, their AUC and the final descriptions. Add one decision row for each model ("freeze the descriptions of the loop", How `measurement`, Evidence `results/fair/loop/`). Add a process row.

### Task 10: Calibration and test runs (controller)

- [ ] **Step 1: Calibration runs**

For each configuration of design section 5.6, run `FAIR_SPLIT=calibration Rscript scripts/fair_score.R`. Run CLIP `scripts/fair_clip.R` (Task 5), with the `zero_final` variant now that the descriptions are frozen.

- [ ] **Step 2: Ask fmm before the test runs**

Show the calibration results (AUC on C, from `scripts/fair_evaluate.R`). The test runs start only after fmm says yes. Record the decision.

- [ ] **Step 3: Test runs**

For each configuration, run `FAIR_SPLIT=test Rscript scripts/fair_score.R` once. Then run `Rscript scripts/fair_evaluate.R`.

- [ ] **Step 4: Record**

- Add the test results to `experiment_log.md`.
- Add the headline results to `replication_materials/project/results.md` (Release `-` until the tag), each with its Source file.
- Log the call totals in `calls/README.md`.

### Task 11: Document, merge and tag

- [ ] **Step 1: Finish the analysis document**

Render it with the results. Check every number in the text against `results/fair/summary/`.

- [ ] **Step 2: Pull request**

Merge `main` into the branch. Open a pull request from `fair-comparison` to `main`. Ask fmm before the merge.

- [ ] **Step 3: Tag and record**

After the merge, tag `v0.1.0` on `main` and push the tag, with the consent of fmm. Add the row `v0.1.0` to `releases.md`, and set the Release of the new results. The check of D75 must be done before this tag.
