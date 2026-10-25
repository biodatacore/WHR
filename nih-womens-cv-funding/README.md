# Temporal Trends in NIH Funding for Women's Cardiovascular Health Research: reproduction code (R)

Annotated R code that reproduces every number and both figures of the accompanying brief report

> Cheng S, Sun N, Geller A, Wei J, Bairey Merz CN. Temporal Trends in NIH Funding for Women's Cardiovascular Health Research. [Journal] [forthcoming].

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
| `Strict + sex differences`, `base` | narrower WHR definition (female-specific plus substantive sex-differences research), used as a bound |
| `NASEM-comparable`, `tnc` | broader WHR definition closest to the NASEM committee's labels, used as a bound |
| `CV_tier == "broad"`, `broad2`, `cv` | **cardiovascular (CV) research**: a CV term in the title or repeated CV terms in the text, excluding non-CV usages |
| `strict` CV | narrower CV definition (sensitivity only) |
| `wcv` | women's CV research = CV research that also meets the WHR definition |

Earlier rule sets (`v1`, `v2`) are nested inside `v3` and are kept only because `v3` is built from them.


## What the pipeline does

| step | script | what it does | methods ref. |
|---|---|---|---|
| 0 | `R/00_setup.R` | checks packages, loads `config.R`, keyword dictionaries (`R/terms.R`) and helpers (`R/utils.R`) | – |
| 1 | `R/01_download.R` | optional RePORTER API v2 download (FY2026, intramural abstracts); builds FY2026 CSVs from the saved JSON | S2 |
| 1b | `R/01b_mortality.R` | women's age-adjusted CV mortality 2013–2024 (CDC WONDER): uses the shipped public table, or re-queries WONDER with `--fetch` | – |
| 2 | `R/02_build.R` | reads raw rows; one record per project per fiscal year with dollars and pooled text | S2–S4 |
| 3 | `R/03_classify.R` | rule-based women's health research (WHR) definitions (see *Terminology*); cardiovascular (CV) and women's-CV rules; project-level CV × WHR table; yearly shares with intramural imputation | S5, S9 |
| 4 | `R/04_analysis.R` | trend statistics: OLS with Newey–West SEs, joinpoint-style segmented regression, clustered grant-level logistic regression, CV × year interaction, two-proportion z tests with FDR | S11 |
| 5 | `R/05_topics.R` | multi-label topic tagging (`R/topics_cv.R`), decomposition FY2013–15 vs FY2023–25, large-award exclusions, topic trends | – |
| 6 | `R/06_figures.R` | Figure 1 and Figure 2 (ggplot2) | S10 |
| 6b | `R/06b_figure1_mortality.R` | Figure 1 as published: funding bars plus women's CV mortality on a second y-axis (`sec_axis`); mortality trend tests | – |
| 7 | `R/07_verify.R` | compares every reported number with `tests/expected_values.csv` and prints PASS/FAIL | – |

`R/run_all.R` runs steps 1–7 in order (including 1b and 6b). All classification is rule-based (regular expressions on
the project title, abstract and public health relevance text); no language model is used.

## Detailed methods

These are the detailed methods referred to in the paper's Methods section.

**Data sources and project records.** Grant records for FY2013–FY2023 came from the project-level workbooks that the NASEM committee assembled from NIH ExPORTER; FY2024–FY2025 records came from the NIH ExPORTER Projects and Abstracts files, and FY2026 records from the RePORTER API (version 2), retrieved October 20, 2026. Intramural abstracts absent from the FY2020 and FY2024 bulk files were retrieved through the same API. Only projects administered by an NIH Institute or Center were analyzed. Because a multicomponent award appears as a parent record plus component records whose costs are already contained in the parent's total cost, records were collapsed to 1 per full project number per fiscal year, valued at the parent award's total cost or, when no parent record existed, the summed component costs. Dollars are nominal.

**Identifying women's health research (WHR).** WHR rules are nested, so each broader rule set keeps every project of the narrower one and adds projects matched by further terms. The rule set used throughout captures grants in which women's health is a primary or substantial (partial) focus and covers female-specific, maternal, female-predominant, and reproductive conditions; cancers that include female cancers; HIV and sexually transmitted infections in women; female-population terms; and substantive sex-differences research after boilerplate sex-as-a-biological-variable statements are filtered out. Rule thresholds were tuned on the committee's FY2013–2017 grant labels and checked on its FY2018–2023 labels with dollar-weighted precision and recall. The committee generated those labels with GPT-4o (OpenAI); they were used only for tuning and evaluation, and the classifier itself uses regular-expression rules and no language model.

