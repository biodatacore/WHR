# Temporal Trends in NIH Funding for Women's Cardiovascular Health Research: reproduction code (R)

Annotated R code (pipeline v11) that reproduces the numbers and figures of the accompanying brief report on NIH funding for women's cardiovascular health research. The v10 estimates use the RePORTER data freeze of 2026-10-31. Changes from the previous pipeline are in [`../CHANGE_LOG.md`](../CHANGE_LOG.md).

Repository: https://github.com/biodatacore/WHR

The code works from publicly available NIH grant records. It estimates the share of NIH cardiovascular (CV) research funding devoted to women's health research (WHR), FY2013–2026, tests its trend against non-CV research, and decomposes the change by research topic.

The code is a faithful R port of the analysis pipeline used for the paper. Section numbers in
comments (S#.#) refer to internal methods sections; the full methods are given under *Detailed methods* below
(the brief report has no supplement).

## Terminology used in the code

The paper uses plain-language definitions; the code keeps short internal names. Their meaning:

| internal name in code | meaning in the paper |
|---|---|
| `Partial tier v3`, `t3`, `v3_*` (the *main* WHR definition) | **women's health research (WHR)**: keyword rules applied to the grant title, abstract and public health narrative indicate women's health as a primary or substantial focus |
| `Strict + sex differences`, `base` | narrower WHR definition (female-specific plus substantive sex-differences research), a definitional sensitivity analysis |
| `NASEM-comparable`, `tnc` | broader WHR definition closest to the NASEM committee's labels, a definitional sensitivity analysis |
| `CV_tier == "broad"`, `broad2`, `cv` | **cardiovascular (CV) research**: a CV term in the title or repeated CV terms in the text, excluding non-CV usages |
| `strict` CV | narrower CV definition (sensitivity only) |
| `wcv` | women's CV research = CV research that also meets the WHR definition |

Earlier rule sets (`v1`, `v2`) are nested inside `v3` and are kept only because `v3` is built from them. The strict and NASEM-comparable definitions are sensitivity analyses of the definition of WHR. They are not lower and upper bounds on dollars spent. Set `WHR_V11_RULES=none` to recover the v10 classification, and `WHR_V10_RULES=none WHR_V11_RULES=none` for the v9 logic.


## What the pipeline does

| step | script | what it does | methods ref. |
|---|---|---|---|
| 0 | `R/00_setup.R` | checks packages, loads `config.R`, keyword dictionaries (`R/terms.R`), helpers (`R/utils.R`) and the v10 rule switches (`R/v10.R`) | – |
| 1 | `R/01_download.R` | optional RePORTER API v2 download (FY2026, intramural abstracts); builds FY2026 CSVs from the saved JSON | S2 |
| 1b | `R/01b_mortality.R` | women's age-adjusted CV mortality 2013–2024 (CDC WONDER): uses the shipped public table, or re-queries WONDER with `--fetch` | – |
| 2 | `R/02_build.R` | reads raw rows; one record per project per fiscal year with dollars and pooled text | S2–S4 |
| 3 | `R/03_classify.R` | rule-based women's health research (WHR) definitions (see *Terminology*); cardiovascular (CV) and women's-CV rules; project-level CV × WHR table; yearly shares with intramural imputation | S5, S9 |
| 4 | `R/04_analysis.R` | trend statistics: OLS with Newey–West SEs, joinpoint-style segmented regression, clustered grant-level logistic regression, CV × year interaction, two-proportion z tests with FDR | S11 |
| 5 | `R/05_topics.R` | multi-label topic tagging (`R/topics_cv.R`), decomposition FY2013–15 vs FY2023–25, large-award exclusions (numerator and denominator), topic trends | – |
| 6 | `R/06_figures.R` | Figure 1 and Figure 2 (ggplot2) | S10 |
| 6b | `R/06b_figure1_mortality.R` | Figure 1 as published: funding bars plus women's CV mortality on a second y-axis (`sec_axis`); mortality trend tests | – |
| 7 | `R/07_verify.R` | compares every reported number with `tests/expected_values.csv` and prints PASS/FAIL | – |

`R/run_all.R` runs steps 1–7 in order (including 1b and 6b). All classification is rule-based (regular expressions on
the project title, abstract and public health relevance text); no language model is used.

## Detailed methods

These are the detailed methods referred to in the paper's Methods section.

**Data sources and project records.** Grant records for FY2013–FY2023 came from the project-level workbooks that the NASEM committee assembled from NIH ExPORTER; FY2024–FY2025 records came from the NIH ExPORTER Projects and Abstracts files, and FY2026 records from the RePORTER API (version 2). The v10 estimates use the freeze of 31 October 2026 (69,809 FY2026 records, $37.65 billion). FY2026 is still incomplete and still contains no intramural projects. Intramural abstracts absent from the FY2020 and FY2024 bulk files were retrieved through the same API. A re-query on that date still found no abstract for 47 intramural project-years (FY2020 n=24, FY2024 n=23), mostly ZIF facility and administrative awards. Only projects administered by an NIH Institute or Center were analyzed. The files in `data/shipped/` are the v11 replication extract built from these inputs and reproduce the v11 estimates.

**Full-project funding attribution.** A project that meets a definition contributes its entire project-year cost. Because a multicomponent award appears as a parent record plus component records whose costs are already contained in the parent's total cost, records were collapsed to one per full project number per fiscal year, valued at the parent award's total cost or, when no parent record existed, the summed component costs. Dollars are nominal. The pipeline does not assign a fraction of a project to WHR. Topic splits, below, divide that full project-year cost among matched topics.

**Identifying women's health research (WHR).** WHR rules are nested, so each broader rule set keeps every project of the narrower one and adds projects matched by further terms. The rule set used throughout captures grants in which women's health is a primary or substantial (partial) focus and covers female-specific, maternal, female-predominant, and reproductive conditions; cancers that include female cancers; HIV and sexually transmitted infections in women; female-population terms; and substantive sex-differences research after boilerplate sex-as-a-biological-variable statements are filtered out. Rule thresholds were tuned on the committee's FY2013–2017 grant labels and checked on its FY2018–2023 labels with dollar-weighted precision and recall. The committee generated those labels with GPT-4o (OpenAI); they were used only for tuning and evaluation, and the classifier itself uses regular-expression rules and no language model. The strict-plus-sex-differences definition and the NASEM-comparable definition are definitional sensitivity analyses. They are not bounds on spending.

v10 changes to that definition, on by default (`R/v10.R`; `WHR_V10_RULES`):

* Pregnancy and maternal-fetal studies count as WHR only with maternal-outcome evidence: at least two maternal-outcome terms (maternal health, morbidity or mortality, pregnant women, postpartum, preeclampsia, gestational diabetes, preterm birth, pregnancy outcomes or complications, placenta, lactation, and related terms), or one such term in the title. Otherwise the project is classified without pregnancy terms.
* Centre, training and network grants are no longer automatically downgraded when the project shows women's or maternal outcome evidence. The CV classifier never had a blanket centre exclusion, because CV status already requires CV terms on the scored row.
* Breast cancer counts as WHR (a breast-cancer term in the title, or at least two mentions).
* Female-predominant conditions on the NASEM list count as WHR when the condition is central (in the title, or at least three mentions), without a separate women or female mention. The list covers lupus, Sjögren's, rheumatoid arthritis, multiple sclerosis, systemic sclerosis, autoimmune thyroid disease, antiphospholipid syndrome, primary biliary cholangitis, osteoporosis, migraine, fibromyalgia, ME/CFS, temporomandibular disorders, irritable bowel syndrome, interstitial cystitis, vulvodynia, chronic pelvic pain, urinary incontinence, pelvic-floor disorders, urinary tract infection, eating disorders and lymphangioleiomyomatosis. Psoriasis, inflammatory bowel disease, celiac disease and type 1 diabetes are not included.
* The 47 intramural project-years that still have no text are imputed at 0% WHR in the main series. A WHR call is not possible without text, and the CV analysis never imputed those dollars. The dollar-weighted intramural rate from the other years is kept as a sensitivity: 6.53% under the previous rules, and 7.29% (+$89.5 million) when re-estimated under the v10 rules.


v11 changes, on by default (`R/v11.R`; `WHR_V11_RULES`, `none` = v10 rules; every v10 rule above is kept):

* **A. Tiered female-predominant criterion.** Each condition is counted separately (`docs/female_predominant_conditions.md`). Tier A conditions (female:male at least 2:1, or at least two-thirds women, including irritable bowel syndrome and binge-eating disorder) count when the condition (or its acronym MS, SLE, IBS, ME/CFS or POTS) is in the title, or when it has at least two mentions in the abstract and the grant is women-focused (women in the title, at least three mentions of women, or substantive sex-differences research) (v10: at least three pooled mentions, no focus needed). Men-only studies (a men-only phrase such as "older men", "men only", MrOS or the Testosterone Trials, and no women terms; feature `menonly`) never qualify through this rule. Tier B conditions (HFpEF, intimate partner violence) count only with a women focus or substantive sex-differences research. Depression, anxiety, PTSD and Alzheimer's disease keep the women-focus requirement.
* **B. New conditions.** Tier A: spontaneous coronary artery dissection, takotsubo syndrome, pulmonary arterial hypertension, POTS, autoimmune hepatitis, hypo- and hyperthyroidism, thyroid cancer, gallstones, microscopic colitis, idiopathic intracranial hypertension, complex regional pain syndrome, Raynaud phenomenon, giant cell arteritis / polymyalgia rheumatica, lichen sclerosus, pelvic organ prolapse, INOCA / coronary microvascular dysfunction and MINOCA. Tier B (women or sex-differences focus required): HFpEF and intimate partner violence. "Chronic fatigue" no longer counts in cancer or other-disease contexts, and urinary incontinence / pelvic floor terms do not count in post-prostatectomy or male contexts without a women focus. Generic "autoimmune", knee osteoarthritis, long COVID, hypermobile Ehlers-Danlos syndrome and borderline personality disorder are not added as stand-alone terms. A new subtopic in topic group 4 collects the added conditions.
* **C. Precision.** (Cw) Pregnancy studies that use maternal exposures only to study offspring outcomes (offspring-outcome and maternal-exposure phrases, no maternal-outcome phrase) lose their maternal-outcome evidence; preclinical tool contexts (mouse mammary tumour virus, estrogen as an assay stimulus) do not count as breast-cancer or hormone evidence; centre, training and network grants need at least two women's or maternal outcome phrases, or one in the title. (Ct) The mixed-sex "profound" condition topics (cardiovascular disease, diabetes/obesity, Alzheimer's disease, depression/anxiety, osteoporosis, CV/metabolic in women) need a title hit or at least three mentions. (Cv, CV pipeline) A row is not broad CV when its strong CV terms occur only in background or future-application sentences, or when it has a single strong CV mention outside the title and the aims; blood-brain-barrier injury and white-matter lesions are not CV on their own.
* **D. Topic-level decisions (v11b; switches D1-D6, `WHR_V11_RULES=A,B,C` gives v11 without them).** (D1) Pulmonary arterial hypertension, irritable bowel syndrome and binge-eating disorder count as WHR whenever they are a topic of the grant: one mention in the title or abstract, including the acronyms PAH (only with pulmonary-hypertension context and no aromatic-hydrocarbon context) and IBS, with no women-focus requirement. (D2) INOCA, MINOCA and coronary microvascular dysfunction (a precursor of INOCA; any "coronary microvascular ..." phrase) count the same way, and are CV-WHR when the grant is CV. (D3) Grants whose only outcomes are fetal or offspring outcomes (fetal, offspring, in utero, placental, birthweight, neonatal, embryo or child-development terms with few or no strictly maternal outcome or condition terms (fetal terms at least 3 and at least 4 times the maternal terms, with at most 2 maternal terms, or a fetal title term, or any fetal term with no maternal or women terms; maternal terms: preeclampsia, gestational diabetes or hypertension, postpartum outcomes, maternal mortality, morbidity or health, pregnant women, miscarriage, cesarean, infertility, contraception, menstruation, menopause; column `matcond`), no maternal term in the title and no sex-differences flag) are not WHR, unless a female-cancer, sex-differences, women-only-cohort or D1/D2 condition rule applies. (D4) Explicit sex-difference aims count as sex-differences research: for example "the role/impact/effects of (biological) sex", "sex-specific differences/mechanisms", "compare males and females", "describe X by age and sex", "sex-by-X interaction" and "moderated by sex". "Sex as a biological variable" boilerplate does not count. (D5) Men-only studies are never WHR, even with a female-predominant condition in the title. A study is men-only when it has a men-only phrase (column `menonly2`: for example "men only", "older men", "MrOS study", the Testosterone Trials) and no women terms, no female-animal terms (ovariectomy, female mice or rats) and no women-only cohort. (D6) Women-only cohorts are always WHR: the Women's Health Initiative, the Nurses' Health Study, SWAN, the Women's Health Study, the Sister Study, the Study of Osteoporotic Fractures, the Black Women's Health Study and WHIMS, or a study that enrolls or recruits women with no men or boys. Each is CV-WHR when the grant is CV.

