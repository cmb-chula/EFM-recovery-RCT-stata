// ============================================================
// 01_table1.do  —  EFM-recovery-RCT-stata (public release)
// Table 1: baseline characteristics by arm.
//
// Rows (manuscript Table 1):
//   Age, gestational age, BMI        mean +/- SD, Welch t-test
//   Parity (0 / 1 / >=2)             n (%), Fisher/chi-square
//   Umbilical cord insertion         n (%), Fisher exact (central vs eccentric)
//   Nuchal cord                      n (%), Fisher exact
//   Meconium-stained amniotic fluid  n (%), Fisher exact
//
// Output: $run_dir/Table_1_baseline_characteristics.csv
// ============================================================

version 17

do "$SRC/lib_stats.do"
use "$path_wide", clear

local out "$run_dir/Table_1_baseline_characteristics.csv"
file open _t1 using "`out'", write replace
file write _t1 "variable,level,bolus,continuous,test,p_value" _n

// ---- Continuous: mean (SD), Welch t-test --------------------
foreach v in age ga bmi {
    quietly summarize `v' if protocol_bin == 1
    local mb = r(mean)
    local sb = r(sd)
    quietly summarize `v' if protocol_bin == 0
    local mc = r(mean)
    local sc = r(sd)

    capture quietly ttest `v', by(protocol_bin) unequal
    local p = cond(_rc == 0, r(p), .)
    _p_text `p'
    local ptxt "`s(text)'"

    local bstr = string(round(`mb', 0.1)) + " ± " + string(round(`sb', 0.1))
    local cstr = string(round(`mc', 0.1)) + " ± " + string(round(`sc', 0.1))
    file write _t1 "`v',mean ± SD,`bstr',`cstr',Welch t,`ptxt'" _n
}

// ---- Parity (0 / 1 / >=2): n (%), Fisher/chi-square ---------
capture confirm variable parity_cat3
if _rc == 0 {
    quietly count if !missing(parity_cat3)
    if r(N) > 0 {
        quietly tabulate parity_cat3 protocol_bin, exact
        local p_par = r(p_exact)
        if missing(`p_par') {
            quietly tabulate parity_cat3 protocol_bin, chi2
            local p_par = r(p)
        }
        quietly levelsof parity_cat3, local(plevels)
        foreach lv of local plevels {
            local lbl : label (parity_cat3) `lv'
            quietly count if parity_cat3 == `lv' & protocol_bin == 1
            local kb = r(N)
            quietly count if protocol_bin == 1 & !missing(parity_cat3)
            local nb = r(N)
            quietly count if parity_cat3 == `lv' & protocol_bin == 0
            local kc = r(N)
            quietly count if protocol_bin == 0 & !missing(parity_cat3)
            local nc = r(N)
            local bstr = "`kb' (" + string(round(100 * `kb' / `nb', 0.1)) + "%)"
            local cstr = "`kc' (" + string(round(100 * `kc' / `nc', 0.1)) + "%)"
            if `lv' == `: word 1 of `plevels'' {
                _p_text `p_par'
                local ptxt "`s(text)'"
            }
            else local ptxt ""
            file write _t1 "parity,`lbl',`bstr',`cstr',Fisher/chi2,`ptxt'" _n
        }
    }
}

// ---- Categorical event indicators: n (%), Fisher exact ------
// Each is a binary "present" flag derived from a Sheet2 text column.
capture confirm variable placenta
if _rc == 0 {
    gen byte _cord_central   = (strlower(strtrim(placenta)) == "central")   if !missing(placenta)
    gen byte _cord_eccentric = (strlower(strtrim(placenta)) == "eccentric") if !missing(placenta)
}
capture confirm variable nuchal_cord
if _rc == 0 {
    capture destring nuchal_cord, gen(_nc_n) force
    gen byte _nuchal = (_nc_n >= 1) if !missing(_nc_n)
    capture drop _nc_n
}
capture confirm variable af
if _rc == 0 gen byte _meconium = (strpos(strlower(strtrim(af)), "thin") > 0) if !missing(af)

// Helper: write one "n (%)" row (Fisher exact) for a 0/1 flag already in memory.
capture program drop _t1cat
program define _t1cat
    syntax, flag(string) variable(string) level(string)
    capture confirm variable `flag'
    if _rc != 0 exit
    quietly count if `flag' == 1 & protocol_bin == 1
    local kb = r(N)
    quietly count if !missing(`flag') & protocol_bin == 1
    local nb = r(N)
    quietly count if `flag' == 1 & protocol_bin == 0
    local kc = r(N)
    quietly count if !missing(`flag') & protocol_bin == 0
    local nc = r(N)
    if `nb' < 1 | `nc' < 1 exit
    quietly tabulate `flag' protocol_bin, exact
    local p = r(p_exact)
    _p_text `p'
    local ptxt "`s(text)'"
    local bstr = "`kb' (" + string(round(100 * `kb' / `nb', 0.1)) + "%)"
    local cstr = "`kc' (" + string(round(100 * `kc' / `nc', 0.1)) + "%)"
    file write _t1 "`variable',`level',`bstr',`cstr',Fisher exact,`ptxt'" _n
end

_t1cat, flag(_cord_central)   variable(cord_insertion) level(Central insertion)
_t1cat, flag(_cord_eccentric) variable(cord_insertion) level(Eccentric insertion)
_t1cat, flag(_nuchal)         variable(nuchal_cord)    level(present)
_t1cat, flag(_meconium)       variable(meconium)       level(Thin meconium)
capture drop _cord_central _cord_eccentric _nuchal _meconium

file close _t1
di "Table 1 saved to `out'"
import delimited "`out'", varnames(1) clear
list, noobs clean compress
