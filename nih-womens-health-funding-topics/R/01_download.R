#' 01_download.R -- obtain and check the raw data (Supplementary Methods S2).
#'
#' PURPOSE
#'   1. FY2026 (S2.3): query NIH RePORTER API v2 for every agency code, page through all FY2026
#'      records (500 per request, sorted by appl_id) and save the raw JSON per agency.
#'   2. Intramural abstracts (S2.4): the FY2020 and FY2024 bulk files lack abstracts for most
#'      intramural (Z-activity) projects; fetch title/abstract/PHR for those application IDs
#'      from API v2 and save them as zfix/api_z.json.
#'   3. Convert the FY2026 JSON into ExPORTER-shaped prj.csv / abs.csv (work_dir/2026/) so that
#'      every year is read by the same loader (S2.3).
#'   Steps 1-2 run only with --fetch (network); by default the script works offline from the
#'   saved files. FY2013-2023 committee workbooks and FY2024-2025 ExPORTER CSVs are NOT
#'   downloaded here (see README.md, "Data", for where to get them).
#'
#' USAGE    Rscript R/01_download.R            # offline: check raw files, rebuild FY2026 CSVs
#'          Rscript R/01_download.R --fetch    # also download anything missing from the API
#'
#' INPUTS   raw_dir/2026/raw/*.json (offline), raw_dir/zfix/api_z.json
#' OUTPUTS  work_dir/2026/prj.csv, work_dir/2026/abs.csv; with --fetch also
#'          raw_dir/2026/counts.json, raw_dir/2026/raw/{agency}.json, raw_dir/zfix/api_z.json
#'
#' RATIONALE
#'   The API is the only source for the current, incomplete fiscal year. Records are added
#'   and revised daily, so re-fetching gives different FY2026 numbers: the published results
#'   are tied to the JSON saved on 2026-10-20. Exact reproduction needs those saved files.

source("R/00_setup.R")
args <- commandArgs(trailingOnly = TRUE)

#' POST a JSON body to RePORTER API v2 with simple linear back-off retries.
api_post <- function(body, tries = 5) {
  for (t in seq_len(tries)) {
    res <- tryCatch({
      h <- curl::new_handle()
      curl::handle_setopt(h, postfields = jsonlite::toJSON(body, auto_unbox = TRUE), timeout = 120)
      curl::handle_setheaders(h, "Content-Type" = "application/json", "Accept" = "application/json")
      r <- curl::curl_fetch_memory(CONFIG$api_url, handle = h)
      if (r$status_code >= 400) stop("HTTP ", r$status_code)
      jsonlite::fromJSON(rawToChar(r$content), simplifyVector = FALSE)
    }, error = function(e) { message("retry ", t, ": ", conditionMessage(e)); Sys.sleep(5 * t); NULL })
    if (!is.null(res)) return(res)
  }
  stop("API request failed repeatedly")
}

#' S2.3: per-agency record counts, then every page per agency (agencies already saved are skipped).
fetch_fy2026 <- function() {
  dir.create(raw_path(2026, "raw"), recursive = TRUE, showWarnings = FALSE)
  cnt_f <- raw_path(2026, "counts.json")
  if (!file.exists(cnt_f)) {
    cnt <- list()
    for (a in CONFIG$api_agencies) {
      j <- api_post(list(criteria = list(fiscal_years = list(2026), agencies = list(a)), limit = 1))
      cnt[[a]] <- j$meta$total
      Sys.sleep(CONFIG$api_sleep_s)
    }
    jsonlite::write_json(cnt, cnt_f, auto_unbox = TRUE)
  }
  cnt <- jsonlite::fromJSON(cnt_f)
  for (a in names(cnt)) {
    n <- cnt[[a]]; f <- raw_path(2026, "raw", paste0(a, ".json"))
    if (is.null(n) || n == 0 || file.exists(f)) next
    res <- list(); off <- 0
    while (off < n) {
      j <- api_post(list(criteria = list(fiscal_years = list(2026), agencies = list(a)), limit = CONFIG$api_page,
                         offset = off, sort_field = "appl_id", sort_order = "asc"))
      res <- c(res, j$results); off <- off + CONFIG$api_page
      Sys.sleep(CONFIG$api_sleep_s)
    }
    jsonlite::write_json(list(agency = a, meta_total = n, results = res), f, auto_unbox = TRUE, null = "null", digits = NA)
    say(a, ": ", n, " expected, ", length(res), " saved")
  }
}

