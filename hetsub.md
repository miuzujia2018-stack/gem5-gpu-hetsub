# HetSub 论文专家分析

**论文题目**：HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems  
**期刊**：IEEE Transactions on Very Large Scale Integration (VLSI) Systems, Vol. 33, No. 11, 2025  
**研究对象**：面向 neuromorphic systems / SNN 类脑计算硬件的低功耗 NoC 架构  
**核心关键词**：Network-on-Chip, Multi-NoC, Power Gating, Heterogeneous Subnetwork, Reconfigurable Long-Range Link, Neuromorphic Computing, Static Power

---

## 1. 一句话总结

这篇论文提出了 **HetSub**，一种面向类脑计算系统的 **异构 Multi-NoC 架构**。它利用 SNN 通信中“局部密集、全局稀疏”的特性，将 always-on 子网络改成低 radix 的 dual-line 拓扑以降低静态功耗和避免传统 Multi-NoC 的序列化延迟；同时在低流量下复用 power-gated mesh 子网络中的空闲物理链路，构建可重构 long-range links，以减少远距离通信延迟。

论文的核心不是提出一个新路由算法，而是提出一个 **workload-aware 的 NoC 架构级优化方案**。

---

## 2. 研究背景

### 2.1 类脑计算对 NoC 的依赖

Neuromorphic computing 通过大规模分布式神经元核心模拟 SNN。每个神经元核心之间需要传输 spike，因此 NoC 是类脑芯片的重要通信基础设施。相比总线结构，NoC 能够支持更好的多核扩展性，但 router、buffer、crossbar 和 physical link 也带来了明显功耗和面积开销。

### 2.2 静态功耗问题越来越突出

传统 NoC 功耗包括：

- **动态功耗**：来自信号翻转、flit 传输、crossbar switching 等；
- **静态功耗**：来自 transistor leakage，尤其是 buffer 和 router storage 的泄漏功耗。

随着工艺缩小，静态功耗占比不断上升。SNN 的事件驱动和 spike 稀疏性虽然可以减少动态功耗，但这反而使静态功耗占比更加突出。因此，类脑 NoC 不能只优化动态功耗，还需要专门降低 idle router、buffer 和 link 带来的静态功耗。

### 2.3 类脑通信具有 locality

论文强调 neuromorphic workload 的两个重要特征：

1. **Sparsity**：spike 事件稀疏，通信并不是持续满负载；
2. **Locality**：连接模式通常是局部密集、全局稀疏，即相邻神经元或相邻层之间通信多，远距离通信少。

这一点是 HetSub 的架构基础。作者认为：既然大部分通信是局部的，就没有必要让所有通信都通过高 radix、高静态功耗的 mesh always-on 子网络完成。

---

## 3. 研究问题

论文要解决的问题可以表述为：

> 在类脑计算系统中，如何在保持通信性能的同时，降低 NoC 的静态功耗，并避免传统 PG + Multi-NoC 架构带来的序列化延迟和网络利用率低的问题？

具体包括四个子问题：

### 3.1 静态功耗问题

类脑系统中 spike traffic 稀疏，很多 router 和 buffer 长时间低利用，但仍然产生 leakage power。传统 NoC 中大量 always-on 资源造成静态功耗浪费。

### 3.2 Power Gating 的唤醒延迟问题

Power gating 可以关闭空闲 router，降低静态功耗。但 PG router 被重新唤醒需要 wake-up time，论文中建模为 6 cycles；并且 power-down / wake-up 过程有额外 energy overhead，break-even time 设为 10 cycles。频繁 sleep/wake-up 不但不能省电，反而会增加延迟和能耗。

### 3.3 Homogeneous Multi-NoC 的序列化问题

Catnap 这类方法把一个 NoC 拆成多个结构相同、带宽降低的子网络。这样可以让部分子网络进入 PG，但由于每个子网络的 link width 变窄，packet 需要拆成更多 flits，引入 serialization latency。

例如，原本 2 个 64-bit flit 的 packet，在 32-bit 子网络中可能变成 4 个 32-bit flit，带来额外周期和更长的带宽占用时间。

### 3.4 低 radix 拓扑的远距离通信问题

HetSub 用 dual-line 低 radix 子网络降低功耗，但低 radix 拓扑的网络直径更大。远距离 global packet 如果一直走 dual-line，会经历更多 hop，导致延迟升高、链路占用变长、甚至触发拥塞。因此需要额外机制处理 sparse global traffic。

---

## 4. 过去方法的局限性

### 4.1 TrueNorth、Loihi、Darwin3 等类脑 NoC：偏重动态功耗

已有类脑芯片通常使用 clockless asynchronous circuit、clock gating、GALS 等方法降低动态功耗。这些方法适合 spike 稀疏传输，但对静态漏电功耗的处理不足。

局限性：

- 主要降低动态功耗；
- router / buffer 静态功耗仍然存在；
- 当 spike activity 很低时，静态功耗可能成为主导。

### 4.2 Ring / segmented bus 等低复杂度互连：扩展性不足

