# Fair comparison and record additions: design

- Date: 2026-10-20
- Branch: `fair-comparison` (from `main` after tag `v0.0.1`)
- Status: draft, for review by fmm
- Written by: Claude Code (Opus 5.5), from the chat with fmm in session b36ad167-66f5-45af-9d6c-bf3f817c6f58
- Decisions in the record: D64 to D75

This design has two parts. Part A redesigns the experiment so that the comparison with CLIP is fair and easy to follow. Part B adds detail to the replication record: a timeline, the tags, the results and the contributions of the researchers.

In section 7, the column "Who" tells who proposed and who decided each item. "Claude call" means that Claude Code proposes the item and fmm did not decide it yet. fmm decides these items when fmm approves this document.

## 1. Intent

The study asks if structured decision models (JEV and Clef-Flash) can detect defects as well as few-shot CLIP, with fewer images in the prompt, and give calibrated probabilities. Version v0.0.1 gave a first answer, but a reader can find five weak points in it (section 3). The redesign removes them. Every method gets the same labeled images. Every method is calibrated. Every comparison is paired on the same test images.

The four goals of fmm (2026-10-20):

- (a) Show that only a few images in the prompt are necessary.
- (b) Show that the description of the defect (the prompt) makes a difference and is worth optimizing.
- (c) Make the comparison with CLIP fair.
- (d) Use a sound method from a machine-learning point of view.

A fifth goal comes from Part B:

- (e) Make the record an honest guide to the co-work with Claude Code. It must show the intellectual contributions and the decisions of the researchers (D73).

## 2. Goals, non-goals and anti-goals

Goals: (a) to (e) above.

Non-goals:

- Multi-class classification. All methods do the binary task: nominal or defective.
- New datasets or new models. The models stay `jev-1.13.0`, Clef-Flash (`Cloudflare/clef-flash`) and CLIP ViT-L/14.
- Fine-tuning of model weights.
- New test sets (see X3).

Anti-goals. The work fails if one of these is true, even if all code runs:

- A method, or the agent that writes a description, sees a test image or a test result before the one test run of its configuration.
- A claim of "few images" that hides the learning and calibration images. The paper must state the full label budget of each method.
- Claude Code writes the contributions of the researchers and nobody checks them.
- A reader cannot tell which images each method used.

## 3. What v0.0.1 did and why it changes

Version v0.0.1 is tag `v0.0.1` (commit 33ffd59).

| Item | v0.0.1 | This design |
|---|---|---|
| Labeled images, JEV and Clef-Flash | 3 to 4 references plus 100 validation images (pans: 4 + 16) | 50 per class for learning (references come from it) plus 25 per class for calibration |
| Labeled images, CLIP baseline | 50 per class (pans: 10) | the same 75 per class as JEV |
| Same images for all methods | partly: the CLIP baseline used other images (table below) | yes |
| Description chosen on | the 100 validation images | the learning images that are not references (48 per class) |
| Description written by | Claude Code, which had seen test results (figure F4) | a fresh agent that cannot see test images or results |
| Clef-Flash description | the description of JEV | its own loop |
| Threshold | tuned on raw validation probabilities | 0.5 on calibrated probabilities |
| Calibration fitted on | the same validation images that chose the description | the separate calibration set |
| CLIP calibrated | no | yes |
| Metrics | balanced accuracy and AUC | the seven metrics of D68, AUC and calibration metrics |

Images of the CLIP baseline sets that JEV also used in v0.0.1 (references or validation):

| Dataset | Shared images |
|---|---|
| Pans | 20 of 20 |
| Pipe staple | 56 of 100 |
| Microstructure | 48 of 100 |
| Extrusion | 19 of 100 |
| Textiles | 11 of 100 |

The five weak points of v0.0.1:

1. The calibration used the images that chose the description. A description that separates these images well looks better on them than on new images. Thus the calibrated probabilities were too confident.
2. The label budgets were different: 103 to 104 labeled images for JEV, 100 for the CLIP baseline, and mostly different images.
3. Claude Code wrote the descriptions after it had seen test results.
4. Clef-Flash used a description that was optimized for JEV.
5. CLIP was not calibrated, and the report gave only two metrics.

The results of v0.0.1 stay in the record and in the tag. The paper reports this design as its main analysis (X14).

## 4. Data

### 4.1 Test sets

The test sets do not change. They are balanced:

