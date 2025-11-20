# Git Multi-Repository Push Script

## 概述

这个脚本用于将gem5-gpu-bak项目的不同组件推送到各自的Gitee仓库。

## 仓库映射

| 本地目录 | Gitee仓库 | 说明 |
|---------|----------|------|
| `/home/siat/gem5-gpu-bak/gem5` | `https://gitee.com/miuzujia/gem5` | gem5模拟器核心 |
| `/home/siat/gem5-gpu-bak/gem5-gpu` | `https://gitee.com/miuzujia/gem5-gpu` | gem5-GPU集成层 |
| `/home/siat/gem5-gpu-bak/gpgpu-sim` | `https://gitee.com/miuzujia/gpgpu-sim` | GPGPU-Sim引擎 |
| `/home/siat/gem5-gpu-bak/Graphite` | `https://gitee.com/miuzujia/graphite` | Graphite组件 |

## 快速使用

### 基本推送操作

```bash
# 推送所有仓库
./push_to_gitee.sh

# 或者
./push_to_gitee.sh --push
```

### 查看状态

```bash
# 查看所有仓库的状态
./push_to_gitee.sh --status

# 列出所有配置的仓库
./push_to_gitee.sh --list

# 查看帮助
./push_to_gitee.sh --help
```

## 脚本功能

1. **自动初始化Git仓库**：如果目录还不是Git仓库，会自动初始化
2. **自动添加远程仓库**：配置正确的Gitee远程URL
3. **批量提交和推送**：自动添加、提交和推送所有更改
4. **详细日志记录**：所有操作记录到`build_logs/git_push_YYYYMMDD_HHMMSS.log`
5. **彩色输出**：清晰的命令行输出，便于识别状态
6. **错误处理**：遇到错误会继续处理其他仓库

## 工作流程

脚本执行以下步骤：

1. **设置Git凭证**
   - 配置Git credential store（首次使用时）
   - 设置用户信息（邮箱和用户名）

2. **处理每个仓库**
   - 检查目录是否存在
   - 初始化Git仓库（如需要）
   - 添加/更新远程仓库URL
   - 检测本地更改
   - 提交更改（如有）
   - 推送到Gitee

3. **生成报告**
   - 显示成功/失败统计
   - 生成详细日志文件

## 安全注意事项

### ⚠️ 当前方案（不推荐用于生产环境）

脚本目前在代码中包含明文密码，这**仅适用于个人开发环境**。

### ✅ 推荐的安全方案

#### 方案1：使用SSH密钥（最安全）

1. **生成SSH密钥**：
```bash
ssh-keygen -t rsa -b 4096 -C "miuzujia1995@163.com"
```

2. **添加公钥到Gitee**：
   - 复制公钥内容：`cat ~/.ssh/id_rsa.pub`
   - 登录Gitee → 设置 → SSH公钥 → 添加公钥

3. **修改脚本使用SSH URL**：
```bash
# 将HTTPS URL改为SSH URL
https://gitee.com/miuzujia/gem5       → git@gitee.com:miuzujia/gem5.git
https://gitee.com/miuzujia/gem5-gpu   → git@gitee.com:miuzujia/gem5-gpu.git
```

#### 方案2：使用Git凭证存储

脚本已配置使用Git credential store，首次推送后会自动保存凭证：

```bash
# 首次推送后，凭证会保存到 ~/.git-credentials
# 后续推送不需要再输入密码
```

#### 方案3：使用环境变量

将密码从脚本中移除，改用环境变量：

```bash
# 在~/.bashrc中添加
export GITEE_PASSWORD="your_password"

# 修改脚本读取环境变量
GITEE_PASSWORD="${GITEE_PASSWORD:-}"
```

## 日志文件

所有操作日志保存在：
```
/home/siat/gem5-gpu-bak/build_logs/git_push_YYYYMMDD_HHMMSS.log
```

日志包含：
- 所有Git操作的详细输出
- 错误信息和警告
- 时间戳和操作摘要

## 常见问题

### Q: 首次运行需要什么准备？

A: 确保：
1. 所有本地目录存在
2. 有网络连接
3. Gitee账号有相应仓库的推送权限

### Q: 如果某个仓库推送失败怎么办？

A: 脚本会继续处理其他仓库，最后显示失败统计。检查日志文件查看详细错误信息。

### Q: 如何只推送某一个仓库？

A: 可以直接在该目录下使用Git命令：
```bash
cd /home/siat/gem5-gpu-bak/gem5
git add -A
git commit -m "Update message"
git push origin master
```

### Q: 如何清除保存的凭证？

A:
```bash
git config --global --unset credential.helper
rm ~/.git-credentials
```

### Q: 脚本会推送到哪个分支？

A: 推送到当前所在分支。如果是新仓库，默认为`master`分支。

## 使用示例

### 示例1：标准工作流

```bash
# 1. 修改代码
cd /home/siat/gem5-gpu-bak/gem5/src/mem/ruby/network/garnet/flexible-pipeline
# 编辑文件...

# 2. 查看所有仓库状态
./push_to_gitee.sh --status

# 3. 推送所有更改
./push_to_gitee.sh

# 4. 检查日志
cat build_logs/git_push_*.log | tail -n 50
```

### 示例2：选择性推送

```bash
# 只推送gem5仓库
cd /home/siat/gem5-gpu-bak/gem5
git add -A
git commit -m "Update flexible-pipeline routing algorithm"
git push

# 只推送gem5-gpu仓库
cd /home/siat/gem5-gpu-bak/gem5-gpu
git add -A
git commit -m "Update GPU integration"
git push
```

## 提交信息规范

脚本自动生成的提交信息格式：
```
Update [repo_name] - YYYY-MM-DD HH:MM:SS
```

建议手动提交时使用更有意义的信息：
```bash
# 不好的提交信息
git commit -m "update"

# 好的提交信息
git commit -m "Implement MVPP_MGC_PSO power monitoring in Router.cc"
git commit -m "Fix buffer overflow in PSOAlgorithm::calculateFitness"
git commit -m "Add DSENT integration for power statistics"
```

## 与现有开发流程集成

这个脚本可以与现有的build和test流程结合使用：

```bash
# 完整开发工作流
./build_and_test_all.sh           # 构建和测试
# 分析结果，修改代码...
./push_to_gitee.sh --status       # 检查更改
./push_to_gitee.sh                # 推送到远程仓库
```

## 脚本维护

### 添加新仓库

编辑脚本中的`REPO_MAP`数组：
```bash
declare -a REPO_MAP=(
    "/path/to/local/dir|https://gitee.com/username/repo|repo_name"
    # 添加新行...
)
```

### 修改用户信息

编辑脚本中的配置部分：
```bash
GITEE_USERNAME="your_email@example.com"
GITEE_PASSWORD="your_password"
```

## 备份建议

在推送前建议：
1. 确保本地代码已经过测试
2. 重要修改前创建Git标签：
   ```bash
   git tag -a v1.0 -m "Version 1.0 - Stable MVPP_MGC_PSO implementation"
   git push origin v1.0
   ```

## 相关文档

- [CLAUDE.md](CLAUDE.md) - 项目开发指南
- [REMOTE_BUILD_README.md](REMOTE_BUILD_README.md) - 跨机器构建系统
- [build_and_test_all.sh](build_and_test_all.sh) - 构建和测试脚本
