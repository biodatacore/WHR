# v12 out-of-sample validation of the v11c rules

Two new stratified random samples of NIH project-years were reviewed by hand, masked to the pipeline's calls: 200 for the women's cardiovascular (CV) brief (`C201`-`C400`, primary measure CV-WHR) and 200 for the total WHR brief (`W201`-`W400`, primary measure WHR). No core project in either sample appeared in any earlier review or validation set (`prior_core_all.txt`, 1,183 core projects), and no core project is in both samples. The v11c rules were frozen before sampling.

## Design
* Frame: v11c project-years FY2013-2025 with text.
* Strata: v11c label x fiscal-year band (FY2013-2018, FY2019-2025). CV set: "CV yes, CV-WHR yes" (100), "CV yes, CV-WHR no" (60), "CV no" (40). Total WHR set: "WHR yes" (100), "WHR no" (100). Simple random sampling of project-years within each stratum, seed 20261102, one project-year per core project.
* Weights: N_h / n_h (portfolio project-years); a dollar weight (x project USD) is reported as a secondary analysis. `strata.csv` gives N_h, n_h, weights and stratum dollars.
* Reference standard: the reviewer's answer. Test: the v11c call. 95% CIs: stratified bootstrap (2,000 replicates, resampling within strata), percentile method.

## Results (unweighted / weighted to the portfolio)

| | Sensitivity, % | Specificity, % | Kappa |
|---|---|---|---|
| Women's CV research (CV-WHR, CV set) | 97.6 / 69.3 (95% CI 46.9-100) | 84.5 / 99.9 | 0.80 / 0.75 |
| Overall WHR (total WHR set) | 94.5 / 60.8 (95% CI 44.5-88.5) | 87.2 / 98.7 | 0.81 / 0.68 |

The weighted sensitivities are imprecise: each grant missed among predicted negatives carries a large weight (up to ~18,000 project-years), and the drop comes from 2 (CV) and 5 (WHR) missed grants. Weighted specificity is high, so the estimates are likely conservative (the rules rarely include grants that reviewers reject but miss some that reviewers accept). Every statistic, weighting and CI is in `results/v12_validation_scores.csv`.

## Files
| File | Content |
|---|---|
| `results/v12_validation_items.csv` | one row per reviewed project-year: set, review ID, public NIH project number, core project, FY, administering IC, USD, stratum, N_h, n_h, weight, v11c calls (WHR, CV, CV-WHR) and the reviewer's calls and WHR category. No titles, abstracts, reviewer comments, reviewer identities, investigator or organization names. |
| `results/v12_validation_scores.csv` | sensitivity, specificity, PPV, NPV, agreement, kappa and prevalence, unweighted, count-weighted and dollar-weighted, with bootstrap CIs |
| `strata.csv` | sampling strata |
| `reviewer_instructions.txt` | the rules sheet given to reviewers |
| `prior_core_all.txt` | core projects excluded because they were in an earlier review set |
| `code/score_v12_validation.py` | scoring; reproduces `results/v12_validation_scores.csv` exactly |
| `code/build_samples.py`, `code/frame.R` | provenance: how the frame, samples and reviewer workbooks were built from a full raw run (needs intermediate files that are not shipped) |

Rescore from the shipped files:

```sh
cd validation_v12/code
python3 score_v12_validation.py --items ../results/v12_validation_items.csv --set CV --out cv_scores.csv
python3 score_v12_validation.py --items ../results/v12_validation_items.csv --set totalWHR --out whr_scores.csv
```
