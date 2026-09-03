# 综合流量测试实现报告

## 概述

当前项目在 `gem5-gpu-xy` 分支上实现了一套可在 **8×8 Mesh** 上运行的综合流量测试体系，覆盖三种流量模式、可控注入率、自动统计解析和绘图闭环。实际路由算法为 **XY Dimension-Ordered Routing (DOR)**，运行于 flexible-pipeline 网络。

---

## 1. 流量生成器：NetworkTest

### 三种流量模式

**文件**: `gem5/src/cpu/testers/networktest/networktest.cc`

#### Uniform Random（类型 0, 行 179-185）
```cpp
destination = random_mt.random<unsigned>(0, numMemories - 1);
```
每个节点独立随机选择目标节点，流量均匀分布，作为基线参考。

#### Bit Reverse（类型 1, 行 187-205）
```cpp
unsigned dest_id = 0;
unsigned src_id = id;
for (int i = 0; i < numBits; i++) {
    unsigned bit = (src_id >> i) & 1;
    dest_id |= (bit << (numBits - 1 - i));
}
destination = dest_id;
```
反转节点 ID 的二进制位生成目标，制造对角线远端通信压力。

#### Transpose（类型 2, 行 207-223）
```cpp
int my_x = id % networkDimension;
int my_y = id / networkDimension;
int dest_x = my_y;
int dest_y = my_x;
destination = dest_y * networkDimension + dest_x;
```
交换二维网格坐标，形成对称热点流量。

### 注入率控制

**文件**: `gem5/src/cpu/testers/networktest/networktest.cc`, 行 142-153

```cpp
// send pkt if random number < injRate * (10^precision)
double injRange = pow((double) 10, (double) precision);
unsigned trySending = random_mt.random<unsigned>(0, (int) injRange);
if (trySending < injRate*injRange)
    send_this_cycle = true;
```

注入率以 **packets/tick/node** 为单位（`--injectionrate` 参数）。每个 tick 生成一个随机数，低于阈值时注入一个报文。通过 `--precision` 控制精度（默认 3 位小数，步长 0.001）。

### VI_hammer 地址编码

**文件**: `gem5/src/cpu/testers/networktest/networktest.cc`, 行 232-242

```cpp
// [unique_block_seq | dest_dir | block_offset]
int dirBits = 0;
int n = numMemories;
while (n >>= 1) dirBits++;
Addr paddr = ((uniqueBlockSeq << dirBits) | destination) << blockSizeBits;
uniqueBlockSeq++;
```

- `uniqueBlockSeq`：单调递增，保证每次访问不同 cache line，强制 L1 cache miss
- `destination`：目标目录 ID（与 traffic pattern 计算的 destination 一致）
- `blockSizeBits`：由 cacheline_size 计算（128B → 7 bits），与 Ruby 保持一致

**相关文件**: `gem5/src/cpu/testers/networktest/networktest.hh` 行 126 — `uint64_t uniqueBlockSeq` 成员变量

---

## 2. 路由执行：flexible-pipeline + XY DOR

### 主路由入口

**文件**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc`

普通 VC（非 escape）路径（行 980）：
```cpp
} else {
    outport = getRoute(destination);
}
```

Escape VC 路径也直接使用 `getRouteXY()`（行 956-958）。

### XY 方向选择

**文件**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc`, 行 1370-1379

```cpp
int Router::getRouteXY(int src, int dest) const {
    int sx = src % 8, sy = src / 8;
    int dx = dest % 8, dy = dest / 8;
    if (dx > sx) return 1;  // East
    if (dx < sx) return 3;  // West
    if (dy > sy) return 2;  // South
    if (dy < sy) return 0;  // North
    return -1;  // Local
}
```

先比较 X 坐标（East/West），X 坐标相同后才比较 Y（South/North）。严格 X-first DOR。

### 方向到物理端口映射

**文件**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh`, 行 805 — `m_direction_to_port[5]`

**文件**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc`, 行 167 — `setDirectionPort()` 注册内部链路

### 拓扑与网络类型

**文件**: `gem5/configs/ruby/Ruby.py`, 行 170-175

```python
elif options.garnet_network == "flexible":
    NetworkClass = GarnetNetwork
    ...
```

**文件**: `gem5-gpu/configs/gpu_protocol/VI_hammer.py`, 行 300-302

```python
elif options.topology == "Mesh":
    topology = Mesh(all_controllers)
```

默认 `garnet_network=flexible`，`topology=Mesh`，`mesh_rows=8`，`num_cpus=64`。

---

## 3. 统计采集

### 飞片级统计

**文件**: `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc`

| 统计项 | 类型 | 行号 |
|--------|------|------|
| `flits_received` | Stats::Vector (per vnet) | 94-96 |
| `flits_injected` | Stats::Vector (per vnet) | — |
| `network_latency` | Stats::Vector (per vnet) | — |
| `queueing_latency` | Stats::Vector (per vnet) | — |
| `average_vnet_latency` | Stats::Formula | 128 |
| `average_network_latency` | Stats::Formula | 135-136 |
| `average_queueing_latency` | Stats::Formula | 139-140 |
| `average_latency` | Stats::Formula | 141 |

这些统计在 flit 注入/接收时自动更新，无需额外配置。

### 路由器级统计

