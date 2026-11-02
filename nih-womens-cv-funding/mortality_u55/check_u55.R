#' Check the under-55 CDC WONDER mortality extension against tests/expected_values_u55.csv.
#' Run from nih-womens-cv-funding/:  Rscript mortality_u55/check_u55.R
#' Uses only mortality_u55/women_u55_mortality_2013_2024.csv (no network access) and R/utils.R::nw_trend
#' (OLS on year, Newey-West lag 1, no prewhitening, normal-theory 95% CI), as in the main mortality analysis.
suppressMessages(library(data.table)); source("R/utils.R")
U <- fread("mortality_u55/women_u55_mortality_2013_2024.csv")
out <- list()
for (cs in c("all_cvd", "heart_disease")) {
  s <- U[cause == cs][order(year)]
  for (y in c(2013, 2019, 2021, 2024)) out[[length(out) + 1]] <- data.table(id = sprintf("u55_%s_%d", cs, y), value = s[year == y, age_adjusted_rate_per_100k])
  for (w in list(list("1324", 2013:2024), list("1319", 2013:2019), list("ex2022", setdiff(2013:2024, 2020:2022)))) {
    z <- s[year %in% w[[2]]]; a <- nw_trend(z$age_adjusted_rate_per_100k, z$year, 1)
    for (k in c("slope", "ci_low", "ci_high", "p")) out[[length(out) + 1]] <- data.table(id = sprintf("u55_%s_%s_%s", cs, w[[1]], k), value = a[[k]])
  }
}
O <- rbindlist(out); E <- fread("tests/expected_values_u55.csv"); M <- merge(E, O, by = "id", all = TRUE)
M[, status := fifelse(!is.na(value) & !is.na(expected) & abs(value - expected) <= tolerance, "PASS", "FAIL")]
print(M[, .(id, expected, value, status)])
cat(sprintf("SUMMARY: PASS %d / %d\n", sum(M$status == "PASS"), nrow(M)))
if (any(M$status != "PASS")) quit(status = 1)
