# flexible-pipeline 路由算法 Code Review：XY 路由实现与结构分析

## 1. 评审范围

本评审聚焦 `gem5/src/mem/ruby/network/garnet/flexible-pipeline/` 中与路由决策直接相关的代码，重点回答两个问题：

1. 当前 flexible-pipeline 的主运行路径是否真的实现了 XY 路由算法。
2. 路由算法的结构、组成模块、所在文件以及主要风险点是什么。

主要审阅文件：

| 类别 | 文件 | 作用 |
| --- | --- | --- |
| 拓扑默认配置 | `gem5/configs/ruby/Ruby.py:68` | 默认选择 `Mesh8x8_CPU_GPU`，`mesh_rows=8`。 |
| 8x8 Mesh 拓扑 | `gem5/configs/topologies/Mesh8x8_CPU_GPU.py:107` | 创建 8x8、64 个 router，并建立水平/垂直链路。 |
| flexible 网络参数 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.py:68` | 定义 `routing_algorithm` 参数，但当前 C++ 路径未使用。 |
| 网络建链与方向映射 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:133` | 调用 `Router::addOutPort()` 并设置 XY 方向到物理端口的映射。 |
| Router 主路由逻辑 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:963` | `request_vc()` 是实际选择 outport 的入口。 |
| XY 实现 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1330` | `getRoute()` 调用 `getRouteXY()` 并返回物理 outport。 |
| XY 方向计算 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1396` | `getRouteXY()` 先 X 后 Y，返回 N/E/S/W 方向。 |
| Router 声明 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:978` | 声明 `getRoute()`、`routeCompute()`、`getRouteXY()` 等接口。 |
| PSO/协同模块 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/SConscript:50` | 编译 PSO、Swarm、Performance、NetworkUtilities 等模块，但主路径未选择它们。 |

## 2. 总体结论

**结论：当前 flexible-pipeline 的主路由路径确实实现了一个 8x8 Mesh 上的 X-first XY 路由，但实现是硬编码且不可配置的。**

更具体地说：

- **是 XY**：`Router::getRoute()` 使用 `getRouteXY(m_id, dest_router)`，`getRouteXY()` 明确先比较 X 坐标，只有 X 坐标相同才比较 Y 坐标。这符合经典 XY / dimension-ordered routing 中“先 X 后 Y”的决策规则。
- **是主路径**：普通 VC 分配路径 `request_vc(..., escape_mode=false)` 直接调用 `getRoute(destination)`；escape VC 路径也显式调用 `getRouteXY()`。
- **不是可配置多算法框架**：虽然 Python SimObject 暴露了 `routing_algorithm = "TABLE_"`，Router 也有 PSO、协同、功耗感知等函数，但当前主路由入口没有根据该参数切换算法。
- **不是泛化 XY**：所有坐标计算都假设 8 列、64 个 router，例如 `x = id % 8`、`y = id / 8`。在 4x4 Mesh 或其他拓扑上不再是正确的 XY 实现。
- **存在 fallback 偏离**：当 XY 方向映射出的端口不能通过 routing table 到达目的地时，代码退化为扫描 routing table 的第一个可达端口；该分支可能不是严格 XY。

因此，可以把当前实现描述为：**“active routing path = 8x8 Mesh 专用、X-first、带 routing-table 校验与 fallback 的确定性 XY 路由”**。

## 3. 主路由调用链

当前真正影响 flit 输出端口的调用链如下：

```text
Topology / GarnetNetwork 建链
  └─ GarnetNetwork::makeInternalLink()
      ├─ Router::addOutPort()
      └─ Router::setDirectionPort(dir, physical_outport)

