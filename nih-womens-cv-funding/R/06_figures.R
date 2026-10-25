#' 06_figures.R -- the two figures of the report, drawn with ggplot2.
#'
#' Style (all figures): Arial, black and grey, red (#c0392b) only where the published figure
#' uses it, no gridlines, minimal formatting. FY2026 (incomplete) is marked: hatched-look open
#' bars with an asterisk in bar charts, dotted/shaded in line charts.
#' Figure 1  Total NIH cardiovascular (CV) funding (grey bars, broad CV tier) with women's CV
#'           research funding (red bars, partial tier v3 within CV), labelled with the % of CV dollars.
#' Figure 2  Small multiples of topic shares (fractional allocation): rows 1-3 = share of all NIH
#'           CV funding (black; red dashed = excluding the 3M/IMPROVE award OT2HL158287; grey
#'           lines = specific conditions); row 4 = share of women's CV funding (relative decline).
#' INPUTS   work_dir outputs of 03 and 05
#' OUTPUTS  out_dir/Figure1.{png,pdf}, out_dir/Figure2.{png,pdf}

source("R/00_setup.R")
FONT <- if (CONFIG$font %in% systemfonts::system_fonts()$family) CONFIG$font else "sans"
RED <- CONFIG$red; INC <- CONFIG$incomplete_year
theme_min <- function(size = 9) theme_classic(base_size = size, base_family = FONT) +
  theme(axis.line = element_line(linewidth = 0.4), axis.ticks = element_line(linewidth = 0.4),
        axis.text = element_text(colour = "black"), plot.title = element_text(size = size, hjust = 0),
        legend.key.size = unit(0.35, "cm"))

#' Save a ggplot as 300-dpi PNG and vector PDF (no author metadata is written).
save_fig <- function(p, name, w, h) {
  ggsave(out_path(paste0(name, ".png")), p, width = w, height = h, dpi = 300, device = ragg::agg_png)
  ggsave(out_path(paste0(name, ".pdf")), p, width = w, height = h, device = cairo_pdf)
}

#' Overlapping bar chart: totals (grey, wide) with the WHR part (red, narrow, in front).
bars <- function(y, tot, w, pct, ymax, step, off, legend, name) {
  d <- data.table(FY = y, tot = tot, w = w, pct = pct, inc = y == INC)
  p <- ggplot(d) +
    geom_col(aes(FY, tot, fill = "a"), width = 0.7, data = d[inc == FALSE]) +
    geom_col(aes(FY, tot), width = 0.7, data = d[inc == TRUE], fill = "white", colour = "grey50", linewidth = 0.3, linetype = "22") +
    geom_col(aes(FY, w, fill = "b"), width = 0.5, data = d[inc == FALSE]) +
    geom_col(aes(FY, w), width = 0.5, data = d[inc == TRUE], fill = "#e8a59d", colour = RED, linewidth = 0.3, linetype = "22") +
    geom_text(aes(FY, w + off, label = sprintf("%.1f%%", pct)), vjust = 0, colour = RED, size = 8 / .pt, family = FONT) +
    scale_fill_manual(values = c(a = "grey85", b = RED), labels = legend, name = NULL) +
    scale_x_continuous(breaks = y, labels = c(head(y, -1), paste0(tail(y, 1), "*")), expand = expansion(add = 0.6)) +
    scale_y_continuous(limits = c(0, ymax), breaks = seq(0, ymax, step), expand = c(0, 0)) +
    labs(x = "Fiscal year", y = "Funding ($ billions)") + theme_min() +
    theme(legend.position = c(0.01, 0.99), legend.justification = c(0, 1))
  save_fig(p, name, 7, 3.6)
}

# ---- Figure 1: CV funding bars -----------------------------------------------------------------
R <- readRDS(work_path("cv", "R.rds"))[CV_tier == "broad"]
bars(R$FY, R$CV_proj_B, R$`Partial tier v3 B`, R$`Partial tier v3 pct_B`, 5, 1, 0.06,
     c("Total NIH cardiovascular funding", "Women's cardiovascular health research"), "Figure1")

