# 统一 10-cluster 三仓比较结果

## 结论范围

本结果评估 HetSub 核心方法迁移到当前 gem5-gpu 平台后的行为，不复现原论文的 SNN 平台、数据集、RTL/工艺流程或性能收益。正式批次为 `m5out/comparison_10c/formal_10c_v2_20261015/`；两个 `audit_*.json` 均为 `ok: true`。此前 v1 审计发现 HetSub/TBP 的 GPU L2 索引位计算错误，导致 `start_index_bit=47`；修正为 `ceil(log2(40))=6` 后实际索引位为 13，v1 不作为正式结果。

三仓实际配置均为 16 TimingSimpleCPU、10 CudaCore、4 Directory、40 GPU L2、64 router、72 外部端点；CPU/Ruby 2 GHz、GPU 700 MHz、cacheline 128 B、2 VC/vnet、buffer 深度 4、2 pipeline stages。GPGPU-Sim 为 10 clusters × 1 core，SP units=2。三仓使用同一应用二进制、输入和最终 seed 0；HetSub Algorithm 2 只读取 seed 17 pilot。

## 正式结果

`Δtime` 相对同仓 HetSub-off/XY。吞吐是退出前已交付原始消息数除以 Ruby 周期。活动量按 config.ini 链路 section 命名区分物理与虚拟：`ext_links`、`int_links`、`het_line_links` 为物理链路，`het_relay_links` 为虚拟 relay 接入通道。`wire MB` 仅计物理链路活动，`virtual relay MB` 单列虚拟接入通道活动；两者之和为登记通道活动。Jain 仅根据物理链路计算；不同结构的物理登记链路数不同，因此它只描述各方法自身负载分布。活动量是 flit 数乘实际通道宽度的活动代理，不是能量。

本表物理/虚拟分列是对 `formal_10c_v2_20261015` 已有数据的重分析（GOAL-HS-N1 N1-1），未重跑仿真；重分析输出为 `m5out/comparison_10c/formal_10c_v2_20261015/reanalysis_wire_classification_backprop.json` 与 `…_kmeans.json`。仅静态模式的 `het_relay_links` 非零，因此只有静态行的 Jain 相对旧口径（全部登记链路）变化。

### backprop

| 方法 | sim ticks | Δtime | service cycles | completion cycles | msg/Ruby cycle | physical link Jain | wire MB (physical) | virtual relay MB | exit inflight |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| HetSub off/XY | 1,533,477,000 | 0.00% | 34.65 | 81.07 | 0.035371 | 0.1694 | 14.63 | 0.00 | 20 |
| HetSub dual 128/64 | 1,607,134,500 | +4.80% | 116.21 | 218.12 | 0.033743 | 0.1455 | 51.98 | 0.00 | 31 |
| HetSub dual 128/56 | 1,607,098,500 | +4.80% | 116.03 | 217.30 | 0.033743 | 0.1459 | 52.00 | 0.00 | 32 |
| HetSub static-4 128/64 | 1,617,896,000 | +5.51% | 155.11 | 300.95 | 0.033526 | 0.1413 | 38.27 | 1.42 | 15 |
| HetSub static-4 128/56 | 1,632,467,000 | +6.46% | 171.80 | 337.12 | 0.033225 | 0.1439 | 39.24 | 1.42 | 21 |
| TB-TBP | 1,532,142,500 | -0.09% | 40.31 | 91.48 | 0.035403 | 0.2266 | 14.63 | 0.00 | 16 |
| bak XY | 1,575,458,500 | +2.74% | 82.41 | 197.31 | 0.034419 | 0.1673 | 14.63 | 0.00 | 43 |
| bak online | 1,575,578,000 | +2.75% | 82.64 | 187.85 | 0.034416 | 0.1712 | 15.23 | 0.00 | 47 |

### kmeans

| 方法 | sim ticks | Δtime | service cycles | completion cycles | msg/Ruby cycle | physical link Jain | wire MB (physical) | virtual relay MB | exit inflight |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| HetSub off/XY | 652,411,000 | 0.00% | 33.81 | 76.37 | 0.089244 | 0.1615 | 15.70 | 0.00 | 20 |
| HetSub dual 128/64 | 735,163,000 | +12.68% | 112.08 | 195.16 | 0.079165 | 0.1422 | 56.32 | 0.00 | 27 |
| HetSub dual 128/56 | 735,359,000 | +12.71% | 111.90 | 194.70 | 0.079144 | 0.1425 | 56.33 | 0.00 | 30 |
| HetSub static 128/64 | 750,754,500 | +15.07% | 148.87 | 258.28 | 0.077513 | 0.1373 | 41.37 | 1.54 | 32 |
| HetSub static 128/56 | 764,156,500 | +17.13% | 169.57 | 291.97 | 0.076161 | 0.1399 | 42.43 | 1.54 | 27 |
| TB-TBP | 655,967,000 | +0.55% | 42.07 | 99.13 | 0.088728 | 0.2125 | 15.70 | 0.00 | 8 |
| bak XY | 704,208,000 | +7.94% | 83.40 | 186.62 | 0.082650 | 0.1597 | 15.70 | 0.00 | 10 |
| bak online | 703,379,500 | +7.81% | 83.58 | 177.09 | 0.082750 | 0.1634 | 16.34 | 0.00 | 14 |

