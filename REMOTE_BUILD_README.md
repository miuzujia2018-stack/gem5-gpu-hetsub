# gem5-gpu 跨机器开发编译测试系统

## 系统概述

本系统提供了一套完整的**跨机器开发-编译-测试**自动化工具，支持在开发机器（192.168.197.138）上修改代码，然后在编译机器（192.168.197.130）上自动同步、编译和测试。

### 架构示意图

```
┌─────────────────────────────────────────────────────────────┐
│  192.168.197.138 (开发机器 - 当前机器)                       │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │  代码编辑    │────────>│  触发脚本    │                  │
│  │  修改源码    │         │ (自动化)     │                  │
│  └──────────────┘         └──────┬───────┘                  │
│                                   │ rsync + SSH              │
└───────────────────────────────────┼──────────────────────────┘
                                    │ 局域网传输
┌───────────────────────────────────▼──────────────────────────┐
│  192.168.197.130 (编译/测试机器)                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  接收代码    │─>│   编译项目   │─>│  运行测试    │       │
│  │   (rsync)    │  │   (scons)    │  │  (gem5.opt)  │       │
│  └──────────────┘  └──────────────┘  └──────┬───────┘       │
│                                              │ 日志回传       │
└──────────────────────────────────────────────┼───────────────┘
                                               │
                    ┌──────────────────────────▼──┐
                    │   138机器接收日志供分析      │
                    └─────────────────────────────┘
```

## 脚本文件说明

本系统包含以下脚本文件：

| 脚本文件 | 功能描述 | 使用场景 |
|---------|---------|---------|
| `setup_ssh_key.sh` | 配置SSH免密登录 | **首次使用必须运行** |
| `sync_and_build.sh` | 同步代码并编译 | 修改代码后需要编译 |
| `run_tests.sh` | 运行基准测试 | 编译完成后运行测试 |
| `build_and_test_all.sh` | 一键完成编译和测试 | 推荐日常使用 |

## 快速开始（3步完成配置）

### 第1步：配置SSH免密登录（首次运行）

```bash
cd /home/siat/gem5-gpu-bak
chmod +x setup_ssh_key.sh
./setup_ssh_key.sh
```

**作用：**
- 生成SSH密钥对
- 自动复制公钥到130机器
- 测试免密登录是否成功
- 避免每次输入密码

**预期输出：**
```
[SUCCESS] SSH密钥生成成功
[SUCCESS] SSH公钥复制成功
[SUCCESS] SSH免密登录配置成功！
```

### 第2步：赋予所有脚本执行权限

```bash
chmod +x sync_and_build.sh run_tests.sh build_and_test_all.sh
```

### 第3步：运行编译和测试

```bash
# 方式1: 一键完成编译和测试（推荐）
./build_and_test_all.sh

# 方式2: 只编译
./build_and_test_all.sh -b

# 方式3: 只测试
./build_and_test_all.sh -t all
```

## 详细使用指南

### 方案1：一键式自动化（推荐）

适合日常开发使用，自动完成同步、编译、测试全流程。

```bash
# 编译并运行所有测试
./build_and_test_all.sh

# 只编译不测试
./build_and_test_all.sh -b

# 只测试不编译
./build_and_test_all.sh -t all

# 只运行backprop测试
./build_and_test_all.sh -t backprop

# 只运行kmeans测试
./build_and_test_all.sh -t kmeans
```

### 方案2：分步手动控制

适合需要精细控制的场景。

#### 2.1 同步代码并编译

```bash
./sync_and_build.sh
```

**执行流程：**
1. 检查SSH连接
2. 使用rsync增量同步代码到130机器
3. 在130机器上执行编译（-j64并行编译）
4. 回传编译日志到本地

**同步的目录：**
- `gem5-gpu/src/` - GPU集成层源码
- `gpgpu-sim/` - GPU模拟器
- `gem5/src/` - gem5核心源码
- `gem5/configs/` - 配置文件
- `gem5-gpu/configs/` - GPU配置
- `benchmarks/` - 基准测试程序

**排除的目录（不同步）：**
- `build/` - 编译产物
- `.git/` - Git仓库
- `build_logs/` - 日志文件
- `m5out/` - 模拟输出

#### 2.2 运行测试

```bash
# 运行backprop测试
./run_tests.sh backprop

# 运行kmeans测试
./run_tests.sh kmeans

# 运行所有测试
./run_tests.sh all
```

**测试配置：**

**backprop测试：**
- 二进制：`/home/siat/gem5-gpu-bak/gem5/build/X86_VI_hammer_GPU/gem5.opt`
- 配置：`gem5-gpu/configs/se_fusion.py`
- 网络：`--garnet-network=flexible`
- 程序：`benchmarks/rodinia/backprop/gem5_fusion_backprop`
- 参数：`"16"`

**kmeans测试：**
- 二进制：同上
- 配置：同上
- 网络：`--garnet-network=flexible`
- 程序：`benchmarks/rodinia/kmeans/gem5_fusion_kmeans`
- 参数：`"-i /home/siat/Downloads/kmeans_input.txt"`

