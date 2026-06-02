# Data dictionary: EFM-recovery-RCT-stata

This dictionary documents (1) the source workbook the pipeline reads, (2) the
analysis-ready dataset `00_preprocess.do` builds from it, and (3) the two
aggregate sub-study inputs. The bundled synthetic dataset follows exactly this
schema; see [`data/synthetic/README.md`](data/synthetic/README.md) for its
provenance.

Trial design: two parallel arms, 1:1 allocation, n = 60 (30 **Bolus**,
30 **Continuous**). One row per participant in the analysis dataset.

---

## 1. Source workbook (`synthetic_crf.xlsx` / real CRF)

The loader reads two sheets **by column position** (so it is insensitive to header
text). Only the columns below are used; others are ignored.

### Sheet `Form responses 1` (case report form; ≥1 row per participant)

| Col | Field | Used as |
|---|---|---|
| A | Timestamp | de-duplication ordering |
| B | Hospital Number | participant key (sort order for linkage; never exported) |
| D | Protocol | arm (substring `bolus`/`load` vs `continuous`/`infusion`) |
| F | EFM Category | baseline category (eligibility: Category II) |
| L, M | IVC Minimum / Maximum (pre) | IVC-CI pre |
| O | UA Pulsatility Index (pre) | UA PI pre |
| Q | EFM Category 2 | post-IUR category (de-dup: keep first Cat I row) |
| W, X | IVC Minimum / Maximum (post) | IVC-CI post |
| Z | UA Pulsatility Index (post) | UA PI post |

Multiple rows per participant are de-duplicated to one (the recovery row), then
the cohort is filtered to baseline Category II.

### Sheet `Sheet2` (one row per enrolled participant)

| Col | Field | Used as |
|---|---|---|
| A | Order | participant order (Sheet1↔Sheet2 link key) |
| B | Age | `age` |
| D | GA | `ga` (parsed from `weeks+days`) |
| F | Protocol | authoritative arm assignment |
| T | monitor +30 | 30-min EFM category → `event_30` |
| AB | monitor +60 | 60-min category → `event_recovered` |
| AJ | monitor +120 | 120-min category → `event_recovered_120` |
| AR | BMI | `bmi`, `bmi_cat` |
| AT | Route | delivery route (Table S1) |
| AV | Placenta | cord insertion (Table 1) |
| AX | Nuchal cord | `nuchal_cord` (Table 1) |
| AZ | AF | amniotic fluid / meconium (Table 1) |
| BB | NICU | NICU admission (Table S1) |
| BD, BE | APGAR 1 / 5 min | Apgar < 7 (Table S1) |
| BF | Parity | `parity_raw`, `parity_cat3` (Table 1, added column) |

> **Note.** Column BF (Parity) is present in the synthetic workbook. The
> original CRF captured parity separately; the loader reads it if present and
> otherwise leaves parity missing.

---

## 2. Analysis dataset (`data/clean/clean_efm_data.csv`, one row per participant)

| Variable | Type | Description |
|---|---|---|
| `order` | int | Participant order (1–60) |
| `protocol` | str | `"Bolus"` / `"Continuous"` |
| `protocol_bin` | 0/1 | 1 = Bolus, 0 = Continuous (reference) |
| `age` | num | Maternal age (years) |
| `ga` | num | Gestational age (fractional weeks; `"38+3"` → 38.43) |
| `bmi` | num | Body-mass index (kg/m²) |
| `bmi_cat` | 0/1 | 0 = `<25`, 1 = `≥25` (cut-point `BMI_CUT` = 25) |
| `parity_raw` | int | Parity count (0, 1, 2, …) |
| `parity_cat3` | 0/1/2 | 0 = nulliparous, 1 = para 1, 2 = para ≥2 |
| `event_30` | 0/1 | **Primary**: Category I at 30 min |
| `event_recovered` | 0/1 | Category I by 60 min (key secondary; censored at 60) |
| `time_to_cat1_min` | num | Time to Category I or 60-min censoring (30/60) |
| `event_recovered_120` | 0/1 | Category I by 120 min (exploratory) |
| `time_to_cat1_120_min` | num | Time to Category I or 120-min censoring (30/60/120) |
| `ivc_ci_pre` | num | IVC collapsibility index pre-IUR, `(max−min)/max` ∈ [0,1] |
| `ivc_ci_post` | num | IVC collapsibility index post-IUR |
| `ua_pi_pre` | num | Umbilical-artery pulsatility index pre-IUR |
| `ua_pi_post` | num | Umbilical-artery pulsatility index post-IUR |
| `route` | str | Delivery route (raw text) |
| `placenta` | str | Cord-insertion text (`Central` / `Eccentric`) |
| `nuchal_cord` | 0/1 | Nuchal cord present |
| `af` | str | Amniotic-fluid text (`Thin meconium` / `Clear`) |
| `nicu` | 0/1 | NICU admission |
| `apgar_1_min`, `apgar_5_min` | int | Apgar scores |

`data/clean/secondary_outcomes.csv` is a subset (`order`, `route`, `nicu`,
`apgar_1_min`, `apgar_5_min`) used to build Table S1.

### Derived-variable rules

- **EFM category** parsed from the monitor text to {1 = Cat I, 2 = Cat II,
  3 = Cat III} via case-insensitive regex.
- **Recovery events** are cumulative: `event_recovered_120` ≥ `event_recovered`
  ≥ `event_30`. Non-recoverers are censored at the window edge.
- **IVC-CI** = (IVC max − IVC min) / IVC max, on the proportion scale; reported
  ×100 (%) in Table S2.

---

## 3. Aggregate sub-study inputs (`data/synthetic/`)

### `reviewer_aggregate.csv`: Figure 2/3 reviewer rows

| Column | Description |
|---|---|
| `arm` | `Bolus` / `Continuous` |
| `assessor` | `Bedside` / `Reviewer_A` / `Reviewer_B` / `Consensus` |
| `cat1` | Participants classified Category I at 30 min |
| `n` | Participants per arm (30) |

### `inter_rater.csv`: Table S3 (Cohen's κ)

| Column | Description |
|---|---|
| `order` | Participant order (1–60) |
| `timepoint` | `baseline` / `post30` |
| `a`, `b` | Reviewer A / B EFM category (1 = Cat I, 2 = Cat II) |
| `bedside` | Real-time investigator category (baseline = all Cat II by inclusion) |
