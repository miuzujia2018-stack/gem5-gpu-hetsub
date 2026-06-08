#!/bin/bash
# sweep_synth_traffic.sh — Sweep injection rates for 3 traffic patterns
#
# Usage: ./scripts/sweep_synth_traffic.sh [--sim-cycles 100000] [--seed 42]
#
# Output: m5out/synth/<pattern>/inj_<rate>/stats.txt for each run
#         m5out/synth/results.csv (aggregated)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GEM5_OPT="${PROJECT_DIR}/gem5/build/X86_VI_hammer_GPU/gem5.opt"
CONFIG="${PROJECT_DIR}/gem5-gpu/configs/synth_vi_hammer.py"
OUTBASE="${PROJECT_DIR}/m5out/synth"

SIM_CYCLES=100000
SEED=42
declare -A PATTERN_NAMES
PATTERN_NAMES[0]="uniform_random"
PATTERN_NAMES[1]="bit_reverse"
PATTERN_NAMES[2]="transpose"

# Injection rate sweep
INJ_RATES=(0.01 0.02 0.05 0.08 0.10 0.12 0.15 0.18 0.20 0.25 0.30 0.40 0.50 0.70 1.00)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sim-cycles) SIM_CYCLES="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "=== Synthetic Traffic Sweep ==="
echo "  sim-cycles: $SIM_CYCLES"
echo "  seed: $SEED"
echo "  patterns: ${PATTERN_NAMES[0]}, ${PATTERN_NAMES[1]}, ${PATTERN_NAMES[2]}"
echo "  inj rates: ${INJ_RATES[*]}"
echo ""

for pattern in 0 1 2; do
    pname="${PATTERN_NAMES[$pattern]}"
    for rate in "${INJ_RATES[@]}"; do
        outdir="${OUTBASE}/${pname}/inj_${rate}"
        mkdir -p "$outdir"

        echo "--- pattern=$pname ($pattern)  rate=$rate ---"
        "${GEM5_OPT}" \
            --outdir="$outdir" \
            "${CONFIG}" \
            --synthetic="$pattern" \
            --injectionrate="$rate" \
            --sim-cycles="$SIM_CYCLES" \
            --seed="$SEED" \
            > "${outdir}/stdout.log" 2>&1

        echo "  done"
    done
done

echo ""
echo "=== Parsing stats to CSV ==="
python "${SCRIPT_DIR}/parse_synth_stats.py" "${OUTBASE}"
echo ""
echo "=== Sweep complete. Results: ${OUTBASE}/results.csv ==="
