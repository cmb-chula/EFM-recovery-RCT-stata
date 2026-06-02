// ============================================================
// lib_stats.do  —  EFM-recovery-RCT-stata (public release)
// Shared statistical helper programs, sourced by the step files that
// need them and by the test suite (so the tests exercise the same code).
// ============================================================

version 17

// ---- Cohen's kappa for two raters (with H0 p-value) ----------
// Returns r(n), r(po) [observed agreement], r(pe) [chance agreement],
// r(kappa), r(p). When either rater used a single category, kappa is
// undefined and pe/kappa/p are returned missing.
capture program drop _kappa2
program define _kappa2, rclass
    args r1 r2
    quietly count if !missing(`r1', `r2')
    local N = r(N)
    quietly count if `r1' == `r2' & !missing(`r1', `r2')
    local po = r(N) / `N'
    return scalar n  = `N'
    return scalar po = `po'
    quietly levelsof `r1' if !missing(`r1', `r2'), local(c1)
    quietly levelsof `r2' if !missing(`r1', `r2'), local(c2)
    if `: word count `c1'' < 2 | `: word count `c2'' < 2 {
        return scalar pe = .
        return scalar kappa = .
        return scalar p = .
        exit
    }
    local cats : list c1 | c2
    local pe 0
    local vterm 0
    foreach c of local cats {
        quietly count if `r1' == `c' & !missing(`r1', `r2')
        local p1 = r(N) / `N'
        quietly count if `r2' == `c' & !missing(`r1', `r2')
        local p2 = r(N) / `N'
        local pe = `pe' + `p1' * `p2'
        local vterm = `vterm' + `p1' * `p2' * (`p1' + `p2')
    }
    local kappa = (`po' - `pe') / (1 - `pe')
    // SE under H0 (kappa = 0): Fleiss-Cohen-Everitt.
    local se0 = sqrt(`pe' + `pe'^2 - `vterm') / ((1 - `pe') * sqrt(`N'))
    return scalar pe = `pe'
    return scalar kappa = `kappa'
    return scalar p  = 2 * (1 - normal(abs(`kappa' / `se0')))
end

// ---- Landis-Koch interpretation of kappa --------------------
capture program drop _lk_interp
program define _lk_interp, sclass
    args k
    if      `k' <= 0.20 sreturn local lab "Slight agreement"
    else if `k' <= 0.40 sreturn local lab "Fair agreement"
    else if `k' <= 0.60 sreturn local lab "Moderate agreement"
    else if `k' <= 0.80 sreturn local lab "Substantial agreement"
    else                sreturn local lab "Almost perfect agreement"
end

// ---- Manuscript-facing p-value text -------------------------
capture program drop _p_text
program define _p_text, sclass
    args p step fmt
    if "`step'" == "" local step 0.001
    if "`fmt'"  == "" local fmt "%9.3f"

    if "`p'" == "" {
        sreturn local text ""
        exit
    }
    if missing(`p') {
        sreturn local text ""
        exit
    }
    if `p' < 0.001 {
        sreturn local text "<0.001"
        exit
    }

    local ptxt = strtrim(string(round(`p', `step'), "`fmt'"))
    sreturn local text "`ptxt'"
end
