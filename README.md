# NIH women's health research funding, FY2013–2026

This repository holds the annotated R code (pipeline v11c) and de-identified replication data for two companion brief reports on NIH women's health research funding. The estimates use the RePORTER data freeze of 2026-10-31. What changed is in [`CHANGE_LOG.md`](CHANGE_LOG.md).

| Folder | Report |
|---|---|
| [`nih-womens-cv-funding/`](nih-womens-cv-funding/) | Women's cardiovascular research funding at NIH |
| [`nih-womens-health-funding-topics/`](nih-womens-health-funding-topics/) | NIH women's health research funding across major areas of need |
| [`validation_v12/`](validation_v12/) | Out-of-sample manual validation of the v11c rules (both reports) |

Each report folder is self-contained. `data/shipped/` is the v11c cache (FY2026 freeze 2026-10-31). Open a folder and run `Rscript R/run_all.R`; it rebuilds every reported number and figure from `data/shipped/` alone and checks them against `tests/expected_values.csv` (total WHR 84/84, women's CV 265/265). See each folder's README and `data/README.md`. Data are from NIH RePORTER (public domain) and CDC WONDER (national aggregates); FY2026 is incomplete.

## Headline values (v11c)

| | FY2013–15 | FY2023–25 |
|---|---|---|
| Women's health research, share of all NIH funding | 9.02% | 8.93% |
| Women's cardiovascular research, share of NIH cardiovascular funding | 7.80% | 12.92% |

FY2013–2026: 74,124 women's health research project-years; 7,712 women's cardiovascular project-years.

Age-adjusted mortality among women younger than 55 years (CDC WONDER, 2013–2024) did not decline significantly: all CVD 17.1 to 16.7 and heart disease 12.6 to 12.0 per 100,000, both peaking in 2021 (trends +0.041 [95% CI −0.097 to 0.179] and −0.007 [−0.107 to 0.093] per year).

Validation (masked review of 2 new stratified samples of 200 project-years each; unweighted / weighted to the portfolio): women's cardiovascular research sensitivity 97.6% / 69.3%, specificity 84.5% / 99.9%, κ 0.80 / 0.75; overall WHR sensitivity 94.5% / 60.8%, specificity 87.2% / 98.7%, κ 0.81 / 0.68.
