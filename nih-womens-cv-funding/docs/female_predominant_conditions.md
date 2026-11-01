# Female-predominant conditions (pipeline v11)

One count column per condition in the WHR feature tables (`fp_<name>`, title flag `t_fp_<name>`; patterns in `R/v11.R`). Tier A (female:male >= 2:1, or >= two-thirds women) counts as WHR when the condition is central to the grant: >= 2 mentions of that condition or a title hit. Tier B (about 1.5-2:1, or affects women differently) counts only with a women focus (women in the title or >= 3 mentions) or substantive sex-differences research. Depression, anxiety, PTSD and Alzheimer's disease keep the women-focus rule of earlier versions. Not added as stand-alone terms: generic "autoimmune", knee osteoarthritis, long COVID, hypermobile Ehlers-Danlos syndrome, borderline personality disorder. Ratios are approximate literature values from public sources; check them before citing.

| Column | Condition | Tier | Female:male | Source | Added |
|---|---|---|---|---|---|
| `fp_lupus` | Systemic lupus erythematosus | A | ~9:1 | https://www.niams.nih.gov/health-topics/lupus | v10 list |
| `fp_sjogren` | Sjogren disease | A | ~9:1 | https://www.niams.nih.gov/health-topics/sjogrens-disease | v10 list |
| `fp_ra` | Rheumatoid arthritis | A | 2-3:1 | https://www.cdc.gov/arthritis/rheumatoid-arthritis/ ; https://www.ncbi.nlm.nih.gov/books/NBK612404/ | v10 list |
| `fp_ms` | Multiple sclerosis | A | ~3:1 | https://www.ninds.nih.gov/health-information/disorders/multiple-sclerosis | v10 list |
| `fp_ssc` | Systemic sclerosis/scleroderma | A | ~4:1 | https://www.niams.nih.gov/health-topics/scleroderma | v10 list |
| `fp_aithyroid` | Hashimoto thyroiditis / hypothyroidism | A | ~5-8:1 | https://www.niddk.nih.gov/health-information/endocrine-diseases/hashimotos-disease | v10 list |
| `fp_aps` | Antiphospholipid syndrome | A | ~3.5-5:1 (primary) | https://www.nhlbi.nih.gov/health/antiphospholipid-syndrome | v10 list |
| `fp_pbc` | Primary biliary cholangitis | A | ~9:1 | https://www.niddk.nih.gov/health-information/liver-disease/primary-biliary-cholangitis | v10 list |
| `fp_osteopor` | Osteoporosis | A | ~4:1 age 50+ (19.6% vs 4.4%) | https://www.cdc.gov/nchs/products/databriefs/db405.htm | v10 list |
| `fp_migraine` | Migraine | A | ~3:1 | https://www.ninds.nih.gov/health-information/disorders/migraine | v10 list |
| `fp_fibro` | Fibromyalgia | A | ~2:1 population (higher in clinics) | https://www.cdc.gov/arthritis/fibromyalgia/ | v10 list |
| `fp_cfs` | ME/CFS | A | ~3:1 | https://www.cdc.gov/me-cfs/ ; https://www.ncbi.nlm.nih.gov/books/NBK612404/ | v10 list |
| `fp_tmd` | Temporomandibular disorders | A | ~2:1 or more | https://www.nidcr.nih.gov/health-info/tmd | v10 list |
| `fp_ic` | Interstitial cystitis/bladder pain | A | ~2-5:1 | https://www.niddk.nih.gov/health-information/urologic-diseases/interstitial-cystitis-painful-bladder-syndrome | v10 list |
| `fp_pelvicpain` | Vulvodynia, chronic pelvic pain | A | female-specific / mostly female | https://www.ncbi.nlm.nih.gov/books/NBK612404/ | v10 list |
| `fp_uro` | Urinary incontinence | A | ~2:1 | https://www.niddk.nih.gov/health-information/urologic-diseases/bladder-control-problems | v10 list |
| `fp_uti` | Urinary tract infection | A | ~30:1 adults | https://www.niddk.nih.gov/health-information/urologic-diseases/bladder-infection-uti-in-adults | v10 list |
| `fp_ed` | Anorexia nervosa / bulimia | A | ~3:1 | https://www.nimh.nih.gov/health/statistics/eating-disorders | v10 list |
| `fp_lam` | Lymphangioleiomyomatosis | A | almost exclusively women | https://www.nhlbi.nih.gov/health/lam | v10 list |
| `fp_ibs` | Irritable bowel syndrome | B | ~1.5-2:1 | https://www.niddk.nih.gov/health-information/digestive-diseases/irritable-bowel-syndrome | v10 list |
| `fp_binge` | Binge-eating disorder | B | ~1.7:1 (3.5% vs 2.0% lifetime) | https://www.nimh.nih.gov/health/statistics/eating-disorders | v10 list |
| `fp_scad` | Spontaneous coronary artery dissection | A | ~90% women | https://doi.org/10.1161/CIR.0000000000000564 | v11 |
| `fp_takotsubo` | Takotsubo cardiomyopathy | A | ~90% women (mostly postmenopausal) | https://doi.org/10.1161/CIR.0000000000000564 | v11 |
| `fp_pah` | Pulmonary arterial hypertension | A | ~4:1 (registry ~80% women) | https://www.nhlbi.nih.gov/health/pulmonary-hypertension | v11 |
| `fp_pots` | POTS | A | ~4-5:1 | https://www.ninds.nih.gov/health-information/disorders/postural-tachycardia-syndrome-pots | v11 |
| `fp_aih` | Autoimmune hepatitis | A | ~3.5:1 (70-80% women) | https://www.niddk.nih.gov/health-information/liver-disease/autoimmune-hepatitis | v11 |
| `fp_thyroidfx` | Graves disease / hyperthyroidism | A | ~5-10:1 | https://www.niddk.nih.gov/health-information/endocrine-diseases/graves-disease | v11 |
| `fp_thyca` | Thyroid cancer | A | ~3:1 incidence | https://seer.cancer.gov/statfacts/html/thyro.html | v11 |
| `fp_gall` | Gallstones | A | ~2:1 | https://www.niddk.nih.gov/health-information/digestive-diseases/gallstones | v11 |
| `fp_mcolitis` | Microscopic colitis | A | more common in women (~2-3:1) | https://www.niddk.nih.gov/health-information/digestive-diseases/microscopic-colitis | v11 |
| `fp_iih` | Idiopathic intracranial hypertension | A | ~90% women of childbearing age | https://www.nei.nih.gov/learn-about-eye-health/eye-conditions-and-diseases/idiopathic-intracranial-hypertension | v11 |
| `fp_crps` | Complex regional pain syndrome | A | ~3-4:1 | https://www.ninds.nih.gov/health-information/disorders/complex-regional-pain-syndrome | v11 |
| `fp_raynaud` | Raynaud phenomenon (primary) | A | more common in women (~2-4:1) | https://www.nhlbi.nih.gov/health/raynauds | v11 |
| `fp_gcapmr` | Giant cell arteritis / PMR | A | ~2-3:1 | https://www.niams.nih.gov/health-topics/polymyalgia-rheumatica-giant-cell-arteritis | v11 |
| `fp_lichen` | Lichen sclerosus | A | ~6-10:1 | https://www.niams.nih.gov/health-topics/lichen-sclerosus | v11 |
| `fp_pop` | Pelvic floor disorders / pelvic organ prolapse | A | prolapse female-specific; ~25% of women | https://www.nichd.nih.gov/health/topics/pelvicfloor | v11 |
| `fp_inoca` | INOCA / coronary microvascular dysfunction | B (women/sex-differences focus) | majority women in angina-no-obstruction cohorts; worse outcomes | https://doi.org/10.1161/CIR.0000000000000564 | v11 |
| `fp_minoca` | MINOCA | B (women/sex-differences focus) | ~40-50% women (vs ~25% of MI) | https://doi.org/10.1161/CIR.0000000000000670 | v11 |
| `fp_hfpef` | HFpEF | B (women/sex-differences focus) | ~55-65% women | https://www.nhlbi.nih.gov/health/heart-failure | v11 |
| `fp_ipv` | Intimate partner violence (severe) | B (women/sex-differences focus) | severe IPV ~1 in 4 women vs 1 in 10 men; profound | https://www.cdc.gov/intimate-partner-violence/about/ | v11 |