#' S2.4: application IDs of Z-activity rows in FY2020 and FY2024, 500 IDs per request.
#' Needs the FY2020 workbook and the FY2024 ExPORTER CSVs.
fetch_intramural <- function() {
  f <- raw_path("zfix", "api_z.json")
  if (file.exists(f)) return(invisible())
  out <- list()
  for (y in CONFIG$zfix_years) {
    d <- load_rows(y)
    ids <- sort(unique(as.numeric(d$APPLICATION_ID[is_intramural(d)])))
    res <- list()
    for (i in seq(1, length(ids), by = CONFIG$api_page)) {
      j <- api_post(list(criteria = list(appl_ids = as.list(ids[i:min(i + CONFIG$api_page - 1, length(ids))])),
                         include_fields = list("ApplId", "ProjectTitle", "AbstractText", "PhrText"),
                         offset = 0, limit = CONFIG$api_page))
      res <- c(res, lapply(j$results, function(x) x[c("appl_id", "project_title", "abstract_text", "phr_text")]))
      Sys.sleep(CONFIG$api_sleep_s)
    }
    out[[as.character(y)]] <- res
    say(y, ": ", length(ids), " intramural ids, ", length(res), " returned")
  }
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(out, f, auto_unbox = TRUE, null = "null", digits = NA)
}

#' S2.3: map API v2 JSON fields onto ExPORTER column names (only the columns the analysis
#' uses). Component (sub-project) records carry their award amount in TOTAL_COST_SUB_PROJECT,
#' parents in TOTAL_COST, mirroring ExPORTER so the dollar rule of S3.2 applies unchanged.
#' Abstracts go to a separate abs.csv, written only for non-empty abstracts.
build_fy2026_csv <- function() {
  files <- sort(Sys.glob(raw_path(2026, "raw", "*.json")), method = "radix")   # byte order
  nz <- function(v) if (is.null(v)) NA else v
  rows <- vector("list", length(files)); ab <- vector("list", length(files))
  for (k in seq_along(files)) {
    R <- jsonlite::fromJSON(files[k], simplifyVector = FALSE)$results
    if (!length(R)) next
    g <- function(f) vapply(R, function(r) { v <- f(r); if (is.null(v)) NA_character_ else as.character(v) }, character(1))
    sub <- g(function(r) r$subproject_id)
    is_sub <- !is.na(sub) & sub != ""
    amt <- g(function(r) r$award_amount)
    rows[[k]] <- data.table(
      APPLICATION_ID = g(function(r) r$appl_id), ACTIVITY = g(function(r) r$activity_code),
      ADMINISTERING_IC = g(function(r) r$agency_ic_admin$code),
      CORE_PROJECT_NUM = g(function(r) r$core_project_num), FULL_PROJECT_NUM = g(function(r) r$project_num),
      PHR = g(function(r) r$phr_text), PROJECT_TITLE = g(function(r) r$project_title), SUBPROJECT_ID = sub,
      TOTAL_COST = ifelse(is_sub, NA, amt), TOTAL_COST_SUB_PROJECT = ifelse(is_sub, amt, NA))
    abst <- g(function(r) r$abstract_text)
    keep <- !is.na(abst) & abst != ""
    ab[[k]] <- data.table(APPLICATION_ID = rows[[k]]$APPLICATION_ID[keep], ABSTRACT_TEXT = abst[keep])
    rm(R); gc(verbose = FALSE)
  }
  P <- rbindlist(rows); A <- rbindlist(ab)
  fwrite(P, work_path("2026", "prj.csv")); fwrite(A, work_path("2026", "abs.csv"))
  say("FY2026 rows ", nrow(P), ", abstracts ", nrow(A))
}

#' List every raw input and stop with a clear message if one is missing.
check_raw <- function() {
  need <- c(raw_path(CONFIG$committee_years, sprintf("AllData_%d.xlsx", CONFIG$committee_years)),
            as.vector(outer(CONFIG$exporter_years, c("prj.csv", "abs.csv"), function(y, f) raw_path(y, f))),
            raw_path("zfix", "api_z.json"))
  miss <- need[!file.exists(need)]
  if (!length(Sys.glob(raw_path(2026, "raw", "*.json")))) miss <- c(miss, raw_path(2026, "raw", "*.json"))
  if (length(miss)) stop("Missing raw inputs:\n  ", paste(miss, collapse = "\n  "))
  say("all raw inputs present")
}

if ("--fetch" %in% args) { fetch_fy2026(); fetch_intramural() }
check_raw()
build_fy2026_csv()