低 radix ring 或 segmented-bus 可以降低面积和功耗，但全局通信代价高，难以支撑大规模类脑系统。

局限性：

- ring 直径随节点数线性增长；
- global packet 延迟高；
- segmented bus 对全局通信不友好；
- 更适合特定 mapping 或 converted SNN，不够通用。

### 4.3 PG + Multi-NoC：有节能潜力，但存在延迟和利用率问题

Catnap 是代表性方法：把 NoC 分成多个同构子网络，第一层子网络 always-on，其余子网络使用 PG。低负载时只使用 always-on 子网络，高负载时唤醒更多子网络。

局限性：

1. **serialization latency**：子网络带宽降低，packet 被拆成更多 flit；
2. **homogeneous subnetwork 不匹配类脑 locality**：所有子网络结构相同，没有区分 local/global traffic；
3. **always-on 子网络利用率低**：类脑通信稀疏时，homogeneous high-radix 子网络仍然消耗较高静态功耗；
4. **PG wake-up penalty**：拥塞或突发通信会触发 PG router 唤醒，增加延迟和能耗。

---

## 5. HetSub 方法组成

HetSub 主要由以下部分组成：

| 组成部分 | 功能 |
|---|---|
| Heterogeneous Multi-NoC | 将传统同构 Multi-NoC 改为异构子网络结构 |
| Always-on dual-line subnetwork | 承载主要 local traffic，降低 radix、VC、buffer 和静态功耗 |
| PG mesh subnetwork | 低优先级子网络，必要时承载 global traffic |
| Dynamic subnetwork selection | 根据拥塞状态动态决定 local/global packet 注入哪个子网络 |
| Reconfigurable long-range link | 低流量下复用休眠 mesh 的物理链路作为 shortcut |
| Heuristic long-range link insertion | 基于 Hilbert space-filling curve 和 traffic threshold 插入 shortcut |
| Deadlock-free routing rule | 限制 shortcut 使用条件，避免 long-range link 破坏死锁安全 |

---

## 6. HetSub 架构结构

### 6.1 总体结构

HetSub 不是单一 NoC，而是两个子网络构成的 heterogeneous Multi-NoC：

| 子网络 | 状态 | 拓扑 | 作用 |
|---|---|---|---|
| Subnetwork 1 | Always-on | Dual-line / low-radix | 主要承载 local traffic |
| Subnetwork 2 | Power-gated | 2D mesh | 拥塞时承载 global traffic |
| Long-range link | 复用 PG mesh 物理链路 | Shortcut | 低流量下减少远距离通信延迟 |

其核心思想是：

> 本地通信用轻量 always-on 子网络；远距离通信在必要时才使用 PG mesh；低流量时不唤醒 mesh router，而是复用其物理链路构建 shortcut。

### 6.2 Dual-line always-on 子网络

传统 Catnap 的 always-on 子网络仍是 mesh，只是带宽减半。HetSub 改成 dual-line 结构。

Dual-line 的特点：

- 两条方向相反的线性路径；
- 每个节点连接度低；
- router radix 小；
- arbitration 请求少；
- 可以用 1 个 VC 保持死锁安全；
- buffer 和 control logic 开销低。

论文用 **两个 64-bit 端口的 dual-line 子网络** 替代 **四个 32-bit 端口的 mesh 子网络**，在总带宽近似保持不变的条件下避免 packet 过度拆分，从而降低 serialization latency。

### 6.3 PG mesh 子网络

Subnetwork 2 保留 2D mesh。它不是一直工作，而是在低流量时进入 PG 状态。当 always-on 子网络接近拥塞时，global packet 会按比例进入 Subnetwork 2。

保留 mesh 的原因是：

- mesh 直径比 ring / line 更小；
- 更适合 global communication；
- 可以弥补 dual-line 远距离路径长的问题。

### 6.4 Dynamic subnetwork selection policy

该策略有两个目标：

1. 将 local packet 和 global packet 分离，提高 dual-line 子网络中的通信 locality；
2. 尽量延长 PG 子网络的连续 idle time，减少频繁 wake-up。

工作方式如下：

- 低负载时，所有 packet 都进入 Subnetwork 1；
- Subnetwork 1 接近拥塞时，开始 packet separation；
- local packet 优先进入 Subnetwork 1；
- global packet 按动态比例进入 Subnetwork 2；
- Subnetwork 1 拥塞会提高 global packet 进入 Subnetwork 2 的比例；
- Subnetwork 2 拥塞会降低 global packet 进入 Subnetwork 2 的比例。

拥塞检测基于 router port buffer usage。当 buffer usage 超过阈值时产生 congestion signal；当 buffer usage 低于另一个阈值时清除 congestion signal。

### 6.5 Reconfigurable long-range link

低流量时，Subnetwork 2 的 router 处于 sleep 状态。HetSub 利用这些 idle physical links 和 crossbar 构建静态 shortcut。

关键点：

