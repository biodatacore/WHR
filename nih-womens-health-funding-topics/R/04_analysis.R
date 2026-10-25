#' 04_analysis.R -- statistical analysis of the yearly WHR share (Supplementary Methods S11).
#'
#' DATA     Project-level table from 03_classify.R: NIH projects with dollars > 0, one row per
#'          project-year. WHR = partial tier v3 (main), with strict + sex differences and
#'          NASEM-comparable as sensitivity definitions. Periods FY2013-2026 (main; FY2026
#'          incomplete) and FY2013-2025.
#'          Group: All NIH.
#'
#' METHODS
#'   S11.1 OLS of the yearly WHR % of dollars on (FY - 2013) with Newey-West standard errors
#'         (lags 1 and 2; lag 1 reported), and the Durbin-Watson statistic of the residuals.
#'   S11.2 Joinpoint-style segmented regression of log(% of dollars) on FY with 0, 1 or 2
#'         continuous breakpoints at interior years (not the first/last two years; >= 3 years
#'         apart), chosen by BIC counting each breakpoint as an extra parameter.
#'         APC = 100 (exp(slope) - 1); AAPC = 100 (exp(length-weighted mean slope) - 1); 95% CIs
#'         conditional on the chosen breakpoints (normal approximation). NCI's Joinpoint
#'         software was not used; this is an exhaustive grid search over integer breakpoints.
#'   Pooled shares: WHR % of NIH funding pooled over FY2013-2015 and FY2023-2025 (with the
#'   imputation, i.e. exactly the yearly series of Figure 1) are computed in 05_topics.R.
#'   The trend tests use classified projects WITHOUT the intramural no-text imputation (the
#'   published convention), so FY2020/2024 shares here are ~0.1 pp below Figure 1.
#'   The bootstrap confidence intervals of the Supplementary Methods (S11.5) are not reported
#'   in the brief report and are not reproduced here.
#'
#' INPUTS   work_dir/whr/G.rds
#' OUTPUTS  work_dir/stats.rds; out_dir/stats_results.xlsx; out_dir/key_numbers_stats.csv

source("R/00_setup.R")

MET <- c(t3 = "Partial tier v3 (main)", base = "Strict + sex differences", tnc = "NASEM-comparable")
PERIODS <- list(list(c(2013, 2026), "2013-2026 (2026 incomplete)"), list(c(2013, 2025), "2013-2025"))

G <- readRDS(work_path("whr", "G.rds"))
G <- G[!is.na(USD) & USD > 0]          # projects with no reported dollars carry no weight in $ shares
G[, core := sub("-.*$", "", sub("^[0-9]", "", FULL_PROJECT_NUM))]
G[, fyc := FY - 2013]                  # centred so intercepts refer to FY2013
GR <- list(`All NIH` = function(d) d)

#' WHR % of dollars per FY (named by year).
yearly_pct <- function(d, m) { s <- d[, .(p = 100 * sum(USD * get(m)) / sum(USD)), keyby = FY]; setNames(s$p, s$FY) }

#' S11.2 segmented regression (see header). Returns one row per segment plus the AAPC row.
segmented <- function(s, ml, yl, gn) {
  yv <- log(unname(s)); xv <- as.numeric(names(s)); n <- length(yv)
  inner <- xv[3:(n - 2)]
  cands <- c(list(numeric(0)), as.list(inner),
             Filter(function(b) b[2] - b[1] >= 3, combn(inner, 2, simplify = FALSE)))
  best <- NULL
  for (bk in cands) {
    X <- do.call(cbind, c(list(1, xv - 2013), lapply(bk, function(b) pmax(xv - b, 0))))
    fit <- lm.fit(X, yv); ssr <- sum(fit$residuals^2)
    bic <- n * log(ssr / n) + (ncol(X) + length(bk)) * log(n)
    if (is.null(best) || bic < best$bic) best <- list(bic = bic, bk = bk, X = X, fit = fit, ssr = ssr)
  }
  X <- best$X; b <- best$fit$coefficients; bk <- best$bk
  cov <- best$ssr / (n - ncol(X)) * solve(crossprod(X))        # classical OLS covariance
  edges <- c(xv[1], bk, xv[n]); out <- list(); L <- list(); w <- numeric(0)
  apc <- function(l) { e <- sum(l * b); se <- sqrt(drop(t(l) %*% cov %*% l))
    100 * (exp(c(e, e - 1.96 * se, e + 1.96 * se)) - 1) }
  for (i in seq_len(length(edges) - 1)) {
    l <- numeric(ncol(X)); l[2] <- 1; if (i > 1) l[3:(1 + i)] <- 1
    L[[i]] <- l; w[i] <- edges[i + 1] - edges[i]
    a <- apc(l)
    out[[i]] <- data.table(Method = ml, Years = yl, Group = gn, n_breakpoints = length(bk),
                           breakpoints = if (length(bk)) paste(bk, collapse = ",") else "-",
                           segment = sprintf("%d-%d", edges[i], edges[i + 1]), APC = a[1], CI_low = a[2], CI_high = a[3], BIC = best$bic)
  }
  la <- Reduce(`+`, Map(`*`, L, w)) / sum(w); a <- apc(la)
  out[[length(out) + 1]] <- data.table(Method = ml, Years = yl, Group = gn, n_breakpoints = length(bk),
                                       breakpoints = if (length(bk)) paste(bk, collapse = ",") else "-",
                                       segment = "AAPC (full period)", APC = a[1], CI_low = a[2], CI_high = a[3], BIC = best$bic)
  rbindlist(out)
}

