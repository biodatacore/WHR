#' v10.R -- rule changes approved for the v10 rerun (2026-10-31). See CHANGE_LOG.md.
#'
#' Every change sits behind a switch so that its effect can be attributed. The active switches
#' come from the environment variable WHR_V10_RULES (comma-separated; "all" = default; "none" =
#' v9 logic, which reproduces the v9 classification exactly):
#'   imp0   intramural projects still without text (FY2020/2024; 47 project-years, mostly ZIF)
#'          imputed at 0% WHR. The dollar-weighted intramural rate of the other years is kept
#'          as the "_imp" sensitivity (6.53% under the v9 rules; 7.29% when re-estimated
#'          under the v10 rules on the 2026-10-31 run).
#'   topics autoimmune disease -> "profound", osteoporosis -> "predominant" (NASEM Table 7-1 / Ch. 3)
#'   a      pregnancy / maternal-fetal projects count as WHR only with maternal-outcome evidence
#'   b      no blanket centre/training/network exclusion; such grants count when they show
#'          women's or maternal outcome evidence
#'   c      blood-disorder grants and tumour-vessel / tumour-endothelium grants are not CV
#'   d      breast cancer is women-specific: breast-cancer projects count as WHR
#'   e      any cardiotoxicity counts as CV
#'   f      female-predominant conditions (NASEM list) count as WHR without a separate women mention
#'   excl   exclusion sensitivities remove the excluded awards from numerator AND denominator
#' Sourced by R/00_setup.R after terms.R and utils.R.

.v10_env <- Sys.getenv("WHR_V10_RULES", "all")
V10_ALL <- c("imp0", "topics", "a", "b", "c", "d", "e", "f", "excl")
V10 <- if (.v10_env == "all") V10_ALL else if (.v10_env %in% c("none", "")) character(0) else strsplit(.v10_env, ",", fixed = TRUE)[[1]]
v10_on <- function(k) k %in% V10
V10_KW_VARIANTS <- TRUE   # keyword_classify() also returns the rule (a)/(b) variants

# ---------------------------------------------------------------------------------------
# v10 terms (lower-cased text, Python/ICU syntax as in terms.R)
# ---------------------------------------------------------------------------------------
# (b) women's / maternal OUTCOME evidence (required for centre/training/network grants)
V10_WOUT <- alt(c(
  r"---(\b(?:wom[ae]n|female|maternal|mothers?|girls?)(?:'s)? (?:health|outcomes?|morbidity|mortality|survival|well-?being)\b)---",
  r"---(\boutcomes? (?:in|among|for|of) (?:wom[ae]n|mothers|pregnant|postpartum|girls|females)\b)---",
  r"---(\bhealth of (?:wom[ae]n|mothers|pregnant))---"))
# (d) breast cancer
V10_BREAST <- alt(c(
  r"---(\bbreast (?:cancers?|tumou?rs?|carcinomas?|neoplasms?|malignan\w*)\b)---",
  r"---(\bmammary (?:tumou?r\w*|carcinoma\w*|cancers?|adenocarcinoma\w*))---",
  r"---(\btriple[- ]negative\b)---", r"---(\btnbc\b)---", r"---(\bductal carcinoma)---", r"---(\bdcis\b)---",
  r"---(\bher2[- ]?(?:positive|amplified|enriched))---", r"---(\bmammogra\w*)---"))
