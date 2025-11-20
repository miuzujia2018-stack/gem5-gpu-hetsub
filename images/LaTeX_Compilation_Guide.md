# LaTeX文档编译说明

## 文档信息
- **文件名**: `MVPP_MGC_PSO_Method_Complete.tex`
- **文件大小**: 20 KB
- **总行数**: 159行
- **位置**: `/home/siat/gem5-gpu-bak/images/`

## 文档内容结构
该LaTeX文档包含MVPP_MGC_PSO路由算法的完整方法描述，包括：

1. **全局网络建模** - 5个核心性能指标公式
2. **数据包粒子表示与群体组织** - PSO粒子结构和群体聚类
3. **粒子群优化算法** - 速度更新、位置更新、路由解码
4. **多目标适应度函数** - 6维目标加权和
5. **多群体协作机制** - 知识共享、粒子迁移、全局同步
6. **路由决策与实时适应** - 分层路由策略、拥塞响应、相位转换检测
7. **收敛性与终止条件** - 多重终止机制

共包含 **20+个数学公式**，使用标准LaTeX数学环境。

## 在本机编译（需要安装LaTeX）

### 方法1: 安装完整TeX Live发行版
```bash
sudo apt-get update
sudo apt-get install texlive-full
```

### 方法2: 安装精简版（推荐，更快）
```bash
sudo apt-get install texlive-latex-base texlive-latex-extra
sudo apt-get install texlive-xetex texlive-lang-chinese
```

### 编译命令
```bash
cd /home/siat/gem5-gpu-bak/images/

# 使用XeLaTeX（支持中文，推荐）
xelatex MVPP_MGC_PSO_Method_Complete.tex
xelatex MVPP_MGC_PSO_Method_Complete.tex  # 运行两次生成完整引用

# 或使用PDFLaTeX
pdflatex MVPP_MGC_PSO_Method_Complete.tex
pdflatex MVPP_MGC_PSO_Method_Complete.tex
```

## 在其他机器编译

### Windows系统
1. 下载并安装 MiKTeX 或 TeX Live
2. 使用 TeXworks、TeXstudio 或 Overleaf 打开 `.tex` 文件
3. 点击"编译"按钮

### Linux/Mac系统
```bash
# 复制文件到有LaTeX环境的机器
scp MVPP_MGC_PSO_Method_Complete.tex user@remote_host:/path/

# SSH到远程机器并编译
ssh user@remote_host
cd /path/
xelatex MVPP_MGC_PSO_Method_Complete.tex
```

### 在线编译（Overleaf）
1. 访问 https://www.overleaf.com/
2. 创建新项目
3. 上传 `MVPP_MGC_PSO_Method_Complete.tex`
4. 点击"Recompile"

## 生成的输出文件
成功编译后将生成：
- `MVPP_MGC_PSO_Method_Complete.pdf` - 最终PDF文档
- `MVPP_MGC_PSO_Method_Complete.aux` - 辅助文件
- `MVPP_MGC_PSO_Method_Complete.log` - 编译日志
- `MVPP_MGC_PSO_Method_Complete.out` - 超链接信息

## 常见问题

### Q: 编译时出现 "! LaTeX Error: File `ctex.sty' not found"
**A**: 安装中文支持包
```bash
sudo apt-get install texlive-lang-chinese
```

### Q: 公式显示不正确
**A**: 确保安装了数学包
```bash
sudo apt-get install texlive-latex-extra texlive-science
```

### Q: 编译速度很慢
**A**: 第一次编译较慢（生成字体缓存），后续编译会加快

## 文档预览（前30行）
文档使用标准学术论文格式，包含：
- 中文支持（ctex包）
- 数学公式（amsmath, amssymb）
- 算法伪代码（algorithm, algorithmic）
- 超链接（hyperref）
- 页面设置（geometry，2.5cm边距）

## 验证文档完整性
```bash
# 检查文件大小
ls -lh MVPP_MGC_PSO_Method_Complete.tex

# 统计行数
wc -l MVPP_MGC_PSO_Method_Complete.tex

# 检查公式数量
grep -c "\\begin{equation}" MVPP_MGC_PSO_Method_Complete.tex
```

## 建议
由于当前系统未安装LaTeX，建议：
1. **复制文件到192.168.197.130**（如果该机器有LaTeX）
2. **使用Overleaf在线编译**（最简单，无需安装）
3. **在本地Windows机器编译**（如果有MiKTeX）
