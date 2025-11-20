# 安装LaTeX并生成PDF - 操作指南

## 🚀 一键安装并编译（推荐）

在终端中运行以下命令：

```bash
cd /home/siat/gem5-gpu-bak/images
bash complete_install_and_compile.sh
```

输入sudo密码后，脚本将自动：
1. 安装LaTeX环境（约500MB）
2. 编译生成PDF文档
3. 显示生成的PDF路径

---

## 📝 分步操作（如果一键脚本失败）

### 步骤1: 安装LaTeX环境

```bash
# 复制粘贴以下完整命令到终端
sudo apt-get update && sudo apt-get install -y \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    texlive-lang-chinese \
    texlive-fonts-recommended
```

输入密码，等待5-10分钟安装完成。

### 步骤2: 验证安装

```bash
which xelatex
# 应该输出: /usr/bin/xelatex
```

### 步骤3: 编译生成PDF

```bash
cd /home/siat/gem5-gpu-bak/images
./run.sh
```

---

## 📄 查看生成的PDF

编译成功后运行：

```bash
# 方法1: 使用evince（Gnome默认）
evince MVPP_MGC_PSO_Method_Complete.pdf &

# 方法2: 使用默认应用
xdg-open MVPP_MGC_PSO_Method_Complete.pdf &

# 方法3: 使用okular（KDE）
okular MVPP_MGC_PSO_Method_Complete.pdf &
```

---

## ⚡ 快速命令（复制粘贴）

### 安装+编译一条命令搞定：

```bash
cd /home/siat/gem5-gpu-bak/images && sudo apt-get update && sudo apt-get install -y texlive-latex-base texlive-latex-extra texlive-xetex texlive-lang-chinese texlive-fonts-recommended && ./run.sh
```

---

## ❓ 常见问题

**Q: 安装需要多长时间？**
A: 首次安装约5-10分钟，取决于网络速度。

**Q: 需要多少磁盘空间？**
A: 约500MB-1GB。

**Q: 如果没有sudo权限怎么办？**
A: 使用在线Overleaf编译（见下方）。

**Q: 编译出错怎么办？**
A: 查看日志 `cat MVPP_MGC_PSO_Method_Complete.log`

---

## 🌐 替代方案：在线编译（无需安装）

如果无法安装LaTeX，可以使用Overleaf：

1. 访问 https://www.overleaf.com/
2. 注册/登录账号
3. 创建新项目（New Project → Blank Project）
4. 删除默认的main.tex
5. 点击 Upload 上传 `MVPP_MGC_PSO_Method_Complete.tex`
6. 点击 Recompile 按钮
7. 下载生成的PDF

---

## 📊 文档信息

- **LaTeX源文件**: MVPP_MGC_PSO_Method_Complete.tex (20KB)
- **生成PDF**: MVPP_MGC_PSO_Method_Complete.pdf (约150-200KB)
- **页数**: 约8-10页
- **公式数**: 20+个
- **章节数**: 7个子章节

---

## ✅ 成功标志

看到以下输出表示成功：

```
==================================================
✓ 编译成功！
==================================================
生成文件: MVPP_MGC_PSO_Method_Complete.pdf
文件大小: 156K
```
