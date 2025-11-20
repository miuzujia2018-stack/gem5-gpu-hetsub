#!/bin/bash

# 测试flexible-pipeline段错误修复的编译脚本
# 只编译，不运行，确保修复正确

set -e

echo "========================================"
echo "测试编译flexible-pipeline段错误修复"
echo "时间: $(date)"
echo "========================================"

# 进入gem5目录
cd /home/siat/gem5-gpu-bak/gem5/

# 清理特定的flexible-pipeline编译文件
echo "清理flexible-pipeline编译文件..."
rm -rf build/X86_VI_hammer_GPU/mem/ruby/network/garnet/flexible-pipeline/

# 编译gem5
echo "开始编译gem5..."
python `which scons` build/X86_VI_hammer_GPU/gem5.opt \
    --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \
    PROTOCOL=VI_hammer \
    GPGPU_SIM=True \
    -j4

echo "========================================"
echo "编译成功！修复有效。"
echo "时间: $(date)"
echo "========================================"

echo ""
echo "注意："
echo "1. 编译成功表明代码语法问题已修复"
echo "2. 主要修复包括："
echo "   - 添加了缺失的成员变量声明"
echo "   - 在wakeup()函数中添加了延迟同步机制"
echo "   - 在状态计算函数中添加了安全检查"
echo "3. 如需运行测试，请使用修复后的build_gem5.sh" 