## 日志系统

所有编译和测试日志都保存在本地，方便分析和调试。

### 日志目录结构

```
/home/siat/gem5-gpu-bak/build_logs/
├── sync_build_20251104_143022.log        # 同步和编译主日志
├── remote_build_20251104_143022.log      # 远程编译详细日志
├── test_backprop_20251104_144530.log     # backprop测试日志
└── test_kmeans_20251104_145612.log       # kmeans测试日志
```

### 查看日志

```bash
# 查看最新的编译日志
ls -lt build_logs/ | head -5

# 查看最新的编译详细信息
cat build_logs/remote_build_*.log | tail -100

# 搜索编译错误
grep -i "error" build_logs/remote_build_*.log

# 查看测试结果
grep -i "result" build_logs/test_*.log
```

## 典型工作流程

### 场景1：修改代码并验证

```bash
# 在138机器上修改flexible-pipeline目录中的代码
vim gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc

# 同步代码并编译
./sync_and_build.sh

# 如果编译成功，运行测试验证
./run_tests.sh all

# 或者一键完成
./build_and_test_all.sh
```

### 场景2：快速迭代开发

```bash
# 修改代码
# ... 编辑文件 ...

# 只编译验证语法
./build_and_test_all.sh -b

# 编译成功后运行单个测试快速验证
./run_tests.sh backprop

# 全部测试通过后再运行所有测试
./run_tests.sh all
```

### 场景3：分析测试失败

```bash
# 运行测试
./run_tests.sh backprop

# 如果失败，查看详细日志
less build_logs/test_backprop_*.log

# 分析错误信息，修改代码
vim gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc

# 重新编译和测试
./build_and_test_all.sh -t backprop
```

## 编译参数说明

### 编译命令详解

```bash
python $(which scons) build/X86_VI_hammer_GPU/gem5.opt \
    --default=X86 \               # X86架构
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \  # 额外源码目录
    PROTOCOL=VI_hammer \          # Ruby缓存一致性协议
    GPGPU_SIM=True \             # 启用GPGPU-Sim集成
    -j64                         # 64线程并行编译
```

### 编译输出位置

```
130机器: /home/siat/gem5-gpu-bak/gem5/build/X86_VI_hammer_GPU/gem5.opt
```

## 测试配置说明

### 测试输出目录

```
130机器: /home/siat/test/
```

每次测试前会自动清空此目录，测试结果包括：
- `config.ini` - 模拟器配置
- `stats.txt` - 性能统计
- `ruby.stats` - Ruby内存系统统计
- `system.pc.com_1.device` - 设备输出

### 网络配置

测试使用 `--garnet-network=flexible` 参数，启用flexible-pipeline网络模型，这是**MVPP_MGC_PSO路由算法**所在的网络实现。

## 故障排除

### 问题1：SSH连接失败

**症状：**
```
[ERROR] SSH连接检查失败，终止执行
```

**解决方案：**
```bash
# 1. 检查130机器是否在线
ping 192.168.197.130

# 2. 检查SSH服务是否运行
ssh siat@192.168.197.130 "systemctl status sshd"

# 3. 重新配置SSH密钥
./setup_ssh_key.sh
```

### 问题2：代码同步失败

**症状：**
```
[ERROR] 同步 gem5/src 失败
```

**解决方案：**
```bash
# 1. 检查磁盘空间
ssh siat@192.168.197.130 "df -h"

# 2. 检查目录权限
ssh siat@192.168.197.130 "ls -ld /home/siat/gem5-gpu-bak"

# 3. 手动同步测试
rsync -avzh gem5/src/ siat@192.168.197.130:/home/siat/gem5-gpu-bak/gem5/src/
```

### 问题3：编译失败

**症状：**
```
[ERROR] 编译失败！退出码: 2
```

**解决方案：**
```bash
# 1. 查看详细编译日志
cat build_logs/remote_build_*.log

# 2. 搜索具体错误
grep -A 5 "error:" build_logs/remote_build_*.log

# 3. 检查130机器的编译环境
ssh siat@192.168.197.130 "python --version && which scons"

# 4. 手动登录130机器编译测试
ssh siat@192.168.197.130
cd /home/siat/gem5-gpu-bak/gem5
python $(which scons) build/X86_VI_hammer_GPU/gem5.opt --default=X86 EXTRAS=../gem5-gpu/src:../gpgpu-sim/ PROTOCOL=VI_hammer GPGPU_SIM=True -j64
```

### 问题4：测试失败

**症状：**
```
[ERROR] backprop测试失败！退出码: 1
```

