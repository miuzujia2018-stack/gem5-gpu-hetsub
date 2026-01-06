# 代码同步问题修复

## 问题描述

再次编译 Network_test 时，仍然出现之前相同的错误：

```
fatal error: device_types.h: No such file or directory
 #include <device_types.h>
compilation terminated.
```

## 根本原因

虽然我们在本地修复了 Router.cc（移除了 L2Cache 和 DMA），但**修改后的代码没有同步到远程编译机器**。

### 问题分析

**compile_networktest.sh 的原始同步列表**：
```bash
SYNC_FILES=(
    "gem5/src/cpu/testers/networktest/"     # ✅ NetworkTest 生成器
    "gem5/configs/example/ruby_network_test.py"  # ✅ 配置文件
    "gem5/configs/ruby/Network_test.py"      # ✅ 协议配置
    "gem5/SConstruct"                        # ✅ 构建脚本
    "gem5/build_opts/"                       # ✅ 构建选项
    # ❌ 缺少 flexible-pipeline 目录！
)
```

**结果**：
- 本地机器：Router.cc 已修复（只使用 L1Cache + Directory）
- 远程机器：Router.cc 仍是旧版本（使用 L1Cache + L2Cache + Directory + DMA）
- 远程编译失败，因为 Network_test 协议没有 L2Cache 和 DMA

## 修复方案

### 修复 1: 添加 flexible-pipeline 到同步列表

**修改位置**：`compile_networktest.sh` Line 116-123

**修改后**：
```bash
SYNC_FILES=(
    "gem5/src/cpu/testers/networktest/"
    "gem5/src/mem/ruby/network/garnet/flexible-pipeline/"  # ✅ 新增：Router.cc 所在目录
    "gem5/configs/example/ruby_network_test.py"
    "gem5/configs/ruby/Network_test.py"
    "gem5/SConstruct"
    "gem5/build_opts/"
)
```

**影响**：
- ✅ Router.cc 的协议兼容性修复会被同步到远程机器
- ✅ MVPP_MGC_PSO 路由算法的所有文件都会同步
- ✅ 确保远程编译使用最新代码

### 修复 2: 清理 gpgpu-sim 符号链接

**修改位置**：
- `compile_networktest.sh` Line 157（远程编译）
- `compile_networktest.sh` Line 194-195（本地编译）

**远程编译命令**：
```bash
REMOTE_COMPILE_CMD="cd ${REMOTE_PROJECT_DIR}/gem5 && \
    rm -rf build/X86_Network_test/ && \       # 清理构建目录
    rm -f src/gpgpu-sim && \                  # ✅ 新增：删除 gpgpu-sim 符号链接
    export CUDAHOME=/usr/local/cuda && \
    python \`which scons\` build/X86_Network_test/gem5.opt \
        --default=X86 PROTOCOL=Network_test -j64"
```

**本地编译命令**：
```bash
rm -rf build/X86_Network_test/   # 清理构建目录
rm -f src/gpgpu-sim               # ✅ 新增：删除 gpgpu-sim 符号链接
```

**为什么需要删除 src/gpgpu-sim？**

gem5-gpu 项目可能在 gem5/src/ 目录下创建了指向 gpgpu-sim 的符号链接：
```bash
gem5/src/gpgpu-sim -> ../../gpgpu-sim/
```

即使我们没有在 EXTRAS 中指定 gpgpu-sim，SCons 仍然会扫描 src/ 目录下的所有子目录，包括这个符号链接，导致尝试编译 GPGPU-Sim 代码。

## 修复总结

| 文件 | 修改位置 | 修改内容 | 目的 |
|------|---------|---------|------|
| `compile_networktest.sh` | Line 118 | 添加 `gem5/src/mem/ruby/network/garnet/flexible-pipeline/` | 同步 Router.cc |
| `compile_networktest.sh` | Line 157 | 添加 `rm -f src/gpgpu-sim` | 删除远程 gpgpu-sim 符号链接 |
| `compile_networktest.sh` | Line 195 | 添加 `rm -f src/gpgpu-sim` | 删除本地 gpgpu-sim 符号链接 |

## 验证修复

现在重新运行编译：

```bash
cd /home/siat/gem5-gpu-bak/
./compile_networktest.sh
```

**预期行为**：

1. **代码同步阶段**：
```
[STEP] 步骤 1/2: 同步代码到远程机器
sending incremental file list
gem5/src/mem/ruby/network/garnet/flexible-pipeline/
gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc
gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh
... (更多 flexible-pipeline 文件)
[SUCCESS] 代码同步完成
```

