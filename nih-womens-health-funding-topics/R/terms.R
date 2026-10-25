#' terms.R -- every keyword list and regular expression used by the classification.
#'
#' This file is a line-by-line translation of the keyword dictionaries used for the published
#' analysis. All patterns are applied to LOWER-CASED text (project title, abstract and public
#' health relevance statement) unless noted. Lists of alternatives are joined with "|" by alt();
#' the joined strings are byte-for-byte identical to the patterns that produced the published
#' results, so do not "tidy" them without re-running R/07_verify.R.
#'
#' Patterns are written as R raw strings r"---(...)---" so backslashes are exactly as in the
#' regular expression. They are compiled with the ICU engine (stringi) through rx() in
#' R/utils.R, which converts Python-style "." (any character except newline) to the ICU
#' equivalent "[^\n]"; see utils.R for the reason.
#'
#' Section numbers (S#.#) refer to the Supplementary Methods of the paper.

#' Join regular-expression alternatives with "|" (top-level alternation).
alt <- function(parts) paste(parts, collapse = "|")



# ---------------------------------------------------------------------------------------
# NIH universe (S3.1). Administering-IC two-letter codes counted as NIH. Used for
# FY2024-2026 directly and for the per-project WHR universe in all years.
# (FY2013-2023 CV / classifier universes use the committee file's IS_NIH flag instead.)
# ---------------------------------------------------------------------------------------
NIH_ICS <- c("AA", "AG", "AI", "AR", "AT", "CA", "CL", "CT", "DA", "DC", "DE", "DK", "EB", "ES", "EY", "GM", "HD", "HG", "HL", "LM", "MD", "MH", "NR", "NS", "OD", "TR", "TW", "WH")

# Activity codes treated as "centres / networks / cooperative groups" in the multi-cancer
# rule (S5.4): a centre grant needs only 1 breast/gynaecologic-cancer mention instead of 2.
CENTER_ACTIVITY <- r"---(^(P30|P50|P01|P20|U10|UG1|U54|U19|UM1|U24|N01|ZIA|U01|R35))---"
# ...plus these title phrases (matched in the lower-cased title):
CENTER_TITLE <- r"---(cancer center|oncology group|cooperative group|clinical trials network|spore|ncorp|oncology)---"

# ---------------------------------------------------------------------------------------
# S5.1  Keyword classification (strict / main / broad tiers).
# ---------------------------------------------------------------------------------------
# Condition/topic groups. The count of each group in title+abstract+PHR drives confidence.
CLS_CORE <- list(
    `pregnancy/maternal` = alt(c(
      r"---(\bpregnan\w*)---",
      r"---(\bmaternal\b)---",
      r"---(\bpostpartum\b)---",
      r"---(\bperinatal\b)---",
      r"---(\bprenatal\b)---",
      r"---(\bantenatal\b)---",
      r"---(eclampsia)---",
      r"---(\bpreterm (?:birth|labor|delivery))---",
      r"---(\bplacent\w*)---",
      r"---(\bmiscarriage)---",
      r"---(\bstillbirth)---",
      r"---(\bcesarean)---",
      r"---(\bcaesarean)---",
      r"---(\bchildbirth)---",
      r"---(\bgestational diabetes)---"
    )),
    `breast cancer` = alt(c(
      r"---(\bbreast (?:cancer|tumou?rs?|carcinoma|neoplasm))---",
      r"---(\bmammogra\w*)---",
      r"---(\bductal carcinoma)---"
    )),
    `gyn cancer/organs` = alt(c(
      r"---(\bovar(?:y|ian|ies)\b)---",
      r"---(\buter(?:us|ine)\b)---",
      r"---(\bendometri\w*)---",
      r"---(\bcervical (?:cancer|neoplasia|screening))---",
      r"---(\bcervix\b)---",
      r"---(\bvagin\w*)---",
      r"---(\bvulv\w*)---",
      r"---(\bgynecolog\w*)---",
      r"---(\bgynaecolog\w*)---",
      r"---(\bobstetric\w*)---",
      r"---(\bfibroids?\b)---",
      r"---(\bleiomyoma\w*)---",
      r"---(\bpolycystic ovary)---",
      r"---(\bpcos\b)---"
    )),
    `menopause/menstrual` = alt(c(
      r"---(\bmenopaus\w*)---",
      r"---(\bperimenopaus\w*)---",
      r"---(\bmenstru\w*)---",
      r"---(\bmenarche)---"
    )),
    `contraception/fertility` = alt(c(
      r"---(\bcontracepti\w*)---",
      r"---(\binfertil\w*)---",
      r"---(\bfemale fertility)---",
      r"---(\boocytes?\b)---",
      r"---(\bin vitro fertiliz\w*)---",
      r"---(\blactat(?:ion|ing)\b)---",
      r"---(\bbreastfe\w*)---",
      r"---(\bbreast milk)---"
    )),
    `sex/gender differences` = alt(c(
      r"---(\bsex differences?)---",
      r"---(\bsex-specific)---",
      r"---(\bsex as a biological variable)---",
      r"---(\bgender differences?)---",
      r"---(\bsexual(?:ly)? dimorphi\w*)---",
      r"---(\bsex-based)---",
      r"---(\bsex-dependent)---",
      r"---(\bsex disparit\w*)---"
    )),
    `female hormones` = alt(c(
      r"---(\bestrogens?\b)---",
      r"---(\boestrogens?\b)---",
      r"---(\bestradiol)---",
      r"---(\bprogesterone\b)---"
    )),
    `violence against women` = alt(c(
      r"---(\bintimate partner violence)---",
      r"---(\bdomestic violence)---",
      r"---(\bsexual assault)---"
    )),
    `female-prevalent conditions` = alt(c(
      r"---(\bosteoporosis)---",
      r"---(\bpelvic floor)---",
      r"---(\burinary incontinence)---",
      r"---(\blupus\b)---"
    ))
  )
