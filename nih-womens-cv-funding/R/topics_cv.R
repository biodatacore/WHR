#' topics_cv.R -- topic dictionary for women's cardiovascular (CV) research (05_topics.R).
#'
#' Multi-label keyword dictionary, searched in the lower-cased project title and in the pooled
#' title + abstract + public health relevance text. A topic is assigned if its pattern occurs in
#' the TITLE, or at least twice in the text (drops passing mentions); the highly specific rare
#' topics in CV_TOPICS_ONE need only one hit anywhere. Projects matching no topic form the
#' residual "Other / general women's CV" category. Patterns are byte-identical to those used
#' for the published analysis (Python syntax; compiled through rx() in utils.R).
#' The dictionary was refined by reading random samples of hits per topic (for example,
#' "cmd" and "apo" were removed as false positives); it is not a manual coding.

CV_TOPICS <- c(
  `Hypertensive disorders of pregnancy` = r"---(pre-?eclampsia|eclampsia|hellp|gestational hypertension|hypertensive disorders? of pregnancy|hdp\b|pregnancy[- ]induced hypertension|hypertension (?:in|during) pregnancy|chronic hypertension in pregnancy)---",
  `Adverse pregnancy outcomes / maternal CV health (general)` = r"---(adverse pregnancy outcome|preterm (?:birth|delivery)|small[- ]for[- ]gestational|fetal growth restriction|stillbirth|numom2b|maternal (?:cardiovascular|cardiac|heart)|cardiovascular health (?:in|during|of) pregnan|pregnan\w* (?:and|&) (?:future |later |long-term )?cardiovascular|postpartum (?:cardiovascular|hypertension|blood pressure)|preconception)---",
  `Gestational diabetes & CV risk` = r"---(gestational diabetes|\bgdm\b)---",
  `Peripartum cardiomyopathy` = r"---(peripartum cardiomyopathy|postpartum cardiomyopathy|\bppcm\b|pregnancy[- ]associated cardiomyopathy)---",
  `Maternal mortality / severe maternal morbidity` = r"---(maternal (?:morbidity and )?mortality|maternal morbidity|maternal death|improve initiative|\(3m\)|severe maternal morbidity|\bsmm\b|pregnancy[- ]related (?:death|mortality))---",
  `Heart disease in pregnancy (congenital/structural, stroke)` = r"---((?:congenital heart disease|valv\w+ (?:heart )?disease|heart disease|stroke|aortic|arrhythmi\w*) (?:in|during) pregnan|pregnan\w* (?:in|among) women with (?:congenital|heart)|pregnancy[- ]associated stroke|cardio-obstetric)---",
  `Coronary microvascular dysfunction / INOCA / MINOCA` = r"---(coronary microvascular|microvascular angina|\binoca\b|\bminoca\b|ischemia with no(?:n-?)? ?obstructive|non-?obstructive coronary|coronary flow reserve|women'?s ischemia syndrome evaluation)---",
  `SCAD` = r"---(spontaneous coronary artery dissection|\bscad\b|fibromuscular dysplasia)---",
  `Takotsubo / stress cardiomyopathy` = r"---(takotsubo|tako-tsubo|stress cardiomyopathy|broken heart syndrome|apical ballooning)---",
  `Menopause / sex hormones & CVD` = r"---(menopaus|estrogen|oestrogen|estradiol|hormone (?:replacement )?therapy|\bhrt\b|ovarian hormone|ovariectom|sex hormone|ovarian (?:function|aging|reserve)|swan\b|study of women'?s health across the nation)---",
  `PCOS` = r"---(polycystic ovar|\bpcos\b)---",
  `Cardio-oncology (breast/gynecologic cancer)` = r"---((?:breast|ovarian|endometrial|cervical|gyn\w*) cancer.{0,200}(?:cardio|cardiac|heart|cardiotox)|(?:cardiotox|cardio-?oncolog|anthracycline|trastuzumab).{0,200}breast)---",
  `Sex differences / female-specific mechanisms` = r"---(sex differen|sex-specific|sexual dimorphi|sex as a biological variable|sex-dependent|sex-based differen|female[- ]specific|x chromosome|between (?:men|males) and (?:women|females)|in females compared|female (?:mice|rats))---",
  `Placental / maternal-fetal vascular biology` = r"---(placenta|trophoblast|uteroplacental|uterine arter|spiral arter|decidua)---",
  `Women's cohorts (WHI, Nurses' Health, etc.)` = r"---(women'?s health initiative|\bwhi\b|nurses'? health study|women'?s health study|\bwihs\b)---",
  `Lifestyle, obesity & social determinants in women` = r"---(physical activity|exercise|diet\b|dietary|obesity|weight loss|sleep|smoking|psychosocial|neighborhood|social determinant|health equity|disparit|racism|discrimination)---",
  `Offspring / developmental programming & perinatal` = r"---(offspring|developmental (?:origins|programming)|fetal programming|prenatal exposure|in utero|neonat|infant|perinatal stroke|childhood)---",
  `Autoimmune disease & CVD (lupus, RA)` = r"---(lupus|\bsle\b|rheumatoid arthritis|systemic sclerosis|autoimmun)---",
  `HIV & CVD in women` = r"---(\bhiv\b|human immunodeficiency)---"
)

#' Topics needing only one hit anywhere (rare, highly specific terms).
CV_TOPICS_ONE <- c("Coronary microvascular dysfunction / INOCA / MINOCA", "PCOS", "Peripartum cardiomyopathy", "SCAD", "Takotsubo / stress cardiomyopathy")
CV_OTHER <- "Other / general women's CV"
