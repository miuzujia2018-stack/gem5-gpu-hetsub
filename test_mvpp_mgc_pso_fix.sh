#!/bin/bash

# 测试MVPP_MGC_PSO路由算法修复的脚本
echo "=== 测试MVPP_MGC_PSO路由算法修复 ==="

# 设置环境变量
export GEM5_GPU_HOME=/home/siat/gem5-gpu-bak
export GEM5_HOME=$GEM5_GPU_HOME/gem5
export BENCHMARK_HOME=$GEM5_GPU_HOME/benchmarks

# 进入gem5目录
cd $GEM5_HOME

# 清理之前的构建
echo "清理之前的构建..."
rm -rf build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/

# 重新编译Router.cc
echo "重新编译Router.cc..."
if scons build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/Router.o --no-cache -j1; then
    echo "Router.cc编译成功"
else
    echo "Router.cc编译失败"
    exit 1
fi

# 编译其他相关文件
echo "编译其他相关文件..."
if scons build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.o --no-cache -j1; then
    echo "GarnetNetwork.cc编译成功"
else
    echo "GarnetNetwork.cc编译失败"
    exit 1
fi

# 编译完整的gem5
echo "编译完整的gem5..."
if scons build/X86_VI_hammer_GPU/gem5.opt -j4; then
    echo "gem5编译成功"
else
    echo "gem5编译失败"
    exit 1
fi

# 运行简单的测试
echo "运行简单测试..."
TEST_OUTPUT_DIR="/home/siat/test_mvpp_fix"
mkdir -p $TEST_OUTPUT_DIR

# 使用简单的测试程序
$GEM5_HOME/build/X86_VI_hammer_GPU/gem5.opt \
    -d $TEST_OUTPUT_DIR \
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
    2>&1 | tee $TEST_OUTPUT_DIR/test.log

# 检查结果
if [ $? -eq 0 ]; then
    echo "=== 测试成功！MVPP_MGC_PSO路由算法修复有效 ==="
    echo "测试输出目录: $TEST_OUTPUT_DIR"
    echo "日志文件: $TEST_OUTPUT_DIR/test.log"
else
    echo "=== 测试失败！需要进一步调试 ==="
    echo "请检查日志文件: $TEST_OUTPUT_DIR/test.log"
    exit 1
fi

echo "=== 测试完成 ===" 