# Women/female population words ...
CLS_POP <- alt(c(
    r"---(\bwom[ae]n\b)---",
    r"---(\bfemales?\b)---",
    r"---(\bgirls?\b)---",
    r"---(\bmothers?\b)---",
    r"---(\bwives\b)---"
  ))
# ... minus animal-model uses of "female" (subtracted from the population count).
CLS_EXCL <- r"---(\bfemale (?:mice|rats?|mouse|animals)\b)---"
# Groups NOT counted as "strong" (hormones and female-prevalent conditions are weaker evidence).
WEAK_GROUPS <- c("female hormones", "female-prevalent conditions")
# Title words that flag a centre/training/core grant.
CLS_TITLE_CENTER <- r"---(cancer center support|training|career development|core\b)---"
# Male-reproductive words: a WHR call is reversed if these outnumber female terms
# and the title has none of CLS_TITLE_FEMALE.
CLS_MALE <- alt(c(
    r"---(\bsperm\w*)---",
    r"---(\btest(?:is|es|icular)\b)---",
    r"---(\bmale (?:infertility|fertility|reproduct\w*))---",
    r"---(\bprostat\w*)---",
    r"---(\bepididym\w*)---",
    r"---(\bspermatogon\w*)---",
    r"---(\bmen\b)---"
  ))
CLS_TITLE_FEMALE <- r"---(wom[ae]n|female|girl|mother|pregnan|ovar|uter|breast)---"
# Broad / infrastructure grant titles: WHR is one component, not the primary focus.
CLS_BROAD <- alt(c(
    r"---(cancer center)---",
    r"---(support grant)---",
    r"---(training)---",
    r"---(career development)---",
    r"---(\bscholars?\b)---",
    r"---(\bcore\b)---",
    r"---(center for)---",
    r"---(research center)---",
    r"---(repository)---",
    r"---(symposium)---",
    r"---(conference)---",
    r"---(consortium)---"
  ))
# A High-confidence broad grant keeps WHR only at Low confidence unless its title has one of these:
CLS_TITLE_WHR_FOCUS <- r"---(wom[ae]n|maternal|pregnan|breast|ovar|gyn|uter|cervi|reproduct|perinatal)---"