- 不唤醒 PG router；
- crossbar 增加 global configuration；
- input port 到 crossbar 增加 bypass path；
- 绕过 VC、buffer、RC、SA；
- PG router 只作为物理连接路径；
- long-range link 的 hop count 近似被压缩为 1 hop。

这部分是论文最有特色的设计：

> 传统方法把 PG 子网络视为关闭资源；HetSub 把 PG 子网络中的空闲 physical links 作为 shortcut 资源复用。

### 6.6 Relay mechanism in NI

由于 Subnetwork 1 和 Subnetwork 2 的 flit width 不同，NI 中需要 relay 机制进行跨子网络传输。

新增模块包括：

- relay buffer；
- serialization module；
- deserialization module；
- MUX；
- send / receive handshake；
- round-robin arbitration；
- local port relay path。

每个节点可以同时支持：

- 一个 output long-link；
- 一个 input long-link。

### 6.7 Deadlock-free routing

Dual-line + DOR 本身可以用 1 个 VC 保持死锁安全。但 long-range link 会引入新路径，可能打破 DOR 的单调性，造成 cyclic dependency。

论文的解决方法是限制 shortcut 使用条件：

> 只有当 long-range link 的目标节点位于当前节点到 packet 最终目的节点的路径上时，packet 才能使用该 shortcut。

这样可以恢复路径方向一致性，不需要额外 VC，也不需要复杂死锁检测逻辑。

---

## 7. Long-range link 插入算法

### 7.1 问题背景

传统 long-range link insertion 通常根据通信频率和物理距离，在通信频繁且路径较远的节点之间插入 shortcut。但 HetSub 的情况更复杂：

1. dual-line 是 1D 拓扑，mesh 是 2D 拓扑，需要考虑 1D 到 2D 的物理映射；
2. shortcut 经过多个 sleep router 的 crossbar bypass，路径过长会引起 RC delay；
3. crossbar 静态配置可能产生路径冲突；
4. 过多 shortcut 会增加复杂度，也可能在高负载下产生反效果。

### 7.2 Hilbert space-filling curve

论文采用 Hilbert space-filling curve 将 1D dual-line 映射到 2D mesh。

优点：

- 保持 locality；
- 1D 上相近的节点在 2D 空间中也尽量相近；
- 具有分形和层次结构；
- 有利于分层插入 shortcut。

### 7.3 RC delay 约束

长距离 wire 会带来明显 RC delay，影响时钟频率和时序收敛。论文没有采用大量 repeater 或 pipeline，因为这些会增加面积、功耗和绝对延迟。

作者采用更保守的方案：

> 限制 long-range link 的物理长度，使其在 2D mesh 中不超过 2 hop。

这降低了灵活性，但更符合低功耗硬件设计目标。

### 7.4 启发式分层插入

算法流程可以概括为：

1. 基于 Hilbert curve 将节点划分成不同层级的 U-shaped parts；
2. 对每个 U-shaped part 再划分为 4 个 subparts；
3. 枚举 subpart 之间的候选 shortcut；
4. 排除相邻 subparts，因为距离太短时 serialization overhead 可能抵消收益；
5. 检查是否与已有 long-range link 冲突；
6. 统计候选 subparts 之间 traffic；
7. 如果 traffic 超过 threshold，则插入 shortcut；
8. 高层 shortcut 优先，因为它们跨越的通信距离更长，收益更大。

### 7.5 算法性质

该算法不是全局最优优化，而是硬件友好的启发式方法。

优点：

- 复杂度低；
- 物理路径受控；
- 考虑 crossbar conflict；
- 适合静态或准静态配置。

缺点：

- threshold 设置依赖经验；
- 不保证全局最优；
- 对 workload mapping 敏感；
- 高注入率下收益下降，甚至可能产生反效果。

---

## 8. 主要创新点

### 8.1 异构 Multi-NoC 架构

过去 Catnap 类方案是 homogeneous Multi-NoC。HetSub 的创新在于将子网络功能分化：

- always-on 子网络专门服务 local traffic；
- PG mesh 子网络专门服务 global traffic；
- long-range link 低流量下复用 idle physical links。

这是一种 workload-aware architecture，不是简单的资源关闭。

### 8.2 用低 radix dual-line 缓解序列化延迟

Catnap 通过降低每个子网络带宽换取 PG，但造成 packet fragmentation。HetSub 通过 dual-line 拓扑降低 router radix，使 always-on 子网络可以保持更宽 flit，从而避免部分 serialization latency。

### 8.3 复用休眠子网络作为 long-range shortcut

这是论文最具辨识度的创新。它将 PG mesh 子网络中的 idle physical links 和 crossbar 作为静态 shortcut 使用，不唤醒 router，不走完整 routing pipeline。

这使 long-range link 不再需要大量额外 ASIC 布线，而是利用已有 Multi-NoC 资源。

### 8.4 将硬件约束纳入架构设计

论文不仅提出 shortcut 概念，还考虑了：

- RC delay；
- crossbar conflict；
- deadlock-free routing；
- serialization / deserialization；
- PG wake-up latency；
- buffer storage overhead；
- RTL synthesis area。

