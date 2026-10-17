# HetSub flexible Garnet 源码与科研基准审查（2026-10-17）

审查基线：父仓 `badfbe00`，分支 `synthetic-traffic-three-patterns`；gem5 `a90c04ca8aad279876784601f9647c2e0195c763`。开始审查时父仓和 gem5 工作树干净。本轮直接读取论文、源码及本地既有产物，不继承历史 APPROVE 作为证据；不修改模拟器、配置、插入器，不运行新仿真或构建。

## 裁决

| 审查维度 | 裁决 | 准确含义 |
|---|---|---|
| 论文复现完整性 | **CONDITIONAL** | 核心机制均有实现；动态反馈、ordered 流量、旁路时序存在适配；正式 static 额外限制最多 4 条 shortcut，不能称未截断 Algorithm 2 的完整复现 |
| 算法与实现正确性 | **PASS（冻结配置与已验证范围）** | 未发现可确认的丢包、错误路由、无限 relay 缓冲或绕开实际数据路径的阻断缺陷；不等于任意 Ruby 协议/配置的形式化证明 |
| 性能基准资格 | **CONDITIONAL；限定命名后 PASS** | 可用于固定平台 HetSub 移植模型与 XY/TBP/bak 比较；static 须标明 4-link 上限、时序和资源差异。不能充当原论文未经约束的方法结果或纯路由单因素实验 |

建议冻结实现，使用已有 v2 数据进入正式比较与论文写作。唯一新增实质性发现是方法主张需要准确限定，不据此自动启动开发、重建或重跑。性能负收益不是复现失败。

## 关键发现（证据优先）

### F1：正式 Algorithm 2 被全局 4-link 预算截断，确实改变选择结果

