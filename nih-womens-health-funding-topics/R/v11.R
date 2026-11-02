#' v11.R -- rule changes for the v11 rerun (2026-11-01). See CHANGE_LOG.md (v11).
#'
#' All v10 rules stay on (R/v10.R). The v11 changes sit behind switches so that each one can be
#' attributed. Active switches come from WHR_V11_RULES (comma-separated; "all" = default;
#' "none" = v10 logic exactly; "C" = Cw,Ct,Cv):
#'   A   tiered female-predominant criterion (v10 condition list):
#'         Tier A (>= 2:1 female or >= 2/3 women) counts when CENTRAL: >= 2 mentions of the same
#'         condition or a title hit (v10: >= 3 pooled mentions);
#'         (IBS and binge-eating disorder are Tier A, as in v10's list.) Women-focus-gated (Tier B) conditions count
#'         only with a women focus or substantive sex-differences research;
#'         profound conditions (depression, anxiety, PTSD, Alzheimer's) keep the v10 women-focus rule.
#'   B   new conditions: Tier A additions (SCAD, takotsubo, PAH, POTS, autoimmune hepatitis,
#'         hypo-/hyperthyroidism, thyroid cancer, gallstones, microscopic colitis, IIH, CRPS,
#'         Raynaud, GCA/PMR, lichen sclerosus, pelvic organ prolapse, INOCA / coronary microvascular dysfunction, MINOCA); women-focus-gated
#'         additions (HFpEF, intimate
#'         partner violence); over-matching fixes ("chronic fatigue" in cancer/other-disease
#'         contexts; urinary incontinence / pelvic floor in post-prostatectomy or male contexts).
#'   Cw  WHR precision: pregnancy studies that use maternal exposures only for offspring
#'         outcomes lose maternal-outcome evidence; preclinical tool contexts (mouse mammary
#'         tumour virus, estrogen as an assay stimulus) do not count as breast-cancer or
#'         hormone evidence; centre / training / network grants need >= 2 women's or maternal
#'         outcome phrases (or one in the title).
#'   Ct  topic tagging (total-WHR topics): the mixed-sex "profound" condition topics (CVD,
#'         diabetes/obesity, Alzheimer's, depression/anxiety, osteoporosis, CV/metabolic in women)
#'         need a title hit or >= 3 text hits (v10: >= 2).
#'   Cv  CV precision: a row is not broad CV when its strong CV terms occur only in background /
#'         future-application sentences (none in the title or an aim sentence, < 5 mentions), or
#'         when it has a single strong CV mention outside the title and aims; blood-brain-barrier
#'         injury and white-matter lesions are not CV on their own (blanked before counting).
#' Sourced by R/00_setup.R after R/v10.R.

.v11_env <- Sys.getenv("WHR_V11_RULES", "all")
V11_ALL <- c("A", "B", "Cw", "Ct", "Cv", "D1", "D2", "D3", "D4", "D5", "D6")
V11 <- if (.v11_env == "all") V11_ALL else if (.v11_env %in% c("none", "")) character(0) else {
  s <- strsplit(.v11_env, ",", fixed = TRUE)[[1]]; unique(unlist(lapply(s, function(k) if (k == "C") c("Cw", "Ct", "Cv") else if (k == "D") paste0("D", 1:6) else k)))
}
v11_on <- function(k) k %in% V11

