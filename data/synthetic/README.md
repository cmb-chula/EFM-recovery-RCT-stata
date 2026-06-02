# Synthetic example dataset

Everything in this folder is **fully synthetic**. No real participant data was
read, used, or reverse-engineered to create it. The files are generated
deterministically by [`generate_synthetic_data.py`](generate_synthetic_data.py),
calibrated only to the **published aggregate results** of the trial (group
sizes, recovery counts, subgroup splits, Doppler medians, reviewer-agreement
counts). They exist so that the analysis pipeline runs end-to-end and
reproduces the structure of the manuscript's figures and tables without anyone
needing access to the confidential case report form.

## Files

| File | Consumed by | Contents |
|---|---|---|
| `synthetic_crf.xlsx` | `00_preprocess.do` | Two sheets mirroring the real CRF: `Form responses 1` (Doppler) and `Sheet2` (recovery, demographics, secondary outcomes). |
| `reviewer_aggregate.csv` | `04_cumulative.do`, `08_figure2_forest.do` | Per-arm Category-I counts at 30 min by assessor (Figure 2/3 reviewer rows). |
| `inter_rater.csv` | `07_reliability.do` | Per-participant Reviewer A / B / investigator EFM categories at baseline and 30 min (Table S3 κ). |

## Regenerating

```bash
cd data/synthetic
python generate_synthetic_data.py     # requires numpy + openpyxl
```

A fixed seed makes the output identical on every run. The script prints an
aggregate-only calibration report (counts and means, never row values).

## Calibration targets (all from the published manuscript)

- **Recovery (bedside):** 30 min Bolus 26/30 vs Continuous 16/30; 60 min 29/30
  vs 17/30; 120 min 30/30 vs 17/30.
- **BMI subgroup:** ≥25, Bolus 17 (16 recovered) / Continuous 21 (12); <25,
  Bolus 13 (10) / Continuous 9 (4).
- **Reviewer Category-I @30 min:** A 21/15, B 22/13, Consensus 24/14,
  Bedside 26/16.
- **Inter-rater agreement (30 min):** A-vs-investigator κ 0.49, B-vs-investigator
  κ 0.68, A-vs-B κ 0.62; A-vs-B baseline κ 0.82.
- **Demographics / surrogates:** age, gestational age, BMI, IVC-CI and UA PI
  are drawn to approximate the published arm means / medians.

Because real RCT data should never be exactly reproducible from a synthetic
surrogate, the continuous variables (BMI, age, Doppler indices) are close to,
but not identical to, the published values, while the discrete outcome counts
that define the figures are matched exactly.

## Safety

This synthetic data is safe to share publicly. The real CRF
(`Bolus vs Continuous IUR Case Report Form Responses.xlsx`) is **not** part of
this repository and must never be committed.
