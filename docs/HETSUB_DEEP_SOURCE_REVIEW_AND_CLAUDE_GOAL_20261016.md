# HetSub 冻结代码深度审查、机制忠实度门禁与 Claude Code Goal

> 日期：2026-10-16
> 父仓：`miuzujia2018-stack/gem5-gpu-hetsub`，分支 `synthetic-traffic-three-patterns`，审查基线 `e3c8a72e24c91bd3c01f15030e5ff34fac75b6d1`
> 核心代码：`gem5` gitlink `a90c04ca8aad279876784601f9647c2e0195c763`；其余 gitlink：`gem5-gpu e53ac2648`、`gpgpu-sim 17f16f104`、`Graphite e3ab0ecfd`、`benchmarks 35d755060`
> 审查类型：GitHub 冻结源码及测试断言直接阅读 + 历史 R2/N1 运行证据和方法审查交叉核对；**本次未取得本地 ignored m5out 原始数据，未运行 simulator，未获得原论文全文的直接可读 PDF**（IEEE PDF 在线访问受限）。原论文具体章节/算法内容基于仓库已有审查，全文精细核对须由可读取本地 PDF 的 Claude Code 完成。
> **明确目标**：复现论文 HetSub *核心方法和关键数据路径*，而非原平台、性能、面积或功耗数字。

## 1. 结论先行（findings first）

**本次未确认新增 P0 或足以撤销已有限定批准的 P1。既有 `CONDITIONAL APPROVE / FREEZE` 维持。** 这不是形式化全正确证明：源码体现了独立 L/M 路由与链路、真实宽度/流控、动态选择、PG、静态 shortcut 与有界 relay，以及 Algorithm 1/2；历史 22-case 有限包验收和正式 v2 应用数据支持固定平台内的机制正确性，但原始运行日志在 GitHub 之外、此轮没有独立执行。

**下一个最有科研价值的动作不是增加实验，而是消除论文语义与源码之间尚存的有限疑问**，重点是原文的“global reconfigurability”是否指运行中重配置。若论文实际只要求运行前针对场景重新计算/下发 frozen shortcut，现有实现足够；若明确要求运行时替换连接，则当前源码只有构造期下发，应根据论文确定是否属于未实现的关键机制，**不得在未证明其必要性前开发新框架**。

### 发现及优先级

| 编号 | 优先级 | 直接证据与影响 | 裁决 |
|---|---|---|---|
| HS-CR-01 | **P1-QUESTION（待论文原文裁决，不是已确认缺陷）** | `gem5/configs/ruby/HetSub.py:73-113` 在 `configure_shortcuts` 启动时读取 frozen JSON；`GarnetNetwork.cc:260-310` 在 `initHetShortcuts` 构造绑定；已读源码中未发现运行期替换路径/资源映射入口。论文摘要提到 global reconfigurability，但具体时序要求未在此轮直接从全文证实。 | **首先核对论文 III-C/Algorithm 2 的重构触发、下发与生效时点**。若只需场景间重新配置，关闭；若严格需要同次运行在线重配置，标记范围及机制缺口，提交用户裁决，不得擅自实现。 |
| HS-CR-02 | P2（表达不精确） | `GarnetNetwork.cc:326-342` **static 首先返回 L=0**，然后才检查 ordered vnet→M=1；`HetSubPolicy.hh:98-103` ordered 分支只作用于其动态选择对象。此前方法表中的“ordered vnet 固定 M/XY”仅对 dual 成立。 | 论文文字分别声明 dual ordered→M、static ordered→冻结 L 路径且 VC/顺序约束仍须满足；不作为新开发任务。 |
| HS-CR-03 | P2（表达不精确） | `GarnetNetwork.cc:333-340` 当选网请求抵达且与上次抽样间隔达到 128 cycles 才采样拥塞；未见独立按 128 周期触发的监测事件。 | 用“请求触发的间隔不少于 128-cycle 更新”代替严格周期独立采样。若论文要求持续实时监测，先论证方法必要性和可见影响，再决定是否升级缺陷。 |
| HS-CR-04 | P2（已披露的建模边界） | `NetworkLink.cc:176-187` 和 `GarnetNetwork.cc:287-310` 以单条 composite proxy 代理冻结 M 物理段并累积各段 activity；延迟为 `segments.size()` 或 abstract=1，**不进行逐物理段独立弹性缓冲/RTL 时序仿真**。 | 保持保守近似/时序边界，不能声称与原论文逻辑 hop、工艺时序和芯片面积完全等价；不要求重构 circuit switching。 |
| HS-CR-05 | P2（证据可获取性） | `docs/COMPARISON_10C_RESULTS.md`、`.ai/reports/REPORT.md` 和 `validate_network.py` 有测试结果与可执行断言，但正式 `m5out` 被 gitignore；本次 GitHub 阅读不能独立打开原始 `stats.txt` 和 verify 凭据。 | 标注“source/test assertion checked”与“historical run reported”区别；Claude Code 有本地只读访问时优先核对**已有**目标文件，不为证明记录存在而重跑。 |
| HS-CR-06 | P2（已知名词边界） | `tools/hetsub/audit_comparison.py:89-91` 对所有非 `het_relay_links` 默认标为 physical；冻结链路命名适用，但未来新增类别将被静默纳入。 | 冻结配置维持，不引入新统计框架；仅在实际新增 channel 类时复审 fail-closed 分类。 |

