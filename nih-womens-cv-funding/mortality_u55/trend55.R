suppressMessages(library(data.table)); source("R/utils.R")
U <- fread(Sys.getenv("F"))
for (cs in c("all_cvd","heart_disease")) for (w in list(list("2013-2024",2013:2024),list("2013-2019",2013:2019),list("ex2020-22",setdiff(2013:2024,2020:2022)))) {
 s <- U[cause==cs & year %in% w[[2]]][order(year)]; a <- nw_trend(s$age_adjusted_rate_per_100k, s$year, 1)
 cat(sprintf("%s %s slope %.3f (%.3f to %.3f) p=%.3f\n", cs, w[[1]], a$slope, a$ci_low, a$ci_high, a$p)) }
