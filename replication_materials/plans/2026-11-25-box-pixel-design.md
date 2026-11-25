# Plan: pixel masks and better localization from Jev (Box study M7, pixel stage)

## Context

The D336 test (2026-11-25) showed that `locate()` is not better than the old top-down search on real images, and that all Box strategies are weak on AutoVI and FabriD.

fmm asked for:
- a swarm of agents to find how Jev's Box results can be improved (theory, the CV literature, tests of hypotheses);
- a plan made in plan mode;
- an end to the mixing of segmentation and detection evaluation;
- if possible, a way to "teach Jev with a box to do segmentation" (pixel masks).

Six agents (3 exploration, 3 design) did the work below with no paid call. The literature is used here for method design only, not for paper text (D260 stays).

## What the swarm found

1. **The mixing is real.**
   - Every localization number so far is a box measure (center in the truth box with a 2% margin, box IoU, F1), scored against boxes drawn around pixel masks (AutoVI) or polygons (FabriD).
   - Nothing is scored at the pixel level.
   - A "hit" can land on a pixel with no defect: inside a tank-screw ring, beside a thin FabriD polygon, or inside engine-wiring truth boxes that cover more than half of the image.
   - `mask_truth()` also loses the defect type, because AutoVI codes the type in the pixel value (255, 254, ...) and our code thresholds at > 127.
2. **Pixel truth exists for all datasets.**
   - FabriD labels are polygons: 2,502 objects, none a plain box.
   - AutoVI has one PNG per defect, plus `defects_config.json` with the sPRO saturation values.
3. **The ceiling for a box, scored as a mask.** A perfect tight box reaches a median pixel IoU of only FabriD .42, tank .37 (ring masks), pipe .61, engine .50. Our boxes reach .03–.20.
4. **Location is the main limit, not box shape.**
   - A perfect segmenter inside L's box would reach IoU = L's pixel recall: .28 / .24 / .57 / .15.
   - So a mask step can help mostly on pipe clip.
   - How L fails:
     - pipe: boxes about 2× too big and shifted;
     - tank: boxes too small, inside the ring;
     - engine: boxes too small and shifted;
     - FabriD: 24% of defective images get no box;
     - good images: boxes on 70–100% of them, except tank.
   - Shrinking boxes does not help (dev).
5. **Jev's capabilities.**
   - The question types are noul, choice, score and box (one box, no "not found"). There is no point, mask or multi-box type.
   - Cost is about 353 + 0.00253 × pixels tokens per image, plus about 40 per question, at USD 0.042 per million tokens. A 280 px crop costs about USD 0.00002, so dense probing fits the D278 limit of USD 0.01 per image.
   - Earlier probes: the window Noul ranks windows well (AUC .93 FabriD, .92 pipe, .75 tank). Sending 280 px windows does as well as 768 px.
6. **Answers already saved, which make free maps possible:**
   - G4 window Nouls at 5 sizes for the 65 D278 dev images;
   - every window TD asked on the 158 D336 images;
   - L's 9 tile probabilities and 4 boxes.
7. **Literature with ideas we can use:**
   - WinCLIP: window scores become pixel maps.
   - GPT-4V-AD: API only; numbered superpixels scored by the VLM; superpixels beat SAM regions, which beat a grid.
   - SAA+ and ClipSAM: boxes or points prompt SAM, and the masks are fused with a coarse map.
   - AnomalyDINO: DINOv2 patch kNN against a few nominal images; the strongest published few-shot pixel numbers.
   - HQ-SAM: SAM masks degrade fast with loose boxes.
   - Zoom-Refine: crop and ask again.
   - The AutoVI official evaluation: AU-sPRO at FPR 0.05, and image AUROC as the map maximum.
   - No zero-shot or few-shot results on AutoVI have been published.
8. **Machine.**
   - RTX 5000 Ada, 32 GB.
   - The conda env `eagerprep` has torch 2.11+cu128 and transformers 4.57.6 with SAM, SAM 2, SAM-HQ and DINOv2 classes. No weights are cached.
9. **Fresh images for a new one-time test:**
   - FabriD 228 defective / 78 good;
   - tank 49 / 303;
   - pipe 83 distinct / 180;
   - engine (fastening and multiple) 288 / 275;
   - underbody_pipes 180 / 161, never used.
   - 60 engine-wiring test images have the same bytes as train/good images, so the nominal banks need an MD5 check.

**Theory behind the plan.** A mask needs two things:
- **localization** (where);
- **delineation** (which pixels).

A Box answer gives 4 numbers and does both badly. Jev gives a few calibrated bits per question, so a mask needs either:
- many cheap questions: window maps for location, segment questions for the outline; or
- a local delineator (SAM) that Jev steers and checks.

