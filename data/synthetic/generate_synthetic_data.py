#!/usr/bin/env python3
"""Generate the synthetic example dataset for EFM-recovery-RCT-stata.

This script produces a *fully synthetic* workbook and two aggregate sub-study
CSVs that flow through the Stata pipeline and reproduce the structure of the
manuscript's figures and tables. NO real participant data is read or used: the
generator is calibrated only to the published aggregate results (group sizes,
recovery counts, subgroup splits, Doppler medians, reviewer-agreement counts).

Outputs (written next to this script, i.e. data/synthetic/):
    synthetic_crf.xlsx        sheets "Form responses 1" (CRF) and "Sheet2"
    reviewer_aggregate.csv    per-arm Category-I counts by assessor (Figure 2/3)
    inter_rater.csv           per-participant A/B/investigator classifications (Table S3)

Deterministic: a fixed seed makes every run identical.

Calibration targets (from the manuscript):
    Recovery (bedside): 30 min  Bolus 26/30, Continuous 16/30
                        60 min  Bolus 29/30, Continuous 17/30
                        120 min Bolus 30/30, Continuous 17/30
    BMI subgroup:  >=25  Bolus 17 (16 rec), Continuous 21 (12 rec)
                   <25   Bolus 13 (10 rec), Continuous  9 ( 4 rec)
    Reviewer Cat-I @30: A 21/15, B 22/13, Consensus 24/14, Bedside 26/16
"""

from __future__ import annotations
import csv
import os
import numpy as np
from openpyxl import Workbook

SEED = 20260525
RNG = np.random.default_rng(SEED)
HERE = os.path.dirname(os.path.abspath(__file__))
N_PER_ARM = 30

# Excel column headers (positions matter; the Stata loader renames by position).
SHEET1_HEADERS = [
    "Timestamp", "Hospital Number (HN)", "Input data ", "Protocol", "IUR time",
    "EFM Category", "Fetal heart rate", "Variability", "Acceleration", "Deceleration",
    "รูป EFM Monitor before IUR", "IVC Minimum", "IVC Maximum ",
    "Umbilical Artery Resistance Index (SI)", "Umbilical Artery Pulsatility Index (PI)",
    "Umbilical Artery Systolic/Diastolic (SD) ratio ", "EFM Category 2",
    "Fetal heart rate 2", "Variability 2", "Acceleration 2", "Deceleration 2",
    "รูป EFM Monitor after IUR", "IVC Minimum 2", "IVC Maximum  2",
    "Umbilical Artery Resistance Index (SI) 2", "Umbilical Artery Pulsatility Index (PI) 2",
    "Umbilical Artery Systolic/Diastolic (SD) ratio  2",
]
SHEET2_HEADERS = [
    "Order", "Age ", "Count", "GA", "Count.1", "Protocol", "Count.2", "IUR time",
    "monitor before", "Count.3", "FHR", "Count.4", "Variability", "Count.5",
    "Acceleration", "Count.6", "Deceleration", "Count.7", "IUR +20", "monitor +30",
    "Count.8", "Variability.1", "Count.9", "Deceleration.1", "Count.10",
    "Acceleration.1", "Count.11", "monitor +60", "Count.12", "Variability.2",
    "Count.13", "Deceleration.2", "Count.14", "Acceleration.2", "Count.15",
    "monitor +120", "Count.16", "Variability.3", "Count.17", "Deceleration.3",
    "Count.18", "Acceleration.3", "Count.19", "BMI", "Count.20", "Route", "Count.21",
    "Placenta", "Count.22", "Nuchal cord", "Count.23", "AF", "Count.24", "NICU",
    "Count.25", "APGAR 1 min", "APGAR 5 min", "Parity",  # Parity is the added column (BF)
]
PROTO_TEXT = {1: "Load (Bolus dose NSS 500ml IV bolus)",
              0: "Continuous (NSS 1000ml IV rate 150ml/hour)"}
CAT = {1: "Cat I", 2: "Cat II", 3: "Cat III"}


def truncated(mean, sd, lo, hi, n):
    """n samples from N(mean, sd) rejected to [lo, hi]."""
    out = []
    while len(out) < n:
        x = RNG.normal(mean, sd)
        if lo <= x <= hi:
            out.append(x)
    return np.array(out)


