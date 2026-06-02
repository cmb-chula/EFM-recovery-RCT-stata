// ============================================================
// 00_preprocess.do  —  EFM-recovery-RCT-stata (public release)
// Workbook -> analysis-ready datasets.
//
//   Sheet "Form responses 1"  : CRF, one row per submission. Provides the
//                               pre/post Doppler indices (IVC-CI, UA PI).
//                               De-duplicated to one row per participant.
//   Sheet "Sheet2"            : one row per enrolled participant. Provides
//                               protocol, demographics, the 30/60/120-min
//                               EFM categories (recovery), and the
//                               delivery/neonatal secondary outcomes.
//
// The two sheets are linked by participant order (Sheet1 sorted by hospital
// number == Sheet2 sorted by `order`). In the bundled synthetic workbook the
// sheets are constructed in matching order, so the linkage is exact and needs
// no special flags; with real CRF data the same row-order linkage is used
// (see the manuscript methods and DATA_DICTIONARY.md).
//
// Outputs (gitignored, regenerated each run):
//   $path_wide       — one row per participant (analysis frame)
//   $path_secondary  — delivery / neonatal outcomes (Table S1 source)
//
// Data safety: only aggregate counts are displayed; no row values.
// ============================================================

version 17
set more off

// ============================================================
// SHEET 1 — CRF: pre/post Doppler (IVC-CI, UA PI)
// ============================================================
quietly {

import excel using "$raw_dir/$raw_xlsx", sheet("Form responses 1") cellrange(A1) allstring clear
drop in 1     // discard the header row (cellrange ignores firstrow)

// Positional rename (xlsx column letter -> analytic name); only the
// columns this pipeline uses are kept.
capture rename A  timestamp
capture rename B  hn
capture rename D  protocol_raw
capture rename F  baseline_category
capture rename L  ivc_min_pre
capture rename M  ivc_max_pre
capture rename O  ua_pi_pre
capture rename Q  post_category
capture rename W  ivc_min_post
capture rename X  ivc_max_post
capture rename Z  ua_pi_post
keep timestamp hn protocol_raw baseline_category ///
     ivc_min_pre ivc_max_pre ua_pi_pre post_category ///
     ivc_min_post ivc_max_post ua_pi_post

// ---- Normalise protocol + EFM categories (substring/anchored regex) ----
gen byte protocol_bin = .
replace protocol_bin = 1 if regexm(strlower(strtrim(protocol_raw)), "bolus|load")
replace protocol_bin = 0 if regexm(strlower(strtrim(protocol_raw)), "continuous|infusion")
gen str10 protocol = cond(protocol_bin == 1, "Bolus", cond(protocol_bin == 0, "Continuous", ""))

gen byte baseline_cat_num = .
replace baseline_cat_num = 1 if regexm(strlower(strtrim(baseline_category)), "cat.?i$|category.?i$|^i$|^1$")
replace baseline_cat_num = 2 if regexm(strlower(strtrim(baseline_category)), "cat.?ii$|category.?ii$|^ii$|^2$")
replace baseline_cat_num = 3 if regexm(strlower(strtrim(baseline_category)), "cat.?iii$|category.?iii$|^iii$|^3$")

gen byte post_cat_num = .
replace post_cat_num = 1 if regexm(strlower(strtrim(post_category)), "cat.?i$|category.?i$|^i$|^1$")
replace post_cat_num = 2 if regexm(strlower(strtrim(post_category)), "cat.?ii$|category.?ii$|^ii$|^2$")
replace post_cat_num = 3 if regexm(strlower(strtrim(post_category)), "cat.?iii$|category.?iii$|^iii$|^3$")

// ---- De-duplicate to one row per participant ----------------
// Within each hospital number, keep the first row whose post-IUR category is
// Category I (the recovery row, which carries the post Doppler); if no such
// row exists, keep the last row by timestamp. Baseline/arm/pre-Doppler values
// are carried forward within the participant first.
gen double _ts = clock(timestamp, "YMDhms")
replace _ts = clock(timestamp, "MDYhms") if missing(_ts)
replace _ts = clock(timestamp, "DMYhms") if missing(_ts)
replace _ts = _n if missing(_ts)

sort hn _ts
foreach sv in protocol baseline_category ivc_min_pre ivc_max_pre ua_pi_pre {
    by hn: replace `sv' = `sv'[_n-1] if (`sv' == "" | missing(`sv')) & _n > 1
    gsort hn -_ts
    by hn: replace `sv' = `sv'[_n-1] if (`sv' == "" | missing(`sv')) & _n > 1
    sort hn _ts
}
by hn: egen byte _protobin_hn = max(protocol_bin)
replace protocol_bin = _protobin_hn if missing(protocol_bin)
by hn: egen byte _basecat_hn = max(baseline_cat_num)
replace baseline_cat_num = _basecat_hn if missing(baseline_cat_num)

gen byte _is_post_cat1 = (post_cat_num == 1)
sort hn _ts
by hn: gen long _row_in_hn = _n
by hn: gen long _last_in_hn = _N
by hn: egen byte _any_cat1 = max(_is_post_cat1)
by hn: gen long _cumcat1 = sum(_is_post_cat1)
gen byte _is_first_cat1 = (_is_post_cat1 == 1 & _cumcat1 == 1)
gen byte _keep = (_any_cat1 == 1 & _is_first_cat1 == 1) | (_any_cat1 == 0 & _row_in_hn == _last_in_hn)
keep if _keep == 1

// Eligibility: enrolled participants had a baseline Category II tracing.
keep if baseline_cat_num == 2

// Row-order join key: Sheet1 sorted by hospital number.
sort hn
gen long _row1 = _n

// ---- IVC collapsibility index = (max - min) / max -----------
foreach v in ivc_min_pre ivc_max_pre ivc_min_post ivc_max_post ua_pi_pre ua_pi_post {
    destring `v', replace force
}
gen double ivc_ci_pre  = (ivc_max_pre  - ivc_min_pre)  / ivc_max_pre  if ivc_max_pre  > 0 & !missing(ivc_max_pre,  ivc_min_pre)
gen double ivc_ci_post = (ivc_max_post - ivc_min_post) / ivc_max_post if ivc_max_post > 0 & !missing(ivc_max_post, ivc_min_post)
label variable ivc_ci_pre  "IVC collapsibility index (pre-IUR)"
label variable ivc_ci_post "IVC collapsibility index (post-IUR)"

keep _row1 ivc_ci_pre ivc_ci_post ua_pi_pre ua_pi_post
tempfile sheet1_clean
save `sheet1_clean', replace

} // end quietly (sheet 1)

// ============================================================
// SHEET 2 — recovery, demographics, secondary outcomes
// ============================================================
quietly {

import excel using "$raw_dir/$raw_xlsx", sheet("Sheet2") cellrange(A1) allstring clear
drop in 1

capture rename A   order
capture rename B   age
capture rename D   ga_raw
capture rename F   protocol_s2_raw
capture rename T   monitor_30
capture rename AB  monitor_60
capture rename AJ  monitor_120
capture rename AR  bmi
capture rename AT  route
capture rename AV  placenta
capture rename AX  nuchal_cord
capture rename AZ  af
capture rename BB  nicu
capture rename BD  apgar_1_min
capture rename BE  apgar_5_min
capture rename BF  parity_raw   // present in the synthetic workbook; absent in the original CRF

keep order age ga_raw protocol_s2_raw monitor_30 monitor_60 monitor_120 ///
     bmi route placenta nuchal_cord af nicu apgar_1_min apgar_5_min parity_raw

destring order, replace force
keep if !missing(order)

// Protocol from Sheet2 column F (authoritative).
gen byte protocol_bin = .
replace protocol_bin = 1 if regexm(strlower(strtrim(protocol_s2_raw)), "bolus|load")
replace protocol_bin = 0 if regexm(strlower(strtrim(protocol_s2_raw)), "continuous|infusion")
label define protocol_lbl 0 "Continuous" 1 "Bolus", replace
label values protocol_bin protocol_lbl
gen str10 protocol = cond(protocol_bin == 1, "Bolus", cond(protocol_bin == 0, "Continuous", ""))
drop protocol_s2_raw

// ---- Gestational age "37+1" -> 37.143 weeks ----------------
gen double ga = .
destring ga_raw, gen(_ga_num) force
replace ga = _ga_num if !missing(_ga_num) & !strpos(ga_raw, "+")
replace ga = real(substr(ga_raw, 1, strpos(ga_raw, "+") - 1)) + ///
             real(substr(ga_raw, strpos(ga_raw, "+") + 1, .)) / 7 if strpos(ga_raw, "+") > 0
drop _ga_num ga_raw
label variable ga "Gestational age (fractional weeks)"

foreach v in age bmi apgar_1_min apgar_5_min parity_raw {
    capture destring `v', replace force
}

// ---- EFM category at each checkpoint -> recovery events -----
foreach tp in 30 60 120 {
    gen byte cat_`tp' = .
    replace cat_`tp' = 1 if regexm(strlower(strtrim(monitor_`tp')), "cat.?i$|category.?i$|^i$|^1$")
    replace cat_`tp' = 2 if regexm(strlower(strtrim(monitor_`tp')), "cat.?ii$|category.?ii$|^ii$|^2$")
    replace cat_`tp' = 3 if regexm(strlower(strtrim(monitor_`tp')), "cat.?iii$|category.?iii$|^iii$|^3$")
}

// 30-min primary endpoint
gen byte event_30 = (cat_30 == 1) if !missing(cat_30)

// 60-min key secondary (recovery by 60 min; censored at 60)
gen byte   event_recovered  = .
gen double time_to_cat1_min = .
replace event_recovered  = 1  if cat_30 == 1
replace time_to_cat1_min = 30 if cat_30 == 1
replace event_recovered  = 1  if cat_30 != 1 & cat_60 == 1
replace time_to_cat1_min = 60 if cat_30 != 1 & cat_60 == 1
replace event_recovered  = 0  if missing(event_recovered)
replace time_to_cat1_min = $RECOVERY_WINDOW_MIN if missing(time_to_cat1_min)
label variable event_recovered  "Event: Cat I within 60 min (0=censored)"

// 120-min exploratory endpoint
gen byte   event_recovered_120   = .
gen double time_to_cat1_120_min  = .
replace event_recovered_120  = 1   if cat_30 == 1
replace time_to_cat1_120_min = 30  if cat_30 == 1
replace event_recovered_120  = 1   if cat_30 != 1 & cat_60 == 1
replace time_to_cat1_120_min = 60  if cat_30 != 1 & cat_60 == 1
replace event_recovered_120  = 1   if cat_30 != 1 & cat_60 != 1 & cat_120 == 1
replace time_to_cat1_120_min = 120 if cat_30 != 1 & cat_60 != 1 & cat_120 == 1
replace event_recovered_120  = 0   if missing(event_recovered_120)
replace time_to_cat1_120_min = 120 if missing(time_to_cat1_120_min)

// ---- BMI subgroup + 3-level parity --------------------------
gen byte bmi_cat = .
replace bmi_cat = 0 if bmi <  $BMI_CUT & !missing(bmi)
replace bmi_cat = 1 if bmi >= $BMI_CUT & !missing(bmi)
label define bmi_lbl 0 "<25" 1 "≥25", replace
label values bmi_cat bmi_lbl

gen byte parity_cat3 = .
replace parity_cat3 = 0 if parity_raw == 0 & !missing(parity_raw)
replace parity_cat3 = 1 if parity_raw == 1 & !missing(parity_raw)
replace parity_cat3 = 2 if parity_raw >= 2 & !missing(parity_raw)
label define parity_lbl 0 "0 (nulliparous)" 1 "1" 2 "≥2", replace
label values parity_cat3 parity_lbl

// ---- Secondary-outcome frame (Table S1) ---------------------
preserve
    keep order route nicu apgar_1_min apgar_5_min
    save "$path_secondary", replace
    export delimited using "$path_secondary_csv", replace
restore

// ---- Merge Sheet1 Doppler by row-order key ------------------
sort order
gen long _row1 = _n
merge 1:1 _row1 using `sheet1_clean', nogenerate keep(master match)

// ---- Analysis frame -----------------------------------------
keep order protocol protocol_bin age ga bmi bmi_cat parity_raw parity_cat3 ///
     event_30 event_recovered time_to_cat1_min event_recovered_120 time_to_cat1_120_min ///
     ivc_ci_pre ivc_ci_post ua_pi_pre ua_pi_post ///
     route placenta nuchal_cord af nicu apgar_1_min apgar_5_min
order order protocol protocol_bin
save "$path_wide", replace
export delimited using "$path_wide_csv", replace

} // end quietly (sheet 2)

// ---- Aggregate QC -------------------------------------------
use "$path_wide", clear
di _newline "--- Preprocessing QC (aggregate only) ---"
di "Total enrolled (n): " _N
tabulate protocol_bin
di _newline "Recovery at 30 min by arm:"
tabulate event_30 protocol_bin, col
di _newline "Preprocessing complete. Files saved to $data_dir"
