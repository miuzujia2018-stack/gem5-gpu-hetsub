# GOAL-HS-R4：HetSub 机制证据闭环与公平性边界（只读阶段）

日期：2026-10-16。角色：科研方法审稿人 + gem5/garnet Code Reviewer。
本文件同时是独立源码抽查记录、下一阶段研究裁决和可执行的 Claude Code GOAL；不构成重新开启 R3 的授权。

## 0. 裁决优先（findings first）

**结论：CONDITIONAL APPROVE / FREEZE，建议执行 R4-DOC（只读文稿/证据），不执行 R4-IMPL。**

- **P0/P1：本次所检查源码范围内，没有新的已确认阻断缺陷。** 不把“未观察到反例”表述为“任意流量已经形式化证明正确”。
- **P2/披露：** 拥塞反馈采用“每 vnet 最忙 transit 端口”而不是原文“router 全部端口总 buffer 占用”；有序 vnet 钉在 M（单一路径保证 Ruby 顺序）；128-cycle 请求触发采样；静态 bypass 的 pipeline/线长为代理模型；PG 是周期与 WU 记账，非 J/W；128/56 只近似内部链路等预算。
- **精度修正：** shortcut 不能概括为“每节点总数上限 1”。`configs/ruby/HetSub.py:92-103` 和 `insert_shortcuts.py:67-82` 按 (tile, 输入/输出端口或方向) 及有向物理边去重；一个 tile 能在不冲突的端口参与其他路径。注意：同一 tile 作为起点（或终点）时的本地接入位冲突仍会限制相应角色，二者不矛盾。
- **证据边界：** 本次通过 GitHub 独立读取代码与已提交报告；未取得完整原论文 PDF 重新逐页复核（R3 报告记录过执行侧 PDF 阅读）、未读取被 gitignore 的 `m5out` 原始批次、未在本地构建或运行测试。因此，源码存在性/逻辑路径属于本次直接检查；22-case PASS、16-case 结果、依赖图统计及构建凭据为已有审查记录，**不得写成本次新执行的测试**。
- **论文范围：** 论文为 Y. Li 等，`HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems`，IEEE TVLSI 33(11), 3131–3144 (2025)，DOI: 10.1109/TVLSI.2025.3597406。原文所演示 long-range link 配置为静态，运行时按流量重新插入属于 future work。初始化配置是平台适配，不应凭“没有在线重配置”重新升为 P1。

## 1. 冻结对象与审查基准

- 父仓：`miuzujia2018-stack/gem5-gpu-hetsub`，`synthetic-traffic-three-patterns`，R3 封口 HEAD `a2459724742de714debef68e84354852cee78959`，其父为终审 `866c19c6`。
- 子模块：gem5 `a90c04ca`，Graphite `e3ab0ecf`，benchmarks `35d75506`，gem5-gpu `e53ac264`，gpgpu-sim `17f16f10`；以后续 GitHub 远端快照核对为准。
- 证据入口：`docs/HETSUB_R3_DEEP_SOURCE_REVIEW_AND_ADJUDICATION_20261016.md`；`docs/HETSUB_R2_CLAIM_EVIDENCE_AND_LIMITATIONS_20261016.md`；`docs/COMPARISON_10C_RESULTS.md`；`.ai/reviews/REVIEW.md`；`.ai/reports/REPORT.md`。
- 指标与目标：只要求复现核心算法、资源/数据路径和约束；不要求原 SNN 环境、原始实验配置、数值/曲线、面积或功耗结果，也不要求性能正收益。

## 2. 机制—源码—证据矩阵（本次源码独立抽查 + 历史运行证据）

源码均相对 `gem5/`（下述 `fp/` = `src/mem/ruby/network/garnet/flexible-pipeline/`），其余路径相对父仓。

