#' 06_figures.R -- the two figures of the report, drawn with ggplot2.
#'
#' Style (all figures): Arial, black and grey, red (#c0392b) only where the published figure
#' uses it, no gridlines, minimal formatting. FY2026 (incomplete) is marked: hatched-look open
#' bars with an asterisk in bar charts, dotted/shaded in line charts.
#' Figure 1  Total NIH funding (grey bars) with WHR funding (red bars, partial tier v3),
#'           labelled with the WHR % of NIH dollars.
#' Figure 2  A: 7 topic groups as % of all NIH funding; B: selected subtopics as % of WHR funding.
#'           Female cancers and breast cancer in red; direct line labels; FY2026 shaded.
#' INPUTS   work_dir outputs of 03 and 05
#' OUTPUTS  out_dir/Figure1.{png,pdf}, out_dir/Figure2_v3.{png,pdf} (predominant/profound; the earlier Figure2 layout is in git history)

source("R/00_setup.R")
source("R/topics_whr.R")
FONT <- if (CONFIG$font %in% systemfonts::system_fonts()$family) CONFIG$font else "sans"
RED <- CONFIG$red; INC <- CONFIG$incomplete_year
theme_min <- function(size = 9) theme_classic(base_size = size, base_family = FONT) +
  theme(axis.line = element_line(linewidth = 0.4), axis.ticks = element_line(linewidth = 0.4),
        axis.text = element_text(colour = "black", size = size), legend.text = element_text(size = size), plot.title = element_text(size = size, hjust = 0),
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
    geom_text(aes(FY, w + off, label = sprintf("%.1f%%", pct)), vjust = 0, colour = RED, size = 11 / .pt, family = FONT) +
    scale_fill_manual(values = c(a = "grey85", b = RED), labels = legend, name = NULL) +
    scale_x_continuous(breaks = y, labels = c(paste0("'", substr(head(y, -1), 3, 4)), paste0("'", substr(tail(y, 1), 3, 4), "*")), expand = expansion(add = 0.6)) +
    scale_y_continuous(limits = c(0, ymax), breaks = seq(0, ymax, step), expand = c(0, 0)) +
    labs(x = "Fiscal year", y = "Funding ($ billions)") + theme_min(13) +
    theme(legend.position = c(0.01, 0.99), legend.justification = c(0, 1))
  save_fig(p, name, 7.5, 4.6)
}

# ---- Figure 1: NIH funding bars ------------------------------------------------------------------
Y <- readRDS(work_path("whr", "yearly.rds"))
bars(Y$FY, Y$nih_B, Y$v3_B, Y$v3_pct, 50, 10, 0.6, c("Total NIH funding", "Women's health research"), "Figure1")

# ---- Figure 2: two-panel topic figure ------------------------------------------------------------
T <- readRDS(work_path("topics", "whr_topics.rds")); y <- CONFIG$years
K <- "black"; G <- "grey55"
spA <- list(c("3 Female cancers", "Female cancers", RED, "solid"), c("5 Sex differences / conditions affecting women differently", "Sex differences / affect women differently", K, "solid"),
  c("2 Maternal / pregnancy health", "Maternal / pregnancy health", K, "dashed"), c("6 Violence / social determinants", "Violence / social determinants", G, "solid"),
  c("1 Female-specific conditions", "Female-specific conditions", K, "dotted"), c("4 Female-predominant conditions", "Female-predominant conditions", G, "dashed"),
  c("7 Other / general women's health", "Other / general women's health", G, "dotted"))
spB <- list(c("Breast cancer", "Breast cancer", RED, "solid"), c("Health equity / social determinants in women", "Health equity / social determinants", K, "solid"),
  c("HIV / STIs in women", "HIV / STIs", G, "solid"), c("Pregnancy cohorts / prenatal exposures (ECHO, nuMoM2b)", "Pregnancy / birth cohorts", G, "dashed"),
  c("Sex-differences biology", "Sex-differences biology", K, "dashed"), c("Postpartum / lactation / breastfeeding", "Postpartum / lactation", K, "dotted"))
#' push end-of-line labels apart so they do not overlap (iterative pairwise spreading)
spread <- function(v, gap) { o <- order(v); s <- v[o]
  for (it in 1:200) for (i in 2:length(s)) if (s[i] - s[i - 1] < gap) { m <- (s[i] + s[i - 1]) / 2; s[i - 1] <- m - gap / 2; s[i] <- m + gap / 2 }
  out <- numeric(length(v)); out[o] <- s; out }
