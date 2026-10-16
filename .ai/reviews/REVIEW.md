# Review — HetSub 最小适配设计（2026-10-15）

## 2026-10-16 全面 Code Review

最新完整审查见 [HetSub 方法复现全面 Code Review 与下一阶段研究计划](../../docs/HETSUB_COMPREHENSIVE_CODE_REVIEW_AND_NEXT_PLAN_20261016.md)。本轮直接核对论文全文、冻结源码和已有原始产物，未修改核心代码、未重新运行仿真。结论：未发现新的 P0/P1；核心机制均进入真实数据路径；动态选择、local/global 定义及 composite shortcut 时序属于已披露的平台适配。裁决为方法完整性 `CONDITIONAL`、算法正确性 `PASS`、固定平台性能基准资格 `PASS（限定）`，综合 `CONDITIONAL APPROVE / FREEZE`。

下一阶段不再开发机制或扩充测试矩阵，只执行文档定义的 `GOAL-HS-R2`：论文级证据—主张闭环和负结果分析。`review_independence: same-family`；`acceptance_status: provisional`。

## GOAL-HS-N1 最终独立 Code Review（2026-10-16）

**Verdict: APPROVE — GOAL-HS-N1 P1 最小闭环完成；继续保留 10-cluster 固定平台 HetSub 核心机制复现的限定性批准。** 本轮审核以父仓 `50b52f0a552f7612925e58de72d2348baf7f7217` 为冻结基线，比较 `d2c1a4a...50b52f0a`（3 个提交，10 个修改/新增文件）；父仓五个子模块 gitlink 未改变。**无已确认 P0；本审查未运行仿真，也未读取被忽略的本地原始 `m5out`、build 凭据及 reanalysis JSON。** 因此“22 项全部 PASS / 重分析 ok:true”属于提交报告中的运行证据声明，不是本次 GitHub 审查独立重跑的结论。本裁决认可源码、定向断言和报告链相互支持的范围。

### Findings first（N1 封口）

1. **N1-1 / P1 — CLOSED（固定平台统计口径）。** `tools/hetsub/audit_comparison.py:89-91,190-221` 将 `het_relay_links*` 归为虚拟 relay 接入，其余当前冻结配置登记通道归入物理；输出 `registered_channel_activity_bytes`、`physical_wire_bytes`、`virtual_relay_access_bytes` 及 `physical_link_load_jain`。`docs/COMPARISON_10C_RESULTS.md:9-39` 将物理/虚拟活动分列，仅物理链路参与表中 Jain。静态 backprop 128/64 的 `38.27+1.42=39.69 MB`，kmeans 128/64 的 `41.37+1.54=42.91 MB`，与旧“全部登记通道”数值一致；非 static 无虚拟 relay 活动，指标不应改变。**已纠正的只是指标语义及离线计算，不是重新计时、能耗测量或源仿真行为变更。** `link_peak_to_mean` 仍使用所有登记链路，若未来使用须标记为 all-registered metric，不得误称物理峰均比。分类器 `else physical` 对未来未知通道名称不是 fail-closed，但在本次冻结命名范围内不构成阻断；后续新增链路类型时才需复审分类规则。
2. **N1-2 / P1 — CLOSED（level-2 选择及实际旁路承载）。** `tools/hetsub/fixtures/profile_level2.csv` 只有 (10→17, 1152 B)，`static_level2.csv` 的全部 level-1 为 `below_threshold` 且只有 `2,10,17,1152,selected`；`static_level2.json` 冻结路径 `[10,9,17]`。`tools/hetsub/test_insertion.py:46-57` 直接断言选择、层级与唯一性。运行入口 `run_network_checks.sh:54-57` 使用 static/56-bit M/transpose/16 包每 tester；`validate_network.py:120-133` 核验运行配置路径、第一 relay `completed_frames>=16`、两 relay 收发帧/flit 对等、真实旁路 segment beats 与统计一致，通用校验同时检查总 packet/bytes/flit 守恒、排空、M 普通 RC/写 buffer 为 0。这是一条**真实运行路径的可执行验收门**，不是只查看离线配置。报告声称 48 帧、1792 B、136→294 flits、1176 segment beats；独立算术复核：`22×72+26×8=1792`、`22×5+26×1=136`、`22×11+26×2=294`、`294×4=1176`，相互一致。**注意：`completed_frames>=16` 及聚合计数只能证明冻结 level-2 relay 的实际使用；并不能逐包归因证明 tester 10 的每一个包均走该捷径。当前 TASK 验收只要求实际命中，而非该更强命题。**
3. **N1-3 / P1 — ACCEPTED AS REPORTED。** `run_network_checks.sh:16` 在原 21 项上只增 `static_level2` 一项；`.ai/reports/REPORT.md` N1 节记一次 22 案例全 PASS（exit0，目录 `m5out/hetsub_network/20261015T152707Z`），5 个插入单元测试通过。历史 `20261015T151741Z` 首次“帧数必须恰好16”断言失败已经记录；失败源于过强的**测试归因假设**，不是证明被测数据路径丢包，后修为 `>=16` 仍要求路径、守恒与排空。本审核未取得原始 stdout/stats，故不写“独立复核 22/22 日志”。
4. **N1-4 / P1 — CLOSED BY THIS REVIEW。** 提交成果与审查路径固定；源码 diff 不涉及 `gem5/`、`gem5-gpu/`、`gpgpu-sim/` 等指纹仓；脚本中仍于每次模拟前调用 `verify_gem5_build.sh verify`。只改父仓文档与 helper，不因本评审触发 gem5 官方干净重建；不授权再次运行正式三仓 16 个应用实验。

