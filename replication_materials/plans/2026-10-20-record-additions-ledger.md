| Item | Value |
|---|---|
| Status | Closed |
| Version | 1.0 (2026-10-21) |
| Written by | Claude Code |

This ledger is a copy of the working ledger for the plan `plans/2026-10-20-record-additions-plan.md`. It was copied on 2026-10-21 at the end of the work. Internal agent IDs are removed.


# SDD ledger — plan: C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev/replication_materials/plans/2026-10-20-record-additions-plan.md

Spec: C:/Users/megahefm/Dropbox/Miami/Code/claude/fine_tuned_jev/replication_materials/plans/2026-10-20-fair-comparison-design.md (Part B, section 10; git rules, section 11).
Worktree: C:/Users/megahefm/Dropbox/Miami/Code/claude/claude-skills-record-additions (branch record-additions, from main 385b472).
Baseline: npm test 108/108 pass; npm run test:a11y 43/43 pass.
Tasks 1 to 7 run here (subagent-driven). Task 8 runs in fine_tuned_jev, by the controller with fmm.

## Pre-flight scan

| Pair or task | Produces / consumes | Finding |
|---|---|---|
| T1 -> T2 | T1 gives decision IDs from readAllDecisions; T2 resolves ranges and Decisions lists against them | Consistent. Both edit loadProject in project.mjs; sequential, no conflict. |
| T1 -> T4 | T1 `time`; T4 orders by time | Consistent. |
| T1 -> T5 | T1 `topic, impact, replaces, checked, check`, `model.topics`; T5 renders them | Consistent names. |
| T2 -> T3 | T2 `model.releases` (newest first), `model.results`; T3 renders | Consistent. T3 empty-fixture test needs a fixture without the two files: T3 builds it in a temp folder. |
| T3, T4, T5, T6 (nav) | T3 makes the nav model-driven; T4 adds Timeline; T5 adds Contributions | The plan does not fix the nav order. Ruling 1. |
| T3, T4, T5 (a11y) | each adds its page to FIXTURE_PAGES | T5 also adds a document page (project/contributions.md) that the plan does not list for a11y. Ruling 5. |
| T5 <- T1 (Checks) | T5 lists "Corrections and checks"; T1 parses the Checks table | Consistent. |
| T6 <- T1 (rulings) | T6 counts rulings for each ledger | readRulings exists; consistent. |
| T7 <- T1 (templates) | T7 adds optional columns to the template decisions.md header | T1 must accept empty optional cells and an empty Topics table, else the template D1 row fails. Ruling 2. |
| T7 <- SKILL.md set-up step 7 | the placeholder check greps README.md and decisions.md only | New template files must not hold a placeholder marker. Ruling 4. |
| T8 <- T1 | T8 puts topics in a Topics table in decisions.md | Consistent with T1 (the design said site.config.json; the plan rules for decisions.md in T8). |
| T1 (self) | tests vs code | Replaces: the plan does not say if ruling IDs are allowed. Ruling 3. |
| T2 (self) | tests vs code | Consistent. Fixture file data/summary.csv is under the fixture root, which loadProject receives. |
| T3 (self) | tests vs code | Consistent. |
| T4 (self) | tests vs code | Consistent. |
| T5 (self) | tests vs code | Consistent; contributions.md listed by readDocuments also shows on Records (kind contributions), which T6 renders. |
| T6 (self) | tests vs code | Consistent. |
| T7 (self) | tests vs code | Consistent. |

Ruling 1: The nav order is Home, Records, Decisions, Contributions, Timeline, Releases, Results, Progress, Process, then the extra pages. Releases and Results show only when their record file exists. — The plan leaves the order open and three tasks touch it; one order avoids churn. — Cost if wrong: a one-line reorder.
Ruling 2: An empty or "-" cell in Time (UTC), Topic, Impact or Replaces gives null (or [] for Replaces) with no error, and a Topics table may have no rows. The plan rule stays: a Topic column with no Topics table is an error. — The templates and old rows need empty cells. — Cost if wrong: small parser change.
Ruling 3: Replaces accepts decision IDs (D<n>) only; ruling IDs (R-...) are an error in Replaces. — Rulings have no Replaces column and live in ledgers. — Cost if wrong: widen one regex.
Ruling 4: The new template files (releases.md, results.md, contributions.md) hold no placeholder marker of the form [...] so set-up step 7 stays valid. — Cost if wrong: set-up leaves a marker unflagged.
Ruling 5: Task 5 adds docs/project/contributions/index.html to FIXTURE_PAGES with the Contributions page. — New pages must pass axe. — Cost if wrong: one more a11y case.