# ---------------------------------------------------------------------------------------
# S5.3  Sex-differences research and the SABV boilerplate filter.
# ---------------------------------------------------------------------------------------
# Candidate phrases (a project is examined only if one appears).
SD_PH <- alt(c(
    r"---(sex differences?)---",
    r"---(sex-specific)---",
    r"---(sex specific)---",
    r"---(sex as a biological variable)---",
    r"---(sexual(?:ly)? dimorphi\w*)---",
    r"---(sex-dependent)---",
    r"---(sex dependent)---",
    r"---(sex-based differences)---",
    r"---(gender differences?)---",
    r"---(gender-specific)---",
    r"---(sex disparit\w*)---",
    r"---(sex-related differences)---",
    r"---(differ(?:s|ences?)? (?:between|by) (?:the )?sex(?:es)?)---",
    r"---(between males and females)---",
    r"---(male and female)---",
    r"---(in females\b)---",
    r"---(female (?:mice|rats|mouse|rat|animals))---",
    r"---((?:estrogen|estradiol|ovarian hormone|progesterone|sex hormone|gonadal hormone)s?\b)---"
  ))
# Phrases that count as substantive sex-difference content.
SD_STRONGPH <- alt(c(
    r"---(sex differences?)---",
    r"---(sex-specific)---",
    r"---(sexual(?:ly)? dimorphi\w*)---",
    r"---(sex-dependent)---",
    r"---(sex dependent)---",
    r"---(sex-based differences)---",
    r"---(gender differences?)---",
    r"---(sex disparit\w*)---",
    r"---(sex-related differences)---",
    r"---(differ\w* (?:between|by) (?:the )?sex(?:es)?)---",
    r"---((?:estrogen|estradiol|ovarian hormone|sex hormone|gonadal hormone)s?\b)---"
  ))
# Sentences containing any of these are treated as SABV-policy boilerplate and discarded.
SD_BOIL <- alt(c(
    r"---(both sexes)---",
    r"---(will be included)---",
    r"---(will include)---",
    r"---(include both)---",
    r"---(including both)---",
    r"---(equal numbers)---",
    r"---(balanced)---",
    r"---(sabv)---",
    r"---(nih policy)---",
    r"---(in accordance)---",
    r"---(consider(?:ed|ing)? sex as)---",
    r"---(as a biological variable will)---",
    r"---(will be considered)---",
    r"---(will be (?:used|studied|examined|analyzed))---",
    r"---(we will (?:also )?(?:use|include|study) (?:both )?male and female)---",
    r"---(power(?:ed)? to detect sex)---",
    r"---(exploratory)---",
    r"---(secondary)---",
    r"---(account for sex)---",
    r"---(covariate)---",
    r"---(stratif)---"
  ))
# Aim / hypothesis language: strong sentences that also contain this count as "aim" sentences.
SD_AIM <- r"---(\b(?:aim|hypothes\w*|we (?:will|propose to) (?:test|determine|investigate|examine|identify|define|elucidate|characterize)|test(?:ing)? whether|determine (?:whether|how|if)|investigat\w*|elucidat\w*|mechanism\w*|underl\w*|objective|goal|focus\w*)\b)---"
# Title test for sex-difference focus = STRONGPH or these extra words:
SD_TITLE_EXTRA <- r"---(|\bsex\b|\bfemales?\b|\bmale and female)---"