**解决方案：**
```bash
# 1. 查看测试日志
cat build_logs/test_backprop_*.log

# 2. 检查gem5.opt是否存在
ssh siat@192.168.197.130 "ls -lh /home/siat/gem5-gpu-bak/gem5/build/X86_VI_hammer_GPU/gem5.opt"

# 3. 检查基准测试程序
ssh siat@192.168.197.130 "ls -lh /home/siat/gem5-gpu-bak/benchmarks/rodinia/backprop/gem5_fusion_backprop"

# 4. 手动运行测试
ssh siat@192.168.197.130
cd /home/siat/gem5-gpu-bak
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /home/siat/test/ \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"
```

### 问题5：网络延迟导致同步慢

**解决方案：**
```bash
# 优化rsync参数，使用更激进的压缩
# 编辑 sync_and_build.sh，修改 RSYNC_OPTS：
RSYNC_OPTS="-avz --compress-level=9 --progress"
```

## 高级配置

### 自定义远程机器配置

如果需要更改远程机器IP或用户，编辑相应脚本：

```bash
# 编辑 sync_and_build.sh
vim sync_and_build.sh

# 修改以下参数
REMOTE_USER="your_username"
REMOTE_HOST="your_host_ip"
```

同样修改 `run_tests.sh` 和 `setup_ssh_key.sh`。

### 添加新的测试

编辑 `run_tests.sh`，添加新的测试函数：

```bash
# 添加新的测试函数
run_new_test() {
    log_test "开始运行new_test基准测试..."

    TEST_NAME="new_test"
    REMOTE_LOG="/tmp/gem5_test_${TEST_NAME}_${TIMESTAMP}.log"
    LOCAL_LOG="${LOG_DIR}/test_${TEST_NAME}_${TIMESTAMP}.log"

    # 测试命令
    TEST_CMD="${GEM5_BINARY} -d ${TEST_OUTPUT_DIR} \
        ${PROJECT_DIR}/gem5-gpu/configs/se_fusion.py \
        --garnet-network=flexible \
        -c ${PROJECT_DIR}/benchmarks/path/to/new_test \
        -o \"args\""

    # ... 执行测试逻辑 ...
}

# 在main函数中添加新的case
case ${TEST_TYPE} in
    # ... 现有的测试 ...
    new_test)
        if run_new_test; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
        ;;
    # ...
esac
```

### 性能优化建议

#### 1. 增量编译优化

只同步修改过的文件，避免全量同步：

```bash
# 修改特定文件后
rsync -avzh gem5/src/mem/ruby/network/garnet/flexible-pipeline/ \
    siat@192.168.197.130:/home/siat/gem5-gpu-bak/gem5/src/mem/ruby/network/garnet/flexible-pipeline/
```

#### 2. 并行编译线程数调整

根据130机器的CPU核心数调整 `-j` 参数：

```bash
# 查看CPU核心数
ssh siat@192.168.197.130 "nproc"

# 修改 sync_and_build.sh 中的编译命令
# 建议使用: -j$(nproc) 或 -j$(nproc - 2)
```

#### 3. 使用编译缓存

启用ccache加速重复编译：

```bash
# 在130机器上安装ccache
ssh siat@192.168.197.130 "sudo apt-get install ccache"

# 配置环境变量
export PATH="/usr/lib/ccache:$PATH"
```

## 系统要求

### 开发机器（192.168.197.138）

- 操作系统：Linux
- 必需工具：
  - `rsync` - 代码同步
  - `ssh` - 远程连接
  - `sshpass` - 密码认证（可选）
- 磁盘空间：至少1GB用于日志存储

### 编译/测试机器（192.168.197.130）

- 操作系统：Linux
- 必需工具：
  - `python` (2.7或3.x)
  - `scons` - 构建工具
  - `gcc/g++` - C/C++编译器
  - SSH服务运行中
- CPU：建议16核以上（支持 -j64 并行编译）
- 内存：建议16GB以上
- 磁盘空间：至少20GB

## 安全注意事项

1. **SSH密钥管理**
   - 保护好私钥文件 `~/.ssh/id_rsa`
   - 不要将私钥分享给他人
   - 建议定期更换密钥

2. **密码管理**
   - 配置SSH密钥后，删除脚本中的明文密码
   - 不要将包含密码的脚本提交到Git仓库

3. **网络安全**
   - 确保局域网安全，避免中间人攻击
   - 建议使用VPN或安全隔离的网络环境

## 总结

本系统提供了一套完整的跨机器开发解决方案：

✅ **自动化程度高** - 一键完成同步、编译、测试
✅ **日志完整** - 所有操作都有详细日志记录
✅ **容错性强** - 完善的错误处理和提示信息
✅ **易于扩展** - 简单添加新的测试或配置
✅ **高效可靠** - rsync增量同步，并行编译加速

### 推荐工作流

```bash
# 1. 首次配置（仅需运行一次）
./setup_ssh_key.sh

# 2. 日常开发
vim gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc
./build_and_test_all.sh

# 3. 快速验证
./build_and_test_all.sh -t backprop

# 4. 分析结果
cat build_logs/*.log
```

---

**文档版本**: 1.0
**创建日期**: 2025-11-04
**维护者**: gem5-gpu开发团队
