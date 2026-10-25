#' 06b_figure1_mortality.R -- Figure 1 with women's CV mortality on a second y-axis, and the
#'                            mortality trend tests reported in the Methods/Results.
#'
#' FIGURE   Same bars as Figure 1 from 06_figures.R (grey = total NIH cardiovascular [CV] funding,
#'          broad CV tier; red = women's CV research, partial tier v3; red labels = % of CV
#'          dollars; FY2026 incomplete, hatched-look open bars with an asterisk), plus black lines
#'          on the right-hand axis: women's age-adjusted death rates per 100,000 (CDC WONDER,
#'          final data, 2013-2024; solid = all CVD, I00-I99; dashed = diseases of heart,
#'          I00-I09, I11, I13, I20-I51). No 2025 provisional point is drawn.
#'          Note: funding is by NIH fiscal year, mortality by calendar year.
#' TRENDS   For each cause, 2013-2024:
#'            * change 2013 -> 2024 (rate and %),
#'            * OLS of the rate on (year - 2013) with Newey-West SEs (lags 1 and 2; same helper,
#'              nw_trend(), as the funding trends), slope in deaths per 100,000 per year,
#'            * log-linear OLS (log rate on year), giving the annual percent change
#'              APC = 100 * (exp(b) - 1) with its CI (one segment, so APC = AAPC),
#'            * sensitivity analysis excluding the COVID-19 years 2020-2022, and the
#'              pre-pandemic years 2013-2019 alone.
#'          These are descriptive, ecological comparisons; no causal link to funding is tested.
#' INPUTS   work_dir/cv/R.rds (from 03_classify.R), work_dir/mortality/cvd_mortality_women.csv (01b)
#' OUTPUTS  out_dir/Figure1_mortality.{png,pdf}, out_dir/mortality_trends.csv,
#'          out_dir/key_numbers_mortality.csv (checked by 07_verify.R)

source("R/00_setup.R")
FONT <- if (CONFIG$font %in% systemfonts::system_fonts()$family) CONFIG$font else "sans"
RED <- CONFIG$red; INC <- CONFIG$incomplete_year
SCALE <- 50   # right axis = left axis x 50  (0-6 $ billions  <->  0-300 deaths per 100,000)

# ---- mortality series -------------------------------------------------------------------------
mf <- work_path("mortality", "cvd_mortality_women.csv")
if (!file.exists(mf)) stop("Run R/01b_mortality.R first (", mf, " not found).")
M <- fread(mf)[year %in% 2013:2024][order(cause, year)]

# ---- trend tests -------------------------------------------------------------------------------
K <- list(); TT <- list()
key <- function(id, v) K[[length(K) + 1]] <<- data.table(id = id, value = v)
for (cs in c("all_cvd", "heart_disease")) {
  m <- M[cause == cs]; ab <- if (cs == "all_cvd") "cvd" else "heart"
  r0 <- m[year == 2013, age_adjusted_rate_per_100k]; r1 <- m[year == 2024, age_adjusted_rate_per_100k]
  key(paste0("mort_", ab, "_2013"), r0); key(paste0("mort_", ab, "_2024"), r1)
  key(paste0("mort_", ab, "_2019"), m[year == 2019, age_adjusted_rate_per_100k])
  key(paste0("mort_", ab, "_2021"), m[year == 2021, age_adjusted_rate_per_100k])
  key(paste0("mort_", ab, "_pctchg"), 100 * (r1 / r0 - 1))
  for (w in list(list("1324", 2013:2024), list("ex2022", setdiff(2013:2024, 2020:2022)), list("1319", 2013:2019))) {
    s <- m[year %in% w[[2]]]
    for (lag in 1:2) {
      a <- nw_trend(s$age_adjusted_rate_per_100k, s$year, lag)
      g <- nw_trend(log(s$age_adjusted_rate_per_100k), s$year, lag)
      apc <- 100 * (exp(c(g$slope, g$ci_low, g$ci_high)) - 1)
      TT[[length(TT) + 1]] <- data.table(cause = cs, years = w[[1]], NW_lag = lag, slope = a$slope, lo = a$ci_low, hi = a$ci_high,
                                         p = a$p, APC = apc[1], APC_lo = apc[2], APC_hi = apc[3], APC_p = g$p)
      if (lag == 1) {   # the report quotes lag 1
        pre <- paste0("mort_", ab, "_", w[[1]], "_")
        key(paste0(pre, "slope"), a$slope); key(paste0(pre, "lo"), a$ci_low); key(paste0(pre, "hi"), a$ci_high); key(paste0(pre, "p"), a$p)
        key(paste0(pre, "apc"), apc[1]); key(paste0(pre, "apc_lo"), apc[2]); key(paste0(pre, "apc_hi"), apc[3])
      }
    }
  }
}
TT <- rbindlist(TT); fwrite(TT, out_path("mortality_trends.csv")); fwrite(rbindlist(K), out_path("key_numbers_mortality.csv"))
print(TT[NW_lag == 1, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])