# ---------------------------------------------------------------------------------------
# Female-predominant conditions, one count column per condition (fp_<name>, t_fp_<name>).
# Tier and source (NIH ORWH / published female:male ratios) are in
# docs/female_predominant_conditions.csv. "old" = v10 list (switch A); "new" = switch B.
# ---------------------------------------------------------------------------------------
V11_FP <- data.table::rbindlist(list(
  # ---- v10 list (switch A) ------------------------------------------------------------------
  list(name = "lupus",     tier = "A", set = "old", pattern = r"---(\blupus\b)---"),
  list(name = "sjogren",   tier = "A", set = "old", pattern = r"---(\bsj[oö]gren\w*)---"),
  list(name = "ra",        tier = "A", set = "old", pattern = r"---(\brheumatoid arthritis)---"),
  list(name = "ms",        tier = "A", set = "old", pattern = r"---(\bmultiple sclerosis)---"),
  list(name = "ssc",       tier = "A", set = "old", pattern = r"---(\bsystemic sclerosis|\bscleroderma)---"),
  list(name = "aithyroid", tier = "A", set = "old", pattern = r"---(\bhashimoto\w*|\bgraves\W* disease|\bautoimmune thyroid\w*|\bthyroiditis|\bthyroid (?:disease|autoimmun\w*))---"),
  list(name = "aps",       tier = "A", set = "old", pattern = r"---(\bantiphospholipid)---"),
  list(name = "pbc",       tier = "A", set = "old", pattern = r"---(\bprimary biliary (?:cholangitis|cirrhosis))---"),
  list(name = "osteopor",  tier = "A", set = "old", pattern = r"---(\bosteoporo\w*)---"),
  list(name = "migraine",  tier = "A", set = "old", pattern = r"---(\bmigraine\w*)---"),
  list(name = "fibro",     tier = "A", set = "old", pattern = r"---(\bfibromyalgia)---"),
  list(name = "cfs_raw",   tier = "A", set = "old", pattern = r"---(\bchronic fatigue|\bmyalgic encephalomyelitis|\bme/cfs)---"),
  list(name = "tmd",       tier = "A", set = "old", pattern = r"---(\btemporomandibular|\btmds?\b)---"),
  list(name = "ic",        tier = "A", set = "old", pattern = r"---(\binterstitial cystitis|\bbladder pain)---"),
  list(name = "pelvicpain",tier = "A", set = "old", pattern = r"---(\bvulvodynia|\bpelvic pain)---"),
  list(name = "uro_raw",   tier = "A", set = "old", pattern = r"---(\burinary incontinence|\bpelvic floor)---"),
  list(name = "uti",       tier = "A", set = "old", pattern = r"---(\burinary tract infections?)---"),
  list(name = "ed",        tier = "A", set = "old", pattern = r"---((?<!binge[- ])\beating disorders?|\banorexia nervosa|\bbulimi\w*)---"),
  list(name = "lam",       tier = "A", set = "old", pattern = r"---(\blymphangioleiomyomatosis)---"),
  list(name = "ibs",       tier = "A", set = "old", pattern = r"---(\birritable bowel)---"),
  list(name = "binge",     tier = "A", set = "old", pattern = r"---(\bbinge[- ]eating)---"),
  # ---- v11 additions and over-matching fixes (switch B) -----------------------------------
  list(name = "cfs",       tier = "A", set = "new", pattern = r"---(\bmyalgic encephalomyelitis|\bme/cfs|\bchronic fatigue syndrome|(?<!cancer[- ]related )(?<!treatment[- ]related )\bchronic fatigue\b(?! syndrome)(?![^.;]{0,80}\b(?:cancers?|survivors?|chemotherap\w*|radiotherap\w*|tumou?rs?|dialysis|hiv|multiple sclerosis|lupus|arthritis|heart failure|copd|kidney)\b))---"),
  list(name = "uro",       tier = "A", set = "new", pattern = r"---(\burinary incontinence|\bpelvic floor (?:disorders?|dysfunction|muscles?|symptoms|health|disease)|\bstress (?:urinary )?incontinence|\burge(?:ncy)? (?:urinary )?incontinence|\bmixed (?:urinary )?incontinence)---"),
  list(name = "scad",      tier = "A", set = "new", pattern = r"---(\bspontaneous coronary artery dissection|(?<!deviation \()(?<!dehydrogenase \()\bscad\b(?![- ]?(?:deficien\w*|enzyme|gene|protein|activity|mice|penalt\w*)))---"),
  list(name = "takotsubo", tier = "A", set = "new", pattern = r"---(\btako-?tsubo|(?<!induced )\bstress cardiomyopathy|\bbroken heart syndrome|\bapical ballooning syndrome)---"),
  list(name = "pah",       tier = "A", set = "new", pattern = r"---(\bpulmonary arterial hypertension)---"),
  list(name = "pots",      tier = "A", set = "new", pattern = r"---(\bpostural (?:orthostatic )?tachycardia syndrome|\bpots\b(?=[^.]{0,60}(?:tachycardia|orthostatic|dysautonomia|syncope)))---"),
  list(name = "aih",       tier = "A", set = "new", pattern = r"---(\bautoimmune hepatitis)---"),
  list(name = "thyroidfx", tier = "A", set = "new", pattern = r"---((?<!congenital )\bhypothyroid\w*|\bhyperthyroid\w*)---"),
  list(name = "thyca",     tier = "A", set = "new", pattern = r"---(\bthyroid (?:cancers?|carcinomas?|neoplasms?|malignan\w*)|\bpapillary thyroid)---"),
  list(name = "gall",      tier = "A", set = "new", pattern = r"---(\bgallstones?|\bcholelithiasis|\bgallbladder stones?|\bcholesterol gallstone)---"),
  list(name = "mcolitis",  tier = "A", set = "new", pattern = r"---(\bmicroscopic colitis|\bcollagenous colitis|\blymphocytic colitis)---"),
  list(name = "iih",       tier = "A", set = "new", pattern = r"---(\bidiopathic intracranial hypertension|\bpseudotumou?r cerebri)---"),
  list(name = "crps",      tier = "A", set = "new", pattern = r"---(\bcomplex regional pain syndrome|\breflex sympathetic dystrophy)---"),
  list(name = "raynaud",   tier = "A", set = "new", pattern = r"---(\braynaud\w*)---"),
  list(name = "gcapmr",    tier = "A", set = "new", pattern = r"---(\bgiant[- ]cell arteritis|\bpolymyalgia rheumatica|\btemporal arteritis)---"),
  list(name = "lichen",    tier = "A", set = "new", pattern = r"---(\blichen sclerosus)---"),
  list(name = "pop",       tier = "A", set = "new", pattern = r"---(\bpelvic organ prolapse|\buterine prolapse|\bvaginal (?:vault )?prolapse)---"),
  list(name = "inoca",     tier = "A", set = "new", pattern = r"---(\bcoronary microvascular (?:dysfunction|disease)|\bmicrovascular angina|\binoca\b|\bischemia with no(?:n-?)? ?obstructive coronary)---"),
  list(name = "minoca",    tier = "A", set = "new", pattern = r"---(\bminoca\b|\bmyocardial infarction with no(?:n-?)? ?obstructive)---"),
  list(name = "hfpef",     tier = "B", set = "new", pattern = r"---(\bhfpef\b|\bheart failure with preserved ejection fraction)---"),
  list(name = "ipv",       tier = "B", set = "new", pattern = r"---(\bintimate partner violence|\bpartner violence|\bdomestic violence)---")
))
# male / post-prostatectomy context for urinary incontinence and pelvic floor (switch B)
V11_MALEURO <- r"---(\bprostatectom\w*|\bprostate cancer|\bbenign prostatic|\bbph\b|\bmen with (?:urinary|lower urinary|incontinence)|\bmale (?:patients|veterans|incontinence|lower urinary|pelvic floor)|\bincontinence in men\b|\berectile)---"

