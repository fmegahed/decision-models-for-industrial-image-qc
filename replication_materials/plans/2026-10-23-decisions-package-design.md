# The R package decisions: design

- Date: 2026-10-23 (revision 2)
- Milestone: M3
- Status: draft, for review by fmm
- Written by: Claude Code (Opus 5.5), from the chat with fmm in session b36ad167-66f5-45af-9d6c-bf3f817c6f58
- Decisions in the record: D136 to D165
- Replaces: `docs/decisionqc_design.md` (draft of 2026-10-20, when the package had the name decisionqc and served only image inspection)

In this document, "Claude call" marks an item that Claude Code proposes and fmm did not decide yet. fmm decides these items when fmm approves this document. Section 12 lists them. Revision 2 applies D156 to D162: the package is smaller, it manages no spending, and it keeps no cache and no prices.

## 1. Intent

The reader of the package is an R user who wants to try decision models (D136). A decision model, also called a System One model, does not write text. It reads a state (a text, an image or both) and typed questions, and it returns a probability for each allowed answer. TypeSafe released Jev in September 2026. In October 2026, Microsoft, OpenAI, Cloudflare, Convai Innovations and Perplexity released their own.

Writing rule (D163): the package, its documents and its vignettes do not call Jev, or any other model, the first decision model. The System One hub calls Jev the first, but fmm believes that earlier models exist. Each API is a little different, and no R package calls them.

The package `decisions` (D146, D152) makes these models easy to use from R, as ellmer makes chat models easy to use. It is a sister of ellmer, focused on decision models (D139). It is a self-contained package on httr2.

The package is small (D160). It has a few functions. Its use comes from the vignettes, which show the package with other packages: tidymodels, Shiny, an agent skill. The paper gives the package one sentence (fmm writes it).

## 2. Goals, non-goals and anti-goals

Goals:

- G1. Ask typed questions (noul, choice, score) about a text, an image or both, to any supported decision model (D136, D141).
- G2. Ask about one input or many inputs, and about several models in one run, with answers restricted to the allowed answers (D137).
- G3. Calibrate the probabilities (D137).
- G4. Give, for each input, the answer, the probabilities, the tokens, the cost that the provider reports and the time. The vignettes turn these into reports of performance, cost and speed.
- G5. Tune the settings (the descriptions, the number of references, the image size, the model) on learning data, with a guard for the test data (D155).
- G6. Saved setup files that a Shiny app outside the package can read: the Hugging Face Space (the build mode) and a short app in vignette 6 (the use mode) (D147, D165).
- G7. An agent skill in the package that tunes the descriptions (D148).
- G8. Six vignettes (D140, D149), and the lightest example in the web browser with webR (D145, D151).
- G9. A release on CRAN when release 0.1.0 is complete (D154).

Non-goals:

- Chat models, and probabilities from the tokens of chat models (D136).
- Model inference inside R. The models run on servers. The package has no C, C++ or Rust code (D139).
- Spending management: no spending cap and no budget (D159). A user sets limits on the API key with the provider.
- A cache of answers. A cache saves money only when the same request repeats, and in tuning each candidate differs. The `path` of `decide()` covers the runs that repeat (section 5.2).
- Prices, size limits and other model facts that change, except the input types (D161, D162).
- A tidymodels engine, a report function and provider batch jobs (revision 1 had them; D160 removes them).
- Fine-tuning of model weights, and a built-in object detector (the package has a hook for one, D142).
- A replication record in the repository of the package (D158).
- A GUI in the package (D165). The Space is the build mode, and vignette 6 has a short app for the use mode.

Anti-goals. The work fails if one of these is true, even if all code runs:

- An API key goes into a printed object, a saved setup, a `path` file, a link or an error message.
- A failed call is dropped, or is scored as a wrong answer, without a visible error.
- The package sends an image to a model that the table says reads only text, unless the user overrides the table.
- The package blocks a request because of a size limit that it assumes.
- The package shows an estimated cost as if the provider reported it.
- A CRAN check or a test makes a network call or needs a key.
- `score_setup()` scores rows that are marked as test data.
- The API of the package is specific to quality control.

## 3. Models and request formats

### 3.1 The models of interest (2026-10-23)

The facts below come from the web pages in the section "Sources". These facts change (D161). The builder checks them against the documentation of each provider, and with real calls (D153), before the code uses them.

