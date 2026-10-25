# The Hugging Face Space of decisions: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public R Shiny app on a Docker Space, `fmegahed/decisions`, that asks Jev a noul, choice or score question about each of a set of images or texts, shows the answers, and gives the R code and a bundle of the run.

**Architecture:** One Shiny app in its own repository, `decisions-space`, after the Space structured_text_extraction (app 1). Pure functions in `R/` (spec, data, runs, spending, answers, code, bundle, status) carry the logic and the tests; `R/ui.R` and `R/server.R` wire them. Calls to Jev go through `decisions::decide()` in chunks of 10, as an `ExtendedTask` on mirai daemons, with injectable dependencies so that the tests use a mock and make no call.

**Tech Stack:** R 4.6.1, shiny, decisions (commit b25fc9f), mirai, dplyr, purrr, stringr, tibble, readr, jsonlite, httr2, yardstick, magick, zip, testthat, shinytest2 (+ axe-core 4.10.2), Docker (`rocker/shiny:4.6.1`), GitHub Actions, Hugging Face Spaces.

**Spec:** `replication_materials/plans/2026-10-24-decisions-space-design.md` (revision 2, approved D242). Mockup: `replication_materials/plans/2026-10-24-decisions-space-mockup.png`.

## Global Constraints

- Repository: `C:\Users\megahefm\Dropbox\Miami\Code\claude\decisions-space` (new git repository, branch `main`). GitHub `fmegahed/decisions-space` (public, MIT). Space `fmegahed/decisions` (private until fmm makes it public). Usage dataset `fmegahed/decisions-space-usage` (private).
- Model `jev-1.14.0` (constant `MODEL`, written nowhere else in the app code). Image settings `max_size = 768`, `upscale = TRUE`, `crop = "none"`.
- The key: only through `\() Sys.getenv("HF_JEV_API")`. Never in the UI, a log, the bundle, a test fixture or a commit. The usage token: `HF_USAGE_TOKEN`, read only by the usage store.
- The `.error` text of `decide()` holds the provider text word for word and can hold a part of a key. The app never shows it and never logs it: it shows and logs only the category of `classify_error()`.
- Price: USD 0.042 per million input tokens. Limits (UTC): USD 0.25 each session, USD 2 each day, USD 20 each month. Token guesses before the first call: 16,000 for an image call, 1,000 for a text call.
- Input limits: 5 MB for each file, 50 MB for a zip file, 100 images or 200 texts in a run, 4,000 characters in a text, 500 in instructions, 300 in a description; choice 2 to 6 answers, score 2 to 5 levels; at most 2 references for each answer. Chunks of 10 inputs.
- Labels in the app are short nouns: "Help", "Answers", "R code", "About", "Record", "Video", "Import", "Samples". Never "How to read this" or a question.
- WCAG 2.2 AA. Palette: Miami Red #C41230, Light Tan #EDECE2, Medium Tan #CCC9B8, Dark Tan #70685C, Warm White #FAF9F7, Slate Blue #3E5468, ink #1b1b1b, muted text #5f5a52, code background #fbfaf7, code comments #5f5a52, functions #3E5468, strings #7a3e00. Fonts Source Serif 4, Source Sans 3, IBM Plex Mono, served from `www/fonts`.
- At run time the app calls only TypeSafe (through decisions), the Hugging Face API (usage dataset), `raw.githubusercontent.com` (status) and, after a click on Video, `youtube-nocookie.com`.
- R style: tidyverse verbs with `|>`, `pkg::fun` calls (no `library()` in `R/`), yardstick for metrics, `<-`, the simplest code that passes the tests. Comments in the style of app 1.
- Text in the README, About and help: 80% ASD-STE100. No claim that any model was the first (D163).
- Run R from the `decisions-space` folder with `"/c/Program Files/R/R-4.6.1/bin/Rscript.exe"`. Never start R from fine_tuned_jev.
- Commit messages end with the two trailer lines of the session (Co-Authored-By and Claude-Session).
- Paid calls: none before fmm approves a budget row in `fine_tuned_jev/replication_materials/calls/README.md`. Tasks 1 to 11 make no paid call.

## Review Focus

1. A zip file from macOS or Windows (entries `__MACOSX/`, `.DS_Store`, `Thumbs.db`, nested top folder, spaces and non-ASCII in names, the same file name in two folders): the junk entries are skipped, a single top folder is unwrapped, and every input gets a unique id. Test in Task 3.
2. Folder names that differ from the answer names only by case or spaces ("Defective ", "nominal"): the app matches them after `stringr::str_squish()` and `stringr::str_to_lower()`, and lists any folder that still does not match. Test in Task 3.
3. A run when the key is missing or wrong (`decide()` aborts before any request, or every row is HTTP 401): no crash, no spend, the message "The demo is not available right now.", and no more calls that day. Test in Task 4 and Task 10.
4. A CSV with a UTF-8 BOM, Latin-1 text, empty rows or a label column with blanks: empty texts are dropped with a count, blanks are unlabelled, the text reads correctly. Test in Task 3.
5. A run that crosses midnight UTC, or two sessions near the day limit: the day key is the UTC date at the time of each write, and the check before a run uses the latest totals of the store. Test in Task 5.

---

### Task 1: Repository, configuration and Docker image

**Files:**
- Create: `README.md` (Space metadata), `LICENSE` (MIT, Fadel M. Megahed and Ying-Ju Chen, 2026), `.gitignore`, `.dockerignore`, `Dockerfile`, `app.R`, `R/_disable_autoload.R`, `R/config.R`, `tests/testthat.R`, `tests/testthat/test-config.R`, `.github/workflows/tests.yml`

