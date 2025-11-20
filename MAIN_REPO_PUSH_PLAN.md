# gem5-gpu-bak 主仓库推送方案

## 📋 方案概述

本方案采用 **Git Submodules** 架构，将大型代码仓库作为子模块管理，主仓库只包含配置文件、脚本和文档。

### 设计理念

✅ **优势**：
- 避免重复推送已有代码（gem5, gem5-gpu等）
- 大幅减少主仓库大小（从4GB+ 降至 <50MB）
- 保持项目结构清晰
- 便于独立更新各个组件
- 符合Git最佳实践

❌ **排除内容**：
- 大型日志文件（537MB gem5_build.log）
- 构建产物和临时文件
- 可重新生成的CSV结果文件
- 备份文件

## 🏗️ 仓库架构

```
┌─────────────────────────────────────────────────────────┐
│  gem5-gpu-bak (主仓库)                                   │
│  https://gitee.com/miuzujia/gem5-gpu-bak                │
└─────────────────────────────────────────────────────────┘
        │
        ├─ gem5/          → Submodule → gitee.com/miuzujia/gem5
        ├─ gem5-gpu/      → Submodule → gitee.com/miuzujia/gem5-gpu
        ├─ gpgpu-sim/     → Submodule → gitee.com/miuzujia/gpgpu-sim
        ├─ Graphite/      → Submodule → gitee.com/miuzujia/graphite
        ├─ benchmarks/    → Submodule → gitee.com/miuzujia/benchmarks
        │
        ├─ *.sh                    ✅ 所有Shell脚本
        ├─ *.md                    ✅ 所有文档
        ├─ *.py                    ✅ Python工具
        ├─ images/                 ✅ 文档图片
        ├─ manuscript/             ✅ 论文手稿
        ├─ reports/                ✅ 小型报告
        └─ mvpp_mgc_pso_path_planning.cpp  ✅ 参考代码
```

## 📦 主仓库包含的文件

### 1. 构建和测试脚本 (~20个)
```bash
build_gem5.sh
build_and_test_all.sh
run_tests.sh
sync_and_build.sh
compare_experiments.sh
debug_*.sh
setup_*.sh
```

### 2. 文档文件 (~15个)
```bash
CLAUDE.md                      # 项目开发指南
REMOTE_BUILD_README.md         # 远程构建文档
GIT_PUSH_README.md             # Git推送文档
COMPREHENSIVE_CSV_GUIDE.md     # CSV系统文档
STATS_SYSTEM_ANALYSIS.md       # 统计系统分析
GIT_PUSH_QUICK_REFERENCE.txt   # 快速参考
```

### 3. Python分析工具 (~8个)
```bash
generate_comprehensive_csv.py
generate_utilization_csv.py
generate_router_utilization.py
plot_load_balancing_analysis.py
MVPP_MGC_PSO_Implementation_Diagram.py
cleanup_comments.py
```

### 4. 配置和输入文件
```bash
kmeans_input.txt
kmean_input.txt
.gitignore
.gitmodules
```

### 5. 小型报告和图表
```bash
reports/                       # 报告目录
images/                        # 图片资源
manuscript/                    # 论文手稿
MVPP_MGC_PSO_Evaluation_Metrics_Report.pdf
MVPP_MGC_PSO_Implementation_ASCII.txt
```

### 6. 参考代码
```bash
mvpp_mgc_pso_path_planning.cpp  # 路径规划算法参考实现
```

## 🚫 排除的文件（.gitignore）

### 大型文件
- `gem5_build.log` (537MB) - 构建日志
- `build_logs/` (19MB) - 测试日志目录
- `m5out/` - 模拟输出
- `load_balance_results/` - 可重新生成

### 子模块目录（单独管理）
- `gem5/` (3.2GB)
- `gem5-gpu/` (30MB)
- `gpgpu-sim/` (18MB)
- `Graphite/` (175MB)
- `benchmarks/` (79MB)

### 临时和备份文件
- `*.log` - 所有日志
- `*.bak`, `*.backup` - 备份文件
- `*.swp`, `*~` - 编辑器临时文件
- `.vscode/`, `.idea/` - IDE配置

### 可重新生成的文件
- `comprehensive_*.csv` - 综合CSV（可重新生成）
- `stats_*.csv` - 统计CSV
- `results_*.csv` - 结果CSV

## 🚀 使用步骤

### 步骤1：检查当前将推送的文件

```bash
# 查看将被包含的文件
git add -A --dry-run

# 查看文件总数
git status -s
```

### 步骤2：运行初始化脚本

```bash
./init_main_repo.sh
```

脚本会自动：
1. ✅ 初始化Git仓库
2. ✅ 配置用户信息
3. ✅ 检查.gitignore
4. ✅ 预览要推送的文件
5. ✅ 添加并提交文件
6. ✅ 创建.gitmodules配置
7. ✅ 推送到Gitee

### 步骤3：在Gitee上创建仓库（如果还没有）

访问：https://gitee.com/new
- 仓库名称：`gem5-gpu-bak`
- 可见性：公开或私有
- 不要初始化README

### 步骤4：验证推送

