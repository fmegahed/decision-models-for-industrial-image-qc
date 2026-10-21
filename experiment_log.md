# JEV experiment log

Objective: maximize validation balanced accuracy per dataset. Test images stay untouched until the final frozen evaluation.

Date of all entries: 2026-10-20.

## Setup notes

- 2026-10-20. The two manifests in `results/` came from `Y:/My Drive/Miami/Code/GitHub/imagejev/`. All paths were changed to relative `imgs/...` paths. All 4,525 split paths and 18 reference paths exist here, and each file has the same size as its `Y:` original.
- 2026-10-20. Bug fix in `optimize_jev.R`. In `dplyr::filter(.data$dataset == dataset)`, the bare `dataset` is the data column, not the R variable, so the filter kept all datasets. The validation pool and the references mixed datasets. The fix is `.env$dataset` (3 lines). The reference guard stopped the first smoke run before any API call.
- 2026-10-20. Smoke test in a scratch copy, so no validation manifest was frozen here. Microstructure, 3 images per class, 2 identical runs: 12 calls, all HTTP 200. JEV is not deterministic: the same image scored 0.55 and then 0.49. Tokens per call: about 2,650 for microstructure with 4 references, about 550 for one 250 px textile image, and 31,764 for pan at 1568 px with 4 references (the limit is 32k per question).
- 2026-10-20. Threshold diagnostic on the trial 1, 3 and 5 predictions (no files, no API calls; optimistic because fitted to validation): best BA 0.73 for microstructure at t=0.20, 0.89 for textiles at t=0.14, 0.75 for extrusion at t=0.55. Plan: change criteria, references and size at t=0.50 first, and tune the threshold last on the final configuration.
- 2026-10-20. Keep rule changed by the user after trial 9 (AUC, threshold last). For criteria, reference and size changes: keep if ROC AUC rises by at least 0.02 (repeat-run AUC noise was under 0.01); if AUC does not change by that much, the current best stays. BA is still reported. The threshold is tuned once, at the end, on the final configuration. Why: at t=0.50, trial 9 lost 0.19 BA while its AUC rose 0.09, and trial 8 gained 0.04 BA with no AUC gain. Trials 8 and 9 were decided again under this rule.
- 2026-10-20. Threshold rule (fixed before the final step): on a 0.01 grid, take the midpoint of the widest run of thresholds that all reach the maximum validation BA. Threshold trials are judged by BA, because AUC does not change with the threshold.
- 2026-10-20. Leakage check (experiments/check_leakage.R, then MD5 checksums). pan_images: all 20 train images, including the 4 references, had byte-identical copies in test, and test had 3 more internal duplicates. On request of the user, the 23 duplicate test files were deleted and their manifest rows removed (experiments/remove_pan_duplicates.R; the originals stay on Y:). Pan test is now 39 defective + 40 nominal; no duplicate MD5s remain. A 48x48 gray-thumbnail check found no near-duplicates: test images are closer to each other (median 1.08) than to train images (2.05). No file names with "copy" remain. pipe_staple: no exact duplicates and no near-duplicates (median 13.2 vs 13.7).
- 2026-10-20. Paid-call cap raised by the user to 5,000 API calls in total for this work. Used before batch 4: 1,418 (smoke 18, batch 1 600, batch 2 300, batch 3a 200, batch 3b 300).
- 2026-10-20. Ceiling exception (decision of the user, pipe_staple): when the baseline AUC is so high that a gain of 0.02 is not possible, compare the trials by BA at their tuned thresholds.
- 2026-10-20. Test sets matched to the prior CLIP study (decisions of the user; experiments/match_prior_test_sizes.R). pan_images: test/nominal/21.JPG deleted, because the prior test folder (github.com/fmegahed/qe_genai, data/pan_images/test) does not have it; pan test is now the same 78 images (39 + 39) as the prior study. textiles_real added as a test-only dataset: the 100 real images (94 icImgs nominal, 6 ocImgs defective), scored with the frozen textiles configuration unchanged (tuned_on = textiles), as in the prior transfer test. The other test sets already had the prior sizes (microstructure 450, textiles 200, extrusion 200, pipe_staple 100); only pipe_staple has the same images, because the prior study sampled with a Python seed. The few-shot learning-set sizes of the prior study are not copied: JEV uses a few references, not a CLIP learning set.
- 2026-10-20. Paid-call cap raised by the user to 7,000. Zero-shot ablation (request of the user): each frozen configuration was run again without reference images, on validation (416 calls) and on test (1,128 calls), with its own threshold from the same plateau rule. Calibration of the JEV probabilities and a CLIP run on the same partition were added (both without API calls).
- 2026-10-20. textiles_real dropped (decision of the user): the transfer test also failed for CLIP. Its manifest rows, frozen rows and result files were removed; its numbers stay in the final-test notes below. Exact-duplicate audit of all datasets (MD5): only extrusion has duplicates (11 groups of identical video frames, 22 files); 3 groups span test and the pool ("over" frames), and none of those pool files is a JEV reference or validation image, so the JEV and same-reference CLIP results are not affected. Near-duplicate check (48x48 gray): none for textiles and microstructure; extrusion test frames have close pool neighbors, as expected for video frames.
- 2026-10-20. Clef-Flash (Cloudflare, 9B open weights, Apache-2.0) served locally with SGLang (image lmsysorg/sglang:dev-clef, GPU RTX 5000 Ada, 24.8 GB GPU memory), endpoint http://localhost:30000/v1/systemone; no paid API calls. Finding: the server silently ignores the TypeSafe `assets` field, so the first test scored two very different images the same (0.84 / 0.16) with 251 input tokens (text only). Its SystemOne schema takes an ordered top-level `images` list instead, with no link from a criterion to its example images. The wrapper got a backward-compatible `image_format = "images"` option: images in order (inspection image first, then references), and the state text says which image is which. After that, a 5-image request used 990 tokens and the scores separated (0.88 against 0.10). Clef-Flash returns full-precision probabilities, not 2 decimals.
- 2026-10-20. Repository organized before the first push (request of the user): shared code to `R/`, runnable steps to `scripts/`, CLIP functions to `python/`, `GOAL.md` and the package design to `docs/`, the first analysis script to `archive/`; the project file renamed to `decision-models-for-industrial-image-qc.Rproj`. Data and result paths did not change (they are recorded in the score files). After the move, all no-cost scripts reproduced their outputs byte for byte, and both CLIP scripts reproduced their results. `run_clip_paper.R` crashed twice without a message while the Clef-Flash server held the GPU; it ran cleanly after `docker stop clef-flash`.
- 2026-10-20. Unintended paid run: while testing the new frozen-validation guard of `scripts/optimize_jev.R` (with `JEV_RESULTS_ROOT` set to a temporary folder), Rscript reloaded the API key from `.Renviron`, and the runner made 100 JEV calls (about USD 0.011). It repeated the microstructure baseline with the frozen validation set: BA 0.54, AUC 0.789 (baseline 0.55 and 0.803; repeat 0.55 and 0.805). The guard worked: the run used the frozen validation set, unchanged. No file in `results/` changed.
- Model: `jev-latest` points to `jev-1.13.0` today (docs.typesafe.ai/models). Input costs USD 0.042 per million tokens; output is free.

