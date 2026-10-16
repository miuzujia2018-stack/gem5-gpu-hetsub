# GOAL-HS-R2：机制—证据—主张闭环、负结果解释与公平性披露

日期：2026-10-16。依据：`docs/HETSUB_COMPREHENSIVE_CODE_REVIEW_AND_NEXT_PLAN_20261016.md` 第 7 节 GOAL-HS-R2（R2-0…R2-5）。

本文件是 R2 交付物。R2 不修改任何源码、不重跑任何仿真；全部数值来自已冻结的 `formal_10c_v2_20261015` 数据、已提交的审查与资源审计，以及一次离线几何计算。修订记录：依据独立终审（父仓 `8cfa9e23`，R2-F01…R2-F05）修正 R2-2 因果措辞与 R2-2(4)/R2-3 统计分母、补充 R2-4 计算公式；实际结果数值全部保留，未改动源码或重跑实验。执行前门禁（第 8.1 节，只读）当日复核通过：

- `verify_gem5_build.sh verify`：`X86_Network_test` 与 `X86_VI_hammer_GPU` 均 BUILD-PROVENANCE VERIFIED（source `a5470ae3…`，binary `1bef3876…` / `9f5ed9cb…`）。
- `test_insertion.py`：5 项测试全部通过。

## R2-0 冻结与命名

正式批次：`m5out/comparison_10c/formal_10c_v2_20261015/`（两个 `audit_*.json` 均 `ok: true`）。v1 因 GPU L2 索引位错误（`start_index_bit=47`，应为 `ceil(log2(40))=6` → 实际 13）明确无效，不作为任何主张的证据。

构建凭据（官方干净构建，运行前 verify 门禁）：

| 仓库 | source SHA-256（前 8） | binary SHA-256（前 8） | 构建日志 |
|---|---|---|---|
| HetSub（本仓） | `a5470ae3` | `9f5ed9cb`（GPU）/ `1bef3876`（Network_test） | `docker_build_and_test_j64_20261015_203550.log` |
| gem5-gpu-tbp | `2d85cd7a` | `1fc9f7ca` | `docker_build_and_test_tbp_20261015_204344.log` |
| gem5-gpu-bak | `76ee344d` | `409517d9` | `docker_build_and_test_j64_20261015_193851.log` |

方法命名（论文与结果文档统一使用）：

| 名称 | 含义 |
|---|---|
| HetSub off/XY | 方法关闭，XY DOR 基线（回归分母，不代表 HetSub） |
| HetSub dual 128/64 | 独立双子网常开，L 128-bit / M 64-bit，拥塞驱动动态选择 |
| HetSub dual 128/56 | 同上，M 56-bit（内部链路等预算变体） |
| HetSub static 128/64、128/56 | 冻结静态 long-link/crossbar bypass + 有界 relay，关闭动态 M 唤醒 |
| TB-TBP | gem5-gpu-tbp 仓库方法 |
| bak XY / bak online | gem5-gpu-bak 基线与在线方法 |

冻结平台（三仓显式对齐）：16 TimingSimpleCPU、10 CudaCore（10 clusters × 1 core，SP units=2）、4 Directory、40 GPU L2、64 tile Mesh、72 外部端点、72 NI、10 协议 vnet；CPU/Ruby 2 GHz、GPU 700 MHz、cacheline 128 B、2 VC/vnet、buffer 深度 4、2 pipeline stages；最终 seed 0，Algorithm 2 pilot seed 17。方法参数（源码常量，已复核）：75% 占用进入 / 50% 退出滞回、128-cycle 采样、PG 空闲 50-cycle 阈值、6-cycle WU、10-cycle 转换等价、Algorithm 2 threshold 128 B、limit 4、排除相邻子块与最小 2×2。

冻结 Algorithm 2 配置（正式运行只读 JSON，不读测试未来消息）：两应用均选中 4 条 level-1 有向 shortcut（27→36、35→28、36→27、28→35）；全部 level-2 候选为 `below_threshold` 或 `limit`，无 level-2 进入正式配置。

冻结声明：flexible-pipeline 源码、HetSubRelay、`HetSub.py`、插入算法与上述批次数据自 2026-10-15/16 起冻结。仅当出现审查第 8.3 节的具体机制反例，或用户明确扩张研究范围时，才重新打开核心实现。

