# flexible 路由算法是否为 TB-TBP 的代码审查

## 审查结论

当前项目 `gem5/src/mem/ruby/network/garnet/flexible-pipeline/` 中的 active routing path **不是真正的 TB-TBP 路由算法**。

根据当前代码证据，flexible-pipeline 实际主路径是 **XY Dimension-Ordered Routing (XY DOR)**，并带有 routing-table fallback。项目中没有发现可识别的 TB-TBP 实现：没有 TB-TBP 命名的类/函数/配置参数，没有 task-based adaptive routing 的任务分类与决策逻辑，也没有 CPU/GPU task-aware 的 TB-TBP 端口选择流程。

如果论文、报告或实验表格把当前 flexible 路由结果称为 TB-TBP 结果，属于严重结果归因错误；若在明知当前代码只跑 XY 的情况下仍宣称为 TB-TBP，则存在高风险学术不端嫌疑。

---

## 1. 项目自述证据：当前目标是 XY baseline

`CLAUDE.md` 明确说明当前项目目标：

- `CLAUDE.md:14`：项目是 `XY Dimension-Ordered Routing (DOR) baseline`。
- `CLAUDE.md:14`：说明这是替代 MVPP_MGC_PSO 的 `pure XY DOR`，用于 performance comparison baseline。
- `CLAUDE.md:16`：说明 XY routing 是先 X 维 East/West，再 Y 维 North/South。

这与 TB-TBP 路由算法不是同一件事。TB-TBP 如果存在，应体现 task-based / adaptive / heterogeneous CPU-GPU aware 的路由决策，而不是固定 X-first/Y-second 的 DOR。

---

## 2. 未发现 TB-TBP 实现入口

对当前核心源码和配置搜索 TB-TBP 相关关键字：

- `tb-tbp`
- `tb_tbp`
- `TBTBP`
- `TBP`
- `task-based`
- `task based routing`
- `task-based adaptive routing`

在 `gem5/src`、`gem5/configs`、`gem5-gpu/configs`、`scripts`、`run.sh`、`docker_build_and_test_j64.sh` 中，没有发现可作为 TB-TBP 路由实现的类、函数或配置入口。

搜索中出现的 `ITBPtr`、`DTBPtr` 属于指令/数据 TLB 指针，与 TB-TBP 无关。

审查判断：当前代码没有命名层面的 TB-TBP 算法实现。

---

## 3. flexible 主路由入口实际调用 XY

### 3.1 VC 请求入口

`Router::request_vc()` 是 flexible router 的 VC 分配前路由决策入口。

关键代码：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:938`：进入 `Router::request_vc(..., bool escape_mode)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:943`：escape VC 分支。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:956`：escape VC 直接调用 `getRouteXY(m_id, dest_router)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:979`：普通非 escape 分支。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:980`：普通分支调用 `getRoute(destination)`。

因此 active path 是：

```text
request_vc()
  ├─ escape_mode: getRouteXY()
  └─ normal: getRoute()
```

没有 TB-TBP 分支。

### 3.2 主路由函数 `getRoute()` 是 XY

`getRoute()` 自身注释和代码都表明是 XY：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1304`：`Router::getRoute(NetDest destination)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1306`：注释为 `XY Dimension-Ordered Routing (baseline for comparison)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1339`：调用 `getRouteXY(m_id, dest_router)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1343`：将 XY direction 映射到物理端口。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1350`：检查该端口是否在 routing table 中可达。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1355`：若 XY 端口不可用，则 fallback 遍历 routing table。

核心路径是：

```text
getRoute(destination)
  -> getDestInfo(destination)
  -> MachineID -> physical router id
  -> getRouteXY(current_router, dest_router)
  -> m_direction_to_port[dir]
  -> routingTableHasDest(port, destination)
  -> return port
  -> fallback: first routing table port that has dest
```

这不是 TB-TBP。

---

## 4. `getRouteXY()` 明确实现 X-first / Y-second

关键代码：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1370`：`Router::getRouteXY(int src, int dest) const`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1372`：计算源坐标 `sx, sy`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1373`：计算目的坐标 `dx, dy`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1374`：若 `dx > sx` 返回 East。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1375`：若 `dx < sx` 返回 West。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1376`：若 `dy > sy` 返回 South。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1377`：若 `dy < sy` 返回 North。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1378`：同路由器返回 local。

这就是典型 deterministic XY DOR：先处理 X 维，再处理 Y 维。

TB-TBP 应当至少有任务类型、CPU/GPU 节点角色、任务到处理单元/通信模式的映射、基于任务/负载的 adaptive port selection 等逻辑；这些都没有出现在 active route path 中。

---

## 5. 方向到物理端口映射也是为 XY 服务

