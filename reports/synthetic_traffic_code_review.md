# 综合流量实验代码审查结论

## 结论

当前项目**部分实现了合成流量测试能力**，但**不能认定已经完成“综合流量实验”**。

更准确的表述应为：项目已经具备在 `Network_test` / `flexible-pipeline` 上运行三种 synthetic traffic 的代码入口、扫描脚本、统计解析脚本和绘图脚本；但当前仓库没有保留完整 sweep 结果，自动化测试也没有执行 synthetic sweep，且脚本和报告中存在若干不一致。因此它是一个“合成流量实验框架/雏形”，不是已经完成并验证的综合实验体系。

---

## 审查范围

本次只审查代码本身，不评价论文叙述或算法贡献。

重点文件：

- `gem5/src/cpu/testers/networktest/networktest.cc`
- `gem5/src/cpu/testers/networktest/NetworkTest.py`
- `gem5/configs/example/ruby_network_test.py`
- `gem5-gpu/configs/synth_vi_hammer.py`
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc`
- `scripts/sweep_synth_traffic.sh`
- `scripts/parse_synth_stats.py`
- `scripts/plot_synth_traffic.py`
- `reports/synthetic_traffic_implementation.md`

---

## 已实现的代码能力

### 1. NetworkTest 支持三种 synthetic traffic

`NetworkTest.py` 暴露了 traffic 参数：

- `gem5/src/cpu/testers/networktest/NetworkTest.py:42` 定义 `traffic_type`，说明 0/1/2 分别为 uniform random、bit reverse、transpose。
- `gem5/src/cpu/testers/networktest/NetworkTest.py:43` 定义 `inj_rate`。
- `gem5/src/cpu/testers/networktest/NetworkTest.py:44` 定义注入率精度 `precision`。

C++ 发送端实现了三种目的节点生成逻辑：

- `gem5/src/cpu/testers/networktest/networktest.cc:179`：`trafficType == 0` 时随机选择目的节点。
- `gem5/src/cpu/testers/networktest/networktest.cc:187`：`trafficType == 1` 时执行 bit reverse。
- `gem5/src/cpu/testers/networktest/networktest.cc:207`：`trafficType == 2` 时执行 transpose。
- `gem5/src/cpu/testers/networktest/networktest.cc:225`：非法 traffic type 回退为 uniform random。

注入率控制也已实现：

- `gem5/src/cpu/testers/networktest/networktest.cc:148` 计算 `10^precision` 范围。
- `gem5/src/cpu/testers/networktest/networktest.cc:149` 生成随机数。
- `gem5/src/cpu/testers/networktest/networktest.cc:150` 根据 `injRate * injRange` 决定本周期是否发包。
- `gem5/src/cpu/testers/networktest/networktest.cc:156` 在允许注入时调用 `generatePkt()`。

地址编码也已实现：

- `gem5/src/cpu/testers/networktest/networktest.cc:237` 计算目的目录位宽。
- `gem5/src/cpu/testers/networktest/networktest.cc:240` 将 `uniqueBlockSeq` 和 `destination` 编码进物理地址。
- `gem5/src/cpu/testers/networktest/networktest.cc:241` 每包递增 `uniqueBlockSeq`，用于尽量避免重复 cache line。

审查判断：这一部分是真实代码实现，不是单纯文档。

### 2. Network_test 配置暴露了 synthetic 参数

`ruby_network_test.py` 支持直接运行 synthetic traffic：

- `gem5/configs/example/ruby_network_test.py:51` 添加 `--synthetic` 参数。
- `gem5/configs/example/ruby_network_test.py:54` 添加 `--injectionrate` 参数。
- `gem5/configs/example/ruby_network_test.py:60` 添加 `--precision` 参数。
- `gem5/configs/example/ruby_network_test.py:64` 添加 `--sim-cycles` 参数。
- `gem5/configs/example/ruby_network_test.py:95` 创建 `NetworkTest` 实例。
- `gem5/configs/example/ruby_network_test.py:98` 将 `options.synthetic` 传入 `traffic_type`。
- `gem5/configs/example/ruby_network_test.py:99` 将 `options.injectionrate` 传入 `inj_rate`。

审查判断：这是可运行 synthetic traffic 的主要配置入口。

### 3. 存在 VI_hammer synthetic 配置

`synth_vi_hammer.py` 也存在，并创建 `NetworkTest` 节点：

- `gem5-gpu/configs/synth_vi_hammer.py:39` 添加 `--synthetic`。
- `gem5-gpu/configs/synth_vi_hammer.py:41` 添加 `--injectionrate`。
- `gem5-gpu/configs/synth_vi_hammer.py:48` 默认 `num_cpus=64`。
- `gem5-gpu/configs/synth_vi_hammer.py:52` 默认 `garnet_network="flexible"`。
- `gem5-gpu/configs/synth_vi_hammer.py:53` 默认 `topology="Mesh"`。
- `gem5-gpu/configs/synth_vi_hammer.py:72` 创建 `NetworkTest`。
- `gem5-gpu/configs/synth_vi_hammer.py:76` 传入 `traffic_type=options.synthetic`。
- `gem5-gpu/configs/synth_vi_hammer.py:77` 传入 `inj_rate=options.injectionrate`。
- `gem5-gpu/configs/synth_vi_hammer.py:88` 调用 `Ruby.create_system()`。

审查判断：这个入口存在，但当前 sweep 脚本没有使用它；它不能作为“当前综合实验已跑通”的证据，只能作为另一个可用配置入口候选。

### 4. 当前实际路由是 XY DOR

主路由路径是：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:938` 进入 `request_vc()`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:980` 普通 VC 调用 `getRoute(destination)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1304` `getRoute()` 是当前主路由函数。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1339` 调用 `getRouteXY(m_id, dest_router)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1370` `getRouteXY()` 实现 X-first / Y-second 方向选择。

