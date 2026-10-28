# Box study (M7): plan of the search for an agentic strategy

Approved by fmm on 2026-10-28 (D278): "spend up to $3 to try to come up with an agentic strategy that is generalizable for defect detection -- all using the JEV API".

## Goal

Find one strategy that finds the defects of an image and puts a box on each of them, with calls to the JEV API only (`jev-1.14.0`). The strategy is the same for each dataset. Only these inputs change:

- the words for the defect (one sentence);
- one nominal reference image, and one defective reference image for each defect type.

The strategy is "agentic": it decides its next call from the answers it has.

## What the spikes showed (D272 to D277)

- One Box on the whole image points to the defect on FabriD (70% of the images), but not on AutoVI.
- With references, the Noul of a region finds the defect on tank screw (region AUC 1.00). Without references it does not (0.75).
- The top-down search (D277) cuts the false alarms. On FabriD and pipe clip, the Noul of an enlarged small crop says yes too often.
- Box answers land near the defect but often have the wrong size, so IoU 0.5 understates them. Repeat answers differ only a little (Noul 0.76 and 0.79 for the same request), so votes must come from different crops, wordings and question types, not from repeats.

## Data

The test images are used once. Nothing is tuned on them.

| Set | FabriD | Tank screw | Pipe clip |
|---|---|---|---|
| Development | 20 defective (the 10 spike images and 10 from the valid split) and 5 with no defect (valid split) | 15 defective (the 5 spike images and 10 more) and 5 good (test/good) | 15 defective (the 5 spike images and 10 more) and 5 good |
| Test (once) | 30 defective and 10 with no defect, from the test split, none of them in the spikes | 30 defective and 10 good, none in development | 30 defective and 10 good, none in development |
| References | The images of round 2 (training split) | The images of round 2 | The images of round 2 |

A held-out dataset that the development never sees would test whether the strategy generalizes. D270 names only three datasets, so this needs fmm's agreement (open question).

## Building blocks

Each block is a use of a JEV question. Every answer is cached by image and request, so the offline search can combine the answers without new calls.

**Generators (candidate boxes)**

- G1: one Box on the whole image, without and with references, with a general and a specific wording.
- G2: Box on 4 shifted crops of 80% of the image, fused into one box (an ensemble of views).
- G3: Choice over tiles: one Choice whose options are 9 tiles of the image (3 x 3, with overlap); the chosen tile is split and the Choice is asked again (2 levels). The probabilities of the tiles also give a heat map.
- G4: Noul of regions with references: the full ladder down to level 6, so that the top-down and flat searches can be replayed with any threshold and cap.
- G5: Box in a crop of 1.5 times a proposal of G3 or G4.

**Voters (scores of a candidate box)**

- V1: Noul of the crop of the candidate, with references.
- V2: agreement: the number of generators with a box whose center lies in the candidate, or that overlaps it.
- V3: the Box confidence and the Noul of the region that made the candidate.
- V4: a Choice among the best candidates ("which crop shows the defect?").

**Refiners**

- R1: Box again in a crop of 1.5 times the candidate.
- R2: edge checks: one Noul for each edge of the box ("does the defect go past this edge?"); an edge with a yes moves out by 20%.

**Image decision**

- D1: Noul of the whole image, with references; D2: the none/one/several Choice; D3: the highest score of the voted candidates.

## Stages

| Stage | Work | Budget (USD) |
|---|---|---|
| 1 | Answer bank on the development set: pass A, the generators and the image questions (G1 to G4, D1, D2); pass B, the voters and refiners for each distinct candidate (G5, V1, V4, R1, R2) | 0.6 |
| 2 | Offline search: every combination of generator set, fusion (union, weighted box fusion, at least 2 votes), voter (none, V1, V2, V1 and V2) and refiner (none, R1, R2), with thresholds tuned on the development set. No calls | 0 |
| 3 | The best strategies as an agent: one function that makes the calls in order and stops early (for example, no more calls when D1 and D2 both say no defect). Live run on the development set to check the cost and that it matches the offline result | 0.3 |
| 4 | The frozen strategy on the test sets, once; and on the held-out dataset, if fmm agrees | 1.6 |
| 5 | Findings for the record, and a proposal for the package (decisions 0.2.0) | 0 |

Each stage stops at its budget. Each call has a row in `calls/typesafe-calls.csv`.

## Measures

- Image level: AUC and accuracy of the image score (defect or not).
- Location: recall and precision of the boxes by pointing (the center of the box lies in a defect, 2% margin), by IoU 0.3 and by IoU 0.5; false boxes on images with no defect.
- Cost: calls, input tokens and USD for each image.
- Primary measure for the choice of a strategy: the F1 of pointing (recall and precision), at a cost of at most USD 0.01 for each image.

## Code

On the branch `m7-box`, in `fine_tuned_jev-box/box/` (D275): an answer cache, the blocks, the offline search and the agent. The data stay in `BOX_DATA`.

## Open questions

1. A held-out dataset for stage 4 (for example AutoVI engine wiring or underbody screw, or VisA), outside the list of D270.
