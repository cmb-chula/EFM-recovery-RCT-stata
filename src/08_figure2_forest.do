// ============================================================
// 08_figure2_forest.do  —  EFM-recovery-RCT-stata (public release)
// Figure 2: primary-effects forest (2a) + numeric effect table (2b).
//
// Rows shown:
//   * Overall 30-min primary endpoint (bedside)
//   * Blinded Reviewer A / B / Consensus sensitivity
//   * BMI subgroup rows (the only subgroup in the manuscript)
//   * Overall 60-min and 120-min endpoints
//
// RR and Fisher p come from `csi a b c d, exact level()`. RD confidence
// intervals use the Newcombe-Wilson hybrid (1998 method 10) from two Wilson
// binomial intervals.
//
// Outputs:
//   $run_dir/primary_effects_forest.csv      (plotted effect estimates)
//   $run_dir/Figure_2a_forest.png            (relative-risk forest)
//   $run_dir/Figure_2b_effect_table.png      (n/N, RD, NNT, RR, Fisher p)
// ============================================================

version 17

do "$SRC/lib_stats.do"
tempfile effect_rows
clear
set obs 0
gen str60 label = ""
gen str14 row_kind = ""
gen int endpoint_min = .
gen int k_bolus = .
gen int n_bolus = .
gen int k_cont = .
gen int n_cont = .
gen double rr = .
gen double rr_lo = .
gen double rr_hi = .
gen double rd = .
gen double rd_lo = .
gen double rd_hi = .
gen double nnt = .
gen double nnt_lo = .
gen double nnt_hi = .
gen double fisher_p = .
save `effect_rows', replace

// ---------- helper: append one row to effect_rows ----------
capture program drop _append_row
program define _append_row
    syntax, kind(string) label(string) endpoint(integer) ///
            kb(integer) nb(integer) kc(integer) nc(integer) ///
            rows(string)
    quietly csi `kb' `kc' `=`nb' - `kb'' `=`nc' - `kc'', ///
            exact level($CI_LEVEL_PCT)
    local _rr    = cond(`kb' > 0 & `kc' > 0, r(rr), .)
    local _rr_lo = cond(`kb' > 0 & `kc' > 0, r(lb_rr), .)
    local _rr_hi = cond(`kb' > 0 & `kc' > 0, r(ub_rr), .)
    local _rd    = r(rd)
    local _pf    = r(p_exact)

    if (`nb' > 0 & `nc' > 0) {
        local _p_b = `kb' / `nb'
        local _p_c = `kc' / `nc'
        quietly cii proportions `nb' `kb', wilson level($CI_LEVEL_PCT)
        local _wi_lo_b = r(lb)
        local _wi_hi_b = r(ub)
        quietly cii proportions `nc' `kc', wilson level($CI_LEVEL_PCT)
        local _wi_lo_c = r(lb)
        local _wi_hi_c = r(ub)
        local _rd_lo = `_rd' - sqrt((`_p_b' - `_wi_lo_b')^2 + ///
                                    (`_wi_hi_c' - `_p_c')^2)
        local _rd_hi = `_rd' + sqrt((`_wi_hi_b' - `_p_b')^2 + ///
                                    (`_p_c' - `_wi_lo_c')^2)
    }
    else {
        local _rd_lo = .
        local _rd_hi = .
    }

    local _nnt   = cond(abs(`_rd') > 1e-9, 1 / `_rd', .)
    local _nnt_lo = cond(abs(`_rd_hi') > 1e-9 & sign(`_rd_lo') == sign(`_rd_hi'), 1 / `_rd_hi', .)
    local _nnt_hi = cond(abs(`_rd_lo') > 1e-9 & sign(`_rd_lo') == sign(`_rd_hi'), 1 / `_rd_lo', .)

    use `rows', clear
    set obs `=_N + 1'
    replace label = "`label'" in `=_N'
    replace row_kind = "`kind'" in `=_N'
    replace endpoint_min = `endpoint' in `=_N'
    replace k_bolus = `kb' in `=_N'
    replace n_bolus = `nb' in `=_N'
    replace k_cont = `kc' in `=_N'
    replace n_cont = `nc' in `=_N'
    replace rr = `_rr' in `=_N'
    replace rr_lo = `_rr_lo' in `=_N'
    replace rr_hi = `_rr_hi' in `=_N'
    replace rd = `_rd' in `=_N'
    replace rd_lo = `_rd_lo' in `=_N'
    replace rd_hi = `_rd_hi' in `=_N'
    replace nnt = `_nnt' in `=_N'
    replace nnt_lo = `_nnt_lo' in `=_N'
    replace nnt_hi = `_nnt_hi' in `=_N'
    replace fisher_p = `_pf' in `=_N'
    save `rows', replace
end

// ============================================================
// 1. Overall 30-min primary endpoint
// ============================================================
use "$path_wide", clear
quietly count if protocol_bin == 1 & event_30 == 1
local _kb = r(N)
quietly count if protocol_bin == 1
local _nb = r(N)
quietly count if protocol_bin == 0 & event_30 == 1
local _kc = r(N)
quietly count if protocol_bin == 0
local _nc = r(N)
_append_row, kind(overall) label("Overall 30-min primary endpoint") ///
    endpoint(30) kb(`_kb') nb(`_nb') kc(`_kc') nc(`_nc') rows(`effect_rows')

// ============================================================
// 2. Reviewer A / B blinded sensitivity rows
//    Source: data/reviewer_aggregate.csv (aggregate Cat-I counts derived
//    from the pre-specified Sheet1↔Sheet2 linkage; see data/README.md
//    for provenance). Reading the aggregate avoids reproducing the
//    Sheet1↔Sheet2 logic in pure Stata.
// ============================================================
local _ra_path "$aggregate_dir/reviewer_aggregate.csv"
capture confirm file "`_ra_path'"
if _rc != 0 {
    di as error "Reviewer aggregate file `_ra_path' not found — cannot build Figure 2 reviewer rows."
    exit 601
}
else {
    // Load into locals; cannot keep dataset in memory across _append_row
    // calls because _append_row does `use rows, clear`.
    local _kb_A = .
    local _nb_A = .
    local _kc_A = .
    local _nc_A = .
    local _kb_B = .
    local _nb_B = .
    local _kc_B = .
    local _nc_B = .
    local _kb_C = .
    local _nb_C = .
    local _kc_C = .
    local _nc_C = .
    preserve
        import delimited using "`_ra_path'", varnames(1) clear
        capture destring cat1 n, replace force
        quietly count
        if r(N) > 0 {
            forvalues _i = 1/`=_N' {
                local _arm  = arm[`_i']
                local _ass  = assessor[`_i']
                local _k    = cat1[`_i']
                local _n    = n[`_i']
                local _suffix ""
                if regexm("`_ass'", "Reviewer_A") local _suffix "A"
                if regexm("`_ass'", "Reviewer_B") local _suffix "B"
                if regexm("`_ass'", "Consensus")  local _suffix "C"
                if "`_suffix'" == "" continue
                if "`_arm'" == "Bolus" {
                    local _kb_`_suffix' = `_k'
                    local _nb_`_suffix' = `_n'
                }
                if "`_arm'" == "Continuous" {
                    local _kc_`_suffix' = `_k'
                    local _nc_`_suffix' = `_n'
                }
            }
        }
    restore

    if missing(`_nb_A', `_nc_A', `_nb_B', `_nc_B', `_nb_C', `_nc_C') {
        di as error "reviewer_aggregate.csv is missing required Reviewer A/B/Consensus arm summaries."
        exit 601
    }

    if !missing(`_nb_A') & !missing(`_nc_A') & `_nb_A' > 0 & `_nc_A' > 0 {
        _append_row, kind(reviewer)                       ///
            label("Blinded Reviewer A")                    ///
            endpoint(30)                                   ///
            kb(`_kb_A') nb(`_nb_A')                        ///
            kc(`_kc_A') nc(`_nc_A')                        ///
            rows(`effect_rows')
    }
    if !missing(`_nb_B') & !missing(`_nc_B') & `_nb_B' > 0 & `_nc_B' > 0 {
        _append_row, kind(reviewer)                       ///
            label("Blinded Reviewer B")                    ///
            endpoint(30)                                   ///
            kb(`_kb_B') nb(`_nb_B')                        ///
            kc(`_kc_B') nc(`_nc_B')                        ///
            rows(`effect_rows')
    }
    if !missing(`_nb_C') & !missing(`_nc_C') & `_nb_C' > 0 & `_nc_C' > 0 {
        _append_row, kind(reviewer)                       ///
            label("Consensus (>=2 of 3)")                  ///
            endpoint(30)                                   ///
            kb(`_kb_C') nb(`_nb_C')                        ///
            kc(`_kc_C') nc(`_nc_C')                        ///
            rows(`effect_rows')
    }
}

// ============================================================
// 3. Subgroup rows (BMI is the only subgroup shown in the manuscript).
// ============================================================
local _sg_vars bmi_cat
foreach _sg of local _sg_vars {
    use "$path_wide", clear
    capture confirm variable `_sg'
    if _rc != 0 continue
    quietly levelsof `_sg', local(_levels)
    foreach _lv of local _levels {
        // Reload at every inner iteration because _append_row replaces
        // the in-memory dataset with effect_rows.
        use "$path_wide", clear
        capture confirm variable `_sg'
        if _rc != 0 continue

        local _lv_label : label (`_sg') `_lv'
        if "`_lv_label'" == "" local _lv_label "`_lv'"
        local _sg_label "`_sg'"
        if "`_sg'" == "bmi_cat" local _sg_label "BMI"

        quietly count if protocol_bin == 1 & `_sg' == `_lv' & event_30 == 1
        local _kb = r(N)
        quietly count if protocol_bin == 1 & `_sg' == `_lv' & !missing(event_30)
        local _nb = r(N)
        quietly count if protocol_bin == 0 & `_sg' == `_lv' & event_30 == 1
        local _kc = r(N)
        quietly count if protocol_bin == 0 & `_sg' == `_lv' & !missing(event_30)
        local _nc = r(N)
        if `_nb' < 2 | `_nc' < 2 continue

        _append_row, kind(subgroup)                       ///
            label("`_sg_label': `_lv_label'")             ///
            endpoint(30)                                  ///
            kb(`_kb') nb(`_nb') kc(`_kc') nc(`_nc')        ///
            rows(`effect_rows')
    }
}

// ============================================================
// 4. 60-min and 120-min overall endpoints
// ============================================================
forvalues _i = 2/3 {
    local _ev  = cond(`_i' == 2, "event_recovered", "event_recovered_120")
    local _ep  = cond(`_i' == 2, 60, 120)
    local _lbl = cond(`_i' == 2, "Overall 60-min key secondary", "120-min exploratory")

    use "$path_wide", clear
    capture confirm variable `_ev'
    if _rc != 0 continue

    quietly count if protocol_bin == 1 & !missing(`_ev')
    local _nb = r(N)
    quietly count if protocol_bin == 1 & `_ev' == 1
    local _kb = r(N)
    quietly count if protocol_bin == 0 & !missing(`_ev')
    local _nc = r(N)
    quietly count if protocol_bin == 0 & `_ev' == 1
    local _kc = r(N)

    if `_nb' == 0 | `_nc' == 0 continue

    _append_row, kind(overall) label("`_lbl'")       ///
        endpoint(`_ep')                              ///
        kb(`_kb') nb(`_nb') kc(`_kc') nc(`_nc')      ///
        rows(`effect_rows')
}

// ============================================================
// 5. Render forest
// ============================================================
use `effect_rows', clear
if _N == 0 {
    di as error "No effect rows assembled — cannot build Figure 2."
    exit 601
}

gen int row_id = _N - _n + 1
gen double rr_lo_plot = max(rr_lo, .35)
gen double rr_hi_plot = min(rr_hi, 8)

// plot_group palette:
//   1 = overall 30-min (manuscript primary)
//   2 = overall 60-min
//   3 = overall 120-min
//   4 = subgroup
//   5 = reviewer sensitivity
gen byte plot_group = 4
replace plot_group = 1 if row_kind == "overall"  & endpoint_min == 30
replace plot_group = 2 if row_kind == "overall"  & endpoint_min == 60
replace plot_group = 3 if row_kind == "overall"  & endpoint_min == 120
replace plot_group = 5 if row_kind == "reviewer"

gen str44 row_label = label
replace row_label = "Overall 30 min"  if row_kind == "overall" & endpoint_min == 30
replace row_label = "Overall 60 min"  if row_kind == "overall" & endpoint_min == 60
replace row_label = "Overall 120 min" if row_kind == "overall" & endpoint_min == 120

gen str24 bolus_txt = string(k_bolus, "%2.0f") + "/" + string(n_bolus, "%2.0f") + ///
    " (" + string(100 * k_bolus / n_bolus, "%4.1f") + ")"
gen str24 cont_txt  = string(k_cont,  "%2.0f") + "/" + string(n_cont,  "%2.0f") + ///
    " (" + string(100 * k_cont  / n_cont,  "%4.1f") + ")"
gen str36 rd_txt    = string(100 * rd, "%5.1f") + " (" + ///
    string(100 * rd_lo, "%5.1f") + ", " + string(100 * rd_hi, "%5.1f") + ")"
gen str28 nnt_txt   = cond(missing(nnt) | missing(nnt_lo) | missing(nnt_hi), ///
                            "-",                                              ///
                            string(nnt, "%4.1f"))
replace nnt_txt = string(nnt, "%4.1f") + " (" + string(nnt_lo, "%4.1f") + ", " + ///
                  string(nnt_hi, "%4.1f") + ")"                                  ///
                  if !missing(nnt, nnt_lo, nnt_hi)
gen str38 rr_txt = string(rr, "%4.2f") + " (" + string(rr_lo, "%4.2f") + ///
                   ", " + string(rr_hi, "%4.2f") + ")"
replace rr_txt = "not estimable" if missing(rr) | missing(rr_lo) | missing(rr_hi)
gen str12 p_txt = cond(missing(fisher_p), "",        ///
                       cond(fisher_p < .001, "p<0.001", "p=" + string(fisher_p, "%4.3f")))

export delimited using "$run_dir/primary_effects_forest.csv", replace

gen double rr_logx    = log10(max(rr, .35))
gen double rr_lo_logx = log10(max(rr_lo_plot, .35))
gen double rr_hi_logx = log10(min(rr_hi_plot, 8))

// Figure 2 is split into 2a (forest) + 2b (table), each a separate file.
// Build the shared y-axis row-label list (before any band obs are appended)
// and save a clean copy of the display rows so each figure can reload it.
local ylab
forvalues _j = 1/`=_N' {
    local ylab `"`ylab' `=row_id[`_j']' "`=row_label[`_j']'""'
}
local NROW = _N
tempfile display_rows
save `display_rows', replace

// ============================================================
// FIGURE 2a — relative-risk forest (markers + 95% CI), its own file.
// "Favours" labels (British spelling for BJOG) sit in the top corners
// (top margin at y_ban), clear of all rows/CIs.
// ============================================================
use `display_rows', clear
local xl    = -0.85
local xr    =  1.35
local y_top = `NROW' + 1.30
local y_ban = `NROW' + 0.72

// alternating row shading (light-grey bands on alternate rows, x = [xl, xr])
gen int    band_id = .
gen double band_x  = .
gen double band_lo = .
gen double band_hi = .
local _obs = _N
local _bid = 0
forvalues _r = 1/`NROW' {
    if mod(`NROW' - `_r', 2) != 0 continue
    local ++_bid
    local ++_obs
    set obs `_obs'
    replace band_id = `_bid'      in `_obs'
    replace band_x  = `xl'        in `_obs'
    replace band_lo = `_r' - 0.46 in `_obs'
    replace band_hi = `_r' + 0.46 in `_obs'
    local ++_obs
    set obs `_obs'
    replace band_id = `_bid'      in `_obs'
    replace band_x  = `xr'        in `_obs'
    replace band_lo = `_r' - 0.46 in `_obs'
    replace band_hi = `_r' + 0.46 in `_obs'
}
local bandlayers
forvalues _b = 1/`_bid' {
    local bandlayers `"`bandlayers' (rarea band_hi band_lo band_x if band_id==`_b', color(gs15) lwidth(none))"'
}

twoway                                                                  ///
    `bandlayers'                                                        ///
    (rcap rr_lo_logx rr_hi_logx row_id if plot_group == 1, horizontal   ///
        lcolor("$COLOR_BOLUS_RGB") lwidth(medthick))                    ///
    (scatter row_id rr_logx if plot_group == 1,                         ///
        mcolor("$COLOR_BOLUS_RGB") msymbol(diamond) msize(medlarge))    ///
    (rcap rr_lo_logx rr_hi_logx row_id if plot_group == 5, horizontal   ///
        lcolor("$COLOR_RULE_RGB") lwidth(medthin))                      ///
    (scatter row_id rr_logx if plot_group == 5,                         ///
        mcolor(white) mlcolor("$COLOR_RULE_RGB")                        ///
        msymbol(square) msize(medsmall))                                ///
    (rcap rr_lo_logx rr_hi_logx row_id if plot_group == 2, horizontal   ///
        lcolor("$COLOR_CONTINUOUS_RGB") lwidth(medthick))               ///
    (scatter row_id rr_logx if plot_group == 2,                         ///
        mcolor("$COLOR_CONTINUOUS_RGB") msymbol(diamond) msize(medlarge)) ///
    (rcap rr_lo_logx rr_hi_logx row_id if plot_group == 3, horizontal   ///
        lcolor("$COLOR_120_RGB") lwidth(medthick))                      ///
    (scatter row_id rr_logx if plot_group == 3,                         ///
        mcolor("$COLOR_120_RGB") msymbol(diamond) msize(medlarge))      ///
    (rcap rr_lo_logx rr_hi_logx row_id if plot_group == 4, horizontal   ///
        lcolor("$COLOR_SUBGROUP_RGB") lwidth(thin))                     ///
    (scatter row_id rr_logx if plot_group == 4,                         ///
        mcolor(white) mlcolor("$COLOR_SUBGROUP_RGB")                    ///
        msymbol(circle) msize(small)),                                  ///
    xscale(range(`xl' `xr'))                                            ///
    xlabel(-0.301 ".5" 0 "1" 0.301 "2" 0.602 "4" 0.903 "8",             ///
           nogrid labsize(medsmall))                                    ///
    xline(0, lpattern(dash) lcolor(gs8))                                ///
    xline(-0.301 0.301 0.602 0.903, lpattern(solid) lcolor(gs14)        ///
          lwidth(vthin))                                                ///
    yscale(range(-.85 `y_top'))                                         ///
    ylabel(`ylab', angle(0) labsize(medsmall) nogrid)                   ///
    ytitle("")                                                          ///
    xtitle("Relative risk of Category I recovery (Bolus / Continuous)", ///
           size(medsmall))                                              ///
    text(`y_ban' -0.80 "Favours Continuous", placement(e) size(medsmall) color(gs6)) ///
    text(`y_ban'  1.30 "Favours Bolus",      placement(w) size(medsmall) color(gs6)) ///
    legend(off) scheme(s2color) graphregion(color(white))               ///
    plotregion(margin(zero))                                            ///
    xsize(10) ysize(7.0)                                                ///
    name(g_2a, replace)

graph export "$run_dir/Figure_2a_forest.png", replace width(3200)

// ============================================================
// FIGURE 2b — numeric effect table (no forest), its own file.
// Row labels on the y-axis; columns are left-justified text; x-axis off.
// ============================================================
use `display_rows', clear
local xl    = -0.15
local xr    =  5.55
local y_hdr = `NROW' + 0.92
local y_top = `NROW' + 1.45
local x_bol = 0.30
local x_con = 1.15
local x_rd  = 2.00
local x_nnt = 2.92
local x_rr  = 3.78
local x_p   = 4.70

gen int    band_id = .
gen double band_x  = .
gen double band_lo = .
gen double band_hi = .
local _obs = _N
local _bid = 0
forvalues _r = 1/`NROW' {
    if mod(`NROW' - `_r', 2) != 0 continue
    local ++_bid
    local ++_obs
    set obs `_obs'
    replace band_id = `_bid'      in `_obs'
    replace band_x  = `xl'        in `_obs'
    replace band_lo = `_r' - 0.46 in `_obs'
    replace band_hi = `_r' + 0.46 in `_obs'
    local ++_obs
    set obs `_obs'
    replace band_id = `_bid'      in `_obs'
    replace band_x  = `xr'        in `_obs'
    replace band_lo = `_r' - 0.46 in `_obs'
    replace band_hi = `_r' + 0.46 in `_obs'
}
local bandlayers
forvalues _b = 1/`_bid' {
    local bandlayers `"`bandlayers' (rarea band_hi band_lo band_x if band_id==`_b', color(gs15) lwidth(none))"'
}

local tbl
local tbl `"`tbl' text(`y_hdr' `x_bol' "Bolus" "n/N (%)",          size(medsmall) color(gs2) just(left))"'
local tbl `"`tbl' text(`y_hdr' `x_con' "Continuous" "n/N (%)",     size(medsmall) color(gs2) just(left))"'
local tbl `"`tbl' text(`y_hdr' `x_rd'  "RD, pp" "(95% CI)",        size(medsmall) color(gs2) just(left))"'
local tbl `"`tbl' text(`y_hdr' `x_nnt' "NNT" "(95% CI)",           size(medsmall) color(gs2) just(left))"'
local tbl `"`tbl' text(`y_hdr' `x_rr'  "RR" "(95% CI)",            size(medsmall) color(gs2) just(left))"'
local tbl `"`tbl' text(`y_hdr' `x_p'   "Fisher's exact" "p-value", size(medsmall) color(gs2) just(left))"'
forvalues _j = 1/`NROW' {
    local _y      = row_id[`_j']
    local _bol    = bolus_txt[`_j']
    local _con    = cont_txt[`_j']
    local _nntt   = nnt_txt[`_j']
    local _rdfull = rd_txt[`_j']
    local _rrfull = rr_txt[`_j']
    local _ptxt   = p_txt[`_j']
    local tbl `"`tbl' text(`_y' `x_bol' "`_bol'",    size(medsmall) color(gs3) just(left))"'
    local tbl `"`tbl' text(`_y' `x_con' "`_con'",    size(medsmall) color(gs3) just(left))"'
    local tbl `"`tbl' text(`_y' `x_rd'  "`_rdfull'", size(medsmall) color(gs3) just(left))"'
    local tbl `"`tbl' text(`_y' `x_nnt' "`_nntt'",   size(medsmall) color(gs3) just(left))"'
    local tbl `"`tbl' text(`_y' `x_rr'  "`_rrfull'", size(medsmall) color(gs3) just(left))"'
    local tbl `"`tbl' text(`_y' `x_p'   "`_ptxt'",   size(medsmall) color(gs3) just(left))"'
}

gen double _ax = 0
twoway                                                                  ///
    `bandlayers'                                                        ///
    (scatter row_id _ax, msymbol(none)),                                ///
    xscale(range(`xl' `xr') off)                                        ///
    yscale(range(-.85 `y_top'))                                         ///
    ylabel(`ylab', angle(0) labsize(medsmall) nogrid)                   ///
    ytitle("") xtitle("")                                               ///
    `tbl'                                                               ///
    legend(off) scheme(s2color) graphregion(color(white))               ///
    plotregion(margin(zero))                                            ///
    xsize(18) ysize(7.0)                                                ///
    name(g_2b, replace)

graph export "$run_dir/Figure_2b_effect_table.png", replace width(5400)

di _newline "Figure 2a (forest) + 2b (effect table) saved to:"
di "   $run_dir/Figure_2a_forest.png"
di "   $run_dir/Figure_2b_effect_table.png"
di "   $run_dir/primary_effects_forest.csv"
