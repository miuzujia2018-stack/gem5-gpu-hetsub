# GOAL-HS-R2：机制—证据—主张闭环、负结果解释与公平性披露

日期：2026-10-16。依据：`docs/HETSUB_COMPREHENSIVE_CODE_REVIEW_AND_NEXT_PLAN_20261016.md` 第 7 节 GOAL-HS-R2（R2-0…R2-5）。

本文件是 R2 交付物。R2 不修改任何源码、不重跑任何仿真；全部数值来自已冻结的 `formal_10c_v2_20261015` 数据、已提交的审查与资源审计，以及一次离线几何计算。执行前门禁（第 8.1 节，只读）当日复核通过：

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

## R2-2 正式结果解释（负收益的因果链）

当前 CPU/GPU 负载下 HetSub 服务时间与总时间均劣于 off/XY（backprop +4.80%…+6.46%，kmeans +12.68%…+17.13%）。解释如下，全部来自已有数据与离线计算：

1. **路径长度不匹配（主因）**。方法假设局部性流量（Hilbert 距离小）。离线用与 simulator 完全一致的 Hilbert 几何（`test_insertion.py` 已验证 `hilbert_order()` 与 `HetSubPolicy.hh::Geometry` 一致）对 pilot profile 计算：未加权全对平均 XY 5.25 hop vs Hilbert 21.33 hop；按字节加权 backprop 5.86 vs 26.14、kmeans 5.87 vs 26.52。pilot 字节中 Hilbert 距离 ≤2 仅 5.68%（backprop）/ 5.27%（kmeans）——流量以 global 为主，L 子网为少数局部字节付出 4–5 倍 hop 数。
2. **序列化代价**。16-byte 消息在 8/7-byte 通道上按连续字节流拆 flit：link flits 从 off 的 914,547（backprop）升至 dual8 的 3,259,418（3.56×），wire bytes 14.63→51.98 MB。服务延迟 34.65→116.21 cycles（backprop）。
3. **PG 前提不成立**。M 子网在 dual 模式下 99.93%（backprop dual8）/ 99.89%（kmeans dual8）的 router-cycles 处于 sleep；实际服务仅 126,679 / 99,654 个 M active router-cycles。唤醒 1,403/1,260 次、转换代价 14,030/12,600 WU 是真实记账，但相对极小的 active 时间，PG 的"局部流量+间歇"前提在当前负载下不成立。
4. **shortcut 命中率低**。pilot 字节中仅 24.86%（backprop）/ 24.66%（kmeans）落在 4 条选中流上；正式运行 relay 每接入侧实际转换 384,216 / 417,256 bytes（含控制帧），即约 38% 字节走 bypass，其余仍走 L 的 Hilbert 长路径。静态模式因此无法抵消 (1) 的长路径。
5. **128/56 变体更差**是上述机制的直接推论：更窄通道 → 更多 flit（backprop dual7 flits 3,264,608、static7 2,743,037）与更多 relay 阻塞（static7 blocked 154,687 vs static8 14,232 cycles）。

结论边界：该负结果描述"方法在当前平台/负载下的迁移行为"，不能外推到原文 SNN 平台；它不否定机制正确性（21+1 项检查、守恒、排空均通过）。

## R2-3 公平性披露（threats to validity）

- **负载局部性不满足方法前提**：当前应用以 global 字节为主（≤2 距离约 5.3–5.7%），方法为其设计场景（SNN 局部流量）未被覆盖。这是负载选择的结果，不是调参失败。
- **三仓代码基线除路由外不逐行相同**：平台审计只证明冻结项目相同（16/10/4/40/64/72、频率、输入、seed），TBP/bak 绝对值含其自身实现差异。
- **活动量是代理**：wire MB = flits × 通道宽度，不是能量；无工艺校准，不输出 J/W/百分比。
- **应用未排空**：退出时 8–47 个在途消息；延迟人口为退出前已接收消息，不声称全网排空；有限包 Network_test 的显式排空不能替代应用边界。
- **128/56 仅内部链路等预算**：外部 NI 线路安装位宽 3456/3312 vs 2304 bytes，存储与 mux/crossbar 无完整面积等价。
- **pilot 与正式运行 seed 不同**（17 vs 0）：配置由 pilot 冻结生成，正式流量分布与 pilot 有差异（如 shortcut 命中字节 24.9% pilot vs 38.2% 正式），已如实分列。
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

R2-2 的离线路径长度计算为一次性分析（工具 `hilbert_order()` 与 simulator `Geometry` 经测试确认一致），结果已写入本文件，不保留脚本。

## R2-5 最终审查者检查清单

审查者应确认本文件与结果文档：

1. 每个"已实现"主张都有实际数据路径证据（非标签或事后统计），近似项（静态传播、拥塞反馈范围）已标注。
2. 未引用原文性能数值（38%/58%/16%）作为本实现结果。
3. 未声称完整面积等价、实际功耗（J/W）或 2 GHz 时序证明。
4. 应用排空与退出在途边界如实分列；延迟人口定义明确。
5. 负结果保留且未被调参消除；pilot/正式 seed 差异已披露。
6. v1 无效、v2 为唯一正式批次；构建凭据与 verify 门禁可复核。
7. 冻结状态与重新打开条件（第 8.3 节反例或用户明确扩张）一致。
