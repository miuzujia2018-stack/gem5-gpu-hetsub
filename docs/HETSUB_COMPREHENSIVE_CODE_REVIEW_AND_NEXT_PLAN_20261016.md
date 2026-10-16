# HetSub 方法复现全面 Code Review 与下一阶段研究计划

> 日期：2026-10-16
>
> 审查基线：父仓 `8f478cda`，`gem5` 子仓 `a90c04ca8`，分支 `synthetic-traffic-three-patterns`
>
> 审查范围：论文 III-A～III-C、Algorithm 1/2、Table I、Fig. 7～10；`flexible-pipeline`、`HetSub.py`、离线插入工具、测试器和正式 v2 结果
>
> 审查方式：论文全文、冻结源码、已有原始产物与验证脚本交叉核对；本轮不修改核心代码、不重新运行仿真
>
> `review_independence: same-family`；`acceptance_status: provisional`

## 1. 目标、边界与裁决

本项目的目标是在固定 gem5-gpu / flexible Garnet / VI_hammer CPU–GPU 平台上，复现 HetSub 的核心架构方法和关键数据路径机制；不迁移 Noxim/SNN 平台，不复现原论文的性能幅度、工艺面积或实际功耗数值。论文依据为 Y. Li et al., *HetSub: A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems*, IEEE TVLSI 33(11), 3131–3144, 2025，[DOI](https://doi.org/10.1109/TVLSI.2025.3597406)，本地全文见 [论文 PDF](</home/siat/paper/network_on_chip/HetSub A Heterogeneous Multi-NoC With Reconfigurable Long-Range Links for Neuromorphic Systems.pdf>)。

| 维度 | 裁决 | 适用范围 |
|---|---|---|
| 论文方法复现完整性 | **CONDITIONAL** | 核心机制全部存在并接入真实数据路径；动态分流反馈、local/global 定义和 shortcut 时序是公开的平台适配，不是逐位复刻 |
| 算法与功能正确性 | **PASS** | 未发现会导致错误路由、错误交付、资源无界或实验失效的已确认 P0/P1 缺陷 |
| 性能比较基准资格 | **PASS（限定）** | 可用于固定平台上的 NoC 架构级时延、吞吐、拥塞、PG 状态和活动量比较；不可外推为纯路由单因素、完整面积等价、J/W 或原论文性能复现 |
| 综合处置 | **CONDITIONAL APPROVE / FREEZE** | 现有限定条件已经在结果文档中披露；冻结核心实现，进入论文级结果分析，不新增机制开发或重复实验 |

这里的 `provisional` 只表示本轮没有跨模型独立审稿人，不表示源码和原始产物证据未经核对。

## 2. 证据等级

- **A：直接源码或原始产物证据。** 本轮直接读到冻结 SHA 的实现、`config.ini`、`stats.txt` 或可执行断言。
- **B：已有测试报告并可由当前脚本复核。** 本轮没有重新启动模拟器，但重新对已有产物运行验证器。
- **C：设计选择或论文未给出完整细节的合理平台适配。** 允许使用，但论文必须披露。
- **D：当前范围外或缺少支撑。** 不允许据此形成性能、面积或能耗主张。

文档中的“已实现”要求至少有 A 级源码证据和一项 B 级行为证据；仅有参数、注释或结果标签不算完成。

## 3. 论文机制—代码—证据逐项核查

| 核心机制 | 论文要求 | 当前实现和源码证据 | 状态与偏差 |
|---|---|---|---|
| 异构双子网 | 常开低 radix dual-line；独立 PG Mesh；独立 RC/VA/SA 和链路 | [HetSub.py](../gem5/configs/ruby/HetSub.py) 构造 64 个 L Router 和原 64 个 M Router；[GarnetNetwork.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc) `initHetLinks()` 建立独立 L 链路；Router 的 HetSub 路径与遗留 PSO 状态隔离 | **已完成（A/B）**。软件对象为 128 个逻辑子路由器，物理语义仍是 64 对 L/M 子路由器，不能按“64 router”隐藏第二套控制资源 |
| Hilbert dual-line 路由 | 每节点最多前驱、后继和 local；路径唯一、严格单调；1 VC | [HetSubPolicy.hh](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/HetSubPolicy.hh) `Geometry::next()`；[Router.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc) `getRoute()`；L Router `vcs_per_vnet=1` | **已完成（A/B）**。64×64 路径检查通过 |
| M 子网 XY 路由 | 完整 2-D Mesh、2 VC、可 PG | `Router::getRoute()` 对 M 使用严格 X-then-Y；M Router 和链路均为 `vcs_per_vnet=2` | **已完成（A/B）** |
| 真实宽窄 flit | L 64-bit、M 32-bit；窄子网产生更多 flit 并真实占用容量 | 当前平台按比例放大为 L=128 bit、M=64 bit；另有 M=56 bit 内部链路等预算变体。[NetworkInterface.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc) 按实际消息字节和子网宽度生成 flit；[NetworkLink.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkLink.cc) 每周期只传一个本链路 flit | **已完成（A/B）**。Ruby 消息长度替代论文固定 packet 长度，属于正确的平台映射；56-bit 不是论文参数 |
| NI 选网与共享服务 | tile 同时连接两个子网，但消息只注入一次，不能免费翻倍 tile 带宽 | `flitisizeHetMessage()` 在生成 flit 前决定子网；`scheduleOutputLink()` 对 L/M 共用一个 round-robin 发射机会 | **已完成（A/B）** |
| 动态子网选择 | 低流量全部进 L；L 拥塞后 local 优先 L、global 按动态比例进 M；M 拥塞降低该比例；拥塞信号有滞回 | [HetSubPolicy.hh](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/HetSubPolicy.hh) `Selection`；[GarnetNetwork.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc) `hetChoose/hetCommit`；[Router.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc) `hetCongestion` | **部分等价、机制完成（A/B/C）**。当前采用每 vnet 最忙 transit 输出端口、75%/50% 滞回、128-cycle 采样；local 定义为 Hilbert 距离≤2。论文没有给出完整比例函数，但正文描述的是所有端口 buffer 使用量，不能宣称逐位一致 |
| ordered vnet | 不因跨子网选择破坏协议顺序 | ordered vnet 固定 M/XY，并只使用该 vnet 的第一个 VC | **已完成的平台保护（A）**。牺牲了 ordered 流量参与 L/shortcut 的覆盖率，应在方法章节披露 |
| PG 状态机 | M 可休眠；真实 6-cycle WU；每次 WU 计 10-cycle 静态功耗等价转换成本；有在途资源时不得休眠 | [Router.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc) `hetResourcesIdle/hetIdleCheck/hetPowerReady`；VC grant 在 WAKING 中被阻塞 | **已完成（A/B）**。50-cycle idle threshold 是实现选择；统计是状态/事件代理，不是实际 J/W |
| 静态 long-link | 低流量时屏蔽普通 M 选择；利用休眠 M 物理链路和 crossbar bypass；中间不走正常 buffer/RC/VA | [HetSub.py](../gem5/configs/ruby/HetSub.py) static 模式强制 L；[GarnetNetwork.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc) 绑定真实 M segment；static 结果中 M route request/buffer write 为 0 | **已完成（A/B）** |
| 旁路容量和冲突 | 一至两段 Mesh hop；物理段和 crossbar 不可冲突；目标满时必须背压 | `configure_shortcuts()` 和 `initHetShortcuts()` 双重校验输入/输出/有向物理段；[NetworkLink.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkLink.cc) 以单一 composite 流水通道代理冻结物理段并独占资源 | **已完成、时序近似（A/B/C）**。容量、独占、背压和活动真实；各物理段不分别排队。默认 `segments.size()` 周期为保守传播，另有论文式一周期抽象，均非 RTL/STA |
| NI relay 与 ser/deser | 使用 local port 在 L/M 间中转；64→32 序列化、32→64 反序列化；有界缓存和握手 | [HetSubRelay.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/HetSubRelay.cc) 每 vnet 一个 frame、四输入 flit 槽、一个共享 staging；连续有效字节转换；request/grant/release 贯穿完整 frame | **已完成（A/B）**。支持 16↔8 和 16↔7，不按宽 flit 独立补齐 |
| Algorithm 1 | shortcut 终点必须严格位于 current 与 packet destination 的单调区间内 | `Geometry::shortcutAllowed()` 实现 `(c<e≤d) or (d≤e<c)`，Router 仅在谓词为真时进入 shortcut | **已完成（A/B）** |
| Algorithm 2 | Hilbert 分层 U 子区；排除相邻子区和最低 2×2；高层优先；中心端点；流量阈值；冲突过滤 | [insert_shortcuts.py](../tools/hetsub/insert_shortcuts.py)；[test_insertion.py](../tools/hetsub/test_insertion.py)；独立 pilot→冻结 JSON→不同 seed 正式运行 | **已完成（A/B）**。同层采用确定性顺序、最多 4 条有向 shortcut，是公开的实现选择 |
| 正确交付 | 最终消息不得丢失、重复、错 NI、错 vnet 或乱序；有限包测试必须排空 | [NetworkInterface.cc](../gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc) `checkHetReceive()` 检查目的、格式、flit ID 和有效字节；[validate_network.py](../tools/hetsub/validate_network.py) 检查 packet/byte/flit 守恒和 `het_busy_resources=0` | **已完成（A/B）** |
| 原论文系统、性能、面积与功耗 | Noxim、SNN workload、SMIC 55 nm RTL、原文收益幅度 | 本项目没有实现，也不属于固定平台目标 | **未实现、明确范围外（D）** |

## 4. 数据流审查

实际路径为：Ruby MessageBuffer → NI 将 multicast 拆为独立 unicast → `hetChoose()` 选择 L/M → 按 16/8/7-byte 宽度生成 flit → 有界源 VC → L Hilbert Router 或 M XY Router → 最终 NI 检查并重组 → Ruby 目标 MessageBuffer。

static 模式命中捷径时，路径变为：L Router → serializer relay → 冻结 composite M 物理段 → deserializer relay → L Router。此路径具有以下已确认性质：

1. shortcut 选择发生在实际 `Router::getRoute()`，不是统计阶段重标记；
2. relay 输出必须先取得下游 VC grant；
3. relay FIFO、link source staging 和目标 L buffer 均产生背压；
4. bypass 物理段被构造期独占，普通 M 注入被禁止；
5. 中间 M Router 的 RC/VA/buffer 不参与；
6. 原始 `MsgPtr`、生成时间、协议 vnet 和最终目的保持不变；
7. 最终 tail 只向 Ruby 交付一次。

未发现会使算法“未真正接入数据路径”的旁路或回退分支。

## 5. Findings first：问题分级

### 5.1 P0/P1：无已确认阻断缺陷

本轮未发现以下任一情况：错误目的投递、宽度/字节不守恒、shortcut 越过目的、M 正常路由与 frozen segment 同占、relay 无界缓存、PG 在活跃 VC 上休眠、静态路径调用中间普通 RC/VA、合法有限包无法排空。现有源码和原始产物不支持重新打开核心实现。

### 5.2 P2：必须披露但不需要修代码的建模偏差

| ID | 已确认偏差 | 科学影响 | 处置 |
|---|---|---|---|
| F-01 | local/global 用 Hilbert 距离≤2代理 SNN 语义 | 影响流量分离比例和性能，不影响机制是否存在 | 在论文方法章节写成迁移定义；不得称原文分类逐位一致 |
| F-02 | 拥塞反馈为“当前 vnet 最忙 transit 端口”，不是论文文字中的“所有端口总 buffer 使用量” | 可能改变触发时刻，但保留双子网反馈、滞回和动态比例 | 保留为 output-buffered Garnet 适配；无需为追求论文曲线重写 |
| F-03 | composite shortcut 默认采用物理段数周期的保守传播；论文把旁路视为 logical hop=1 | static 性能不能直接视为原论文硬件结果 | 正式表注明时序模型；已有一周期 sensitivity 仅用于建模边界，不要求重复运行 |
| F-04 | 128/56 只匹配内部有向链路位宽预算 | 外部 NI 线路、buffer、relay、mux/control 和布线没有完整面积等价 | 允许做内部链路等预算比较；禁止写“总面积/总带宽完全等价” |
| F-05 | 应用退出时有 8–47 个在途原始消息 | 完成延迟人口仅为退出前已接收消息 | 继续单列 inflight；有限包测试承担排空正确性证明 |
| F-06 | 三仓不是逐行相同的单一源码 | TBP/bak/HetSub 差值包含各方法实现结构 | 称“冻结平台上的方法系统比较”，不称纯路由单因素因果 |

### 5.3 文档一致性问题

[HETSUB_FUNCTIONAL_REQUIREMENTS.md](../HETSUB_FUNCTIONAL_REQUIREMENTS.md) 的旧参数表将 Table I 写成 L=2 flits、M=8 flits。原文 Table I 是 2×64-bit 与 4×32-bit；4/8 flits属于 Fig. 13 的另一组延迟分解。当前实现按实际 Ruby message bytes 计算 flit，因此源码和正式结果不受影响。该旧文档不得再作为权威参数来源；未来整理文稿时顺手修正即可，不构成新开发阶段。

### 5.4 非必要优化，明确不做

- 不增加逐包 registry、CSV/图表哈希、哈希链或结果数据库；
- 不把 composite link 重写成通用 circuit-switching 框架；
- 不迁移 Noxim、SNN 软件栈、RTL 综合或后端布线；
- 不为得到正收益调整 local radius、拥塞阈值、idle threshold 或 shortcut 数；
- 不扩展成全 workload × 多 seed × 多阈值笛卡尔矩阵；
- 不以“形式化证明任意 Ruby 协议无死锁”替代当前有界数据路径验收；
- 不重构 `Router.cc` 中与 HetSub 路径隔离的遗留 PSO 代码。

## 6. 已有验证证据及其边界

本轮只重放验证器，不重新启动模拟器：

- `X86_Network_test` 与 `X86_VI_hammer_GPU` 当前构建凭据均通过官方 verifier；
- 20 个已有成功运行目录重新通过 [validate_network.py](../tools/hetsub/validate_network.py)；
- 5 个 Algorithm 2 单元测试通过；
- 13 组 dual/static 配置重新通过 64×64 路径和通道依赖无环检查；
- `independence`：10557 个同 tile L/M 并行周期，M 唤醒时 L 继续前进，L 满时 M 继续前进；
- `pg_mesh`：212 次唤醒、1272 waking cycles，满足 `212×6`；转换成本满足 `wakeups×10`；
- `static_level2`：1024 packet、28608 byte、2730 flit 全部守恒并排空；48 frame 实际通过 level-2 relay，1176 个物理 segment beats，202 个下游阻塞周期，19 次 local MUX 延后；
- 正式 `formal_10c_v2_20261015` 两份 audit 均为 `ok:true`，16 个应用运行平台签名一致且数值检查通过。

`static_level2` 的 relay 聚合计数证明该 frozen shortcut 实际承载流量，但不能单独逐帧归因“tester 10 的恰好 16 包全部命中”。确定性路由源码可证明 10→17 在 router 10 满足 Algorithm 1；当前研究主张不需要增加逐源追踪。

## 7. 下一阶段唯一研究目标

### GOAL-HS-R2：冻结方法实现，形成论文级“机制—证据—主张”闭环

当前没有尚未实现的核心机制。下一阶段不再以修改 flexible 数据路径为目标，而是将现有实现和正式 v2 结果组织为可投稿、可复核且不过度外推的固定平台研究结论，重点解释负收益及适用边界。

| 步骤 | 优先级 | 工作内容 | 预期产物 | 完成标准 |
|---|---|---|---|---|
| R2-0 冻结与命名 | P0 | 固定父仓/子仓 SHA、正式批次和方法名称；将 off、dual 128/64、dual 128/56、static 128/64、static 128/56 分开 | 论文实验配置表和冻结声明 | 不混用论文比例与 matched-budget；不按 workload 选择较优配置 |
| R2-1 主张矩阵 | P0 | 把每项论文机制对应到源码、定向测试和允许主张；将近似/范围外项写入限制 | 一张 mechanism-to-evidence/claim 表 | 每个“已实现”至少有源码与运行证据；每个性能主张有统一人口和单位 |
| R2-2 正式结果解释 | P0 | 使用现有 v2 数据分析为何当前 CPU/GPU workload 下 HetSub 为负收益：Hilbert 路径长度、序列化、M 唤醒、shortcut 命中及 inflight 边界 | 结果章节文本和必要的已有数据图表 | 保留全部负结果；不调参、不择优、不引用原文收益作为目标 |
| R2-3 公平性披露 | P0 | 明确内部链路预算、外部线路、buffer/control、跨仓源码和应用未排空边界 | threats-to-validity/limitations 小节 | 128/56 只称内部链路等预算；活动量不称能耗；跨仓不称纯路由因果 |
| R2-4 证据封装 | P1 | 从已有 audit、stats 和 config 提取论文需要的最小表格；不上传大体积 m5out，不增加哈希体系 | 可追溯表格及命令说明 | 表格数值能追溯到正式目录和现有脚本；无新的仿真依赖 |
| R2-5 最终科研复审 | P1 | 检查论文文字是否超出本文件裁决；只审查主张与证据，不重新验收已冻结代码 | 最终 reviewer checklist | 无“原论文性能复现、完整面积等价、实际能耗、应用全网排空”等越界表述 |

## 8. 下一阶段测试与验收设计

### 8.1 当前阶段立即需要的测试

**无新增 simulator test。** 当前源码、构建和正式结果已经满足核心方法复现门槛。重复运行 22 项有限包测试或 16 个应用案例不会提升当前结论的证据等级。

只允许执行以下只读、低成本复核：

```bash
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_Network_test
tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_VI_hammer_GPU

cd tools/hetsub
PYTHONDONTWRITEBYTECODE=1 python3 test_insertion.py
```

已有运行目录需要复审时，可对指定案例调用：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 tools/hetsub/validate_network.py \
  m5out/hetsub_network/20261015T152707Z/static_level2 static_level2

PYTHONDONTWRITEBYTECODE=1 python3 tools/hetsub/check_dependencies.py \
  m5out/hetsub_network/20261015T152707Z/static_level2/config.ini
```

### 8.2 若未来修改核心数据路径，才重新开启的最小回归门

| 层级 | 最小测试 | 判定标准 |
|---|---|---|
| 单元 | `test_policy.cc` + `test_insertion.py` | 4096 L 路径到达；Algorithm 1 正反/越界谓词正确；7/8/16-byte flit 有效字节守恒；Algorithm 2 层级、阈值和冲突断言通过 |
| 模块集成 | `line`、`mesh7`、`policy_load`、`pg_mesh`、`static7`、`static_level2`、两个非法配置 | 双子网均真实传输；拥塞分流非零；`waking=6×wakeups`；非法路径拒绝；relay 有界且背压恢复 |
| 最小端到端 | 一次完整 22-case finite-packet suite | 所有合法案例 packet/byte/flit 守恒，`het_busy_resources=0`；static 中普通 M RC/buffer=0；无 fatal、fallback、错误 NI/vnet |
| 应用 | 仅当修改可能影响 Ruby/GPU 交付时，运行 backprop 和 kmeans 的 off + 一个受影响 HetSub 配置 | 应用正常退出、CPU 参考数值通过；退出 inflight 单列，不要求应用全网排空 |

不得因为仅修改论文文字、审查文档或离线表格而触发 simulator 重建或应用重跑。

### 8.3 硬失败标准

出现以下任一证据时才重新打开核心实现并将当前批准降为 FAIL：

1. 合法有限包场景发生错误目的、丢失、重复、错误 vnet 或无法排空；
2. flit/有效字节转换不守恒，或 56-bit 边界产生逐宽 flit 补齐；
3. shortcut 越过最终目的、反向使用或形成已证实的通道依赖环；
4. static 模式的普通 M Router 产生 route request/buffer write，或 frozen 物理段与其他流量同时占用；
5. relay 超过四输入槽、绕过背压或在完整 frame 前释放 VC；
6. M Router 在存在活动 VC、buffer、staging 或非旁路在途 flit时进入 sleep；
7. 正式比较的实际 CPU/GPU/cache/endpoint 映射或输入不一致；
8. 源码变化后仍使用旧二进制或 verifier 失败。

性能下降、shortcut 命中率低、应用退出存在已披露 inflight、某工作负载不适合 HetSub，均不属于实现失败。

## 9. 允许与禁止的科研结论

| 现有证据条件 | 允许结论 | 禁止结论 |
|---|---|---|
| 当前全部证据 | 在固定 gem5-gpu CPU–GPU 平台上实现了 HetSub 核心机制的周期级移植模型 | 完整复现原论文平台、实验和性能收益 |
| 128/64 | 保留论文 L:M=2:1 位宽比例 | 与 128-bit XY 在当前有限 Mesh 上严格总资源相等 |
| 128/56 | 当前 8×8 Mesh 内部有向链路位宽预算相等 | 总面积、外部线路、buffer/control 和能耗完全相等 |
| v2 应用 | 报告退出前已完成消息的服务/完成延迟和应用总时间 | 所有注入消息均已排空、零丢包已由应用证明 |
| PG/activity stats | 报告 sleep/waking/active cycle、wakeups、WU 和通道活动代理 | 未经工艺校准的 J、W、节能百分比 |
| 跨仓结果 | 同冻结系统配置下的方法系统比较 | 除路由函数外完全相同的单因素因果实验 |

## 10. 最终停机与冻结条件

本次审查已经满足以下停机条件：所有核心机制均有真实数据路径实现；Algorithm 1/2 均有源码和运行见证；有限包正确交付、守恒、背压和排空成立；正式应用平台与数值正确性审计通过；建模近似和负结果已披露；未发现新的 P0/P1。

因此：

- **冻结 flexible-pipeline、HetSub.py、relay 和插入算法实现；**
- **正式结果固定为 `m5out/comparison_10c/formal_10c_v2_20261015/`；**
- **下一阶段只做论文级分析、表述和证据整理；**
- **不得人为增加新的机制验收任务。**

只有出现第 8.3 节的具体反例，或研究目标被明确扩张到 RTL/工艺、原论文 SNN 平台、实际能耗/面积时，才另立任务并重新评估范围。