Finding 4 says to fix localization first and delineation second.

## Design

### A. Three-level evaluation (fixes the mixing)

| Level | Input | Headline | Also reported |
|---|---|---|---|
| Image | one declared image score (map methods: the map maximum, as in AutoVI) | image AUROC | AP, F1-max; Brier and ECE for probability scores, as description only |
| Detection | boxes with scores; truth = one tight box per AutoVI mask file or per FabriD polygon | box AP at IoU 0.3 (greedy matching; a box on a good image is a false positive) | AP at 0.1 and 0.5; false boxes per good image; pointing game against the **mask** (a hit within 15 px of a mask pixel); old pointing F1 as a legacy column only |
| Pixel | real-valued map at full size | **AU-sPRO at FPR 0.05**, with the AutoVI `defects_config.json` (FabriD: a generated config, one channel per polygon, relative saturation 1, which equals AUPRO) | AU-sPRO at 0.3; pixel AUROC; pixel F1-max; IoU and Dice at a threshold fixed on dev |

- **Box-only methods** become maps in two ways:
  - box-as-mask: the maximum confidence of the boxes that cover a pixel;
  - box-vote: the sum of those confidences, divided by the number of requests.
- **Map methods** become boxes from the connected parts above the dev threshold.
- **Reference rows in each table:**
  - the truth box as a mask (the box ceiling);
  - a constant map (chance: AU-sPRO@0.05 = 0.025).
- **R port of sPRO/AUPRO, checked against the official code.**
  - The official code is github.com/phcarval/autovi_evaluation_code (BSD-3), pinned by commit and run once in its own conda env with `python -I`.
  - The port must match within 0.005 at each FPR limit, and image AUROC exactly, on:
    - L box-as-mask maps for tank and engine (several channels, plus the absolute 800 px blue_hoop rule);
    - FabriD with the generated config;
    - perfect, constant and seeded random maps.
  - The port uses per-image histograms, so the bootstrap stays fast.
  - Maps are single-channel 16-bit PNGs in the AutoVI layout under `C:/Users/megahefm/box_data/maps/` (outside git); git keeps their MD5 list, the histograms, `boxes.csv` and `image_scores.csv`.

### B. Images

- **Development pool:** 223 images = the D278 dev images (65) and the D336 test images (158, now seen). Pilots use stratified subsets of 40–80 images (seed 2040).
- **Fresh one-time final test** (seed 2041), with these exclusions:
  - the MD5 of any image sent before;
  - dHash distance ≤ 4 to any sent image, or to another image in the set (this removes the 13 pipe_clip byte twins);
  - FabriD images within 30 s, by file-name timestamp, of a sent image.
- **Final test sizes:**
  - FabriD 60 defective + 40 good;
  - tank all eligible (about 49) + 40;
  - pipe 60 + 40;
  - engine 60 + 40;
  - **underbody_pipes 60 + 40 as the held-out class** (no call so far; references from its test split, seed 2042);
  - underbody_screw all 18 + 40, descriptive only.
- **Nominal banks** (registered references, DINOv2 banks) come from train/good, never from a dev or test image, and are checked by MD5.

### C. Methods and hypotheses, in stages (dev only; a decision at each stage)

**Dev rule for "keep":** a paired bootstrap over images (2,000 resamples, seed 2031). Keep a change when the 95% interval of the pooled AU-sPRO@0.05 gain lies above 0 and no dataset falls by more than 0.03. Image AUROC must not fall by more than 0.02. Dev numbers are optimistic (D336 showed this), so only the final test decides.

**Stage 0: evaluation and free baselines (0 calls)**
- Build the pixel truth: mask channels by pixel value, and rasterized FabriD polygons.
- Write the evaluation code and check the port.
- Re-score L, TD and Z on D336, and T, TD and Z on D303 dev, at all three levels.
  - Marked post hoc, with no verdict; H16 stays true for its box measure.
- H0, free maps from the saved answers:
  - boxes as box-as-mask and box-vote maps, and as Gaussians;
  - L tile maps;
  - G4 and TD window maps;
  - a check for a pull toward tile t1, because Choice leans to its first option.
- Choose how window scores spread to pixels.

**Stage 1: local models on the GPU (0 calls)**
- Use `eagerprep`'s Python as it is (assert the versions; no installs).
- Download the weights to `C:/Users/megahefm/box_data/hf` at fixed revisions and store their sha256.
- R calls Python with `system2(python, c("-I", "box/python/boxseg.py", task, manifest))`.
- **H1 (SAM oracle):** SAM ViT-B, SAM 2.1 and HQ-SAM prompted with the **truth** box, and with the truth box made 1.5× larger and shifted by 0.2. This is the ceiling of a mask step. Go on with a mask step only for datasets where the gain over the box ceiling is ≥ 0.10.
- **H2 (Jev box → SAM):** the saved L boxes and box centers as SAM prompts (box; box + center point; box ×1.5 + negative points; center only).
  - For tank, a mask transfer: SAM segments the screw in the nearest good image, and that mask is pasted in, because the cameras are fixed and the defect is an absent object.