| 机制 | 本次直接查到的源码路径 | 既有证据（引用，不宣称本次复跑） | 裁决 |
|---|---|---|---|
| ① 独立 L Hilbert line 与 M XY Mesh | `configs/ruby/HetSub.py:51-69` 生成 64 个 L router 与 Hilbert 双向线链；`fp/GarnetNetwork.cc:221-257` 装配；`fp/Router.cc:1323-1344` 分路由 | R3 independence 检查、22-case 套件 | 已实现，当前 8×8 平台 |
| ② Hilbert 单调路径 | `fp/HetSubPolicy.hh:19-52` rank/next/shortcutAllowed；`fp/Router.cc:1332-1335` 实际出口决策 | R3 所列 4096 路径及 262144 三元组断言 | 已实现 |
| ③ 16/8/7-byte flit 与实时宽度转换 | `fp/HetSubPolicy.hh:55-68`；`fp/HetSubRelay.cc:76-143` 的 byte 转换；`fp/NetworkInterface.cc:280-340` format/VC；`fp/NetworkLink.cc:150-152` fatal 守卫 | 网络套件字节/flit 守恒 | 已实现 |
| ④ 动态子网选择 + 滞回 | `fp/HetSubPolicy.hh:77-109` 滞回、quarters、preview/commit；`fp/GarnetNetwork.cc:326-353` 请求触发采样、强制模式及提交 | policy_load 分流记录与历史定向测试 | 已实现；信号口径和周期为近似 |
| ⑤ ordered vnet 协议顺序 | `fp/HetSubPolicy.hh:98-103` ordered→M；`fp/GarnetNetwork.cc:330-331`；`fp/NetworkInterface.cc:306-326,423-464` | 无 NI-WARN 的有限包验证（历史） | 协议适配，P2 方向差异 |
| ⑥ M 的 PG 三态/唤醒 | `fp/Router.cc:2392-2466` ACTIVE/SLEEP/WAKING、6 cycles、10 WU | R3 pg_mesh 212 次 WU、1272 waking cycles | 已实现周期代理；非实际功率 |
| ⑦ 静态物理 bypass | `configs/ruby/HetSub.py:79-113` 配置检查；`fp/GarnetNetwork.cc:260-311` 连接；`fp/NetworkLink.cc:176-188` 独占物理段 | static8、static_level2 物理 segment beat、排空 | 已实现；时序/线长未工艺校准 |
| ⑧ 有界 relay、credit/backpressure | `fp/HetSubRelay.cc:33-74,76-143` 单 vnet frame、4 槽、1 staging、grant/release、阻塞 | 已存定向流控/帧数/守恒证据 | 已实现；有限包证据≠通用证明 |
| ⑨ Algorithm 1 单调 shortcut | `fp/HetSubPolicy.hh:48-52`；`fp/Router.cc:1333-1335` | R3 test_policy 与 static_level2 实际流量 | 已实现 |
| ⑩ Algorithm 2 分层插入 | `tools/hetsub/insert_shortcuts.py:18-109` 候选分层、非相邻子块、flow 阈值、路径资源冲突、limit；`configs/ruby/HetSub.py:83-108` 再检验 | `test_insertion.py` 五项、level2 定向案例（历史） | 已实现；限制/优先级须如实描述 |
| ⑪ 端到端交付与验证 | `fp/NetworkInterface.cc:423-464`；`tools/hetsub/validate_network.py` 守恒、配置和退出检查；`tools/hetsub/check_dependencies.py` 枚举通道依赖 | R3 22-case PASS、正式 v2 两份 audit ok:true（历史） | 在被测范围已闭环；不声称任意流量无死锁 |

源码文件的存在不等于测试通过；历史数值如无可访问的原始 `m5out`，必须标明“依据 R3/R2 记录”。

## 3. 与论文本体的差异及科学影响

1. **动态 long-link**：原文演示静态配置；在线改连是 future work，不是本轮必需复现项。硬件 special-packet 预装与仿真初始化冻结 JSON 的“配置已生效”功能语义可等价，但配置传输成本并未建模，必须披露。
2. **拥塞**：每 vnet 最忙 transit 输出端口 vs 原文全部端口总缓冲占用；128-cycle 请求到达时采样。滞回与有记忆的双向分流代码真实存在；不能声称拥塞观测与原文逐字相同。
3. **ordered vnet**：Ruby 协议顺序决定只能走一个子网；本实现固定 M，而原文优先选择 L。属于可辩护的工程适配，非绝对同构。
4. **PG、时序和面积**：6-cycle WU + 10 WU/唤醒是仿真模型；不是已标定 Joule、Watt 或 2 GHz timing closure。`128/56` 与纯 Mesh 的近似预算只约束内部线宽，总架构面积未被证明等价。
5. **shortcut 的资源约束**：分别核查 per-port/per-direction 冲突、起点/终点 L 接入、每条有向物理边、独占 bypass；避免把实际算法误写成“每节点总数≤1”。
6. **测试范围**：通道依赖图 acyclic 只对所枚举 NoC 路由资源和指定配置成立，不覆盖 Ruby 协议依赖或所有运行状态；有限包排空不等于任意流量无死锁。

只有发现**具体输入/状态可达的关键机制反例，且能提供源码路径或现存原始证据**，才建议重新打开 P1；其他精度/措辞差异列 P2，不以偏好取代缺陷证明。

## 4. R2-3 公平性边界，R4 必须逐条对照最终文稿

