# Temporal Trends in National Institutes of Health Funding for Women's Health Research, Fiscal Years 2013–2026: reproduction code (R)

Annotated R code that reproduces every number and both figures of the accompanying brief report

> Bairey Merz CN, Sun N, Geller A, Wei J, Cheng S. Temporal Trends in National Institutes of Health Funding for Women's Health Research, Fiscal Years 2013–2026. [Journal] [forthcoming].

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
| `Strict + sex differences`, `base` | narrower WHR definition (female-specific plus substantive sex-differences research), used as a bound |
| `NASEM-comparable`, `tnc` | broader WHR definition closest to the NASEM committee's labels, used as a bound |

Earlier rule sets (`v1`, `v2`) are nested inside `v3` and are kept only because `v3` is built from them.
`Figure2_v3` is the output name of the current three-panel Figure 2 (predominant/profound layout); the suffix refers to the figure layout version, not to a journal.


## What the pipeline does

| step | script | what it does | methods ref. |
|---|---|---|---|
| 0 | `R/00_setup.R` | checks packages, loads `config.R`, keyword dictionaries (`R/terms.R`) and helpers (`R/utils.R`) | – |
| 1 | `R/01_download.R` | optional RePORTER API v2 download (FY2026, intramural abstracts); builds FY2026 CSVs from the saved JSON | S2 |
| 2 | `R/02_build.R` | reads raw rows; one record per project per fiscal year with dollars and pooled text | S2–S4 |
| 3 | `R/03_classify.R` | rule-based women's health research (WHR) definitions (see *Terminology*); project-level analysis universe; yearly shares with intramural imputation | S5 |
| 4 | `R/04_analysis.R` | trend statistics: OLS with Newey–West SEs, joinpoint-style segmented regression | S11 |
| 5 | `R/05_topics.R` | multi-label topic tagging (`R/topics_whr.R`), decomposition FY2013–15 vs FY2023–25, large-award exclusions, topic trends; predominant vs profound categories (NASEM 2024 Table 7-1), with CVD split from diabetes/obesity | – |
| 6 | `R/06_figures.R` | Figure 1 and Figure 2 (ggplot2) | S10 |
| 7 | `R/07_verify.R` | compares every reported number with `tests/expected_values.csv` and prints PASS/FAIL | – |

`R/run_all.R` runs steps 1–7 in order. All classification is rule-based (regular expressions on
the project title, abstract and public health relevance text); no language model is used.

## Detailed methods

These expand the paper's Methods and brief eMethods.

**Grant records.** The analytic file combines 3 public-source extracts: NASEM committee grant workbooks built from NIH ExPORTER for FY2013–FY2023, ExPORTER Projects and Abstracts files for FY2024–FY2025, and RePORTER API (version 2) responses for FY2026, downloaded October 20, 2026. The API also supplied intramural abstracts missing from the FY2020 and FY2024 bulk files. Only projects administered by an NIH Institute or Center are included. To avoid double counting multicomponent awards, whose component costs are already included in the parent total, every full project number contributes a single record per fiscal year, using the parent's total cost or, when no parent exists, the sum of its subprojects. Amounts are nominal US dollars. FY2026 was incomplete at retrieval and contains no intramural projects.

**Identifying women's health research (WHR).** WHR is identified by regular expressions run on each project's title, abstract and public health narrative, organized as nested definitions in which each broader definition adds rules to the narrower one. The main definition counts a grant when women's health is a primary or substantial focus and captures female-specific and reproductive conditions, maternal health, female and multisite cancers, conditions more common in women, HIV and sexually transmitted infections among women, female-population terms, and sex-differences research, excluding generic sex-as-a-biological-variable boilerplate. A narrower definition (female-specific plus sex-differences research) and a NASEM-comparable definition bound the estimate. Thresholds were fit to NASEM committee labels for FY2013–2017 and evaluated against FY2018–2023 labels using dollar-weighted precision and recall. The committee derived those labels with GPT-4o (OpenAI); no language model is part of this pipeline, and committee labels serve only for calibration and evaluation.

