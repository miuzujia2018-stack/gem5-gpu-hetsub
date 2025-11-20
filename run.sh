#!/bin/bash


cp -f /home/siat/Downloads/VI_hammer.py /home/siat/gem5-gpu-bak/gem5-gpu/configs/gpu_protocol/VI_hammer.py

cp -f /home/siat/Downloads/VI_hammer_fusion.py /home/siat/gem5-gpu-bak/gem5-gpu/configs/gpu_protocol/VI_hammer_fusion.py

cp -f /home/siat/Downloads/se_fusion.py /home/siat/gem5-gpu-bak/gem5-gpu/configs/se_fusion.py

cp -f /home/siat/Downloads/Ruby.py /home/siat/gem5-gpu-bak/gem5/configs/ruby/Ruby.py

cp -f /home/siat/Downloads/Mesh4x4_CPU_GPU.py /home/siat/gem5-gpu-bak/gem5/configs/topologies/Mesh4x4_CPU_GPU.py

current_dir=$(pwd)
cd /home/siat/
/home/siat/gem5-gpu-bak/gem5/build/X86_VI_hammer_GPU/gem5.opt /home/siat/gem5-gpu-bak/gem5-gpu/configs/se_fusion.py -c /home/siat/gem5-gpu-bak/benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"
cd "$current_dir"
