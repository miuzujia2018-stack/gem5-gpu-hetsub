#!/bin/bash

# 调试段错误的详细脚本
echo "=== 调试MVPP_MGC_PSO段错误 ==="

# 设置环境变量
export GEM5_GPU_HOME=/home/siat/gem5-gpu-bak
export GEM5_HOME=$GEM5_GPU_HOME/gem5
export BENCHMARK_HOME=$GEM5_GPU_HOME/benchmarks

# 进入gem5目录
cd $GEM5_HOME

# 启用调试编译
echo "启用调试编译..."
export CXXFLAGS="-g -O0 -DDEBUG"
export CFLAGS="-g -O0 -DDEBUG"

# 清理并重新编译
echo "清理并重新编译..."
rm -rf build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/

# 编译Router.cc with debug symbols
echo "编译Router.cc with debug symbols..."
if scons build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/Router.o --no-cache -j1; then
    echo "Router.cc编译成功"
else
    echo "Router.cc编译失败"
    exit 1
fi

# 编译完整的gem5 with debug symbols
echo "编译完整的gem5 with debug symbols..."
if scons build/X86_VI_hammer_GPU/gem5.opt -j4; then
    echo "gem5编译成功"
else
    echo "gem5编译失败"
    exit 1
fi

# 创建调试输出目录
DEBUG_OUTPUT_DIR="/home/siat/debug_mvpp_segfault"
mkdir -p $DEBUG_OUTPUT_DIR

echo "运行调试测试..."
echo "使用gdb调试段错误..."

# 使用gdb运行并捕获段错误
gdb -batch -ex "run" -ex "bt" -ex "info registers" -ex "quit" \
    --args $GEM5_HOME/build/X86_VI_hammer_GPU/gem5.opt \
    -d $DEBUG_OUTPUT_DIR \
    $GEM5_GPU_HOME/gem5-gpu/configs/se_fusion.py \
    --garnet-network=flexible \
    --num-cpus=2 \
    --num-dirs=1 \
    --num-l2caches=4 \
    -c $BENCHMARK_HOME/rodinia/backprop/gem5_fusion_backprop \
    -o "4" \
    --ruby-clock=1GHz \
    --sys-clock=1GHz \
    --cpu-clock=1GHz \
    --maxinsts=1000 \
    2>&1 | tee $DEBUG_OUTPUT_DIR/gdb_debug.log

echo "调试完成，检查日志文件: $DEBUG_OUTPUT_DIR/gdb_debug.log"

# 分析结果
echo "=== 分析调试结果 ==="
if grep -q "Program received signal SIGSEGV" $DEBUG_OUTPUT_DIR/gdb_debug.log; then
    echo "发现段错误！"
    echo "错误堆栈："
    grep -A 20 "Program received signal SIGSEGV" $DEBUG_OUTPUT_DIR/gdb_debug.log
else
    echo "未发现段错误，程序可能正常运行"
fi

echo "=== 调试完成 ===" 