**Identifying cardiovascular (CV) research.** CV relevance is scored on each parent and component record, not on pooled project text, because components of large center awards can describe unrelated science. A record qualifies as CV research when CV is a substantive part of it, shown by a CV term in the title or repeated CV terms in the text; terms that do not denote CV research (eg, tumor angiogenesis, heart rate variability, intracranial or portal hypertension, heat stroke) are excluded. v10 also excludes tumour-vessel and tumour-endothelium phrases, cancer projects whose CV signal is only weak vascular language, and blood-disorder projects (sickle cell disease, thalassemia, thrombotic thrombocytopenic purpura, hemophilia, von Willebrand disease, coagulation or clotting factors, thrombocytopenia, anemia, hemostasis and related terms) unless the title names cardiac, pulmonary-hypertension, thrombotic or cerebrovascular disease. Any cardiotoxicity counts as CV (in the title, at least two mentions, or one mention plus at least two other strong CV terms) and overrides those exclusions. Random-sample review of the previous CV rule showed about 84% precision. Women's CV research is CV funding that also meets the WHR definition.

**CV topic dictionary.** Women's CV projects are searched against a 20-topic dictionary spanning sex-specific CV risk (eg, hypertensive disorders of pregnancy, menopause and sex hormones, polycystic ovary syndrome, gestational diabetes), conditions that mainly affect women (coronary microvascular dysfunction and INOCA/MINOCA, peripartum cardiomyopathy, SCAD, takotsubo syndrome), and broader themes. A topic is assigned when one of its terms appears in the title or at least twice in the text (once for rare named conditions). Projects can carry several topics. The full project-year cost is split equally among the matched topics, so topic dollars sum to the women's CV total. That split is independent of the category split in the companion pipeline; the two levels are not additive.

