# Provenance only: builds the v12 sampling frame from intermediate pipeline files of a full raw run
# (v11c calls, the earlier validation call file and the per-year project tables in the work directory).
# These intermediates are not shipped; strata.csv and results/ hold everything needed to rescore.
# Sampling frame: all v11c project-years FY2013-2025 with text, plus USD and IC
suppressMessages(library(data.table))
C <- fread("val/v11c_calls.csv", colClasses=c(FULL_PROJECT_NUM="character"))
N <- fread(cmd="zcat work/calls_v11.csv.gz", select=c("FY","FULL_PROJECT_NUM","CORE_PROJECT_NUM","notext"), colClasses=c(FULL_PROJECT_NUM="character"))
X <- merge(C, unique(N, by=c("FY","FULL_PROJECT_NUM")), by=c("FY","FULL_PROJECT_NUM"))
P <- rbindlist(lapply(2013:2025, function(fy){p<-readRDS(sprintf("work/proj/proj_%d.rds",fy))
  p<-unique(p[, .(FULL_PROJECT_NUM, USD, IC, hastext=!is.na(text)&nchar(text)>50)], by="FULL_PROJECT_NUM"); p[,FY:=fy]; p}))
X <- merge(X, P, by=c("FY","FULL_PROJECT_NUM"))
cat("merged", nrow(X), "\n")
X <- X[FY<=2025 & notext!=TRUE & hastext==TRUE]
X[is.na(USD), USD:=0]
fwrite(X[, .(FY,FULL_PROJECT_NUM,CORE_PROJECT_NUM,IC,USD,t3,cv)], "work/frame.csv"); cat("frame", nrow(X), "\n")
