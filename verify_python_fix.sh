#!/bin/bash
# 快速验证修复 - 检查所有脚本是否已更新为使用 python

echo "=========================================="
echo "Python 版本修复验证脚本"
echo "=========================================="
echo ""

# 检查文件
FILES=(
    "compile_networktest.sh"
    "implement_traffic_patterns.sh"
    "quickstart_phase4_verification.sh"
)

echo "检查脚本中的 Python 调用..."
echo ""

ALL_FIXED=true

for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "✗ 文件不存在: $file"
        ALL_FIXED=false
        continue
    fi

    echo "检查: $file"

    # 检查是否还有 python3 调用 scons
    if grep -q "python3.*scons" "$file"; then
        echo "  ✗ 发现 python3 调用 scons"
        grep -n "python3.*scons" "$file"
        ALL_FIXED=false
    else
        echo "  ✓ 没有 python3 调用 scons"
    fi

    # 显示 python 调用（不包括注释）
    PYTHON_CALLS=$(grep -n "python\s" "$file" | grep -v "^#" | grep -v "python3")
    if [ -n "$PYTHON_CALLS" ]; then
        echo "  ✓ 使用 python 的行:"
        echo "$PYTHON_CALLS" | sed 's/^/    /'
    fi

    echo ""
done

echo "=========================================="
if [ "$ALL_FIXED" = true ]; then
    echo "✅ 所有脚本已正确使用 python"
    echo "=========================================="
    echo ""
    echo "可以运行以下命令测试编译:"
    echo "  ./compile_networktest.sh"
    echo ""
else
    echo "✗ 仍有脚本使用 python3"
    echo "=========================================="
    echo ""
    echo "请检查上述错误信息"
    echo ""
    exit 1
fi
