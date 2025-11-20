#!/bin/bash

# LaTeX环境安装脚本
# 需要sudo权限，请手动运行此脚本

echo "开始安装LaTeX编译环境..."
echo "这将安装约500MB的软件包，可能需要5-10分钟"
echo ""

# 更新包列表
sudo apt-get update

# 安装基础LaTeX包
echo "正在安装基础LaTeX包..."
sudo apt-get install -y texlive-latex-base

# 安装扩展包（数学、算法等）
echo "正在安装扩展包..."
sudo apt-get install -y texlive-latex-extra

# 安装XeLaTeX（支持中文）
echo "正在安装中文支持..."
sudo apt-get install -y texlive-xetex texlive-lang-chinese

# 安装字体
echo "正在安装字体包..."
sudo apt-get install -y texlive-fonts-recommended texlive-fonts-extra

echo ""
echo "安装完成！"
echo "现在可以运行 ./run.sh 编译LaTeX文档"
