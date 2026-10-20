# decisionqc design

Status: DRAFT for discussion, 2026-10-20. Nothing is built yet.

This document maps each step of the JEV image-inspection experiment to a function of the package and to a section of the paper. The roxygen2 blocks follow the style of `industrial_defect_classifier.R`: a title line, `@param` lines with backticks for values, `@return`, `@details` when needed, `@export`. The code uses `pkg::fun()`, the native pipe and httr2.

## 1. Workflow

| Step | What we did | Package function | Paper section |
|---|---|---|---|
| 1. Data | Read the folders into one manifest; one test partition per dataset | `image_manifest()`, `split_images()` | 3.1 Data |
| 2. Audit | Find exact and near duplicates across splits (MD5, gray thumbnails) | `check_leakage()` | 3.2 Data audit |
| 3. Validation | Draw a fixed validation set once; never redraw it | `freeze_validation()` | 3.3 Protocol |
| 4. Trials | Change one setting at a time; score each trial on validation | `jev_criteria()`, `select_references()`, `classify_images()`, `run_trial()`, `compare_trials()` | 3.3 Protocol |
| 5. Decision | Keep a change by AUC (+0.02), with a ceiling exception | `keep_change()` | 3.4 Decision rule |
| 6. Threshold and calibration | Tune the threshold last, or calibrate (Platt or isotonic) on validation | `tune_threshold()`, `calibrate()`, `calibration_metrics()` | 3.5 Calibration |
| 7. Test | Freeze the configuration; one guarded pass on the test set | `freeze_config()`, `evaluate_frozen()` | 3.6 Evaluation |
| 8. Report | Progress chart, reliability diagram, comparison tables | `plot_progress()`, `plot_reliability()` | 4 Results |

Two research goals of the package need functions that the experiment did not have yet:

- Sample size (goal b): `validation_size()` gives the images per class for a target standard error of AUC or BA. The few-shot question (how many references) is a set of `run_trial()` calls with nested reference sets from `select_references()`.
- Simulated data (goal c): the simulated textiles come from the R textile package. A wrapper, `simulate_textiles()`, can make a new dataset with known defect types.

## 2. API

### Data and partitions

```r
#' Read an image folder into a manifest
#' @param image_dir Folder with one subfolder per defect type.
#' @param nominal_folders Names of the subfolders that hold nominal images.
#' @param dataset Name of the dataset, used in every later file.
#' @return Tibble with `dataset`, `image_name`, `image_path`, `defect_type`, and
#'   `actual_class` (`"nominal"` or `"defective"`). Paths are relative to the project.
#' @export
image_manifest <- function(image_dir, nominal_folders, dataset) { ... }

#' Hold out a fixed test partition
#' @param manifest Tibble from [image_manifest()].
#' @param test_counts Named integer vector: test images per `defect_type`.
#' @param method `"random"` (seeded, per defect type) or `"last"` (the last
#'   images in sorted order, as for AutoVI pipe staple).
#' @param seed Seed for `"random"`.
#' @return The manifest with a `split` column (`"test"` or `"pool"`).
#' @details The partition is written once. Later calls read it and stop if the
#'   image files changed.
#' @export
split_images <- function(manifest, test_counts, method = c("random", "last"), seed = 202610L) { ... }

#' Find duplicate images across splits
#' @param manifest Tibble with a `split` column.
#' @param method `"md5"` for identical files, `"thumbnail"` for near
#'   duplicates (48 x 48 gray thumbnails, mean absolute difference).
#' @param references Optional reference paths to check against the test split.
#' @return Tibble of flagged pairs with their distance. Zero rows means no leak.
#' @details A path check is not enough: in our pan data, copies had other names.
#' @export
check_leakage <- function(manifest, method = c("md5", "thumbnail"), references = NULL) { ... }

#' Draw a fixed validation set once
#' @param manifest Tibble with a `split` column.
#' @param n_per_class Images per class (`"nominal"`, `"defective"`).
#' @param path CSV file that keeps the set. If it exists, it is read, not redrawn.
#' @param exclude Paths that may not be used (for example, references).
#' @return Tibble of validation images.
#' @export
freeze_validation <- function(manifest, n_per_class = 50L, path, exclude = character(), seed = 202610L) { ... }
```

### JEV calls

