# HetSub RTL 面积实验跟踪表

生成时间：2026-10-17 13:06:31 CST  
当前状态：`E0 DONE / E1.1 PASS / E2.1–E2.4 PASS / E1.2 PENDING (toolchain download)`

| ID | 实验/检查 | 关键变量 | 主要指标 | 通过条件 | 状态 |
|---|---|---|---|---|---|
| E0.1 | 恢复 ALPHA 综合口径 | library/version、PVT、clock、buffer 实现 | 来源完备性 | 足以唯一执行；否则正式转为 re-estimated | 完成（转 re-estimated） |
| E0.2 | 固定面积边界 | router/tile scope、PG cells、wire exclusion | 纳入/排除清单 | Baseline 与 HetSub 定义一致 | 完成 |
| E1.1 | Baseline RTL 定向仿真 | 5-port、128-bit、2 VC、depth 4/1 | 守恒、credit、路由 | 全部断言通过并排空 | PASS |
| E1.2 | Baseline 正式综合 | 固定 45 nm flow | total、hier area、WNS | 已解析/已约束/WNS≥0；memory 非零 | 待办 |
| E1.3 | 原表校准判定 | 同原环境时才适用 | 与 0.2303 mm² 差异 | ≤5% 才允许直接追加原表 | 待办 |
| E2.1 | L/M router 仿真 | L 128/1VC；M 64/2VC | 路由、VA/SA、反压 | 定向流量守恒并排空 | PASS |
| E2.2 | relay 仿真 | 128↔64、partial tail、backpressure | 字节一致、占用有界 | 无丢失/重复/重排 | PASS |
| E2.3 | bypass + Algorithm 1 | 合法/非法候选、资源冲突 | 单调性、独占、实际旁路 | 合法承载，非法拒绝 | PASS |
| E2.4 | select + PG 仿真 | 拥塞阈值、滞回、wake latency | 选网生效、在途安全 | off 前排空，wake 前隔离 | PASS |
| E3.1 | HetSub top 正式综合 | 与 Baseline 同 flow | total、hier area、WNS | 核心模块均在 top；WNS≥0 | 待办 |
| E3.2 | 面积归属审计 | hierarchy mapping | 分项、residual、重复计数 | sum(items)+Other=Total | 待办 |
| E4.1 | 生成 Table 3 | same-flow Baseline 分母 | mm²、Increase % | 数值可追溯到报告 | 待办 |

## 记录规范

每项完成时填写：日期、命令、RTL commit、工具/库/约束、报告路径、PASS/FAIL 和一个结论句。失败结果保留，不为降低面积反复调约束。

## 决策日志

- 2026-10-17：确认不能把 HetSub 原文 55 nm 数值直接加入 ALPHA 45 nm Table 3。
- 2026-10-17：主配置冻结为论文比例 128/64；128/56 只作为非阻塞敏感性实验。
- 2026-10-17：最终增幅以同批次、同 flow 的 Baseline 为分母；取得原作者环境并通过校准前，不使用 0.2303 作为分母。
- 2026-10-17：Method-specific 增加 HetSub 专属子列，避免将核心机制隐藏在 Other。

## 执行记录

### E0.1 — 口径恢复（完成，转 re-estimated）

- 2026-10-17：ALPHA 原环境（Synopsys DC 版本、PVT corner）不可恢复，正式转为"同口径 re-estimated"。
- 锁定公开库：Nangate45 Open Cell Library，typ corner，134 cells。
  - 文件：`rtl/pdk/Nangate45_typ.lib`
  - SHA-256：`2efd0b32eb580e4e60e72fc0575bb3bc69aac907c91d908442e4ae6d7fe55895`（与上游 OpenSTA test 文件一致）
  - 来源：https://raw.githubusercontent.com/The-OpenROAD-Project/OpenSTA/master/test/nangate45/Nangate45_typ.lib
- 单一时钟约束点：1.0 ns（1 GHz），Baseline 与 HetSub 共用。
- Buffer 建模：寄存器阵列（flops），无 memory blackbox；Baseline 与 HetSub 同一建模方式。
- 工具：Yosys + `read_liberty`/`dfflibmap`/`abc -liberty`；OpenSTA 不可用，面积取 `stat -liberty` 单元面积和。

### E0.2 — 面积边界（完成）

- 面积单位 = 一个 HetSub tile：L router（3-port、128-bit、1 VC/vnet）+ M router（5-port、64-bit、2 VC/vnet）+ NI select/backpressure + 128↔64 relay（有界缓存）+ 静态 long-link crossbar bypass + 拥塞采样 + 滞回 + PG 状态机/wake/isolation + 静态配置寄存器。
- Algorithm 2 为离线计算（无面积），但其配置存储/bypass 控制计入。
- 排除：连线与 P&R 面积；若库无 PG header/isolation cell，对应项记 N/A。
- `Other = Total − attributed`；Table 3 增加 `HetSub modules` 子列。
- Baseline 与 HetSub 使用同一 flow、同一库、同一约束、同一 buffer 建模；增幅分母为同 flow 重新综合的 Baseline。

