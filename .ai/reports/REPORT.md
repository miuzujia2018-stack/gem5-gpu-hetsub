# Report: HetSub 核心机制实施进度（2026-10-15）

## 当前状态

### 10-cluster正式比较完成（已同步GitHub）

正式有效批次为`m5out/comparison_10c/formal_10c_v2_20261015/`。backprop与kmeans各8个方法案例全部正常退出、通过独立CPU数值检查；两个`audit_*.json`均`ok: true`，实际配置一致为16 CPU、10 CudaCore、4 Directory、40 GPU L2、64 routers和72 endpoints，GPGPU-Sim为10×1。TBP VC grant、bak PSO表使用率以及HetSub dual/static活动均为正。

审计曾在v1发现HetSub/TBP的旧`VI_hammer_fusion.py`错误地把40个L2直接作为索引位数，实际`start_index_bit=47`，与bak的13不一致。已在HetSub/TBP改为`ceil(log2(num_l2caches))`，分别提交`e53ac26`与`4d0cf3b`，重新官方干净构建后才产生v2；v1明确无效。最终应用构建凭据：HetSub source `a5470ae3` / binary `9f5ed9cb`，TBP source `2d85cd7a` / binary `1fc9f7ca`，bak source `76ee344d` / binary `409517d9`。构建日志分别为`docker_build_and_test_j64_20261015_203550.log`、TBP `docker_build_and_test_tbp_20261015_204344.log`、bak `docker_build_and_test_j64_20261015_193851.log`。

最终Network_test source `a5470ae3` / binary `1bef3876`，`m5out/hetsub_network/p8_final_20261015/`全部21项通过：有限包排空、消息/字节/flit守恒、L/M并行和阻塞隔离、PG、16↔8/7转换、静态relay/backpressure、pilot与非法配置拒绝均有证据。

正式应用退出仍有8–47个在途消息，延迟人口为退出前已接收原始消息，不声称应用全网排空。四维结果和逐项机制状态见`docs/COMPARISON_10C_RESULTS.md`。当前平台下HetSub dual/static均为负收益；没有调参或选择性隐藏。活动量与PG状态只作为代理，不报告实际J/W或节能百分比。

最终成果父仓提交`3332114f`已推送至`synthetic-traffic-three-patterns`，五个嵌套仓远端提交与父仓gitlink逐项一致。会话导出文件不属于项目交付物，按聊天日志规则保留在本地并忽略，不纳入成果提交。

### 10-cluster正式比较执行阶段记录（已由上方完成状态取代）

用户已批准三仓正式比较专用10 clusters×1、16CPU/4dir/40GPU L2/64tile配置，配置决策阻塞解除。保持旧默认与历史数据，新批次采用独立输出目录和显式参数；规格见TASK及docs/COMPARISON_10C.md。正在执行当前提交的官方干净重建、基线统计口径审查与实际平台核对。新比较尚未通过验收，不把下列旧p6机制数据升级为正式三仓结果。

### 阶段性 GitHub 备份

用户现已明确：阶段性成果检查或配置确认之前，必须先推送 GitHub。本次备份覆盖 HetSub 核心源码、Docker/构建门禁、测试入口、复现方案、执行/审查/资源报告，并在AGENTS/CLAUDE中固化该要求。备份保留“GPU口径待确认、三仓正式比较未完成”的状态，不表示最终验收通过。原始大体积build_logs/m5out和本机构建凭据按现有规则继续忽略。

当前凭据指纹包含HEAD和未提交改动的表示；提交源码会改变指纹，后续仿真须重新通过官方干净构建，不能手动重录凭据来绕过门禁。已有验证证据对应REPORT所列p6构建及其原始运行。

**以下为阶段性备份时的历史状态。** 当时GPU配置尚未裁决，因此没有发起正式比较；该阻塞现已由用户批准10-cluster正式配置解除。已有数据继续保留为旧16/10机制证据。

### 资源与PG补充审查（源码仍为p6）

- `tools/hetsub/audit_resources.py`核对18个合成HetSub案例和8个应用案例，共26个运行，router/NI/relay/staging数据位、PG逐router周期分解与6/10事件计数全部一致。完整资源表及排除项见[RESOURCE_AUDIT.md](RESOURCE_AUDIT.md)。本轮没有改动三个指纹源码仓，无需重建。
- 原文IV-A重新核对6-cycle WU、10-cycle break-even静态功耗等价事件成本。澄清历史方案能量式：按WU事件总成本记账时，不再重复叠加6-cycle waking能量。现有源码仅记录事件/状态，没有输出未经校准的焦耳或节能率，未改动已验证数据路径。
- 128/56匹配内部总链路位宽，但72个应用端点双向接入线路安装位宽3312 byte，高于单网2304 byte；128/64为3456 byte。NI服务仍为每端点每方向最多16 byte/cycle。资源公平性必须保留此差异。
- 当前应用数据队列合计：dual8 415584 bytes、dual7 385776 bytes、4-shortcut static8 422144 bytes、static7 392172 bytes。传播pipeline、控制元数据与mux/crossbar未做RTL面积映射，不能将这些合计称为完整硬件面积。
- pilot实测Hilbert距离≤2的有效字节占比：backprop 5.6787%，kmeans 5.2734%；不是原文聚类系数。多数global通信与SNN局部性不同，支持保留本平台负收益作为迁移结论。
- GPU口径仍待先前异步问题的答复；未擅自切换10 clusters，未启动三仓正式比较。任务目标保持完整。


### p6 最新状态：核心机制与应用数值已验证，三仓正式比较未完成

- Network_test官方干净构建：`build_logs/hetsub_network_p6_packet_metrics.log`，成功并通过现有凭据验证。`m5out/hetsub_network/20261015T080744Z/`的21项检查全部PASS（exit 0）。
- 新增原始packet最终tail交付一次的service/source-queue/completion/max-completion统计；relay保留原始birth与delay。检查`completion_cycles = service_cycles + queue_cycles`及平均值分母为收到的原始消息，off/dual/static一致。历史flit平均延迟与PerformanceAnalyzer打印不用于比较。
- 独立性4096包压力：10557个同tile双子网并行周期；2559次L传输发生在同tile M WAKING期间；10990次M传输发生在对应vnet的L转发队列满时，结束全部排空。
- 配置通道依赖检查：dual枚举8192路由，350资源/512依赖；4-shortcut static枚举4096路由，142资源/144依赖，均无环。检查实际L/M边与冻结路径；范围限每vnet隔离的NoC通道/relay，排除Ruby协议层依赖和硬件时序。
- VI_hammer_GPU官方干净构建已成功并记录/验证凭据：`build_logs/hetsub_app_p6_off.log`。官方一键命令测试阶段因Ubuntu14旧Bash空数组在模拟前中止（exit 1）；父仓run.sh兼容修复后，用同一已验证二进制经run.sh重新运行both，exit 0。未手动修改凭据，也未把首次完整脚本记为成功。
- 应用启动显式保留16CPU、4dir、40L2、64tile、CPU2GHz/Ruby2GHz、D4/2stage；输出位于仓库独立目录。kmeans加`-o -r`输出数值，数据与二进制不变。后续比较全部方法必须使用相同参数与输出选项。

#### p6 应用机制读数（保留现有GPU配置；不是三仓正式比较）

