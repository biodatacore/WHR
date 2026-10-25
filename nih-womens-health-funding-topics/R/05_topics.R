#' 05_topics.R -- topic decomposition of all NIH women's health research (WHR) funding.
#'
#' UNIVERSE  Partial-tier-v3 WHR projects (per-project counting), all NIH, FY2013-2026 (2026
#'           incomplete), that have text. FY2020/2024 intramural projects use the API v2 text
#'           (as in the classification). Intramural FY2020/2024 projects that still had no text
#'           cannot be tagged; their imputed WHR dollars (S5.7) are carried as a separate
#'           pseudo-topic, so yearly WHR totals equal the main analysis (Figure 1) exactly.
#' TAGGING   Two-level multi-label taxonomy (R/topics_whr.R): a subtopic is assigned if its
#'           pattern is in the title or occurs >= 2 times in title + abstract + PHR (>= 1 for
#'           the specific conditions in WHR_SUB_ONE); a group = any of its subtopics;
#'           "7 Other / general women's health" = no subtopic.
#' MEASURES  frac = project dollars split equally across matched GROUPS (group tables) or matched
#'           SUBTOPICS (subtopic tables); sums to the WHR total. any = full dollars per match.
#' ANALYSES  * pooled dollar-weighted shares of NIH funding and of WHR funding, FY2013-2015 vs
#'             FY2023-2025 (decomposition);
#'           * exclusion sensitivities: the NHLBI 3M/IMPROVE award alone, and all key large
#'             awards (National Children's Study, ECHO, WHI, NRG Oncology, HPTN LOC, NCI pooled
#'             contracts, 3M/IMPROVE). Award dollars are removed from the topic and WHR totals;
#'             the NIH denominator is unchanged;
#'           * OLS trends of each share on FY with Newey-West SEs (lags 1, 2), FY2013-2025 (main)
#'             and FY2013-2026.
#' CAVEAT    Topic results are indicative: matches were spot-checked, not manually coded.
#'
#' INPUTS   work_dir/whr/tiers.rds, imputation_rates.rds, yearly.rds; work_dir/proj/*.rds
#' OUTPUTS  work_dir/topics/whr_topics.rds (for 06_figures.R); out_dir/whr_topic_trends.xlsx;
#'          out_dir/key_numbers_topics.csv

source("R/00_setup.R")
source("R/topics_whr.R")
Y0 <- CONFIG$years; A <- as.character(CONFIG$pooled_early); B <- as.character(CONFIG$pooled_late)
SUB <- WHR_TOPICS$subtopic; GRP <- sort(unique(WHR_TOPICS$group))
IMPN <- "Imputed intramural FY2020/2024 (no text)"
yv <- function(s) { v <- setNames(numeric(length(Y0)), Y0); v[as.character(s[[1]])] <- s[[2]]; v }

# ---- universe, denominators and imputed dollars --------------------------------------------
X <- readRDS(work_path("whr", "tiers.rds")); rate <- readRDS(work_path("whr", "imputation_rates.rds"))[["t3"]]
NIH <- yv(X[, .(sum(USD)), keyby = FY])
IMP <- yv(X[notext == TRUE, .(sum(USD) * rate), keyby = FY])
P <- rbindlist(lapply(Y0, function(y) {
  p <- readRDS(work_path("proj", sprintf("proj_%d.rds", y)))[, .(FY = y, FULL_PROJECT_NUM, CORE_PROJECT_NUM, PROJECT_TITLE, text, IC, ACT)]
  if (y %in% CONFIG$zfix_years) {               # intramural projects: API v2 text (S2.4)
    z <- readRDS(work_path("proj", sprintf("projz_%d.rds", y)))
    i <- match(p$FULL_PROJECT_NUM, z$FULL_PROJECT_NUM); p[!is.na(i), text := z$text[i[!is.na(i)]]]
  }
  p
}))
D <- merge(X[t3 == TRUE & notext == FALSE, .(FY, FULL_PROJECT_NUM, USD)], P, by = c("FY", "FULL_PROJECT_NUM"), all.x = TRUE, sort = FALSE)
D[, text := fifelse(is.na(text), "", lower(text))]; D[, title_l := lower(PROJECT_TITLE)]
V <- readRDS(work_path("whr", "yearly.rds"))
WT <- yv(D[, .(sum(USD)), keyby = FY]) + IMP
stopifnot(isTRUE(all.equal(unname(WT / 1e9), V$v3_B, tolerance = 1e-9)))   # equals the main analysis
say("WHR project-years with text: ", nrow(D))