审查判断：如果运行 synthetic traffic，它测到的是 flexible Garnet + XY/traditional routing，而不是 PSO/MVPP。

### 5. 基础网络统计来自 BaseGarnetNetwork

可解析的基础统计项确实存在：

- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:94` 注册 `flits_received`。
- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:100` 注册 `flits_injected`。
- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:106` 注册 `network_latency`。
- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:112` 注册 `queueing_latency`。
- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:135` 计算 `average_network_latency`。
- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:138` 计算 `average_queueing_latency`。
- `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc:141` 计算 `average_latency`。

审查判断：解析 `stats.txt` 中这些字段是合理的。

### 6. sweep / parse / plot 脚本形成实验闭环雏形

扫描脚本：

- `scripts/sweep_synth_traffic.sh:13` 指向 `X86_Network_test/gem5.opt`。
- `scripts/sweep_synth_traffic.sh:14` 使用 `ruby_network_test.py`。
- `scripts/sweep_synth_traffic.sh:19` 定义 traffic pattern 名称。
- `scripts/sweep_synth_traffic.sh:24` 定义 15 个 injection rate。
- `scripts/sweep_synth_traffic.sh:42` 双层循环遍历 3 种 pattern 和 15 个 rate。
- `scripts/sweep_synth_traffic.sh:49` 调用 gem5。
- `scripts/sweep_synth_traffic.sh:52` 传入 `--synthetic`。
- `scripts/sweep_synth_traffic.sh:53` 传入 `--injectionrate`。
- `scripts/sweep_synth_traffic.sh:67` 调用解析脚本。
- `scripts/sweep_synth_traffic.sh:71` 调用绘图脚本。

解析脚本：

- `scripts/parse_synth_stats.py:19` 提取 `average_latency`。
- `scripts/parse_synth_stats.py:22` 提取 `average_network_latency`。
- `scripts/parse_synth_stats.py:25` 提取 `average_queueing_latency`。
- `scripts/parse_synth_stats.py:28` 提取 `flits_received::total`。
- `scripts/parse_synth_stats.py:31` 提取 `sim_ticks`。
- `scripts/parse_synth_stats.py:57` 计算 `flits / sim_ticks`。
- `scripts/parse_synth_stats.py:79` 写出 `results.csv`。

绘图脚本：

