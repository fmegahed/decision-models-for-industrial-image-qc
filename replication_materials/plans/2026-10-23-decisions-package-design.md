# The R package decisions: design

- Date: 2026-10-23
- Milestone: M3
- Status: draft, for review by fmm
- Written by: Claude Code (Opus 5.5), from the chat with fmm in session b36ad167-66f5-45af-9d6c-bf3f817c6f58
- Decisions in the record: D136 to D151
- Replaces: `docs/decisionqc_design.md` (draft of 2026-10-20, when the package had the name decisionqc and served only image inspection)

In this document, "Claude call" marks an item that Claude Code proposes and fmm did not decide yet. fmm decides these items when fmm approves this document. Section 10 lists them.

## 1. Intent

The reader of the package is an R user who wants to try decision models (D136). A decision model, also called a System One model, does not write text. It reads a state (a text, an image or both) and typed questions, and it returns a probability for each allowed answer. Jev of TypeSafe was the first such model (September 2026). In October 2026, Microsoft, OpenAI, Cloudflare, Convai Innovations and Perplexity released their own. Each API is a little different, and no R package calls them.

The package `decisions` makes these models easy to use from R, as ellmer makes chat models easy to use. It is a sister of ellmer, focused on decision models (D139). It is a self-contained package on httr2. It does not need a change in ellmer.

Our study (M1, M5) showed three things that the package makes easy: the text of the descriptions matters and is worth tuning; raw probabilities are not calibrated, and Platt scaling or isotonic regression fixes this with few labeled examples; cost and speed matter as much as accuracy when you choose a model. The paper gives the package one sentence (fmm writes it).

fmm wants the package on CRAN soon.

## 2. Goals, non-goals and anti-goals

Goals:

- G1. Ask typed questions (noul, choice, score) about a text, an image or both, to any supported decision model (D136, D141).
- G2. Ask about one input or about many inputs in one batch, with outputs restricted to the typed answers (D137).
- G3. Calibrate the probabilities (D137).
- G4. Report performance, cost and speed in one table.
- G5. Let a tidymodels user run ML-style experiments on top of the package (D138), shown in a vignette, not built into the package (D139).
- G6. A GUI with a build mode and a use mode that share a saved setup file (D147).
- G7. An agent skill in the package that connects a coding agent to the package to tune the descriptions (D148).
- G8. Six vignettes (D140, D149), and the lightest example in the web browser with webR (D145).
- G9. A first release on CRAN soon.

Non-goals:

- Chat models, and probabilities from the tokens of chat models (D136).
- Model inference inside R. The models run on servers: a hosted API, or a server on the computer of the user. The package has no C, C++ or Rust code (D139).
- A tidymodels model engine inside the package (D139). tidymodels is not a dependency.
- Fine-tuning of model weights.
- A built-in object detector. The package has a hook for one (D142).
- A Quarto site for vignette 6 (D150).

Anti-goals. The work fails if one of these is true, even if all code runs:

- A user pays twice for the same call, or a run spends more than the spending cap.
- An API key goes into a printed object, a log, the cache, a saved setup, a livelink URL or an error message.
- A failed call is dropped, or is scored as a wrong answer, without a visible error.
- The package sends an image to a model that takes only text.
- A CRAN check or a test makes a network call or needs a key.
- The agent skill lets an agent see the test data.
- The API of the package is specific to quality control. Quality control is one use case among six.

## 3. Models and request formats

### 3.1 The models of interest (2026-10-23)

The facts below come from the web pages in the section "Sources". The pages of OpenAI and of Laya are primary sources. Some facts about Microsoft-Decision-1 and OpenRouter come from secondary sources. The builder checks them against the documentation of each provider before the code uses them.

