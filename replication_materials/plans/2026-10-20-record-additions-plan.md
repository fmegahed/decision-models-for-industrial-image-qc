# Record additions (replication-materials 1.2.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add releases, results, a timeline, a contributions page and more decision detail to the replication-materials skill (version 1.2.0), then fill them in for this project.

**Architecture:** The skill reads markdown tables from `replication_materials/` into one model (`lib/project.mjs`, `lib/decisions.mjs`) and renders static pages (`lib/pages.mjs`). New record files and columns are optional, so old records stay valid and `format_version` stays 1. Tasks 1 to 7 change the skill in `fmegahed/claude-skills`. Task 8 updates this project and fills in its record.

**Tech Stack:** Node 22 (ES modules, `node:test`), Playwright with axe-core for the accessibility tests, markdown record files.

**Spec:** `replication_materials/plans/2026-10-20-fair-comparison-design.md`, Part B (section 10), with the git rules of section 11.

## Global Constraints

- Skill folder: `C:\Users\megahefm\Dropbox\Miami\Code\claude\claude-skills\skills\replication-materials`. Tests run from the root of `claude-skills`: `npm test`, `npm run test:a11y`, `npm run test:a11y:record`.
- New version: `1.2.0` in `scripts/lib/html.mjs` (`VERSION`), in the first line of `scripts/build-site.mjs`, and in the version line of the workflow template. `FORMAT_VERSION` stays 1.
- Every new file and column is optional. A record of version 1.1.0 must build with no change and give the same pages as before, plus the new pages in their empty state.
- Errors use `RecordFormatError(file, line, detail)`, so the build prints `replication-materials: <file>:<line>: <detail>`.
- Pages meet WCAG 2.2 AA (the axe tests at widths 320 and 1280) and use the existing tokens, `table()`, `tr()`, `filterBar()` and `shell()` helpers. No new CDN script.
- All page text escapes record text with `escapeHtml()` or `inline()`.
- No root-absolute links (`href="/` or `src="/`).
- Record text and docs: 80% ASD-STE100 (short sentences, active voice, no contractions).
- Git: in `claude-skills`, follow its `CLAUDE.md`. Code commits there are pushed only after fmm says yes. In this project, record-only commits go to `main` and are pushed without asking. The update of `.replication/` and the workflow is not record-only, so ask before that push.
- Never print, log or commit an API key.

## Review Focus

- A record with no `releases.md`, `results.md`, `contributions.md`, Topics table or Checks table: the build must pass, and the new pages must say "No releases yet." and similar. Task 3 and Task 5 test the empty fixture.
- A decision row with a Replaces ID that is later than itself, or unknown: the build must stop with the line number. Task 1 tests it.
- A results row whose Source file does not exist: the build must stop with the line number. Task 2 tests it.
- A decisions table where all rows have the same date: the chart over time must bin by hour, not show one bar. Task 5 tests it.
- A record text with `<script>` or a `|` in the new columns: the pages must escape it. Task 5 tests it.

---

### Task 1: Optional decision columns, Topics and Checks

**Files:**
- Modify: `scripts/lib/decisions.mjs`
- Modify: `scripts/lib/project.mjs` (`readAllDecisions`)
- Modify: `tests/fixtures/full/replication_materials/project/decisions.md`
- Test: `tests/decisions.test.mjs`, `tests/project.test.mjs`

**Interfaces:**
- Produces: each decision object gets `time` (string `"HH:MM"` or `null`), `topic` (string or `null`), `impact` (string or `null`), `replaces` (array of decision IDs, maybe empty) and `checked` (boolean).
- Produces: `readTopics(text, file)` returns an array of `{ topic, meaning }` from an optional `## Topics` table (columns `Topic`, `Meaning`) in `decisions.md`.
- Produces: `readChecksTable(text, file)` returns the optional `## Checks` table (columns `Decision`, `Checked by`, `Date`, `Note`) or `null`.
- Produces: `model.topics` (array) and, on each correction or check, the existing `corrected` field or a new `check` field `{ by, date, note }`.

- [ ] **Step 1: Write the failing tests**