# ---- Cw: pregnancy studies with offspring-only outcomes ---------------------------------------
# maternal exposure phrases
V11_MEXPO <- r"---(\b(?:prenatal|in utero|intrauterine|gestational|maternal|perinatal|antenatal|fetal) (?:exposures?|exposed|smoking|nicotine|tobacco|alcohol|drug use|opioids?|cannabis|marijuana|stress|obesity|overweight|diabetes|hyperglyc\w*|diet|nutrition|high[- ]fat|undernutrition|malnutrition|infections?|immune activation|inflammation|hypoxia|environment|toxicants?|chemicals?|pollutants?|air pollution|medication|antidepressant\w*)\b|\bexposures? (?:in utero|during pregnancy|during gestation|before birth)|\bdevelopmental origins|\bfetal (?:origins|programming)|\bdevelopmental programming)---"
# offspring outcome phrases
V11_OFFOUT <- r"---(\boffspring\b|\b(?:fetal|fetus|infant|neonatal|newborn|child(?:hood)?|children'?s|pediatric|early[- ]life|adolescent) (?:outcomes?|development|growth|neurodevelopment\w*|brain|health|obesity|asthma|adiposity|cognition|cognitive|behavio\w*|heart|cardiac|lung|kidney|renal|metabolism|metabolic|autism|adhd|immune)\b|\bneurodevelopment\w*|\bautism\b|\badhd\b)---"
# strong maternal (mother's own) outcome phrases
V11_MATSTRONG <- r"---(\bmaternal (?:health|outcomes?|morbidity|mortality|depression|mental health|well-?being|cardiovascular health|blood pressure|weight gain|weight retention|quality of life|deaths?|complications?)\b|\bpostpartum (?:depression|weight|hypertension|blood pressure|health|hemorrhage|haemorrhage|cardiovascular|care|period|women|mothers)\b|\bpregnancy (?:outcomes?|complications?)\b|\b(?:outcomes?|health|well-?being) (?:of|in|for|among) (?:pregnant |postpartum )?(?:women|mothers)\b|\bmothers'? (?:health|depression|outcomes|well-?being)\b|\bsevere maternal morbidity|\bmaternal and (?:infant|child|neonatal|fetal|newborn) (?:health|outcomes?)|\bpre-?eclamp\w*|\beclampsia|\bgestational hypertension|\bhellp\b)---"
# ---- Cw: preclinical tool contexts ----------------------------------------------------------
V11_TOOL <- r"---(\bmouse mammary tumou?r virus|\bmmtv\b|\b(?:estrogen|estradiol|e2|17[- ]?(?:beta|β)[- ]?estradiol)[- ](?:stimulated|stimulation|treated|treatment of cells|induced (?:gene|transcription|proliferation|expression)|responsive (?:reporter|elements?|genes?)|response elements?)|\bere[- ]luciferase|\bestrogen response elements?)---"
V11_MMTV <- r"---(\bmouse mammary tumou?r virus)---"   # its "mammary tumor" also matched the breast-cancer feature

