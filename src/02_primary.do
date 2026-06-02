// ============================================================
// 02_primary.do  —  EFM-recovery-RCT-stata (public release)
// Primary outcome (Category I recovery at 30 min) — in-text numbers.
//
// Methods (per manuscript):
//   Fisher's exact test; RR via log-binomial model; RD 95% CI via the
//   Newcombe-Wilson hybrid; NNT = 1/RD. BMI-adjusted logistic regression
//   is reported as a sensitivity analysis (average marginal effect on the
//   risk-difference scale).
//
//   Per-arm proportion 95% CI       cii proportions, wilson | exact
//   Fisher exact + RR + RD          csi a b c d, exact
//   Newcombe-Wilson hybrid RD CI    Newcombe 1998 method 10
//   Log-binomial RR (robust SE)     glm y i.trt, family(binomial) link(log) vce(robust)
//   BMI-adjusted OR + AME           logit y i.trt c.bmi, vce(robust); margins, dydx(trt)
//
// Output: $run_dir/primary_outcome.csv
// ============================================================

version 17

do "$SRC/lib_stats.do"
use "$path_wide", clear

quietly {
    count if protocol_bin == 1 & event_30 == 1
    local kb = r(N)
    count if protocol_bin == 1
    local nb = r(N)
    count if protocol_bin == 0 & event_30 == 1
    local kc = r(N)
    count if protocol_bin == 0
    local nc = r(N)
}
local pb = `kb' / `nb'
local pc = `kc' / `nc'

// ---- Per-arm CIs (Wilson + Clopper-Pearson exact) -----------
quietly cii proportions `nb' `kb', wilson level($CI_LEVEL_PCT)
local wi_lo_b = r(lb)
local wi_hi_b = r(ub)
quietly cii proportions `nc' `kc', wilson level($CI_LEVEL_PCT)
local wi_lo_c = r(lb)
local wi_hi_c = r(ub)
quietly cii proportions `nb' `kb', exact level($CI_LEVEL_PCT)
local cp_lo_b = r(lb)
local cp_hi_b = r(ub)
quietly cii proportions `nc' `kc', exact level($CI_LEVEL_PCT)
local cp_lo_c = r(lb)
local cp_hi_c = r(ub)

// ---- csi: RR (log-method CI), RD (Wald), Fisher exact -------
quietly csi `kb' `kc' `=`nb' - `kb'' `=`nc' - `kc'', exact level($CI_LEVEL_PCT)
local rr      = r(rr)
local rr_lo   = r(lb_rr)
local rr_hi   = r(ub_rr)
local rd      = r(rd)
local p_fisher = r(p_exact)