Head flit 请求 VC
  └─ Router::request_vc(in_vc, in_port, destination, request_time, escape_mode)
      ├─ escape_mode == true  : getRouteXY() + routingTableHasDest() 校验
      └─ escape_mode == false : getRoute(destination)
             ├─ getDestInfo(destination)
             ├─ MachineID -> physical router id 映射
             ├─ getRouteXY(current_router, dest_router)
             ├─ direction -> physical outport
             ├─ routingTableHasDest(outport, destination) 校验
             └─ fallback: 扫描 routing table 第一个可达端口

路由结果落地
  └─ InVcState::setRoute(outport)
      └─ Router::routeCompute()
          └─ 将 flit 插入 m_router_buffers[outport][outvc]
```

关键代码位置：

- `Router::request_vc()`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:963`
- escape VC 使用 XY：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:981`
- 普通路径调用 `getRoute()`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1006`
- `InVcState::setRoute(outport)`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1008`
- `routeCompute()` 使用已保存 outport：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1961`

## 4. XY 路由实现细节

### 4.1 目的地解析

`getRoute()` 先通过 `getDestInfo(destination)` 找到目标 MachineID 的编码 key，然后使用 `s_mid_to_router_id` 将 MachineID 映射到实际物理 router id。

相关代码：

- `Router::getDestInfo()`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1110`
- `s_mid_to_router_id` 声明：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:992`
- MachineID 到 RouterID 注册：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:140`

如果映射表中没有目标 key，代码退化为 `dest_key % 64`。这个 fallback 与 8x8/64 router 假设绑定。

### 4.2 XY 方向计算

核心函数是 `Router::getRouteXY(int src, int dest)`：

```text
sx = src % 8, sy = src / 8
dx = dest % 8, dy = dest / 8
if dx > sx -> East
if dx < sx -> West
if dy > sy -> South
if dy < sy -> North
else       -> Local
```

代码位置：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1396`

这个顺序是标准 X-first XY：

1. 当前 router 与目标 router X 坐标不同：优先沿 East/West 移动。
2. X 坐标相同后：沿 South/North 移动。
3. 两个坐标都相同：返回 local。

方向编码在代码中约定为：

| 编码 | 方向 | 含义 |
| --- | --- | --- |
| `0` | North | Y 减小 |
| `1` | East | X 增大 |
| `2` | South | Y 增大 |
| `3` | West | X 减小 |
| `-1` | Local | 当前 router 即目标 router |

### 4.3 方向到物理 outport 的映射

`getRouteXY()` 返回的是方向，不是物理端口。真正的 outport 由 `m_direction_to_port[]` 映射得到：

- 映射数组声明：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:805`
- 初始化为 `-1`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:638`
- 设置接口：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:935`
- 内部链路建链时注册 N/E/S/W：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:167`
- 外部链路建链时注册 local：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:137`

`GarnetNetwork::makeInternalLink()` 使用 `dest % 8 - src % 8` 与 `dest / 8 - src / 8` 判断方向，这与 `getRouteXY()` 的 8x8 坐标假设保持一致。

### 4.4 routing table 校验与 fallback

`getRoute()` 并不是盲目返回 XY 方向对应端口，而是先校验该端口的 routing table 是否包含目标 destination：

- 校验函数：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:193`
- XY 端口校验：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1375`
- fallback 扫描 routing table：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1381`

这个设计有两个效果：

1. 正常 8x8 Mesh 中，XY 端口合法时返回严格 XY outport。
2. 如果方向端口缺失、local 端口映射不唯一、或者拓扑不是 8x8，fallback 会选择第一个能到达目的地的 table 端口；此时结果不一定仍是 XY。

## 5. 拓扑与 XY 一致性

### 5.1 默认拓扑是 8x8 Mesh

默认 Ruby 配置是：

- `--topology` 默认 `Mesh8x8_CPU_GPU`：`gem5/configs/ruby/Ruby.py:68`
- `--mesh-rows` 默认 `8`：`gem5/configs/ruby/Ruby.py:70`

`Mesh8x8_CPU_GPU.py` 明确创建：