# ---- A: men-only studies (never qualify through the female-predominant rule) -------------------
V11_MENONLY <- r"---(\b(?:men|males?) only\b|\bonly (?:men|males)\b|\ball[- ]male\b|\b(?:older|elderly|aging|ageing|middle[- ]aged|hypogonadal|community[- ]dwelling) men\b|\bmale (?:veterans|participants|subjects|volunteers|cohort)\b|\bmros\b|\bosteoporotic fractures in men\b|\btestosterone trials?\b|\bmen who have sex with men\b|\bmsm\b)---"

# A: condition acronyms that count as a title hit (matched case-sensitively in the title only)
V11_TITLE_ACR <- list(ms = r"---(\bMS\b)---", lupus = r"---(\bSLE\b)---", ibs = r"---(\bIBS\b)---", cfs = r"---(\bME/CFS\b)---", cfs_raw = r"---(\bME/CFS\b)---",
                      pots = r"---(\bPOTS\b)---")

# ---- D (v11b): topic-level decisions of 2026-11-01 -----------------------------------------------
# D1 PAH / IBS acronyms (PAH counted only with pulmonary-hypertension context, not hydrocarbons)
V11_PAHACR <- r"---(\bpah\b)---"
V11_PHCTX  <- r"---(\bpulmonary (?:arterial |vascular )?hypertension|\bpulmonary vascular|\bright ventric\w*)---"
V11_PAHX   <- r"---(\bpolycyclic aromatic|\baromatic hydrocarbons?)---"
V11_IBSACR <- r"---(\bibs\b)---"
# D2 coronary microvascular dysfunction (any "coronary microvascular ..." phrase; precursor of INOCA)
V11_CMD <- r"---(\bcoronary microvascul\w*)---"
# D3 fetal / offspring outcome terms
V11_FETOFF <- r"---(\bfetal\b|\bfetus(?:es)?\b|\boffspring\b|\bin[- ]utero\b|\bplacenta\w*|\bbirth ?weight|\bneonat\w*|\bnewborns?\b|\bembryo\w*|\bchildren'?s (?:neuro)?development|\bchild (?:neuro)?development)---"
# D4 explicit sex-difference aims (not "sex as a biological variable" boilerplate)
V11_SEXAIM <- r"---(\b(?:role|impact|effects?|influence|contribution|importance) of (?:biological )?sex\b(?! (?:hormones?|steroids?|workers?|work|trafficking|education|partners?|offenders?|chromosomes?))|\bsex[- ]specific (?:differences|mechanisms|effects|responses|signaling|patterns)|\b(?:describe|characteri[sz]e|compare|examine|test|determine|assess|evaluate)\b[^.;]{0,60}\bby (?:[a-z]+, )*(?:and )?sex\b(?!ual)|\b(?:compare|comparing|comparison of|contrast\w*)\b[^.;]{0,30}\b(?:males? (?:and|vs\.?|versus|with) females?|females? (?:and|vs\.?|versus|with) males?|men (?:and|vs\.?|versus|with) women|women (?:and|vs\.?|versus|with) men)\b|\bsex[- ]by[- ]\w+ interactions?|\b(?:moderat|modif)\w* by (?:biological )?sex\b|\bsex (?:as a|is a) (?:key |critical |major )?(?:moderator|modifier))---"
# D3 strictly maternal outcomes / conditions (the v10 matout list also matches fetal-oriented pregnancy terms)
V11_MATCOND <- r"---(\bpre-?eclampsia|\beclampsia|\bgestational (?:diabetes|hypertension|weight gain)|\bhypertensive disorders? of pregnancy|\bpostpartum (?:hemorrhage|depression|hypertension|weight|health|care|period|women)|\bmaternal (?:mortality|morbidity|health|outcomes?|complications?|deaths?|weight gain|blood pressure|cardiovascular|hypertension|diabetes|obesity)|\bsevere maternal|\bpregnant (?:women|people|individuals|persons|patients)|\bwomen during pregnancy|\bmiscarriage|\bcesarean|\binfertil\w*|\bcontracep\w*|\bmenstru\w*|\bmenopaus\w*)---"
# D5 men-only phrases without the bare "mros" acronym (also mitochondrial ROS)
V11_MENONLY2 <- r"---(\b(?:men|males?) only\b|\bonly (?:men|males)\b|\ball[- ]male\b|\b(?:older|elderly|aging|ageing|middle[- ]aged|hypogonadal|community[- ]dwelling) men\b|\bmale (?:veterans|participants|subjects|volunteers|cohort)\b|\bmros (?:study|cohort|sleep|participants|men)\b|\bosteoporotic fractures in men\b|\btestosterone trials?\b|\bmen who have sex with men\b|\bmsm\b)---"
# D5 female animals (an ovariectomy model is not men-only)
V11_FEMANIMAL <- r"---(\bovariectom\w*|\bovx\b|\bfemale (?:mice|rats?|mouse|animals|rodents|monkeys|macaques|primates|pigs|sheep))---"
# D6 women-only cohorts
V11_WONLY <- r"---(\bwomen'?s health initiative|\bwhi\b|\bnurses'? health stud(?:y|ies)|\bstudy of women'?s health across the nation|\bswan\b|\bwomen'?s health study|\bsister study|\bstudy of osteoporotic fractures|\bblack women'?s health study|\bwhims\b)---"
V11_WENROLL <- r"---(\b(?:enrol\w*|recruit\w*|randomi[sz]\w*) (?:\d[\d,]* |up to \d[\d,]* |a cohort of |a sample of )?(?:[a-z'-]+ ){0,4}women\b(?! and (?:men|males))|\bwomen[- ]only\b|\bonly women\b|\ball[- ]female (?:cohort|sample|participants))---"
V11_MENWORD <- r"---(\bmen\b|\bboys?\b|\bmale (?:participants|subjects|patients|veterans|volunteers))---"
# title acronyms for D1 (case-sensitive)
V11_TITLE_ACR_D <- list(pah = r"---(\bPAH\b)---", ibs = r"---(\bIBS\b)---", inoca = r"---(\bINOCA\b|\bCMD\b|\bCMVD\b)---", minoca = r"---(\bMINOCA\b)---")

