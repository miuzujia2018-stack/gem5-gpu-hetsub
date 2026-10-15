# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview

**gem5-gpu** — a heterogeneous CPU-GPU simulation framework integrating:
- **gem5**: Modular system architecture simulator
- **GPGPU-Sim**: Cycle-level GPU functional/timing simulator
- **Ruby memory system**: Coherent cache hierarchy and interconnect (garnet/flexible-pipeline)

### Primary Objective

**在现有 gem5-gpu 平台尽可能忠实复现 HetSub 核心方法，用于与 gem5-gpu-bak 和 gem5-gpu-tbp 比较。** 不复现原论文性能数值、性能曲线或优势幅度，不重建原论文实验框架和系统平台。

当前已有 XY DOR 实现作为功能关闭时的基线和回归分母；它不代表 HetSub 已实现。XY 先处理 X 维，再处理 Y 维。

## HetSub 核心方法复现边界（当前研究目标）

**尽可能忠实复现 HetSub 的核心方法；不以复现原论文性能数值、性能曲线或优势幅度为目标，不复现原论文的实验框架和系统平台。** 本节优先于旧任务、旧需求文档中不一致的研究目标与范围；下方强制干净构建及运行前验证门禁继续有效。

- **固定当前平台**：沿用 gem5-gpu / flexible Garnet / VI_hammer、当前 CPU/GPU/缓存系统、64-tile 布局、Docker 环境和现有应用。与 `gem5-gpu-bak`、`gem5-gpu-tbp` 比较时对齐实际配置、端点映射、输入和测量口径。不得为复现论文而迁移 Noxim、搭建 SNN/神经形态平台、复制原文数据集或重建其 RTL/工艺实验流程。
- **允许必要的 NoC 内部改造**：独立子网、链路位宽、buffer/VC、仲裁、电源状态和 NI relay 属于待复现方法本身，不等于更换系统平台。改动须集中、可解释，按实际链路容量和存储位数核算资源；不能为了少改代码，把关键资源竞争或时序效果仅替换成标签和事后统计修正。
- **核心机制优先**：独立常开 dual-line 与 PG Mesh 子网；真实宽窄 flit 与序列化/反序列化；拥塞驱动的动态子网选择；PG 唤醒与转换代价；静态 long-link、crossbar bypass 和有界 relay；Algorithm 1 的单调路径限制与 Algorithm 2 的 Hilbert 分层插入。不能仅实现 Hilbert 路由就称完成 HetSub。
- **验收机制，不验收论文收益**：检查机制是否在实际数据路径中生效、消息守恒与正确交付、顺序和流控、资源约束、时序、排空和应用正确性。不得要求达到原文的 38% 延迟改善、58% 静态功耗降低、16% 面积节省，或要求优于 bak/TBP。不为贴合原文曲线调整平台、挑选结果或反复调参。
- **允许在当前平台测量性能**：用于客观比较和解释机制，保留负收益与适用边界；“不复现性能”不意味着免测服务时间、带宽、拥塞和唤醒代价。当前 CPU/GPU 工作负载下的结果是方法迁移评估，不是原文 SNN 实验的复现。
- **明确完成度**：报告“已实现／近似／未实现”的逐项机制清单及测试证据。近似和缺失必须进入结论，不用主观相似度百分比或原文结果替代证据；未实现的核心机制不能静默省略后宣称完成。
- **禁止过度工程化、过度哈希**：优先复用现有类、脚本和测试入口，不新增通用调度平台、插件体系、在线重配置或无关重构。只保留现有强制源码/二进制构建凭据，不新增逐包/CSV/图表哈希、哈希链或登记数据库。

实施方案优先参考 [固定平台下的忠实复现方案](docs/HETSUB_FAITHFUL_PLATFORM_PLAN.md)，具体文件范围与阶段验收写入 `.ai/tasks/TASK.md`。共享 Mesh 的旧最小适配方案仅作受限退路，不可当成独立双子网已经复现的证据。方案中的性能比较矩阵服务于当前平台评估，不扩张为重建原论文实验体系。

## Dual-Agent Workflow Contract

When `.ai/tasks/TASK.md` exists, treat it as the active execution spec.

Execution rules:
- Follow `.ai/tasks/TASK.md` for the goal, file scope, acceptance criteria, and test commands, within the HetSub research boundaries above.
- The task file overrides the default working-directory focus below when they conflict.
- Write execution results to `.ai/reports/REPORT.md`.
- Do not edit `.ai/reviews/REVIEW.md`.
- Escalate if the task spec and repo state disagree.

