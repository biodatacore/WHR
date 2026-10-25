#' 05_topics.R -- topic decomposition of women's cardiovascular research funding.
#'
#' UNIVERSE  Women's CV research = projects in the broad CV tier AND the partial-tier-v3 WHR
#'           tier (per-project counting; work_dir/cv/G.rds), FY2013-2026 (2026 incomplete).
#' TEXT      Project title + abstract + PHR of all rows of the project (work_dir/proj), the
#'           same text used for classification.
#' TAGGING   Multi-label keyword dictionary (R/topics_cv.R): a topic is assigned if its pattern
#'           is in the title or occurs >= 2 times in the text (>= 1 for rare conditions).
#'           "Other / general women's CV" = no topic matched.
#' MEASURES  any  = full project dollars counted in every matching topic (overlapping);
#'           frac = project dollars split equally among its topics (sums exactly to the women's
#'                  CV total; used for the decomposition and Figure 2).
#' ANALYSES  * pooled dollar-weighted topic share of ALL broad-CV funding, FY2013-2015 vs
#'             FY2023-2025, and each topic's contribution to the change;
#'           * the same excluding the NHLBI Maternal Morbidity & Mortality (3M)/IMPROVE
#'             coordinating award (core project OT2HL158287);
#'           * OLS trends of topic share of CV funding on FY with Newey-West SEs (lags 1, 2),
#'             FY2013-2025 (main) and FY2013-2026;
#'           * topic share of women's CV funding by year (bottom row of Figure 2).
#' CAVEAT    Topic results are indicative: matches were spot-checked, not manually coded.
#'
#' INPUTS   work_dir/cv/G.rds, work_dir/cv/R.rds, work_dir/proj/proj_{FY}.rds
#' OUTPUTS  work_dir/topics/cv_topics.rds (tagged projects + yearly tables, for 06_figures.R)
#'          out_dir/topic_trends_cv.xlsx; out_dir/key_numbers_topics.csv

source("R/00_setup.R")
source("R/topics_cv.R")
TP <- names(CV_TOPICS); TA <- c(TP, CV_OTHER)
Y0 <- CONFIG$years; A <- CONFIG$pooled_early; B <- CONFIG$pooled_late

# ---- universe and text --------------------------------------------------------------------
G <- readRDS(work_path("cv", "G.rds"))
W <- G[cv & t3, .(FY, FULL_PROJECT_NUM, USD)]
P <- rbindlist(lapply(Y0, function(y) readRDS(work_path("proj", sprintf("proj_%d.rds", y)))[
  , .(FY = y, FULL_PROJECT_NUM, PROJECT_TITLE, text, IC, ACT, CORE_PROJECT_NUM)]))
D <- merge(W, P, by = c("FY", "FULL_PROJECT_NUM"), all.x = TRUE, sort = FALSE)
D[, text := fifelse(is.na(text), "", lower(text))]
D[, title_l := lower(PROJECT_TITLE)]
say("women's CV project-years: ", nrow(D))

# ---- tagging -------------------------------------------------------------------------------
for (k in TP) {
  need <- if (k %in% CV_TOPICS_ONE) 1 else 2
  set(D, j = k, value = has_match(D$title_l, CV_TOPICS[[k]]) | n_match(D$text, CV_TOPICS[[k]]) >= need)
}
D[, (CV_OTHER) := rowSums(.SD) == 0, .SDcols = TP]
D[, n_topics := rowSums(.SD), .SDcols = TP]

# ---- denominators ----------------------------------------------------------------------------
Rcv <- readRDS(work_path("cv", "R.rds"))[CV_tier == "broad"]
CVT <- setNames(Rcv$CV_proj_B * 1e9, Rcv$FY)                       # all broad-CV dollars by FY
WT <- D[, .(u = sum(USD)), keyby = FY]; WT <- setNames(WT$u, WT$FY)   # women's CV dollars by FY
stopifnot(isTRUE(all.equal(unname(WT / 1e9), Rcv$`Partial tier v3 B`, tolerance = 1e-9)))

