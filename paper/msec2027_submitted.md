# MSEC 2027: submitted title and abstract

| Item | Value |
|---|---|
| Status | Submitted by the author (author's rewrite of the draft in msec2027_abstract.md) |
| Version | As submitted, recorded 2026-10-20 |
| Written by | Fadel M. Megahed |

## Title

Beyond CLIP: Calibrated Few-Shot Defect Detection With Structured Decision Models

## Abstract

Detecting manufacturing defects remains challenging despite continued advances in computer vision. For example, for highly customized or newly launched products, we lack the large training sets needed to train/tune advanced computer models. Furthermore, in high-capability processes, we do not observe enough defects to train traditional image classification models. Few-shot adaptation of vision models (e.g., CLIP) can help address this problem; however, these methods may still require 50–100 samples per class (i.e., nominal and possibly defect subclasses). In this study, we examine whether structured decision models can: (a) achieve similar classification performance with fewer examples; and (b) provide calibrated probability estimates of class assignment.

To support this analysis, we propose a five-stage framework for few-shot defect detection using structured decision models, which assign probabilities to predefined answers to questions about an image. The framework involves: (1) identifying duplicate images across data splits; (2) defining inspection tasks using explicit defect criteria and a few reference images; (3) refining the criteria and references on a fixed validation set using AUC; (4) calibrating the predicted probabilities using validation data; and (5) evaluating the frozen configuration on held-out test data. We evaluate the framework on five manufacturing datasets covering metallic pans, additive manufacturing extrusion, simulated textured surfaces, automotive assembly, and material microstructures.

Using only two to four reference images, a hosted decision model (JEV) achieves test balanced accuracies ranging from 0.73 to 1.00 and matches or outperforms CLIP on all five datasets when both use the same references. Compared with CLIP using its recommended 20–700 labeled images, JEV performs better on three datasets, including automotive assembly (0.98 versus 0.57). On the remaining two datasets, CLIP performs slightly better despite using substantially more labeled images. We also find that explicitly describing defect characteristics provides the largest performance improvements. While raw probability estimates are poorly calibrated (ECE of 0.11–0.23), isotonic regression reduces ECE to 0.01–0.04 on four datasets. We also examine whether the proposed framework can be used with a self-hosted, open-weight decision model rather than relying on a hosted inference API. Using CLEF-Flash (9B model) with the same frozen configurations, we obtain the resulting balanced accuracies ranged from 0.68 to 0.99 on the five datasets. Overall, our results show that structured decision models can achieve competitive defect-detection performance with very few labeled examples and improved class probability estimates.

## Claims to carry into the full paper

| Claim in the abstract | Value in the results | Source |
|---|---|---|
| JEV test BA 0.73 to 1.00 (2 to 4 references) | 0.725 to 1.00 | `results/final_test/method_comparison.csv` |
| Matches or beats CLIP with the same references on all five | microstructure tie (0.92 both); better on the other four | same file |
| Better than CLIP (recommended learning sets) on three datasets | pipe_staple 0.98 vs 0.57, pan 1.00 vs 0.91, microstructure 0.92 vs 0.85 | `results/clip_paper/summary.csv` |
| CLIP "slightly better" on two | textiles 0.975 vs 0.86; extrusion 0.82 vs 0.73 (350 per class) | same file |
| Raw ECE 0.11 to 0.23; isotonic 0.01 to 0.04 on four | raw 0.109 to 0.231; isotonic 0.007 to 0.038 (extrusion 0.128) | `results/final_test/calibration.csv` |
| Clef-Flash BA 0.68 to 0.99 | 0.68 to 0.99 | `results/final_test/method_comparison.csv` |