这使该工作比纯算法型 NoC 路由优化更接近实际硬件实现。

---

## 9. 硬件实现

### 9.1 实现平台

论文将所有 router designs 用 Verilog HDL 实现，并使用 Synopsys Design Compiler 基于 SMIC 55-nm 工艺库综合。

综合设置：

- 工艺库：SMIC 55 nm；
- corner：SS, slow nMOS and slow pMOS；
- 电压：standard V threshold；
- 时钟约束：200 MHz；
- 大型存储组件如 flit buffer 使用 memory compiler 生成。

### 9.2 Router 级改动

HetSub 的 router 改动包括：

1. **Always-on router R0 简化**  
   - 低 radix dual-line；
   - input port 数量减少；
   - VC 数量减少；
   - RC / VA / SA 逻辑简化；
   - crossbar 更小。

2. **PG mesh router R1 保留完整 mesh 能力**  
   - 用于 global traffic；
   - 支持 power gating；
   - 在低负载时可保持 sleep。

3. **long-range link 相关改动**  
   - crossbar 增加 global configuration；
   - 增加 bypass path，使 input port 可直接连到 crossbar；
   - crossbar 需要位于 PG domain 之外，或至少保持可用于静态物理连接；
   - routing algorithm 需要识别 long-link port；
   - PG sleep 状态下仍允许作为物理通路。

### 9.3 NI 级改动

NI 是 HetSub 中硬件改动较多的地方。新增或修改包括：

- tile 到两个子网络的 MUX；
- relay buffer；
- serialization module，64-bit flit 转 32-bit flit；
- deserialization module，32-bit flit 合并回 64-bit flit；
- send / receive handshake；
- round-robin arbitration；
- long-range link injection / ejection 控制；
- congestion signal 接收与 subnetwork selection。

### 9.4 控制逻辑改动

新增控制逻辑包括：

- buffer usage based congestion detection；
- subnetwork selection policy；
- global packet / local packet 判断；
- dynamic injection ratio 调整；
- long-range link availability 判断；
- deadlock-free shortcut 使用规则。

### 9.5 电源域相关改动

HetSub 对 PG 电源域提出了额外要求：

- PG router 的主要 buffer 和控制逻辑可以 sleep；
- crossbar 或 bypass connection 需要在 sleep 时仍可作为静态通路；
- PG signal 需要控制 NI MUX，使 packet 可以进入 relay path；
- 如果采用真正 ASIC 实现，需要仔细处理 always-on domain 和 PG domain 的边界。

论文对此有架构级描述，但没有给出完整后端电源域验证。

---

## 10. 硬件消耗与面积数据

论文 Table II 给出了面积综合结果，单位为 μm²。

### 10.1 总面积对比

| 架构 | 总面积 μm² | 相对 Catnap |
|---|---:|---:|
| Single-NoC | 63,693.00 | -14.56% |
| Catnap | 74,543.84 | baseline |
| HetSub | 62,040.16 | -16.77% |
| HetSub-Longlink | 66,116.12 | -11.31% |

论文正文概括为：

- HetSub 相比 Catnap 面积节省约 **16%**；
- long-range link 可重构机制额外增加约 **6%** 面积。

从表中计算，HetSub-Longlink 相比 HetSub 的面积增加为：

\[
\frac{66116.12 - 62040.16}{62040.16} \approx 6.57\%
\]

### 10.2 关键模块面积

| 模块 | Single-NoC R0 | Catnap R0 | Catnap R1 | HetSub R0 | HetSub R1 | HetSub-Longlink R0 | HetSub-Longlink R1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Input Port / VC | 35087.08 | 22148.00 | 22148.84 | 11042.64 | 22148.84 | 11154.00 | 22148.84 |
| VC | 27831.72 | 14895.16 | 14895.16 | 9166.92 | 14895.16 | 9166.92 | 14895.16 |
| RC | 1632.68 | 1655.92 | 1655.92 | 646.80 | 1655.92 | 754.88 | 1655.92 |
| VA/SA | 955.08 | 966.56 | 966.56 | 109.76 | 966.56 | 109.76 | 966.56 |
| Crossbar | 1873.20 | 1013.00 | 1013.60 | 567.00 | 1013.60 | 567.00 | 1028.72 |
| PG Ctrl | 22.40 | 0.00 | 22.40 | 0.00 | 22.40 | 0.00 | 22.40 |
| Router | 38073.00 | 24264.24 | 24286.64 | 11760.56 | 24286.64 | 11872.84 | 24301.76 |
| NI | 25620.00 | 25992.96 | - | 25992.96 | - | 29941.52 | - |
| Total | 63693.00 | 74543.84 | - | 62040.16 | - | 66116.12 | - |

### 10.3 面积变化原因分析

#### Catnap 面积偏高的原因

Catnap 将一个 NoC 拆成两个结构相同的子网络。虽然每个子网络带宽降低，但 control unit 被复制，包括：

- RC；
- VA；
- SA；
- crossbar；
- router control logic。

因此，Catnap 相比 Single-NoC 面积明显增加。