def build_patients():
    """Return a list of 60 patient dicts with all calibrated attributes."""
    # Bolus = odd order (1,3,..,59); Continuous = even order (2,4,..,60).
    bolus_orders = list(range(1, 61, 2))
    cont_orders = list(range(2, 61, 2))
    pts = {}
    for o in bolus_orders:
        pts[o] = {"order": o, "arm": 1}
    for o in cont_orders:
        pts[o] = {"order": o, "arm": 0}

    # ---- recovery timing x BMI category (exact cross-tabs) -----------------
    # Each entry: (bmi_cat, recovery_time) where recovery_time in {30,60,120,None}
    def assign(orders, plan):
        i = 0
        for (bmi_cat, rtime), k in plan:
            for _ in range(k):
                pts[orders[i]]["bmi_cat"] = bmi_cat
                pts[orders[i]]["rtime"] = rtime
                i += 1
        assert i == len(orders)

    # Bolus: >=25 -> 16 rec@30 + 1 rec@60 (=17); <25 -> 10 rec@30 + 2 rec@60 + 1 rec@120 (=13)
    assign(bolus_orders, [
        ((1, 30), 16), ((1, 60), 1),
        ((0, 30), 10), ((0, 60), 2), ((0, 120), 1),
    ])
    # Continuous: >=25 -> 12 rec@30 + 1 rec@60 + 8 never (=21); <25 -> 4 rec@30 + 5 never (=9)
    assign(cont_orders, [
        ((1, 30), 12), ((1, 60), 1), ((1, None), 8),
        ((0, 30), 4), ((0, None), 5),
    ])

    # ---- BMI value conditional on category, tuned to arm means -------------
    # Bolus mean ~26.9 (17 >=25, 13 <25); Continuous mean ~29.5 (21 >=25, 9 <25).
    bmi_hi = {1: (29.7, 3.0), 0: (31.8, 4.5)}   # (mean, sd) for BMI >= 25 by arm
    bmi_lo = {1: (23.0, 1.3), 0: (22.6, 1.6)}   # (mean, sd) for BMI < 25 by arm
    for arm in (1, 0):
        hi_orders = [o for o in pts if pts[o]["arm"] == arm and pts[o]["bmi_cat"] == 1]
        lo_orders = [o for o in pts if pts[o]["arm"] == arm and pts[o]["bmi_cat"] == 0]
        for o, v in zip(hi_orders, truncated(*bmi_hi[arm], 25.01, 45, len(hi_orders))):
            pts[o]["bmi"] = round(v, 1)
        for o, v in zip(lo_orders, truncated(*bmi_lo[arm], 17, 24.99, len(lo_orders))):
            pts[o]["bmi"] = round(v, 1)

    # ---- Age, GA (normal, hit arm means) -----------------------------------
    for arm, (am, asd, gm, gsd) in {1: (29.6, 5.2, 38.9, 1.1),
                                    0: (28.7, 4.4, 38.8, 1.2)}.items():
        ao = [o for o in pts if pts[o]["arm"] == arm]
        for o, a, g in zip(ao, truncated(am, asd, 18, 45, len(ao)),
                           truncated(gm, gsd, 37, 41.5, len(ao))):
            pts[o]["age"] = int(round(a))
            # GA as "weeks+days" string (e.g. 38+5)
            wk = int(g)
            day = int(round((g - wk) * 7))
            if day == 7:
                wk, day = wk + 1, 0
            pts[o]["ga"] = f"{wk}+{day}" if day else f"{wk}"

    # ---- Categorical counts (parity, cord, nuchal, meconium, delivery) -----
    def assign_counts(arm, field, value_counts):
        orders = [o for o in pts if pts[o]["arm"] == arm]
        vals = []
        for val, k in value_counts:
            vals += [val] * k
        assert len(vals) == len(orders), (field, arm, len(vals), len(orders))
        vals = list(RNG.permutation(vals))
        for o, v in zip(orders, vals):
            pts[o][field] = v

    # Parity: Bolus 12/10/8, Continuous 11/11/8  (0 / 1 / >=2-> store 2)
    assign_counts(1, "parity", [(0, 12), (1, 10), (2, 8)])
    assign_counts(0, "parity", [(0, 11), (1, 11), (2, 8)])
    # Cord insertion (placenta): Central Bolus 6 / Continuous 2; rest Eccentric
    assign_counts(1, "placenta", [("Central", 6), ("Eccentric", 24)])
    assign_counts(0, "placenta", [("Central", 2), ("Eccentric", 28)])
    # Nuchal cord present: Bolus 6 / Continuous 4
    assign_counts(1, "nuchal", [(1, 6), (0, 24)])
    assign_counts(0, "nuchal", [(1, 4), (0, 26)])
    # Meconium-stained AF (thin): Bolus 1 / Continuous 2
    assign_counts(1, "af", [("Thin meconium", 1), ("Clear", 29)])
    assign_counts(0, "af", [("Thin meconium", 2), ("Clear", 28)])
    # Route caesarean: Bolus 15 / Continuous 20
    assign_counts(1, "caesarean", [(1, 15), (0, 15)])
    assign_counts(0, "caesarean", [(1, 20), (0, 10)])
    # NICU: Bolus 2 / Continuous 0
    assign_counts(1, "nicu", [(1, 2), (0, 28)])
    assign_counts(0, "nicu", [(1, 0), (0, 30)])
    # Apgar <7 @1 min: Bolus 1 / Continuous 2  (5-min: all >=7)
    assign_counts(1, "apgar1_low", [(1, 1), (0, 29)])
    assign_counts(0, "apgar1_low", [(1, 2), (0, 28)])

    # ---- Doppler: IVC-CI and UA PI, baseline + 30 min ----------------------
    # Stored as IVC min/max (CI = (max-min)/max) and UA PI directly.
    # Targets (median): IVC-CI baseline B 42.4 / C 47.2 ; 30min B 46.0 / C 41.2
    #                   UA PI    baseline B 0.86 / C 0.83; 30min B 0.82 / C 0.79
    # Baseline arms overlap (between-arm comparison non-significant, like the
    # manuscript); the treatment signal is the differential change: bolus rises,
    # continuous falls. (pre_med, pre_sd, mean_change)
    ivc_par = {1: (0.44, 0.11, +0.015), 0: (0.46, 0.11, -0.055)}
    uapi_par = {1: (0.86, 0.07, -0.04), 0: (0.83, 0.10, -0.03)}
    for arm in (1, 0):
        ao = [o for o in pts if pts[o]["arm"] == arm]
        pre_m, pre_sd, dch = ivc_par[arm]
        pre = truncated(pre_m, pre_sd, 0.05, 0.90, len(ao))
        post = np.clip(pre + RNG.normal(dch, 0.045, len(ao)), 0.05, 0.95)
        upm, upsd, udch = uapi_par[arm]
        upre = truncated(upm, upsd, 0.55, 1.15, len(ao))
        upost = np.clip(upre + RNG.normal(udch, 0.06, len(ao)), 0.50, 1.20)
        for o, a, b, c, d in zip(ao, pre, post, upre, upost):
            pts[o]["ivc_ci_pre"], pts[o]["ivc_ci_post"] = a, b
            pts[o]["ua_pi_pre"], pts[o]["ua_pi_post"] = round(c, 2), round(d, 2)

    return pts


