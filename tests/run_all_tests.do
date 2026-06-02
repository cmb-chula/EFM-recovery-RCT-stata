// ============================================================
// tests/run_all_tests.do  —  run every method test on toy data.
// Run from the pipeline root:
//   /Applications/StataNow/StataSE.app/Contents/MacOS/stata-se -b -q do tests/run_all_tests.do
// Exits non-zero if any test fails.
// ============================================================
version 17
set more off

local tests primary cumulative subgroups doppler reliability table1
local n_pass 0
local n_fail 0
local failed ""

foreach t of local tests {
    di _newline as text "{hline 50}"
    di as text "RUN: test_`t'"
    capture noisily do tests/test_`t'.do
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
        local failed "`failed' `t' (rc=`=_rc')"
    }
}

di _newline as text "{hline 50}"
di as text "TEST SUMMARY: `n_pass' passed, `n_fail' failed"
if `n_fail' > 0 {
    di as error "FAILED: `failed'"
    exit 9
}
di as result "ALL TESTS PASSED"
