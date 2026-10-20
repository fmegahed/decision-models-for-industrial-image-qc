# Paid calls

Claude Code makes no paid call before a row exists for it in this table.

| Date | Service | Purpose | Max calls | Max cost (USD) | Approved by |
|---|---|---|---|---|---|
| 2026-10-20 | TypeSafe JEV API | All JEV calls of the study, within the free credit for a new user (D44); calls left under the 7,000-call cap of D26 | 2446 | 5 | fmm |

## Call logs

Each service has one log: `<service>-calls.csv`. The columns are:

`time_utc,call_id,purpose,model,request_id,status,latency_ms,input_tokens,output_tokens,cost_usd`

## Paid calls before the record

The record started after the experiments (D7). The paid calls before it were approved in the chat, not in this table. There is no per-call log for them (open item O2).

- Service: TypeSafe JEV API (`jev-1.13.0`). Calls made: 4,554, on 2026-10-20.
- Approvals in the chat: batch 1 with 600 calls (D4), a cap of 1,000 calls (D10), a cap of 5,000 calls (D16), and a cap of 7,000 calls (D26).
- Estimated cost: about USD 0.52 (12.3 million input tokens at USD 0.042 per million). The estimate multiplies the calls of each batch by the input tokens measured for that kind of request. These calls count against the USD 5 budget above, so about USD 4.48 remains.
- Clef-Flash (D34) and CLIP ran on a local GPU. They had no API cost.

## Rule

Do not put a key, a token or an authorization header in any file in this folder.