# ---- Figure 2: topic small multiples ------------------------------------------------------------
T <- readRDS(work_path("topics", "cv_topics.rds")); y <- CONFIG$years
A <- 100 * T$frac / T$CVT; X <- 100 * T$frac_x / T$CVT
panels <- list(c("Lifestyle, obesity & social determinants in women", "Lifestyle, obesity & social determinants"),
  c("Hypertensive disorders of pregnancy", "Hypertensive disorders of pregnancy"),
  c("Maternal mortality / severe maternal morbidity", "Maternal mortality / severe morbidity"),
  c("Sex differences / female-specific mechanisms", "Sex differences / female-specific mechanisms"),
  c("Offspring / developmental programming & perinatal", "Offspring / developmental & perinatal"),
  c("Other / general women's CV", "Other / general women's CV"),
  c("Menopause / sex hormones & CVD", "Menopause / sex hormones"),
  c("Placental / maternal-fetal vascular biology", "Placental / maternal-fetal vascular biology"))
L <- list()
for (i in seq_along(panels)) {
  t <- panels[[i]][1]; lab <- sprintf("%s. %s", letters[i], panels[[i]][2])
  L[[length(L) + 1]] <- data.table(panel = lab, FY = y, v = A[, t], s = "all", row = ceiling(i / 3))
  if (max(abs(A[, t] - X[, t])) > 1e-6) L[[length(L) + 1]] <- data.table(panel = lab, FY = y, v = X[, t], s = "excl", row = ceiling(i / 3))
}
for (x in list(c("Coronary microvascular dysfunction / INOCA / MINOCA", "CMD/INOCA/MINOCA"), c("Peripartum cardiomyopathy", "PPCM"),
               c("SCAD", "SCAD"), c("Takotsubo / stress cardiomyopathy", "Takotsubo")))
  L[[length(L) + 1]] <- data.table(panel = "i. Specific conditions", FY = y, v = A[, x[1]], s = x[2], row = 3)
for (x in list(c("Menopause / sex hormones & CVD", "j. Menopause / sex hormones (women's CV)"),
               c("Placental / maternal-fetal vascular biology", "k. Placental / fetal vascular (women's CV)")))
  L[[length(L) + 1]] <- data.table(panel = x[2], FY = y, v = T$WSH[, x[1]], s = "all", row = 4)
for (x in list(c("PCOS", "PCOS"), c("Gestational diabetes & CV risk", "Gestational diabetes"), c("Takotsubo / stress cardiomyopathy", "Takotsubo ")))
  L[[length(L) + 1]] <- data.table(panel = "l. Flat or declining (women's CV)", FY = y, v = T$WSH[, x[1]], s = x[2], row = 4)
d <- rbindlist(L); d[, panel := factor(panel, levels = unique(panel))]
main <- d[s == "all"]; grey <- d[!s %in% c("all", "excl")]
p <- ggplot() +
  geom_line(aes(FY, v), data = main[FY <= INC - 1], linewidth = 0.5) +
  geom_line(aes(FY, v), data = main[FY >= INC - 1], linewidth = 0.5, linetype = "dotted") +
  geom_line(aes(FY, v), data = d[s == "excl"], colour = RED, linewidth = 0.4, linetype = "dashed") +
  geom_line(aes(FY, v, linetype = s), data = grey, colour = "grey35", linewidth = 0.4) +
  scale_linetype_manual(values = c(`CMD/INOCA/MINOCA` = "solid", PPCM = "dashed", SCAD = "dotted", Takotsubo = "dotdash",
                                   PCOS = "solid", `Gestational diabetes` = "dashed", `Takotsubo ` = "dotdash"), name = NULL) +
  facet_wrap(~panel, ncol = 3, scales = "free_y") +
  scale_x_continuous(breaks = c(2013, 2017, 2021, 2025)) + scale_y_continuous(limits = c(0, NA)) +
  labs(x = NULL, y = "% of NIH CV funding (rows 1-3); % of women's CV funding (row 4)",
       caption = paste0("Fractional allocation (project dollars split across matched topics). Dotted segment: FY2026 (incomplete).\n",
                        "Bottom row: share of women's CV funding. Red dashed: excluding NHLBI Maternal Morbidity & Mortality (3M/IMPROVE) award OT2HL158287.")) +
  theme_min(8) + theme(strip.background = element_blank(), strip.text = element_text(hjust = 0, size = 8),
                       legend.position = "bottom", plot.caption = element_text(hjust = 0, size = 6.5, colour = "grey30"))
save_fig(p, "Figure2", 7.5, 8.4)
say("figures written to ", CONFIG$out_dir)