#### HetSub 面积降低的原因

HetSub 的 R0 是低 radix dual-line router，因此：

- Input Port / VC 面积从 Catnap R0 的 22148.00 降到 11042.64；
- VC 面积从 14895.16 降到 9166.92；
- RC 面积从 1655.92 降到 646.80；
- VA/SA 面积从 966.56 降到 109.76；
- Crossbar 面积从 1013.00 降到 567.00。

这说明 dual-line 的低 radix 直接减少了 router storage 和 control logic。

#### Long-range link 增加面积的原因

HetSub-Longlink 相比 HetSub 的面积增加主要来自：

- NI 面积增加：25992.96 → 29941.52；
- R0 RC 面积增加：646.80 → 754.88；
- R1 crossbar 面积增加：1013.60 → 1028.72；
- R1 router 面积小幅增加：24286.64 → 24301.76。

这符合论文设计逻辑：long-range link 的主要开销不在大规模 buffer，而是在 NI relay、serialization/deserialization、global configuration 和少量 routing/crossbar 控制。

---

## 11. 实验设计

### 11.1 仿真器

论文使用 Noxim cycle-accurate NoC simulator，并扩展支持：

- PG wake-up modeling；
- PG energy overhead；
- 新拓扑；
- 新 routing algorithm；
- long-range link；
- subnetwork selection。

PG 参数：

| 参数 | 设置 |
|---|---:|
| Wake-up time | 6 cycles |
| Break-even time | 10 cycles |
| Warm-up time | 1000 cycles |
| Simulation time | 10000 cycles |

### 11.2 对比方法

| 方法 | 含义 |
|---|---|
| No-PG | 单一 NoC，无 power gating，代表普通类脑 NoC baseline |
| Single-NoC | 单一 NoC，每条 route 支持 PG |
| Catnap | homogeneous Multi-NoC + PG |
| HetSub | 本文异构 Multi-NoC |
| HetSub-Longlink | HetSub + reconfigurable long-range links |

### 11.3 Synthetic workload

论文构造 small-world network，并用 clustering coefficient 表示 locality 强度。

实验变量：

- injection rate：0.01 到 0.2 packets/node/cycle；
- clustering coefficient：例如 0.5 和 0.75；
- local/global connection 比例由 clustering coefficient 控制。

评价指标：

- average packet latency；
- normalized static energy；
- total energy breakdown；
- latency breakdown；
- packet distribution across subnetworks；
- throughput；
- maximum flit latency。

### 11.4 Long-range link 实验

#### 4×4 实验

在 4×4 网络中，作者手动构造两对 shortcuts：

- node 3 ↔ node 9；
- node 8 ↔ node 14。

测量开启和不开启 long-range link 时的：

- average flit latency；
- maximum flit latency；
- throughput。

#### 8×8 实验

在 8×8 网络中，作者测试不同 shortcut 数量对 average flit latency 的影响。由于 8×8 下 shortcut 插入更复杂，论文启用 heuristic hierarchical insertion policy，高层 shortcut 优先，同层 shortcut 随机选择。

结论：

- 低注入率下 long-range link 效果明显；
- 前两个高层 shortcut 收益最大；
- 后续 shortcut 边际收益下降；
- 高注入率下 long-range link 不能解决整体拥塞，过多 shortcut 甚至可能产生负效果。

### 11.5 Real application workload

论文评估四个真实 SNN 应用：

| 应用 | 类型 | 说明 |
|---|---|---|
| MNIST | Converted SNN | 使用 LeNet-5，映射到 16 cores |
| DVS-Gesture | Converted SNN | 网络规模更大，映射到 8×8 NoC |
| FSDD | Native SNN | 使用 LSM，1000 neurons，映射到 16 cores |
| N-MNIST | Native SNN | 使用 LSM，1000 neurons，映射到 16 cores |

为了避免 mapping 不公平，论文采用已有 SNN-to-NoC mapping algorithm，将通信密集的 clusters 优先映射到空间邻近位置。

---

## 12. 性能数据与结果分析

### 12.1 总体结果

论文在真实应用 workload 上给出的核心结果：

| 指标 | HetSub 相比 Catnap |
|---|---:|
| Average packet latency | 改善 38% |
| Static power consumption | 降低 58% |
| Area | 节省 16% |
| Long-range link 额外面积 | 增加约 6% |

### 12.2 Synthetic workload 结果

#### 低注入率

No-PG 由于没有 PG wake-up latency，通常具有最低延迟。但它没有关闭 idle router，因此 static power 很高。

Single-NoC 虽然通过 PG 降低静态功耗，但频繁 wake-up 导致延迟最高。

Catnap 通过 always-on 子网络减少 wake-up latency，但带宽减半导致 serialization latency。

HetSub 在低注入率下的延迟不一定最低，因为 global packet 在 dual-line 中可能走较长路径。但由于 R0 更轻量，静态功耗明显低于 Catnap。

#### 中高注入率

当 injection rate 增大时，Catnap 的 serialization penalty 更明显，延迟快速上升。HetSub 因为减少了 packet fragmentation，带宽占用时间更短，因此 congestion mitigation 更好。

