# HetSub 核心机制的最小迁移与基准比较方案

日期：2026-10-15。状态：设计方案，尚未实现或完成新实验。

> 后续修订：若目标是在固定系统平台下最大程度复现论文，优先采用 [独立双子网方案](HETSUB_FAITHFUL_PLATFORM_PLAN.md)。本文件保留为物理NoC也不允许改动时的低成本适配方案，其共享端口与服务时间近似不能代表原版HetSub的核心硬件收益。

## 1. 结论与选择

建议在现有 flexible Garnet 的 **64 个路由器、原有 Mesh 物理链路、CPU/GPU/内存映射和 VI_hammer 协议**上实现 `HetSub-adapted`。用现有 VC 划分逻辑 dual-line 与 Mesh 通道，保留局部性分流、按需唤醒、静态长链路旁路和 Hilbert 分层插入。采用有明确资源约束的周期级近似，不复制整个 Ruby network，也不增加第二套 CPU/GPU 系统。

这能保留论文的大部分决策机制，同时把改动集中在 flexible-pipeline。代价是：共享物理端口、共享仲裁器及固定宽度 buffer 与原论文的两个独立物理子网不同。因此正式图例必须写 **HetSub-adapted (shared-mesh)**，不能直接写“原版 HetSub”。原论文的面积和静态功耗收益不能作为本实现的结果。

这里存在不可消除的取舍：原版的两套独立子网、不同位宽 buffer、不同 radix 硬件与独立电源域，不可能只通过换一个路由函数完整保留。本方案优先保证与 bak/TBP 的平台和资源可比，并保留有实际调度、带宽与背压效果的机制。

交付两种固定运行模式，分别报告，禁止按测试结果挑选每个 workload 中较好的一种拼成“HetSub”曲线：

| 模式 | 内容 | 用途 |
|---|---|---|
| `off` | 对齐配置后的现有 XY | 回归与统一分母 |
| `dual` | 逻辑双子网、动态分流、Mesh 通道按需唤醒 | 与 bak/TBP 的主比较 |
| `shortcut` | 全部普通包走 dual-line；Mesh 通道用于冻结配置的旁路；关闭动态分流 | 保留论文最有辨识度的长链路机制，单独比较 |

固定模式无需运行中撤销捷径、迁移在途包或重建 head flit。原文也将这类动态重配置列为未来工作。

## 2. 读取依据与原文核对

### 2.1 论文原文

已读取本地 14 页 PDF 全文，并查看 Algorithm 1、Algorithm 2、Fig. 8–10、Table I 的页面图像：