Verification rules:
- Use the verification commands required by the task file.
- The default `./docker_build_and_test_j64.sh` requirement below still applies when you change simulator source files or when the task does not define a narrower verification plan.

## Behavioral Guidelines

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Build System (Docker)

Use the dedicated Docker container **`gem5gpu-dev-hetsub`** (image `myubuntu14:latest`) for HetSub runtime tests. It explicitly bind-mounts `/home/siat/gem5-gpu-hetsub` at the same path. Official clean builders may use temporary containers from the same image with the explicit project bind. This replaces the earlier shared-container requirement by user instruction.

**IMPORTANT**: This system requires `sudo docker`. The container must be running before use:
```bash
sudo docker start gem5gpu-dev-hetsub    # if stopped
```

### Mandatory: Build + Test After Changes

**After ANY code change to flexible-pipeline/ (or other source files), you MUST run:**

```bash
./docker_build_and_test_j64.sh
```

This compiles gem5.opt (-j64) AND runs both benchmarks (backprop + kmeans). A final implementation approval requires a passing run. User-required stage checkpoints must still be pushed with their exact verification status and remaining failures, following the stage-checkpoint rule below. If the script fails, fix the issue and rerun before proceeding.

### What the script does

1. `scons build/X86_VI_hammer_GPU/gem5.opt` inside the container
2. `./run.sh both` — backprop + kmeans benchmarks

### Critical Runtime Requirements

**Two fixes are essential for simulation to work:**

1. **Absolute path for `-c`**: Must use absolute path to the benchmark binary. Relative paths cause `_dl_get_origin` assertion failure in the simulated process's libc (gem5 SE mode returns relative path from `readlink("/proc/self/exe")`, but glibc requires it to start with `/`).

2. **CUDA environment variables**: `ptxas` must be in PATH, otherwise GPGPU-Sim PTX loader calls `exit(1)`. Set all three:
   ```bash
   export CUDAHOME=/usr/local/cuda/cuda
   export PATH=/usr/local/cuda/cuda/bin:$PATH
   export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64
   ```

### Manual commands (inside container)

```bash
# Compile
cd /home/siat/gem5-gpu-hetsub/gem5
export CUDAHOME=/usr/local/cuda/cuda
scons build/X86_VI_hammer_GPU/gem5.opt --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ PROTOCOL=VI_hammer GPGPU_SIM=True -j64

# Test backprop (8x8 mesh, flexible pipeline)
export CUDAHOME=/usr/local/cuda/cuda
export PATH=/usr/local/cuda/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /tmp/test \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c /home/siat/gem5-gpu-hetsub/benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"

# Test kmeans
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /tmp/test \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c /home/siat/gem5-gpu-hetsub/benchmarks/rodinia/kmeans/gem5_fusion_kmeans \
    -o "-i /home/siat/gem5-gpu-hetsub/kmeans_input.txt"
```

## Working Directory Constraints

- **Primary working directory**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- **Allowed**: Make necessary .cc/.hh/.py changes in flexible-pipeline. The active task may also identify limited topology, configuration, build registration, runner, parser, and test changes required for the HetSub methods and fair comparison.
- **Scope limit**: Do not modify CPU/GPU execution models or the coherence protocol, replace the experimental platform, create .bak files, or restructure unrelated directories. Changes outside flexible-pipeline must have a concrete role in the active task.

## Interface Preservation Rules

Existing public method signatures must NOT be modified. Extend by adding new methods/members, not changing existing ones.

Key classes and their core interfaces:

```cpp
// Router (Router.hh) - MUST preserve:
int getRoute(NetDest destination);
int getRoutePSO(NetDest destination);
int getRouteCollaborative(NetDest destination);
void routeCompute(flit *m_flit, int inport);
void addInPort(NetworkLink *in_link);
void addOutPort(NetworkLink *out_link, const NetDest& routing_table_entry, int link_weight);
void wakeup();
uint32_t get_id() const;

// PSOAlgorithm (PSOAlgorithm.hh) - MUST preserve:
void initializePSO();
int getRoutePSO(NetDest destination);
double calculateMultiObjectiveFitness(const PacketParticle& packet);
void updateParticlePosition(Particle& particle, int src_node, int dest_node);
```