| Model | Maker | Weights | Input | Request format | Where it runs |
|---|---|---|---|---|---|
| Jev | TypeSafe AI | closed | text; images only with the header `TypeSafe-Danger-Zone-Images: true` | SystemOne | TypeSafe API, OpenRouter |
| Microsoft-Decision-1 | Microsoft | closed | text only, 32,768 tokens | close to SystemOne (Foundry) | Microsoft Foundry, OpenRouter |
| Decisions API, `gpt-6-luna` | OpenAI | closed | text, images, JSON | OpenAI Decisions | OpenAI |
| Clef, Clef-Flash | Cloudflare | open, Apache 2.0 | text and images | SystemOne, with an ordered image list | weights on Hugging Face; SGLang server (as in our study) |
| Laya (3 checkpoints) | Convai Innovations | open, Apache 2.0 | text only; runs on a CPU | SystemOne (`laya-serve`) | weights on Hugging Face; own server |
| pplx-decider | Perplexity | open | text and images (one source) | not clear | Perplexity API; weights on Hugging Face |

Hugging Face has no common way to call decision models. Its router serves chat models only. The open decision models put their weights on Hugging Face and bring their own server, and these servers speak SystemOne. Thus SystemOne is the common format in practice.

### 3.2 Request formats

The package supports these formats:

1. SystemOne. `POST <base_url>/v1/systemone` with `model`, `state`, `assets` and a `questions` object keyed by name. The `answers` object is keyed by name. TypeSafe, `laya-serve` and Foundry (approximately) use it.
2. SystemOne with an ordered image list. The SGLang server of Clef-Flash ignores `assets`. It takes an `images` list of data URLs, and the state text says which image is which. The study code does this (`image_format = "images"` in `R/industrial_defect_classifier.R`).
3. OpenAI Decisions. `POST /v1/decisions` with `input` (a text, or messages with `input_text`, `input_image` and `input_json`) and a `questions` array. Each question has a `name`. The `answers` array has one item per question.
4. OpenRouter decisions. `POST https://openrouter.ai/api/alpha/decisions` (alpha), with `model`, `state` and a `questions` map (reported by secondary sources).

The question types map as follows:

| Package | SystemOne | OpenAI Decisions | Answer in the package |
|---|---|---|---|
| noul (yes or no) | `noul`, criteria `true` and `false` | `predicate` | probability of yes |
| choice | `choice`, criteria per option | `choice`, `choices` with `value` and `description` | chosen option and a probability per option |
| score | `score`, ordered levels | `score`, `levels` (2 to 10) | weighted score and a probability per level |

A small translator for each format turns the questions of the package into the request, and the response into the answer of the package. A new format is a new translator. The rest of the package does not change.

### 3.3 The model list

The package has a list of known models, `decision_models()`, as a tibble. Each row has: provider, model, request format, input (`text`, `image` or `text+image`), a flag for experimental image input (Jev), open or closed weights, context length, price per million input tokens, the date of the check and the source URL. A user can add a row for a new model. The package checks the row before a call. It stops before the call if the input has an image and the model takes only text.

## 4. Package design

### 4.1 Style

The package follows the style of ellmer, so that ellmer users feel at home: constructors that return a model object, typed question helpers, one function for one input and functions for many inputs. Claude call: the objects are S7 classes, as in ellmer. The names below are Claude calls. They avoid the names of ellmer and magick, so that both packages can be attached at the same time.

### 4.2 Models and credentials (D143)

- `decider_typesafe(model = "jev-1.13.0")`, `decider_openai(model = "gpt-6-luna")`, `decider_foundry(endpoint, deployment)`, `decider_openrouter(model)`: hosted models.
- `decider_systemone(base_url, model)`: any server that speaks SystemOne, for example Clef-Flash or Laya on the computer of the user. The argument `image_format` selects the asset form or the ordered image list.
- Credentials work as in ellmer. By default, the key comes from an environment variable: `TYPESAFE_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` or the Foundry key. The argument `credentials` takes a function that returns the key, for example for an Azure (Entra ID) token. The object never stores or prints the key.

### 4.3 Questions and inputs

- `question_noul(instructions, true = NULL, false = NULL)`, `question_choice(instructions, choices)`, `question_score(instructions, levels)`. `choices` and `levels` are named character vectors: the name is the answer, and the value is its description. `questions(...)` collects named questions.
- Text inputs are character strings.
- Image inputs (D142): `input_image_file(path)`, `input_image_url(url)`, `input_image_plot()` (the plot that is open in R) and `input_image_magick(image)`. In a batch, a column of paths or URLs works in the same way.
- Image preparation is set by arguments, not by user code (D142): `image_options(max_size = 768, upscale = FALSE, keep_resolution = FALSE, crop = "none")`. `crop` is `"none"`, `"center"`, a box (x, y, width, height), or a function. The function takes a magick image and returns a box. This is the hook for an object detection model that finds the part. The package ships no detector.
- `references(nominal = ..., defective = ...)`: reference examples per answer, for models that use them (the few-shot references of our study).

