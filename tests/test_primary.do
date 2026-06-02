// ============================================================
// tests/test_primary.do  —  validate the primary-outcome methods
// (Fisher exact, RR, RD, NNT via csi; Wilson CI via cii) on the toy data.
// ============================================================
version 17
do tests/toy_data.do
make_toy

// csi: a c b d = events_bolus events_cont nonevents_bolus nonevents_cont
quietly csi 8 4 2 6, exact level(95)
local rr = r(rr)
local rd = r(rd)
local fp = r(p_exact)
local nnt = 1 / r(rd)

// Wilson CI for 8/10 and 4/10
quietly cii proportions 10 8, wilson level(95)
local wlo_b = r(lb)
local whi_b = r(ub)
quietly cii proportions 10 4, wilson level(95)
local wlo_c = r(lb)

assert reldif(`rr', 2.0) < 1e-6                       // RR = 2.0
assert reldif(`rd', 0.4) < 1e-6                       // RD = 0.40
assert reldif(`nnt', 2.5) < 1e-6                      // NNT = 2.5
assert abs(`fp' - 0.169802) < 0.0005                  // Fisher exact 2-sided p
assert abs(`wlo_b' - 0.4902) < 0.002                  // Wilson lower, 8/10
assert abs(`whi_b' - 0.9433) < 0.002                  // Wilson upper, 8/10
assert abs(`wlo_c' - 0.1682) < 0.002                  // Wilson lower, 4/10

di as result "PASS: test_primary (7 assertions)"