#' Fractional allocation: each project's dollars split equally among its matched topics
#' (incl. the residual); returns a FY x topic matrix of dollars.
alloc <- function(d) {
  M <- as.matrix(d[, ..TA]) * 1; M <- M / rowSums(M) * d$USD
  out <- rowsum(M, d$FY); out <- out[match(Y0, rownames(out)), , drop = FALSE]; out[is.na(out)] <- 0
  rownames(out) <- Y0; out
}
frac <- alloc(D)
anyd <- sapply(TA, function(t) { s <- D[get(t) == TRUE, .(u = sum(USD)), keyby = FY]; v <- setNames(numeric(length(Y0)), Y0); v[as.character(s$FY)] <- s$u; v })
cnt <- sapply(TA, function(t) { s <- D[get(t) == TRUE, .N, keyby = FY]; v <- setNames(integer(length(Y0)), Y0); v[as.character(s$FY)] <- s$N; v })

# yearly table (long)
Yt <- rbindlist(lapply(TA, function(t) data.table(Topic = t, FY = Y0, Projects = cnt[, t], USD_M_any = anyd[, t] / 1e6,
  USD_M_frac = frac[, t] / 1e6, pct_of_WCV_any = 100 * anyd[, t] / WT, pct_of_WCV_frac = 100 * frac[, t] / WT,
  pct_of_CV_any = 100 * anyd[, t] / CVT, pct_of_CV_frac = 100 * frac[, t] / CVT)))

# ---- decomposition: pooled dollar-weighted share of all CV funding ---------------------------
pooled <- function(M, yrs) 100 * colSums(M[as.character(yrs), , drop = FALSE]) / sum(CVT[as.character(yrs)])
decomp <- function(M, wt, total_name) {
  R <- data.table(Topic = colnames(M), pct_of_CV_2013_15 = pooled(M, A), pct_of_CV_2023_25 = pooled(M, B))
  R[, change_pts := pct_of_CV_2023_25 - pct_of_CV_2013_15]
  setorder(R, -change_pts)
  tot <- data.table(Topic = total_name, pct_of_CV_2013_15 = 100 * sum(wt[as.character(A)]) / sum(CVT[as.character(A)]),
                    pct_of_CV_2023_25 = 100 * sum(wt[as.character(B)]) / sum(CVT[as.character(B)]))
  tot[, change_pts := pct_of_CV_2023_25 - pct_of_CV_2013_15]
  R[, share_of_total_change_pct := 100 * change_pts / sum(change_pts)]
  rbind(R, tot, fill = TRUE)
}
DEC <- decomp(frac, WT, "TOTAL (women's CV share)")
m3 <- !is.na(D$CORE_PROJECT_NUM) & D$CORE_PROJECT_NUM == "OT2HL158287"     # 3M / IMPROVE coordinating award
frac_x <- alloc(D[!m3]); WX <- WT - tapply(D$USD[m3], factor(D$FY[m3], levels = Y0), sum, default = 0)
DX <- decomp(frac_x, WX, "TOTAL excl. 3M")
M3 <- D[m3, .(USD_M = sum(USD) / 1e6), keyby = FY]
M3[, `:=`(pct_of_CV = 100 * USD_M * 1e6 / CVT[as.character(FY)], pct_of_WCV = 100 * USD_M * 1e6 / WT[as.character(FY)])]

# ---- trends: OLS of topic share of CV funding on FY, Newey-West lags 1 and 2 ----------------
TR <- list()
for (basis in c("frac", "any-mention")) {
  M <- if (basis == "frac") frac else anyd
  for (t in TA) for (yy in list(c(2013, 2025), c(2013, 2026))) for (lag in 1:2) {
    k <- Y0 >= yy[1] & Y0 <= yy[2]; r <- nw_trend(100 * M[k, t] / CVT[k], Y0[k], lag)
    TR[[length(TR) + 1]] <- data.table(Basis = basis, Topic = t, Years = paste(yy, collapse = "-"), NW_lag = lag,
                                       slope_pts_per_yr = r$slope, CI_lo = r$ci_low, CI_hi = r$ci_high, p = r$p)
  }
}
TR <- rbindlist(TR)

# share of women's CV funding by topic and year (bottom row of Figure 2)
WSH <- 100 * frac / WT

saveRDS(list(D = D[, c("FY", "FULL_PROJECT_NUM", "CORE_PROJECT_NUM", "USD", TA, "n_topics"), with = FALSE],
             frac = frac, frac_x = frac_x, CVT = CVT, WT = WT, WSH = WSH, DEC = DEC, DX = DX, TR = TR),
        work_path("topics", "cv_topics.rds"))