| Model | Maker | Weights | Input | Request format | Where it runs |
|---|---|---|---|---|---|
| Jev | TypeSafe AI | closed | text; images only with the header `TypeSafe-Danger-Zone-Images: true` | SystemOne | TypeSafe API, OpenRouter |
| Microsoft-Decision-1 | Microsoft | closed | text only | close to SystemOne (Foundry) | Microsoft Foundry, OpenRouter |
| Decisions API, `gpt-6-luna` | OpenAI | closed | text, images, JSON | OpenAI Decisions | OpenAI |
| Clef, Clef-Flash | Cloudflare | open, Apache 2.0 | text and images | SystemOne, with an ordered image list | weights on Hugging Face; SGLang server (as in our study) |
| Laya (3 checkpoints) | Convai Innovations | open, Apache 2.0 | text only; runs on a CPU | SystemOne (`laya-serve`) | weights on Hugging Face; own server |
| pplx-decider | Perplexity | open | text and images (one source) | not clear | Perplexity API; weights on Hugging Face |

Hugging Face has no common way to call decision models. The open decision models put their weights on Hugging Face and bring their own server, and these servers speak SystemOne.

### 3.2 Request formats

1. SystemOne: `POST <base_url>/v1/systemone` with `model`, `state`, `assets` and a `questions` object keyed by name. TypeSafe, `laya-serve` and Foundry (approximately) use it.
2. SystemOne with an ordered image list: the SGLang server of Clef-Flash ignores `assets`. It takes an `images` list of data URLs, and the state text says which image is which (`image_format = "images"` in `R/industrial_defect_classifier.R`).
3. OpenAI Decisions: `POST /v1/decisions` with `input` (a text, or messages with `input_text`, `input_image` and `input_json`) and a `questions` array.
4. OpenRouter decisions: `POST https://openrouter.ai/api/alpha/decisions` (alpha), with `model`, `state` and a `questions` map (secondary sources).

| Package | SystemOne | OpenAI Decisions | Answer in the package |
|---|---|---|---|
| noul (yes or no) | `noul` | `predicate` | probability of yes |
| choice | `choice` | `choice` | chosen option and a probability per option |
| score | `score` | `score` | weighted score and a probability per level |

A small internal translator for each format builds the request and reads the response. A new format is a new translator. Each translator puts the parts that all inputs share first (instructions, then references) and the input last. Then the prompt caching of a provider can work (OpenAI caches a shared start of 1,024 tokens or more and charges less for it). Claude call.

## 4. The API

### 4.1 Exported functions (14)

| Group | Function | What it does |
|---|---|---|
| Models | `decider_typesafe(model, credentials, input)` | Jev |
| | `decider_openai(model, credentials, input)` | the OpenAI Decisions API |
| | `decider_foundry(endpoint, deployment, credentials, input)` | Microsoft-Decision-1 on Microsoft Foundry |
| | `decider_openrouter(model, credentials, input)` | Jev or Microsoft-Decision-1 through OpenRouter |
| | `decider_systemone(base_url, model, image_format, credentials, input)` | any SystemOne server, for example Clef-Flash or Laya on the computer of the user |
| Questions | `question_noul(instructions, true, false)` | a yes-or-no question |
| | `question_choice(instructions, choices)` | one answer from named options with descriptions |
| | `question_score(instructions, levels)` | an ordered score with described levels |
| Asking | `decide(decider, questions, text, image, references, max_size, upscale, crop, max_active, rpm, path, ignore_hash)` | one input or many, one model or a named list of models; returns a tibble |
| Setups | `decision_setup(decider, questions, references, max_size, upscale, crop, calibrator)` | one complete decision, in memory |
| | `write_setup(setup, path)`, `read_setup(path)` | save a setup as one JSON file, and read it |
| Tuning | `score_setup(setup, text, image, truth, role, metric, path)` | score one setup or a named list of setups on learning rows |
| | `evaluate_once(setup, text, image, truth, path)` | score the test rows one time only |

`decide()`, `score_setup()` and `evaluate_once()` also accept a setup in place of `decider` and `questions`.

### 4.2 Internal

- The four request translators and the parsing of the answers.
- Image preparation with magick: size, upscale, crop, and the crop function.
- The checks that keep each answer inside the allowed answers.
- The table of input types (text, image or both), with the date of each row.
- The search for keys: environment variables, or the `credentials` function.
- Parallel requests and retries with httr2.
- The `path` files: the hash, the chunks, the reading at a new run.
- The ROC AUC of `score_setup()`.
- The application of a probably calibrator that a setup holds.
- The JSON layout of a setup.