**Interfaces:**
- Produces (in `R/config.R`): `APP_VERSION` ("1.0.0"), `APP_DATE`, `MODEL`, `DECISIONS_SHA` ("b25fc9ffa7908e9a6a2d9833f080de1456c9d50a"), `PRICE_PER_TOKEN` (0.042 / 1e6), `LIMIT_SESSION` (0.25), `LIMIT_DAY` (2), `LIMIT_MONTH` (20), `TOKENS_GUESS` (`c(image = 16000, text = 1000)`), `MAX_FILE_MB` (5), `MAX_ZIP_MB` (50), `MAX_IMAGES` (100), `MAX_TEXTS` (200), `MAX_TEXT_CHARS` (4000), `MAX_INSTRUCTIONS` (500), `MAX_DESCRIPTION` (300), `ANSWER_RANGE` (`list(choice = c(2, 6), score = c(2, 5))`), `MAX_REFERENCES` (2), `CHUNK_SIZE` (10), `IMAGE_SETTINGS` (`list(max_size = 768, upscale = TRUE, crop = "none")`), `KEY_VAR` ("HF_JEV_API"), `USAGE_TOKEN_VAR` ("HF_USAGE_TOKEN"), `USAGE_REPO`, `STATUS_URL` ("https://raw.githubusercontent.com/fmegahed/decisions-space/main/status/status.csv"), `SPACE_HOST` ("https://fmegahed-decisions.hf.space"), `VIDEO_URL` (""), `app_config()` (a named list of all values that the help text uses).
- Produces (in `app.R`): the order of `source()` calls for `R/*.R`; `options(shiny.maxRequestSize = MAX_ZIP_MB * 1024^2)`.

- [ ] **Step 1: Make the folder, `git init -b main`, and check the local packages.** Run `Rscript -e "for (p in c('shiny','decisions','mirai','dplyr','purrr','stringr','tibble','readr','jsonlite','httr2','yardstick','magick','zip','testthat','shinytest2','withr')) cat(p, requireNamespace(p, quietly = TRUE), '\n')"`. Install what is missing (decisions with `pak::pak("url::https://github.com/fmegahed/decisions/archive/b25fc9ffa7908e9a6a2d9833f080de1456c9d50a.tar.gz")`).

- [ ] **Step 2: Write the failing test** `tests/testthat/test-config.R`:

```r
test_that("the limits and the model are the values of the design", {
  expect_identical(MODEL, "jev-1.14.0")
  expect_equal(c(LIMIT_SESSION, LIMIT_DAY, LIMIT_MONTH), c(0.25, 2, 20))
  expect_equal(PRICE_PER_TOKEN * 1e6, 0.042)
  expect_identical(IMAGE_SETTINGS, list(max_size = 768, upscale = TRUE, crop = "none"))
  expect_identical(VIDEO_URL, "")
})

test_that("the model id is written only in R/config.R", {
  files <- c("app.R", list.files("R", full.names = TRUE)) |> setdiff("R/config.R")
  hits <- purrr::keep(files, \(f) any(stringr::str_detect(readLines(f), "jev-[0-9]")))
  expect_length(hits, 0)
})
```

`tests/testthat.R` sources `R/*.R` in the order of `app.R` (one helper, `tests/testthat/helper-app.R`, does it, as in app 1) and runs `testthat::test_dir("tests/testthat")`.

- [ ] **Step 3: Run it and see it fail.** `Rscript tests/testthat.R` → FAIL: `MODEL` not found.

- [ ] **Step 4: Write `R/config.R`, `app.R` (a page with the top-bar title "decisions" and `<meta name="app-version" content="1.0.0">`), `R/_disable_autoload.R`.** `README.md` starts with the Space metadata (`title: decisions`, `emoji`, `colorFrom: red`, `colorTo: yellow`, `sdk: docker`, `app_port: 7860`, `license: mit`, `short_description`), then a short README in STE (filled in Task 12). `.gitignore` and `.dockerignore`: `.env`, `.Renviron`, `.Rhistory`, `.RData`, `.Rproj.user/`, `tests/` (docker only), `.git`, `.github`, `status/` (docker only).

- [ ] **Step 5: Run the tests.** `Rscript tests/testthat.R` → all PASS.

- [ ] **Step 6: Write the `Dockerfile`.** `FROM rocker/shiny:4.6.1`; system libraries `libcurl4-openssl-dev libssl-dev libxml2-dev libmagick++-dev libfontconfig1-dev libfreetype6-dev`; `install.packages('pak')`; `pak::pak('url::https://github.com/fmegahed/decisions/archive/b25fc9ffa7908e9a6a2d9833f080de1456c9d50a.tar.gz')`; the other runtime packages with `pak::pak()` at the versions installed in Step 1 (`pkg@version`); a last line that loads each package; `COPY app.R ./`, `COPY R/ ./R/`, `COPY www/ ./www/` (one line each, so the folders stay); `CMD ["R", "--quiet", "-e", "shiny::runApp(host='0.0.0.0', port=7860)"]`.

- [ ] **Step 7: Build the image.** `docker build -t decisions-space .` → success, and the last `RUN` prints no error. `docker run --rm -p 7860:7860 decisions-space` serves the page at http://localhost:7860 (check with `curl -s localhost:7860 | grep app-version`), then stop the container by its ID.

- [ ] **Step 8: Write `.github/workflows/tests.yml`** after app 1: on push and pull request; job `tests`: `r-lib/actions/setup-r` (R 4.6.1, public RSPM) and `setup-r-dependencies` with the packages of Step 1 (decisions as `url::https://github.com/fmegahed/decisions/archive/b25fc9ffa7908e9a6a2d9833f080de1456c9d50a.tar.gz`), then `Rscript tests/testthat.R`; job `docker`: `docker build -t decisions-space .` (no push). Pin every action to a commit SHA with a `# vN` comment; `permissions: read-all`.

- [ ] **Step 9: Commit.** `git add -A && git commit -m "Repository, configuration and Docker image"`.

