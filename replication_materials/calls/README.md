# Paid calls

Claude Code makes no paid call before a row exists for it in this table.

| Date | Service | Purpose | Max calls | Max cost (USD) | Approved by |
|---|---|---|---|---|---|

## Call logs

Each service has one log: `<service>-calls.csv`. The columns are:

`time_utc,call_id,purpose,model,request_id,status,latency_ms,input_tokens,output_tokens,cost_usd`

## Paid calls before the record

The record started after the experiments (D7). The paid calls before it were approved in the chat, not in this table, so this table has no rows for them. There is no per-call log for these calls (open item O2).

- Service: TypeSafe JEV API (`jev-1.13.0`). Calls made: 4,554, on 2026-10-20.
- Approvals in the chat: batch 1 with 600 calls (D4), a cap of 1,000 calls (D10), a cap of 5,000 calls (D16), and a cap of 7,000 calls (D26). The person approved call counts; no cost limit in USD was set.
- Clef-Flash (D34) and CLIP ran on a local GPU. They had no API cost.

## Rule

Do not put a key, a token or an authorization header in any file in this folder.