## 5. Behavior

### 5.1 Models and credentials (D143, D161)

- Credentials work as in ellmer. By default, the key comes from an environment variable: `TYPESAFE_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY` or the Foundry key. `credentials` takes a function that returns the key, for example for an Azure (Entra ID) token. No object stores or prints the key.
- When the user gives no `model`, the package prints the default model that it uses, as ellmer does. When a provider retires a model, the user sees which name to change.
- `input` (`"text"`, `"image"` or `"text+image"`) overrides the table of input types. For a model that is not in the table (for example a new model on `decider_systemone()`), the package does not check the input type.

### 5.2 decide()

- Inputs: `text` is a character vector; `image` is a vector of file paths or URLs, or a list of magick images. One element is one input. With both, element i of each is one input.
- Image preparation is set by arguments (D142): `max_size` (default 768), `upscale` (default `FALSE`), and `crop`: `"none"`, `"center"`, a box (x, y, width, height), or a function that takes a magick image and returns a box. The function is the hook for an object detection model. magick is needed only for images.
- `references`: reference examples per answer, for models that use them.
- Several models: `decider` can be a named list of models. All requests of all models go into one parallel pool (`httr2::req_perform_parallel()`), so the models run at the same time. The output has one row per input and model, with the name in `.model`. If a model in the list reads only text and the input has an image, `decide()` stops before any call and names the model.
- `path` (Claude call, as `ellmer::batch_chat()`): a JSON file that keeps the finished answers. The inputs go out in chunks (a few times `max_active`), and the file is written after each chunk. The file holds a hash of the models, the questions, the references and the image settings. At a new run with the same `path`, `decide()` reads the file, checks the hash (it stops on a different hash unless `ignore_hash = TRUE`), and sends only the inputs that are not in the file. Failed calls do not go into the file, so a new run tries them again. Without `path`, nothing is written.
- Retries (Claude call): the package retries a call only when the server surely did not process it (HTTP 429, or no connection). After a timeout or an HTTP 5xx error, the row gets an `.error`, and a new run with `path` tries it again.

### 5.3 The output of decide()

- One row per input (and per model). For each question: the answer (a factor with the allowed answers) and one probability column per allowed answer. The probability columns use the names of tidymodels (`.pred_<answer>`, with the name of the question as a prefix when there is more than one question), so that probably and yardstick read the output with no extra code (D164).
- `.model`, `.input_tokens`, `.cost`, `.seconds`, `.error`.
- `.cost` (D162) holds only the cost that the provider reports in the response. When a provider does not report it, `.cost` is `NA`, and `decide()` prints one message, for example: "TypeSafe does not report a cost. `.cost` is NA. `.input_tokens` has the input tokens." The package has no prices.
- An answer outside the allowed answers, or a failed call, gives `NA` answers and the message in `.error`. The error text of the provider is kept word for word, with the model name and the size of the request (D161). The row stays in the output.

### 5.4 Calibration

- The package does not fit calibrators (D164). The probably package of tidymodels does: `probably::cal_estimate_logistic()`, `cal_estimate_isotonic()`, `cal_estimate_beta()` and `cal_estimate_multinomial()` fit a calibrator, and `probably::cal_apply()` applies it. tailor wraps the same functions as a step of a workflow (`tailor::adjust_probability_calibration()`).
- probably is in Suggests. It brings about 97 more packages (tune, workflows, ggplot2, furrr and others), so only the users who calibrate install it.
- The "logistic" method of probably is a smooth GAM by default; with `smooth = FALSE` it is a logistic regression on the probability. Neither is exactly the Platt scaling of the study (a logistic regression on logit(p) with the targets of Platt). The numbers of vignette 5 can therefore differ a little from the paper (D156 allows this).
- Choice questions with three or more options use the multinomial method, so the package has no limit on the number of options.

### 5.5 Setups (D147)

- `decision_setup()` holds one complete decision: the model (name, URL, input types; no key), the questions and their descriptions, the references, the image settings and the calibrator.
- `write_setup()` writes one JSON file, with the reference images after preparation (base64). Claude call. An agent can edit the descriptions as text, and git shows the changes, as in the diffs of our description loops. `read_setup()` reads it.
- The calibrator in a setup is a probably calibrator (D164), stored in the JSON file as a serialized R object, with a hash of the questions and the references at the time of the fit. When the questions or the references change, `read_setup()` drops the calibrator with a warning, because a calibrator fitted for the old descriptions does not apply to the new ones. `decide()` applies the calibrator of a setup (probably must be installed).
- Uses: the Space and the app of vignette 6; the agent skill; sharing with a co-author.