## Trials

The `#`, `Dataset`, `Trial`, `Change` and `Decision` columns feed `plot_progress.R`. Decision is one of baseline, kept, discarded, replicate (a repeat to measure API noise), ablation, comparison (another model; not in the progress chart), failed. Do not use a "|" character inside a cell.

| # | Dataset | Trial | Variable | Change | Decision | BA / Sens / Spec / AUC | Rationale and next hypothesis |
|---|---|---|---|---|---|---|---|
| 1 | microstructure | baseline | none | Generic criteria; refs 1 Uniform + Band/Bimodal/SingleCrystal_medium; 768; center; t=0.50 | baseline | 0.55 / 0.10 / 1.00 / 0.80 | Model almost never says defective. Mean score: Uniform 0.21, Bimodal_low 0.18, Band and Bimodal 0.24-0.27, SingleCrystal_high 0.50. Ranking comes mostly from SingleCrystal. Next: criteria that name color clustering. |
| 2 | microstructure | baseline_rep | none | Repeat of trial 1 | replicate | 0.55 / 0.10 / 1.00 / 0.80 | 0 of 100 images flipped; mean score change 0.017. API noise is small here. |
| 3 | textiles | baseline | none | Generic criteria; refs 1 nominal + 1 local + 1 global; 768 (images stay 250, padded to 280); t=0.50 | baseline | 0.81 / 0.62 / 1.00 / 0.94 | Local recall 0.94; global recall 0.00 (mean score 0.21 vs nominal 0.08). Next: criteria that describe the global texture change. |
| 4 | textiles | baseline_rep | none | Repeat of trial 3 | replicate | 0.81 / 0.62 / 1.00 / 0.94 | 0 of 100 images flipped; mean score change 0.015. |
| 5 | extrusion | baseline | none | Generic criteria; refs 1 normal + 1 over + 1 under; 768 (images stay 85 or 224, padded to 280); t=0.50 | baseline | 0.72 / 0.74 / 0.70 / 0.79 | Scores cluster near 0.5 (over 0.57, under 0.58, normal 0.45). Next: over/under criteria. |
| 6 | extrusion | baseline_rep | none | Repeat of trial 5 | replicate | 0.70 / 0.72 / 0.68 / 0.80 | 6 of 100 flipped, all with scores 0.47-0.57. Noise floor about 0.02 BA. Keep rule stays: +0.03 BA and no loss of sensitivity. |
| 7 | microstructure | criteria_color | criteria | experiments/microstructure_criteria_color.csv (grain-color clusters); all else as trial 1 | kept | 0.83 / 0.66 / 1.00 / 0.97 | 28 defects improved, 0 worsened. Uniform mean score 0.21 to 0.05. Still missed: Bimodal_low 0/3 (mean 0.04), Bimodal_medium 0/7 (0.32), Band_low 5 of 7. Best-threshold BA (diagnostic) 0.73 to 0.95. Next: reference set with one image per subtype. |
| 8 | textiles | criteria_weave | criteria | experiments/textiles_criteria_weave.csv (speck or blurrier texture); all else as trial 3 | discarded | 0.85 / 0.70 / 1.00 / 0.95 | Re-decided under the AUC rule: AUC +0.007 is a tie, so the baseline stays best. At t=0.50 it gave +0.04 BA: 4 global images improved, 0 worsened. But AUC +0.01 and best-threshold BA 0.89 to 0.88, so the gain is mostly a score shift, not better ranking. Next: upscale 250 to 768. |
| 9 | extrusion | criteria_over_under | criteria | experiments/extrusion_criteria_over_under.csv (bulge vs thin strand); all else as trial 5 | kept | 0.53 / 1.00 / 0.06 / 0.88 | Kept under the AUC rule (AUC 0.79 to 0.88). At t=0.50 BA fell because all scores moved up (normal mean 0.45 to 0.66). But AUC 0.79 to 0.88 and best-threshold BA 0.75 to 0.83. The threshold is tuned last. Next: upscale to 448. |
| 10 | microstructure | color_refs_all9 | references | experiments/microstructure_refs_all9.csv (1 Uniform + 1 per each of 9 subtypes); criteria as trial 7 | discarded | 0.84 / 0.68 / 1.00 / 0.96 | AUC 0.966 to 0.964 (tie): trial 7 stays best and keeps 4 references (fewer tokens). Bimodal_low and Bimodal_medium still 0 of 10 even with their own reference. Next: criteria wording for the bimodal pattern. |
| 11 | textiles | weave_upscale_768 | image size | Upscale 250 to 768 (JEV_UPSCALE=true); criteria as trial 8 | discarded | 0.81 / 0.68 / 0.94 / 0.90 | AUC 0.95 to 0.90. Local recall 1.00, but nominal mean score 0.09 to 0.20: enlarged normal texture looks like flaws. Next: references for the global defect. |
| 12 | microstructure | criteria_color2 | criteria | experiments/microstructure_criteria_color2.csv (adds the color-range cue for bimodal); refs as trial 7 | discarded | 0.81 / 0.62 / 1.00 / 0.96 | AUC 0.966 to 0.964 (tie). Bimodal_medium 0 to 3 of 7, but Band_medium 6 to 4 of 8, Band_low 2 to 1, SingleCrystal_low 5 to 3. A trade, not a gain. |
| 13 | textiles | refs_global2 | references | experiments/textiles_refs_global2.csv (+1 nominal, +1 global); generic criteria as trial 3 | discarded | 0.84 / 0.68 / 1.00 / 0.95 | AUC 0.943 to 0.948 (tie). Global recall 0 to 3 of 17 at t=0.50; nominal mean score 0.08 to 0.13. |
| 14 | extrusion | over_under_upscale_448 | image size | Upscale 85 or 224 to 448 (JEV_UPSCALE=true); criteria as trial 9 | discarded | 0.55 / 0.98 / 0.12 / 0.85 | AUC 0.881 to 0.854. Enlarging blurry 85 px crops did not help. Paid trials stop here (800 of the 1,000-call cap). |
| 15 | microstructure | criteria_color_t016 | threshold | t=0.50 to 0.16 on the trial 7 predictions (rescore_threshold.R, no API calls) | discarded | 0.95 / 0.90 / 1.00 / 0.97 | Superseded by trial 23: the threshold picker had float drift (seq gives 0.41000000000000003). On an exact grid the plateau is 0.16 to 0.18. Old note: max-BA plateau 0.15 to 0.17. Optimistic: the threshold is fitted on these validation images. Remaining misses: Bimodal_low and Bimodal_medium. |
| 16 | textiles | baseline_t014 | threshold | t=0.50 to 0.14 on the trial 3 predictions (no API calls) | kept | 0.89 / 0.88 / 0.90 / 0.94 | The plateau is one grid point, so the threshold is fragile: nominal scores are dense near 0.1. Expect a lower test BA. |
| 17 | extrusion | criteria_over_under_t076 | threshold | t=0.50 to 0.76 on the trial 9 predictions (no API calls) | kept | 0.83 / 0.82 / 0.84 / 0.88 | The plateau is one grid point, so the threshold is fragile. |
| 18 | pipe_staple | baseline | none | Generic criteria; refs 2 good + 2 missing; 768 (images stay 400); center; t=0.50 | baseline | 0.92 / 0.84 / 1.00 / 0.997 | AUC already near the ceiling. Missing-staple mean score 0.63, good 0.25. |
| 19 | pipe_staple | baseline_rep | none | Repeat of trial 18 | replicate | 0.92 / 0.84 / 1.00 / 0.998 | 0 of 100 flipped; mean score change 0.024. |
| 20 | pipe_staple | criteria_specific | criteria | experiments/pipe_staple_criteria_specific.csv (wording from the qmd) | discarded | 0.99 / 1.00 / 0.98 / 1.000 | AUC 0.997 to 1.000 is a tie under the AUC rule, because AUC is at its ceiling. Threshold-tuned BA would be 1.00 against 0.97 for the baseline. Flagged for the user before the test run. |
| 21 | pipe_staple | criteria_staple | criteria | experiments/pipe_staple_criteria_staple.csv (bright square clip near the center) | discarded | 0.99 / 1.00 / 0.98 / 1.000 | Same as trial 20, with the widest max-BA plateau (0.75 to 0.85). Flagged for the user. |
| 22 | pipe_staple | baseline_t041 | threshold | t=0.50 to 0.41 on the trial 18 predictions (no API calls) | discarded | 0.96 / 0.96 / 0.96 / 0.997 | Float drift in the picker: a score of exactly 0.41 fell on the wrong side. Superseded by trial 24. |
| 23 | microstructure | criteria_color_t017 | threshold | t=0.50 to 0.17 on the trial 7 predictions (no API calls) | kept | 0.95 / 0.90 / 1.00 / 0.97 | Exact-grid plateau 0.16 to 0.18. Replaces trial 15. |
| 24 | pipe_staple | baseline_t039 | threshold | t=0.50 to 0.39 on the trial 18 predictions (no API calls) | discarded | 0.97 / 0.98 / 0.96 / 0.997 | Exact-grid plateau 0.38 to 0.40. Replaced by trial 30 (decision of the user). |
| 25 | pan_images | baseline | none | Generic criteria; refs 2 nominal + 2 defective; 1568 (as in the qmd); center; t=0.50. Validation is 8 + 8 train images (all non-reference train images) | baseline | 1.00 / 1.00 / 1.00 / 1.00 | Perfect on 16 images. Run after the duplicate cleanup, so no validation image has a copy in test. About 31.8k tokens per call (limit 32k). |
| 26 | pan_images | baseline_rep | none | Repeat of trial 25 | replicate | 1.00 / 1.00 / 1.00 / 1.00 | 0 of 16 flipped. |
| 27 | pan_images | size_1024 | image size | max size 1568 to 1024 | kept | 1.00 / 1.00 / 1.00 / 1.00 | Judged as no-worse (the user asked to try smaller sizes to save tokens): keep if AUC does not fall by 0.02 and BA at t=0.50 does not fall. About 2.3 times fewer image tokens. |
| 28 | pan_images | size_768 | image size | max size 1024 to 768 | kept | 1.00 / 1.00 / 1.00 / 1.00 | No worse; about 4 times fewer image tokens than 1568. With only 16 images, this shows no loss, not equality. |
| 29 | pan_images | size_768_t047 | threshold | t=0.50 to 0.47 on the trial 28 predictions (no API calls) | kept | 1.00 / 1.00 / 1.00 / 1.00 | Max-BA plateau 0.12 to 0.81 (wide). |
| 30 | pipe_staple | criteria_staple_t080 | threshold | t=0.50 to 0.80 on the trial 21 predictions (no API calls) | kept | 1.00 / 1.00 / 1.00 / 1.000 | Decision of the user at the pre-test checkpoint: at the AUC ceiling (0.997 baseline), use BA at the tuned threshold. Trial 21 (bright-clip wording) reaches 1.00 with the widest plateau (0.75 to 0.85), against 0.97 for the baseline. |
| 31 | pan_images | zero_shot | references (ablation) | Frozen pan configuration without reference images | ablation | 0.94 / 1.00 / 0.88 / 1.00 | Zero-shot ablation (request of the user): what do the references add? Same criteria, size and crop; no reference images. |
| 32 | pipe_staple | zero_shot | references (ablation) | Frozen pipe_staple configuration (bright-clip wording) without reference images | ablation | 0.76 / 0.54 / 0.98 / 0.967 | AUC 1.000 with references, 0.967 without. |
| 33 | textiles | zero_shot | references (ablation) | Frozen textiles configuration (generic criteria) without reference images | ablation | 0.76 / 0.52 / 1.00 / 0.73 | AUC 0.943 with references, 0.728 without: the largest gain from references. |
| 34 | extrusion | zero_shot | references (ablation) | Frozen extrusion configuration (over/under wording) without reference images | ablation | 0.57 / 1.00 / 0.14 / 0.77 | AUC 0.881 with references, 0.768 without. |
| 35 | microstructure | zero_shot | references (ablation) | Frozen microstructure configuration (grain-color wording) without reference images | ablation | 0.70 / 0.40 / 1.00 / 0.94 | AUC 0.966 with references, 0.942 without. |
| 36 | pan_images | zero_shot_t053 | threshold (ablation) | t=0.50 to 0.53 on the trial 31 predictions (no API calls) | ablation | 1.00 / 1.00 / 1.00 / 1.00 | Same plateau rule as the main condition, so the zero-shot test comparison is fair. |
| 37 | pipe_staple | zero_shot_t035 | threshold (ablation) | t=0.50 to 0.35 on the trial 32 predictions (no API calls) | ablation | 0.92 / 0.98 / 0.86 / 0.967 | Plateau 0.33 to 0.37. |
| 38 | textiles | zero_shot_t029 | threshold (ablation) | t=0.50 to 0.29 on the trial 33 predictions (no API calls) | ablation | 0.80 / 0.62 / 0.98 / 0.73 | Single-point plateau. |
| 39 | extrusion | zero_shot_t072 | threshold (ablation) | t=0.50 to 0.72 on the trial 34 predictions (no API calls) | ablation | 0.72 / 0.70 / 0.74 / 0.77 | Single-point plateau. |
| 40 | microstructure | zero_shot_t007 | threshold (ablation) | t=0.50 to 0.07 on the trial 35 predictions (no API calls) | ablation | 0.91 / 0.90 / 0.92 / 0.94 | Single-point plateau. |
| 41 | microstructure | clef_refs | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, with references | comparison | 0.62 / 0.24 / 1.00 / 0.887 | Comparison model; not part of the JEV tuning. |
| 42 | microstructure | clef_refs_t011 | threshold (Clef-Flash) | t=0.50 to 0.11 on the clef_refs predictions (no API calls) | comparison | 0.80 / 0.64 / 0.96 / 0.887 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 43 | microstructure | clef_zero | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, without references | comparison | 0.58 / 0.16 / 1.00 / 0.895 | Comparison model; not part of the JEV tuning. |
| 44 | microstructure | clef_zero_t006 | threshold (Clef-Flash) | t=0.50 to 0.06 on the clef_zero predictions (no API calls) | comparison | 0.82 / 0.68 / 0.96 / 0.895 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 45 | textiles | clef_refs | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, with references | comparison | 0.59 / 0.18 / 1.00 / 0.909 | Comparison model; not part of the JEV tuning. |
| 46 | textiles | clef_refs_t008 | threshold (Clef-Flash) | t=0.50 to 0.08 on the clef_refs predictions (no API calls) | comparison | 0.84 / 0.94 / 0.74 / 0.909 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 47 | textiles | clef_zero | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, without references | comparison | 0.51 / 0.02 / 1.00 / 0.722 | Comparison model; not part of the JEV tuning. |
| 48 | textiles | clef_zero_t009 | threshold (Clef-Flash) | t=0.50 to 0.09 on the clef_zero predictions (no API calls) | comparison | 0.75 / 0.58 / 0.92 / 0.722 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 49 | extrusion | clef_refs | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, with references | comparison | 0.72 / 0.86 / 0.58 / 0.811 | Comparison model; not part of the JEV tuning. |
| 50 | extrusion | clef_refs_t052 | threshold (Clef-Flash) | t=0.50 to 0.52 on the clef_refs predictions (no API calls) | comparison | 0.74 / 0.70 / 0.78 / 0.811 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 51 | extrusion | clef_zero | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, without references | comparison | 0.65 / 0.66 / 0.64 / 0.747 | Comparison model; not part of the JEV tuning. |
| 52 | extrusion | clef_zero_t056 | threshold (Clef-Flash) | t=0.50 to 0.56 on the clef_zero predictions (no API calls) | comparison | 0.73 / 0.56 / 0.90 / 0.747 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 53 | pipe_staple | clef_refs | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, with references | comparison | 0.95 / 1.00 / 0.90 / 0.999 | Comparison model; not part of the JEV tuning. |
| 54 | pipe_staple | clef_refs_t056 | threshold (Clef-Flash) | t=0.50 to 0.56 on the clef_refs predictions (no API calls) | comparison | 0.99 / 1.00 / 0.98 / 0.999 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 55 | pipe_staple | clef_zero | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, without references | comparison | 0.92 / 0.98 / 0.86 / 0.981 | Comparison model; not part of the JEV tuning. |
| 56 | pipe_staple | clef_zero_t049 | threshold (Clef-Flash) | t=0.50 to 0.49 on the clef_zero predictions (no API calls) | comparison | 0.93 / 1.00 / 0.86 / 0.981 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 57 | pan_images | clef_refs | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, with references | comparison | 0.94 / 0.88 / 1.00 / 1.000 | Comparison model; not part of the JEV tuning. |
| 58 | pan_images | clef_refs_t023 | threshold (Clef-Flash) | t=0.50 to 0.23 on the clef_refs predictions (no API calls) | comparison | 1.00 / 1.00 / 1.00 / 1.000 | Threshold from the same plateau rule (exact 2-decimal grid). |
| 59 | pan_images | clef_zero | model (Clef-Flash) | Clef-Flash (local SGLang, image_format=images) with the frozen JEV configuration, without references | comparison | 0.88 / 0.75 / 1.00 / 0.992 | Comparison model; not part of the JEV tuning. |
| 60 | pan_images | clef_zero_t026 | threshold (Clef-Flash) | t=0.50 to 0.26 on the clef_zero predictions (no API calls) | comparison | 0.94 / 0.88 / 1.00 / 0.992 | Threshold from the same plateau rule (exact 2-decimal grid). |

