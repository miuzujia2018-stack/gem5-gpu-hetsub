# 综合流量实验最终代码审查

## 结论

当前分支已经完成并验证了一个 **三模式 synthetic traffic sweep 实验**：

- `uniform_random`
- `bit_reverse`
- `transpose`

实验对象是 **8x8 Mesh + flexible Garnet + XY DOR baseline**，运行入口是 `X86_Network_test/gem5.opt` + `gem5/configs/example/ruby_network_test.py`。

可以在论文中如实表述为：

> 本文实现并完成了基于 Network_test 的三种合成流量模式测试，在 8x8 Mesh flexible Garnet 网络和 XY DOR 基线路由上，对 uniform random、bit reverse、transpose 三种 traffic pattern 进行了注入率扫描，并统计 network latency (cycles) 与 throughput (packets/cycle/node) 结果。

不应表述为：

> 已完成完整或广义的综合流量实验。

除非论文中已经明确定义“综合流量实验”只指这三种 synthetic patterns 的 sweep。否则，“综合流量实验”容易被理解为覆盖更完整的 NoC synthetic benchmark suite、多拓扑、多规模、多 seed、多路由算法或真实 workload 组合；当前代码和产物尚不支持这种宽泛宣称。

## 审查结果

Verdict: **Approve with wording restrictions**

当前代码可以支持“已完成三种 synthetic traffic sweep 实验”的论文声明。

当前代码不支持无限定地声明“已完成综合流量实验”。

## 已核验证据

### 1. Traffic 生成逻辑真实存在

`NetworkTest` 按注入率随机决定每周期是否发包：

- `gem5/src/cpu/testers/networktest/networktest.cc:147` 定义 `send_this_cycle`
- `gem5/src/cpu/testers/networktest/networktest.cc:148` 使用 `10^precision` 作为注入概率范围
- `gem5/src/cpu/testers/networktest/networktest.cc:149` 生成随机数
- `gem5/src/cpu/testers/networktest/networktest.cc:150` 根据 `injRate` 判断是否发包
- `gem5/src/cpu/testers/networktest/networktest.cc:156` 在命中注入概率时调用 `generatePkt()`

三种目的节点生成逻辑真实存在：

- `gem5/src/cpu/testers/networktest/networktest.cc:179` 到 `185`: uniform random
- `gem5/src/cpu/testers/networktest/networktest.cc:187` 到 `205`: bit reverse
- `gem5/src/cpu/testers/networktest/networktest.cc:207` 到 `223`: transpose

### 2. 配置入口真实暴露 synthetic 参数

`ruby_network_test.py` 支持传入 traffic pattern 和注入率：

- `gem5/configs/example/ruby_network_test.py:51`: `--synthetic`
- `gem5/configs/example/ruby_network_test.py:54`: `--injectionrate`
- `gem5/configs/example/ruby_network_test.py:60`: `--precision`
- `gem5/configs/example/ruby_network_test.py:64`: `--sim-cycles`
- `gem5/configs/example/ruby_network_test.py:95` 到 `99`: 将参数传入 `NetworkTest`

### 3. Sweep 脚本覆盖三种模式和 7 个注入率

`scripts/sweep_synth_traffic.sh` 当前定义：

- `scripts/sweep_synth_traffic.sh:24` 到 `26`: 三种 pattern
- `scripts/sweep_synth_traffic.sh:29`: 7 个 injection rate，范围为 `0.01` 到 `0.15`
- `scripts/sweep_synth_traffic.sh:47` 到 `68`: 双层循环运行 21 个 case
- `scripts/sweep_synth_traffic.sh:57`: 传入 `--synthetic`
- `scripts/sweep_synth_traffic.sh:58`: 传入 `--injectionrate`
- `scripts/sweep_synth_traffic.sh:59`: 传入 `--sim-cycles`
- `scripts/sweep_synth_traffic.sh:60` 到 `62`: 固定 64 节点、64 dirs、8x8 Mesh、flexible Garnet

### 4. Host-side wrapper 解决了 Docker 产物一致性问题

`scripts/run_synth_sweep.sh` 是当前可信的端到端入口：