**Topics and condition categories.** A dictionary of 34 subtopics in 6 NASEM-style topic groups (plus a residual general category) is matched against the text of WHR grants (71,784 project-years with text). Each subtopic requires a dictionary term in the title or at least 2 mentions in the text (1 for some specific conditions); a grant matching several subtopics has its dollars divided equally among them. Following the NASEM condition matrix, subtopics are then grouped by whether a condition affects women:

* **predominantly** (exclusively or mostly women): female-specific conditions, maternal health, female cancers, and female-predominant conditions (autoimmune disease, thyroid disease, migraine/chronic pain/fibromyalgia, urinary incontinence/UTI);
* **profoundly** (a large share of morbidity or mortality burden in women): cardiovascular disease (CVD), Alzheimer disease and dementia, depression and anxiety, osteoporosis, and diabetes/obesity (CVD is reported separately from diabetes/obesity);
* the remainder are **cross-cutting** (sex-differences biology, health equity, substance use, HIV and sexually transmitted infections, violence, women's cohorts) or unclassified.

Two placements differ from NASEM's own grouping: autoimmune disease is placed under *predominant* and osteoporosis under *profound*.

**Statistical analysis.** Annual WHR and topic shares are trended by ordinary least squares with Newey–West standard errors (Bartlett kernel, 1 lag, 2 as a check; no prewhitening or small-sample correction; normal-theory 95% CIs). Pooled FY2013–2015 and FY2023–2025 shares are compared, and joinpoint-style segmented regression of the log WHR share gives annual and average annual percent changes. Sensitivity analyses drop FY2026 and key large awards (ECHO cohorts and the NHLBI 3M/IMPROVE coordinating award).

**Software and code.** The analysis was written in Python 3.13 (pandas, statsmodels) and ported to R 4.5.0 (data.table, stringi, sandwich, ggplot2) in this repository, which draws both figures. `R/07_verify.R` confirms that the R port reproduces every checked value within tolerance. The NASEM committee workbooks are not redistributed.

**Blinded manual validation.** Two reviewers, blinded to any pre-assigned labels, each reviewed 100 grants and verified the accuracy of the automated labeling (WHR status and topic assignments: topic group, subtopic, and predominant or profound category).

**Figures.** Figure 1: grey bars for all NIH funding with overlaid red WHR bars, red percentage labels (WHR share of NIH funding) drawn as plain text with no background box, FY2026 hatched. Figure 2: three panels stacked vertically (A, predominant / profound / cross-cutting / unclassified as % of all NIH funding; B, predominant families as % of WHR; C, profound conditions as % of WHR, CVD in red), FY2026 shaded. Text is set large (13-pt base, 11–12-pt labels) for legibility at page width.

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
| `Figure1.png/.pdf` | total NIH funding with women's health research funding (Figure 1) |
| `Figure2_v3.png/.pdf` | A: predominant / profound / cross-cutting categories (% of NIH); B: predominant families (% of WHR); C: profound conditions, CVD in red (% of WHR); panels stacked (Figure 2) |
| `whr_categories_predominant_profound.xlsx` | category scheme, pooled shares and Newey-West trends |
| `stats_results.xlsx` | OLS/Newey–West trends and segmented regression |
| `whr_topic_trends.xlsx` | taxonomy, totals, decompositions (all / excl. 3M / excl. key awards), trends |
| `key_numbers_stats.csv`, `key_numbers_topics.csv` | the reported numbers (input to 07_verify.R) |
| `verification_report.csv` | every reported number: expected value, reproduced value, difference, PASS/FAIL |

## Verification

The shipped-data route (`Rscript R/run_all.R` on a fresh clone, no raw files) was tested end to end and produced outputs byte-identical to the raw-data route (all key-number CSVs, the verification report and the PNG figures).

`tests/expected_values.csv` lists each number quoted in the paper with its full-precision value
from the original analysis and an absolute tolerance (half a unit of the precision reported;
counts and years exact). On the original data this R port reproduced **all 75 checked values within tolerance**.

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
