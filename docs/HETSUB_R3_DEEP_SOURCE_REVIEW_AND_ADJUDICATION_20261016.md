# GOAL-HS-R3：核心方法复现的源码深审与最终科学裁定

日期：2026-10-16。本文件是 GOAL-HS-R3 交付物：只读审查，不修改任何源码，不运行新的 gem5 仿真，不重跑 22-case 网络套件或 16 个应用案例；仅对既有测试做只读复核（见第 7 节）。本审查不继承 `docs/HETSUB_DEEP_SOURCE_REVIEW_AND_CLAUDE_GOAL_20261016.md` 的 PASS 结论，全部主张从论文原文、源码实际数据路径与既有运行结果重新建立。

修订记录：依据独立终审（父仓 `866c19c6`，R3-DOC-01/R3-DOC-02）修正第 2 节观察 1 的冲突粒度措辞与第 7 节示例命令路径；裁定结论（STOP/FREEZE、三问 P2）与全部证据不变。

## 1 冻结版本与证据来源

- 审查起点：父仓 HEAD `2ee61cb6`，工作区干净。五个 gitlink：Graphite `e3ab0ecf`、benchmarks `35d75506`、gem5 `a90c04ca`、gem5-gpu `e53ac264`、gpgpu-sim `17f16f10`。
- 论文原文（独立读取，非转述既有文档）：Y. Li et al., "HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems," IEEE TVLSI 33(11) 3131–3144, 2025, DOI 10.1109/TVLSI.2025.3597406。14 页，`pdftotext -layout` 全文提取后逐节读取（III-A、III-B、III-C、Algorithm 1、Algorithm 2、静态 long-range link、全局可配置性、IV-A、V 讨论）。下文页码均出自该提取文本。
- 源码（逐行读取实际数据路径）：`HetSubPolicy.hh`、`HetSubRelay.hh/cc`、`GarnetNetwork.cc`、`NetworkLink.cc`、`Router.cc`（HetSub 路由/拥塞/PG 段）、`NetworkInterface.cc`（HetSub 段）、`configs/ruby/HetSub.py`。
- 既有运行结果（未重跑）：正式批次 `m5out/comparison_10c/formal_10c_v2_20261015/`（两个 audit `ok:true`）；定向网络套件 `m5out/hetsub_network/20261015T152707Z/`（22 case，含 `config.ini`/`stats.txt`/日志）；冻结插入配置 `tools/hetsub/configs/` 与 fixtures。
- 既有测试入口（只读复核）：`test_insertion.py`、`validate_network.py`、`check_dependencies.py`、`test_policy.cc`（静态断言集，未在本轮重新编译，作为既有证据引用）。

## 2 发现优先（重新裁定，不继承原评级）

原审查文档的 HS-CR-01…HS-CR-06 逐条独立重裁。本轮没有新的 P0/P1。

