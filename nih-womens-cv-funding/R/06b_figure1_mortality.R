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

# ---- Figure 1 with mortality overlay (v8/v9 colour style) + panel B, women aged <55 -----------
R <- readRDS(work_path("cv", "R.rds"))[CV_tier == "broad"]
d <- data.table(FY = R$FY, tot = R$CV_proj_B, w = R$`Partial tier v3 B`, pct = R$`Partial tier v3 pct_B`)[, inc := FY == INC]
M[, lab := fifelse(cause == "all_cvd", "c", "d")]
# Panel B input: CDC WONDER rates for women aged <55 (mortality_u55/; shipped copy in inst/extdata).
# WHR_U55_CSV overrides the path; WHR_U55_CSV=none draws panel A only.
U55F <- Sys.getenv("WHR_U55_CSV", "inst/extdata/cdc_wonder_women_u55_mortality_2013_2024.csv")
U <- if (nzchar(U55F) && U55F != "none" && file.exists(U55F)) fread(U55F)[year %in% 2013:2024][order(cause, year)] else NULL
labs4 <- c(a = "Total NIH cardiovascular funding", b = "Women's cardiovascular health research",
           c = "Women, all CVD mortality (I00\u2013I99)", d = "Women, heart disease mortality")
#' Diagonal hatch segments clipped to rectangles (x0, x1, 0, h); asp converts x to y units so lines look ~45 degrees.
hatch <- function(x0, x1, h, gap = 0.12, asp = 0.86) {
  out <- list()
  for (i in seq_along(x0)) {
    for (c0 in seq(-h[i] / asp, x1[i] - x0[i], by = gap)) {          # line x = x0 + c0 + y/asp
      ya <- max(0, -c0 * asp); yb <- min(h[i], (x1[i] - x0[i] - c0) * asp)
      if (yb > ya) out[[length(out) + 1]] <- data.table(x = x0[i] + c0 + ya / asp, y = ya, xend = x0[i] + c0 + yb / asp, yend = yb)
    }
  }
  rbindlist(out)
}
di <- d[inc == TRUE]
p <- ggplot(d) +
  geom_col(aes(FY, tot, fill = "a"), width = 0.7, data = d[inc == FALSE]) +
  geom_col(aes(FY, tot), width = 0.7, data = di, fill = "white", colour = "grey45", linewidth = 0.35) +
  geom_segment(aes(x, y, xend = xend, yend = yend), data = hatch(di$FY - 0.35, di$FY + 0.35, di$tot), colour = "grey55", linewidth = 0.25) +
  geom_col(aes(FY, w, fill = "b"), width = 0.5, data = d[inc == FALSE]) +
  geom_col(aes(FY, w), width = 0.5, data = di, fill = "#e8a59d", colour = RED, linewidth = 0.35) +
  geom_segment(aes(x, y, xend = xend, yend = yend), data = hatch(di$FY - 0.25, di$FY + 0.25, di$w, gap = 0.1), colour = RED, linewidth = 0.25) +
  geom_text(aes(FY, w + 0.06, label = sprintf("%.1f%%", pct)), vjust = 0, colour = RED, size = 9.5 / .pt, family = FONT, data = d[inc == FALSE]) +
  geom_label(aes(FY, w + 0.06, label = sprintf("%.1f%%", pct)), vjust = 0, colour = RED, size = 9.5 / .pt, family = FONT, data = di,
             fill = "white", label.size = 0, label.padding = unit(0.04, "lines"), label.r = unit(0, "lines")) +
  geom_line(aes(year, age_adjusted_rate_per_100k / SCALE, linetype = lab), data = M, colour = "black", linewidth = 0.65) +
  scale_fill_manual(values = c(a = "grey85", b = RED), labels = labs4[1:2], name = NULL) +
  scale_linetype_manual(values = c(c = "solid", d = "dashed"), labels = labs4[3:4], name = NULL) +
  scale_x_continuous(breaks = d$FY, labels = c(head(d$FY, -1), paste0(tail(d$FY, 1), "*")), limits = range(d$FY) + c(-0.6, 0.6), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, 6), breaks = 0:6, expand = c(0, 0),
                     sec.axis = sec_axis(~ . * SCALE, breaks = seq(0, 300, 50), name = "Women's age-adjusted deaths per 100,000")) +
  labs(x = if (is.null(U)) "Fiscal year" else NULL, y = "Funding ($ billions)", tag = if (is.null(U)) NULL else "A") +
  guides(fill = guide_legend(order = 1, ncol = 1), linetype = guide_legend(order = 2, ncol = 1, override.aes = list(linewidth = 0.6)))
