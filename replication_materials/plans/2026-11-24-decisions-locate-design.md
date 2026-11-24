# decisions: locate(), the Box functions (short design)

Date: 2026-11-24. Decisions: D317 (Box passes its gate), D319 (locate() only), D320 (ship local_textile_0199), D310 (Box does not hold 0.2.0). Status: draft for the approval of fmm.

## Intent

Box passed its gate on the textiles of decisions (D317): the strategy T of D303 pointed to 14 of 14 local defects and put no box on 23 nominal images. decisions gets one function, `locate()`, that runs strategy T for each image (D319). It is experimental: TypeSafe can change Box between releases, and only Jev 1.14 has it. It joins 0.2.0 only if it is ready when Gemini and Venn are done (D310).

## Goals, non-goals, anti-goals

- Goals: `locate()` gives, for each image, an image score of a defect and one box, with the steps that passed the gate; one vignette section shows it on the textiles.
- Non-goals: no Box question type in `decide()` (D319); no several defects in one image; no strategy Z; no provider other than TypeSafe.
- Anti-goals: no hidden cost (the output reports the calls and tokens); no result in the vignette that a reader cannot rerun from `data-raw/`.

## Approaches

| Approach | Result |
|---|---|
| A. `locate()` only | Chosen by fmm (D319) |
| B. `question_box()` and `locate()` | Not chosen: the raw one-request Box tested worst (D273's setting) |
| C. `decide(locate = TRUE)` | Not chosen: hides 2 calls per image, mixes two output shapes |

## Design

**Signature.** `locate(decider, image, defect, references, max_active = 10, rpm = NULL)`.

- `decider`: from `decider_typesafe()`. `locate()` stops before any request for another provider, or for a Jev model before 1.14 (`jev-1.13.0`; `jev-latest` and `jev-1.14.0` pass).
- `image`: as in `decide()` (paths, URLs or magick images); one row for each image, in input order.
- `defect`: one phrase with its article, for example "a textile flaw (a small patch where the regular diagonal weave is replaced by fine speckled noise)".
- `references`: a list with `nominal` and `defective`, each a list of images: crops that show a part with no defect and a part with the defect, at about the scale of a tile (half the side of the inspected image). `locate()` does not crop them.

**Steps** (strategy T of D303, as run in D307; Claude Code's calls in italics):

1. T1, one request: a Choice "Which picture shows <defect>? Compare it with the examples." over 9 tiles of half the image with 50% overlap, each sent at 560 px, and an option "none" ("None of the pictures shows <defect>."). The reference crops go in the state at 560 px, with the note "Each question shows one part of the same inspection image. Examples from other images: `nominal_example_1` shows a part with no defect; ...; `defective_example_1` shows <defect>." *(generated notes, D307 had notes for the textiles).*
2. If the choice is not "none", T2, one request: a Box in each of the two most likely tiles (grown by 1.2, sent at 1024 px), with two wordings: "the defect" and <defect> with its first article changed to "the" *(the rule for the second wording)*. The answer is the box in the first tile, with the wording whose two boxes agree more (IoU), or the higher mean confidence on a tie.
3. Every image is enlarged so that its short side is at least 280 px (the limit of TypeSafe).

**Output.** A tibble with one row for each image: `.pred_defect` (1 minus P("none") of T1), `.box_left`, `.box_top`, `.box_right`, `.box_bottom` (fractions of the image, origin top left; `NA` when T1 says "none"), `.box_confidence`, `.wording` (`"generic"` or `"defect"`), `.input_tokens`, `.cost` (`NA`: TypeSafe reports none), `.seconds`, `.error`; and the attribute `requests` (the number of requests sent).

**Code.** A new file `R/locate.R`: `locate()` and its internal helpers (the tiles, the crop geometry, the T1 and T2 bodies, the reading of a Box answer, the IoU), ported from `fine_tuned_jev-box/box/R/` (`candidates.R`, `bank.R`, `regions.R`) and `box/scripts/d307_03_run.R`. It uses the request code of `decide()` (`new_request()` with the image header, `perform_requests()`, the key) *(the builder decides how to share it)*.

**Data.** `inst/extdata/textiles/local_textile_0199.jpg` (from the byte-exact replay, D320) and one row of `textiles` with the role `"box_reference"`. `data-raw/textiles.R` adds it. The other vignettes filter `role == "reference"`, so they do not change.

**Tests.** Fixtures from the vignette run (real TypeSafe requests and responses): the T1 and T2 bodies of one image equal the saved ones; a Box answer reads into the right fractions of the image; "none" gives `NA` boxes and no T2 call; a non-TypeSafe decider and `jev-1.13.0` stop before any request; the output keeps the input order.

**Vignette.** A section "Where is the defect?" in the images vignette: `locate()` on the 46 textile inputs with the two nominal references and the crop of `local_textile_0199.jpg` (x 56 to 180, y 68 to 192, as in D307), the saved results (`inst/extdata/locate.rds`, made by `data-raw/vignette_results.R`), a figure of the 14 local defects with their boxes, and the pointed count against the truth boxes of D307. The text says that Box is experimental and that the gate run of D317 gave 14 of 14.

**Budget.** The vignette run: at most 150 TypeSafe calls and USD 0.05 (46 images, 1 or 2 calls each, and the fixture calls). A new budget row; fmm approves it with this design.

## Left to the builder

- The names of the internal helpers and how `locate()` shares the request code of `decide()`.
- The words of the help page and of the vignette section, within the facts above.