# (f) female-predominant conditions: NASEM 2025 (Box 7-1: autoimmune and chronic conditions in
# women; Ch. 3: ME/CFS, RA, osteoporosis, migraine, fibromyalgia) plus the v9 list
V10_FPRED <- alt(c(
  r"---(\blupus\b)---", r"---(\bsj[oö]gren\w*)---", r"---(\brheumatoid arthritis)---", r"---(\bmultiple sclerosis)---",
  r"---(\bsystemic sclerosis)---", r"---(\bscleroderma)---", r"---(\bhashimoto\w*)---", r"---(\bgraves\W* disease)---",
  r"---(\bautoimmune thyroid\w*)---", r"---(\bthyroiditis)---", r"---(\bthyroid (?:disease|autoimmun\w*))---",
  r"---(\bantiphospholipid)---", r"---(\bprimary biliary (?:cholangitis|cirrhosis))---",
  r"---(\bosteoporo\w*)---", r"---(\bmigraine\w*)---", r"---(\bfibromyalgia)---", r"---(\bchronic fatigue)---",
  r"---(\bmyalgic encephalomyelitis)---", r"---(\bme/cfs)---", r"---(\btemporomandibular)---", r"---(\birritable bowel)---",
  r"---(\binterstitial cystitis)---", r"---(\bbladder pain)---", r"---(\bvulvodynia)---", r"---(\bchronic pelvic pain)---",
  r"---(\burinary incontinence)---", r"---(\bpelvic floor)---", r"---(\burinary tract infections?)---",
  r"---(\beating disorders?)---", r"---(\banorexia nervosa)---", r"---(\bbulimi\w*)---", r"---(\bbinge eating)---",
  r"---(\blymphangioleiomyomatosis)---"))
# (c) blood disorders (sickle cell, TTP, coagulation-only)
V10_HEME <- alt(c(
  r"---(\bsickle\b)---", r"---(\bthalass[ae]mi\w*)---", r"---(\bthrombotic thrombocytopenic purpura)---", r"---(\bttp\b)---",
  r"---(\bhaem?ophilia\w*)---", r"---(\bvon willebrand)---", r"---(\b(?:coagulation|clotting) factors?)---",
  r"---(\bfactor (?:viii|ix|xi|xiii|fviii)\b)---", r"---(\bbleeding disorders?)---", r"---(\bplatelet (?:disorders?|function disorders?))---",
  r"---(\bimmune thrombocytopeni\w*)---", r"---(\bthrombocytopeni\w*)---", r"---(\bhemoglobinopath\w*)---",
  r"---(\bhaem?ostasis)---", r"---(\bcoagulopath\w*)---", r"---(\bhemolytic uremic)---", r"---(\bparoxysmal nocturnal)---",
  r"---(\ban(?:a)?emia)---", r"---(\bhemolysis)---"))
# title terms that keep a blood-disorder grant CV (cardiac, pulmonary-vascular, thrombotic or cerebrovascular disease)
V10_HEME_CV_TITLE <- r"---(\b(?:cardiac|cardio\w*|heart|myocardi\w*|coronary|pulmonary hypertension|venous thrombo\w*|thromboembol\w*|deep vein|pulmonary embol\w*|thrombosis|strokes?|cerebrovascular|atheroscl\w*|vasculopathy|aort\w*)\b)---"
# (c) tumour-vessel / tumour-endothelium phrases, blanked like CV_EXC
V10_TUMVASC_EXC <- alt(c(
  r"---(tumou?r[- ]?endotheli\w*(?: cells?)?)---", r"---(tumou?r (?:blood )?vessels?)---", r"---(tumou?r microvascul\w*)---",
  r"---((?:tumou?r|cancer)[- ]associated (?:endotheli\w*|vessels?|vasculature))---", r"---((?:tumou?r|cancer) angiogenesis)---",
  r"---(angiogenesis (?:in|of) (?:tumou?rs?|cancers?))---", r"---(tumou?r perfusion)---", r"---(vascular normali[sz]ation)---",
  r"---(vascular mimicry)---", r"---(endothelial cells? (?:in|of) (?:the )?(?:tumou?rs?|cancers?))---"))
# (c) cancer context for the tumour-vessel rule
V10_CANCER <- r"---(\b(?:cancers?|tumou?rs?|oncolog\w*|carcinoma\w*|metasta\w*|glioblastoma\w*|gliomas?|melanoma\w*|lymphoma\w*|leuka?emi\w*|sarcoma\w*|neoplas\w*)\b)---"
# (e) cardiotoxicity of any type
V10_CARDIOTOX <- alt(c(
  r"---(\bcardiotox\w*)---", r"---(\bcardiac toxicit\w*)---", r"---(\bcardiovascular toxicit\w*)---", r"---(\bcardio-?oncolog\w*)---",
  r"---(\b(?:anthracycline|doxorubicin|chemotherapy|trastuzumab|radiation|radiotherapy|drug|immunotherapy|checkpoint inhibitor|treatment)[- ]induced (?:cardi\w*|heart|arrhythmi\w*|myocarditis|qt))---",
  r"---(\bqt[- ]prolong\w*)---", r"---(\btorsades?)---", r"---(\bdrug[- ]induced arrhythmi\w*)---"))