访问：https://gitee.com/miuzujia/gem5-gpu-bak

应该看到：
- 所有脚本文件 (*.sh)
- 所有文档文件 (*.md)
- Python工具
- .gitmodules配置
- 不包含大型子目录

## 📥 其他人如何使用

### 完整克隆（包含子模块）

```bash
# 方法1：一步克隆（推荐）
git clone --recursive https://gitee.com/miuzujia/gem5-gpu-bak
cd gem5-gpu-bak

# 此时所有子模块都已克隆完成
```

### 分步克隆

```bash
# 方法2：分步克隆
git clone https://gitee.com/miuzujia/gem5-gpu-bak
cd gem5-gpu-bak

# 初始化子模块
git submodule init

# 更新子模块（克隆子仓库）
git submodule update
```

### 更新项目

```bash
# 更新主仓库
git pull

# 更新所有子模块
git submodule update --remote
```

## 📊 预期仓库大小对比

| 组件 | 不使用Submodules | 使用Submodules |
|------|-----------------|----------------|
| gem5 | 3.2GB | 0 (引用) |
| gem5-gpu | 30MB | 0 (引用) |
| gpgpu-sim | 18MB | 0 (引用) |
| Graphite | 175MB | 0 (引用) |
| benchmarks | 79MB | 0 (引用) |
| 日志文件 | 537MB+ | 0 (排除) |
| **主仓库** | **~4.1GB** | **~15-30MB** ✅ |

**节省空间：99%+**

## 🔄 日常工作流程

### 修改脚本/文档后推送

```bash
# 在主仓库修改文件后
git add build_gem5.sh CLAUDE.md
git commit -m "Update build script and documentation"
git push
```

### 修改子模块代码后推送

```bash
# 在子模块目录工作
cd gem5/src/mem/ruby/network/garnet/flexible-pipeline

# 修改代码...

# 提交到子模块
git add Router.cc
git commit -m "Update MVPP_MGC_PSO routing algorithm"
git push

# 返回主仓库
cd /home/siat/gem5-gpu-bak

# 更新子模块引用
git add gem5
git commit -m "Update gem5 submodule reference"
git push
```

### 使用现有的推送脚本

```bash
# 推送所有子模块（使用已有脚本）
./push_to_gitee.sh

# 这会推送：gem5, gem5-gpu, gpgpu-sim, Graphite, benchmarks
```

## ⚠️ 重要提示

### 1. Submodule vs Direct Files

**Submodule（子模块）**：
- ✅ 引用已推送的仓库
- ✅ 独立版本控制
- ✅ 减少主仓库大小
- ✅ 便于协作开发

**Direct Files（直接文件）**：
- ❌ 会复制所有文件到主仓库
- ❌ 主仓库变得巨大
- ❌ 难以管理

### 2. 首次推送前检查

```bash
# 确保不会推送大文件
git add -A --dry-run | grep -E "(gem5|build.log|\.csv)"

# 如果看到子模块目录，说明.gitignore没生效
```

### 3. .gitignore优先级

.gitignore文件必须在 `git init` 之后、`git add` 之前创建，否则可能无效。

### 4. 已经tracked的文件

如果某些文件已被Git跟踪，需要先取消跟踪：

```bash
# 取消跟踪但保留文件
git rm --cached -r gem5/
git rm --cached gem5_build.log
git rm --cached -r build_logs/

# 然后提交
git commit -m "Remove large files from tracking"
```

## 🛠️ 故障排除

### 问题1：推送失败 - 仓库不存在

**错误**：
```
fatal: repository 'https://gitee.com/miuzujia/gem5-gpu-bak' not found
```

**解决**：
1. 访问 https://gitee.com/new
2. 创建名为 `gem5-gpu-bak` 的仓库
3. 不要勾选"初始化仓库"
4. 重新运行 `./init_main_repo.sh`

### 问题2：推送了不该推送的大文件

**解决**：
```bash
# 从Git历史中删除大文件
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch gem5_build.log" \
  --prune-empty --tag-name-filter cat -- --all

# 强制推送
git push origin master --force
```

### 问题3：子模块没有显示

**解决**：
```bash
# 初始化子模块
git submodule init
git submodule update

# 或重新克隆
git clone --recursive https://gitee.com/miuzujia/gem5-gpu-bak
```

## 📚 相关文档

- [Git Submodules 官方文档](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [.gitignore 模式](https://git-scm.com/docs/gitignore)
- [push_to_gitee.sh](push_to_gitee.sh) - 子模块推送脚本
- [GIT_PUSH_README.md](GIT_PUSH_README.md) - Git推送详细文档

## 🎯 总结

这个方案通过以下方式优化了推送策略：

1. **使用Submodules** - 避免重复推送大型代码库
2. **精确的.gitignore** - 排除日志、临时文件、构建产物
3. **只推送必要文件** - 脚本、文档、配置、小型报告
4. **自动化脚本** - `init_main_repo.sh` 一键初始化

**结果**：主仓库从 4.1GB 减少到 15-30MB，减少 99%+ 的空间占用！

---

**作者**: Claude Code
**创建日期**: 2025-11-20
**版本**: 1.0