### 5.1 Router 侧声明

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:771`：注释为 `XY routing: direction-to-physical-port mapping`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:772`：方向定义 `0=North, 1=East, 2=South, 3=West, 4=Local`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh:795`：`m_direction_to_port[5]`，注释为 `XY physical port mapping`。

### 5.2 GarnetNetwork 侧注册

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:137`：注册 local/external 方向端口，注释为 `XY routing`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:167`：注册内部链路方向，注释为 `XY routing`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:168`：根据 `dest % 8 - src % 8` 计算 `dx`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:169`：根据 `dest / 8 - src / 8` 计算 `dy`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:171` 到 `174`：将 dx/dy 转成 East/West/South/North。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.cc:176`：调用 `setDirectionPort()`。

这些代码为 XY DOR 提供方向映射，不是 TB-TBP 的 task-aware mapping。

---

## 6. TB-TBP 关键机制缺失

按“TB-TBP = task-based adaptive routing for heterogeneous CPU-GPU NoC”理解，至少应看到以下机制中的一部分：

1. task 类型识别或任务 ID。
2. CPU/GPU/Memory controller 的任务角色分类。
3. task-to-destination 或 task-to-processing-unit 映射。
4. 基于任务类型选择候选路径或候选端口。
5. 基于 buffer/congestion/load 的 adaptive 端口选择。
6. TBP / TB-TBP 相关数据结构、参数、统计项。
7. 与 XY、table routing 不同的主路径分支。

当前 active path 中没有这些机制。

当前代码只做：

```text
目的 MachineID -> 目的 router id -> XY direction -> physical outport
```

这不是 task-based adaptive routing。

---

## 7. 配置参数不支持切换到 TB-TBP

`GarnetNetwork.py` 中存在一些泛化/残留参数：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.py:48`：`enable_pso = Param.Bool(False, ...)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.py:69`：`routing_algorithm = Param.String("TABLE_", ...)`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/GarnetNetwork.py:70`：说明中列出 `TABLE_, XY_, RANDOM_, ADAPTIVE_, MVPP_MGC_PSO_`。

但 C++ active route path 没有读取 `routing_algorithm` 参数来分发算法。搜索 C++ 使用情况后，只看到：

- `GarnetNetwork.py` 定义参数。
- `Router.hh` 中有 `m_enable_pso`。
- `Router.cc:4572` 在 power-optimized helper 中检查 `m_enable_pso`。

没有看到 `request_vc()` 或 `getRoute()` 根据 `routing_algorithm` 分发到 TB-TBP、adaptive 或其他算法。

审查判断：这些参数不是 TB-TBP 的可用实现入口。

---

## 8. PSO/MVPP 残留也不是 TB-TBP

当前 flexible 代码中还有大量 PSO/MVPP/GlobalGraph/DSENT/PerformanceAnalyzer 残留，例如：

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1395`：`getRoutePSO()` 直接 `return -1`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1859`：`wakeup()` 中仍有 PSO table lazy init。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc:1873`：仍调用 `syncWithGlobalGraph()`。
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/PerformanceAnalyzer.cc:360`：打印 MVPP_MGC_PSO routing 的系统配置描述。

这些残留本身已经会造成统计/文档归因混乱，但它们也不是 TB-TBP 实现。

审查判断：不能把 PSO/MVPP 残留解释为 TB-TBP。

---

## 9. 与 TB-TBP 声称相关的学术风险

### 9.1 如果只说“当前是 XY baseline”

如果论文/报告明确说：

> 当前 flexible 实现为 8x8 Mesh XY DOR baseline，用于和 TB-TBP 或其他算法比较。

那么这是与代码一致的，风险低。

### 9.2 如果说“当前 flexible 实现了 TB-TBP”

如果论文/报告声称：

> 当前 flexible 的路由算法是 TB-TBP。

则与代码证据矛盾，风险高。因为 active path 是 `request_vc()` -> `getRoute()` -> `getRouteXY()`，没有 TB-TBP 分支。

### 9.3 如果用当前 flexible 结果冒充 TB-TBP 性能结果

如果实验结果来自当前代码，却在论文/图表中标注为 TB-TBP，则属于严重结果归因错误。若存在主观明知，则可能构成学术不端。

### 9.4 如果拿当前代码与 TB-TBP 对比

可以，但必须明确：

- 当前代码是 XY baseline。
- TB-TBP 结果必须来自另一个真实实现或论文复现实验。
- 不能用当前 flexible 的 stats 代表 TB-TBP。

---

## 10. 最终审稿意见

| 审查项 | 结论 |
| --- | --- |
| flexible active route 是否为 TB-TBP | 否 |
| flexible active route 是否为 XY DOR | 是 |
| 是否存在 TB-TBP 命名实现 | 未发现 |
| 是否存在 task-based adaptive routing 主路径 | 未发现 |
| 是否存在 CPU/GPU task-aware port selection | 未发现 |
| 是否存在 routing_algorithm 参数控制 TB-TBP | 未发现 |
| 是否存在 PSO/MVPP 残留 | 是，但不是 TB-TBP |
| 若宣称当前结果为 TB-TBP 是否有学术风险 | 高 |

**最终结论：当前项目 flexible 路由算法不是真正的 TB-TBP；它实际是 XY DOR baseline 加 routing-table fallback。若将当前 flexible 运行结果标注为 TB-TBP 结果，存在严重学术诚信风险。**

---

## 11. 建议整改

1. 如果目标是 XY baseline：
   - 删除或重命名所有 TB-TBP / PSO / MVPP 相关误导性描述。
   - 在文档中明确写：`flexible-pipeline currently implements XY DOR baseline`。

2. 如果目标是真正实现 TB-TBP：
   - 新增明确的 `getRouteTBTBP()` 或等价函数。
   - 在 `request_vc()` 或 `getRoute()` 中通过参数显式分发到 TB-TBP。
   - 增加 task classification 数据结构。
   - 增加 CPU/GPU/Memory task-aware 目标/端口选择逻辑。
   - 增加 congestion/load/buffer adaptive 选择逻辑。
   - 增加 TB-TBP 专属 stats：`tbtbp_routing_count`、fallback count、task-type distribution。
   - 增加单元测试或仿真验证，证明 TB-TBP 分支被调用。

3. 如果要发表或写报告：
   - 当前结果只能标注为 `XY DOR baseline`。
   - 不应标注为 `TB-TBP`。