| Dataset | Nominal | Defective |
|---|---|---|
| Pans | 39 | 39 |
| Extrusion | 100 | 100 |
| Textiles | 100 | 100 |
| Pipe staple | 50 | 50 |
| Microstructure | 225 | 225 |

Each new configuration has one test run. A guard refuses a second run, as `scripts/evaluate_frozen.R` does now. The v0.0.1 test runs used these test sets once. The paper states this (X3).

### 4.2 Learning set L

L is the CLIP baseline set of each dataset (D70). The file is `results/clip_paper/learning_sets.csv`.

| Dataset | Setting | Nominal | Defective |
|---|---|---|---|
| Pans | `pan_10` | 10 | 10 |
| Extrusion | `extrusion_50` | 50 | 50 (25 over, 25 under) |
| Textiles | `textiles_50` | 50 | 50 (25 local, 25 global) |
| Pipe staple | `pipe_staple_50` | 50 | 50 (missing) |
| Microstructure | `microstructure_50` | 50 (Uniform) | 50 (6 each for Band_high, Band_low, Band_medium, Bimodal_high, Bimodal_low; 5 each for the other 4 types) |

Impact: the CLIP baseline already learned from L, so its saved test predictions stay valid. Only its calibration is new. Most v0.0.1 references are in L.

### 4.3 Calibration set C

C has 25 images per class, from the non-test images that are not in L. The defective images are stratified over the defect types. The seed is 202611.

| Dataset | Images left after L and test | C |
|---|---|---|
| Pans | none | none (see 4.4) |
| Extrusion | 314 nominal, 731 defective | 25 + 25 |
| Textiles | 850 + 850 | 25 + 25 |
| Pipe staple | 88 nominal, 17 defective | 17 + 17 (all defective images that are left) |
| Microstructure | 25 nominal, 175 defective | 25 + 25 (all nominal images that are left; 3 images for each of 7 types, 2 for each of 2 types) |

No image in C has a byte-identical copy (MD5) in L or in the test set (checked on 2026-10-20). C is balanced, so a threshold of 0.5 on calibrated probabilities aims at balanced accuracy.

Near-copies (Claude call, from the builder check). Extrusion frames come from video, so a C frame can nearly copy an L frame. CLIP scores an image by its highest similarity to L, so such a frame gets a very confident score, and Platt fitted on C becomes too steep for CLIP. Thus the draw of C excludes the near-copies of L and test images. It uses the dHash check of `experiments/check_leakage.R`, with the same distance limit. The draw reports how many images it excluded. Open item O3 (near-copies between L and the test set) stays open. The paper states it as a limitation of the CLIP baseline on extrusion.

### 4.4 Pans

Pans have only 20 non-test images, and all 20 are in L. Thus pans have no C and no description loop:

- JEV and Clef-Flash use the generic description (section 5.3).
- They calibrate on the images of L that are not references. These images choose nothing, so the calibration is not optimistic.
- The CLIP baseline calibrates on leave-one-out scores in L. Near-identical pan photos make these scores optimistic (v0.0.1 found this). The paper states it.
- CLIP with the same references calibrates on the images of L that are not references, as JEV does. CLIP zero-shot calibrates on all 20 images of L (Claude call).

### 4.5 Label budget

| Method | Learning | Calibration | Labeled images per class |
|---|---|---|---|
| JEV and Clef-Flash | L (k references; the rest chooses the description) | C | 75 (pans 10, pipe staple 67) |
| CLIP baseline | L | C | 75 (pans 10, pipe staple 67) |
| CLIP, same references | the k references of JEV | C | k + 25 |
| CLIP, zero-shot | none | C | 25 |

This table replaces table T5. For goal (a), the paper separates two numbers:

- The images that the model sees for each test image: k per class.
- The labeled images that the method needs in total: 75 per class.

## 5. Methods

### 5.1 Common settings

- Binary task: nominal or defective. The event class for all metrics is defective.
- Images: center crop, maximum size 768 px, no upscaling. This is the frozen v0.0.1 setting of all datasets.
- Models: `jev-1.13.0` (TypeSafe API), Clef-Flash (local sglang server), CLIP ViT-L/14 (local GPU). The settings of each model stay as in v0.0.1.

### 5.2 References

