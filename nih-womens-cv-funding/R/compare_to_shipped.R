#' compare_to_shipped.R -- check a raw-data rebuild against the shipped replication data.
#'
#' PURPOSE  After rebuilding from raw NIH files (Rscript R/run_all.R --raw, with WHR_WORK_DIR
#'          pointing to a NEW directory), compare the re-derived project features and labels with
#'          the shipped files, fiscal year by fiscal year. Records missing on either side and
#'          label disagreements are counted; disagreements are written to
#'          outputs/compare_to_shipped.csv for inspection.
#' USAGE    WHR_WORK_DIR=/path/to/rebuild Rscript R/compare_to_shipped.R
#' NOTE     Re-downloaded RePORTER records change over time (FY2026 in particular, which was
#'          retrieved on 2026-10-20 while incomplete), so small differences are expected.

source("R/00_setup.R")
rd <- function(f) { d <- read.csv(gzfile(f), na.strings = "NA", colClasses = c(FULL_PROJECT_NUM = "character", APPLICATION_ID = "character", title = "character", cls = "character", conf = "character", ACT = "character", IC = "character"), check.names = FALSE); setDT(d) }
key <- c("cls", "sexdiff", grep("^(t_)?(mat|women|cancer|repro|femprev|c_|n_)", names(rd(file.path("data/shipped/features", "whr_features_2013.csv.gz"))), value = TRUE))
out <- list(); diffs <- list()
for (fy in CONFIG$years) {
  S <- rd(file.path("data/shipped/features", sprintf("whr_features_%d.csv.gz", fy)))
  f <- work_path("whr", sprintf("feat_%d.rds", fy))
  if (!file.exists(f)) { say(fy, ": no rebuilt features in ", CONFIG$work_dir); next }
  R <- readRDS(f)
  m <- merge(S, R, by = "FULL_PROJECT_NUM", suffixes = c(".s", ".r"))
  nd <- 0
  for (k in key) { d <- m[[paste0(k, ".s")]] != m[[paste0(k, ".r")]]; d[is.na(d)] <- TRUE; nd <- nd + sum(d)
    if (any(d)) diffs[[length(diffs) + 1]] <- data.table(FY = fy, FULL_PROJECT_NUM = m$FULL_PROJECT_NUM[d], feature = k) }
  out[[length(out) + 1]] <- data.table(FY = fy, shipped = nrow(S), rebuilt = nrow(R), only_shipped = nrow(S) - nrow(m),
    only_rebuilt = nrow(R) - nrow(m), usd_diff = sum(m$USD.r - m$USD.s), feature_disagreements = nd)
}
O <- rbindlist(out); print(O)
dir.create(CONFIG$out_dir, showWarnings = FALSE)
fwrite(rbindlist(diffs), file.path(CONFIG$out_dir, "compare_to_shipped.csv"))
say(if (all(O$only_shipped == 0 & O$only_rebuilt == 0 & O$feature_disagreements == 0)) "rebuild identical to shipped data" else "differences found (see outputs/compare_to_shipped.csv)")
