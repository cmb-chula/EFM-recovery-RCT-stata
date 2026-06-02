// ============================================================
// 03_subgroups_bmi.do  —  EFM-recovery-RCT-stata (public release)
// Pre-specified BMI-stratified subgroup analysis (in text, Section 3.3).
//
//   csi a b c d, exact level()        per-stratum RR + RD + Fisher exact
//   cc event_30 protocol_bin, by(bmi_cat) bd   Breslow-Day OR-homogeneity
//
// Output: $run_dir/bmi_subgroup.csv
// ============================================================

version 17

do "$SRC/lib_stats.do"
use "$path_wide", clear

capture confirm variable bmi_cat
if _rc != 0 {
    di as error "bmi_cat missing — cannot run BMI subgroup analysis."
    exit 601
}

local out "$run_dir/bmi_subgroup.csv"
file open _bs using "`out'", write replace
file write _bs "stratum,n_total,k_bolus,n_bolus,prop_bolus,k_cont,n_cont,prop_cont,rr,rr_lo,rr_hi,rd,p_fisher" _n

quietly levelsof bmi_cat, local(levels)
foreach lv of local levels {
    local lbl : label (bmi_cat) `lv'

    quietly count if bmi_cat == `lv'
    local n_tot = r(N)
    quietly count if bmi_cat == `lv' & protocol_bin == 1 & event_30 == 1
    local kb = r(N)
    quietly count if bmi_cat == `lv' & protocol_bin == 1
    local nb = r(N)
    quietly count if bmi_cat == `lv' & protocol_bin == 0 & event_30 == 1
    local kc = r(N)
    quietly count if bmi_cat == `lv' & protocol_bin == 0
    local nc = r(N)
    if `nb' < 1 | `nc' < 1 continue

    quietly csi `kb' `kc' `=`nb' - `kb'' `=`nc' - `kc'', exact level($CI_LEVEL_PCT)
    _p_text `=r(p_exact)' 0.0001 %9.4f
    local p_exact_txt "`s(text)'"
    file write _bs "BMI `lbl',`n_tot',`kb',`nb'," ///
        (string(round(`kb'/`nb', 0.001))) ",`kc',`nc'," ///
        (string(round(`kc'/`nc', 0.001))) "," ///
        (string(round(r(rr),  0.001))) "," ///
        (string(round(r(lb_rr), 0.001))) "," ///
        (string(round(r(ub_rr), 0.001))) "," ///
        (string(round(r(rd),  0.001))) "," ///
        "`p_exact_txt'" _n
}

// ---- Breslow-Day OR-homogeneity -----------------------------
quietly cc event_30 protocol_bin, by(bmi_cat) bd
local bd_chi2 = r(chi2_bd)
local bd_df   = r(df_bd)
local bd_p    = cond(missing(`bd_df') | `bd_df' <= 0, ., chi2tail(`bd_df', `bd_chi2'))
_p_text `bd_p' 0.0001 %9.4f
local bd_p_txt "`s(text)'"

file write _bs "breslow_day,,,,,,,,,,," ///
    "chi2=" (string(round(`bd_chi2', 0.001))) " df=" (string(`bd_df')) " p=`bd_p_txt'" _n
file close _bs

di _newline "=== BMI-stratified primary outcome ==="
import delimited "`out'", varnames(1) clear
list, noobs clean compress
di _newline "Breslow-Day chi2(" (`bd_df') ") = " %5.3f `bd_chi2' ", p = " %5.3f `bd_p'
di "BMI subgroup table saved to `out'"
