#!/bin/bash
# Phase 4 综合流量验证 - 完整工作流
# 这个脚本会自动执行所有缺失的步骤

set -e

echo "════════════════════════════════════════════════════════════════"
echo "  Phase 4 综合流量验证 - 完整执行流程"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  重要说明:"
echo "   您之前运行的 ./build_and_test_all.sh 是用于真实负载测试"
echo "   这个脚本是用于综合流量测试（Phase 4 验证的核心）"
echo ""
echo "两个独立的测试系统:"
echo "  1. 真实负载系统: VI_hammer_GPU 协议（backprop, kmeans）"
echo "  2. 综合流量系统: Network_test 协议（bit_reverse, transpose）"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# 步骤 1: 检查当前状态
echo "步骤 1/4: 检查当前状态"
echo "────────────────────────────────────────────────────────────────"

VI_HAMMER_BIN="/home/siat/gem5-gpu-bak/gem5/build/X86_VI_hammer_GPU/gem5.opt"
NETWORK_TEST_BIN="/home/siat/gem5-gpu-bak/gem5/build/X86_Network_test/gem5.opt"

if [ -f "$VI_HAMMER_BIN" ]; then
    echo "✓ VI_hammer_GPU 已编译（真实负载系统）"
    ls -lh "$VI_HAMMER_BIN" | awk '{print "  大小:", $5, "修改时间:", $6, $7, $8}'
else
    echo "✗ VI_hammer_GPU 未编译"
fi

if [ -f "$NETWORK_TEST_BIN" ]; then
    echo "✓ Network_test 已编译（综合流量系统）"
    ls -lh "$NETWORK_TEST_BIN" | awk '{print "  大小:", $5, "修改时间:", $6, $7, $8}'
    NEED_COMPILE=false
else
    echo "✗ Network_test 未编译 ⚠️ 需要编译"
    NEED_COMPILE=true
fi

echo ""

# 步骤 2: 编译 Network_test（如果需要）
if [ "$NEED_COMPILE" = true ]; then
    echo "步骤 2/4: 编译 Network_test 协议"
    echo "────────────────────────────────────────────────────────────────"
    echo "预计时间: 3-5 分钟（远程 -j64 编译）"
    echo ""

    if [ -f "./compile_networktest.sh" ]; then
        ./compile_networktest.sh

        if [ $? -eq 0 ]; then
            echo ""
            echo "✓ Network_test 编译成功"
        else
            echo ""
            echo "✗ Network_test 编译失败"
            echo "请检查日志: build_logs/networktest_build_*.log"
            exit 1
        fi
    else
        echo "✗ 编译脚本不存在: ./compile_networktest.sh"
        exit 1
    fi
else
    echo "步骤 2/4: 编译 Network_test 协议"
    echo "────────────────────────────────────────────────────────────────"
    echo "✓ 已跳过（二进制文件已存在）"
fi

echo ""

# 步骤 3: 运行综合流量测试
echo "步骤 3/4: 运行 Phase 4 综合流量验证测试"
echo "────────────────────────────────────────────────────────────────"
echo "测试场景:"
echo "  1. uniform-random @ 0.3 (稳定基线)"
echo "  2. transpose @ 0.5 (中等动态)"
echo "  3. bit_reverse @ 0.5 (高动态)"
echo "  4. bit_reverse @ 0.7 (极端压力)"
echo ""
echo "预计时间: 4-6 分钟"
echo ""

read -p "开始运行测试? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "./run_phase4_traffic_verification.sh" ]; then
        ./run_phase4_traffic_verification.sh

        if [ $? -eq 0 ]; then
            echo ""
            echo "✓ 所有测试完成"
            RESULTS_DIR=$(ls -td build_logs/phase4_traffic_verification_* 2>/dev/null | head -1)
            TESTS_COMPLETED=true
        else
            echo ""
            echo "✗ 测试失败"
            exit 1
        fi
    else
        echo "✗ 测试脚本不存在: ./run_phase4_traffic_verification.sh"
        exit 1
    fi
else
    echo "测试已跳过"
    echo "稍后可以手动运行: ./run_phase4_traffic_verification.sh"
    TESTS_COMPLETED=false
fi

echo ""

# 步骤 4: 分析结果
if [ "$TESTS_COMPLETED" = true ] && [ -n "$RESULTS_DIR" ]; then
    echo "步骤 4/4: 分析测试结果"
    echo "────────────────────────────────────────────────────────────────"

    if [ -f "./analyze_traffic_results.sh" ]; then
        ./analyze_traffic_results.sh "$RESULTS_DIR"

        if [ $? -eq 0 ]; then
            echo ""
            echo "✓ 结果分析完成"
        fi
    else
        echo "✗ 分析脚本不存在: ./analyze_traffic_results.sh"
    fi
else
    echo "步骤 4/4: 分析测试结果"
    echo "────────────────────────────────────────────────────────────────"
    echo "已跳过（测试未运行）"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  工作流程完成"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ "$TESTS_COMPLETED" = true ]; then
    echo "✅ Phase 4 综合流量验证已完成"
    echo ""
    echo "查看结果:"
    echo "  - CSV 汇总: $RESULTS_DIR/phase4_verification_summary.csv"
    echo "  - 详细报告: $RESULTS_DIR/phase4_analysis_report.txt"
    echo ""
    echo "查看详细统计:"
    echo "  cat $RESULTS_DIR/uniform_0.3/stats.txt"
    echo "  cat $RESULTS_DIR/bit_reverse_0.5/stats.txt"
    echo ""
else
    echo "⏳ 还需手动执行测试"
    echo ""
    echo "运行测试:"
    echo "  ./run_phase4_traffic_verification.sh"
    echo ""
    echo "分析结果:"
    echo "  ./analyze_traffic_results.sh <结果目录>"
    echo ""
fi

echo "════════════════════════════════════════════════════════════════"
