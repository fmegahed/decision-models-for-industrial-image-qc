# The Hugging Face Space of decisions: design

- Date: 2026-10-24 (revision 2)
- Milestone: M6
- Status: draft for the review of fmm
- Written by: Claude Code (Opus 5.5), from the chat with fmm in session b36ad167-66f5-45af-9d6c-bf3f817c6f58
- Decisions in the record: D225 to D241, with the earlier D147, D157, D165 and D175

Revision 2 adds the answers to the builder check (section 15) and D241 (the TypeSafe account has no credit card; no price check before launch).
- Replaces: section 8 of `plans/2026-10-23-decisions-package-design.md` (a Space with Laya and the key of the visitor)

## 1. Intent

The Space is a public web app for the R package decisions. A visitor asks a decision model a question about each of a set of images or texts, sees the answers and the probabilities, and takes the same run to R. The model is Jev from TypeSafe, paid with a key of fmm, so the visitor needs no key and no account (D225).

Two kinds of visitors come (D226):

- An R user who heard of decisions and wants to see what it does before installing it. This visitor uses text and images.
- A reader of the project paper ("Beyond CLIP: Calibrated (Few-Shot) Defect Detection With Structured Decision Models", in preparation) who wants to try the method on their own images or on our sample.

Both must get a result within minutes, without writing R code. When they leave, they have the R code of their run and a bundle with their setup and their answers.

The Space is outside the package (D157, D165). The documentation of the package links to it.

## 2. Goals, non-goals and anti-goals

Goals:

- G1. Text and images (D234). Images for both kinds of visitors; text for the R users.
- G2. The three question types of the package: noul (true or false), choice (named answers) and score (ordered levels), for text and for images (D234).
- G3. Two samples that open at once and cost nothing, and the data of the visitor: labelled or unlabelled (D226, D231).
- G4. For labelled data, show how well the answers agree with the labels (D237).
- G5. Give the R code of the run and a bundle to download (D238). The code uses only functions of decisions 0.1.0.
- G6. Keep the cost of fmm small and bounded (D227).
- G7. A public record of the days in service, which also keeps the Space awake (D232, D233).
- G8. Help in the app, not only outside it (D235, D237). A short video (D239).
- G9. WCAG 2.2 AA and the Miami palette.

Non-goals:

- No calibration in the app (D237). The app shows the raw probabilities of Jev. The package and its vignettes keep calibration.
- No run of R in the browser (D238, replaces D236). The key must not reach the browser.
- No model other than Jev, and no key of the visitor.
- No accounts and no sign-in.
- No storage of the inputs of a visitor after the session.

Anti-goals (a failure even if the app works):

- The key, or any part of it, reaches the browser, a log, the bundle or a repository.
- The cost of a month goes over USD 20.
- A visitor opens the app and sees a page of text before the app (the problem of app 1, fmm 2026-10-24).
- The R code does not do what the app did, or does not run.
- A label or a header is a question or a sentence ("How to read this"). Use short nouns: "Help", "Answers", "R code" (D237).

## 3. Constraints

- R Shiny in Docker on a free CPU Space (2 vCPU, 16 GB, disk not persistent). The account of fmm has PRO, which a new Docker Space needs.
- Each push to the Space rebuilds and restarts it. A Space on free CPU sleeps after 48 hours with no visitor.
- The package decisions 0.1.0 is on its way to CRAN. Until CRAN accepts it, the Docker image installs it from GitHub at a fixed commit.
- TypeSafe refuses images smaller than 280 pixels. The package sends images at `max_size = 768` with `upscale = TRUE`, as the images vignette does.
- TypeSafe reports input tokens, not a cost (D162). The app estimates the cost as input tokens times USD 0.042 per million (the price of the record, `calls/README.md`). The price is not checked against the account; the account has no credit card, so the spend cannot go over its credit (D241). The TypeSafe console shows no usage per key and has no cap per key.
- Writing rules: short noun labels in the app (D237); 80% ASD-STE100 in the README and the help; no claim that any model was the first (D163).

## 4. Layout (D235, D237, D240)

The layout is layout A of the second mockups, after the app Gene List Builder of the Posit Shiny gallery. The final mockup is `plans/2026-10-24-decisions-space-mockup.png`. It shows the R code card open; D240 closes it when the app opens. Its numbers are real (the saved Jev answers of the textile sample).

