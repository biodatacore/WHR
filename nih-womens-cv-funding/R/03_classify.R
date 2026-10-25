#' 03_classify.R -- women's health research (WHR) tiers (S5) and cardiovascular (CV) / women's CV classification (S9).
#'
#' PURPOSE
#'   A. WHR (S5). Assign every NIH project in every fiscal year to the nested rule-based tiers
#'        keyword strict / main / broad ..... S5.1  (Classification x Confidence)
#'        strict + sex differences ("base") . S5.3  (keyword strict OR substantive sex-difference
#'                                                   research after the SABV boilerplate filter)
#'        partial tier v1 ................... S5.4  (maternal, multi-cancer, HIV/STI in women,
#'                                                   female-predominant, reproductive rules)
#'        partial tier v2 ................... S5.5  (conditions more common in women)
#'        partial tier v3  (MAIN ANALYSIS) .. S5.6  (HPV vaccine, microbicides, LAM, UTI, puberty,
#'                                                   Latina, sexual violence, female populations)
#'        NASEM-comparable .................. S5.6  (both-sex sex-difference + maternal-
#'                                                   sensitivity rules; widest)
#'      and compute the yearly WHR share of NIH dollars with the intramural no-text imputation (S5.7).
#'   B. CV (S9). Row-level CV scoring of every NIH row, the CV tiers, the women's-CV rule, and
#'      the project-level table that links CV status to the WHR tiers (input to 04-06).
#'
#' INPUTS   work_dir/proj/*.rds and work_dir/rows/*.rds (02_build.R); raw_dir/zfix/api_z.json
#' OUTPUTS  work_dir/whr/feat_{FY}.rds   features per NIH project (intramural-fixed)
#'          work_dir/whr/tiers.rds       project-level tier flags (FY, FULL_PROJECT_NUM, USD, ...)
#'          work_dir/whr/yearly.rds      yearly NIH $B and WHR n / $B / % (strict+sexdiff, v3,
#'                                       NASEM-comparable) -> Figure 1 and the yearly shares
#'          work_dir/cv/feat_{FY}.rds    row-level CV features
#'          work_dir/cv/G.rds            project-level CV flags + WHR tiers + USD (-> 04, 05)
#'          work_dir/cv/R.rds            yearly CV totals and WHR / women's-CV shares (-> Figure 1)
#'
#' RATIONALE (see S5 and S9 of the Supplementary Methods for the full discussion)
#'   * Rules are nested: each tier keeps everything in the previous tier and adds projects
#'     matched by new, independently hand-checked rules, so differences between tiers are
#'     attributable to specific rules.
#'   * Thresholds were tuned on FY2013-2017 committee labels and checked on FY2018-2023
#'     using dollar-weighted precision/recall (the outcome is a dollar share). The committee
#'     labels are used only to tune/evaluate, never to classify; this script does not need them.
#'   * Universe = projects whose administering IC is an NIH Institute/Center (S3.1).
#'   * CV is scored per ROW (not on pooled project text) because component rows of large
#'     centres describe unrelated science; the parent row describes the award.


source("R/00_setup.R")

# --- feature dictionary: name -> regex. Each gives a text count <name> and a title flag t_<name>.
FEATURES <- c(V1_FEATURES,                                               # S5.4
              setNames(V2_CONDITIONS, paste0("c_", names(V2_CONDITIONS))),  # S5.5
              setNames(V3_NEW, paste0("n_", names(V3_NEW))),                # S5.6
              list(a3 = V3_A3, sexd = V3_SEXD))                            # S5.6 NASEM-comparable

# Python's \s (Unicode whitespace) written out for ICU, used to split text into sentences.
PY_SPACE <- "[\\t\\n\\x0b\\f\\r\\x1c-\\x1f\\x85\\p{Z}]"

