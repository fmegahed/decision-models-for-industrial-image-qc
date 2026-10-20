# Goal: Improve JEV balanced accuracy for each industrial-image dataset

You are working in the `imagejev` R project with Claude Code. Use a disciplined, small-step experimental loop. The objective is **maximize validation balanced accuracy separately** for `extrusion`, `microstructure`, `pan_images`, `pipe_staple`, and `textiles` without contaminating held-out test sets.

## Project inputs

- `industrial_defect_classifier.R`: existing JEV API wrapper. Prefer not to modify it; if necessary, make the smallest possible backward-compatible change.
- `optimize_jev.R`: one validation experiment. Run from the repository root.
- `results/image_split_manifest.csv`: authoritative image paths and `split` labels. Never use `split == "test"` for tuning.
- `results/reference_manifest_seed202610_by_dataset.csv`: starting reference choices. It has columns `dataset`, `reference_class`, `reference_rank`, `image_path`.
- `jev_image_inspection*.qmd` and `clip_image_inspection*.qmd`: reporting and eventual matched JEV/CLIP comparison. Do not rewrite them during optimization.

## First action

Inspect the existing files and run **one inexpensive smoke test** on a single dataset with a small validation size (for example `JEV_N_VALIDATION=5`). Get approval before running large paid API batches. Check the API key is loaded from `TYPESAFE_API_KEY`; never print or commit it.

## Experimental loop

1. Create a fixed validation manifest **once per dataset**. `optimize_jev.R` persists it in `results/optimization/<dataset>/validation_images.csv`. Do not regenerate it between trials. These images are held out from reference selection.
2. Establish a baseline using the current image size, cropping, references, and original descriptions. Record balanced accuracy, sensitivity, specificity, ROC AUC, and image-level predictions.
3. Propose **one change at a time**: (a) better normal/defective criteria, (b) one representative defective reference per subtype, (c) choice/number of references within token constraints, (d) image crop or resolution, or (e) probability threshold. Keep the validation data and every other setting fixed.
4. Run a uniquely named trial. Inspect both the score and subtype errors; keep or reject the change based on balanced accuracy, with particular attention to missed defects.
5. Record a short rationale, variable changed, result, and next hypothesis for every trial in a concise `experiment_log.md`.
6. After selecting the best configuration *for each dataset*, freeze descriptions, reference paths, crop, size, and threshold. Only then run **one final evaluation on the untouched test images** and compare with CLIP on the same partition. Clearly distinguish selection/validation metrics from final test metrics.

## Dataset-specific hypotheses

| Dataset | First changes to try |
|---|---|
| `microstructure` | Uniform normal plus Band_medium, Bimodal_medium, SingleCrystal_medium defective references; investigate low sensitivity and good ranking/AUC. |
| `textiles` | One nominal reference and one each from local/global defect types; precise weave-disruption descriptions and validation-only threshold experiments. |
| `extrusion` | One normal, one over, one under reference; inspect the 85x85 originals, try 280/448 input sizes; do not claim upscaling adds information. |
| `pipe_staple` | Explicit missing metallic-clamp criteria; compare generic and specific wording with fixed references. |
| `pan_images` | Verify no near-duplicate or train/test leakage before trying to improve an already near-perfect result. |

## Trial interface

Set environment variables, then run `Rscript optimize_jev.R` from the project root.

| Variable | Example | Meaning |
|---|---|---|
| `JEV_DATASET` | `microstructure` | One of the five dataset identifiers |
| `JEV_TRIAL` | `micro_medium_refs` | Unique output name; do not overwrite previous trials |
| `JEV_CRITERIA_FILE` | `experiments/micro_criteria.csv` | Optional CSV with **one row**, `normal` and `defective` columns; omit for generic criteria |
| `JEV_REFERENCE_FILE` | `experiments/my_references.csv` | Optional manifest with same columns as starting reference manifest |
| `JEV_CROP` | `center` | `center` or `none` |
| `JEV_MAX_SIZE` | `768` | Integer between 280 and 1568 |
| `JEV_THRESHOLD` | `0.50` | Classify defective when score is at least threshold |
| `JEV_USE_REFERENCES` | `true` | `true` or `false` |
| `JEV_N_VALIDATION` | `20` | Per-class maximum used **only when creating** a validation manifest |

Example in a Unix-like shell (set environment variables in R or PowerShell as appropriate on Windows):

```sh
JEV_DATASET=microstructure JEV_TRIAL=baseline JEV_MAX_SIZE=768 Rscript optimize_jev.R
```

Files written per trial:

- `results/optimization/<dataset>/<trial>_predictions.csv`
- `results/optimization/<dataset>/<trial>_score.csv`

`balanced_accuracy` is the **primary optimization objective**. Report changes in sensitivity and specificity as well, so improved balanced accuracy does not hide unacceptable missed-defect rates. For comparisons at a fixed threshold, use the same candidate validation images throughout. Choose any tuned threshold from validation data, not from the held-out test set.

## Guardrails

- Never select reference images from test **or validation** images. The runner checks both.
- Freeze validation before changing references. If a candidate reference conflicts with validation, replace the reference, not the validation set.
- Do not compare changes using different test subsets or quietly change preprocessing between conditions.
- Image API requests cost money and may fail with `max_tokens_exceeded`; validate with small batches first. Do not silently drop failures or label them incorrect. Preserve the error and report the failed trial.
- Do not automatically chase 100% validation accuracy. Repeated tuning on a small fixed validation set can overfit; limit trials and use a final untouched test evaluation.
- Keep R code simple, explicit (`pkg::function` style), and human-readable. No caching frameworks, parallel API calls, hidden state, or elaborate orchestration.
- Important: the runner writes candidate predictions and score only after an entire run completes; if an API call fails mid-run, it will need a fresh trial. This intentionally favors simplicity over resumability.

## Deliverable

Provide a compact results table **by dataset**, with baseline vs best validation balanced accuracy, defect sensitivity, nominal specificity, selected instructions, reference image paths/types, crop, max image size, and threshold. Explain which modifications helped, which did not, and why the final test set remained untouched during tuning. Do not claim improvement on the final test until the frozen model configuration has been evaluated there.