当其他方法接近拥塞、延迟指数增长时，HetSub 可以保持较低 latency。

#### locality 影响

clustering coefficient 越高，说明 local traffic 越多，HetSub 越占优势。因为 dual-line 子网络正是针对 local communication 优化的。

### 12.3 Energy breakdown

论文指出 buffer energy 是 total energy 的主要组成部分。因此，HetSub 减少 VC 数量和 input port 数量可以显著降低能耗。

相比之下，RC 和 VA/SA 能耗占比较小。因此，Multi-NoC 中复制 control unit 的能耗影响小于 buffer storage，但面积影响仍然明显。

### 12.4 Latency breakdown

论文将 latency 分成：

- serialization latency；
- route latency；
- injection latency。

结果显示：

1. 在低注入率下，serialization latency 是 Catnap 的重要延迟来源；
2. 在高注入率下，较长 packet 占用网络资源更久，进一步放大 congestion；
3. dual-line 虽然 VC 数减少，但因为 flit 更宽、packet 更短，整体拥塞控制更好。

### 12.5 Subnetwork selection 效果

论文统计了两个子网络接收的 packet 类型。结果表明：

- 低注入率时，local 和 global packet 都进入 Subnetwork 1；
- Subnetwork 1 拥塞后，global packet 开始进入 Subnetwork 2；
- 当 clustering coefficient 较高时，local traffic 占主导，最终可以实现更清晰的 local/global separation；
- 当 clustering coefficient 较低时，global traffic 较多，Subnetwork 2 也可能拥塞，selection policy 会降低 global packet 注入 Subnetwork 2 的比例。

### 12.6 Long-range link 效果

Long-range link 的主要收益场景是：

- sparse traffic；
- global packet 数量少；
- dual-line 中远距离通信路径长；
- PG mesh 不希望被唤醒。

实验结论：

- 4×4 中 long-range link 能明显降低 average flit latency 和 maximum flit latency；
- 8×8 中，增加 shortcut 数量可降低 latency，但收益递减；
- 前两个高层 shortcut 收益最大；
- 高注入率下，long-range link 无法替代 subnetwork wake-up 和 packet separation；
- 过多 shortcut 在拥塞场景下可能反而降低效果。

### 12.7 Real application 结果

四个真实应用中，HetSub 在 average latency 和 total power 上整体优于其他方案。

具体解释：

- FSDD 和 N-MNIST 是 native SNN，具有明显 small-world locality，因此 HetSub 延迟接近 No-PG，同时功耗显著更低；
- MNIST 是较小 converted SNN，层间通信局部性较强，HetSub 表现较好；
- DVS-Gesture 规模更大，locality 变弱，dual-line 的远距离通信缺点更明显，需要启用 PG mesh 或 long-range link。

---

## 13. 局限性：适用范围、拓扑依赖与硬件实现风险

这一部分是理解 HetSub 时最容易忽略的地方。HetSub 的结果很好，但它不是一个通用 NoC 路由方法，而是一个 **面向类脑计算通信特征的专用 NoC 架构优化**。因此，它的局限性主要来自两个方面：**workload-specific** 和 **topology-specific**。

### 13.1 适用场景局限：主要面向类脑计算通信

HetSub 的核心假设是 neuromorphic workloads / SNN workloads 具有：

1. **通信稀疏性**：spike 事件不是每个周期都大量产生；
2. **通信局部性**：大部分通信发生在相邻神经元、相邻层或相邻 core 之间；
3. **局部密集、全局稀疏**：local traffic 占多数，global traffic 较少。

因此，HetSub 的基本逻辑是：

```text
local packet 多  → 走低功耗 always-on dual-line 子网络
global packet 少 → 低负载下走 long-range shortcut，拥塞时才唤醒 PG mesh
```

如果换成普通 heterogeneous manycore，例如 CPU + GPU + accelerator 系统，通信模式可能包括：

- CPU cache coherence traffic；
- GPU burst traffic；
- accelerator-to-memory traffic；
- 多应用并发产生的不规则 traffic；
- 动态 task mapping 导致的 phase change；
- hotspot 或 uniform random traffic。

这些通信不一定满足“局部密集、全局稀疏”。如果 global traffic 很多，HetSub 的 dual-line 子网络会出现 hop 数过长、路径占用时间变长、PG mesh 频繁唤醒等问题，原本的静态功耗优势可能被延迟和 wake-up overhead 抵消。

所以，HetSub 更准确的定位是：

> **Neuromorphic-specific / SNN-locality-aware NoC architecture**，而不是 general-purpose heterogeneous manycore NoC routing。

### 13.2 拓扑依赖性：不是任意 mesh 都能直接使用

HetSub 并不是“在一个普通 2D mesh 上换一个路由算法”。它依赖一个特定的异构 Multi-NoC 结构：

```text
Subnetwork 1: always-on dual-line / low-radix topology
Subnetwork 2: power-gated 2D mesh topology
Long-range link: 复用 PG mesh 的 idle physical links + crossbar bypass
```