#' S5.3 substantive sex-differences research, with the SABV boilerplate filter.
#'   1. Skip unless a candidate phrase (SD_PH) appears anywhere in the text.
#'   2. Split into sentences (after . ; ! ?); keep sentences with a candidate phrase ...
#'   3. ... drop any containing boilerplate (SD_BOIL: "both sexes will be included", SABV ...).
#'   4. strong = remaining sentences with a substantive phrase (SD_STRONGPH);
#'      aim    = strong sentences that also use aim/hypothesis language (SD_AIM).
#'   5. Qualify if: title signals a sex focus AND >= 1 non-boilerplate sentence;
#'                  OR >= 3 strong sentences with >= 1 aim; OR >= 2 strong with >= 2 aims.
#' @return data.table(sexdiff = flag, sexd_good = number of non-boilerplate sentences)
sexdiff_flag <- function(text, title_l) {
  n <- length(text); flag <- logical(n); good <- integer(n)
  cand <- which(has_match(text, SD_PH))
  if (length(cand)) {
    S <- stri_split_regex(text[cand], paste0("(?<=[.;!?])", PY_SPACE, "+"))
    id <- rep(seq_along(S), lengths(S)); s <- unlist(S, use.names = FALSE)
    k <- has_match(s, SD_PH); s <- s[k]; id <- id[k]
    g <- !has_match(s, SD_BOIL)
    st <- g & has_match(s, SD_STRONGPH)
    am <- st & has_match(s, SD_AIM)
    ng <- tabulate(id[g], length(cand)); nst <- tabulate(id[st], length(cand)); nam <- tabulate(id[am], length(cand))
    ttl <- has_match(title_l[cand], paste0(SD_STRONGPH, SD_TITLE_EXTRA))
    flag[cand] <- (ttl & ng >= 1) | (nst >= 3 & nam >= 1) | (nst >= 2 & nam >= 2)
    good[cand] <- ng
  }
  data.table(sexdiff = flag, sexd_good = good)
}

#' Counts of every feature regex in the pooled text and presence in the title (S4: counts of
#' non-overlapping matches in lower-cased title + abstract + PHR of all rows of the project).
features <- function(P, fy) {
  X <- data.table(FY = fy, FULL_PROJECT_NUM = P$FULL_PROJECT_NUM, USD = P$USD, cls = P$Classification,
                  conf = P$Confidence, title = P$PROJECT_TITLE, ACT = P$ACT, IC = P$IC)
  for (k in names(FEATURES)) {
    set(X, j = k, value = n_match(P$text, FEATURES[[k]]))
    set(X, j = paste0("t_", k), value = has_match(P$title_l, FEATURES[[k]]))
  }
  cbind(X, sexdiff_flag(P$text, P$title_l))
}

#' Features for one fiscal year. For FY2020/2024 the intramural projects are replaced by the
#' versions rebuilt from API v2 text (S2.4). As in the original analysis these intramural
#' projects are not re-filtered by IC (all intramural projects are NIH-administered).
year_features <- function(fy) {
  f <- work_path("whr", sprintf("feat_%d.rds", fy))
  if (file.exists(f) && !isTRUE(CONFIG$rebuild)) return(sprintf("%d: cached", fy))
  P <- readRDS(work_path("proj", sprintf("proj_%d.rds", fy)))
  ic <- setNames(P$IC, P$FULL_PROJECT_NUM); act <- setNames(P$ACT, P$FULL_PROJECT_NUM)
  P <- keyword_classify(P[!is.na(IC) & IC %in% NIH_ICS])                 # S3.1 NIH filter, S5.1
  X <- features(P, fy); X[, zfixed := FALSE]
  if (fy %in% CONFIG$zfix_years) {
    Z <- readRDS(work_path("proj", sprintf("projz_%d.rds", fy)))
    Z[, `:=`(IC = unname(ic[FULL_PROJECT_NUM]), ACT = unname(act[FULL_PROJECT_NUM]))]
    XZ <- features(keyword_classify(Z), fy); XZ[, zfixed := TRUE]
    X <- rbind(X[!FULL_PROJECT_NUM %in% Z$FULL_PROJECT_NUM], XZ)
  }
  saveRDS(X, work_path("whr", sprintf("feat_%d.rds", fy)))
  sprintf("%d: %s NIH projects", fy, format(nrow(X), big.mark = ","))
}