以下10次实际运行均正常退出并通过独立CPU数值检查。off smoke使用seed1234，HetSub正式机制验证用seed42，pilot用17；这些读数不拼成正式性能优劣结论。

| 模式目录（均在m5out/hetsub_apps） | backprop service/completion cycles | kmeans service/completion cycles |
|---|---:|---:|
| `20261015T085207Z` off | 34.705593 / 80.881561 | 33.932605 / 76.432308 |
| `p6_dual8` | 115.875718 / 217.870435 | 111.870959 / 194.807023 |
| `p6_dual7` | 115.537826 / 217.289525 | 112.090740 / 195.155800 |
| `p6_static8` | 155.027047 / 297.628905 | 148.763023 / 258.317097 |
| `p6_static7` | 171.184816 / 336.421066 | 168.237582 / 290.561043 |

- 数值参考：`tools/hetsub/reference_backprop.c`链接现有标量backprop.c，在同Docker中编译运行；参考输出`m5out/hetsub_apps/reference/backprop_cpu.txt`。验证16个partial sums、289个权重、有效输入，容差2e-5。原CUDA host未初始化的bias槽0不当成有效输入；所有实际输入仍参与partial-sum/权重检查。
- kmeans独立float32 CPU参考：现有文本reader把首列当ID，因此实际输入为99点×1特征；4轮收敛，五中心47.88261/65.68333/26.79546/7.28823/83.06844。显示坐标容差0.0051。原cluster.c将RMSE暂存int，打印4.000而独立浮点值约4.622897；保留并披露此旧行为，正确性以中心为主。
- 应用pilot目录`p6_dual8_pilot/backprop`与`p6_kmeans_pilot/kmeans`均数值通过，seed17实际流量各生成4条冻结路径（阈值128 bytes、limit4）；配置位于`m5out/hetsub_app_configs/{backprop,kmeans}_p6.json`，static seed42实际读取。两种宽度的static均有M普通RC/buffer零活动及实际旁路beats证据。
- 五种模式的实际72个外部端点映射、106个RubyCache几何及源时钟逐项相同。实际控制器为17 L1Cache、10 GPUL1Cache、40 GPUL2Cache、4 Directory、1 GPUCopyDMA，不能把命令行40L2误写成40个GPU核。
- 进程退出时尚有16–34个在途消息（不是本测试已证明的丢包），HetSub busy资源40–70；平均延迟只统计退出前已收到的原始消息，不宣称应用结束网络排空。合成有限包的完整排空已另行通过。

#### 正式比较前发现的真实平台差异（待用户选择口径）

1. 本仓和TBP的GPUConfig.py在解析16 clusters后硬编码`options.num_sc=10`：config.ini实际10个CudaCore，但gpgpusim.config为16×1。bak无该硬编码，默认又已调整为ALPHA的40 clusters/8dir/8L2。这不是同一系统平台，当前数值只能作本仓已有平台上的机制验证。
2. 已通过异步问题请求选择：推荐三仓显式10 clusters、保留现有10个GPU NoC端点，或保留16/10旧状态但不宣称三仓平台一致。AGENTS要求CPU/GPU固定，未在用户答复前修改GPU配置或外仓。
3. bak使用random_seed布置GPU，本仓/TBP使用topology_seed；后续可采用共同sim seed0/topology seed0，并核对实际映射。CPU/cache/dir/cluster参数必须显式覆盖默认，不能只核对参数名。
4. cmp实测三仓两应用二进制相同；HetSub/TBP的kmeans_input相同，bak输入不同或缺失。正式比较应显式读取同一当前输入；现有证据不是三仓比较结果。


前批次p5官方干净构建`build_logs/hetsub_network_p5_pilot_pressure.log`成功并通过凭据验证。原始输出`m5out/hetsub_network/20261015T072805Z/`涵盖20个案例。初次整套返回1：Transpose未使用全部固定shortcut，但测试断言要求每条都使用；源码仿真没有失败。修正该模式的覆盖断言后，20个保留案例重新检查全部通过（exit 0），Transpose实际单独重跑`m5out/hetsub_network/20261015T073440Z/`也PASS（exit 0）。不把初次exit 1记作整套运行exit 0。

### p5新增证据

- Bit Reverse的L与56-bit M各交付1024包并排空；Transpose的双shortcut配置交付1024包，其中一条实际承载176帧，另一条未命中，保留该适用范围。
- Transpose记录492个下游阻塞周期、8次local MUX延后、3424物理段beats；原始包/有效字节/包含relay转换的所有flit守恒，VC及queue排空。uniform static7记录90个下游阻塞周期。
- pilot使用seed17、1024包，实际接受源消息的tile流量矩阵导出913对，CSV有效字节总数与注入统计一致。现有Stats reset语义适用；无需逐包哈希或注册表。
- `insert_shortcuts.py --profile <pilot>/profile.csv --output <pilot>/shortcuts.json --threshold-bytes=128 --limit=4`选出4条非冲突配置；配置中物理路径与运行时`het_shortcut_paths`已逐项核对相同。
- static_pilot使用seed42及56-bit M，读取上述冻结JSON而不生成/读取测试未来profile；交付1024包，8个relay，4876物理段beats，737下游阻塞周期、9次MUX延后，并全部排空。
- Algorithm 2四项测试再次PASS。原有XY/L/M/选择/PG/1/2GHz检查亦在p5本次输出中重新通过。PG-M本次212次唤醒/1272个waking cycles。
- 尚不能用这些合成有限包结果宣称CPU/GPU应用正确、形式化无死锁或2GHz硬件时序实现。原flit平均延迟因relay分段计数变化不能用作packet延迟；下一阶段添加原始消息完成延迟后再比较。

### p4静态旁路实际证据

- static8：21帧、744 bytes经过单条shortcut，宽→窄57→93 flits，反向转换93→57，372物理段beats；relay存储984 bytes。
- static7：相同21帧/744 bytes，57→123→57 flits，492物理段beats；relay存储943 bytes。FIFO高水位4，未超过容量。
- static_two：两条shortcut分别21/22帧，748物理段beats，relay存储1968 bytes。
- static_abstract：一周期composite传播敏感性配置通过，未宣称硬件时序闭合。
- 所有静态案例交付256原始包、有效字节及全路径flit守恒；M普通route request及buffer write均0；所有Router/NI/relay/link上下文与队列在结束时排空。
- reject_conflict、reject_nonadjacent均在配置阶段按预期拒绝。静态模式无普通M注入；local MUX与有限staging已在源码生效，p5已补充其单独活动计数并有正值证据。
- composite引用并独占原M源本地段、1/2个内部物理段和目标本地段；保守配置传播周期为这些段数，抽象配置为1。虚拟L本地接入与原NI本地链接共享传输机会。VC握手沿用本模拟器事件语义，未复现RTL控制延迟。


任务未完成。以下保留p3九项原始证据；最新版本为p5，覆盖范围与验收结果见上文。专用容器`gem5gpu-dev-hetsub`使用`myubuntu14:latest`，显式绑定当前仓库同名路径。

## 最新实际证据及边界

