# GOAL-HS-R4（A）：论文方法描述与逐项机制映射

日期：2026-10-16。依据：Y. Li et al., "HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems," IEEE TVLSI 33(11) 3131–3144, 2025, DOI 10.1109/TVLSI.2025.3597406；R3 已冻结的核心实现（本仓 `8f478cda` 起冻结，构建凭据 source `a5470ae3`）。

本文件为只读复核交付物：不修改源码、不重跑仿真。每项主张标注证据类型：**源码直接证明** / **历史运行证据** / **推断** / **未验证**。引用原文时只使用已核实引文与页码，不转述无法核实的原文主张。

## 0. 前置上报（已解决）与执行依据

R4 目标文件 `docs/GOAL_HS_R4_METHOD_EVIDENCE_FAIRNESS_READONLY_20261016.md` 在本地执行开始时不存在（工作区、`.ai/` 与全部 git 提交含 `--all --diff-filter=A` 均无），按 CLAUDE.md 升级规则上报。随后经 `git fetch` 确认该文件存在于远端分支，为提交 `60df5cb6`（docs(R4): add independent read-only HetSub method and fairness review goal），其父为 R3 封口 HEAD `a2459724`。本地经非破坏性 rebase 纳入该提交后，本次执行以该冻结目标文件为准（A/B/C 三节交付、R2-3 十项公平性清单、最小充分只读门禁）。

R4-0 基线门禁（本次核对）：五个 gitlink 与目标文件所列冻结 SHA 完全一致（gem5 `a90c04ca`、Graphite `e3ab0ecf`、benchmarks `35d75506`、gem5-gpu `e53ac264`、gpgpu-sim `17f16f10`）；flexible-pipeline 与 `tools/hetsub` 的最后源码提交为 `50b52f0a`（N1），早于 R3 封口，无 R3 后核心代码修改；`.ai/reviews/REVIEW.md` 最新结论仍为 R3 `APPROVE（研究范围限定）/ STOP / FREEZE`。

引文对账：目标文件引用 `insert_shortcuts.py:67-82`（冲突集）与 `18-109`（候选+插入），对应实际文件的 `73-82` 与 `29-48`/`85-107`；语义一致，仅行号区间表述差异，不构成缺陷。

## 1. 论文方法描述（已核实引文）

| 节 | 已核实内容 | 关键引文/要点 |
|---|---|---|
| III-A | 异构双子网：常开宽 Line 子网（16-byte flit）与可休眠窄 Mesh 子网（8 或 7 bytes，`options.hetsub_mesh_bytes`）；Line 走 Hilbert 序路由，Mesh 走 XY | 拥塞定义为**所有端口 buffer 总占用**；置位/复位阈值；状态保持一段时间；双向分流比例；**原文未定义采样周期** |
| III-B | 真实宽窄 flit 与序列化/反序列化；低流量时选择策略被屏蔽，全部消息进入常开 dual-line | 长程链路以"special packets"形式预加载到路由器（p. 3136） |
| Algorithm 1 | 单调 shortcut 限制：仅当目的地位于当前→shortcut 端点→目的地的路径上才允许使用（p. 3136–3137） | — |
| Algorithm 2 | Hilbert 分层插入：排除相邻子块、流量阈值、严格层级优先、无 2×2 层、≤2 hop、crossbar ≤5、每节点 ≤2 入向与 ≤2 出向长程链路（p. 3138）。输入仅 HSC 阶数与流量阈值，**无全局 limit** | 实现另有全局 `--limit=4` 预算（F1，见 A-6） |
| IV-A | PG 三态（active/sleep/waking），WU 6 cycles，转换代价 10 cycles（p. 3139） | — |
| V | 长程链路过程"currently static"，动态化列为 future work（p. 3143） | 本实现的 static 模式与原文一致；动态选择属于 III-B 的 III-A 拥塞机制，不属于长程链路动态化 |

## 2. 逐项机制映射（A-1 … A-7）

### A-1 独立 L/M 双子网与 Hilbert/XY 路由

- 论文依据：III-A（独立双子网；Line=Hilbert 序，Mesh=XY）。
- 实现：128 个独立 Router 实例（64 L + 64 M），`GarnetNetwork.cc:221-257`（`initHetLinks`，223 行强制 64 对）；L 子网路由经 `HetSubPolicy.hh:42`（`next`，沿 Hilbert rank 单调前进）与 `Router.cc:1336`；M 子网经 `getRouteXY`（`Router.cc:1338`）。
- 证据：历史运行（p8 21 项检查：同 tile 独立性、双向阻塞隔离；128 router 对象、638 登记链路）；本次 `validate_network.py` 复跑 PASS（independence 10,557 parallel / 2,559 / 10,990）。
- 类型：源码直接证明 + 历史运行证据。
- 边界：不声称与原文硬件同构。

