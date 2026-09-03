#!/bin/bash
# run_synth_sweep.sh — Host-side wrapper for the 3-pattern synthetic traffic sweep
#
# Usage: ./scripts/run_synth_sweep.sh
#
# Environment split:
#   Simulation → Docker container (gem5gpu-dev) — has gem5.opt build
#   Parse/Plot → Host — has python3 with matplotlib
#
# This wrapper ensures all host-visible artifacts (stats.txt, CSV, plots)
# come from the same run and are internally consistent.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTBASE="${PROJECT_DIR}/m5out/synth"
CONTAINER_PATH="/home/siat/gem5-gpu-xy"

echo "=== run_synth_sweep.sh ==="
echo ""

# ---------------------------------------------------------------------------
# Step 1 — Clean all previous artifacts from host
# ---------------------------------------------------------------------------
echo "Step 1/5: Clean stale artifacts"
rm -rf "${OUTBASE}"
mkdir -p "${OUTBASE}"
echo "  Cleaned ${OUTBASE}"

# ---------------------------------------------------------------------------
# Step 2 — Run full sweep inside Docker (simulation only)
# ---------------------------------------------------------------------------
echo ""
echo "Step 2/5: Run sweep inside Docker (gem5gpu-dev)"
sudo docker cp "${PROJECT_DIR}/scripts/sweep_synth_traffic.sh" \
    "gem5gpu-dev:${CONTAINER_PATH}/scripts/sweep_synth_traffic.sh"
sudo docker exec gem5gpu-dev /bin/bash -c "
  rm -rf ${CONTAINER_PATH}/m5out/synth && \
  mkdir -p ${CONTAINER_PATH}/m5out/synth && \
  cd ${CONTAINER_PATH} && \
  bash scripts/sweep_synth_traffic.sh --sim-cycles 100000 --random_seed 42 --skip-post
"
echo "  Sweep completed inside Docker."

# ---------------------------------------------------------------------------
# Step 3 — Copy artifacts from Docker overlay to host filesystem
# ---------------------------------------------------------------------------
# docker cp is used instead of relying on bind-mount propagation, because
# files created inside the container (root-owned) may remain inconsistent
# with what the host sees for pre-existing directories.
echo ""
echo "Step 3/5: Copy artifacts from Docker to host"
rm -rf "${OUTBASE}"
mkdir -p "${OUTBASE}"
sudo docker cp gem5gpu-dev:${CONTAINER_PATH}/m5out/synth/. "${OUTBASE}"
sudo chown -R "$(id -u):$(id -g)" "${OUTBASE}"
echo "  Copy done: ${OUTBASE}"

# ---------------------------------------------------------------------------
# Step 4 — Parse stats into CSV on host
# ---------------------------------------------------------------------------
echo ""
echo "Step 4/5: Parse stats on host"
python3 "${SCRIPT_DIR}/parse_synth_stats.py" "${OUTBASE}"

# ---------------------------------------------------------------------------
# Step 5 — Plot on host (matplotlib IS available here)
# ---------------------------------------------------------------------------
echo ""
echo "Step 5/5: Generate plots on host"
python3 "${SCRIPT_DIR}/plot_synth_traffic.py" "${OUTBASE}/results.csv"

echo ""
echo "=== Sweep complete ==="
echo "  CSV:        ${OUTBASE}/results.csv"
echo "  Latency:    ${OUTBASE}/latency_vs_load.png"
echo "  Throughput: ${OUTBASE}/throughput_vs_load.png"
