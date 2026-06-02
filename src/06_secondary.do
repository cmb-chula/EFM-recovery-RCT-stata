// ============================================================
// 06_secondary.do  —  EFM-recovery-RCT-stata (public release)
// Table S1: delivery & neonatal outcomes.
//
//   Route of delivery (vaginal / caesarean)   chi-square test
//   NICU admission, Apgar <7 at 1 & 5 min      Fisher's exact test
//
// Output: $run_dir/Table_S1_delivery_neonatal.csv
// ============================================================

version 17

do "$SRC/lib_stats.do"
use "$path_secondary", clear
merge 1:1 order using "$path_wide", keepusing(protocol_bin) nogenerate keep(master match)

// ---- Binary coercions ---------------------------------------
gen byte caesarean = .
replace caesarean = 1 if regexm(strlower(strtrim(route)), "c-section|cesarean|caesarean|csection|c/s|lscs")
replace caesarean = 0 if regexm(strlower(strtrim(route)), "vaginal|vd|ntl|spontaneous|svd|forceps|vacuum")
gen byte vaginal = 1 - caesarean if !missing(caesarean)

gen byte nicu_admit = .
capture destring nicu, gen(_nicu_n) force
replace nicu_admit = 1 if _nicu_n == 1 | regexm(strlower(strtrim(nicu)), "^(yes|y|1|admitted|nicu)$")
replace nicu_admit = 0 if _nicu_n == 0 | regexm(strlower(strtrim(nicu)), "^(no|n|0|none)$")
capture drop _nicu_n

capture destring apgar_1_min apgar_5_min, replace force
gen byte apgar1_low = (apgar_1_min < 7) if !missing(apgar_1_min)
gen byte apgar5_low = (apgar_5_min < 7) if !missing(apgar_5_min)

local out "$run_dir/Table_S1_delivery_neonatal.csv"
file open _so using "`out'", write replace
file write _so "outcome,bolus,continuous,p_value,test" _n

// ---- helper: write one n (%) row with a chosen test ---------
capture program drop _sec_row
program define _sec_row
    syntax, var(string) label(string) test(string) [event(integer 1)]
    quietly count if protocol_bin == 1 & `var' == `event'
    local kb = r(N)
    quietly count if protocol_bin == 1 & !missing(`var')
    local nb = r(N)
    quietly count if protocol_bin == 0 & `var' == `event'
    local kc = r(N)
    quietly count if protocol_bin == 0 & !missing(`var')
    local nc = r(N)
    local bstr = "`kb' (" + string(round(100*`kb'/`nb', 0.1)) + "%)"
    local cstr = "`kc' (" + string(round(100*`kc'/`nc', 0.1)) + "%)"
    if "`test'" == "chi2" {
        quietly tabulate `var' protocol_bin, chi2
        _p_text `=r(p)'
        local p "`s(text)'"
    }
    else if "`test'" == "fisher" {
        quietly tabulate `var' protocol_bin, exact
        _p_text `=r(p_exact)'
        local p "`s(text)'"
    }
    else local p ""
    file write _so "`label',`bstr',`cstr',`p',`test'" _n
end

_sec_row, var(vaginal)    label("Vaginal delivery")    test(none)
_sec_row, var(caesarean)  label("Caesarean delivery")  test(chi2)
_sec_row, var(nicu_admit) label("NICU admission")      test(fisher)
_sec_row, var(apgar1_low) label("Apgar <7 at 1 min")   test(fisher)
_sec_row, var(apgar5_low) label("Apgar <7 at 5 min")   test(fisher)

file close _so
di "Table S1 saved to `out'"
import delimited "`out'", varnames(1) clear
list, noobs clean compress
