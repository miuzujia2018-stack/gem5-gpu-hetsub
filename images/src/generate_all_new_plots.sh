#!/bin/bash
# Batch script to generate all visualization plots from CSV data

echo "=========================================="
echo "Generating All Visualization Plots"
echo "=========================================="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Run all plotting scripts
echo ""
echo "[1/5] Generating normalized energy efficiency (ALPHA)..."
python3 plot_normalized_energy_efficiency_alpha.py

echo ""
echo "[2/5] Generating normalized network latency..."
python3 plot_normalized_network_latency.py

echo ""
echo "[3/5] Generating normalized throughput..."
python3 plot_normalized_throughput.py

echo ""
echo "[4/5] Generating hop count analysis (CPU applications)..."
python3 plot_hop_count_cpu_applications.py

echo ""
echo "[5/5] Generating hop count and queuing latency (GPU applications)..."
python3 plot_hop_count_queuing_latency_gpu.py

echo ""
echo "=========================================="
echo "All plots generated successfully!"
echo "Check the output directory for results."
echo "=========================================="