```r
#' Define the normal and defective criteria
#' @param normal Text that describes a conforming part.
#' @param defective Text that describes the defect and its visual cue.
#' @return A `jev_criteria` object for [classify_image()].
#' @details In our experiment, text that names the visual cue gave the largest
#'   gains (microstructure AUC 0.80 to 0.97).
#' @export
jev_criteria <- function(normal, defective) { ... }

#' Select reference images, one per defect type if needed
#' @param pool Tibble of non-test, non-validation images.
#' @param n_nominal Number of nominal references.
#' @param defect_types Defect types with one reference each, or `NULL` for
#'   `n_defective` images from all defect types.
#' @param seed Seed for a full, nested ordering: more references keep the
#'   earlier ones.
#' @return Named list with `normal` and `defective` paths.
#' @export
select_references <- function(pool, n_nominal = 1L, defect_types = NULL, n_defective = 1L, seed = 202610L) { ... }

#' Classify an industrial inspection image with JEV
#' @param image_path Image to classify.
#' @param criteria A [jev_criteria()] object, or `NULL` for generic criteria.
#' @param reference_images Optional list from [select_references()].
#' @param crop `"none"` or `"center"`.
#' @param max_size Longest side in pixels (280 to 1568).
#' @param upscale If `TRUE`, enlarge small images to `max_size`.
#' @param model Pinned model identifier. `"jev-latest"` can change without notice.
#' @param base_url SystemOne endpoint. Use a local URL for a self-hosted,
#'   compatible model such as Clef-Flash.
#' @param api_key TypeSafe API key (defaults to `TYPESAFE_API_KEY`).
#' @return One-row tibble: `image`, `prob_defective`, `model` (as returned by
#'   the API), and `input_tokens`.
#' @export
classify_image <- function(image_path, criteria = NULL, reference_images = NULL,
                           crop = c("center", "none"), max_size = 768L, upscale = FALSE,
                           model = "jev-1.13.0",
                           base_url = "https://api.typesafe.ai/v1/systemone",
                           api_key = Sys.getenv("TYPESAFE_API_KEY")) { ... }

#' Classify many images, one call at a time
#' @param images Tibble with `image_path` (and labels, which are kept).
#' @param ... Passed to [classify_image()].
#' @return The input tibble with `prob_defective`, `model`, and `input_tokens`.
#' @details Stops at the first failed call and keeps the error. It never drops
#'   a failure or scores it as wrong.
#' @export
classify_images <- function(images, ...) { ... }
```

### Trials and decisions

```r
#' Run one validation trial
#' @param validation Tibble from [freeze_validation()].
#' @param trial_id Unique name; an existing trial is never overwritten.
#' @param dir Folder for `<trial_id>_predictions.csv` and `<trial_id>_score.csv`.
#' @param ... Settings passed to [classify_images()].
#' @return The score tibble (BA, sensitivity, specificity, AUC, settings).
#' @export
run_trial <- function(validation, trial_id, dir, threshold = 0.5, ...) { ... }

#' Compare trials on the same validation images
#' @param trials Named list of prediction tibbles.
#' @return List with accuracy per defect type and the images that flipped
#'   between the first and the last trial.
#' @export
compare_trials <- function(trials) { ... }

#' Decide whether to keep a change
#' @param candidate,current Score tibbles from [run_trial()].
#' @param min_gain Smallest AUC gain to keep a change (repeat runs moved AUC
#'   by less than 0.01).
#' @param ceiling If `current` AUC is above this value, compare BA at tuned
#'   thresholds instead, because AUC cannot rise by `min_gain`.
#' @return `"kept"` or `"discarded"`, with the reason as an attribute.
#' @export
keep_change <- function(candidate, current, min_gain = 0.02, ceiling = 0.98) { ... }
```

### Threshold and calibration