**Statistical analysis.** Newey–West standard errors use a Bartlett kernel with 1 lag (2 lags as a check), no prewhitening, and no small-sample adjustment, with normal-theory 95% CIs. Grant-level logistic models use cluster-robust standard errors by core project. Yearly CV vs non-CV comparisons use 2-proportion z tests with Benjamini–Hochberg FDR adjustment. Sensitivity analyses drop FY2026. A further sensitivity removes the NHLBI 3M/IMPROVE coordinating award (OT2HL158287) from the women's-CV numerator and from the CV denominator. The main estimate keeps that award at full cost. A second sensitivity removes seven award groups from both the numerator and the denominator: OT2HL158287, National Children's Study contracts, ECHO cohorts, Women's Health Initiative contracts and cohorts, the NRG Oncology network, the HIV Prevention Trials Network leadership award (UM1AI068619), and the NCI pooled contracts (N01CO000000 and N01CA000000). Mortality trends (CDC WONDER, women, age-adjusted to the 2000 US standard) use OLS with Newey–West SEs and log-linear APCs, with a sensitivity analysis omitting 2020–2022.

**Software and code.** Analyses were run in Python 3.13 (pandas, statsmodels) and independently re-implemented in R 4.5.0 (data.table, stringi, sandwich, ggplot2, and other CRAN packages) in this repository, which also generates both figures. `R/07_verify.R` compares each reported value with its reproduction; the R code reproduced 126 of 131 checked values within tolerance, and the remaining 5 agreed at the precision reported. Raw NASEM committee workbooks are not redistributed.