| 案例 | 交付packet | L/M注入packet | 实际flit | 结果 |
|---|---:|---:|---:|---|
| off | 256 | 不适用 | 原XY路径 | PASS，2VC、D4、2stage |
| line | 256 | 256/0 | 624 | PASS |
| mesh8 | 256 | 0/256 | 992 | PASS |
| mesh7 | 256 | 0/256 | 1340 | PASS |
| policy | 256 | 256/0 | 624 | PASS，低负载优先L |
| policy_load | 1024 | 978/46 | 2452 | PASS，实际拥塞分流 |
| pg_line | 256 | 256/0 | 624 | PASS，M sleep764800 cycles，0 wakeup |
| pg_mesh | 256 | 0/256 | 992 | PASS，M sleep725464 cycles，213 wakeup、1278 waking cycles |
| line_1ghz | 256 | 256/0 | 624 | PASS，时钟对照 |

每项检查正常退出、包/有效字节/flit守恒，dual模式接收器逐帧检查目的NI、消息身份、索引顺序和有效字节覆盖。PG检查每次唤醒6 cycles、每次转换能量10个active-static-cycle equivalents。它们是有限包机制证据，不证明所有流量无死锁，也不替代应用正确性或relay验收。

- 时间：全局tick=1ps，主项2GHz/12000 cycles对应6000000 ticks；1GHz对照对应12000000 ticks。NetworkTest退出条件已从curTick改为curCycle。
- 拥塞反馈：75%/50%滞回、128-cycle采样保持不变；每端点每vnet测最忙transit输出端口占用，避免空闲vnet和反向端口稀释。该反馈范围属于输出buffer平台适配，不宣称原文逐位一致。
- 资源：128/64内部容量3808 byte/cycle，router buffer387840 bytes，NI VC buffer163840 bytes；128/56分别3584、359680、153600。buffer数字仅覆盖显式VC存储；链路及NI staging、未来relay须另列，不能当成完整面积/总存储证明。
- 生产策略Docker测试既有PASS：4096对L路径、262144个shortcut谓词、7/8/16-byte守恒、滞回及重试。
- Algorithm 2离线四项测试既有PASS：中心候选、阈值、端口/有向边冲突及路径约束。尚未接入旁路数据路径。

## 逐项机制完成度

| 核心机制 | 当前状态 | 验收边界 |
|---|---|---|
| 独立常开L与M、真实16/8/7-byte flit | 已实现，有限包检查通过 | 独立并发/阻塞隔离的定向压力证据待补 |
| 拥塞动态子网选择 | 平台适配实现，真实分流检查通过 | 更多模式/压力及ordered应用待验收 |
| M PG三态与唤醒代价 | 已实现，有限包检查通过 | 应用与边界压力待验收 |
| Algorithm 1单调条件 | 已接入真实shortcut选择，p4有限包通过 | 通道依赖及更多压力待验收 |
| 静态long-link / crossbar bypass | 已实现，p4/p5三种流量及背压检查通过 | 应用与建模边界待验收 |
| 有界relay及连续字节流宽度转换 | 已实现，16↔8/7及p5背压/排空检查通过 | 应用待验收 |
| Algorithm 2分层插入 | 离线脚本、实际独立pilot与配置集成已通过p5合成检查 | CPU/GPU应用pilot待验收 |
| 固定平台应用及bak/TBP比较 | 未完成 | 不能引用合成PASS作为应用结果 |

## 构建与失败记录

`hetsub_network_p1.log`、`hetsub_network_p1_retry.log`保存旧版Params及指针比较编译失败；后续已修复。`hetsub_network_p1_retry2.log`构建成功后，容器因Git对象ID缩写差异拒绝凭据。verifier改用完整对象ID及固定diff heuristic，两端指纹已实测相同，没有手动改凭据。

`hetsub_network_p1_canonical.log`构建成功，首次启动被旧统一位宽限制拒绝，后以默认关闭的异构链接参数支持真实多位宽。`hetsub_network_p2.log`构建成功，启动暴露统计对象未注册；`hetsub_network_p2_stats.log`修复注册后成功运行上述六例，暴露资源reset问题。资源reset修复已通过实际检查，时间单位与拥塞反馈修复也已通过上述九项检查。

## 尚未完成

用户确认GPU口径后的三仓实际平台/输入/种子和测量对齐、必要重新运行、能量/存储/时序近似最终披露及逐机制审查。已有应用正确性仅覆盖当前小输入和旧16/10模型，不能代替一致平台验收。不能用当前helper或有限包测试宣称完整复现，也不以原文性能收益为通过条件。

## GOAL-HS-N1 执行结果（P1 最小闭环，2026-10-15）

按用户阶段表 N1-0…N1-4 执行；未重跑正式三仓应用矩阵，未为改变 HetSub 负收益调整参数。flexible-pipeline 源码无改动，`X86_Network_test` 现有构建凭据继续有效，每次运行前 verify 门禁照常执行。

### N1-1 `wire MB` 语义（重分析，未重跑仿真）

- 分类规则：`ext_links`、`int_links`、`het_line_links` 为物理链路；`het_relay_links` 为虚拟 relay 接入通道。
- 重分析输出（`ok: true`）：`m5out/comparison_10c/formal_10c_v2_20261015/reanalysis_wire_classification_backprop.json` 与 `…_kmeans.json`。
- `docs/COMPARISON_10C_RESULTS.md` 改为物理/虚拟活动分列，Jain 仅按物理链路计算；仅静态行的 Jain 相对旧口径变化，实验结论不变。

### N1-2 Algorithm 2 level-2 插入（离线选择 + 实际承载）

- 单元测试 `tools/hetsub/test_insertion.py::test_level2_only_selection`：profile 仅 `{(10,17): 1152}`，threshold=128、limit=4 → 唯一选中 level-2 对 (10,17)，路径 `[10,9,17]`；全部 level-1 行 `below_threshold`。5 个测试全部通过。
- 冻结配置由离线工具从该 profile 生成：`tools/hetsub/fixtures/profile_level2.csv` → `tools/hetsub/fixtures/static_level2.json`（审计 `static_level2.csv`：仅 `2,10,17,1152,selected`）。
- 定向运行 `static_level2`（转置 pattern，tester 10 全部 16 包目的为 17；16×72 B = 1152 B）：`m5out/hetsub_network/20261015T152707Z/static_level2`。
  - 实际承载：relay `completed_frames = 48`（22 data + 26 control），`input_bytes = output_bytes = 1792`，`fifo_highwater = 4`（≤4），input/output flits 136/294 与消息尺寸一致；物理段 beats 1176 > 0。
  - 守恒与排空：packets 1024 注入=接收，bytes 28608 守恒，flits 2730 注入=接收，`het_busy_resources = 0`；static 下 M 路由器零 route request / buffer write。
  - 背压实际发生：downstream stall 202 cycles、MUX deferrals 19。
  - 判定口径说明：48 帧 > tester 10 的 16 定向包，因为其他 tester 经 router 10 向 tile 17 的包同样满足 Algorithm 1 单调条件并共享该 relay。验收按 TASK.md 为 `completed_frames > 0` + 冻结路径 `[10,9,17]`，不要求恰好 16。首次运行按恰好 16 断言失败（`m5out/hetsub_network/20261015T151741Z` 保留为证据），断言改为 `>= 16` 后通过。

### N1-3 完整有限包套件