- k references per class come from L. The main value is k = 2, so a call holds 4 references.
- The reference curve uses k = 0, 1, 2 and 4.
- The sets are nested: the references at k = 1 are in the set at k = 2, which is in the set at k = 4.
- Nominal references: a random draw from the nominal images of L.
- Defective references: one image per defect type, in a random order of the types, until there are k images. Datasets with one defect type (pans, pipe staple) take a random draw.
- Seed: 202610. JEV, Clef-Flash and CLIP use the same references.

Impact: v0.0.1 used 3 to 4 references in total (1 to 2 nominal, 2 to 3 defective). At k = 2, every dataset has 2 + 2. Microstructure has 9 defect types, so at k = 2 the references show only 2 of them. This is the honest cost of few references, and the curve to k = 4 measures it.

### 5.3 Description loop

The loop runs for JEV and for Clef-Flash separately, on all datasets except pans.

- Design images: the images of L that are not references at k = 2 (48 per class).
- Start: the generic description of `classify_image()`. Normal: "No visible manufacturing defects; the part appears conforming." Defective: "At least one visible manufacturing defect or anomaly."
- Candidates: at most 6 per dataset and model, including the start. A candidate changes only the two description texts. The references (k = 2), the image size and the crop do not change.
- Score: ROC AUC on the design images.
- Keep rule: a candidate replaces the current best if its AUC is at least 0.02 higher. The final description is the last one kept.
- Agent: a fresh Claude Code agent, one for each model, so that the Clef-Flash agent does not see JEV results. The agent works in a sandbox folder that holds only:
  - the design images, with their class and defect type;
  - the generic description;
  - a scoring script;
  - the loop instructions, in the style of `docs/GOAL.md`.

  The agent can look at the design images. It cannot read the test images, C, `results/`, `experiment_log.md`, the v0.0.1 criteria files in `experiments/`, the paper or the analysis document.
- Knowledge: the loop is blind (D74). The instructions carry no dataset knowledge from the researchers. The agent gets the dataset name, the class and defect-type names (from the folder names), the design images and the generic description. It does not get the hypotheses of `docs/GOAL.md`. Thus goal (b) claims: an automated loop on about 48 images per class finds a better description, without expert input.
- People: the researchers do not edit a description during the loop. They approve the loop instructions before it starts.
- Log: for each candidate, the record keeps its text, its AUC, the mean score per defect type, the reason that the agent gave, and the ID of the agent transcript.
- Report: the design AUC (optimistic, because the loop chose on these images) and the AUC on C (not optimistic) of the final description.

Noise of the keep rule, from v0.0.1 validation predictions (paired bootstrap, 2,000 resamples, no API calls):

| Change | AUC change | Wrong decision at 50 per class | Wrong decision at 24 per class |
|---|---|---|---|
| Microstructure, grain-color criteria | +0.16 | 0% (missed) | 0.4% (missed) |
| Extrusion, over/under criteria | +0.10 | 5% (missed) | 13% (missed) |
| Textiles, weave criteria (a tie) | +0.01 | 9% (kept) | 16% (kept) |
| Textiles, extra references (a tie) | +0.01 | 2% (kept) | 8% (kept) |

With 48 design images per class, the error rate of the loop is near the 50-per-class column.

### 5.4 Calibration and decision

- Each configuration scores C once.
- Platt scaling, fitted on C, gives the calibrated probability.
- The decision is defective when the calibrated probability is 0.5 or more. No method tunes a threshold.
- Platt uses the smoothed targets of Platt (1999), as `R/calibration_functions.R` does now, so a C that separates perfectly still gives a finite fit.
- Sensitivity analysis: isotonic regression, fitted on C.
- Continuity: the raw probability at 0.5. For CLIP, this is the rule of the CLIP paper.

### 5.5 CLIP

| Variant | Learning images | Calibration | Why |
|---|---|---|---|
| CLIP baseline | L (the CLIP baseline set) | Platt on C (pans: leave-one-out on L) | the benchmark (goal c) |
| CLIP, same references | the k references of JEV, k = 1, 2, 4 | Platt on C | the same few images as JEV |
| CLIP, zero-shot | none (generic text prompts, as in v0.0.1) | Platt on C | no labeled images in the model |
| CLIP, zero-shot with the final descriptions (optional) | none (the descriptions of the JEV loop as text prompts) | Platt on C | does a better description help CLIP too? |
| CLIP, paper rule | L | none (raw score at 0.5) | continuity with the CLIP paper |