| 编号 | 原评级 | 重裁 | 依据（论文页码 + 代码行） |
|---|---|---|---|
| HS-CR-01 冻结 JSON 仅初始化加载，无运行时替换路径 | P1-QUESTION | **P2（非必须修复）** | 论文 p. 3143（Section V）明确："This process is currently static: once a low traffic scenario is manually identified, the long-range links are established via global configuration of the crossbars, and the subnetwork selection policy is disabled. In future work, we plan to enable long-range links dynamically based on network traffic." 论文演示的设计即静态；动态插入是论文明确列出的 future work。p. 3136（III-B-1）"global configuration information is preloaded into the router in the form of special packets" 描述的是论文硬件的配置下发形式；仿真中以构造期绑定（`HetSub.py:79-113`、`GarnetNetwork.cc:260-311`）实现同一静态语义，属平台适配。对论文已演示方法而言不构成方法缺陷。 |
| HS-CR-02 静态模式先返回 L、有序 vnet 固定 M | P2 | **P2（确认）** | `GarnetNetwork.cc:330`（static→L，与论文静态场景"选择策略被禁用、全部注入常开双子网"一致，p. 3136）；`HetSubPolicy.hh:100` 与 `GarnetNetwork.cc:331`（ordered→M）。论文 III-A（p. 3134-3135）的严格优先级是"L 优先、M 接近拥塞才激活"，且论文未讨论跨子网顺序。Ruby 要求每 vnet 按序交付：若有序 vnet 流量在 dual 模式下跨 L/M 分流，同源同目的消息可能乱序；固定单一子网是平台必要条件。选择 M 而非 L 偏离原文优先级方向，但不破坏正确性，且 `test_policy.cc` 与 `validate_network.py`（policy case）覆盖该路径。 |
| HS-CR-03 拥塞反馈仅在选择请求且 128-cycle 间隔到达时更新 | P2 | **P2（确认）** | 论文 p. 3135（III-A-2）定义拥塞为"router 全部端口总 buffer 占用超过阈值、低于另一阈值才复位、状态保持一段时间"，未定义采样周期。实现：滞回 75%/50%（`HetSubPolicy.hh:77-84`）与双向比例（`sample` 87-96）忠实于"阈值置位/复位、状态保持、两子网联合影响比例"；事件驱动采样不违反论文（论文无采样周期）。两处已披露近似：测量范围为每 vnet 最忙 transit 端口（`Router.cc:2375-2389`）而非全部端口总量；128-cycle 门（`GarnetNetwork.cc:334`）限定状态陈旧度。低负载下状态可能滞后，但滞回语义保持。 |
| HS-CR-04 冻结 M 段的复合代理（bypass 段记账） | P2 | **P2（确认）** | `NetworkLink.cc:176-188`（段独占 `m_bypass_reserved`、宽度一致、3–4 段）与 `GarnetNetwork.cc:288-295`。构造期独占资源、无事后修正；线长/pipeline 未做工艺校准，属已披露保守近似。 |
| HS-CR-05 m5out 被 gitignore | P2 | **P2（确认）** | 证据打包以 docs + 既有目录为准（R2-4），不新增哈希系统，符合 CLAUDE.md。 |
| HS-CR-06 `audit_comparison.py:89-91` 默认物理分类 | P2 | **P2（确认）** | `link_class()` 将 `het_relay_links` 归为 virtual_relay_access、其余为 physical；分类口径在 N1-1 重分析 JSON 中分列，不影响主张。 |

本轮新增观察（均为 P2，非缺陷）：

1. **long-link 冲突粒度与原文口径不同（不是每节点上限）**。论文 p. 3138（Fig. 10 语境）允许每节点最多 2 输入与 2 输出 long-link。实现按 (tile, 端口/方向) 与有向物理边建冲突集（`insert_shortcuts.py:76-82`、`HetSub.py:92-103`）：同一 tile 的本地接入位（-1/L）或同一方向端口不能承载两条同向 shortcut，物理中间段不可共享；同一 tile 可在不冲突的其他端口参与其他 shortcut——实现不限制每节点总数，故不能表述为"每节点上限 1"。冻结配置（4 条 level-1 shortcut）在两种口径下均合法。
2. **拥塞信号范围与论文定义不同**（见 HS-CR-03）：论文为"全部端口总占用"，实现为"每 vnet 最忙 transit 端口"（`Router.cc:2377-2379` 注释已声明理由：输出缓冲 Garnet 中空闲本地端口不能稀释 transit 拥塞）。已披露。
3. **PG 能量为周期记账代理**（`Router.cc:2392-2401`、`2451` `+= 10`），无工艺系数，不输出 J/W——与 R2 边界一致，论文 IV-A（p. 3139）的 6-cycle WU 与 10-cycle break-even 按参数记账。

**没有新的已确认 P0/P1。** 守恒、独占、顺序、死锁与排空均无可达反例（第 3、5 节）。

## 3 论文机制—源码—实际数据路径—测试证据矩阵