# ---------------------------------------------------------------------------------------
# S5.4  Partial-relevance tier v1 feature groups (counts in text; t_<name> = present in title).
# ---------------------------------------------------------------------------------------
V1_FEATURES <- list(
    `mat` = alt(c(
      r"---(\bpregnan\w*)---",
      r"---(\bmaternal\b)---",
      r"---(\bmothers?\b)---",
      r"---(\bpostpartum)---",
      r"---(\bperinatal)---",
      r"---(\bprenatal)---",
      r"---(\bantenatal)---",
      r"---(\bgestation\w*)---",
      r"---(\bplacent\w*)---",
      r"---(\bpreterm)---",
      r"---(\bobstetric\w*)---",
      r"---(\blabor and delivery)---",
      r"---(\bchildbirth)---",
      r"---(\bbreastfe\w*)---",
      r"---(\blactat\w*)---"
    )),
    `matout` = alt(c(
      r"---(\bmaternal (?:health|outcomes?|morbidity|mortality|depression|weight|obesity|diabetes|hypertension|complications?|mental health|well-being))---",
      r"---(\bpregnant wom[ae]n)---",
      r"---(\bpostpartum)---",
      r"---(\bpreeclampsia)---",
      r"---(\beclampsia)---",
      r"---(\bgestational diabetes)---",
      r"---(\bgestational weight)---",
      r"---(\bwomen during pregnancy)---",
      r"---(\bpregnancy outcomes?)---",
      r"---(\bpregnancy complications?)---",
      r"---(\bmothers\W+(?:health|depression|stress|outcomes))---",
      r"---(\bperinatal depression)---",
      r"---(\bpreterm (?:birth|labor|delivery))---",
      r"---(\bmiscarriage)---",
      r"---(\bstillbirth)---",
      r"---(\bcesarean)---",
      r"---(\bplacenta\w*)---",
      r"---(\blactation)---",
      r"---(\bbreastfeeding)---"
    )),
    `child` = alt(c(
      r"---(\bneonat\w*)---",
      r"---(\binfants?\b)---",
      r"---(\bnewborns?)---",
      r"---(\bfetal\b)---",
      r"---(\bfetus)---",
      r"---(\boffspring)---",
      r"---(\bchild(?:ren)?\b)---",
      r"---(\bpediatric)---"
    )),
    `bg` = alt(c(
      r"---(\bbreast (?:cancer|tumou?r|carcinoma))---",
      r"---(\bovarian cancer)---",
      r"---(\bcervical cancer)---",
      r"---(\bendometrial cancer)---",
      r"---(\buterine cancer)---",
      r"---(\bgynecologic\w* (?:cancer|oncology|malignan))---",
      r"---(\bmammogra\w*)---"
    )),
    `cancer` = alt(c(
      r"---(\bcancers?\b)---",
      r"---(\btumou?rs?\b)---",
      r"---(\boncolog\w*)---",
      r"---(\bcarcinoma)---"
    )),
    `hiv` = alt(c(
      r"---(\bhiv\b)---",
      r"---(\baids\b)---",
      r"---(\bprep\b)---",
      r"---(\bsexually transmitted)---",
      r"---(\bstis?\b)---",
      r"---(\bhpv\b)---",
      r"---(\bpapilloma\w*)---",
      r"---(\bmicrobicide)---",
      r"---(\bchlamydia)---",
      r"---(\bgonorrh\w*)---",
      r"---(\bsyphilis)---",
      r"---(\bbacterial vaginosis)---",
      r"---(\btrichomon\w*)---"
    )),
    `women` = alt(c(
      r"---(\bwom[ae]n\b)---",
      r"---(\bfemales?\b(?! (?:mice|rats?|mouse|animals)))---",
      r"---(\bgirls?\b)---",
      r"---(\bmothers?\b)---"
    )),
    `femprev` = alt(c(
      r"---(\blupus\b)---",
      r"---(\bosteoporo\w*)---",
      r"---(\bmigraine\w*)---",
      r"---(\bfibromyalgia)---",
      r"---(\birritable bowel)---",
      r"---(\bsj[oö]gren\w*)---",
      r"---(\binterstitial cystitis)---",
      r"---(\bbladder pain)---",
      r"---(\beating disorders?)---",
      r"---(\banorexia nervosa)---",
      r"---(\bbulimi\w*)---",
      r"---(\burinary tract infections?)---",
      r"---(\bthyroid (?:disease|autoimmun))---",
      r"---(\bhashimoto)---",
      r"---(\bgraves)---",
      r"---(\brheumatoid arthritis)---",
      r"---(\bsystemic sclerosis)---",
      r"---(\bscleroderma)---",
      r"---(\bchronic fatigue)---",
      r"---(\bmyalgic)---",
      r"---(\bpelvic pain)---",
      r"---(\bvulvodynia)---",
      r"---(\burinary incontinence)---",
      r"---(\bpelvic floor)---",
      r"---(\bmultiple sclerosis)---"
    )),
    `repro` = alt(c(
      r"---(\boocytes?\b)---",
      r"---(\bovar(?:y|ian|ies)\b)---",
      r"---(\bfollic\w*)---",
      r"---(\bovulat\w*)---",
      r"---(\buter(?:us|ine)\b)---",
      r"---(\bendometri\w*)---",
      r"---(\bimplantation)---",
      r"---(\bfemale reproduct\w*)---",
      r"---(\bfertility)---",
      r"---(\binfertil\w*)---",
      r"---(\bcorpus luteum)---",
      r"---(\bgranulosa)---",
      r"---(\bmenstru\w*)---",
      r"---(\bmenopaus\w*)---",
      r"---(\bin vitro fertiliz\w*)---",
      r"---(\bcontracep\w*)---"
    )),
    `male` = alt(c(
      r"---(\bsperm\w*)---",
      r"---(\btest(?:is|es|icular)\b)---",
      r"---(\bprostat\w*)---",
      r"---(\bmale (?:infertility|fertility|contracep\w*))---",
      r"---(\bspermatogon\w*)---"
    ))
  )

