# HetSub 论文方法复现：独立 Code Review 与下一阶段最小闭环计划

> 审查日期：2026-10-15  
> 审查方式：GitHub 固定提交静态源码审查 + 已提交的测试器/报告/结果审查；**未修改核心代码、未执行仿真、未复核本地未入库的原始 \`m5out\`/构建日志**。  
> 审查基线（只读）：父仓 \`467f583e8686771ce999a2663c9e6614e9dbd1da\`，核心交付节点 \`3332114ff8ada4a26709cf27a7d9e6a02a328c72\`；gitlink：\`gem5=a90c04ca8aad279876784601f9647c2e0195c763\`、\`gem5-gpu=e53ac2648724060cebf90b801ed7a42b2a992e58\`、\`gpgpu-sim=17f16f104e16f80e8b2a3c8bae68c49c0495cd69\`、\`Graphite=e3ab0ecfd6aef274896219fac4cdfdfa54740426\`、\`benchmarks=35d7550604420dea8f64808208b01c43aae03a39\`。
>
> **核心裁决：维持“当前固定 CPU–GPU 平台上的 HetSub 周期级核心机制复现与迁移比较已完成”的*限定性批准*；不批准据此宣称原论文平台、RTL、面积、实际能耗、性能幅度或任意输入的正确性已复现。本轮静态审查未确认必须立刻修改数据路径的 P0 缺陷，但发现需要纠正的指标语义问题与尚缺定向见证的算法覆盖边界。下阶段先做最小证据闭环，禁止为追求正收益扩张实验。**

## 1. 论文基准、范围与证据等级

论文：Yitao Li 等，*HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems*，IEEE TVLSI 33(11):3131–3144，2025。论文主张异构常开子网与 PG Mesh、拥塞分流、利用空闲 PG Mesh 构建可重构长链路、分层启发式插入；论文自身的 SNN 负载、工艺面积/功耗收益**不是**本项目验收门槛。书目信息：[DBLP](https://dblp.org/rec/journals/tvlsi/LiHJKMP25)；结构、参数与 Algorithm 1/2 的项目内对照：[固定平台忠实复现方案](HETSUB_FAITHFUL_PLATFORM_PLAN.md) §3–5 及 [原文提取需求](../HETSUB_FUNCTIONAL_REQUIREMENTS.md)。

**证据分级**：A = 直接读到冻结 SHA 的实现/可执行断言；B = 脚本确实设置了测试且提交报告称已 PASS（本轮不能独立读取被忽略的原始运行文件）；C = 论文/项目设计说明；D = 缺独立运行见证。不可把 B/C 自动升级为 A 级运行证明。本轮可访问论文公开摘要和项目中已记录的页码/算法参数，但**未获得可逐页逐行校核的论文全文**；“与论文逐句完全一致”尚不可作结论，尤其是 Algorithm 2 的同层候选顺序、threshold 语义和 PG 控制参数。

正式数据入口：[结果](COMPARISON_10C_RESULTS.md)、[最终报告](../.ai/reports/REPORT.md)、[上轮评审](../.ai/reviews/REVIEW.md)、[活动测试清单](../tools/hetsub/run_network_checks.sh)。正式 v2 报告称 backprop/kmeans × 每应用 8 种方法，16/10/4/40/64/72 平台，应用数值审计通过；v1 的 GPU L2 索引错误已修正，v1 不得入正式结论。双应用退出时仍有 8–47 个在途消息；21 个有限包网络案例的 PASS 是另一种独立证据，二者不得混同。

## 2. 逐机制源码证据矩阵

固定核心代码链接以下均指向 [gem5 的 a90c04ca](https://github.com/miuzujia2018-stack/gem5/tree/a90c04ca8aad279876784601f9647c2e0195c763)，父仓脚本均指向 \`467f583e\` 版本。

| 原文核心机制 | 真实数据路径/实现证据（文件:行） | 当前判定与界限 |
|---|---|---|
| 64-tile 常开 Hilbert dual-line + PG Mesh 两套独立路由资源 | [HetSub.py:24–69](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/configs/ruby/HetSub.py#L24-L69) 创建 64 个 L Router、126 条有向 L 内部通道及独立 VC；[GarnetNetwork.cc:74–111](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L74-L111) 将其与原 M 网络装配；[Router.cc:1320–1344](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L1320-L1344) 按 subnet 走 Hilbert/XY | **已实现（A）**。同 tile 并行及隔离是单独验收对象，不是软件 Router 数量即可证明硬件面积 |
| 真实 16/8/7 B flit、VC/backpressure、每 tile 共享注入/弹出预算 | [NetworkInterface.cc:280–345](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc#L280-L345) 按宽度生成 flit；[NI:503–520](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc#L503-L520) 每周期只授予一次 tile 注入；[NI:605–627](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc#L605-L627) 检查原始消息目的地、flit 序列/总字节 | **已实现（A）**；正式应用无完全排空，不能由应用退出推导无残留 |
| 拥塞驱动的动态 L/M 选择、滞回与局部性 | [HetSubPolicy.hh:70–111](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/HetSubPolicy.hh#L70-L111) 75/50% 滞回、比例累加；[GarnetNetwork.cc:325–353](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L325-L353) 128-cycle 采样、Hilbert 距离≤2 分类；[Router.cc:2374–2389](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L2374-L2389) 每 vnet 最忙 transit 端口为反馈 | **已实现但属于平台适配（A）**，不是原论文逐位同义；ordered vnet 优先固定 M，static 固定 L |
| M 的 PG sleep/waking/active；服务阻塞与唤醒成本 | [Router.cc:2392–2464](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L2392-L2464)：检查 VC/队列是否空闲、50-cycle idle、6-cycle 唤醒、10-cycle 等价转换能耗事件；[Router.cc:1007–1009](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L1007-L1009) 阻断尚未唤醒的授予 | **周期级机制已实现（A）**；不等于真实瓦特/焦耳或工艺级 power-gate 控制 |
| Algorithm 1：Hilbert 单调区间限制 + 运行时走捷径 | [HetSubPolicy.hh:38–52](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/HetSubPolicy.hh#L38-L52) 区间谓词；[Router.cc:1320–1336](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L1320-L1336) 实际端口选择 | **已实现（A）**；现有依赖图只覆盖有限当前资源模型，不是协议层/任意流量无死锁证明 |
| 冻结 long-link / crossbar bypass 与真实窄宽转换 | [HetSub.py:76–113](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/configs/ruby/HetSub.py#L76-L113) 检查物理段和端口冲突；[GarnetNetwork.cc:260–310](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L260-L310) 物理段与 relay 连接；[HetSubRelay.cc:69–143](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/HetSubRelay.cc#L69-L143) 有界队列、连续字节转换与下游背压；[NetworkLink.cc:128–188](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/NetworkLink.cc#L128-L188) 共享 local MUX、冻结旁路的物理段占用 | **已实现，但传播采用 composite-link 的保守周期近似（A）**。中继物理段的 activity 加账不等于每段独立的周期占用/STA；硬件布线闭合不在本范围 |
| Algorithm 2：Hilbert 分层插入、真实 pilot、冲突过滤、冻结输出 | [insert_shortcuts.py:13–111](../tools/hetsub/insert_shortcuts.py) 两级候选、跨子区流量、优先层级、阈值与资源冲突；[run_comparison_campaign.sh:26–39](../tools/hetsub/run_comparison_campaign.sh) seed17 pilot→JSON→seed0 应用；[test_insertion.py:9–48](../tools/hetsub/test_insertion.py) 当前不变量断言 | **实现存在（A），完整层级运行覆盖不足（B/D）**：正式两个应用据结果文档仅选中 4 条 level-1 线；缺“level-2 被实际选择并经数据路径使用”的定向见证 |
| 原始 packet 测量与正确交付 | [GarnetNetwork.cc:364–374](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L364-L374) 原始消息最终完成计量；[NetworkInterface.cc:423–483](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc#L423-L483) tail 入 Ruby 协议队列、最后统计 | **功能已实现（A）**；平均值分母是退出前已接收消息而不是所有注入消息 |
| 面积、实际功耗、原论文 SNN 性能复现 | [GarnetNetwork.cc:538–575](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L538-L575) 仅数据容量/PG/活动代理 | **未实现且非授权范围**；不应作为必须修复 |

**端到端数据流（源码一致的最小模型）**：Ruby protocol MessageBuffer → NI 拆分单播与选 L/M → 有界源 VC/共享 NI 注入 → L Hilbert Router 或 M XY Router →（static 且命中捷径时）L Router → serializer relay → 冻结 M 段代理 / local MUX → deserializer relay → L Router → NI 按顺序重组并最终交付 Ruby。PG 控制 M 常规转发，static 禁止 M 的普通路由，但允许冻结旁路复用其物理段。**此为跨类路径的逻辑表示，不是 RTL 网表。**

## 3. Findings first：问题分级与科研判断

分级：P0 = 一旦确认会使数据路径错误、实验无效的阻断项；P1 = 下一阶段必须关闭的忠实度/证据/结论缺口；P2 = 明确披露即可、不应扩成新工程。**“已确认代码问题”与“覆盖不足/待验证”必须区分。**

| ID | 级别/性质 | 源码证据、影响与处置 |
|---|---|---|
| F-01 | **P1，已确认统计语义问题** | [GarnetNetwork.cc:593–597](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L593-L597) 已说明 link vector **包括虚拟 relay 接入通道**；但 [audit_comparison.py:185–209](../tools/hetsub/audit_comparison.py) 对全部登记链路直接求 \`link_wire_bytes\` 和 Jain。故结果表的 \`wire MB\` 不能直接称“真实物理走线传输字节”或能耗近似精确值；static 路径还存在旁路物理段记账与虚拟访问链路活动的混合。**必须在报告中更名/区分“registered-channel activity”和“physical-segment activity”，明确维度及计数边界；优先对既有 stats/config 做只读重新分类，不先跑新实验。** |
| F-02 | **P1，算法覆盖缺口，不是已确认算法错误** | [insert_shortcuts.py:31–55](../tools/hetsub/insert_shortcuts.py) 定义 level1/2；[test_insertion.py:9–44](../tools/hetsub/test_insertion.py) 仅断言层级顺序和阈值；[正式结果](COMPARISON_10C_RESULTS.md) 报告两个 pilot 最终均 4 条 level-1。尚缺单独构造 \`level1=0、level2>threshold\` 的 profile，并实证产生的 level-2 线在 Network_test 中承载消息。**下一阶段优先补这一条定向机制见证**；不要扩张到全部应用/seed 组合。 |
| F-03 | **P1，结论边界/不可把未完成流量算成完整交付** | [NI:423–483](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc#L423-L483) 以 received packets 计算完成；[audit_comparison.py:173–216](../tools/hetsub/audit_comparison.py) 接受 \`injected>received\` 并标记 \`explicit_network_drain=false\`。v2 应用在途 8–47 条不意味着丢包，但也不能宣称“应用网络全排空”“所有注入消息均完成”；当前结果文档已经正确披露。**只要继续坚持该措辞，暂不构成需改核心代码的缺陷。** |
| F-04 | **P2，方法平台适配，须留在论文明示** | [GarnetNetwork.cc:325–352](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L325-L352) \`Hilbert distance≤2\` 判 local、ordered vnet 固定 M；[Router.cc:2374–2389](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L2374-L2389) 最忙端口代替可能不同的论文采样；这些是迁移映射，不能写“原算法所有细节逐位一致”。 |
| F-05 | **P2，时序与能量模型界限** | [GarnetNetwork.cc:294–295](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L294-L295) 1-cycle abstract 或 \`segments.size()\` 保守延迟；[Router.cc:2440–2452](https://github.com/miuzujia2018-stack/gem5/blob/a90c04ca8aad279876784601f9647c2e0195c763/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L2440-L2452) 的 10 WU 为静态功耗等价事件。不能推导 2GHz 路径物理闭合、J/W 或全面积公平。128/56 只匹配内部链路位宽预算。 |
| F-06 | **P2，跨仓指标不可混作单因素因果** | [audit_comparison.py:110–129](../tools/hetsub/audit_comparison.py) 比较了选定平台签名，但不证明三个独立源码基线只差路由；Jain 的链路集合、子网构成也不同。结果表可保留，但不能用跨网络 Jain 数值直接宣称某一方法负载更均衡；TBP/bak 与 HetSub-off 的时间差是“同冻结平台方法系统比较”，非纯路由因果。 |
| F-07 | **P2，远程证据可复核性缺口** | \`m5out/comparison_10c/formal_10c_v2_20261015/\` 和构建凭据并未作为 GitHub 文本证据入库；[REPORT](../.ai/reports/REPORT.md) 记载两个 \`audit_*.json\` 为 \`ok:true\`，本轮不能独立读取原始 \`config.ini/stats.txt/stdout.log\`。**不得把本次远程源码审查描述为已重新运行 16+21 实验**。不建议上传大体积原始目录或引入多重哈希链；复审时只需在执行机按原命令核验必要摘要。 |

### P0 裁决

本轮**未找到已坐实的 P0**；它只是对所读路径的静态检查结论，并非“证明不存在 P0”。若后续最小测试出现消息少送/重复送、字节不守恒、跨 vnet 错投、合法场景无排空、PG 在活动 VC 存在时休眠、冻结捷径与普通 M 同占一段的反例，立刻升级 P0 并阻断最终声明。单纯 HetSub 性能下降**不**属于 P0/P1，也不能作为改算法参数的理由。

## 4. 下一阶段单一目标与最小实施方案

### GOAL-HS-N1：机制忠实度与统计口径的可归因收口

**研究问题**：当前代码已体现原论文多子网和长链路机制；尚需给出“分层插入确实在下一级触发、物理段复用与统计没有混淆”的**最小因果见证**，使机制描述与实验证据一一对应。不是新算法优化任务，不寻求正收益或重演原文曲线。

| 步骤 | 优先级 | 做什么（最小变更） | 产物 | 判定门 |
|---|---|---|---|---|
| N1-0：论文—源码映射核对 | P1 | 直接逐行核对论文 Algorithm 1/2 伪码及 III-A/III-B 对应条件、阈值、候选顺序、static 与 PG 模式；记录“论文规定 / 当前实现 / 平台适配 / 尚无法比对”。仅补审查文字，不碰核心码 | \`docs/HETSUB_METHOD_FIDELITY_CROSSWALK.md\`（约 1–2 页） | 每个论文决策分支有源码行号、输入条件、差异判定；没有全文则标 \`SOURCE-PENDING\`，不得猜测 |
| N1-1：指标语义修复 | **P1 首做** | 对现有 \`config.ini + stats.txt\` 只读归类物理 M/L 内部段、独立 NI 物理通道、虚拟 relay 接入、静态代理统计；调整 \`audit_comparison.py\` 输出/文档标签，优先不改变采样内核 | 一份单案例分类审计和修订版指标字典；旧结果保留 | 归类和为现有登记链路活动；“物理段”不包含虚拟 relay 访问；未校准活动不写 J/W；若无法可靠识别则明确 \`not computable\` 而不是猜 |
| N1-2：Algorithm 2 两级功能见证 | **P1** | 在既有 \`test_insertion.py\` 新增构造 profile：让所有 level-1 子区之间流量为 0、同一 4×4 区内非相邻 2×2 子区流量超过阈值；固定一次冻结 level-2 配置。使用现有 Network_test 在该配置下做**一项**有限包定向测试；不扩张为应用/seed 矩阵 | 最小 fixture、一个单元测试、一个网络测试输出、审查摘要 | 确实选出 level-2，配置合法；运行时该 shortcut 的物理段 beats **>0**；完整 packet/byte/flit 守恒且所有 NI/VC/relay/link 显式排空；不命中时不能将 \`selected\` 当作已生效 |
| N1-3：旁路服务与 PG 边界 | P1（只在缺见证时） | 先复用现有 \`static7\`、\`static_pilot\`、\`pg_mesh\`、\`independence\` 证据；针对未覆盖的不变量只加 **最多一项**定向对照，比较 M sleeping/waking 与 L 推进、relay 下游阻塞/恢复、local MUX 授权和静态 M 普通 RC=0 | 不变量检查脚本断言/原有日志索引 | \`waking_cycles=6×wakeups\`、\`WU=10×wakeups\`；活动资源不提前睡眠；背压计数正且未丢包；static 中普通 M 路由请求及 buffer write=0 |
| N1-4：最终复审/封版 | P1 | 按本文件表格对新增/更新证据复核，修订“已实现/近似/未实现”；保持 negative results 和 v1 无效记录；GitHub 文档提交与远端 SHA 校验 | \`.ai/reviews/REVIEW.md\` 中 N1 决议 + 对应报告 | 所有 P1 关闭或有明确不能关闭的证据/限制；零未解释失败；源码修改后官方干净构建及运行前 verify；用户审查前推送 GitHub |

### 最小测试预算与停机条件

- **单元测试**：利用 [test_insertion.py](../tools/hetsub/test_insertion.py)；1 个新“level2 非零/level1 零”样例即可；其余 64 位 Hilbert 双向逆映射、合法/非法 path 和阈值边界复用现有断言。
- **模块集成**：复用当前 [validate_network.py](../tools/hetsub/validate_network.py) 的 messages/bytes/flits、relay FIFO≤4、真实物理段 beats、M 普通路由活动=0、排空断言；只为新增层级/测量区分增补缺口，不重建通用测试框架。
- **最小端到端**：最多 1 条针对 level-2 shortcut 的有限包 Network_test；对同代码版本原有 21 项是否需要全部回归，由是否改变数据路径决定。只改审查文档或离线分析脚本时**无需重新编译/重复跑 21 案例**；改 gem5 运行代码后才执行官方干净构建与必要回归门禁。正式 backprop/kmeans 16 次对比**不重复跑**，除非发现使已有数据失效的 P0 或配置漂移。
- **硬失败标准**：任一来源不明的统计混算被拿来声称真实功耗；level-2 测试 zero hit 却报告机制通过；无效/非法 shortcut 未拒绝；非零残留却标全网排空；源码变动后使用旧二进制；以上立即 FAIL，停止扩表和调参。
- **明确不做**：新增 SNN 软件栈、Noxim/RTL/后端、在线全局重配置、无科研动机的消融/新 workload sweep、强迫 38%/58% 正收益、增加哈希数据库/多级摘要、重构 Router 大型遗留文件、重跑所有已确认历史配置。

## 5. 执行契约与最终输出

1. 当前仅授权**审查文档提交**；N1 代码修改、网络运行、正式实验都属于将来的实施步骤，**本轮未授权执行**。
2. 下一阶段若需要执行，先在 \`.ai/tasks/TASK.md\` 冻结具体改动文件和一项新定向场景，再最小修改；严格复用 \`tools/reproduction/verify_gem5_build.sh\`，不得手工录入或绕过凭据。
3. 验收只问：“论文决策机制是否由真实源码实现、定向输入能否引出预期状态和活动、是否正确守恒和交付、差异有没有被清晰披露？”不以性能是否优于 XY/bak/TBP 判断复现成功。
4. 任何阶段性请用户审查或确认之前，依 AGENTS.md 先提交并推送 GitHub，核对父仓/子仓 SHA，附可直接访问的 Markdown 链接；仅文档改动不触发源码指纹重建。

**终态定义**：N1 的两项核心 P1——**物理/虚拟链路指标可辨**、**Algorithm 2 level-2 实际命中且守恒排空**——形成可复核的固定证据；其余机制通过原有数据路径源码与既有定向测试封口，未知处明确保留。此时才把“完整覆盖已选择的周期级核心机制”作为不夸大的结论。
