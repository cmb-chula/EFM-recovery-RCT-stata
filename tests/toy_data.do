// ============================================================
// tests/toy_data.do  —  shared toy dataset for the test suite.
// Defines make_toy: a 20-participant dataset with hand-computable answers,
// used to validate the binary-outcome / survival / subgroup methods.
//
// Known properties:
//   Primary (event_30): Bolus 8/10, Continuous 4/10
//       RR = 2.0, RD = 0.40, NNT = 2.5, Fisher exact p = 0.16980
//       Wilson 95% CI 8/10 = [0.4902, 0.9433]; 4/10 = [0.1682, 0.6873]
//   BMI strata (bmi_cat): each stratum 5 Bolus + 5 Continuous, 4/5 vs 2/5
//       -> per-stratum RR = 2.0, OR = 6.0 (equal -> Breslow-Day homogeneous)
//   Cumulative: Bolus 8 -> 9 -> 10 at 30/60/120; Continuous 4 -> 4 -> 4
// ============================================================

capture program drop make_toy
program define make_toy
    clear
    set obs 20
    gen byte protocol_bin = (_n <= 10)                       // 1 = Bolus
    gen byte bmi_cat = (_n <= 5 | inrange(_n, 11, 15))       // 1 = BMI >= 25

    gen byte event_30 = 0
    replace event_30 = 1 in 1/4        // Bolus, BMI>=25: 4/5
    replace event_30 = 1 in 6/9        // Bolus, BMI<25 : 4/5  -> Bolus 8/10
    replace event_30 = 1 in 11/12      // Cont,  BMI>=25: 2/5
    replace event_30 = 1 in 16/17      // Cont,  BMI<25 : 2/5  -> Cont 4/10

    gen byte event_recovered = event_30
    replace event_recovered = 1 in 5             // +1 Bolus by 60 -> 9/10
    gen byte event_recovered_120 = event_recovered
    replace event_recovered_120 = 1 in 10        // +1 Bolus by 120 -> 10/10

    gen double time_to_cat1_min = 60
    replace time_to_cat1_min = 30 if event_30 == 1
    replace time_to_cat1_min = 60 if event_recovered == 1 & event_30 == 0
    gen double time_to_cat1_120_min = 120
    replace time_to_cat1_120_min = 30  if event_30 == 1
    replace time_to_cat1_120_min = 60  if event_recovered == 1 & event_30 == 0
    replace time_to_cat1_120_min = 120 if event_recovered_120 == 1 & event_recovered == 0
end
