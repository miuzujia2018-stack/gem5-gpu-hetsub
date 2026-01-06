#!/bin/bash
# Generate all plots from CSV data
# This script runs all Python plotting scripts to generate figures

echo "=========================================================================="
echo "                    GENERATING ALL PLOTS FROM CSV DATA                   "
echo "=========================================================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Array of all plotting scripts
scripts=(
    "plot_dynamic_energy.py"
    "plot_energy_analysis.py"
    "plot_energy_efficiency.py"
    "plot_execution_time.py"
    "plot_hop_count_cpu.py"
    "plot_hop_count_cpu_applications.py"
    "plot_hop_count_gpu.py"
    "plot_hop_count_queuing_latency_gpu.py"
    "plot_latency_analysis.py"
    "plot_normalized_energy_efficiency_alpha.py"
    "plot_normalized_network_latency.py"
    "plot_normalized_throughput.py"
    "plot_static_energy.py"
    "plot_synthetic_traffic.py"
)

# Counter for tracking progress
total=${#scripts[@]}
current=0
success=0
failed=0

echo "Total scripts to run: $total"
echo ""

# Run each script
for script in "${scripts[@]}"; do
    current=$((current + 1))
    echo "[$current/$total] Running $script..."

    if python3 "$script" > /dev/null 2>&1; then
        echo "  ✓ Success"
        success=$((success + 1))
    else
        echo "  ✗ Failed"
        failed=$((failed + 1))
    fi
    echo ""
done

# Print summary
echo "=========================================================================="
echo "                           GENERATION SUMMARY                             "
echo "=========================================================================="
echo "Total scripts: $total"
echo "Successful:    $success"
echo "Failed:        $failed"
echo "=========================================================================="

if [ $failed -eq 0 ]; then
    echo "✓ All plots generated successfully!"
else
    echo "✗ Some plots failed to generate. Please check individual scripts."
fi

echo ""
echo "Output files are located in: $(dirname "$SCRIPT_DIR")/output/"
echo "=========================================================================="