### 4.4 Decisions for one input and for many inputs (D137)

- `decide(decider, input, questions, references = NULL, image_options = NULL)`: one input, one call.
- `decide_parallel(decider, inputs, questions, ..., max_active = 10, rpm = NULL)`: many inputs, many calls at the same time (`httr2::req_perform_parallel()`), within the rate limit. This is the sister of `ellmer::parallel_chat_structured()`.
- `decide_batch(decider, inputs, questions, ..., path, wait = TRUE)`: the batch job of a provider, where a provider offers one. The `laya-serve` server has `/v1/systemone/batch` (up to 64 states). The builder checks whether TypeSafe, OpenAI, Microsoft or OpenRouter offer a cheaper batch job for decisions. This is the sister of `ellmer::batch_chat_structured()`, which also takes a `path` to continue a job.
- The output is a tibble with one row per input, in the order of the inputs. For each question: the answer (a factor with the allowed levels; a probability for noul) and one probability column per allowed answer. Each row also has `.model`, `.input_tokens`, `.cost_usd`, `.seconds` and `.error`.
- Typed answers: the package checks each answer against the allowed answers. An answer outside them, or a failed call, gives `NA` answers and a message in `.error`. The row stays in the output. `decide_parallel()` stops when the share of failed calls passes a limit (Claude call: 10%).

### 4.5 Cache, continuation and spending cap

- A cache on disk keeps each answer. Its key is a hash of the request format, the model, the base URL, the questions, the references, the image options and the prepared input. The key does not contain the API key. Claude call: the cache is in `tools::R_user_dir("decisions", "cache")`, as CRAN allows, with `decisions_cache_clear()`.
- The cache also makes long runs continue. If a run of 2,000 images stops at image 1,500, the next run reads 1,500 answers from the cache and calls the model for the other 500. No input is paid for twice with the same settings.
- In resampling, the same image with the same settings comes from the cache. A 10-fold resample with fixed settings costs about one pass over the data.
- A spending cap is a hard limit (Claude call, after the builder check):
  - `decision_budget(max_usd, path = NULL)` makes a budget. With `path`, the spent total is saved on disk, so it carries over between function calls and between R sessions. `decide()`, `decide_parallel()`, `decide_batch()` and `score_setup()` take the same budget, so an agent loop that calls `score_setup()` many times has one limit.
  - Before each call, the package estimates its cost from a high estimate of the input tokens (text and images, per provider) and the price in the model list. It reserves that amount. The calls that are still running keep their reservations, so parallel calls cannot pass the cap. After each call, the reported cost replaces the reservation.
  - A model with no known price (a row that a user added without a price, or a local server) runs only with `max_usd = Inf` or with a price that the user gives. Local servers have price 0.
  - The package warns at 80% of the budget.
- Retries do not pay twice (Claude call): the package retries a call only when the server surely did not process it (HTTP 429, or no connection). After a timeout or an HTTP 5xx error, it does not retry. The row gets an `.error`, and the user decides to run it again.

### 4.6 Calibration and the report

- `calibrate(prob, truth, method = c("platt", "isotonic"))` returns a calibrator. `predict()` applies it to new probabilities. The code comes from the tested functions of the study (`R/calibration_functions.R`). The package needs no new dependency for this. Claude call: the first release calibrates noul questions and choice questions with two options; more options come later.
- `calibration_metrics(prob, truth)`: Brier score, expected calibration error (10 bins) and log loss.
- `decision_report(results, truth)`: one table with performance (accuracy, sensitivity, specificity, ROC AUC, ECE, Brier), cost (USD per 1,000 inputs) and speed (median and 90th percentile seconds per input). Claude call: the package computes these itself; vignette 5 shows the same numbers with yardstick.

### 4.7 Saved setups