Existing struct members in `Particle`, `PacketParticle` must also be preserved. Add new fields but don't remove/rename existing ones.

## Current Implementation State

### Topology: 8x8 Mesh (64 nodes)

Key constants in `Router.hh`:
- `GlobalGraph::MESH_SIZE = 8`
- `GlobalGraph::TOTAL_NODES = 64`
- `GlobalGraph::TOTAL_EDGES = 224`

### Critical Bug Fixes Applied

1. **`Set.hh:71`** — `INDEX_SHIFT = LONG_BITS >= 64 ? 6 : 5` (was `LONG_BITS == 64 ? 6 : 5`). Fixes bit overflow for MachineTypes with >32 controllers.

2. **`Router.hh/cc`** — `routingTableHasDest()` + `m_routing_table_mids`: Bypasses `NetDest::intersectionIsNotEmpty()` which only checks the first Set word. Pre-computes MachineID lists at `addOutPort()` time.

3. **`process.cc:407,455`** — gettid and tgkill syscall implementations for SE mode.

4. **`-c` absolute path requirement** — Benchmark binary path passed to `-c` must be absolute (e.g., `/home/siat/gem5-gpu-bak/benchmarks/...`). Relative paths cause `_dl_get_origin` assertion failure in simulated glibc during `readlink("/proc/self/exe")`.

5. **CUDA env vars for simulation** — Must export `CUDAHOME=/usr/local/cuda/cuda`, add `ptxas` to PATH, and set `LD_LIBRARY_PATH`. Without this, GPGPU-Sim PTX loader calls `exit(1)` when `ptxas` is not found.

### Flexible-Pipeline Components (24 files)

| File | Role |
|------|------|
| `Router.hh/cc` | Main router with XY DOR algorithm (PSO code retained but unused) |
| `PSOAlgorithm.hh/cc` | Particle Swarm Optimization engine (unused, kept for API compat) |
| `SwarmManager.hh/cc` | Multi-swarm collaboration (unused, kept for API compat) |
| `PerformanceAnalyzer.hh/cc` | Performance monitoring and power statistics |
| `NetworkUtilities.hh/cc` | Topology management and utilities |
| `GarnetNetwork.hh/cc` | Network controller, topology, direction-to-port mapping registration |

### Routing Decision Hierarchy

```
1. getRouteXY() → XY Dimension-Ordered Routing (primary)
2. Table Routing (fallback, if XY port mapping fails)
```

### XY Direction-to-Port Mapping Architecture

`getRouteXY(src, dest)` returns a logical direction (0=N, 1=E, 2=S, 3=W, -1=local), but physical output port indices are assigned by `addOutPort()` in a fixed order (external links first, then internal links sorted by dest switch ID). The `m_direction_to_port[5]` array bridges this gap:

- **`GarnetNetwork::makeOutLink()`** — registers external link as direction 4 (local)
- **`GarnetNetwork::makeInternalLink()`** — computes XY direction from `(dx, dy)` between src/dest router IDs and registers via `setDirectionPort()`
- **`Router::getRoute()`** — calls `getRouteXY()`, maps result through `m_direction_to_port[]`, verifies port is in routing table, falls back to table scan on failure

### Coding Conventions

- **Naming**: `snake_case` for variables, `CamelCase` for classes
- **Members**: `m_` prefix (e.g., `m_router_ptr`)
- **Statics**: `s_` prefix (e.g., `s_global_graph`)
- **C++11**: smart pointers, `auto`, range-based for, lambdas, move semantics

## Key Architecture

```
CPU Application (CUDA Runtime)
        ↓
   CudaGPU Interface
        ↓
   GPGPU-Sim Engine ←→ Ruby Memory System
        ↓                     ↓
   GPU Cores/Shaders     Cache Hierarchy (VI_hammer protocol)
        ↓                     ↓
   GPU Memory System ←→ CPU Memory System
```

### Integration Points

- `gem5-gpu/src/gpu/gpgpu-sim/cuda_gpu.hh` — CudaGPU main entry point
- `gem5-gpu/src/mem/protocol/` — VI_hammer coherence protocol
- `gem5-gpu/configs/se_fusion.py` — Primary simulation config
- `gpgpu-sim/` — GPU timing models, CUDA functional sim, GPUWattch power

### Benchmarks

Rodinia suite in `benchmarks/rodinia/`: backprop, bfs, cfd, kmeans, etc.
Build with `make -f Makefile.gem5-fusion`.

