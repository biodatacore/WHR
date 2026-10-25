# Replication data

These files let anyone reproduce every number, table and figure of the accompanying report from this repository alone:

```sh
git clone https://github.com/biodatacore/WHR
cd <this repository folder>
Rscript R/run_all.R        # uses data/shipped/ automatically when data/raw/ does not exist
```

`R/02_load_shipped.R` checks every file against `data/shipped/MD5SUMS`, converts the files into the intermediate files the pipeline expects (in `data/work/`, or `WHR_WORK_DIR`), and the remaining steps (classification tiers, statistics, topics, figures and `07_verify.R`) then run unchanged.

## Source and terms

* All grant records are public NIH RePORTER / ExPORTER data (titles, abstracts, public health narratives, project numbers, administering Institute/Center, activity code, total cost). NIH RePORTER data are in the public domain; please cite NIH RePORTER (https://reporter.nih.gov) and follow its terms of use (https://reporter.nih.gov/faqs).
* **No investigator, contact or organization fields are included**: no PI names or IDs, emails, phone numbers, organization names/addresses, program officers or study sections. Abstract text is reproduced as published by NIH and may occasionally mention a person's name within the text itself.
* No committee working files, committee relevance labels or other committee-derived annotations are included. The classification thresholds in `R/terms.R` were fixed in advance (calibrated offline); no step of the pipeline needs, or reads, external labels.
* FY2026 was retrieved from the RePORTER API v2 on 2026-10-20 and is **incomplete**; FY2020 and FY2024 intramural abstracts were filled from the API on the same date. RePORTER revises records daily, so a fresh download will differ slightly from these files.

## Size

Per-fiscal-year gzip-compressed CSV (UTF-8, RFC 4180 quoting, missing values written as `NA`). Every file is well under GitHub's 50 MB recommendation; Git LFS is not needed. Read with base R `read.csv(gzfile(f), na.strings = "NA")` (as `02_load_shipped.R` does) or any CSV reader that handles fields beginning with a doubled quote.

## Files
### `shipped/features/whr_features_{FY}.csv.gz` (FY2013-2026, one row per NIH project-year)

The analytic file: every NIH-administered project-year with its funding and the keyword feature counts from which `R/03_classify.R` assigns the women's health research (WHR) tiers.

| column | content |
|---|---|
| `FY` | fiscal year |
| `FULL_PROJECT_NUM` | full NIH project number (e.g. 5R01HL123456-04) |
| `USD` | project-year dollars: parent award total cost, or summed component costs if no parent record |
| `cls`, `conf` | keyword classification (`WHR`/`Non-WHR`) and confidence (`High`/`Low`), S5.1 |
| `title` | project title |
| `ACT`, `IC` | activity code, administering Institute/Center |
| `<feature>` | number of regex matches of the feature in the lower-cased title + abstract + narrative (all records of the project); features are defined in `R/terms.R`: `mat`, `matout`, `child`, `bg`, `cancer`, `hiv`, `women`, `femprev`, `repro`, `male` (S5.4), `c_*` conditions more common in women (S5.5), `n_*` tier-v3 additions (S5.6), `a3`, `sexd` (S5.6 comparison tier) |
| `t_<feature>` | TRUE if the feature appears in the title |
| `sexdiff`, `sexd_good` | substantive sex-differences research flag and number of non-boilerplate sex-difference sentences (S5.3) |
| `zfixed` | TRUE for FY2020/2024 intramural projects whose text came from the API (S2.4) |

### `shipped/text/whr_text_{FY}.csv.gz` (one row per WHR project-year)

Title and pooled text for every project-year in the main WHR tier (71,784 project-years), the universe of the topic and category analyses (`R/05_topics.R`). Text for non-WHR projects is not needed for any reported result and is not shipped (see *Rebuilding from the raw NIH files*).

| column | content |
|---|---|
| `FULL_PROJECT_NUM`, `CORE_PROJECT_NUM`, `IC`, `ACT` | identifiers as above |
| `PROJECT_TITLE` | title as published |
| `text` | lower-cased title + abstract + public health narrative of all records of the project, as used by the classifiers |
| `source` | `file` = bulk RePORTER/ExPORTER record; `api_intramural` = FY2020/2024 intramural replacement text from API v2 (S2.4) |

### `shipped/universe/intramural_no_text.csv`

FY2020 and FY2024 intramural projects for which neither the bulk files nor the API had an abstract (47 project-years); their dollars are allocated at the intramural tier rate (S5.7). Columns `FY`, `FULL_PROJECT_NUM`.

### `shipped/universe/nih_project_universe.csv.gz`

All project-years with at least one NIH record (869,421), the universe of the grant-level statistics in `R/04_analysis.R`. Columns `FY`, `FULL_PROJECT_NUM`.

### `validation/validation_sample_total.csv`

De-identified results of the blinded manual validation (200 stratified random grants; seeds documented in the methods). One row per grant: `Review ID`, `Project number`, `Fiscal year`, `Sampling stratum`, the pipeline labels (`Pipeline ...`, 1/0) and the reviewers' adjudications (`Staff ...`, 1/0; reference standard). No reviewer names or initials, and no free-text comments, are included. The sample was enriched by stratum, so unweighted positive predictive values do not equal population values; weight each stratum by its share of eligible grant-years to estimate population values. Not read by the pipeline.

## Rebuilding from the raw NIH files (optional)

The shipped files are derived from the raw records with `R/01_download.R` and `R/02_build.R` plus the feature step of `R/03_classify.R`. To re-derive them yourself, obtain the raw files as described in the main README (*Data*), run in a new work directory, and compare:

```sh
WHR_WORK_DIR=/path/to/rebuild Rscript R/run_all.R --raw
WHR_WORK_DIR=/path/to/rebuild Rscript R/compare_to_shipped.R   # per-FY record counts, dollars and feature disagreements
```

FY2013-2023 records in the original analysis came from a grant workbook compiled from ExPORTER that is not public; the same fiscal years are available from ExPORTER (<https://reporter.nih.gov/exporter>), but current ExPORTER records have been revised since, so a rebuild from them will match closely but not exactly. FY2026 re-downloaded from the API will differ because the year was incomplete on 2026-10-20.

## Checksums

`shipped/MD5SUMS` lists the MD5 of every shipped file (`md5sum -c MD5SUMS` from `data/shipped/`); `R/02_load_shipped.R` checks them before loading.