### Task 2: Run spec, questions and samples

**Files:**
- Create: `R/spec.R`, `R/samples.R`, `tests/testthat/test-spec.R`, `tests/testthat/test-samples.R`

**Interfaces:**
- Consumes: the constants of Task 1.
- Produces:
  - A *question* is `list(type = "noul" | "choice" | "score", instructions = <chr1>, answers = <named chr>)`; names are answer names, values are descriptions (`""` for none). For noul the names are `c("true", "false")`.
  - A *spec* is `list(mode = "image" | "text", question, references = <named list of file paths, or NULL>, inputs = <tibble>, source = "textiles" | "injuries" | "upload" | "import", name = <chr1, file-safe>)`.
  - *inputs* is a tibble with `id` (chr, unique), `path` (chr or NA), `text` (chr or NA), `file` (chr, display name), `label` (chr or NA).
  - `check_question(question) -> character()` (problems, empty when valid).
  - `as_decisions_question(question) -> <decisions question>` (`decisions::question_noul()`, `question_choice()` or `question_score()`).
  - `target_answer(question, pick = NULL) -> chr1`: `"true"` for noul; else `pick` if it is an answer, else the last answer.
  - `spec_fingerprint(spec) -> chr1`: `rlang::hash()` of mode, type, instructions, answers, `MODEL`, and the basenames and sizes of the references.
  - `sample_spec(id) -> spec` and `sample_answers(id) -> tibble` (the saved `decide()` output, with `id`), for `id` in `c("textiles", "injuries")`.
  - `SAMPLE_FACTS`: `list(textiles = c(auc = 0.75, accuracy = 0.80), injuries = c(accuracy = 0.96))` and their help sentences.

- [ ] **Step 1: Write the failing tests.**

```r
test_that("check_question() enforces the limits of the design", {
  ok <- list(type = "choice", instructions = "Which?", answers = c(a = "", b = ""))
  expect_length(check_question(ok), 0)
  expect_match(check_question(modifyList(ok, list(answers = c(a = "")))), "2 to 6")
  seven <- setNames(rep("", 7), letters[1:7])
  expect_match(check_question(modifyList(ok, list(answers = seven))), "2 to 6")
  expect_match(check_question(modifyList(ok, list(type = "score", answers = seven[1:6]))), "2 to 5")
  long <- strrep("x", 301)
  expect_match(check_question(modifyList(ok, list(answers = c(a = long, b = "")))), "300")
  expect_match(check_question(modifyList(ok, list(instructions = strrep("x", 501)))), "500")
  expect_match(check_question(modifyList(ok, list(answers = c(a = "", A = "")))), "unique")
})

test_that("as_decisions_question() makes the question of the package", {
  q <- list(type = "score", instructions = "How bad?", answers = c(low = "", high = "Very bad."))
  expect_true(S7::S7_inherits(as_decisions_question(q), decisions::question_score))
})

test_that("target_answer() follows the design", {
  noul <- list(type = "noul", instructions = "?", answers = c(true = "", false = ""))
  ch <- list(type = "choice", instructions = "?", answers = c(nominal = "", defective = ""))
  expect_identical(target_answer(noul), "true")
  expect_identical(target_answer(ch), "defective")
  expect_identical(target_answer(ch, "nominal"), "nominal")
  expect_identical(target_answer(ch, "other"), "defective")
})

test_that("the samples match the saved runs of the vignettes", {
  tex <- sample_spec("textiles")
  expect_identical(tex$question$instructions, "Does the woven pattern in `inspection_image` have a flaw?")
  expect_identical(names(tex$question$answers), c("nominal", "defective"))
  expect_identical(basename(tex$references$nominal), c("nominal_textile_0731.jpg", "nominal_textile_0630.jpg"))
  expect_identical(basename(tex$references$defective), c("local_textile_0471.jpg", "global_textile_0330.jpg"))
  expect_equal(nrow(tex$inputs), 46)
  expect_identical(nrow(sample_answers("textiles")), 46L)
  inj <- sample_spec("injuries")
  expect_equal(nrow(inj$inputs), 75)
  expect_identical(names(inj$question$answers), c("amputation", "fracture", "crushing injury", "thermal burn", "concussion"))
  expect_true(all(file.exists(tex$inputs$path)))
})

test_that("the fingerprint changes when the question changes", {
  tex <- sample_spec("textiles")
  edited <- tex
  edited$question$instructions <- "Is there a flaw?"
  expect_false(identical(spec_fingerprint(tex), spec_fingerprint(edited)))
})
```

- [ ] **Step 2: Run them and see them fail.** `Rscript tests/testthat.R` → FAIL: functions not found.

- [ ] **Step 3: Write `R/spec.R` and `R/samples.R`.** The samples read the installed package: `system.file("extdata", "textiles", package = "decisions")`, `decisions::textiles`, `system.file("extdata", "images.rds", ...)` (`$inputs`, `$answers$jev`) and `system.file("extdata", "choosing-a-model.rds", ...)` (`$injuries`, `$answers$jev`). The instructions and descriptions are copied from the vignettes `images.Rmd` (lines 119 to 124) and `choosing-a-model.Rmd` (the `nature` question), word for word. References: `textiles` rows with `role == "reference"`, ordered by `class` then `reference_rank`.

- [ ] **Step 4: Run the tests.** → all PASS.

- [ ] **Step 5: Commit.** `git commit -am "Run spec, questions and samples"` (add the new files first).

### Task 3: Data of the visitor

**Files:**
- Create: `R/data.R`, `tests/testthat/test-data.R`, `tests/testthat/fixtures/` (small JPEGs made in the test with magick, and CSV text written in the test)