**已证实；P1（完整复现/比较主张），不是数据路径正确性 P1。** 论文 p.3138 Algorithm 2 的输入为 HSC 阶数和流量阈值，循环各层并检查相邻子区、冲突、阈值；不存在全局 `limit=4` 条件。实现 [insert_shortcuts.py](../tools/hetsub/insert_shortcuts.py#L86) 第 95–96 行在达到上限时跳过候选，[run_comparison_campaign.sh](../tools/hetsub/run_comparison_campaign.sh#L31) 明确传入 `--threshold-bytes=128 --limit=4`。

本轮复用正式批次两个 pilot 的 `profile.csv`，仅在内存调用现有 `insert(profile,128,limit)`，不写配置、不仿真：

| pilot | limit=4 | limit=100（对本例不构成限制） | 原冻结 CSV 的 `limit` 条目 |
|---|---:|---:|---:|
| backprop | 4 条 level-1 | 4 条 level-1 + 9 条 level-2 | 11 |
| kmeans | 4 条 level-1 | 4 条 level-1 + 9 条 level-2 | 11 |

两应用额外可选端点相同：`9→17,18→9,17→10,21→14,14→21,49→42,42→49,53→46,46→53`，均通过**现有插入器**的端口/物理边冲突约束。11 个被预算拒绝候选中，解除预算后 9 个可选，不能把 11 个全部认作可并存链路。13 条也不代表已经完成其运行正确性或性能验证。

证据目录：`m5out/comparison_10c/formal_10c_v2_20261015/hetsub_pilot/{backprop,kmeans}/profile.csv`、`configs/{backprop,kmeans}.csv`。例如 backprop `9→17` 流量 5208 B，大于 128 B，却因 `limit` 被拒绝。

**影响**：level-2 定向测试证明“代码支持该层”，不能证明“正式配置执行了所有符合条件的层级插入”。历史报告虽然提到 limit，却将 Algorithm 2 简写为“已实现”，不足以说明这一有效截断。也不能将 static 的负结果概括为论文完整 long-link 策略的负结果。

**最小处理**：现有结果统一标注“HetSub static，最多 4 条有向 shortcut 的 Algorithm 2 预算变体”；本报告即作此限定。保留配置和负结果即可，不要求新增实验。如果将来必须声称未截断 Algorithm 2，才需取消这项额外预算、检查所生成配置，并仅重测受影响 static 条目；这不是本轮授权实施任务。

### F2：动态选择是实质性平台适配，不能宣称与论文控制策略严格等价

**已证实；P2（需披露）。** 论文 p.3135 依据 router 全端口总 buffer 占用生成拥塞信号；[Router.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc#L2375) 取当前 vnet 最忙 transit 输出端口。两种信号可能对同一状态给出不同选择，因此“等价”并未成立。75%/50% 滞回、四分比例步进和请求触发的 128-cycle 更新间隔，是本文移植的明确参数；论文没有给出该采样周期。

[GarnetNetwork.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc#L326) 在 dual 模式把 ordered vnet 固定到 M，static 固定到 L。固定单一路径有保序理由，但选择 M 并非 Ruby 必然要求，也偏离论文低流量优先 L 的原则。[HetSubPolicy.hh](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/HetSubPolicy.hh#L98) 与 NI 的单 VC 分配保持这一约束。

128 cycles 是相邻采样的**最小间隔**，不是状态陈旧度上限：没有请求时不会更新。历史“128-cycle 陈旧度门”不宜解释成最多滞后 128 cycles。上述差异不构成已经证实的错误交付；无需为使性能变好而更改阈值或选网方向。

### F3：基准结果有效，但资源、时序、统计人口和跨仓归因有限

**已证实；P2（基准边界）。** 128/56 的内部有向链路容量为 `126×16+224×7=3584 B/cycle`，与 128-bit Mesh 的 `224×16` 相同；128/64 为 3808 B/cycle，高 6.25%。这不是总面积等价，额外 NI 线路、relay、存储和控制成本必须保留。

旁路以独占复合通道模拟，默认传播延迟为 3/4 cycles（含两端接入），并非论文所有长链路均为 1 logical hop 的严格周期等价。模型有真实宽度、容量、背压和物理段活动，故不能指责其只是事后延迟修正；也不能当作已经校准的电路时序。

正式应用退出存在 8–47 个在途原始消息，service/completion 延迟人口仅为已接收消息；不能据此证明全部应用消息最终交付。各结构链路集合不同，物理 Jain 不直接证明跨结构更优的负载均衡。跨仓实现并非只改路由；即使平台参数相同，绝对差值仍不能全部归因于算法。首选同仓 off/XY 为 HetSub 对照。

### F4：旧报告的 GPU 16/10 待确认是陈旧文字，不是当前阻塞

**本轮直接核实。** 两个正式 audit 均 `ok:true`、各 8 项无错误；逐一读取正式与 pilot 的实际 `config.ini`/`gpgpusim.config`，均为 10 CudaCore、10 clusters×1 core。R4 公平性报告末尾仍写“GPU 16/10 待确认”，与当前配置和 TASK 已授权的统一方案不符。无需重新请求用户确认或重跑实验。论文应采用正式 v2 配置，旧 p6 状态仅作为历史记录。

## 论文机制与实际执行链

论文为 Y. Li et al., *HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems*, TVLSI 33(11), 3131–3144，DOI `10.1109/TVLSI.2025.3597406`。本轮提取本地 PDF 原文，并直接查看 p.3137/3138 的 Fig.8、Algorithm 1/2、Fig.9/10 页面图像。

| 机制 | 直接源码依据 | 结论 |
|---|---|---|
| 独立常开 L、PG M | `HetSub.py:40–69`、`GarnetNetwork.cc:221–257`；64+64 Router、独立链路，L 1 VC/vnet、M 2 VC/vnet | 已实现；不是共享 Mesh 上仅贴子网标签 |
| L Hilbert、M XY | `Router.cc:951–1005,1323–1344` | `request_vc→getRoute→setRoute` 真正决定端口；`routeCompute:1792` 使用已分配端口；没有被旧最短路表或 PSO 回退覆盖 |
| Algorithm 1 | `HetSubPolicy.hh:48–52`、`Router.cc:1333–1336` | 只有 shortcut 终点位于当前到目的的严格单调区间才使用；当前即目的时先按完整 endpoint 找本地端口 |
| 宽窄 flit | `NetworkInterface.cc:279–346`、`NetworkLink.cc:151–152` | `ceil(bytes/width)` 实际生成 16/8/7 B flit，链路检查宽度；不是延迟倍率替代序列化 |
| relay | `HetSubRelay.cc:33–143` | 每 vnet 有界帧、4 输入槽、共享 1 staging；连续有效字节转换，保留消息/生成时间；release 检查完整帧；在途 flit 纳入容量 |
| 静态旁路与共享带宽 | `GarnetNetwork.cc:260–311`、`NetworkLink.cc:130–188` | 构造期独占 M 段，serializer→proxy→deserializer→L；普通 M RC/buffer 不参与；relay 接入与既有本地 L 通道轮转共享 |
| PG | `Router.cc:1009,2403–2464` | VC 仲裁被 sleep/waking 阻断；6-cycle 等待实际影响 grant，10-cycle 等价转换成本单独记账；不是额外 10-cycle 延迟 |
| 动态选择 | `GarnetNetwork.cc:326–353`、`HetSubPolicy.hh:71–109` | preview 后仅在成功注入时 commit；滞回、比例、local/global 分类进入 NI 实际分配；反馈定义有 F2 差异 |
| Algorithm 2 | `insert_shortcuts.py:29–110`、`HetSub.py:76–113` | 高层优先、中心候选、相邻排除、区域流量、阈值、≤2 物理 hop、端口独占均有实现；正式配置受 F1 截断 |
| 正确交付与指标 | `NetworkInterface.cc:423–464`、`GarnetNetwork.cc:365` | tail 才向准确 vnet 投递原始消息；HetSub 错误 vnet fatal；完成指标按原始消息计数，避开 relay 分段 flit 均值 |

冲突约束应准确表述：配置按 `(tile,input/output port)` 和有向物理边独占，本地端口使每 tile 至多作为一条 shortcut 的源、至多作为一条的目的，但它仍可参与其他路径的物理中继。`Router.hh:682` 也只存一个出向 shortcut。不能把该模型表述为普遍实现了任意“每节点两入两出”的所有组合；对冻结配置未发现端口超配或冲突。论文 Fig.10 的连接限制与实现资源模型须分别描述，不凭措辞差异制造额外故障。

**允许的平台适配**：保留 gem5-gpu/Ruby、128/64 或 128/56 位宽、构造期 JSON、协议 vnet、周期级复合通道。论文 p.3143 明确演示静态配置、动态 long-link 为未来工作，所以缺少在线重配置不构成核心缺失；不需要实现 special-packet 配置网络、RTL、Noxim 或 SNN 平台。

**未实现且不批准的主张**：原文 SNN 收益、实际 J/W、总硬件面积等价、2 GHz 物理时序闭合、运行时动态重配置、任意 Ruby 负载无死锁。它们不作为本次基准前置要求。

## 证据强度与最小验证

本轮没有执行任何 gem5 仿真，也没有重新计算源码/二进制哈希。读取已有构建日志与运行 metadata：正式应用日志记录 source `a5470ae3…`、binary `9f5ed9cb…`，与 `build_logs/docker_build_and_test_j64_20261015_203550.log` 的 RECORDED/VERIFIED 记录吻合；Network_test 已有日志记录同 source 与 binary `1bef3876…`。这是历史构建/运行证据，不冒充本轮重新验证当前二进制。

已有 22 项网络检查和 16 项应用验证作为历史证据。本轮仅重放三个现有结果目录的离线 validator，另外做一次已有依赖检查，不重跑整个测试集：

| 本轮读取/检查 | 结果 |
|---|---|
| `20261015T152707Z/static_level2` | PASS；1024 包、字节/flit 守恒、busy=0；1176 physical segment beats、202 stall cycles、19 MUX deferrals |
| 同批 `policy_load` | PASS；1024 包，实际 L/M 均有注入、守恒、排空 |
| 同批 `pg_mesh` | PASS；256 包；212 次唤醒、1272 waking cycles、725371 sleep cycles |
| `check_dependencies.py …/static_level2/config.ini` | 4096 路径，130 资源、129 依赖，acyclic；仅该 NoC 抽象，不含 Ruby 协议依赖 |
| 两个正式 audit JSON | 16 个记录，无错误；本轮逐个核实 GPU 实际配置；未重新审计全部跨仓源码 |
| 两 pilot 的插入器内存复算 | F1 的 4→13；不表示 13-link 仿真通过或性能会改善 |

现有应用数值正确性通过独立 CPU 参考是历史执行证据，本轮没有重新执行应用或重新计算 CPU 参考。level-2 聚合帧数不能逐包证明指定源的全部报文都使用该路径；它足以证明该层旁路在真实运行中承载数据。依赖枚举验证的是配置路由模型，不是直接穷举 C++ 所有状态。

离线 F1 可按以下最小片段复核，无文件输出：

```python
import csv, sys
from pathlib import Path
sys.path.insert(0, 'tools/hetsub')
from insert_shortcuts import insert
root = Path('m5out/comparison_10c/formal_10c_v2_20261015')
for app in ('backprop', 'kmeans'):
    profile = {}
    for row in csv.DictReader((root/'hetsub_pilot'/app/'profile.csv').open()):
        key = int(row['src_tile']), int(row['dst_tile'])
        profile[key] = profile.get(key, 0) + int(row['bytes'])
    for limit in (4, 100):
        links, _ = insert(profile, 128, limit)
        print(app, limit, [(x['level'], x['src'], x['dst']) for x in links])
```

## 科研处置

1. **保持核心代码冻结**。本轮未发现必须修改 flexible 的运行正确性缺陷，不新增实施目标或验收套件。
2. **使用明确命名进入正式性能比较**：同仓 off/XY、HetSub dual（披露 F2）、HetSub static-4（披露 F1 与传播时序）分别报告；128/64 与 128/56 分列。已有 v2 结果可复用。
3. **保留负结果**：相对同仓 XY，backprop 总时间增加约 4.80%–6.46%，kmeans 增加约 12.68%–17.13%。这证明所测移植配置在这两个负载下更慢，不证明论文方法在 SNN 上无效，也不证明解除预算能改善结果。
4. 完整复现与基准资格的 CONDITIONAL 是**主张范围条件**，不是要求新实验的借口。若论文明确使用以上适配与 static-4 定义，可按限定基准 PASS 开展比较；如果坚持“原论文完整 Algorithm 2”的标签，现有证据不足，不能批准该标签。
