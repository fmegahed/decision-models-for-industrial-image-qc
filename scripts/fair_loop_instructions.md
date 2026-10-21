# Goal: Improve the design AUC of {{model}} on {{dataset}} images

You work in a small sandbox folder with Claude Code. Use a disciplined, small-step loop. Your objective is to **raise the ROC AUC on the design images** of the `{{dataset}}` dataset. You do this by changing only two texts: the description of a nominal image and the description of a defective image.

## What the model does

{{model}} is a structured decision model. For each image, it reads the two descriptions and two reference images of each class. It then gives a probability that the image is defective. The probability depends on your two texts. The ROC AUC measures how well the probabilities rank the defective images above the nominal images.

You cannot change the model, the reference images, the image size or the crop. You change only the two texts.

## Files in this folder

- `images/`: the design images, named `img_001` and so on. `labels.csv` gives the class (`nominal` or `defective`) and the defect type of each image. The defect types are: {{defect_types}}.
- `references/`: the four reference images that the model sees (`normal_1`, `normal_2`, `defective_1`, `defective_2`).
- `generic_description.csv`: the generic description (columns `normal` and `defective`).
- `candidates/1.csv`: candidate 1. It holds the generic description.
- `scores/`: one score file for each scored candidate. It is written for you.
- `loop_log.csv`: one row for each scored candidate. It is written for you.
- `score.sh`: the scoring command.

## What you may read

Read only files in this folder. You may look at the images in `images/` and `references/` with the Read tool. Do not read, list or search any file outside this folder. Do not use the internet. Your tool calls are audited after the loop.

## Steps

1. Run the scoring command for candidate 1. It scores the generic description:

   ```
   {{score_command}}
   ```

   Replace `N` with the candidate number. Run it from this folder. It scores all design images, so it takes a few minutes. Run it once for each candidate.
2. Read the printed result: the AUC, the mean score for each defect type and the current best candidate. Open `scores/N.csv` to see which images get the wrong scores.
3. Look at the images that the model ranks wrongly. Compare them with the reference images.
4. Write the next candidate to `candidates/N.csv`, where N is the next number. The file is a CSV with three columns: `normal`, `defective` and `reason`. It has one data row. Put each text in quotes. Write the reason in one or two sentences: what you saw, and what the new text changes.
5. Score the candidate with the scoring command. Go back to step 2.

## Rules

- A candidate changes only the `normal` text and the `defective` text. Each text is plain language about what is visible in an image. Do not write instructions about scores or labels.
- Use the next number only. The scoring command refuses a skipped number, a number that you already scored and any number above 6.
- Score each candidate once. Do not edit a candidate file after you score it.
- Do not change the other files in this folder.
- Base each change on what you see in the design images and in the scores. Change one idea at a time, so that the log shows what helped.
- Do not aim for an AUC of 1. A small design set can mislead you. Prefer a clear, general description over a long list of special cases.

## Keep rule

A candidate replaces the current best only if its AUC is at least 0.02 higher than the AUC of the current best. Candidate 1 is the first best. The last candidate that passes the rule is the final description. The scoring command prints the current best after each run. You do not apply the rule yourself.

## Limit and stop

You have at most 6 candidates, including candidate 1. Stop after you score candidate 6. Stop sooner if you have no further idea that you expect to help. Then write a short summary in your last message: the candidates that you tried, the AUC of each, and the current best.

## Guardrails

- Do not guess the labels of images from their file names. The names carry no information.
- Do not try to read the scoring code or the model settings.
- Do not run any command other than the scoring command and simple commands that list or read files in this folder.
- If the scoring command fails, report the error in your last message and stop. Do not retry more than once.
- Use only the Read, Write, Edit, Glob, Grep and Bash tools. Do not start subagents. Write only to the `candidates/N.csv` file of the next candidate.
- Do not use `~`, `$HOME`, any other variable, `cd`, or any path outside this folder in a command. Do not use PowerShell.
- Inside a text, write a quote as two quotes ("").