- 一次完整运行 22 项（21 项既有 + 新用例 `static_level2`）全部 PASS，exit 0，无 FAIL：输出目录 `m5out/hetsub_network/20261015T152707Z`。
- 既有 PG、背压、旁路、pilot、非法配置拒绝用例无新增未解释缺陷；关键证据：independence 10557 并行 tile cycles / 2559 L-during-M-wake / 10990 M-during-L-full；static_transpose 492 stall + 8 deferrals；static_pilot 737 stall + 9 deferrals；reject_conflict 与 reject_nonadjacent 均被拒绝。

### N1-4 关闭状态

- 证据（重分析 JSON、单元测试、定向用例运行输出与 validate 结果）已写入本节；本提交包含 `tools/hetsub` 改动与 fixtures。推送并核对远端后，最终 Code Review 由用户执行；`.ai/reviews/REVIEW.md` 未修改。
- 终审结果：GOAL-HS-N1 APPROVE（`.ai/reviews/REVIEW.md`，提交 `2707194e`）；HetSub 方法复现正式冻结，除非发现具体机制反例不再重复验证。

---

# Historical Report: Must-Fix Follow-Up for Synthetic Traffic Workflow

## Summary

The two must-fix workflow issues are resolved in code and the host-visible artifacts are now internally consistent:

1. Host raw `stats.txt` files now match the `results.csv` produced from the same run.
2. The workflow no longer depends on plotting inside Docker; simulation runs in Docker, while parse/plot run on the host.

## Files Changed

| File | Change |
|------|--------|
| `scripts/parse_synth_stats.py` | Added `uniform_random -> 0` mapping and a `KNOWN_PATTERNS` whitelist to ignore stale directories |
| `scripts/sweep_synth_traffic.sh` | Added `--skip-post` mode so Docker can run simulation-only without parse/plot |
| `scripts/run_synth_sweep.sh` | New host-side wrapper: clean host output, sync latest sweep script into Docker, run simulation in Docker, copy raw results back, then parse/plot on host |

## Final Authoritative Command Path

Run from the host at repo root:

```bash
./scripts/run_synth_sweep.sh
```

Intended behavior:
1. Clean host `m5out/synth/`
2. Copy the latest `scripts/sweep_synth_traffic.sh` into Docker
3. Run the 21-case sweep inside Docker with `--skip-post`
4. Copy `m5out/synth/` back from Docker to the host
5. Parse on the host
6. Plot on the host

## Verification Performed

### 1. Full single-command rerun

The final authoritative wrapper was rerun end-to-end from the host:

```bash
./scripts/run_synth_sweep.sh
```

Observed behavior:
- cleaned host `m5out/synth/`
- copied the latest `scripts/sweep_synth_traffic.sh` into Docker
- completed all 21 simulations inside `gem5gpu-dev` with `--skip-post`
- copied the raw `m5out/synth/` tree back to the host
- parsed `stats.txt` into `results.csv` on the host
- generated both plots on the host

Result:
- `m5out/synth/results.csv` written with 21 rows
- `m5out/synth/latency_vs_load.png` generated
- `m5out/synth/throughput_vs_load.png` generated

### 2. CSV shape

Verified on the host:

- row count: `21`
- patterns: `bit_reverse`, `transpose`, `uniform_random`
- synthetic IDs: `0`, `1`, `2`
- injection rates: `0.01`, `0.02`, `0.05`, `0.08`, `0.10`, `0.12`, `0.15`

### 3. Raw stats vs CSV consistency

Host `stats.txt` samples now match the CSV for all three patterns. Example at injection rate `0.10`:

| Pattern | sim_ticks | network_latency | throughput_packets_per_cycle_per_node |
|---------|-----------|-----------------|----------------------------------------|
| `uniform_random` | `100000` | `38.181620` | `0.09987344` |
| `bit_reverse` | `100000` | `169.191566` | `0.08903172` |
| `transpose` | `100000` | `123.429976` | `0.09233638` |

The sampled host `stats.txt` values and the corresponding CSV rows match exactly.

## Outputs Produced

| Artifact | Path |
|----------|------|
| Raw stats tree | `m5out/synth/<pattern>/inj_<rate>/stats.txt` |
| CSV | `m5out/synth/results.csv` |
| Latency plot | `m5out/synth/latency_vs_load.png` |
| Throughput plot | `m5out/synth/throughput_vs_load.png` |

## Remaining Risks

1. Sweep duration is lower than the previous 45-case sweep, but still non-trivial for `21` runs at `100000` sim-cycles.

2. `run_synth_sweep.sh` requires a running `gem5gpu-dev` container and `sudo docker` access.

3. `scripts/run_synth_sweep.sh` currently hardcodes `--sim-cycles 100000 --random_seed 42`. That is fine for the current baseline workflow, but a future convenience improvement would be to accept pass-through CLI arguments for cheaper smoke runs.

## GOAL-HS-R2 执行记录（2026-10-16）

范围：仅文档与证据闭环，无源码修改、无仿真重跑。交付物为 `docs/HETSUB_R2_CLAIM_EVIDENCE_AND_LIMITATIONS_20261016.md`（R2-0…R2-5）。

### 执行前门禁（审查第 8.1 节，只读）
- `verify_gem5_build.sh verify`：`X86_Network_test`（binary `1bef3876…`）与 `X86_VI_hammer_GPU`（binary `9f5ed9cb…`）均 VERIFIED，source `a5470ae3…`。
- `test_insertion.py`：5 项测试全部通过。

### R2-2 新增离线计算（基于已有数据，未重跑）
- 工具 `hilbert_order()` 与 simulator `HetSubPolicy.hh::Geometry` 经测试确认一致后，对 pilot profile 计算流量加权路径长度：backprop XY 5.86 vs Hilbert 26.14 hop；kmeans XY 5.87 vs Hilbert 26.52 hop；未加权全对 5.25 vs 21.33。
- M 路由器 PG 分解（dual 模式）：backprop dual8 sleep 205,578,119（99.93%）、M active 126,679、waking 8,418=1403×6、WU 14,030；kmeans dual8 sleep 93,993,650（99.89%）、M active 99,654、waking 7,560=1260×6、WU 12,600。恒等式（每 M router 状态周期=窗口）成立。
- 静态模式实际承载：8 个 relay 接入侧，backprop static8 每侧 384,216 bytes（81,366 帧，含控制帧）、segment beats 192,108、blocked 14,232、downstream_stall 2,594；kmeans static8 每侧 417,256 bytes（88,378 帧）、beats 208,628、blocked 16,554、stall 3,838。pilot 选中字节占比 24.86%/24.66%，正式运行每侧实际转换占比 38.2%/38.9%（seed 17 vs 0 差异已披露）。

### 状态
R2 全部条目完成；方法保持冻结。最终 Code Review 由用户执行，`.ai/reviews/REVIEW.md` 未修改。

## GOAL-HS-R2 终审后文档修正（2026-10-16）

依据独立终审（父仓 `8cfa9e23`，R2-F01…R2-F05）仅修正 `docs/HETSUB_R2_CLAIM_EVIDENCE_AND_LIMITATIONS_20261016.md` 的因果措辞与统计分母；无源码修改、无仿真重跑、实际结果数值全部保留。

