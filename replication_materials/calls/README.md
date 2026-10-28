# Paid calls

Claude Code makes no paid call before a row exists for it in this table. The Service of a row is the name of its call log, `<service>-calls.csv`: `typesafe` is the TypeSafe JEV API (D111), `openai` is the OpenAI Decisions API, and `openrouter` is OpenRouter (D188).

| Date | Service | Purpose | Max calls | Max cost (USD) | Approved by |
|---|---|---|---|---|---|
| 2026-10-20 | typesafe | All JEV calls of the study, within the free credit for a new user (D44); calls left under the 7,000-call cap of D26 | 2446 | 5 | fmm |
| 2026-10-21 | typesafe | Fair comparison: description loops, checks, calibration and test runs (design X17, D84) | 50000 | 20 | fmm |
| 2026-10-23 | typesafe | Package decisions (M3), Task 2: real responses of each question type (noul, choice, score) and of an image request, for the tests of the package (D188) | 400 | 9.5 | fmm |
| 2026-10-23 | openai | Package decisions (M3), Task 2: the same with the OpenAI Decisions API (gpt-6-luna) (D188) | 400 | 9.5 | fmm |
| 2026-10-23 | openrouter | Package decisions (M3), Task 2: the same with Jev and Microsoft-Decision-1 through OpenRouter (D188) | 400 | 9.5 | fmm |
| 2026-10-23 | typesafe | Package decisions (M3), Task 11: saved results of vignettes 1 to 4 and 6 (D191) | 300 | 1 | fmm |
| 2026-10-23 | openai | Package decisions (M3), Task 11: the same with the OpenAI Decisions API (D191) | 300 | 1 | fmm |
| 2026-10-23 | openrouter | Package decisions (M3), Task 11: Jev and Microsoft-Decision-1 through OpenRouter for vignette 3 (D191) | 150 | 0.5 | fmm |
| 2026-10-23 | typesafe | Package decisions (M3), Task 12: vignette 5 repeats the study with Jev (grid, rescoring of the loop wordings, calibration, one test) (D191) | 8000 | 5 | fmm |
| 2026-10-23 | openai | Package decisions (M3), Task 12: the same with gpt-6-luna (D191) | 8000 | 10 | fmm |
| 2026-10-25 | typesafe | Space decisions (M6): smoke test and the gate on the private Space (D244) | 1000 | 0.05 | fmm |
| 2026-10-26 | typesafe-space | Space decisions (M6): the calls of visitors on the public Space, for each month (D227, D251). The app stops at USD 0.25 for each visit, USD 2 each day and USD 20 each month. It limits the cost, not the number of calls. Max calls is USD 20 at 8,253 tokens for each image call. | 57700 | 20 | fmm |
| 2026-10-28 | typesafe | Box study (M7), pilot with jev-1.14.0: the input tokens of one image at several sizes, the form of the Box answer, and the first Box answers on FabriD, tank screw and pipe clip (D269) | 2000 | 1 | fmm |

## Call logs

Each service has one log: `<service>-calls.csv`. The columns are:

`time_utc,call_id,purpose,model,request_id,status,latency_ms,input_tokens,output_tokens,cost_usd`

The log of `typesafe-space` is different. The Space keeps no log of single calls. It keeps one row for each day in `usage.csv` of the private dataset `fmegahed/decisions-space-usage`: date, calls, input tokens and cost. Claude Code copies these rows into the record at the end of M6 and in each later session about the Space. The rows start on the day the Space is public; the calls before that day are under D244. The file `typesafe-space-calls.csv` does not exist yet: the site of the record counts one row of a log as one call, so a row for each day needs a change of the record tools first (open).

## Paid calls before the record

The record started after the experiments (D7). The paid calls before it were approved in the chat, not in this table. There is no per-call log for them (open item O2).

- Service: TypeSafe JEV API (`jev-1.13.0`). Calls made: 4,554, on 2026-10-20.
- Approvals in the chat: batch 1 with 600 calls (D4), a cap of 1,000 calls (D10), a cap of 5,000 calls (D16), and a cap of 7,000 calls (D26).
- Estimated cost: about USD 0.52 (12.3 million input tokens at USD 0.042 per million). The estimate multiplies the calls of each batch by the input tokens measured for that kind of request. These calls count against the USD 5 budget above, so about USD 4.48 remains.
- Clef-Flash (D34) and CLIP ran on a local GPU. They had no API cost.

## Paid calls after the budget row