In `tests/decisions.test.mjs`, add tests with inline record text:
- A table without the optional columns gives `time: null, topic: null, impact: null, replaces: []`.
- `| Time (UTC) |` with `21:05` gives `time: "21:05"`. The value `25:00` or `9:05` throws `decisions.md:<line>: Time (UTC) "9:05" must look like 14:30.` An empty cell or `-` gives `null`.
- A Topic that is not in the `## Topics` table throws a message that lists the allowed topics. A Topic column with no `## Topics` table throws `a Topic column needs a ## Topics table`.
- `Replaces` with `D3, D5` gives `["D3", "D5"]`. A row D4 with `Replaces` D7 throws `D4 cannot replace a later decision D7.`, and an unknown ID throws `unknown decision "D99"`.
- `checked` is `false` for `How = classified` with no correction and no check. It is `true` for any other How, for a classified row with a Corrections row, and for a classified row with a Checks row.
- A Checks row that names an unknown decision throws with its line.

In `tests/project.test.mjs`, assert that `loadProject("tests/fixtures/full").topics` has the fixture topics.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: the new tests FAIL; the old tests pass.

- [ ] **Step 3: Implement the columns in `decisions.mjs` and the cross-row checks in `readAllDecisions`**

`findTable` already accepts extra columns. Read the optional cells with `c["Time (UTC)"] ?? ""`. Do the Replaces checks after all rows and rulings are read (an ID is "later" when its number is larger). Add Topics and Checks rows to the fixture: at least one classified row that is checked, one that is not, and one row with all four optional columns.

- [ ] **Step 4: Run the tests to see them pass**

Run: `npm test`
Expected: PASS, with no change to the old assertions.

- [ ] **Step 5: Commit**

```bash
git add skills/replication-materials/scripts/lib tests
git commit -m "Read optional decision columns, topics and checks"
```

### Task 2: Releases and results files

**Files:**
- Create: `scripts/lib/releases.mjs`
- Modify: `scripts/lib/project.mjs` (`loadProject`)
- Create: `tests/fixtures/full/replication_materials/project/releases.md`, `tests/fixtures/full/replication_materials/project/results.md`, `tests/fixtures/full/data/summary.csv`
- Test: `tests/releases.test.mjs`

**Interfaces:**
- Consumes: decision IDs from Task 1.
- Produces: `readReleases(text, file, decisionIds)` returns `[{ tag, date, time, commit, summary, decisionIds, resultIds, line }]`. Columns: `Tag`, `Date`, `Commit`, `Summary`, `Decisions`, `Results`.
- Produces: `readResults(text, file, { root, releaseTags, decisionIds })` returns `[{ id, release, result, value, source, decisionIds, replaces, line }]`. Columns: `ID`, `Release`, `Result`, `Value`, `Source`, `Decisions`, `Replaces`.
- Produces: `model.releases` (newest first) and `model.results` (in ID order), both `[]` when the file is absent.

Ruling for this plan: the results file has a `Replaces` column, not the `Superseded by` column of the design. A new row names the result it replaces, so no row is edited later. This keeps the rule of the record that rows are not changed. The page derives "replaced by".

- [ ] **Step 1: Write the failing tests**

In `tests/releases.test.mjs`:
- Tag must match `^v\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$` and be unique.
- Date is `YYYY-MM-DD` or `YYYY-MM-DDTHH:MMZ` (the time goes in `time`).
- Commit matches `^[0-9a-f]{7,40}$`.
- Decisions is `-`, one ID, or a range `D1 to D63`. A range resolves to the existing IDs in it. An end ID that does not exist throws.
- Results is `-` or a comma list of result IDs. Each one must exist in `results.md`.
- Result ID matches `^H\d+$` (H for headline). Release is a tag of `releases.md` or `-` (not released yet).
- Source is a path from the repository root, optionally with `#anchor`. A missing file throws `results.md:<line>: Source "x" is not a file in the repository.`
- Replaces names an earlier result ID, or throws.
- A project with neither file gives `releases: [], results: []`.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: FAIL in `tests/releases.test.mjs`.

- [ ] **Step 3: Implement `releases.mjs` and call it from `loadProject`**

Read `results.md` first (releases refer to results), then `releases.md`. Check the cross-references both ways.

- [ ] **Step 4: Run the tests to see them pass**

Run: `npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/replication-materials/scripts/lib tests
git commit -m "Read releases and results"
```

### Task 3: Releases and Results pages

