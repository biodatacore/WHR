## v11 (2026-11-01): tiered female-predominant criterion, new conditions, precision fixes

No new data: same inputs as v10 (FY2013-2025 unchanged; FY2026 RePORTER freeze of 2026-10-31). The shipped replication cache was rebuilt because the v11 rules need new keyword counts. Every v10 rule is kept. The v11 rules sit behind `WHR_V11_RULES` (`all` by default; `none` reproduces v10 exactly, verified against the v10 `tests/expected_values.csv`; `C` = `Cw,Ct,Cv`).

### Code
| File | Change |
|---|---|
| `R/v11.R` (new, both) | v11 switches A, B, Cw, Ct, Cv; per-condition female-predominant patterns (`fp_*`), male-context, offspring/maternal-exposure/maternal-outcome and preclinical-tool phrase counts; CV aim/background sentence counts; BBB/white-matter blanking; `v11_features`, `v11_assign_tiers`, `v11_cv_row_features`, `v11_cv_tiers`, `v11_topic_need`. |
| `R/00_setup.R` (both) | Sources `R/v11.R`. |
| `R/03_classify.R` (both) | Uses `v11_features` / `v11_assign_tiers`; CV repo adds the v11 row columns (`ts11 tw11 s11 w11 saim sbf`) and uses `v11_cv_tiers`. |
| `R/05_topics.R`, `R/topics_whr.R` (total WHR) | Ct thresholds for profound condition topics; new subtopic "Other female-predominant (SCAD, PAH, POTS, GI, thyroid, pain, vascular)" in group 4 (predominant) under switch B. |
| `docs/female_predominant_conditions.md` (new, both) | Condition list with tier, approximate female:male ratio and public source. |
| `tests/expected_values.csv` (both) | v11 values. |
| `README.md`, `data/README.md` (both) | v11 rules and the rebuilt cache. |

### Rules (see README "v11 changes")
* **A** Tier A conditions count when central (>= 2 mentions of the same condition or a title hit; v10 >= 3 pooled). Tier B (IBS, binge-eating disorder) needs a women focus or sex-differences research. Depression/anxiety/PTSD/Alzheimer's keep the women-focus rule. The v10 v2 condition rules (RA, thyroid, TMD, CFS, other) are replaced by the per-condition rule.
* **B** New Tier A and women-focus-gated conditions; "chronic fatigue" over-matching fix; urinary incontinence/pelvic floor need no male/post-prostatectomy context (or a women focus). Regexes were checked against real abstracts; acronyms that over-matched were dropped or guarded ("crps" = collegiate recovery programs, "scad" = a penalized regression method, "stress-induced cardiomyopathy" in sepsis models, "ipv" = polio vaccine, "pah" = hydrocarbons).
* **Cw** offspring-only pregnancy studies, preclinical tool contexts, stronger outcome evidence for centre/training/network grants.
* **Ct** profound condition topics need a title hit or >= 3 mentions. A uniform >= 3 rule for all topics was tested and rejected (it removed more true female-specific, maternal and female-cancer calls than false ones).
* **Cv** background/future-only and isolated single CV mentions are not broad CV; BBB injury and white-matter lesions are not CV on their own.

### Results (local build 2026-11-01; pooled dollar-weighted share of NIH funding)
| | v10 | v11 |
|---|---|---|
| Total WHR FY2013-15 | 9.38% | 9.87% |
| Total WHR FY2023-25 | 8.98% | 9.37% |
| Trend FY2013-26 (pp/yr, 95% CI) | -0.006 (-0.08 to 0.07) | -0.021 (-0.09 to 0.05) |
| Excluding all 7 key award groups, FY2023-25 | 8.65% | 9.06% |
| Excluding OT2HL158287, FY2023-25 | 8.81% | 9.20% |
| Imputation sensitivity (observed intramural rate), FY2023-25 | 9.01% (7.29%) | 9.41% (7.91%) |
| Women's CV share of CV funding FY2013-15 | 6.19% | 7.19% |
| Women's CV share of CV funding FY2023-25 | 10.26% | 11.70% |
| Women's CV excl. OT2HL158287, FY2023-25 | 8.51% | 9.85% |
| WHR project-years with text | 76,374 | 81,385 |

Cumulative contributions (total WHR FY13-15 / FY23-25, pp): A +0.40/+0.33; B +0.23/+0.21; Cw -0.15/-0.15; Ct 0/0 (topics only); Cv 0 (CV only). Women's CV (FY13-15 / FY23-25, pp): A +0.35/+0.33; B +1.07/+1.18; Cw -0.39/-0.07; Cv -0.02/0.00.
Verification: with `WHR_V11_RULES=none` the v11 code reproduced the v10 expected values (84/84 total WHR, 139/139 CV). Fresh copies run from the rebuilt shipped cache alone pass the v11 expected values (84/84 total WHR, 141/141 CV checks).
