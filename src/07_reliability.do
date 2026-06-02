// ============================================================
// 07_reliability.do  —  EFM-recovery-RCT-stata (public release)
// Table S3: inter-rater agreement of blinded EFM classification.
//
// For each rater pair and time point, reports observed agreement, chance-
// expected agreement, Cohen's kappa, the two-sided p-value (H0: kappa = 0),
// and the Landis-Koch interpretation. At baseline the real-time investigator
// recorded only Category II (the inclusion criterion), so kappa against the
// investigator is undefined and only observed agreement is reported.
//
// Input  : $aggregate_dir/inter_rater.csv  (order, timepoint, a, b, bedside)
// Output : $run_dir/Table_S3_reliability.csv
// ============================================================

version 17

capture confirm file "$aggregate_dir/inter_rater.csv"
if _rc != 0 {
    di as error "inter_rater.csv not found in $aggregate_dir — cannot build Table S3."
    exit 601
}
do "$SRC/lib_stats.do"      // defines _kappa2 (Cohen's kappa) and _lk_interp

import delimited using "$aggregate_dir/inter_rater.csv", varnames(1) clear
foreach v in a b bedside {
    capture destring `v', replace force
}

local out "$run_dir/Table_S3_reliability.csv"
file open _kr using "`out'", write replace
file write _kr "assessment,comparison,n_cases,observed_agreement_pct,expected_agreement_pct,kappa,p_value,interpretation" _n

// Table S3 rows in the manuscript's order: (timepoint rater1 rater2 label)
foreach spec in                                                        ///
    "baseline a bedside Reviewer A vs. real-time investigator"         ///
    "baseline b bedside Reviewer B vs. real-time investigator"         ///
    "post30   a bedside Reviewer A vs. real-time investigator"         ///
    "post30   b bedside Reviewer B vs. real-time investigator"         ///
    "baseline a b Reviewer A vs. Reviewer B"                           ///
    "post30   a b Reviewer A vs. Reviewer B" {

    gettoken tp  rest : spec
    gettoken r1  rest : rest
    gettoken r2  lab  : rest
    local lab = strtrim("`lab'")
    local alab = cond("`tp'" == "baseline", "Baseline", "30 min after IUR")

    preserve
        keep if timepoint == "`tp'"
        _kappa2 `r1' `r2'
        local n  = r(n)
        local po = string(100 * r(po), "%4.1f")
        if missing(r(kappa)) {
            file write _kr "`alab',`lab',`n',`po',,,,Not interpretable" _n
        }
        else {
            local pe = string(100 * r(pe), "%4.1f")
            local k  = string(r(kappa), "%4.2f")
            _lk_interp `=r(kappa)'
            _p_text `=r(p)'
            local ptxt "`s(text)'"
            file write _kr "`alab',`lab',`n',`po',`pe',`k',`ptxt',`s(lab)'" _n
        }
    restore
}

file close _kr
di "Table S3 saved to `out'"
import delimited "`out'", varnames(1) clear
list, noobs clean compress
