# Audit dedup report

## Changes
- R/fair_loop.R:411 new dedupe_tool_blocks(): keeps each tool call once by id; prefers the assistant entry, else the first seen. Blocks without an id and tool results stay.
- R/fair_loop.R scoring_calls() and audit_transcript() now walk dedupe_tool_blocks(parsed$entries). close_loop() uses both, so it is covered. The cwd check is unchanged (it reads entries, not blocks, and its rows are already unique per cwd).
- scripts/fair_score.R: check-only end prints "Check-only: nothing was scored."
- tests/testthat/test-fair-loop.R: tool_line() now gives each call a unique id (it used the id "x" for all calls, which dedup would merge). New tests: 2.1.306 shape with and without blob entries (calls 1, 1, 2; one repeat row at t2; one outside Read row; two rows in all); close_loop passes the missing-call check.

## RED
Before the fix: FAIL 7 (scoring_calls length 6 not 3; 3 repeat rows; 2 Read rows; 6 rows; audit_rows 6).
## GREEN
Full suite: [ FAIL 0 | WARN 0 | SKIP 0 | PASS 2430 ]

## Real rehearsal transcript
scoring_calls: 1 1
audit: one row, 2026-10-21T12:14:44.830Z, Bash, "repeated scoring call for candidate 1". Nothing else.