**文件**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc`, 行 2189-2280

`regStats()` 注册 13 个 scalar、1 个 vector、3 个 histogram、4 个 formula。包括 `traditionalRoutingCount`（XY 路由次数）、`averageHopCount`（曼哈顿距离均值）等。

---

## 4. 配置脚本

### VI_hammer 合成流量配置

**文件**: `gem5-gpu/configs/synth_vi_hammer.py`（93 行）

关键行为：
- 注册 GPUConfig/GPUMemConfig/Common/Ruby 选项（行 33-36）
- 设置默认 `num_cpus=64`、`num_dirs=64`、`num_l2caches=64`、`garnet_network=flexible`（行 48-50）
- 创建 NetworkTest 实例（每个 CPU 端口一个），传入 `block_offset` 对齐到 128B cacheline（行 70-77）
- 调用 `Ruby.create_system()` 创建完整 Ruby 系统 + flexible-pipeline 网络（行 86）

### Network_test 配置（快速泛型）

**文件**: `gem5/configs/example/ruby_network_test.py`

自带 synthetic traffic 参数支持，只需追加 `--garnet-network=flexible --topology=Mesh --mesh-rows=8` 即启用 flexible-pipeline + XY 路由。

---

## 5. 扫描/解析/绘图脚本

### 扫描脚本

**文件**: `scripts/sweep_synth_traffic.sh`（76 行）

```
1. 定义 3 种流量模式：uniform / bit_reverse / transpose
2. 遍历 15 个注入率：0.01 ~ 1.00
3. 为每个 (pattern, rate) 组合运行 gem5 并保存 stats.txt
4. 自动调用 parse → CSV
5. 自动调用 plot → latency_vs_load.png + throughput_vs_load.png
```

### 解析脚本

**文件**: `scripts/parse_synth_stats.py`（93 行）

从每个 stats.txt 提取：`avg_latency`、`network_latency`、`queueing_latency`、`flits_received`、`sim_ticks`，计算 `throughput_flits_per_tick`，输出 `results.csv`。

### 绘图脚本

**文件**: `scripts/plot_synth_traffic.py`（106 行）

读入 results.csv，生成两张图：
- `latency_vs_load.png` — 三种模式的延迟 vs 注入率曲线
- `throughput_vs_load.png` — 三种模式的吞吐量 vs 注入率曲线

---

## 6. 运行方式

```bash
# 完整 sweep
./scripts/sweep_synth_traffic.sh --sim-cycles 50000

# 单点测试（VI_hammer）
./gem5/build/X86_VI_hammer_GPU/gem5.opt \
    gem5-gpu/configs/synth_vi_hammer.py \
    --synthetic=0 --injectionrate=0.1 --sim-cycles=5000 \
    --num-cpus=64 --random_seed=42

# 单点测试（Network_test，纯网络无协议噪声）
./gem5/build/X86_Network_test/gem5.opt \
    gem5/configs/example/ruby_network_test.py \
    --synthetic=0 --injectionrate=0.1 --sim-cycles=5000 \
    --num-cpus=64 --num-dirs=64 \
    --garnet-network=flexible --topology=Mesh --mesh-rows=8 \
    --random_seed=42
```

---

## 7. 已验证输出格式示例

CSV 输出 (`m5out/synth/results.csv`):
```csv
pattern,synthetic,injection_rate,avg_latency,network_latency,queueing_latency,flits_received,sim_ticks,throughput_flits_per_tick
uniform,0,0.10,40.060807,38.060807,2,73890,5000,14.77800000
```

说明：
- `avg_latency` — 端到端平均延迟（ticks，≈ ns）
- `network_latency` — 网络传输延迟（ticks）
- `queueing_latency` — 排队延迟（ticks）
- `throughput_flits_per_tick` — 全局交付吞吐量（`flits_received / sim_ticks`）
- `injection_rate` — 注入率（packets/tick/node）

---

## 8. 代码文件汇总

| 功能 | 文件 | 关键行 |
|------|------|--------|
| 流量发生器 | `gem5/src/cpu/testers/networktest/networktest.cc` | 176-244 |
| 流量发生器定义 | `gem5/src/cpu/testers/networktest/networktest.hh` | 110-139 |
| SimObject 参数 | `gem5/src/cpu/testers/networktest/NetworkTest.py` | 33-47 |
| XY 方向计算 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc` | 1370-1379 |
| XY 路由入口 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc` | 1304-1362 |
| 方向→端口映射 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh` | 805 |
| 方向注册 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc` | 154-167 |
| 基础网络统计 | `gem5/src/mem/ruby/network/garnet/BaseGarnetNetwork.cc` | 91-143 |
| VI_hammer 配置 | `gem5-gpu/configs/synth_vi_hammer.py` | 33-86 |
| Network_test 配置 | `gem5/configs/example/ruby_network_test.py` | 48-72 |
| Mesh 拓扑支持 | `gem5-gpu/configs/gpu_protocol/VI_hammer.py` | 300-302 |
| Ruby 4 值兼容 | `gem5/configs/ruby/Ruby.py` | 194-201 |
| 扫描脚本 | `scripts/sweep_synth_traffic.sh` | 13-64 |
| 解析脚本 | `scripts/parse_synth_stats.py` | 12-96 |
| 绘图脚本 | `scripts/plot_synth_traffic.py` | 28-106 |

---

## 9. 路由行为验证

stats.txt 中实际统计数据显示：

- `mvpp_mgc_pso_routing_count` = **0**（PSO 不使用）
- `traditional_routing_count` = 非零（实际 XY 路由次数）
- `average_hop_count` = 5-6 hops（8×8 mesh 曼哈顿距离，合理）
- `average_network_latency` ≈ 38 ticks（~5.5 hops × 4 pipeline stages）

路由决策路径一致：通过 `getRoute()` → `getRouteXY()` 保证 X-first DOR 确定性最短路径，无绕路。