V11_FEATURES <- c(setNames(as.list(V11_FP$pattern), paste0("fp_", V11_FP$name)),
                  list(maleuro = V11_MALEURO, mexpo = V11_MEXPO, offout = V11_OFFOUT, matstrong = V11_MATSTRONG,
                       tool = V11_TOOL, mmtv = V11_MMTV, menonly = V11_MENONLY,
                       pahacr = V11_PAHACR, phctx = V11_PHCTX, pahx = V11_PAHX, ibsacr = V11_IBSACR, cmd = V11_CMD, fetoff = V11_FETOFF,
                       sexaim = V11_SEXAIM, femanimal = V11_FEMANIMAL, wonly = V11_WONLY, wenroll = V11_WENROLL, menword = V11_MENWORD,
                       matcond = V11_MATCOND, menonly2 = V11_MENONLY2))

v11_features <- function(P, fy) {
  X <- v10_features(P, fy)
  for (k in names(V11_FEATURES)) {
    set(X, j = k, value = n_match(P$text, V11_FEATURES[[k]]))
    set(X, j = paste0("t_", k), value = has_match(P$title_l, V11_FEATURES[[k]]))
  }
  X
}

#' Tiers: v10 tiers with the v11 switches. With no v11 switch on, identical to v10_assign_tiers().
v11_assign_tiers <- function(X) {
  if (!length(V11)) return(v10_assign_tiers(X))
  miss <- setdiff(c(paste0("fp_", V11_FP$name), "mexpo", "offout", "matstrong", "tool", "mmtv", "menonly", if (any(grepl("^D", V11))) c("pahacr", "phctx", "pahx", "ibsacr", "cmd", "fetoff", "sexaim", "femanimal", "wonly", "wenroll", "menword", "matcond", "menonly2")), names(X))
  if (length(miss)) stop("Cached WHR features lack v11 columns (", paste(head(miss, 5), collapse = ", "),
                         ", ...). data/shipped is a pre-v11 cache; rebuild with WHR_REBUILD=1 or set WHR_V11_RULES=none. See README.md.")
  CENT <- grepl(CENTER_ACTIVITY, fifelse(is.na(X$ACT), "", X$ACT), perl = TRUE) |
    has_match(fifelse(is.na(X$title), "nan", stri_trans_tolower(X$title)), CENTER_TITLE)
  w <- X$women
  wf <- X$t_women | w >= 3
  if (v11_on("D4")) X[, sexdiff := sexdiff | sexaim >= 1 | t_sexaim]   # D4 explicit sex-difference aims
  # D6 women-only cohort; D5 men-only definition excludes female animals and women-only cohorts
  wonly_v <- if (v11_on("D6")) X$wonly >= 1 | X$t_wonly | ((X$wenroll >= 1 | X$t_wenroll) & X$menword == 0 & !X$t_menword) else rep(FALSE, nrow(X))
  hit <- function(c) X[[c]] >= 3 | X[[paste0("t_", c)]]
  any1 <- function(c) X[[c]] >= 1 | X[[paste0("t_", c)]]
  central <- function(nm) X[[paste0("fp_", nm)]] >= 2 | X[[paste0("t_fp_", nm)]]
  # A: men-only study = a men-only phrase (title or text) and no women terms anywhere
  menonly <- (X$menonly >= 1 | X$t_menonly) & X$women == 0 & !X$t_women
  if (v11_on("D5")) menonly <- (X$menonly2 >= 1 | X$t_menonly2) & X$women == 0 & !X$t_women & X$femanimal == 0 & !X$t_femanimal & !(X$wonly >= 1 | X$t_wonly)
  # ---- Cw: offspring-only pregnancy studies and tool contexts --------------------------------
  offspring_only <- if (v11_on("Cw")) X$offout >= 2 & X$mexpo >= 1 & X$matstrong == 0 & !X$t_matstrong & !X$t_matout else rep(FALSE, nrow(X))
  matev <- (X$matout >= 2 | X$t_matout) & !offspring_only
  breast_n <- if (v11_on("Cw")) pmax(X$breast - X$mmtv, 0L) else X$breast
  tool_ctx <- if (v11_on("Cw")) X$tool >= 1 & w == 0 & !X$t_women & !X$t_breast & breast_n < 2 & !X$sexdiff else rep(FALSE, nrow(X))
  # ---- (b) centre / training / network grants ------------------------------------------------
  outev <- if (v11_on("Cw")) (X$wout >= 2 | X$t_wout | matev) else (X$wout >= 1 | matev)
  use_np <- v10_on("a") & !matev
  use_nb <- v10_on("b") & outev
  X[, cls_v := fifelse(use_np, fifelse(use_nb, cls_npnb, cls_np), fifelse(use_nb, cls_nb, cls))]
  X[, conf_v := fifelse(use_np, fifelse(use_nb, conf_npnb, conf_np), fifelse(use_nb, conf_nb, conf))]
  X[, kw_strict := cls_v == "WHR" & conf_v == "High" & !tool_ctx]
  X[, kw_main := cls_v == "WHR"]
  X[, kw_broad := kw_main | (cls_v == "Non-WHR" & conf_v == "Low")]
  X[, kw_strict_v9 := cls == "WHR" & conf == "High"]
  base <- X$kw_strict | X$sexdiff
  # ---- female-predominant conditions (A, B) --------------------------------------------------
  focus <- wf | X$sexdiff
  # title acronyms (case-sensitive, title only), e.g. "progressive MS"
  ttl <- fifelse(is.na(X$title), "", X$title)
  t_acr <- function(nm) if (nm %in% names(V11_TITLE_ACR)) stri_detect_regex(ttl, V11_TITLE_ACR[[nm]]) else FALSE
  centralA <- function(nm) X[[paste0("t_fp_", nm)]] | t_acr(nm) | (X[[paste0("fp_", nm)]] >= 2 & focus)
  if (v11_on("A") || v11_on("B")) {
    tierA <- V11_FP[tier == "A" & set == "old"]$name
    tierB <- V11_FP[tier == "B" & set == "old"]$name
    if (v11_on("B")) {
      tierA <- c(setdiff(tierA, c("cfs_raw", "uro_raw")), setdiff(V11_FP[tier == "A" & set == "new"]$name, "uro"))
      tierB <- c(tierB, V11_FP[tier == "B" & set == "new"]$name)
    }
    if (!v11_on("A")) {   # B alone: new terms on top of the v10 rule (pooled count, >= 3 or title)
      fpA <- (X$fpred >= 3 | X$t_fpred) | Reduce(`|`, lapply(setdiff(tierA, V11_FP[set == "old"]$name), central))
      fpB <- Reduce(`|`, lapply(V11_FP[tier == "B" & set == "new"]$name, central)) & focus
    } else {
      # A: a title hit counts on its own; abstract-only hits (>= 2 mentions) need a women focus
      fpA <- Reduce(`|`, lapply(tierA, centralA))
      fpB <- if (length(tierB)) Reduce(`|`, lapply(tierB, central)) & focus else rep(FALSE, nrow(X))
    }
    if (v11_on("B")) fpA <- fpA | ((if (v11_on("A")) centralA("uro") else central("uro")) & (X$maleuro == 0 | wf))
    fp_rule <- fpA | fpB
    # D1/D2: PAH, IBS, binge eating, INOCA/MINOCA/coronary microvascular dysfunction count whenever
    # they are a topic (one mention in title or abstract, acronyms included), with no women-focus gate
    fpD <- rep(FALSE, nrow(X))
    tacr <- function(nm) stri_detect_regex(ttl, V11_TITLE_ACR_D[[nm]])
    any1fp <- function(nm) X[[paste0("fp_", nm)]] >= 1 | X[[paste0("t_fp_", nm)]]
    if (v11_on("D1")) fpD <- fpD | any1fp("pah") | tacr("pah") | ((X$pahacr >= 1 | X$t_pahacr) & X$phctx >= 1 & X$pahx == 0) |
      any1fp("ibs") | tacr("ibs") | X$ibsacr >= 1 | X$t_ibsacr | any1fp("binge")
    if (v11_on("D2")) fpD <- fpD | any1fp("inoca") | any1fp("minoca") | X$cmd >= 1 | X$t_cmd | tacr("inoca") | tacr("minoca")
    fp_rule <- fp_rule | fpD
    if (v11_on("A")) fp_rule <- fp_rule & !menonly   # men-only studies never qualify through this rule
  } else { fp_rule <- (X$fpred >= 3 | X$t_fpred); fpD <- rep(FALSE, nrow(X)) }
  v1 <- with(X, list(
    maternal = mat >= 3 & matev,
    multicancer = cancer >= 3 & (bg >= 2 | (CENT & bg >= 1)),
    hiv_sti_women = hiv >= 3 & (w >= 3 | t_women),
    female_predominant = fp_rule,
    repro = repro >= 4 & male < repro / 2 & (w >= 1 | t_repro)))
  v1$breast_cancer <- X$t_breast | breast_n >= 2
  v2 <- list(perinatal_dep = (X$c_perinatal_dep >= 1 | X$t_c_perinatal_dep) & w >= 1)
  for (c in c("depression", "anxiety", "ptsd", "alzheimer", "ild"))
    v2[[c]] <- hit(paste0("c_", c)) & wf
  if (v11_on("A")) {
    # rheumatoid/thyroid/TMD/CFS/"other" conditions are covered by the per-condition Tier A/B rule
    for (c in c("rheumatoid", "thyroid", "tmd", "cfs", "other")) v2[[c]] <- rep(FALSE, nrow(X))
  } else {
    v2[["rheumatoid"]] <- hit("c_rheumatoid")
    for (c in c("thyroid", "tmd", "cfs", "other")) v2[[c]] <- hit(paste0("c_", c))
  }
  v3 <- with(X, list(
    hpv_vaccine = any1("n_hpvvax"),
    microbicide = any1("n_microbicide") & hiv >= 2 & w >= 2,
    lam = any1("n_lam"),
    uti = hit("n_uti"),
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
  # D3 fetal/offspring-only grants (no maternal outcome) are not WHR, unless a female cancer,
  # sex-differences or women-only-cohort rule applies; D5 men-only studies are never WHR;
  # D6 women-only cohorts always are
  fetal_only <- if (v11_on("D3")) !X$t_matcond & ((X$fetoff >= 3 & X$matcond <= 2 & X$fetoff >= 4 * X$matcond) | (X$t_fetoff & X$matcond <= 1) |
    (X$fetoff >= 1 & X$matcond == 0 & X$women == 0)) & !X$sexdiff & !v1$breast_cancer & !v1$multicancer & !wonly_v & !fpD else rep(FALSE, nrow(X))
  men_only <- if (v11_on("D5")) menonly else rep(FALSE, nrow(X))
  set(X, j = "t3", value = ((X$t3 & !fetal_only) | wonly_v) & !men_only)
  set(X, i = which(wonly_v & X$r1 == "" & X$r2 == "" & X$r3 == ""), j = "r1", value = "women_only_cohort")
  set(X, j = "fetal_only", value = fetal_only); set(X, j = "men_only", value = men_only); set(X, j = "women_only", value = wonly_v)
  X[, addnc := anyl(nc) & !t3]; X[, rnc := first_rule(nc)]
  set(X, j = "tnc", value = (X$t3 | X$addnc) & !men_only & !(fetal_only & !X$t3))
  X[, `:=`(matev = matev, outev = outev, offspring_only = offspring_only, tool_ctx = tool_ctx)]
  X[]
}

# ---------------------------------------------------------------------------------------
# Cv: CV row features and tiers
# ---------------------------------------------------------------------------------------
# blood-brain barrier and white-matter lesions are not CV on their own (blanked like CV_EXC)
V11_NEURO_EXC <- alt(c(
  r"---(blood[- ]brain[- ]barriers?(?: (?:injury|damage|disruption|breakdown|dysfunction|permeability|leakage|integrity))?)---",
  r"---(\bbbb (?:injury|damage|disruption|breakdown|dysfunction|permeability|leakage|integrity))---",
  r"---(white[- ]matter (?:lesions?|hyperintensit\w*|injury|damage|disease|abnormalit\w*))---"))
V11_CV_EXC <- paste(V10_CV_EXC, V11_NEURO_EXC, sep = "|")
# aim / objective sentences
V11_AIM <- r"---(\b(?:aims?\b|specific aims?|objectives?\b|hypothes\w*|we (?:will|propose|plan|aim|seek)|this (?:project|study|proposal|application|program|research) (?:will|aims|seeks|proposes|is designed)|goals? (?:of|is|are)|to (?:determine|test|examine|investigate|evaluate|assess|identify|characterize|define|elucidate|develop|compare|measure|quantify)\b))---"
# background / future-application sentences
V11_BGF <- r"---(\b(?:may|might|could|potential(?:ly)?|future|eventually|ultimately|long[- ]term goal|implications? for|relevan\w* (?:to|for)|applicable to|such as|leading causes?|risk factors? for|associated with|linked to|prevalen\w*|millions? of|burden|morbidity and mortality|is a major|are a major|including)\b)---"
PY_SPACE_V11 <- "[\\t\\n\\x0b\\f\\r\\x1c-\\x1f\\x85\\p{Z}]"

#' Strong CV term counts in aim sentences (saim) and in background/future sentences that are
#' not aim sentences (sbf). `tx` is the abstract + PHR text after the exclusion blanking.
v11_cv_sentences <- function(tx) {
  n <- length(tx); saim <- integer(n); sbf <- integer(n)
  cand <- which(has_match(tx, CV_STR))
  if (length(cand)) {
    S <- stri_split_regex(tx[cand], paste0("(?<=[.;!?])", PY_SPACE_V11, "+"))
    id <- rep(seq_along(S), lengths(S)); s <- unlist(S, use.names = FALSE)
    k <- n_match(s, CV_STR); keep <- k > 0; s <- s[keep]; id <- id[keep]; k <- k[keep]
    am <- has_match(s, V11_AIM); bf <- !am & has_match(s, V11_BGF)
    saim[cand] <- as.integer(rowsum(k * am, factor(id, levels = seq_along(cand)))[, 1])
    sbf[cand] <- as.integer(rowsum(k * bf, factor(id, levels = seq_along(cand)))[, 1])
  }
  list(saim = saim, sbf = sbf)
}

#' v11 row-level CV columns (added to the v10 row features in 03_classify.R).
v11_cv_row_features <- function(ti0, tx0) {
  ti <- stri_replace_all_regex(ti0, rx(V11_CV_EXC), " ")
  tx <- stri_replace_all_regex(tx0, rx(V11_CV_EXC), " ")
  sc <- v11_cv_sentences(tx)
  data.table(ts11 = n_match(ti, CV_STR), tw11 = n_match(ti, CV_WEAK), s11 = n_match(tx, CV_STR), w11 = n_match(tx, CV_WEAK),
             saim = sc$saim, sbf = sc$sbf)
}

v11_cv_tiers <- function(F) {
  F <- v10_cv_tiers(F)
  if (!v11_on("Cv")) return(F[, cv_dropped_v11 := FALSE][])
  miss <- setdiff(c("ts11", "tw11", "s11", "w11", "saim", "sbf"), names(F))
  if (length(miss)) stop("Cached CV row features lack v11 columns (", paste(miss, collapse = ", "),
                         "). Rebuild with WHR_REBUILD=1 or set WHR_V11_RULES without Cv. See README.md.")
  # strong CV terms only in background / future-application sentences (none in the title or an aim sentence)
  F[, bgonly := ts11 == 0 & saim == 0 & sbf >= s11 & s11 < 5]
  # a single strong CV mention outside the title and the aims (isolated keyword)
  F[, cv_isolated := ts11 == 0 & s11 <= 1 & saim == 0]
  F[, strict := (ts11 >= 1 | s11 >= 5) & !tumvasc & !heme_ctx]
  F[, broad2 := strict | s11 >= 3 | (s11 >= 2 & w11 >= 2) | (tw11 >= 1 & s11 >= 1) | (tw11 >= 1 & w11 >= 6) | (s11 >= 1 & w11 >= 5)]
  F[, broad2 := (broad2 & !tumvasc & !heme_ctx & !bgonly & !cv_isolated) | ctox_hit]
  F[, cv_dropped_v11 := broad9 & !broad2]
  core <- F$strict | (F$broad2 & F$wp >= 2)
  F[, wcv3 := core & (tws >= 1 | wp >= 2 | wsx >= 2 | (wm >= 2 & ww >= 2) | ww >= 6)]
  F[]
}

#' Ct: minimum text hits for a topic without a title hit. Only the mixed-sex "profound" condition
#' topics, where the reviewers found isolated keywords, background mentions and possible future
#' applications, need >= 3 hits; female-specific, maternal, female-cancer and female-predominant
#' topics keep >= 2 (raising those lost more true calls than it removed false ones).
V11_CT_TOPICS <- c("Alzheimer's / dementia / cognitive aging", "Depression / anxiety / PTSD / eating disorders", "Osteoporosis / bone",
                   "Cardiovascular / metabolic in women", "Cardiovascular disease", "Diabetes / obesity")
v11_topic_need <- function(need, topic) if (v11_on("Ct") && need >= 2 && topic %in% V11_CT_TOPICS) need + 1L else need
