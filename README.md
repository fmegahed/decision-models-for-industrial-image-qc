# Beyond CLIP: Calibrated Few-Shot Defect Detection With Structured Decision Models

Fadel M. Megahed ([fmegahed](https://github.com/fmegahed)) and Ying-Ju (Tessa) Chen ([ying-ju](https://github.com/ying-ju))

Status: ongoing work. An abstract is submitted to MSEC 2027 (`paper/msec2027_submitted.md`). An R package, `decisionqc`, is in design (`docs/decisionqc_design.md`).

## What this study asks

Can structured decision models, which return a probability for each allowed answer to a question about an image, (a) detect manufacturing defects as well as few-shot CLIP with fewer labeled examples, and (b) give calibrated class probabilities?

The study uses a five-stage framework:

1. Audit the images for duplicates across data splits.
2. Specify the task with explicit defect criteria and a few reference images.
3. Refine the criteria and references on a fixed validation set, one change at a time, by ROC AUC.
4. Calibrate the probabilities on the validation set (Platt scaling or isotonic regression).
5. Freeze the configuration and evaluate it once on held-out test images.

## Main results (test sets)

Balanced accuracy at a threshold chosen on validation. JEV is the hosted TypeSafe model (`jev-1.13.0`); Clef-Flash is an open-weight 9B model run locally. CLIP is ViT-L/14.

| Dataset | Test images | JEV, 2 to 4 references | JEV, no references | Clef-Flash, same references | CLIP, same references | CLIP, learning sets of the CLIP paper |
|---|---|---|---|---|---|---|
| Microstructure | 450 | 0.92 | 0.88 | 0.81 | 0.92 | 0.85 (72 + 72) |
| Textiles (simulated) | 200 | 0.86 | 0.73 | 0.85 | 0.81 | 0.98 (50 + 50) |
| Extrusion | 200 | 0.73 | 0.69 | 0.68 | 0.50 | 0.82 (350 + 350) |
| Pipe staple (AutoVI) | 100 | 0.98 | 0.96 | 0.99 | 0.61 | 0.57 (50 + 50) |
| Metallic pans | 78 | 1.00 | 0.96 | 0.92 | 0.94 | 0.91 (10 + 10) |

Raw JEV probabilities are not calibrated (expected calibration error 0.11 to 0.23). Isotonic regression fitted on validation reduces it to 0.01 to 0.04 on four of the five datasets. About 10 to 20 validation images per class were enough for the calibration step. Details: `experiment_log.md`.

## Repository layout

| Path | Contents |
|---|---|
| `experiment_log.md` | The lab notebook: setup notes, every trial (60), decisions and rule changes, and the final-test sections |
| `R/` | Shared R functions: the JEV/SystemOne client (`industrial_defect_classifier.R`) and calibration functions |
| `scripts/` | Runnable steps (run from the repository root; see below) |
| `python/` | CLIP functions (from the CLIP qmd of the prior study) |
| `experiments/` | Inputs chosen during tuning (criteria and reference sets) and one-time data scripts (leakage check, duplicate removal) |
| `results/` | Split and reference manifests, all trial outputs (`optimization/`), the frozen configurations, test results (`final_test/`), and CLIP results (`clip/`, `clip_paper/`) |
| `paper/` | MSEC 2027 abstract: draft and submitted versions, with the source of each number |
| `docs/` | The original task (`GOAL.md`) and the draft design of the `decisionqc` package |
| `archive/` | The first analysis script, kept for the record |

## Data

The images are not in this repository. Copy the folders of [fmegahed/qe_genai/data](https://github.com/fmegahed/qe_genai/tree/main/data) into `imgs/` (same folder names: `extrusion_images`, `microstructure`, `pan_images`, `pipe_staple`, `textile_images`).

- `results/image_split_manifest.csv` lists exactly the images used and their split. The scripts stop if an image is missing.
- Two cleanups differ from a fresh copy: duplicate pan test images were removed (the `qe_genai` test folder already matches), and 3 extrusion frames that were byte-identical copies of test frames were removed from the non-test pool. Extra files in `imgs/` are not used.
- The pipe staple images are from the Automotive Visual Inspection Dataset (AutoVI), Renault Group, CC BY-NC-SA 4.0, [doi:10.5281/zenodo.10459003](https://doi.org/10.5281/zenodo.10459003). For the other datasets, see Megahed et al. (2026), below.

## Reproduce

Requirements: R 4.6.1 with httr2, magick, base64enc, tibble, purrr, dplyr, tidyr, readr, yardstick and ggplot2. Run every script from the repository root.

- JEV (paid API): put `TYPESAFE_API_KEY=...` in a `.Renviron` file at the root. Never commit it.
- Validation trial: `JEV_DATASET=microstructure JEV_TRIAL=<name> Rscript scripts/optimize_jev.R` (settings in the script header).
- Threshold trial, no API calls: `scripts/rescore_threshold.R`. Progress chart: `scripts/plot_progress.R`.
- One-time test of a frozen configuration: `JEV_DATASET=<dataset> Rscript scripts/evaluate_frozen.R` (`JEV_CHECK_ONLY=true` runs the checks only).
- Summaries, no API calls: `scripts/summarize_final.R`, `scripts/calibration.R`, `scripts/validation_size.R`, `scripts/compare_methods.R`.
- CLIP (local GPU): a Python 3.12 environment with torch 2.8.0 and OpenAI CLIP (versions in `results/clip/python_environment.txt`), then `RETICULATE_PYTHON=<env>/python.exe Rscript scripts/run_clip.R` and `scripts/run_clip_paper.R`. Stop the Clef-Flash server first: two CUDA processes on one GPU made the CLIP run crash.
- Clef-Flash (local GPU, about 25 GB): `docker run --gpus all -p 30000:30000 lmsysorg/sglang:dev-clef sglang serve --model-path Cloudflare/clef-flash --host 0.0.0.0 --port 30000`, then run the scripts with `JEV_BASE_URL=http://localhost:30000/v1/systemone JEV_MODEL=Cloudflare/clef-flash JEV_IMAGE_FORMAT=images`. Its server ignores the TypeSafe `assets` field, so images go as an ordered list (`image_format = "images"`).

## Related work

- Megahed, Fadel Mounir, et al. "Adapting OpenAI's CLIP model for few-shot image inspection in manufacturing quality control: An expository case study with multiple application examples." *Journal of Quality Technology* (2026): 1-27. Open access: [doi:10.1080/00224065.2026.2640171](https://www.tandfonline.com/doi/pdf/10.1080/00224065.2026.2640171) (preprint: [arXiv:2501.12596](https://arxiv.org/abs/2501.12596)).
- The notebook of that study: [image_inspection_with_clip.ipynb](https://github.com/fmegahed/qe_genai/blob/main/notebook/image_inspection_with_clip.ipynb).

## License

MIT for the code and documents in this repository (see `LICENSE`). The images are not included; each dataset keeps its own license (for example, AutoVI is CC BY-NC-SA 4.0).