```r
#' Tune a decision threshold on validation
#' @param prob Defect probabilities.
#' @param truth `"defective"` or `"nominal"`.
#' @param digits Grid precision. JEV scores have 2 decimals, so use an exact
#'   2-decimal grid (`seq()` alone drifts: 0.41 becomes 0.41000000000000003).
#' @return The midpoint of the widest run of thresholds with the maximum BA.
#' @export
tune_threshold <- function(prob, truth, digits = 2L) { ... }

#' Fit a calibrator on validation probabilities
#' @param prob,truth Validation probabilities and labels.
#' @param method `"platt"` (logistic on logit(p) with Platt's soft targets) or
#'   `"isotonic"` (pool-adjacent-violators).
#' @return A `jev_calibrator` object; use [predict()] on new probabilities.
#' @details In our test sets, isotonic had a lower calibration error for 3 of 5
#'   datasets and needed fewer validation images (about 10 per class); Platt
#'   had a lower log loss for extrusion. After calibration, a 0.5 cutoff
#'   matched the tuned thresholds. Calibration does not transfer to a new
#'   image domain.
#' @export
calibrate <- function(prob, truth, method = c("isotonic", "platt")) { ... }

#' Measure calibration
#' @return Tibble with Brier score, expected calibration error (10 bins), log
#'   loss, and mean probability minus the defect rate.
#' @export
calibration_metrics <- function(prob, truth, bins = 10L) { ... }
```

### Evaluation, sample size and plots

```r
#' Freeze a configuration for the test run
#' @param source_trial The validation trial that chose the configuration.
#' @return One row for `frozen_configs.csv`, checked against the source trial.
#' @export
freeze_config <- function(dataset, source_trial, dir, condition = "references") { ... }

#' Evaluate a frozen configuration once on the test set
#' @details Reads the settings only from the frozen row. Refuses to run if the
#'   row differs from its source trial, if a reference is a test image (path or
#'   MD5), or if test results already exist.
#' @export
evaluate_frozen <- function(config, manifest, out_dir, check_only = FALSE) { ... }

#' Images per class for a target standard error
#' @param auc Expected AUC (Hanley-McNeil standard error), or `NULL` to use BA.
#' @param se Target standard error.
#' @return Images per class.
#' @export
validation_size <- function(se = 0.03, auc = NULL, ba = 0.85) { ... }

#' Plot validation progress, one panel per dataset
#' @export
plot_progress <- function(log, scores) { ... }

#' Plot a reliability diagram
#' @export
plot_reliability <- function(prob, truth, calibrators = NULL) { ... }
```

### Package files

- `DESCRIPTION`. Imports: httr2, magick, base64enc, tibble, purrr, dplyr, readr, tools. Suggests: ggplot2, testthat, reticulate (CLIP baseline only).
- `R/`: one file per section above: `data.R`, `classify.R`, `trials.R`, `calibrate.R`, `evaluate.R`, `plots.R`.
- `tests/testthat/`: httr2 mocked responses (`httr2::local_mocked_responses()`), so tests make no paid calls. Test the guards: overwrite refusal, leakage stops, exact threshold grid, calibrators on separated data.
- `vignettes/`: one worked example (simulated textiles: fast and free of licenses), one for the full protocol.
- Data: the image sets are not shipped. AutoVI (pipe staple) is CC BY-NC-SA 4.0. The package downloads or points to them.

## 3. Paper outline

1. Introduction: few-shot image inspection; why calibrated probabilities matter in quality control.
2. Background: JEV and the SystemOne API; the CLIP baseline (Megahed et al., 2026).
3. Methods
   1. Data: five datasets; test partitions matched to the CLIP paper.
   2. Data audit: exact and near duplicates; the pan cleanup.
   3. Protocol: fixed validation, one change per trial, repeat runs for API noise.
   4. Decision rule: AUC with a minimum gain; ceiling exception.
   5. Calibration: Platt and isotonic, fitted on validation.
   6. Evaluation: frozen configurations, one guarded test pass; ablations (zero-shot JEV); baselines (CLIP with the same references; CLIP with the paper's learning sets).
4. Results: progress chart; test table; zero-shot ablation; calibration (reliability diagram, bootstrap intervals); CLIP comparisons; cost (tokens, USD).
5. Discussion: text criteria give the largest gains; references improve ranking; calibration replaces threshold tuning; limits of transfer (real textiles, dropped).
6. Limitations: 50 validation images per class; model versions; class balance (the probabilities are calibrated at 50% defects); simulated data.
7. Reproducibility: the replication record and the package.

## References

Megahed, F. M., Chen, Y.-J., Colosimo, B. M., Grasso, M., Jones-Farmer, L. A., Knoth, S., Sun, H., & Zwetsloot, I. M. (2026). Adapting OpenAI's CLIP model for few-shot image inspection in manufacturing quality control: An expository case study with multiple application examples. *Journal of Quality Technology, 58*(4), 415–441. https://doi.org/10.1080/00224065.2026.2640171