th <- theme_classic(base_size = 11, base_family = FONT) +
  theme(axis.line = element_line(linewidth = 0.4), axis.ticks = element_line(linewidth = 0.4),
        axis.text = element_text(colour = "black", size = 11), axis.title = element_text(size = 11),
        axis.title.y.right = element_text(angle = 90), legend.key.size = unit(0.35, "cm"), legend.key.width = unit(0.7, "cm"),
        legend.text = element_text(size = 10.5), legend.position = "inside", legend.position.inside = c(0.01, 0.99), legend.justification = c(0, 1),
        legend.box = "vertical", legend.spacing.y = unit(0.05, "cm"), legend.background = element_blank(),
        plot.tag = element_text(size = 12, face = "bold", margin = margin(r = 10, b = 6)), plot.tag.position = "topleft", plot.tag.location = "margin",
        plot.caption = element_text(hjust = 0, size = 9.5), plot.caption.position = "plot")
cap <- "*FY2026 funding incomplete. Mortality: CDC WONDER (final through 2024). No 2025\u20132026 mortality data shown."
if (is.null(U)) {
  p <- p + labs(caption = cap) + th
  ggsave(out_path("Figure1_mortality.png"), p, width = 7, height = 3.8, dpi = 300, device = ragg::agg_png)
  ggsave(out_path("Figure1_mortality.pdf"), p, width = 7, height = 3.8, device = cairo_pdf)
} else {
  # Panel B: women aged <55, age-adjusted by CDC WONDER (2000 US standard, ten-year groups <1 to 45-54), same causes and years.
  U[, lab := fifelse(cause == "all_cvd", "e", "f")]
  labsU <- c(e = "Women aged <55 years, all CVD mortality (I00\u2013I99)", f = "Women aged <55 years, heart disease mortality")
  pb <- ggplot(U) +
    geom_line(aes(year, age_adjusted_rate_per_100k, linetype = lab), colour = "black", linewidth = 0.65) +
    geom_point(aes(year, age_adjusted_rate_per_100k), colour = "black", size = 1.1) +
    scale_linetype_manual(values = c(e = "solid", f = "dashed"), labels = labsU, name = NULL) +
    scale_x_continuous(breaks = d$FY, labels = c(head(d$FY, -1), paste0(tail(d$FY, 1), "*")), limits = range(d$FY) + c(-0.6, 0.6), expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 30), breaks = seq(0, 30, 10), expand = c(0, 0), position = "right",
                       name = "Deaths per 100,000") +
    labs(x = "Fiscal year (funding) / calendar year (mortality)", tag = "B", caption = paste0(cap, "\nB: age-adjusted to the 2000 US standard population, ages <1 to 45\u201354 years.")) +
    guides(linetype = guide_legend(ncol = 1, override.aes = list(linewidth = 0.6))) + th +
    theme(axis.line.y.left = element_blank(), legend.position.inside = c(0.01, 0.03), legend.justification = c(0, 0))
  g <- rbind(ggplotGrob(p + th), ggplotGrob(pb), size = "max")
  pa_rows <- unique(g$layout$t[grepl("^panel", g$layout$name)])
  g$heights[pa_rows[1]] <- unit(3, "null"); g$heights[pa_rows[2]] <- unit(1.25, "null")
  for (f in c("png", "pdf")) {
    fn <- out_path(paste0("Figure1_mortality.", f))
    if (f == "png") ragg::agg_png(fn, width = 7, height = 5.9, units = "in", res = 300) else cairo_pdf(fn, width = 7, height = 5.9)
    grid::grid.newpage(); grid::grid.draw(g); dev.off()
  }
}
say("Figure1_mortality and mortality trend tests written to ", CONFIG$out_dir)
