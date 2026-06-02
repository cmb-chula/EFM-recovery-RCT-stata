// ============================================================
// params.do  —  EFM-recovery-RCT-stata (public release)
// All scientific constants. Reviewers should read this file once;
// no step file hard-codes these values.
// ============================================================

version 17

// ---- Statistical thresholds ---------------------------------
global CI_LEVEL_PCT = 95         // integer form for cii, csi, ttest, ...

// ---- Trial design constants ---------------------------------
global RECOVERY_WINDOW_MIN = 60  // 60-min key-secondary censoring horizon

// ---- Subgroup cut-point (BMI is the only subgroup in the manuscript) ----
global BMI_CUT = 25.0            // kg/m^2

// ---- Figure palette (RGB triples, BJOG/Wiley house style) ---
global COLOR_BOLUS_RGB      "46 92 138"    // bolus arm / 30-min primary
global COLOR_CONTINUOUS_RGB "214 125 44"   // continuous arm / 60-min
global COLOR_SUBGROUP_RGB   "90 143 96"    // BMI subgroup rows
global COLOR_120_RGB        "140 74 110"   // 120-min exploratory
global COLOR_RULE_RGB       "31 38 48"     // reviewer rows / annotations
global COLOR_TEXT_RGB       "63 72 83"     // numeric labels / p-value boxes

di "Params loaded."
