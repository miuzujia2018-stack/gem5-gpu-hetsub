#!/bin/bash

# 一键安装并编译 - 请在终端中手动运行此文件
# 用法: bash complete_install_and_compile.sh

set -e  # 遇到错误立即退出

echo "=================================================="
echo "  MVPP_MGC_PSO LaTeX文档一键安装编译脚本"
echo "=================================================="
echo ""

# 检查是否有sudo权限
if ! sudo -n true 2>/dev/null; then
    echo "此脚本需要sudo权限，请输入密码："
fi

echo "步骤 1/3: 更新软件包列表..."
sudo apt-get update -qq

echo "步骤 2/3: 安装LaTeX环境（约500MB，需要5-10分钟）..."
echo "正在安装 texlive-latex-base..."
sudo apt-get install -y texlive-latex-base -qq

echo "正在安装 texlive-latex-extra..."
sudo apt-get install -y texlive-latex-extra -qq

echo "正在安装中文支持包..."
sudo apt-get install -y texlive-xetex texlive-lang-chinese -qq

echo "正在安装字体包..."
sudo apt-get install -y texlive-fonts-recommended -qq

echo ""
echo "✓ LaTeX环境安装完成！"
echo ""

# 检查安装是否成功
if command -v xelatex &> /dev/null; then
    echo "✓ XeLaTeX 已安装: $(which xelatex)"
elif command -v pdflatex &> /dev/null; then
    echo "✓ PDFLaTeX 已安装: $(which pdflatex)"
else
    echo "✗ 错误: LaTeX编译器未成功安装"
    exit 1
fi

echo ""
echo "步骤 3/3: 编译LaTeX文档生成PDF..."
echo ""

# 执行编译脚本
./run.sh

echo ""
echo "=================================================="
echo "  ✓ 全部完成！"
echo "=================================================="
