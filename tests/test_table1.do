// ============================================================
// tests/test_table1.do  —  validate the Table 1 methods: Welch t-test
// (mean +/- SD continuous rows) and Fisher's exact (categorical rows).
// ============================================================
version 17
clear
input byte arm double x
1 26
1 27
1 28
1 29
1 30
1 31
0 28
0 29
0 30
0 31
0 32
0 33
end

quietly summarize x if arm == 1
assert reldif(r(mean), 28.5) < 1e-9                    // Bolus mean
assert r(sd) > 0
quietly summarize x if arm == 0
assert reldif(r(mean), 30.5) < 1e-9                    // Continuous mean

quietly ttest x, by(arm) unequal                       // Welch t-test
// `ttest, by()` orders groups by ascending value: mu_1 = arm 0, mu_2 = arm 1.
assert reldif(r(mu_1), 30.5) < 1e-9                    // Continuous (arm 0)
assert reldif(r(mu_2), 28.5) < 1e-9                    // Bolus (arm 1)
assert r(p) > 0 & r(p) < 1                              // valid two-sided p

// Categorical 2x2 Fisher exact (toy: 5/6 vs 2/6)
clear
input byte present byte arm
1 1
1 1
1 1
1 1
1 1
0 1
1 0
1 0
0 0
0 0
0 0
0 0
end
quietly tabulate present arm, exact
assert r(p_exact) > 0 & r(p_exact) <= 1                 // valid Fisher exact p
quietly count if present == 1 & arm == 1
assert r(N) == 5                                        // Bolus present count

di as result "PASS: test_table1 (8 assertions)"
