# decision-models-for-industrial-image-qc

This record belongs to a study that asks whether structured decision models (JEV, a hosted model, and Clef-Flash, an open-weight model) can detect manufacturing defects as well as few-shot CLIP with fewer labeled images, and give calibrated class probabilities. The record holds the decisions (who proposed and who decided each one), the process events with their times, the milestones and open items, the paid-call budgets, and the software versions. The experiment itself (each trial, its settings and its result) is in `experiment_log.md` and `results/` at the root of the repository.

People: Fadel M. Megahed (Owner) and Ying-Ju (Tessa) Chen (Co-author). The full list is in `project/roadmap.md`.

## Folders

| Folder | What it holds |
|---|---|
| `plans/` | Specs, plans and ledgers. The names are `YYYY-MM-DD-<topic>-<kind>.md`. |
| `probes/` | One folder for each probe, with scripts and a README. |
| `findings/` | The findings of each probe, with the script and the output. |
| `calls/` | The budgets in `README.md` and the logs of paid calls in `<service>-calls.csv`. |
| `project/` | The roadmap, the decisions and the process events. |
| `environment/` | Session information, lock files and software versions. |

## Local build

1. Install Node 22.
2. Open a terminal in the root folder of the repository.
3. Run `node .replication/build-site.mjs --out _site`.
4. Open `_site/index.html` in a browser.
