# Beyond CLIP: Calibrated (Few-Shot) Defect Detection With Structured Decision Models

Fadel M. Megahed ([fmegahed](https://github.com/fmegahed)) and Ying-Ju (Tessa) Chen ([ying-ju](https://github.com/ying-ju))

Status: ongoing work. An abstract is submitted to MSEC 2027 (`paper/msec2027_submitted.md`). An R package, `decisionqc`, is in design (`docs/decisionqc_design.md`).

Analysis: [all paper tables and figures, with their code](https://fmegahed.github.io/decision-models-for-industrial-image-qc/pages/beyond_clip_analysis.html) (`beyond_clip_analysis.html`, rendered from `beyond_clip_analysis.qmd`). Replication record: [website](https://fmegahed.github.io/decision-models-for-industrial-image-qc/).

## Objective

Can structured decision models, which return a probability for each allowed answer to a question about an image, (a) detect manufacturing defects as well as few-shot CLIP with fewer labeled examples, and (b) give calibrated class probabilities?

The fair comparison (branch `fair-comparison`, design in `replication_materials/plans/2026-10-20-fair-comparison-design.md`) gives every method the same labeled images:

1. Audit the images for duplicates across data splits.
2. Draw the sets: a learning set L (the CLIP baseline set, 50 images per class; pans 10), k reference images per class from L, and a calibration set C (25 images per class) that excludes near-copies of L and test images.
3. Find a better defect description with a blind loop: a fresh Claude Code agent changes only the two description texts and keeps a change when the ROC AUC on the images of L that are not references rises by at least 0.02.
4. Calibrate every method (JEV, Clef-Flash and CLIP) with Platt scaling on C, and decide at 0.5.
5. Score each configuration once on the test images, and compare the methods with paired tests on the same images.

## Results (v0.0.1)

The table below gives the results of the first version, tag [`v0.0.1`](https://github.com/fmegahed/decision-models-for-industrial-image-qc/tree/v0.0.1). The fair comparison replaces them: its results appear in the analysis document after the decision-model runs. Section "v0.0.1" of the analysis document lists the five weak points of v0.0.1 and what changed.

Balanced accuracy at a threshold chosen on validation. JEV is the hosted TypeSafe model (`jev-1.13.0`); Clef-Flash is an open-weight 9B model run locally. CLIP is ViT-L/14.

| Dataset | Test images | JEV, 2 to 4 references | JEV, no references | Clef-Flash, same references | Clef-Flash, no references | CLIP, same references | CLIP baseline: paper rule / tuned threshold | CLIP, learning sets of the CLIP paper: paper rule / tuned threshold |
|---|---|---|---|---|---|---|---|---|
| Microstructure | 450 | 0.92 | 0.88 | 0.81 | 0.84 | 0.92 | 0.84 / 0.92 (50 + 50) | 0.85 / 0.96 (72 + 72) |
| Textiles (simulated) | 200 | 0.86 | 0.73 | 0.85 | 0.71 | 0.81 | 0.98 / 0.98 (50 + 50) | 0.98 / 0.98 (50 + 50) |
| Extrusion | 200 | 0.73 | 0.69 | 0.68 | 0.61 | 0.50 | 0.70 / 0.73 (50 + 50) | 0.82 / 0.83 (350 + 350) |
| Pipe staple (AutoVI) | 100 | 0.98 | 0.96 | 0.99 | 0.90 | 0.61 | 0.57 / 0.57 (50 + 50) | 0.57 / 0.57 (50 + 50) |
| Metallic pans | 78 | 1.00 | 0.96 | 0.92 | 0.72 | 0.94 | 0.91 / 0.64 (10 + 10) | 0.91 / 0.64 (10 + 10) |

The CLIP baseline learns from 50 images per class (10 for pans), the low end of the 50 to 100 per class in the abstract of the CLIP paper; the defect images are split evenly over the defect types. It needs about as many labeled images as JEV with references plus validation (about 100). The tuned CLIP threshold comes from leave-one-out scores of the learning set, because the CLIP learning sets hold most of our validation images (`scripts/run_clip_paper_threshold.R`). For pans, near-identical learning photos make the leave-one-out scores too optimistic, so the tuned threshold is worse than the rule of the paper.

Raw JEV probabilities are not calibrated (expected calibration error 0.11 to 0.23). Isotonic regression fitted on validation reduces it to 0.01 to 0.04 on four of the five datasets. Test balanced accuracy settled with about 10 to 20 validation images per class; the calibration error kept falling with more. Details: `experiment_log.md` and the analysis page.

## Structure

| Path | Contents |
|---|---|
| `beyond_clip_analysis.qmd` | The replication document of the fair comparison: data, methods, description loop, main results, paired comparisons, reference curve, calibration, a short v0.0.1 section, appendix and re-run steps. It makes every table and figure of the paper from the saved results; switches re-run the paid and GPU steps |
| `beyond_clip_analysis.html` | The rendered document (self-contained), for readers who do not run it; also on the record website |
| `figs/` | Figures of the document: F1 reference images (k = 2), F2 description loop, F3 to F5 paired comparisons P1 to P3, F6 reference curve, F7 reliability diagrams. Each as PNG, PDF and SVG, in one-column and two-column sizes. F2 to F5 appear after the decision-model runs |
| `tables/` | Tables of the document (CSV and LaTeX): T1 sets, T2 label budget, T3 calibration draw, T4 description loop, T5 main results, T6 paired comparisons, T7 calibration; appendix A1 isotonic calibration, A2 loop candidates, A3 CLIP variants. T4, T6 and A2 appear after the decision-model runs. `T4_test_results_long.csv` and `validation_size.csv` are v0.0.1 outputs: they stay because the replication record (results H6 to H8) names them as sources |
| `fonts/` | Outfit and Cabin (SIL Open Font License), used by the figures |
| `references.bib`, `apa.csl` | References of the document, in APA style |
| `replication_materials/` | The replication record: decisions, process, plans, releases, results and paid-call budget (website above) |
| `experiment_log.md` | The lab notebook: setup notes, every v0.0.1 trial (60), decisions and rule changes, and the final-test sections |
| `R/` | Shared R functions: the JEV/SystemOne client (`industrial_defect_classifier.R`), calibration (`calibration_functions.R`), metrics and paired tests (`evaluation.R`), and the fair comparison: sets (`fair_sets.R`, `image_hash.R`), scoring runner and guards (`fair_runner.R`), blind loop (`fair_loop.R`), CLIP leave-one-out (`fair_clip.R`) and evaluation (`fair_evaluate.R`) |
| `scripts/` | Runnable steps (run from the repository root; see below). `fair_*.R` make the fair comparison; the other scripts reproduce tag `v0.0.1` |
| `tests/testthat/` | Tests of the R functions and of the guards of the fair comparison (no paid call) |
| `python/` | CLIP functions (from the CLIP qmd of the prior study) |
| `experiments/` | Inputs chosen during the v0.0.1 tuning (criteria and reference sets) and one-time data scripts (leakage check, duplicate removal) |
| `results/` | Split manifest; `fair/`: the sets, score files, loop logs, frozen descriptions and summaries of the fair comparison; v0.0.1: reference manifests, trial outputs (`optimization/`), frozen configurations, test results (`final_test/`) and CLIP results (`clip/`, `clip_paper/`) |
| `paper/` | MSEC 2027 abstract (v0.0.1 results): draft and submitted versions, with the source of each number |
| `docs/` | The original task (`GOAL.md`) and the draft design of the `decisionqc` package |
| `archive/` | The first analysis script, kept for the record |

## Data

The images are not in this repository. Copy the folders of [fmegahed/qe_genai/data](https://github.com/fmegahed/qe_genai/tree/main/data) into `imgs/` (same folder names: `extrusion_images`, `microstructure`, `pan_images`, `pipe_staple`, `textile_images`).

- `results/image_split_manifest.csv` lists exactly the images used and their split. The scripts stop if an image is missing.
- Two cleanups differ from a fresh copy: duplicate pan test images were removed (the `qe_genai` test folder already matches), and 3 extrusion frames that were byte-identical copies of test frames were removed from the non-test pool. Extra files in `imgs/` are not used.
- The pipe staple images are from the Automotive Visual Inspection Dataset (AutoVI; Carvalho et al., 2024), CC BY-NC-SA 4.0. For the other datasets, see Megahed et al. (2026).

## Reproduction

Requirements: R 4.6.1 with httr2, magick, base64enc, tibble, purrr, dplyr, tidyr, readr, stringr, withr, yardstick, ggplot2 and testthat. Run every script from the repository root.

- Exact R package versions: `renv.lock` (renv 1.2.3; 103 CRAN packages with their dependencies). To install them in a project library: `install.packages("renv")`, then `renv::restore()` and choose to activate the project. The lockfile records the versions only: this repository does not activate renv. The Python versions for CLIP are in `results/clip/python_environment.txt`.
- All tables and figures of the paper: `quarto render beyond_clip_analysis.qmd` (Quarto 1.9; the first chunk installs the missing R packages). It reads the saved results in `results/fair/`, needs `imgs/`, makes no API call, and takes a few minutes. Its switches (`run_evaluate`, `run_clip`, `run_clef`, `run_jev`) re-run steps into `results/rerun/fair/`, and a second render with `use_rerun <- TRUE` builds every table and figure from the re-run; section "Re-run steps" of the document lists all steps.
- Tests, no paid call: `Rscript -e "testthat::test_dir('tests/testthat')"`.

Fair comparison (scripts `scripts/fair_*.R`, in this order):

1. Sets, no cost: `Rscript scripts/fair_draw_sets.R`. It draws L, C, the references and the design images into `results/fair/sets/` (seeds 202610 and 202611), with the near-copy rule of each dataset.
2. CLIP variants (local GPU): `RETICULATE_PYTHON=<env>/python.exe Rscript scripts/fair_clip.R`. It needs a Python 3.12 environment with torch 2.8.0 and OpenAI CLIP (versions in `results/clip/python_environment.txt`). After the loops, `FAIR_CLIP_TEXT=final` adds CLIP zero-shot with the final descriptions. Stop the Clef-Flash server first: two CUDA processes on one GPU made a CLIP run crash.
3. Description loops: `Rscript scripts/fair_make_sandbox.R <model> <dataset>` makes the sandbox, a fresh Claude Code agent runs the loop in it (instructions: `scripts/fair_loop_instructions.md`), and `Rscript scripts/fair_close_loop.R <model> <dataset> <transcript>` audits the transcript and freezes the description. **Paid** for JEV (up to 576 calls per dataset); local GPU for Clef-Flash.
4. Calibration and test runs: `FAIR_MODEL=<jev or clef> FAIR_DATASET=<dataset> FAIR_DESCRIPTION=<final or generic> FAIR_K=<0, 1, 2 or 4> FAIR_SPLIT=calibration Rscript scripts/fair_score.R`, then the same with `FAIR_SPLIT=test`. Each run is one-time. `JEV_CHECK_ONLY=true` runs the checks only. **Paid** for JEV; local GPU for Clef-Flash.
5. Evaluation, no cost: `Rscript scripts/fair_evaluate.R` writes `metrics.csv`, `paired.csv` and `k_curve.csv` to `results/fair/summary/`.

- JEV (paid API): put `TYPESAFE_API_KEY=...` in a `.Renviron` file at the root. Never commit it. A paid run needs a budget row in `replication_materials/calls/README.md`; each call goes to `replication_materials/calls/typesafe-calls.csv`.
- Clef-Flash (local GPU, about 25 GB): `docker run --gpus all -p 30000:30000 lmsysorg/sglang:dev-clef sglang serve --model-path Cloudflare/clef-flash --host 0.0.0.0 --port 30000`. Its server ignores the TypeSafe `assets` field, so images go as an ordered list (`image_format = "images"`).

v0.0.1: the other scripts reproduce tag [`v0.0.1`](https://github.com/fmegahed/decision-models-for-industrial-image-qc/tree/v0.0.1); the analysis document of that tag calls them.

- Validation trial: `JEV_DATASET=microstructure JEV_TRIAL=<name> Rscript scripts/optimize_jev.R` (settings in the script header).
- Threshold trial, no API calls: `scripts/rescore_threshold.R`. Progress chart: `scripts/plot_progress.R`.
- One-time test of a frozen configuration: `JEV_DATASET=<dataset> Rscript scripts/evaluate_frozen.R` (`JEV_CHECK_ONLY=true` runs the checks only).
- Summaries, no API calls: `scripts/summarize_final.R`, `scripts/calibration.R`, `scripts/validation_size.R`, `scripts/compare_methods.R`.
- CLIP (local GPU): `scripts/run_clip.R`, `scripts/run_clip_paper.R` and `scripts/run_clip_paper_threshold.R`.
- Clef-Flash: run the scripts with `JEV_BASE_URL=http://localhost:30000/v1/systemone JEV_MODEL=Cloudflare/clef-flash JEV_IMAGE_FORMAT=images`.

## References

Carvalho, P., Lafou, M., Durupt, A., Leblanc, A., & Grandvalet, Y. (2024). *The Automotive Visual Inspection Dataset (AutoVI): A genuine industrial production dataset for unsupervised anomaly detection* [Data set]. Zenodo. https://doi.org/10.5281/zenodo.10459003

Megahed, F. M., Chen, Y.-J., Colosimo, B. M., Grasso, M., Jones-Farmer, L. A., Knoth, S., Sun, H., & Zwetsloot, I. M. (2026). Adapting OpenAI's CLIP model for few-shot image inspection in manufacturing quality control: An expository case study with multiple application examples. *Journal of Quality Technology, 58*(4), 415–441. https://doi.org/10.1080/00224065.2026.2640171 (Open access, CC BY 4.0. Preprint: https://arxiv.org/abs/2501.12596.)

The notebook of Megahed et al. (2026): [image_inspection_with_clip.ipynb](https://github.com/fmegahed/qe_genai/blob/main/notebook/image_inspection_with_clip.ipynb).

## License

MIT for the code and documents in this repository (see `LICENSE`). The image folders are not included; each dataset keeps its own license.

Figure F1 (`figs/*/F1_reference_images.*`) and `beyond_clip_analysis.html` show the reference images. The pipe staple images in them are from AutoVI (Carvalho et al., 2024) and stay under CC BY-NC-SA 4.0: attribution, non-commercial use only, and adaptations under the same license. The other images are from the data of Megahed et al. (2026).