### 本次终审按不变量的验收表

| 机制/门槛 | 源码、测试器或受检证据 | 判定及边界 |
|---|---|---|
| 已有正式应用平台与数值正确性 | `docs/COMPARISON_10C_RESULTS.md`，历史 v2 审计 | **维持此前有限 APPROVE**；不是本次重新执行的结果 |
| 统计区分物理与虚拟通道 | `audit_comparison.py:89-91,190-220`；结果表静态行的加法可复核 | **PASS（静态定义/算术）**；reanalysis JSON 的 `ok:true` 为本地报告，未在此独立打开 |
| Algorithm 2 level-2 唯一选择 | `test_insertion.py:46-57`、两份提交的 fixture | **PASS（源码断言可检查）**；报告称 5 tests OK |
| level-2 frozen bypass 真正使用 | `run_network_checks.sh:54-57`，`validate_network.py:120-133`；报告 48 frames/1176 beats | **PASS（设计与已报告运行吻合）**；缺 per-source flit 路径归因，但该更强主张未作为验收 |
| 有限包守恒与排空 | `validate_network.py:33-49,82-151`：1024 received/injected、有效 bytes、flits、relay、`het_busy_resources=0`；报告数值一致 | **PASS（报告 + 断言）**；不得将此转移为应用退出全网排空 |
| PG、背压、流控、非法配置拒绝 | 原有测试断言 + REPORT N1-3 声明 22/22 | **维持通过（非独立重跑）**；不做多余新矩阵 |
| 性能/面积/能量外推 | `COMPARISON_10C_RESULTS.md` 明确负结果、内部链路预算、代理统计 | **仅限固定平台迁移评估**，不批准论文收益/RTL/工艺 J/W/硬件面积等价的外推 |

### 最终裁决、科研建议与范围

- **GOAL-HS-N1 关闭，两个 P1 已有最小充分机制证据；无需为此增加任何实验。** 本次无新的已确认 P0。对 `N1-1` 输出的“physical wire MB”应始终附上“登记物理通道上的 flit×width 活动代理”的口径，不能当作耗能、实际线长或芯片面积。
- **48≠16 为合理现象而非修改成功标准**：源节点之外的包亦可抵达 router 10，符合 Algorithm 1 单调条件后使用相同静态 relay；测量只证明聚合路径活动及全网守恒。若将来论文需要声称“指定源的16包全部命中”，须另补逐源计数，但**不是本任务的 P1 或后续强制前置**。
- 正式应用均为未全网排空的退出时点统计（在途 8–47），服务延迟人群严格为已接收消息；不得写零丢包/全应用包排空。HetSub 在 backprop/kmeans 上的负收益继续保留；不因负结果修算法或补无关 workload。
- 本次只更新 `.ai/reviews/REVIEW.md`；后续若没有新的、可定位的机制反例或核心科学问题，应**冻结代码与实验**，无需另开 GOAL 或扩充 matrix。审核报告旧批次段落是历史记录，以上裁决优先。

