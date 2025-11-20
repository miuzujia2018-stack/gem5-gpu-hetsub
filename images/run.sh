#!/bin/bash

# LaTeX文档自动编译脚本
# 用法: ./run.sh

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 设置文件名
TEX_FILE="MVPP_MGC_PSO_Method_Complete.tex"
PDF_FILE="MVPP_MGC_PSO_Method_Complete.pdf"

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  LaTeX文档自动编译脚本${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""

# 检查xelatex是否安装
if command -v xelatex &> /dev/null; then
    LATEX_CMD="xelatex"
    echo -e "${GREEN}✓ 使用XeLaTeX编译（支持中文）${NC}"
elif command -v pdflatex &> /dev/null; then
    LATEX_CMD="pdflatex"
    echo -e "${YELLOW}! 使用PDFLaTeX编译（中文支持可能有限）${NC}"
else
    echo -e "${RED}✗ 错误: 未找到LaTeX编译器${NC}"
    echo -e "${YELLOW}请先运行: chmod +x install_latex.sh && ./install_latex.sh${NC}"
    exit 1
fi

# 检查tex文件是否存在
if [ ! -f "$TEX_FILE" ]; then
    echo -e "${RED}✗ 错误: 找不到文件 $TEX_FILE${NC}"
    exit 1
fi

echo -e "${YELLOW}文件: $TEX_FILE${NC}"
echo ""

# 清理之前的临时文件
echo "清理旧的临时文件..."
rm -f *.aux *.log *.out *.toc *.lof *.lot 2>/dev/null
echo ""

# 第一次编译
echo -e "${YELLOW}[1/2] 第一次编译...${NC}"
$LATEX_CMD -interaction=nonstopmode "$TEX_FILE" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 编译失败！查看错误日志:${NC}"
    $LATEX_CMD -interaction=nonstopmode "$TEX_FILE" | tail -50
    exit 1
fi
echo -e "${GREEN}✓ 第一次编译完成${NC}"

# 第二次编译（生成完整引用和目录）
echo -e "${YELLOW}[2/2] 第二次编译（生成完整引用）...${NC}"
$LATEX_CMD -interaction=nonstopmode "$TEX_FILE" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 第二次编译失败！${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 第二次编译完成${NC}"
echo ""

# 检查PDF是否生成
if [ -f "$PDF_FILE" ]; then
    FILE_SIZE=$(ls -lh "$PDF_FILE" | awk '{print $5}')
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${GREEN}✓ 编译成功！${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo -e "生成文件: ${GREEN}$PDF_FILE${NC}"
    echo -e "文件大小: ${GREEN}$FILE_SIZE${NC}"
    echo -e "完整路径: ${GREEN}$(pwd)/$PDF_FILE${NC}"
    echo ""

    # 清理临时文件（可选）
    echo -e "${YELLOW}是否清理临时文件? (y/n)${NC}"
    read -t 5 -n 1 cleanup
    echo ""
    if [ "$cleanup" = "y" ] || [ "$cleanup" = "Y" ]; then
        rm -f *.aux *.log *.out *.toc *.lof *.lot
        echo -e "${GREEN}✓ 临时文件已清理${NC}"
    else
        echo -e "${YELLOW}临时文件保留（.aux, .log, .out）${NC}"
    fi

    echo ""
    echo -e "${GREEN}使用以下命令查看PDF:${NC}"
    echo -e "  evince $PDF_FILE &       ${YELLOW}# Linux PDF阅读器${NC}"
    echo -e "  xdg-open $PDF_FILE &     ${YELLOW}# 默认应用打开${NC}"
    echo -e "  okular $PDF_FILE &       ${YELLOW}# KDE PDF阅读器${NC}"
else
    echo -e "${RED}✗ 错误: PDF文件未生成${NC}"
    echo -e "${YELLOW}查看详细日志: less ${TEX_FILE%.tex}.log${NC}"
    exit 1
fi
