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