- `scripts/run_synth_sweep.sh:26` 到 `29`: 清空 host 侧旧产物
- `scripts/run_synth_sweep.sh:36` 到 `37`: 将最新 sweep 脚本复制进 Docker
- `scripts/run_synth_sweep.sh:38` 到 `43`: Docker 内运行 simulation-only sweep
- `scripts/run_synth_sweep.sh:54` 到 `57`: 将 Docker 内 raw stats 复制回 host 并修正 owner
- `scripts/run_synth_sweep.sh:64` 到 `65`: host 侧解析 CSV
- `scripts/run_synth_sweep.sh:70` 到 `72`: host 侧生成图

这解决了之前 host 与 container 内 `stats.txt` 内容不一致的问题。

### 5. Parser 已修复旧命名污染问题并输出论文图所需指标

`scripts/parse_synth_stats.py` 当前行为：

- `scripts/parse_synth_stats.py:39`: 只接受 `uniform_random`、`bit_reverse`、`transpose`
- `scripts/parse_synth_stats.py:45` 到 `48`: 跳过未知 pattern 目录
- `scripts/parse_synth_stats.py:53`: 将 `uniform_random` 映射为 synthetic id `0`
- 计算 `throughput_packets_per_cycle_per_node`
- 保留 `throughput_flits_per_tick` 作为原始 flit 级辅助字段

因此旧的 `uniform/` 目录不会再污染最终 CSV。

### 6. 完整实验产物已存在且一致

当前 `m5out/synth/` 中存在：

- 21 个 `stats.txt`
- `m5out/synth/results.csv`
- `m5out/synth/latency_vs_load.png`
- `m5out/synth/throughput_vs_load.png`

CSV 校验结果：

- 行数: `21`
- pattern 分布:
  - `bit_reverse`: 7
  - `transpose`: 7
  - `uniform_random`: 7
- synthetic id 分布:
  - `0`: 7
  - `1`: 7
  - `2`: 7
- injection rates:
  - `0.01`
  - `0.02`
  - `0.05`
  - `0.08`
  - `0.10`
  - `0.12`
  - `0.15`

抽样核对 `inj_0.10`：

| Pattern | sim_ticks | network_latency | throughput_packets_per_cycle_per_node |
| --- | ---: | ---: | ---: |
| `uniform_random` | 100000 | 38.181620 | 0.09987344 |
| `bit_reverse` | 100000 | 169.191566 | 0.08903172 |
| `transpose` | 100000 | 123.429976 | 0.09233638 |

这些数值来自 host-visible `stats.txt`，并与 `results.csv` 对齐。

### 7. 样本 stdout 证明运行参数正确

`m5out/synth/<pattern>/inj_0.10/stdout.log` 中的 command line 显示：

- `--synthetic=0/1/2`
- `--injectionrate=0.10`
- `--sim-cycles=100000`
- `--num-cpus=64`
- `--num-dirs=64`
- `--garnet-network=flexible`
- `--topology=Mesh`
- `--mesh-rows=8`
- `--random_seed=42`

同一批日志均显示：

- `Exiting @ tick 100000 because Network Tester completed simCycles`

## 论文表述边界

### 可以宣称

可以宣称：

- 已实现三种 synthetic traffic pattern 的测试能力
- 已完成三种 synthetic traffic pattern 的注入率扫描
- 实验覆盖 uniform random、bit reverse、transpose
- 实验拓扑为 8x8 Mesh
- 实验网络为 flexible Garnet
- 路由基线为 XY DOR
- 统计并绘制了 network latency (cycles) 和 throughput (packets/cycle/node) 随 injection rate 的变化曲线

推荐措辞：

> We implemented and evaluated a three-pattern synthetic traffic sweep on an 8x8 Mesh flexible Garnet network using the XY DOR baseline. The evaluated patterns are uniform random, bit reverse, and transpose. For each pattern, we swept seven injection rates from 0.01 to 0.15 and collected network latency (cycles) and throughput (packets/cycle/node) statistics from gem5/Ruby.

中文推荐措辞：

> 本文实现并完成了三种合成流量模式的低到中等注入率扫描实验。实验在 8x8 Mesh flexible Garnet 网络和 XY DOR 基线路由上运行，覆盖 uniform random、bit reverse、transpose 三种 synthetic traffic pattern，注入率范围为 0.01 到 0.15，并统计 network latency (cycles) 与 throughput (packets/cycle/node) 随注入率变化的结果。

