# GOAL-HS-R4（C）：主张—证据索引（最小可追溯）

日期：2026-10-16。每条科研主张追溯至论文锚点、源码锚点与现有证据位置，并标注证据类型。不上传大型 `m5out`，不新增哈希系统。

## 1. 主张索引

| # | 主张 | 论文锚点 | 源码锚点 | 证据位置 | 证据类型 | 状态 |
|---|---|---|---|---|---|---|
| 1 | 128 独立 Router（64 L/M 对）与独立物理通道 | III-A | `GarnetNetwork.cc:221-257`（223 强制 64 对） | p8 21 项检查；`validate_network.py` independence（10,557/2,559/10,990） | 源码 + 历史运行 | 已实现 |
| 2 | L=Hilbert 序、M=XY 路由 | III-A | `HetSubPolicy.hh:42`；`Router.cc:1336/1338` | p8；本次复跑 PASS | 源码 + 历史运行 | 已实现 |
| 3 | 真实宽窄 flit 与连续字节流序列化 | III-B | `HetSubPolicy.hh:55/62`；`NetworkInterface.cc:279-298/300-346`；`NetworkLink.cc:151-152` | 有限包字节/flit 守恒（按实际字节断言）；应用实际链路活动 | 源码 + 历史运行 | 已实现 |
| 4 | 拥塞驱动动态选择与滞回（75%/50%） | III-A | `HetSubPolicy.hh:77-84/87-96/98-103/105-109`；`NetworkInterface.cc:315`；`GarnetNetwork.cc:326-343`（128-cycle 门 334） | p4/p6 实际分流；policy_load PASS | 源码 + 历史运行 | 已实现（平台适配）；与原文全局拥塞定义等价：未验证 |
| 5 | 反馈范围为每 vnet 最忙 transit 端口（已披露差异） | III-A（所有端口总占用） | `Router.cc:2375-2389`（2379 注释）、`2353-2372` | 注释与调用链 | 源码直接证明 | P2 已披露，非阻塞 |
| 6 | PG 三态、6-cycle WU、10-cycle 转换 | IV-A（p. 3139） | `Router.cc:2438-2464/2424-2435/2403-2421/2392-2401` | pg_mesh 状态分解（725,371/212/1,272=64×12000）；正式批次 M sleep 99.93%/99.89% | 源码 + 历史运行 | 已实现（周期记账代理）；净能量未验证 |
| 7 | 静态 long-link / crossbar bypass / 有界 relay / 背压 | III-B（p. 3136）、V（p. 3143） | `GarnetNetwork.cc:260-311`（308-309）；`NetworkLink.cc:179-184`；`HetSubRelay.cc:10-12/73/105-135/141`；`HetSub.py:77-78` | static_level2（1,176 beats/202 stalls/19 deferrals）、static8（372/6/0）、排空断言 | 源码 + 历史运行 | 已实现（保守近似，未工艺校准） |
| 8 | Algorithm 1 单调 shortcut 限制 | p. 3136–3137 | `HetSubPolicy.hh:48-52`；`Router.cc:1334` | 定向用例与通道依赖检查 | 源码 + 历史运行 | 已实现 |
| 9 | Algorithm 2 Hilbert 分层插入（threshold 128 B、limit 4、排除相邻、无 2×2 层） | p. 3138 | `insert_shortcuts.py:13-27/29-48/85-107`；`HetSub.py:88-104` | `test_insertion.py` 5 项（本次复跑 OK）；冻结配置 4 条 level-1（27→36、35→28、36→27、28→35）；定向运行实际承载 | 源码 + 历史运行 | 已实现；每节点 ≤2 上限：未实现（冲突按 (tile,端口/方向) 与有向边去重，`insert_shortcuts.py:73-82`、`HetSub.py:92-103`） |
| 10 | 守恒、顺序、端到端交付与排空边界 | — | `NetworkInterface.cc:54-119/263-269/272-276/411-425/423-464`；`HetSubRelay.cc:56-67` | 16 案例正常退出 + CPU 数值参考；Network_test 显式排空；`check_dependencies.py` 4096/130/129 acyclic | 源码 + 历史运行 | 已实现；应用边界不声称全网排空（8–47 在途） |