- `scripts/plot_synth_traffic.py:28` 读取 CSV。
- `scripts/plot_synth_traffic.py:40` 生成 latency 曲线。
- `scripts/plot_synth_traffic.py:64` 生成 throughput 曲线。
- `scripts/plot_synth_traffic.py:53` 图标题标明 `8x8 Mesh XY DOR`。
- `scripts/plot_synth_traffic.py:77` throughput 图标题同样标明 `8x8 Mesh XY DOR`。

审查判断：脚本链路设计是存在的，但是否完成实验要看它是否正确、是否被运行、是否有输出证据。

---

## 未完成或存在问题的证据

### 1. 当前仓库没有完整 sweep 输出

当前检查时没有发现：

- `m5out/synth/results.csv`
- `m5out/synth/latency_vs_load.png`
- `m5out/synth/throughput_vs_load.png`
- `m5out/synth/<pattern>/inj_<rate>/stats.txt`

审查判断：没有当前可追溯的完整实验产物，不能认定“实验已经完成”。最多能说“代码具备运行实验的入口”。

### 2. 最新自动化构建测试没有运行 synthetic sweep

最新构建日志只显示 `backprop + kmeans`：

- `build_logs/docker_build_and_test_j64_20260611_151040.log` 显示编译完成。
- 同一日志显示运行 `backprop` 和 `kmeans`。
- 未发现 `sweep_synth_traffic.sh`、`ruby_network_test.py`、`m5out/synth` 或 `results.csv` 的运行记录。

审查判断：自动化测试证明项目能编译并跑应用测试，但不能证明综合流量实验已运行。

### 3. parser 与 sweep 的 pattern 名称不一致

扫描脚本输出 pattern 目录名：

- `scripts/sweep_synth_traffic.sh:20` 使用 `uniform_random`。
- `scripts/sweep_synth_traffic.sh:21` 使用 `bit_reverse`。
- `scripts/sweep_synth_traffic.sh:22` 使用 `transpose`。

解析脚本映射：

- `scripts/parse_synth_stats.py:46` 使用 `{'uniform': 0, 'bit_reverse': 1, 'transpose': 2}`。

问题：`uniform_random` 不会匹配 `uniform`，因此解析出来的 `synthetic` 会是 `-1`。

审查判断：这是明确代码 bug。即使 sweep 成功运行，CSV 中 uniform_random 的 `synthetic` 编号也会错误。

### 4. 报告中的 CSV 示例与当前脚本不一致

现有报告写道：

- `reports/synthetic_traffic_implementation.md:240` 声称 CSV 输出在 `m5out/synth/results.csv`。
- `reports/synthetic_traffic_implementation.md:243` 示例为 `uniform,0,0.10,...`。

但当前 sweep 脚本实际目录名应是 `uniform_random`，解析脚本又会把它映射成 `-1`。

审查判断：报告中的示例不是当前脚本自然产生的结果，至少需要修正。

### 5. “综合”覆盖范围不足

当前 sweep 仅覆盖：

- 3 种 traffic pattern：uniform_random、bit_reverse、transpose。
- 15 个 injection rate。
- 1 个固定 random seed。
- 1 个拓扑：8x8 Mesh。
- 1 个路由：XY DOR。
- 主要统计：latency、network_latency、queueing_latency、flits_received、throughput。

缺失内容包括：

- 多 seed 重复实验。
- 置信区间/误差条。
- hotspot、tornado、neighbor、shuffle、bit complement 等更多 NoC 常见 synthetic patterns。
- 多拓扑或多规模验证。
- 不同 buffer / VC / pipeline 参数扫描。
- 多路由算法对照。
- 饱和点检测或 warm-up / measurement window 区分。
- 自动化 CI 或构建脚本中集成 sweep。

审查判断：如果“综合流量实验”按论文/评测标准理解，当前覆盖不够；如果按“有限 synthetic sweep”理解，则已有基础框架。

### 6. VI_hammer synthetic 配置没有被 sweep 使用

报告列出了 `gem5-gpu/configs/synth_vi_hammer.py`，该文件确实存在。

但当前 sweep 脚本使用的是：

- `scripts/sweep_synth_traffic.sh:13`：`gem5/build/X86_Network_test/gem5.opt`
- `scripts/sweep_synth_traffic.sh:14`：`gem5/configs/example/ruby_network_test.py`

不是：

- `gem5/build/X86_VI_hammer_GPU/gem5.opt`
- `gem5-gpu/configs/synth_vi_hammer.py`

