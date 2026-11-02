# Temporal Trends in National Institutes of Health Funding for Women's Health Research, Fiscal Years 2013–2026: reproduction code (R)

Annotated R code (pipeline v11) that reproduces the numbers and figures of the accompanying brief report on NIH funding for women's health research, fiscal years 2013–2026. The v10 estimates use the RePORTER data freeze of 2026-10-31. Changes from the previous pipeline are in [`../CHANGE_LOG.md`](../CHANGE_LOG.md).

Repository: https://github.com/biodatacore/WHR

The code works from publicly available NIH grant records. It estimates the share of all NIH funding devoted to women's health research (WHR), FY2013–2026, tests its trend, and decomposes it into topic groups and subtopics.

The code is a faithful R port of the analysis pipeline used for the paper. Section numbers in
comments (S#.#) refer to internal methods sections; the methods are summarized under *Detailed methods* below
(the paper's brief eMethods give a shorter version).

## Terminology used in the code

The paper uses plain-language definitions; the code keeps short internal names. Their meaning:

| internal name in code | meaning in the paper |
|---|---|
| `Partial tier v3`, `t3`, `v3_*` (the *main* WHR definition) | **women's health research (WHR)**: keyword rules applied to the grant title, abstract and public health narrative indicate women's health as a primary or substantial focus |
| `Strict + sex differences`, `base` | narrower WHR definition (female-specific plus substantive sex-differences research), a definitional sensitivity analysis |
| `NASEM-comparable`, `tnc` | broader WHR definition closest to the NASEM committee's labels, a definitional sensitivity analysis |

Earlier rule sets (`v1`, `v2`) are nested inside `v3` and are kept only because `v3` is built from them. The strict and NASEM-comparable definitions are sensitivity analyses of the definition of WHR. They are not lower and upper bounds on dollars spent. Set `WHR_V11_RULES=none` to recover the v10 classification, and `WHR_V10_RULES=none WHR_V11_RULES=none` for the v9 logic.
`Figure2_v3` is the output name of the current three-panel Figure 2 (predominant/profound layout); the suffix refers to the figure layout, not to the pipeline version.


## What the pipeline does

| step | script | what it does | methods ref. |
|---|---|---|---|
| 0 | `R/00_setup.R` | checks packages, loads `config.R`, keyword dictionaries (`R/terms.R`), helpers (`R/utils.R`) and the v10 rule switches (`R/v10.R`) | – |
| 1 | `R/01_download.R` | optional RePORTER API v2 download (FY2026, intramural abstracts); builds FY2026 CSVs from the saved JSON | S2 |
| 2 | `R/02_build.R` | reads raw rows; one record per project per fiscal year with dollars and pooled text | S2–S4 |
| 3 | `R/03_classify.R` | rule-based women's health research (WHR) definitions (see *Terminology*); project-level analysis universe; yearly shares with intramural imputation | S5 |
| 4 | `R/04_analysis.R` | trend statistics: OLS with Newey–West SEs, joinpoint-style segmented regression | S11 |
| 5 | `R/05_topics.R` | multi-label topic tagging (`R/topics_whr.R`), decomposition FY2013–15 vs FY2023–25, large-award exclusions (numerator and denominator), topic trends; predominant vs profound categories realigned to NASEM for autoimmune disease and osteoporosis, with CVD split from diabetes/obesity | – |
| 6 | `R/06_figures.R` | Figure 1 and Figure 2 (ggplot2) | S10 |
| 7 | `R/07_verify.R` | compares every reported number with `tests/expected_values.csv` and prints PASS/FAIL | – |

`R/run_all.R` runs steps 1–7 in order. All classification is rule-based (regular expressions on
the project title, abstract and public health relevance text); no language model is used.

## Detailed methods

These expand the paper's Methods and brief eMethods.

**Grant records.** The analytic file combines 3 public-source extracts: NASEM committee grant workbooks built from NIH ExPORTER for FY2013–FY2023, ExPORTER Projects and Abstracts files for FY2024–FY2025, and RePORTER API (version 2) responses for FY2026. The v10 estimates use the freeze of 31 October 2026 (69,809 FY2026 records, $37.65 billion). FY2026 is still incomplete and still contains no intramural projects. The API also supplied intramural abstracts missing from the FY2020 and FY2024 bulk files. A re-query on that date still found no abstract for 47 intramural project-years (FY2020 n=24, FY2024 n=23), mostly ZIF facility and administrative awards. Only projects administered by an NIH Institute or Center are included. The files in `data/shipped/` are the v11 replication extract built from these inputs and reproduce the v11 estimates.

**Full-project funding attribution.** A project that meets a definition contributes its entire project-year cost. To avoid double counting multicomponent awards, whose component costs are already included in the parent total, every full project number contributes a single record per fiscal year, using the parent's total cost or, when no parent exists, the sum of its subprojects. Amounts are nominal US dollars. The pipeline does not assign a fraction of a project to WHR.

**Identifying women's health research (WHR).** WHR is identified by regular expressions run on each project's title, abstract and public health narrative, organized as nested definitions in which each broader definition adds rules to the narrower one. The main definition counts a grant when women's health is a primary or substantial focus and captures female-specific and reproductive conditions, maternal health, female and multisite cancers, conditions more common in women, HIV and sexually transmitted infections among women, female-population terms, and sex-differences research, excluding generic sex-as-a-biological-variable boilerplate. A narrower definition (female-specific plus sex-differences research) and a NASEM-comparable definition are definitional sensitivity analyses, not bounds on spending. Thresholds were fit to NASEM committee labels for FY2013–2017 and evaluated against FY2018–2023 labels using dollar-weighted precision and recall. The committee derived those labels with GPT-4o (OpenAI); no language model is part of this pipeline, and committee labels serve only for calibration and evaluation.

v10 changes to that definition, on by default (`R/v10.R`; `WHR_V10_RULES`):

* Pregnancy and maternal-fetal studies count as WHR only with maternal-outcome evidence: at least two maternal-outcome terms, or one such term in the title. Otherwise the project is classified without pregnancy terms.
* Centre, training and network grants count when they show women's or maternal outcome evidence. Without that evidence the previous downgrade remains.
* Breast cancer counts as WHR (a breast-cancer term in the title, or at least two mentions).
* Female-predominant conditions on the NASEM list count as WHR when the condition is central (in the title, or at least three mentions), without a separate women or female mention. Psoriasis, inflammatory bowel disease, celiac disease and type 1 diabetes are not on that list.
* The 47 intramural project-years that still have no text are imputed at 0% WHR in the main series. The dollar-weighted intramural rate from the other years is kept as a sensitivity: 6.53% under the previous rules, and 7.29% (+$89.5 million) when re-estimated under the v10 rules.


v11 changes, on by default (`R/v11.R`; `WHR_V11_RULES`, `none` = v10 rules; every v10 rule above is kept):

* **A. Tiered female-predominant criterion.** Each condition is counted separately (`docs/female_predominant_conditions.md`). Tier A conditions (female:male at least 2:1, or at least two-thirds women, including irritable bowel syndrome and binge-eating disorder) count when the condition (or its acronym MS, SLE, IBS, ME/CFS or POTS) is in the title, or when it has at least two mentions in the abstract and the grant is women-focused (women in the title, at least three mentions of women, or substantive sex-differences research) (v10: at least three pooled mentions, no focus needed). Men-only studies (a men-only phrase such as "older men", "men only", MrOS or the Testosterone Trials, and no women terms; feature `menonly`) never qualify through this rule. Tier B conditions (HFpEF, intimate partner violence) count only with a women focus or substantive sex-differences research. Depression, anxiety, PTSD and Alzheimer's disease keep the women-focus requirement.
* **B. New conditions.** Tier A: spontaneous coronary artery dissection, takotsubo syndrome, pulmonary arterial hypertension, POTS, autoimmune hepatitis, hypo- and hyperthyroidism, thyroid cancer, gallstones, microscopic colitis, idiopathic intracranial hypertension, complex regional pain syndrome, Raynaud phenomenon, giant cell arteritis / polymyalgia rheumatica, lichen sclerosus, pelvic organ prolapse, INOCA / coronary microvascular dysfunction and MINOCA. Tier B (women or sex-differences focus required): HFpEF and intimate partner violence. "Chronic fatigue" no longer counts in cancer or other-disease contexts, and urinary incontinence / pelvic floor terms do not count in post-prostatectomy or male contexts without a women focus. Generic "autoimmune", knee osteoarthritis, long COVID, hypermobile Ehlers-Danlos syndrome and borderline personality disorder are not added as stand-alone terms. A new subtopic in topic group 4 collects the added conditions.
* **C. Precision.** (Cw) Pregnancy studies that use maternal exposures only to study offspring outcomes (offspring-outcome and maternal-exposure phrases, no maternal-outcome phrase) lose their maternal-outcome evidence; preclinical tool contexts (mouse mammary tumour virus, estrogen as an assay stimulus) do not count as breast-cancer or hormone evidence; centre, training and network grants need at least two women's or maternal outcome phrases, or one in the title. (Ct) The mixed-sex "profound" condition topics (cardiovascular disease, diabetes/obesity, Alzheimer's disease, depression/anxiety, osteoporosis, CV/metabolic in women) need a title hit or at least three mentions. (Cv, CV pipeline) A row is not broad CV when its strong CV terms occur only in background or future-application sentences, or when it has a single strong CV mention outside the title and the aims; blood-brain-barrier injury and white-matter lesions are not CV on their own.
* **D. Topic-level decisions (v11b; switches D1-D6, `WHR_V11_RULES=A,B,C` gives v11 without them).** (D1) Pulmonary arterial hypertension, irritable bowel syndrome and binge-eating disorder count as WHR whenever they are a topic of the grant: one mention in the title or abstract, including the acronyms PAH (only with pulmonary-hypertension context and no aromatic-hydrocarbon context) and IBS, with no women-focus requirement. (D2) INOCA, MINOCA and coronary microvascular dysfunction (a precursor of INOCA; any "coronary microvascular ..." phrase) count the same way, and are CV-WHR when the grant is CV. (D3) Grants whose only outcomes are fetal or offspring outcomes (fetal, offspring, in utero, placental, birthweight, neonatal, embryo or child-development terms with few or no strictly maternal outcome or condition terms (fetal terms at least 3 and at least 4 times the maternal terms, with at most 2 maternal terms, or a fetal title term, or any fetal term with no maternal or women terms; maternal terms: preeclampsia, gestational diabetes or hypertension, postpartum outcomes, maternal mortality, morbidity or health, pregnant women, miscarriage, cesarean, infertility, contraception, menstruation, menopause; column `matcond`), no maternal term in the title and no sex-differences flag) are not WHR, unless a female-cancer, sex-differences, women-only-cohort or D1/D2 condition rule applies. (v11c) A grant is kept as WHR, despite fetal terms, when it has at least 2 maternal-fetal protection terms (column `mfprot`: preeclampsia/eclampsia, hypertensive disorders of pregnancy, maternal-fetal medicine/network/health, MFMU, pregnancy complications, pregnancies complicated by, obstetric disease/complications/patients/outcomes/care, placental abruption, cardiovascular health or adaptation in pregnancy, pregnant women, first-time/under-resourced/pregnant mothers) and these terms plus IUGR terms (column `iugr`) outnumber birthweight and fetal-growth terms (column `bw`). Only grants with purely fetal or offspring outcomes are excluded. (D4) Explicit sex-difference aims count as sex-differences research: for example "the role/impact/effects of (biological) sex", "sex-specific differences/mechanisms", "compare males and females", "describe X by age and sex", "sex-by-X interaction" and "moderated by sex". "Sex as a biological variable" boilerplate does not count. (D5) Men-only studies are never WHR, even with a female-predominant condition in the title. A study is men-only when it has a men-only phrase (column `menonly2`: for example "men only", "older men", "MrOS study", the Testosterone Trials) and no women terms, no female-animal terms (ovariectomy, female mice or rats) and no women-only cohort. (D6) Women-only cohorts are always WHR: the Women's Health Initiative, the Nurses' Health Study, SWAN, the Women's Health Study, the Sister Study, the Study of Osteoporotic Fractures, the Black Women's Health Study and WHIMS, or a study that enrolls or recruits women with no men or boys. Each is CV-WHR when the grant is CV.

**Topics and condition categories.** A dictionary of 34 subtopics in 6 topic groups (plus a residual general category) is matched against the text of WHR grants (76,374 project-years with text under the v10 rules). Each subtopic requires a dictionary term in the title or at least 2 mentions in the text (1 for some specific conditions). A grant matching several subtopics has its full project-year dollars divided equally among those subtopics. Separately, a grant matching several condition categories has its dollars divided equally among those categories. The two allocations are independent: each sums to the WHR total, and category dollars are not the sum of the subtopic dollars inside them.

Subtopics are grouped by how a condition affects women. Autoimmune disease is profound and osteoporosis is predominant, matching NASEM Table 7-1 and Chapter 3. The scheme is described as adapted from NASEM only where it still differs: NASEM's 2×3 DALY matrix is collapsed to two categories plus a cross-cutting group; thyroid disease, chronic pain and urinary conditions are placed as predominant; diabetes and obesity are added as profound.

* **predominantly** (exclusively or mostly women): female-specific conditions, maternal health, female cancers, female-predominant conditions (thyroid disease, migraine/chronic pain/fibromyalgia, urinary incontinence/UTI) and osteoporosis;
* **profoundly** (a large share of the morbidity or mortality burden in women, including conditions NASEM places with differential disability and early mortality): autoimmune disease, cardiovascular disease (CVD), Alzheimer disease and dementia, depression and anxiety, and diabetes/obesity (CVD is reported separately from diabetes/obesity);
* the remainder are **cross-cutting** (sex-differences biology, health equity, substance use, HIV and sexually transmitted infections, violence, women's cohorts) or unclassified.

**Statistical analysis.** Annual WHR and topic shares are trended by ordinary least squares with Newey–West standard errors (Bartlett kernel, 1 lag, 2 as a check; no prewhitening or small-sample correction; normal-theory 95% CIs). Pooled FY2013–2015 and FY2023–2025 shares are compared, and joinpoint-style segmented regression of the log WHR share gives annual and average annual percent changes. Sensitivity analyses drop FY2026. A further sensitivity removes seven award groups from both the WHR numerator and the NIH denominator: the NHLBI 3M/IMPROVE coordinating award (OT2HL158287), National Children's Study contracts, ECHO cohorts, Women's Health Initiative contracts and cohorts, the NRG Oncology network, the HIV Prevention Trials Network leadership award (UM1AI068619), and the NCI pooled contracts (N01CO000000 and N01CA000000). Award dollars leave the denominator even when the project was not classified as WHR. The main estimate keeps every award, including OT2HL158287 at its full project cost.

**Software and code.** The analysis was written in Python 3.13 (pandas, statsmodels) and ported to R 4.5.0 (data.table, stringi, sandwich, ggplot2) in this repository, which draws both figures. `R/07_verify.R` confirms that the R port reproduces every checked value within tolerance. The NASEM committee workbooks are not redistributed.

**Blinded manual validation.** Two reviewers, blinded to any pre-assigned labels, each reviewed 100 grants and verified the accuracy of the automated labeling (WHR status and topic assignments: topic group, subtopic, and predominant or profound category).

**Figures.** Figure 1: grey bars for all NIH funding with overlaid red WHR bars, red percentage labels (WHR share of NIH funding) drawn as plain text with no background box, FY2026 hatched. Figure 2: three panels stacked vertically (A, predominant / profound / cross-cutting / unclassified as % of all NIH funding; B, predominant families as % of WHR, including osteoporosis and not autoimmune disease; C, profound conditions as % of WHR, with CVD in red and autoimmune disease in place of osteoporosis), FY2026 shaded. Text is set large (13-pt base, 11–12-pt labels) for legibility at page width. End labels in panels A and C are spaced so they do not overlap.

## Replication data (included)

`data/shipped/` holds de-identified, compressed per-fiscal-year files derived from public NIH RePORTER records: an analytic file of every NIH project-year with funding and classification features, row-level cardiovascular term counts (where used), the title and text of every project-year in the main women's health research tier, and the project universe. With them, `Rscript R/run_all.R` reproduces every reported number and figure without any raw files (about 10–15 min). No investigator names, contact details or committee-derived labels are included. Contents, column definitions, checksums and how to compare a rebuild from raw records are documented in [`data/README.md`](data/README.md). De-identified results of the blinded manual validation are in `data/validation/`.

## Raw data (optional; not included in this repository)

To rebuild from the raw records instead (`Rscript R/run_all.R --raw`), put the raw files
in one directory (default `data/raw/`, or set `WHR_RAW_DIR`):

```
{FY}/AllData_{FY}.xlsx      FY2013–2023  NASEM committee grant workbooks, sheet "All Data"
{FY}/prj.csv, {FY}/abs.csv  FY2024–2025  NIH ExPORTER "Projects" and "Abstracts" files
2026/raw/*.json             FY2026       RePORTER API v2 responses (R/01_download.R --fetch)
2026/counts.json            FY2026       per-agency record counts (written by --fetch)
zfix/api_z.json             FY2020/2024  intramural titles/abstracts (R/01_download.R --fetch)
```

1. **FY2024–2025, NIH ExPORTER** (public): go to <https://reporter.nih.gov/exporter>, open
   *Projects* and *Abstracts*, download the CSV for each fiscal year, unzip, and rename to
   `prj.csv` and `abs.csv` in `data/raw/2024/` and `data/raw/2025/`.
2. **FY2026 and intramural abstracts, RePORTER API v2** (public, no key):
   `Rscript R/01_download.R --fetch` queries <https://api.reporter.nih.gov/v2/projects/search>
   (needs the FY2020 and FY2024 files for the intramural step). The published analysis used
   responses retrieved on 2026-10-31 for the v10 estimates (69,809 FY2026 records); FY2026 was
   incomplete and RePORTER revises records daily, so a new download gives somewhat different
   FY2026 numbers. The extract in `data/shipped/` is the earlier 2026-10-20 download.
   Exact reproduction of the v10 estimates requires the saved 2026-10-31 responses: [DATA AVAILABILITY STATEMENT / ARCHIVE LINK].
3. **FY2013–2023, NASEM committee workbooks** (`AllData_{FY}.xlsx`): these are the grant-level
   files assembled by the National Academies committee for *A New Vision for Women's Health
   Research* (2025; doi:10.17226/28586). They contain investigator names and are **not public**;
   they are obtained from the National Academies: [ACCESS ROUTE FOR NASEM COMMITTEE FILES].
   The pipeline reads only the columns it needs (ids, activity, administering IC, costs, title,
   abstract, PHR, `IS_NIH`); names are never loaded. *Alternative:* the same fiscal years can be
   downloaded from ExPORTER (step 1) and saved as `prj.csv`/`abs.csv`; the code then needs the
   committee-year rule changed in `config.R` (`committee_years`, `exporter_years`), and results
   will differ slightly because the committee files differ from current ExPORTER records
   (records revised since, and the committee's `IS_NIH` universe flag).

## How to run

```sh
# R >= 4.5 and the CRAN packages listed in DESCRIPTION:
Rscript -e 'install.packages(c("data.table","stringi","readxl","jsonlite","curl","sandwich","ggplot2","openxlsx","ragg","systemfonts"))'

# optional: point the pipeline at raw data / scratch space (or edit config.R)
export WHR_RAW_DIR=/path/to/raw   WHR_WORK_DIR=/path/to/scratch   WHR_WORKERS=4

# data/shipped (v11 cache) reproduces tests/expected_values.csv on a fresh clone
Rscript R/run_all.R --raw        # v10 from raw NIH files, including the 2026-10-31 FY2026 JSON
WHR_REBUILD=1 Rscript R/run_all.R --raw   # ignore an older feature cache in the work directory
WHR_V11_RULES=none Rscript R/run_all.R    # v10 rules on the shipped cache; does not match tests/expected_values.csv
Rscript R/run_all.R --from 04    # re-run from a step (intermediate files are kept)
Rscript R/07_verify.R            # re-check at any time
```

`config.R` holds every path, year range, seed and constant. `WHR_WORKERS` sets the number of
fiscal years processed in parallel (each needs ~1–2 GB of memory; parallelism uses forked
processes and is ignored on Windows). Figures use Arial if installed, otherwise the default sans font.

**Runtime and resources** (8-core Linux machine, R 4.5.0, 15 GB RAM): about 60–75 min wall time with 5 workers from scratch (download ~15 s, build ~5 min with 1 worker because of memory, classification ~45–60 min, analysis/topics/figures ~5–8 min); peak memory ~6 GB in step 02
Intermediate files need about 6 GB of disk.

## Expected outputs (`outputs/`)

| file | content |
|---|---|
| `Figure1.png/.pdf` | total NIH funding with women's health research funding (Figure 1) |
| `Figure2_v3.png/.pdf` | A: predominant / profound / cross-cutting categories (% of NIH); B: predominant families (% of WHR); C: profound conditions, CVD in red (% of WHR); panels stacked (Figure 2) |
| `whr_categories_predominant_profound.xlsx` | category scheme, pooled shares and Newey-West trends |
| `stats_results.xlsx` | OLS/Newey–West trends and segmented regression |
| `whr_topic_trends.xlsx` | taxonomy, totals, decompositions (all / excl. 3M / excl. key awards, with the NIH denominator reduced in the exclusion sheets), key awards, trends |
| `key_numbers_stats.csv`, `key_numbers_topics.csv` | the reported numbers (input to 07_verify.R) |
| `verification_report.csv` | every reported number: expected value, reproduced value, difference, PASS/FAIL |

## Verification

`tests/expected_values.csv` lists each checked number from the v10 analysis (RePORTER freeze 2026-10-31) with its full-precision value and an absolute tolerance (half a unit of the precision reported; counts and years exact). The committed `data/shipped/` tables are the v11 cache: `Rscript R/run_all.R` on a fresh clone reproduces every value in `tests/expected_values.csv`, and `WHR_V11_RULES=none` reproduces the v10 values.

On the previous pipeline, this R port reproduced all 75 checked values within tolerance. The v10 main-tier count is 76,374 project-years with text. The shipped text files still cover the previous main tier (71,784 project-years).

Known, documented differences from the original (Python) implementation:
* Regular expressions run on the ICU engine (stringi) instead of Python's `re`. Patterns are
  byte-identical and Python's "." and `\s` semantics are reproduced explicitly (`R/utils.R`).
  ICU and Python differ in rare Unicode word-boundary cases (combining marks), which changed
  feature counts for a handful of projects per year; no reported value is affected beyond its tolerance.
* Two project texts (FY2021, FY2022) differ in one character because of spreadsheet-reader
  differences; no reported value is affected.
* Standard errors: Newey–West (Bartlett kernel, no small-sample adjustment, normal-theory CIs);
  matching the statsmodels defaults used originally.
* The FY2026 numbers depend on the date of the API download (see Data).

## Package versions

R 4.5.0; data.table, stringi, readxl, jsonlite, curl, sandwich, ggplot2, openxlsx, ragg,
systemfonts (versions in `DESCRIPTION`). All are on CRAN. To pin them for long-term
reproducibility, run `renv::init()` once in a fresh clone and commit the generated `renv.lock`.

## License

Code: MIT (see `LICENSE`). NIH RePORTER data are public; NASEM committee files are subject to
the National Academies' terms.
