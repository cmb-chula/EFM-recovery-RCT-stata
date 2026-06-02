// ============================================================
// tests/test_reliability.do  —  validate the shared _kappa2 / _lk_interp
// programs (lib_stats.do) against a hand-computed confusion table and
// against Stata's built-in `kap`.
// ============================================================
version 17
do src/lib_stats.do

// Toy confusion (20 cases, binary): 8 both Cat I, 8 both Cat II,
// 2 (A=I,B=II), 2 (A=II,B=I). Marginals 10/10 each.
//   observed agreement = 16/20 = 0.80
//   expected agreement = .5*.5 + .5*.5 = 0.50
//   kappa = (0.80 - 0.50)/(1 - 0.50) = 0.60
//   cases  1- 8: A=1 B=1   (both Cat I)
//   cases  9-10: A=1 B=2
//   cases 11-18: A=2 B=2   (both Cat II)
//   cases 19-20: A=2 B=1
clear
set obs 20
gen byte a = 1
replace a = 2 in 11/20           // A: 10 Cat I, 10 Cat II
gen byte b = 1
replace b = 2 in 9/18            // B: 10 Cat I (1-8,19-20), 10 Cat II (9-18)

quietly count if a == b
assert r(N) == 16                                       // observed agreement 16/20

_kappa2 a b
assert r(n) == 20
assert reldif(r(po), 0.80) < 1e-9                       // observed
assert reldif(r(pe), 0.50) < 1e-9                       // expected
assert reldif(r(kappa), 0.60) < 1e-6                    // Cohen's kappa
assert r(p) < 0.05                                      // H0 (kappa=0) rejected
assert abs(r(p) - 0.0073) < 0.002                       // analytic H0 p-value

// Cross-check against Stata's built-in kap
quietly kap a b
assert reldif(r(kappa), 0.60) < 1e-3                    // agrees with kap

// Landis-Koch interpretation
_lk_interp 0.60
assert "`s(lab)'" == "Moderate agreement"
_lk_interp 0.82
assert "`s(lab)'" == "Almost perfect agreement"

_p_text 0
assert "`s(text)'" == "<0.001"
_p_text 0.0101 0.0001 %9.4f
assert "`s(text)'" == "0.0101"

// Constant rater -> kappa undefined (missing)
replace b = 1
_kappa2 a b
assert missing(r(kappa))

di as result "PASS: test_reliability (13 assertions)"
