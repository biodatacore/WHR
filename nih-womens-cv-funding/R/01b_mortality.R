#' 01b_mortality.R -- women's age-adjusted cardiovascular mortality, 2013-2024 (CDC WONDER).
#'
#' PURPOSE  Provides the mortality series overlaid on Figure 1 (second y-axis) and tested in
#'          06b_figure1_mortality.R. The aggregated public table is shipped with the repository
#'          (inst/extdata/cdc_wonder_cvd_mortality_women_2013_2024.csv: national totals only, one
#'          row per year and cause, no individual records). By default this step only checks that
#'          file and copies it to work_dir. With --fetch it re-queries CDC WONDER instead.
#'
#' SOURCE   CDC WONDER Underlying Cause of Death (National Center for Health Statistics, National
#'          Vital Statistics System; final data). WONDER has no bulk-download API; its XML API
#'          (https://wonder.cdc.gov/wonder/help/WONDER-API.html) accepts one request per table and
#'          only for national-level data. Two databases are needed because of the race-coding change:
#'            D76  Underlying Cause of Death 1999-2020, bridged race   -> years 2013-2017
#'            D158 Underlying Cause of Death 2018-2024, single race    -> years 2018-2024
#'          (for 2018-2020 the two databases give identical national rates.)
#'
#' EXACT QUERY (same in both databases; equivalent to the web form at
#'          https://wonder.cdc.gov/ucd-icd10.html and https://wonder.cdc.gov/ucd-icd10-expanded.html)
#'   Group results by   Year (V1-level1), Sex (V7)
#'   Measures           Deaths, Population, Crude rate, Age-adjusted rate (M1, M2, M3, M41, M42)
#'   Age adjustment     2000 U.S. standard population (O_aar = aar_std, O_aar_pop = 0000)
#'   Rate per           100,000; precision 1 decimal
#'   Location, age, race, Hispanic origin, place of death, autopsy, urbanization: All
#'   Cause of death     (a) "Diseases of heart": ICD-10 113 Cause List, code GR113-054
#'                          = I00-I09, I11, I13, I20-I51 (O_ucd = V4)
#'                      (b) "All CVD": ICD-10 chapter I00-I99, Diseases of the circulatory
#'                          system (O_ucd = V2)
#'   Years              All (rows outside 2013-2024 and the Male rows are dropped here)
#'   You must accept the WONDER data use restrictions (accept_datause_restrictions = true).
#'   Published analysis: retrieved 2026-10-22 (D158 vintage released 2026).
#'
#' USAGE    Rscript R/01b_mortality.R            # use the shipped CSV (default, offline)
#'          Rscript R/01b_mortality.R --fetch    # re-query CDC WONDER (4 requests, ~1 min)
#' OUTPUTS  work_dir/mortality/cvd_mortality_women.csv

source("R/00_setup.R")
SHIPPED <- "inst/extdata/cdc_wonder_cvd_mortality_women_2013_2024.csv"
dir.create(work_path("mortality"), recursive = TRUE, showWarnings = FALSE)
OUT <- work_path("mortality", "cvd_mortality_women.csv")

#' Build the XML request for one WONDER database (db = "D76" or "D158") and one cause.
#' The parameter names are those of the WONDER request form; unspecified filters are "*All*".
wonder_xml <- function(db, ucd, code) {
  V <- function(v) paste0(db, ".", v)
  p <- list(B_1 = V("V1-level1"), B_2 = V("V7"), B_3 = "*None*", B_4 = "*None*", B_5 = "*None*",
            M_1 = V("M1"), M_2 = V("M2"), M_3 = V("M3"), M_41 = V("M41"), M_42 = V("M42"),
            O_aar = "aar_std", O_aar_pop = "0000", O_age = V("V5"), O_javascript = "on",
            O_location = V("V9"), O_precision = "1", O_rate_per = "100000", O_show_totals = "false",
            O_timeout = "600", O_title = "", O_ucd = V(ucd), O_urban = V("V19"),
            action.Send = "Send", stage = "request")
  for (v in c("V1", "V10", "V27", "V9")) { p[[paste0("F_", V(v))]] <- "*All*"; p[[paste0("O_", v, "_fmode")]] <- "freg"
    p[[paste0("V_", V(v))]] <- ""
    if (v != "V10") p[[paste0("finder-stage-", V(v))]] <- "codeset" }
  p[[paste0("F_", V("V2"))]] <- if (ucd == "V2") code else "*All*"; p$O_V2_fmode <- "freg"
  p[[paste0("V_", V("V2"))]] <- ""; p[[paste0("finder-stage-", V("V2"))]] <- "codeset"
  p[[paste0("I_", V("V1"))]] <- "*All* (All Dates)"
  for (v in c("V10", "V27", "V9")) p[[paste0("I_", V(v))]] <- "*All* (The United States)"
  p[[paste0("I_", V("V2"))]] <- if (ucd == "V2") code else "*All* (All Causes of Death)"
  for (v in c("V11", "V12", "V17", "V19", "V20", "V21", "V22", "V23", "V24", "V25", "V5", "V51", "V52", "V7"))
    p[[paste0("V_", V(v))]] <- "*All*"
  p[[paste0("V_", V("V4"))]] <- if (ucd == "V4") code else "*All*"; p[[paste0("V_", V("V6"))]] <- "00"
  for (v in c("V10", "V17", "V1_S", "V7")) p[[paste0("VM_", V("M6"), "_", V(v))]] <- "*All*"
  p[[paste0("VM_", V("M6"), "_", V("V10"))]] <- ""
  if (db == "D76") { p[[paste0("V_", V("V8"))]] <- "*All*"; p[[paste0("VM_", V("M6"), "_", V("V8"))]] <- "*All*" }
  if (db == "D158") {
    for (v in c("V42", "V43", "V44", "V45", "V18")) p[[paste0("V_", V(v))]] <- "*All*"
    for (v in c("V25", "V30", "V31")) { p[[paste0("F_", V(v))]] <- "*All*"; p[[paste0("O_", v, "_fmode")]] <- "freg"; p[[paste0("V_", V(v))]] <- "" }
    p$O_race <- V("V42"); p[[paste0("VM_", V("M6"), "_", V("V42"))]] <- "*All*"
  }
  names(p) <- sub("^action\\.Send$", "action-Send", names(p))
  paste0("<request-parameters>", paste0("<parameter><name>", names(p), "</name><value>", unlist(p), "</value></parameter>", collapse = ""), "</request-parameters>")
}

