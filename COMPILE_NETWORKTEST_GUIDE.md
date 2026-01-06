# compile_networktest.sh - 优化后的编译脚本使用指南

## 📋 概述

`compile_networktest.sh` 是一个优化的 Network_test 协议编译脚本，参考 `build_and_test_all.sh` 的跨机器编译能力进行了重构。

### ✨ 主要特性

1. **跨机器编译支持** - 支持本地 (138) 和远程 (128) 编译
2. **智能并行度** - 远程 -j64 vs 本地 -j8
3. **自动代码同步** - rsync 增量同步源代码
4. **完整日志记录** - 所有操作记录到日志文件
5. **二进制自动传输** - 远程编译后自动传输回本地

---

## 🚀 快速开始

### 默认用法（推荐 - 远程编译）

```bash
cd /home/siat/gem5-gpu-bak/
./compile_networktest.sh
```

**特点**:
- 使用远程机器 192.168.157.128 编译
- 编译并行度: -j64
- 预计时间: **3-5 分钟**
- 自动传输二进制文件回本地

---

### 本地编译（备选方案）

```bash
./compile_networktest.sh --local
# 或
./compile_networktest.sh -l
```

**特点**:
- 在当前机器 (138) 编译
- 编译并行度: -j8
- 预计时间: **15-25 分钟**
- 适用于远程机器不可用时

---

## 🔧 详细用法

### 命令行选项

```
用法: ./compile_networktest.sh [选项]

选项:
    -l, --local         本地编译（在当前机器上编译，-j8）
    -r, --remote        远程编译（在192.168.157.128上编译，-j64，默认）
    -h, --help          显示此帮助信息
```

### 使用示例

```bash
# 1. 远程编译（默认，推荐）
./compile_networktest.sh

# 2. 明确指定远程编译
./compile_networktest.sh --remote

# 3. 本地编译
./compile_networktest.sh --local

# 4. 查看帮助
./compile_networktest.sh --help
```

---

## 📊 性能对比

| 编译模式 | 机器 | 并行度 | 预计时间 | 适用场景 |
|---------|------|--------|---------|----------|
| **远程编译** | 192.168.157.128 | -j64 | **3-5分钟** | ✅ 推荐（默认） |
| **本地编译** | 192.168.197.138 | -j8 | 15-25分钟 | 远程不可用时 |

**速度提升**: 远程编译比本地快 **5-8倍**

---

## 🔄 工作流程

### 远程编译模式（默认）

```
步骤 1: 检查SSH连接
   ↓
步骤 2: 同步源代码到远程机器 (rsync)
   ├─ gem5/src/cpu/testers/networktest/
   ├─ gem5/configs/example/ruby_network_test.py
   ├─ gem5/configs/ruby/Network_test.py
   ├─ gem5/SConstruct
   └─ gem5/build_opts/
   ↓
步骤 3: 远程编译 (-j64)
   ├─ python3 scons build/X86_Network_test/gem5.opt
   ├─ --default=X86
   ├─ PROTOCOL=Network_test
   └─ -j64
   ↓
步骤 4: 传输二进制文件回本地 (scp)
   └─ gem5/build/X86_Network_test/gem5.opt
   ↓
✅ 完成
```

### 本地编译模式

```
步骤 1: 本地编译 (-j8)
   ├─ cd /home/siat/gem5-gpu-bak/gem5
   ├─ python3 scons build/X86_Network_test/gem5.opt
   ├─ --default=X86
   ├─ PROTOCOL=Network_test
   └─ -j8
   ↓
✅ 完成
```

---

## 📝 日志文件

所有编译操作会记录到日志文件：

```bash
/home/siat/gem5-gpu-bak/build_logs/networktest_build_YYYYMMDD_HHMMSS.log
```

### 查看日志

```bash
# 查看最新编译日志
cat build_logs/networktest_build_*.log | tail -100

# 查看所有日志文件
ls -lth build_logs/networktest_build_*.log
```

---

## ⚙️ 配置参数

脚本开头定义的配置参数（可根据需要修改）：

```bash
REMOTE_USER="siat"                              # 远程用户名
REMOTE_HOST="192.168.157.128"                   # 远程主机IP
REMOTE_PASSWORD="123"                           # 远程密码（如需密码认证）
LOCAL_PROJECT_DIR="/home/siat/gem5-gpu-bak"     # 本地项目目录
REMOTE_PROJECT_DIR="/home/siat/gem5-gpu-bak"    # 远程项目目录
```

---

## 🔐 SSH 认证

### SSH 密钥认证（推荐）

脚本优先尝试使用 SSH 密钥认证：

```bash
# 配置 SSH 密钥（首次执行）
./setup_ssh_key.sh
```

### 密码认证（备选）

如果 SSH 密钥未配置，脚本会自动使用密码认证（需要 sshpass）：

```bash
# 安装 sshpass（如果未安装）
sudo apt-get install sshpass
```

---

## ✅ 成功输出示例