## R2-1 机制—证据—主张矩阵

| 机制 | 证据（位置） | 允许的主张 | 不允许的主张 |
|---|---|---|---|
| 独立常开双子网（L/M 独立 Router 实例与物理通道） | p8 21 项检查（同 tile 独立性、双向阻塞隔离）；128 router 对象与 638 登记链路审计 | 已实现并在实际数据路径生效 | 不声称与原文硬件同构 |
| 真实宽窄 flit 与连续字节流序列化（16↔8/16↔7） | 有限包字节/flit 守恒；应用实际链路活动；relay input=output bytes | 已实现 | 不按单宽 flit 补齐；不声称已证明 2 GHz 时序 |
| 拥塞驱动动态选择（75%/50% 滞回、128-cycle 采样） | 实际分流与压力检查（p4/p6）；反馈范围为每 vnet 最忙 transit 端口 | 已实现（平台适配） | 不声称与原文全局拥塞定义等价 |
| PG 三态、6-cycle WU、10-cycle 转换代价 | 状态周期分解恒等（active+sleep+waking=窗口）、waking=wakeups×6、WU=wakeups×10，非事后修正 | 已实现 | 无工艺系数，不输出 J/W 或节能百分比 |
| Algorithm 1 单调 shortcut 限制 | `shortcutAllowed` 谓词与定向用例、通道依赖检查 | 已实现 | — |
| 静态 long-link/crossbar bypass + 有界 relay | 构造期校验、独占资源、背压（blocked/downstream_stall 非零）、排空 | 已实现（保守近似） | pipeline/线长未做工艺校准 |
| Algorithm 2 Hilbert 分层插入 | `test_insertion.py` 5 项（含 level-2 唯一选中）、冻结配置、定向运行实际承载（relay frames>0、beats>0、排空） | 已实现 | 仅凭离线生成配置不构成实际承载证据 |
| 原论文性能/平台/工艺 | 无 | 无 | 不引用原文 38%/58%/16% 作为本实现结果 |

## R2-2 正式结果解释（机制一致的解释，2026-10-16 按独立终审修订）

当前 CPU/GPU 负载下 HetSub 服务时间与总时间均劣于 off/XY（backprop +4.80%…+6.46%，kmeans +12.68%…+17.13%）。以下为与已有数据一致的机制解释：各条只陈述与观测一致的方向，不为任何因素分配独立因果贡献，也不宣称任一因素已被严格识别为"主因"。

