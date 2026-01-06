#!/bin/bash
# Synthetic Traffic Pattern Implementation Script
# Automatically applies bit_reverse, transpose, uniform-random traffic patterns
# Generated: December 17, 2025

set -e  # Exit on error

echo "=========================================="
echo "Synthetic Traffic Pattern Implementation"
echo "=========================================="
echo ""

# Configuration
NETWORKTEST_CC="/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc"
BACKUP_FILE="${NETWORKTEST_CC}.backup_20251217"
TEMP_FILE="${NETWORKTEST_CC}.tmp"

# Step 1: Backup original file
echo "[1/5] Creating backup of networktest.cc..."
if [ ! -f "$BACKUP_FILE" ]; then
    cp "$NETWORKTEST_CC" "$BACKUP_FILE"
    echo "✓ Backup created: $BACKUP_FILE"
else
    echo "✓ Backup already exists: $BACKUP_FILE"
fi

# Step 2: Check if modification already applied
echo ""
echo "[2/5] Checking if modification already applied..."
if grep -q "BIT REVERSE" "$NETWORKTEST_CC"; then
    echo "⚠️  Traffic patterns already implemented!"
    echo "   Skipping modification step."
    ALREADY_MODIFIED=true
else
    echo "✓ Original code detected, proceeding with modification..."
    ALREADY_MODIFIED=false
fi

# Step 3: Apply code modification
if [ "$ALREADY_MODIFIED" = false ]; then
    echo ""
    echo "[3/5] Applying traffic pattern modifications..."

    # Create modified version using sed
    cat > "$TEMP_FILE" << 'EOF_REPLACEMENT'
unsigned destination = id;
if (trafficType == 0) {
    // ====================================================================
    // Traffic Pattern 0: UNIFORM RANDOM
    // Baseline pattern for stable congestion testing
    // Each node randomly selects destination from all available nodes
    // ====================================================================
    destination = random_mt.random<unsigned>(0, numMemories - 1);

} else if (trafficType == 1) {
    // ====================================================================
    // Traffic Pattern 1: BIT REVERSE
    // Adversarial pattern creating maximum network stress
    // For N=16 (4 bits): reverse bit order of node ID
    // Example: Node 5 (0101) → Node 10 (1010)
    // ====================================================================
    int numBits = (int) log2(numMemories);  // 4 bits for 16 nodes

    // Reverse the bits of source ID to get destination ID
    unsigned dest_id = 0;
    unsigned src_id = id;
    for (int i = 0; i < numBits; i++) {
        // Extract bit i from source
        unsigned bit = (src_id >> i) & 1;
        // Place it at position (numBits-1-i) in destination
        dest_id |= (bit << (numBits - 1 - i));
    }
    destination = dest_id;

} else if (trafficType == 2) {
    // ====================================================================
    // Traffic Pattern 2: TRANSPOSE
    // Matrix transpose pattern creating diagonal hotspots
    // Node (x,y) sends to node (y,x)
    // Example: Node (1,3) → Node (3,1)
    // Creates symmetric bidirectional traffic
    // ====================================================================
    int networkDimension = (int) sqrt(numMemories);
    int my_x = id % networkDimension;
    int my_y = id / networkDimension;

    // Transpose: swap x and y coordinates
    int dest_x = my_y;
    int dest_y = my_x;

    destination = dest_y * networkDimension + dest_x;

} else {
    // ====================================================================
    // Default: UNIFORM RANDOM (fallback for invalid trafficType)
    // ====================================================================
    destination = random_mt.random<unsigned>(0, numMemories - 1);
    warn("Invalid traffic type %d, using Uniform Random\n", trafficType);
}
EOF_REPLACEMENT

    # Use Python for precise line replacement
    python << 'EOF_PYTHON'
import sys

# Read original file
with open('/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc', 'r') as f:
    lines = f.readlines()

# Read replacement block
with open('/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc.tmp', 'r') as f:
    replacement = f.read()

# Find and replace lines 177-199 (0-indexed: 176-198)
output_lines = []
i = 0
while i < len(lines):
    # Check if we're at line 177 (index 176)
    if i == 176 and 'unsigned destination = id;' in lines[i]:
        # Found the start, write replacement block
        output_lines.append(replacement)
        # Skip original lines 177-199 (indices 176-198, total 23 lines)
        i += 23
    else:
        output_lines.append(lines[i])
        i += 1

# Write modified file
with open('/home/siat/gem5-gpu-bak/gem5/src/cpu/testers/networktest/networktest.cc', 'w') as f:
    f.writelines(output_lines)

print("✓ Code modification applied successfully")
EOF_PYTHON

    # Add include directive if not present
    if ! grep -q "#include <cmath>" "$NETWORKTEST_CC"; then
        sed -i '31i #include <cmath>  // For log2() function in bit-reverse pattern' "$NETWORKTEST_CC"
        echo "✓ Added #include <cmath>"
    fi

    rm -f "$TEMP_FILE"
    echo "✓ Traffic patterns implemented successfully"
else
    echo "✓ Skipping modification (already applied)"
fi

# Step 4: Verify modification
echo ""
echo "[4/5] Verifying modification..."
if grep -q "BIT REVERSE" "$NETWORKTEST_CC" && grep -q "TRANSPOSE" "$NETWORKTEST_CC"; then
    echo "✓ Verification passed: Traffic patterns detected"
else
    echo "✗ Verification failed: Traffic patterns not found"
    echo "   Please check $NETWORKTEST_CC manually"
    exit 1
fi

# Step 5: Recompile gem5
echo ""
echo "[5/5] Recompiling gem5 with Network_test protocol..."
echo "   This will take 3-5 minutes on build machine..."
echo ""

cd /home/siat/gem5-gpu-bak/gem5/
export CUDAHOME=/usr/local/cuda  # 避免 gpgpu-sim/SConscript 报错
python `which scons` build/X86_Network_test/gem5.opt \
    --default=X86 \
    PROTOCOL=Network_test \
    -j8 2>&1 | tee /tmp/networktest_build.log

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Implementation Complete!"
    echo "=========================================="
    echo ""
    echo "Traffic Patterns Implemented:"
    echo "  - Type 0: uniform-random (baseline)"
    echo "  - Type 1: bit_reverse (adversarial)"
    echo "  - Type 2: transpose (symmetric)"
    echo ""
    echo "Next Steps:"
    echo "  1. Run quick verification test:"
    echo "     ./build/X86_Network_test/gem5.opt \\"
    echo "         configs/example/ruby_network_test.py \\"
    echo "         --num-cpus=16 --num-dirs=2 \\"
    echo "         --network=garnet --topology=Mesh --mesh-rows=4 \\"
    echo "         --synthetic=1 --injectionrate=0.1 --sim-cycles=1000"
    echo ""
    echo "  2. Run full Phase 4 verification:"
    echo "     See: reports/20251217_traffic_patterns_implementation_guide.md"
    echo "     Section 8.2 for complete test matrix"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "✗ Compilation Failed"
    echo "=========================================="
    echo ""
    echo "Check build log: /tmp/networktest_build.log"
    echo "Restore backup: cp $BACKUP_FILE $NETWORKTEST_CC"
    exit 1
fi