Top bar, left to right:

- The hex logo of decisions, the name "decisions" and the tag "DECISION MODELS".
- Tabs: Build, About, Record.
- Right side: a Help switch, a chip "in service N days" (section 8), the button Video (only when `VIDEO_URL` has a value, D239), the button Import, and the button Samples.

Build tab, two columns:

- Sidebar with three numbered groups. Each group has one line of help.
  - 01 Data: Images or Text; the data source (sample or upload).
  - 02 Question: the type (Yes / no, Choice, Score), the instructions, and the answers with their descriptions.
  - 03 References (images only): up to two images for each answer.
  - Buttons: "Try on 5" and "Run all N · ≈ $x". A Stop button replaces them during a run (D175).
  - The spending meter of the visit ("$0.02 of $0.25") and one line that names the provider: "Images go to TypeSafe (Jev). Do not upload confidential images." (D175).
- Main column:
  - The intro card: one sentence, three numbered steps (Question, Answers, R code), and the link Hide. The card is open on the first visit.
  - Card 1, Answers: the stats line, a Help note, and the answers as a gallery (images) or a table (text and images), sorted by the probability of the target answer (section 5.5), highest first. A button downloads the answers as CSV.
  - Card 2, R code: closed when it opens (D240). The closed card shows one line ("R code of this run · 32 lines") and the buttons Copy, Download (`<name>.R`) and Bundle (`.zip`). Open, it shows a Help note, the code and the list of the files in the bundle.

Footer: the version of the app, the commit of decisions, the model; the authors with their universities (Fadel M. Megahed, Miami University; Ying-Ju (Tessa) Chen, University of Dayton); Source; MIT.

On a narrow screen, the sidebar goes above the cards (WCAG reflow at 320 CSS pixels).

## 5. Behavior

### 5.1 Samples (D226)

The Samples menu has two samples. Each one opens with the saved Jev answers of a vignette, so it shows at once and costs nothing. The answers card says "Saved run, jev-1.14.0". "Run all" asks Jev again and costs the visitor's budget.

| Sample | Data | Question | Saved answers |
|---|---|---|---|
| Woven textiles | 46 images of `textiles` (role `input`), labelled; references: the 4 images of role `reference` | choice, `nominal` and `defective`, the wording of the images vignette | `extdata/images.rds`, `answers$jev` |
| Injury reports | the 75 narratives of the choosing-a-model vignette (`ohio_injuries`, seed 2026), labelled by `collapsed_nature_title` | choice, five injury types, the wording of that vignette | `extdata/choosing-a-model.rds`, `answers$jev` |

The saved answers show only while the question, the answers, the references and the model are those of the sample. A change clears them.

Facts for the help text (from the saved runs): textiles, AUC 0.75 and accuracy 0.80; Jev ranks all 14 local flaws first, and the 9 global flaws score like regular weaves (0.14 to 0.26). Injury reports: accuracy 0.96.

### 5.2 Data of the visitor (D231, D234)

Images:

- Labelled: one zip file with one folder for each answer (`nominal/`, `defective/`). The folder names must be the answer names.
- Unlabelled: several image files, or a zip file with no folders.
- JPEG, PNG and WebP. At most 5 MB for each file and 50 MB for a zip file. At most 100 images in a run.

Text:

- Paste: one input for each paragraph (blank lines separate inputs).
- CSV: the visitor chooses the text column and, if there is one, the label column. Labels must be answer names.
- At most 200 inputs in a run and 4,000 characters in an input.

The app keeps uploads in the temporary folder of the session and deletes them when the session ends.

### 5.3 Questions (D234)

- Yes / no: `question_noul()`. Two fixed answers, `true` and `false`, with optional descriptions.
- Choice: `question_choice()`. 2 to 6 answers.
- Score: `question_score()`. 2 to 5 levels, from low to high.
- Answer names follow the rules of the package (unique, distinct column names). Descriptions have at most 300 characters. Instructions have at most 500 characters.
- With Jev, references attach to the answers of noul and choice questions. A score question has no place for them; the help line of group 03 says so when the type is Score.