**Interfaces:**
- Consumes: inputs tibble of Task 2; limits of Task 1.
- Produces:
  - `read_images(files) -> list(inputs = <tibble>, problems = <chr>)`. `files` has the columns `name` and `datapath` of `shiny::fileInput()`. A zip file is unpacked into `tempfile()`; a folder below the (single, unwrapped) top level gives the label; loose files are unlabelled. Accepts `.jpg`, `.jpeg`, `.png`, `.webp`; skips `__MACOSX/`, dot files and `Thumbs.db`.
  - `read_references(files) -> list(paths = <chr>, problems = <chr>)`: at most `MAX_REFERENCES`.
  - `read_text_paste(text) -> list(inputs, problems)`: one input for each paragraph (split at one or more blank lines).
  - `csv_columns(path) -> chr`; `read_text_csv(path, text_col, label_col = NULL) -> list(inputs, problems)` with `readr::read_csv()` (encoding guessed with `readr::guess_encoding()`).
  - `match_labels(inputs, answers) -> list(inputs, problems)`: matches labels to answer names after `stringr::str_squish()` and `stringr::str_to_lower()`; lists the labels that do not match.

- [ ] **Step 1: Write the failing tests.** One test each, with the exact problems text checked by `expect_match()`:
  - a labelled zip (`nominal/a.jpg`, `defective/b.jpg`) gives two inputs with labels `nominal` and `defective`;
  - a zip with a single top folder `parts/` around the label folders gives the same result;
  - junk entries (`__MACOSX/._a.jpg`, `.DS_Store`, `Thumbs.db`) are skipped and not counted;
  - the same name `a.jpg` in two folders gives two distinct ids;
  - 101 images give the problem "at most 100 images";
  - a 6 MB file gives the problem "at most 5 MB";
  - a `.pdf` in the zip is skipped with the problem "1 file is not an image";
  - folders `Defective ` and `NOMINAL` match the answers `defective` and `nominal`; a folder `scratch` gives the problem "scratch is not an answer";
  - paste text with three paragraphs and extra blank lines gives three inputs;
  - a 4,001-character text gives the problem "at most 4,000 characters";
  - a CSV with a UTF-8 BOM, one empty text row and a blank label reads two inputs (one unlabelled) and the problem "1 empty text was dropped";
  - a Latin-1 CSV with "Résumé" reads the text "Résumé".

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Write `R/data.R`.** Use `zip::unzip()`, `fs`-free base path functions, `purrr`, `stringr`, `readr`. Ids: `sprintf("%03d", seq_len(n))` joined with the cleaned file name.

- [ ] **Step 4: Run the tests.** → all PASS.

- [ ] **Step 5: Commit.**

### Task 4: Runs, errors and cost

**Files:**
- Create: `R/runs.R`, `tests/testthat/test-runs.R`, `tests/testthat/helper-mock.R`

**Interfaces:**
- Consumes: spec of Task 2.
- Produces:
  - `make_decider() -> <decisions decider>`: `decisions::decider_typesafe(MODEL, credentials = \() Sys.getenv(KEY_VAR))`.
  - `chunk_ids(n, size = CHUNK_SIZE) -> list of integer vectors`.
  - `run_chunk(spec, rows, decide_fn = decisions::decide) -> tibble`: calls `decide_fn(make_decider(), as_decisions_question(spec$question), image = <paths> or text = <texts>, references = spec$references, max_size = 768, upscale = TRUE, crop = "none")` and adds `id`. If `decide_fn` aborts, it returns one row for each input with `NA` answers and `.error = "config"`.
  - `classify_error(text) -> chr` (vectorised): `NA` for `NA`; `"config"`; `"credit"` for `^HTTP 402` or text that matches `credit|balance|insufficient|payment` (ignore case); `"auth"` for `^HTTP 40[13]`; `"rate"` for `^HTTP 429`; `"server"` for `^HTTP 5` or a timeout; `"input"` for other `^HTTP 4`; else `"answer"`.
  - `error_message(category) -> chr`: config and auth → "The demo is not available right now."; credit → "The credit of this demo is used up. Try again later."; rate → "Too many requests. Try again in a minute."; server → "TypeSafe did not answer. Try again."; input → "TypeSafe refused this input."; answer → "The answer could not be read.".
  - `stops_the_day(category) -> lgl`: TRUE for config, auth and credit.
  - `chunk_usage(answers) -> list(calls, tokens, cost)`: cost = `sum(.input_tokens, na.rm = TRUE) * PRICE_PER_TOKEN`.
  - `estimate_cost(spec, n, mean_tokens = NULL) -> dbl`: `n * (mean_tokens %||% TOKENS_GUESS[[spec$mode]]) * PRICE_PER_TOKEN`.
  - Test helpers (in `helper-mock.R`): `sample_lookup(id) -> tibble` (the column `input`, the path or the text of each sample input, joined to `sample_answers(id)` by `id`); `mock_decide(lookup = NULL, error = NULL, abort = FALSE) -> function` with the signature of `decisions::decide()`. The function returns, for the given `image` or `text`, the rows of `lookup` in that order (a row with the first answer at probability 1 for an input that is not in `lookup`); with `error`, every row has `NA` answers and that `.error`; with `abort = TRUE`, it calls `cli::cli_abort()`. `environment(f)$calls` counts its calls.

- [ ] **Step 1: Write the failing tests.**

