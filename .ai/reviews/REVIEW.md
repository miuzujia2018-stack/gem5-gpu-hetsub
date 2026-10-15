# Review — HetSub 最小适配设计（2026-10-15）

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