### 5.4 Runs (D175)

- "Try on 5" asks about the first five inputs. "Run all" asks about all. Both show the estimated cost before the call; the button is disabled when the estimate is more than the money left (section 6).
- The run calls `decide()` with the setup of the sidebar, `max_size = 768` and `upscale = TRUE`, and the credentials function `\() Sys.getenv("HF_JEV_API")` (D229).
- The run does not block the app: it runs as a background task, in chunks of at most 10 inputs. Stop takes effect at the end of the current chunk. The answers of the finished chunks stay.
- An input that fails shows its error in its tile or row. The other inputs go on.
- The app writes to its log only counts: the number of inputs, the tokens, the estimated cost, the errors and the time. It never writes an input, an answer text or a key.

### 5.5 Answers (D237)

- The target answer: `true` for Yes / no; for Choice and Score, the answer that the visitor picks next to the sort control (default: the last answer, for example `defective`). The sort and the AUC use it.
- Gallery (images): the image, the probability of the target answer as a number and a bar, the answer with the highest probability, and the label when there is one.
- Table (text and images): the input (the text, cut at 150 characters, or the file name), the answer, the probability of each answer, the label, the tokens and the seconds.
- Stats line: the number of inputs and the estimated cost; with labels, the accuracy, and the AUC when the question has two answers.
- Help note: what the probability is (the raw probability of Jev, not calibrated), and, for the samples, the facts of section 5.1.
- Download: `<name>-answers.csv`.

### 5.6 R code and bundle (D238, D240)

The app writes the R code of the run as text. The code:

- starts with a comment: the date, "Run it with your own key", and the comment on paths (below);
- builds the question with `question_noul()`, `question_choice()` or `question_score()`, with the exact text of the sidebar;
- gives the references and the inputs;
- calls `decide(decider_typesafe("jev-1.14.0"), <question>, image = ..., references = ..., max_size = 768, upscale = TRUE)` or `decide(..., text = ...)`;
- uses only functions of decisions 0.1.0 and base R.

Paths:

- Samples: `system.file("extdata", "textiles", package = "decisions")` and the dataset `ohio_injuries` (with the seed and the subset of the vignette), so the code runs on any computer.
- Data of the visitor: relative paths. Images: `images/<file>` (labelled: `images/<answer>/<file>`) and `references/<answer>/<file>`. Text: `read.csv("data.csv")`. The comment on paths says: put this script, the folder `images` and the folder `references` (or `data.csv`) in one folder, and make it the working directory (RStudio: Session > Set Working Directory > To Source File Location); `getwd()` shows where R looks.

The bundle is one zip file, `<name>-<date>.zip`:

| File | Content |
|---|---|
| `<name>.R` | the code above |
| `<name>-setup.json` | the setup from `write_setup()`: model, question, references and image settings |
| `<name>-answers.csv` | the answers of section 5.5 |
| `references/<answer>/<file>` | the reference images of the run (at most 2 for each answer), so that the code runs with its relative paths; none for the samples, which use `system.file()` |
| `README.md` | what each file is; the versions (app, decisions commit, model) and the date; how to install decisions; how to cite; how to set `TYPESAFE_API_KEY` |