# ---------------------------------------------------------------------------------------
# S5.5  Partial tier v2: conditions that are more common / differently expressed in women.
# Feature names in the pipeline are 'c_<key>'.
# ---------------------------------------------------------------------------------------
V2_CONDITIONS <- list(
    `perinatal_dep` = alt(c(
      r"---(\b(?:perinatal|postpartum|post-partum|antenatal|prenatal|maternal) (?:depress\w*|mood|anxiety))---"
    )),
    `depression` = alt(c(
      r"---(\bdepress(?:ion|ive)\b)---"
    )),
    `anxiety` = alt(c(
      r"---(\banxiety\b)---"
    )),
    `ptsd` = alt(c(
      r"---(\bptsd\b)---",
      r"---(\bposttraumatic stress)---",
      r"---(\bpost-traumatic stress)---"
    )),
    `alzheimer` = alt(c(
      r"---(\balzheimer\w*)---"
    )),
    `rheumatoid` = alt(c(
      r"---(\brheumatoid arthritis)---"
    )),
    `thyroid` = alt(c(
      r"---(\bhashimoto\w*)---",
      r"---(\bgraves\W* disease)---",
      r"---(\bautoimmune thyroid\w*)---",
      r"---(\bthyroiditis)---"
    )),
    `tmd` = alt(c(
      r"---(\btemporomandibular)---",
      r"---(\btmds?\b)---"
    )),
    `ild` = alt(c(
      r"---(\binterstitial lung disease)---",
      r"---(\blymphangioleiomyomatosis)---",
      r"---(\blam\b)---"
    )),
    `cfs` = alt(c(
      r"---(\bchronic fatigue)---",
      r"---(\bmyalgic encephalomyelitis)---",
      r"---(\bme/cfs)---"
    )),
    `other` = alt(c(
      r"---(\bfibromyalgia)---",
      r"---(\birritable bowel)---",
      r"---(\bsj[oö]gren\w*)---",
      r"---(\bscleroderma)---",
      r"---(\bsystemic sclerosis)---",
      r"---(\burinary incontinence)---",
      r"---(\burinary tract infections?)---",
      r"---(\bvulvodynia)---",
      r"---(\bchronic pelvic pain)---",
      r"---(\bpelvic pain)---",
      r"---(\binterstitial cystitis)---",
      r"---(\bbladder pain)---"
    ))
  )

