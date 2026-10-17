# HetSub RTL 面积估算实验计划

生成时间：2026-10-17 13:06:31 CST  
状态：规划完成，RTL 与综合尚未开始

## 1. 目标与结论边界

本阶段目标是在统一的 RTL、工艺库、时序约束和面积统计边界下，得到可填入 ALPHA 论文 Table 3 风格表格的 HetSub 面积数据。目标是复现并估算 HetSub 硬件机制，而不是写论文，也不要求复现任何性能收益。

主要结论（target claim）：在与基线相同的 45 nm 标准单元库、PVT、时钟、综合选项和存储实现下，报告一个 HetSub tile 的总标准单元面积、分模块面积及相对基线增幅。

反证目标（anti-claim）：排除因遗漏第二子网、relay/串并转换、PG/隔离控制、静态旁路配置逻辑，或因未约束设计、存储黑盒、层级重复计数而得到的虚低面积。

当前事实边界：

- 用户给出的数字来自 ALPHA 的 Table 3。该表说明使用 Synopsys Design Compiler 和 45 nm 开源库，但论文正文未给出足以唯一复现的库版本、PVT 和完整时序约束。
- HetSub 原文面积流程使用 Synopsys Design Compiler、SMIC 55 nm、SS/SVT、200 MHz。该结果不能直接追加到 ALPHA 的 45 nm 表中。
- 当前仓库实现是 gem5 C++ 时序/功能模型，不是可综合 RTL；仓库中未发现 HetSub SystemVerilog/Verilog、综合 Tcl 或 45 nm `.lib/.db`。
- 因而现阶段不能诚实地产生 HetSub 数值。最终必须选择以下一种口径：
  1. **严格追加原表**：取得 ALPHA 基线 RTL、准确 45 nm 库和约束，先复现 0.2303 mm²，再综合 HetSub；
  2. **同口径重新估算（推荐的现实路径）**：用公开且固定版本的 45 nm 库和明确约束，重新综合 Baseline 与 HetSub，仅将原表其他行作为文献值，表题注明 `re-estimated`；不得用新 HetSub 除以原文 0.2303 计算增幅。

## 2. 面积对象与公平比较单位

### 2.1 比较单位

面积比较单位固定为“一个逻辑 tile 所需的 NoC router/NI-side HetSub 逻辑”，而非整张 8×8 网络。基线 top 为一个 5-port Mesh router；HetSub top 必须同时包含：

- 常开 L 子网 router：两个 line 邻居端口加一个 local 端口，128-bit datapath，1 VC/vnet；
- 可电源门控 M 子网 router：N/S/E/W/local 五端口，64-bit datapath，2 VC/vnet；
- NI 子网选择与反压逻辑；
- 128↔64-bit relay 串行化/反串行化及其有界缓存；
- 静态 long-link crossbar bypass 的配置、选择和占用控制；
- 拥塞采样、PG 状态机、唤醒/隔离控制；
- Algorithm 1 路由限制与 Algorithm 2 生成的静态配置在硬件中的消费逻辑。

Algorithm 2 本身为离线插入算法，不把运行于主机的配置生成器计入芯片面积；配置寄存器和硬件旁路控制必须计入。

主结果使用论文比例 `L=128 bit, M=64 bit`。当前 gem5 的 `128/56` 配置仅可作为单独敏感性行，不得替代 HetSub 主行。

### 2.2 不计入或单列项目

- DC cell area 不包含 NoC 长线布线面积；线长/拥塞/P&R 面积不得伪装成逻辑综合面积。
- 若开源 45 nm 库无 header switch、isolation/retention cells，则主表标为 `logic-only, PG cells excluded`，并把 PG cell 面积列为 `N/A`，不得静默记为 0。
- 时钟树、routing filler、decap 等后端面积不属于 ALPHA 的逻辑综合口径；若未来做 P&R，应形成独立表格。

## 3. RTL 最小实现范围

采用模块化但不搭建通用框架：