#' Send one request and parse the returned data table (Year, Sex, Deaths, Population, Crude, Age-adjusted).
wonder_fetch <- function(db, ucd, code) {
  # WONDER expects an application/x-www-form-urlencoded POST (not multipart)
  body <- paste0("request_xml=", curl::curl_escape(wonder_xml(db, ucd, code)), "&accept_datause_restrictions=true")
  h <- curl::new_handle(); curl::handle_setopt(h, postfields = body, timeout = 600)
  curl::handle_setheaders(h, "Content-Type" = "application/x-www-form-urlencoded")
  x <- enc2utf8(rawToChar(curl::curl_fetch_memory(paste0("https://wonder.cdc.gov/controller/datarequest/", db), handle = h)$content))
  # Each <r> row holds top-level <c l="label"/> or <c v="value"/> cells (nested <l v="(CI)"/> are
  # confidence intervals and are ignored). The year cell spans the Female and Male rows, so carry it.
  rows <- regmatches(x, gregexpr("<r>.*?</r>", x))[[1]]; yr <- NA_integer_; out <- list()
  for (r in rows) {
    cell <- sub('^<c (l|v)="', "", regmatches(r, gregexpr('<c (l|v)="[^"]*', r))[[1]])
    cell <- trimws(cell)   # the final year carries a trailing space ("2024 ")
    if (grepl("^[0-9]{4}$", cell[1])) { yr <- as.integer(cell[1]); cell <- cell[-1] }
    out[[length(out) + 1]] <- data.table(year = yr, sex = cell[1], deaths = as.integer(gsub(",", "", cell[2])),
                                         age_adjusted_rate_per_100k = as.numeric(cell[5]))
  }
  rbindlist(out)
}

if ("--fetch" %in% commandArgs(trailingOnly = TRUE)) {
  say("querying CDC WONDER (D76 for 2013-2017, D158 for 2018-2024)")
  L <- list()
  for (q in list(c("all_cvd", "V2", "I00-I99", "I00-I99"), c("heart_disease", "V4", "GR113-054", "I00-I09,I11,I13,I20-I51")))
    for (db in c("D76", "D158")) {
      r <- wonder_fetch(db, q[2], q[3]); Sys.sleep(15)   # WONDER asks for >= 15 s between requests
      r <- r[sex == "Female" & year %in% if (db == "D76") 2013:2017 else 2018:2024]
      L[[length(L) + 1]] <- r[, `:=`(cause = q[1], icd10 = q[4], database = db, standard_population = "2000 U.S. standard", status = "final")]
    }
  M <- rbindlist(L)[order(cause, year)]
  setcolorder(M, c("year", "sex", "cause", "icd10", "age_adjusted_rate_per_100k", "deaths", "database", "standard_population", "status"))
  S <- fread(SHIPPED)
  d <- merge(M, S, by = c("year", "cause"))[, max(abs(age_adjusted_rate_per_100k.x - age_adjusted_rate_per_100k.y))]
  say(sprintf("fetched %d rows; max |difference| from shipped CSV = %.1f per 100,000", nrow(M), d))
} else {
  M <- fread(SHIPPED)
}
stopifnot(nrow(M) == 24, all(M$year %in% 2013:2024), setequal(unique(M$cause), c("all_cvd", "heart_disease")))
fwrite(M, OUT)
say("mortality series written to ", OUT)
