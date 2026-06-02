// ============================================================
// tests/test_doppler.do  —  validate the IVC-CI formula, the ANCOVA
// (regress post i.trt c.pre) and the Mann-Whitney change comparison.
// ============================================================
version 17
clear
set obs 12
gen byte protocol_bin = (_n <= 6)               // 6 Bolus, 6 Continuous
gen double ivc_max_pre  = 100
gen double ivc_max_post = 100
// Bolus: pre min 40 (CI .60) -> post min 30 (CI .70)  => change +0.10
// Cont : pre min 40 (CI .60) -> post min 50 (CI .50)  => change -0.10
gen double ivc_min_pre  = 40
gen double ivc_min_post = cond(protocol_bin == 1, 30, 50)

gen double ivc_ci_pre  = (ivc_max_pre  - ivc_min_pre)  / ivc_max_pre
gen double ivc_ci_post = (ivc_max_post - ivc_min_post) / ivc_max_post
gen double chg = ivc_ci_post - ivc_ci_pre

assert reldif(ivc_ci_pre[1], 0.60) < 1e-9                       // (100-40)/100
assert reldif(ivc_ci_post[1], 0.70) < 1e-9                      // Bolus post
assert reldif(ivc_ci_post[12], 0.50) < 1e-9                     // Continuous post

quietly summarize chg if protocol_bin == 1
local mb = r(mean)
quietly summarize chg if protocol_bin == 0
local mc = r(mean)
assert reldif(`mb', 0.10) < 1e-9                                // Bolus change +0.10
assert `mb' > `mc'                                              // Bolus change > Continuous

// ANCOVA: post on arm + pre -> Bolus coefficient positive
quietly regress ivc_ci_post i.protocol_bin c.ivc_ci_pre, vce(robust)
assert _b[1.protocol_bin] > 0                                   // adjusted Bolus advantage

// Mann-Whitney on the change separates the arms
quietly ranksum chg, by(protocol_bin)
assert abs(r(z)) > 1.96                                         // significant separation

di as result "PASS: test_doppler (7 assertions)"
