# EFM-recovery-RCT-stata: Pipeline Structure

> Stata analysis bundle for a two-arm randomized controlled trial (n = 60)
> comparing a rapid intravenous saline **bolus** versus **continuous** infusion
> for recovery from Category II → Category I electronic fetal monitoring
> tracings. From a single workbook it reproduces the manuscript's Figure 2,
> Figure 3, and Tables 1/S1/S2/S3, plus the in-text BMI-adjusted and
> BMI-stratified analyses. It runs end-to-end on a bundled synthetic dataset, so
> the real CRF is never needed to reproduce the structure of the results.

## Summary for reviewers and LLMs

- **Inputs:** one workbook (`synthetic_crf.xlsx`, or a real CRF via `EFM_RAW_XLSX`) plus two aggregate CSVs (`reviewer_aggregate.csv`, `inter_rater.csv`), all under `$EFM_RAW_DIR` (default `data/synthetic/`).
- **Stages:** 9 sequential steps (`00`–`08`), run via `do src/master.do` **from the repo root**.
- **Outputs:** 3 figures + 8 tables → `output/run_<TIMESTAMP>/`, plus `run_manifest.csv` and `pipeline.log`.
- **Headline outputs:** Figure 2 (primary-effects forest + numeric effect table), Figure 3 (cumulative recovery + exploratory DTSA HR), `primary_outcome.csv`.
- **DUA status:** restricted; the real CRF holds participant-level data (Queen Savang Vadhana Memorial Hospital). The public bundle ships synthetic data only, and `.gitignore` is fail-closed for all data extensions.

## File tree (annotated)

```text
.
├── README.md                      # install / run / output guide + preview gallery
├── LICENSE                        # BSD 3-Clause (© 2026 Dhup Bhukdee)
├── DATA_DICTIONARY.md             # workbook + analysis-frame schema
├── PIPELINE_STRUCTURE.md          # this file
├── .gitignore                     # fail-closed data-safety allowlist
├── src/                           # all analysis code; run from the repo root
│   ├── master.do                  # entry point: runs steps 00→08, writes manifest
│   ├── config.do                  # paths / env vars ($SRC, data, output)
│   ├── params.do                  # scientific constants + figure palette
│   ├── lib_stats.do               # shared helpers: _kappa2, _lk_interp, _p_text
│   └── 00_preprocess.do … 08_figure2_forest.do
├── tests/                         # Stata-native toy tests (6 files + runner + fixture)
└── data/synthetic/                # synthetic workbook + 2 aggregate CSVs + generator
```

Generated at runtime (gitignored): `data/clean/` (analysis frames) and `output/run_<TIMESTAMP>/` (figures, tables, manifest, log).

## Pipeline stages

| Step | File | Inputs | Outputs |
|---|---|---|---|
| 00 | `src/00_preprocess.do` | workbook (`synthetic_crf.xlsx`) | `data/clean/clean_efm_data.{dta,csv}`, `data/clean/secondary_outcomes.{dta,csv}` |
| 01 | `src/01_table1.do` | `clean_efm_data` | `Table_1_baseline_characteristics.csv` |
| 02 | `src/02_primary.do` | `clean_efm_data` | `primary_outcome.csv` |
| 03 | `src/03_subgroups_bmi.do` | `clean_efm_data` | `bmi_subgroup.csv` |
| 04 | `src/04_cumulative.do` | `clean_efm_data`, `reviewer_aggregate.csv` | `cumulative_recovery.csv`, `Figure_3_cumulative_recovery.png` |
| 05 | `src/05_doppler.do` | `clean_efm_data` | `Table_S2_physiological_surrogates.csv` |
| 06 | `src/06_secondary.do` | `secondary_outcomes`, `clean_efm_data` | `Table_S1_delivery_neonatal.csv` |
| 07 | `src/07_reliability.do` | `inter_rater.csv` | `Table_S3_reliability.csv` |
| 08 | `src/08_figure2_forest.do` | `clean_efm_data`, `reviewer_aggregate.csv` | `primary_effects_forest.csv`, `Figure_2a_forest.png`, `Figure_2b_effect_table.png` |

