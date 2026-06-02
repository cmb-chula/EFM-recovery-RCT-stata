// ============================================================
// 04_cumulative.do  —  EFM-recovery-RCT-stata (public release)
// Figure 3: cumulative recovery (Cat II -> Cat I) at 30/60/120 min with
// Wilson 95% CIs, per-checkpoint Fisher exact p, blinded-reviewer 30-min
// risers, and the discrete-time survival analysis (DTSA) complementary
// log-log hazard ratio over the pre-specified 0-30 and 30-60 min intervals.
//
// Outputs:
//   $run_dir/cumulative_recovery.csv          (plotted proportions + Wilson CI)
//   $run_dir/Figure_3_cumulative_recovery.png
// ============================================================

version 17

do "$SRC/lib_stats.do"
use "$path_wide", clear
gen byte event_60 = event_recovered     // event_recovered encodes the 60-min event

// ---- Cumulative proportion + Wilson CI at each checkpoint ---
local out "$run_dir/cumulative_recovery.csv"
file open _cr using "`out'", write replace
file write _cr "arm,cutoff_min,k,n,proportion,ci_lo_wilson,ci_hi_wilson" _n
foreach protocol_val in 1 0 {
    local arm_lbl = cond(`protocol_val' == 1, "Bolus", "Continuous")
    foreach tp in 30 60 120 {
        if `tp' == 30  local ev event_30
        if `tp' == 60  local ev event_60
        if `tp' == 120 local ev event_recovered_120
        quietly count if protocol_bin == `protocol_val' & !missing(`ev')
        local n = r(N)
        quietly count if protocol_bin == `protocol_val' & `ev' == 1
        local k = r(N)
        quietly cii proportions `n' `k', wilson level($CI_LEVEL_PCT)
        file write _cr "`arm_lbl',`tp',`k',`n'," (string(round(`k'/`n',0.001))) "," (string(round(r(lb),0.001))) "," (string(round(r(ub),0.001))) _n
    }
}
file close _cr
di "Cumulative recovery table saved to `out'"

// ---- Per-checkpoint Fisher exact p + number-at-risk ---------
foreach tp in 30 60 120 {
    if `tp' == 30  local ev event_30
    if `tp' == 60  local ev event_60
    if `tp' == 120 local ev event_recovered_120
    quietly count if protocol_bin == 1 & !missing(`ev')
    local nb = r(N)
    quietly count if protocol_bin == 1 & `ev' == 1
    local kb = r(N)
    quietly count if protocol_bin == 0 & !missing(`ev')
    local nc = r(N)
    quietly count if protocol_bin == 0 & `ev' == 1
    local kc = r(N)
    scalar __fp = .
    capture quietly tabi `kb' `=`nb' - `kb'' \ `kc' `=`nc' - `kc'', exact
    if !_rc capture scalar __fp = r(p_exact)
    local fp = __fp
    _p_text `fp'
    local ptxt_`tp' "p = `s(text)'"
    if "`s(text)'" == "<0.001" local ptxt_`tp' "p < 0.001"
}

tempvar rec60 rec120
gen double `rec60'  = time_to_cat1_min     if event_recovered == 1
gen double `rec120' = time_to_cat1_120_min if event_recovered_120 == 1
foreach protocol_val in 0 1 {
    local key = cond(`protocol_val' == 1, "b", "c")
    foreach tp in 0 30 60 120 {
        local ref = cond(`tp' > 60, "`rec120'", "`rec60'")
        quietly count if protocol_bin == `protocol_val' & (missing(`ref') | `ref' >= `tp')
        local risk_`key'_`tp' = r(N)
    }
}

// ---- DTSA cloglog HR over the 0-30 + 30-60 min intervals ----
// Person-period split of the pre-specified 0-60 min window; the exponentiated
// protocol coefficient is reported as the hazard ratio.
tempfile _wide_for_dsta
preserve
    keep order protocol_bin event_30 event_60
    save `_wide_for_dsta', replace
restore
preserve
    use `_wide_for_dsta', clear
    expand 2
    bysort order: gen byte interval = _n             // 1,2 -> (0,30], (30,60]
    gen byte event = .
    replace event = event_30                         if interval == 1
    replace event = (event_60 == 1 & event_30 == 0)  if interval == 2
    gen byte at_risk = 1
    replace at_risk = 0 if interval == 2 & event_30 == 1
    keep if at_risk == 1
    capture quietly cloglog event i.protocol_bin i.interval, vce(cluster order) nolog
    if _rc == 0 {
        quietly lincom 1.protocol_bin, eform level($CI_LEVEL_PCT)
        local _hr = r(estimate)
        local _lo = r(lb)
        local _hi = r(ub)
        local _p  = r(p)
    }
restore
if !missing("`_hr'") {
    _p_text `_p'
    local _ptxt "`s(text)'"
    local dsta_line1 = "Exploratory DTSA HR " + string(`_hr', "%4.2f")
    local dsta_line2 = "(95% CI " + string(`_lo', "%4.2f") + "-" + string(`_hi', "%4.2f") + ")"
    local dsta_line3 = cond("`_ptxt'" == "<0.001", "p < 0.001", "p = `_ptxt'")
}
else {
    local dsta_line1 "DTSA cloglog HR (n/a)"
    local dsta_line2 ""
    local dsta_line3 ""
}
di _newline "Figure 3 legend DTSA HR: `dsta_line1' `dsta_line2' `dsta_line3'"

// ---- Build step + marker series -----------------------------
import delimited "`out'", varnames(1) clear
gen x = cutoff_min
gen pct       = proportion * 100
gen pct_label = string(pct, "%4.1f") + "%"
gen str8 kind = "marker"
tempfile markers stepdata
save `markers', replace

tempname step_post
postfile `step_post' str20 arm double x double pct int seq using `stepdata', replace
foreach plot_arm in Continuous Bolus {
    quietly summarize pct if arm == "`plot_arm'" & x == 30,  meanonly
    local p30 = r(mean)
    quietly summarize pct if arm == "`plot_arm'" & x == 60,  meanonly
    local p60 = r(mean)
    quietly summarize pct if arm == "`plot_arm'" & x == 120, meanonly
    local p120 = r(mean)
    post `step_post' ("`plot_arm'") (0)   (0)     (1)
    post `step_post' ("`plot_arm'") (30)  (0)     (2)
    post `step_post' ("`plot_arm'") (30)  (`p30')  (3)
    post `step_post' ("`plot_arm'") (60)  (`p30')  (4)
    post `step_post' ("`plot_arm'") (60)  (`p60')  (5)
    post `step_post' ("`plot_arm'") (120) (`p60')  (6)
    post `step_post' ("`plot_arm'") (120) (`p120') (7)
}
postclose `step_post'
use `stepdata', clear
gen str8 kind = "step"
append using `markers'
sort arm seq

// ---- Reviewer A/B 30-min risers -----------------------------
// Allocation-blind reviewers assessed at 30 min only; each riser stops at 30.
local _have_rev 0
capture confirm file "$aggregate_dir/reviewer_aggregate.csv"
if _rc != 0 {
    di as error "reviewer_aggregate.csv not found in $aggregate_dir — cannot build Figure 3 reviewer risers."
    exit 601
}
preserve
    import delimited using "$aggregate_dir/reviewer_aggregate.csv", varnames(1) clear
    capture destring cat1 n, replace force
    forvalues _i = 1/`=_N' {
        local _as = assessor[`_i']
        local _ar = arm[`_i']
        if n[`_i'] > 0 {
            local _p = 100 * cat1[`_i'] / n[`_i']
            if regexm("`_as'", "Reviewer_A") & "`_ar'" == "Bolus"      local _ra_b = `_p'
            if regexm("`_as'", "Reviewer_A") & "`_ar'" == "Continuous" local _ra_c = `_p'
            if regexm("`_as'", "Reviewer_B") & "`_ar'" == "Bolus"      local _rb_b = `_p'
            if regexm("`_as'", "Reviewer_B") & "`_ar'" == "Continuous" local _rb_c = `_p'
        }
    }