---


## 最终复现审查（10-cluster固定平台）

### Findings first

1. **应用退出没有全网排空。** 16个正式运行全部正常退出并通过数值检查，但各有8–47个在途消息；应用延迟只适用于退出前已接收原始消息。有限包21项检查提供独立完整排空证据。
2. **性能为负结果。** 相对HetSub-off/XY，dual在backprop/kmeans总时间分别约+4.8%/+12.7%，static约+5.5%至+17.1%。不影响机制验收，也不能外推为原论文SNN结果。
3. **资源等价仍有限。** 128/56只对齐内部链路位宽预算；外部NI线路、buffer、mux/control、长线和工艺功耗不具备完整等价或校准。
4. **平台审计发现并修复真实缺陷。** v1的HetSub/TBP GPU L2 `start_index_bit=47`与bak的13不一致。修复后官方重建并全量重跑；只有v2被批准为固定平台迁移结果。

### Verdict

**APPROVE，限HetSub核心方法在当前平台的机制复现与迁移比较。** v2两个审计均通过，三仓实际平台、输入、seed和测量口径一致；方法活动、独立数值正确性、构建凭据、有限包守恒/排空与核心数据路径证据齐全。批准“已实现/近似/未实现”表及当前平台负结果；不批准原论文性能复现、总面积等价、实际能耗或任意流量无死锁的扩张性结论。

逐项证据和数值见`docs/COMPARISON_10C_RESULTS.md`，原始正式目录为`m5out/comparison_10c/formal_10c_v2_20261015/`，最终Network_test为`m5out/hetsub_network/p8_final_20261015/`。

## 实施阶段检查（未最终批准）

### 资源与能量审查补充

- 26个已有运行的显式数据存储计数及PG状态分解核验通过；资源表见RESOURCE_AUDIT.md。
- **范围限制：** “128/56等预算”只涉及内部链路。NI接入线路安装位宽仍增加43.75%，pipeline/control/mux/crossbar没有完整面积映射；不批准总硬件等预算或面积节省结论。
- 原文WU为10-cycle等价事件成本；历史能量公式已澄清，防止再叠加6-cycle waking导致重复计费。现阶段只发布状态/事件，无功耗校准结果。
- 应用pilot的R=2字节局部性只有约5%，未调整映射或输入掩盖该差异。GPU口径待答复期间保持源码平台不变。

### p6优先发现

1. **正式比较平台不一致，需确认后修正口径。** 本仓/TBP实际gem510个CudaCore而GPGPU-Sim16 clusters；bak无硬编码且默认40 clusters/8dir/8L2。当前仅数值机制验证，不批准三仓性能比较。用户AGENTS固定CPU/GPU约束优先，已异步询问10 clusters方案，答复前保持现状。
2. **应用退出不等于网络排空。** 当前10个应用检查正常退出且CPU参考数值匹配，仍有16–34个在途消息；延迟只统计已收到消息，不能报告全网排空或把差额认作已证明丢包。合成21项另有排空证据。
3. **一键应用测试曾失败。** p6源码干净构建、凭据记录/验证成功；旧Bash空数组导致测试尚未仿真就退出1。启动脚本兼容修复后同已验证二进制run.sh both退出0，不能将首次一键命令写成通过。
4. **新增证据。** 21项网络检查exit0；同tile独立性/阻塞隔离、原始packet完成指标、NoC通道依赖枚举均通过；10个应用（off及dual/static×两宽度）独立CPU数值通过，static旁路活动存在、M普通RC/buffer为0。
5. **统计限制。** 旧PerformanceAnalyzer与分段flit均值不用来比较；packet指标已独立实现。旧kmeans RMSE整型截断、backprop保留bias槽未初始化已披露，数字验证依据有效输出。

以下为历史阶段检查，最新证据以REPORT p6节为准。

- p4干净构建及十五项验证已PASS，原始数据`m5out/hetsub_network/20261015T070634Z/`。16↔8/7转换、单双shortcut、配置冲突拒绝、M RC/buffer零活动及显式排空有实际证据。p5干净构建及独立pilot/三模式压力实际运行也已完成。20个保留案例在修正Transpose覆盖断言后重检通过；该案例另有重跑PASS，见REPORT。

