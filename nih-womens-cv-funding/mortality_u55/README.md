# Women aged <55: CVD and heart-disease mortality (CDC WONDER), Figure 1B

Queried 2026-11-01 from CDC WONDER Underlying Cause of Death, final data, through the WONDER XML API (`accept_datause_restrictions=true`). Only national aggregate rates and counts are stored here; there are no individual records.

* Databases: D76 (1999-2020, bridged race) for 2013-2017; D158 (2018-2024, single race) for 2018-2024.
* Same request as `R/01b_mortality.R`, with Ten-Year Age Groups (V5) restricted to <1, 1-4, 5-14, 15-24, 25-34, 35-44 and 45-54 years. Female rows only.
* Causes: all CVD = ICD-10 I00-I99; diseases of the heart = GR113-054 (I00-I09, I11, I13, I20-I51).
* `raw/*_aar55_*`: grouped by year and sex; deaths, population, crude rate and WONDER's age-adjusted rate (2000 US standard).
* `raw/*_byage55_*`: grouped by year, sex and ten-year group (for transparency and the standardization check).

| File | Content |
|---|---|
| `wonder_fetch.py`, `run_all.py` | build and send the WONDER requests; write `raw/*_request.xml` and `raw/*_response.xml` (a fresh query needs network access; WONDER asks for ~15 s between requests) |
| `compute.py` | parse the responses into `women_u55_mortality_2013_2024.csv` (WONDER age-adjusted rates, used in Figure 1B) and `women_u55_counts_by_age_2013_2024.csv`; independent direct standardization of the by-age counts reproduces WONDER's rates within 0.1 per 100,000 (20 of 24 exact) |
| `trend55.R` | trends (OLS on year, Newey-West lag 1, normal CI; `R/utils.R::nw_trend`) for 2013-2024, 2013-2019 and excluding 2020-2022: `F=mortality_u55/women_u55_mortality_2013_2024.csv Rscript mortality_u55/trend55.R` |
| `women_u55_trends_NW_lag1.txt` | output of `trend55.R` |
| `check_u55.R` | offline check against `tests/expected_values_u55.csv` (32 values): `Rscript mortality_u55/check_u55.R` |

`inst/extdata/cdc_wonder_women_u55_mortality_2013_2024.csv` is a copy of `women_u55_mortality_2013_2024.csv`; `R/06b_figure1_mortality.R` reads it for panel B by default (`WHR_U55_CSV` overrides the path, `WHR_U55_CSV=none` draws panel A only).

## Results (age-adjusted deaths per 100,000 women aged <55)

| | 2013 | 2019 | 2021 (peak) | 2024 | Trend 2013-2024, per year (95% CI) | Excluding 2020-2022 |
|---|---|---|---|---|---|---|
| All CVD (I00-I99) | 17.1 | 16.9 | 19.2 | 16.7 | +0.041 (-0.097 to 0.179), P = .56 | -0.053 (-0.088 to -0.017), P = .003 |
| Heart disease | 12.6 | 12.3 | 13.9 | 12.0 | -0.007 (-0.107 to 0.093), P = .89 | -0.074 (-0.104 to -0.044), P < .001 |

Neither series declined significantly over 2013-2024; both fall significantly when 2020-2022 are excluded.