**Files:**
- Modify: `scripts/lib/pages.mjs` (`renderReleases`, `renderResults`, `renderSite`)
- Modify: `scripts/lib/html.mjs` (`pageShell`: the nav comes from the model)
- Test: `tests/pages.test.mjs`, `tests/a11y.spec.mjs` (`FIXTURE_PAGES`)

**Interfaces:**
- Consumes: `model.releases`, `model.results`, `model.decisions`, `model.config.repository`.
- Produces: pages `releases/index.html` and `results/index.html`. The nav shows "Releases" and "Results" only when the file exists.

- [ ] **Step 1: Write the failing tests**

- Releases page, newest first. Each release has an `h2` with the tag. It has links to `<repo>/tree/<tag>`, `<repo>/commit/<commit>`, and, from the second release on, `<repo>/compare/<previous>...<tag>`. It has a table of the decisions in its range (ID, Decision, Proposed by, Decided by) and a table of its results.
- Results page: one table with ID, Release, Result, Value, Source, Decisions, Status. Status is "Current" or "Replaced by H<n>". A filter has the groups Release and Status. Source links to `<repo>/blob/<release tag or main>/<path>`.
- An empty fixture (copy `tests/fixtures/full` without the two files to a temp folder) builds and has no "Releases" or "Results" nav item.
- Add both pages to `FIXTURE_PAGES` in `tests/a11y.spec.mjs`.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: FAIL for the new page tests.

- [ ] **Step 3: Implement the two renderers and the model-driven nav**

- [ ] **Step 4: Run the unit and accessibility tests**

Run: `npm test` and then `npm run test:a11y`
Expected: PASS for both. No axe violations at 320 and 1280 px.

- [ ] **Step 5: Commit**

```bash
git add skills/replication-materials/scripts/lib tests
git commit -m "Add the Releases and Results pages"
```

### Task 4: Timeline page

**Files:**
- Modify: `scripts/lib/pages.mjs` (`renderTimeline`), `scripts/lib/html.mjs` (nav)
- Test: `tests/pages.test.mjs`, `tests/a11y.spec.mjs`

**Interfaces:**
- Consumes: `model.events`, `model.decisions` (with `time`), `model.releases`, `model.milestones`, `model.people`.
- Produces: page `timeline/index.html`, always in the nav.

- [ ] **Step 1: Write the failing tests**

- The page has one `h2` per date, newest first.
- In a date, the timed items come in order of time, then the items with no time. Decisions with no time keep their ID order. A release has the label "Tag".
- A decision that a person decided (any ID in `decidedBy` that is not `claude`, `subagent` or `unknown`) shows its ID, time and text.
- Decisions that only Claude Code or a subagent decided, and the rulings, show as one count line per date, for example "7 decisions and rulings by Claude Code". The line links to the Decisions page.
- A stage table has the columns Stage, Start, End and Events (from `process.md`: the first and the last event of each stage). Each row has a bar: a `div` with a CSS width in percent of the full span, and `aria-hidden="true"`, because the table holds the same data.
- Add the page to `FIXTURE_PAGES`.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: FAIL.

- [ ] **Step 3: Implement `renderTimeline`**

- [ ] **Step 4: Run the unit and accessibility tests**

Run: `npm test` and `npm run test:a11y`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/replication-materials/scripts/lib tests
git commit -m "Add the Timeline page"
```

### Task 5: Contributions page and decision detail

**Files:**
- Modify: `scripts/lib/pages.mjs` (`renderContributions`, `renderDecisions`), `scripts/lib/project.mjs` (`readDocuments` lists `project/contributions.md` when it exists, kind `contributions`)
- Create: `tests/fixtures/full/replication_materials/project/contributions.md`
- Test: `tests/pages.test.mjs`, `tests/a11y.spec.mjs`

**Interfaces:**
- Consumes: decisions with `topic`, `impact`, `replaces`, `checked`, `corrected`, `check`; `model.topics`; the corrections table.
- Produces: page `contributions/index.html`, always in the nav; the document page of `project/contributions.md` when the file exists.

- [ ] **Step 1: Write the failing tests**

Contributions page:
- A grid table, "Who proposed and who decided": rows are the proposers, columns are the deciders, and the cells are counts. Rulings are not in the grid; a line under it gives their count.
- Section "Proposed by the researchers": every decision with a proposer who is a person (not `claude`, `subagent` or `unknown`). Each shows the ID, date and time, the text and the evidence quote.
- Section "Proposed by Claude Code and decided by a researcher".
- Section "Replaced decisions": the pairs "D58 → replaced by D62", from `replaces`.
- Section "Corrections and checks by the researchers": the rows of the Corrections and Checks tables.
- When `project/contributions.md` exists: its title, its `Status` from the Item/Value table, and a link to its document page. When it does not exist: "The researchers have not written their account yet."
- Each decision that is not checked shows the text "not checked by a person". The top of the page gives the count of these decisions.

Decisions page:
- The Date cell shows the date and the time when there is one (`2026-10-20 21:05`).
- A filter group "Topic" appears when topics exist.
- Under the decision text: "Impact: ...", "Replaces D58." and "Not checked by a person." when they apply.
- A table "Who decided, by topic": topics by deciders, with a total column (when topics exist).
- A table "Decisions over time" with a bar for each bin. The bins are days when the decisions span 2 or more dates. When they all have one date and some have a time, the bins are hours.
- A `<script>` in an Impact cell shows escaped.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: FAIL.

- [ ] **Step 3: Implement the two renderers**

- [ ] **Step 4: Run the unit and accessibility tests**

Run: `npm test` and `npm run test:a11y`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/replication-materials/scripts/lib tests
git commit -m "Add the Contributions page and decision detail"
```