- 最新官方干净构建`build_logs/hetsub_network_p3_clock_congestion.log`及凭据验证成功。
- `m5out/hetsub_network/20261015T063402Z/`九项实际检查PASS，exit 0。关闭XY、L、两种M宽度、低负载/拥塞策略、PG及1/2GHz对照均有本次证据。
- policy_load交付1024包，L978/M46；旧版无分流问题已在该场景得到修复证据。反馈范围改为每vnet最忙transit端口，属平台适配，须披露。
- 时间对照12000 cycles分别为6000000/12000000 ticks，1ps分辨率已验证。
- p5独立pilot seed17导出913个流量对，生成4条冻结配置；seed42正式测试交付1024包，737下游阻塞周期、9次local MUX延后，物理段计数与帧宽度转换及运行时配置一致。
- **仍缺失：** CPU/GPU应用及其pilot/配置对齐、独立并发与阻塞隔离的专门证据、通道依赖检查及packet完成时间指标。不能用已改变语义的旧flit平均延迟比较方法。
- 现有合成检查已覆盖三种traffic、72-byte跨四槽FIFO的流式转发、在途容量和显式排空；尚未证明任意流量/协议无死锁。VC、staging和relay已分别列账，传播pipeline的存储/时序建模假设仍须在最终结论披露。
- 当前为Codex实施过程中的自检记录，无独立Claude执行报告可供最终审查。整个HetSub实现未获最终批准。

## 后续设计修订

用户继续要求固定实验平台下最大程度复现。已形成 [独立双子网方案](../../docs/HETSUB_FAITHFUL_PLATFORM_PLAN.md)，将固定边界收敛为系统平台与tile映射，允许论文必需的NoC资源组织变化。发现8×8有限Mesh中直接采用128/64子网宽度，内部总链路位宽较224条128-bit基线多6.25%；文档区分论文比例与128/56等预算配置。前一版共享端口模型只能作低成本适配，不足以代表原文异构独立子网。上述均为设计推导，不是已验证实现；实现审批仍待测试证据。

## Findings first

1. **比较配置不一致**：本仓网络默认4 VC/无限buffer/4级，bak/TBP为2 VC/深度4/2级；拓扑RNG种子规则也不同。需要先对齐实际config和MachineID映射。
2. **旧需求与原文有偏差**：Table I为dual-line 2 flits、Mesh 4 flits，Fig.13另用4/8；长链路模式为静态配置、关闭动态子网选择；PG转换能量应按每次唤醒计入。
3. **实验统计不适合直接扩展**：parser固定包长及tick=cycle；NetworkTest以curTick判断simCycles。新比较必须显式校正时间口径和packet/byte计数。
4. **代码路径不能仅换标签**：本仓仍是XY；旧最短路径表可能否决Hilbert绕行；NI存在错误vnet redirect；ordered VC与escape需要显式处理。
5. **shortcut是主要实现风险**：直接投递远端、无限relay buffer或只减延迟都不合格。必须保持物理链路容量、背压、有限缓冲和正确交付。

## Verdict

已完成论文及代码阅读并形成可交接的设计规格；**尚未批准任何 HetSub 实现或性能结果**。本轮无新的Claude实现diff可审，未运行新实验。

对应规格：[HETSUB_MINIMAL_BASELINE_PLAN.md](../../docs/HETSUB_MINIMAL_BASELINE_PLAN.md)。后续按其第7、9节提供测试证据后再进行实现验收。现有构建凭据只证明其对应源码/binary，不能补认证旧结果。

---

# Historical Review — Synthetic Traffic Workflow

## Verdict

Approve

## Must Fix

- None.

## Should Improve

- Consider teaching `scripts/run_synth_sweep.sh` to accept optional pass-through arguments such as `--sim-cycles` for cheaper smoke verification in the future.

## Tests Still Needed

- None required for the current task.

## Notes

- The original must-fix issues are resolved at the artifact level:
  - host raw `stats.txt` samples now match `results.csv`
  - Docker no longer needs to plot
  - stale `uniform/` directories no longer pollute parsing
