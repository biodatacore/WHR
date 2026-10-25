#' 04_analysis.R -- statistical analysis of the yearly WHR share (Supplementary Methods S11).
#'
#' DATA     Project-level table from 03_classify.R: NIH projects with dollars > 0, one row per
#'          project-year. WHR = partial tier v3 (main), with strict + sex differences and
#'          NASEM-comparable as sensitivity definitions. Periods FY2013-2026 (main; FY2026
#'          incomplete) and FY2013-2025.
#'          Groups: All NIH, CV (broad CV tier) and non-CV.
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
#'   S11.3 Grant-level logistic regression WHR ~ (FY - 2013), count-weighted and dollar-
#'         weighted (weights = dollars / mean dollars), standard errors clustered by core
#'         project (FULL_PROJECT_NUM without the leading type digit and suffix, so renewals
#'         form one cluster; HC1-type small-sample factor).
#'   S11.4 CV vs non-CV: logistic WHR ~ (FY - 2013) * CV (clustered as above), yearly OLS
#'         pct ~ (FY - 2013) * CV with Newey-West SEs, and per-year two-proportion z tests
#'         (counts, pooled variance) with Benjamini-Hochberg FDR across the 14 years.
#'   The grant-level analyses use classified projects WITHOUT the intramural no-text
#'   imputation, so FY2020/2024 all-NIH shares are ~0.1 pp below Figure 1 of the WHR report.
#'   The bootstrap confidence intervals of the Supplementary Methods (S11.5) are not reported
#'   in the brief report and are not reproduced here.
#'
#' INPUTS   work_dir/cv/G.rds
#' OUTPUTS  work_dir/stats.rds; out_dir/stats_results.xlsx; out_dir/key_numbers_stats.csv

source("R/00_setup.R")

MET <- c(t3 = "Partial tier v3 (main)", base = "Strict + sex differences", tnc = "NASEM-comparable")
PERIODS <- list(list(c(2013, 2026), "2013-2026 (2026 incomplete)"), list(c(2013, 2025), "2013-2025"))

G <- readRDS(work_path("cv", "G.rds"))
G <- G[!is.na(USD) & USD > 0]          # projects with no reported dollars carry no weight in $ shares
G[, core := sub("-.*$", "", sub("^[0-9]", "", FULL_PROJECT_NUM))]
G[, fyc := FY - 2013]                  # centred so intercepts refer to FY2013
G[, cv := as.integer(cv)]
GR <- list(`All NIH` = function(d) d, CV = function(d) d[cv == 1], `Non-CV` = function(d) d[cv == 0])

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