- [本地论文 PDF](</home/siat/paper/network_on_chip/HetSub A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems.pdf>)。
- Y. Li et al., *HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems*, IEEE TVLSI 33(11), 3131–3144, 2025，[DOI](https://doi.org/10.1109/TVLSI.2025.3597406)。

原文与方案的对应关系：

| 原文位置 | 实际方法 | 本方案处理 |
|---|---|---|
| III-A-1，pp.3134–3135，Fig.5 | 常开 dual-line：两方向、宽 flit、1 VC；PG Mesh：四方向、窄 flit、2 VC | 保留 Hilbert 线性路径与功能分化；资源受限时采用每 vnet 1+1 VC；位宽采用服务时间近似 |
| III-A-2，p.3135 | 低流量全部进入常开子网；拥塞后才分离 local/global；双子网拥塞反馈与滞回 | NI 注入时选择；包进入后不在普通双子网之间切换 |
| III-B，pp.3136–3137 | 复用休眠 Mesh 的物理链路、crossbar bypass、NI relay、序列化与反序列化 | 保留受限短隧道、容量竞争和背压；用已有缓冲空间承担端点 relay |
| Algorithm 1，p.3137 | shortcut 终点必须位于当前节点到目的节点的线性路径内 | 严格使用 Hilbert 序号的单调区间条件 |
| III-C，p.3138，Algorithm 2 | Hilbert 分层、非相邻子区候选、流量阈值、冲突检查、高层优先；物理长度不超过 2 Mesh hop | 一次离线配置，固定排序，显式输出路径与冲突检查 |
| IV-A，p.3139，Table I | 基本实验 dual-line 为 64 bit、2 flits、1 VC；Mesh 为 32 bit、4 flits、2 VC；深度 4 | 使用当前平台消息长度，不能照搬固定 2/4 包长 |
| Fig.13，p.3140 | 延迟分解另用 4/8 flits | 纠正旧需求把不同实验的 2/8 flits 混在一起的描述 |
| IV-C、V，pp.3141–3143 | long-link 实验屏蔽子网选择；低流量模式由人工识别并静态配置；在线切换尚待解决 | 两个固定模式；不做在线重配置状态机 |
| IV-A，p.3139 | 每次唤醒收取相当于 10 个周期静态功耗的转换能量；唤醒时间 6 周期 | 正确计入每次转换代价，不能简单把短睡眠节能置零 |

### 2.2 代码及 review 的实际结论

读取了本仓库 `.ai/{tasks,reports,reviews}`，以及 `reports/flexible_tbtbp_route_review.md`、`reports/synthetic_traffic_code_review.md`、`reports/synthetic_traffic_final_code_review.md`。旧 review 的 Approve 只覆盖当时的三模式实验产物一致性，不代表已经复现 HetSub，也不代表满足当前跨仓库比较条件。

此次检查时 gem5 HEAD：本仓 `275143083`，bak `ecfe48d67`，TBP `d3b0c81`。这里只记录定位信息；实际实施时以当时工作树为准。

| 发现 | 对方案的约束 |
|---|---|
| 本仓 `Router::getRoute()` 仍为 XY，`routing_algorithm` 字符串不等于已实现算法切换 | 新增明确模式分支和运行计数，不能靠改名称宣称实现 |
| bak 的实际入口包含 PSO 表查询与 table fallback；TBP 有 task class、XY/YX 和运行阶段状态 | 方法名、配置和路径计数共同确认算法身份；本仓旧“没有 TBP”审查不能套用于兄弟 TBP 仓库 |
| 本仓默认 4 VC、`buffer_size=0`、4 级流水；bak 为 2 VC、深度 4、2 级流水 | 比较前显式对齐；不能把默认运行结果直接放在同一表中 |
| TBP contract：8×8、2 GHz、2 VC/vnet、深度4、2级、128 bit、VI_hammer 10 vnets、368条有向内部及外部数据链路 | 作为应用比较的起始契约，逐项检查实际 config，而非只信命令行 |
| 本仓 GPU placement 使用 `random.shuffle`；bak 用 simulation seed；TBP 用独立 topology seed | 相同 simulation seed 不保证相同映射；须对比完整 MachineID→router 列表 |
| `getRoute()` 检查最短路径 routing table；Hilbert 路径可能绕行 | Hilbert 模式用物理相邻端口查找，不能被旧最短路径表否决后退回 XY |
| 本仓一个方向槽可能无法表达多个 local NI，且 NI 收包存在错误 vnet redirect | 本地交付按完整 MachineID 找准确外部端口；正式运行不允许 redirect/drop |
| VC 请求早于 flit 到达；路由在 `request_vc()` 中决定 | 不能只在 `routeCompute()` 改端口；需要使 VC 请求与整包路径一致 |
| `get_valid_vcs()` 对 ordered vnet 只给一个 VC | ordered 流量需要固定路径；不默认两子网动态选择仍能保持顺序 |
| `averageHopCount` 记录的是当前到目的的 Manhattan 距离 | 新比较使用实际过链路计数，不把该字段当实际包跳数 |
| `parse_synth_stats.py` 硬编码 `[1,1,5]` flits/packet，并直接除 `sim_ticks` | 采用显式 packet/byte 计数和 Ruby 周期；缺字段报错，不能把 flits 当 packets |
| NetworkTest 的 `simCycles` 被拿来与 `curTick()` 比较；配置把全局 tick 设置为 1 ns | 参数名不能证明单位；2 GHz 网络不能套用这一时间精度，见测试部分 |
| sweep wrapper 指向 `/home/siat/gem5-gpu-xy`；应用 runner 使用共享 `/tmp/test_*` 输出 | 新运行必须绑定正确源码目录、使用方法独立输出目录，避免运行错仓库或覆盖结果 |

代码定位：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/{Router,NetworkInterface,NetworkLink,GarnetNetwork}.{cc,hh}`；`gem5/configs/topologies/Mesh8x8_CPU_GPU.py`；`gem5/configs/example/ruby_network_test.py`；`scripts/parse_synth_stats.py`。TBP 比较契约见 `/home/siat/gem5-gpu-tbp/workflow/tbtbp/contract.json`。

## 3. 不变平台与公平比较边界

### 3.1 应用比较的固定项

统一使用 VI_hammer、flexible Garnet、Mesh8x8_CPU_GPU、原有 CPU/GPU/目录数量与缓存配置；网络 2 GHz、128-bit 基础 flit、2 VC/vnet、深度 4、2 级普通路由流水。工作负载使用相同二进制、输入、CPU/GPU 时钟和运行终止条件。应用不改成 SNN，不通过重映射 GPU/目录节点人为增强 HetSub 的 locality。

每次运行读取 config.ini，输出一页配置摘要和实际端点映射。内部 Mesh 有 224 条有向链路；TBP 应用契约的 368 包括外部链路。二者不能混淆，也不能把应用网络的 368 强加给 Network_test。

第一次只用 simulation seed 1234、topology seed 0。bak 如尚无独立 topology seed，最小修补为与 TBP 相同的局部 RNG 及同一节点列表排序；不能通过把 bak 的 simulation seed 改为 0 偷换通信随机性。端点映射逐行比较，不建立哈希登记系统。

不要合并三个分叉的全部源码。只对齐确实影响比较的配置、拓扑映射、统计定义和必要 bugfix。若即使 `off/XY` 对齐后仍存在未解释的交付、时序差异，先解释该差异，再发表跨仓库改进率。

### 3.2 同平台不等于同一种硬件

主表中的 `dual` 是固定 Mesh 资源上的算法/控制适配。`shortcut` 还增加旁路控制语义，应单独列明“旁路支持”。即使没有新连线，也不能声称旁路硬件免费。

不为 HetSub 增加 VC、router、可用 buffer 总量、单物理链路峰值带宽或独立 NI 注入端口。只减少未使用资源或重新划分已有资源。需要额外 metadata 的控制位可逐项列出；本阶段不做综合、自动面积估算或新 DSENT 校准项目。

原文的 `2×64-bit + 4×32-bit` 是其特定子网资源分配。直接在现有 Mesh 上额外添加一套宽 dual-line 链路并保留原 Mesh 满带宽，会增加资源，不能作为本方案的主基准。

## 4. 最小机制设计

### 4.1 两个逻辑平面，共用原来的路由器

固定当前 8×8 Hilbert 映射，建立 `router_to_h[64]` 和逆映射。相邻 Hilbert 序号必须对应物理相邻 Mesh 节点。保留全部原有物理链接；本功能不改变 CPU/GPU placement。

对每个 vnet 的两个 VC：`offset 0 → L`（dual-line），`offset 1 → M`（Mesh）。L 只允许沿 Hilbert 前驱/后继到目标及正确本地端口；M 使用严格 XY。两平面分别分配已有 VC，不能普通包中途跨平面。物理端口和链路仍统一仲裁，不能各自每周期发送一个 flit。

在普通 `dual` 模式下，平面由 VC offset 即可表达，无需建立全局 packet registry。NI 分配 VC、Router 分配下游 VC、NetworkLink 请求传递必须遵守同一映射。原来把 congestion 转成 XY escape 的路径不能对 L 包生效；L 包一旦注入，必须保持 Hilbert 单调。

当源与目的映射到同一 router 时直接准确本地交付，不使用 `%64` 猜测缺失映射。多个 NI 共用 router 时，依据完整 MachineID 找外部端口。新模式映射失败应立即报错。

ordered vnet 在 `dual` 中固定 M/XY，保持既有单 VC 的顺序约束；在 `shortcut` 中固定 L 及同一套静态路径，遇忙等待，不能临时绕行。报告 ordered 流量占比，它会限制可迁移机制的覆盖率。

### 4.2 注入选择：保留原文逻辑，参数少且可解释

local/global 在当前平台定义为 `abs(h(src)-h(dst)) <= R`，初始 `R=2`。这是 CPU/GPU 适配的代理定义，不是论文已给出的统一阈值，也不能把这种距离自动等同于 SNN 的连接类型。

对 unordered 流量：

1. L 不拥塞：local 和 global 都优先进入 L。
2. L 拥塞：local 保持 L；global 按比例进入 M。
3. M 拥塞：降低进入 M 的比例。
4. 每个包在成功获得源 NI VC 时固定平面；重试不能反复计数或消耗随机数。

拥塞用源 router 对应平面的有限 buffer 占用率；HI/LO 初始为 75%/50%，使用滞回。只采用局部反馈，不引入零延迟全网广播。每 128 个 Ruby cycles 最多更新一次比例，使用 `{0,1/4,1/2,3/4,1}`，按两个拥塞信号增减；同时拥塞优先降低 M 比例。源 NI 使用整数累加器选择 global 包，避免消耗流量生成器的 RNG。数值是预设工程起点，在 pilot 后冻结，不逐 workload 调参。

不要求全网流量比例随注入率严格单调。验收检查控制器对给定信号的响应和实际分流计数，性能趋势由实验决定。

### 4.3 位宽差异：固定 flit 对象，建模真实服务时间

为降低侵入性，保持 Ruby message、基础 128-bit flit、包编号和现有缓冲布局。L 每基础 flit 一个发送服务槽；M 和 shortcut 用半宽服务，基础 flit 所含有效字节数为 `b` 时占用 `ceil(b / 8)` 个网络周期。末尾不足 16 bytes 的 flit 按实际字节数计算；不能对 8-byte 控制包无条件罚两个周期。

占用必须约束源出队、端口仲裁、NetworkLink 可用时刻和下一包的发射。只在最终 latency 上加常数不合格。一个物理链路的所有 L/M/shortcut 传输合计不得超过原来的容量。源 NI 与目标 NI 的外部端口继续按统一平台速率工作；relay 的转换服务单独计入。

这是 **固定 flit 的序列化服务模型**：保留 2:1 服务宽度差异，但未重建两个 64-bit 子 flit 的完整 wormhole 重叠行为，不能视为原论文的周期精确复现或严格性能下界。buffer 存储仍为原宽度，不能因此宣称窄 buffer 面积收益。

保留一个 `serialization=1/2` 的开关用于消融，主设为 2。若两种设置导致相对排名翻转，应报告模型敏感性，不能只发表有利的一组。核心定向测试必须验证实际发送间隔及长包吞吐，而非仅验证统计字段。

### 4.4 Power gating：关闭 M 的缓冲/控制资源

同一物理 router 内只对 M bank 建模 `ACTIVE/SLEEP/WAKING`。共享物理 crossbar、L bank、必要连接控制不能随 M 一起关闭。进入 sleep 需要 M 的 buffer 空、无已授权 VC/未完成 request、无待发及在途接收；仅检查“最近没有 flit”不够。

连续空闲阈值初设 50 cycles；收到 M 请求时唤醒，6 cycles 后才允许相应 grant/forward。每次唤醒记录转换次数，睡眠/唤醒/活跃周期用事件间隔累计，避免逐周期扫描全网。

如报告能量估计，使用统一公式：

`E_M = P_active*T_active + P_sleep*T_sleep + N_wakeup*E_WU`

2026-10-15原文IV-A复核：按WU事件总成本解释，`E_WU=P_active*10*Tcycle`。功率用W、时间用秒；active/sleep周期数乘Ruby周期转换。6-cycle waking由该事件成本覆盖，不再重复计入同一唤醒能量。若采用另行校准的`P_waking*T_waking + N*E_transition`分解，须保证两项之和等于WU事件成本，不能直接在10-cycle事件成本之上再加6-cycle能量。共享crossbar/链路及端点relay的能量另计，不能因为M bank休眠就全部归零。

不能免除短睡眠的唤醒代价。功率系数缺少同工艺校准时，只报告状态周期和唤醒次数；原有 DSENTIntegration 中的经验活动估算不能直接支撑跨仓库准确节能百分比。当前实际资源与计数边界见[资源审查](../.ai/reports/RESOURCE_AUDIT.md)。

### 4.5 静态长链路：固定、短、受背压约束

这是实现难度最高但应尽量保留的机制。限定实际路径不超过 2 条现有 Mesh 链路，不增加新物理边。每个节点最多一条输出和一条输入 shortcut；候选必须检查实际有向边及 crossbar 输入→输出冲突。限制同一有向边只属于一条静态 shortcut，以减少实现和证明负担。该冲突规则比论文更保守，需声明。

在 `shortcut` 模式开始前完成配置；整个运行不变，动态 M 注入关闭。L 包只有满足下面条件才能使用从 `u` 到 `v` 的 shortcut：

```text
h(u) < h(v) <= h(dst)  或  h(dst) <= h(v) < h(u)
```

对相同源目的，使用冻结的确定性路径；通路忙时等待，不能以忙闲为由临时改变 ordered 包路径。普通 L 传输与 shortcut 共享原来的物理链路服务，不允许额外免费通道。

**推荐实现为短隧道，不增加网络实例或 Router 对象：**

- 源/终点 relay 复用静态模式中空闲的 M buffer 槽位，总深度仍为 4；这些被当作 relay 使用的槽位必须保持活跃并记账，不能同时记作已断电。
- 为 shortcut 添加少量“隧道编号/端点/剩余物理段”状态。头 flit 决定隧道，body/tail 跟随；临时 M VC 表示隧道资源，不能误入普通 M/XY 路由分支。
- 在发送前先确保目标 L VC 和接收空间可用。隧道内部使用预定的 M VC 控制槽记录预约，避免新增队列；对至多两段进行完整预约或完全不预约，不能持有一半路径等待另一半。
- flit 传输仍经过实际 NetworkLink。中间 router 走专用 bypass，跳过普通 RC/VA 和 `m_router_buffers`，保留真实链路传播、共享端口仲裁和背压。控制槽预约不等于原文完全不使用 VC 控制，属于需披露的实现近似。
- 若需要预约后续周期的链路服务，仅保存覆盖两段短路径的有限待发槽；禁止建立无限事件缓存。已有输出队列不能因为 bypass 被当成新的无限缓冲，源数据在获准发送前留在原有有界 buffer。
- 终点接回 L；头尾、原目的地、vnet、时间戳不变。尾 flit 释放全部隧道状态。接收空间要在发射时预留，不能等 flit 到达时才发现满而丢包。

不把物理 2 hop 自动折算成 1 cycle。在当前 2 GHz 平台没有物理时序证据时，传播至少按实际链路延迟累计；收益来自绕过中间普通路由流水和缩短 Hilbert 路径。端点转换各初设 1 cycle，并计入半宽服务。分别记录 logical hop 和 physical link traversals。

这部分须先做单隧道定向测试再扩展。若只能“改目的地直接送到远端”“把跳数减一”或增加不受约束的逻辑链路，则验收失败，不能作为 HetSub 长链路结果。若实现确实超出小改范围，允许只交付 `dual`，但必须标为“未覆盖 long-link 的部分适配”，不能宣布完整完成本方案。

### 4.6 Hilbert 分层插入：一个离线小脚本即可

按 Algorithm 2 的分层 U 形子区生成中心候选；跳过相邻子区和最低 2×2 层，优先高层，再检查实际物理路径 ≤2 hop、入/出度与资源冲突，最后使用子区间流量阈值决定是否加入。不能替换成“把所有高流量节点随意连起来”。

第一次用几何固定的 2 条有向 shortcut 做机制测试；随后实现分层脚本，初始上限 4 条有向 shortcut。论文中的一对双向 shortcut 在本方案计为两条，避免数量歧义。同层按固定节点编号排序，这是相对原文随机同层选择的可复现简化。

流量 profile 仅记录在源 NI 的每个单播消息的源 router、目的 router、字节数，生成 64×64 聚合矩阵。使用独立 pilot 输入/前缀收集并冻结配置，禁止用最终测试阶段的完整流量作免费预知。确实使用同应用离线训练时，单独标为 application-profiled，并报告 profile 成本。默认跨仓库比较使用预先冻结的几何配置；profiled 版本只作为补充。

配置输出一个 CSV：层级、源、终点、物理中继、估计流量、保留/拒绝原因。无需数据库、优化器或运行时文件监听。

## 5. 最小改动清单与范围

| 文件/位置 | 必要修改 |
|---|---|
| `GarnetNetwork.py/.hh/.cc` | 模式、有限参数、Hilbert/端点映射、shortcut 表、聚合统计 |
| `NetworkInterface.cc/.hh` | 选择 L/M VC、ordered 固定路径、消息/字节计数、精确交付检查 |
| `Router.cc/.hh` | 请求阶段路由、VC 隔离、局部拥塞、M 状态机、旁路入口与资源约束 |
| `NetworkLink.cc/.hh` | 服务间隔、共享容量与隧道传输/背压；保持物理端点与链路列表 |
| `InVcState` / `OutVcState` / `flit` / `FlexibleConsumer` | 仅在现有 VC offset 不足以表示隧道时增量扩展最少字段与默认兼容的请求参数 |
| 正在使用的 Python 配置入口 | 暴露少量开关，显式对齐网络配置及时间单位 |
| `Mesh8x8_CPU_GPU.py` | 必要时只加局部 topology RNG；不改放置策略和物理 Mesh |
| `scripts/` | 一个参数化 runner、一个插入/检查脚本；修订现有 parser |

核心纯逻辑可放一个 `HetSubPolicy.hh/.cc`，方便直接测试；不要再拆成 manager/controller/registry 插件体系。只有新增编译单元时才改 SConscript。不要重构 PSO、替换协议、移植新版 Garnet、升级 Python、复制整个拓扑目录或开展 RTL 综合。

旧需求“只能改 flexible-pipeline 目录”不足以修复配置和实验入口；本方案明确允许表中的必要小改。`gem5-gpu/` 仅限实际配置入口，不改 GPU 执行模型；`gpgpu-sim/` 不需改动。

参数入口优先采用 `hetsub_mode`、`local_radius`、`serialization`、`pg_enable`、`shortcut_file`。其余 HI/LO、更新周期、唤醒参数先集中声明为具名常量并打印到日志；只有做指定敏感性测试时才扩展参数，避免一开始暴露几十个选项。

## 6. 实施顺序与停止条件

| 阶段 | 实施内容 | 通过后才能做什么 |
|---|---|---|
| P0 | 配置/映射/时间单位对齐，正确 packet/byte 指标，正确仓库入口；同配置 XY 基线 | 开始研究机制 |
| P1 | Hilbert L + XY M、VC 隔离、动态分流；PG 暂关、序列化设1 | 证明路由正确并可终止 |
| P2 | 半宽服务与 M PG、所需统计 | 形成可用于主比较的 `dual` |
| P3 | 单条静态隧道→两条冲突测试→冻结多隧道；转换与容量约束 | 形成 `shortcut`，不能省略本阶段就宣称保留 long-link |
| P4 | 分层插入脚本、独立 pilot profile、固定配置对照 | 覆盖第三项论文贡献 |
| P5 | 小规模统一矩阵与结果审查 | 判断适配版本能支持哪些论文结论 |

所有机制默认关闭。P0 后的同配置 XY 是主回归分母；旧 21-case 仅作历史参考，不要求新配置生成相同 CSV MD5。开关关闭时比较稳定的功能与周期数值；忽略 wall time、日志顺序和新增计数字段。

正确性优先于结果方向。禁止把“HetSub 必须优于 TBP/MVPP”“越多长链路必须越快”“节能必须达到论文数值”设为实现验收条件。

## 7. 测试与验收

### 7.1 零仿真定向检查

一个小测试文件直接调用生产用 policy helper，避免重写一套独立算法再自测通过。

| 测试 | 输入与验收标准 |
|---|---|
| 映射 | 64 个唯一节点；Hilbert 邻接为物理相邻；全部 MachineID 有且只有一个真实映射 |
| 全源目的路径 | 64×64 对；L 每步严格单调且最多63步到达；M 严格 XY；同 router 的不同 NI 正确交付 |
| VC 隔离 | 每个 vnet 的 L/M 候选集不交叉；ordered 模式固定；没有跨 vnet 分配 |
| Algorithm 1 | 正反方向、终点相等、越过目的、反向捷径、无捷径、源=目的全部覆盖；不合法捷径不可用 |
| 分层插入 | 高层优先、排除相邻子区及2×2层；每条物理路径≤2、每节点入/出≤1；共享边/crossbar冲突必须拒绝 |
| 分流滞回 | 给定 HI/LO 信号序列，比例正确增减且有界；一次成功注入才更新一次选择计数 |
| 时间换算 | config tick/clock→Ruby cycles；例如1 ps tick、2 GHz，500000 ticks=1000 cycles；错误量纲应被拒绝 |

对 `dual` 的两个平面分别生成通道依赖图，验证无环。`shortcut` 将完整隧道作为逻辑边分析，再检查资源预约不持有部分路径等待其他路径。拓扑无环检查加持续压力测试仍不能等价于整个 VI_hammer 协议的形式化证明；保留各 vnet 隔离及 ordered 约束，记录证明适用范围。

### 7.2 Docker 内最小功能测试

在验证过的构建上，使用当前网络配置的短包、长包、双向流、同 router 多 NI、单目的热点及多 vnet 并发。可以给现有 NetworkTest 添加一个仅测试用的固定目的/有限发包选项，但不另建仿真器或协议。

| 检查 | 验收标准 |
|---|---|
| 有限发包后排空 | 每个单播消息正确送达一次；源/目的/vnet/顺序正确；injected=received、所有VC和预约最终释放 |
| 关闭回归 | `off` 与修改前、同一已对齐配置的 XY 稳定指标相同；不能比较来自不同参数的旧 CSV |
| 半宽服务 | 16-byte基础flit在半宽路径占2槽，8-byte有效尾/控制flit占1槽；后续包被真实限速；长包吞吐正确 |
| 共享容量 | L、M、shortcut 任意组合不能让同物理链路超额发送；满buffer时必须背压，无隐藏无限队列 |
| PG | 空闲后可睡眠；有在途包/预约时不睡；首个M请求承担6周期唤醒；连续请求不重复支付唤醒；转换能量按次数计 |
| 旁路 | 中间普通buffer读写及RC/VA处理计数为0；实际链路计数非零；目标空间满时停在源，解除后恢复 |
| 隧道冲突 | 两源竞争同物理资源、目标堵塞、跨vnet并发，能恢复并排空；途中不能撤销配置 |
| 模式身份 | `off`无HetSub数据路径计数；`dual`有有效分流；`shortcut`有真实旁路次数且没有普通M注入 |
| 应用冒烟 | backprop 16 与 kmeans原输入正常完成、结果符合已有参考；不是仅有stats文件或到时间上限就算通过 |

接收计数必须在真实交付完成时更新；出现错误 vnet redirect、未知目的、静默fallback或drop，运行判失败。定向测试的短暂 packet ID 日志即可，无需对所有正式实验输出逐 flit 全量跟踪。

### 7.3 合成流量：小矩阵，覆盖必要问题

首先沿用三种模式 `uniform_random/bit_reverse/transpose`，注入率 `{0.01,0.05,0.10,0.15}`，seed 42，方法为 XY、bak冻结方法、TBP、`dual`、`shortcut`，共60组。TBP在Network_test中必须有明确、可观察的任务分类；如果三模式不能有效激活其任务机制，则该矩阵只评价其配置在合成流量下的行为，不能代替应用比较。无法统一实现的 synthetic 基线标为未测，不能拿旧结果填补。

增加一个很小的 locality 诊断：以概率 `p` 选择 Hilbert 相邻节点，其余从其他节点选择；`p={0.25,0.75}`，注入率 `{0.02,0.10}`。所有方法共享同一注入轨迹。该 p 只叫“局部目的选择概率”，不要称为论文的图聚类系数。无需引入完整 SNN 或一整套新 traffic suite。

初始窗口为 warm-up 10000、measurement 100000 个 Ruby cycles，之后停止注入并排空。先在配置层把绝对 tick 边界换算清楚；NetworkTest 若无法分别停止注入/排空，允许对其终止逻辑做局部修补。2 GHz 测试统一采用可表示0.5 ns的tick精度（如1 ps），且给 tester 和 Ruby 明确时钟。关闭回归使用旧兼容路径，不能悄悄改变所有历史脚本的时间语义。

有限包守恒在排空后检查；稳态 throughput 只取 measurement 窗口，不能将排空时间混入或把仍在网络中的包直接当丢包。标明延迟统计的测量 cohort，避免只统计高负载下已完成的快包而隐藏积压。

只在接近拥塞的一两个点把测量时长翻倍，检查吞吐和队列趋势是否稳定。窗口之间相差超过5%或队列持续增长则延长/标记未稳定，不强行报稳态平均值。随机流量最终比较补 seed `{42,43,44}`；不对全部模块做全排列消融。

若所有点均未出现吞吐平台或明显积压，仅沿当前最重负载向上增加少量注入点。到达持续积压后保留一个过载点即可，不扫描到1.0，不预先声称0.15一定未饱和或一定已饱和。

### 7.4 真实应用与比较资格

第一轮：backprop 16、kmeans已有输入；simulation seed 1234、topology seed 0，五个方法/模式，共10次应用运行。通过后，正式结果按TBP已有契约补topology seed 1、2，得到30次。三个placement是映射敏感性样本，不是三个独立随机流量重复；分别报告各placement和汇总，不能虚称充分统计显著性。

TBP使用正式 `paper` 时间参数，记录TB/TBP阶段实际覆盖。短应用若根本未进入预期阶段，报告“仅覆盖启动/TB阶段”，不能把它当完整自适应机制的证据。`verification`缩短阶段仅用于定向功能测试。bak同样保留实际方法设置、路径命中/回退和在线更新计数；未知配置不得统一标成MVPP完整方法。

小输入只够证明功能和限定场景性能。如需“通用GPU负载”的结论，应另行扩展输入或应用；本方案不自动开展大规模benchmark工程。

### 7.5 最少必要指标与消融

主指标：相同观察窗口的Ruby周期/执行时间、正确接收packets与有效bytes、bytes/cycle、端到端packet延迟、已有Garnet flit延迟。这里有效bytes统一采用Ruby MessageSizeType转换后的消息字节数（含该模型定义的协议开销、排除flit填充），不能混用应用payload。packet延迟与flit平均延迟单独命名，禁止互换。基础flit宽度一致时保留flits/cycle以与TBP契约对照，半宽服务beat不能冒充更多有效flit。

机制指标：L/M注入数量、ordered固定路由数量、真实物理链路遍历、捷径次数、serialization占用槽、唤醒次数和睡眠周期、最大队列占用、排空时间。仅需少量聚合量；不建立每个节点数百项新统计。

消融选择一个低负载locality案例和一个接近拥塞案例：`dual`对比PG关闭、serialization=1；`shortcut`对比同模式但0条捷径；再比较2与4条有向捷径。普通`dual`与`shortcut`之间同时改变选择策略与旁路，不能用它们的差值单独归因于long-link。

如要比较能效，先确认三个实现使用相同能量范围和系数；否则仅发布性能及PG活动，不把未经校准的proxy与另一个仓库DSENT数值混画。

## 8. 构建、证据与不过度工程化

此次只写文档，无需重编译。后续代码实施继续遵守AGENTS.md已有构建门禁：

```bash
# 在每个项目根目录执行；应用目标使用本仓官方builder。
./docker_build_and_test_j64.sh       # HetSub及bak
./docker_build_and_test_tbp.sh       # 仅TBP
./tools/reproduction/docker_build_network_test.sh

# 每次实际仿真前，在对应项目路径和运行环境中执行。
tools/reproduction/verify_gem5_build.sh verify <project-root> <build-name>
```

这些是构建入口说明，不是让三个builder在同一目录依次运行。synthetic执行在`gem5gpu-dev`内，必须先核实该容器看到的是本次项目树与已验证binary。当前Network_test builder虽然干净构建并验证凭据，但脚本本身没有功能测试；构建成功不等于表7.2通过。若容器挂载错误，修复启动/挂载流程，禁止复制一个不明版本binary救场。

**不新增哈希体系。**只复用仓库强制要求的源码/二进制凭据；不对CSV、图表、每个packet或每阶段报告做链式哈希，不增加签名、manifest数据库或多层审批。每次源码变更后的对应目标干净构建足够；只改运行参数不重复clean build，每次运行按现有要求verify。

每次实验目录只保存：`command.txt`（命令、模式、输入、种子）、`config.ini`、stdout/stderr、原始`stats.txt`、已存在的build凭据/构建日志位置，以及一份汇总CSV。需要的profile/shortcut配置一并保留。旧结果没有与实际binary相连的证据时标为historical/unverified，不能凭今天的凭据补认证过去结果。

一份结果报告说明实际修改、通过/失败测试、最终参数、资源差异与限制即可。无需新建调度平台、全仓库重构、持续优化循环、自动审批流程或大规模哈希审计。

## 9. 最终验收判定

### 可作为主比较基准的最低条件

- [ ] 三仓应用配置、实际端点映射、输入、测量口径对齐。
- [ ] `off`同配置回归通过；未用历史CSV哈希代替功能检查。
- [ ] `dual`的VC隔离、序列化服务、PG时序和正确交付通过定向测试。
- [ ] 全源目的路径检查、资源依赖检查和压力后排空通过。
- [ ] bak/TBP的实际方法身份与应用阶段覆盖有证据。
- [ ] 原始数据、命令、config与已有构建凭据齐全；Docker运行来自正确源码树。
- [ ] 论文清楚标注`HetSub-adapted (shared-mesh)`及固定宽度缓冲/共享端口的近似。

### 可宣称最大限度保留本文核心机制的追加条件

- [ ] 静态shortcut真实经过物理链路、遵守容量与背压、中间旁路生效。
- [ ] relay/serialization代价与被占用的缓冲资源已记账。
- [ ] Algorithm 1单调条件与Algorithm 2分层插入均实现并经过测试。
- [ ] `dual`和`shortcut`分别报告；没有事后择优拼表。
- [ ] 至少一个locality案例与一个非locality/拥塞案例，允许出现负收益。

任何正确性或资源约束失败都阻止接受相应模式；速度不占优不构成实现失败。只有P0–P4机制和测试完整完成，才能说完成本方案。即使全部通过，也只能评价这份明确披露的适配模型，不能将结果表述为对原版HetSub硬件的直接复现。

## 10. 与旧需求的关系

本文件是本次“最小改动、跨bak/TBP比较”任务的实施依据。旧 `HETSUB_FUNCTIONAL_REQUIREMENTS.md` 保留为历史完整复现设想；其中P0–P6不自动全部执行。明确替换以下要求：

1. 不以原21-case CSV的MD5不变作为新实验验收；采用同配置数值回归。
2. 不强制PG/分流/长链路收益随注入率或条数单调；检查机制，客观报告结果。
3. 不把一个方向mask宣称为原版独立异构物理子网。
4. 不把原Table I的2/4-flit设定与Fig.13的4/8-flit设定混用。
5. 不把PG转换能量简化为“短睡眠不计收益”。
6. 不实现运行中动态撤销长链路；采用论文已有静态模式。
7. 不用距离分布代替真实流量profile却仍称复现了流量驱动插入。
8. 不用未修改的单路由表fallback、NI redirect或输出统计重命名掩盖功能缺失。