restore
if missing("`_ra_b'", "`_ra_c'", "`_rb_b'", "`_rb_c'") {
    di as error "reviewer_aggregate.csv is missing required Reviewer A/B arm summaries."
    exit 601
}
local _have_rev 1
local rev_layers
local rev_legend
local rev_labels
if `_have_rev' {
    local _ra_b_t = string(`_ra_b', "%3.1f") + "%"
    local _ra_c_t = string(`_ra_c', "%3.1f") + "%"
    local _rb_b_t = string(`_rb_b', "%3.1f") + "%"
    local _rb_c_t = string(`_rb_c', "%3.1f") + "%"
    local rev_layers `"(pci 0 24 `_ra_b' 24, lpattern(dot) lcolor("$COLOR_BOLUS_RGB") lwidth(medthick)) (pci `_ra_b' 22 `_ra_b' 26, lpattern(solid) lcolor("$COLOR_BOLUS_RGB") lwidth(medthick)) (pci 0 24 `_ra_c' 24, lpattern(dot) lcolor("$COLOR_CONTINUOUS_RGB") lwidth(medthick)) (pci `_ra_c' 22 `_ra_c' 26, lpattern(solid) lcolor("$COLOR_CONTINUOUS_RGB") lwidth(medthick)) (pci 0 36 `_rb_b' 36, lpattern(dash) lcolor("$COLOR_BOLUS_RGB") lwidth(medthick)) (pci `_rb_b' 34 `_rb_b' 38, lpattern(solid) lcolor("$COLOR_BOLUS_RGB") lwidth(medthick)) (pci 0 36 `_rb_c' 36, lpattern(dash) lcolor("$COLOR_CONTINUOUS_RGB") lwidth(medthick)) (pci `_rb_c' 34 `_rb_c' 38, lpattern(solid) lcolor("$COLOR_CONTINUOUS_RGB") lwidth(medthick))"'
    local rev_legend `"8 "Reviewer A (30 min)" 12 "Reviewer B (30 min)""'
    local rev_labels `"text(`_ra_b' 22 "`_ra_b_t'", placement(w) size(small) color("$COLOR_BOLUS_RGB")) text(`_ra_c' 22 "`_ra_c_t'", placement(w) size(small) color("$COLOR_CONTINUOUS_RGB")) text(`_rb_b' 38 "`_rb_b_t'", placement(e) size(small) color("$COLOR_BOLUS_RGB")) text(`_rb_c' 38 "`_rb_c_t'", placement(e) size(small) color("$COLOR_CONTINUOUS_RGB"))"'
}

// ---- Top panel: curves + checkpoints + DTSA inset + legend --
twoway (line pct x if kind == "step" & arm == "Continuous", ///
        lcolor("$COLOR_CONTINUOUS_RGB") lwidth(medthick) lpattern(solid)) ///
       (line pct x if kind == "step" & arm == "Bolus",      ///
        lcolor("$COLOR_BOLUS_RGB") lwidth(medthick) lpattern(solid)) ///
       (scatter pct x if kind == "marker" & arm == "Continuous", ///
        mcolor("$COLOR_CONTINUOUS_RGB") msymbol(square) msize(medium) ///
        mlabel(pct_label) mlabcolor("$COLOR_CONTINUOUS_RGB") mlabposition(6) ///
        mlabsize(medsmall) mlabgap(*2))                       ///
       (scatter pct x if kind == "marker" & arm == "Bolus",  ///
        mcolor("$COLOR_BOLUS_RGB") msymbol(circle) msize(medium)    ///
        mlabel(pct_label) mlabcolor("$COLOR_BOLUS_RGB") mlabposition(12) ///
        mlabsize(medsmall) mlabgap(*2))                       ///
       (pci 0 30 112 30,  lcolor("$COLOR_RULE_RGB") lpattern(dash) lwidth(vthin)) ///
       (pci 0 60 112 60,  lcolor("$COLOR_RULE_RGB") lpattern(dash) lwidth(vthin)) ///
       (pci 0 120 112 120, lcolor("$COLOR_RULE_RGB") lpattern(dash) lwidth(vthin)) ///
       `rev_layers' , ///
    xscale(range(-20 132))                                    ///
    xlabel(0 "0" 30 "30" 60 "60" 120 "120", labsize(medsmall)) ///
    xtitle("")                                                ///
    yscale(range(0 122))                                      ///
    ylabel(0(20)100, grid labsize(medsmall))                  ///
    ytitle("Cumulative recovery probability (%)", size(medsmall)) ///
    title("Cumulative recovery: Category II to Category I", size(medsmall)) ///
    text(116 30 "`ptxt_30'", box fcolor(white) lcolor(gs11) lwidth(thin) margin(small) size(small) color("$COLOR_TEXT_RGB"))  ///
    text(116 60 "`ptxt_60'", box fcolor(white) lcolor(gs11) lwidth(thin) margin(small) size(small) color("$COLOR_TEXT_RGB"))  ///
    text(116 120 "`ptxt_120'", box fcolor(white) lcolor(gs11) lwidth(thin) margin(small) size(small) color("$COLOR_TEXT_RGB")) ///
    text(80 78 "`dsta_line1'" "`dsta_line2'" "`dsta_line3'", placement(e) size(small) color("$COLOR_RULE_RGB") box fcolor(white) lcolor(gs11) lwidth(thin) margin(small)) ///
    `rev_labels' ///
    legend(order(1 "Continuous infusion" 2 "Bolus" `rev_legend') ///
           cols(1) position(5) ring(0) size(small)            ///
           region(lstyle(solid) lcolor(gs10) fcolor(white))   ///
           bmargin(small))                                    ///
    scheme(s2color) graphregion(color(white)) plotregion(margin(small)) ///
    fysize(75) name(g_main, replace) nodraw