The CLIP text encoder reads at most 77 tokens. The optional variant must cut longer descriptions at 77 tokens and report this.

### 5.6 Configurations

| Model | Description | k per class | Datasets |
|---|---|---|---|
| JEV | final description of the loop | 0, 1, 2, 4 | 4 (pans: generic) |
| JEV | generic | 0, 2 | 4 |
| Clef-Flash | final description of its loop | 0, 1, 2, 4 | 4 (pans: generic) |
| Clef-Flash | generic | 0, 2 | 4 |
| CLIP | the variants of 5.5 | as in 5.5 | 5 |

Pans have 4 JEV configurations and 4 Clef-Flash configurations, because their only description is the generic one.

At k = 4, a call holds 9 images. Before the runs, a check confirms that the TypeSafe API and the Clef-Flash server accept 9 images in one call. In v0.0.1, JEV accepted 11 (trial 10). If Clef-Flash does not, its curve stops at k = 2, and the paper states it (Claude call).

## 6. Metrics and paired comparisons

### 6.1 Metrics

Each configuration reports these metrics on C and on the test set:

| Metric | yardstick function |
|---|---|
| Accuracy | `accuracy()` |
| Balanced accuracy | `bal_accuracy()` |
| Sensitivity (recall) | `sens()` |
| Specificity | `spec()` |
| Precision | `precision()` |
| F1 | `f_meas()` |
| MCC | `mcc()` |
| ROC AUC | `roc_auc()` |
| Brier score | `brier_class()` |
| Log loss | `mn_log_loss()` |
| ECE (10 equal bins) | a short function of our own; yardstick has none |

The factor level `defective` comes first, so yardstick uses it as the event (`event_level = "first"`). Otherwise sensitivity, precision and F1 describe the nominal class.

### 6.2 Which metric decides

- The loop uses AUC. The description must rank defective images above nominal images. Calibration sets the cut-off later. A thresholded metric on 48 images per class moves in steps of about 0.02 and mixes the ranking with the cut-off.
- No metric chooses a threshold. The threshold is 0.5 on calibrated probabilities.
- The headline metrics are balanced accuracy and MCC. Balanced accuracy does not depend on the prevalence. MCC uses all four cells of the confusion matrix. F1 and precision ignore true negatives, and they change when the other class is the positive class. In quality control, a missed defect and a rejected good part both cost money.
- All test sets are balanced, so accuracy equals balanced accuracy on the test sets. The tables show both.

### 6.3 Paired comparisons

These comparisons are fixed before the test runs. Each one applies to each dataset and to each decision model (JEV, Clef-Flash):

| ID | Comparison | Goal |
|---|---|---|
| P1 | Decision model (final description, k = 2, calibrated) against CLIP baseline (calibrated) | (c) |
| P2 | Final description against generic description, both at k = 2 | (b) |
| P3 | k = 2 against k = 0, both with the final description | (a) |

Method:

- A paired bootstrap over the test images, stratified by class, 2,000 resamples. It gives the difference and its 95% interval for balanced accuracy, MCC and AUC.
- An exact McNemar test on the correctness of each image, as a second check. The p-values are Holm-adjusted within each model: 14 tests (P1 to P3 for 4 datasets, P1 and P3 for pans).
- The reference curve (k = 0, 1, 2, 4) is a figure, with paired intervals against k = 0.
- Pans have no P2, because they have no loop.

## 7. Decisions and their impacts

