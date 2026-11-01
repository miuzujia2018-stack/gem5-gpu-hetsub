#!/usr/bin/env bash
# Server-side replacement for the legacy Docker wrapper: the simulation runs in
# the disposable unified container for the hetsub profile on the Synopsys
# server, and parse/plot still run on this host (python3 with matplotlib).
# The legacy body is preserved under
# gem5-unified/manifests/legacy-specialized-20261028/.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTBASE="${PROJECT_DIR}/m5out/synth"
PROFILE=hetsub
SOURCE_DIR_NAME=gem5-gpu-hetsub
UNIFIED="$(cd -P -- "$SCRIPT_DIR/../../gem5-unified" && pwd)"
export GEM5_IMAGE="${GEM5_IMAGE:-localhost/gem5gpu-standby:20261027}"
export GEM5_SERVER_MODE=1
REMOTE="${GEM5_SYNC_REMOTE:-suat-lic-server}"
REMOTE_ROOT="${GEM5_SYNC_REMOTE_ROOT:-gem5-unified}"

echo "=== run_synth_sweep.sh (server: $REMOTE) ==="
echo ""

# ---------------------------------------------------------------------------
# Step 1 — Clean all previous artifacts on this host
# ---------------------------------------------------------------------------
echo "Step 1/5: Clean stale artifacts"
rm -rf "${OUTBASE}"
mkdir -p "${OUTBASE}"
echo "  Cleaned ${OUTBASE}"

# ---------------------------------------------------------------------------
# Step 2 — Run the full sweep in the unified container (simulation only)
# ---------------------------------------------------------------------------
echo ""
echo "Step 2/5: Run sweep in the $PROFILE container on the server"
"$UNIFIED/scripts/server-command.sh" "$PROFILE" \
    bash /home/siat/${SOURCE_DIR_NAME}/scripts/run_synth_sweep.server.sh
echo "  Sweep completed on the server."

# ---------------------------------------------------------------------------
# Step 3 — Fetch artifacts from the per-profile results directory
# ---------------------------------------------------------------------------
echo ""
echo "Step 3/5: Fetch artifacts from the server"
rm -rf "${OUTBASE}"
mkdir -p "${OUTBASE}"
# Extract the contents of the remote synth directory directly into OUTBASE:
# the parser expects <OUTBASE>/<pattern>/inj_<rate>/stats.txt, i.e. the same
# layout the legacy docker-cp wrapper produced.
ssh -o BatchMode=yes "$REMOTE" \
    "tar -C '${REMOTE_ROOT}/results/${PROFILE}/synth' -cf - ." |
    tar -xf - -C "${OUTBASE}"
echo "  Copy done: ${OUTBASE}"

# ---------------------------------------------------------------------------
# Step 4 — Parse stats into CSV on this host
# ---------------------------------------------------------------------------
echo ""
echo "Step 4/5: Parse stats on host"
python3 "${SCRIPT_DIR}/parse_synth_stats.py" "${OUTBASE}"

# ---------------------------------------------------------------------------
# Step 5 — Plot on this host (matplotlib IS available here)
# ---------------------------------------------------------------------------
echo ""
echo "Step 5/5: Generate plots on host"
python3 "${SCRIPT_DIR}/plot_synth_traffic.py" "${OUTBASE}/results.csv"

echo ""
echo "=== Sweep complete ==="
echo "  CSV:        ${OUTBASE}/results.csv"
echo "  Latency:    ${OUTBASE}/latency_vs_load.png"
echo "  Throughput: ${OUTBASE}/throughput_vs_load.png"