**Identifying cardiovascular (CV) research.** CV relevance is scored on each parent and component record, not on pooled project text, because components of large center awards can describe unrelated science. A record qualifies as CV research when CV is a substantive part of it, shown by a CV term in the title or repeated CV terms in the text; terms that do not denote CV research (eg, tumor angiogenesis, heart rate variability, intracranial or portal hypertension, heat stroke) are excluded. Random-sample review showed about 84% precision. Women's CV research is CV funding that also meets the WHR definition.

**CV topic dictionary.** Women's CV projects are searched against a 20-topic dictionary spanning sex-specific CV risk (eg, hypertensive disorders of pregnancy, menopause and sex hormones, polycystic ovary syndrome, gestational diabetes), conditions that mainly affect women (coronary microvascular dysfunction and INOCA/MINOCA, peripartum cardiomyopathy, SCAD, takotsubo syndrome), and broader themes. A topic is assigned when one of its terms appears in the title or at least twice in the text (once for rare named conditions). Projects can carry several topics, and their dollars are split equally among them, so topic dollars sum to the women's CV total.

**Statistical analysis.** Newey–West standard errors use a Bartlett kernel with 1 lag (2 lags as a check), no prewhitening, and no small-sample adjustment, with normal-theory 95% CIs. Grant-level logistic models use cluster-robust standard errors by core project. Yearly CV vs non-CV comparisons use 2-proportion z tests with Benjamini–Hochberg FDR adjustment. Sensitivity analyses exclude FY2026 and the NHLBI 3M/IMPROVE coordinating award (OT2HL158287). Mortality trends (CDC WONDER, women, age-adjusted to the 2000 US standard) use OLS with Newey–West SEs and log-linear APCs, with a sensitivity analysis omitting 2020–2022.

**Software and code.** Analyses were run in Python 3.13 (pandas, statsmodels) and independently re-implemented in R 4.5.0 (data.table, stringi, sandwich, ggplot2, and other CRAN packages) in this repository, which also generates both figures. `R/07_verify.R` compares each reported value with its reproduction; the R code reproduced 126 of 131 checked values within tolerance, and the remaining 5 agreed at the precision reported. Raw NASEM committee workbooks are not redistributed.

**Blinded manual validation.** Two study reviewers, blinded to any pre-assigned labels, each reviewed 100 grants and verified the accuracy of the automated labeling for WHR status, women's CV research status, and CV topic subtypes.

**Figures.** Figure 1 (`Figure1_mortality`, as in the paper): grey bars for total NIH CV funding with overlaid red bars for women's CV research, red percentage labels (women's share of CV funding) drawn as plain text with no background box, FY2026 hatched, and women's age-adjusted CVD (solid) and heart disease (dashed) mortality on a right-hand axis. Figure 2: topic shares of CV and women's CV funding as small multiples.

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
   responses retrieved on 2026-10-20; FY2026 was incomplete and RePORTER revises records daily,
   so a new download gives somewhat different FY2026 (and slightly different FY2020/2024)
   numbers. Exact reproduction requires the saved 2026-10-20 responses: [DATA AVAILABILITY STATEMENT / ARCHIVE LINK].
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

Rscript R/run_all.R              # all steps + verification (shipped data unless data/raw exists)
Rscript R/run_all.R --raw        # rebuild from raw NIH files (see Raw data)
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
| `topic_trends_cv.xlsx` | topic dictionary, yearly topic tables, decomposition (with/without 3M award), trends |
| `key_numbers_stats.csv`, `key_numbers_topics.csv` | the reported numbers (input to 07_verify.R) |
| `verification_report.csv` | every reported number: expected value, reproduced value, difference, PASS/FAIL |

## Verification

The shipped-data route (`Rscript R/run_all.R` on a fresh clone, no raw files) was tested end to end and produced outputs byte-identical to the raw-data route (all key-number CSVs, the verification report and the PNG figures).

`tests/expected_values.csv` lists each number quoted in the paper with its full-precision value
from the original analysis and an absolute tolerance (half a unit of the precision reported;
counts and years exact). On the original data this R port reproduced **126 of 131 checked values within tolerance (all 52 mortality values exactly); the 5 others still agree at the precision printed in the report (6,376 vs 6,378 project-years, because of a regex word-boundary difference between ICU and Python affecting 2 project-years; see Known differences)**.

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

ICU (used by stringi) treats `\b` differently from Python's `re` when Unicode format characters such as soft hyphens appear next to words. On the original data, this changes term counts for 2 project-years. As a result, the R port finds 6,376 women's-CV project-years instead of 6,378. A few derived values move in the second decimal place: the FY2023 share (10.38% vs 10.39%), the segmented APCs (-6.36/11.03 vs -6.37/11.05), and the lifestyle share of the gain (30.7% vs 30.8%). `tests/expected_values.csv` keeps the published values, so `07_verify.R` reports these 5 as FAIL.
