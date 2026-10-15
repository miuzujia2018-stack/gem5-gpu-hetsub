# Active Task — HetSub 核心机制实施（2026-10-15）

## 当前生效裁决：正式三仓统一配置（取代下文等待确认状态）

用户已批准正式比较专用配置：10 clusters × 1 core、16 CPU、4 Directory、40 GPU L2、64 tile Mesh，保留10个GPU NoC端点。配置决策阻塞已解除，不再重复请求相同确认。旧16/10混合结果仅为历史机制证据；bak默认40-cluster配置及历史实验保留。

实施范围与顺序：
1. 新增集中、简单的正式比较入口和配置审计，使用显式CLI覆盖，尽量不改三仓默认值。固定共同二进制/输入、CPU/GPU/Ruby频率、缓存参数、端点和cache映射、种子和统计窗口。实际config.ini与gpgpusim.config必须同时证明10核；72个controller映射与106个cache几何逐项核对。
2. 三仓分别通过官方Docker干净构建和每次运行前verify；记录源码/二进制现有凭据、命令、构建日志及配置。不沿用p6旧结果作为新比较数据，不新增结果哈希。
3. 比较off/XY、TB-TBP、bak当前方法及HetSub dual/static 128/64与128/56；方法若无有效启用证据必须标明未验证，不能将XY冒充方法结果。应用pilot独立于最终seed，冻结Algorithm 2配置。
4. 测量低时延、拥塞/吞吐、负载分布和PG/活动量四维；指标必须同人口/时间单位。无校准功耗不报告J或节能百分比。128/56只匹配内部链路位宽，外部线路/存储差异进入结论。
5. 区分应用正常退出、injected=received+inflight的守恒证据和全网排空。有限包合成测试必须完整排空；应用未排空必须显式报告在途与资源，不把退出当排空，必要增加统一退出后测量而不改应用统计窗口。
6. 验收数值正确性、实际平台一致、方法启用、流控/时序/资源约束及排空证据。最终REVIEW写已实现/近似/未实现清单；缺失为NEED FIX/UNVERIFIED，不为收益调参。
7. 阶段审查前先提交推送所有相关改动，核对远端SHA与gitlink并给出链接。未完成不记PASS。

允许文件：父仓tools/hetsub、docs与.ai交接文件，必要run/build入口；如测量需修改源代码，限GPU配置、flexible Garnet同定义计数及仿真退出处理，先说明具体缺口。跨仓操作遵守各自AGENTS，不覆盖并行工作；优先从本仓驱动独立正式配置。

## 当前交付与范围

用户要求读取论文原文和 code review，设计一个尽量保留 HetSub 核心方法、尽量少改现有实验平台的比较基准，用于与 gem5-gpu-bak 和 gem5-gpu-tbp 比较，并保存 Markdown 测试/验收方案；禁止过度工程化、过度哈希。

当前优先设计：[HETSUB_FAITHFUL_PLATFORM_PLAN.md](../../docs/HETSUB_FAITHFUL_PLATFORM_PLAN.md)。用户已要求开始执行复现，允许必要NoC源码改造；固定系统平台，复现机制而不复现原文性能或实验平台。此前 [HETSUB_MINIMAL_BASELINE_PLAN.md](../../docs/HETSUB_MINIMAL_BASELINE_PLAN.md) 保留为历史适配退路，不作为本次独立双子网实现规格。

使用用户新授权的专用容器 `gem5gpu-dev-hetsub`，显式绑定本仓同名路径，替代旧共享容器要求。

## 后续实施规格

以当前优先设计第6节为准：先对齐平台，再实现独立双子网及真实flit宽度，随后加入选择/PG、静态旁路与真实relay、离线分层插入。禁止用共享两个VC或末端延迟补偿代替独立子网与真实序列化。

固定系统、64个tile位置、协议、输入及实际端点映射；NoC资源按真实bit数和链路容量核算。分别保留128/64论文比例与128/56内部链路等预算配置；普通双子网和静态long-link模式独立报告。软件Router对象个数不替代硬件资源计数。旧需求文档的全部阶段不自动构成本任务范围。

## 验收要点

- 论文原文页码、算法和参数已核对，代码与旧 review 的限制已写入文档。
- 实施后需满足当前优先设计第7节及旧方案仍适用的定向测试、排空、应用正确性与统一比较条件。
- long-link 必须有真实资源占用、服务时间和背压；未完成不得宣称已覆盖该机制。
- 保留官方干净构建与现有 verify 门禁；不新增结果哈希链或验证平台。
- 性能提升不是正确性通过条件；保留负结果和模型近似。

## 当前修复批次：拥塞信号与时间单位