#' S5.3-S5.6 tiers. Thresholds are counts of regex matches in the pooled project text.
assign_tiers <- function(X) {
  CENT <- grepl(CENTER_ACTIVITY, fifelse(is.na(X$ACT), "", X$ACT), perl = TRUE) |
    has_match(fifelse(is.na(X$title), "nan", stri_trans_tolower(X$title)), CENTER_TITLE)
  w <- X$women
  wf <- X$t_women | w >= 3                               # "women-focused": in title or >= 3 mentions
  hit <- function(c) X[[c]] >= 3 | X[[paste0("t_", c)]]  # condition is central: >= 3 mentions or in title
  any1 <- function(c) X[[c]] >= 1 | X[[paste0("t_", c)]] # condition mentioned at all
  X[, kw_strict := cls == "WHR" & conf == "High"]
  X[, kw_main := cls == "WHR"]
  X[, kw_broad := kw_main | (cls == "Non-WHR" & conf == "Low")]
  # S5.3 base tier = keyword strict + sex-differences research
  base <- X$kw_strict | X$sexdiff
  # S5.4 v1 rules (tuned on FY2013-2017)
  v1 <- with(X, list(
    maternal = mat >= 3 & matout >= 1,                                   # maternal-outcome focus
    multicancer = cancer >= 3 & (bg >= 2 | (CENT & bg >= 1)),            # breast/gyn cancer within cancer grants
    hiv_sti_women = hiv >= 3 & (w >= 3 | t_women),                       # HIV/STI research in women
    female_predominant = (femprev >= 3 | t_femprev) & w >= 1,            # e.g. lupus, MS, migraine
    repro = repro >= 4 & male < repro / 2 & (w >= 1 | t_repro)))         # female reproduction
  # S5.5 v2 rules: female-predominant / sex-differential conditions with a women focus
  v2 <- list(perinatal_dep = (X$c_perinatal_dep >= 1 | X$t_c_perinatal_dep) & w >= 1)
  for (c in c("depression", "anxiety", "ptsd", "alzheimer", "rheumatoid", "ild"))
    v2[[c]] <- hit(paste0("c_", c)) & wf                   # common conditions: need a women focus
  for (c in c("thyroid", "tmd", "cfs", "other"))
    v2[[c]] <- hit(paste0("c_", c)) & w >= 1               # strongly female-predominant: one mention suffices
  # S5.6 v3 rules
  v3 <- with(X, list(
    hpv_vaccine = any1("n_hpvvax"),
    microbicide = any1("n_microbicide") & hiv >= 2 & w >= 2,
    lam = any1("n_lam"),                                     # LAM occurs almost only in women
    uti = hit("n_uti") & w >= 1,
    puberty_girls = hit("n_puberty") & w >= 2,
    latina = any1("n_latina"),
    sexual_violence = (n_sexviol >= 2 | t_n_sexviol) & w >= 1,
    female_population = hit("n_fempop") & w >= 2))
  # S5.6 NASEM-comparable extras (closer to the committee's inclusive reading)
  nc <- with(X, list(bothsex_sexdiff = a3 >= 2 & sexd >= 1 & w >= 2,
                     maternal_sensitivity = mat >= 6))
  anyl <- function(l) Reduce(`|`, l)
  #' name of the first matching rule (for audit), "" if none
  first_rule <- function(l) { M <- do.call(cbind, l); r <- max.col(M, ties.method = "first"); fifelse(rowSums(M) > 0, names(l)[r], "") }
  X[, base := base]
  X[, t1 := base | anyl(v1)]
  X[, t2 := t1 | anyl(v2)]
  X[, add3 := anyl(v3) & !t2]; X[, r3 := first_rule(v3)]
  X[, t3 := t2 | add3]
  X[, addnc := anyl(nc) & !t3]; X[, rnc := first_rule(nc)]
  X[, tnc := t3 | addnc]
  X[]
}

# NASEM report Table A-1 published WHR % of NIH dollars (S2.5), reference column only.
NASEM_PUBLISHED_PCT <- c(`2013` = 9.69, `2014` = 9.59, `2015` = 9.09, `2016` = 8.87, `2017` = 9.12, `2018` = 9.0,
                         `2019` = 8.96, `2020` = 7.77, `2021` = 8.59, `2022` = 8.94, `2023` = 7.85)

#' S5.7 yearly shares. Intramural projects that still have no abstract after the API fix
#' (FY2020, FY2024) cannot be classified; their dollars are allocated at the dollar-weighted
#' tier rate observed for intramural projects in the other years.
yearly <- function(X, zrows) {
  X[, Z := !is.na(ACT) & startsWith(ACT, "Z")]
  nt <- rbindlist(lapply(names(zrows), function(fy) {
    z <- zrows[[fy]]; data.table(FY = as.integer(fy), FULL_PROJECT_NUM = unique(z$FULL_PROJECT_NUM[is.na(z$ABSTRACT_TEXT)]))
  }))
  X[, notext := paste(FY, FULL_PROJECT_NUM) %in% paste(nt$FY, nt$FULL_PROJECT_NUM)]
  zo <- X[Z & !FY %in% CONFIG$zfix_years]
  rate <- sapply(c("base", "t3", "tnc"), function(c) sum(zo$USD[zo[[c]]]) / sum(zo$USD))
  Y <- rbindlist(lapply(CONFIG$years, function(fy) {
    x <- X[FY == fy]; Tt <- sum(x$USD)
    d <- list(FY = fy, nih_projects = nrow(x), nih_B = Tt / 1e9)
    for (c in c("base", "t3", "tnc")) {
      lab <- c(base = "strict_sexdiff", t3 = "v3", tnc = "nasem_comp")[[c]]
      u <- sum(x$USD[x[[c]] & !x$notext]) + rate[[c]] * sum(x$USD[x$notext])
      d[[paste0(lab, "_n")]] <- sum(x[[c]] & !x$notext)
      d[[paste0(lab, "_B")]] <- u / 1e9
      d[[paste0(lab, "_pct")]] <- 100 * u / Tt
    }
    d$imputed_B <- sum(x$USD[x$notext]) / 1e9
    d$NASEM <- unname(NASEM_PUBLISHED_PCT[as.character(fy)])
    d
  }))
  list(Y = Y, rate = rate)
}