# ---------------------------------------------------------------------------------------
# WHR features and tiers (override the definitions in 03_classify.R)
# ---------------------------------------------------------------------------------------
V10_FEATURES <- list(wout = V10_WOUT, breast = V10_BREAST, fpred = V10_FPRED)

v10_features <- function(P, fy) {
  X <- data.table(FY = fy, FULL_PROJECT_NUM = P$FULL_PROJECT_NUM, USD = P$USD, cls = P$Classification,
                  conf = P$Confidence, title = P$PROJECT_TITLE, ACT = P$ACT, IC = P$IC,
                  CORE_PROJECT_NUM = P$CORE_PROJECT_NUM,
                  cls_np = P$cls_np, conf_np = P$conf_np, cls_nb = P$cls_nb, conf_nb = P$conf_nb,
                  cls_npnb = P$cls_npnb, conf_npnb = P$conf_npnb)
  for (k in names(FEATURES)) {
    set(X, j = k, value = n_match(P$text, FEATURES[[k]]))
    set(X, j = paste0("t_", k), value = has_match(P$title_l, FEATURES[[k]]))
  }
  for (k in names(V10_FEATURES)) {
    set(X, j = k, value = n_match(P$text, V10_FEATURES[[k]]))
    set(X, j = paste0("t_", k), value = has_match(P$title_l, V10_FEATURES[[k]]))
  }
  cbind(X, sexdiff_flag(P$text, P$title_l))
}