### A-2 真实宽窄 flit 与连续字节流序列化

- 论文依据：III-B（16↔8/16↔7 真实转换；低流量全入 dual-line）。
- 实现：`HetSubPolicy.hh:55`（`flitCount = 1 + (bytes-1)/width`）、`:62`（`validBytes`）；`NetworkInterface.cc:279-298`（`fillHetBuffer` + `setHetFormat`）、`:300-346`（`flitisizeHetMessage`）；物理宽度守卫 `NetworkLink.cc:151-152`（flit 宽度必须等于物理通道宽度，否则 fatal）。
- 证据：有限包字节/flit 守恒（`validate_network.py` 按消息实际字节计算期望 flit 并断言相等，line/mesh8/mesh7 等 case PASS）；应用实际链路活动；relay input=output bytes。
- 类型：源码直接证明 + 历史运行证据。
- 边界：不声称已证明 2 GHz 时序。

### A-3 拥塞驱动动态选择、反馈与滞回

- 论文依据：III-A（所有端口 buffer 总占用、置位/复位阈值、状态保持、双向分流；无采样周期定义）。
- 实现：`HetSubPolicy.hh:71-109`——`updateSignal`（77-84：75% 进入 / 50% 退出滞回）、`sample`（87-96：双向 quarters）、`preview`（98-103）、`commit`（105-109）；调用链 `NetworkInterface.cc:315`（`hetChoose`）→ `GarnetNetwork.cc:326-343`（128-cycle 采样门 334、local ≤2、preview）→ `:346-353`（`hetCommit`）。
- 已披露适配差异（P2，非阻塞）：(a) 反馈范围为每 vnet 最忙 transit 端口（`Router.cc:2375-2389`，2379 行注释明示不掩盖满队列，资源核算仍用 `hetOccupancy` 2353-2372），与原文"所有端口总占用"口径不同；(b) 128-cycle 是实现选择的相邻采样最小间隔（请求触发；无请求时不更新），原文未定义采样周期，不宜解释为最多滞后 128 cycles 的状态陈旧度上限；(c) 低流量屏蔽路径存在（`hetChoose` static/force 分支），与 III-B 一致；(d) ordered vnet 钉在 M 单一路径（`HetSubPolicy.hh:98-103`、`GarnetNetwork.cc:330-331`）以保证 Ruby 协议顺序，原文优先选择 L，方向差异为已披露工程适配。
- 证据：实际分流与压力检查（p4/p6 历史运行）；本次 `validate_network.py` policy_load PASS（两 vnet 均有实际注入）。
- 类型：源码直接证明（机制与调用链）+ 历史运行证据（实际分流）；"与原文全局拥塞定义等价"为**未验证**，不允许主张。

### A-4 PG 状态转换与时序

- 论文依据：IV-A（三态、WU 6 cycles、转换代价 10 cycles，p. 3139）。
- 实现：`Router.cc:2438-2464`（`hetPowerReady`，仅 subnet 1：SLEEP→WAKING +6、`+= 10`、WAKING→ACTIVE）、`:2424-2435`（`hetIdleCheck`，idle ≥ 50 cycles）、`:2403-2421`（`hetResourcesIdle`）、`:2392-2401`（`hetAccountPower`）。恒等式（active+sleep+waking=窗口、waking=wakeups×6、WU=wakeups×10）为记账恒等，非事后修正。
- 证据：历史运行状态周期分解（pg_mesh：sleep 725,371、wakeups 212、waking 1,272 = 64×12000；本次复跑 PASS）；正式批次 M 子网 99.93%/99.89% router-cycles 处于 sleep。
- 类型：源码直接证明 + 历史运行证据。
- 边界：PG 为**周期记账代理**，无工艺系数，不输出 J/W 或节能百分比；净能量收益**未验证**，不允许主张。

### A-5 静态 long-link、物理 bypass、有界 relay 与背压

- 论文依据：III-B（special packets 预加载，p. 3136）、V（过程 currently static，p. 3143）。
- 实现：`GarnetNetwork.cc:260-311`（`initHetShortcuts`，`shareWith` 308-309 共享物理段）；`NetworkLink.cc:179-184`（segments 3–4、`m_bypass_reserved` 独占、宽度匹配）；`HetSubRelay.cc`（10-12 仅允许 16↔7/8；73 credit bound <4；105-135 round-robin；141 `blockedCycles`）。静态模式禁止 M 注入（`HetSub.py:77-78`）。
- 证据：构造期校验、独占资源、背压（static7/static_transpose/static_pilot case 要求 downstream_stall > 0、MUX deferrals > 0，本次复跑 static_level2：1,176 beats、202 stalls、19 deferrals；static8：372 beats、6 stalls）；排空（`het_busy_resources == 0`）。
- 类型：源码直接证明 + 历史运行证据。
- 边界：传播按 segments-cycles 保守记账，pipeline/线长未做工艺校准（已披露近似）。