| ID | Decision | Why | Impact | Who |
|---|---|---|---|---|
| X1 | L is the CLIP baseline set of each dataset | It is the budget of the CLIP paper (50 per class; pans 10). It was drawn before this design. | The CLIP baseline test predictions stay valid. JEV and Clef-Flash get new references and new design images. | proposed by Claude, decided by fmm (D70) |
| X2 | One separate C of 25 per class, the same for all methods | Calibration must use images that chose nothing. | 75 labeled images per class for every method (pans 10, pipe staple 67). The calibration is not optimistic. | fmm (D69) |
| X3 | Keep the test sets. The description agent is blind. The paper states that v0.0.1 used the test sets once. | New test sets break the comparison with the CLIP paper, and pans have no spare images. | The researchers know the v0.0.1 test results; the agent that writes the descriptions does not. | Claude call |
| X4 | Pans have no description loop | 20 images cannot give references, design images and calibration images. | The loop result (goal b) rests on 4 datasets. | Claude call |
| X5 | Platt scaling is the calibration; isotonic is a sensitivity analysis | Platt has 2 parameters. With 25 images per class, isotonic overfits and makes ties. | The calibrated results are stable. The isotonic results are in an appendix table. | Claude call |
| X6 | Decision at 0.5 on calibrated probabilities, with no threshold search | One rule for all methods. C is balanced. | No method tunes a cut-off. v0.0.1 thresholds are not used. | Claude call |
| X7 | The loop uses AUC, keeps a change at +0.02, and stops after 6 candidates | AUC is the least noisy metric on 48 images per class. The cap limits overfitting and calls. | Wrong keeps of ties: 2 to 9% (section 5.3). | Claude call |
| X8 | k = 2 per class is the main setting; the curve uses k = 0, 1, 2, 4 | The curve shows how many images the model must see (goal a). | Every dataset gets 2 + 2 references. Microstructure shows only 2 of 9 defect types at k = 2. | Claude call |
| X9 | Generic and final descriptions at k = 2 and k = 0 | This isolates the effect of the description (goal b). | 2 more configurations for each model and dataset. | Claude call |
| X10 | Clef-Flash gets its own loop and its own agent | In v0.0.1, Clef-Flash used a description that was made for JEV. | Clef-Flash results measure the model, not a transfer of the prompt. | Claude call |
| X11 | Calibrate all CLIP variants on C; add CLIP with the same references; the zero-shot variant with the final descriptions is optional | Same calibration for all (D67). | CLIP results change from the 0.5 rule to calibrated results. The paper rule stays for continuity. | fmm (D67); variants: Claude call |
| X12 | Report the metrics of 6.1; the headline is balanced accuracy and MCC | D68 asks for all common metrics. | Wider tables. The paper gives balanced accuracy (MCC); the other metrics go in the long table. | fmm (D68); headline: Claude call |
| X13 | Paired comparisons P1 to P3, fixed before the test runs | D71. | One forest figure for each comparison. | proposed by Claude, decided by fmm (D71) |
| X14 | The paper reports this design. v0.0.1 is the exploratory phase in the record. | The new design answers goals (a) to (d). | The v0.0.1 tables and figures leave the paper. The tag and the record keep them. | Claude call |
| X15 | R code: 80 to 90% tidyverse, stringr, yardstick, simple | D66. | The analysis document, the new scripts and `R/calibration_functions.R` change. The JEV client (`R/industrial_defect_classifier.R`) keeps its behavior, and only its style may change. | fmm (D66); scope: Claude call |
| X16 | The loop changes only the description text | It isolates the effect of the text. The reference curve covers the references. | v0.0.1 also tried image sizes and reference sets; this design does not. | Claude call |
| X17 | A new budget row for about 10,500 JEV calls, at most USD 3 | Section 8. | No paid call before fmm approves the row. | Claude call (needs approval) |

## 8. Paid calls

Only JEV calls cost money. Clef-Flash and CLIP run on the local GPU.

| Step | Calls |
|---|---|
| Description loop: 4 datasets, up to 6 candidates, 96 design images | up to 2,304 |
| Calibration: 6 configurations on C for 4 datasets (184 images), plus 4 pan configurations (66 images) | about 1,170 |
| Test: 6 configurations for 4 datasets (950 images), plus 4 pan configurations (78 images) | about 6,012 |
| Total | about 9,490 |
| With 10% for retries | about 10,500 |

The record gives a price of about USD 0.042 per million input tokens (`calls/README.md`). A call with k = 4 sends more images, so the estimate uses 4,000 tokens for each call. 10,500 calls are about 42 million tokens, or about USD 1.80. The proposed row is 10,500 calls and at most USD 3. Each call goes in `calls/typesafe-calls.csv`, with the per-call log of `JEV_CALL_LOG`.

## 9. Presentation

The analysis document on the branch changes to this order:

1. Data: L, C and the test sets, with the label budget table.
2. Methods: the protocol of section 5, in plain words.
3. Description loop: for each dataset and model, the candidates with their design AUC, and the final AUC on C.
4. Main results: one table with all metrics. The interactive view keeps the dot chart and the glyphs against the CLIP baseline.
5. Paired comparisons: one forest figure each for P1, P2 and P3, with the differences and the 95% intervals.
6. Reference curve: balanced accuracy and AUC against k.
7. Calibration: reliability diagrams, and ECE before and after Platt.
8. v0.0.1: a short section that links the tag and states what changed and why.
9. Appendix: isotonic results, all loop candidates, the CLIP variants.