#' S5.3-S5.6 tiers with the v10 switches. With no switch on, identical to the v9 assign_tiers().
#' data/shipped is the v10 cache (FY2026 freeze 2026-10-31) and includes these columns.
#' A feature table that lacks them stops with an explicit error. WHR_V10_RULES=none still runs.
v10_assign_tiers <- function(X) {
  need <- c("cls_np", "conf_np", "cls_nb", "conf_nb", "cls_npnb", "conf_npnb",
            "wout", "breast", "t_breast", "fpred", "t_fpred")
  if (any(v10_on(c("a", "b", "d", "f")))) {
    miss <- setdiff(need, names(X))
    if (length(miss)) {
      stop("Cached WHR features lack v10 columns (", paste(miss, collapse = ", "),
           "). The committed data/shipped extract includes them (FY2026 freeze 2026-10-31). ",
           "Rebuild this table from raw project text with WHR_REBUILD=1, or set WHR_V10_RULES=none to run the previous rules. See README.md.")
    }
  }
  CENT <- grepl(CENTER_ACTIVITY, fifelse(is.na(X$ACT), "", X$ACT), perl = TRUE) |
    has_match(fifelse(is.na(X$title), "nan", stri_trans_tolower(X$title)), CENTER_TITLE)
  w <- X$women
  wf <- X$t_women | w >= 3
  hit <- function(c) X[[c]] >= 3 | X[[paste0("t_", c)]]
  any1 <- function(c) X[[c]] >= 1 | X[[paste0("t_", c)]]
  # (a) maternal-outcome evidence: >= 2 maternal-outcome terms, or one in the title
  matev <- X$matout >= 2 | X$t_matout
  # (b) women's / maternal outcome evidence for centre, training and network grants
  outev <- if ("wout" %in% names(X)) (X$wout >= 1 | matev) else rep(FALSE, nrow(X))
  use_np <- v10_on("a") & !matev
  use_nb <- v10_on("b") & outev
  if (any(use_np) || any(use_nb)) {
    X[, cls_v := fifelse(use_np, fifelse(use_nb, cls_npnb, cls_np), fifelse(use_nb, cls_nb, cls))]
    X[, conf_v := fifelse(use_np, fifelse(use_nb, conf_npnb, conf_np), fifelse(use_nb, conf_nb, conf))]
  } else {
    X[, `:=`(cls_v = cls, conf_v = conf)]
  }
  X[, kw_strict := cls_v == "WHR" & conf_v == "High"]
  X[, kw_main := cls_v == "WHR"]
  X[, kw_broad := kw_main | (cls_v == "Non-WHR" & conf_v == "Low")]
  X[, kw_strict_v9 := cls == "WHR" & conf == "High"]
  base <- X$kw_strict | X$sexdiff
  v1 <- with(X, list(
    maternal = mat >= 3 & (if (v10_on("a")) matev else matout >= 1),
    multicancer = cancer >= 3 & (bg >= 2 | (CENT & bg >= 1)),
    hiv_sti_women = hiv >= 3 & (w >= 3 | t_women),
    female_predominant = if (v10_on("f")) (fpred >= 3 | t_fpred) else (femprev >= 3 | t_femprev) & w >= 1,
    repro = repro >= 4 & male < repro / 2 & (w >= 1 | t_repro)))
  if (v10_on("d")) v1$breast_cancer <- X$t_breast | X$breast >= 2
  v2 <- list(perinatal_dep = (X$c_perinatal_dep >= 1 | X$t_c_perinatal_dep) & w >= 1)
  for (c in c("depression", "anxiety", "ptsd", "alzheimer", "ild"))
    v2[[c]] <- hit(paste0("c_", c)) & wf
  v2[["rheumatoid"]] <- hit("c_rheumatoid") & (if (v10_on("f")) TRUE else wf)
  for (c in c("thyroid", "tmd", "cfs", "other"))
    v2[[c]] <- hit(paste0("c_", c)) & (if (v10_on("f")) TRUE else w >= 1)
  v3 <- with(X, list(
    hpv_vaccine = any1("n_hpvvax"),
    microbicide = any1("n_microbicide") & hiv >= 2 & w >= 2,
    lam = any1("n_lam"),
    uti = hit("n_uti") & (if (v10_on("f")) TRUE else w >= 1),
    puberty_girls = hit("n_puberty") & w >= 2,
    latina = any1("n_latina"),
    sexual_violence = (n_sexviol >= 2 | t_n_sexviol) & w >= 1,
    female_population = hit("n_fempop") & w >= 2))
  nc <- with(X, list(bothsex_sexdiff = a3 >= 2 & sexd >= 1 & w >= 2,
                     maternal_sensitivity = mat >= 6))
  anyl <- function(l) Reduce(`|`, l)
  first_rule <- function(l) { M <- do.call(cbind, l); r <- max.col(M, ties.method = "first"); fifelse(rowSums(M) > 0, names(l)[r], "") }
  X[, base := base]
  X[, t1 := base | anyl(v1)]; X[, r1 := first_rule(c(list(kw_strict = X$kw_strict, sexdiff = X$sexdiff), v1))]
  X[, t2 := t1 | anyl(v2)]; X[, r2 := first_rule(v2)]
  X[, add3 := anyl(v3) & !t2]; X[, r3 := first_rule(v3)]
  X[, t3 := t2 | add3]
  X[, addnc := anyl(nc) & !t3]; X[, rnc := first_rule(nc)]
  X[, tnc := t3 | addnc]
  X[, `:=`(matev = matev, outev = outev)]
  X[]
}

