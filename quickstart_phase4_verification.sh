#!/bin/bash
# Phase 4 Traffic Pattern Verification - Quick Start Guide
# Complete workflow from implementation to results analysis
# Generated: December 17, 2025

echo "════════════════════════════════════════════════════════════════════════"
echo "  Phase 4 Predictive Congestion Modeling - Traffic Pattern Verification"
echo "  Quick Start Guide"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}═══ STEP $1: $2 ═══${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Note: This script now supports both local (138) and remote (128) execution
# If on 138, it will use remote compilation (faster)
# If on 128, it will use local compilation

# ═══════════════════════════════════════════════════════════════════════════
print_step "1" "Implementation Status Check"
# ═══════════════════════════════════════════════════════════════════════════

NETWORKTEST_CC="/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc"
GEM5_BIN="/home/siat/gem5-gpu-bak/gem5/build/X86_Network_test/gem5.opt"

echo "Checking if traffic patterns are already implemented..."
echo ""

if grep -q "BIT REVERSE" "$NETWORKTEST_CC" 2>/dev/null; then
    print_success "Traffic patterns already implemented in networktest.cc"
    IMPLEMENTATION_DONE=true
else
    print_warning "Traffic patterns NOT YET implemented"
    IMPLEMENTATION_DONE=false
fi

if [ -f "$GEM5_BIN" ]; then
    print_success "gem5 Network_test binary exists"
    BINARY_EXISTS=true
else
    print_warning "gem5 Network_test binary NOT found"
    BINARY_EXISTS=false
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
print_step "2" "Implementation (if needed)"
# ═══════════════════════════════════════════════════════════════════════════

if [ "$IMPLEMENTATION_DONE" = false ]; then
    echo "Modifying networktest.cc to add traffic patterns..."
    echo ""

    # Apply code modifications only (without compilation)
    NETWORKTEST_CC="/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc"
    BACKUP_FILE="${NETWORKTEST_CC}.backup_$(date +%Y%m%d)"
    TEMP_FILE="${NETWORKTEST_CC}.tmp"

    # Create backup if not exists
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$NETWORKTEST_CC" "$BACKUP_FILE"
        print_success "Backup created: $BACKUP_FILE"
    fi

    # Apply modifications using Python script
    python << 'EOF_PYTHON'
import sys

# Read original file
with open('/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc', 'r') as f:
    lines = f.readlines()

# Replacement code block
replacement = """unsigned destination = id;
if (trafficType == 0) {
    // UNIFORM RANDOM
    destination = random_mt.random<unsigned>(0, numMemories - 1);
} else if (trafficType == 1) {
    // BIT REVERSE
    int numBits = (int) log2(numMemories);
    unsigned dest_id = 0;
    unsigned src_id = id;
    for (int i = 0; i < numBits; i++) {
        unsigned bit = (src_id >> i) & 1;
        dest_id |= (bit << (numBits - 1 - i));
    }
    destination = dest_id;
} else if (trafficType == 2) {
    // TRANSPOSE
    int networkDimension = (int) sqrt(numMemories);
    int my_x = id % networkDimension;
    int my_y = id / networkDimension;
    int dest_x = my_y;
    int dest_y = my_x;
    destination = dest_y * networkDimension + dest_x;
} else {
    destination = random_mt.random<unsigned>(0, numMemories - 1);
    warn("Invalid traffic type %d, using Uniform Random\\n", trafficType);
}
"""

# Find and replace lines 177-199
output_lines = []
i = 0
while i < len(lines):
    if i == 176 and 'unsigned destination = id;' in lines[i]:
        output_lines.append(replacement)
        i += 23  # Skip 23 lines
    else:
        output_lines.append(lines[i])
        i += 1

# Write modified file
with open('/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc', 'w') as f:
    f.writelines(output_lines)

print("✓ Code modification applied")
EOF_PYTHON

    # Add include directive if not present
    if ! grep -q "#include <cmath>" "$NETWORKTEST_CC"; then
        sed -i '31i #include <cmath>  // For log2() function' "$NETWORKTEST_CC"
        print_success "Added #include <cmath>"
    fi

    print_success "Traffic patterns code modified"
    IMPLEMENTATION_DONE=true
else
    print_success "Traffic patterns already implemented"
fi

echo ""

# Now compile if binary doesn't exist
if [ "$BINARY_EXISTS" = false ]; then
    echo "gem5 Network_test binary not found - need to compile"
    echo ""

    if [ -f "./compile_networktest.sh" ]; then
        chmod +x ./compile_networktest.sh
        print_success "Using optimized cross-machine compilation script"
        echo ""
        ./compile_networktest.sh

        if [ $? -eq 0 ]; then
            print_success "Compilation completed successfully"
            BINARY_EXISTS=true
        else
            print_error "Compilation failed - check error messages above"
            exit 1
        fi
    else
        print_error "Compilation script not found: ./compile_networktest.sh"
        exit 1
    fi
else
    print_success "gem5 binary already exists - skipping compilation"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
print_step "3" "Run Phase 4 Verification Test Matrix"
# ═══════════════════════════════════════════════════════════════════════════

echo "This will run 4 test scenarios:"
echo "  1. uniform-random @ 0.3 injection (10,000 cycles) - baseline"
echo "  2. transpose @ 0.5 injection (20,000 cycles) - moderate dynamic"
echo "  3. bit_reverse @ 0.5 injection (20,000 cycles) - high dynamic"
echo "  4. bit_reverse @ 0.7 injection (30,000 cycles) - extreme stress"
echo ""
echo "Estimated total time: 4-6 minutes"
echo ""

read -p "Run tests now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "./run_phase4_traffic_verification.sh" ]; then
        chmod +x ./run_phase4_traffic_verification.sh
        ./run_phase4_traffic_verification.sh

        if [ $? -eq 0 ]; then
            print_success "All tests completed successfully"
            TESTS_COMPLETED=true
            # Extract results directory from last run
            RESULTS_DIR=$(ls -td build_logs/phase4_traffic_verification_* 2>/dev/null | head -1)
        else
            print_error "Tests failed - check error messages above"
            exit 1
        fi
    else
        print_error "Test script not found: ./run_phase4_traffic_verification.sh"
        exit 1
    fi
else
    print_warning "Tests skipped - you can run them later with:"
    echo "  ./run_phase4_traffic_verification.sh"
    TESTS_COMPLETED=false
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
print_step "4" "Analyze Results"
# ═══════════════════════════════════════════════════════════════════════════

if [ "$TESTS_COMPLETED" = true ] && [ -n "$RESULTS_DIR" ]; then
    echo "Analyzing results from: $RESULTS_DIR"
    echo ""

    if [ -f "./analyze_traffic_results.sh" ]; then
        chmod +x ./analyze_traffic_results.sh
        ./analyze_traffic_results.sh "$RESULTS_DIR"

        if [ $? -eq 0 ]; then
            print_success "Results analysis completed"
        else
            print_warning "Analysis completed with warnings"
        fi
    else
        print_error "Analysis script not found: ./analyze_traffic_results.sh"
    fi
else
    if [ "$TESTS_COMPLETED" = false ]; then
        print_warning "No results to analyze (tests not run)"
    else
        print_error "Results directory not found"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
print_step "5" "Summary and Next Steps"
# ═══════════════════════════════════════════════════════════════════════════

echo "════════════════════════════════════════════════════════════════════════"
echo "  WORKFLOW SUMMARY"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

if [ "$IMPLEMENTATION_DONE" = true ]; then
    print_success "Traffic patterns implemented (bit_reverse, transpose, uniform-random)"
else
    print_error "Traffic patterns NOT implemented"
fi

if [ "$BINARY_EXISTS" = true ]; then
    print_success "gem5 Network_test binary compiled"
else
    print_error "gem5 Network_test binary NOT compiled"
fi

if [ "$TESTS_COMPLETED" = true ]; then
    print_success "Phase 4 verification tests completed"
    print_success "Results available in: $RESULTS_DIR"
else
    print_warning "Tests not yet run"
fi

echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "  NEXT STEPS"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

if [ "$TESTS_COMPLETED" = true ]; then
    echo "1. Review analysis report:"
    echo "   cat $RESULTS_DIR/phase4_analysis_report.txt"
    echo ""
    echo "2. Check CSV summary:"
    echo "   cat $RESULTS_DIR/phase4_verification_summary.csv"
    echo ""
    echo "3. View detailed statistics for specific test:"
    echo "   cat $RESULTS_DIR/bit_reverse_0.5/stats.txt"
    echo ""
    echo "4. Compare with baseline (Phase 3 only) to calculate improvements:"
    echo "   ./compare_phase4_baseline.sh $RESULTS_DIR <baseline_results_dir>"
    echo ""
else
    echo "1. Run verification tests:"
    echo "   ./run_phase4_traffic_verification.sh"
    echo ""
    echo "2. Analyze results:"
    echo "   ./analyze_traffic_results.sh <results_directory>"
    echo ""
fi

echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Save workflow status
STATUS_FILE="/home/siat/gem5-gpu-bak/phase4_verification_status.txt"
cat > "$STATUS_FILE" << EOF
Phase 4 Traffic Pattern Verification Status
═══════════════════════════════════════════

Last Updated: $(date)

Implementation Status:
  - Traffic patterns: $([ "$IMPLEMENTATION_DONE" = true ] && echo "✓ Implemented" || echo "✗ Not implemented")
  - gem5 binary: $([ "$BINARY_EXISTS" = true ] && echo "✓ Compiled" || echo "✗ Not compiled")

Test Status:
  - Verification tests: $([ "$TESTS_COMPLETED" = true ] && echo "✓ Completed" || echo "⏳ Pending")
  - Results location: ${RESULTS_DIR:-"N/A"}

Next Action:
$(if [ "$TESTS_COMPLETED" = true ]; then
    echo "  Review analysis report and compare with baseline"
else
    echo "  Run ./run_phase4_traffic_verification.sh"
fi)
EOF

print_success "Workflow status saved to: $STATUS_FILE"
echo ""