因此，它的 long-range link 机制强依赖：

1. **dual-line 到 2D mesh 的映射关系**；
2. **Hilbert space-filling curve 的 1D-to-2D locality-preserving mapping**；
3. **PG mesh 中可复用的 physical links 和 crossbar**；
4. **2D mesh 下 physical length 不超过 2-hop 的 RC delay 约束**；
5. **static crossbar configuration 不产生路径冲突**。

如果换成其他拓扑，HetSub 不能直接套用，需要重新设计 mapping、routing、deadlock avoidance 和 shortcut insertion。

| 拓扑类型 | 是否能直接使用 HetSub | 原因 |
|---|---|---|
| 2D mesh + dual-line Multi-NoC | 可以 | 与论文假设一致 |
| 普通单层 2D mesh | 不能直接使用 | 缺少 dual-line 子网和 PG mesh 复用通路 |
| 2D torus | 需要大幅改造 | 环绕链路会改变路径依赖和死锁分析 |
| ring / line | 不适合原方案 | 没有 2D mesh 物理 shortcut 结构 |
| tree / fat-tree | 不适合直接套用 | 路径结构和物理映射不同 |
| irregular NoC | 需要重新设计 | 无法直接使用 Hilbert mapping 和固定 2-hop 约束 |

因此，在论文对比表中，HetSub 可以标注为：

```text
Hardware Cost: Medium (topology/workload-specific)
```

或者更明确地写成：

```text
Topology Dependence: High, dual-line + 2D mesh required
```

### 13.3 与普通 8×8 mesh 路由方法不是同一类方法

如果你的研究是：

```text
8×8 mesh + 路由表优化 + PRU / MOPSO 动态端口选择
```

那么你的方法是在 **保持 mesh 拓扑不变** 的基础上改 routing decision。

而 HetSub 是：

```text
改 topology + 改 router + 改 NI + 改 crossbar + 改 PG 子网络使用方式
```

两者的比较需要注意分类：

| 方法类型 | 代表 | 改动层次 |
|---|---|---|
| Routing-only | XY, O1TURN, DyXY, PRU/MOPSO routing | 主要改路由决策 |
| Router/control enhancement | ALPHA, congestion-aware routing | 改控制逻辑或局部硬件 |
| Architecture-level redesign | HetSub | 改子网络拓扑、router、NI、crossbar、电源域 |

所以在表格中，HetSub 不应被描述为普通 mesh adaptive routing，而应描述为 **architecture-level, topology-specific, neuromorphic-specific** 方法。

### 13.4 Long-range link 当前偏静态配置

论文中 low-traffic 场景下通过 global configuration 建立 long-range link，并 mask subnetwork selection policy。这个过程目前更偏静态或半静态。

局限性：

- 需要先识别 low-traffic scenario；
- shortcut 配置依赖统计 traffic；
- 对 phase change 和突发流量适应性有限；
- 动态关闭 long-range link 时，如果一个 packet 的 flit 序列只传了一部分，可能导致 packet 被分裂，需要额外 head flit 重建逻辑；
- 如果运行时频繁重配置 long-range links，global configuration 的控制开销和一致性问题需要进一步处理。

### 13.5 插入算法不保证全局最优

启发式算法硬件友好，但存在：

- traffic threshold 难以设定；
- shortcut 数量和位置依赖 workload；
- 不保证全局最优；
- 高负载下收益下降；
- 过多 shortcut 可能适得其反；
- 不同 SNN mapping algorithm 可能改变 traffic locality，从而影响 shortcut 插入效果。

### 13.6 后端物理验证不足

虽然论文考虑了 RC delay，并限制 long-range link 的物理长度，但仍缺少完整后端验证。

可能需要进一步验证：

- placement and routing 后的真实 wire delay；
- clock balancing；
- long wire crosstalk；
- bypass crossbar timing；
- PG domain 与 always-on domain 的时序边界；
- sleep router 中 crossbar always-on 的电源完整性；
- global configuration storage 和 always-on control 的可靠性；
- power gating cell、isolation cell、level shifter 等真实低功耗实现开销。

### 13.7 动态功耗分析还可以更充分

论文重点是 static power，但 HetSub 也引入了额外动态开销：

- serialization/deserialization；
- NI relay；
- MUX switching；
- crossbar global configuration；
- bypass path switching；
- long-range link 上更复杂的数据转发路径。

如果进一步扩展工作，可以增加 EDP、ED²P、runtime energy under phase-changing workloads、动态重配置开销等指标。

### 13.8 对比方法范围有限

论文主要对比 No-PG、Single-NoC、Catnap。虽然这些 baseline 合理，但还可以进一步比较：

- small-world NoC；
- express channel NoC；
- concentrated mesh；
- ring / torus / hierarchical NoC；
- application-specific long-range link insertion；
- neuromorphic segmented-bus interconnect；
- 其他异构 manycore adaptive routing 方法。

### 13.9 局限性总结

一句话概括：