```r
test_that("classify_error() maps provider texts to categories", {
  expect_identical(
    classify_error(c(NA, "HTTP 402 {...}", "HTTP 400 insufficient balance", "HTTP 401 bad key ...abcd",
                     "HTTP 429", "HTTP 503", "HTTP 422 bad image", "answer is not allowed", "config")),
    c(NA, "credit", "credit", "auth", "rate", "server", "input", "answer", "config"))
})

test_that("the raw error text never reaches the visitor text", {
  msg <- error_message(classify_error("HTTP 401 Incorrect API key provided: sk-...wxyz"))
  expect_false(stringr::str_detect(msg, "wxyz|sk-|HTTP"))
})

test_that("run_chunk() returns one row per input and keeps the ids", {
  tex <- sample_spec("textiles")
  out <- run_chunk(tex, 11:20, mock_decide(sample_lookup("textiles")))
  expect_identical(out$id, tex$inputs$id[11:20])
  expect_equal(out$.pred_defective, dplyr::filter(sample_answers("textiles"), id %in% tex$inputs$id[11:20])$.pred_defective)
  out <- run_chunk(tex, 1:10, mock_decide(sample_lookup("textiles")))
  expect_identical(out$id, tex$inputs$id[1:10])
})

test_that("a missing key stops the run without a crash", {
  withr::local_envvar(HF_JEV_API = "")
  out <- run_chunk(sample_spec("injuries"), 1:3, mock_decide(abort = TRUE))
  expect_identical(unique(classify_error(out$.error)), "config")
  expect_true(stops_the_day("config"))
})

test_that("estimate_cost() uses the guess, then the measured mean", {
  tex <- sample_spec("textiles")
  expect_equal(estimate_cost(tex, 46), 46 * 16000 * 0.042 / 1e6)
  expect_equal(estimate_cost(tex, 46, mean_tokens = 8253), 46 * 8253 * 0.042 / 1e6)
})

test_that("chunk_ids() makes chunks of 10", {
  expect_identical(lengths(chunk_ids(46)), c(10L, 10L, 10L, 10L, 6L))
})
```

- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write `R/runs.R` and `helper-mock.R`.**
- [ ] **Step 4: Run the tests.** → all PASS.
- [ ] **Step 5: Commit.**

### Task 5: Spending and the usage store

**Files:**
- Create: `R/spending.R`, `tests/testthat/test-spending.R`

**Interfaces:**
- Produces:
  - A *usage store* is `list(read = function() <tibble>, write = function(usage) invisible(TRUE))`. The tibble has `date` (chr, `YYYY-MM-DD`, UTC), `calls` (int), `input_tokens` (dbl), `cost` (dbl).
  - `usage_store_memory(usage = empty_usage())`.
  - `usage_store_hf(repo = USAGE_REPO, token = Sys.getenv(USAGE_TOKEN_VAR))`: read `https://huggingface.co/datasets/<repo>/resolve/main/usage.csv` with httr2 and the Bearer token (an empty usage when the file does not exist, HTTP 404); write with `POST https://huggingface.co/api/datasets/<repo>/commit/main`, body `application/x-ndjson`: a line `{"key":"header","value":{"summary":"usage <date>"}}` and a line `{"key":"file","value":{"path":"usage.csv","content":<base64>,"encoding":"base64"}}`. Check the format against the current huggingface_hub documentation (context7) before the code. A failed write warns in the log (with no token) and keeps the totals in memory.
  - `usage_add(usage, now, calls, tokens, cost) -> tibble` (adds to the row of the UTC date of `now`).
  - `spend_status(session_cost, usage, now = Sys.time()) -> list(session_left, day_left, month_left)`.
  - `run_allowed(estimate, status) -> list(ok = lgl, reason = NA | "session" | "day" | "month")` and `limit_message(reason) -> chr` with the three texts of the design, section 6.

- [ ] **Step 1: Write the failing tests:** the day and month sums for a fixed `now`; a run of USD 0.30 is refused for "session" with USD 0 spent; the day limit at USD 1.99 spent refuses an estimate of USD 0.02 for "day"; the month limit refuses for "month"; `usage_add()` at `2026-11-03 23:59:59 UTC` and `2026-11-04 00:00:01 UTC` writes two rows; a memory store written then read gives the same tibble; `usage_store_hf()` with `httr2::with_mocked_responses()`: a 404 read gives an empty usage, a write sends the header line and a file line whose decoded content is the CSV, and the token never appears in a warning.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write `R/spending.R`.**
- [ ] **Step 4: Run the tests.** → all PASS.
- [ ] **Step 5: Commit.**

### Task 6: Answers and stats

**Files:**
- Create: `R/answers.R`, `tests/testthat/test-answers.R`

**Interfaces:**
- Consumes: spec (Task 2), `decide()` output (Task 4), `classify_error()`, `error_message()`.
- Produces:
  - `answers_table(spec, answers, target) -> tibble` with `id`, `file`, `text` (cut at 150 characters), `answer` (the `.pred_class`), `p_target`, one `p_<answer>` column for each answer, `label`, `tokens`, `seconds`, `problem` (from `error_message()`, `NA` when none); sorted by `p_target`, highest first. Probability columns come from the cleaned names of decisions (`crushing injury` → `.pred_crushing_injury`).
  - `answer_stats(table, spec, target) -> list(n, cost, accuracy, auc)`: `accuracy` with `yardstick::accuracy_vec()` on labelled rows (NA with no labels); `auc` with `yardstick::roc_auc_vec()` when the question has two answers and both labels occur (event level = `target`), else NA.
  - `alt_text(row) -> chr`: "<file>: answer <answer>, probability of <target> <p>".
  - `help_note(spec, stats, target) -> chr`: for a sample with its saved answers, the facts of `SAMPLE_FACTS`; else a generic note ("The probability is the raw probability of Jev for <target>. It is not calibrated.").
  - `answers_csv(table) -> chr` (the CSV text for the download).

- [ ] **Step 1: Write the failing tests:** the textile table has 46 rows and its first 14 rows are the local flaws; `answer_stats()` gives accuracy 0.80 and AUC 0.75 (both rounded to 2 decimals) for the saved textile answers; the injuries stats give accuracy 0.96 and AUC NA; an unlabelled spec gives accuracy NA; a row with `.error = "HTTP 401 ... wxyz"` has the problem "The demo is not available right now." and the CSV text does not contain "wxyz".
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write `R/answers.R`.**
- [ ] **Step 4: Run the tests.** → all PASS.
- [ ] **Step 5: Commit.**

