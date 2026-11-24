| Item | Value |
|---|---|
| Status | Closed |
| Version | 1.0 (2026-11-24) |
| Written by | Claude Code |

This ledger is a copy of the working ledger for the plan `C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev/replication_materials/plans/2026-11-24-box-textiles-plan.md`. It was copied on 2026-11-24 at the end of the work. Internal agent IDs are removed.

# SDD ledger — plan: C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev/replication_materials/plans/2026-11-24-box-textiles-plan.md

Setup: worktree fine_tuned_jev-box, branch m7-box at 1f0e531; spec replication_materials/plans/2026-11-24-decisions-0.2.0-design.md section 4 (approved, D313); gate D312.
Pre-flight: Task 1 -> Task 2: Task 2 consumes truth.csv (file, x0, y0, x1, y1, source) for the crop of local_textile_0471.jpg and the contact sheet. OK.
Pre-flight: Task 2 -> Task 3: Task 3 consumes inputs.json and truth.csv; Task 3 makes no call before fmm accepts the contact sheet (Task 2 Step 3). OK.
Task 1: Step 1: the replay of the simulation (set.seed(2024), spc4sts 0.6.5) makes all 40 compared files byte for byte (15 local, 25 nominal: same MD5, pixel difference 0); truth boxes from the simulation (source = simulation) for the 14 local inputs and local_textile_0471.jpg. Step 2 not needed.
Task 1: Step 3: frame_check.png: each box sits on the visible defect (rows of the matrix on x, columns on y from the bottom). No local truth box holds the image center (Review Focus 2: 0 of 14).
Task 1: Ruling: commit d307_01_truth.R and its outputs (truth.csv, replay_check.csv, frame_check.png) on m7-box now, not at Task 3 — they are inputs of Task 2 and should not stay untracked — cost if wrong: none (branch m7-box is not pushed).
Task 1: complete (commits 1f0e531..044ed49, tests: Rscript -e 't <- read.csv("box/results/d307_textiles/truth.csv"); r <- read.csv("box/results/d307_textiles/replay_check.csv"); stopifnot(nrow(t) == 15, all(t$source == "simulation"), all(t$x1 > t$x0), all(t$y1 > t$y0), all(r$same_md5), nrow(r) == 40); cat("truth 15 rows; replay 40/40 byte-exact\n")' → truth 15 rows; replay 40/40 byte-exact)
Task 2: Ruling: all three reference crops are 125 px squares (the tile size of T): the two nominal references cut at the middle tile, the defective one centered on the truth box of local_textile_0471.jpg and clamped inside the image — the same scale as the tiles that T1 compares — cost if wrong: the tile Choice compares tiles with crops of another scale.
Task 2: Ruling: the flaw of local_textile_0471.jpg is near the corner of the image (x 231-241, y 203-225), so the clamped crop shows it at its lower-right edge, not at its center; kept, because it is the only local reference of the package and is clearly visible — cost if wrong: the example teaches 'flaws sit at the edge'; fmm sees it on the contact sheet.
Task 2: Ruling: the textile words were written from the frame check (the look of the simulated defects), before any call and with no model answer — cost if wrong: none for the gate (no answer was seen).
Task 2: STOP for fmm: contact_sheet.png shown; no call until fmm accepts (plan Task 2 Step 3).
Task 2: fix of fmm (2026-11-24, 'Fix the flaw crop edge'): the defective reference is now local_textile_0199.jpg of the replay of the simulation (d307_02b_reference.R; flaw 7.8 px from the center; not one of the 15 local textiles of the package), cropped as a 125 px square centered on its flaw (x 56-180, y 68-192). This replaces the clamped crop of local_textile_0471.jpg and the second Task 2 ruling.
Task 2: Ruling: a reference from the replay, not a smaller crop of local_textile_0471.jpg — a centered crop of 0471 can be at most 27 px wide (its flaw is 13 px from the right edge), which changes the scale of the tiles; the replay is byte-exact with the package, so 0199 comes from the same simulation — cost if wrong: the reference is not one of the 4 references of the package dataset, so a vignette with the package references can differ from this test.
Task 3: Ruling: the first run made 46 calls that got HTTP 403 (no key: d307_03_run.R did not call readRenviron() as d303_common.R does); USD 0, no answer stored; fixed (readRenviron of the main .Renviron, and a check), then the run again; the 46 failed calls count toward the cap of 400 (46 + at most 184 = 230) — cost if wrong: none.
Task 3: complete (commits e984a3b..dc256b1, tests: Rscript -e 'm <- read.csv("box/results/d307_textiles/measures.csv"); stopifnot(nrow(m) == 2, length(list.files("box/results/d307_textiles/per_image")) == 46, max(m$local_pointed) >= 12); cat("measures for T and Z on 46 inputs; best pointed", max(m$local_pointed), "of 14; gate PASS\n")' → measures for T and Z on 46 inputs; best pointed 14 of 14; gate PASS)
Final: review by a fresh reviewer (Fable): the gate result is right (T 14 of 14 from independent code, at margin 0, with either wording, under corrected truth). No Critical.
Final: fixed Important 1 (truth boxes 1 px too far right and down) — d307_00_truth_test.R RED (pads 0 0 2 2 at three positions) → GREEN (pads 1 1 1 1); truth_box() in box/R/truth.R used by d307_01 and d307_02b; truth.csv and truth_reference.csv made again (all 60 coordinates -1, replay still byte-exact); measures: pointed T 14, Z 13 (unchanged), median IoU T 0.668 (was 0.657), Z 0.612 (was 0.543).
Final: fixed Important 2 (evidence not in git) — boxes.csv written by d307_04_results.R (107 rows); box/R/, per_image/, bank/, bank_responses/ committed.
Final: fixed Important 3 (no code for frame_check.png) — d307_01_truth.R draws it; it now shows the corrected boxes. contact_sheet.png and inputs.json stay as fmm accepted them (D315), with the boxes of before the 1 px fix: they record what was sent.
Final: minor (deferred): center baseline at margin 0 while pointing uses 0.02; the crop-center baseline (1 of 14) is not in the summary.
Final: minor (deferred): nominal_flagged uses two rules; the AUC is not split by defect type (T local 1.00, global 0.81; Z 0.92, 0.27); T answers none for 8 of 9 global inputs.
Final: minor (deferred): width and height fixed at 250 in run_image(); whole_at() has no guard below 280 px; crop_at() has no assertion (no effect: all images are 250 x 250).
Final: minor (deferred): the retry after HTTP 429/503 in box/R/typesafe.R can pass the call cap by 1.
Final: minor (deferred): a no-op path expression in d307_03_run.R; inputs.json mixes an absolute and a relative path.
Final: minor (deferred): summary.md does not say that the defective reference is not a package image, nor that in 3 of 14 images (0212, 0325, 0406) the wording was picked by confidence.
Final: minor (deferred): plan deviations with no effect (sheet.png not sheet.jpg; D303 code copied, not sourced; the plan mode does not stop by itself).
Final: minor (deferred): git cannot show that d307_04_results.R was fixed before the answers (one commit, 18 s after the run); its pointed() equals center_in() of d303_eval.R.