- **R2-F01**：R2-2(2) 不再把 3.56× link flits 归因于窄通道序列化。核对 audit JSON：平均每个登记 link flit 的字节数 off 16.00 B vs dual8 15.95 B（backprop；kmeans 16.00/15.97），dual 常开 L 仍为 16 B flit，与 off/XY 同宽；活动量增长改述为跳数/长路径活动主导。窄通道转换成本仅以同模式窄变体自身计数举证（dual7> dual8、static7> static8 flits）。
- **R2-F02**：R2-2(3) 由"PG 前提不成立"改为"M 使用稀少、对当前时延贡献有限；PG 净能量效应未知（无功耗模型及对照）"；高 sleep 比例同时意味着潜在漏电节省窗口。局部性假设不匹配单独归因于 pilot ≤2 字节比例。
- **R2-F03**：两个占比分别命名并给出公式。`pilot eligible-region flow fraction` 24.86%/24.66%（249,744/1,004,752、264,608/1,072,856，象限区域对聚合字节，已从 profile.csv 复算一致）。`formal relay-converted bytes / formal injected bytes` 修正分母为**同一 static8 运行**的 `bytes_injected`：384,216/1,004,808=38.24%（backprop）、417,256/1,072,784=38.89%（kmeans）；此前误引其他运行/跨 seed 分母。分子含控制帧与允许的 transit 转换，注明为 bypass 份额上界代理。R2-3 seed 条目同步修订，不再作同定义命中率解读。
- **R2-F04**：R2-2(5) 收窄为"128/56 仅在 static 模式更慢"；补充 dual7 vs dual8 基本持平且符号混合（backprop dual7 −36,000 ticks、服务 116.03 vs 116.21 cycles；kmeans dual7 +196,000 ticks）。
- **R2-F05**：R2-2(1) 的 XY/Hilbert 距离改称"潜在几何 hop 距离、与趋势一致的机制假设"，删除"主因"表述；R2-4 补充可复核公式（加权均值 `Σ bytes·d / Σ bytes`、XY Manhattan、Hilbert rank 差、profile 路径、两个占比的分子/分母定义）。

修正后 R2 claim 门按终审要求完成文字一致性检查；`.ai/reviews/REVIEW.md` 仍未修改。

## GOAL-HS-R2 claim 门封口（2026-10-16）

用户独立复核（父仓 `3e126518`，仅改 `.ai/reviews/REVIEW.md`，五个 gitlink 不变）确认五项发现全部落实、无新阻断问题：R2-2 由 `NEED FIX` 改判 `PASS`（限定于已冻结证据支持的科学主张），R2 claim 门正式关闭。最终裁决维持 `CONDITIONAL APPROVE / FREEZE`。

- 五项发现复核结果：F01 PASS（链路累计活动与宽度转换明确区分）、F02 PASS（保留状态证据、不推断净节能）、F03 PASS（两指标独立命名、正式分母来自同一 static8 运行）、F04 PASS（仅 static7 更慢，dual7 差异小且方向不一致）、F05 PASS（机制假设 + 复核公式）。
- 后续科研处置：维持核心源码与 `formal_10c_v2_20261015` 数据冻结；不增加实验、不修改算法、不因负收益调参、不重跑 22-case/16 应用。现有成果进入论文写作与方法比较阶段，须保留已确认的平台、时序、资源和因果解释边界；超出本闭环的更强因果/能耗/面积主张须另行评估证据。
- 本记录为执行侧封口登记；`.ai/reviews/REVIEW.md` 未修改。

## GOAL-HS-R3 源码深审与最终裁定（2026-10-16）

交付物：`docs/HETSUB_R3_DEEP_SOURCE_REVIEW_AND_ADJUDICATION_20261016.md`。只读审查：无源码修改、无新仿真、无 22-case/16 应用重跑；不继承既有审查文档的 PASS 结论。

- 论文全文独立读取（TVLSI 33(11) 3131–3144, 2025, DOI 10.1109/TVLSI.2025.3597406，14 页 pdftotext 提取）。关键原文：p. 3143 Section V "This process is currently static… In future work, we plan to enable long-range links dynamically"；p. 3136 III-B-1 "preloaded… in the form of special packets"；p. 3135 III-A-2 拥塞定义（全端口总占用、置位/复位阈值、状态保持、双向比例、无采样周期）；p. 3136-3137 Algorithm 1（shortcut 终点须在路径上）；p. 3138 Algorithm 2（分层、排除相邻、阈值、严格层级优先、无 2×2、≤2 hop、crossbar≤5、每节点≤2 入/出）；p. 3139 IV-A（WU 6、break-even 10）。
- 实际数据路径逐行核对：`HetSubPolicy.hh`（几何/滞回/比例/preview）、`HetSubRelay.cc`（request/grant/release、守恒 fatal_if、背压）、`GarnetNetwork.cc`（hetChoose 325-343、initHetLinks 221-257、initHetShortcuts 260-311）、`NetworkLink.cc`（共享 MUX 128-174、bypass 独占 176-188）、`Router.cc`（getRoute HetSub 路径 1320-1345、hetCongestion 2375-2389、PG 2392-2464）、`NetworkInterface.cc`（flitisizeHetMessage 301-346、接收 MUX 412-425、delivery 423-464）、`HetSub.py`（冻结 JSON 79-113）。
- 只读门禁本轮执行：verify 门禁两目标均 BUILD-PROVENANCE VERIFIED（source `a5470ae3…`，binary `1bef3876…`/`9f5ed9cb…`）；`test_insertion.py` 5 项 OK；`check_dependencies.py`（static_level2 config.ini）4096 路径、acyclic；`validate_network.py` 抽读 independence/static_level2/policy/pg_mesh/static8/line/mesh8 全部 PASS。
- 重裁结果：HS-CR-01 由 P1-QUESTION 降为 P2（论文演示即静态，动态为论文明确 future work）；HS-CR-02/03/04/05/06 维持 P2。新增观察均为 P2（每节点 long-link 上限 1 比原文 ≤2 更严；拥塞范围为每 vnet 最忙 transit 端口；PG 为周期记账代理）。无新的已确认 P0/P1。
- 三个研究问题裁定：Q1 不要求运行时连接变化、冻结 JSON 非方法缺陷（P2）；Q2 有序 vnet 固定 M 满足 Ruby 按序交付前提、方向偏离原文优先级（P2）；Q3 事件驱动采样不违反论文（论文无采样周期），范围与 128-cycle 门为已披露近似（P2）。
- 最终决定：**STOP / FREEZE**，维持 CONDITIONAL APPROVE / FREEZE；下一阶段唯一目标为论文方法描述与公平性边界核对，不新增实验。`.ai/reviews/REVIEW.md` 未修改。

## GOAL-HS-R3 封口与文档精度修正（2026-10-16）

用户独立终审（父仓 `866c19c6`，仅改 `.ai/reviews/REVIEW.md`，五个 gitlink 不变）接受 R3 裁定：STOP/FREEZE、三问 P2 非阻断、维持 CONDITIONAL APPROVE / FREEZE、R3 任务 CLOSED。终审记录两项文档精度问题（明确不是新的阻断性整改门或批准前置），本轮在执行侧报告顺手修正：