# ---------------------------------------------------------------------------------------
# S5.6  Partial tier v3 additions (feature names 'n_<key>') and NASEM-comparable extras.
# ---------------------------------------------------------------------------------------
V3_NEW <- list(
    `hpvvax` = alt(c(
      r"---(\bhpv vaccin\w*)---",
      r"---(\bpapillomavirus vaccin\w*)---"
    )),
    `microbicide` = alt(c(
      r"---(\bmicrobicid\w*)---",
      r"---(\bvaginal ring)---",
      r"---(\bdapivirine)---"
    )),
    `lam` = alt(c(
      r"---(\blymphangioleiomyomatosis)---",
      r"---(\blam\b(?=.{0,60}lung))---",
      r"---(\blung.{0,60}\blam\b)---"
    )),
    `uti` = alt(c(
      r"---(\burinary tract infections?)---",
      r"---(\butis?\b)---"
    )),
    `puberty` = alt(c(
      r"---(\bpubert\w*)---",
      r"---(\bmenarche)---"
    )),
    `latina` = alt(c(
      r"---(\blatinas?\b)---"
    )),
    `sexviol` = alt(c(
      r"---(\bsexual (?:victimization|assault|violence|abuse))---",
      r"---(\brape\b)---"
    )),
    `fempop` = alt(c(
      r"---(\bwives\b)---",
      r"---(\bwidows?\b)---",
      r"---(\bsisters?\b)---",
      r"---(\bdaughters?\b)---",
      r"---(\bgrandmothers?\b)---",
      r"---(\bfemale (?:sex workers|adolescents|veterans|partners|participants|patients))---",
      r"---(\bmotherhood)---",
      r"---(\bwomen\'s\b)---"
    ))
  )
# Common conditions studied in both sexes (NASEM-comparable "both-sex + sex differences" rule).
V3_A3 <- alt(c(
    r"---(\basthma)---",
    r"---(\bdiabet\w*)---",
    r"---(\bheart failure)---",
    r"---(\bcoronary)---",
    r"---(\blung cancer)---",
    r"---(\bstroke)---",
    r"---(\bcerebrovascular)---",
    r"---(\bhiv\b)---",
    r"---(\bsubstance (?:use|misuse))---",
    r"---(\bopioid)---",
    r"---(\balcohol use)---",
    r"---(\bautism)---",
    r"---(\banemia)---",
    r"---(\bpulmonary hypertension)---",
    r"---(\bosteoarthritis)---",
    r"---(\bcaregiv\w*)---",
    r"---(\bthyroid cancer)---",
    r"---(\bcarpal tunnel)---",
    r"---(\bdepress\w*)---",
    r"---(\banxiety)---",
    r"---(\balzheimer)---",
    r"---(\bobesity)---",
    r"---(\bhypertension)---",
    r"---(\bcardiovascular)---"
  ))
# Sex-difference phrases for the NASEM-comparable rule.
V3_SEXD <- alt(c(
    r"---(sex differences?)---",
    r"---(sex-specific)---",
    r"---(sexual(?:ly)? dimorphi\w*)---",
    r"---(sex-dependent)---",
    r"---(gender differences?)---",
    r"---(sex disparit\w*)---",
    r"---(differ\w* (?:between|by) (?:the )?sex(?:es)?)---",
    r"---(between (?:men and women|women and men|males and females))---"
  ))

# ---------------------------------------------------------------------------------------
# S9  Cardiovascular (CV) research and women's CV health (row-level; title and abstract+PHR
# are scored separately after EXC phrases are blanked out).
# ---------------------------------------------------------------------------------------
# False-positive phrases removed before counting (tumour angiogenesis, VEGF, heart rate, ...).
CV_EXC <- alt(c(
    r"---(vascular endothelial growth factors?(?: receptors?)?)---",
    r"---(vegf\w*)---",
    r"---(anti-?angiogen\w*)---",
    r"---(tumou?r[- ](?:angiogenesis|vasculature|vascular\w*|vessels?))---",
    r"---((?:cancer|tumou?r)[- ]associated vasculature)---",
    r"---(cardiorespiratory fitness)---",
    r"---(cardio-?respiratory fitness)---",
    r"---(heart rates?(?: variability)?)---",
    r"---((?:intracranial|ocular|portal|idiopathic intracranial) hypertension)---",
    r"---(heat ?stroke)---",
    r"---(sunstroke)---",
    r"---(at the heart of)---",
    r"---(heart of (?:the|this|our))---",
    r"---(lymphatic vessels?)---",
    r"---(hepatic vein)---",
    r"---(retinal vein occlusion)---"
  ))