`src/master.do` sources `config.do` → `params.do` → `lib_stats.do`, fails closed if any required input is missing (`exit 601`), writes `run_manifest.csv`, then runs steps 00→08 and stops on the first non-zero return code.

## Output catalog (every file written to `output/run_<TIMESTAMP>/`)

| Path | Kind | Produced by | Description |
|---|---|---|---|
| `Table_1_baseline_characteristics.csv` | table | step 01 | Baseline characteristics by arm: mean ± SD (Welch t) / n (%) (Fisher) |
| `primary_outcome.csv` | table | step 02 | 30-min recovery: per-arm proportions (Wilson + exact), RD (Newcombe-Wilson), RR (log-binomial + csi), NNT, Fisher p, BMI-adjusted OR + AME |
| `bmi_subgroup.csv` | table | step 03 | BMI-stratified RR/RD + Fisher p; Breslow-Day OR-homogeneity |
| `cumulative_recovery.csv` | table | step 04 | Cumulative recovery proportions + Wilson 95% CI at 30/60/120 min |
| `Figure_3_cumulative_recovery.png` | figure | step 04 | Cumulative recovery curves + number-at-risk + exploratory DTSA cloglog HR |
| `Table_S2_physiological_surrogates.csv` | table | step 05 | IVC-CI & UA-PI median (IQR), ranksum, ANCOVA-adjusted 30-min MD |
| `Table_S1_delivery_neonatal.csv` | table | step 06 | Delivery route, NICU admission, Apgar < 7 (chi-square / Fisher) |
| `Table_S3_reliability.csv` | table | step 07 | Inter-rater Cohen's κ + H0 p + Landis-Koch interpretation |
| `primary_effects_forest.csv` | table | step 08 | Plotted effect estimates: overall 30/60/120, reviewers A/B/consensus, BMI strata |
| `Figure_2a_forest.png` | figure | step 08 | Primary-effects relative-risk forest |
| `Figure_2b_effect_table.png` | figure | step 08 | Numeric effect table (n/N, RD, NNT, RR, Fisher p) |
| `run_manifest.csv` | manifest | master | Run provenance: date, Stata version, input mode (synthetic/restricted), params |
| `pipeline.log` | log | master | Full run log (`log using`) |

## Data sources (every file the pipeline reads)

| Name in code | Path under `$EFM_RAW_DIR` | Format | Used by | Description |
|---|---|---|---|---|
| workbook | `synthetic_crf.xlsx` (or real CRF via `EFM_RAW_XLSX`) | xlsx | 00 | Sheet "Form responses 1" (pre/post Doppler) + "Sheet2" (recovery, demographics, secondary outcomes) |
| `reviewer_aggregate.csv` | `reviewer_aggregate.csv` | csv | 04, 08 | Per-arm Category-I counts at 30 min by assessor (bedside / Reviewer A / B / consensus) |
| `inter_rater.csv` | `inter_rater.csv` | csv | 07 | Per-participant Reviewer A / B / investigator EFM categories at baseline and 30 min |

## Entry points

- **Pipeline:** `stata-se -b -q do src/master.do` (run from the repo root). Steps run 00→08 in order; there is no per-step CLI; comment out entries in the `step_files` list in `src/master.do` to run a subset.
- **Tests:** `stata-se -b -q do tests/run_all_tests.do` → expect `6 passed, 0 failed`.
- **Config:** `src/config.do` (paths, `$SRC`, env-var overrides) and `src/params.do` (scientific constants).
- **Real CRF:** set `EFM_RAW_DIR`, `EFM_RAW_XLSX`, `EFM_OUTPUT_DIR` before running (see README → "Run On The Restricted Real CRF").

## Headline output preview

Thumbnails of the three headline figures (reduced-size, aggregate-only, from the synthetic run) are in [`docs/preview/`](docs/preview/) and embedded at the top of the [README](README.md).

## Reproduction targets (synthetic run)

The bundled synthetic run reproduces the manuscript's aggregate values exactly: 30-min recovery 26/30 vs 16/30, RD 33.3 pp (95% CI 10.2–52.3), RR 1.625 (1.13–2.34), Fisher p = 0.0101, NNT 3.0, exploratory DTSA HR 3.20 (1.70–6.00). See the README value table for the full list.