**硬失败条件**：如实证存在错 NI/vnet、flit 或有效字节不守恒、重复投递、合法有限包无法排空、非单调 shortcut、物理资源双重占用、relay 无界或无 VC 背压、活跃 M VC 进入睡眠、已验证源码与二进制身份不匹配，则升级 P0/P1，并暂停原批准的受影响范围。**负性能收益、并不符合 SNN 的流量局部性、面积或 J/W 未校准，不是代码缺陷。**

## 2. 论文机制—实现路径—完成度逐项核查

本表源代码位置均相对于 `gem5` 子仓固定 gitlink；`tools/hetsub/` 等属于父仓。证据 A=本次直接读取源码、B=本次直接读取现有验证断言、R=报告记载的历史运行（本次不独立重跑），C=论文/平台语义须保留差异。

| 机制 | 实际源码/调用路径证据 | 状态 | 最小验收和边界 |
|---|---|---|---|
| 独立 L/M 子网 | `HetSub.py:29-69` 配置 M 原网并创建 L 的 64 Router、Hilbert 正反向 126 内链路；`GarnetNetwork.cc:56-85,221-257` 累加 128 Router 并接通独立 L/M NI。 | **完成（A/B/R）** | `validate_network.py:157-173` 校验 128 subrouters、宽度和存储；`independence` 案例区分并行与彼此阻塞。128 是逻辑 Router 对象数，非原文物理面积等价。 |
| Hilbert L 路由（1 VC） | `HetSubPolicy.hh:12-53` 几何/rank/next/单调谓词；`Router.cc:1321-1344` L 使用 next 或合法 shortcut；`HetSub.py:46-67` L `vcs_per_vnet=1`。 | **完成（A/B/R）** | `test_policy.cc:8-37` 对全部 64×64 源目的遍历检查终止和单调；不是对任意拓扑的证明。 |
| XY M 路由（2 VC） | `Router.cc:1337-1344` 对 M X→Y 路由；`HetSub.py:33-45` M `vcs_per_vnet=2`。 | **完成（A/B/R）** | `check_dependencies.py:32-37,49-103` 检查已配置 64×64 的通道依赖无环；不等于 Ruby 协议无死锁证明。 |
| 真实 16/8/7 B 序列化 | `NetworkInterface.cc:280-297,301-340` 按消息字节和对应 subnet width 逐 VC 构造 flit；`NetworkLink.cc:128-165` 真实占用链路传输；`HetSubPolicy.hh:55-69` 合法字节计算。 | **完成（A/B/R），位宽是固定平台比例适配** | `test_policy.cc:38-45` 检查各宽度的有效字节守恒；`validate_network.py:86-95,155-156` 反算对应 flit 数；128/56 不是原论文原始参数。 |
| NI 单次注入与选择反馈 | `NetworkInterface.cc:301-344,496-521` 使用 `hetChoose` 只选一个子网，统一出口发射机会、成功后 `hetCommit`；`GarnetNetwork.cc:326-353` 分流并采用 per-vnet transit 峰值压力；`HetSubPolicy.hh:73-111` 75/50 滞回、quarter accumulator。 | **机制完成、反馈定义部分等价（A/B/R/C）** | `test_policy.cc:47-65` 检查预览/提交及阈值；`policy_load` 断言双网实传；local=Hilbert distance≤2，反馈不是原文全端口总缓冲压力，采样按需触发。 |
| ordered vnet 顺序保护 | `GarnetNetwork.cc:330-342` dual ordered 直接选 M；`NetworkInterface.cc:315-325` ordered 使用单 VC；`Router.cc:1053-1071` ordered 限制为首 VC。 | **双网完成；static 规则另列（A/C）** | 静态模式强制 L，不应写 ordered 永远固定 M；本仓证据支持静态单一路径但不证明全部 Ruby 协议层排序性质。 |
| M 动态 PG 与 WU | `Router.cc:2391-2463` 统计 sleep/active/waking、资源空闲检查、50 idle、6 waking、10 WU；`vc_arbitrate:1007-1052` 受 `hetPowerReady()` 限制。 | **机制完成（A/B/R/C）** | `pg_mesh` 已报告 `212 wakeups / 1272 waking`、成本守恒；无统一工艺功耗/RTL 时序，不得报实际净节能。 |
| frozen static bypass 物理资源占用 | `HetSub.py:73-113` 校验、冻结输入/输出/物理边；`GarnetNetwork.cc:260-310` 从已有 M segment 构造复合旁路并独占资源；`NetworkLink.cc:176-187` 拒绝重复保留。 | **启动时可配置、运行中固定（A/B/R/C）** | `static7/static8/static_two/static_level2/reject_conflict/reject_nonadjacent` 验证实际 segment activity、拒绝冲突与背压；不等价于可随时在线重配置。 |
| 有界 relay，真实跨宽转换 | `HetSubRelay.hh` 4 个输入 flit 槽、每 vnet 一 frame 和 1 shared staging；`HetSubRelay.cc:33-74,77-142` request/grant/release、有效字节连续消费、downstream backpressure、完成后释放。 | **完成（A/B/R）** | `validate_network.py:96-150` 验证分段两侧字节/flit/frames 与高水位及真实 stall；无整包无限缓存。 |
| Algorithm 1 单调限制 | `HetSubPolicy.hh:48-53` 允许 `c<e≤d` 或 `d≤e<c`；`Router.cc:1332-1336` 真实 getRoute 选捷径。 | **完成（A/B/R）** | `test_policy.cc:30-36` 对全部 64³ 关系覆盖；已配置旁路单调且不可越目的。 |
| Algorithm 2 Hilbert 分层选边 | `tools/hetsub/insert_shortcuts.py:13-111`：8×8/4×4 层、跳过最小2×2、候选 flow_bytes 阈值、limit 与 port/edge 冲突；`test_insertion.py:1-60`。 | **完成（A/B/R）；确定性 tie/limit 是实现选择** | `static_level2` fixture 唯一 level-2 选择及独立定向有限包真实 relay activity；正式应用只选 level-1 不影响 level-2 已实现结论。 |
| 端到端正确交付与排空 | `NetworkInterface.cc:604-627` 对每 VC 目的、vnet、flit id、width、有效字节逐帧校验；`validate_network.py:14-83,145-173` 收发 packets/bytes/flits、inflight 与显式 `het_busy_resources=0`。 | **固定有限包场景通过（A/B/R）；应用未排空（事实边界）** | 22-case 报告 PASS；应用退出尚有 8–47 inflight，服务延迟只包含退出前已完成消息。 |
| 全球重配置时机与论文细节 | 源码直接可见加载只发生在 `HetSub.py.configure_shortcuts` 与 `GarnetNetwork::initHetShortcuts`。 | **运行前配置完成；原文是否要求运行中重配待核对（A/C）** | 优先阅读原论文相关章节并作范围裁决；无证据时不得称完整在线重配。 |