| # | 机制（论文页码） | 源码（实际数据路径） | 实际数据路径证据 | 状态 |
|---|---|---|---|---|
| 1 | 独立常开 L 与 PG M 双子网（III-A, p. 3134-3135；L 每 router 2 端口、M 4 端口，2:1） | `HetSub.py:51-69`（64 L router、126 line edge、72×2 NI 通道）；`GarnetNetwork.cc:221-257`（128 router 对象、line edge 邻接校验） | `validate_network.py` independence case：10,557 tile-cycle 并行、L 在 M 唤醒期间推进 2,559、M 在 L 满期间推进 1,0990；64 对独立 L/M | 已实现（128/64 为 2 GHz/700 MHz 平台等比缩放，非原文 64/32 位宽） |
| 2 | L 的 Hilbert 路由与 M 的 XY DOR（III-A, p. 3134-3135；DOR 无死锁） | `HetSubPolicy.hh:19-47`（order/rank/next 单调）；`Router.cc:1323-1344`（L：shortcut→Hilbert next；M：XY） | `test_policy.cc`：4096 条 L 路由逐跳距离严格递减、hops==distance；22-case 套件全通过 | 已实现 |
| 3 | 真实宽窄 flit 与序列化/反序列化（III-B-2, p. 3136-3137；64→32 转换、round-robin、credit buffer、PG 信号选择 relay MUX） | `HetSubPolicy.hh:55-68`（flitCount/validBytes）；`HetSubRelay.cc:10-12`（16↔8/7 守卫）、`76-143`（逐字节转换、round-robin turn）；`NetworkInterface.cc:280-298`（`setHetFormat`）；`NetworkLink.cc:151-152`（flit 宽度与物理通道不符即 fatal） | 有限包字节/flit 守恒（`validate_network.py` 全 case）；relay input=output bytes；`test_policy.cc` 宽度守恒（1..256 字节 × {7,8,16}） | 已实现（按单宽 flit 补齐被守卫禁止；2 GHz 时序未证明） |
| 4 | 拥塞驱动动态选择：阈值置位/复位滞回、状态保持、双向比例（III-A-2, p. 3135） | `HetSubPolicy.hh:77-84`（75% 进入/50% 退出、带内保持）、`87-96`（双向 quarters）、`98-103`（preview）、`105-109`（commit 累加器）；`GarnetNetwork.cc:333-342`（128-cycle 门 + 源 tile 两 router 采样） | `test_policy.cc` 滞回与比例断言；p4/p6 实际分流与压力检查；policy case PASS | 已实现（范围近似：每 vnet 最忙 transit 端口；事件驱动采样） |
| 5 | 有序 vnet 路径与顺序约束（论文未讨论跨子网顺序；Ruby 每 vnet 按序交付） | `HetSubPolicy.hh:100`、`GarnetNetwork.cc:331`（ordered→M）；`NetworkInterface.cc:316`（ordered 或 L 为单 VC） | `validate_network.py` 全 case 无 NI-WARN/回退；delivery 路径 `NetworkInterface.cc:423-464` | 已实现（平台必要；方向偏离原文优先级，P2） |
| 6 | PG 三态、6-cycle WU、10-cycle 转换代价（IV-A, p. 3139） | `Router.cc:2424-2435`（50-cycle 空闲→SLEEP）、`2438-2464`（SLEEP→WAKING +6、`+=10`、WAKING→ACTIVE）、`2392-2401`（状态周期分解） | pg_mesh case：sleep 725,371、wakeups 212、waking 1,272（=212×6）；正式批次恒等式 waking=wakeups×6、WU=wakeups×10 精确成立 | 已实现（无工艺系数，不输出 J/W） |
| 7 | 静态 long-link、crossbar bypass、物理段独占、时序（III-B, p. 3136-3137；p. 3143 静态演示） | `HetSub.py:86-113`（路径≤3、邻接、crossbar/本地端口/物理边冲突、按 (tile, 端口/方向) 的入/出冲突集）；`NetworkLink.cc:176-188`（段独占、宽度一致）；`GarnetNetwork.cc:260-311`（构造期绑定、relay 连接、`shareWith`） | static8/static_level2 case：物理段 beats（372/1,176）、blocked/downstream_stall 非零、排空；`check_dependencies.py`：4096 路径、130 资源、129 依赖、acyclic | 已实现（保守近似；线长/pipeline 未工艺校准） |
| 8 | 有界 relay、request/grant/release、背压（III-B-2, p. 3136-3137） | `HetSubRelay.cc:33-74`（每 vnet 一帧、4 入槽、1 staging、单 VC/协议类守卫）、`70-74`（credit 界）、`56-67`（release 前帧守恒 fatal_if）、`139-141`（blocked/downstream_stall 记账） | 全 static case：completed_frames、fifo_highwater、排空；backprop static8 relay 输入 768,432 B（384,216/侧）、81,366 帧 | 已实现 |
| 9 | Algorithm 1 单调 shortcut 限制（p. 3136-3137：仅当 shortcut 终点位于当前节点到最终目的地的路径上） | `HetSubPolicy.hh:48-52`（`shortcutAllowed`）；`Router.cc:1333-1335`（谓词门控出端口） | `test_policy.cc`：262,144 个 (current,end,dest) 三元组与"距离可加"等价断言 | 已实现 |
| 10 | Algorithm 2 Hilbert 分层插入（p. 3138：分层、排除相邻子块、流量阈值、严格层级优先、无最低 2×2、物理长度≤2 hop、crossbar≤5 无冲突路径、每节点≤2 入/出） | `tools/hetsub/insert_shortcuts.py`（候选、阈值 128 B、limit 4、相邻排除、最小 2×2、flow_bytes 区域聚合）；`test_insertion.py` 5 项（含 level-2 唯一选中）；冻结配置：4 条 level-1（27→36、35→28、36→27、28→35），全部 level-2 below_threshold/limit | `test_insertion.py` 5 项通过（本轮只读复核）；定向 level-2 运行实际承载（relay frames>0、beats>0、排空） | 已实现（冲突按 (tile, 端口/方向) 与有向物理边去重，见第 2 节观察 1） |
| 11 | 消息/字节/flit 守恒与端到端交付 | `validate_network.py`（injected==received==expected、bytes、flits、service+queue==completion）；`HetSubRelay.cc` 与 `NetworkLink.cc` 的 fatal_if 守卫 | 22-case 既有结果全 PASS（本轮抽读 independence/static_level2/policy/pg_mesh/static8/line/mesh8 复跑校验器，全部 PASS）；正式批次 audit `ok:true` | 已实现 |

