# Python 版本修复说明

## 问题

远程机器 (192.168.157.128) 上的 SCons 版本为 2.3.0，不支持 Python 3：

```
scons: *** SCons version 2.3.0 does not run under Python version 3.4.3.
Python 3 is not yet supported.
```

## 修复

已将所有脚本中的 `python3` 改为 `python`：

### 修改的文件

| 文件 | 行号 | 修改前 | 修改后 |
|------|------|--------|--------|
| `compile_networktest.sh` | 152 | `python3 \`which scons\`` | `python \`which scons\`` |
| `compile_networktest.sh` | 188 | `python3 \`which scons\`` | `python \`which scons\`` |
| `implement_traffic_patterns.sh` | 104 | `python3 <<` | `python <<` |
| `implement_traffic_patterns.sh` | 166 | `python3 \`which scons\`` | `python \`which scons\`` |
| `quickstart_phase4_verification.sh` | 88 | `python3 <<` | `python <<` |

### 修改详情

#### 1. compile_networktest.sh

**远程编译命令** (行152):
```bash
# 修改前
REMOTE_COMPILE_CMD="cd ${REMOTE_PROJECT_DIR}/gem5 && python3 \`which scons\` ..."

# 修改后
REMOTE_COMPILE_CMD="cd ${REMOTE_PROJECT_DIR}/gem5 && python \`which scons\` ..."
```

**本地编译命令** (行188):
```bash
# 修改前
python3 `which scons` build/X86_Network_test/gem5.opt ...

# 修改后
python `which scons` build/X86_Network_test/gem5.opt ...
```

#### 2. implement_traffic_patterns.sh

**Python heredoc** (行104):
```bash
# 修改前
python3 << 'EOF_PYTHON'

# 修改后
python << 'EOF_PYTHON'
```

**编译命令** (行166):
```bash
# 修改前
python3 `which scons` build/X86_Network_test/gem5.opt ...

# 修改后
python `which scons` build/X86_Network_test/gem5.opt ...
```

#### 3. quickstart_phase4_verification.sh

**Python heredoc** (行88):
```bash
# 修改前
python3 << 'EOF_PYTHON'

# 修改后
python << 'EOF_PYTHON'
```

## 验证

现在可以重新运行编译脚本：

```bash
./compile_networktest.sh
```

应该不会再出现 SCons Python 3 不兼容的错误。

## 技术说明

### SCons 版本兼容性

- **SCons 2.x**: 只支持 Python 2.x
- **SCons 3.x**: 支持 Python 2.7 和 Python 3.5+
- **SCons 4.x**: 只支持 Python 3.6+

### gem5 构建系统

gem5 项目使用 SCons 作为构建系统。在较老的 gem5 版本中：
- 使用 SCons 2.x
- 需要 Python 2.x 运行 scons 命令
- Python 脚本（代码修改）可以用 Python 2 或 Python 3

### 建议

如果未来需要升级到 Python 3 支持：
1. 升级远程机器上的 SCons 到 3.x 或更高版本
2. 升级 gem5 到支持 Python 3 的版本
3. 然后才能使用 `python3` 运行 scons

---

**修复时间**: 2025-12-18
**状态**: ✅ 所有脚本已修复，使用 `python` 代替 `python3`
