# decisions: locate() Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `locate(decider, image, defect, references)` runs strategy T of D317 for each image and returns one row per image with an image score and one box, with a vignette section on the textiles.

**Architecture:** A new file `R/locate.R`: pure helpers (tiles, crop geometry, the mapping of a box back to the image, IoU, the second wording), two body builders (T1: a Choice over 9 tiles with the reference crops; T2: a Box in the two best tiles with two wordings), a reader of Box answers, and `locate()`, which sends T1 for all images, then T2 for the images whose answer is not "none", with the request code of `decide()`.

**Tech Stack:** R, httr2, magick, S7 (deciders), testthat 3 with fixtures from real TypeSafe calls.

**Spec:** `replication_materials/plans/2026-11-24-decisions-locate-design.md` (approved, D321); D317, D319, D320; the code that passed the gate: `fine_tuned_jev-box/box/scripts/d307_03_run.R` and `box/R/{candidates,bank,regions}.R` (commit c21449e of m7-box).

## Global Constraints

- Starts after part 1 (the Gemini and Venn deciders) merges into `main`; branch `locate` from `main`.
- TypeSafe only, `jev-1.14.0` or `jev-latest`; `jev-1.13.0` (no Box) stops before any request.
- Sizes of D307: tiles of half the image with 50% overlap, sent at 560 px; reference crops at 560 px; the Box crops grown by 1.2 and sent at 1024 px; every image at least 280 px on its short side.
- Texts: T1 "Which picture shows <defect>? Compare it with the examples."; the option "none": "None of the pictures shows <defect>."; the state note: "Each question shows one part of the same inspection image. Examples from other images: ..."; the Box questions "<wording> in this picture: <key>" with the wordings "the defect" and <defect> with its first article changed to "the".
- Paid calls: budget row of D321 (TypeSafe, 150 calls, USD 0.05), each logged in `typesafe-calls.csv` with the purpose prefix `decisions-0.2.0-locate-`.
- Box is experimental: the help page and the vignette say so.

## Review Focus

1. A box mapped from the crop to the image in the wrong frame or with an off-by-one: a test maps a known crop box by hand.
2. An image whose T1 answer is "none": no T2 request, `NA` box columns, a `.pred_defect` below 0.5 is not required.
3. Output rows out of input order when T2 runs for some images only: a test with three images, the middle one "none".
4. A reference crop smaller than 280 px on a side (the textiles crops are 125 px): it is enlarged before it is sent.
5. A T1 answer with a missing tile probability or a T2 answer with no box: a row error, not a crash.

---

### Task 1: The box reference in the data

**Files:** `inst/extdata/textiles/local_textile_0199.jpg` (from `fine_tuned_jev/imgs/textile_images/simulated/local/textile_0199.jpg`, byte-identical to the replay), `data-raw/textiles.R`, `data/textiles.rda`, `R/data.R`, the dataset test.

- [ ] Add the image and one row of `textiles` (`class = "defective"`, `defect_type = "local"`, `role = "box_reference"`, `reference_rank = NA`); document the role; a test checks 51 rows, one `box_reference`, and that the 4 rows of `role == "reference"` are unchanged. Commit.

### Task 2: The geometry helpers (no call)

**Files:** `R/locate.R`, `tests/testthat/test-locate.R`.

- [ ] Tests first, from the D307 code: `locate_tiles()` gives 9 tiles of half the image (fractions, 50% overlap, row-major order with the names of D307); `locate_crop(box, grow, width, height)` gives the pixel crop, clamped to the image; `locate_to_image(box, crop, width, height)` maps a Box answer (fractions of the crop) to fractions of the image (a hand-made case); `locate_iou()`; `locate_wording("a textile flaw (a small patch ...)")` gives "the textile flaw (a small patch ...)", and "an ..." gives "the ...". Implement; the suite passes. Commit.

### Task 3: The bodies and the fixtures

**Files:** `R/locate.R`, `data-raw/probe_providers.R` (`probe_locate()`), `tests/testthat/fixtures/locate-{t1,t2}{,-request}.json`.

- [ ] `locate_body_tiles(model, image, defect, references)` and `locate_body_boxes(model, image, tiles, defect, references)` give the TypeSafe bodies (`model`, `questions`, `assets`, `state`), as `d307_03_run.R` builds them, with the generated notes of the design. `probe_locate()` builds them for one textile input and sends them (2 calls, logged); the saved responses become fixtures. Tests: the bodies equal the saved requests; `locate_read_tiles()` and `locate_read_boxes()` read the saved responses (tile probabilities and P("none"); the box in fractions). Commit.

### Task 4: locate()

**Files:** `R/locate.R`, `NAMESPACE`, `man/locate.Rd`, `tests/testthat/test-locate.R`.

- [ ] Tests first with recorded responses (the fixtures): one image gives one row with `.pred_defect`, the box columns, `.box_confidence`, `.wording`, `.input_tokens`, `.cost` (`NA`), `.seconds`, `.error`; three images with the middle one "none" keep the input order, send 2 + 0 + 2 requests and give `NA` boxes in the middle row; `decider_openai()` and `decider_typesafe("jev-1.13.0")` stop with no request; a T2 answer with no box gives a row error. Implement with `new_request()` (the image header), `perform_requests()` and the key of the decider; `max_active` and `rpm` as in `decide()`. The help page says that Box is experimental. Commit.

### Task 5: The vignette section, the docs and the check

**Files:** `data-raw/vignette_results.R` (`case_images_locate()`), `inst/extdata/locate.rds`, `vignettes/images.Rmd`, `NEWS.md`, `README.md`, `inst/skills/decisions/SKILL.md`, `_pkgdown.yml`, `inst/WORDLIST`.

- [ ] Run `locate()` on the 46 textile inputs with the two nominal references and the crop of `local_textile_0199.jpg` (x 56 to 180, y 68 to 192) and the wording of D307 (at most 92 calls, logged); save the answers. The section "Where is the defect?" shows the code, a figure of the 14 local defects with their boxes, and the pointed count against the truth boxes of D307 (the truth of `box/results/d307_textiles/truth.csv`, kept in the script), next to 14 of 14 of the gate run (D317). Docs; `R CMD check --as-cran` with no note; record the calls; push; pull request.
