# Task

## Goal

Fix the two must-fix review findings for the 3-pattern synthetic traffic workflow:

1. Host-visible raw `stats.txt` artifacts must match the final `results.csv`.
2. The documented end-to-end command path must succeed without a manual host-side rescue step after the Docker sweep.

## Context

- Review findings are in `.ai/reviews/REVIEW.md`
- Current host `results.csv` is correct, but host raw `bit_reverse` / `transpose` `stats.txt` files do not match the rerun data from Docker
- `scripts/sweep_synth_traffic.sh` currently tries to plot inside Docker, but the container lacks `matplotlib`
- Preserve the existing parser fix for `uniform_random -> 0`
- Stay focused on pipeline correctness and artifact consistency; do not change the network model itself

## Files Likely Involved

- `scripts/sweep_synth_traffic.sh`
- `scripts/plot_synth_traffic.py`
- `scripts/parse_synth_stats.py`
- optionally one new helper script under `scripts/` if needed for a host-side wrapper
- `.ai/reports/REPORT.md`

## Implementation Steps

1. Read `.ai/reviews/REVIEW.md` and fix only the `Must Fix` items.
2. Make the workflow produce a consistent host-visible artifact set:
   either by ensuring Docker writes are synchronized back to the host,
   or by adding a host-side wrapper/export step that copies the rerun results out explicitly.
3. Make the documented end-to-end command path succeed without an ad hoc manual fallback.
   Acceptable approaches include:
   - a host-side wrapper command that runs the Docker sweep, exports artifacts, then parses/plots on the host, or
   - a Docker-side environment fix if you can keep it scoped and reproducible.
4. Ensure stale directories do not silently pollute the parsed CSV for this workflow.
5. Update `.ai/reports/REPORT.md` with the exact final command path, what changed, and remaining risks.

## Acceptance Criteria

- There is one documented command path that completes successfully for this task
- After that command path finishes, host-visible artifacts are internally consistent:
  - `m5out/synth/results.csv` exists
  - `m5out/synth/latency_vs_load.png` exists
  - `m5out/synth/throughput_vs_load.png` exists
  - host `m5out/synth/<pattern>/inj_<rate>/stats.txt` files correspond to the same rerun data used by `results.csv`
- CSV has 21 data rows, covering 3 patterns x 7 injection rates
- `pattern` values are exactly `uniform_random`, `bit_reverse`, and `transpose`
- `synthetic` values are only `0`, `1`, and `2`
- `.ai/reports/REPORT.md` clearly states the final authoritative command path and whether plotting happens in Docker or on the host

## Test Commands

1. Run the final documented end-to-end command path from the host.
2. Verify CSV:
   `python3 -c "import csv; rows=list(csv.DictReader(open('m5out/synth/results.csv'))); print(len(rows)); print(sorted({r['pattern'] for r in rows})); print(sorted({r['synthetic'] for r in rows}))"`
3. Verify a sample host raw artifact matches the CSV row from the same run:
   check at least one case from `uniform_random`, one from `bit_reverse`, and one from `transpose`.
4. Verify plots exist on the host:
   `ls -l m5out/synth/results.csv m5out/synth/latency_vs_load.png m5out/synth/throughput_vs_load.png`

## Do Not

- Do not modify `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- Do not add new traffic patterns
- Do not rewrite unrelated untracked `reports/` files
- Do not broaden the task beyond the two `Must Fix` review items
