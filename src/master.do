// ============================================================
// master.do  —  EFM-recovery-RCT-stata (public release)
//
// Reproduces, from a single workbook, every manuscript deliverable:
// Figure 2, Figure 3, Tables 1/S1/S2/S3, and the in-text sensitivity
// analyses. With no environment variables set it runs on the bundled
// synthetic example dataset.
//
// Usage (from the repository root):
//   /Applications/StataNow/StataSE.app/Contents/MacOS/stata-se -b -q do src/master.do
//
// Requires Stata 17+ only — every estimate uses a built-in command
// (csi, cii, cc, cloglog, logit, glm, regress, ranksum, ttest,
//  tabulate, kap, lincom, margins). No SSC packages are needed.
//
// Deliverable map (step -> manuscript asset):
//   00_preprocess      workbook -> analysis-ready datasets
//   01_table1          Table 1   (baseline characteristics)
//   02_primary         primary outcome + BMI-adjusted logistic (in text)
//   03_subgroups_bmi   BMI-stratified RR + Breslow-Day (in text, Sec 3.3)
//   04_cumulative      Figure 3  (cumulative recovery + DTSA cloglog HR)
//   05_doppler         Table S2  (physiological surrogates + ANCOVA)
//   06_secondary       Table S1  (delivery & neonatal outcomes)
//   07_reliability     Table S3  (Cohen's kappa agreement)
//   08_figure2_forest  Figure 2  (2a primary-effects forest + 2b effect table)
// ============================================================

version 17
set more off
set linesize 120

do src/config.do
do "$SRC/params.do"
do "$SRC/lib_stats.do"

foreach required_input in ///
    "$raw_dir/$raw_xlsx" ///
    "$aggregate_dir/reviewer_aggregate.csv" ///
    "$aggregate_dir/inter_rater.csv" {

    capture confirm file "`required_input'"
    if _rc != 0 {
        di as error "Required manuscript-reproduction input not found: `required_input'"
        exit 601
    }
}

di _newline(2) as text "{hline 60}"
di as text " EFM-recovery-RCT-stata (public release)"
di as text " Run dir: $run_dir"
di as text "{hline 60}" _newline

log using "$run_dir/pipeline.log", replace text

local input_mode = cond("$raw_dir" == "data/synthetic" & "$raw_xlsx" == "synthetic_crf.xlsx", "synthetic", "restricted")
local run_date = c(current_date)
local run_time = c(current_time)
local stata_version = c(stata_version)
file open _manifest using "$run_dir/run_manifest.csv", write replace
file write _manifest "key,value" _n
file write _manifest "repository,EFM-recovery-RCT-stata" _n
file write _manifest "run_date,`run_date'" _n
file write _manifest "run_time,`run_time'" _n
file write _manifest "stata_version,`stata_version'" _n
file write _manifest "input_mode,`input_mode'" _n
file write _manifest "raw_dir,$raw_dir" _n
file write _manifest "raw_xlsx,$raw_xlsx" _n
file write _manifest "aggregate_dir,$aggregate_dir" _n
file write _manifest "ci_level_pct,$CI_LEVEL_PCT" _n
file write _manifest "recovery_window_min,$RECOVERY_WINDOW_MIN" _n
file write _manifest "bmi_cut,$BMI_CUT" _n
file close _manifest
di as text "Run manifest saved to $run_dir/run_manifest.csv"

local step_files          ///
    00_preprocess         ///
    01_table1             ///
    02_primary            ///
    03_subgroups_bmi      ///
    04_cumulative         ///
    05_doppler            ///
    06_secondary          ///
    07_reliability        ///
    08_figure2_forest

foreach step of local step_files {
    di _newline as text "--- `step' ---"
    capture noisily do "$SRC/`step'.do"
    local rc = _rc
    if `rc' != 0 {
        di as error "STEP `step' FAILED (rc = `rc'). Pipeline stopped."
        log close
        exit `rc'
    }
}

di _newline(2) as text "{hline 60}"
di as text " Pipeline complete. Outputs: $run_dir"
di as text "{hline 60}"

log close