def assign_reviewers(pts):
    """Set baseline/post30 EFM categories for reviewers A, B and the bedside
    investigator, calibrated to the Table S3 agreement counts:
        baseline: A-vs-inv 55/60, B-vs-inv 53/60, A-vs-B 58/60
        30 min:   A-vs-inv 46/60 (k=0.49), B-vs-inv 51/60 (k=0.68), A-vs-B 49/60 (k=0.62)
    """
    bolus_rec = [o for o in pts if pts[o]["arm"] == 1 and pts[o]["rtime"] == 30]
    bolus_non = [o for o in pts if pts[o]["arm"] == 1 and pts[o]["rtime"] != 30]
    cont_rec = [o for o in pts if pts[o]["arm"] == 0 and pts[o]["rtime"] == 30]
    cont_non = [o for o in pts if pts[o]["arm"] == 0 and pts[o]["rtime"] != 30]

    # Bedside post30 = Cat I iff recovered by 30 min; baseline = Cat II for all.
    for o in pts:
        pts[o]["bedside_base"] = 2
        pts[o]["bedside_30"] = 1 if pts[o]["rtime"] == 30 else 2

    # Start A and B post30 equal to bedside, then apply the flip plan.
    for o in pts:
        pts[o]["a_30"] = pts[o]["bedside_30"]
        pts[o]["b_30"] = pts[o]["bedside_30"]

    def setcat(orders, field, val):
        for o in orders:
            pts[o][field] = val

    # Reviewer A flips: bolus FN=5 (first 5 recovered -> Cat II);
    #   cont FN=5 (first 5 recovered -> II), FP=4 (first 4 non-rec -> I)
    setcat(bolus_rec[0:5], "a_30", 2)
    setcat(cont_rec[0:5], "a_30", 2)
    setcat(cont_non[0:4], "a_30", 1)
    # Reviewer B flips: bolus FN=4 ({0,1,2,5}); cont FN=4 ({0,1,5,6}), FP=1 ({0})
    setcat([bolus_rec[i] for i in (0, 1, 2, 5)], "b_30", 2)
    setcat([cont_rec[i] for i in (0, 1, 5, 6)], "b_30", 2)
    setcat([cont_non[0]], "b_30", 1)

    # Baseline reviewer calls: A has 5 Cat-I, B has 7 Cat-I (A's 5 are a subset),
    # giving A-vs-inv 55, B-vs-inv 53, A-vs-B 58.
    all_orders = sorted(pts)
    for o in all_orders:
        pts[o]["a_base"] = 2
        pts[o]["b_base"] = 2
    a_base_ci = all_orders[0:5]
    b_base_ci = all_orders[0:7]   # superset of A's
    setcat(a_base_ci, "a_base", 1)
    setcat(b_base_ci, "b_base", 1)
    return pts


