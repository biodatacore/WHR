#' topics_whr.R -- two-level topic taxonomy for all NIH women's health research (05_topics.R).
#'
#' Each row is (group, subtopic, pattern). A subtopic is assigned if its pattern occurs in the
#' lower-cased TITLE, or at least twice in the pooled title + abstract + PHR text; subtopics in
#' WHR_SUB_ONE need only one hit. A group is assigned if any of its subtopics is. Projects with
#' no subtopic form the residual group "7 Other / general women's health". Patterns are
#' byte-identical to those used for the published analysis (Python syntax; compiled through
#' rx() in utils.R).
#' NOTE (kept for exact reproduction): the "\\bgog\\b" alternative of the gynecologic-oncology
#' subtopic contains literal backslashes, so it never matches; "gynecologic oncology" and
#' "nrg oncology" carry that subtopic. Fixing it would change the published numbers slightly.

WHR_TOPICS <- data.table::rbindlist(list(
  list(group = "1 Female-specific conditions", subtopic = "Endometriosis / adenomyosis", pattern = r"---(endometrio(?:sis|tic)|adenomyosis)---"),
  list(group = "1 Female-specific conditions", subtopic = "Uterine fibroids", pattern = r"---(fibroid|leiomyoma)---"),
  list(group = "1 Female-specific conditions", subtopic = "PCOS", pattern = r"---(polycystic ovar|\bpcos\b)---"),
  list(group = "1 Female-specific conditions", subtopic = "Menopause / ovarian aging / hormone therapy", pattern = r"---(menopaus|ovarian aging|ovarian reserve|hot flash|vasomotor symptom|hormone (?:replacement )?therapy|\bswan\b|study of women'?s health across the nation)---"),
  list(group = "1 Female-specific conditions", subtopic = "Infertility / ART / reproductive biology", pattern = r"---(infertil|in vitro fertili|\bivf\b|assisted reproduct|oocyte|ovulat|folliculogenesis|ovarian follicle|ovarian (?:function|failure|insufficiency)|endometri(?:um|al receptivity|al stromal)|menstrua|uterine biology|female reproductive)---"),
  list(group = "1 Female-specific conditions", subtopic = "Contraception / family planning / abortion", pattern = r"---(contracepti|family planning|abortion|intrauterine device|\biud\b|levonorgestrel)---"),
  list(group = "1 Female-specific conditions", subtopic = "Vulvovaginal / pelvic floor / gyn conditions", pattern = r"---(vagin|vulv|bacterial vaginosis|pelvic floor|pelvic organ prolapse|dyspareunia|vulvodynia|chronic pelvic pain|dysmenorrhea|gynecolog(?:ic|ical) (?:condition|disorder|health))---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Pregnancy complications / placenta", pattern = r"---(pregnancy complication|placenta|trophoblast|fetal growth restriction|small[- ]for[- ]gestational|stillbirth|miscarriage|pregnancy loss|adverse pregnancy outcome|chorioamnionitis)---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Preterm birth / labor", pattern = r"---(preterm (?:birth|labor|delivery)|premature birth|parturition|\blabor\b|cervical ripening|cesarean)---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Hypertensive disorders of pregnancy", pattern = r"---(pre-?eclampsia|eclampsia|hellp|gestational hypertension|hypertensive disorders? of pregnancy)---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Gestational diabetes", pattern = r"---(gestational diabetes|\bgdm\b)---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Maternal mortality / SMM", pattern = r"---(maternal (?:morbidity and )?mortality|severe maternal morbidity|maternal morbidity|maternal death|pregnancy[- ]related (?:death|mortality)|improve initiative)---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Postpartum / lactation / breastfeeding", pattern = r"---(postpartum|lactat|breastfe|breast milk|human milk)---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Perinatal mental health / substance use in pregnancy", pattern = r"---(perinatal depression|postpartum depression|antenatal depression|prenatal depression|maternal depression|perinatal mood|(?:opioid|substance|alcohol|cannabis|marijuana|smoking|tobacco)\w* (?:use )?(?:in|during) pregnan|pregnant (?:women|people) (?:who|with) (?:use|opioid))---"),
  list(group = "2 Maternal / pregnancy health", subtopic = "Pregnancy cohorts / prenatal exposures (ECHO, nuMoM2b)", pattern = r"---(\becho\b|environmental influences on child health outcomes|numom2b|national children'?s study|prenatal exposure|pregnancy cohort|birth cohort|in utero exposure|prenatal care|maternal[- ]fetal|pregnan\w* (?:women|people))---"),
  list(group = "3 Female cancers", subtopic = "Breast cancer", pattern = r"---(breast cancer|breast tumou?r|mammary (?:tumor|carcinoma|cancer)|ductal carcinoma|\bbrca[12]?\b|mammograph|breast carcinoma|her2)---"),
  list(group = "3 Female cancers", subtopic = "Ovarian cancer", pattern = r"---(ovarian cancer|ovarian carcinoma|ovarian tumou?r|high[- ]grade serous)---"),
  list(group = "3 Female cancers", subtopic = "Cervical cancer / HPV", pattern = r"---(cervical cancer|cervical (?:intraepithelial|neoplasia|carcinoma)|human papillomavirus|\bhpv\b|pap (?:smear|test))---"),
  list(group = "3 Female cancers", subtopic = "Uterine / endometrial cancer", pattern = r"---(endometrial cancer|endometrial carcinoma|uterine (?:cancer|serous|carcinosarcoma|sarcoma))---"),
  list(group = "3 Female cancers", subtopic = "Gynecologic oncology networks (NRG/GOG) / gyn cancer general", pattern = r"---(nrg oncology|gynecologic oncology|gynecologic(?:al)? (?:cancer|malignanc)|\\bgog\\b|vulvar cancer|vaginal cancer)---"),
  list(group = "4 Female-predominant conditions", subtopic = "Autoimmune (lupus, RA, MS, Sjogren, scleroderma)", pattern = r"---(lupus|\bsle\b|rheumatoid arthritis|multiple sclerosis|sj[oö]gren|systemic sclerosis|scleroderma|autoimmun)---"),
  list(group = "4 Female-predominant conditions", subtopic = "Osteoporosis / bone", pattern = r"---(osteopor|bone (?:mineral )?density|bone loss|fracture|osteopenia)---"),
  list(group = "4 Female-predominant conditions", subtopic = "Alzheimer's / dementia / cognitive aging", pattern = r"---(alzheimer|dementia|cognitive (?:decline|aging|impairment))---"),
  list(group = "4 Female-predominant conditions", subtopic = "Depression / anxiety / PTSD / eating disorders", pattern = r"---(depress|anxiety|ptsd|posttraumatic|post-traumatic|eating disorder|anorexia nervosa|bulimia|binge eating)---"),
  list(group = "4 Female-predominant conditions", subtopic = "Migraine / chronic pain / fibromyalgia", pattern = r"---(migraine|fibromyalgia|chronic pain|chronic overlapping pain|temporomandibular|interstitial cystitis|irritable bowel)---"),
  list(group = "4 Female-predominant conditions", subtopic = "Thyroid", pattern = r"---(thyroid (?:disease|disorder|dysfunction|function|cancer|autoimmun|hormone)|hypothyroid|hyperthyroid|graves'? disease|hashimoto)---"),
  list(group = "4 Female-predominant conditions", subtopic = "Urinary incontinence / UTI", pattern = r"---(incontinence|urinary tract infection|\buti\b|overactive bladder|lower urinary tract)---"),
  list(group = "5 Sex differences / conditions affecting women differently", subtopic = "Cardiovascular / metabolic in women", pattern = r"---(cardiovascular|heart disease|hypertension|stroke|coronary|cardiac|atheroscler|obesity|diabetes|cardiometabolic)---"),
  list(group = "5 Sex differences / conditions affecting women differently", subtopic = "HIV / STIs in women", pattern = r"---(\bhiv\b|human immunodeficiency|sexually transmitted|\bstis?\b|chlamydia|gonorrh|syphilis|herpes simplex|trichomon|\bwihs\b|\bprep\b)---"),
  list(group = "5 Sex differences / conditions affecting women differently", subtopic = "Substance use / alcohol / tobacco", pattern = r"---(substance use|opioid|alcohol|tobacco|smoking|cigarette|nicotine|cannabis|marijuana|cocaine|methamphetamine)---"),
  list(group = "5 Sex differences / conditions affecting women differently", subtopic = "Sex-differences biology", pattern = r"---(sex differen|sex-specific|sexual dimorphi|sex as a biological variable|sex-dependent|sex-based differen|sex chromosome|x chromosome|four core genotypes|in females compared|between (?:men|males) and (?:women|females))---"),
  list(group = "5 Sex differences / conditions affecting women differently", subtopic = "Women's cohorts (WHI, Nurses' Health)", pattern = r"---(women'?s health initiative|\bwhi\b|nurses'? health study|women'?s health study)---"),
  list(group = "6 Violence / social determinants", subtopic = "Intimate partner violence / sexual assault", pattern = r"---(intimate partner violence|\bipv\b|domestic violence|sexual (?:assault|violence|abuse)|\brape\b|gender[- ]based violence|dating violence)---"),
  list(group = "6 Violence / social determinants", subtopic = "Health equity / social determinants in women", pattern = r"---(health equity|disparit|social determinant|racism|discrimination|neighborhood|socioeconomic|rural women|underserved|minority women|black women|latina|hispanic women)---")
))

#' Subtopics needing only one hit anywhere.
WHR_SUB_ONE <- c("Endometriosis / adenomyosis", "Gestational diabetes", "Hypertensive disorders of pregnancy", "Intimate partner violence / sexual assault", "Ovarian cancer", "PCOS", "Uterine / endometrial cancer", "Uterine fibroids")
WHR_OTHER <- "7 Other / general women's health"