## 3. 正确性与科学有效性边界

1. **可支持的主张**：固定 gem5-gpu / flexible Garnet 平台上的 HetSub 核心机制移植；有限包环境的已测试正确交付、真实背压与排空；正式 10-cluster v2 应用下的客观负结果。
2. **不能支持的主张**：原 SNN/Noxim 平台及性能比例复现；外部 NI 线宽、存储、mux/crossbar、寄存器与布局的完整面积等价；J/W 或节能百分比；所有合法 Ruby 协议组合的形式化无死锁；跨三仓只有路由函数不同的因果试验。
3. **正式结果不变**：`formal_10c_v2_20261015`；backprop/kmeans 的 dual/static 相对 HetSub off/XY 更慢（`docs/COMPARISON_10C_RESULTS.md`）；R2 已正确将 flit 活动、PG sleep、几何距离、relay bytes 描述为机制一致的解释，非独立因果分解。
4. **证据区别**：源代码、测试器断言直接检查 ≠ 已重跑成功；报告中的 `22/22`、build VERIFIED、`audit ok:true` 为此前执行者的本地运行结论，本次 GitHub 不可读取全部原始产物。
5. **差异不自动转为工程任务**：本次可确认的 ordered/static 和按请求采样属于 P2 文字精确性；仅“运行中全局重配”是否必要尚属 P1-QUESTION。严禁为证明严谨而添加与研究目标无关的注册系统、层层哈希或工作负载矩阵。