- `num_rows = 8`、`num_columns = 8`、`num_routers = 64`：`gem5/configs/topologies/Mesh8x8_CPU_GPU.py:107`
- router id 为 `row * num_columns + col`：`gem5/configs/topologies/Mesh8x8_CPU_GPU.py:117`
- 水平 East-West 链路：`gem5/configs/topologies/Mesh8x8_CPU_GPU.py:347`
- 垂直 North-South 链路：`gem5/configs/topologies/Mesh8x8_CPU_GPU.py:359`

因此，在默认 `Mesh8x8_CPU_GPU + flexible` 组合下，`id % 8` / `id / 8` 与拓扑 router 编号一致，XY 方向计算成立。

### 5.2 4x4 Mesh 下不成立

项目中也存在 4x4 拓扑，例如：

- `gem5/configs/topologies/Mesh_4x4.py:15`
- `gem5/configs/topologies/Mesh4x4_CPU_GPU.py`

但 flexible Router 的 XY 实现硬编码了 8 列。举例：在 4x4 Mesh 中，router 3 到 router 4 实际应从第一行最右侧向 South 走；但 `getRouteXY(3, 4)` 按 8 列坐标计算为 `(3,0) -> (4,0)`，会返回 East。这说明当前 XY 实现不是拓扑无关算法。

## 6. 路由算法结构与组成

### 6.1 Active：当前真正执行的 XY 路由层

| 组成 | 文件位置 | 说明 |
| --- | --- | --- |
| `request_vc()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:963` | VC 请求阶段选择 outport，是当前路由决策入口。 |
| `getRoute()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1330` | 普通路径使用的主算法；实际执行 XY + 校验 + fallback。 |
| `getRouteXY()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1396` | X-first XY 的方向计算。 |
| `routingTableHasDest()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:193` | 用预计算 MachineID 列表验证端口是否可达 destination。 |
| `m_direction_to_port` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:805` | 将 N/E/S/W/Local 方向映射到物理 outport。 |
| `routeCompute()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1961` | 不再计算路由，只消费 `request_vc()` 保存的 outport。 |

### 6.2 拓扑建链与路由表层

| 组成 | 文件位置 | 说明 |
| --- | --- | --- |
| `Mesh8x8_CPU_GPU` | `gem5/configs/topologies/Mesh8x8_CPU_GPU.py:48` | 默认 8x8 CPU/GPU mesh 拓扑。 |
| `Topology::createLinks()` | `gem5/src/mem/ruby/network/Topology.cc:124` | 根据 link weight 计算每条 link 的 routing table entry。 |
| `shortest_path_to_node()` | `gem5/src/mem/ruby/network/Topology.cc:298` | 为每条物理 link 计算可达 MachineID 集合。 |
| `GarnetNetwork::makeInternalLink()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:154` | 注册内部链路和方向端口映射。 |
| `GarnetNetwork::makeOutLink()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:120` | 注册 router 到 NI 的外部端口和 MachineID 映射。 |
| `Router::addOutPort()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:888` | 保存 routing table entry 并预计算 MachineID 列表。 |

### 6.3 Escape VC 层

| 组成 | 文件位置 | 说明 |
| --- | --- | --- |
| escape flag 设置 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1971` | `routeCompute()` 根据 downstream congestion 标记 escape mode。 |
| escape route 选择 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:969` | `request_vc()` 在 escape mode 下使用 XY 路由。 |
| downstream 拥塞判断 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1407` | 跳过 VC0，检查其他 VC buffer 是否超过阈值。 |

escape VC 的目标是保留一个 deterministic、deadlock-free 的 DOR/XY 逃逸路径。就当前代码而言，escape mode 和普通 mode 都基本走 XY；区别是 escape path 更直接地在 `request_vc()` 内调用 `getRouteXY()`。

### 6.4 Inactive / 未接入的 PSO、协同和功耗感知分支

代码中存在大量高级路由组件，但当前主路径没有调用它们：