- **R3-DOC-01**：第 2 节观察 1、第 3 节矩阵行 7/10 与第 5 节偏差条目改为"冲突按 (tile, 端口/方向) 与有向物理边去重"，删除"每节点上限 1"表述；同一 tile 可在不冲突端口参与其他 shortcut，实现不限制每节点总数（`insert_shortcuts.py:76-82`、`HetSub.py:92-103`）。上文 R3 条目中的旧措辞以修正后文本为准。
- **R3-DOC-02**：第 7 节示例命令统一从仓库根目录执行（`python3 tools/hetsub/...`），消除 `cd tools/hetsub` 与仓库根相对路径混用；无重跑。

证据边界（终审自述）：终审核对了已提交报告与对应源码，未独立重开论文 PDF、未本地运行构建/测试；对论文措辞与七项只读门禁的接受依赖 R3 执行侧证据。

下一阶段唯一目标：论文方法描述（机制—代码—证据矩阵）与公平性边界核对（R2-3 清单），不新增仿真、算法或测试扩展；仅在出现具体关键机制反例或用户明确扩张研究范围时重新打开核心实现。`.ai/reviews/REVIEW.md` 未修改。

## GOAL-HS-R4：方法描述、公平性审查与文档交付（2026-10-16）

交付物：`docs/HETSUB_R4_METHOD_DESCRIPTION.md`、`docs/HETSUB_R4_FAIRNESS_AND_CLAIMS.md`、`docs/HETSUB_R4_CLAIM_EVIDENCE_INDEX.md`。只读复核：无源码/配置/实验结果修改、无重跑、无新测试矩阵、无新增哈希系统。

- **前置上报（已解决）**：R4 目标文件 `docs/GOAL_HS_R4_METHOD_EVIDENCE_FAIRNESS_READONLY_20261016.md` 在本地执行开始时不存在（工作区、`.ai/` 与全部 git 提交含 `--all --diff-filter=A` 均无），按 CLAUDE.md 升级规则上报；随后经 `git fetch` 确认其存在于远端（提交 `60df5cb6`，父为 R3 封口 HEAD `a2459724`），本地非破坏性 rebase 纳入后，本次执行以该冻结目标文件为准。R4-0 基线门禁：五个 gitlink 与目标文件所列冻结 SHA 完全一致；flexible-pipeline/tools 最后源码提交 `50b52f0a`（N1）早于 R3 封口，无 R3 后核心修改；REVIEW.md 最新结论仍为 R3 APPROVE（研究范围限定）/ STOP / FREEZE。
- 只读门禁本轮复核：两个 verify 门禁均 BUILD-PROVENANCE VERIFIED（source `a5470ae3…`，binary `1bef3876…`/`9f5ed9cb…`）；`test_insertion.py` 5 项 OK；`check_dependencies.py` 4096/130/129 acyclic；`validate_network.py` 七 case PASS（independence 10,557/2,559/10,990；static_level2 1,176 beats/202 stalls/19 deferrals；pg_mesh 725,371/212/1,272；static8 372/6/0）。
- A-1…A-7 逐项映射至论文锚点、源码 `file:line` 与现有证据，标注证据类型（源码直接证明/历史运行/推断/未验证）；无新增已确认 P0/P1，R3 的 P2 观察全部维持且无具体可达反例，不升级为阻塞缺陷。
- 可复现重算核对：加权几何距离与 eligible-region 分式与 R2 记录精确一致（5.8588/26.1440、5.8741/26.5222；24.8563%/24.6639%）；relay ÷2 分式精确复现（384,216/417,256 → 38.24%/38.89%）。两项文档精度 P2：F-R4-01（R2-2(1) 的 ≤2 占比 5.68%/5.27% 精确复现于 p6 pilot profile 307/323 流，而 R2-4 所引正式批次 pilot profile 为 299/355 流，按该定义复算为 5.5082%/5.4196%）；F-R4-02（R2 未加权 5.25/21.33 对应含自对的 4096 分母，按 R2-4 声明的 64×63 分母为 5.3333/21.6667）。均不改变定性结论。
- 措辞澄清与 F-R4-03（用户独立源码核对触发）：本轮为文档一致性复核（GitHub 提交、R4 三份报告、历史审查记录）+ 既有源码锚点引用 + 离线脚本复跑，非新一轮完整独立 Code Review；本轮未重读全部源码、未运行仿真。用户从 GitHub 独立读取冻结提交 `a90c04ca` 实际源码（`HetSub.py`、`HetSubPolicy.hh`、`Router.cc`、`HetSubRelay.cc`、`insert_shortcuts.py`），确认既有锚点；其中 `HetSub.py` 以 bytes 计宽（Line `channel_width=16`、Mesh `options.hetsub_mesh_bytes` 8/7、relay `input_bytes=16`/`output_bytes=width`），据此修正方法描述 §1 III-A 的"16-bit flit"为"16-byte flit（Line）/ Mesh 8 或 7 bytes"（F-R4-03，文档精度 P2，结论不变）。
- 负结果逐字保留（backprop +4.80%…+6.46%、kmeans +12.68%…+17.13%），未调参、未换负载、未改统计口径。GPU 16/10 不一致口径仍待用户确认。
- 与 20261017 独立审查（`docs/HETSUB_READONLY_REVIEW_20261017.md`，提交 `515fd49c`）的对接：F1 已独立复算确认——在内存调用现有 `insert(profile,128,limit)`（阈值与冲突规则不变，不写配置、不仿真），两 pilot 均 limit=4 → 4 条 level-1（即冻结配置）、limit=100 → 4+9=13；复算逐行精确复现冻结 `configs/{backprop,kmeans}.csv`（30 行）；11 条 `limit` 拒绝条目中 9 条解除预算后可选、2 条（`10→17`、`17→9`）转为冲突。现有 static 结果按"最多 4 条有向 shortcut 的 Algorithm 2 预算变体"命名。F4 解决 GPU 16/10 陈旧文字（实际均为 10 CudaCore、10 clusters×1 core，audit `ok:true`）。三份 R4 文档已按该审查更新（主张索引行 9、公平性第 1/2/5 节、方法描述 §1/A-3(b)/A-6/§3）。
- 命名同步（用户 20261017 审查后请求的最小文档修正）：`docs/COMPARISON_10C_RESULTS.md` 正式结果表 static 条目统一为 `HetSub static-4`（数值不变），新增 static-4 命名说明（全局 `--limit=4` 为实现预算、`Router.hh:682-683` 每源至多一个出向 shortcut），完成度行改为"已实现（预算变体 static-4）"；主张索引 §2.1 补充结构性约束与证据性质（4→13 为本地离线复算、`m5out` 未提交 GitHub、用户核实算法逻辑与文档一致性而非具体数字）。无数据、统计或性能结果改动，无重建/仿真。
- 裁定：**PASS（含 P2 精度注记）→ R4-DOC CLOSED / CORE FREEZE RETAINED**；论文复现完整性按 20261017 审查为 CONDITIONAL（static-4 命名条件），算法与实现正确性 PASS（限冻结配置及已验证范围），性能基准资格 CONDITIONAL（限定命名后 PASS）。`.ai/reviews/REVIEW.md` 未修改。

## GOAL-HS-R5：RTL 面积实验（E0–E2 功能门，2026-10-17）

范围：`rtl/` 下 Verilog 模型与定向测试；无 flexible-pipeline 源码改动，不触发仿真构建门禁。执行口径见 `refine-logs/EXPERIMENT_PLAN.md`，跟踪表见 `refine-logs/EXPERIMENT_TRACKER.md`。