The bundle holds no input image of the visitor and no key. (Claude Code's call: the references go in as files, so the code of section 5.6 needs no change for an imported setup.)

Import takes a bundle zip file or a setup JSON file that this Space made, and restores the question, the answers and the references. It makes no call. Rules (Claude Code's call, after the builder check):

- The app parses the JSON itself (jsonlite). It never calls `read_setup()` on an upload and never unserializes anything: `read_setup()` unserializes a stored calibrator, and its help says to read only trusted files.
- The app accepts a file with one question, no calibrator, and image settings `max_size = 768`, `upscale = TRUE`, `crop = "none"`. It refuses any other file with a short message.
- The model of the file must be the model of the app; if not, the app says so and uses its own model.
- Imported references have no file names. The app names them `ref_1.jpg`, `ref_2.jpg` in `references/<answer>/`, and the code uses these names.

### 5.7 Help (D235, D237)

- The intro card (section 4).
- One help line in each sidebar group.
- A note "Help" at the top of each result card.
- The Help switch in the top bar shows or hides the help lines and notes. The choice stays for the session.
- The About tab: what the app does; the method and the paper (in preparation), with the link to the project repository; the package (CRAN or GitHub, website, record); privacy (section 10); the limits (made from `R/config.R`, as app 1 does); the versions; how to cite; contact.
- The "?" buttons of app 1 are not needed.

### 5.8 Video (D239)

- After the Space runs, Claude Code makes a video of about two minutes with the skill narrated-demo-video: the textile sample, an upload, the answers, the R code and the bundle.
- Voice: ElevenLabs, with `ELEVENLABS_API_KEY` from the `.Renviron` of this repository (D21). Captions come from the same script as the narration.
- fmm posts it on YouTube with its captions file. Claude Code sets `VIDEO_URL` in `R/config.R`.
- The Video button opens a dialog: the embed comes from `youtube-nocookie.com` and loads only when the dialog opens; Escape and the close button close it and stop the video; focus stays in the dialog (the pattern of app 1, `www/app.js`).

## 6. Spending (D225, D227, D229)

- The key is a secret of the Space with the name `HF_JEV_API`. The app reads it only in the credentials function.
- The estimated cost of a call is its input tokens times USD 0.042 per million.
- Limits, in `R/config.R`:

  | Limit | Value | What the visitor sees when it is reached |
  |---|---|---|
  | Each session | USD 0.25 | "The limit of this visit is reached." The samples and the R code still work. |
  | Each day (UTC), all visitors | USD 2 | "The limit of today is reached. Try again tomorrow." |
  | Each month (UTC), all visitors | USD 20 | "The limit of this month is reached." |

- Before a run, the app estimates its cost: the number of inputs times the tokens of one call. Before the first call of a setup, it uses 16,000 tokens for an image call and 1,000 for a text call; after "Try on 5", it uses the mean of those calls. A run that would go over a limit does not start.
- After each chunk, the app adds the reported tokens to the totals.
- The day and month totals must survive a restart. The app keeps them in a private Hugging Face dataset, `fmegahed/decisions-space-usage`, as one CSV row for each day (date, calls, input tokens, estimated cost). It reads the file at start and writes it after each run. A second Space secret, `HF_USAGE_TOKEN`, is a token that can write only to this dataset. (Claude Code's call; another store is acceptable if it survives restarts and holds no inputs.)
- A page reload starts a new session, so the session limit only shapes normal use; the day and month limits bound the cost (D227).
- The credit of the TypeSafe account is the last guard (D241). When TypeSafe refuses a call for lack of credit, the app shows "The credit of this demo is used up. Try again later." makes no more calls that day, and writes the event (with no input) to its log. A test with the mock decider covers this answer.

## 7. Accessibility and look

- WCAG 2.2 AA. Text contrast at least 4.5:1, large text 3:1. The measured pairs of the mockup: code comments #5f5a52 on #fbfaf7, 6.55:1; functions #3E5468, 7.53:1; strings #7a3e00, 7.99:1; code text #22262b, 14.58:1; help text #5f5a52 on white, 6.84:1; Miami Red #C41230 on white, 6.04:1.
- The code block takes keyboard focus (`tabindex="0"`, `role="region"`, an accessible name) and scrolls long lines; every control has a visible focus ring; the image gallery gives each image an alternative text (file name, answer and probability).
- Miami palette (Miami Red #C41230, Light Tan #EDECE2, Medium Tan #CCC9B8, Dark Tan #70685C, Warm White #FAF9F7, Slate Blue #3E5468), with no tints.
- Fonts: Source Serif 4 (headings), Source Sans 3 (text), IBM Plex Mono (labels and code), all under the SIL Open Font License, served from `www/fonts` (no call to Google Fonts).

## 8. Uptime record (D232, D233)

- A GitHub Actions workflow in the GitHub repository runs twice a day (cron `17 5,17 * * *`, off the hour).
- It requests the app (`https://fmegahed-decisions.hf.space/`, timeout 180 seconds) like a visitor. This visit keeps the Space awake.
- It adds a row to `status/status.csv`: `time_utc, http_status, seconds, answered, app_version`. The app writes its version in a `<meta name="app-version">` tag, and the workflow reads it from the page.
- It commits the file to `main` of the GitHub repository. It does not push to the Space.
- The app reads `status.csv` from GitHub at start and every hour. The chip shows the days since the first answered check; the Record tab shows the checks answered out of the checks made, the last 60 checks, and links to the package record (https://fmegahed.github.io/decisions/record/) and to the project record.
- If the docs of Hugging Face or a test show that this visit does not keep the Space awake, Claude Code reports it to fmm.

## 9. Repository, build and deploy (D228, D230)

- Folder: `C:\Users\megahefm\Dropbox\Miami\Code\claude\decisions-space`, its own git repository.
- GitHub: `fmegahed/decisions-space` (public, MIT). Space: `fmegahed/decisions` (Claude Code's call for both names). The Space is private until it passes the gate of section 12 and fmm makes it public.
- Files, after app 1: `app.R`, `R/config.R` (the model, the limits, the versions, `VIDEO_URL`), `R/` (one file for each part: data, questions, runs, answers, code, bundle, spending, status, help), `www/` (theme, fonts, logo, `app.js`), `samples/` (the saved answers of section 5.1), `tests/`, `status/status.csv`, `Dockerfile`, `README.md` (with the metadata of the Space: `sdk: docker`, `app_port: 7860`).
- Dockerfile: `rocker/shiny:4.6.1`; decisions from `url::https://github.com/fmegahed/decisions/archive/b25fc9ffa7908e9a6a2d9833f080de1456c9d50a.tar.gz` (the commit of the CRAN submission of 0.1.0) with pak; the other packages at fixed versions; the last line of the build loads each package. After CRAN accepts decisions, the Dockerfile installs `decisions` 0.1.0 from CRAN.
- GitHub workflows:
  - tests on each push and pull request;
  - deploy: on a push to `main` that changes the app (not `status/`), upload the app files to the Space with the secret `HF_TOKEN` of the GitHub repository;
  - status: section 8.
- Secrets of the Space: `HF_JEV_API`, `HF_USAGE_TOKEN`. fmm sets them; Claude Code never sees them. Secret of the GitHub repository: `HF_TOKEN` (write to the Space).
- Locally, the key stays in the `.Renviron` of fine_tuned_jev (D229). A local run reads it with `readRenviron()` on that file.

Roles (proposed by Claude Code; open until fmm approves this design):

- Claude Code creates the GitHub repository with `gh`. After fmm runs `hf auth login` on this computer, Claude Code creates the Space and the usage dataset, both private.
- fmm makes the three tokens and sets the secrets (`HF_JEV_API` and `HF_USAGE_TOKEN` in the Space, `HF_TOKEN` in the GitHub repository). Claude Code never sees a value.
- While the Space is private, Claude Code may push to `main` of decisions-space without asking; each push redeploys only the private Space.
- fmm makes the Space public after the gate of section 12 and his review. After that, Claude Code asks before each push to `main`.

## 10. Privacy

- The inputs and the references go to TypeSafe (Jev). The app says so next to the Run buttons and in About.
- The Space keeps no input after the session. The usage dataset holds only daily totals.
- The bundle and the logs hold no key.

## 11. Tests

- Unit and server tests with testthat and `shiny::testServer()`. A mock decider replaces Jev, so the tests need no key and make no call (as in app 1).
- The code of section 5.6: for each sample and for a labelled and an unlabelled upload of each kind, the generated code parses, and it runs with `decide()` replaced by a stub that returns the saved answers.
- The bundle: it has the four files; `read_setup()` reads its setup file; it holds no key-like text.
- Spending: a run over each limit does not start; the totals survive a restart (a test with a fake usage store).
- Accessibility: axe-core (WCAG 2.2 A and AA rules) on four states (start, sample answers, R code open, About), with 0 violations; a keyboard pass by Claude Code.
- The Docker image builds in CI.
- A live smoke test (`tests/live_smoke.R`, as in app 1): one text call and one image call with the key. It runs only by hand, under its budget row.

## 12. Record and paid calls

- A new milestone M6, "Hugging Face Space of decisions", goes into `roadmap.md` when fmm approves the plan.
- Budget rows to propose before the first paid call (none exist yet):
  - typesafe: the build and the smoke tests by Claude Code, about 300 calls and USD 0.50. These calls go in `calls/typesafe-calls.csv`, as before.
  - typesafe-space: the calls of visitors on the public Space, USD 20 each month (D227). The Space enforces it. A separate service name keeps the calls of visitors out of the log of the study. Its log, `calls/typesafe-space-calls.csv`, holds one row for each day (the totals of the usage dataset). Claude Code copies the rows from the dataset when it updates the record: at the end of M6 and in each later session about the Space. (Claude Code's call, after the builder check.)
  - elevenlabs: the narration of the video (D239). The cost depends on the plan of fmm; Claude Code proposes the row with the length of the script.
- Gate before the Space goes public: the Space is first private (section 9). Claude Code runs "Try on 5" on each sample there, under the build budget row, and reads the usage dataset (with the Hugging Face login of fmm on this computer) to check that the day and month totals are written and survive a restart.
- The record of the Space (decisions, process, ledger) stays in this repository (D230).

## 13. Decisions and their impacts

| ID | Decision | Impact on this design |
|---|---|---|
| D225 | the key of fmm, as a Space secret; no Laya | sections 1, 6 |
| D226 | two kinds of visitors; one sample is enough | sections 1, 5.1 |
| D227 | USD 0.25 per session, USD 2 per day, USD 20 per month | section 6 |
| D228 | start from app 1 (structured_text_extraction) | sections 4, 9, 11 |
| D229 | the key name `HF_JEV_API` | sections 5.4, 6, 9 |
| D230 | its own folder and repository; the record stays here | section 9 |
| D231 | labelled and unlabelled image data | section 5.2 |
| D232, D233 | the uptime record; a visit from GitHub twice a day | section 8 |
| D234 | text and images; noul, choice and score | sections 5.2, 5.3 |
| D235 | layout A; help in the app | sections 4, 5.7 |
| D236 | webR panel (replaced by D238) | - |
| D237 | no calibration; short noun labels ("Help") | sections 2, 5.5 |
| D238 | the R code of the run, Copy, Download, Bundle; no run in the browser | section 5.6 |
| D239 | the video | section 5.8 |
| D240 | the R code card is closed when it opens | section 4 |

## 14. Left to the builder

- The Shiny structure (modules or not), the background task mechanism and the chunk loop.
- The upload controls and the CSV column picker.
- The exact wording of the help lines, the Help notes and About, within the rules of section 3.
- The layout of the Record tab.
- How the app writes to the usage dataset, within section 6.
- The exact fixed versions of the R packages in the Dockerfile.

## 15. Builder check and answers

A fresh reviewer read revision 1 as a builder (2026-10-24) and asked four questions.

| Question | Answer | Where |
|---|---|---|
| What may Claude Code do alone in the new repository and on Hugging Face, and how is the real usage store tested? | The test of the usage store: Claude Code's call (a private Space first, then a check of the dataset). The roles: proposed in section 9, for fmm to approve with this design. | sections 9, 12 |
| Is USD 0.042 per million input tokens confirmed, and does the USD 20 limit apply to the estimate or to the bill? | fmm: the console has no usage or cap per key, and the account has no credit card, so no check is needed (D241). The limits use the estimate; the credit is the last guard. | sections 3, 6 |
| Must Import accept any setup file, or only the files of this Space? | Only the files of this Space, parsed without `read_setup()` and with no unserialize; the bundle holds the references as files. Claude Code's call. | section 5.6 |
| How do the calls of visitors enter the record? | A budget row and a log of daily totals under the service name `typesafe-space`. Claude Code's call. | section 12 |

## Sources

- Hugging Face, Spaces Overview: https://huggingface.co/docs/hub/en/spaces-overview
- Hugging Face, Spaces hardware and sleep time: https://huggingface.co/docs/hub/spaces-gpus
- App 1 (structured_text_extraction): https://huggingface.co/spaces/fmegahed/structured_text_extraction
- Posit Shiny gallery, Gene List Builder: https://shiny.posit.co/r/gallery/bioinformatics/gene-list-builder/
- Posit Shiny gallery, Signature Scoring: https://shiny.posit.co/r/gallery/bioinformatics/signature-scoring/
- EXPERTA (bundle export and import): https://expertadoe.app/app