#' Logistic GLM with standard errors clustered by core project; returns exp(coef) and CIs.
#' Dollar weights enter as prior weights (= variance weights); R warns about non-integer
#' "successes" with fractional weights, which is expected and harmless here.
clustered_logit <- function(formula, d, dollar) {
  d[, w_ := if (dollar) USD / mean(USD) else 1]
  fit <- suppressWarnings(glm(formula, family = binomial(), data = d, weights = w_))
  V <- sandwich::vcovCL(fit, cluster = d$core, type = "HC1")
  b <- coef(fit); se <- sqrt(diag(V))
  list(est = exp(b), lo = exp(b - qnorm(0.975) * se), hi = exp(b + qnorm(0.975) * se), p = 2 * pnorm(-abs(b / se)))
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
      for (wl in c("count", "dollar")) {                                          # S11.3
        dd <- copy(d)[, y := as.integer(get(m))]
        r <- clustered_logit(y ~ fyc, dd, wl == "dollar")
        T3[[length(T3) + 1]] <- data.table(Method = ml, Years = yl, Group = gn, Weighting = wl, OR_per_year = r$est[["fyc"]],
                                           CI_low = r$lo[["fyc"]], CI_high = r$hi[["fyc"]], p = r$p[["fyc"]],
                                           n_grants = nrow(dd), n_clusters = uniqueN(dd$core))
      }
    }
    for (wl in c("count", "dollar")) {                                            # S11.4 logistic
      dd <- copy(D)[, y := as.integer(get(m))]
      r <- clustered_logit(y ~ fyc * cv, dd, wl == "dollar")
      for (k in list(c("cv", "CV vs non-CV, level at FY2013 (OR)"), c("fyc:cv", "CV vs non-CV, trend (ratio of ORs per year)"),
                     c("fyc", "Non-CV trend (OR per year)")))
        T4[[length(T4) + 1]] <- data.table(Method = ml, Years = yl, Weighting = wl, Term = k[2], Estimate = r$est[[k[1]]],
                                           CI_low = r$lo[[k[1]]], CI_high = r$hi[[k[1]]], p = r$p[[k[1]]])
    }
    # S11.4 yearly OLS with interaction; rows ordered non-CV years then CV years (the HAC
    # estimator uses row order as time order, exactly as in the published analysis)
    Y <- rbindlist(lapply(0:1, function(g) { s <- yearly_pct(D[cv == g], m); data.table(FY = as.numeric(names(s)), pct = unname(s), cv = g) }))
    Y[, fyc := FY - 2013]
    fit <- lm(pct ~ fyc * cv, data = Y)
    for (lag in 1:2) {
      V <- sandwich::NeweyWest(fit, lag = lag, prewhite = FALSE, adjust = FALSE)
      for (k in list(c("cv", "Level difference at FY2013 (pp)"), c("fyc:cv", "Trend difference (pp/yr)"), c("fyc", "Non-CV trend (pp/yr)"))) {
        b <- coef(fit)[[k[1]]]; se <- sqrt(V[k[1], k[1]])
        T5[[length(T5) + 1]] <- data.table(Method = ml, Years = yl, NW_lag = lag, Term = k[2], Estimate = b,
                                           CI_low = b - qnorm(0.975) * se, CI_high = b + qnorm(0.975) * se, p = 2 * pnorm(-abs(b / se)))
      }
    }
  }
  # S11.4 per-year two-proportion z tests (counts), Benjamini-Hochberg across years
  zt <- rbindlist(lapply(CONFIG$years, function(y) {
    d <- G[FY == y]; c1 <- sum(d[[m]][d$cv == 1]); c0 <- sum(d[[m]][d$cv == 0]); n1 <- sum(d$cv == 1); n0 <- sum(d$cv == 0)
    pp <- (c1 + c0) / (n1 + n0); z <- (c1 / n1 - c0 / n0) / sqrt(pp * (1 - pp) * (1 / n1 + 1 / n0))
    data.table(Method = ml, FY = y, CV_WHR = c1, CV_n = n1, CV_pct = 100 * c1 / n1, NonCV_WHR = c0, NonCV_n = n0,
               NonCV_pct = 100 * c0 / n0, z = z, p = 2 * pnorm(-abs(z)))
  }))
  zt[, p_FDR := p.adjust(p, "BH")]
  T6[[length(T6) + 1]] <- zt
}
S <- list(`OLS trend (Newey-West)` = rbindlist(T1), `Segmented (joinpoint-style)` = rbindlist(T2))
S[["Grant-level logistic"]] <- rbindlist(T3)
S[["CV vs non-CV logistic"]] <- rbindlist(T4)
S[["CV vs non-CV yearly OLS"]] <- rbindlist(T5)
S[["Two-proportion tests (FDR)"]] <- rbindlist(T6)
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
o3 <- S$`Grant-level logistic`; o4 <- S$`CV vs non-CV logistic`; o6 <- S$`Two-proportion tests (FDR)`
r <- pick(o3, Method = main, Years = P1, Group = "CV", Weighting = "dollar"); add("logit_cv_dollar_or", r$OR_per_year); add("logit_cv_dollar_lo", r$CI_low); add("logit_cv_dollar_hi", r$CI_high)
r <- pick(o4, Method = main, Years = P1, Weighting = "dollar", Term = "CV vs non-CV, level at FY2013 (OR)"); add("int_level_or", r$Estimate); add("int_level_lo", r$CI_low); add("int_level_hi", r$CI_high)
r <- pick(o4, Method = main, Years = P1, Weighting = "dollar", Term = "CV vs non-CV, trend (ratio of ORs per year)"); add("int_trend_ror", r$Estimate); add("int_trend_lo", r$CI_low); add("int_trend_hi", r$CI_high)
z <- o6[Method == main]
add("ztest_last_fy_significant_fdr", max(z$FY[z$p_FDR < 0.05]))    # last FY with an FDR-significant CV vs non-CV difference
fwrite(rbindlist(kn), out_path("key_numbers_stats.csv"))
print(o1[Method == main & NW_lag == 1, .(Years, Group, slope = round(slope_pp_per_yr, 3), lo = round(CI_low, 3), hi = round(CI_high, 3))])