rnd <- function(x, d = 4) { x <- copy(x); for (j in names(x)) if (is.numeric(x[[j]])) set(x, j = j, value = round(x[[j]], d)); x }
openxlsx::write.xlsx(list(Dictionary = data.table(Topic = TP, Regex = unname(CV_TOPICS),
                                                  Rule = ifelse(TP %in% CV_TOPICS_ONE, ">=1 hit anywhere", "title hit, or >=2 hits in text")),
                          Yearly = rnd(Yt), Decomposition = rnd(DEC), Decomp_excl_3M = rnd(DX), `3M_IMPROVE_award` = rnd(M3), Trends = rnd(TR)),
                     out_path("topic_trends_cv.xlsx"))

# ---- key numbers quoted in the report --------------------------------------------------------
kn <- list(); add <- function(id, v) kn[[length(kn) + 1]] <<- data.table(id = id, value = v)
dv <- function(tab, t, col) tab[Topic == t][[col]]
add("wcv_project_years", nrow(D))
for (y in c(2013, 2023, 2025)) { add(sprintf("cv_B_%d", y), Rcv[FY == y]$CV_proj_B); add(sprintf("wcv_pct_%d", y), Rcv[FY == y]$`Partial tier v3 pct_B`) }
add("cv_share_nih_mean", mean(Rcv$CV_share_NIH_pct))
add("wcv_n_topics_incl_other", length(TA))
add("wcv_pooled_1315", dv(DEC, "TOTAL (women's CV share)", "pct_of_CV_2013_15"))
add("wcv_pooled_2325", dv(DEC, "TOTAL (women's CV share)", "pct_of_CV_2023_25"))
add("wcv_pooled_change", dv(DEC, "TOTAL (women's CV share)", "change_pts"))
for (x in list(c("lifestyle", "Lifestyle, obesity & social determinants in women"), c("matmort", "Maternal mortality / severe maternal morbidity"),
               c("sexdiff", "Sex differences / female-specific mechanisms"), c("hdp", "Hypertensive disorders of pregnancy"))) {
  add(paste0("dec_", x[1], "_change"), dv(DEC, x[2], "change_pts"))
  add(paste0("decx3m_", x[1], "_change"), dv(DX, x[2], "change_pts"))
}
add("dec_lifestyle_share_of_gain", dv(DEC, "Lifestyle, obesity & social determinants in women", "share_of_total_change_pct"))
spec <- c("Coronary microvascular dysfunction / INOCA / MINOCA", "Peripartum cardiomyopathy", "SCAD", "Takotsubo / stress cardiomyopathy")
add("dec_specific_conditions_share_of_gain_pct", sum(DEC[Topic %in% spec]$change_pts) / dv(DEC, "TOTAL (women's CV share)", "change_pts") * 100)
add("m3_total_musd", sum(M3$USD_M)); add("m3_first_fy", min(M3$FY)); add("m3_last_fy", max(M3$FY))
add("m3_pts_of_gain", dv(DEC, "TOTAL (women's CV share)", "change_pts") - dv(DX, "TOTAL excl. 3M", "change_pts"))
add("wcv_excl3m_pooled_1315", dv(DX, "TOTAL excl. 3M", "pct_of_CV_2013_15")); add("wcv_excl3m_pooled_2325", dv(DX, "TOTAL excl. 3M", "pct_of_CV_2023_25"))
add("takotsubo_usd_after_2016", sum(frac[as.character(2017:2026), "Takotsubo / stress cardiomyopathy"]))
add("menopause_share_wcv_2013", WSH["2013", "Menopause / sex hormones & CVD"]); add("menopause_share_wcv_2025", WSH["2025", "Menopause / sex hormones & CVD"])
add("placental_share_wcv_2013", WSH["2013", "Placental / maternal-fetal vascular biology"]); add("placental_share_wcv_2025", WSH["2025", "Placental / maternal-fetal vascular biology"])
tp <- function(t) TR[Basis == "frac" & Topic == t & Years == "2013-2025" & NW_lag == 1]
add("trend_menopause_p", tp("Menopause / sex hormones & CVD")$p); add("trend_placental_p", tp("Placental / maternal-fetal vascular biology")$p)
fwrite(rbindlist(kn), out_path("key_numbers_topics.csv"))
print(rnd(DEC[, .(Topic, pct_of_CV_2013_15, pct_of_CV_2023_25, change_pts)], 3))
print(rnd(DX[, .(Topic, change_pts)], 3)[1:6])
