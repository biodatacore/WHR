# CHANGE_LOG — WHR pipelines v10 (data freeze 2026-10-31)

Both pipelines (`nih-womens-cv-funding` and `nih-womens-health-funding-topics`) now use the v10 rules by default. Set `WHR_V10_RULES=none` to recover the previous classification logic. The switches live in `R/v10.R`.

`data/shipped/` is the v10 cache for that freeze: 869,672 project-years in the universe, text for 76,374 WHR project-years (and, in the cardiovascular pipeline, every broad-CV project-year as well). `tests/expected_values.csv` stores the v10 numbers. The default rules reproduce them from `data/shipped/` with no raw files. `WHR_V10_RULES=none` may miss some topic text.

## Data refresh

* FY2026 was re-fetched from the RePORTER API v2 on 2026-10-31. FY2026 now has 69,809 records ($37.65 billion total cost), up from 69,556 ($36.92 billion) on 2026-10-20. FY2026 is still incomplete and still contains no intramural projects. The derived `data/shipped/` cache from that freeze is in the repository. The raw API responses are not.
* The 47 FY2020/FY2024 intramural project-years that lack text were re-queried on 2026-10-31. None has an abstract yet.
* FY2013–2025 inputs are unchanged.

## Code

| File | Change |
|---|---|
| `R/v10.R` (new) | Every v10 rule sits behind a switch (`WHR_V10_RULES`: `imp0`, `topics`, `a`–`f`, `excl`; `all` by default, `none` = previous logic) and the new term lists. |
| `R/00_setup.R` | Sources `R/v10.R`. Paths stay in `config.R` (`WHR_RAW_DIR`, `WHR_WORK_DIR`, `WHR_OUT_DIR`). |
| `R/utils.R` | `keyword_classify()` keeps the previous if/else chain in `.kw_logic()` and also returns variants without pregnancy terms and without the blanket centre/training downgrade. |
| `R/03_classify.R` | `features`, `assign_tiers` and `yearly` are the v10 versions. The observed intramural rate is saved beside the main (0%) rate. The CV pipeline also replaces `cv_tiers` and keeps audit flags. A cached feature table that lacks the v10 columns stops with an explicit error. |
| `R/05_topics.R` | WHR: autoimmune disease moves to profound and osteoporosis to predominant. Exclusion sensitivities remove the award dollars from the NIH denominator as well. CV: OT2HL158287 leaves the CV denominator, and an all-seven-group exclusion is added. |
| `R/06_figures.R` | WHR Figure 2 panel C shows autoimmune disease in place of osteoporosis. CV Figure 2 uses the award-excluded denominator for the dashed series. Label spacing and type size were adjusted for legibility only. |

## Rules

1. **Imputation at 0%.** The 47 intramural project-years still without text (FY2020 n=24, FY2024 n=23; mostly ZIF facility and administrative awards) are imputed at 0% WHR. A WHR call is not possible without text. The observed-rate method (6.53% under the previous rules; 7.29%, +$89.5 million, when re-estimated under the v10 rules) is kept as the `_imp` sensitivity columns.
2. **Topic mapping.** Autoimmune disease moves to *profound* (NASEM Table 7-1 places autoimmune disorders among conditions that differentially or disproportionately affect women, through disability and early mortality). Osteoporosis moves to *predominant* (NASEM Chapter 3 lists it among conditions that predominantly affect women). The scheme is described as adapted from NASEM only where it still differs: the 2×3 DALY matrix is collapsed to two categories; thyroid disease, chronic pain and urinary conditions are placed as predominant; diabetes/obesity is added as profound; there is a cross-cutting group. Fractional allocation is independent at the category level and at the subtopic level (two separate equal splits of the full project-year cost), so the two levels are not additive.
3. **Classification.**
   * Pregnancy and maternal-fetal studies count only with maternal-outcome evidence (at least two maternal-outcome terms, or one in the title). Otherwise the call falls back to the version without pregnancy terms.
   * Centre, training and network grants are not blanket-downgraded when the project shows women's or maternal outcome evidence. The CV code never had a blanket centre exclusion.
   * Blood-disorder grants and tumour-vessel or tumour-endothelium grants are not CV, unless a blood-disorder grant's title names cardiac, pulmonary-hypertension, thrombotic or cerebrovascular disease. Cancer projects whose CV signal is only weak vascular language are not CV.
   * Breast cancer counts as WHR.
   * Any cardiotoxicity counts as CV and overrides the exclusions above.
   * Female-predominant conditions on the NASEM list count as WHR when the condition is central, without a separate women mention. Psoriasis, inflammatory bowel disease, celiac disease and type 1 diabetes are not on that list.
4. **Exclusions are definitional sensitivities, not spending bounds.** The strict and NASEM-comparable definitions are alternative definitions. They are not lower and upper bounds on dollars. The seven award groups (OT2HL158287, National Children's Study contracts, ECHO, the Women's Health Initiative, NRG Oncology, UM1AI068619, and the NCI pooled contracts N01CO000000 and N01CA000000) are removed from both the numerator and the denominator in the sensitivity. OT2HL158287 stays in every main estimate at full project cost. Funding attribution is at the full project: parent total cost, or the sum of component costs when there is no parent.

## Headline results (previous rules to v10)

* Total WHR share: FY2013–15 8.78% to 9.38%; FY2023–25 8.74% to 8.98%. Slope +0.025 to −0.006 percentage points per year.
* Excluding the seven award groups from numerator and denominator: 9.06% to 8.65% (FY2013–15 to FY2023–25).
* Women's CV share: FY2013–15 5.81% to 6.19%; FY2023–25 10.37% to 10.26%; change +4.55 to +4.07 percentage points.
* OT2HL158287 removed from both the women's-CV numerator and the CV denominator: 8.51% in FY2023–25. The award is 1.75 percentage points and 43% of the gain.
* Profound share of WHR in FY2013–15: 11.4% to 16.6%, mainly because autoimmune disease moved to profound.

The female-predominant rule (conditions count without a separate women mention) is the largest single classification change. The shipped text extract includes those project-years.