- 八项实际运行中七项通过；`policy_load`全部使用L，未满足真实拥塞分流验收。保持75%/50%滞回与128-cycle采样，不为跑出分流降低阈值。
- flexible Garnet使用输出buffer，拥塞信号改为当前消息vnet的最忙transit端口VC占用比例，避免其他vnet及反方向空队列掩盖瓶颈；这是本平台的反馈范围适配，资源统计继续覆盖全部端口。
- NetworkTest终止条件使用对象cycle，配置使用1ps全局tick；验证1GHz与2GHz运行同样周期、实际tick数与clock period相符。
- 源码修改后官方干净构建，再运行关闭回归、宽度、拥塞和PG检查；失败保持未验收，不调整平台/输入选择性能结果。

## 下一阶段静态旁路实现约束

- 接受离线插入配置，构造时校验候选端点、物理有向路径（最多2-hop）、crossbar输入/输出独占和端点度数。静态模式禁止普通M注入；配置在运行期间冻结。
- 复用NetworkLink及FlexibleConsumer接口，新增一个局部宽度转换relay类即可；每vnet一个有界帧上下文、4个输入flit槽和一个共享输出staging槽。保留原MsgPtr、生成时间和协议vnet；按连续有效字节流转换16↔8或16↔7，不能按单个宽flit补齐。
- request/grant/release必须贯通两端及L router，包含所有在途flit的容量检查；输出tail未释放前保留该帧上下文，禁止多个包交错和无限整包缓存。
- composite旁路引用已有M物理段，收集各段实际传输，独占对应资源；不调用中间普通RC/VA/写buffer。共享原NI本地服务预算，新增relay端口不得免费增加tile注入/弹出带宽。
- Router只在Algorithm 1严格单调区间内选择已冻结捷径，越界/反向走原L路径；ordered vnet保持单一VC及确定性路径。
- 首先覆盖单条、双条、冲突拒绝、72-byte以上长帧、56-bit跨宽flit边界、目标背压恢复、所有上下文/VC/link排空；再连接独立pilot生成的Algorithm 2配置。
- 时序与存储列明建模假设；原文logical-hop抽象与保守物理传播分别测试，不声称已经证明2GHz硬件时序。

## 当前实施批次：静态旁路

新增HetSubRelay局部类（继承ClockedObject/FlexibleConsumer），构造阶段接入原M链路代理与新增本地L接入。NetworkLink增加冻结旁路段记账及二路本地MUX，Router增加严格单调shortcut端口、有限staging和实际活动计数。配置从离线JSON读取，校验所有物理段与crossbar资源冲突；默认off/dual不启用旁路。先以固定单条/双条配置测试，未通过不得宣称核心机制完成。源码修改后必须官方干净构建，再执行新旧模式检查。测量存储包括新增relay及本地输出VC，明确composite传播时序假设。

## 接续批次：实际pilot与背压证据

p4十五项检查已PASS。接续增加源NI实际接受的tile流量矩阵导出（独立pilot CSV，使用现有Stats reset语义）、relay下游阻塞周期和本地MUX延后计数；添加三种traffic压力与pilot→Algorithm 2→冻结配置的独立测试。pilot与最终验证采用不同seed，配置只读取pilot，不读取测试未来消息。修改后重新执行官方干净构建与门禁，p4结果不得替代新版本验收。

## 当前批次：packet测量与应用

- 在最终NI交付tail时为原始消息各记一次service、源排队、完成延迟与最大完成延迟，保留relay原始生成时间；off/dual/static相同定义。禁止把relay分段flit平均延迟当packet延迟。
- 实际内部Link记录同tile L/M同周期前进、M唤醒期间L前进、L满时M前进，用于独立性验收。
- 官方干净构建Network_test后验证新增计数和旧20案例；官方应用目标干净构建与backprop/kmeans测试。
- 当前bak默认配置已变为ALPHA（8dir、8L2、40cluster），与本仓/TBP的4dir、40L2、16cluster不同；不修改平台追随该默认，后续比较通过显式参数对齐并核对实际端点映射。bak placement用random_seed，本仓/TBP用topology_seed，同seed名字不等于映射相同。

## 历史独立验收：资源和PG（旧16/10配置）

此前GPU口径待确认期间，仅审查已有数据和NoC模型。该批证据继续保留为历史机制证据：核对实际内部/外部链路宽度、router/NI/relay/staging存储，验证PG状态周期分解及每次10-cycle静态功耗等价的WU记账。原文IV-A明确6-cycle WU、10-cycle break-even；无同工艺系数时不输出J或节能百分比。资源账必须区分独立外部线路宽度与NI共享服务上限，pipeline/control/短接线未校准不能写成完整面积。

## 当前状态

**状态：实施、验收及 GitHub 同步均已完成。** 正式有效批次为`formal_10c_v2_20261015`；三仓双应用、实际平台、方法活动、数值正确性和四维指标审计均通过。最终HetSub 21项有限包检查通过。v1发现并修复的GPU L2映射错误及应用退出未排空边界已写入REPORT/REVIEW与结果文档。最终成果提交为父仓`3332114f`，其五个gitlink及对应远端分支已核对一致；后续仅有流程状态修订时，以更新后的父仓提交为准。