## Final test

Run with `evaluate_frozen.R` after all configurations were frozen in `results/optimization/frozen_configs.csv`. Settings came only from that file. Each frozen row was checked against its source trial. No reference image is in a test set, checked by path and by MD5. 1,128 calls; 3,010 of the 5,000-call cap used in total. These are evaluation numbers, not selection numbers. Nothing was tuned after this run.

| Dataset | Test n | Validation BA (selection) | Test BA | Test Sens / Spec | Test AUC | Prior CLIP BA (AUC) |
|---|---|---|---|---|---|---|
| microstructure | 450 | 0.95 | 0.92 | 0.84 / 1.00 | 0.96 | 0.90 (0.95), other test images |
| textiles (simulated) | 200 | 0.89 | 0.86 | 0.88 / 0.83 | 0.95 | zero-shot 0.50, other test images |
| textiles_real (transfer) | 100 | not tuned | 0.50 | 1.00 / 0.00 | 0.97 | 0.50 (0.79), same images |
| extrusion | 200 | 0.83 | 0.73 | 0.71 / 0.74 | 0.81 | 0.65 (0.68), other test images |
| pipe_staple | 100 | 1.00 | 0.98 | 0.96 / 1.00 | 1.00 | 0.58 (0.61), same images |
| pan_images | 78 | 1.00 | 1.00 | 1.00 / 1.00 | 1.00 | 0.94 (1.00), same images |

