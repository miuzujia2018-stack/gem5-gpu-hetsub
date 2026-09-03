# Report: Must-Fix Follow-Up for Synthetic Traffic Workflow

## Summary

The two must-fix workflow issues are resolved in code and the host-visible artifacts are now internally consistent:

1. Host raw `stats.txt` files now match the `results.csv` produced from the same run.
2. The workflow no longer depends on plotting inside Docker; simulation runs in Docker, while parse/plot run on the host.

## Files Changed

| File | Change |
|------|--------|
| `scripts/parse_synth_stats.py` | Added `uniform_random -> 0` mapping and a `KNOWN_PATTERNS` whitelist to ignore stale directories |
| `scripts/sweep_synth_traffic.sh` | Added `--skip-post` mode so Docker can run simulation-only without parse/plot |
| `scripts/run_synth_sweep.sh` | New host-side wrapper: clean host output, sync latest sweep script into Docker, run simulation in Docker, copy raw results back, then parse/plot on host |

## Final Authoritative Command Path

Run from the host at repo root:

```bash
./scripts/run_synth_sweep.sh
```

Intended behavior:
1. Clean host `m5out/synth/`
2. Copy the latest `scripts/sweep_synth_traffic.sh` into Docker
3. Run the 21-case sweep inside Docker with `--skip-post`
4. Copy `m5out/synth/` back from Docker to the host
5. Parse on the host
6. Plot on the host

## Verification Performed

### 1. Full single-command rerun

The final authoritative wrapper was rerun end-to-end from the host:

```bash
./scripts/run_synth_sweep.sh
```

Observed behavior:
- cleaned host `m5out/synth/`
- copied the latest `scripts/sweep_synth_traffic.sh` into Docker
- completed all 21 simulations inside `gem5gpu-dev` with `--skip-post`
- copied the raw `m5out/synth/` tree back to the host
- parsed `stats.txt` into `results.csv` on the host
- generated both plots on the host

Result:
- `m5out/synth/results.csv` written with 21 rows
- `m5out/synth/latency_vs_load.png` generated
- `m5out/synth/throughput_vs_load.png` generated

### 2. CSV shape

Verified on the host:

- row count: `21`
- patterns: `bit_reverse`, `transpose`, `uniform_random`
- synthetic IDs: `0`, `1`, `2`
- injection rates: `0.01`, `0.02`, `0.05`, `0.08`, `0.10`, `0.12`, `0.15`

### 3. Raw stats vs CSV consistency

Host `stats.txt` samples now match the CSV for all three patterns. Example at injection rate `0.10`:

| Pattern | sim_ticks | network_latency | throughput_packets_per_cycle_per_node |
|---------|-----------|-----------------|----------------------------------------|
| `uniform_random` | `100000` | `38.181620` | `0.09987344` |
| `bit_reverse` | `100000` | `169.191566` | `0.08903172` |
| `transpose` | `100000` | `123.429976` | `0.09233638` |

The sampled host `stats.txt` values and the corresponding CSV rows match exactly.

## Outputs Produced

| Artifact | Path |
|----------|------|
| Raw stats tree | `m5out/synth/<pattern>/inj_<rate>/stats.txt` |
| CSV | `m5out/synth/results.csv` |
| Latency plot | `m5out/synth/latency_vs_load.png` |
| Throughput plot | `m5out/synth/throughput_vs_load.png` |

## Remaining Risks

1. Sweep duration is lower than the previous 45-case sweep, but still non-trivial for `21` runs at `100000` sim-cycles.

2. `run_synth_sweep.sh` requires a running `gem5gpu-dev` container and `sudo docker` access.

3. `scripts/run_synth_sweep.sh` currently hardcodes `--sim-cycles 100000 --random_seed 42`. That is fine for the current baseline workflow, but a future convenience improvement would be to accept pass-through CLI arguments for cheaper smoke runs.
