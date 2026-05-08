#!/bin/bash
set -e

export CUDAHOME=/usr/local/cuda/cuda
export PATH=/usr/local/cuda/cuda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

project_dir=/home/siat/gem5-gpu-bak

cd /home/siat
"$project_dir/gem5/build/X86_VI_hammer_GPU/gem5.opt" \
  "$project_dir/gem5-gpu/configs/se_fusion.py" \
  -c "$project_dir/benchmarks/rodinia/backprop/gem5_fusion_backprop" \
  -o "16" \
  "$@"