- `decision_setup(decider, questions, references = NULL, image_options = NULL, calibrator = NULL)` collects one complete decision.
- `write_setup(setup, path)` and `read_setup(path)`. Claude call: one JSON file. It holds the model name and URL (no key), the questions and their descriptions, the image options, the calibrator and the reference images after preparation (base64). One file is easy to share, and the GUI and R code read the same file.

### 4.8 Hooks for the agent skill (D148)

- `score_setup(setup, inputs, truth, metric = "roc_auc", log = NULL)` scores a setup on labeled inputs that are not references, and returns the metric. With `log`, it adds one line per attempt to a JSON Lines file: the time, the descriptions, the score, the calls and the cost. `read_attempts(log)` reads the file. A person can review each attempt.
- The skill is in `inst/skills/decisions/` (`SKILL.md` and reference files), as in commons 0.1.1. The description of the skill names the functions of the package, so that an agent loads the skill when a project uses them. A vignette shows how to copy it to `.claude/skills` (Claude Code) or to `.agents/skills` (Posit Assistant, Codex) with `system.file()` and `file.copy()`.
- Reference files (Claude call): writing questions; tuning descriptions; calibration and evaluation; sharing a setup.
- The rules of the description loop of the study go into the skill (`scripts/fair_loop_instructions.md`): keep a change only when the ROC AUC rises by at least 0.02; base each change on what the examples show; do not aim for an AUC of 1; the agent sees only the scores and the learning examples, never the test set; the spending cap applies.

### 4.9 GUI (D147)

- Build mode, `decisions_app()`: pick text or images, write the questions, choose a model, try a few examples, calibrate on labeled examples, see the report, save the setup.
- Use mode, `use_app(setup)`: a plain screen for colleagues who do not code. They give a text or an image and see the answer and how sure the model is. They see no question editor and no model choice.
- `write_app(setup, dir)` writes `app.R` and the setup file for Posit Connect or a Hugging Face Space. The key is an environment variable (a secret) of the host. It is never in the files.
- Claude call: Shiny with bslib, in Suggests. fmm mentioned shinychat. A chat helper in the build mode needs a chat model, which D136 keeps out of the package. Section 10 asks fmm about it.

### 4.10 A tidymodels engine that registers only when parsnip is installed

Claude call, after the builder check. Without a parsnip engine, `tune_grid()` and workflow sets cannot use a decision model, and vignette 5 must use a hand-written loop. D138 asks for the decision model as "one more model" inside tidymodels, and D139 keeps tidymodels out of the dependencies. Both are possible: the package registers a parsnip engine when the package loads and parsnip is installed (parsnip in Suggests). "Fitting" picks the k references per answer from the training rows. The description texts and k are tuning parameters. Calibration is a tailor step after the model.

### 4.11 Dependencies

- Imports (Claude call): httr2, S7, rlang, cli, tibble, jsonlite. All are on CRAN and in webR.
- Suggests: magick (needed only for images), shiny, bslib, testthat, withr, knitr, rmarkdown, yardstick, rsample, tailor, parsnip. livelink is not a dependency, not even in Suggests (D151).
- No compiled code (D139). The package then builds in webR, and the CRAN review is short.

### 4.12 Tests

- `httr2::local_mocked_responses()` with saved response files for each request format. Tests make no network call and need no key.
- Tests of the guards: no image to a text-only model; the cache key has no API key; a failed call stays in the output with `.error`; the spending cap stops the run; the cache continues a stopped run; a saved setup has no key.
- Live tests run only on the computer of fmm, with `skip_on_cran()` and a check for the key. Each live test needs a budget row in `replication_materials/calls/README.md` before the first call.

## 5. Vignettes (D140, D141, D144, D149, D150)

| # | Title (draft) | Reader | Content |
|---|---|---|---|
| 1 | Getting started with text | first afternoon | the three question types (noul, choice, score) on short texts, such as support tickets; one input, then many; the agent skill (how to copy it) |
| 2 | Images | image users | the four image inputs; the image options (size, resolution, crop, crop function); references per answer; the simulated textiles of the study (no licence limit) |
| 3 | Choosing a model | users of closed models | credentials as in ellmer; the same task on Jev, Microsoft-Decision-1 and the OpenAI Decisions API; one report of performance, cost and speed |
| 4 | Open models on your own computer | users with no key | Laya on a CPU, no key, no cost per call; only the URL changes |
| 5 | Experiments with tidymodels | ML users | the comparison of Clef-Flash and JEV in the paper (D144): rsample splits, calibration with tailor on each resample, yardstick metrics, and description tuning as a small tuning run |
| 6 | Grading short answers with a rubric | teachers | each idea of a rubric and each known wrong claim is a noul question; the student sees only rubric text; sample answers with known verdicts set the threshold (0.6 in the game); questions about the package itself |