// ---- Newcombe (1998) method 10 hybrid RD CI -----------------
local rd_nw_lo = `rd' - sqrt((`pb' - `wi_lo_b')^2 + (`wi_hi_c' - `pc')^2)
local rd_nw_hi = `rd' + sqrt((`wi_hi_b' - `pb')^2 + (`pc' - `wi_lo_c')^2)

// ---- NNT (point + inverted Newcombe CI) ---------------------
local nnt    = cond(abs(`rd')       < 1e-10, ., 1 / `rd')
local nnt_lo = cond(abs(`rd_nw_hi') < 1e-10, ., 1 / `rd_nw_hi')
local nnt_hi = cond(abs(`rd_nw_lo') < 1e-10, ., 1 / `rd_nw_lo')

// ---- Log-binomial RR with robust SE -------------------------
// Reconstruct the patient-level binary outcome from aggregate counts so the
// GLM is identical to a raw-data fit (no identifiers are touched; only totals).
preserve
    clear
    set obs `=`nb' + `nc''
    gen byte bolus = (_n <= `nb')
    gen byte recovered = 0
    quietly replace recovered = 1 in 1/`kb'
    quietly replace recovered = 1 in `=`nb' + 1'/`=`nb' + `kc''
    glm recovered i.bolus, family(binomial) link(log) eform vce(robust) nolog
    local rr_lb    = exp(_b[1.bolus])
    local rr_lb_lo = exp(_b[1.bolus] - invnormal(1 - (1 - $CI_LEVEL_PCT/100)/2) * _se[1.bolus])
    local rr_lb_hi = exp(_b[1.bolus] + invnormal(1 - (1 - $CI_LEVEL_PCT/100)/2) * _se[1.bolus])
    local rr_lb_p  = 2 * (1 - normal(abs(_b[1.bolus] / _se[1.bolus])))
restore

// ---- BMI-adjusted logistic regression (sensitivity) ---------
local or_adj = .
local ame_rd = .
capture confirm variable bmi
if _rc == 0 {
    preserve
        gen byte bolus = (protocol_bin == 1) if !missing(protocol_bin)
        logit event_30 i.bolus c.bmi, vce(robust) nolog
        quietly lincom 1.bolus, or level($CI_LEVEL_PCT)
        local or_adj    = r(estimate)
        local or_adj_lo = r(lb)
        local or_adj_hi = r(ub)
        local or_adj_p  = r(p)
        quietly margins, dydx(bolus) level($CI_LEVEL_PCT)
        matrix _ame_b = r(b)
        matrix _ame_V = r(V)
        local ame_rd    = _ame_b[1, 2]
        local ame_se    = sqrt(_ame_V[2, 2])
        local ame_rd_lo = `ame_rd' - invnormal(1 - (1 - $CI_LEVEL_PCT/100)/2) * `ame_se'
        local ame_rd_hi = `ame_rd' + invnormal(1 - (1 - $CI_LEVEL_PCT/100)/2) * `ame_se'
        local ame_p     = 2 * (1 - normal(abs(`ame_rd' / `ame_se')))
    restore
}

_p_text `rr_lb_p'
local rr_lb_p_txt "`s(text)'"
_p_text `p_fisher' 0.0001 %9.4f
local p_fisher_txt "`s(text)'"
_p_text `or_adj_p'
local or_adj_p_txt "`s(text)'"
_p_text `ame_p'
local ame_p_txt "`s(text)'"

// ---- Display ------------------------------------------------
di _newline "=== Primary outcome (Cat I within 30 min) ==="
di "Bolus:      `kb'/`nb' = " %4.1f 100*`pb' "%  (Wilson " %4.1f 100*`wi_lo_b' "-" %4.1f 100*`wi_hi_b' ")"
di "Continuous: `kc'/`nc' = " %4.1f 100*`pc' "%  (Wilson " %4.1f 100*`wi_lo_c' "-" %4.1f 100*`wi_hi_c' ")"
di "RD            : " %4.1f 100*`rd' " pp  (Newcombe-Wilson " %4.1f 100*`rd_nw_lo' " to " %4.1f 100*`rd_nw_hi' ")"
di "RR (csi log)  : " %4.2f `rr' " (" %4.2f `rr_lo' "-" %4.2f `rr_hi' ")"
di "RR (log-binom): " %4.2f `rr_lb' " (" %4.2f `rr_lb_lo' "-" %4.2f `rr_lb_hi' "), p = `rr_lb_p_txt'"
di "NNT           : " %3.1f `nnt' " (" %3.1f `nnt_lo' "-" %3.1f `nnt_hi' ")"
di "Fisher exact p: " %6.4f `p_fisher'
di "BMI-adjusted AME (RD pp): " %4.1f 100*`ame_rd' " (" %4.1f 100*`ame_rd_lo' " to " %4.1f 100*`ame_rd_hi' "), p = `ame_p_txt'"

// ---- Save ---------------------------------------------------
local out "$run_dir/primary_outcome.csv"
file open _of using "`out'", write replace
file write _of "quantity,value,ci_lo,ci_hi,p_value,method" _n
file write _of "bolus_proportion," (string(round(`pb',0.001))) "," (string(round(`wi_lo_b',0.001))) "," (string(round(`wi_hi_b',0.001))) ",,wilson" _n
file write _of "bolus_proportion," (string(round(`pb',0.001))) "," (string(round(`cp_lo_b',0.001))) "," (string(round(`cp_hi_b',0.001))) ",,clopper_pearson" _n
file write _of "continuous_proportion," (string(round(`pc',0.001))) "," (string(round(`wi_lo_c',0.001))) "," (string(round(`wi_hi_c',0.001))) ",,wilson" _n
file write _of "continuous_proportion," (string(round(`pc',0.001))) "," (string(round(`cp_lo_c',0.001))) "," (string(round(`cp_hi_c',0.001))) ",,clopper_pearson" _n
file write _of "risk_difference," (string(round(`rd',0.001))) "," (string(round(`rd_nw_lo',0.001))) "," (string(round(`rd_nw_hi',0.001))) ",,newcombe_wilson" _n
file write _of "relative_risk," (string(round(`rr_lb',0.001))) "," (string(round(`rr_lb_lo',0.001))) "," (string(round(`rr_lb_hi',0.001))) ",`rr_lb_p_txt',log_binomial_robust" _n
file write _of "relative_risk," (string(round(`rr',0.001))) "," (string(round(`rr_lo',0.001))) "," (string(round(`rr_hi',0.001))) ",,csi_log_method" _n
file write _of "nnt," (string(round(`nnt',0.1))) "," (string(round(`nnt_lo',0.1))) "," (string(round(`nnt_hi',0.1))) ",,one_over_rd" _n
file write _of "fisher_exact_p,,,,`p_fisher_txt',csi_exact" _n
file write _of "bmi_adjusted_or_bolus," (string(round(`or_adj',0.01))) "," (string(round(`or_adj_lo',0.01))) "," (string(round(`or_adj_hi',0.01))) ",`or_adj_p_txt',logit_bmi_adjusted" _n
file write _of "bmi_adjusted_ame_rd," (string(round(`ame_rd',0.001))) "," (string(round(`ame_rd_lo',0.001))) "," (string(round(`ame_rd_hi',0.001))) ",`ame_p_txt',margins_dydx" _n
file close _of
di _newline "Primary outcome saved to `out'"
