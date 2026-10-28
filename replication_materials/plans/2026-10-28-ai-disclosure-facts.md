# AI-use disclosure: facts (O6)

Facts for the AI-use disclosure of the MSEC 2027 paper (ASME position statement on AI, section B). Claude Code collected them on 2026-10-28 from the session transcripts and this record. fmm and yjc write the text (D110).

## Claude Code: main sessions

- Maker: Anthropic.
- Versions: 2.1.304 to 2.1.312.
- Models: claude-opus-5-5 (main agent); claude-sonnet-5-5 and claude-haiku-5-5 (subagents).
- Access: command-line interface on a Windows 11 desktop computer.
- Dates: 2026-10-20 to 2026-10-28 (2 sessions, 195 subagent transcripts).
- Use: Claude Code wrote all code of the project under the supervision of fmm (D279). This includes the code that draws F0 to F7 and the code of the LaTeX tables (D107, D257).

## Claude Code: description loops (contribution 2)

- 8 loop agents, one for each model and dataset (D81).
- Version 2.1.306. Model claude-opus-5-5. Headless mode, started by `scripts/fair_run_loop.sh`.
- Date: 2026-10-21.
- Prompt: `scripts/fair_loop_instructions.md`. Each candidate description, in order: the "Description loops" page of the record website.
- Each agent could run only the scoring command. All its Bash calls are `bash score.sh <n>`.

## replication-materials skill

- fmm made it with Claude Code. Public: https://github.com/fmegahed/claude-skills. Version 1.3.1 in this project.
- It keeps this record: 280 decisions (D1 to D280), each with proposer, decider, method, dated quote and session ID; stage rows; plans and ledgers; a budget row before each paid call; a log of each paid call.
- D2 to D38 come from earlier transcripts. fmm checked them (D75).

## Other tools (fmm reports them, D279)

- Codex, OpenAI. Model gpt-6-astra, reasoning effort xhigh. Use: polish of the LaTeX (TikZ) code of Figure 2, the method figure. IV.A.7 applies (D280). Access and dates: fmm to add.
- Grammarly. Use: editorial edits. Version, access and dates: fmm to add. Maker: fmm to confirm the current company name (Grammarly announced the name Superhuman in 2025).
- ChatGPT.com, OpenAI. Model sol-5.6, effort medium. Use: editorial edits, in some cases. Access: web browser. Dates: fmm to add.

## Limits of the record

- The record starts on 2026-10-20 with the import of an earlier study (JEV tuning and test results). AI use before that date is not in this sheet. fmm to add.
- The record shows only Claude Code work in this repository. The tools of the section above are self-reported.

## AI did not do these

- Claude Code wrote no paper text (D110) and did no literature search (D260).
- The paper does not use the TikZ draft of the method figure that Claude Code made (D106).
- The observations in the analysis document (supplement) and the table notes that Claude Code wrote are drafts. fmm and yjc rewrite them (D105, D114).