| 组成 | 文件位置 | 当前状态 |
| --- | --- | --- |
| `GarnetNetwork.routing_algorithm` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.py:68` | Python 参数存在，但 C++ Router 未读取、未分发。 |
| `enable_pso` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.py:47` | SimObject 参数存在，但 Router 构造中硬编码 `m_enable_pso = true`。 |
| `Router::getRoutePSO()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1421` | 实现了 PSO 选择逻辑，但 `request_vc()` 没有调用。 |
| `Router::runPSO()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1229` | 连续空间 PSO 路径搜索，但当前不在主路径。 |
| `PSOAlgorithm::getRoutePSO()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/PSOAlgorithm.cc:106` | 模块化 PSO 实现，编译进工程，但未被主路由入口调用。 |
| `SwarmManager` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/SwarmManager.cc:34` | 负责 swarm/group 管理，当前更多是统计或备用结构。 |
| `NetworkUtilities` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/NetworkUtilities.cc:35` | 提供坐标、邻居、fitness、link mapping 等工具函数。 |
| `GlobalGraph` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:145` | 维护 8x8 全局图；主要被 PSO/协同分支使用。 |
| `getRouteCollaborative()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:200` | 协同路由入口，但未被 `request_vc()` 选择。 |
| `getRoutePowerOptimized()` | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:4785` | 功耗感知路由入口，但未在主路径调用。 |
| `SimplifiedPSO` 声明 | `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:1209` | 有接口声明，未发现对应编译实现，也未被调用。 |

这意味着代码结构上像是“XY 主干 + 多个实验性/未接入优化分支”，而不是一个已经通过配置统一选择 TABLE/XY/RANDOM/ADAPTIVE/MVPP 的路由框架。

## 7. 主要问题与风险点

### 7.1 高优先级：`routing_algorithm` 参数未生效

`GarnetNetwork.py` 声明了：

- `routing_algorithm = Param.String("TABLE_", "Routing algorithm: TABLE_, XY_, RANDOM_, ADAPTIVE_, MVPP_MGC_PSO_")`

但没有看到该参数传入 `Router` 或在 `request_vc()` / `getRoute()` 中分发。实际效果是：无论配置写 `TABLE_`、`XY_` 还是 `MVPP_MGC_PSO_`，主路径仍然走 `getRoute()` 的 XY 逻辑。

影响：实验结果如果声称切换了路由算法，代码层面不成立。

### 7.2 高优先级：8x8 硬编码导致非 8x8 拓扑不正确

硬编码分布在多处：

- `getRouteXY()` 使用 `% 8`、`/ 8`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1398`
- `GarnetNetwork::makeInternalLink()` 使用 `% 8`、`/ 8`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:168`
- `GlobalGraph` 常量为 8x8/64：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:190`
- `GlobalGraph::initializeMesh()` 创建 64 节点：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:3733`

影响：默认 `Mesh8x8_CPU_GPU` 下成立；切换到 `Mesh_4x4`、`Mesh4x4_CPU_GPU`、普通 `Mesh` 或其他 rows/columns 时，XY 坐标计算会错误。

### 7.3 中高优先级：fallback 可能破坏严格 XY

`getRoute()` 在 XY 端口校验失败时扫描 routing table 的第一个可达端口。这个设计能提高鲁棒性，但严格意义上不再保证每次都是 XY。尤其是：

- local 端口 `m_direction_to_port[4]` 只有一个槽位；同一个 router 如果连接多个外部 controller，local 端口可能被后注册的 outport 覆盖。
- 非 8x8 拓扑下，XY 方向可能算错，fallback 会掩盖错误但不保证 XY 语义。

影响：主路径大多数情况是 XY，但存在“XY 失败后 table fallback”的非 XY 分支。

### 7.4 中优先级：`enable_pso` 参数未控制实际构造状态

`GarnetNetwork.py` 中 `GarnetRouter.enable_pso` 默认是 `False`，但 `Router` 构造函数中直接设置：