#' S5.7 yearly shares. imp0: the no-text intramural projects get 0% WHR in the main series; the
#' observed intramural rate (the v9 method) is kept as the "_imp" sensitivity columns.
v10_yearly <- function(X, zrows) {
  X[, Z := !is.na(ACT) & startsWith(ACT, "Z")]
  nt <- rbindlist(lapply(names(zrows), function(fy) {
    z <- zrows[[fy]]; data.table(FY = as.integer(fy), FULL_PROJECT_NUM = unique(z$FULL_PROJECT_NUM[is.na(z$ABSTRACT_TEXT)]))
  }))
  X[, notext := paste(FY, FULL_PROJECT_NUM) %in% paste(nt$FY, nt$FULL_PROJECT_NUM)]
  zo <- X[Z & !FY %in% CONFIG$zfix_years]
  rate_obs <- sapply(c("base", "t3", "tnc"), function(c) sum(zo$USD[zo[[c]]]) / sum(zo$USD))
  rate <- if (v10_on("imp0")) rate_obs * 0 else rate_obs
  Y <- rbindlist(lapply(CONFIG$years, function(fy) {
    x <- X[FY == fy]; Tt <- sum(x$USD)
    d <- list(FY = fy, nih_projects = nrow(x), nih_B = Tt / 1e9)
    for (c in c("base", "t3", "tnc")) {
      lab <- c(base = "strict_sexdiff", t3 = "v3", tnc = "nasem_comp")[[c]]
      u <- sum(x$USD[x[[c]] & !x$notext]) + rate[[c]] * sum(x$USD[x$notext])
      ui <- sum(x$USD[x[[c]] & !x$notext]) + rate_obs[[c]] * sum(x$USD[x$notext])
      d[[paste0(lab, "_n")]] <- sum(x[[c]] & !x$notext)
      d[[paste0(lab, "_B")]] <- u / 1e9
      d[[paste0(lab, "_pct")]] <- 100 * u / Tt
      d[[paste0(lab, "_pct_imp")]] <- 100 * ui / Tt
    }
    d$imputed_B <- sum(x$USD[x$notext]) / 1e9
    d$NASEM <- unname(NASEM_PUBLISHED_PCT[as.character(fy)])
    d
  }))
  list(Y = Y, rate = rate, rate_obs = rate_obs)
}

# ---------------------------------------------------------------------------------------
# CV row features and tiers (rules c and e)
# ---------------------------------------------------------------------------------------
V10_CV_EXC <- paste(CV_EXC, V10_TUMVASC_EXC, sep = "|")

v10_cv_tiers <- function(F) {
  if (any(v10_on(c("c", "e")))) {
    need <- c("ts10", "tw10", "s10", "w10", "canc", "t_canc", "heme", "t_heme", "t_hemecv", "ctox", "t_ctox")
    miss <- setdiff(need, names(F))
    if (length(miss)) {
      stop("Cached CV row features lack v10 columns (", paste(miss, collapse = ", "),
           "). The committed data/shipped/cv_features extract includes them (FY2026 freeze 2026-10-31). ",
           "Rebuild from raw rows with WHR_REBUILD=1, or set WHR_V10_RULES=none. See README.md.")
    }
  }
  F[, strict9 := ts >= 1 | s >= 5]
  F[, broad9 := strict9 | s >= 3 | (s >= 2 & w >= 2) | (tw >= 1 & s >= 1) | (tw >= 1 & w >= 6) | (s >= 1 & w >= 5)]
  if (v10_on("c")) {
    F[, strict := ts10 >= 1 | s10 >= 5]
    F[, broad2 := strict | s10 >= 3 | (s10 >= 2 & w10 >= 2) | (tw10 >= 1 & s10 >= 1) | (tw10 >= 1 & w10 >= 6) | (s10 >= 1 & w10 >= 5)]
    # cancer grants whose CV signal is only weak vascular language (tumour vessels, angiogenesis)
    F[, tumvasc := (t_canc | canc >= 5) & ts10 == 0 & s10 < 3]
    # blood-disorder grants (sickle cell, TTP, coagulation) without cardiac/thrombotic/cerebrovascular disease in the title
    F[, heme_ctx := (t_heme | heme >= 3) & !t_hemecv]
    F[, `:=`(strict = strict & !tumvasc & !heme_ctx, broad2 = broad2 & !tumvasc & !heme_ctx)]
  } else {
    F[, `:=`(strict = strict9, broad2 = broad9, tumvasc = FALSE, heme_ctx = FALSE)]
  }
  if (v10_on("e")) {
    F[, ctox_hit := t_ctox | ctox >= 2 | (ctox >= 1 & s10 >= 2)]
    F[, broad2 := broad2 | ctox_hit]
  } else F[, ctox_hit := FALSE]
  core <- F$strict | (F$broad2 & F$wp >= 2)
  F[, wcv3 := core & (tws >= 1 | wp >= 2 | wsx >= 2 | (wm >= 2 & ww >= 2) | ww >= 6)]
  F[]
}
