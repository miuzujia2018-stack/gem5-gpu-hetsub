# 8x8 Topology Segmentation Fault Analysis

生成时间：2026-05-05 20:24 CST

## 问题现象

当前项目把 Ruby/Garnet 拓扑从 4x4 扩展到 8x8 后，程序不是在编译阶段崩溃，而是在仿真刚进入事件队列后发生段错误。

复现命令来自 `m5out_repro_current/run.log`：

```bash
gem5/build/X86_VI_hammer_GPU/gem5.opt \
  -d m5out_repro_current \
  gem5-gpu/configs/se_fusion.py \
  -c benchmarks/rodinia/backprop/gem5_fusion_backprop \
  -o 16 \
  --maxinsts=1000
```

GDB 日志显示：

- `m5out_gdb_8x8/gdb.log:1662`：进入 `event queue @ 0` 后触发 `SIGSEGV`。
- `m5out_gdb_8x8/gdb.log:1663`：崩溃点为 `MessageBuffer::enqueue(this=0x0, ...)`。
- `m5out_gdb_8x8/gdb.log:1665`：调用栈来自 `NetworkInterface::wakeup()`。
- `m5out_gdb_8x8_flit/gdb.log:1668`：触发问题的 flit 为 `vnet=2, vc=8`，目的集合中出现 `NodeID 59`。

直接崩溃代码位置：

```cpp
outNode_ptr[t_flit->get_vnet()]->enqueue(
    t_flit->get_msg_ptr(), Cycles(1));
```

对应源码：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc:276`。

也就是说，某个 flit 被送到了一个 NetworkInterface，但该 NI 对该 vnet 没有注册 `fromNet` 消息队列，`outNode_ptr[vnet] == nullptr`，随后解引用空指针。

## 8x8 拓扑是否生成成功

从 `m5out_repro_current/run.log` 看，Python 拓扑创建阶段基本成功：

- `Total nodes in topology: 72`
- `CPU L1=16, GPU L1=10, GPU L2=40, Dir=4, DMA=0, Other=2`
- `Created 72 external links for 72 controllers`
- `Created 112 internal links`
- `Created 64 routers`
- `FINAL CHECK - Controllers: 72, ext_links: 72`

因此问题不是“外链数量不等于 controller 数量”，而是在路由选择阶段出现了目的/端口/vnet 不一致。

## 当前拓扑与协议的关键事实

本次运行中 Ruby MachineType 全局 NodeID 大致如下：

| MachineType | 数量 | 全局 NodeID 范围 | 说明 |
| --- | ---: | --- | --- |
| `L1Cache` | 17 | 0-16 | 16 个 CPU L1 + 1 个 page-walk L1 |
| `GPUL1Cache` | 10 | 17-26 | GPU L1/TCP |
| `GPUL2Cache` | 40 | 27-66 | GPU L2 |
| `GPUCopyDMA` | 1 | 67 | Copy engine DMA |
| `Directory` | 4 | 68-71 | 目录控制器 |

因此 GDB 中出现的 `NodeID 59` 不是 router 59，而是 `GPUL2Cache` 的一个全局 machine node。

GPUL2 的网络队列定义见 `gem5-gpu/src/mem/protocol/VI_hammer-GPUL2cache.sm`：

- `requestFromL1Cache`：`network="From"`, `virtual_network="7"`
- `forwardToCache`：`network="From"`, `virtual_network="3"`
- `responseToCache`：`network="From"`, `virtual_network="4"`
- `requestFromCache`：`network="To"`, `virtual_network="2"`

也就是说，GPUL2 可以从网络接收 vnet 7/3/4，但不能接收 vnet 2。若 vnet 2 flit 被送到 GPUL2 的 NI，`outNode_ptr[2]` 必然为空。

## 为什么“只改拓扑”就会崩溃

gem5 Ruby/Garnet 的核心假设是：

1. SLICC 协议用 `MachineID` / `NetDest` 表达消息目的。
2. Python 拓扑通过 `ExtLink(ext_node=controller, int_node=router)` 建立 `MachineID -> router` 映射。
3. C++ `Topology` 根据全局图自动生成每个 router 输出端口的 `m_routing_table`。
4. router 只能选择一个 `destination.intersectionIsNotEmpty(m_routing_table[port])` 的端口。

当前自定义路由逻辑破坏了这些假设：

### 1. 把 Machine NodeID 当成 Router ID

`Router::getRouteCollaborative()` 中：

```cpp
std::vector<NodeID> all_destinations = destination.getAllDest();
dest_node = static_cast<int>(all_destinations[0]);
```

这里拿到的是 Ruby 全局 Machine NodeID，不是 8x8 router id。比如 `NodeID 59` 是某个 GPUL2 controller，不是 router 59。

### 2. 对超出 64 的 Machine NodeID 做 `% 64`

当前代码存在类似逻辑：

```cpp
dest_node = dest_node % GlobalGraph::TOTAL_NODES;
```

Directory 的 NodeID 是 68-71，经过 `% 64` 后变成 4-7，这会把 Directory 目的错误解释成 router 4-7。

### 3. 把全局下一跳 router id 当作本地端口下标

全局图返回的 `recommended_next_hop` 是“下一跳 router id”，但代码中出现了把它当 `m_routing_table` 下标使用的路径。

router 的本地输出端口编号不是全局 router 编号。对于边缘/角落 router，本地端口数量通常只有 3-5 个；端口 1 并不等于 router 1。

### 4. 找不到候选端口时回退到第一个 outlink

当前代码在候选为空时会返回第一个非空 outlink。这个策略会把包送到完全不匹配的 NI，最终造成 `outNode_ptr[vnet] == nullptr`。

这是段错误最直接的触发机制。

## 根因总结

8x8 拓扑本身不是直接原因。真正原因是自定义 MVPP/MGC/PSO 路由层把“拓扑 router id”和“Ruby Machine NodeID”混用，并且在路由表不匹配时使用了不安全 emergency fallback。

4x4 时很多硬编码假设可能刚好不暴露：

- router 数量少；
- controller 分布与算法内部 4x4 模型更接近；
- 某些错误 fallback 仍可能落到可接收该 vnet 的 NI；
- 自定义 `GlobalGraph` 的 4x4 建模和原拓扑更一致。

扩展到 8x8 后，controller 数量仍是 72，但 router 变为 64，Machine NodeID 与 router id 完全不是同一命名空间，错误映射被迅速放大，仿真第一个事件就可能把 flit 送错 NI。

## 修复原则

### 短期止血

1. `NetworkInterface::wakeup()` 中发现 `outNode_ptr[vnet] == nullptr` 时使用 `fatal()` 打印清楚原因，避免空指针段错误。
2. `Router::getRoute()` 返回前必须验证端口合法，并且端口对应的 `m_routing_table[port]` 必须与 `destination` 相交。
3. 如果自定义算法返回非法端口，回退到 gem5 原始 routing-table 最小权重选择。
4. 如果原始 routing table 也找不到候选，直接 `fatal()`，不要返回第一个 outlink。

### 中期修复

1. 自定义 PSO/协作路由只能在 Ruby routing table 给出的候选端口集合中排序，不能自行生成不受约束的端口。
2. `GlobalGraph` 只能作为候选端口的评分输入，不能直接把 router id 当端口返回。
3. 建立显式 `MachineID -> router_id` 映射；不要用 `NodeID % 64`。

### 长期修复

1. 让 Python 拓扑输出 controller-to-router 映射文件，C++ 路由层读取或通过 SimObject 参数传入。
2. 将 4x4/8x8 维度从硬编码常量改为运行时参数。
3. 为每次拓扑生成添加连通性检查和 per-vnet 可达性检查。

## 建议验证步骤

1. 重新编译 `X86_VI_hammer_GPU/gem5.opt`。
2. 用短运行验证：

```bash
gem5/build/X86_VI_hammer_GPU/gem5.opt \
  -d m5out_verify_8x8 \
  gem5-gpu/configs/se_fusion.py \
  -c benchmarks/rodinia/backprop/gem5_fusion_backprop \
  -o 16 \
  --maxinsts=1000