panel <- function(spec, M, den, ylab, tag, gap) {
  d <- rbindlist(lapply(spec, function(s) data.table(FY = y, v = 100 * M[, s[1]] / den, lab = s[2], col = s[3], lt = s[4])))
  e <- d[FY == max(y)]; e[, ly := spread(v, gap)]
  ggplot(d, aes(FY, v, group = lab)) +
    annotate("rect", xmin = INC - 0.5, xmax = INC + 0.5, ymin = -Inf, ymax = Inf, fill = "grey92") +
    geom_line(aes(colour = col, linetype = lt, linewidth = col == RED)) +
    geom_text(aes(x = INC + 0.7, y = ly, label = lab, colour = ifelse(col == G, "grey40", col)), data = e, hjust = 0, size = 12 / .pt, family = FONT) +
    { if (tag == "A") annotate("text", x = INC, y = Inf, label = "FY2026\nincomplete", vjust = -0.2, size = 11 / .pt, colour = "grey35", family = FONT) } +
    scale_colour_identity() + scale_linetype_identity() + scale_linewidth_manual(values = c(`FALSE` = 0.55, `TRUE` = 0.7), guide = "none") +
    scale_x_continuous(breaks = seq(2013, 2025, 2)) +
    scale_y_continuous(limits = c(0, max(d$v) * 1.2)) + coord_cartesian(xlim = c(2012.6, 2026.5), expand = FALSE, clip = "off") +
    labs(x = "Fiscal year", y = ylab, tag = tag) + theme_min(13) +
    theme(axis.line.x = element_blank(), plot.margin = margin(40, 210, 8, 5), plot.tag = element_text(face = "bold", size = 14), plot.tag.position = "topleft", plot.tag.location = "margin") +
    annotate("segment", x = 2012.6, xend = INC + 0.5, y = -Inf, yend = -Inf, linewidth = 0.4)
}
#' Figure 2 (v2): predominant vs profound categories (see 05_topics.R). A: categories, % of all NIH
#' funding; B: predominant families, % of WHR; C: profound conditions, % of WHR (CVD in red).
famcol <- function(cols) rowSums(T$fcs[, cols, drop = FALSE])
FAM <- cbind(`Female cancers` = famcol(WHR_TOPICS[group == "3 Female cancers"]$subtopic),
             `Maternal health` = famcol(WHR_TOPICS[group == "2 Maternal / pregnancy health"]$subtopic),
             `Female-specific conditions` = famcol(WHR_TOPICS[group == "1 Female-specific conditions"]$subtopic),
             `Female-predominant conditions` = famcol(c("Autoimmune (lupus, RA, MS, Sjogren, scleroderma)", "Thyroid", "Migraine / chronic pain / fibromyalgia", "Urinary incontinence / UTI")))
spA <- list(c("Predominant", "Predominant", K, "solid"), c("Profound", "Profound", RED, "solid"), c("Cross-cutting", "Cross-cutting", G, "solid"), c("Unclassified", "Unclassified", G, "dotted"))
spB <- list(c("Female cancers", "Female cancers", K, "solid"), c("Maternal health", "Maternal health", K, "dashed"),
            c("Female-specific conditions", "Female-specific conditions", K, "dotted"), c("Female-predominant conditions", "Female-predominant conditions", G, "solid"))
spC <- list(c("Cardiovascular disease", "Cardiovascular disease", RED, "solid"), c("Diabetes / obesity", "Diabetes / obesity", G, "solid"),
            c("Depression / anxiety / PTSD / eating disorders", "Depression / anxiety", K, "dashed"), c("Alzheimer's / dementia / cognitive aging", "Alzheimer's / dementia", K, "solid"),
            c("Osteoporosis / bone", "Osteoporosis / bone", G, "dashed"))
pA <- panel(spA, T$fcat, T$NIH, "Share of total NIH funding, %", "A", 0.5)
pB <- panel(spB, FAM, T$WT, "Share of WHR funding, %", "B", 3.6)
pC <- panel(spC, T$fcs, T$WT, "Share of WHR funding, %", "C", 0.62)
# three panels stacked vertically using base grid (no extra packages)
png_pdf <- function(dev, file, ...) { dev(file, ...); grid::grid.newpage(); lay <- grid::grid.layout(3, 1)
  grid::pushViewport(grid::viewport(layout = lay)); for (i in 1:3) print(list(pA, pB, pC)[[i]], vp = grid::viewport(layout.pos.row = i)); dev.off() }
png_pdf(ragg::agg_png, out_path("Figure2_v3.png"), width = 8, height = 8.6, units = "in", res = 300)
png_pdf(cairo_pdf, out_path("Figure2_v3.pdf"), width = 8, height = 8.6)
say("figures written to ", CONFIG$out_dir)