- **H3 (AnomalyDINO alone):** DINOv2-S/B patch kNN against k = 1/4/16 good images, with a "local" variant (nearest neighbour only near the same position). FabriD compares each patch with other patches of the same image.
  - This is the **no-Jev baseline**: it shows what Jev adds.
- **H4a:** the DINO map gated by L's p(defect) (free).

**Stage 2: localization with pure Jev (paid, about 680 calls, about USD 0.42)**
- **H5 (gate G):** one Noul: "Is there {one} in `inspection_image` that is not in `reference_image`?" The reference is the nearest train/good image (FabriD: the existing references).
  - Compare with L's 1 − P(none) and Z's Noul on image AUROC.
- **H6 (registered window ladder):** windows at 5 sizes. Each window gets a Noul against the crop at the same place in the nearest good image (±8 px search). Spread the scores to a map, and multiply by G^γ.
  - Pilot on the 40 AutoVI D278 images first (the saved G4 answers are the same windows without the reference); then all 223 images.

**Stage 3: "teach Jev with a box to segment", two mask steps head to head (paid, about 620 calls, about USD 0.26)**
- **H7 (pure Jev, outlined segments):**
  1. Crop 1.5× around the map peak or the Jev box.
  2. Split the crop into about 30 SLIC-like segments (kmeans on x, y and Lab color, seeded).
  3. Draw each segment in magenta, with the rest dimmed, at 448 px. One Noul each: "Is the area inside the magenta outline part of {the}?"
  4. Paint the segment probabilities onto the map. Variant: a single overlay with numbered segments (GPT-4V-AD style), to cut cost.
- **H8 (hybrid, Jev picks the SAM mask):**
  1. Take up to 4 distinct SAM masks from the box/point prompts.
  2. Draw each one outlined on a 560 px crop.
  3. One Choice "Which picture outlines {the}?" (m1–m4 plus none). The state holds a reference crop with its **truth mask outlined**: this is the "teaching with a box" part.
  4. Soft mask = Σ p_k × mask_k.
  - Run only if the best candidate's IoU minus SAM's own top pick is ≥ 0.08 (free pre-check).
- **H9 (hybrid, Jev checks the DINO regions):** for the top 3 parts of the DINO map, one Noul each on the test crop against the same crop of the nearest good image. Parts with p < 0.2 go to 0.

**Stage 4: boxes and fusion (paid, about 730 calls, about USD 0.40)**
- **H10 (box TTA):** Box on 8 shifted, scaled or mirrored crops around L's tiles, with 2 wordings. WBF gives the box; the votes give a map.
- **H11 (boxes from the best map):** at the F1-max threshold, plus the zoom cascade (crop 2× around the box and ask Box again, twice).
  - Judged on detection AP@0.3 and false boxes per good image, against L.
- **H12 (Score type):** the 5-level Score against the Noul on 60 images; keep it only if F1-max gains ≥ 0.03.
- **H13 (fusion, ClipSAM style):** z(Jev map) + z(DINO map) + SAM masks weighted by their mean score; compared with the best single map.