# ---- tagging ------------------------------------------------------------------------------
for (i in seq_len(nrow(WHR_TOPICS))) {
  s <- WHR_TOPICS$subtopic[i]; need <- if (s %in% WHR_SUB_ONE) 1 else 2
  set(D, j = s, value = has_match(D$title_l, WHR_TOPICS$pattern[i]) | n_match(D$text, WHR_TOPICS$pattern[i]) >= need)
}
for (g in GRP) set(D, j = g, value = rowSums(D[, WHR_TOPICS[group == g]$subtopic, with = FALSE]) > 0)
D[, (WHR_OTHER) := rowSums(.SD) == 0, .SDcols = GRP]

# ---- key large awards (first matching definition wins) -----------------------------------
KEY <- list(`NHLBI 3M / IMPROVE coordinating award (OT2HL158287)` = function(d) d$CORE_PROJECT_NUM %in% "OT2HL158287",
  `National Children's Study contracts` = function(d) has_match(d$title_l, "national children.s study"),
  `ECHO cohorts` = function(d) has_match(d$title_l, r"(\becho\b|environmental influences on child)"),
  `Women's Health Initiative contracts/cohorts` = function(d) has_match(d$title_l, r"(women.s health initiative|\bwhi\b)"),
  `NRG Oncology network` = function(d) has_match(d$title_l, "nrg oncology"),
  `HIV Prevention Trials Network LOC (UM1AI068619)` = function(d) d$CORE_PROJECT_NUM %in% "UM1AI068619",
  `NCI pooled contracts N01CO/N01CA000000` = function(d) d$CORE_PROJECT_NUM %in% c("N01CO000000", "N01CA000000"))
D[, key_award := ""]
for (k in names(KEY)) D[KEY[[k]](D) & key_award == "", key_award := k]
m3 <- D$CORE_PROJECT_NUM %in% "OT2HL158287"; mk <- D$key_award != ""

#' Fractional allocation over `cols` (rows of `d`), FY x topic dollars, plus the imputed column.
alloc <- function(cols, keep = rep(TRUE, nrow(D))) {
  d <- D[keep]; M <- as.matrix(d[, ..cols]) * 1; M <- M / rowSums(M) * d$USD
  o <- rowsum(M, d$FY); o <- o[match(Y0, rownames(o)), , drop = FALSE]; o[is.na(o)] <- 0; rownames(o) <- Y0
  cbind(o, setNames(matrix(IMP, ncol = 1, dimnames = list(NULL, IMPN)), IMPN))
}
GC <- c(GRP, WHR_OTHER); SC <- c(SUB, WHR_OTHER)
fg <- alloc(GC); fs <- alloc(SC)

#' pooled decomposition: share of `den` in FY2013-15 vs FY2023-25, plus a total row for `wt`
dec <- function(M, den, total, wt) {
  R <- data.table(Topic = colnames(M), pct_2013_15 = 100 * colSums(M[A, ]) / sum(den[A]), pct_2023_25 = 100 * colSums(M[B, ]) / sum(den[B]))
  R[, change_pts := pct_2023_25 - pct_2013_15]; setorder(R, -change_pts)
  rbind(R, data.table(Topic = total, pct_2013_15 = 100 * sum(wt[A]) / sum(den[A]), pct_2023_25 = 100 * sum(wt[B]) / sum(den[B]))[
    , change_pts := pct_2023_25 - pct_2013_15])
}
DG_N <- dec(fg, NIH, "TOTAL WHR (% of NIH)", WT); DS_N <- dec(fs, NIH, "TOTAL WHR (% of NIH)", WT)
DG_W <- dec(fg, WT, "TOTAL", WT); DS_W <- dec(fs, WT, "TOTAL", WT)
excl_w <- function(mask) yv(D[!mask, .(sum(USD)), keyby = FY]) + IMP
w3 <- excl_w(m3); wk <- excl_w(mk)
fg3 <- alloc(GC, !m3); fgk <- alloc(GC, !mk); fs3 <- alloc(SC, !m3); fsk <- alloc(SC, !mk)
DX3 <- dec(fg3, NIH, "TOTAL WHR excl. 3M (% of NIH)", w3); DXK <- dec(fgk, NIH, "TOTAL WHR excl. all key awards (% of NIH)", wk)