### 5.6 Tuning and the guard for test data (D148, D155)

- Data roles: learning rows (for tuning; the references come from them, and only the other learning rows are scored), calibration rows (for `calibrate()`) and test rows (for `evaluate_once()`).
- `score_setup()` takes one setup or a named list of setups. It sends all calls in one parallel pool and returns one row per setup: the metric (ROC AUC by default), the number of inputs, the calls, the input tokens, the reported cost, the seconds and the errors, with the answers per input in a list column. With `role`, it refuses rows marked `"test"`. With `path`, it continues a stopped run.
- Two ways to tune, both shown in vignette 5:
  - A grid: a tibble of candidates (for example wordings by k by model), turned into setups and scored in one call. This suits k, the image size, the model and a few written wordings.
  - One change at a time, as in the description loop of the study: a person or an agent looks at the mistakes, writes one new wording, scores it, and keeps it only when the ROC AUC rises by at least 0.02.
- `evaluate_once()` scores the test rows one time only, as `scripts/evaluate_frozen.R` did. It refuses a second run when its result file exists.
- The documentation says that these guards stop mistakes, not an agent that reads files with a shell (O5).

### 5.7 Agent skill (D148)

- The skill is in `inst/skills/decisions/` (`SKILL.md` and reference files), as in commons 0.1.1. Its description names the functions of the package, so that an agent loads it when a project uses them. Vignette 1 shows how to copy it to `.claude/skills` or `.agents/skills` with `system.file()` and `file.copy()`.
- Reference files (Claude call): writing questions; tuning descriptions; calibration and evaluation; sharing a setup.
- The rules come from the description loop of the study (`scripts/fair_loop_instructions.md`): the 0.02 keep rule; base each change on what the examples show; change one idea at a time; prefer a clear, general description over a long list of special cases; do not aim for an AUC of 1; use only learning rows. The skill has no fixed length limit (D161). When a provider refuses a long candidate, the agent reads the error and shortens the text.

### 5.8 Apps outside the package (D147, D165)

The package has no GUI (D165). Two Shiny apps outside the package read its setup files:

- The build mode is the Hugging Face Space (D157, section 8): pick text or images, write the questions, choose a model, try a few examples, calibrate, see the answers with tokens, cost and time, and download the setup.
- The use mode is a short app (about 30 lines) in vignette 6: read a setup, take a text or an image, call `decide()`, and show the answer and how sure the model is. A teacher can share the rubric checker with students on Posit Connect or a Space.

The lessons of querychat 0.3.0 apply to both apps:

- Show what makes the result: the model, the questions and the descriptions of the setup, and offer the setup file and the R code that repeats the result (querychat shows its SQL "for transparency and reproducibility").
- Say which provider receives each text or image.
- Accept a `credentials` function, so a host such as Posit Connect can give the key in each session (querychat added `$server(client = ...)` for this).
- Give a stop button for long batches.
- The key is a secret of the host, never a field of the app.
- No chat helper: a chat helper needs a chat model, which D136 keeps out.

### 5.9 Dependencies

- Imports (Claude call): httr2, S7, rlang, cli, tibble, jsonlite.
- Suggests: magick (images), probably (calibration), testthat, withr, knitr, rmarkdown, and the packages of the vignettes (rsample, yardstick, dplyr). livelink is not a dependency (D151). shiny is not a dependency: the app chunk of vignette 6 is shown, not run, on CRAN (D165).
- No compiled code (D139), so the package builds in webR.

## 6. Build and tests (D153, D158)

