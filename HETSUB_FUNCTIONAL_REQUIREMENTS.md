# HetSub 复现：功能需求与分阶段实施计划

> 目标：在 gem5-gpu / flexible-pipeline 平台上**最大程度**复现 HetSub 论文
> (Li et al., *IEEE TVLSI*, Vol. 33, No. 11, Nov. 2025) 的架构方法。
> 不要求 100% 位级一致，要求**机制可复现、趋势可验证、结论可对照**。
>
> 状态：进行中
> 最后更新：2026-09-16

---

## 0. 论文方法提取

### 0.1 论文一句话

HetSub 不是路由算法论文，是**架构级异构 Multi-NoC**：利用类脑 SNN 通信
"局部密集、全局稀疏"的特性，把 always-on 子网络降维成低 radix 的 dual-line
拓扑以降低静态功耗并避免序列化延迟，同时在低流量下复用 power-gated mesh
子网络的空闲物理链路构建可重构 long-range links。

### 0.2 组成（7 个部件）

| # | 部件 | 作用 | 论文位置 |
|---|---|---|---|
| C1 | Heterogeneous Multi-NoC | 两个功能分化的子网络 | Sec. III-A |
| C2 | Always-on dual-line 子网（R0） | 承载 local traffic，低 radix、1 VC、64-bit flit | Fig. 5(d) |
| C3 | PG mesh 子网（R1） | 承载 global traffic，radix 5、2 VC、32-bit flit、可 power-gate | Fig. 5(c) |
| C4 | Dynamic subnetwork selection | 按 buffer 占用阈值做 local/global 分流 + 动态比例 | Sec. III-A-2 |
| C5 | Reconfigurable long-range link | 复用 PG mesh 空闲物理链路 + crossbar bypass，hop≈1 | Sec. III-B-1 |
| C6 | NI relay | relay buffer + serialization 64→32 + deserialization 32→64 + MUX + 握手 | Sec. III-B-2 |
| C7 | Heuristic long-range link insertion | Hilbert 曲线分层插入 + traffic 阈值 + 冲突检查 + 2-hop 长度约束 | Sec. III-C |

### 0.3 关键参数（论文 Table I / Sec. IV-A）

| 参数 | 值 |
|---|---|
| PG wake-up time | 6 cycles |
| PG break-even time | 10 cycles |
| Warm-up time | 1000 cycles |
| 仿真时长 | 10000 cycles |
| R0 (dual-line) | 64-bit flit, packet 2 flits, buffer depth 4, **1 VC** |
| R1 (PG mesh) | 32-bit flit, packet 8 flits, buffer depth 4, **2 VC** |
| long-range link 物理长度上限 | 2D mesh 中 ≤ 2 hop |
| 每节点 long-link 上限 | 1 output + 1 input |

### 0.4 创新点（4 条）

1. **异构 Multi-NoC**：子网络功能分化（always-on 管 local / PG mesh 管 global），
   对比 Catnap 的同构子网络。
2. **low-radix dual-line 缓解序列化延迟**：靠降 radix 而非降 flit 宽度省静态功耗，
   总带宽不变 → 消除 Catnap 的 packet fragmentation。
3. **复用休眠子网作为 long-range shortcut**：不唤醒 PG router、不走完整 pipeline、
   不额外 ASIC 布线。
4. **硬件约束闭环**：RC delay、crossbar 冲突、死锁、ser/deser、PG 唤醒、RTL 面积。

### 0.5 论文结论（对照基准）

相对 Catnap：latency ↓38%、static power ↓58%、area ↓16%、long-link 额外面积 +6%。

---

## 1. 复现策略与工程映射

### 1.1 建模假设（必须在论文中显式声明）

| 论文概念 | gem5-gpu 落地方式 | 理由 |
|---|---|---|
| SNN spike 通信 | VI_hammer cache coherence 消息 | 平台承载的是协议消息，无 spike 语义 |
| **local / global packet** | 按**源-目的 Hilbert 距离**分类（阈值可配） | 论文 locality 的可实现代理；Hilbert 距离本身就是论文的 locality 度量 |
| packet 拆分成 flit | `NetworkInterface::flitisizeMessage()` 的 message_size / flit_width | 与论文 serialization 机制同构 |
| dual-line 物理拓扑 | **Hilbert 曲线本身即 dual-line**：沿 Hilbert 序 ±1 的前后邻居构成两条反向线 | 论文正是用 Hilbert 曲线做 1D dual-line ↔ 2D mesh 映射，复用该映射即忠实 |
| crossbar bypass | flit 不经 VC 分配/缓冲，直接投递到目标 router 输入 | 论文 C5 的核心 |