**Blinded manual validation.** Two study reviewers, blinded to any pre-assigned labels, each reviewed 100 grants and verified the accuracy of the automated labeling for WHR status, women's CV research status, and CV topic subtypes.

**Figures.** Figure 1 (`Figure1_mortality`, as in the paper): grey bars for total NIH CV funding with overlaid red bars for women's CV research, red percentage labels (women's share of CV funding) drawn as plain text with no background box, FY2026 hatched, and women's age-adjusted CVD (solid) and heart disease (dashed) mortality on a right-hand axis. Figure 2: topic shares of CV and women's CV funding as small multiples. The red dashed series drops OT2HL158287 from the numerator and from the CV denominator.

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

## CDC WONDER mortality data (included)

`inst/extdata/cdc_wonder_cvd_mortality_women_2013_2024.csv` holds 24 rows of public, aggregated national statistics (women, 2013–2024; one row per year and cause: age-adjusted death rate per 100,000 and number of deaths). It contains no individual records. Columns: `year, sex, cause, icd10, age_adjusted_rate_per_100k, deaths, database, standard_population, status`.

* **Source:** CDC WONDER, Underlying Cause of Death (National Center for Health Statistics, National Vital Statistics System), final data. D76 (1999–2020, bridged race) was used for 2013–2017 and D158 (2018–2024, single race) for 2018–2024. The two databases give identical national rates for 2018–2020.
* **Causes:** *all CVD* = ICD-10 I00–I99 (diseases of the circulatory system); *heart disease* = ICD-10 113 Cause List "Diseases of heart" (GR113-054: I00–I09, I11, I13, I20–I51).
* **Exact query** (same in D76 and D158; web forms <https://wonder.cdc.gov/ucd-icd10.html> and <https://wonder.cdc.gov/ucd-icd10-expanded.html>):
  * Group by Year, then Sex.
  * Measures: Deaths, Population, Crude rate, Age-adjusted rate.
  * Standard population: 2000 U.S. standard; rates per 100,000 to 1 decimal.
  * Every other filter (location, age, race, Hispanic origin, place of death, autopsy, urbanization) set to *All*.
  * Cause: ICD-10 codes I00–I99 for all CVD, or 113 Cause List GR113-054 for heart disease.
  * You must accept the WONDER data use restrictions.
* **Retrieval:** the published analysis used data retrieved on 2026-10-22.
* **Bulk download:** WONDER has no bulk-download API. `Rscript R/01b_mortality.R --fetch` sends the 4 queries above through the WONDER XML API (POST `https://wonder.cdc.gov/controller/datarequest/D76` and `.../D158`, with 15 s between requests). It then reports any difference from the shipped table; on 2026-10-24 it reproduced the table exactly. Without `--fetch`, the step only validates and copies the shipped table.
* **Suggested citation (from WONDER):** Centers for Disease Control and Prevention, National Center for Health Statistics. National Vital Statistics System, Mortality 1999–2020 (released 2021) and Mortality 2018–2024 (released 2026) on CDC WONDER Online Database. Data are from the Multiple Cause of Death Files, as compiled from data provided by the 57 vital statistics jurisdictions through the Vital Statistics Cooperative Program.
* **Mortality trend tests** (`R/06b_figure1_mortality.R`), run separately for each cause over 2013–2024:
  * 2013 vs 2024 rate and percent change.
  * OLS of the rate on (year − 2013) with Newey–West SEs (lags 1 and 2, the same `nw_trend()` helper as the funding trends).
  * Log-linear OLS giving the annual percent change (one segment, so APC = AAPC).
  * Sensitivity analyses excluding the COVID-19 years 2020–2022, and for 2013–2019 alone.

  These are descriptive, ecological comparisons. Funding is by fiscal year and mortality by calendar year.

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
| `Figure1.png/.pdf` | NIH cardiovascular funding with women's CV research funding (Figure 1 without the mortality overlay) |
| `Figure2.png/.pdf` | topic shares of CV / women's CV funding, 4 x 3 small multiples (Figure 2) |
| `Figure1_mortality.png/.pdf` | Figure 1 as published: CV funding bars with women's CV mortality (right axis; solid = all CVD, dashed = heart disease) |
| `mortality_trends.csv`, `key_numbers_mortality.csv` | mortality trend tests (all windows, NW lags 1 and 2) and the reported mortality numbers |
| `stats_results.xlsx` | OLS/Newey–West, segmented, grant-level logistic, CV × year interaction, z tests |
| `topic_trends_cv.xlsx` | topic dictionary, yearly topic tables, decomposition, 3M exclusion and all-seven-award exclusion (numerator and denominator), key awards, trends |
| `key_numbers_stats.csv`, `key_numbers_topics.csv` | the reported numbers (input to 07_verify.R) |
| `verification_report.csv` | every reported number: expected value, reproduced value, difference, PASS/FAIL |

## Verification

`tests/expected_values.csv` lists each checked number from the v10 analysis (RePORTER freeze 2026-10-31) with its full-precision value and an absolute tolerance (half a unit of the precision reported; counts and years exact). The committed `data/shipped/` tables are the v11 cache: `Rscript R/run_all.R` on a fresh clone reproduces every value in `tests/expected_values.csv`, and `WHR_V11_RULES=none` reproduces the v10 values.

On the previous pipeline, this R port reproduced 126 of 131 checked values within tolerance (all 52 mortality values exactly). The other 5 agreed at the precision printed then (6,376 vs 6,378 women's-CV project-years), because of a regex word-boundary difference between ICU and Python affecting 2 project-years. The v10 expected count is 6,338 women's-CV project-years.

Known, documented differences from the original (Python) implementation:
* Regular expressions run on the ICU engine (stringi) instead of Python's `re`. Patterns are
  byte-identical and Python's "." and `\s` semantics are reproduced explicitly (`R/utils.R`).
  ICU and Python differ in rare Unicode word-boundary cases (combining marks), which changed
  feature counts for a handful of projects per year; no reported value is affected beyond its tolerance.
* Two project texts (FY2021, FY2022) differ in one character because of spreadsheet-reader
  differences; no reported value is affected.
* Standard errors: Newey–West (Bartlett kernel, no small-sample adjustment, normal-theory CIs); logistic models use cluster-robust (HC1) SEs by core project;
  matching the statsmodels defaults used originally.
* The FY2026 numbers depend on the date of the API download (see Data).

## Package versions

R 4.5.0; data.table, stringi, readxl, jsonlite, curl, sandwich, ggplot2, openxlsx, ragg,
systemfonts (versions in `DESCRIPTION`). All are on CRAN. To pin them for long-term
reproducibility, run `renv::init()` once in a fresh clone and commit the generated `renv.lock`.

## License

Code: MIT (see `LICENSE`). NIH RePORTER data are public; NASEM committee files are subject to
the National Academies' terms.

## Known differences

ICU (used by stringi) treats `\b` differently from Python's `re` when Unicode format characters such as soft hyphens appear next to words. On the previous pipeline this changed term counts for 2 project-years (6,376 vs 6,378 women's-CV project-years). `tests/expected_values.csv` now stores the v10 R results, including 6,338 women's-CV project-years.
