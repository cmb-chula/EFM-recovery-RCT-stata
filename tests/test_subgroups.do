// ============================================================
// tests/test_subgroups.do  —  validate per-stratum RR (csi) and the
// Breslow-Day OR-homogeneity test (cc, bd) on the toy data.
// ============================================================
version 17
do tests/toy_data.do
make_toy

// Per-stratum 2x2 (each stratum: Bolus 4/5, Continuous 2/5)
quietly count if bmi_cat == 1
assert r(N) == 10                                     // 10 per stratum
quietly count if bmi_cat == 0
assert r(N) == 10

foreach lv in 0 1 {
    quietly count if bmi_cat == `lv' & protocol_bin == 1 & event_30 == 1
    local kb = r(N)
    quietly count if bmi_cat == `lv' & protocol_bin == 0 & event_30 == 1
    local kc = r(N)
    quietly csi `kb' `kc' `=5 - `kb'' `=5 - `kc'', exact level(95)
    assert reldif(r(rr), 2.0) < 1e-6                  // each stratum RR = 2.0
}

// Breslow-Day: equal stratum ORs (6.0) -> homogeneous (chi2 ~ 0, p high)
quietly cc event_30 protocol_bin, by(bmi_cat) bd
assert r(chi2_bd) < 0.5                               // homogeneous
assert chi2tail(r(df_bd), r(chi2_bd)) > 0.5          // non-significant

di as result "PASS: test_subgroups (6 assertions)"
