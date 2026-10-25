#' run_all.R -- run the whole pipeline in order, then the verification.
#'
#' USAGE   Rscript R/run_all.R              # default: shipped data (data/shipped) if data/raw is absent,
#'                                          # otherwise steps 01-07 from the saved raw data
#'         Rscript R/run_all.R --shipped    # force the shipped-data route (02_load_shipped.R replaces 01/02)
#'         Rscript R/run_all.R --raw        # force the raw-data route
#'         Rscript R/run_all.R --fetch      # let 01_download.R download missing API data and
#'                                          # 01b_mortality.R re-query CDC WONDER
#'         Rscript R/run_all.R --from 04    # resume from a step (intermediate files are kept)
#' Each step runs in a fresh R process so memory is released between steps; timings are printed.

args <- commandArgs(trailingOnly = TRUE)
raw_dir <- Sys.getenv("WHR_RAW_DIR", "data/raw")
shipped <- "--shipped" %in% args || (!"--raw" %in% args && !dir.exists(raw_dir) && dir.exists("data/shipped"))
if (shipped && !"--raw" %in% args) {
  wd <- Sys.getenv("WHR_WORK_DIR", "data/work")
  if (!dir.exists(wd) || !file.exists(file.path(wd, "SHIPPED"))) {   # a work dir built from raw data would be overwritten
    if (dir.exists(wd) && length(list.files(wd))) stop("work_dir ", wd, " holds files from the raw-data route; use another WHR_WORK_DIR for the shipped route")
  }
  cat("route: shipped data (data/shipped)\n")
} else cat("route: raw data (", raw_dir, ")\n", sep = "")
steps <- if (shipped) c("01b_mortality.R", "02_load_shipped.R", "03_classify.R", "04_analysis.R", "05_topics.R", "06_figures.R",
           "06b_figure1_mortality.R", "07_verify.R") else c("01_download.R", "01b_mortality.R", "02_build.R", "03_classify.R", "04_analysis.R", "05_topics.R", "06_figures.R",
           "06b_figure1_mortality.R", "07_verify.R")
from <- if ("--from" %in% args) args[which(args == "--from") + 1] else "01"
steps <- steps[which(startsWith(steps, from))[1]:length(steps)]   # e.g. --from 06b
rs <- file.path(R.home("bin"), "Rscript")
t00 <- Sys.time()
for (s in steps) {
  t0 <- Sys.time(); cat("\n=== ", s, "\n", sep = "")
  extra <- if ("--fetch" %in% args && s %in% c("01_download.R", "01b_mortality.R")) "--fetch" else character(0)
  st <- system2(rs, c(file.path("R", s), extra))
  cat(sprintf("--- %s finished in %.1f min (exit %d)\n", s, as.numeric(difftime(Sys.time(), t0, units = "mins")), st))
  if (st != 0) stop(s, " failed")
}
cat(sprintf("\npipeline finished in %.1f min\n", as.numeric(difftime(Sys.time(), t00, units = "mins"))))