### 功能门（6 项，全部 PASS，2026-10-17）

| 门 | 测试 | 结果 |
|---|---|---|
| 1 Baseline 数据路径 | `tb/tb_baseline.v` | PASS：injected=15 delivered=15 drained, credits restored |
| 2 拥塞选网+滞回 | `tb/tb_select_pg.v` | PASS：hysteresis, wake latency, in-flight safety, isolation |
| 3 relay 128↔64 | `tb/tb_relay.v` | PASS：4 words byte-exact, beats=7 (held 1), context drained |
| 4 bypass + Algorithm 1 | `tb/tb_bypass.v` | PASS：legality, exclusivity, block, hop budget |
| 5 PG 安全 | `tb/tb_select_pg.v` | PASS：off 前排空、wake 前隔离、在途不关断 |
| 6 守恒与排空 | 各 TB 终态断言 | PASS：注入=交付，credit/VC/relay 上下文排空 |

命令：`iverilog -o sim_<t> tb/tb_<t>.v src/*.v && vvp sim_<t>`（Icarus Verilog 11.0）。

### 本轮实现修正（保留失败证据）

- `hetsub_relay_tx`：原实现在呈现 beat 的同一 posedge 清除 pending，而消费端看到寄存器输出晚一拍，反压时丢 beat。改为 pending 保持到 `ready_in` 实际接受。
- `hetsub_relay_rx`：`ready_out` 由 `!acc_valid` 改为透传 `ready_in`（完成字的 beat 仍被接受），使 tx/rx 握手一致。
- `tb_relay`：事件在 posedge 按 DUT 实际使用的值采样，negedge 记分；此前 negedge 相位错开导致误判。
- `tb_bypass`/`tb_select_pg` 期望值按 NBA 语义与输出端口索引（`byp_valid`/`exclusive` 按输出索引，`block` 按输入索引）修正；DUT 行为本身未改。
- `vc_table`：释放回路原用打包向量的标量位 `vc_port[i]` 而非 3-bit 字段 `vc_port[i*3 +: 3]`，清错 `vc_busy` 位；已改为字段索引。
- `vc_buffer`：新增由 pre-edge 值计算的注册 `drained` 标志（消除与 vc_table 同沿读取 `single/accept` 的竞争），vc_table 改收 `clear_en=drained`。
- `sw_alloc`：sa_req 硬编码两个 VC 项，NVC=1 时 `p*NVC+1` 别名到下一端口条目（L router 输出 1 误请求 entry 0）；改为 `if (NVC == 1)` generate 分支。
- `tb_m_router`：block 阶段 flit 单次接受后清除 `valid_in[2]`（此前 accept 每周期重触发导致重复交付）；block 阶段计入守恒（injected=16）。
- 2026-10-17 重跑：六项功能门全部 PASS（`iverilog -o sim_<t> tb/tb_<t>.v src/*.v && vvp sim_<t>`）。调试用 `tb_dbg.v` 已删除。

### 未完成项

- ~~E1.2/E3.1 正式综合与 WNS~~：已完成（2026-10-18，见下节 Table 3）；WNS 两设计均 FAIL（-6.2300 / -3.1200），如实保留。
- ~~E3.2 面积归属审计、E4.1 Table 3~~：已完成（Other = 0.0000 两设计；Table 3 见下节）。
- 128/56 敏感性行：可选项，未执行（不阻塞主表）。
- 连线与 P&R 面积按计划排除；Nangate45 无 PG header/isolation 单元，对应项 N/A。

## Table 3（same-口径 re-estimated，2026-10-18）

面积单位 = 一个代表性 HetSub RTL tile macro（L router + M router + relay + bypass + select/PG）；单位 µm²；≥4 位小数。分母为同 flow 重新综合的 Baseline（非原表 0.2303 mm²）。本表是 same-flow standard-cell mapping area，不是 1 GHz 已收敛的实现面积（1.0 ns SDC 只用于随后的 OpenSTA 检查，不作为映射时序目标）。

> Same-flow standard-cell area estimates for representative RTL models, using Yosys and the Nangate45 typical library. The comparison excludes physical implementation and does not establish timing closure or full hardware equivalence to the gem5 HetSub model.

LIC 与 Batch Scheduling 非 HetSub 核心机制，保留为模板兼容占位（`–`）；若本表仅比较 Baseline 与 HetSub，可去掉这两列。

| Configuration | Flit Buffer/Logic | RC Unit | VA Unit | SA Unit | Crossbar | VC Table | Other | LIC | Batch Scheduling | HetSub modules | Total | Increase by % |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Baseline（re-synthesized） | 48351.3520 | 43.8900 | 3708.0400 | 702.7720 | 12320.0560 | 460.9780 | 0.0000 | – | – | – | 65587.0880 | – |
| HetSub tile | 39494.0840 | 68.6280 | 3857.7980 | 850.1360 | 10664.7380 | 572.9640 | 0.0000 | – | – | 4416.6640 | 59925.0120 | **-8.6329%** |

列增幅（对同 flow Baseline）：Flit Buffer -18.3186%、RC +56.3636%、VA +4.0387%、SA +20.9690%、Crossbar -13.4360%、VC Table +24.2931%。

HetSub modules 子列明细：`hetsub_select_pg` 117.0400 + `hetsub_bypass` 1064.2660 + `hetsub_relay_rx` 1657.4460 + `hetsub_relay_tx` 1577.9120 = 4416.6640。

### 一页口径说明

1. **单一口径**：Nangate45 typ（pinned SHA `2efd0b32…5895`，Yosys 用其派生副本 SHA `55b248d6…38d9`），单一时钟约束 1.0 ns（1 GHz），buffer 建模为 flops（无 memory blackbox），Baseline 与 HetSub 完全同一 flow（`proc; opt -noff; techmap; dfflibmap; abc`）。不与 ALPHA 原表（45 nm、Synopsys DC）数值混用；原环境不可恢复（E0.1），故为"同口径 re-estimated"。
2. **面积来源**：Yosys `stat -liberty` 单一层级 top（`baseline_router` / `hetsub_tile_top`）；分项取该 top 内层级面积，保留面积归属所需模块边界；不得把独立综合的子模块面积直接相加冒充 Total。`Other = Total − attributed`，两设计均为 0.0000——这只证明**已建模模块**的映射单元归属完整，不证明系统所需的全部硬件模块都已建模。
3. **归属边界**：Flit Buffer/Logic = vc_buffer；RC = rc_xy（Baseline）/ rc_mono + rc_xy（HetSub）；VA = vc_alloc + 其内 rr_arb 实例；SA = sw_alloc + 其内 rr_arb 实例；Crossbar、VC Table 按实例所在 router 归属；HetSub 专属机制（select_pg、bypass、relay_tx/rx）单列，不隐藏在 Other。Algorithm 2 为离线计算（无面积）；bypass 列计入 grant 逻辑与消耗计数 FF，但 `cfg_en/cfg_out/cfg_hop` 是 top 级输入，完整配置存储未在 top 内建模。
4. **时序门（FAIL，保留）**：OpenSTA `report_wns`：Baseline **-6.2300**、HetSub **-3.1200**（1 GHz）。两设计均无 latch、无未映射单元、无 blackbox；WNS 失败不为降低面积而调约束，也不用于比较两设计的时序优劣。WNS 在 `fix_ports.py` 修复端口名后的可链接子集上测得（abc 单元端口名仅唯一可恢复者被重命名；歧义实例 Baseline 2032 / HetSub 1613 被排除于 WNS 之外）——面积不受此影响（来自完整层级设计）。原始运行日志已提交：`rtl/syn/log_sta_baseline.txt`、`rtl/syn/log_sta_hetsub.txt`。
5. **时序单元占比**：Baseline 48.75%（31973.2000）、HetSub 49.36%（29579.2000）。
6. **负收益与边界**：HetSub tile 面积低于 Baseline 主要来自窄 flit（64-bit）buffer/crossbar 缩小；RC、VA、SA、VC Table 与专属机制均为净增加。此结果是同口径面积核算，不是原文 16% 面积节省的复现，也不构成性能优势主张。
7. **可选项**：128/56 敏感性行未执行（不阻塞主表）。

