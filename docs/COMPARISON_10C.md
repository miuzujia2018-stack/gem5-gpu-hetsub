# 三仓正式比较：formal_10c_v1

## 用户裁决与平台

2026-10-15用户批准正式比较统一10 clusters×1 core、16 CPU、4 Directory、40 GPU L2、64 tile Mesh，保留10个GPU NoC端点。此配置是新的冻结实验条件；旧16/10混合配置结果仅为历史机制证据。三仓默认值、bak的40-cluster配置与历史实验不覆盖。

入口：`python3 tools/hetsub/run_comparison.py REPO APP --method METHOD --tag TAG`。REPO为hetsub/tbp/bak，APP为backprop/kmeans。正式输出独立存于`m5out/comparison_10c/TAG/REPO_METHOD/APP/`，拒绝覆盖；每次记录实际命令、现有构建凭据与退出码。该入口每次先verify，在Docker中显式绑定目标源码树并再次verify。

固定系统：CPU/Ruby 2GHz、system 1GHz、GPU Fermi 700MHz；cacheline128B；CPU L1D64kB/2way、L1I32kB/2way，GPU L1 64kB/4way，GPU L2总容量参数1MB/16way，CPU L2参数2MB/8way。所有数值以实际config.ini审计为准，不能仅凭CLI。三个方法读取本仓同一个应用二进制和kmeans_input.txt。

最终sim seed0；HetSub/TBP topology seed0，bak placement绑定sim seed，因此本批固定0以得到同一映射。pilot seed17、topology seed0，仅用于HetSub离线Algorithm 2，最终不能读未来流量。该单一共同种子的结果不作跨种子稳健性结论。

## 方法与测量

- 同时保留bak显式`routing-mode=xy`的正式XY控制和HetSub off回归控制；TB-TBP保留paper定时参数700000/200000/3000000/2000000cycles，不能静默换为verification快速配置。
- HetSub dual/static分128/64与128/56两种；dual启用PG，static使用独立pilot冻结JSON，保守物理段传播模型。
- bak必须确认当前方法实际启用的配置及路由活动，不能把默认回退XY称作bak方法结果。
- 比较低时延（原始message service/completion）、拥塞（源排队/有效吞吐/压力下背压）、负载分布（实际物理链路活动及容量归一化），能量维度仅PG状态/唤醒事件、链路/存储活动代理。无校准功耗系数，不给J或节能百分比。
- 统一full-job统计到应用退出，不做kernel reset。正常退出、消息守恒和网络排空分开验收。应用未排空须报告inflight及已交付消息统计人口，不能把尾部截断视为已证明丢包或全网排空。有限包合成检查单独验证全网排空。
- 128/56只匹配内部链路位宽，不代表外部线路、buffer、控制电路、面积或功耗等预算。

## 验收状态

修正 GPU L2 索引位计算后，正式批次 `formal_10c_v2_20261015` 的双应用三仓审计、独立CPU数值检查和方法活动检查均通过。结果、负收益及边界见 [COMPARISON_10C_RESULTS.md](COMPARISON_10C_RESULTS.md)。应用正常退出但未全网排空；有限包排空由独立 Network_test 验证。阶段审查前仍须提交、推送并核对远端SHA。