1. **路径长度不匹配（与趋势一致的机制假设）**。方法假设局部性流量（Hilbert 距离小）。离线用与 simulator 完全一致的 Hilbert 几何（`test_insertion.py` 已验证 `hilbert_order()` 与 `HetSubPolicy.hh::Geometry` 一致）对 pilot profile 计算**潜在几何 hop 距离**（定义见 R2-4；非实测路径）：未加权全对平均 XY 5.25 hop vs Hilbert 21.33 hop；按字节加权 backprop 5.86 vs 26.14、kmeans 5.87 vs 26.52。pilot 字节中 Hilbert 距离 ≤2 仅 5.68%（backprop）/ 5.27%（kmeans）——流量以 global 为主。dual 动态选择与 static bypass 都会改变实际采用路径，且正式 seed 与 pilot 不同，故该几何距离是解释性能趋势的有力机制假设，不是实测主因。
2. **链路活动量增长主要来自跳数/路径活动，而非注入端序列化**。backprop link flits 从 off 的 914,547 升至 dual8 的 3,259,418（3.564×），wire bytes 14.63→51.98 MB（3.553×）；两者都是各链路的传输累积、包含跳数。两倍数几乎相同，平均每个登记 link flit 的字节数为 16.00 B（off）vs 15.95 B（dual8）：dual 模式常开的 L 子网仍为 16 B flit，与 off/XY 同宽，且 M 子网绝大部分时间在休眠。因此现有数据更支持跳数/长路径活动主导增长，不能把这部分链路跳数开销称为序列化开销。窄通道确有实际 flit 转换成本，其证据限于同模式窄通道变体自身的计数：backprop dual7 flits 3,264,608 > dual8 3,259,418、static7 2,743,037 > static8 2,576,850（kmeans 同向）。服务延迟 34.65→116.21 cycles（backprop dual8）。
3. **M 子网使用稀少；PG 净能量效应未知**。M 子网在 dual 模式下 99.93%（backprop dual8）/ 99.89%（kmeans dual8）的 router-cycles 处于 sleep；实际服务仅 126,679 / 99,654 个 M active router-cycles。唤醒 1,403/1,260 次、转换代价 14,030/12,600 WU 是真实记账（恒等式 waking=wakeups×6、WU=wakeups×10 精确成立），但恒等式只证明状态机与成本记账正确。高 sleep 比例证明 M 在本负载下低活跃、独立 M 网络对当前时延贡献有限；它同时意味着存在潜在漏电节省窗口。PG 净收益或前提是否满足须有功耗模型及对照才可判断，本文件不作"PG 不适用"或节能价值判断。与原文局部性假设的不匹配单独归因于 (1) 的 pilot ≤2 字节比例。
4. **shortcut 占比：两个不同定义的分式，分别命名、不可互推**。
   - `pilot eligible-region flow fraction` = 24.86%（backprop）/ 24.66%（kmeans）：pilot profile 中流经 4 条选中 shortcut 端点象限区域之间（27↔36、28↔35 对应的 4×4 区域对）的字节占比（249,744/1,004,752、264,608/1,072,856），刻画配置生成时的候选区域流量份额。
   - `formal relay-converted bytes / formal injected bytes` = 38.24%（384,216/1,004,808，backprop static8）/ 38.89%（417,256/1,072,784，kmeans static8）：正式运行 relay 输入接入侧转换字节（含控制帧与允许的 transit 转换）除以**同一 static8 运行**的注入字节；是 bypass 份额的上界代理，不是严格的"选中源目的消息字节命中率"。
   两式不是同一集合，24.9%→38.2% 不构成同定义命中率变化，也不能据此推断 seed 的因果效应。静态模式仍有大部分字节走 L 的 Hilbert 长路径，无法抵消 (1) 的长路径。
5. **128/56 仅在 static 模式更慢，不可泛化到整个变体**。static7 在两个负载下均明显慢于 static8（backprop 1,632,467,000 vs 1,617,896,000 ticks；kmeans 764,156,500 vs 750,754,500），伴随更多 flit（backprop 2,743,037 vs 2,576,850）与更多 relay 阻塞（blocked 154,687 vs 14,232 cycles），与更窄通道及阻塞开销一致，但并非隔离因果实验。dual7 相对 dual8 基本持平且符号混合：backprop dual7 总时间少 36,000 ticks（1,607,098,500 vs 1,607,134,500）、服务 116.03 vs 116.21 cycles；kmeans dual7 略高（735,359,000 vs 735,163,000 ticks）。

结论边界：该负结果描述"方法在当前平台/负载下的迁移行为"，是机制一致的解释而非因果分解；不能外推到原文 SNN 平台；它不否定机制正确性（21+1 项检查、守恒、排空均通过）。

## R2-3 公平性披露（threats to validity）

- **负载局部性不满足方法前提**：当前应用以 global 字节为主（≤2 距离约 5.3–5.7%），方法为其设计场景（SNN 局部流量）未被覆盖。这是负载选择的结果，不是调参失败。
- **三仓代码基线除路由外不逐行相同**：平台审计只证明冻结项目相同（16/10/4/40/64/72、频率、输入、seed），TBP/bak 绝对值含其自身实现差异。
- **活动量是代理**：wire MB = flits × 通道宽度，不是能量；无工艺校准，不输出 J/W/百分比。
- **应用未排空**：退出时 8–47 个在途消息；延迟人口为退出前已接收消息，不声称全网排空；有限包 Network_test 的显式排空不能替代应用边界。
- **128/56 仅内部链路等预算**：外部 NI 线路安装位宽 3456/3312 vs 2304 bytes，存储与 mux/crossbar 无完整面积等价。
- **pilot 与正式运行 seed 不同**（17 vs 0）：配置由 pilot 冻结生成，正式流量分布与 pilot 有差异。pilot 24.86%/24.66%（eligible-region flow fraction，离线区域聚合）与正式 38.24%/38.89%（relay 转换字节/同运行注入字节）定义不同、不可直接同比，已按 R2-2(4) 分别命名分列，不作同定义命中率解读。
- **时序近似**：静态传播按 segments-cycles 保守记账，未做 RTL/布局校准；6-cycle WU 与 10-cycle break-even 按原文 IV-A 参数记账。
- **审查状态**：`acceptance_status: provisional`——最终 Code Review 由用户执行，本闭环未经跨模型独立评审。