### 1.2 架构设计意图（P2 核心）

保留 8×8 mesh 物理链路，引入**子网维度**：

```
子网 1 (always-on, dual-line 语义)
  可用方向 = {Hilbert 前驱, Hilbert 后继, local}   → radix 3
  VC 数    = 1
  flit 宽度 = 64 bit
  功耗状态  = always-on

子网 2 (PG mesh)
  可用方向 = {N, E, S, W, local}                  → radix 5
  VC 数    = 2
  flit 宽度 = 32 bit
  功耗状态  = 可 power-gate
```

这直接复现论文的三个核心量化效应：**radix 降低**（3 vs 5）、**VC 减半**（1 vs 2）、
**flit 宽度差异导致的序列化开销**。

### 1.3 基线保护原则（硬约束）

> **所有 HetSub 功能默认关闭。** 新增 SimObject 参数一律默认 `False` / 论文默认值
> 之外的保守值。关闭时，网络行为必须与当前 XY DOR baseline **逐字节一致**
> （`m5out/synth/results.csv` 的 MD5 不变）。

理由：当前 `synthetic-traffic-three-patterns` 分支的 21-case 结果是另一篇论文的
对照基线，不能被破坏。每次修改后都要做回归验证。

---

## 2. 分阶段实施计划

每个阶段给出：**目标 / 改动范围 / 验收标准 / 放宽条件**。
验收标准刻意不做成硬性 CI 门禁——这是科研任务，允许在工程中调整；
但**每一条都必须留下可复查的证据**（stats 数值、日志、CSV、图）。

---

### P0 — 可观测性基线

**目标**：为后续所有阶段提供测量能力。没有测量就没有验收。

**改动范围**（`flexible-pipeline/` 内）
- `Router.cc/.hh`：新增每 router 统计
- `NetworkInterface.cc/.hh`：新增注入/弹出统计
- `GarnetNetwork.cc/.hh`：新增子网级聚合统计

**新增统计量**
| 统计量 | 含义 |
|---|---|
| `router_buffer_occupancy` (Vector) | 每 router buffer 占用时间积分 |
| `router_sleep_cycles` (Vector) | P1 用，先占位 |
| `flits_injected_per_subnet` / `flits_ejected_per_subnet` | 子网级流量 |
| `packets_local` / `packets_global` | 按 Hilbert 距离分类的包计数 |
| `hop_count_hist` (Histogram) | 跳数分布 |
| `serialization_latency` / `queueing_latency` / `route_latency` | 延迟分解 |

**验收标准**
1. `./docker_build_and_test_j64.sh` 通过（backprop + kmeans 无崩溃）。
2. 跑一次 3-pattern sweep，上述统计量出现在 `stats.txt` 中且非全零。
3. **回归**：`m5out/synth/results.csv` 与改动前 MD5 一致。
4. `packets_local + packets_global == 总包数`。

**放宽条件**
- 延迟分解可先只做 serialization + queueing，`route_latency` 允许先并入 queueing。
- `hop_count_hist` 若与现有 `averageHopCount` 冲突，可先复用现有字段。

---

### P1 — Power Gating 建模

**目标**：复现论文 C3 的功耗状态机，为静态功耗结论提供依据。

**改动范围**
- `Router.cc/.hh`：sleep/active 状态机 + 空闲检测 + 唤醒延迟
- `DSENTIntegration.cc/.hh`：接入 PG 静态功耗记账（或新增独立记账）
- `GarnetNetwork.py`：新增参数

**新增参数**（`GarnetRouter` 经 `Parent.` 继承自 `GarnetNetwork`）
```python
enable_power_gating   = Param.Bool(False, ...)   # 默认关闭
pg_wakeup_cycles      = Param.UInt32(6, ...)     # 论文 6 cycles
pg_breakeven_cycles   = Param.UInt32(10, ...)    # 论文 10 cycles
pg_idle_threshold     = Param.UInt32(..., ...)   # 连续空闲多久进入 sleep
pg_static_power_mw    = Param.Float(..., ...)    # 单 router active 静态功耗
```

**机制**
1. Router 维护 `ACTIVE / SLEEP / WAKING` 三态。
2. 连续 `pg_idle_threshold` 周期无 flit 经过 → 进入 `SLEEP`。
3. 有 flit 需要转发时 → `WAKING`，经 `pg_wakeup_cycles` 后才能转发（**该延迟要真实
   加到 flit 时间戳上**，这是论文 latency 惩罚的来源）。