- Claude Code builds the package in a new local folder, `C:/Users/megahefm/Dropbox/Miami/Code/claude/decisions` (a sibling of this repository, not inside it), with git and no remote. Claude Code does not push it (D158). fmm makes the GitHub repository and pushes when fmm wants.
- The package repository has no replication record (D158). The records of M3 stay in this repository.
- Unit tests use `httr2::local_mocked_responses()` with saved responses of each request format. They make no network call and need no key. The saved responses come from real calls to TypeSafe, OpenAI, Foundry or OpenRouter, and the local servers (D153), with keys removed.
- Tests of the guards: no image to a model that reads only text; no key in a printed object, a setup file or a `path` file; a failed call stays in the output with `.error`; the provider error is kept word for word; `.cost` is `NA` with a message when the provider reports no cost; `path` continues a stopped run and stops on a different hash; `score_setup()` refuses test rows; `evaluate_once()` refuses a second run.
- `R CMD check --as-cran` passes with no error, warning or note (except the note of a new submission).
- Claude Code then runs the workflow end to end with real calls: each vignette, and vignette 5 in full. Each live call needs a budget row in `replication_materials/calls/README.md` that fmm approves before the first call.
- Then fmm tests the package with the code of vignette 5 (D158).

## 7. Vignettes (D140, D141, D149, D150, D156)

| # | Title (draft) | Models | Content |
|---|---|---|---|
| 1 | Getting started with text | a text model (Jev or Laya) | the three question types (noul, choice, score) on short texts, such as support tickets; one input, then many; how to copy the agent skill |
| 2 | Images | Jev, OpenAI, Clef-Flash | the image inputs and arguments (size, resolution, crop, crop function); references per answer; the simulated textiles of the study |
| 3 | Choosing a model | Jev, Microsoft-Decision-1, OpenAI | credentials as in ellmer; one text task on a list of models in one `decide()` call; performance with yardstick, and the reported cost and time with dplyr |
| 4 | Open models on your own computer | Laya | no key and no cost per call; only the URL changes |
| 5 | The study again, with the package | all models that read images: Jev, OpenAI `gpt-6-luna`, Clef-Flash (and Clef 27B if it fits on the GPU) | D156: the pipeline of the study with the package, new paid calls, no CLIP: learning, calibration and test rows; a tuning grid for k, the image size and the model; one change at a time for the wording (by hand or with the skill); calibration; `evaluate_once()`; rsample folds over the learning rows to show how much the AUC moves; yardstick metrics. The results can differ from the paper. |
| 6 | Grading short answers with a rubric | a text model | each idea of a rubric and each known wrong claim is a noul question; the student sees only rubric text; sample answers written for the vignette set the threshold; questions about the package itself; a short Shiny app that shares the checker as a setup (the use mode, D165) |