- [ ] 当前应用的局部性不满足论文主要假设：pilot 按字节 Hilbert 距离 ≤2 约 5.68%/5.27%，不能外推到 SNN。
- [ ] 三仓平台项目 16 CPU/10 GPU clusters/4 Directory/40 L2/64 tile/72 端点、输入、seed 与主要设置统一；但源代码非路由部分并非逐行相同，跨仓差值不能完全归因于路由算法。
- [ ] 只使用 `formal_10c_v2_20261015`，v1 因 GPU L2 索引位错误判无效；不能混用。
- [ ] `wire MB` 是物理登记链路 flit×width 活动量，virtual relay 单列；Jain 在不同登记链路集合间只能谨慎解读；均不能写成真实能耗。
- [ ] 应用正常退出但存在 8–47 个 in-flight 消息；统计人口为退出前已接收消息，不能宣称应用级全网排空。
- [ ] `128/56` 仅涉及内部链路近似预算，NI 接入、buffer/mux/crossbar/control、总面积没有等价证明。
- [ ] pilot seed 17、正式 seed 0；pilot eligible-region fraction 24.86%/24.66% 与 formal relay-converted/injected 38.24%/38.89% 定义和集合不同，禁止直接当成相同“命中率”。
- [ ] static propagation segments-cycles 是保守模型，PG 10 WU 是无工艺系数的代理。
- [ ] 正式负结果如实保留：backprop HetSub vs 同仓 off/XY 时间 +4.80%～+6.46%；kmeans +12.68%～+17.13%。禁止把解释性机制假设写成经隔离实验确认的单因子因果结论。
- [ ] 不照搬原文 38%/58%/16% 作为当前平台收益；明确“机制复现/平台迁移”，不称“原始性能复现”。

## 5. 下一阶段执行计划（唯一 GOAL）

**GOAL-HS-R4-DOC：冻结代码不变，完成论文方法描述、证据可追溯和比较公平性收口。**

### R4-0 基线门禁（只读）
确认远端父仓/五个 gitlink 的既定 SHA，以及 `.ai/reviews/REVIEW.md` 最新结论；确认没有 R3 以后的核心代码修改。禁止将旧结果和新的未验证二进制混写。若仓库已发生变化，记录差异并停下当前裁定，不自动变更算法。

### R4-1 方法正文（不制造新科学结论）
编写 `docs/HETSUB_R4_METHOD_DESCRIPTION.md`：依论文 III-A/III-B/Algorithm 1/Algorithm 2 顺序，分段说明独立 L/M 子网、packet 选择、flit 宽度转换、PG、静态 shortcut、真实旁路、Algorithm 2。每段至少包含：原文方法要点；冻结代码入口 `path:line`；实际 flit/VC/credit 或资源传递路径；既有运行证据文件；偏差/边界。不能把相关源码名称简单罗列冒充调用链。

### R4-2 公平性逐条审查
编写 `docs/HETSUB_R4_FAIRNESS_AND_CLAIMS.md`，把第 4 节各项映射到论文方法、实验设置、结果讨论或局限性段落（可写推荐文案）；对 `COMPARISON_10C_RESULTS.md` 中两应用五种 HetSub 配置与对照项检查分母、方向、单位和被比较对象。保留负结果、应用在途、pilot/formal 两种定义和 v2 唯一正式批次。

### R4-3 审稿主张表与缺口清单
编写 `docs/HETSUB_R4_CLAIM_EVIDENCE_INDEX.md`：逐项列出主张、论文来源（章节/页）、源码、既有原始证据路径、证明级别（源码直读/历史数据/理论推断/工艺未验证）及可公开的精确表述。单独标出不能主张的事项。若发现新问题必须附最小反例和影响；**不得为了“完成下一阶段”虚构 P1 或修复工作量**。

### R4-4 终审与收口
报告 findings first，明确 `PASS / CONDITIONAL / BLOCKED` 三者之一。若无新增已确认 P0/P1、文稿断言有来源、R2-3 十项已检查，裁定 `R4-DOC CLOSED / CORE FREEZE RETAINED`。R4 文档变更可按仓库流程单独提交/推送；不得触动核心实现、历史结果或重写 `.ai/reviews/REVIEW.md` 的既有 R3 终审记录。

## 6. 测试设计与验收门槛（最小充分）

**本阶段默认不重跑模拟器。** 审查者首先只读既有 `test_policy.cc`、`test_insertion.py`、`validate_network.py`、`check_dependencies.py`、正式审计 JSON 的记录/路径及 R3 7 项门禁记录。如本地确实有原始证据，可以运行已有离线脚本重算；不得以缺少被 gitignore 的 m5out 为由凭空宣布新 PASS 或触发重跑。