Notes:
- Test BA is lower than validation BA by 0.02 to 0.04, except extrusion (0.10). The extrusion threshold (0.76) was a single-point plateau, as noted in trial 17.
- microstructure: Bimodal_low 0 of 25 and Bimodal_medium 17 of 25; all other defect subtypes 22 of 25 or more. Uniform specificity 1.00.
- textiles_real: the threshold tuned on simulated fabric (0.14) does not transfer: real nominal images score 0.40 on average, so all 94 were called defective. The ranking does transfer (AUC 0.97). A threshold set on a few real nominal images would be needed; such images were not available outside this test set.
- The CLIP comparison on the same partition (GOAL step 6) is still to do with the CLIP qmd. The prior-study numbers above are a reference only.

### Zero-shot ablation

Same frozen configurations without reference images, each with its own validation threshold (trials 31 to 40). 1,128 test calls; 4,554 of the 7,000-call cap used in total. Gain = with references minus zero-shot.

| Dataset | BA zero-shot | BA with references | BA gain | AUC zero-shot | AUC with references | AUC gain |
|---|---|---|---|---|---|---|
| microstructure | 0.88 | 0.92 | +0.04 | 0.93 | 0.96 | +0.03 |
| textiles | 0.73 | 0.86 | +0.13 | 0.66 | 0.95 | +0.29 |
| textiles_real | 0.62 | 0.50 | -0.12 | 0.95 | 0.97 | +0.02 |
| extrusion | 0.69 | 0.73 | +0.04 | 0.77 | 0.81 | +0.05 |
| pipe_staple | 0.96 | 0.98 | +0.02 | 0.99 | 1.00 | +0.01 |
| pan_images | 0.96 | 1.00 | +0.04 | 1.00 | 1.00 | +0.00 |

