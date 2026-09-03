#!/bin/bash
# sweep_synth_traffic.sh — Sweep injection rates for 3 traffic patterns
#
# Usage: ./scripts/sweep_synth_traffic.sh [--sim-cycles 100000] [--random_seed 42]
#
# Output: m5out/synth/<pattern>/inj_<rate>/stats.txt for each run
#         m5out/synth/results.csv (aggregated)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GEM5_OPT="${PROJECT_DIR}/gem5/build/X86_Network_test/gem5.opt"
CONFIG="${PROJECT_DIR}/gem5/configs/example/ruby_network_test.py"
OUTBASE="${PROJECT_DIR}/m5out/synth"

# Remove stale directories from previous naming conventions
rm -rf "${OUTBASE}/uniform" 2>/dev/null || true

SIM_CYCLES=100000
SEED=42
SKIP_POST=0
declare -A PATTERN_NAMES
PATTERN_NAMES[0]="uniform_random"
PATTERN_NAMES[1]="bit_reverse"
PATTERN_NAMES[2]="transpose"

# Injection rate sweep
INJ_RATES=(0.01 0.02 0.05 0.08 0.10 0.12 0.15)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sim-cycles) SIM_CYCLES="$2"; shift 2 ;;
        --random_seed) SEED="$2"; shift 2 ;;
        --skip-post) SKIP_POST=1; shift ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

echo "=== Synthetic Traffic Sweep ==="
echo "  sim-cycles: $SIM_CYCLES"
echo "  random_seed: $SEED"
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
            --num-cpus=64 --num-dirs=64 \
            --garnet-network=flexible \
            --topology=Mesh --mesh-rows=8 \
            --random_seed="$SEED" \
            > "${outdir}/stdout.log" 2>&1

        echo "  done"
    done
done

if [[ "$SKIP_POST" -eq 1 ]]; then
    echo ""
    echo "=== Sweep complete (simulation only) ==="
    echo "  Raw stats: ${OUTBASE}/<pattern>/inj_<rate>/stats.txt"
    exit 0
fi

echo ""
echo "=== Parsing stats to CSV ==="
python3 "${SCRIPT_DIR}/parse_synth_stats.py" "${OUTBASE}"

echo ""
echo "=== Plotting latency/throughput curves ==="
if python3 -c "import matplotlib" 2>/dev/null; then
    python3 "${SCRIPT_DIR}/plot_synth_traffic.py" "${OUTBASE}/results.csv"
else
    echo "  matplotlib not available — skipping plot (run on host after docker cp)"
fi

echo ""
echo "=== Sweep complete ==="
echo "  CSV: ${OUTBASE}/results.csv"
echo "  Plots: ${OUTBASE}/latency_vs_load.png, ${OUTBASE}/throughput_vs_load.png"