## 4. 下一阶段唯一建议：GOAL-HS-R3（论文原文语义裁决与只读主张复核）

**范围：先审查后停机；不是授权新算法、运行时重配置或新实验。** 已关闭的 N1/R2 不重新打开；R3 只服务论文方法忠实度的最后一道条件判断。

| 阶段 | 优先级 | 具体执行 | 产物 | PASS / FAIL / STOP |
|---|---|---|---|---|
| R3-0 身份门 | P0 | `git status`、`git rev-parse HEAD`、五 gitlink、`AGENTS.md`；比对原先冻结指纹；读取本地原论文 PDF（不能访问则标 UNVERIFIED）。 | snapshot 与可访问证据清单 | 代码 SHA/论文版本有据；无证据不假装读过。 |
| R3-1 论文机制对照 | P0 | 逐段核对 III-A/III-B/III-C、Algorithm 1/2、长链路插入与全局重配“触发→配置→生效”语义；标注原文页/图/公式，映射实际函数。 | paper-to-code 的争议项判定 | 不能仅用此前 REVIEW 推定“原文要求”；每项有来源与具体实现。 |
| R3-2 定向静态审计 | P0 | 只读追踪 `choose→commit→flitisize→grant→route→link→relay→delivery`，另查 PG 以及 frozen segment 独占；针对 HS-CR-01/02/03 写最短代码反例或排除说明。 | findings-first 的 P0/P1/P2 清单、路径行号、可达条件 | 若无新**已确认** P0/P1，明确 **STOP/FREEZE**；不把 P2 文本差异升级为代码缺陷。 |
| R3-3 最小已有证据复核 | P1（条件执行） | 优先只读既有 `static_level2`、`policy_load`、`pg_mesh`、`formal_10c_v2` 的 config/stats/验证输出；可选择对原始目录运行现成纯检查器。默认不启动模拟器。 | 证据对照表和可重放验证命令 | 当前证据可支持的主张全部对应源码和验证器；数据不可得写 UNVERIFIED，而非新实验填空。 |
| R3-4 最终收口 | P0 | 更新一个 Markdown 审查件：完成/部分/缺失、must-fix/可披露、必要的目标与测试、范围外结论；提交并核对远端。 | 单一新 `docs/` 报告及提交链接 | 若无 P0/P1，**不创建新的开发 Goal**，只留论文写作待办；如有 P0/P1，先交用户审批最小修复合同。 |

**唯一允许的有条件新开发**：R3-1/2 发现原文明确要求的关键机制未接入真实数据路径，且有具体可定位的路径级证据或构造性反例。届时先输出 `NEED FIX`、原因、最多一个定向反例与候选最小修改文件，不直接改源码；获用户授权后方进入新实现任务。

## 5. 最小测试与验收合同（只在需要时适用）

| 层级 | 现有入口/最小实例 | 必需判定 |
|---|---|---|
| 单元 | `tools/hetsub/test_policy.cc`、`test_insertion.py` | 4096 对 Hilbert 路径终止；全部 shortcut 单调谓词；7/8/16 有效字节守恒；Algorithm 2 层级、唯一性、冲突、限额符合。仅检查现有结果；不默认重跑。 |
| 集成 | `run_network_checks.sh` 里的 `policy_load`、`pg_mesh`、`static7`、`static_level2` 及一个拒绝配置 | L/M 双网实际活动；PG 唤醒/周期守恒；relay 有界/背压恢复；static M 不写普通 router buffer；level-2 物理 segment 真正承载。 |
| 端到端 | **已报告完成的** 22-case fixed-packet suite | 正确目的/vnet、消息字节及 flit 守恒、`het_busy_resources=0`、非错误退出；不以应用退出替代排空。 |
| 应用 | 已冻结 `formal_10c_v2_20261015` 两应用 × 已运行配置 | 同源二进制/输入/seed、实际节点映射、CPU 数值参考检查；记录退出时 inflight，不强求应用排空。 |

**执行门**：文档/审查无需 simulator；若未来**获批且修改了子仓源代码**，必须调用官方 Docker clean builder，重建相应目标、获取 source/binary provenance 并在每次运行前 `verify_gem5_build.sh verify`；依影响面做上述**最小相关**用例，绝不为得到正收益重开 16 应用全矩阵。不增加结果/脚本/图片的哈希链，也不添加全新测试框架。