> **HetSub 的优势来自对类脑通信局部性的专用利用，但也因此具有明显的 workload-specific 和 topology-specific 局限。**

更具体地说：

| 局限类型 | 具体表现 | 对结果的影响 |
|---|---|---|
| Workload-specific | 依赖 SNN / neuromorphic locality | 对普通 CPU/GPU heterogeneous manycore 不一定有效 |
| Topology-specific | 依赖 dual-line + 2D mesh Multi-NoC | 不能直接迁移到任意 mesh、torus、ring 或 irregular NoC |
| Static configuration | long-range link 当前偏静态 | 对 phase change 和突发流量适应性不足 |
| Heuristic algorithm | shortcut 插入不保证最优 | 对 workload mapping 和 threshold 敏感 |
| Physical design | 缺少完整后端验证 | RC delay、电源域、时序收敛仍有风险 |
| Evaluation scope | baseline 范围有限 | 与更多 neuromorphic / general NoC 方法的比较不足 |

在论文中可以这样评价 HetSub：

> HetSub achieves strong energy and latency benefits by exploiting the locally dense and globally sparse communication pattern of neuromorphic workloads. However, its effectiveness is workload-specific and topology-dependent, since the dual-line always-on subnetwork, 2-D mesh PG subnetwork, and Hilbert-curve-based long-range link insertion are tightly coupled to the assumed neuromorphic traffic locality and heterogeneous Multi-NoC topology.

中文含义是：

> HetSub 通过利用类脑负载中局部密集、全局稀疏的通信模式，实现了较好的能耗和延迟优化。然而，该方法具有明显的负载特定性和拓扑依赖性，因为 dual-line always-on 子网络、2D mesh PG 子网络以及基于 Hilbert 曲线的长距离链路插入算法，都与类脑通信局部性和特定异构 Multi-NoC 拓扑紧密绑定。

## 14. 专家评价

这篇论文的学术价值在于，它不是简单地提出“降低功耗”或“增加 shortcut”，而是把 workload 特性、NoC 拓扑、PG 机制、子网络选择、long-range link 复用和硬件实现结合起来。

其设计逻辑非常清晰：

1. 类脑计算具有 sparse traffic；
2. sparse traffic 使 static power 更突出；
3. PG 能降低 static power，但 wake-up 有代价；
4. Catnap 用 Multi-NoC 缓解 wake-up，但造成 serialization latency；
5. 类脑通信具有 locality；
6. 因此 always-on 子网络可以降维成 low-radix dual-line；
7. dual-line 对 global traffic 不友好；
8. 因此复用 sleep mesh 的 physical links 构建 long-range shortcut；
9. 为避免 RC delay 和 deadlock，再设计插入算法和 routing 约束。

从论文质量看，HetSub 的强项是：

- 问题定义明确；
- workload motivation 强；
- 架构创新清晰；
- 硬件代价有综合结果支撑；
- 实验覆盖 synthetic workload、long-range link、real applications 和 hardware overhead。

弱项是：

- 对 workload locality 依赖较强；
- long-range link 动态适应能力不足；
- 后端物理实现验证不够完整；
- 对比对象偏少；
- heuristic insertion algorithm 缺少最优性分析。

总体上，这篇论文适合作为 **异构 NoC 架构设计、低功耗 NoC、类脑芯片互连、PG + Multi-NoC 优化** 方向的重要参考。

---

## 15. 对异构 NoC / 动态路由研究的启发

如果将这篇论文用于支撑自己的 NoC 路由或架构论文，可以借鉴以下写法：

1. **先找 workload property**：不要直接提出方法，而是先证明 workload 存在 locality、heterogeneity 或 phase behavior。
2. **架构设计要和 workload 对齐**：HetSub 的 dual-line 并不是通用最好，而是针对 local traffic 最合适。
3. **硬件约束要提前写**：死锁、VC、RC delay、crossbar conflict、PG wake-up、area overhead 都需要在方法部分处理。
4. **不要只报告 latency**：还应报告 static power、total energy、area、hardware overhead、scalability。
5. **4×4 适合机制验证，8×8 适合证明扩展性**：这篇论文也在 8×8 上测试 shortcut 插入和真实 DVS-Gesture workload。

---

## 16. 结论

HetSub 的核心贡献可以归纳为：

> 利用 neuromorphic workload 的 locality，将传统 homogeneous Multi-NoC 改造为 heterogeneous Multi-NoC；通过 low-radix always-on 子网络降低静态功耗和序列化延迟；通过复用 PG mesh 的空闲物理链路构建 reconfigurable long-range links，改善低流量下的 global communication latency。

其最终实验结果表明，相比 Catnap，HetSub 在真实应用 workload 上实现：

- **38% average packet latency improvement**；
- **58% static power reduction**；
- **16% area saving**；
- long-range link reconfiguration 仅带来约 **6% extra area overhead**。

这是一篇典型的、面向专用 workload 的 NoC 架构优化论文，适合作为写作“研究背景—问题—局限性—方法—硬件实现—实验验证”完整逻辑链的范例。
