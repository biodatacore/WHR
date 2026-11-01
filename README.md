# NIH women's health research funding, FY2013–2026

This repository holds the annotated R code (pipeline v10) and de-identified replication data for two companion brief reports on NIH women's health research funding. The v10 estimates use the RePORTER data freeze of 2026-10-31. What changed is in [`CHANGE_LOG.md`](CHANGE_LOG.md).

| Folder | Report |
|---|---|
| [`nih-womens-cv-funding/`](nih-womens-cv-funding/) | Women's cardiovascular research funding at NIH |
| [`nih-womens-health-funding-topics/`](nih-womens-health-funding-topics/) | NIH women's health research funding across major areas of need |

Each folder is self-contained. `data/shipped/` is the v10 cache (FY2026 freeze 2026-10-31; 869,672 project-years; text for 76,374 women's health research project-years). Open a folder and run `Rscript R/run_all.R`. See each folder's README and `data/README.md`. Data are from NIH RePORTER (public domain); FY2026 is incomplete.
