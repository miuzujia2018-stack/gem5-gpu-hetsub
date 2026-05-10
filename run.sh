#!/bin/bash
set -e

export CUDAHOME=/usr/local/cuda/cuda
export PATH=/usr/local/cuda/cuda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

project_dir=/home/siat/gem5-gpu-bak
test=${1:-backprop}

cd /home/siat

run_test() {
    local name=$1
    local bin=$2
    local opts=$3
    local outdir=$4
    mkdir -p "$outdir"
    echo "=== Testing: $name ==="
    "$project_dir/gem5/build/X86_VI_hammer_GPU/gem5.opt" \
      -d "$outdir" \
      "$project_dir/gem5-gpu/configs/se_fusion.py" \
      --garnet-network=flexible \
      -c "$bin" -o "$opts" \
      > "${outdir}/stdout.log" 2> "${outdir}/stderr.log"
    echo "  $name: done (stats: $(wc -c < "$outdir/stats.txt") bytes)"
}

case "$test" in
    backprop)
        run_test "backprop" \
          "$project_dir/benchmarks/rodinia/backprop/gem5_fusion_backprop" \
          "16" "/tmp/test_backprop"
        ;;
    kmeans)
        run_test "kmeans" \
          "$project_dir/benchmarks/rodinia/kmeans/gem5_fusion_kmeans" \
          "-i $project_dir/kmeans_input.txt" \
          "/tmp/test_kmeans"
        ;;
    both)
        run_test "backprop" \
          "$project_dir/benchmarks/rodinia/backprop/gem5_fusion_backprop" \
          "16" "/tmp/test_backprop"
        run_test "kmeans" \
          "$project_dir/benchmarks/rodinia/kmeans/gem5_fusion_kmeans" \
          "-i $project_dir/kmeans_input.txt" \
          "/tmp/test_kmeans"
        ;;
    *)
        echo "Usage: $0 {backprop|kmeans|both}"
        exit 1
        ;;
esac