## 2. 可复现数值（本次重算，全部与记录核对）

定义与分母（与 R2-4 一致，除 F-R4-01/02 注记）：

- 输入：`m5out/comparison_10c/formal_10c_v2_20261015/hetsub_pilot/{app}/profile.csv`（299/355 流，1,004,752 / 1,072,856 字节）。
- `d_XY = |x_s−x_d| + |y_s−y_d|`（row-major tile）；`d_H = |rank(s)−rank(d)|`，rank 为 `HetSubPolicy.hh::Geometry` Hilbert rank（与 `insert_shortcuts.py hilbert_order()` 经 `test_insertion.py` 确认一致）。
- 字节加权均值 `D̄ = Σ bytes·d / Σ bytes`；未加权对 64×63 有序对（不含自对）。

| 量 | backprop | kmeans | 与记录核对 |
|---|---:|---:|---|
| 加权 XY / Hilbert | 5.8588 / 26.1440 | 5.8741 / 26.5222 | 与 R2 记录（5.86/26.14、5.87/26.52）一致 |
| 未加权（64×63）XY / Hilbert | 5.3333 / 21.6667 | 5.3333 / 21.6667 | R2 记录 5.25/21.33 对应含自对的 4096 分母（F-R4-02） |
| ≤2 字节占比（含同 tile） | 5.5082% | 5.4196% | RESOURCE_AUDIT 5.6787%/5.2734% 精确复现于 p6 pilot（307/323 流）（F-R4-01） |
| eligible-region flow fraction | 24.8563%（249,744/1,004,752） | 24.6639%（264,608/1,072,856） | 与 R2 记录一致 |
| relay 转换字节 ÷2 / 同运行注入字节 | 38.24%（384,216/1,004,808） | 38.89%（417,256/1,072,784） | 与 R2-2(4)/R2-4 一致；上界代理，非严格命中率 |

## 3. 证据位置与可复核命令（只读，不触发重跑）

| 证据 | 位置 |
|---|---|
| 正式结果表 | `docs/COMPARISON_10C_RESULTS.md` |
| 平台/映射审计 | `m5out/comparison_10c/formal_10c_v2_20261015/audit_backprop.json`、`audit_kmeans.json`（`ok:true`） |
| 物理/虚拟活动重分析（N1-1） | `…/reanalysis_wire_classification_backprop.json`、`…_kmeans.json` |
| 资源与 PG 口径 | `.ai/reports/RESOURCE_AUDIT.md` |
| 执行历史与构建凭据 | `.ai/reports/REPORT.md` |
| 插入算法测试与冻结配置 | `tools/hetsub/test_insertion.py`、`…/fixtures/`、`m5out/comparison_10c/formal_10c_v2_20261015/configs/{backprop,kmeans}.json` |
| 定向 level-2 运行 | `m5out/hetsub_network/20261015T152707Z/static_level2` |
| p6 pilot profile（F-R4-01 对照） | `m5out/hetsub_apps/p6_dual8_pilot/backprop/profile.csv`、`p6_kmeans_pilot/kmeans/profile.csv` |

```bash
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_Network_test
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_VI_hammer_GPU
cd tools/hetsub && PYTHONDONTWRITEBYTECODE=1 python3 test_insertion.py
```

本次执行门禁复核（2026-10-16）：两个 verify 门禁均 BUILD-PROVENANCE VERIFIED（source `a5470ae3…`，binary `1bef3876…`/`9f5ed9cb…`）；`test_insertion.py` 5 项 OK；`check_dependencies.py` 4096/130/129 acyclic；`validate_network.py` 七 case PASS。

## 4. 状态

无新增已确认关键缺陷；F-R4-01/F-R4-02 为文档精度 P2，不改变任何定性结论；GPU 16/10 口径仍待用户确认。裁定：**R4-DOC CLOSED / CORE FREEZE RETAINED**。