### A-6 Algorithm 1 单调性与 Algorithm 2 分层插入

- 论文依据：Algorithm 1（p. 3136–3137）、Algorithm 2（p. 3138）。
- 实现（Algorithm 1）：`HetSubPolicy.hh:48-52`（`shortcutAllowed`：`(c<e && e<=d) || (d<=e && e<c)`），调用点 `Router.cc:1334`。
- 实现（Algorithm 2）：`tools/hetsub/insert_shortcuts.py`——`hilbert_order()`（13-27，与 `HetSubPolicy.hh::Geometry` 同一算法，`test_insertion.py` 断言一致）、`candidates()`（29-48：level 1 = 4×4 区域中心、level 2 = 2×2 子块、排除相邻 `abs(i-j)<=1`、无最低 2×2 层）、`insert()`（85-107：threshold 128 B、limit 4、冲突集）；运行侧校验 `HetSub.py:88-104`（≤3 节点、相邻性、冲突集）。
- 已披露差异（P2，非阻塞）：冲突粒度为按 (tile, 端口/方向) 与有向物理边去重（`insert_shortcuts.py:73-82`、`HetSub.py:92-103`），**不是**原文的每节点 ≤2 入/出上限；实现不限制每节点总数。同一 tile 作为起点/终点时，本地接入位（`-1`/`L`）冲突仍限制相应角色（R3-DOC-01），与端口/方向冲突集不矛盾。另有结构性约束：`Router.hh:682-683` 每路由器只保存一个 shortcut 目的与出向端口，即每源路由器至多一个出向 shortcut；不能声称覆盖论文允许的全部链路组合。
- **F1（主张范围条件，P1 级完整复现主张）**：原文 Algorithm 2 无全局 limit；实现的全局 `--limit=4`（`insert_shortcuts.py:95-96`、`run_comparison_campaign.sh:31`）确实改变选择结果。本次在内存复用两个现有 pilot profile（阈值与冲突规则不变）：limit=4 → 每应用 4 条 level-1（即冻结配置）；limit=100 → 4 + 9 条 level-2 = 13；冻结 CSV 的 11 条 `limit` 条目中 9 条解除预算后可选、2 条（`10→17`、`17→9`）转为冲突。现有 static 结果须命名为"最多 4 条有向 shortcut 的 Algorithm 2 预算变体"；定向 level-2 运行只证明代码支持该层，不证明正式配置执行了所有符合条件的层级插入。保留现有配置与负结果即可，不要求新增实验。
- 证据：`test_insertion.py` 5 项测试（本次复跑全部 OK，含 level-2 唯一选中）；冻结配置（两应用各 4 条 level-1：27→36、35→28、36→27、28→35；全部 level-2 候选 below_threshold/limit）；定向运行实际承载（relay frames>0、beats>0、排空）。
- 类型：源码直接证明 + 历史运行证据。仅凭离线生成配置不构成实际承载证据（已分列）。

### A-7 Ruby 协议顺序、守恒与端到端交付

- 实现：`NetworkInterface.cc`（per-subnet in/out links 与 src queues 54-119；`hetIndex` 263-269；`isBufferNotFull` bound 2 272-276；round-robin MUX 411-425；delivery 423-464）；`HetSubRelay.cc` frame 守恒 fatal_if（56-67）。
- 证据：16 个正式应用案例正常退出并通过独立 CPU 数值参考；有限包 Network_test 显式排空与守恒（本次复跑 7 case PASS）；`check_dependencies.py` 4096 paths / 130 resources / 129 dependencies / acyclic。
- 类型：历史运行证据（应用边界）+ 源码直接证明（守恒断言）。
- 边界：退出时 8–47 个在途消息；延迟人口为退出前已接收消息；不声称应用全网排空。

## 3. 不允许的主张（与 R2/R3 一致）

不引用原文 38%/58%/16% 作为本实现结果；不声称完整面积等价、实际功耗（J/W）或 2 GHz 时序证明；不声称拥塞反馈与原文全局定义等价；不声称每节点 ≤2 长程链路上限已实现；不把静态传播 segments-cycles 当作 RTL/布局校准结果；不把现有 static 结果称为未截断 Algorithm 2 的完整复现（须按"最多 4 条有向 shortcut 的 Algorithm 2 预算变体"命名，F1）。

交叉引用：用户 20261017 独立审查 `docs/HETSUB_READONLY_REVIEW_20261017.md`（提交 `515fd49c`）——F1（Algorithm 2 全局预算，本次已独立复算确认）、F2（拥塞口径与 128-cycle 最小间隔）、F3（资源/时序/统计人口边界）、F4（GPU 16/10 陈旧文字已解决）。本文件上述条目与该审查一致。