**Stage 5: freeze and final test (only after fmm's go)**
- Freeze two candidates:
  - the best **pure-Jev** pipeline;
  - the best **hybrid** pipeline.
- Freeze also their words, thresholds and image-score rules, and the commit.
- Write the final inputs, run once on the fresh test, and score it.
- The cost of a candidate must be ≤ USD 0.01 per image (a likely pipeline is 4–6 calls and about USD 0.004).

### D. Pre-registered rule for the final test (written before any final call)

- **Reference:** L as box-as-mask.
- **Primary family:** AU-sPRO@0.05 for 5 datasets × 2 candidates = 10 tests.
  - Paired bootstrap with 5,000 resamples, stratified by good/defective, seed 2043.
  - Holm correction at α 0.05.
- **A candidate "does better"** when:
  - it is significantly better on ≥ 3 of 5 datasets;
  - it is significantly worse on none;
  - it has no significant loss in image AUROC (the secondary family, also Holm-corrected).
- **Descriptive only:**
  - detection AP;
  - the other pixel metrics;
  - each hybrid against its no-Jev version (what Jev adds);
  - underbody_screw.
- **Failures:** a failed call is retried twice. After that the image gets a zero map and a score of 0; no image is dropped.

### E. Budget

**fmm's answers (2026-11-25):** "Both tracks (Recommended)" and "Approve 12,000 / USD 10 (Recommended)". These are recorded as D343 (budget) and as part of D342 (tracks), both with How `question`.

**New budget row, approved by fmm:** "Box study (M7), pixel study (D340–D343): map methods on the development pool and one final test", **12,000 calls, USD 10**, purpose prefix `box px`.

Caps in code, as `d336_check_cap()` does:

| Cap | Calls | USD |
|---|---|---|
| `box px dev` | 5,000 | 4 |
| `box px final` | 7,000 | 6 |
| per image | — | 0.01 |

- **Expected spend:**
  - dev about 2,000 calls, about USD 1.1, plus pilots and reruns;
  - final test about 547 images × (2 candidates × about 5 calls + L 2 + Z 1), about 7,000 calls, about USD 4.5.
- The D335 row closes at USD 0.39 used.

### F. Code (worktree `fine_tuned_jev-box`, branch `m7-box`)

**Reuse:**
- `box/R/typesafe.R` (`jev_ask`, `box_of`, logging);
- the replay cache and cap pattern of `box/scripts/d336_02_run.R` and `d336_common.R`;
- the MD5 exclusion of `d336_01_inputs.R`;
- `load_img`, `crop_sent` and `fabrid_truth` of `01_scan_spike.R`;
- `search_image` of `04_top_down_live.R` (saved TD windows);
- the bootstrap pattern of `d336_03_results.R`;
- the R code of the offline-analysis agent (polygon fill, box mask, pixel metrics).

**New R files:**
- `box/R/evaluate.R`: `truth_masks()`, `truth_config()`, `boxes_to_map()`, `map_to_boxes()`, `pixel_hist()`, `eval_image()`, `eval_boxes()`, `eval_pixels()`, `boot_compare()`, `map_write()`, `map_read()`;
- `box/R/maps.R`: `spread_windows()`, `vote_map()`, `tile_map()`, `segment_map()`, `gate_map()`;
- `box/R/register.R`: `nearest_good()`, `registered_crop()`;
- `box/R/superpixels.R`: `slic_lite()`, `outline_image()`, `som_image()`, using composites, because `image_draw()` fails here;
- `box/R/hyb_python.R`.

**New Python files:**
- `box/python/boxseg.py`: one file with the subcommands `fetch`, `sam`, `auto`, `dino` and `overlay`;
- `requirements-boxseg.txt`.

**Scripts:** `box/scripts/px_00_truth.R`, `px_01_validate.R`, `px_02_rescore.R`, `px_1x_*.R` (one per stage), `px_20_final_inputs.R`, `px_21_final_run.R`, `px_22_final_results.R`.

**One row per image and method:**
```
tibble(id, dataset, method, map_file, image_score, gate,
       boxes = list(tibble(left, top, right, bottom, score)),
       calls, input_tokens, usd, error)
```

**testthat checks:**
- a perfect map gives AU-sPRO 1;
- a constant map gives 0.5 at every limit;
- the box ceiling reproduces .42 / .37 / .61 / .50;
- the re-scored D336 box IoUs match `per_image.csv`.

### G. Records (main checkout, record-only commits)

- **D340:** fmm's request, quoting "you are mixing image segmentation assessments with those of object detection" (How: chat).
- **D341:** the three-level evaluation and its headlines.
- **D342:** the protocol (pools, final test, held-out class, rule) and the two tracks (fmm, question: "Both tracks").
- **D343:** the budget row, 12,000 calls / USD 10 (fmm, question).
- **Later:**
  - a ruling that the port passed its check;
  - fmm's go for the final test.
- **Process rows** at each stage.
- **Results rows:**
  - H17: the post hoc three-level baselines (cites H16);
  - H18: the final verdicts.
- **Plan files:** the formal task plan `replication_materials/plans/2026-11-26-box-pixel-plan.md` (writing-plans format), its ledger, and `replication_materials/environment/python-boxseg-environment.txt`.

## Verification

- **Port check:** the R AU-sPRO is within 0.005 of the official code on the check maps (Stage 0 gate). Nothing paid runs before it passes.
- **Smoke run:** each paid stage first runs on 4–10 dev images. Check that:
  - the call-log rows carry the prefix;
  - a rerun sends 0 calls (replay);
  - the caps stop the run when reached.
- **Contact sheets** for each stage (maps, masks and truth outlines); look at them before deciding.
- **Final test:**
  - the inputs and pre-registration are committed before the first call;
  - the run sends each image once;
  - the results script prints each verdict by rule D.

## Execution

After approval:
1. Record D340–D343.
2. Write the formal plan in `replication_materials/plans/` (writing-plans).
3. Run Stages 0–4 with a ledger, giving a short report after each stage.
4. Stop before Stage 5 for fmm's go.
