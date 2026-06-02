// ============================================================
// 05_doppler.do  —  EFM-recovery-RCT-stata (public release)
// Table S2: maternal-fetal physiological surrogates (IVC-CI, UA PI).
//
//   Per-arm value, baseline & 30 min   median (IQR)
//   Between-arm comparison             ranksum (Mann-Whitney)
//   Within-arm change from baseline    median (IQR) + ranksum between arms
//   ANCOVA-adjusted 30-min difference  regress post i.trt c.pre, vce(robust)
//
// IVC-CI is reported on the percentage-point scale; the ANCOVA excludes any
// value outside the [0, 1] physiological domain. UA PI is reported raw.
//
// Output: $run_dir/Table_S2_physiological_surrogates.csv
// ============================================================

version 17

do "$SRC/lib_stats.do"
use "$path_wide", clear

local out "$run_dir/Table_S2_physiological_surrogates.csv"
file open _dp using "`out'", write replace
file write _dp "index,measure,bolus,continuous,p_value,ci_lo,ci_hi" _n

// index | pre var | post var | display scale | number format
//   ivc_ci scaled x100 (percentage points); ua_pi raw
foreach spec in "ivc_ci 100 %3.1f" "ua_pi 1 %4.2f" {
    local v     : word 1 of `spec'
    local mult  : word 2 of `spec'
    local fmt   : word 3 of `spec'
    local label = cond("`v'" == "ivc_ci", "IVC-CI (%)", "UA PI")

    capture confirm variable `v'_pre
    if _rc != 0 continue

    gen double _pre  = `v'_pre  * `mult'
    gen double _post = `v'_post * `mult'
    gen double _chg  = _post - _pre

    // ---- median (IQR) by arm, at baseline and 30 min ----------
    foreach when in pre post {
        local _tlab = cond("`when'" == "pre", "baseline", "30 min")
        foreach arm in 1 0 {
            quietly summarize _`when' if protocol_bin == `arm', detail
            local m_`arm' = string(r(p50), "`fmt'") + " (" + string(r(p25), "`fmt'") + "–" + string(r(p75), "`fmt'") + ")"
        }
        quietly ranksum _`when', by(protocol_bin)
        local p = 2 * min(normprob(r(z)), 1 - normprob(r(z)))
        _p_text `p'
        local ptxt "`s(text)'"
        file write _dp "`label',`_tlab',`m_1',`m_0',`ptxt',," _n
    }

    // ---- change from baseline: median (IQR) by arm ------------
    foreach arm in 1 0 {
        quietly summarize _chg if protocol_bin == `arm', detail
        local d_`arm' = string(r(p50), "`fmt'") + " (" + string(r(p25), "`fmt'") + "–" + string(r(p75), "`fmt'") + ")"
    }
    quietly ranksum _chg, by(protocol_bin)
    local p_chg = 2 * min(normprob(r(z)), 1 - normprob(r(z)))
    _p_text `p_chg'
    local p_chg_txt "`s(text)'"
    file write _dp "`label',change from baseline,`d_1',`d_0',`p_chg_txt',," _n

    // ---- ANCOVA: post ~ trt + pre, robust SE ------------------
    if "`v'" == "ivc_ci" {
        gen byte _oor = (`v'_pre < 0 | `v'_pre > 1 | `v'_post < 0 | `v'_post > 1) if !missing(`v'_pre, `v'_post)
        capture quietly regress _post i.protocol_bin c._pre if _oor == 0, vce(robust)
        drop _oor
    }
    else {
        capture quietly regress _post i.protocol_bin c._pre, vce(robust)
    }
    if _rc == 0 {
        local coef = _b[1.protocol_bin]
        local se   = _se[1.protocol_bin]
        local zc   = invnormal(1 - (1 - $CI_LEVEL_PCT/100)/2)
        file write _dp "`label',ANCOVA adj. MD (Bolus-Continuous) at 30 min," ///
            (string(round(`coef', 0.001))) ",,," ///
            (string(round(`coef' - `zc'*`se', 0.001))) "," (string(round(`coef' + `zc'*`se', 0.001))) _n
    }

    drop _pre _post _chg
}

file close _dp
di "Table S2 saved to `out'"
import delimited "`out'", varnames(1) clear
list, noobs clean compress