4. 累计 sleep 时间 < `pg_breakeven_cycles` 时不计入节能（避免频繁开关的负收益）。
5. 静态功耗：`SLEEP` 时接近 0（保留小泄漏），`ACTIVE/WAKING` 时全额。

**验收标准**
1. 构建 + benchmark 通过。
2. `enable_power_gating=True` 时，低注入率下**存在 router 进入 SLEEP**
   （`router_sleep_cycles > 0` 的 router 数 > 0）。
3. sleep 占比随注入率**单调下降**（至少 0.01 vs 0.15 两点满足）。
4. 开启 PG 后低负载 latency **略有上升**（唤醒延迟代价），高负载 latency 变化不显著。
5. 静态能量统计随注入率下降而下降。
6. **回归**：`enable_power_gating=False` 时结果与 baseline 一致。

**放宽条件**
- 功耗绝对值不要求与论文一致（论文是 SMIC 55nm 综合结果），只要求**相对趋势正确**。
- `pg_idle_threshold` 可先取经验值（如 50 cycles）后调参，不要求理论最优。

---

### P2 — 异构双子网（Heterogeneous Multi-NoC）

**目标**：复现论文 C1 + C2 + C3 的架构核心。**这是最关键也最重的一步。**

**改动范围**
- `flit.hh/.cc`：新增 `m_subnet` 字段（0=dual-line, 1=mesh）
- `Router.cc/.hh`：子网感知的 buffer / VC / 路由 / 仲裁
- `NetworkInterface.cc/.hh`：注入时决定子网
- `GarnetNetwork.cc/.hh`：双路由表、双方向映射
- `GarnetNetwork.py`：新增参数

**新增参数**
```python
enable_het_subnet     = Param.Bool(False, ...)
dual_line_vcs         = Param.UInt32(1, ...)    # 论文 R0 = 1 VC
mesh_vcs              = Param.UInt32(2, ...)    # 论文 R1 = 2 VC
dual_line_flit_bytes  = Param.UInt32(8, ...)    # 64-bit
mesh_flit_bytes       = Param.UInt32(4, ...)    # 32-bit
```

**机制**
1. 用 Hilbert 序为 64 节点建立 1D 顺序；节点 i 的 dual-line 邻居 = Hilbert 序 ±1 的节点。
2. 子网 1 的路由只允许朝 Hilbert 前驱/后继 + local 三个方向（radix 3）。
3. 子网 2 保持完整 XY DOR（radix 5）。
4. VC 资源按子网隔离：子网 1 用 1 个 VC，子网 2 用 2 个。
5. flit 宽度按子网区分 → 同一 message 在子网 1 产生更少 flit（复现序列化差异）。
6. 死锁：子网 1 沿 Hilbert 序严格单调（Hilbert 距离递减），单 VC 安全；
   子网 2 用 XY DOR，各自独立无环。

**验收标准**
1. 构建 + benchmark 通过，**无死锁**（backprop/kmeans 正常结束）。
2. `enable_het_subnet=True` 时，两个子网都有非零流量统计。
3. 子网 1 的 VC 数为 1 且不出现 VC 饥饿导致的死锁或超时。
4. 同一 message 在两个子网的 flit 数比值 ≈ flit 宽度反比（8/4 = 2×）。
5. 低负载下子网 1 承载**主要**流量（占比 > 50%）。
6. **回归**：`enable_het_subnet=False` 时结果与 baseline 一致。

**放宽条件**
- 若双路由表改造风险过高，允许先做**单路由表 + 方向掩码**的简化实现
  （子网 1 用掩码屏蔽非 Hilbert 方向），只要验收标准 2/5 仍满足。
- 允许 P2 先不实现 flit 宽度差异（并入 P5 与 relay 一起做），
  此时验收标准 4 延后到 P5 判定。

---

### P3 — 动态子网选择策略

**目标**：复现论文 C4。

**改动范围**
- `Router.cc/.hh`：拥塞信号生成/清除
- `NetworkInterface.cc/.hh`：注入决策 + 动态比例
- `GarnetNetwork.cc/.hh`：全局拥塞信号广播（或按节点局部）

**机制**
1. 每 router 跟踪各端口 buffer 占用。
2. 总占用 > `hi_threshold` → 置 congestion signal；< `lo_threshold` → 清除（滞回）。
3. 分类：Hilbert 距离 ≤ `local_radius` → local packet；否则 global packet。
4. 注入决策：
   - 无拥塞 → 全部进子网 1
   - 子网 1 拥塞 → local 仍优先进子网 1；global 按比例 `r` 进子网 2
   - 子网 1 拥塞 ↑ → `r` ↑；子网 2 拥塞 ↑ → `r` ↓