### Task 7: R code, bundle and import

**Files:**
- Create: `R/code.R`, `R/bundle.R`, `tests/testthat/test-code.R`, `tests/testthat/test-bundle.R`

**Interfaces:**
- Consumes: spec (Task 2), `answers_table()` and `answers_csv()` (Task 6).
- Produces:
  - `run_code(spec, date = Sys.Date()) -> chr1`. The code of design section 5.6: the first comment ("The run of the decisions Space on <date>, in R. Run it with your own key."), `library(decisions)`, the comment on paths (the six lines of the final mockup), the inputs and references (samples: `system.file()` and `textiles`, or the seed and `dplyr::slice_sample()` of the choosing-a-model vignette; uploads: `images/<file>`, `images/<label>/<file>`, `references/<answer>/<file>`, `read.csv("data.csv")`), the question constructor with the exact text, and `decide(decider_typesafe("<MODEL>"), <question>, image = ..., references = ..., max_size = 768, upscale = TRUE)` or `decide(..., text = ...)`. The model id is inserted from `MODEL`.
  - `code_lines(code) -> int` (for the closed card: "R code of this run · N lines").
  - `write_bundle(spec, table, zipfile, date = Sys.Date()) -> chr` (the zip path): `<name>.R`, `<name>-setup.json` (from `decisions::write_setup(decisions::decision_setup(make_decider(), list(<name> = as_decisions_question(...)), references = ..., max_size = 768, upscale = TRUE))`), `<name>-answers.csv`, `references/<answer>/<file>` (uploads and imports only), `README.md` (versions: `APP_VERSION`, `DECISIONS_SHA`, `MODEL`; date; install with `pak::pak("fmegahed/decisions")`; set `TYPESAFE_API_KEY`; how to cite).
  - `read_import(path) -> list(question, references, problems)`: a zip (finds `*-setup.json`) or a JSON file; parses with `jsonlite::read_json()`; never calls `decisions::read_setup()` and never unserializes; accepts version 1, one question, `calibrator` null, `image_settings` equal to `IMAGE_SETTINGS`; decodes the references to `references/<answer>/ref_<i>.jpg` in `tempfile()`; a model other than `MODEL` gives the problem "This file uses <model>. The app uses <MODEL>.".

- [ ] **Step 1: Write the failing tests.**
  - For each of: textiles, injuries, a labelled image upload, an unlabelled image upload, a text CSV upload, an import: `parse(text = run_code(spec))` succeeds, and the code runs in an environment where `decide` is a stub that records its arguments (`library(decisions)` attaches the package; the stub is in the evaluation environment). The stub sees `max_size = 768`, `upscale = TRUE`, the exact instructions, and 46 image paths for textiles that all exist.
  - The textile code contains `system.file("extdata", "textiles", package = "decisions")` and the paths comment; the upload code contains `"images/"`.
  - `write_bundle()` for an upload has the four files and the reference files; `decisions::read_setup()` reads its setup file (in the test only, on our own file); no file in the zip matches `HF_JEV_API|Bearer|sk-` or the value of a fake key set with `withr::local_envvar(HF_JEV_API = "fake-key-1234567890")`.
  - `read_import()` on that bundle restores the question and two references per answer; on a file with a `calibrator` value it gives the problem "This file was not made by this app." and does not call `unserialize` (use `testthat::local_mocked_bindings(unserialize = \(...) stop("called"), .package = "base")`); on `decisions`'s `inst/extdata/rubric_setup.json` (six questions) it gives the same problem.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write `R/code.R` and `R/bundle.R`.** Use `stringr::str_glue()` or `sprintf()` for the template, and `encodeString(x, quote = '"')` for each user string so that quotes and backticks in the text stay valid R.
- [ ] **Step 4: Run the tests.** → all PASS.
- [ ] **Step 5: Commit.**

### Task 8: Uptime record

**Files:**
- Create: `R/status.R`, `tests/testthat/test-status.R`, `.github/workflows/status.yml`, `status/status.csv` (the header line only)

**Interfaces:**
- Produces:
  - `read_status(url = STATUS_URL, read_fn = \(u) readr::read_csv(u, show_col_types = FALSE)) -> tibble` (`time_utc`, `http_status`, `seconds`, `answered`, `app_version`); an empty tibble when the read fails.
  - `status_summary(status, now = Sys.time()) -> list(days, answered, checks, last)`: `days` = whole days since the first answered check (0 when none); `last` = the last 60 rows.
  - `status_chip(summary) -> chr`: "in service <days> days" (singular "day" for 1; "new" for 0).

- [ ] **Step 1: Write the failing tests:** a fixture of 5 rows (first answered on 2026-11-03 05:17Z, one failed) at `now = 2026-11-10 12:00Z` gives `days = 7`, `answered = 4`, `checks = 5`; a failing `read_fn` gives `days = 0` and the chip "new".
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write `R/status.R`.**
- [ ] **Step 4: Write `.github/workflows/status.yml`:** `on: schedule: - cron: "17 5,17 * * *"` and `workflow_dispatch`; `permissions: contents: write`; one job: `curl -s -o page.html -w "%{http_code} %{time_total}" --max-time 180 https://fmegahed-decisions.hf.space/`; read the version from `<meta name="app-version" content="...">` with `sed`; append `time_utc,http_status,seconds,answered,app_version` (answered = `true` when the status is 200 and the version was found); commit `status/status.csv` as `github-actions[bot]` with the message "Status check <time>"; push. Pin `actions/checkout` to a SHA.
- [ ] **Step 5: Run the tests.** → all PASS. Lint the workflow with `actionlint` if it is installed; else check the YAML with `Rscript -e "yaml::read_yaml('.github/workflows/status.yml')"`.
- [ ] **Step 6: Commit.**