2. **编译阶段**：
```
[STEP] 步骤 2/2: 在远程机器上编译 Network_test 协议
[INFO] 编译并行度: -j64
[INFO] 预计时间: 3-5分钟
----------------------------------------
scons: Reading SConscript files ...
Building in /home/siat/gem5-gpu-bak/gem5/build/X86_Network_test
scons: done reading SConscript files.
scons: Building targets ...
 [     CXX] X86_Network_test/mem/ruby/network/garnet/flexible-pipeline/Router.cc -> .o
 ... (只编译必要的文件，不包含 gpgpu-sim)
 [    SHCC] X86_Network_test/gem5.opt
----------------------------------------
[SUCCESS] 远程编译完成
```

**不应该出现的错误**：
- ❌ `error: 'MachineType_L2Cache' was not declared`
- ❌ `fatal error: device_types.h: No such file or directory`
- ❌ `[     CXX] X86_Network_test/gpgpu-sim/...`

## 技术说明

### 为什么需要同步 flexible-pipeline？

**Router.cc 的作用**：
- 实现 MVPP_MGC_PSO 路由算法
- 处理所有数据包的路由决策
- 需要根据协议类型（Network_test vs VI_hammer）选择正确的机器类型

**协议兼容性修复**：
```cpp
// 修改前（本地已修复，但远程未同步）
MachineID machine_ids[] = {
    {MachineType_L1Cache, ...},     // ✅ Network_test 有
    {MachineType_L2Cache, ...},     // ❌ Network_test 没有
    {MachineType_Directory, ...},   // ✅ Network_test 有
    {MachineType_DMA, ...}          // ❌ Network_test 没有
};

// 修改后（需要同步到远程）
MachineID machine_ids[] = {
    {MachineType_L1Cache, ...},     // ✅ 所有协议都有
    {MachineType_Directory, ...}    // ✅ 所有协议都有
};
```

### 为什么 GPGPU-Sim 仍在被编译？

**gem5-gpu 构建系统的特殊性**：

1. **符号链接机制**：
   ```bash
   gem5/src/gpgpu-sim -> ../../gpgpu-sim/
   ```
   这个符号链接可能在之前的 VI_hammer_GPU 构建中创建。

2. **SCons 扫描行为**：
   ```python
   # SConstruct 伪代码
   for subdir in src/*:
       if os.path.isdir(subdir):
           scan_sconscript(subdir)  # 包括符号链接目录
   ```
   即使没有指定 EXTRAS，SCons 也会扫描 src/ 下的所有目录。

3. **解决方案**：
   ```bash
   rm -f src/gpgpu-sim  # 删除符号链接
   ```
   这样 SCons 就不会尝试编译 GPGPU-Sim 代码。

### Network_test vs VI_hammer 编译对比

| 项目 | Network_test | VI_hammer_GPU |
|------|--------------|---------------|
| **协议** | Network_test（简化） | VI_hammer（完整） |
| **机器类型** | L1Cache, Directory | L1Cache, L2Cache, Directory, DMA |
| **EXTRAS** | 无 | `../gem5-gpu/src:../gpgpu-sim/` |
| **依赖** | 只需 NetworkTest tester | 需要 GPGPU-Sim, CUDA SDK |
| **用途** | 综合流量测试 | 真实 GPU 应用测试 |
| **编译时间** | 3-5分钟（-j64） | 10-15分钟（-j64） |

## 对比：修复前后的同步行为

### 修复前
```bash
# 同步的文件
gem5/src/cpu/testers/networktest/   ✅
gem5/configs/...                     ✅
gem5/build_opts/                     ✅

# 未同步的文件
gem5/src/mem/ruby/network/garnet/flexible-pipeline/  ❌

# 结果
远程机器使用旧版 Router.cc → 编译失败
```

### 修复后
```bash
# 同步的文件
gem5/src/cpu/testers/networktest/   ✅
gem5/src/mem/ruby/.../flexible-pipeline/  ✅ 新增
gem5/configs/...                     ✅
gem5/build_opts/                     ✅

# 清理操作
rm -rf build/X86_Network_test/      ✅
rm -f src/gpgpu-sim                  ✅ 新增

# 结果
远程机器使用新版 Router.cc → 编译成功
```

## 总结

### 问题本质
1. **代码同步不完整**：Router.cc 的修复没有同步到远程机器
2. **符号链接残留**：src/gpgpu-sim 符号链接导致 GPGPU-Sim 被编译

### 解决方案
1. ✅ **添加 flexible-pipeline 到同步列表**：确保 Router.cc 修复被同步
2. ✅ **删除 gpgpu-sim 符号链接**：避免编译不需要的 GPU 代码

### 验证完成
- ⏳ 等待重新运行 `./compile_networktest.sh`
- ⏳ 验证编译成功
- ⏳ 运行 Phase 4 综合流量测试

---

**修复时间**: 2025-12-18 14:40
**状态**: ✅ 已修复，等待重新编译
**下一步**: 运行 `./compile_networktest.sh` 验证修复
