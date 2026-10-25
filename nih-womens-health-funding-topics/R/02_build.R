#' 02_build.R -- row tables and per-project tables for every fiscal year (S2-S4).
#'
#' PURPOSE
#'   For each fiscal year: load the raw rows (S2; cached as work_dir/rows/rows_{FY}.rds) and
#'   collapse them to one record per FULL_PROJECT_NUM with dollars and pooled lower-cased text
#'   (per-project counting, S3.2; text preparation, S4). For FY2020 and FY2024 a second project
#'   table is built from the intramural rows with RePORTER API v2 abstracts (S2.4).
#'
#' INPUTS   raw files (config.R); work_dir/2026/{prj,abs}.csv from 01_download.R
#' OUTPUTS  work_dir/rows/rows_{FY}.rds       row-level table (analysis columns only, character)
#'          work_dir/proj/proj_{FY}.rds       project table: FULL_PROJECT_NUM, CORE_PROJECT_NUM,
#'                                            PROJECT_TITLE, title_l, text, USD, IC, ACT
#'                                            (IC / ACT = first non-missing administering IC /
#'                                            activity code among the project's rows)
#'          work_dir/proj/projz_{FY}.rds      FY2020/2024 intramural projects with API text
#'          work_dir/proj/zfix_rows_{FY}.rds  the intramural rows used for projz (no-text check)
#'
#' RATIONALE
#'   * Counting per project rather than per row (S3.2): multi-component awards appear as one
#'     parent row plus many component rows whose costs are already inside the parent
#'     TOTAL_COST; summing rows would double count them.
#'   * The NIH filter (S3.1) is NOT applied here; later steps apply the variant they need.
#'   * Runtime: the committee workbooks take ~10-40 s each to read; set WHR_WORKERS to
#'     process several years in parallel (each needs ~2-3 GB of memory).

source("R/00_setup.R")
api <- load_api_z()

build_year <- function(fy) {
  d <- load_rows(fy)
  P <- project_table(copy(d))
  saveRDS(P, work_path("proj", sprintf("proj_%d.rds", fy)))
  msg <- sprintf("%d: %s rows, %s projects, $%.2fB", fy, format(nrow(d), big.mark = ","),
                 format(nrow(P), big.mark = ","), sum(P$USD) / 1e9)
  if (fy %in% CONFIG$zfix_years) {
    z <- zfix_rows(fy, d, api)
    saveRDS(z, work_path("proj", sprintf("zfix_rows_%d.rds", fy)))
    saveRDS(project_table(copy(z)), work_path("proj", sprintf("projz_%d.rds", fy)))
    msg <- paste0(msg, sprintf("; intramural rows %d, still without abstract %d", nrow(z), sum(is.na(z$ABSTRACT_TEXT))))
  }
  rm(d, P); gc(verbose = FALSE)
  msg
}

# Committee workbooks are the slowest to read, so they are scheduled first.
for (m in pmap_years(CONFIG$years, build_year)) say(m)