References raise AUC on every test set, most for textiles (+0.29). The one BA loss (textiles_real) is a threshold-transfer effect: its zero-shot threshold (0.29) happens to sit closer to the real-fabric scores than the reference threshold (0.14).

### CLIP, same references

`run_clip.R` (no API calls): CLIP ViT-L/14 with the method and prompts of `clip_image_inspection.qmd` (unchanged), on the same test images and the same reference images as JEV. Every method uses a threshold chosen on the same validation images; AUC needs no threshold. Environment: conda env `~/.conda-envs/imagejev-clip`, Python 3.12, torch 2.8.0+cu128, OpenAI CLIP commit d05afc4, GPU RTX 5000 Ada; full list in `results/clip/python_environment.txt`. One bug was fixed before the results: a length-1 R vector reached Python as a string (`as.list()` added).

| Dataset | JEV references BA (AUC) | JEV zero-shot BA (AUC) | CLIP references BA (AUC) | CLIP zero-shot BA (AUC) |
|---|---|---|---|---|
| microstructure | 0.92 (0.96) | 0.88 (0.93) | 0.92 (0.98) | 0.50 (0.31) |
| textiles | 0.86 (0.95) | 0.73 (0.66) | 0.81 (0.88) | 0.50 (0.28) |
| textiles_real | 0.50 (0.97) | 0.62 (0.95) | 0.50 (0.14) | 0.50 (0.81) |
| extrusion | 0.73 (0.81) | 0.69 (0.77) | 0.50 (0.49) | 0.65 (0.71) |
| pipe_staple | 0.98 (1.00) | 0.96 (0.99) | 0.61 (0.69) | 0.55 (0.71) |
| pan_images | 1.00 (1.00) | 0.96 (1.00) | 0.94 (0.99) | 0.46 (0.57) |

