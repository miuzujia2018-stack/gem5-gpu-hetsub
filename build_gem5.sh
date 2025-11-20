#!/bin/bash

# Exit on error
set -e

# Function to clean old log files, keeping only the 3 most recent ones
cleanup_old_logs() {
    echo "Cleaning up old log files..."
    
    # Find all gem5_build_*.log files, sort by modification time (newest first)
    # and keep only the 3 most recent ones
    log_files=$(find . -name "gem5_build_*.log" -type f -printf '%T@ %p\n' | sort -nr | head -3 | awk '{print $2}')
    
    # Get all log files
    all_log_files=$(find . -name "gem5_build_*.log" -type f)
    
    # Delete files that are not in the keep list
    for file in $all_log_files; do
        should_keep=false
        for keep_file in $log_files; do
            if [ "$file" = "$keep_file" ]; then
                should_keep=true
                break
            fi
        done
        
        if [ "$should_keep" = false ]; then
            echo "Removing old log file: $file"
            rm -f "$file"
        fi
    done
    
    echo "Log cleanup completed. Keeping the 3 most recent log files."
}

# Clean up old log files before starting new build
cleanup_old_logs

# Set up logging with timestamp filename
LOG_FILE="gem5_build_$(date +%Y%m%d_%H%M%S).log"
echo "Log file will be: $LOG_FILE"

# Redirect all output to both terminal and log file
exec 1> >(tee "$LOG_FILE") 2>&1

echo "=========================================="
echo "gem5-gpu Build Log - $(date)"
echo "Log file: $LOG_FILE"
echo "=========================================="

echo "Starting gem5-gpu build..."

# Enter build directory
cd /home/siat/gem5-gpu-bak/gem5/build

# Remove old build files
echo "Cleaning old build files..."
rm -rf X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/

# Enter gem5 directory
cd /home/siat/gem5-gpu-bak/gem5/

# Set CUDAHOME environment variable and add CUDA binaries to PATH
export CUDAHOME=/usr/local/cuda/cuda
export PATH=$PATH:/usr/local/cuda/cuda/bin

# Execute build command
echo "Starting compilation..."
scons build/X86_VI_hammer_GPU/gem5.opt \
    --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \
    PROTOCOL=VI_hammer \
    GPGPU_SIM=True \
    -j8

echo "Build completed!"

# Run benchmark test with 2GHz CPU clock
echo "Running benchmark test with 2GHz CPU clock"
cd /home/siat/
/home/siat/gem5-gpu-bak/gem5/build/X86_VI_hammer_GPU/gem5.opt -d /home/siat/test/ /home/siat/gem5-gpu-bak/gem5-gpu/configs/se_fusion.py --garnet-network=flexible --cpu-clock=1GHz -c /home/siat/gem5-gpu-bak/benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"

echo "=========================================="
echo "Build process completed - $(date)"
echo "Log saved to: $LOG_FILE"
echo "=========================================="