## 6. 可复制的 Claude Code Goal

```text
GOAL-HS-R3 — HetSub 论文方法复现的源码级反证审查与最终研究裁决（先审查、后停机）

你是资深 NoC/体系结构研究人员兼严谨的 C++/Python/gem5 Code Reviewer。研究仓库：/home/siat/gem5-gpu-hetsub，父仓分支 synthetic-traffic-three-patterns；以实际 git HEAD 为准。阅读 AGENTS.md、.ai/tasks/TASK.md、.ai/reviews/REVIEW.md，以及 docs/HETSUB_DEEP_SOURCE_REVIEW_AND_CLAUDE_GOAL_20261016.md。不要照搬已有 APPROVE，优先寻找可定位的反例，也不要为证明工作量而制造新问题。

核心目标仅是忠实复现论文 HetSub 的算法、架构及关键数据路径，不是重现原论文平台、数据集、性能数字、完整面积或功耗。先直接读取本地原论文 PDF；核查 III-A/B/C、Algorithm 1/2、静态 long-range link、global reconfigurability 的具体时序语义；若 PDF 不可读，诚实标 UNVERIFIED，严禁编造页码、公式或原文主张。

冻结代码审查：HetSub.py / HetSubPolicy.hh / HetSubRelay.* / GarnetNetwork.cc / Router.cc / NetworkInterface.cc / NetworkLink.cc，以及父仓 insert_shortcuts.py、test_policy.cc、test_insertion.py、validate_network.py、check_dependencies.py、audit_comparison.py。对每项机制标注原文要求、函数/行号、入口/调用链、已实现/部分/缺失、实际数据路径证据和历史运行证据等级。特别独立核对：
① global reconfiguration 是否要求单次运行内动态切换；当前 JSON 仅构造期加载是否足够；
② dual ordered vnet 固定 M，但 static mode 强制 L，不能写成全模式 M；
③ 128-cycle 拥塞更新实际是否为有选网请求才触发、与论文定义是否等价；
④ VC request/grant/release、FIFO 高水位、单 flit per physical link per cycle、composite shortcut 资源独占与延迟模型；
⑤ 目的/vnet/flit/字节守恒、源选网提交、PG 睡眠及唤醒期间是否存在违反关键不变量的可达行为；
⑥ Algorithm 2 各层中心/阈值/冲突及 level-2 真实命中；
⑦ frozen v2 负结果的结论边界、活动量非能量、应用退出并非排空和三仓非单变量对照。

优先只读审查现有文件与现有结果；不修改核心源代码，不执行任何 gem5 模拟，不重跑 22-case 或 16 应用，不调整参数求性能，不新建框架/哈希系统。若发现疑点，区分 CONFIRMED P0/P1、P1-QUESTION（缺论文语义证据）、P2 表达差异和范围外。每个 P0/P1 必须提供准确文件行号、错误路径、最小构造性反例及可判定的修复验收条件；仅日志/历史 REVIEW 说已完成不算直接证据。没有新 P0/P1 时明确 STOP，不另开机制实施 Goal。

最终在 docs/ 下输出一份 Markdown：审查快照与 SHA、findings-first、论文机制→源码→真实路径→证据矩阵、正确性和适用边界、科研价值最高的唯一下一步、必要时的单元/集成/端到端最小测试及 PASS/FAIL/UNVERIFIED 门槛。若全机制无新阻断问题，下一阶段仅为论文方法章节证据整理；如果确定关键缺口，只提出最小修复合同等待用户批准，严禁自动开发。

修改范围仅允许本次审查 Markdown 与必要的执行记录；不动任何子仓核心源码/构建凭据/正式数据。完成后根据 AGENTS.md 检查五个 gitlink、提交并 push 到 GitHub，核对父仓远端 HEAD，输出审查文档链接、结论及未执行项目。禁止虚报独立运行结果。
```

## 7. 本轮审查停机标准

1. 有源代码层面支持的实现清单及有限证据边界；未直接打开的原始日志与论文 PDF 单列 UNVERIFIED。
2. 不出现“原文性能复现、真正 J/W、严格面积等价、任意负载无死锁、应用全网排空”的越界主张。
3. 不要求任何新仿真；若没有可定位新 P0/P1，保持 `CONDITIONAL APPROVE / FREEZE`，停止新增 Goal。
4. 若论文证明“运行时全球重配置”是必需核心机制，先提出范围裁决，**不在此次审查中自动解冻算法**。
5. 不编辑已有 N1/R2 封口历史；新文档独立保存、推送并核对 gitlink，不打乱成果谱系。