### Task 6: Records detail and the Now section

**Files:**
- Modify: `scripts/lib/pages.mjs` (`renderRecords`, `renderHome`), `scripts/lib/project.mjs` (ruling count for each ledger)
- Test: `tests/pages.test.mjs`, `tests/project.test.mjs`

**Interfaces:**
- Consumes: `model.documents`, `model.milestones`, `model.releases`, `model.openItems`, the rulings.
- Produces: each document gets `milestone` (milestone ID or `null`) and `size` (a string or `null`).

- [ ] **Step 1: Write the failing tests**

- Records table columns: Date, Title, Kind, Milestone, Size, Status, Links.
- Milestone is the ID of the milestone whose Plan or Ledger is the document.
- Size: for a plan, "N tasks" (its `### Task` headings); for a ledger, "N tasks complete; M rulings"; else "-".
- Links: "Page" (the document page) and "GitHub" (`<repo>/blob/main/replication_materials/<path>`).
- Home has a section "Now" with the latest release (tag and date, or "No release yet."), the milestone at `now`, and the open items as a list with their IDs. It has links to the new pages.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: FAIL.

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run the tests to see them pass**

Run: `npm test` and `npm run test:a11y`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/replication-materials/scripts/lib tests
git commit -m "Show milestone, size and links on Records, and Now on Home"
```

### Task 7: Templates, docs and version 1.2.0

**Files:**
- Create: `templates/replication_materials/project/releases.md`, `templates/replication_materials/project/results.md`, `templates/replication_materials/project/contributions.md` (headers and empty tables only)
- Modify: `templates/replication_materials/project/decisions.md` (empty `## Topics` and `## Checks` tables; the optional columns in the header)
- Modify: `SKILL.md`, `references/record-formats.md`, `references/site.md`
- Modify: `scripts/lib/html.mjs`, `scripts/build-site.mjs`, `templates/.github/workflows/replication-site.yml` (version lines)
- Test: `tests/templates.test.mjs`, `tests/build.test.mjs`

**Interfaces:**
- Consumes: all of Tasks 1 to 6.

- [ ] **Step 1: Write the failing tests**

- The templates parse with no error, and a project made from the templates builds.
- The generator meta of every page is `replication-materials 1.2.0`.
- The workflow template has the version line 1.2.0.

- [ ] **Step 2: Run the tests to see them fail**

Run: `npm test`
Expected: FAIL.

- [ ] **Step 3: Write the templates and the docs**

`SKILL.md`, "During the work":
- Give each new decision row a Time (UTC) from `date -u +%H:%M`, and a Topic from the `## Topics` table. Give it Impact and Replaces when they apply.
- At each tag, add a row to `project/releases.md`.
- When the work gives a headline result, add a row to `project/results.md`. A new result that replaces an old one names it in Replaces. Never edit the old row.
- When a person checks a classified row and finds it right, add a row to `## Checks`.
- Add `contributions.md` to the red flags: "Claude Code can draft it. It is not complete until a researcher approves it."

`record-formats.md`: each new table, column, pattern and error. `site.md`: the new pages.

- [ ] **Step 4: Run all tests**