## 4 完成度：已实现 / 部分 / 未实现 / 偏差

- **已实现（实际数据路径生效）**：矩阵第 1–11 行全部机制，含守卫与守恒。
- **部分（近似，已披露）**：拥塞信号范围（每 vnet 最忙 transit 端口 vs 论文全端口总量）；事件驱动采样 + 128-cycle 陈旧度门（论文无采样周期）；静态传播 segments-cycles 保守记账（未 RTL/布局校准）；PG 为周期记账代理（无工艺系数）。
- **未实现（论文明确为 future work，不视为缺陷）**：运行时动态 long-link 插入（p. 3143）。本实现按论文演示范围冻结。
- **偏差（方向性，P2）**：有序 vnet 固定 M（原文严格优先级会选 L）；long-link 冲突按 (tile, 端口/方向) 与有向物理边去重（原文为每节点 ≤2 入/出；实现不限制每节点总数，见第 2 节观察 1）；位宽 128/64（原文 64/32 的 2:1 比例在平台频率下等比缩放）。

## 5 三个研究问题的最终裁定

**Q1：论文的全局可配置性是否要求运行时改变连接结构？仅在初始化加载冻结 JSON 是否构成方法缺陷？**
不要求，不构成缺陷。论文 p. 3143（Section V）原文将演示过程明确限定为静态（"This process is currently static… In future work, we plan to enable long-range links dynamically"）；p. 3136 的 special-packet 预载是硬件下发形式，且同一节说明低流量场景下选择策略被全局配置屏蔽、全部包进入常开双子网——与 static 模式行为一致（`GarnetNetwork.cc:330`、`HetSub.py:77-78` 禁止 M 注入）。构造期绑定与运行时 special-packet 预载在静态配置下功能等价，属平台适配。**裁定：P2，非必须修复；HS-CR-01 从 P1-QUESTION 降为 P2。**

**Q2：动态模式有序 vnet 固定 M、静态模式强制 L，是否符合论文约束与实际协议顺序要求？**
符合实际协议顺序要求，方向上偏离原文优先级。论文 III-A 的严格优先级（L 优先、M 拥塞临近才激活）与单 VC dual-line 假设未处理跨子网乱序：dual 模式下同一有序 vnet 若跨 L/M 分流，同源同目的消息可能乱序，违反 Ruby 每 vnet 按序交付前提。`HetSubPolicy.hh:100`/`GarnetNetwork.cc:331` 将有序 vnet 钉在单一子网（M）消除该风险；静态模式强制 L 与论文静态演示一致。选择 M 而非 L 是任意但安全的实现选择。**裁定：P2，非必须修复；若未来要求与原文优先级逐字一致，唯一最小改动是 ordered 时选 L 并保证该 vnet 不跨子网分流——当前无此必要。**