The figure and table style stays as in v0.0.1: theme_bw, Dark2, Outfit and Cabin, colored subtitles, DT tables, PNG, PDF and SVG files.

## 10. Part B: the replication record

### 10.1 What the record has now

The record site (skill `replication-materials` 1.1.0) has these pages:

- Home: status, pages, milestones, decisions by decider.
- Records: a list of documents.
- Decisions: ID, date, decision, proposed by, decided by, how, evidence, source.
- Process: events by stage and date.
- Progress: milestones, open items, paid calls.
- Analysis.

The record has 73 decisions and 16 process events.

The EXPERTA record (https://project.expertadoe.app/records/index.html) shows more detail:

- a grid of decisions by topic and decider, and a chart of decisions per day;
- a "Basis" and a "Cost if wrong" for decisions;
- documents with their phase, size (tasks, rulings), status and links;
- a "Now" section (production commit, branches, open pull requests);
- completed work by plan;
- a timeline of the plans.

It has no releases, no results and no split of human and AI contributions.

### 10.2 Additions

| ID | Addition | Content | Where |
|---|---|---|---|
| B1 | Releases | New record file `project/releases.md`: Tag, Date, Commit, Summary, Decisions (an ID range, for example D1 to D63), Results. A Releases page shows each tag, with links to the GitHub tree and to the comparison with the tag before it, and lists the decisions of its range. The build does not read git: the links come from the tag names, and the range comes from the row. The first row is `v0.0.1`. | skill, and the rows in this record |
| B2 | Results | New record file `project/results.md`: ID, Release, Result, Value, Source (a file in the repository), Decisions, Superseded by. Each headline result has a version. When a later result replaces it, the row stays and names its successor. A reader can then see how the headline results changed, for example from "best CLIP result on the test set" (D58) to "CLIP baseline at 50 per class" (D62), and then to this design. | skill, and the rows in this record |
| B3 | Timeline | A new page that shows the events in order of time: the tags, the changes of stage, the milestones and the decisions. Decisions of the researchers show with their text. Rulings and decisions of Claude Code show as counts. A bar for each stage shows when it started and ended (from `process.md`). All 73 decisions of this record have the same date (2026-10-20), so a timeline by day says little. Thus B5 adds a time to each decision. | skill |
| B4 | Contributions | A new page with: a grid of "Proposed by" against "Decided by"; every decision that a researcher proposed, with the quote; every proposal of Claude Code that a researcher decided; the decisions that a later decision replaced (column Replaces); the corrections; and a short text by the researchers in a new optional file `project/contributions.md`. Claude Code can draft that text. The file states who wrote and who approved it. There is no column for refused proposals: the record has a row only for a decision that was made. | skill; the text by fmm and yjc |
| B5 | Decision detail | Four optional columns in `decisions.md`: Time (UTC), Topic (a fixed list in `site.config.json`), Impact (what changed because of the decision, or the cost if it is wrong) and Replaces (the ID of an earlier decision). New rows get all four. For D1 to D73, Claude Code fills Time from the time stamp of the chat message that holds the quoted words; when no message matches, Time stays empty. Claude Code also fills Topic; fmm checks it. The Decisions page gets the grid by topic and the chart over time. | skill, and the rows in this record |
| B6 | Records detail | The Records page shows the milestone, the size (tasks and rulings of ledgers) and links to the file on GitHub. | skill |
| B7 | Now | The Home page shows the latest tag, the milestone at `now` and the open items. It does not show branches: the site builds only at a push to `main`, so a list of branches goes out of date. | skill |

The site features (B1 to B7) go into the skill in `fmegahed/claude-skills` as version 1.2.0, so other projects get them too. The new files and columns are optional. Old records stay valid, and `format_version` stays 1. This project then takes 1.2.0 with the Update procedure of the skill.

### 10.3 Honesty rules for the record

- The record shows the errors of Claude Code that the researchers found, and the decisions that later decisions replaced. It does not hide them.
- The record shows the 100 JEV calls that Claude Code made by mistake (`calls/README.md`), and it shows that v0.0.1 used the test sets.
- A decision of a researcher has the words of the researcher as evidence. Claude Code does not paraphrase it.
- `project/contributions.md` is not complete until a researcher approves it.
- Claude Code back-filled 37 decision rows (D2 to D38, How `classified`) from the transcript. No person checked them. The Decisions and Contributions pages show these rows with the mark "not checked by a person" (D75). Claude Code prepares a short checklist. fmm, and yjc if yjc wants, check the rows before the tag `v0.1.0`. Each correction goes in the Corrections table, and the mark goes away for each checked row.

## 11. Order of work

1. fmm approves this design. Claude Code writes the plan.
2. Part B: skill 1.2.0, then the update of this record and the back-fill (releases, results, topics). The redesign then goes into the record in the new form.
3. Part A, code with no paid calls: draw C and the references, the sandbox for the loop, yardstick metrics, calibration, paired comparisons, and the guard for the test runs.
4. fmm approves the loop instructions and the budget row (X17).
5. The loops (JEV and Clef-Flash), then calibration, then the one test run of each configuration. CLIP runs on the local GPU.
6. The analysis document, the README and the record. Merge `fair-comparison` into `main` with a pull request. Tag `v0.1.0` on `main` after the merge.

Git rules (Claude call, from the builder check). CLAUDE.md and the skill do not agree on where records go when code is on a branch. CLAUDE.md is the instruction of the project, so it applies:

- Record-only commits go to `main` and Claude Code pushes them without asking. The record site then always shows the current state. Decision IDs cannot collide between two branches.
- Code goes to `fair-comparison`. The branch takes the record commits by a merge of `main`.
- The update of the skill files in this project (`.replication/` and the workflow) is not record-only. Claude Code asks before that push, and before a push to `fmegahed/claude-skills`.
- Part B goes to `main` before Part A, because it is record and skill work only.

## 12. Left to the builder

- File names, script names and the structure of the scripts.
- The mechanics of the sandbox for the loop agent, in the limits of section 5.3.
- The layout of the new pages and figures, in the style of the current ones.
- The text of the loop instructions, in the style of `docs/GOAL.md`. fmm approves it before the loop starts.

## 13. Claude calls for fmm to check

- Section 7: X3 to X10, the headline of X12, the CLIP variants of X11, the scope of X15, and X14, X16 and X17.
- From the builder check: the exclusion of near-copies from C (4.3); the calibration of the CLIP variants on pans (4.4); the check of 9 images per call (5.6); the Holm family of 14 tests (6.3); the time and the ID range for the timeline (B1, B5); no list of branches on the Home page (B7); the git rules (section 11).

Decided by fmm after the builder check: the loop is blind (D74), and the back-filled rows show with a mark until a person checks them (D75).

## 14. Addendum: execution time (D78)

fmm asked on 2026-10-21 to record execution time. Before this addendum, only the paid JEV calls had a time (latency in the call log), and the loop log had a time stamp for each candidate. CLIP had no timing, and the score files had no time.

- Each decision-model score file gets a column `elapsed_ms`: the wall time of the call for that image, with image preparation.
- Each scoring run (design, calibration, test) adds one row to `results/fair/timing/runs.csv`: model, description, k, dataset, split, number of images, start and end (UTC), seconds and hardware ("TypeSafe API" or the local GPU name).
- Clef-Flash calls go to their own log, `results/fair/timing/clef-calls.csv`, not to the TypeSafe call log. The budget counts only JEV rows. (Before this change, Clef-Flash calls went into the TypeSafe log and counted against the JEV budget: a bug found while answering D78.)
- CLIP: a separate timing run on the test images measures the time per image of each variant (encoding and scoring) on the local GPU. It writes `results/fair/timing/clip_timing.csv` and does not change the CLIP score files (they are one-time).
- `scripts/fair_evaluate.R` writes `results/fair/summary/timing.csv`: the median and the 25th and 75th percentiles of the time per image, for each method and dataset, and the total time of each step.
- The analysis document gets a section "Time and cost": time per image for each method, the total time of each step, and the JEV calls and cost from the call log. The times come from different hardware, so the document names the hardware and does not rank the methods on time alone.
- Cost (D79): the JEV call log already holds, for each call, the request ID, the input and output tokens, the latency and an estimated cost (input tokens times USD 0.042 per million, the price in `R/industrial_defect_classifier.R`). `results/fair/summary/timing.csv` also gets the number of calls, the tokens and the estimated cost of each JEV configuration (from the purpose of each log row). After the runs, the record compares the logged total with the usage that the TypeSafe account shows.