Notes:
- JEV with references has the highest or equal-highest BA on every in-domain test set. CLIP with references equals it only on microstructure (BA 0.92; CLIP AUC 0.98 against 0.96).
- An AUC below 0.5 means the CLIP ranking is inverted (CLIP zero-shot on microstructure and textiles, CLIP references on textiles_real).
- CLIP uses the same 2 to 4 references as JEV here. The prior CLIP study used larger learning sets (10 to 350 images), so these CLIP numbers are not a replication of that study.

### Calibration

`calibration.R`, no API calls. Both calibrators were fitted on the validation predictions of the source trial and applied unchanged to the test predictions. ECE = expected calibration error (10 bins). Interval = 95% paired bootstrap interval of (isotonic - Platt) over test images, 2,000 resamples; negative means isotonic is better.

| Dataset (with references) | ECE raw | ECE Platt | ECE isotonic | ECE interval (iso - Platt) | Log-loss interval (iso - Platt) |
|---|---|---|---|---|---|
| microstructure | 0.18 | 0.05 | 0.03 | -0.041 to -0.007 | -0.033 to 0.015 |
| textiles | 0.19 | 0.08 | 0.04 | -0.081 to -0.002 | -0.037 to 0.014 |
| extrusion | 0.23 | 0.07 | 0.13 | -0.006 to 0.057 | 0.023 to 0.127 |
| pipe_staple | 0.11 | 0.03 | 0.02 | -0.028 to 0.003 | -0.024 to 0.058 |
| pan_images | 0.11 | 0.20 | 0.01 | -0.217 to -0.169 | -0.257 to -0.191 |

Isotonic has a clearly lower ECE for microstructure, textiles and pan (Platt with only 16 pan validation images pulls scores toward 0.1 and 0.9). Platt has a clearly lower log loss for extrusion. pipe_staple has no clear winner. Both calibrators give the same BA at the 0.5 cutoff, close to the BA of the tuned thresholds. Full table, including zero-shot: `results/final_test/calibration.csv` and `calibration_bootstrap.csv`.

### CLIP, paper learning sets

`run_clip_paper.R`, no API calls. Learning-set sizes from Megahed et al. (2026; read in the preprint, arXiv:2501.12596): pan 10 per class (all train images, as in the paper), pipe_staple the first 50 sorted per class (as in the paper), textiles 50 per class ("97% accuracy with 50 examples per class"), extrusion 200 per class (the plateau) and 350 per class (the best reported), microstructure 72 nominal and 8 per defect type. Decision rule as in the paper: the class with the higher maximum similarity. Learning images come from the non-test pool without copies of test images. Learning sets: `results/clip_paper/learning_sets.csv`.

| Setting | Learning images (nominal + defective) | Accuracy (Sens / Spec) | AUC | Paper accuracy (Sens / Spec), AUC | JEV with references: test BA (AUC) |
|---|---|---|---|---|---|
| pan, 10 per class | 10 + 10 | 0.910 (0.821 / 1.000) | 0.999 | 0.910 (0.821 / 1.000), 0.998 | 1.00 (1.00) |
| pipe_staple, 50 per class | 50 + 50 | 0.570 (0.560 / 0.580) | 0.631 | 0.580 (0.560 / 0.600), 0.608 | 0.98 (1.00) |
| textiles, 50 per class | 50 + 50 | 0.975 (0.970 / 0.980) | 0.998 | 0.97 | 0.86 (0.95) |
| extrusion, 200 per class | 200 + 200 | 0.790 (0.810 / 0.770) | 0.835 | plateau; no number | 0.73 (0.81) |
| extrusion, 350 per class | 350 + 350 | 0.820 (0.830 / 0.810) | 0.870 | 0.80 (0.78 / 0.81) | 0.73 (0.81) |
| microstructure, 72 + 72 | 72 + 72 | 0.853 (1.000 / 0.707) | 0.994 | 0.898 (0.987 / 0.809), 0.952 | 0.92 (0.96) |