5. 比例调整要平滑（避免震荡）。

**验收标准**
1. 低注入率：global packet 进子网 2 的比例 ≈ 0。
2. 注入率升高到子网 1 拥塞后：该比例**单调上升**。
3. 子网 2 也拥塞时：比例回落（滞回生效）。
4. local/global 分离度随注入率提高而提高（对照论文 Fig. 14 趋势）。
5. 不出现比例震荡（相邻采样点变化幅度有界）。

**放宽条件**
- 允许先实现"全局统一比例"而非"每节点独立比例"。
- 阈值可经验设定后调参，不要求复现论文的最优阈值。
- 验收标准 4 只要求**趋势方向正确**，不要求数值接近论文。

---

### P4 — Reconfigurable Long-Range Link + crossbar bypass

**目标**：复现论文 C5，这是论文最有辨识度的创新。

**改动范围**
- `Router.cc/.hh`：long-link 表、bypass 投递路径
- `NetworkInterface.cc/.hh`：long-link 注入/弹出
- `GarnetNetwork.cc/.hh`：long-link 注册与冲突检查

**机制**
1. Router 维护 `m_long_links[dest_router] = out_port`。
2. 命中 long-link 的 flit **不经过 VC 分配、不占 buffer**，直接投递到目标 router 的输入。
3. long-link 复用子网 2 的物理链路：仅当子网 2 处于 SLEEP 时该链路可用作 shortcut。
4. 每个节点 ≤ 1 output + 1 input long-link（论文约束）。
5. hop count 计为 1（而非物理经过的 router 数）。
6. **死锁规则**（论文 Algorithm 1）：只有当 long-link 的目标节点位于
   `当前节点 → 最终目的节点` 的路径上时才允许使用；否则退回普通转发。

**验收标准**
1. 构建 + benchmark 通过，**无死锁**。
2. 开启 long-link 后，低注入率（0.01–0.05）下 global packet 平均 latency **下降**。
3. 高注入率（≥0.12）下收益**递减**甚至消失（对照论文 Fig. 15/17）。
4. long-link 上的 flit 确实绕过了 VC/buffer（可通过统计计数验证）。
5. 关闭时结果与 baseline 一致。

**放宽条件**
- 允许 long-link 的物理长度约束先放宽到 ≤ 3 hop 再收紧到 2 hop。
- 若"复用 sleep 链路"实现复杂，允许先做**固定配置的 long-link**（等价论文的
  global configuration 静态配置阶段），动态启用留待 P6。
- 验收标准 3 只要求"高负载收益不优于低负载"，不要求出现负收益。

---

### P5 — NI Relay（serialization / deserialization）

**目标**：复现论文 C6。

**改动范围**
- `NetworkInterface.cc/.hh`：relay buffer、MUX、ser/deser、握手
- `flit.hh/.cc`：可能需要宽度标记
- `GarnetNetwork.py`：relay 相关参数

**机制**
1. NI 增加 relay buffer（跨子网中转）。
2. 子网 1 → 子网 2：64-bit flit 拆成 2 个 32-bit flit（serialization）。
3. 子网 2 → 子网 1：2 个 32-bit 合并为 1 个 64-bit（deserialization）。
4. MUX 由 PG 信号控制选择 relay 路径。
5. send/recv 握手 + round-robin 仲裁。
6. 每节点支持 1 output long-link + 1 input long-link。

**验收标准**
1. 构建 + benchmark 通过。
2. 跨子网 packet 的 flit 数符合 ser/deser 规则（子网 2 中 flit 数 = 2× 子网 1）。
3. 统计上可观测到 ser/deser 引入的额外延迟。
4. relay buffer 不出现死锁/溢出。
5. 关闭时结果与 baseline 一致。

**放宽条件**
- 允许用**延迟模型**而非真实 buffer 拷贝来实现 relay（只要能观测到额外延迟）。
- 若 ser/deser 与 P2 的 flit 宽度实现冲突，允许合并设计。

---

### P6 — Hilbert 启发式插入算法 + 死锁规则闭环

**目标**：复现论文 C7，把 P4 的 long-link 从静态配置升级为算法生成。

**改动范围**
- 新增 `HilbertInsertion.cc/.hh`（flexible-pipeline 内）
- `GarnetNetwork.cc/.hh`：调用插入算法、注册结果
- `GarnetNetwork.py`：阈值参数

