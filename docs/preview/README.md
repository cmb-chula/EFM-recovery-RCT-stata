# Output preview thumbnails

Reduced-size (≤ 300 px wide, ≤ 80 KB each), aggregate-only previews of the
headline figures, used in the top-level README gallery and in
`PIPELINE_STRUCTURE.md`. They were generated from the **synthetic** release run
(`do src/master.do` on `data/synthetic/synthetic_crf.xlsx`) by resampling the
full-resolution PNGs. No participant-level data is encoded; every panel is a
group-level summary (curves, forest estimates, n/N counts) of the bundled
synthetic cohort.

| Thumbnail | Full output | Produced by |
|---|---|---|
| `figure2a_forest.png` | `Figure_2a_forest.png` | `src/08_figure2_forest.do` |
| `figure2b_effect_table.png` | `Figure_2b_effect_table.png` | `src/08_figure2_forest.do` |
| `figure3_recovery.png` | `Figure_3_cumulative_recovery.png` | `src/04_cumulative.do` |

To regenerate: run the pipeline, then
`sips --resampleWidth 300 output/run_<TS>/<figure>.png --out docs/preview/<thumb>.png`.