def write_workbook(pts):
    wb = Workbook()
    # ---- Sheet "Form responses 1": 2 rows per participant ------------------
    ws1 = wb.active
    ws1.title = "Form responses 1"
    ws1.append(SHEET1_HEADERS)
    ts = 0
    for o in sorted(pts):
        p = pts[o]
        hn = 600000 + o            # sorts identically to `order`
        ivc_max_pre, ivc_max_post = 2.0, 2.0
        ivc_min_pre = round(ivc_max_pre * (1 - p["ivc_ci_pre"]), 3)
        ivc_min_post = round(ivc_max_post * (1 - p["ivc_ci_post"]), 3)
        # Enrollment row (baseline Cat II, pre-Doppler, no recovery yet)
        ts += 1
        ws1.append([
            f"2025-08-01 {8 + ts % 12:02d}:00:00", hn, "", PROTO_TEXT[p["arm"]], 15,
            "Cat II", 140, "moderate", "absent", "none", "",
            ivc_min_pre, ivc_max_pre, 0.65, p["ua_pi_pre"], 2.6,
            "Cat II", 140, "moderate", "absent", "none", "",
            "", "", "", "", "",
        ])
        # Recovery row (post Cat I + post-Doppler); de-dup keeps this row.
        ts += 1
        ws1.append([
            f"2025-08-01 {8 + ts % 12:02d}:30:00", hn, "", PROTO_TEXT[p["arm"]], 15,
            "Cat II", 140, "moderate", "absent", "none", "",
            ivc_min_pre, ivc_max_pre, 0.65, p["ua_pi_pre"], 2.6,
            "Cat I", 142, "moderate", "present", "none", "",
            ivc_min_post, ivc_max_post, 0.62, p["ua_pi_post"], 2.5,
        ])

    # ---- Sheet "Sheet2": one row per participant ---------------------------
    ws2 = wb.create_sheet("Sheet2")
    ws2.append(SHEET2_HEADERS)
    for o in sorted(pts):
        p = pts[o]
        cat30 = CAT[1] if p["rtime"] == 30 else CAT[2]
        cat60 = CAT[1] if p["rtime"] in (30, 60) else CAT[2]
        cat120 = CAT[1] if p["rtime"] in (30, 60, 120) else CAT[2]
        route = "Caesarean delivery" if p["caesarean"] == 1 else "Vaginal delivery"
        row = [""] * len(SHEET2_HEADERS)
        row[0] = o                      # A  Order
        row[1] = p["age"]               # B  Age
        row[3] = p["ga"]                # D  GA
        row[5] = PROTO_TEXT[p["arm"]]   # F  Protocol
        row[8] = "Cat II"               # I  monitor before (baseline)
        row[10] = 140                   # K  FHR
        row[12] = "moderate"            # M  Variability
        row[19] = cat30                 # T  monitor +30
        row[27] = cat60                 # AB monitor +60
        row[35] = cat120                # AJ monitor +120
        row[43] = p["bmi"]              # AR BMI
        row[45] = route                 # AT Route
        row[47] = p["placenta"]         # AV Placenta (cord insertion)
        row[49] = 1 if p["nuchal"] == 1 else 0   # AX Nuchal cord
        row[51] = p["af"]               # AZ AF (meconium)
        row[53] = 1 if p["nicu"] == 1 else 0     # BB NICU
        row[55] = 5 if p["apgar1_low"] == 1 else 9   # BD APGAR 1 min
        row[56] = 9                     # BE APGAR 5 min (all >=7)
        row[57] = p["parity"]           # BF Parity (added column)
        ws2.append(row)

    out = os.path.join(HERE, "synthetic_crf.xlsx")
    wb.save(out)
    return out


