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
* **A** Tier A conditions (including IBS and binge-eating disorder) count with a title hit (including the title acronyms MS, SLE, IBS, ME/CFS, POTS), or with >= 2 mentions of the same condition plus a women focus (women in title, >= 3 women mentions, or the sex-differences flag); v10 counted >= 3 pooled mentions with no focus. Men-only studies (new feature `menonly`: a men-only phrase such as "older men", "men only", MrOS or the Testosterone Trials, with no women terms) never qualify through this rule. Depression/anxiety/PTSD/Alzheimer's keep the women-focus rule. The v10 v2 condition rules (RA, thyroid, TMD, CFS, other) are replaced by the per-condition rule.
* **B** New Tier A conditions (including INOCA / coronary microvascular dysfunction and MINOCA) and women-focus-gated conditions (HFpEF, intimate partner violence); "chronic fatigue" over-matching fix; urinary incontinence/pelvic floor need no male/post-prostatectomy context (or a women focus). Regexes were checked against real abstracts; acronyms that over-matched were dropped or guarded ("crps" = collegiate recovery programs, "scad" = a penalized regression method, "stress-induced cardiomyopathy" in sepsis models, "ipv" = polio vaccine, "pah" = hydrocarbons).
* **Cw** offspring-only pregnancy studies, preclinical tool contexts, stronger outcome evidence for centre/training/network grants.
* **Ct** profound condition topics need a title hit or >= 3 mentions. A uniform >= 3 rule for all topics was tested and rejected (it removed more true female-specific, maternal and female-cancer calls than false ones).
* **Cv** background/future-only and isolated single CV mentions are not broad CV; BBB injury and white-matter lesions are not CV on their own.

### Results
The v11 numbers (after the IBS/binge-eating restoration, the INOCA/MINOCA move and the title-or-women-focus and men-only rule) are in the v10 / v11 / v11b table below.

## v11b (2026-11-01): topic-level decisions D1-D6 (`R/v11.R`, switches D1-D6; `WHR_V11_RULES=A,B,C` reproduces v11 exactly, regression-checked)

* **D1** Pulmonary arterial hypertension, IBS and binge-eating disorder count as WHR at one mention in the title or abstract, including the acronyms PAH (only with pulmonary-hypertension context) and IBS. No women focus is needed.
* **D2** INOCA, MINOCA and coronary microvascular dysfunction (new column `cmd`: any "coronary microvascular ..." phrase) count the same way. They are CV-WHR when the grant is CV.
* **D3** Fetal- or offspring-dominant grants are not WHR. The new column `matcond` holds strictly maternal outcomes. A grant is fetal-dominant when it has no maternal term in the title and either (a) at least 3 fetal or offspring terms, at most 2 maternal terms, and at least 4 times as many fetal as maternal terms, (b) a fetal term in the title and at most 1 maternal term, or (c) any fetal term and no maternal or women terms. Grants that qualify through a female-cancer, sex-differences, women-only-cohort or D1/D2 rule are exempt.
* **D4** Explicit sex-difference aims (new column `sexaim`) set the sex-differences flag. "Sex as a biological variable" boilerplate is not counted.
* **D5** Men-only studies are never WHR, even with the condition in the title. The new column `menonly2` drops the bare "mros" acronym, which also means mitochondrial ROS. Studies with female animals (ovariectomy, female mice or rats; column `femanimal`) or a women-only cohort are not men-only.
* **D6** Women-only cohorts are always WHR (columns `wonly`, `wenroll`, `menword`): WHI, the Nurses' Health Study, SWAN, the Women's Health Study, the Sister Study, SOF, the Black Women's Health Study, WHIMS, and studies that enroll only women.
* New feature columns: `pahacr`, `phctx`, `pahx`, `ibsacr`, `cmd`, `fetoff`, `sexaim`, `femanimal`, `wonly`, `wenroll`, `menword`, `matcond`, `menonly2`, each with a `t_*` title flag. They are included in the shipped cache.

### Results v10 / v11 / v11b (pooled dollar-weighted shares)
| | v10 | v11 | v11b |
|---|---|---|---|
| Total WHR FY2013-15 | 9.38% | 8.74% | 8.97% |
| Total WHR FY2023-25 | 8.98% | 8.65% | 8.85% |
| Trend FY2013-26, pp/yr (95% CI) | -0.006 (-0.079 to 0.067) | +0.022 (-0.047 to 0.092) | +0.015 (-0.053 to 0.083) |
| Total WHR excl. OT2HL158287, FY2023-25 | 8.81% | 8.48% | 8.68% |
| Women's CV share of CV FY2013-15 | 6.19% | 5.50% | 7.70% |
| Women's CV share of CV FY2023-25 | 10.26% | 10.77% | 12.83% |
| WHR project-years | 76,374 | 72,953 | 73,314 |

Verification: the v11b expected values pass in clean copies run from the shipped cache alone (total WHR 84/84, CV 201/201).

## v11c (2026-11-01): D3 softened (maternal-fetal protection)
* D3 now keeps maternal-fetal grants. A grant is kept when it has at least 2 maternal-fetal protection terms (new column `mfprot`: preeclampsia/HDP, maternal-fetal medicine/network, MFMU, pregnancy complications, obstetric disease, pregnant women, ...) and those terms plus IUGR terms (`iugr`) outnumber birthweight/fetal-growth terms (`bw`). Only grants with purely fetal or offspring outcomes are excluded. No other rule changed.
