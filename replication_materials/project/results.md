# Results

Add one row for each headline result, with Release "-". At a tag, set the Release cell of each unreleased result in the release to the tag. That is the only edit of an old row. A new result that replaces an old one names it in Replaces.

## Results

| ID | Release | Result | Value | Source | Decisions | Replaces |
|---|---|---|---|---|---|---|
| H1 | v0.0.1 | JEV with 2 to 4 references: test balanced accuracy on the five datasets | 0.73 to 1.00 (pans 1.00, extrusion 0.73, textiles 0.86, pipe staple 0.98, microstructure 0.92) | results/final_test/method_comparison.csv | D11, D23 | - |
| H2 | v0.0.1 | JEV against CLIP with the same references: equal or better on all five datasets | microstructure equal (0.92 and 0.92); JEV better on the other four | results/final_test/method_comparison.csv | D24 | - |
| H3 | v0.0.1 | JEV against CLIP with the learning sets of the CLIP paper (20 to 700 labeled images): JEV better on three datasets, CLIP slightly better on two | pipe staple 0.98 vs 0.57, pans 1.00 vs 0.91, microstructure 0.92 vs 0.85; textiles 0.86 vs 0.975, extrusion 0.73 vs 0.82 | results/clip_paper/summary.csv | D28 | - |
| H4 | v0.0.1 | Calibration of the JEV probabilities on the test sets | raw ECE 0.11 to 0.23; isotonic regression 0.01 to 0.04 on four of the five datasets | results/final_test/calibration.csv | D29 | - |
| H5 | v0.0.1 | Clef-Flash with the frozen JEV configurations: test balanced accuracy | 0.68 to 0.99 | results/final_test/method_comparison.csv | D34 | - |
| H6 | v0.0.1 | Benchmark of the analysis document: the best CLIP result on the test set for each dataset | pans 0.94, extrusion 0.83, textiles 0.98, pipe staple 0.61, microstructure 0.96 | tables/T4_test_results_long.csv | D58, D60 | - |
| H7 | v0.0.1 | JEV with references against the CLIP baseline (50 learning images per class, pans 10; rule of the CLIP paper): JEV higher on four datasets, lower on textiles | pans 1.00 vs 0.91, extrusion 0.73 vs 0.70, textiles 0.86 vs 0.98, pipe staple 0.98 vs 0.57, microstructure 0.92 vs 0.84 | tables/T4_test_results_long.csv | D62 | H6 |
| H8 | v0.0.1 | Validation size (JEV with references): test balanced accuracy settles at about 10 to 20 validation images per class; the calibration error keeps falling up to 50 | mean test balanced accuracy at 20 and at 50 per class: extrusion 0.726 and 0.725, textiles 0.848 and 0.855, pipe staple 0.991 and 0.980, microstructure 0.920 and 0.920 (pans have 8 per class only) | tables/validation_size.csv | - | - |