# Strong (specific) CV terms.
CV_STR <- r"---(\b(?:cardiac|cardio(?:vascular|myopath\w*|myocyte\w*|logy|logists?|genic|toxicity|protect\w*|metabolic)|heart|hearts|coronary|myocardi\w*|arrhythmi\w*|atrial|(?:left|right|bi)[- ]?ventric\w*|ventricular (?:tachycardia|fibrillation|function|hypertrophy|remodeling)|heart valves?|valvular|aort\w*|hypertensi\w*|atheroscl\w*|atherothromb\w*|atherogen\w*|atheroma\w*|strokes?|cerebrovascular|intracerebral (?:hemorrhage|haemorrhage)|subarachnoid hemorrhage|aneurysm\w*|peripheral arter\w*|venous thrombo\w*|deep vein thrombosis|pulmonary embol\w*|thromboembol\w*|vasculitis|kawasaki|preeclamp\w*|pre-eclamp\w*|eclampsia|hypertensive disorders?|cardiomyopath\w*|takotsubo|angina|tetralogy|fontan|endothelial dysfunction|vascular (?:disease|diseases|biology|smooth muscle|dementia|cognitive|function|dysfunction|stiffness|inflammation|remodeling|injury|calcification|aging)|arterial stiffness|tachycardia|bradycardia|fibrillation|myocyte|cardiomyocyte\w*|cardiosurg\w*|cardiopulmonary bypass|ischemic (?:heart|stroke)|thrombosis)\b)---"
# Weak (non-specific vascular / lipid) terms.
CV_WEAK <- r"---(\b(?:vascular\w*|vasculature|endotheli\w*|blood pressure|angiogen\w*|veins?|venous|arteri\w*|artery|thromb\w*|microvascul\w*|vasodilat\w*|vasoconstrict\w*|vessels?|perfusion|cholesterol|lipoprotein\w*|dyslipid\w*|statins?)\b)---"
# Women/female words in the TITLE.
CV_WT <- r"---(\b(?:women|woman|female|females|maternal|mothers?|pregnan\w*|sex differences?|sex-specific|sex dimorph\w*|sexual dimorph\w*|menopaus\w*|postmenopaus\w*|perimenopaus\w*|postpartum|peripartum|girls?|gestational|obstetric\w*|estrogen\w*|ovar\w*)\b)---"
# Pregnancy-related and women-specific CV conditions.
CV_WP <- alt(c(
    r"---(preeclamp\w*)---",
    r"---(pre-eclamp\w*)---",
    r"---(eclampsia)---",
    r"---(hypertensive disorders? of pregnancy)---",
    r"---(gestational hypertension)---",
    r"---((?:peri|post)partum cardiomyopathy)---",
    r"---(spontaneous coronary artery dissection)---",
    r"---(\bscad\b)---",
    r"---(takotsubo)---",
    r"---(\binoca\b)---",
    r"---(\bminoca\b)---",
    r"---(coronary microvascular dysfunction)---",
    r"---(women'?s ischemia syndrome)---",
    r"---(fibromuscular dysplasia)---",
    r"---(pregnancy[- ]related (?:cardiovascular|cardiac|heart|hypertension))---",
    r"---(maternal (?:cardiovascular|cardiac|heart|hypertension))---",
    r"---(adverse pregnancy outcomes)---"
  ))
# Menopause / hormone terms.
CV_WM <- alt(c(
    r"---(menopaus\w*)---",
    r"---(postmenopaus\w*)---",
    r"---(perimenopaus\w*)---",
    r"---(estrogen\w*)---",
    r"---(hormone (?:replacement )?therapy)---",
    r"---(polycystic ovar\w*)---",
    r"---(\bpcos\b)---"
  ))
# Sex-difference / women-focused phrases.
CV_WS <- alt(c(
    r"---(sex differences?)---",
    r"---(sex-specific)---",
    r"---(sex dimorph\w*)---",
    r"---(sexual dimorph\w*)---",
    r"---(between (?:men and women|women and men|males and females|females and males))---",
    r"---(sex-based differences)---",
    r"---(in women)---",
    r"---(among women)---",
    r"---(female-specific)---",
    r"---(women'?s (?:heart|cardiovascular))---"
  ))
# Plain women/female words.
CV_WW <- r"---(\b(?:women|woman|female|females)\b)---"