### 不应宣称

不应无条件宣称：

- 已完成完整综合流量实验
- 已覆盖所有典型 NoC synthetic traffic
- 已完成多拓扑综合流量评估
- 已完成多网络规模综合流量评估
- 已完成多随机种子统计显著性实验
- 已完成真实应用流量与 synthetic traffic 的综合对比
- 已完成 VI_hammer GPU workload 的 synthetic sweep
- 已证明某个新路由算法在综合流量实验中优于 XY DOR

除非后续补充相应实验，否则这些说法会越过当前证据边界。

## 仍然存在的限制

### 1. 覆盖范围有限

当前只有三种 synthetic patterns：

- uniform random
- bit reverse
- transpose

没有覆盖常见 NoC synthetic patterns，例如：

- tornado
- bit complement
- shuffle
- neighbor
- hotspot
- transpose2 / reverse transpose

因此，如果论文中的“综合流量实验”按 NoC 领域常见 benchmark suite 理解，当前覆盖仍不足。

### 2. 只有一个拓扑和一个规模

当前实验固定：

- topology: Mesh
- mesh rows: 8
- nodes / dirs: 64

没有 4x4、16x16、多拓扑或不同注入节点规模。

### 3. 注入率范围只覆盖 0.01 到 0.15

当前 sweep 不再覆盖 `0.18` 到 `1.00` 的高负载区间，因此不能据此宣称已经观察或比较了完整饱和曲线。

论文中应明确这是低到中等注入率范围的 synthetic traffic sweep，而不是完整注入率范围扫描。

### 4. 只有一个 random seed

当前 wrapper 固定：

- `--random_seed=42`

uniform random 模式没有多 seed 置信区间或方差统计。

论文中不应暗示结果具有跨 seed 稳健性，除非后续补充多 seed。

### 5. 只评估 Network_test synthetic traffic

当前主 sweep 使用：

- `gem5/build/X86_Network_test/gem5.opt`
- `gem5/configs/example/ruby_network_test.py`

它不是 GPU benchmark workload，也不是 VI_hammer GPU workload 的应用级流量。仓库中存在 `gem5-gpu/configs/synth_vi_hammer.py`，但当前 `run_synth_sweep.sh` 没有使用它。

论文应避免把这批结果描述成 GPU 应用流量实验。

### 6. 自动构建测试未集成 full sweep

当前 full sweep 通过 `scripts/run_synth_sweep.sh` 手动运行。它没有并入 `docker_build_and_test_j64.sh`，也不适合作为默认 CI，因为完整 21-case 运行仍需要较长时间。

可以说“提供了可复现实验脚本并完成了一次完整运行”，不应说“自动化测试默认覆盖完整 synthetic sweep”。

## 需要修正文档的地方

`reports/synthetic_traffic_code_review.md` 是旧审查，里面仍写着“当前项目没有完成严格意义上的综合流量实验”。这个结论对当时状态成立，但现在已经过时。

建议保留旧文件作为历史记录，同时在论文或最终报告中引用本文件作为当前状态。

`reports/synthetic_traffic_implementation.md` 如果继续使用，需要谨慎修改措辞：

- 将“综合流量测试体系”改为“三种 synthetic traffic sweep 实验”
- 将 `uniform` 示例改为 `uniform_random`
- 明确运行入口是 `scripts/run_synth_sweep.sh`
- 明确 parse/plot 在 host 侧完成
- 明确实验不覆盖 VI_hammer GPU workload synthetic sweep

## 最终判断

当前代码和产物支持以下结论：

> 三种 synthetic traffic 模式的注入率扫描实验已经实现、完整运行并产生可追溯产物。

当前代码和产物不支持以下无限定结论：

> 综合流量实验已经完整完成。

最严谨的论文写法是把范围写清楚：

> 完成三种 synthetic traffic patterns 的综合流量测试。

或者：

> 完成有限范围的 synthetic traffic sweep，用于评估 8x8 Mesh XY DOR baseline 在三种典型合成流量下的 latency/throughput 表现。
