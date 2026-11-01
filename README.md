# NIH women's health research funding, FY2013–2026

This repository holds the annotated R code (pipeline v10) and de-identified replication data for two companion brief reports on NIH women's health research funding. The v10 estimates use the RePORTER data freeze of 2026-10-31. What changed is in [`CHANGE_LOG.md`](CHANGE_LOG.md).

| Folder | Report |
|---|---|
| [`nih-womens-cv-funding/`](nih-womens-cv-funding/) | Women's cardiovascular research funding at NIH |
| [`nih-womens-health-funding-topics/`](nih-womens-health-funding-topics/) | NIH women's health research funding across major areas of need |

Each folder is self-contained. The files in `data/shipped/` are the pre-v10 feature cache (FY2026 retrieved 2026-10-20). The default v10 rules need a rebuild from raw project text; `WHR_V10_RULES=none` runs the previous rules on the shipped cache. See each folder's README and `data/README.md`. Data are from NIH RePORTER (public domain); FY2026 is incomplete.