当前 CPU/GPU 工作负载下，HetSub 机制运行正确，但服务时间和总时间均劣于 HetSub-off/XY；128/56 static-4 模式的序列化代价最大。该负结果不影响机制验收，也不能外推到原论文 SNN 平台。TBP 和 bak 的绝对值还包含其仓库自身实现差异，平台审计只证明已冻结项目相同，不声称三个代码基线除路由外逐行相同。

**static-4 命名**：表中 static 条目为"最多 4 条有向 shortcut 的 Algorithm 2 预算变体"——全局 `--limit=4`（`insert_shortcuts.py:95-96`、`run_comparison_campaign.sh:31`）是实现预算，非论文 Algorithm 2 规格（p.3138 输入仅 HSC 阶数与流量阈值）；另有每源路由器至多一个出向 shortcut 的结构性约束（`Router.hh:682-683`）。这些结果不能代表未截断 Algorithm 2 的链路选择策略。

## HetSub 活动与 PG

- backprop dual 128/64：205,578,119 个 PG sleep router-cycles、1,403 次唤醒、14,030 WU；128/56 为 205,560,538、1,505、15,050 WU。
- kmeans dual 128/64：93,993,650 个 PG sleep router-cycles、1,260 次唤醒、12,600 WU；128/56 为 94,011,569、1,273、12,730 WU。
- static-4 模式关闭动态 M 路由器唤醒，仍通过真实 bypass segment 活动检查。Algorithm 2 的两个应用均从独立 pilot 选择 4 条有向 level-1 shortcut（全局 `--limit=4` 预算下的选择；离线解除预算、阈值与冲突规则不变时两应用均可选出 13 条 = 4 level-1 + 9 level-2），正式运行只读冻结 JSON。
- `wire MB`（仅物理链路）、`virtual relay MB`（虚拟接入通道）、PG 状态周期、唤醒次数和 WU 是可比较的活动/状态代理。没有工艺校准，因此不输出 J、W 或节能百分比。

## 正确性与排空边界

所有 16 个正式应用案例正常退出，backprop 与 kmeans 均通过独立 CPU 数值参考。退出时仍有 8–47 个在途原始消息；延迟人口只包含退出前已接收消息，因此不声称应用全网排空。最终有限包 Network_test 独立检查宽度转换、流控、消息/字节/flit 守恒和显式排空。

## 完成度

| 机制 | 状态 | 证据边界 |
|---|---|---|
| 独立常开 dual-line 与 PG Mesh | 已实现 | 独立 Router、物理通道、并发与阻塞隔离检查通过 |
| 16/8/7-byte flit 与连续序列化 | 已实现 | 有限包字节/flit守恒和应用实际链路活动 |
| 拥塞驱动动态选择 | 已实现（平台适配） | 实际分流和压力检查；反馈范围为每 vnet 最忙 transit 端口 |
| PG 三态、6-cycle 唤醒、10 WU | 已实现 | 状态周期、唤醒次数、转换代价均非事后修正 |
| Algorithm 1 单调限制 | 已实现 | 实际 shortcut 数据路径及通道依赖检查 |
| 静态 long-link/crossbar bypass | 已实现（保守近似） | 有界 relay、物理段容量与背压；传播 pipeline/线长未做工艺校准 |
| Algorithm 2 Hilbert 分层插入 | 已实现（预算变体 static-4） | 独立 pilot、阈值/冲突/路径约束、冻结配置；全局 `--limit=4` 为实现预算、非论文规格（F1），另有每源路由器至多一个出向 shortcut 的结构性约束（`Router.hh:682-683`）；不声称覆盖论文允许的全部链路组合 |
| 原论文性能、平台和工艺结果 | 未复现（范围外） | 不引用原文收益作为本实现结果 |

128/56 只使内部链路位宽预算与 128-bit Mesh 接近；外部 NI 线路、buffer、mux、控制和跨距布线没有完整面积等价证明。