| 模块 | 最低实现要求 | 面积归类 |
|---|---|---|
| `baseline_router` | 5 ports、128 bit、2 VC/vnet、data VC depth 4、control VC depth 1、2-stage wormhole | 各公共列 |
| `hetsub_l_router` | 3 ports、128 bit、1 VC/vnet、Hilbert/单调路径与 L 仲裁 | 公共列 |
| `hetsub_m_router` | 5 ports、64 bit、2 VC/vnet、XY、PG 边界接口 | 公共列 |
| `hetsub_relay` | 连续字节流 128↔64 转换、有界上下文、反压、tail 后释放 | HetSub-specific |
| `hetsub_bypass` | 静态配置、输入/输出独占、最多两跳物理段、旁路 M 的普通 RC/VA/buffer | HetSub-specific / Crossbar，二选一且不可重复 |
| `hetsub_select_pg` | 拥塞驱动选网、滞回/采样、PG 状态和唤醒计数、隔离控制 | HetSub-specific |
| `hetsub_tile_top` | 实例化 L、M 与上述控制，作为总面积唯一统计 top | Total |

不要为面积估算移植完整 gem5。RTL 行为以论文机制和已经冻结的 gem5 实现作为双重规格；发现两者差异时，主 RTL 采用论文机制，平台适配另列参数。

## 4. 功能仿真门禁

工具优先使用当前可用的 Verilator 或 Icarus Verilog；仿真仅覆盖影响面积结论的最小功能，不运行大规模应用。

### 4.1 必须通过的定向测试

1. Baseline：每个方向和 local 端口各一组 head/body/tail，检查 VC 分配、credit 和交叉开关传输。
2. 双子网选择：低拥塞走 L、达到阈值后走 M、滞回返回；选网决定必须实际控制发送端口。
3. relay：至少覆盖 128→64、64→128、非整宽尾 flit、背压中断与恢复；按字节重构完全一致。
4. 静态 bypass：合法 Algorithm 1 单调路径能够承载，非法转向/资源冲突被拒绝；旁路时不进入中间普通 M buffer/RC/VA。
5. PG：M 有在途 flit 时不得关闭；wake latency 到期前不得放行；隔离期间输出稳定。
6. 守恒：有限包测试结束时 injected = delivered，重复/丢失为 0，所有 credit、buffer 和 relay context 排空。

### 4.2 最小断言

- 每个 VC 的 occupancy 在 `[0, DEPTH]`；credit 不溢出、不为负。
- 同一 VC 内 packet/flit 顺序保持；每个输入 flit 至多被一个输出接受。
- 配置冻结期间 bypass 端口互斥；禁止组合环。
- PG off 前 M 子网内部及 relay 到 M 的在途状态为空。

这些测试验证 RTL 确实实现拟综合的机制，但不作为性能优势测试。

## 5. 综合方法

### 5.1 环境冻结

每次正式综合记录：RTL commit、综合工具与版本、45 nm library 文件及版本、PVT、wire-load/physical-aware 模式、时钟周期与 uncertainty、输入/输出延迟、fanout/transition、compile 命令、面积与时序报告。

首先恢复 ALPHA 的准确设置。若无法取得，则明确采用一个可公开复现的固定 45 nm 标准单元库，结果命名为“同口径重新估算”，不声称精确复现 ALPHA 原数值。

### 5.2 存储建模

Flit buffer 是表中最大项，必须统一建模：

- 首选：Baseline 与 HetSub 均使用同一 memory compiler/macro，按实际位数和端口数计面积；
- 可接受退路：两者均综合为寄存器阵列；
- 禁止一方用 SRAM macro、另一方用 flop；禁止未链接 memory black box 后把面积当 0。

### 5.3 综合与报告

- 对 `baseline_router` 和 `hetsub_tile_top` 使用完全相同的约束和优化等级。
- 保留面积归属所需模块边界（例如 `compile_ultra -no_autoungroup` 或针对性 `set_ungroup false`），但不对整个方法模块 `dont_touch`，避免扭曲优化。
- 运行 `check_design`、`check_timing`、`report_qor`、`report_timing`、`report_reference` 和 `report_area -hierarchy`。
- 正式面积必须满足：无 unresolved reference、无未约束关键路径、无意外 latch、所有 memory 有非零面积、WNS ≥ 0。
- `Total` 只取完整 top 的一次层次综合面积；分项取该 top 内层级面积。不得把独立综合的子模块面积直接相加冒充 Total。

## 6. Table 3 列映射与计算