# ---- trends -----------------------------------------------------------------------------------
TR <- rbindlist(lapply(list(list("frac", fg, fs, NIH, "% of NIH"), list("frac", fg, fs, WT, "% of WHR"),
                            list("frac excl. 3M", fg3, fs3, NIH, "% of NIH"), list("frac excl. key awards", fgk, fsk, NIH, "% of NIH")), function(b)
  rbindlist(lapply(c(GC, SUB), function(t) { s <- 100 * (if (t %in% GC) b[[2]][, t] else b[[3]][, t]) / b[[4]]
    rbindlist(lapply(list(c(2013, 2025), c(2013, 2026)), function(yy) rbindlist(lapply(1:2, function(lag) {
      k <- Y0 >= yy[1] & Y0 <= yy[2]; r <- nw_trend(s[k], Y0[k], lag)
      data.table(Basis = b[[1]], Denominator = b[[5]], Level = if (t %in% GC) "Group" else "Subtopic", Topic = t,
                 Years = paste(yy, collapse = "-"), NW_lag = lag, slope_pts_per_yr = r$slope, CI_lo = r$ci_low, CI_hi = r$ci_high, p = r$p) }))))
  }))))

# ---- predominant vs profound categories (Figure 2 and the categorization paragraph) ----------
#' Following the NASEM 2024 condition matrix (A New Vision for Women's Health Research, Table 7-1):
#'   PREDOMINANT = conditions affecting women exclusively or mostly (female-specific, maternal,
#'                 female cancers, female-predominant conditions);
#'   PROFOUND    = conditions with a large share of women's morbidity/mortality burden.
#' "Cardiovascular / metabolic in women" is split into CVD and diabetes/obesity with the same
#' rule (title hit, or >= 2 hits in the text). Dollars are split equally across matched
#' categories (category series) or matched subtopics (subtopic series).
CAT_NEW <- list(`Cardiovascular disease` = r"(cardiovascular|heart disease|heart failure|hypertension|stroke|coronary|cardiac|atheroscler|cardiomyopath|myocardial|arrhythmi|atrial fibrillation|cardiometabolic)",
                `Diabetes / obesity` = r"(diabetes|diabetic|obesity|obese|insulin resistance)")
for (s in names(CAT_NEW)) set(D, j = s, value = has_match(D$title_l, CAT_NEW[[s]]) | n_match(D$text, CAT_NEW[[s]]) >= 2)
PRED <- c(WHR_TOPICS[group %in% c("1 Female-specific conditions", "2 Maternal / pregnancy health", "3 Female cancers")]$subtopic,
          "Autoimmune (lupus, RA, MS, Sjogren, scleroderma)", "Thyroid", "Migraine / chronic pain / fibromyalgia", "Urinary incontinence / UTI")
PROF <- c("Cardiovascular disease", "Alzheimer's / dementia / cognitive aging", "Depression / anxiety / PTSD / eating disorders", "Osteoporosis / bone", "Diabetes / obesity")
CROSS <- c("Sex-differences biology", "Women's cohorts (WHI, Nurses' Health)", "HIV / STIs in women", "Substance use / alcohol / tobacco",
           "Intimate partner violence / sexual assault", "Health equity / social determinants in women")
CATS <- list(Predominant = PRED, Profound = PROF, `Cross-cutting` = CROSS)
for (k in names(CATS)) set(D, j = k, value = rowSums(D[, CATS[[k]], with = FALSE]) > 0)
D[, Unclassified := rowSums(.SD) == 0, .SDcols = names(CATS)]
fcat <- alloc(c(names(CATS), "Unclassified")); fcs <- alloc(c(PRED, PROF, CROSS, "Unclassified"))
fcat[, "Unclassified"] <- fcat[, "Unclassified"] + fcat[, IMPN]; fcs[, "Unclassified"] <- fcs[, "Unclassified"] + fcs[, IMPN]
fcat <- fcat[, colnames(fcat) != IMPN]; fcs <- fcs[, colnames(fcs) != IMPN]
stopifnot(isTRUE(all.equal(unname(rowSums(fcat)), unname(WT))), isTRUE(all.equal(unname(rowSums(fcs)), unname(WT))))
pool <- function(v, den, yy) 100 * sum(v[yy]) / sum(den[yy])
anyc <- function(t) yv(D[get(t) == TRUE, .(sum(USD)), keyby = FY])
CT <- rbindlist(lapply(c(names(CATS), "Unclassified", PRED, PROF, CROSS), function(t) {
  v <- if (t %in% colnames(fcat)) fcat[, t] else fcs[, t]
  rbindlist(lapply(list(list("% of WHR", WT), list("% of NIH", NIH)), function(d) { s <- 100 * v / d[[2]]; k <- Y0 <= 2025; r <- nw_trend(s[k], Y0[k], 1)
    data.table(Category = if (t %in% PRED) "Predominant" else if (t %in% PROF) "Profound" else if (t %in% CROSS) "Cross-cutting" else "(category)",
      Topic = t, Denominator = d[[1]], pct_2013_15 = pool(v, d[[2]], A), pct_2023_25 = pool(v, d[[2]], B),
      slope_pts_per_yr = r$slope, CI_lo = r$ci_low, CI_hi = r$ci_high, p = r$p) })) }))