Run: `npm test`, `npm run test:a11y`, `npm run test:a11y:record`
Expected: PASS for all three.

- [ ] **Step 5: Commit, record and ask**

```bash
git add skills/replication-materials tests
git commit -m "Release replication-materials 1.2.0: releases, results, timeline, contributions"
```

Add a decision row and a process row to the `claude-skills` record, then commit them by its record rule. Ask fmm before the push of the code commits.

### Task 8: Update this project and fill in its record

**Files (this project, `fine_tuned_jev`):**
- Update: `.replication/build-site.mjs`, `.replication/lib/`, `.github/workflows/replication-site.yml`, the block in `CLAUDE.md` (the Update procedure of the skill)
- Create: `replication_materials/project/releases.md`, `replication_materials/project/results.md`, `replication_materials/project/contributions.md`, `replication_materials/plans/2026-10-21-backfill-check-review.md`
- Modify: `replication_materials/project/decisions.md` (Topics table, Checks table, optional columns for D1 to the last row)

**Interfaces:**
- Consumes: skill 1.2.0.

Ruling for this plan: the topics go in a `## Topics` table in `decisions.md`, not in `site.config.json` as the design said. The topics are then a record-only change, and the Update procedure does not change `site.config.json`.

- [ ] **Step 1: Update the skill files**

Follow "Update" in `SKILL.md`. Run the build check: `node .replication/build-site.mjs --out "$(mktemp -d)"`. Expected: `Wrote <n> pages ...`. Commit these files alone. Ask fmm before the push.

- [ ] **Step 2: Fill in Time for each decision**

Write a script in the scratchpad (not in the repository). For each decision row, open the transcript of its Source session (`~/.claude/projects/<slug>/<session>.jsonl`, or the session named in the row). Find the first user message, or the answer of an AskUserQuestion, that contains the words of the Evidence quote, after whitespace and quote normalization. Take its time stamp as UTC `HH:MM`. When no message matches, leave Time empty. Print the match count, and give fmm the count, not the transcript text.

- [ ] **Step 3: Fill in Topic, and Replaces where it is clear**

The topics, with one line of meaning each:
- Data and splits
- Models and prompts
- References
- Thresholds and calibration
- Comparison with CLIP
- Metrics and reporting
- Analysis document and figures
- Paid calls and budget
- Record and process
- Code and tooling

Claude Code chooses one topic for each row. Replaces is filled only where a later row states that it replaces an earlier one, for example D62 (CLIP baseline) and the earlier "best CLIP result" benchmark. Do not change any other cell. The original rows keep their text.

- [ ] **Step 4: Write `releases.md` and `results.md`**

- `releases.md`: one row: `v0.0.1`, 2026-10-20, `33ffd59`, a one-line summary, Decisions `D1 to D63`, and its result IDs.
- `results.md`: the headline results of v0.0.1. Each value comes from a file in the repository, named in Source: `tables/T4_test_results.csv`, `tables/T6_calibration.csv`, `tables/validation_size.csv`, `paper/msec2027_submitted.md`. Rows for the earlier benchmark (best CLIP result on the test set) and for the CLIP baseline at 50 per class are linked with Replaces. Release is `v0.0.1` for all of them.

- [ ] **Step 5: Draft `contributions.md` and the check list**

- `contributions.md`: an Item/Value table with `Status: draft, not approved`, `Written by: Claude Code (draft)` and `Approved by: -`. Then a list of the contributions of the researchers, each with the IDs of its decisions. Do not invent: each item names a decision row whose Proposed by is fmm or yjc.
- `plans/2026-10-21-backfill-check-review.md`: a table of D2 to D38 with columns Decision, Text, Evidence, Check, Note. Check is empty, for fmm to fill.

- [ ] **Step 6: Build check, commit and push**

Run: `node .replication/build-site.mjs --out "$(mktemp -d)"`
Expected: `Wrote <n> pages ...`.
Then run the secret scan on the staged files (count only). Commit the record-only files and push them to `main`. Check the run: `gh run list --workflow replication-site.yml --commit "$(git rev-parse HEAD)" --limit 1`. Expected: `completed success`.

- [ ] **Step 7: Show fmm the site**

Give fmm the links to the Timeline, Contributions, Releases and Results pages, and the check list. fmm approves `contributions.md` and does the check (D75) before the tag `v0.1.0`.