- 2026-10-20, about 18:40 UTC: 100 JEV calls, made by mistake. A test of a new guard in `scripts/optimize_jev.R` was meant to stop before any call, but Rscript reloaded the key from `.Renviron`. The run used the default microstructure settings, so it repeated the baseline (BA 0.54, AUC 0.789, against 0.55 and 0.803). Estimated cost: about USD 0.011. There is no per-call log (open item O2).
- Totals: 4,654 JEV calls, about USD 0.53. Left under the budget row: 2,346 calls and about USD 4.47.

## Calls of the fair comparison

Budget row of 2026-10-21 (D84). Each call has a row in `typesafe-calls.csv`. The cost is an estimate: input tokens times USD 0.042 per million.

| Step | Purpose prefix | Calls | Failed | Input tokens | Estimated cost (USD) |
|---|---|---|---|---|---|
| Checks before the loops | fair check | 4 | 0 | 6,448 | 0.0003 |
| Description loops (design set) | fair design | 1,248 | 0 | 2,422,368 | 0.10 |
| Calibration runs (set C) | fair calibration | 1,170 | 0 | 2,292,808 | 0.10 |
| Test runs (one time) | fair test | 6,012 | 0 | 12,622,200 | 0.53 |
| Total | | 8,434 | 0 | 17,343,824 | 0.73 |

- Left under the budget row: 41,566 calls and about USD 19.27.
- Clef-Flash and CLIP ran on a local GPU. They had no API cost.

## Calls of the Space gate

Budget row of 2026-10-25 (D244). The Space counts its own calls in the private dataset `fmegahed/decisions-space-usage` (file `usage.csv`, one row for each day). It does not write `typesafe-calls.csv`. The cost is an estimate: input tokens times USD 0.042 per million.

| Step | Calls | Input tokens | Estimated cost (USD) |
|---|---|---|---|
| Smoke test (`tests/live_smoke.R`, rows in `typesafe-calls.csv`) | 2 | 8,724 | 0.0004 |
| Tests of fmm on the private Space (`usage.csv`, 2026-10-25) | 177 | 877,933 | 0.0369 |
| Total | 179 | 886,657 | 0.0372 |

- Left under the budget row: 821 calls and about USD 0.013.
- At about 21:45 UTC, the usage page of TypeSafe showed 8,822 tokens for the day, about the smoke test alone. The page has a delay.
- On 2026-10-26 at about 00:18 UTC, the usage page of the key `huggingface-decisions` showed 179 requests, 886,657 input tokens and USD 0.0372. These numbers are the same as the table above. The estimate of the app (input tokens times USD 0.042 per million) is the same as the spend of TypeSafe.
- The balance of the TypeSafe account was USD 21.12. The account has no card (D241), so the balance is a hard limit for all calls of the account.

## Calls of the Box study

Budget row of 2026-10-28 (D269): USD 1 and 2,000 calls, model `jev-1.14.0`. Each call has a row in `typesafe-calls.csv` (purpose prefix `box pilot`). The cost is an estimate: input tokens times USD 0.042 per million.

| Step | Calls | Failed | Input tokens | Estimated cost (USD) |
|---|---|---|---|---|
| Image tokens: one tank screw image at 5 sizes, first try | 5 | 5 | 0 | 0 |
| Image tokens: the same, second try | 5 | 0 | 10,344 | 0.0004 |
| Box answers on 3 FabriD test images | 3 | 0 | 3,547 | 0.0001 |
| Spike of the region scan (D275), 20 images: direct requests | 22 | 0 | 30,155 | 0.0013 |
| Spike: scans of the regions | 36 | 2 | 688,335 | 0.0289 |
| Spike: a Box in the kept regions | 20 | 0 | 44,690 | 0.0019 |
| Total | 91 | 7 | 777,071 | 0.0326 |

- The first try failed with HTTP 400 "Invalid image request": the base64 text of the script had line breaks (`jsonlite::base64_enc()` adds them). The responses report no input tokens. The second try removed the line breaks, as the package decisions does.
- Image tokens: input tokens = 353 + 0.00253 x pixels (5 sizes, 280 to 1176 px high). One token is about 395 pixels. An image of 280 x 280 px is about 200 tokens; the largest image (2,458,624 px) is about 6,200 tokens.
- The spike failed twice before it ran: a scan without a `state` (HTTP 422, "Field required") and a scan of about 44,000 tokens (HTTP 400, "max_tokens_exceeded"). Neither reports input tokens. A scan of 33,155 tokens passed, so the spike sends the regions in requests of about 30,000 tokens. Two direct requests ran twice, because the first image was saved only at its end.
- Left under the budget row: 1,909 calls and about USD 0.967.

## Rule

Do not put a key, a token or an authorization header in any file in this folder.
