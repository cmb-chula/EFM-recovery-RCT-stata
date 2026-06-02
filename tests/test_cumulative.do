// ============================================================
// tests/test_cumulative.do  —  validate cumulative proportions, Wilson CI,
// and the discrete-time (cloglog) hazard ratio on the toy data.
// ============================================================
version 17
do tests/toy_data.do
make_toy
gen byte event_60 = event_recovered

// Cumulative proportions
quietly count if protocol_bin == 1 & event_30 == 1
local p30_b = r(N) / 10
quietly count if protocol_bin == 0 & event_30 == 1
local p30_c = r(N) / 10
quietly count if protocol_bin == 1 & event_60 == 1
local p60_b = r(N) / 10
quietly count if protocol_bin == 1 & event_recovered_120 == 1
local p120_b = r(N) / 10

assert reldif(`p30_b', 0.8) < 1e-6                    // Bolus @30 = 0.8
assert reldif(`p30_c', 0.4) < 1e-6                    // Continuous @30 = 0.4
assert reldif(`p60_b', 0.9) < 1e-6                    // Bolus @60 = 0.9
assert reldif(`p120_b', 1.0) < 1e-6                   // Bolus @120 = 1.0

quietly cii proportions 10 8, wilson level(95)
assert abs(r(lb) - 0.4902) < 0.002                    // Wilson lower @30 Bolus

// Discrete-time cloglog HR over the 0-30 + 30-60 intervals (person-period)
gen long order = _n
expand 2
bysort order: gen byte interval = _n
gen byte event = .
replace event = event_30 if interval == 1
replace event = (event_60 == 1 & event_30 == 0) if interval == 2
gen byte at_risk = 1
replace at_risk = 0 if interval == 2 & event_30 == 1
keep if at_risk == 1
quietly cloglog event i.protocol_bin i.interval, vce(cluster order) nolog
quietly lincom 1.protocol_bin, eform level(95)
assert !missing(r(estimate))                          // HR is estimable
assert r(estimate) > 1                                // Bolus recovers faster (HR > 1)

di as result "PASS: test_cumulative (7 assertions)"