p6已完成21项网络检查（含同tile独立性/双向阻塞隔离、packet完成统计、实际配置通道依赖）、官方应用目标干净构建及10个应用数值检查（off及dual/static两宽度）和独立应用pilot。数据与具体命令、首次旧Bash失败/后续修复证据见REPORT。

**以下为 p6 历史状态，已由正式 v2 批次取代。** 当时旧结果存在本仓/TBP gem5 10核而GPGPU-Sim 16 clusters、bak默认系统不同的问题，因此只作历史机制证据。正式v2批次已完成共同输入/种子、实际cache/controller映射验证、正式运行及最终方法近似/资源/时序披露审查。应用退出时的在途消息继续单列，延迟统计人群明确为退出前已接收消息，不能声称应用全网排空。

当前源码范围：flexible-pipeline的GarnetNetwork、GarnetLink、NetworkLink、Router、NetworkInterface、flit及HetSubPolicy；配置Ruby.py/HetSub.py；必要构建入口、tools/hetsub测试及交接文档。默认off须保持兼容，dual中L/M各使用独立Router实例与物理数据通道。验收必须涵盖后续所有核心机制，不得以当前策略测试缩减最终目标。

---

# Historical Task — Synthetic Traffic Workflow

## Goal

Fix the two must-fix review findings for the 3-pattern synthetic traffic workflow:

1. Host-visible raw `stats.txt` artifacts must match the final `results.csv`.
2. The documented end-to-end command path must succeed without a manual host-side rescue step after the Docker sweep.

## Context

- Review findings are in `.ai/reviews/REVIEW.md`
- Current host `results.csv` is correct, but host raw `bit_reverse` / `transpose` `stats.txt` files do not match the rerun data from Docker
- `scripts/sweep_synth_traffic.sh` currently tries to plot inside Docker, but the container lacks `matplotlib`
- Preserve the existing parser fix for `uniform_random -> 0`
- Stay focused on pipeline correctness and artifact consistency; do not change the network model itself

## Files Likely Involved

- `scripts/sweep_synth_traffic.sh`
- `scripts/plot_synth_traffic.py`
- `scripts/parse_synth_stats.py`
- optionally one new helper script under `scripts/` if needed for a host-side wrapper
- `.ai/reports/REPORT.md`

## Implementation Steps

1. Read `.ai/reviews/REVIEW.md` and fix only the `Must Fix` items.
2. Make the workflow produce a consistent host-visible artifact set:
   either by ensuring Docker writes are synchronized back to the host,
   or by adding a host-side wrapper/export step that copies the rerun results out explicitly.
3. Make the documented end-to-end command path succeed without an ad hoc manual fallback.
   Acceptable approaches include:
   - a host-side wrapper command that runs the Docker sweep, exports artifacts, then parses/plots on the host, or
   - a Docker-side environment fix if you can keep it scoped and reproducible.
4. Ensure stale directories do not silently pollute the parsed CSV for this workflow.
5. Update `.ai/reports/REPORT.md` with the exact final command path, what changed, and remaining risks.

## Acceptance Criteria

- There is one documented command path that completes successfully for this task
- After that command path finishes, host-visible artifacts are internally consistent:
  - `m5out/synth/results.csv` exists
  - `m5out/synth/latency_vs_load.png` exists
  - `m5out/synth/throughput_vs_load.png` exists
  - host `m5out/synth/<pattern>/inj_<rate>/stats.txt` files correspond to the same rerun data used by `results.csv`
- CSV has 21 data rows, covering 3 patterns x 7 injection rates
- `pattern` values are exactly `uniform_random`, `bit_reverse`, and `transpose`
- `synthetic` values are only `0`, `1`, and `2`
- `.ai/reports/REPORT.md` clearly states the final authoritative command path and whether plotting happens in Docker or on the host

## Test Commands

1. Run the final documented end-to-end command path from the host.
2. Verify CSV:
   `python3 -c "import csv; rows=list(csv.DictReader(open('m5out/synth/results.csv'))); print(len(rows)); print(sorted({r['pattern'] for r in rows})); print(sorted({r['synthetic'] for r in rows}))"`
3. Verify a sample host raw artifact matches the CSV row from the same run:
   check at least one case from `uniform_random`, one from `bit_reverse`, and one from `transpose`.
4. Verify plots exist on the host:
   `ls -l m5out/synth/results.csv m5out/synth/latency_vs_load.png m5out/synth/throughput_vs_load.png`

## Do Not

- Do not modify `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- Do not add new traffic patterns
- Do not rewrite unrelated untracked `reports/` files
- Do not broaden the task beyond the two `Must Fix` review items
