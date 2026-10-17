# HetSub RTL 面积实验跟踪表

生成时间：2026-10-17 13:06:31 CST  
当前状态：`PLAN READY / RTL NOT STARTED`

| ID | 实验/检查 | 关键变量 | 主要指标 | 通过条件 | 状态 |
|---|---|---|---|---|---|
| E0.1 | 恢复 ALPHA 综合口径 | library/version、PVT、clock、memory model | 来源完备性 | 足以唯一执行；否则正式转为 re-estimated | 待办 |
| E0.2 | 固定面积边界 | router/tile scope、PG cells、wire exclusion | 纳入/排除清单 | Baseline 与 HetSub 定义一致 | 待办 |
| E1.1 | Baseline RTL 定向仿真 | 5-port、128-bit、2 VC、depth 4/1 | 守恒、credit、路由 | 全部断言通过并排空 | 待办 |
| E1.2 | Baseline 正式综合 | 固定 45 nm flow | total、hier area、WNS | 已解析/已约束/WNS≥0；memory 非零 | 待办 |
| E1.3 | 原表校准判定 | 同原环境时才适用 | 与 0.2303 mm² 差异 | ≤5% 才允许直接追加原表 | 待办 |
| E2.1 | L/M router 仿真 | L 128/1VC；M 64/2VC | 路由、VA/SA、反压 | 定向流量守恒并排空 | 待办 |
| E2.2 | relay 仿真 | 128↔64、partial tail、backpressure | 字节一致、占用有界 | 无丢失/重复/重排 | 待办 |
| E2.3 | bypass + Algorithm 1 | 合法/非法候选、资源冲突 | 单调性、独占、实际旁路 | 合法承载，非法拒绝 | 待办 |
| E2.4 | select + PG 仿真 | 拥塞阈值、滞回、wake latency | 选网生效、在途安全 | off 前排空，wake 前隔离 | 待办 |
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