T1 <- list(); T2 <- list(); T3 <- list(); T4 <- list(); T5 <- list(); T6 <- list()
for (m in names(MET)) {
  ml <- MET[[m]]
  for (per in PERIODS) {
    yrs <- per[[1]]; yl <- per[[2]]
    D <- G[FY >= yrs[1] & FY <= yrs[2]]
    for (gn in names(GR)) {
      d <- GR[[gn]](D); s <- yearly_pct(d, m)
      for (lag in 1:2) {                                                          # S11.1
        r <- nw_trend(unname(s), as.numeric(names(s)), lag)
        T1[[length(T1) + 1]] <- data.table(Method = ml, Years = yl, Group = gn, NW_lag = lag, slope_pp_per_yr = r$slope,
                                           CI_low = r$ci_low, CI_high = r$ci_high, p = r$p, DW = r$dw)
      }
      T2[[length(T2) + 1]] <- segmented(s, ml, yl, gn)                             # S11.2
    }
  }
}
S <- list(`OLS trend (Newey-West)` = rbindlist(T1), `Segmented (joinpoint-style)` = rbindlist(T2))
saveRDS(S, work_path("stats.rds"))
openxlsx::write.xlsx(lapply(S, function(v) { v <- copy(v); for (j in names(v)) if (is.numeric(v[[j]])) set(v, j = j, value = round(v[[j]], 5)); v }),
                     out_path("stats_results.xlsx"))

# ---- key numbers quoted in the report (checked by 07_verify.R) ----------------------------
main <- "Partial tier v3 (main)"; P1 <- "2013-2026 (2026 incomplete)"; P2 <- "2013-2025"
o1 <- S$`OLS trend (Newey-West)`; o2 <- S$`Segmented (joinpoint-style)`
kn <- list()
add <- function(id, v) kn[[length(kn) + 1]] <<- data.table(id = id, value = v)
pick <- function(tab, ...) { f <- list(...); r <- tab; for (k in names(f)) r <- r[r[[k]] == f[[k]]]; stopifnot(nrow(r) == 1); r }
for (gn in names(GR)) {
  tag <- gsub("[^a-z]", "", tolower(gn))
  for (pp in list(c(P1, "1326"), c(P2, "1325"))) {
    r <- pick(o1, Method = main, Years = pp[1], Group = gn, NW_lag = 1)
    add(sprintf("ols_%s_%s_slope", tag, pp[2]), r$slope_pp_per_yr); add(sprintf("ols_%s_%s_lo", tag, pp[2]), r$CI_low); add(sprintf("ols_%s_%s_hi", tag, pp[2]), r$CI_high)
  }
  r <- pick(o2, Method = main, Years = P1, Group = gn, segment = "AAPC (full period)")
  add(sprintf("aapc_%s_1326", tag), r$APC); add(sprintf("aapc_%s_1326_lo", tag), r$CI_low); add(sprintf("aapc_%s_1326_hi", tag), r$CI_high)
  add(sprintf("seg_%s_1326_first_apc", tag), o2[Method == main & Years == P1 & Group == gn][1]$APC)
  add(sprintf("seg_%s_1326_second_apc", tag), o2[Method == main & Years == P1 & Group == gn][2]$APC)
}
r <- pick(o1, Method = MET[["base"]], Years = P1, Group = "All NIH", NW_lag = 1); add("ols_allnih_1326_strict_slope", r$slope_pp_per_yr)
fwrite(rbindlist(kn), out_path("key_numbers_stats.csv"))
print(o1[Method == main & NW_lag == 1, .(Years, Group, slope = round(slope_pp_per_yr, 3), lo = round(CI_low, 3), hi = round(CI_high, 3))])