审查判断：报告把两个入口都列为实现证据可以，但不能暗示 sweep 已覆盖 VI_hammer synthetic 实验。

### 7. `ruby_network_test.py` 限制 `num_cpus <= 64`

`gem5/configs/example/ruby_network_test.py:87` 设置 `block_size = 64`。

`gem5/configs/example/ruby_network_test.py:89` 检查 `options.num_cpus > block_size` 时直接退出。

审查判断：当前 64 节点 8x8 可以运行，但它不是可扩展的综合流量测试配置。

### 8. 统计命名仍混有 PSO/MVPP 残留

当前主路由是 XY，但 `Router.cc` 仍保留 MVPP/PSO 统计与代码残留。比如：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1395` 的 `getRoutePSO()` 直接返回 `-1`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1859` 在 `wakeup()` 中仍有 PSO table lazy init。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1873` 仍调用 `syncWithGlobalGraph()`。

审查判断：这不阻止 synthetic traffic 运行，但会污染代码可读性和统计归因，建议清理后再正式宣称实验实现完成。

---

## 实现思路复原

当前代码的 intended flow 应该是：

1. 用户运行 `scripts/sweep_synth_traffic.sh`。
2. 脚本遍历 3 个 traffic pattern 和 15 个 injection rate。
3. 每个组合调用 `X86_Network_test/gem5.opt`。
4. gem5 加载 `ruby_network_test.py`。
5. `ruby_network_test.py` 创建 64 个 `NetworkTest` 实例。
6. 每个 `NetworkTest` 根据 `inj_rate` 随机决定每周期是否发包。
7. `NetworkTest::generatePkt()` 根据 `traffic_type` 选择目的节点。
8. 地址编码把目的目录嵌入物理地址，进入 Ruby / Garnet 网络。
9. flexible-pipeline router 使用 `getRoute()` / `getRouteXY()` 做 XY DOR 路由。
10. Garnet 统计 flit、latency、queueing latency。
11. 每个 run 的 `stats.txt` 写入 `m5out/synth/<pattern>/inj_<rate>/`。
12. `parse_synth_stats.py` 汇总所有 `stats.txt` 到 `m5out/synth/results.csv`。
13. `plot_synth_traffic.py` 读取 CSV 生成 latency / throughput 曲线图。

这个设计是合理的，但当前项目状态缺少完整执行产物和若干修正。

---

## 最终判断

| 问题 | 判断 |
| --- | --- |
| 是否实现了三种 synthetic traffic 生成逻辑 | 是 |
| 是否实现了注入率参数控制 | 是 |
| 是否有 3×15 sweep 脚本 | 是 |
| 是否有 stats 解析和绘图脚本 | 是 |
| 是否已有当前可追溯完整 sweep 结果 | 否 |
| 是否集成进自动化构建/测试流程 | 否 |
| 是否达到“综合流量实验”标准 | 否，当前只能称为有限 synthetic sweep 框架 |
| 是否可以作为后续综合实验基础 | 可以 |

**审查结论：当前项目没有完成严格意义上的综合流量实验；它实现了一个可运行的 synthetic traffic 实验框架，但仍需修正 parser bug、跑完整 sweep、保留 raw stats/CSV/图表，并扩展覆盖范围后，才能称为综合流量实验完成。**

---

## 建议修正项

1. 修复 `scripts/parse_synth_stats.py:46`：把 `uniform` 改成 `uniform_random`，或同时兼容两者。
2. 在 `docker_build_and_test_j64.sh` 中增加可选 synthetic sweep 阶段，不要只跑 backprop/kmeans。
3. 运行完整 sweep 后保留：`stdout.log`、`stats.txt`、`results.csv`、plot 输出。
4. 增加多 seed，例如 5 个 seed，并输出均值/标准差。
5. 增加更多 traffic patterns 或明确声明“只覆盖三种 synthetic patterns”。
6. 清理 Router 中 PSO/MVPP 残留统计，避免把 XY synthetic 结果误归因。
7. 更新 `reports/synthetic_traffic_implementation.md`，把“已实现综合流量测试体系”改为“已实现 synthetic traffic sweep 框架”。