**机制（论文 Algorithm 2）**
```
Links = []
for level = 1 .. order:
    n = 4^(level-1)
    parts = 把 tile 按 Hilbert 序分成 n 个 U-shaped part
    for part in parts:
        for (i, j) in {1,2,3,4}×{1,2,3,4}:
            if |i - j| <= 1: continue          # 相邻太短，ser/deser 抵消收益
            if link(i,j) 与 Links 冲突: continue
            if Traffic(p_i, p_j) > Threshold:
                Links[level] += (i, j)
```
- 高层优先（跨越距离更长，收益更大）
- 物理长度约束：≤ 2 hop
- 最低层（2×2）不插
- 每节点 ≤ 2 个 in/out long-link
- 流量统计来自 P0 的测量（或用 Hilbert 距离分布近似）

**验收标准**
1. 算法能对 8×8 输出一个非空且满足所有约束的 long-link 集合。
2. 约束检查通过：长度 ≤ 2 hop、无 crossbar 冲突、每节点度数 ≤ 2。
3. 插入 long-link 后，低注入率 latency 改善（对照 P4 的手动配置）。
4. 前 2 条 long-link 的边际收益 > 后续 long-link（对照论文 Fig. 17）。
5. 高注入率下收益递减。
6. 无死锁，benchmark 通过。

**放宽条件**
- traffic 统计允许用**离线 profile**（先跑一次 baseline 收集，再静态插入），
  不要求在线自适应。
- 允许先用 Hilbert 距离分布代替真实 traffic 作为阈值判据。
- 验收标准 4 只要求"边际收益递减"的定性趋势。

---

## 3. 全局约束

### 3.1 代码约束（继承 CLAUDE.md）
- 主工作目录：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- 允许：修改该目录下 .cc/.hh/.py，新建文件
- 禁止：修改该目录外的文件、建子目录、建 .bak
- **不修改既有 public 方法签名**，只做增量扩展
- 不删除既有 PSO/MVPP 代码（即使已死）

### 3.2 验证约束
- 每次代码改动后必须跑 `./docker_build_and_test_j64.sh`
- 每次跑完必须做 baseline 回归（`results.csv` MD5）
- 通过后按 `push_all_repos.sh` 流程推送

### 3.3 科研诚实性约束
- 论文/报告中必须区分**实测数据**与**建模假设**
- 必须显式声明第 1.1 节的建模假设
- 不得把论文的绝对数值（38%/58%/16%）宣称为本复现的结果
- 只宣称本平台实测得到的相对趋势

---

## 4. 风险与降级方案

| 风险 | 影响 | 降级方案 |
|---|---|---|
| 双子网改造破坏死锁无关性 | benchmark 挂起 | 退回"单路由表 + 方向掩码"简化实现 |
| flit 宽度差异牵动协议层 | 编译/功能错误 | 用**延迟模型**代替真实宽度变化 |
| PG 唤醒延迟导致 benchmark 超时 | 无法验收 | 降低 `pg_wakeup_cycles` 或只对空闲 router 生效 |
| long-link 绕过 buffer 破坏 VC 记账 | 断言失败 | 保留一个 dummy VC 占位，只跳过 buffer 写入 |
| 改动范围超出 flexible-pipeline | 违反约束 | 通过 `GarnetNetwork.py` 暴露参数，不改外部配置 |
| 复现进度不足 | 论文无法支撑 | 按 P0→P1→P2 优先级交付，每阶段独立可写 |

### 优先级（若时间不足）
```
P0 (测量) > P1 (PG) > P2 (双子网) > P4 (long-link) > P3 (选择策略) > P5 (relay) > P6 (插入算法)
```

---

## 5. 进度追踪

| 阶段 | 状态 | 验收证据 |
|---|---|---|
| P0 可观测性基线 | 未开始 | — |
| P1 Power Gating | 未开始 | — |
| P2 异构双子网 | 未开始 | — |
| P3 动态子网选择 | 未开始 | — |
| P4 Long-Range Link | 未开始 | — |
| P5 NI Relay | 未开始 | — |
| P6 Hilbert 插入算法 | 未开始 | — |

---

## 6. 与既有资产的关系

- 仓库 `/home/siat/gem5-gpu-HetSub` 中的 "HetSub-inspired Hilbert-curve routing (Phase 1)"
  是一个**逐跳贪心路由算法**，与论文把 Hilbert 曲线用于**链路放置映射**的用法不同。
  本计划**不沿用**该实现，但其 `HILBERT_ORDER[64]` 表可复用于 P2 的 dual-line 映射。
- 现有 `m5out/synth/results.csv`（21 case，XY DOR baseline）是**对照基准**，
  所有阶段的对比都以此为参照。
