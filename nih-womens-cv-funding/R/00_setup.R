#' 00_setup.R -- packages, configuration, keyword dictionaries and shared helpers.
#'
#' PURPOSE  Sourced at the top of every numbered script (and by R/run_all.R). It
#'            1. checks that the required CRAN packages are installed (and says how to install
#'               them if not),
#'            2. reads config.R (paths, fiscal years, seeds, API settings),
#'            3. loads the keyword dictionaries (R/terms.R) and helper functions (R/utils.R),
#'            4. creates the scratch and output directories.
#' USAGE    Run any step from the repository root, e.g.  Rscript R/02_build.R
#'          (scripts locate the repository root themselves, so the working directory only
#'          needs to be inside the repository).

local({
  # --- locate the repository root: the folder that holds config.R -----------------------
  d <- normalizePath(getwd())
  while (!file.exists(file.path(d, "config.R")) && dirname(d) != d) d <- dirname(d)
  if (!file.exists(file.path(d, "config.R"))) stop("Run the scripts from inside the repository (config.R not found).")
  setwd(d)
})

# --- required packages (all on CRAN) -------------------------------------------------------
.needed <- c("data.table", "stringi", "readxl", "jsonlite", "curl", "sandwich", "ggplot2", "openxlsx")
.missing <- .needed[!vapply(.needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(.missing)) {
  stop("Missing R packages: ", paste(.missing, collapse = ", "),
       "\nInstall with: install.packages(c(", paste0('"', .missing, '"', collapse = ", "), "))\n",
       "or restore the pinned versions with renv::restore() (see README.md).")
}
suppressPackageStartupMessages({
  library(data.table)
  library(stringi)
  library(ggplot2)
})
options(datatable.print.class = FALSE, width = 200, scipen = 6)

source("config.R")        # -> CONFIG (paths, years, seeds)
source("R/terms.R")       # -> keyword dictionaries (regular expressions)
source("R/utils.R")       # -> helper functions
setDTthreads(CONFIG$dt_threads)
for (.d in c(CONFIG$work_dir, CONFIG$out_dir)) dir.create(.d, recursive = TRUE, showWarnings = FALSE)