## 阶段性检查与确认前必须推送 GitHub

用户工作流程：**每次请用户检查阶段性成果或确认配置、范围等事项前，必须先提交并推送当前成果到 GitHub，核对远端提交，并提供可直接查看的链接。** 此规则也适用于实施中、部分验收通过或等待确认的检查点；提交与报告须明确未完成项，不把阶段性备份称为最终验收通过。

沿用下方 SSH Backup Workflow：先运行 `./push_all_repos.sh --check`；如检查指出工作区未提交或远端尚未同步，保留并报告该事实，再按已授权流程提交、依次推送嵌套仓库和父仓库，最后再次检查远端 SHA 与父仓 gitlink。不得强推覆盖远端。若推送失败，明确失败原因，不将未推送的本地状态当作已可供 GitHub 检查的成果。源码/二进制构建门禁继续约束后续实验；GitHub 备份不代表缺失测试已经通过。

## Push Workflow (Mandatory After Successful Build+Test)

**After any code change passes compilation AND benchmark tests, you MUST push before starting the next modification.** This ensures each change is versioned independently and can be rolled back cleanly.

### Step 1: Document what was changed

Before pushing, write a clear summary of:
- Which files were modified
- Why each modification was made
- What the expected effect is (e.g., routing behavior change, bug fix)

### Step 2: Run push_all_repos.sh

```bash
cd /home/siat/gem5-gpu-hetsub
./push_all_repos.sh --check
./push_all_repos.sh
```

The script uses `git@github-miuzujia` with
`~/.ssh/id_ed25519_miuzujia2018_stack`, pushes the five nested repositories
before the parent, and verifies every remote branch head after pushing.

| Repository | GitHub branch |
|---|---|
| `gem5-gpu-hetsub` parent | `synthetic-traffic-three-patterns` |
| central `gem5` | `gem5-gpu-hetsub` |
| `gem5-gpu`, `gpgpu-sim`, `Graphite` | `gem5-gpu-hetsub` |
| `benchmarks` | `gem5-gpu-hetsub` |

The parent `gem5` gitlink therefore opens the central `gem5` repository at
the `gem5-gpu-hetsub` branch. HTTPS, Gitee URLs, and embedded credentials are
not part of this workflow.

## Mandatory Clean-Build Provenance Gate (Highest Priority)

This section overrides any earlier build or manual-SCons guidance in this file.
Its purpose is to prevent an experiment from silently running a `gem5.opt`
that predates the active source tree.

- After any change under `gem5/`, `gem5-gpu/`, or `gpgpu-sim/` that can affect
  the simulator or a runtime configuration, do not run or accept an experiment
  until the corresponding verified Docker build succeeds.
- For `X86_VI_hammer_GPU`, use the repository's top-level official builder:
  `./docker_build_and_test_tbp.sh` in the TBP repository and
  `./docker_build_and_test_j64.sh` everywhere else.
- For `X86_Network_test`, use
  `./tools/reproduction/docker_build_network_test.sh`.
- The official builders must bind the current project tree explicitly, remove
  only the exact target build directory, perform a clean rebuild, record the
  source and binary SHA-256 credential, verify it, and then run the required
  tests. A failed build must not fall through to tests with an older binary.
- A direct `scons ... gem5.opt` command is diagnostic only. It does not satisfy
  this gate and must not be used to certify or publish experimental results.
- Before every simulator run, require
  `tools/reproduction/verify_gem5_build.sh verify <project-root> <build-name>`.
  `run.sh` and the supported Python entry configurations already enforce this.
  Missing or mismatched credentials are fatal (exit 42); rebuild instead of
  bypassing, editing, or manually re-recording the credential.
- If a new launcher or configuration invokes `gem5.opt`, it must call the same
  verifier before simulation. A custom unguarded entry point is not an
  authorized experimental path.
- Formal experiment metadata must retain the source fingerprint, binary hash,
  build target, build log, configuration, and command. Historical results that
  lack enough information to identify the binary must be labeled unverified
  rather than assumed to match the current source.
- Documentation-only changes outside the three fingerprinted source
  repositories do not require a simulator rebuild. Runtime configuration
  changes inside those repositories do invalidate the credential.

The local `.build_provenance/` credential directory is intentionally ignored
by Git; it is a runtime safety gate, not a replacement for committed source,
tracked experiment manifests, or preserved build/test evidence.
