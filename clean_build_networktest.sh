#!/bin/bash
#
# Clean Build Script for Network_test Protocol
# Purpose: Force clean build without gpgpu-sim contamination
#

set -e

PROJECT_DIR="/home/siat/gem5-gpu-bak"
GEM5_DIR="${PROJECT_DIR}/gem5"
BUILD_TARGET="X86_Network_test"

echo "=========================================="
echo "Clean Build for Network_test Protocol"
echo "=========================================="
echo ""

# Step 1: Aggressive cleanup
echo "[1/3] Cleaning build directory..."
cd "${GEM5_DIR}"

# Remove build directory entirely
if [ -d "build/${BUILD_TARGET}" ]; then
    echo "  Removing build/${BUILD_TARGET}/"
    rm -rf "build/${BUILD_TARGET}/"
fi

# Remove variables cache
if [ -f "build/variables/${BUILD_TARGET}" ]; then
    echo "  Removing build/variables/${BUILD_TARGET}"
    rm -f "build/variables/${BUILD_TARGET}"
fi

# Remove any potential gpgpu-sim symlinks in src/
if [ -L "src/gpgpu-sim" ]; then
    echo "  Removing src/gpgpu-sim symlink"
    rm -f "src/gpgpu-sim"
fi

echo "  ✓ Cleanup complete"
echo ""

# Step 2: Build with explicit parameters
echo "[2/3] Building with Network_test protocol..."
echo "  Parallel: -j8"
echo "  Protocol: Network_test"
echo "  EXTRAS: (none)"
echo ""

# Set CUDAHOME to avoid SConscript errors
export CUDAHOME=/usr/local/cuda

# Build with explicit parameters, NO EXTRAS
python `which scons` \
    build/${BUILD_TARGET}/gem5.opt \
    TARGET_ISA=x86 \
    CPU_MODELS=AtomicSimpleCPU,O3CPU,TimingSimpleCPU \
    PROTOCOL=Network_test \
    -j8

BUILD_RESULT=$?

echo ""

# Step 3: Verify
if [ $BUILD_RESULT -eq 0 ]; then
    echo "[3/3] Build successful!"
    echo "  Binary: ${GEM5_DIR}/build/${BUILD_TARGET}/gem5.opt"

    # Check if gpgpu-sim was included (should NOT be)
    if [ -d "build/${BUILD_TARGET}/gpgpu-sim" ]; then
        echo "  ⚠️  WARNING: gpgpu-sim directory exists (unexpected)"
    else
        echo "  ✓ No gpgpu-sim contamination"
    fi

    exit 0
else
    echo "[3/3] Build failed!"
    echo "  Check errors above"
    exit 1
fi