### Task 9: User interface, theme and help

**Files:**
- Create: `R/ui.R`, `R/help.R`, `www/theme.css`, `www/app.js`, `www/fonts/` (woff2 files and their OFL license texts), `www/logo.png`, `www/logo.svg` (from `decisions/man/figures/`), `tests/testthat/test-ui.R`
- Modify: `app.R` (use `app_ui()`)

**Interfaces:**
- Consumes: `app_config()`, `SAMPLE_FACTS`, `status_chip()`.
- Produces: `app_ui(request) -> shiny tag list` with these input and output ids, which Task 10 uses:
  - inputs: `mode` (radio Images/Text), `source` (select: `textiles`, `injuries`, `upload`), `upload_images`, `upload_csv`, `csv_text_col`, `csv_label_col`, `paste_text`, `qtype` (Yes / no, Choice, Score → `noul`, `choice`, `score`), `instructions`, `answers_ui` (dynamic rows `answer_name_<i>`, `answer_desc_<i>`, buttons `answer_add`, `answer_remove_<i>`), `ref_<answer>` (dynamic file inputs), `try5`, `run_all`, `stop`, `target`, `view` (Gallery/Table), `help_on` (switch), `import_file`, `intro_hide`, `samples_menu` items `sample_textiles`, `sample_injuries`.
  - outputs: `status_chip`, `spend_meter`, `run_estimate`, `stats`, `help_answers`, `gallery`, `table`, `code_summary`, `code`, `bundle_files`, `download_answers`, `download_code`, `download_bundle`, `record_table`, `limits_text`.
  - help: `help_text(key) -> chr` for the keys `intro`, `data`, `question`, `references`, `references_score`, `answers`, `code`, `privacy`, `about`; all text in STE; About is built from `app_config()`.
- The layout of design section 4 and the mockup; the R code card is a `<details>` element, closed, whose `<summary>` holds the summary line and the three buttons; the code block has `tabindex="0"`, `role="region"`, `aria-label="R code of this run"`; the Video button and its dialog render only when `VIDEO_URL != ""` (dialog after app 1 `www/app.js`: the embed `https://www.youtube-nocookie.com/embed/<id>` is set on open and cleared on close; Escape closes; focus is trapped); `<meta name="app-version" content=APP_VERSION>`; the Help switch toggles the class `help-off` on `<body>` (CSS hides `.help` elements), and its state stays in `sessionStorage`; on a screen narrower than 900 CSS pixels the sidebar comes before the cards.

- [ ] **Step 1: Write the failing tests:** the HTML of `app_ui()` has the meta tag with `1.0.0`; has no element with the text "How to read"; has the tabs "Build", "About", "Record"; has no Video button when `VIDEO_URL` is `""` and has one when it is set (`withr::with_options` or a local binding); has the code block with `tabindex="0"` and `role="region"`; links no `fonts.googleapis.com` and no `fonts.gstatic.com`; every `img` has an `alt`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write the UI, the CSS (the palette and fonts of the Global Constraints; focus rings `3px solid #3E5468`), `app.js` and `help.R`.** Download the three font families (woff2, Latin subset) from their OFL sources and add their license files.
- [ ] **Step 4: Run the tests.** → all PASS. Run the app (`Rscript -e "shiny::runApp(port = 7860)"` in the background, stop it by PID) and compare the page with the mockup screenshot.
- [ ] **Step 5: Commit.**

### Task 10: Server

**Files:**
- Create: `R/server.R`, `tests/testthat/test-server.R`
- Modify: `app.R` (`shiny::shinyApp(app_ui, \(input, output, session) app_server(input, output, session))`, `mirai::daemons(2)` at start)

**Interfaces:**
- Consumes: Tasks 2 to 9.
- Produces:
  - `app_deps(decide_fn = decisions::decide, store = usage_store_hf(), status_fn = read_status, now = Sys.time, async = TRUE) -> list`.
  - `app_server(input, output, session, deps = app_deps())`.
  - Behavior: a sample loads with its saved answers and no call, and the answers card says "Saved run, jev-1.14.0" (the model from `MODEL`) until a live run replaces them; `session$onSessionEnded()` deletes the temporary folders of the uploads and imports; the status is read at start and every hour (`shiny::invalidateLater(3600000)`); any edit that changes `spec_fingerprint()` clears the answers; Try on 5 and Run all check `run_allowed()` with `estimate_cost()` and the latest `store$read()`; the chunk loop runs `run_chunk()` through `shiny::ExtendedTask` with `mirai::mirai()` (or synchronously when `deps$async` is FALSE), adds the usage after each chunk (`usage_add()`, `store$write()`), stops at Stop or at a category with `stops_the_day()` (a process-wide flag for the UTC date); the log gets one line per chunk with counts, tokens, cost and categories only; outputs of Task 9 render from `answers_table()`, `answer_stats()`, `run_code()`, `write_bundle()`; Import uses `read_import()` and fills the sidebar.

- [ ] **Step 1: Write the failing tests** with `shiny::testServer(app_server, args = list(deps = app_deps(decide_fn = mock_decide(...), store = usage_store_memory(), status_fn = \() fixture, async = FALSE)))`:
  - selecting `textiles` shows 46 rows, the text "Saved run, jev-1.14.0", and calls the mock 0 times (`environment(mock)$calls`);
  - after the session ends, the temporary folder of an upload no longer exists;
  - editing the instructions clears the answers;
  - Run all on the injuries sample calls the mock 8 times (75 inputs in chunks of 10) and the store's day row has 75 calls;
  - with a store that already holds USD 1.99 today, Run all on textiles is refused and the mock is not called, and the message is the day text;
  - a mock that returns `HTTP 402` rows stops the run after the first chunk and later runs are refused today with the credit text;
  - a mock that aborts (no key) gives "The demo is not available right now." and a spend of 0;
  - Stop after the first chunk keeps 10 answers;
  - the log output (captured with `testthat::capture_messages()`) contains no input text, no file name and no `.error` text.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Write `R/server.R`; update `app.R`.**