pan and pipe_staple use the same test and learning images as the paper and reproduce it to within one or two images. With these larger learning sets, CLIP is better than JEV on textiles and extrusion; JEV is better on pipe_staple, pan and microstructure BA. Label budget: JEV used 2 to 4 references plus 100 labeled validation images per dataset; CLIP used 20 to 700 labeled learning images. Extrusion is from video, so CLIP's many learning frames include near-copies of test frames.

#### Tuned threshold (2026-10-20)

`run_clip_paper_threshold.R`, local GPU, no API calls (request of the user: CLIP also at a threshold tuned like ours). The learning sets hold most of our validation images (pan all 16; extrusion_350 82 of 100; microstructure 59 of 100), so the threshold comes from leave-one-out scores of the learning set: each learning image against the other learning images, with identical frames (same MD5) left out together. Same rule as `run_clip.R` (midpoint of the widest run of cut points at the maximum BA). The saved test scores are not computed again. Output: `results/clip_paper/tuned_thresholds.csv`.

| Setting | Threshold | Leave-one-out AUC | Test BA, paper rule | Test BA, tuned |
|---|---|---|---|---|
| pan, 10 per class | 0.50499 | 0.900 | 0.910 | 0.641 |
| pipe_staple, 50 per class | 0.50000 | 0.881 | 0.570 | 0.570 |
| textiles, 50 per class | 0.49972 | 0.998 | 0.975 | 0.980 |
| extrusion, 200 per class | 0.49995 | 0.813 | 0.790 | 0.800 |
| extrusion, 350 per class | 0.49960 | 0.841 | 0.820 | 0.825 |
| microstructure, 72 + 72 | 0.50052 | 0.983 | 0.853 | 0.960 |

#### Baseline: 50 per class (2026-10-20)

Decision of the user: the benchmark is CLIP with 50 learning images per class (pan: 10 per class, all it has), the low end of "50 to 100 per class" in the abstract of the CLIP paper. Classes are binary, so the 50 defect images are split evenly over the defect types: extrusion 25 over + 25 under; microstructure 6 each for the first five types (alphabetical) and 5 for the other four. pan_10, pipe_staple_50 and textiles_50 already had this size; `run_clip_paper.R` added extrusion_50 and microstructure_50 (`JEV_CLIP_SETTINGS=extrusion_50,microstructure_50`; the saved settings did not change). Thresholds: `run_clip_paper_threshold.R` (the six saved thresholds came out the same).

| Setting | Test BA, paper rule | Test BA, tuned (threshold) | AUC |
|---|---|---|---|
| extrusion, 50 per class | 0.695 | 0.730 (0.49850) | 0.774 |
| microstructure, 50 per class | 0.836 | 0.922 (0.50030) | 0.990 |

Against this baseline (paper rule), JEV with references is higher on four of five datasets (pan +0.09, extrusion +0.03, pipe_staple +0.41, microstructure +0.08) and lower on textiles (-0.12), with about the same number of labeled images (about 100 for both; pan 20). Against the tuned baseline, JEV is level on extrusion and microstructure.