| 门禁 | 可执行判定 | R4 默认动作 |
|---|---|---|
| Hilbert 与 Algorithm 1 | rank/next 单调；shortcut 只能严格向目的地 rank 前进 | 检查冻结源码及已有 test_policy 断言 |
| Algorithm 2 | 分层优先、非相邻、阈值、2-hop 以内物理路径、端口/边资源不冲突 | 检查源代码及现有五项测试结果；不扩矩阵 |
| Relay/网络 | 物理带宽、4 槽 FIFO、staging、grant/release、有限包 packet/byte/flit 守恒 | 检查已有静态定向结果；没有原始文件则注明依据既有报告 |
| 动态选择/ordered | 阈值滞回、quaters 比例、ordered 不跨 L/M | 源码 + 历史 policy/NI 结果；不重做应用 |
| PG | `waking_cycles = 6 × wakeups`、`WU = 10 × wakeups` | 引用既有 pg_mesh/formal 证据，非功耗证明 |
| 公平性与结果 | 表格每项的 seed、时钟、分母、样本人口、资源分类、对照对象无误 | 第 4 节全部完成、负结果完整 |

**只有重新开启机制修复时**，才授权提出对应的 **一个最小单元断言 + 一个最小端到端定向情景**，并说明为何旧测试无法发现反例；须先取得用户批准。若触及模拟器源码，必须重新履行官方干净构建和 `verify_gem5_build.sh` 凭据门禁。禁止无关重构、通用框架、大型矩阵、逐文件/逐包哈希或重跑 16 应用。

## 7. Claude Code 可复制执行指令（GOAL）

> 扮演精通 IEEE TVLSI NoC 方法复现、gem5-gpu flexible Garnet 和硬件仿真科研诚信的独立审稿人。执行 GOAL-HS-R4-DOC，不执行算法改造。
>
> 先验证父仓 `a2459724` 与五个冻结 gitlink，阅读真实源码、`docs/HETSUB_R3_DEEP_SOURCE_REVIEW_AND_ADJUDICATION_20261016.md`、`docs/HETSUB_R2_CLAIM_EVIDENCE_AND_LIMITATIONS_20261016.md`、`docs/COMPARISON_10C_RESULTS.md`、`.ai/reviews/REVIEW.md`。不可仅复述旧 PASS，要求区分“直接代码事实”与“历史运行证据”。能获得原论文全文时独立核对关键段落；否则明示 PDF 证据边界，不编造引文。
>
> 按本文件第 2 节十一项机制，从论文语义 → 源码调用/数据路径 → 既有测试/运行结果 → 边界四层核查；优先检查 Hilbert、动态选择、flit 转换、有界 relay/backpressure、静态物理段独占、Algorithm 1/2。只对明确的、能给出可达输入或实际代码证据的关键问题标 P0/P1；其他偏差标 P2 或披露。尤其不得把静态配置误判为缺失在线 long-link，不得写“每节点总数上限1”。
>
> 下一步唯一执行目标是产出 `HETSUB_R4_METHOD_DESCRIPTION.md`、`HETSUB_R4_FAIRNESS_AND_CLAIMS.md`、`HETSUB_R4_CLAIM_EVIDENCE_INDEX.md`。逐项完成本文件 R2-3 公平性清单，核对 v2 唯一正式、应用未排空、计量与分母、物理/虚拟活动量、128/56 边界、pilot/formal 不同口径，完整保留性能负结果。不得以原论文收益或当前 XY 负收益决定方法是否完成。
>
> 测试遵守最小充分：默认只读复核已有测试、已保存结果及构建凭据；不得运行新的 gem5、重跑网络套件或大规模实验，亦不新增测试矩阵。只有发现可达 P0/P1 反例才提出最小单元 + 最小端到端验证方案，等待明确授权。禁止修改任何核心源码、运行时配置、历史结果、冻结 gitlink、`.ai/reviews/REVIEW.md`；禁止重构、重复哈希系统。
>
> 文档完成后用 findings-first 报告：发现编号/优先级、论文页码、`file:line`、现有证据路径、缺口、可公开主张和禁止主张、PASS/CONDITIONAL/BLOCKED。R4-DOC 仅在每个方法断言可追溯、公平性条目全部核对、无未经证实的 P1 时 CLOSED；核心项目继续 FREEZE。仅提交/推送新文档，按项目 GitHub 流程核实远端，不强推，并提供文件链接。

## 8. 明确禁止的范围扩张

不复制原论文 SNN/RTL、工艺数据或数值；不要求超过 XY/TB-TBP 的性能；不实现论文 future-work 在线 shortcut 重布线；不为外部评价“好看”做调参；不宣称完整面积/功耗/时序等价；不把 channel-dependency 无环推广为 Ruby 级所有流量的无死锁证明；不把静态运行的 proxy 段活动量误称 ASIC 实际功耗。

**最终完成标准：文稿可核对、主张不过界、负结果留存、已有机制冻结。**
