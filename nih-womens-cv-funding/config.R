#' config.R -- every path, year range, seed and constant used by the pipeline.
#'
#' Edit the three directories below, or set the environment variables WHR_RAW_DIR,
#' WHR_WORK_DIR and WHR_OUT_DIR before running (environment variables win). Relative paths
#' are relative to the repository root. data/ and outputs/ are git-ignored.
#'
#' Expected layout of the raw-data directory (see README.md, "Data"):
#'   {FY}/AllData_{FY}.xlsx     FY2013-2023  NASEM committee workbooks, sheet "All Data"
#'   {FY}/prj.csv, {FY}/abs.csv FY2024-2025  NIH RePORTER ExPORTER "Projects" + "Abstracts" CSVs
#'   2026/raw/*.json            FY2026       RePORTER API v2 responses (R/01_download.R --fetch)
#'   2026/counts.json           FY2026       per-agency record counts (API meta.total)
#'   zfix/api_z.json            FY2020/2024  intramural titles/abstracts/PHR from API v2

CONFIG <- list(
  # ---- directories -----------------------------------------------------------------------
  raw_dir  = Sys.getenv("WHR_RAW_DIR",  "data/raw"),    # raw inputs (never modified)
  work_dir = Sys.getenv("WHR_WORK_DIR", "data/work"),   # intermediate .rds files (~6 GB)
  out_dir  = Sys.getenv("WHR_OUT_DIR",  "outputs"),     # tables, figures, verification report

  # ---- fiscal years (S1). FY2026 was retrieved on 2026-10-20 and is INCOMPLETE ------------
  years           = 2013:2026,
  committee_years = 2013:2023,   # years with committee workbooks (and committee labels)
  exporter_years  = 2024:2025,   # ExPORTER CSV years
  api_year        = 2026,        # fetched from RePORTER API v2
  incomplete_year = 2026,
  zfix_years      = c(2020, 2024),  # years whose intramural abstracts were missing (S2.4)

  # ---- RePORTER API v2 (S2.3, S2.4) ---------------------------------------------------------
  api_url     = "https://api.reporter.nih.gov/v2/projects/search",
  api_page    = 500,     # records per request (API maximum)
  api_sleep_s = 1.0,     # politeness delay between requests
  # every agency code the API accepts; non-NIH ones are dropped later by the IC filter (S3.1)
  api_agencies = strsplit(paste(
    "NCI NIAID NIGMS NHLBI NIA NINDS NIDDK NICHD NIMH NIDA NEI VA NIAMS NIEHS NIAAA",
    "NIDCD NIBIB NIDCR NIMHD OD NHGRI NCATS FDA FIC NCCIH NINR AHRQ NLM NIOSH CDC CC",
    "NCCDPHP NCIPC NCEZID NCIRD NCHHSTP NCBDDD ATSDR CGH ACF HRSA SAMHSA CIT NCRR NCHS"), " ")[[1]],

  # ---- analysis constants ----------------------------------------------------------------------
  seed            = 2026,   # set before any random step (none of the published estimates is random)
  pooled_early    = 2013:2015,   # pooled comparison periods for the topic decomposition
  pooled_late     = 2023:2025,
  trend_years     = c(2013, 2025),   # main topic-trend window (FY2026 incomplete)

  # ---- figures ---------------------------------------------------------------------------------
  font = "Arial",           # falls back to the default sans font if Arial is not installed
  red  = "#c0392b",         # the only accent colour; everything else black / grey

  # ---- performance -----------------------------------------------------------------------------
  workers    = as.integer(Sys.getenv("WHR_WORKERS", "2")),   # parallel fiscal years (~2-3 GB each)
  dt_threads = 2L,
  rebuild    = Sys.getenv("WHR_REBUILD", "0") == "1"   # recompute cached per-year feature files
)