- [ ] **Step 4: Run the tests.** → all PASS. Run the app locally with the mock (an environment variable `SPACE_MOCK=1` makes `app_deps()` use `mock_decide()` and `usage_store_memory()`; the Dockerfile never sets it) and click through both samples, an upload, Import and the downloads.
- [ ] **Step 5: Commit.**

### Task 11: Accessibility check

**Files:**
- Create: `tests/a11y/axe.min.js` (axe-core 4.10.2, with its license), `tests/testthat/test-a11y.R`
- Modify: `.github/workflows/tests.yml` (Chrome for shinytest2)

**Interfaces:**
- Consumes: the app with `SPACE_MOCK=1`.

- [ ] **Step 1: Write the test:** `shinytest2::AppDriver$new(".", variant = NULL)` with `SPACE_MOCK=1`; for the states start, textiles answers, R code open (`details` open), About: inject `axe.min.js` with `$run_js()`, run `axe.run(document, {runOnly: {type: "tag", values: ["wcag2a","wcag2aa","wcag21aa","wcag22aa"]}})` with `$get_js()`, and expect 0 violations (print the ids and targets on failure). The test skips when Chrome is not found (`chromote::find_chrome()`).
- [ ] **Step 2: Run it.** Fix every violation in Task 9 files until it passes. Then do a keyboard pass: Tab reaches every control in order, the code block scrolls with the arrow keys, Escape closes the video dialog.
- [ ] **Step 3: Update `tests.yml`** to install Chrome (`browser-actions/setup-chrome`, pinned SHA) and run all tests.
- [ ] **Step 4: Commit.**

### Task 12: GitHub, the private Space and the gate

This task has steps that only fmm can do and one paid step. Stop at each **[fmm]** and **[budget]** step and ask.

**Files:**
- Create: `.github/workflows/deploy.yml`, `tests/live_smoke.R`
- Modify: `README.md` (full text in STE: what the Space does, privacy, limits, run it yourself with Docker, layout, tests, license, how to cite)

- [ ] **Step 1: Write `deploy.yml`:** on push to `main` with `paths` `app.R`, `R/**`, `www/**`, `Dockerfile`, `README.md`; `pip install huggingface_hub`; `hf upload fmegahed/decisions . . --repo-type space --exclude "tests/*" ".github/*" "status/*" ".git*"` with `HF_TOKEN` from the GitHub secrets (check the flags with `hf upload --help` first). Pin the actions.
- [ ] **Step 2: Write `tests/live_smoke.R`:** reads `HF_JEV_API` with `readRenviron("C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev/.Renviron")` (a path given as the first argument); runs `run_chunk()` for the first input of each sample (2 calls); prints only the categories, the answers and the tokens; logs each call in `fine_tuned_jev/replication_materials/calls/typesafe-calls.csv` with the purpose `space-smoke`.
- [ ] **Step 3: Create the GitHub repository** with `gh repo create fmegahed/decisions-space --public --source . --push` (allowed by D242).
- [ ] **Step 4 [fmm]:** fmm runs `! hf auth login` in this session. Then create the Space `fmegahed/decisions` (Docker, private, cpu-basic) and the private dataset `fmegahed/decisions-space-usage` with `hf repo create` (check the flags with `--help`).
- [ ] **Step 5 [fmm]:** fmm makes the tokens and sets the secrets `HF_JEV_API` and `HF_USAGE_TOKEN` in the Space and `HF_TOKEN` in the GitHub repository. Claude Code checks only that the names exist (`gh secret list`; the Space settings page), never a value.
- [ ] **Step 6:** push `main`; watch `deploy.yml`; watch the Space build (`hf` or the Space page) until the app answers at its URL with the version meta tag.
- [ ] **Step 7 [budget]:** propose in chat the budget row "2026-11-xx | typesafe | Space decisions (M6): smoke test and the gate on the private Space | 20 calls | USD 0.05". Write it after fmm approves. Then run `tests/live_smoke.R` (2 calls) and, on the private Space, "Try on 5" on each sample (10 calls).
- [ ] **Step 8: Gate.** Read `usage.csv` of the dataset (with the login of fmm): one row for today with 10 calls. Restart the Space (`hf` or the settings page) and check that the totals stay. Run `status.yml` by hand (`gh workflow run status.yml`) and check its new row.
- [ ] **Step 9:** record the gate in the ledger. Propose to fmm the budget row for visitors ("typesafe-space | the calls of visitors on the public Space (D227) | USD 20 each month") and its log `calls/typesafe-space-calls.csv`. fmm makes the Space public when he wants (D242). After that, ask before each push to `main`.

### Task 13: Video

Starts after the Space is public, or earlier if fmm asks.

- [ ] **Step 1:** write the narration script (about 2 minutes: the textile sample, an upload, the answers, the R code and the bundle) with the skill narrated-demo-video, and count its characters.
- [ ] **Step 2 [budget]:** propose the row "elevenlabs | narration of the Space video (D239) | <n> characters, at most 3 renders | <cost from fmm's plan>" and its log `calls/elevenlabs-calls.csv`. Write it after fmm approves.
- [ ] **Step 3:** make the video with the skill (ElevenLabs voice, `ELEVENLABS_API_KEY` read from the `.Renviron` of fine_tuned_jev, never printed; captions from the script). Send the MP4 and the caption file to fmm.
- [ ] **Step 4 [fmm]:** fmm posts it on YouTube with the captions and gives the URL.
- [ ] **Step 5:** set `VIDEO_URL`; run the tests (the Video button appears; axe passes with the dialog open); ask fmm before the push (the Space is public by then).