## Tasks
Task 1: dispatched (BASE 385b472; implementer, sonnet)
Task 1: implementer DONE_WITH_CONCERNS (5fc73a3; 115/115 unit, 43/43 a11y; no clean RED log; synced .replication/lib copies for repo-record test; readAllDecisions returns {decisions, topics})
Task 1: review dispatched (reviewer, sonnet; package review-385b472..5fc73a3.diff)
Task 1: review Approved (spec ✅, no Critical/Important). ⚠️ full suite resolved by controller: npm test 115/115 pass.
Task 1: minor (deferred): self-replace (D4 replaces D4) gives the 'later decision' message; non-D<n> own ID skips the order check
Task 1: minor (deferred): applyChecks keeps only the first Checked by ID (as applyCorrections); two Checks rows for one decision overwrite silently
Task 1: minor (deferred): parseTables runs three times per readDecisions call
Task 1: minor (deferred): fixture D1 and D2 How changed to classified instead of adding rows
Task 1: complete (commits 385b472..5fc73a3, review clean)
Task 2: dispatched (BASE 5fc73a3; implementer, sonnet)
Task 2: implementer DONE (1919745; 138/138 unit, 43/43 a11y; RED ERR_MODULE_NOT_FOUND; Decisions cells accept lists and ranges, a superset)
Task 2: review dispatched (reviewer, sonnet; package review-5fc73a3..1919745.diff)
Task 2: review Approved with 1 Important (Source accepts backslash: platform-dependent build; report claims otherwise)
Ruling 6: Task 2 fix round adds a consistency check: when a release lists H<n> in Results, the Release cell of H<n> must be that tag. — Task 3 shows results per release; two sources must agree, and the brief asks to check cross-references both ways. — Cost if wrong: one extra error case.
Task 2: minor (deferred): misleading comment 'Results come first' in readReleasesAndResults header
Task 2: minor (deferred): self-replace H1->H1 says 'later result'
Task 2: minor (deferred): release sort ties keep file order
Task 2: minor (deferred): local optional-file read helper may duplicate
Task 2: minor (deferred): no loadProject-level test for a release naming a missing result
Task 2: fix round 1/5 (2 addressed, 0 open — Source backslash, Ruling 6 consistency; commits 1919745..a4dba3a)
Task 2: complete (commits 5fc73a3..a4dba3a, review clean)
Ruling 7: model.recordFiles = { releases, results } (booleans) says which optional files exist; a missing file writes no page and no nav item; an existing file with no rows writes the page with 'No releases yet.' / 'No results yet.' — Needed to tell a missing file from an empty one. — Cost if wrong: one model field.
Task 3: dispatched (BASE a4dba3a; implementer, sonnet)
Task 3: implementer DONE (363b5ca; 147/147 unit, 53/53 a11y; NAV has show predicates; Home Pages list not changed — Task 6 owns Home)
Task 3: review dispatched (reviewer, sonnet; package review-a4dba3a..363b5ca.diff)
Task 3: review Approved (spec ✅, no Critical/Important). ⚠️ resolved: npm test 147/147 by controller; replaces-only-earlier is enforced by the Task 2 validator; Home links belong to Task 6.
Task 3: minor (deferred): pages.test.mjs mid-file imports; cwd-relative fixture path
Task 3: minor (deferred): source/tag/commit not percent-encoded in URLs
Task 3: minor (deferred): status text and data-status derived in two places
Task 3: minor (deferred): axe does not cover an unreleased result in the fixture
Task 3: complete (commits a4dba3a..363b5ca, review clean)
Task 4: dispatched (BASE 363b5ca; implementer, sonnet; resolutions: date grouping, ordering, person-decided rule, bar math, no milestones without dates)
Task 4: implementer DONE (9efeaeb; 152/152 unit, 58/58 a11y; milestones left out of dated list)
Task 4: review dispatched (sonnet; package review-363b5ca..9efeaeb.diff)
Task 4: review Approved (spec ✅, no Critical/Important). ⚠️ resolved by controller: tokens exist in DEFAULT_TOKENS (checked html.mjs); imports present; process times are validated as ...Z by readEvents (TIME regex), so no NaN or offsets; a11y 58/58 per implementer report.
Task 4: minor (deferred): ordering test covers only one timed vs one untimed item (no multi-timed sort, ID order, untimed release)
Task 4: minor (deferred): bar test hard-codes 3 bars; no test of the shared-instant 100% case or the 1% minimum
Task 4: minor (deferred): empty-state test narrow (no decisions-only model; decision and release text escaping untested)
Task 4: minor (deferred): aria-hidden on both track and bar; Span column empty for assistive tech
Task 4: minor (deferred): no page comment that milestones are left out (no dates)
Task 4: complete (commits 363b5ca..9efeaeb, review clean)
Task 5: dispatched (BASE 9efeaeb; implementer, sonnet; resolutions: Claude-proposed = claude or subagent; grids exclude rulings; 'No topic' row; hour bins with 'No time'; data-topic filter)
Task 5: implementer DONE_WITH_CONCERNS (b46db2f; 163/163 unit, 68/68 a11y; rulings lack replaces (guarded with ?? []); pages.mjs ~470 lines; Corrections/checks built from decision fields)
Task 5: review dispatched (sonnet; package review-9efeaeb..b46db2f.diff)
Task 5: review Approved (spec ✅, no Critical/Important). ⚠️ resolved by controller: d.checked computed after corrections and checks (Task 1, reviewed); applyCorrections always sets corrected.fields to an array; a11y 68/68 per implementer.
Task 5: minor (deferred): rulings lack replaces/topic/time fields (renderers guard with ?? [])
Task 5: minor (deferred): bar markup duplicated between Decisions chart and Timeline
Task 5: minor (deferred): grid() rebuilds the table wrapper instead of reusing table()
Task 5: minor (deferred): one date and no times gives one date bin (unstated, untested)
Task 5: minor (deferred): all-zero topic rows; 'rulings by Claude Code' hard-coded; multi-person cells vs Total; data-topic on every row
Task 5: minor (deferred): no test for rulings-only record or for a corrected/checked classified row on the page; brittle count assertion
Task 5: minor (deferred): pages.mjs ~470 lines; consider a module split later
Task 5: complete (commits 9efeaeb..b46db2f, review clean)
Task 6: dispatched (BASE b46db2f; implementer, sonnet; Home Pages list reuses NAV)
Task 6: implementer DONE (c11d3d7; 167/167 unit, 68/68 a11y; navItems(model) shared by nav and Home)
Task 6: review dispatched (sonnet; package review-b46db2f..c11d3d7.diff)
Task 6: review Approved (spec ✅, no Critical/Important). ⚠️ resolved by controller: a11y 68/68 per implementer (tables sit in scroll regions); loadConfig rejects a repository URL with a trailing slash (REPOSITORY regex); ledger format Task <n>: complete is the skill's own convention.
Task 6: minor (deferred): Records 'Page'/'GitHub' link texts repeat in every row (context is the row)
Task 6: minor (deferred): first-match milestone for a document that is plan of one and ledger of another
Task 6: minor (deferred): no test of a zero-ruling ledger
Task 6: minor (deferred): dead filter target !== 'index.html' in pageLinks; Repository item built in two places
Task 6: complete (commits b46db2f..c11d3d7, review clean)
Ruling 8: the template decisions.md appends the optional columns after Source (Time (UTC), Topic, Impact, Replaces); D1 gets an empty Time and '-' elsewhere; updating projects add the optional files and columns only when first needed (Update never changes replication_materials/). — Keeps set-up placeholders unchanged and the Update rule intact. — Cost if wrong: a template edit.
Task 7: dispatched (BASE c11d3d7; implementer, sonnet; controller writes the claude-skills record rows on main after the task)
Task 7: implementer DONE (5fedf07; 169/169 unit, 68/68 a11y, 77/77 a11y:record; During-the-work steps renumbered 6-8 -> 10-12)
Task 7: review dispatched (sonnet; package review-c11d3d7..5fedf07.diff)
Task 7: review Approved (spec ✅, no Critical/Important; step renumbering consistent; docs match parsers).
Task 7: minor (deferred): docs do not say that every existing row needs empty cells when columns are added
Task 7: minor (deferred): SKILL.md does not say a Topic column needs a Topics table (only record-formats.md)
Task 7: minor (deferred): Checks docs omit the unknown-person error
Task 7: minor (deferred): weak placeholder regex in templates test
Task 7: complete (commits c11d3d7..5fedf07, review clean)
Final review: dispatched (opus; package review-385b472..5fedf07.diff; asked to triage the deferred minors)
Final review: With fixes — 0 Critical, 6 Important (I1 checks by built-in IDs remove the mark; I2 checks not shown on Decisions; I3 unknown counted as Claude Code; I4 same-date release order; I5 site.md wrong, contributions authorship missing; I6 unreleased results at tag time), 12 minor; triage in final-fix-brief.md
Ruling 9: the optional templates (releases.md, results.md, contributions.md) move to templates/optional/project/ and are not copied at set-up; they are copied when first needed. — Set-up copied them to every project, which conflicts with 'when first needed'. — Cost if wrong: one folder move.
Ruling 10: at the tag, the Release cell of each unreleased result in the release is set to the tag; this is the only edit allowed on an old row; results.md and releases.md must agree both ways. — Ruling 6 made the edit necessary and the docs forbade it. — Cost if wrong: one docs sentence and one check.
Ruling 11: the Timeline count line counts only rulings and decisions decided only by claude or subagent; a decision decided by unknown (and no person) is listed with its text, decider 'Unknown'. — Unknown is not Claude Code. — Cost if wrong: one predicate.
Final review: fix wave dispatched (one fix subagent, opus; brief final-fix-brief.md)
Final review: fix wave reported DONE_WITH_CONCERNS (1622244; 186/186 unit, 68/68 a11y, 77/77 a11y:record; concern: section 'Corrections and checks by the researchers' lists corrections by built-in IDs)
Ruling 12: rename the Contributions section to 'Corrections and checks' and keep every row with its By column; a correction by a built-in ID is shown as made by Claude Code (or Subagent, Unknown). — The heading must not credit a researcher with work a person did not do; showing all rows keeps the record complete. — Cost if wrong: one heading.
Final review: fix wave DONE (1622244, 49274f3; 187/187 unit; a11y 68/68 and 77/77 in the main wave)
Final review: scoped re-review dispatched (opus; package review-5fedf07..49274f3.diff)
Final review: re-review of the fix wave — all findings ADDRESSED (I1-I6, M1-M3, M5-M12, Ruling 12), no new Critical/Important; npm test 187/187 re-run by the re-reviewer.
Final: parked — site.md says the topic filter shows when ## Topics exists; the code needs at least one row — Ruling: park; a docs nit with no effect on records; fix with the next skill edit. — Cost if wrong: a reader expects a filter that is absent.
Final: parked — site.md mark wording omits the How rule (record-formats.md is correct) — Ruling: park; record-formats.md is the reference agents follow. — Cost if wrong: a docs nit.
Final: parked — on one date, an untimed release sorts older than a timed one regardless of row order — Ruling: park; the brief asked for the exact tie only, and tags normally get a time or a date of their own. — Cost if wrong: a wrong 'latest release' in a rare case.
Final: parked — parameter needsCheck shadows the module function — Ruling: park; style only.
Final: parked — the Contributions 'Corrections and checks' table merges all corrections of a decision into one row with the last By and Date, so a person's correction followed by a claude correction shows only Claude Code — Ruling: real and deferred; no record has such corrections yet; list every corrector (corrected.byIds holds them) in the next skill edit; added as open item O10 in the claude-skills roadmap. — Cost if wrong: a researcher's correction is hidden on Contributions until fixed.
Final: merged record-additions into claude-skills main locally (merge e3da46e; option 1 chosen by fmm). Merged result: npm test 187/187, test:a11y 68/68, test:a11y:record 77/77. Not pushed yet.
Final: worktree and branch kept: the worktree holds this ledger until the end of milestone M4 (after Task 8); remove both then.
Final: pushed claude-skills main (e3da46e) with the consent of fmm; both workflow runs passed.
Task 8: update of fine_tuned_jev to 1.2.0 pushed with the consent of fmm (4d18c02); site run success.
Ruling 13: a back-filled decision whose matched UTC time falls on the day after its Date (D74 to D77) keeps no Time, so the Timeline keeps it at the end of its own date; D78 on uses the UTC date and time. — The Date column of D1 to D77 holds the local date; mixing a UTC time with a local date would misplace rows. — Cost if wrong: four rows without a time.
Ruling 14: results.md for v0.0.1 holds the claims of the submitted abstract (H1 to H5) with the sources the abstract names, plus the benchmark change H6 -> H7 and the validation-size result H8; values come only from files in the repository. — The design asked for the headline results of v0.0.1 and the benchmark change. — Cost if wrong: a reworded row.
Task 8: record back-fill pushed (98e0170): times 63 of 77 (10 classified or measurement rows have no matching words of a person; 4 next-day rows left empty), 10 topics, Replaces D16<-D10, D26<-D16, D30<-D22, D62<-D60, Topics and Checks tables, releases.md v0.0.1, results.md H1 to H8, contributions.md draft (not approved), check list plans/2026-10-21-backfill-check-review.md; site run success.
Task 8: complete (commits 4d18c02..98e0170 in fine_tuned_jev)