# ---- Figure 1 with mortality overlay -----------------------------------------------------------
R <- readRDS(work_path("cv", "R.rds"))[CV_tier == "broad"]
d <- data.table(FY = R$FY, tot = R$CV_proj_B, w = R$`Partial tier v3 B`, pct = R$`Partial tier v3 pct_B`)[, inc := FY == INC]
M[, lab := fifelse(cause == "all_cvd", "c", "d")]
labs4 <- c(a = "Total NIH cardiovascular funding", b = "Women's cardiovascular health research",
           c = "Women, all CVD mortality (I00\u2013I99)", d = "Women, heart disease mortality")
p <- ggplot(d) +
  geom_col(aes(FY, tot, fill = "a"), width = 0.7, data = d[inc == FALSE]) +
  geom_col(aes(FY, tot), width = 0.7, data = d[inc == TRUE], fill = "white", colour = "grey50", linewidth = 0.3, linetype = "22") +
  geom_col(aes(FY, w, fill = "b"), width = 0.5, data = d[inc == FALSE]) +
  geom_col(aes(FY, w), width = 0.5, data = d[inc == TRUE], fill = "#e8a59d", colour = RED, linewidth = 0.3, linetype = "22") +
  geom_text(aes(FY, w + 0.06, label = sprintf("%.1f%%", pct)), vjust = 0, colour = RED, size = 8 / .pt, family = FONT) +
  # mortality: drawn on the funding scale after dividing by SCALE, labelled by the secondary axis
  geom_line(aes(year, age_adjusted_rate_per_100k / SCALE, linetype = lab), data = M, colour = "black", linewidth = 0.65) +
  scale_fill_manual(values = c(a = "grey85", b = RED), labels = labs4[1:2], name = NULL) +
  scale_linetype_manual(values = c(c = "solid", d = "dashed"), labels = labs4[3:4], name = NULL) +
  scale_x_continuous(breaks = d$FY, labels = c(head(d$FY, -1), paste0(tail(d$FY, 1), "*")), expand = expansion(add = 0.6)) +
  scale_y_continuous(limits = c(0, 6), breaks = 0:6, expand = c(0, 0),
                     sec.axis = sec_axis(~ . * SCALE, breaks = seq(0, 300, 50), name = "Women's age-adjusted deaths per 100,000")) +
  labs(x = "Fiscal year", y = "Funding ($ billions)",
       caption = "*FY2026 funding incomplete. Mortality: CDC WONDER (final through 2024). No 2025\u20132026 mortality data shown.") +
  guides(fill = guide_legend(order = 1, ncol = 1), linetype = guide_legend(order = 2, ncol = 1, override.aes = list(linewidth = 0.6))) +
  theme_classic(base_size = 9, base_family = FONT) +
  theme(axis.line = element_line(linewidth = 0.4), axis.ticks = element_line(linewidth = 0.4),
        axis.text = element_text(colour = "black", size = 9), axis.title = element_text(size = 9),
        axis.title.y.right = element_text(angle = 90), legend.key.size = unit(0.35, "cm"), legend.key.width = unit(0.7, "cm"),
        legend.text = element_text(size = 8), legend.position = "inside", legend.position.inside = c(0.01, 0.99), legend.justification = c(0, 1),
        legend.box = "horizontal", legend.background = element_blank(),
        plot.caption = element_text(hjust = 0, size = 7), plot.caption.position = "plot")
ggsave(out_path("Figure1_mortality.png"), p, width = 7, height = 3.8, dpi = 300, device = ragg::agg_png)
ggsave(out_path("Figure1_mortality.pdf"), p, width = 7, height = 3.8, device = cairo_pdf)
say("Figure1_mortality and mortality trend tests written to ", CONFIG$out_dir)