| 表列 | HetSub 归属规则 |
|---|---|
| Flit Buffer/Logic | L 与 M 的输入 VC buffer、指针、credit/FIFO 基础逻辑；relay buffer 放 method-specific |
| RC Unit | L 的 Hilbert/单调 RC 加 M 的 XY RC |
| VA Unit | L 与 M 的 VC allocator；若 L 单 VC被优化为控制逻辑，按实际层级面积报告 |
| SA Unit | L 与 M 的 switch allocator |
| Crossbar | L 3×3×128 与 M 5×5×64 datapath；bypass mux 必须固定只归此列或 method-specific |
| VC Table | L 与 M 的 VC 状态表 |
| Method-specific | 新增 `HetSub relay/bypass/select/PG/config` 子列；LIC 与 Batch Scheduling 对 HetSub 均为 `–` |
| Other | `Total − 所有已归属项`，是残差，不单独综合 |
| Total | `hetsub_tile_top` 的报告总 cell area |
| Increase by % | `(HetSub Total / 同次 Baseline Total − 1) × 100%` |

建议最终展示时保留用户表原列，并在 Method-specific modules 下增加第三个子列 `HetSub modules`；否则会把核心硬件藏入 Other，失去审计性。

内部审计表额外列出 `HetSub-L`、`HetSub-M`、`relay`、`bypass`、`select/PG/config`，但公开 Table 3 只保留一个合计 `Hetsub` 行。

## 7. 分阶段执行与 Go/No-Go

### E0 — 来源与约束恢复

取得或确认 ALPHA baseline RTL、45 nm library、PVT、时钟和 buffer 实现。若拿不到，转为“re-estimated”口径并锁定公开库。禁止继续假装严格复现原表。

### E1 — Baseline 校准

实现并验证 baseline，完成一次正式综合。若采用原作者环境，目标是总面积与 0.2303 mm² 的差异不超过 5%，且 buffer/crossbar 等主要项没有数量级偏差；否则不得把 HetSub 追加到原表。若采用新公开环境，不以 0.2303 为硬门槛，只要求内部一致和时序闭合。

### E2 — HetSub RTL 功能闭环

实现 L、M、relay、bypass、select/PG/config 和 tile top，通过第 4 节定向测试。任一核心模块缺失，只能报告部分面积，不能填写最终 Hetsub 行。

### E3 — 同约束综合与归属

以相同 flow 综合 Baseline 和 HetSub，检查层级报告、时序、memory 解析和归属无重复。只需一个主约束点；不为获得好看面积反复调时钟。

### E4 — 表格生成与审查

从机器可读报告提取数值，保留至少 4 位小数，计算 residual 与 increase。人工复核“分项和 + Other = Total”和 PG/wire 排除项。输出 Table 3 与一页口径说明。

可选项（不阻塞主表）：128/56 灵敏度、P&R、真实 PG header/isolation cell 面积、全 64-tile RTL 网络仿真。

## 8. 成功标准与停止条件

成功必须同时满足：

1. Baseline 与 HetSub 同库、同 PVT、同约束、同存储模型；
2. HetSub 所有核心硬件进入可综合 top，非 testbench 或事后统计；
3. 最小功能/守恒/PG/relay/bypass 测试通过；
4. 综合设计已解析、已约束、WNS ≥ 0；
5. Total 来源于 top，分项无重复，Other 为可解释残差；
6. 45 nm 与 HetSub 原文 55 nm 数值不混算；
7. 表注清楚 PG cells、wire/P&R 和 memory 建模边界。

满足以上条件后应冻结 RTL 和综合脚本，直接生成正式面积表；不以面积增幅是否优于 ALPHA、是否接近 HetSub 原文作为通过条件。

## 9. 最终表格模板

| Configuration | Flit Buffer/Logic | RC Unit | VA Unit | SA Unit | Crossbar | VC Table | Other | LIC | Batch Scheduling | HetSub modules | Total | Increase by % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Baseline (same-flow) | TBD | TBD | TBD | TBD | TBD | TBD | TBD | – | – | – | TBD | – |
| Hetsub (128/64) | TBD | TBD | TBD | TBD | TBD | TBD | TBD | – | – | TBD | TBD | TBD |

原 ALPHA 六行作为“published values”保留，不与重新综合行混称同一实验批次；只有 E0/E1 证明严格复现原环境后，才可直接使用原 Baseline 0.2303 mm² 作为增幅分母。