```

3. 若仍停止，应查看新的 fatal 信息，而不是段错误；重点检查 `NI id`、`vnet`、`destination`、`selected port`。
4. 若 fatal 显示“目的 MachineType 不支持该 vnet”，则需要回到 SLICC 协议消息生成处修正虚网或目的集合。

## 本次已实施的最小补丁

已在当前工作区加入两类保护性修复，用于把“段错误”转化为可定位的 routing/vnet 错误，并阻止明显错误的 emergency fallback：

1. `gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkInterface.cc`
   - 在向 `outNode_ptr[vnet]` 投递前检查 `vnet` 范围和指针是否为空。
   - 若某 NI 收到未注册 vnet 的 flit，使用 `panic()` 打印 `NI id`、`vnet`、`vc`、`outNode_ptr` 大小。
   - 目的：避免 `MessageBuffer::enqueue(this=0x0)` 这种不可读段错误。

2. `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc`
   - 删除“候选为空时返回第一个 outlink”的不安全回退。
   - 在 `getRoute()` 返回前校验端口合法性，并确认 `destination` 与 `m_routing_table[result]` 相交。
   - 若自定义算法返回非法端口，则回退到 gem5 原始 routing-table 最小权重选择。
   - 若 routing table 也没有候选，则 `panic()`，不再随机/任意把 flit 发向本地 NI。

这些补丁不等价于完整 8x8 算法适配；它们是必要的安全底座。若补丁后仍停止，应根据新的 `panic()` 信息继续判断：

- 如果 `Router ... cannot find a valid routing-table output`：说明自定义拓扑生成或 Ruby `NetDest` 可达性有问题。
- 如果 `NetworkInterface ... received flit on unregistered vnet`：说明 flit 已经被送到某个 MachineID 对应 NI，但该协议控制器没有该 vnet 的 `network="From"` 队列；需要检查消息生成动作的 `Destination` 和 vnet。