rnd <- function(x, d = 4) { x <- copy(x); for (j in names(x)) if (is.numeric(x[[j]])) set(x, j = j, value = round(x[[j]], d)); x }
saveRDS(list(fg = fg, fs = fs, NIH = NIH, WT = WT, fcat = fcat, fcs = fcs, PRED = PRED, PROF = PROF), work_path("topics", "whr_topics.rds"))
openxlsx::write.xlsx(list(Scheme = rbindlist(lapply(names(CATS), function(k) data.table(Category = k, Subtopic = CATS[[k]]))), Summary = rnd(CT)),
                     out_path("whr_categories_predominant_profound.xlsx"))
openxlsx::write.xlsx(list(Dictionary = WHR_TOPICS, Totals = rnd(data.table(FY = Y0, WHR_B = WT / 1e9, NIH_B = NIH / 1e9, WHR_pct_NIH = 100 * WT / NIH,
  imputed_B = IMP / 1e9, WHR_excl_3M_pct = 100 * w3 / NIH, WHR_excl_key_pct = 100 * wk / NIH)),
  Decomp_groups_NIH = rnd(DG_N), Decomp_subtopics_NIH = rnd(DS_N), Decomp_groups_WHR = rnd(DG_W), Decomp_subtopics_WHR = rnd(DS_W),
  Decomp_groups_excl_3M = rnd(DX3), Decomp_groups_excl_key = rnd(DXK), Trends = rnd(TR)), out_path("whr_topic_trends.xlsx"))