# ======================================================================================
# A. WHR tiers
# ======================================================================================
for (m in pmap_years(CONFIG$years, year_features)) say(m)
X <- assign_tiers(rbindlist(lapply(CONFIG$years, function(y) readRDS(work_path("whr", sprintf("feat_%d.rds", y))))))
zrows <- setNames(lapply(CONFIG$zfix_years, function(y) readRDS(work_path("proj", sprintf("zfix_rows_%d.rds", y)))), CONFIG$zfix_years)
yy <- yearly(X, zrows)
saveRDS(X, work_path("whr", "tiers.rds"))
saveRDS(yy$Y, work_path("whr", "yearly.rds"))
saveRDS(yy$rate, work_path("whr", "imputation_rates.rds"))
say("intramural imputation rates (%): ", paste(names(yy$rate), round(100 * yy$rate, 2), collapse = ", "))
print(yy$Y[, .(FY, nih_B = round(nih_B, 3), v3_n, v3_B = round(v3_B, 3), v3_pct = round(v3_pct, 3),
               strict = round(strict_sexdiff_pct, 3), nasem_comp = round(nasem_comp_pct, 3))])

# ======================================================================================
# B. Cardiovascular (CV) research and women's CV health (S9)
#
# Universe: FY2013-2023 rows with IS_NIH == True (committee flag); FY2024-2026 rows whose
# administering IC is an NIH IC. Text: FY2020/2024 intramural rows take the API v2 abstract,
# and the API PHR only where the file's PHR is empty (S2.4). Title and abstract+PHR are scored
# separately, after deleting false-positive phrases (CV_EXC: VEGF, tumour angiogenesis, heart
# rate, intracranial hypertension, "at the heart of", ...):
#   ts/tw = strong/weak CV terms in title;  s/w = strong/weak CV terms in abstract+PHR
#   strict = ts>=1 or s>=5
#   broad2 = strict or s>=3 or (s>=2 & w>=2) or (tw>=1 & s>=1) or (tw>=1 & w>=6) or (s>=1 & w>=5)
#            [MAIN CV definition; precision ~84% in a hand-checked random sample]
#   wcv3   = (strict or (broad2 & wp>=2)) & (women word in title or wp>=2 or wsx>=2
#            or (wm>=2 & ww>=2) or ww>=6)          [women's CV rule; reported for reference]
# Project flags (S3.2): taken from the project's parent row(s); a project with no parent row
# uses any of its rows. Dollars come from the WHR project table, so CV and WHR totals agree.
# ======================================================================================
# API v2 intramural text is needed only when the row features have to be computed from raw files
# (not when they were loaded from the shipped data by R/02_load_shipped.R).
need_raw_cv <- isTRUE(CONFIG$rebuild) || !all(file.exists(file.path(CONFIG$work_dir, "cv", sprintf("feat_%d.rds", CONFIG$years))))
ZA <- if (need_raw_cv) rbindlist(load_api_z()) else NULL

cv_year_features <- function(fy) {
  f <- work_path("cv", sprintf("feat_%d.rds", fy))
  if (file.exists(f) && !isTRUE(CONFIG$rebuild)) return(sprintf("%d: cached", fy))
  d <- nih_rows(fy, load_rows(fy))
  tx_ <- row_text(fy, d, ZA)
  ti <- stri_replace_all_regex(lower(d$PROJECT_TITLE), rx(CV_EXC), " ")
  tx <- stri_replace_all_regex(lower(paste0(tx_$a, " . ", tx_$p)), rx(CV_EXC), " ")
  tt <- paste0(ti, " ", tx)
  o <- data.table(FY = fy, APPLICATION_ID = d$APPLICATION_ID, FULL_PROJECT_NUM = d$FULL_PROJECT_NUM,
                  ts = n_match(ti, CV_STR), tw = n_match(ti, CV_WEAK), s = n_match(tx, CV_STR), w = n_match(tx, CV_WEAK),
                  tws = n_match(ti, CV_WT), wp = n_match(tt, CV_WP), wm = n_match(tt, CV_WM), wsx = n_match(tt, CV_WS),
                  ww = n_match(tt, CV_WW), ntext = nchar(tx),
                  SUB = !is.na(d$SUBPROJECT_ID),                                  # component row
                  TC = { v <- suppressWarnings(as.numeric(d$TOTAL_COST)); v[is.na(v)] <- 0; v },
                  Z = tx_$z)
  saveRDS(o, work_path("cv", sprintf("feat_%d.rds", fy)))
  sprintf("%d: %s NIH rows", fy, format(nrow(o), big.mark = ","))
}