- Vignette 6 credits three sources (D150): Jeffrey Biles of PhysicsGraph for the idea to check an explanation while the student types it (https://x.com/JeffreyBiles/status/2107211222320021722, as cited in the README of fmegahed/isa401); the course ISA 401 of fmm at Miami University; and the exam-review game (https://isa401-review.vercel.app, https://github.com/fmegahed/isa401/tree/main/games/exam-review).
- Microsoft-Decision-1 and Laya read only text. They are in vignettes 1, 3, 4 and 6, not in the image vignettes.
- Claude call: on CRAN, each vignette reads saved results (small `.rds` files in `inst/extdata`), because CRAN checks run without network and keys. The live code is on the package website. The saved results of vignette 5 come from the validation run of Claude Code (section 6).
- Vignette 5 ships numbers and image names, not images. The builder checks that the licence of each dataset (AutoVI is CC BY-NC-SA 4.0) allows this.

### 7.1 webR (D145, D151)

- The first choice is webR itself: the reader runs our code in the browser.
- ChatISA (fmegahed/chatisa) shows that webR reaches the internet with httr2 when the page is cross-origin isolated and `ALL_PROXY` points R's libcurl at a websocket proxy (the public r-universe proxy). Without isolation, webR loses all networking (ChatISA ADR-023). On 2026-10-23, the public webR console and the Shinylive editor sent the headers of cross-origin isolation.
- Example A (no key): calibration on saved probabilities of the study. It needs no network.
- Example B (own key): install the package from r-universe, set the proxy, paste a key, ask one noul question about a short text. A test must confirm example B first. The call stays encrypted from webR to the provider; the proxy sees only the host name.
- livelink (CRAN) is the fallback if webR itself is not possible. The authors use it once to make links, and the documents hold the links as plain URLs. It is not a dependency (D151).

## 8. Outside the package

- The Hugging Face Space (D157, D165): the build mode, a Shiny app on a free CPU Space, with Laya on the same CPU, so a visitor can try text decisions with no key. Image decisions need a hosted model and the key of the visitor, which the Space never stores. The Space is not part of the package. The documentation of the package links to it. The speed of Laya on the 2 vCPUs of a free Space is not known yet.
- The repository of the package: fmm makes it (section 6).
- The paper: one sentence about the package; fmm writes it.

## 9. Release plan

Claude call: one first release, 0.1.0, with the 14 functions, the skill, the six vignettes and webR example A. Example B follows when a test confirms it. The release goes to CRAN when it is complete (D154).

## 10. Decisions and their impacts

| ID | Decision | Impact on this design |
|---|---|---|
| D136 | System One models only | no chat models; section 3 |
| D137 | batches, typed answers, calibration, ML-style experiments | sections 5.2 to 5.6 |
| D138 | experiments inside tidymodels, a plus | vignette 5 uses rsample and yardstick |
| D139 | a self-contained sister of ellmer | httr2; no compiled code |
| D140, D149 | six vignettes | section 7 |
| D141 | vignette 1 shows noul, choice and score | section 7 |
| D142 | image preparation by arguments; detector hook | section 5.2 |
| D143 | credentials as in ellmer | section 5.1 |
| D144, D156 | vignette 5 does the study again with the package, all image models, no CLIP | section 7 |
| D145, D151 | webR first; livelink only as a fallback, not a dependency | section 7.1 |
| D146, D152 | the name decisions | all |
| D147, D165 | build and use modes share a saved setup; both apps are outside the package | sections 5.5, 5.8 |
| D148 | agent skill in the package, as in commons | section 5.7 |
| D150 | vignette 6 as a grading option, with credits | section 7 |
| D153 | live tests with all four providers | section 6 |
| D154 | no fixed date for CRAN | section 9 |
| D155 | a guard for test data in the package, rules in the skill | section 5.6 |
| D157 | the Space with Laya, outside the package | section 8 |
| D158 | no record and no push in the package repository; Claude Code tests all, then fmm | section 6 |
| D159 | no spending management | non-goals |
| D160 | a small package | section 4 |
| D161 | the provider is the authority on limits; only input types, dated and overridable | sections 5.1, 5.3 |
| D162 | only the reported cost; say so when there is none | section 5.3 |
| D163 | no claim that a model was the first decision model | section 1 |
| D164 | calibration with probably, not in the package; tidymodels names for the probability columns | sections 4.1, 5.3 to 5.5 |
| D165 | no GUI in the package; the Space and a short app in vignette 6 | sections 5.8, 7, 8 |

## 11. Left to the builder

- The exact column names of the output and the JSON layouts of a setup and of a `path` file.
- The chunk size of `path` and the retry details for each provider.
- The input types in the table, checked against each provider on the day of the release.
- The wording of the skill files, in the style of the commons skill.

## 12. Claude calls for fmm to check

1. S7 classes and the names of the 14 functions (section 4.1).
2. `decide()` takes a named list of models and runs them in one pool (section 5.2).
3. `decide()` has `path` and `ignore_hash`, as `ellmer::batch_chat()` (section 5.2).
4. Retries only when the server surely did not process the call (section 5.2).
5. Translators put the shared parts first, for the prompt caching of providers (section 3.2).
6. A setup stores the probably calibrator as a serialized R object and drops it when the questions change (section 5.5).
7. A setup is one JSON file with the reference images in it (section 5.5).
8. `score_setup()` takes a named list of setups (section 5.6).
9. The lessons of querychat for the two apps outside the package (section 5.8).
10. The dependencies, with magick in Suggests (section 5.9).
11. Vignettes read saved results on CRAN (section 7).
12. Vignette 6 uses sample answers written for it (section 7).
13. pplx-decider stays out of 0.1.0 until its request format is known (section 3.1).
14. One first release with all 14 functions (section 9).

## 13. Builder check and answers

A fresh reviewer read revision 1 as a builder (2026-10-23) and asked seven questions. Claude Code settled four. fmm answered three, and the name, with D152 to D155. D156 to D162 then changed revision 1: vignette 5 makes new calls; the spending cap, the cache, the prices, the report function and the parsnip engine are gone.

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
- Installed versions checked on 2026-10-23: ellmer 0.5.0 (no answer cache; `batch_chat()` keeps a JSON state file with a hash; `parallel_chat_structured()` has `max_active`, `rpm` and `on_error`; `cache` in `chat_anthropic()` is the prompt caching of the provider), tailor 0.1.0, shinychat 0.5.0, httr2 1.2.3 (`req_perform_parallel()` with `on_error = "continue"`).