## R2-4 证据打包（最小可追溯）

全部证据已在仓库或既有目录中，不上传大型 `m5out`，不新增哈希系统：

| 证据 | 位置 |
|---|---|
| 正式结果表 | `docs/COMPARISON_10C_RESULTS.md` |
| 平台/映射审计 | `m5out/comparison_10c/formal_10c_v2_20261015/audit_backprop.json`、`audit_kmeans.json`（`ok:true`） |
| 物理/虚拟活动重分析（N1-1） | `…/reanalysis_wire_classification_backprop.json`、`…_kmeans.json` |
| 资源与 PG 口径 | `.ai/reports/RESOURCE_AUDIT.md` |
| 执行历史与构建凭据 | `.ai/reports/REPORT.md` |
| 插入算法测试与冻结配置 | `tools/hetsub/test_insertion.py`、`…/fixtures/`、`…/configs/` |
| 定向 level-2 运行 | `m5out/hetsub_network/20261015T152707Z/static_level2` |

可复核命令（只读，不触发重跑）：

```bash
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_Network_test
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_VI_hammer_GPU
cd tools/hetsub && PYTHONDONTWRITEBYTECODE=1 python3 test_insertion.py
```

R2-2 的离线几何距离为一次性分析（工具 `hilbert_order()` 与 simulator `Geometry` 经 `test_insertion.py` 确认一致），结果已写入本文件，不保留脚本、不新增工具或哈希系统。可复核定义：

- 输入 profile：`m5out/comparison_10c/formal_10c_v2_20261015/hetsub_pilot/{app}/profile.csv`（列 `src_tile,dst_tile,bytes`；总计 1,004,752 / 1,072,856 字节）。
- XY 距离：`d_XY(s,d) = |x_s−x_d| + |y_s−y_d|`（row-major tile，8×8）。
- Hilbert 距离：`d_H(s,d) = |rank(s) − rank(d)|`，`rank` 为 `HetSubPolicy.hh::Geometry` 的 Hilbert rank。
- 字节加权均值：`D̄ = Σ_{s,d} bytes(s,d)·d(s,d) / Σ_{s,d} bytes(s,d)`；未加权值对全部 64×63 有序对以每对权重 1 计算。此为潜在几何 hop 距离，非实测路径。
- R2-2(4) 正式分式：分子 = `Σ het_relays[0-7].input_bytes ÷ 2`（每接入侧 4 个 relay；backprop 768,432、kmeans 834,512），分母 = **同一 static8 运行** audit JSON 的 `metrics.bytes_injected`（1,004,808 / 1,072,784）。
- R2-2(4) pilot 分式：分子 = profile 中 src/dst 落入选中 shortcut 端点 4×4 象限区域对（27↔36、28↔35）的字节和（249,744 / 264,608），分母 = profile 总字节。

## R2-5 最终审查者检查清单

审查者应确认本文件与结果文档：

1. 每个"已实现"主张都有实际数据路径证据（非标签或事后统计），近似项（静态传播、拥塞反馈范围）已标注。
2. 未引用原文性能数值（38%/58%/16%）作为本实现结果。
3. 未声称完整面积等价、实际功耗（J/W）或 2 GHz 时序证明。
4. 应用排空与退出在途边界如实分列；延迟人口定义明确。
5. 负结果保留且未被调参消除；pilot/正式 seed 差异已披露。
6. v1 无效、v2 为唯一正式批次；构建凭据与 verify 门禁可复核。
7. 冻结状态与重新打开条件（第 8.3 节反例或用户明确扩张）一致。