- `m_enable_pso = true`：`gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:636`

不过即便 `m_enable_pso` 为 true，主路径仍不调用 PSO。因此该变量当前同时存在两个问题：配置不生效，状态也不决定主路由算法。

### 7.5 中优先级：PSO/协同分支存在端口 ID 与节点 ID 混用风险

未接入分支中有多处需要在启用前复核：

- `Router::runPSO()` 返回 `getRouteXY(src_router, gbest_path[1])`，这是方向编码，不一定是物理 outport；但 `initPsoRoutingTable()` 将它作为 `port` 存入 routing table。
- `getRoutePSO()` 中 `global_next_hop` 来自 `optimal_path.node_sequence[1]`，语义是下一跳 node id；后续却与 `m_routing_table.size()` 比较并作为 `routingTableHasDest(global_next_hop, destination)` 的 link/port 参数使用。
- `getRouteCollaborative()` 中 `guidance.recommended_next_hop` 也需要确认语义到底是 node id、global edge id 还是 local outport。

影响：如果后续把 PSO/协同分支接入主路径，可能出现端口错误、路径不连通或 routing-table 校验误判。

### 7.6 中优先级：统计与实际算法命名不一致

`PerformanceAnalyzer` 和 Router 统计中大量描述 MVPP_MGC_PSO，但当前 active path 是 XY。比如 `getRoute()` 将 XY 统计为 traditional routing，而 `PerformanceAnalyzer` 的打印说明会强调 MVPP_MGC_PSO。若论文或实验报告直接引用这些统计名称，容易造成算法归因错误。

## 8. 对“是否真的实现 XY”的最终判断

| 判断项 | 结论 | 依据 |
| --- | --- | --- |
| 是否有 XY 核心逻辑 | 是 | `getRouteXY()` 明确先 X 后 Y。 |
| 主路径是否调用 XY | 是 | `request_vc()` 普通路径调用 `getRoute()`，`getRoute()` 调用 `getRouteXY()`。 |
| 是否严格每次都 XY | 不完全 | XY 端口不可用时会 fallback 到 table 第一个可达端口。 |
| 是否支持 4x4/可变 Mesh | 否 | 多处硬编码 8x8/64。 |
| 是否根据 `routing_algorithm` 选择算法 | 否 | Python 参数存在，但 C++ 主路径未使用。 |
| PSO/MVPP 是否实际替代 XY | 否 | 相关函数存在并编译，但未被 `request_vc()` 调用。 |

**最终结论：默认 8x8 Mesh flexible 配置下，当前代码实际运行的是 XY 路由；但它不是一个健壮、可配置、拓扑无关的 XY 路由模块，更不是已经启用的 MVPP/PSO 路由主路径。**

## 9. 建议改进

1. **显式化算法选择**：将 `routing_algorithm` 和 `enable_pso` 传入 Router，在 `request_vc()` 或专门的 `selectRoute()` 中按枚举分发到 TABLE/XY/PSO/ADAPTIVE。
2. **去除 8x8 硬编码**：把 mesh columns/rows 作为网络参数传入 Router 和 GarnetNetwork，替换所有 `% 8`、`/ 8`、`64`、`224`。
3. **区分 direction、node id、local outport**：为方向、router id、物理 outport 使用不同命名或类型封装，避免 PSO/GlobalGraph 分支混用。
4. **处理多 local 端口**：local destination 不应依赖单个 `m_direction_to_port[4]`；应直接按 `routingTableHasDest()` 查找匹配的外部端口。
5. **记录 fallback 发生次数**：如果目标是验证 XY，应统计 `xy_success_count` 与 `table_fallback_count`，避免 fallback 被误认为 XY。
6. **接入 PSO 前先补单元/仿真验证**：至少验证每个 router 到每个目标的 first-hop outport 与 routing table 一致，并验证路径连续性与死锁逃逸 VC 行为。