The tuned threshold helps microstructure (+0.11; now above JEV's 0.92) and changes little elsewhere. It hurts pan: the 10 defective learning photos are near-copies of each other, so their leave-one-out scores (about 0.51) are higher than those of the test defects (about 0.50), and the threshold misses most test defects. With either rule, JEV is better on pan and pipe_staple, and CLIP is better on textiles and extrusion.

### Clef-Flash

Cloudflare Clef-Flash (9B open weights), served locally with SGLang (`lmsysorg/sglang:dev-clef`) on the RTX 5000 Ada. No paid API calls: 916 validation and 2,056 test calls on the local server. Each dataset used its frozen JEV configuration (criteria, references, 768 px, center crop), with references sent as an ordered image list (`image_format = "images"`), and its own validation threshold from the same plateau rule (trials 41 to 60). One test pass per condition.

| Dataset | JEV references BA (AUC) | Clef-Flash references BA (AUC) | JEV zero-shot BA (AUC) | Clef-Flash zero-shot BA (AUC) |
|---|---|---|---|---|
| microstructure | 0.92 (0.96) | 0.81 (0.92) | 0.88 (0.93) | 0.84 (0.90) |
| textiles | 0.86 (0.95) | 0.85 (0.92) | 0.73 (0.66) | 0.71 (0.68) |
| extrusion | 0.73 (0.81) | 0.68 (0.75) | 0.69 (0.77) | 0.60 (0.73) |
| pipe_staple | 0.98 (1.00) | 0.99 (1.00) | 0.96 (0.99) | 0.90 (0.97) |
| pan_images | 1.00 (1.00) | 0.92 (1.00) | 0.96 (1.00) | 0.72 (0.95) |

Notes:
- With references, Clef-Flash matches JEV on pipe_staple (0.99 against 0.98) and textiles (0.85 against 0.86), and is lower on microstructure, extrusion and pan. On pan, AUC is 1.00 but the threshold chosen on 16 validation images did not transfer well.
- References help Clef-Flash too, even as a plain ordered image list: test AUC rises on every dataset except microstructure (+0.24 for textiles).
- Raw Clef-Flash probabilities are less calibrated than raw JEV probabilities (ECE 0.09 to 0.36, against 0.11 to 0.23). Isotonic regression fitted on validation reduces the Clef-Flash ECE to 0.02 to 0.10.
- Practical differences: Clef-Flash runs locally at about 0.3 s per call with no API fees, needs a 24 GB-class GPU, and needs two adaptations: the ordered image list and three-channel images (its server fails on one-channel gray JPEGs).

### Validation size

`validation_size.R`, no API calls. For each frozen JEV configuration, 200 random validation subsets with 5, 10, 20, 30 or 50 images per class (pan: 5 or 8); on each subset a threshold, a Platt fit and an isotonic fit; each scored on the full test set. Caveat: the criteria and references were chosen on the full validation set, so this measures the threshold and calibration step only. Full table: `results/final_test/validation_size.csv`; chart: `validation_size.png`.

- Test BA is within 0.01 to 0.02 of the 50-per-class value at 10 images per class for microstructure, extrusion, pipe_staple and pan; textiles needs about 20 per class (isotonic: 0.85 at 10 per class).
- Calibration error with isotonic at 10 images per class: microstructure 0.07, textiles 0.09, pipe_staple 0.01, pan 0.03 (at 5 to 8 per class). Extrusion is the exception: Platt is better at every size (0.07 against 0.17).
- Platt needs more images than isotonic on these data: its soft targets pull the probabilities toward 0.5 when the subset is small (pipe_staple ECE 0.16 at 5 per class, 0.03 at 50).
- So, for the threshold and calibration step, about 10 to 20 labeled validation images per class were enough here; with 2 to 4 references, about 25 to 45 labeled images in total.

## Fair comparison (v0.1.0)

Design: `replication_materials/plans/2026-10-20-fair-comparison-design.md`. Plan: `replication_materials/plans/2026-10-20-fair-comparison-plan.md`. Code on branch `fair-comparison`.

### Checks before the runs (2026-10-21)

- fmm approved the loop instructions (D83) and a budget row of 50,000 JEV calls and USD 20 (D84).
- Nine-image check: JEV and Clef-Flash both accept 9 images in one call (k = 4). JEV: 2,236 input tokens, 439 ms. Clef-Flash: 1,415 ms (first call).
- Latency at k = 2 (extrusion image): JEV 383, 372 and 603 ms (1,404 input tokens, about USD 0.00006 per call); Clef-Flash 296, 316 and 283 ms, with the same probability three times (deterministic).
- Check-only rehearsal of the loop launcher (`scripts/fair_run_loop.sh`) in a throwaway Clef-Flash textiles sandbox, Claude Code 2.1.306: all isolation flags accepted; 8 tool calls, all inside the sandbox, none denied. It found two defects, both fixed and reviewed before the loops: the audit counted each tool call twice, because 2.1.306 transcripts repeat tool_use blocks in api-request-blob entries (fix 7dcb698); and `scripts/fair_make_sandbox.R` ignored FAIR_MAP_DIR (fix dbf77fd).
- Paid calls of the checks: 4 JEV calls (purpose "fair check jev k4" and "k2").

### Description loops (2026-10-21)

One fresh, isolated Claude Code agent (Opus 5.5) for each model and dataset (D81), started by `scripts/fair_run_loop.sh` in its sandbox; closed with `scripts/fair_close_loop.R` (audit, mirror check, freeze). Design AUC is on the 48 + 48 design images that chose the description, so it is optimistic; the AUC on C follows in the calibration runs.

| Model | Dataset | Candidates | Generic design AUC | Frozen candidate | Frozen design AUC | Paid calls | Audit |
|---|---|---|---|---|---|---|---|
| Clef-Flash | extrusion | 6 | 0.708 | 2 | 0.764 | 0 (local) | blind |
| Clef-Flash | textiles | 5 | 0.855 | 4 | 0.928 | 0 (local) | blind |
| Clef-Flash | pipe_staple | 2 | 0.569 | 2 | 0.997 | 0 (local) | blind |
| Clef-Flash | microstructure | 5 | 0.886 | 3 | 0.936 | 0 (local) | blind |
| JEV | extrusion | 6 | 0.585 | 3 | 0.783 | 576 | blind |
| JEV | textiles | 2 | 0.917 | 2 | 0.991 | 192 | blind |
| JEV | pipe_staple | 1 | 0.994 | 1 (generic) | 0.994 | 96 | blind |
| JEV | microstructure | 4 | 0.770 | 2 | 0.945 | 384 | blind |

- Every audit has only the row "No call outside the sandbox. The loop was blind." No loop needed a retry.
- The agents stopped early when no candidate could pass the +0.02 rule (pipe staple, JEV textiles) or when they had no further idea that they expected to help (Clef-Flash textiles and microstructure, JEV microstructure).
- What the loops found: naming over- and under-extrusion (extrusion); describing the whole-surface texture, and saying that fine grain is normal (textiles); naming the bright clip that is missing (pipe staple, Clef-Flash); describing the color distribution of the grain map, random against one or two dominant hue families or same-hue patches (microstructure). JEV ranked pipe staple almost perfectly with the generic description, so its final description is the generic one, and its P2 difference is zero by construction.
- Low-severity microstructure defects (Bimodal_low, Band_low) stay hard for both models; the agents said that these images look random to them too.
- Records: `results/fair/loop/` (log copies, mirrors, audits, image maps, score.sh md5), `results/fair/descriptions/` (frozen texts). The 8 transcripts are kept outside git in `../fair-loop-sandbox/transcripts/`; their names and md5 are in the audit files.
- Paid calls of the loops: 1,248 JEV calls (purpose "fair design jev ..."), no failed call.
