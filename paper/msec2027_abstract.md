# MSEC 2027: title and abstract (draft)

| Item | Value |
|---|---|
| Status | Draft for the author |
| Version | 3, dated 2026-10-20 (author's opening; results of both decision models; framework pitch) |
| Written by | Claude Code, from the author's opening paragraph |

Check the word limit in the MSEC 2027 call. Version A keeps the author's opening almost as written. Version B is a shorter version (target 250 words).

## Title

Beyond CLIP: A Framework for Calibrated Few-Shot Defect Detection with Structured Decision Models

Alternative, now that both models are in: Beyond CLIP: A Model-Agnostic Framework for Calibrated Few-Shot Defect Detection with Structured Decision Models

## Abstract, version A (author's opening)

Detecting manufacturing defects remains challenging despite continued advances in computer vision. For example, for highly customized or newly launched products, we lack the large training sets needed to train or tune advanced computer vision models. Furthermore, in high-capability processes, we do not observe many defects that can train traditional image classification models. Few-shot adaptation of vision models (e.g., CLIP) can help address this problem; however, it still requires 50-100 samples per class (i.e., nominal and possibly defect subclasses). In this study, we examine whether structured decision models can: (a) achieve similar classification performance with fewer examples; and (b) provide calibrated probability estimates of class assignment. To support this analysis, we propose a five-step framework: (1) audit the images for duplicates across data splits; (2) specify the task with short defect criteria and a few labeled reference images; (3) refine this specification on a fixed validation set, one change at a time, using the area under the ROC curve; (4) calibrate the probabilities on the validation set; and (5) freeze the configuration and evaluate it once on held-out test images. We apply the framework to a hosted model (JEV) and an open-weight, self-hosted model (Clef-Flash) on five datasets: metallic pans, additive-manufacturing extrusion, simulated textured surfaces, automotive assembly, and material microstructures. With two to four reference images and up to 50 validation images per class, JEV and Clef-Flash reached test balanced accuracies of 0.73-1.00 and 0.68-0.99, respectively. Compared with CLIP using its recommended 20-700 labeled images, both models were far better on automotive assembly (0.98 and 0.99 vs. 0.57), JEV was also better on pans and microstructures, and CLIP remained better on textured surfaces and extrusion. Raw probabilities were poorly calibrated (expected calibration error up to 0.23 for JEV and 0.36 for Clef-Flash); isotonic regression fitted on validation images reduced it to 0.01-0.13 and 0.02-0.10, respectively. An open-source R package that implements the framework is in development.

## Abstract, version B (shorter)

Detecting manufacturing defects remains challenging despite advances in computer vision. Customized or newly launched products lack large training sets, and high-capability processes produce few defects to learn from. Few-shot adaptation of vision models such as CLIP helps, but it still requires 50-100 samples per class. We examine whether structured decision models can (a) achieve similar performance with fewer examples and (b) provide calibrated class probabilities. We propose a five-step framework: audit the data for duplicates across splits; specify the task with short defect criteria and a few reference images; refine the specification on a fixed validation set, one change at a time, by the area under the ROC curve; calibrate the probabilities on validation; and evaluate the frozen configuration once on held-out test images. On five datasets (metallic pans, additive-manufacturing extrusion, simulated textures, automotive assembly, and microstructures), a hosted model (JEV) and an open-weight, self-hosted model (Clef-Flash) reached test balanced accuracies of 0.73-1.00 and 0.68-0.99 with two to four reference images and up to 50 validation images per class. Both far exceeded CLIP with its recommended 20-700 labeled images on automotive assembly (0.98 and 0.99 vs. 0.57); CLIP remained better on textures and extrusion. Raw probabilities were poorly calibrated (expected calibration error up to 0.23 and 0.36); isotonic regression fitted on validation reduced it to 0.01-0.13 and 0.02-0.10. An open-source R package that implements the framework is in development.

Keywords: few-shot learning; visual inspection; probability calibration; structured decision models; quality control; reproducibility.

## Sources of the numbers

- Test balanced accuracy, JEV and Clef-Flash with references: `results/final_test/method_comparison.csv` (JEV 0.725 to 1.00; Clef-Flash 0.68 to 0.99).
- CLIP with the learning sets of the CLIP paper (20 to 700 labeled images): `results/clip_paper/summary.csv`.
- Calibration, test sets: `results/final_test/calibration.csv`. Raw ECE: JEV 0.11 to 0.23, Clef-Flash 0.09 to 0.36. Isotonic ECE: JEV 0.01 to 0.13, Clef-Flash 0.02 to 0.10. Isotonic is reported for all datasets, so that no method is chosen per dataset after the test.
- 50 validation images per class: `results/optimization/<dataset>/validation_images.csv` (pan: 8 per class, because its non-test pool is small).
- Data audit: `experiment_log.md`, Setup notes.

## Notes for the author

- The CLIP comparison at its recommended learning sets uses the paper's decision rule. Against CLIP with the same 2 to 4 references, JEV matched or exceeded CLIP on all five datasets (`method_comparison.csv`).
- Pan used 8 validation images per class (its non-test pool is small), so both versions say "up to 50 validation images per class".