# ---- key numbers quoted in the report ------------------------------------------------------
kn <- list(); add <- function(id, v) kn[[length(kn) + 1]] <<- data.table(id = id, value = v)
dv <- function(tab, t, col) tab[Topic == t][[col]]
tr <- function(basis, den, t) TR[Basis == basis & Denominator == den & Topic == t & Years == "2013-2025" & NW_lag == 1]
add("whr_project_years", nrow(D)); add("whr_n_groups", length(GRP)); add("whr_n_subtopics", length(SUB))
add("nih_B_2013", V[FY == 2013]$nih_B); add("nih_B_2023", V[FY == 2023]$nih_B)
add("v3_pct_min", min(V$v3_pct)); add("v3_pct_max", max(V$v3_pct))
add("strict_pct_min", min(V$strict_sexdiff_pct)); add("strict_pct_max", max(V$strict_sexdiff_pct))
add("nasemcomp_pct_min", min(V$nasem_comp_pct)); add("nasemcomp_pct_max", max(V$nasem_comp_pct))
add("pooled_1315", dv(DG_N, "TOTAL WHR (% of NIH)", "pct_2013_15")); add("pooled_2325", dv(DG_N, "TOTAL WHR (% of NIH)", "pct_2023_25"))
add("pooled_exclkey_1315", dv(DXK, "TOTAL WHR excl. all key awards (% of NIH)", "pct_2013_15")); add("pooled_exclkey_2325", dv(DXK, "TOTAL WHR excl. all key awards (% of NIH)", "pct_2023_25"))
add("femcancer_1315", dv(DG_N, "3 Female cancers", "pct_2013_15")); add("femcancer_2325", dv(DG_N, "3 Female cancers", "pct_2023_25"))
r <- tr("frac", "% of NIH", "3 Female cancers"); add("femcancer_trend", r$slope_pts_per_yr); add("femcancer_trend_lo", r$CI_lo); add("femcancer_trend_hi", r$CI_hi)
add("breast_share_whr_1315", dv(DS_W, "Breast cancer", "pct_2013_15")); add("breast_share_whr_2325", dv(DS_W, "Breast cancer", "pct_2023_25"))
add("violence_1315", dv(DG_N, "6 Violence / social determinants", "pct_2013_15")); add("violence_2325", dv(DG_N, "6 Violence / social determinants", "pct_2023_25"))
add("violence_change", dv(DG_N, "6 Violence / social determinants", "change_pts"))
add("sexdiffgrp_change", dv(DG_N, "5 Sex differences / conditions affecting women differently", "change_pts"))
add("fempred_change", dv(DG_N, "4 Female-predominant conditions", "change_pts"))
add("maternal_change", dv(DG_N, "2 Maternal / pregnancy health", "change_pts"))
add("maternal_trend_p", tr("frac", "% of NIH", "2 Maternal / pregnancy health")$p)
add("maternal_exclkey_change", dv(DXK, "2 Maternal / pregnancy health", "change_pts"))
r <- tr("frac excl. key awards", "% of NIH", "2 Maternal / pregnancy health"); add("maternal_exclkey_trend", r$slope_pts_per_yr); add("maternal_exclkey_trend_lo", r$CI_lo); add("maternal_exclkey_trend_hi", r$CI_hi)
add("femspec_change", dv(DG_N, "1 Female-specific conditions", "change_pts")); add("femspec_trend_p", tr("frac", "% of NIH", "1 Female-specific conditions")$p)
add("other_change", dv(DG_N, WHR_OTHER, "change_pts"))
for (x in list(c("equity", "Health equity / social determinants in women"), c("sexdiffbio", "Sex-differences biology"), c("substance", "Substance use / alcohol / tobacco"),
               c("postpartum", "Postpartum / lactation / breastfeeding"), c("cervical", "Cervical cancer / HPV"), c("alzheimer", "Alzheimer's / dementia / cognitive aging"),
               c("breast", "Breast cancer"), c("cohorts", "Pregnancy cohorts / prenatal exposures (ECHO, nuMoM2b)"), c("hiv", "HIV / STIs in women"),
               c("vulvo", "Vulvovaginal / pelvic floor / gyn conditions"), c("ovarian", "Ovarian cancer")))
  add(paste0("sub_whr_change_", x[1]), dv(DS_W, x[2], "change_pts"))
ct <- function(t, d, col) CT[Topic == t & Denominator == d][[col]]
add("cat_pred_whr_1315", ct("Predominant", "% of WHR", "pct_2013_15")); add("cat_pred_whr_2325", ct("Predominant", "% of WHR", "pct_2023_25"))
add("cat_prof_whr_1315", ct("Profound", "% of WHR", "pct_2013_15")); add("cat_prof_whr_2325", ct("Profound", "% of WHR", "pct_2023_25"))
add("cat_prof_whr_trend", ct("Profound", "% of WHR", "slope_pts_per_yr")); add("cat_prof_whr_trend_lo", ct("Profound", "% of WHR", "CI_lo")); add("cat_prof_whr_trend_hi", ct("Profound", "% of WHR", "CI_hi"))
add("cvd_whr_1315", ct("Cardiovascular disease", "% of WHR", "pct_2013_15")); add("cvd_whr_2325", ct("Cardiovascular disease", "% of WHR", "pct_2023_25"))
add("cvd_whr_trend", ct("Cardiovascular disease", "% of WHR", "slope_pts_per_yr")); add("cvd_whr_trend_lo", ct("Cardiovascular disease", "% of WHR", "CI_lo")); add("cvd_whr_trend_hi", ct("Cardiovascular disease", "% of WHR", "CI_hi"))
cva <- anyc("Cardiovascular disease"); add("cvd_any_whr_1315", pool(cva, WT, A)); add("cvd_any_whr_2325", pool(cva, WT, B))
add("alz_cat_whr_1315", ct("Alzheimer's / dementia / cognitive aging", "% of WHR", "pct_2013_15")); add("alz_cat_whr_2325", ct("Alzheimer's / dementia / cognitive aging", "% of WHR", "pct_2023_25"))
fwrite(rbindlist(kn), out_path("key_numbers_topics.csv"))
print(rnd(DG_N, 3)); print(rnd(DXK, 3))
