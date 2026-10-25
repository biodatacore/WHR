#' 07_verify.R -- check the reproduced numbers against the values behind the published report.
#'
#' PURPOSE  Every number quoted in the report is written by 04_analysis.R and 05_topics.R to
#'          out_dir/key_numbers_*.csv (id, value). This script joins them with
#'          tests/expected_values.csv (id, expected = full-precision value from the original
#'          analysis, tolerance = allowed absolute difference) and prints PASS/FAIL per number.
#'          Tolerances are half a unit of the precision quoted in the report (e.g. 0.005 pp for
#'          values reported to two decimals); counts and years must match exactly.
#' USAGE    Rscript R/07_verify.R      (exit status 1 if any check fails)
#' OUTPUTS  out_dir/verification_report.csv

source("R/00_setup.R")
E <- fread("tests/expected_values.csv")
files <- Sys.glob(out_path("key_numbers_*.csv"))
if (!length(files)) stop("No key_numbers_*.csv in ", CONFIG$out_dir, ": run the pipeline first (Rscript R/run_all.R).")
K <- rbindlist(lapply(files, fread))
V <- merge(E, K, by = "id", all.x = TRUE, sort = FALSE)
V[, diff := value - expected]
V[, status := fifelse(is.na(value), "MISSING", fifelse(abs(diff) <= tolerance + 1e-9, "PASS", "FAIL"))]
fwrite(V, out_path("verification_report.csv"))
print(V[, .(id, expected = signif(expected, 6), value = signif(value, 6), diff = signif(diff, 3), tolerance, status)], nrows = 500)
n <- V[, .N, by = status]
cat("\nSUMMARY:", paste(n$status, n$N, collapse = ", "), "\n")
cat("OVERALL:", if (all(V$status == "PASS")) "PASS" else "FAIL", "\n")
if (!all(V$status == "PASS") && !interactive()) quit(status = 1)