```
==========================================
Network_test 协议编译脚本
==========================================

[INFO] 2025-12-18 10:30:00 - 编译模式: remote
[INFO] 2025-12-18 10:30:00 - 日志文件: build_logs/networktest_build_20251218_103000.log

[INFO] 2025-12-18 10:30:00 - 使用远程编译模式（推荐）

[INFO] 2025-12-18 10:30:01 - 检查与远程机器 192.168.157.128 的SSH连接...
[SUCCESS] 2025-12-18 10:30:01 - SSH密钥认证成功

[STEP] 2025-12-18 10:30:01 - 步骤 1/2: 同步代码到远程机器
[INFO] 2025-12-18 10:30:01 - 本地目录: /home/siat/gem5-gpu-bak
[INFO] 2025-12-18 10:30:01 - 远程目录: siat@192.168.157.128:/home/siat/gem5-gpu-bak
[SUCCESS] 2025-12-18 10:30:15 - 代码同步完成

[STEP] 2025-12-18 10:30:15 - 步骤 2/2: 在远程机器上编译 Network_test 协议
[INFO] 2025-12-18 10:30:15 - 编译并行度: -j64
[INFO] 2025-12-18 10:30:15 - 预计时间: 3-5分钟
[INFO] 2025-12-18 10:30:15 - 执行远程编译命令...
----------------------------------------
[编译输出...]
----------------------------------------
[SUCCESS] 2025-12-18 10:34:20 - 远程编译完成

[STEP] 2025-12-18 10:34:20 - 传输编译好的二进制文件回本地...
[SUCCESS] 2025-12-18 10:34:25 - 二进制文件传输完成
[INFO] 2025-12-18 10:34:25 - 本地路径: /home/siat/gem5-gpu-bak/gem5/build/X86_Network_test/gem5.opt

==========================================
[SUCCESS] 2025-12-18 10:34:25 - 编译完成！
==========================================

[INFO] 2025-12-18 10:34:25 - 总耗时: 265 秒 (4 分钟)
[INFO] 2025-12-18 10:34:25 - gem5 二进制: /home/siat/gem5-gpu-bak/gem5/build/X86_Network_test/gem5.opt
[INFO] 2025-12-18 10:34:25 - 完整日志: build_logs/networktest_build_20251218_103000.log

[INFO] 2025-12-18 10:34:25 - 下一步:
  ./run_phase4_traffic_verification.sh
```

---

## ❌ 故障排除

### 问题 1: SSH 连接失败

**错误信息**:
```
[ERROR] SSH连接检查失败
```

**解决方案**:
1. 检查远程机器是否在线: `ping 192.168.157.128`
2. 配置 SSH 密钥: `./setup_ssh_key.sh`
3. 或使用本地编译: `./compile_networktest.sh --local`

---

### 问题 2: sshpass 未安装

**错误信息**:
```
[ERROR] 未安装sshpass，无法进行密码认证
```

**解决方案**:
```bash
sudo apt-get install sshpass
```

---

### 问题 3: 编译失败

**错误信息**:
```
[ERROR] 远程编译失败，退出码: 2
```

**解决方案**:
1. 查看详细日志: `cat build_logs/networktest_build_*.log | tail -200`
2. 检查是否缺少依赖
3. 尝试本地编译排查问题

---

### 问题 4: 二进制传输失败

**错误信息**:
```
[ERROR] 二进制文件传输失败
```

**解决方案**:
1. 检查磁盘空间: `df -h`
2. 检查网络连接
3. 手动传输: `scp siat@192.168.157.128:/home/siat/gem5-gpu-bak/gem5/build/X86_Network_test/gem5.opt ./gem5/build/X86_Network_test/`

---

## 🔗 与其他脚本的集成

### 在 quickstart_phase4_verification.sh 中的使用

```bash
if [ "$BINARY_EXISTS" = false ]; then
    ./compile_networktest.sh
    # 自动使用远程编译（默认）
    # 如果失败，会提示使用 --local 模式
fi
```

### 与 implement_traffic_patterns.sh 的配合

```bash
# 步骤1: 修改代码（implement_traffic_patterns.sh）
./implement_traffic_patterns.sh

# 步骤2: 编译（compile_networktest.sh，优化版）
./compile_networktest.sh

# 步骤3: 测试
./run_phase4_traffic_verification.sh
```

---

## 📚 相关文档

- `build_and_test_all.sh` - 原始跨机器编译脚本（参考来源）
- `sync_and_build.sh` - VI_hammer 协议编译脚本
- `implement_traffic_patterns.sh` - 流量模式代码修改脚本
- `PHASE4_VERIFICATION_README.md` - 完整验证流程文档

---

## 🎯 总结

### 关键优势

1. ✅ **8倍速度提升** - 远程 -j64 vs 本地 -j8
2. ✅ **自动化流程** - 同步、编译、传输一键完成
3. ✅ **完整日志** - 所有操作可追溯
4. ✅ **灵活模式** - 支持本地/远程切换
5. ✅ **错误处理** - 完善的错误提示和恢复建议

### 推荐用法

```bash
# 日常开发（推荐）
./compile_networktest.sh                # 远程编译，3-5分钟

# 远程不可用时
./compile_networktest.sh --local        # 本地编译，15-25分钟
```

---

**创建时间**: 2025-12-18
**状态**: ✅ 已优化并集成到 Phase 4 验证工作流
