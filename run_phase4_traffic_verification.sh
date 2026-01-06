#!/bin/bash
# Phase 4 Predictive Congestion Verification Test Suite
# Tests MVPP_MGC_PSO with bit_reverse, transpose, uniform-random traffic patterns
# Generated: December 17, 2025

set -e  # Exit on error

echo "==========================================="
echo "Phase 4 Traffic Pattern Verification Suite"
echo "==========================================="
echo ""

# Configuration
GEM5_BIN="/home/siat/gem5-gpu-bak/gem5/build/X86_Network_test/gem5.opt"
TEST_CONFIG="/home/siat/gem5-gpu-bak/gem5/configs/example/ruby_network_test.py"
RESULTS_DIR="/home/siat/gem5-gpu-bak/build_logs/phase4_traffic_verification_$(date +%Y%m%d_%H%M%S)"

# Create results directory
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Test Matrix Definition
declare -a TEST_NAMES=("uniform_0.3" "transpose_0.5" "bit_reverse_0.5" "bit_reverse_0.7")
declare -a PATTERNS=(0 2 1 1)
declare -a INJ_RATES=(0.3 0.5 0.5 0.7)
declare -a SIM_CYCLES=(10000 20000 20000 30000)
declare -a EXPECTED_BENEFIT=("1-2%" "6-10%" "10-15%" "15-20%")

# Check if gem5 binary exists
if [ ! -f "$GEM5_BIN" ]; then
    echo "ERROR: gem5 binary not found at $GEM5_BIN"
    echo "Please run ./implement_traffic_patterns.sh first to compile gem5 with Network_test protocol"
    exit 1
fi

# Run test matrix
echo "=========================================="
echo "Running Phase 4 Verification Test Matrix"
echo "=========================================="
echo ""

for i in {0..3}; do
    TEST_NAME="${TEST_NAMES[$i]}"
    PATTERN="${PATTERNS[$i]}"
    RATE="${INJ_RATES[$i]}"
    CYCLES="${SIM_CYCLES[$i]}"
    BENEFIT="${EXPECTED_BENEFIT[$i]}"

    echo "-------------------------------------------"
    echo "Test $((i+1))/4: $TEST_NAME"
    echo "-------------------------------------------"
    echo "Pattern: $PATTERN (0=uniform, 1=bit_reverse, 2=transpose)"
    echo "Injection Rate: $RATE"
    echo "Sim Cycles: $CYCLES"
    echo "Expected Phase 4 Benefit: $BENEFIT"
    echo ""

    OUTPUT_DIR="$RESULTS_DIR/$TEST_NAME"
    mkdir -p "$OUTPUT_DIR"

    # Run test
    echo "Running simulation..."
    $GEM5_BIN \
        -d "$OUTPUT_DIR" \
        $TEST_CONFIG \
        --num-cpus=16 \
        --num-dirs=2 \
        --network=garnet \
        --topology=Mesh \
        --mesh-rows=4 \
        --synthetic=$PATTERN \
        --injectionrate=$RATE \
        --precision=3 \
        --sim-cycles=$CYCLES \
        2>&1 | tee "$OUTPUT_DIR/simulation.log"

    if [ $? -eq 0 ]; then
        echo "✓ Test completed successfully"

        # Extract key metrics
        if [ -f "$OUTPUT_DIR/stats.txt" ]; then
            echo ""
            echo "Key Metrics:"
            grep "average_packet_latency" "$OUTPUT_DIR/stats.txt" | head -1
            grep "packets_received::total" "$OUTPUT_DIR/stats.txt" | head -1
            grep "average_hops" "$OUTPUT_DIR/stats.txt" | head -1
        fi
    else
        echo "✗ Test failed - check $OUTPUT_DIR/simulation.log"
        exit 1
    fi

    echo ""
done

echo "=========================================="
echo "✅ All Tests Completed Successfully!"
echo "=========================================="
echo ""
echo "Results Location: $RESULTS_DIR"
echo ""
echo "Next Steps:"
echo "1. Analyze results using:"
echo "   ./analyze_traffic_results.sh $RESULTS_DIR"
echo ""
echo "2. Compare specific metrics:"
echo "   grep 'average_packet_latency' $RESULTS_DIR/*/stats.txt"
echo "   grep 'packets_received::total' $RESULTS_DIR/*/stats.txt"
echo ""
echo "3. View detailed logs:"
echo "   cat $RESULTS_DIR/uniform_0.3/stats.txt"
echo "   cat $RESULTS_DIR/bit_reverse_0.5/stats.txt"
echo ""