### E1.1 — Baseline 定向仿真（PASS）

- 2026-10-17：`iverilog -o sim_baseline tb/tb_baseline.v src/*.v && vvp sim_baseline`
- 结果：`PASS tb_baseline: injected=15 delivered=15 drained, credits restored`
- 修正记录（本日重跑确认）：vc_table 释放回路原用 `vc_port[i]`（打包向量的标量位）而非 3-bit 字段 `vc_port[i*3 +: 3]`，清错 vc_busy 位；vc_buffer 新增由 pre-edge 值计算的注册 `drained` 标志（消除与 vc_table 同沿竞争），vc_table 改收 `clear_en=drained`。
- 覆盖：5 端口各一组 head/body/tail（含 local 与 control VC）、VC 分配、credit 计数、crossbar 交付顺序与内容、守恒与排空、credit 恢复（4/1）。
- 结论：Baseline 数据路径（accept → VA → VC 表 → SA → crossbar）功能正确。

### E2.1 — L/M router 定向仿真（PASS）

- 2026-10-17（重跑，含本日修正）：`iverilog -o sim_l_router tb/tb_l_router.v src/*.v && vvp sim_l_router`
  → `PASS tb_l_router: injected=9 delivered=9 drained, credits restored`
- 2026-10-17（重跑，含本日修正）：`iverilog -o sim_m_router tb/tb_m_router.v src/*.v && vvp sim_m_router`
  → `PASS tb_m_router: injected=16 delivered=16 drained, credits restored, blocked input excluded`
- 修正记录：sw_alloc 的 sa_req 硬编码两个 VC 项（`p*NVC+0`/`p*NVC+1`），NVC=1 时第二项别名到下一端口条目（L router 输出 1 误请求 entry 0）；改为 `if (NVC == 1)` generate 分支。tb_m_router 的 block 阶段 flit 被接受后 `valid_in[2]` 未清除，accept 每周期重触发导致同一 flit 重复交付；TB 改为单次接受后清除 valid_in。
- 覆盖：L（3-port、128-bit、1 VC）与 M（5-port、64-bit、2 VC，含 depth-1 control VC）的 VC 分配、credit、crossbar 交付内容/顺序、守恒与排空。
- 结论：双子网 router 数据路径功能正确。

### E2.2 — relay 128↔64 定向仿真（PASS）

- 2026-10-17：`iverilog -o sim_relay tb/tb_relay.v src/hetsub_relay_tx.v src/hetsub_relay_rx.v && vvp sim_relay`
  → `PASS tb_relay: 4 words byte-exact, beats=7 (held 1), context drained`
- 覆盖：全字、partial tail（12 字节 2 beat、5 字节单 beat）、每 6 周期反压（beat 保持至被接受）、字节一致、有界上下文排空。
- 修正记录：tx 原实现把已呈现 beat 在呈现同一周期清除，消费端（寄存器输出晚一拍）反压时丢 beat；改为 pending 保持到 ready_in。rx 的 ready_out 改为透传 ready_in（完成字的 beat 仍被接受）。TB 在 posedge 采样 DUT 实际使用的事件。
- 结论：序列化/反序列化在反压下无丢失、无重复、无重排。

### E2.3 — bypass + Algorithm 1 定向仿真（PASS）

- 2026-10-17：`iverilog -o sim_bypass tb/tb_bypass.v src/hetsub_bypass.v && vvp sim_bypass`
  → `PASS tb_bypass: legality, exclusivity, block, hop budget`
- 覆盖：合法单调 grant（block/exclusive 置位、flit 路由到独占输出）、非法转折拒绝、非 head 拒绝、同输出冲突双方拒绝、hop 预算递减至耗尽后拒绝。
- 结论：Algorithm 1 单调性与独占性在数据路径中生效；被 grant 的输入被 block 阻止进入正常 RC/VA。

### E2.4 — select + PG 定向仿真（PASS）

- 2026-10-17：`iverilog -o sim_pg tb/tb_select_pg.v src/hetsub_select_pg.v && vvp sim_pg`
  → `PASS tb_select_pg: hysteresis, wake latency, in-flight safety, isolation`
- 覆盖：th_hi/th_lo 滞回（hold band）、OFF→WAKING→ON wake latency 计数、ON→OFF 仅在 sel=L 且无在途、OFF/WAKING 期间 m_enable=0（隔离）。
- 结论：拥塞驱动选网与 PG 安全约束功能正确。

### 工具链备注（E0.1 修正）

- 2026-10-17：oss-cad-suite（含 Yosys 与 OpenSTA）正在下载解压至 `/home/siat/tools/oss-cad-suite`；此前"OpenSTA 不可用"的记录作废，WNS 将在 E1.2/E3.1 用 OpenSTA 实测。