### 模型代表性边界（2026-10-18 独立审查确认，源码可核）

以下边界不改变任何面积数值，但限定其科研口径：本表是代表性 RTL 模型的映射面积，不是完整 HetSub 片上网络已实现硬件的节省率。

- **F1 — RC 非 Hilbert**：`hetsub_l_router.v` 为 3 端口（N、E、local），`rc_mono.v` 按 XY 坐标比较作单调转发、S/W 回退 local；gem5 的 `HetSubPolicy.hh::Geometry::next()` 沿 Hilbert 序列选下一跳，路径不总沿 N/E。故 RC Unit 列（68.6280 µm²）是面积估算用的简化路由逻辑，不是与 gem5 相同的 Hilbert RC 硬件面积。
- **F2 — top 是结构容器，非端到端通路**：`hetsub_tile_top.v` 中 `u_tx` 取 L router 输出端口 0 直连 `u_rx`；`u_byp` 独立读取 M 输入并输出旁路结果，两条逻辑未在 top 内形成"序列化→旁路→反序列化"完整通路；`u_pg` 的 `sel`/`m_enable` 仅为 top 输出，未反馈到 L/M 数据通路；拥塞量 `cong` 是外部输入，不从该 top 内 buffer 提取。六项功能门支持各独立模块的定向功能，不证明整个 top 与 gem5 HetSub 实现等价。
- **F3 — 每 tile 配置的代表性**：top 内每 tile 各含 1 TX + 1 RX + 1 bypass。当前正式 static-4 网络在 64 tile 中只部署 4 条有向 shortcut（共 8 个 relay 端点）；把本 tile 面积 ×64 相当于计入 128 个 relay 端点。因此 59925.0120 µm² 是该代表性 tile macro 的映射面积，不是已证明的 64-tile static-4 网络平均每 tile 面积。
- **两个结论须区分**：gem5 HetSub 路由算法的功能复现资格不因本面积模型的简化而失效；-8.6329% 只能作为代表性 RTL 模型的同流程面积估算结果。

命令与报告路径：`yosys syn/syn_baseline.ys` → `rtl/syn/log_baseline.txt`；`yosys syn/syn_hetsub.ys` → `rtl/syn/log_hetsub.txt`；`sta -no_splash -exit syn/sta_baseline.tcl` / `syn/sta_hetsub.tcl` → `rtl/syn/log_sta_baseline.txt` / `rtl/syn/log_sta_hetsub.txt`（2026-10-18 重跑复现 -6.23 / -3.12）。RTL commit `c8cc0806`。功能门（6 项）2026-10-18 重跑全部 PASS。本轮面积估算结果冻结：不因代表性边界而重构 RTL、优化时序或执行 128/56。

- 2026-10-18 最终复核（GOAL-HS-R4）：**PASS / STOP / FREEZE**。提交 `05e3529f` 的差分与远端文件内容核对通过（仅 2 文件、+3/-2 行，无功能代码改动，面积与 WNS 数值未变，子仓指针未变），两项 P2 已落实，维持 R4-DOC CLOSED / CORE FREEZE RETAINED。三类证据口径保持分离：gem5 功能复现（冻结功能与机制证据）、RTL 面积估算（代表性模型同流程映射 -8.6329%）、RTL 时序（无完整设计收敛证明）。非阻塞遗留：`rtl/src/hetsub_tile_top.v` 端口声明前仍保留 `// Static config registers (Algorithm 2 storage)`（旧描述），不另开修复轮次，后续编辑该文件时顺手清理。最终复核为远端只读检查，未重跑工具链。

### 面积主张最终裁定（2026-10-18）

本实验**不能**支持"HetSub 真实硬件比传统 XY 路由器节省面积"这一结论。根本原因不是综合工具算错，而是被比较的两个硬件模型不具备充分的功能等价性与资源公平性：

| 问题 | 严重程度 | 影响 |
|---|---|---|
| Baseline（单个 128-bit 全 router，5 端口/2 VC/DEPTH 4）与 HetSub tile（L 3 端口/1 VC/128-bit + M 5 端口/2 VC/64-bit beat + relay + bypass + select/PG）结构不等价 | 高 | 无法直接归因面积优势 |
| Line 侧 RC 是简化单调 XY（`rc_mono`），非忠实 Hilbert RC | 高 | 少计算了部分真实路由机制 |
| 两套网络未构成完整端到端硬件通路（`sel`/`m_enable` 未反馈、`cong` 外部输入） | 高 | 不能代表完整 HetSub 实现 |
| 配置存储未完整建模（`cfg_*` 为 top 输入） | 中 | 面积核算不完整 |
| STA 大量端口未链接（Warning 201） | 高 | 完整时序有效性无法确认 |

归属复核：-8.6329% 的减少**全部**来自窄路径效应——仅 Flit Buffer/Logic（-18.3186%）与 Crossbar（-13.4360%）两列下降，RC +56.3636%、VA +4.0387%、SA +20.9690%、VC Table +24.2931%、HetSub modules（0 → 4416.6640）均为净增加。窄路径是窄 Mesh 子网这一性能/功耗设计的结构性副作用，不是方法的面积设计目标；其序列化代价（relay tx/rx 合计 3235.3580 µm²）已计入，但不足以改变归属结论。因此 -8.6329% 只能作为两个指定代表性 RTL 模型的映射面积差异保留，不能作为完整 HetSub 架构面积节省的证据。

两条证据链须分开：

| 证据链 | 目标 | 当前状态 |
|---|---|---|
| gem5 功能复现 | 路由、选网、长程链路、背压、数据交付等机制是否正确实现 | 已验证范围内 PASS，可作有范围限制的比较基准；不因 RTL 面积模型简化而失效 |
| RTL 硬件面积比较 | 完整 HetSub 架构是否真的比传统网络使用更少的标准单元面积 | 证据不足，不能宣称面积优势得到验证 |

R4 冻结维持（其声明已覆盖上述局限），但 R4 的 PASS 不可解读为"HetSub 完整硬件面积比较通过"。只有当论文要正式提出面积主张时，才需要建立完整且公平的 RTL 对照（忠实路由逻辑、端到端连接、配置存储、一致的资源和性能约束）；现阶段不启动，也不把 -8.6329% 作为主要科研成果。