Vignette 6 credits three sources (D150): Jeffrey Biles of PhysicsGraph for the idea to check an explanation while the student types it (https://x.com/JeffreyBiles/status/2107211222320021722, as cited in the README of fmegahed/isa401); the course ISA 401 of fmm at Miami University; and the exam-review game (https://isa401-review.vercel.app, https://github.com/fmegahed/isa401/tree/main/games/exam-review).

On CRAN, the checks run without network and without keys. Claude call: each vignette reads saved results (small `.rds` files in `inst/extdata`), and the live code is on the package website. Vignette 5 also needs a GPU server for Clef-Flash. Its readers with a GPU can run the live code.

Vignette 5 in detail (Claude call, after the builder check):

- It is a re-analysis with tidymodels, not a new run. It reads the per-image probabilities that the study saved for the learning set L, the calibration set C and the test sets of the five datasets. It makes no new paid call and needs no GPU.
- The resamples and the tuning use L and C only. The test numbers are the frozen, one-time scores of the paper. The vignette does not score the test images again.
- Description tuning uses the saved attempts of the eight description loops of the study (the page description_loops.html), so the reader sees each candidate description and its score.
- The vignette ships numbers and image names, not images. The builder checks that the licence of each dataset (AutoVI is CC BY-NC-SA 4.0) allows this.

Vignette 6 uses sample answers that are written for the vignette (Claude call). It uses no answer of a student. Its questions are about the package, so the sample answers of the game do not apply.

### 5.1 webR (D145)

- The first choice is webR itself: the reader runs our code in the browser.
- livelink (CRAN, James Balamuta) makes links that open the webR console or Shinylive with code in it. It is the fallback, if webR itself is not possible (D151). The authors use it once to make the links, and the documents hold the links as plain URLs. livelink is not a dependency of the package.
- ChatISA (fmegahed/chatisa) shows that webR reaches the internet with httr2 when the page is cross-origin isolated and `ALL_PROXY` points R's libcurl at a websocket proxy (the public r-universe proxy). Without isolation, webR loses all networking (ChatISA ADR-023).
- On 2026-10-23, the public webR console (webr.r-wasm.org) and the Shinylive editor (shinylive.io) sent the headers of cross-origin isolation.
- Example A (no key): calibration and the report on saved probabilities of the study. It needs no network.
- Example B (own key): install the package from r-universe, set the proxy, paste a key, ask one noul question about a short text. The call stays encrypted from webR to the provider. The proxy sees only the host name. A test must confirm example B before it goes into a vignette.
- The livelink URL never contains a key. The reader types the key in the console.

## 6. Outside the package

- Hugging Face Space (fmm's idea): the build mode of the GUI on a free CPU Space. Visitors bring their own keys, and the Space never stores them. Claude call: the Space runs Laya for text on its own CPU, so a visitor can try text decisions with no key. Image decisions need a hosted model and a key, because a 9B image model is too slow on a free CPU. The speed of Laya on the 2 vCPUs of a free Space is not known yet.
- Repository (Claude call): a new public repository, `fmegahed/decisions`, MIT licence, with a pkgdown website and an r-universe build (the r-universe build also makes the webR binary). The records of M3 stay in this repository until the new repository exists. Then the new repository gets its own replication record and links back to M3.

## 7. Release plan

Claude call:

- 0.1.0 (first CRAN release): sections 3 and 4.1 to 4.8 (models, questions, inputs, decisions, cache, cap, calibration, report, setups, skill hooks and the skill), vignettes 1 to 6, webR example A.
- 0.2.0: the GUI (both modes), `write_app()`, the Hugging Face Space, webR example B.

The date of the first CRAN release is open (section 11).

## 8. Decisions and their impacts

| ID | Decision | Impact on this design |
|---|---|---|
| D136 | System One models only | no chat models; section 3 |
| D137 | batches, typed answers, calibration, ML-style experiments | sections 4.4 to 4.6 |
| D138 | experiments inside tidymodels, a plus | vignette 5 |
| D139 | a self-contained sister of ellmer; first release scope | httr2; no compiled code; no tidymodels dependency |
| D140, D149 | six vignettes | section 5 |
| D141 | vignette 1 shows noul, choice and score | section 5 |
| D142 | image preparation by arguments; detector hook | section 4.3 |
| D143 | credentials as in ellmer | section 4.2 |
| D144 | vignette 5 replicates Clef-Flash against JEV and tunes descriptions | section 5 |
| D145 | the lightest example in webR | section 5.1 |
| D151 | livelink is not a dependency; it is the fallback for webR | sections 4.11, 5.1 |
| D146 | the name decisions | all |
| D147 | GUI with build and use modes and a saved setup | sections 4.7, 4.9 |
| D148 | agent skill in the package, as in commons | section 4.8 |
| D150 | vignette 6 as a grading option, with credits | section 5 |

## 9. Left to the builder

- The exact column names of the output tibble and of the report.
- The JSON layout of a saved setup and of the attempt log.
- The retry rules for each provider (rate limits, HTTP 429 and 5xx).
- The prices in the model list, checked against each provider on the day of the release.
- The wording of the skill files, in the style of the commons skill.

## 10. Claude calls for fmm to check

1. S7 classes and the names of the functions (sections 4.1 to 4.9).
2. The cache in the user cache folder of R (section 4.5).
3. The first release calibrates noul and two-option choice questions only (section 4.6).
4. The package computes the report itself, without yardstick (section 4.6).
5. A saved setup is one JSON file with the reference images in it (section 4.7).
6. Shiny forms for the GUI, with no chat helper (section 4.9).
7. magick in Suggests, needed only for images (section 4.10).
8. Vignettes read saved results on CRAN (section 5).
9. The Space runs Laya for text with no key (section 6).
10. A new repository `fmegahed/decisions` with an MIT licence and its own record (section 6).
11. The split of the work into releases 0.1.0 and 0.2.0 (section 7).
12. A hard spending cap with reservations, saved on disk when the user wants, and no retry after a timeout or an HTTP 5xx error (section 4.5).
13. A parsnip engine that registers only when parsnip is installed (section 4.10).
14. Vignette 5 is a re-analysis of the saved scores of the study, with no new calls (section 5).
15. Vignette 6 uses sample answers written for the vignette (section 5).
16. pplx-decider stays out of 0.1.0 until its request format is known (section 3.1).

## 11. Questions for fmm

To be filled in after the builder check.

## Sources

- OpenAI, Decisions guide: https://developers.openai.com/api/docs/guides/decisions
- Microsoft-Decision-1 on the System One hub: https://systemonemodels.org/models/microsoft-decision-1/
- System One hub: https://systemonemodels.org/
- Laya: https://github.com/NandhaKishorM/laya and https://huggingface.co/convaiinnovations/laya
- Clef-Flash: https://huggingface.co/Cloudflare/clef-flash and https://blog.cloudflare.com/clef-decision-models/
- OpenRouter, Jev guide: https://openrouter.ai/docs/guides/community/jev
- commons 0.1.1 vignette, section "Working with the agent skill": https://github.com/posit-dev/commons
- livelink: https://r-pkg.thecoatlessprofessor.com/livelink/
- ChatISA: https://github.com/fmegahed/chatisa (`web/lib/sandbox/network.ts`, `docs/releases/v6.0.0.md`)
- Exam-review game: https://github.com/fmegahed/isa401/tree/main/games/exam-review
- Installed versions checked on 2026-10-23: ellmer 0.5.0 (`parallel_chat_structured()`, `batch_chat_structured()` with `path`, `content_image_file()` with `resize`, `credentials` in `chat_openai()`), tailor 0.1.0 (`adjust_probability_calibration()`), shinychat 0.5.0, httr2 1.2.3 (`req_perform_parallel()`, `req_throttle()`, `req_retry()`).