cv_tiers <- function(F) {
  F[, strict := ts >= 1 | s >= 5]
  F[, broad2 := strict | s >= 3 | (s >= 2 & w >= 2) | (tw >= 1 & s >= 1) | (tw >= 1 & w >= 6) | (s >= 1 & w >= 5)]
  core <- F$strict | (F$broad2 & F$wp >= 2)
  F[, wcv3 := core & (tws >= 1 | wp >= 2 | wsx >= 2 | (wm >= 2 & ww >= 2) | ww >= 6)]
  F[]
}

for (m in pmap_years(CONFIG$years, cv_year_features)) say(m)
F <- cv_tiers(rbindlist(lapply(CONFIG$years, function(y) readRDS(work_path("cv", sprintf("feat_%d.rds", y))))))
Xk <- unique(X[, .(FY, FULL_PROJECT_NUM, USD, base, t3, tnc)], by = c("FY", "FULL_PROJECT_NUM"))
F[, `:=`(cv = broad2, cvs = strict, wcv = wcv3, par = !SUB)]
F_rows <- F[, .(FY, cv, cvs, TC)]                                 # row-level totals use every NIH row
F <- F[!is.na(FULL_PROJECT_NUM)]                                  # project-level: rows without a project number are dropped
F[, use := par | !any(par), by = .(FY, FULL_PROJECT_NUM)]         # parent rows; all rows if no parent
G <- F[use == TRUE, .(cv = any(cv), cvs = any(cvs), wcv = any(wcv)), by = .(FY, FULL_PROJECT_NUM)]
G <- merge(G, Xk, by = c("FY", "FULL_PROJECT_NUM"), all.x = TRUE, sort = FALSE)
for (c in c("base", "t3", "tnc")) set(G, i = which(is.na(G[[c]])), j = c, value = FALSE)   # not in WHR universe
saveRDS(G, work_path("cv", "G.rds"))

# yearly CV totals and shares (Figure 1 of the CV report, Table S9)
meth <- c(base = "Strict + sex differences", t3 = "Partial tier v3", tnc = "NASEM-comparable", wcv = "Women's CV rule")
Rcv <- rbindlist(lapply(CONFIG$years, function(fy) {
  g <- G[FY == fy]; f <- F_rows[FY == fy]; Tt <- sum(g$USD, na.rm = TRUE)
  rbindlist(lapply(c(broad = "cv", strict = "cvs"), function(den) {
    gc_ <- g[g[[den]]]; fc <- f[f[[den]]]
    d <- list(FY = fy, CV_tier = if (den == "cv") "broad" else "strict", CV_projects = nrow(gc_),
              CV_proj_B = sum(gc_$USD, na.rm = TRUE) / 1e9, CV_rows = nrow(fc), CV_row_B = sum(fc$TC) / 1e9,
              CV_share_NIH_pct = 100 * sum(gc_$USD, na.rm = TRUE) / Tt)
    for (k in names(meth)) {
      m <- gc_[[k]]
      d[[paste(meth[[k]], "n")]] <- sum(m)
      d[[paste(meth[[k]], "B")]] <- sum(gc_$USD[m], na.rm = TRUE) / 1e9
      d[[paste(meth[[k]], "pct_B")]] <- 100 * sum(gc_$USD[m], na.rm = TRUE) / sum(gc_$USD, na.rm = TRUE)
    }
    d
  }))
}))
saveRDS(Rcv, work_path("cv", "R.rds"))
print(Rcv[CV_tier == "broad", .(FY, CV_projects, CV_proj_B = round(CV_proj_B, 3), CV_share_NIH_pct = round(CV_share_NIH_pct, 2),
                                 WHR_in_CV_pct = round(`Partial tier v3 pct_B`, 2))])