**Q3：拥塞反馈仅在选择请求到达且 128-cycle 间隔满足时更新，是否足以支撑论文的动态拥塞控制？**
足以支撑论文定义。论文 p. 3135 只定义阈值置位、复位、状态保持与双向比例，未定义采样周期；事件驱动采样不违反论文。实现完整保留三个语义：滞回（75%/50%，`HetSubPolicy.hh:81-82`）、状态保持（带内不变 + quarters 记忆）、双向联合比例（`sample` 92-95）。两处近似已披露：范围（每 vnet 最忙 transit 端口，`Router.cc:2377-2389`）与 128-cycle 陈旧度门（`GarnetNetwork.cc:334`）。低负载下信号可能滞后于"全端口总量"定义，但这是测量口径差异，不是机制缺失。**裁定：P2，非必须修复。**

## 6 唯一最有科学价值的下一阶段目标

无必须修复缺陷（第 2 节无 P0/P1），维持 **CONDITIONAL APPROVE / FREEZE**。唯一目标：进入论文方法描述与比较写作——把第 3 节矩阵转为论文方法章节的"机制—实现—证据"叙述，并完成公平性边界核对（R2-3 清单逐条对照最终文稿）。步骤：

1. 以第 3 节矩阵为骨架撰写方法描述，每个"已实现"主张引用矩阵行号与既有测试，近似项保留标注。
2. 公平性边界核对：负载局部性前提、三仓基线差异、活动量代理口径、排空边界、128/56 限制、pilot/formal 分式不可互推、时序近似、无 J/W——逐条在最终文稿中显式出现。
3. 不新增实验、不调参、不重跑；若写作中发现与既有数据矛盾之处，回到第 8.3 节反例条件再评估。

## 7 最小测试与可判定验收门禁

只读门禁（本轮已执行，全部 PASS）：

```bash
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_Network_test
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_VI_hammer_GPU
# 以下均在仓库根目录执行（R3-DOC-02：原示例混用 cd tools/hetsub 与仓库根相对路径）
PYTHONDONTWRITEBYTECODE=1 python3 tools/hetsub/test_insertion.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/hetsub/check_dependencies.py \
  m5out/hetsub_network/20261015T152707Z/static_level2/config.ini
PYTHONDONTWRITEBYTECODE=1 python3 tools/hetsub/validate_network.py \
  m5out/hetsub_network/20261015T152707Z/<case> <case>   # independence, static_level2,
  # policy, pg_mesh, static8, line, mesh8 本轮抽读校验器复跑，全部 PASS
```

判定标准：构建凭据匹配（exit 42 即 FAIL）；5 项插入测试 OK；依赖图 acyclic 且 4096 路径；validate_network 无 panic/fatal/NI-WARN、injected==received==expected、字节/flit 守恒、排空恒等式成立。`test_policy.cc` 作为既有断言证据引用（本轮未重新编译；如需复跑须走构建门禁）。

## 8 最终决定

**STOP / FREEZE。** 本轮没有新的已确认 P0 或 P1：三个研究问题均裁定为 P2（非必须修复），HS-CR-01 由 P1-QUESTION 降为 P2，其余维持 P2；新增观察均为保守化或已披露近似。核心机制在论文演示范围内已实现且经实际数据路径验证；负结果保留且未被调参消除；冻结状态与重新打开条件（第 8.3 节机制反例或用户明确扩张研究范围）不变。成果可进入论文写作与方法比较阶段，边界以 R2-3 与本文件第 4 节为准。

审查者检查清单（沿用 R2-5，逐条确认）：每个"已实现"主张有实际数据路径证据；未引用原文 38%/58%/16% 作为本实现结果；未声称面积等价、实际功耗或 2 GHz 时序证明；排空与在途边界如实分列；负结果保留；v1 无效、v2 唯一正式；构建凭据与 verify 门禁可复核；冻结与重开条件一致。
