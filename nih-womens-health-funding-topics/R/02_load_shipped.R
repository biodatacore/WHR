#' 02_load_shipped.R -- load the shipped replication data (data/shipped/) into work_dir.
#'
#' PURPOSE  Default route for outside analysts. Converts the compressed CSV files that ship
#'          with the repository (see data/README.md) into the intermediate .rds files that
#'          R/02_build.R and the feature step of R/03_classify.R would otherwise create from
#'          the raw NIH files:
#'            data/shipped/features/whr_features_{FY}.csv.gz  -> work_dir/whr/feat_{FY}.rds
#'            data/shipped/cv_features/cv_row_features_{FY}.csv.gz -> work_dir/cv/feat_{FY}.rds  (if present)
#'            data/shipped/text/whr_text_{FY}.csv.gz        -> work_dir/proj/proj_{FY}.rds,
#'                                                             work_dir/proj/projz_{FY}.rds (FY2020/2024)
#'            data/shipped/universe/intramural_no_text.csv  -> work_dir/proj/zfix_rows_{FY}.rds
#'            data/shipped/universe/nih_project_universe.csv.gz -> work_dir/whr/universe.rds (if present)
#'          The text files hold only the projects classified as WHR (the universe of the topic
#'          analyses), so steps 03-07 run unchanged and reproduce every published number.
#' USAGE    Rscript R/02_load_shipped.R     (run_all.R calls it automatically when no raw data exist)
#' CHECKS   MD5 of every shipped file against data/shipped/MD5SUMS (base R tools::md5sum) before loading.

source("R/00_setup.R")
S <- file.path("data", "shipped")
if (!dir.exists(S)) stop("data/shipped/ not found: clone the full repository (see README.md).")

# ---- integrity -------------------------------------------------------------------------------
sums <- read.table(file.path(S, "MD5SUMS"), col.names = c("sha", "file"), colClasses = "character")
got <- unname(tools::md5sum(file.path(S, sums$file)))
if (any(is.na(got) | got != sums$sha)) stop("checksum mismatch or missing file:\n  ", paste(sums$file[is.na(got) | got != sums$sha], collapse = "\n  "))
say("checksums OK for ", nrow(sums), " shipped files")

#' RFC-4180 reader (base R handles quoted fields that begin with a quote; fread does not).
rd <- function(f, chr) {
  con <- if (grepl("\\.gz$", f)) gzfile(f) else file(f)
  hdr <- names(read.csv(con, nrows = 1, check.names = FALSE))
  con <- if (grepl("\\.gz$", f)) gzfile(f) else file(f)
  cc <- setNames(rep(NA_character_, length(hdr)), hdr); cc[intersect(chr, hdr)] <- "character"
  d <- read.csv(con, na.strings = "NA", colClasses = cc, encoding = "UTF-8", check.names = FALSE)
  setDT(d); d
}
CHR <- c("FULL_PROJECT_NUM", "APPLICATION_ID", "CORE_PROJECT_NUM", "title", "PROJECT_TITLE", "text", "IC", "ACT", "cls", "conf", "source")
for (d in c("whr", "cv", "proj")) dir.create(work_path(d), recursive = TRUE, showWarnings = FALSE)

nt <- rd(file.path(S, "universe", "intramural_no_text.csv"), CHR)
for (fy in CONFIG$years) {
  saveRDS(rd(file.path(S, "features", sprintf("whr_features_%d.csv.gz", fy)), CHR), work_path("whr", sprintf("feat_%d.rds", fy)))
  f <- file.path(S, "cv_features", sprintf("cv_row_features_%d.csv.gz", fy))
  if (file.exists(f)) saveRDS(rd(f, CHR), work_path("cv", sprintf("feat_%d.rds", fy)))
  t <- rd(file.path(S, "text", sprintf("whr_text_%d.csv.gz", fy)), CHR)
  saveRDS(t[source == "file", !"source"], work_path("proj", sprintf("proj_%d.rds", fy)))
  if (fy %in% CONFIG$zfix_years) {
    saveRDS(t[source == "api_intramural", !"source"], work_path("proj", sprintf("projz_%d.rds", fy)))
    # only FULL_PROJECT_NUM / ABSTRACT_TEXT are used downstream (projects still without text)
    saveRDS(data.table(FULL_PROJECT_NUM = nt[FY == fy]$FULL_PROJECT_NUM, ABSTRACT_TEXT = NA_character_),
            work_path("proj", sprintf("zfix_rows_%d.rds", fy)))
  }
  say(fy, ": loaded")
}
f <- file.path(S, "universe", "nih_project_universe.csv.gz")
if (file.exists(f)) saveRDS(rd(f, CHR), work_path("whr", "universe.rds"))
writeLines(format(Sys.time()), work_path("SHIPPED"))   # marker read by 03_classify.R
say("shipped data loaded into ", CONFIG$work_dir)
