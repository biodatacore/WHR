#' utils.R -- helper functions shared by the numbered pipeline scripts.
#'
#' Sourced by R/00_setup.R (and therefore by every step). Contains:
#'   * path helpers ............................. raw_path(), work_path(), out_path()
#'   * regular-expression helpers ............... rx(), n_match(), has_match()
#'   * raw-data loaders (S2) .................... load_rows(), load_api_z(), zfix_rows()
#'   * per-project table (S3.2, S4) ............. project_table()
#'   * keyword classification (S5.1) ............ keyword_classify()
#'   * row-level NIH universe and text (S9) ..... nih_rows(), row_text()
#'   * Newey-West OLS trend helper (S11.1) ...... nw_trend()
#'
#' Section numbers (S#.#) refer to the Supplementary Methods of the paper.

suppressPackageStartupMessages({
  library(data.table)
  library(stringi)
})

# ---------------------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------------------

#' Build a path inside the raw-data directory (CONFIG$raw_dir).
#' @param ... path components, e.g. raw_path(2013, "AllData_2013.xlsx")
raw_path <- function(...) file.path(CONFIG$raw_dir, ...)

#' Build a path inside the scratch directory (CONFIG$work_dir), creating parent folders.
work_path <- function(...) {
  p <- file.path(CONFIG$work_dir, ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}

#' Build a path inside the output directory (CONFIG$out_dir), creating parent folders.
out_path <- function(...) {
  p <- file.path(CONFIG$out_dir, ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}

#' Print a time-stamped progress message.
say <- function(...) cat(format(Sys.time(), "[%H:%M:%S] "), ..., "\n", sep = "")

#' Apply a function over items, in parallel on Unix when CONFIG$workers > 1.
#' Results come back in input order. Each worker holds one fiscal year in memory.
pmap_years <- function(items, fn) {
  if (CONFIG$workers > 1 && .Platform$OS.type == "unix") {
    res <- parallel::mclapply(items, fn, mc.cores = CONFIG$workers, mc.preschedule = FALSE)
    err <- vapply(res, inherits, logical(1), what = "try-error")
    if (any(err)) stop(res[[which(err)[1]]])
    res
  } else {
    lapply(items, fn)
  }
}

# ---------------------------------------------------------------------------------------
# Regular expressions
#
# The published analysis used Python's `re` module. Here the ICU engine (stringi) is used,
# which follows the same Perl-style syntax for everything in terms.R (\b, \w, (?:...),
# lookahead/lookbehind, {m,n}). Two details are handled explicitly so that counts agree:
#   1. In Python "." matches any character except "\n"; in ICU it also refuses "\r" and a few
#      Unicode line separators. rx() therefore rewrites every unescaped "." outside a
#      character class as "[^\n]", which is exactly Python's meaning.
#   2. Python's findall()/str.count() count NON-OVERLAPPING matches scanning left to right;
#      stri_count_regex() does the same.
# Text is lower-cased with stri_trans_tolower() (Unicode, like Python's str.lower()).
# ---------------------------------------------------------------------------------------

.rx_cache <- new.env(parent = emptyenv())

#' Translate a Python regular expression to the ICU equivalent (see note above).
#' @param p a single pattern string
#' @return the pattern with "." replaced by "[^\n]" outside character classes
rx <- function(p) {
  hit <- .rx_cache[[p]]
  if (!is.null(hit)) return(hit)
  ch <- strsplit(p, "", fixed = TRUE)[[1]]
  out <- character(length(ch)); i <- 1; in_class <- FALSE
  while (i <= length(ch)) {
    c1 <- ch[i]
    if (c1 == "\\" && i < length(ch)) {            # escaped character: copy both verbatim
      out[i] <- paste0(c1, ch[i + 1]); out[i + 1] <- ""; i <- i + 2; next
    }
    if (!in_class && c1 == "[") in_class <- TRUE
    else if (in_class && c1 == "]") in_class <- FALSE
    out[i] <- if (!in_class && c1 == ".") "[^\\n]" else c1
    i <- i + 1
  }
  res <- paste(out, collapse = "")
  assign(p, res, envir = .rx_cache)
  res
}

#' Number of non-overlapping matches of pattern `p` in each element of `x` (NA -> 0).
n_match <- function(x, p) {
  n <- stri_count_regex(x, rx(p))
  n[is.na(n)] <- 0L
  n
}

#' TRUE where pattern `p` occurs at least once in `x` (NA -> FALSE).
has_match <- function(x, p) {
  h <- stri_detect_regex(x, rx(p))
  h[is.na(h)] <- FALSE
  h
}

#' Lower-case text the way Python's str.lower() does; NA becomes "".
lower <- function(x) {
  x <- stri_trans_tolower(x)
  x[is.na(x)] <- ""
  x
}

# ---------------------------------------------------------------------------------------
# S2  Raw row-level tables
# ---------------------------------------------------------------------------------------

# Strings read as missing. These are the default missing-value markers of the CSV/Excel
# readers used in the published analysis (pandas), so the same cells become NA here.
NA_STRINGS <- c("", "#N/A", "#N/A N/A", "#NA", "-1.#IND", "-1.#QNAN", "-NaN", "-nan", "1.#IND",
                "1.#QNAN", "<NA>", "N/A", "NA", "NULL", "NaN", "None", "n/a", "nan", "null")

# Columns used anywhere in the analysis (all other columns are skipped when reading, which
# keeps memory low; investigator names and other identifying fields are never loaded).
KEEP_COLS <- c("APPLICATION_ID", "ACTIVITY", "ADMINISTERING_IC", "FULL_PROJECT_NUM", "CORE_PROJECT_NUM",
               "SUBPROJECT_ID", "TOTAL_COST", "TOTAL_COST_SUB_PROJECT", "PROJECT_TITLE",
               "ABSTRACT_TEXT", "PHR", "IS_NIH", "IS_RELEVENT")

#' Read an ExPORTER-style CSV with every column as character.
#'
#' utils::read.csv() is used (not data.table::fread) because it follows the standard CSV
#' quoting rules exactly (a doubled quote "" inside a quoted field is one quote), which
#' matches the reader used for the published analysis; fread's automatic quote-rule detection
#' leaves "" in some ExPORTER titles. ExPORTER files are usually UTF-8 but some years contain
#' Latin-1 bytes (S2.2): if any text is not valid UTF-8 the file is re-read as Latin-1.
read_csv_any <- function(path) {
  rd <- function(enc) as.data.table(utils::read.csv(path, colClasses = "character", na.strings = NA_STRINGS,
                                                    check.names = FALSE, comment.char = "", strip.white = FALSE,
                                                    quote = "\"", encoding = if (enc == "UTF-8") "UTF-8" else "unknown",
                                                    fileEncoding = if (enc == "UTF-8") "" else "latin1"))
  d <- rd("UTF-8")
  bad <- any(vapply(d, function(v) any(!validUTF8(v[!is.na(v)])), logical(1)))
  if (bad) d <- rd("latin1")
  d
}

#' S2.2: ExPORTER projects + abstracts. One abstract per APPLICATION_ID (first kept),
#' LEFT-joined so projects without an abstract are kept (they can still match on title/PHR).
#' match() keeps the project file's row order, which matters for pooled text (S4).
merge_project_abstract <- function(p, a) {
  p[, ABSTRACT_TEXT := a$ABSTRACT_TEXT[match(p$APPLICATION_ID, a$APPLICATION_ID)]]
  p
}

#' Re-encode control characters (other than tab, newline, carriage return) as Excel-style
#' "_xhhhh_" escapes (see load_rows()).
reescape_ctrl <- function(x) {
  for (cp in setdiff(0:31, c(9, 10, 13))) {
    ch <- intToUtf8(cp)
    if (cp == 0) next                       # NUL cannot occur in R strings
    hit <- !is.na(x) & grepl(ch, x, fixed = TRUE)
    if (any(hit)) x[hit] <- gsub(ch, sprintf("_x%04x_", cp), x[hit], fixed = TRUE)
  }
  x
}

#' Row-level table for one fiscal year, all columns character (cached as .rds in work_dir).
#'
#' FY2013-2023: NASEM committee workbook, sheet "All Data" (S2.1). Only the KEEP_COLS columns
#'              are read. readxl options mirror the original reader: no whitespace trimming,
#'              the same missing-value strings.
#' FY2024-2025: ExPORTER project + abstract CSVs (S2.2).
#' FY2026:      project + abstract CSVs rebuilt from the RePORTER API v2 JSON by 01_download.R.
#' The committee flags IS_NIH / IS_RELEVENT are normalised to "True"/"False".
load_rows <- function(fy) {
  cache <- work_path("rows", sprintf("rows_%d.rds", fy))
  if (file.exists(cache)) return(readRDS(cache))
  if (fy %in% CONFIG$committee_years) {
    f <- raw_path(fy, sprintf("AllData_%d.xlsx", fy))
    h <- names(readxl::read_excel(f, sheet = "All Data", n_max = 0))
    d <- readxl::read_excel(f, sheet = "All Data", col_types = ifelse(h %in% KEEP_COLS, "text", "skip"),
                            trim_ws = FALSE, na = NA_STRINGS, progress = FALSE)
    d <- as.data.table(d)
    # Excel stores control characters as escapes such as "_x0002_". readxl decodes them; the
    # reader used for the published analysis kept them literally. Re-encode them so the text
    # (and therefore every keyword count) is identical.
    for (j in c("PROJECT_TITLE", "ABSTRACT_TEXT", "PHR")) set(d, j = j, value = reescape_ctrl(d[[j]]))
    for (j in c("IS_NIH", "IS_RELEVENT"))   # Excel booleans come back as "TRUE"/"FALSE"
      set(d, j = j, value = ifelse(toupper(d[[j]]) == "TRUE", "True", ifelse(is.na(d[[j]]), NA, "False")))
  } else {
    dir <- if (fy == CONFIG$api_year) file.path(CONFIG$work_dir, "2026") else raw_path(fy)
    p <- read_csv_any(file.path(dir, "prj.csv"))
    p <- p[, intersect(KEEP_COLS, names(p)), with = FALSE]
    a <- read_csv_any(file.path(dir, "abs.csv"))
    d <- merge_project_abstract(p, a)
  }
  saveRDS(d, cache)
  d
}

#' S2.4: {appl_id -> title/abstract/PHR} for the FY2020/FY2024 intramural records fetched
#' from RePORTER API v2 (zfix/api_z.json). Returns one data.table per fiscal year.
load_api_z <- function() {
  j <- jsonlite::fromJSON(raw_path("zfix", "api_z.json"), simplifyVector = FALSE)
  nz <- function(v) if (is.null(v) || identical(v, "")) NA_character_ else as.character(v)
  lapply(j, function(recs) data.table(
    appl_id = vapply(recs, function(x) as.numeric(x$appl_id), numeric(1)),
    abstract_text = vapply(recs, function(x) nz(x$abstract_text), character(1)),
    phr_text = vapply(recs, function(x) nz(x$phr_text), character(1))))
}

#' Intramural projects = activity codes starting with "Z" (ZIA, ZIC, ZIE, ...).
is_intramural <- function(d) !is.na(d$ACTIVITY) & startsWith(d$ACTIVITY, "Z")

#' S2.4: the intramural (Z) rows of `d` with ABSTRACT_TEXT and PHR REPLACED by the API v2
#' values (NA where the API returned none or an empty string). Used by the WHR tiers.
zfix_rows <- function(fy, d, api) {
  z <- copy(d[is_intramural(d)])
  A <- api[[as.character(fy)]]
  i <- match(suppressWarnings(as.numeric(z$APPLICATION_ID)), A$appl_id)
  z[, ABSTRACT_TEXT := A$abstract_text[i]]
  z[, PHR := A$phr_text[i]]
  z
}

# ---------------------------------------------------------------------------------------
# S3.2 / S4  Project table (per-project counting)
# ---------------------------------------------------------------------------------------

#' first non-missing value of a vector (NA if none) -- used for IC and activity code.
first_nonna <- function(v) { v <- v[!is.na(v)]; if (length(v)) v[1] else NA_character_ }

#' Collapse rows to one record per FULL_PROJECT_NUM (rows with a missing project number are
#' dropped, as in the original grouping). Projects keep their order of first appearance.
#'
#' Dollars (S3.2): the parent row's TOTAL_COST; if the project has no parent cost, the sum of
#' its sub-projects' TOTAL_COST_SUB_PROJECT; otherwise 0. Parent rows are rows without a
#' SUBPROJECT_ID. This avoids double counting multi-component awards, whose parent
#' TOTAL_COST already includes the components.
#' Text (S4): title + " . " + abstract + " . " + PHR of EVERY row, concatenated in file order
#' with single spaces and lower-cased, so a women's-health focus stated only in a component
#' is still seen. The title used for title tests is the parent row's title (else the first
#' row's); a missing title becomes the string "nan" (as in the original code, it matches no
#' pattern).
project_table <- function(d) {
  d <- d[!is.na(FULL_PROJECT_NUM)]
  d[, `:=`(TC_ = as.numeric(TOTAL_COST), TCS_ = as.numeric(TOTAL_COST_SUB_PROJECT),
           par_ = is.na(SUBPROJECT_ID),
           txt_ = paste0(fifelse(is.na(PROJECT_TITLE), "", PROJECT_TITLE), " . ",
                         fifelse(is.na(ABSTRACT_TEXT), "", ABSTRACT_TEXT), " . ",
                         fifelse(is.na(PHR), "", PHR)))]
  P <- d[, {
    pt <- if (any(par_)) TC_[par_][1] else NA_real_
    sub <- if (all(is.na(TCS_))) NA_real_ else sum(TCS_, na.rm = TRUE)
    usd <- if (!is.na(pt)) pt else if (!is.na(sub)) sub else 0
    src <- if (!is.na(pt)) "parent TOTAL_COST" else if (!is.na(sub)) "sum of subproject TOTAL_COST_SUB_PROJECT" else "no cost reported"
    title <- if (any(par_)) PROJECT_TITLE[par_][1] else PROJECT_TITLE[1]
    list(CORE_PROJECT_NUM = CORE_PROJECT_NUM[1], n_rows = .N, PROJECT_TITLE = title,
         text = paste(txt_, collapse = " "), USD = usd, USD_source = src,
         IC = first_nonna(ADMINISTERING_IC), ACT = first_nonna(ACTIVITY))
  }, by = FULL_PROJECT_NUM]
  P[, title_l := fifelse(is.na(PROJECT_TITLE), "nan", stri_trans_tolower(PROJECT_TITLE))]
  P[, text := lower(text)]
  P[]
}

# ---------------------------------------------------------------------------------------
# S5.1  Keyword classification -> Classification (WHR / Non-WHR) x Confidence (High/Medium/Low)
#   strict tier = WHR & High;  main tier = WHR (any confidence);  broad = WHR or Non-WHR Low
# ---------------------------------------------------------------------------------------

#' Two passes applied per project (pass 2 refines pass 1). Vectorised translation of the
#' original row-by-row if/elif logic; the order of the conditions is preserved exactly.
#' @param P project table with columns text and title_l
#' @return P with Classification, Confidence, Rationale, pop_n, core_n added
keyword_classify <- function(P) {
  t <- P$text; tl <- P$title_l
  cnts <- vapply(CLS_CORE, function(p) n_match(t, p), integer(length(t)))
  if (is.null(dim(cnts))) cnts <- matrix(cnts, nrow = length(t), dimnames = list(NULL, names(CLS_CORE)))
  # counts of women/female population words, minus animal-model uses ("female mice" ...)
  pop <- n_match(t, CLS_POP) - n_match(t, CLS_EXCL)
  tcore <- vapply(CLS_CORE, function(p) has_match(tl, p), logical(length(t)))
  if (is.null(dim(tcore))) tcore <- matrix(tcore, nrow = length(t), dimnames = list(NULL, names(CLS_CORE)))
  any_tcore <- rowSums(tcore) > 0
  tpop <- has_match(tl, CLS_POP)
  core <- rowSums(cnts)
  weak <- colnames(cnts) %in% WEAK_GROUPS
  strong <- rowSums(cnts[, !weak, drop = FALSE])
  sexd <- cnts[, "sex/gender differences"]
  # ---- pass 1: title evidence beats abstract evidence; thresholds chosen on hand review
  cls <- rep("Non-WHR", length(t)); conf <- rep("High", length(t))
  why <- rep("no WHR terms in title/abstract/narrative", length(t))
  set_ <- function(m, a, b, c) { cls[m] <<- a; conf[m] <<- b; why[m] <<- c }
  r1 <- any_tcore | tpop
  r2 <- !r1 & (strong >= 4 | pop >= 6)
  r3 <- !r1 & !r2 & (core + pop >= 3 | sexd >= 1)
  r4 <- !r1 & !r2 & !r3 & (core + pop > 0)
  set_(r1, "WHR", "High", "women's-health term in title")
  set_(r2, "WHR", "Medium", "repeated WHR terms in abstract/narrative")
  set_(r3, "Non-WHR", "Low", "borderline: some WHR terms but not a central focus")
  set_(r4, "Non-WHR", "Medium", "incidental WHR term(s) only")
  # centre/training/core grants with a condition word (but no population word) in the title
  set_(any_tcore & has_match(tl, CLS_TITLE_CENTER) & !tpop, "WHR", "Low", "WHR term in title of broad center/training grant")
  # ---- pass 2: exclusions and down-grades (an if/elif chain evaluated on the pass-1 result)
  male <- n_match(t, CLS_MALE); fem <- core + pop
  broad_t <- has_match(tl, CLS_BROAD)
  only_weak_title <- rowSums(tcore[, !weak, drop = FALSE]) == 0 & !tpop   # title hits are all weak groups
  w <- cls == "WHR"; c0 <- conf
  e1 <- w & male > fem & !has_match(tl, CLS_TITLE_FEMALE)
  e2 <- !e1 & w & c0 != "High" & broad_t
  e3 <- !e1 & !e2 & w & c0 == "High" & broad_t & !has_match(tl, CLS_TITLE_WHR_FOCUS)
  e4 <- !e1 & !e2 & !e3 & w & c0 == "Medium" & core < 4 & pop < 10
  e5 <- !e1 & !e2 & !e3 & !e4 & w & c0 == "High" & only_weak_title & pop < 3
  set_(e1, "Non-WHR", "Low", "reproductive/pelvic terms but male-focused")
  set_(e2, "Non-WHR", "Low", "broad center/training/resource grant; WHR is one component, not primary focus")
  set_(e3, "WHR", "Low", "WHR term in title of broad grant")
  set_(e4, "Non-WHR", "Low", "women/female mentioned repeatedly but no WHR condition focus")
  conf[e5] <- "Medium"; why[e5] <- "title mentions female hormone or female-prevalent condition"
  P[, `:=`(Classification = cls, Confidence = conf, Rationale = why, pop_n = pop, core_n = core)]
  P[]
}

# ---------------------------------------------------------------------------------------
# Row-level helpers for the cardiovascular classification (S9) and the project universe
# ---------------------------------------------------------------------------------------

#' S3.1 / S9 universe for row-level analyses: FY2013-2023 rows flagged IS_NIH in the committee
#' file; later years rows whose administering IC is an NIH Institute/Center.
nih_rows <- function(fy, d) {
  if (fy %in% CONFIG$committee_years) d[!is.na(IS_NIH) & IS_NIH == "True"]
  else d[!is.na(ADMINISTERING_IC) & ADMINISTERING_IC %in% NIH_ICS]
}

#' Abstract and PHR strings ("" when missing). For FY2020/2024 intramural rows the abstract
#' is REPLACED by the API v2 abstract, and the API PHR is used only where the file's PHR is
#' empty (S2.4). `ZA` = API records of both years, keyed by application id.
row_text <- function(fy, d, ZA) {
  z <- is_intramural(d)
  a <- fifelse(is.na(d$ABSTRACT_TEXT), "", d$ABSTRACT_TEXT)
  p <- fifelse(is.na(d$PHR), "", d$PHR)
  if (fy %in% CONFIG$zfix_years) {
    i <- match(suppressWarnings(as.numeric(d$APPLICATION_ID)), ZA$appl_id)
    za <- fifelse(is.na(ZA$abstract_text[i]), "", ZA$abstract_text[i])
    zp <- fifelse(is.na(ZA$phr_text[i]), "", ZA$phr_text[i])
    a <- fifelse(z, za, a)
    p <- fifelse(z & p == "", zp, p)
  }
  list(a = a, p = p, z = z)
}

# ---------------------------------------------------------------------------------------
# S11.1  OLS trend with Newey-West (HAC) standard errors
# ---------------------------------------------------------------------------------------

#' OLS of a yearly series on (year - 2013) with Newey-West standard errors.
#'
#' Bartlett kernel with `lag` lags, no pre-whitening, NO small-sample adjustment, and
#' normal-theory (z) confidence intervals and p-values -- the defaults of the software used
#' for the published analysis (statsmodels OLS, cov_type = "HAC").
#' @param y yearly values (e.g. percentage of funding)
#' @param yr fiscal years
#' @param lag number of Newey-West lags (1 or 2)
#' @return list(slope, ci_low, ci_high, p, dw)
nw_trend <- function(y, yr, lag) {
  x <- yr - 2013
  fit <- lm(y ~ x)
  V <- sandwich::NeweyWest(fit, lag = lag, prewhite = FALSE, adjust = FALSE)
  b <- coef(fit)[["x"]]; se <- sqrt(V["x", "x"])
  e <- resid(fit)
  list(slope = b, ci_low = b - qnorm(0.975) * se, ci_high = b + qnorm(0.975) * se,
       p = 2 * pnorm(-abs(b / se)), dw = sum(diff(e)^2) / sum(e^2))
}