def write_reviewer_aggregate():
    """Per-arm Cat-I counts at 30 min (published values, feed Figure 2/3)."""
    rows = [
        ("Bolus", "Bedside", 26, 30), ("Continuous", "Bedside", 16, 30),
        ("Bolus", "Reviewer_A", 21, 30), ("Continuous", "Reviewer_A", 15, 30),
        ("Bolus", "Reviewer_B", 22, 30), ("Continuous", "Reviewer_B", 13, 30),
        ("Bolus", "Consensus", 24, 30), ("Continuous", "Consensus", 14, 30),
    ]
    out = os.path.join(HERE, "reviewer_aggregate.csv")
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["arm", "assessor", "cat1", "n"])
        w.writerows(rows)
    return out


def write_inter_rater(pts):
    out = os.path.join(HERE, "inter_rater.csv")
    with open(out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["order", "timepoint", "a", "b", "bedside"])
        for o in sorted(pts):
            p = pts[o]
            w.writerow([o, "baseline", p["a_base"], p["b_base"], p["bedside_base"]])
            w.writerow([o, "post30", p["a_30"], p["b_30"], p["bedside_30"]])
    return out


def report(pts):
    """Print an aggregate-only calibration report (no row-level values)."""
    def cnt(pred):
        return sum(1 for o in pts if pred(pts[o]))
    print("\n=== Synthetic-data calibration report (aggregate only) ===")
    for arm, lab in ((1, "Bolus"), (0, "Continuous")):
        n = cnt(lambda p: p["arm"] == arm)
        r30 = cnt(lambda p: p["arm"] == arm and p["rtime"] == 30)
        r60 = cnt(lambda p: p["arm"] == arm and p["rtime"] in (30, 60))
        r120 = cnt(lambda p: p["arm"] == arm and p["rtime"] in (30, 60, 120))
        bmi_hi = cnt(lambda p: p["arm"] == arm and p["bmi_cat"] == 1)
        bmis = [pts[o]["bmi"] for o in pts if pts[o]["arm"] == arm]
        print(f"{lab:11s} n={n}  rec@30={r30} @60={r60} @120={r120}  "
              f">=25:{bmi_hi}  BMI mean={np.mean(bmis):.1f}")
    # reviewer agreement (post30)
    def agree(f1, f2, tp):
        return cnt(lambda p: p[f"{f1}_{tp}"] == p[f"{f2}_{tp}"])
    print(f"post30 agree  A-inv={agree('a','bedside','30')}  "
          f"B-inv={agree('b','bedside','30')}  A-B={agree('a','b','30')}")
    print(f"baseline agree A-inv={agree('a','bedside','base')}  "
          f"B-inv={agree('b','bedside','base')}  A-B={agree('a','b','base')}")
    aci = cnt(lambda p: p["a_30"] == 1)
    bci = cnt(lambda p: p["b_30"] == 1)
    print(f"post30 Cat-I  A={aci}  B={bci}")


def main():
    pts = build_patients()
    pts = assign_reviewers(pts)
    x = write_workbook(pts)
    r = write_reviewer_aggregate()
    i = write_inter_rater(pts)
    report(pts)
    print(f"\nWrote:\n  {x}\n  {r}\n  {i}")


if __name__ == "__main__":
    main()