// ---- Bottom panel: number at risk ---------------------------
twoway (scatteri 0 0 0 30 0 60 0 120, msymbol(none)),         ///
    xscale(range(-20 132))                                    ///
    xlabel(0 30 60 120, noticks labcolor(white))              ///
    xtitle("Time after IUR initiation (minutes)", size(medsmall)) ///
    yscale(range(0 4) off)                                    ///
    ylabel(0 1 2 3 4, nolabels notick nogrid labcolor(white) glcolor(white) tlcolor(white)) ///
    ytitle("Cumulative recovery probability (%)", size(medsmall) color(white)) ///
    text(3.4 -20 "Number at risk", size(medsmall) color("$COLOR_RULE_RGB") placement(e)) ///
    text(2.2 -20 "Continuous", size(medsmall) color("$COLOR_CONTINUOUS_RGB") placement(e)) ///
    text(1.0 -20 "Bolus", size(medsmall) color("$COLOR_BOLUS_RGB") placement(e))         ///
    text(2.2 0 "`risk_c_0'", size(medsmall) color("$COLOR_TEXT_RGB"))   ///
    text(2.2 30 "`risk_c_30'", size(medsmall) color("$COLOR_TEXT_RGB")) ///
    text(2.2 60 "`risk_c_60'", size(medsmall) color("$COLOR_TEXT_RGB")) ///
    text(2.2 120 "`risk_c_120'", size(medsmall) color("$COLOR_TEXT_RGB")) ///
    text(1.0 0 "`risk_b_0'", size(medsmall) color("$COLOR_TEXT_RGB"))   ///
    text(1.0 30 "`risk_b_30'", size(medsmall) color("$COLOR_TEXT_RGB")) ///
    text(1.0 60 "`risk_b_60'", size(medsmall) color("$COLOR_TEXT_RGB")) ///
    text(1.0 120 "`risk_b_120'", size(medsmall) color("$COLOR_TEXT_RGB")) ///
    legend(off) scheme(s2color) graphregion(color(white)) plotregion(margin(small)) ///
    fysize(25) name(g_risk, replace) nodraw

graph combine g_main g_risk, cols(1) imargin(zero) graphregion(color(white)) xsize(12.2) ysize(9)
graph export "$run_dir/Figure_3_cumulative_recovery.png", replace width(3600)
di "Figure 3 saved to $run_dir/Figure_3_cumulative_recovery.png"
