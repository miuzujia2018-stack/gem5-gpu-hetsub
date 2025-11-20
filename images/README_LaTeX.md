# LaTeX文档编译使用说明

## 快速开始

### 步骤1: 安装LaTeX环境（首次使用）
```bash
cd /home/siat/gem5-gpu-bak/images
./install_latex.sh
```
**注意**: 安装过程需要sudo权限，会下载约500MB软件包，需要5-10分钟。

### 步骤2: 编译LaTeX文档生成PDF
```bash
cd /home/siat/gem5-gpu-bak/images
./run.sh
```
运行后会自动：
1. 检测LaTeX编译器（优先使用XeLaTeX，支持中文）
2. 编译两次生成完整的PDF文档
3. 显示生成的PDF文件路径和大小

## 文件说明

| 文件 | 说明 |
|------|------|
| `install_latex.sh` | LaTeX环境安装脚本（只需运行一次） |
| `run.sh` | PDF编译脚本（每次修改tex后运行） |
| `MVPP_MGC_PSO_Method_Complete.tex` | LaTeX源文件（20KB，159行） |
| `MVPP_MGC_PSO_Method_Complete.pdf` | 编译生成的PDF文档 |

## 编译输出示例

```
==================================================
  LaTeX文档自动编译脚本
==================================================

✓ 使用XeLaTeX编译（支持中文）
文件: MVPP_MGC_PSO_Method_Complete.tex

清理旧的临时文件...

[1/2] 第一次编译...
✓ 第一次编译完成
[2/2] 第二次编译（生成完整引用）...
✓ 第二次编译完成

==================================================
✓ 编译成功！
==================================================
生成文件: MVPP_MGC_PSO_Method_Complete.pdf
文件大小: 156K
完整路径: /home/siat/gem5-gpu-bak/images/MVPP_MGC_PSO_Method_Complete.pdf
```

## 常见问题

### Q: 运行install_latex.sh时提示权限不足
**A**:
```bash
chmod +x install_latex.sh
./install_latex.sh
# 输入sudo密码
```

### Q: run.sh提示"未找到LaTeX编译器"
**A**: 先运行安装脚本：
```bash
./install_latex.sh
```

### Q: 编译失败怎么办？
**A**: 查看详细日志：
```bash
cat MVPP_MGC_PSO_Method_Complete.log
```

### Q: 如何查看生成的PDF？
**A**: 使用以下命令之一：
```bash
evince MVPP_MGC_PSO_Method_Complete.pdf &    # Gnome PDF阅读器
xdg-open MVPP_MGC_PSO_Method_Complete.pdf &  # 默认应用
okular MVPP_MGC_PSO_Method_Complete.pdf &    # KDE PDF阅读器
```

## 修改tex文件后重新编译

1. 编辑 `MVPP_MGC_PSO_Method_Complete.tex`
2. 运行 `./run.sh` 重新生成PDF
3. 无需再次运行 `install_latex.sh`

## 卸载LaTeX环境（可选）

如果需要卸载：
```bash
sudo apt-get remove --purge texlive-*
sudo apt-get autoremove
```

## 文档内容

该LaTeX文档包含MVPP_MGC_PSO路由算法的完整方法描述：

1. **全局网络建模** - 拓扑图、5个性能指标公式
2. **数据包粒子表示** - 4维位置向量、群体组织
3. **粒子群优化算法** - 速度/位置更新、路由解码
4. **多目标适应度函数** - 6维加权和
5. **多群体协作机制** - 知识共享、粒子迁移、全局同步
6. **路由决策与实时适应** - 分层策略、拥塞响应
7. **收敛性与终止条件** - 多重终止机制

共包含20+个数学公式，符合学术论文规范。
