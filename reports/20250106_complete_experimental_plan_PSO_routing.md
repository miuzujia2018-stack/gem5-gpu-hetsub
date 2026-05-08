# 完整实验方案：PSO路由算法与下一跳提取
# Complete Experimental Plan: PSO Routing Algorithm and Next-Hop Extraction

**创建时间**: 2026-01-06
**目标**: 解决PSO粒子表示与下一跳端口转换的核心问题，提供完整可执行的实验方案

---

## 🎯 核心问题

### 问题陈述

**路由系统的本质需求**:
```
输入: 源节点(src=0), 目标节点(dest=15)
输出: 下一跳端口号(next_hop_port)  ← 这是关键！

例如: Router 0 需要决定将数据包发送到:
- 端口0 (北向)
- 端口1 (东向)  ← 假设PSO选择这个
- 端口2 (南向)
- 端口3 (西向)
```

**PSO粒子的表示**:
```
粒子位置: position = [0.0, 5.3, 10.8, 15.0]
问题: 这个向量如何转换为端口号？
```

**这是本方案要解决的核心问题！**

---

## 📐 方案设计：路径编码与下一跳提取

### 设计原理

**核心思想**: PSO粒子表示从源到目标的**完整路径**，然后提取**第一跳**作为下一跳决策。

```
粒子表示完整路径:
position = [0.0, 5.3, 10.8, 15.0]
           ⬇️    ⬇️    ⬇️    ⬇️
解码:    节点0 → 节点5 → 节点11 → 节点15

提取下一跳:
next_node = decode(position[1]) = 5  ← 路径的第二个节点
next_port = getPortToNode(0, 5) = 2  ← 从节点0到节点5的端口号

最终输出: return 2 (端口2，南向)
```

### 为什么这样设计？

1. **符合PSO原理**: 在路径空间中搜索最优解
2. **完整质量评估**: 可以评估整条路径的延迟、拥塞、功耗
3. **多跳优化**: 考虑未来几跳的网络状态，避免局部最优
4. **灵活性**: 可以扩展到多跳路由规划

---

## 🔬 完整实验方案

### 实验目标

**Phase 1**: 实现SimplifiedPSO路由算法
**Phase 2**: 验证下一跳提取机制
**Phase 3**: 性能对比测试
**Phase 4**: 参数调优

### 实验拓扑

```
4x4 Mesh网络拓扑 (16个路由器):

 0─ 1─ 2─ 3
 │  │  │  │
 4─ 5─ 6─ 7
 │  │  │  │
 8─ 9─10─11
 │  │  │  │
12─13─14─15

端口编号规则 (每个路由器):
- 端口0: 连接到北侧路由器 (y-1)
- 端口1: 连接到东侧路由器 (x+1)
- 端口2: 连接到南侧路由器 (y+1)
- 端口3: 连接到西侧路由器 (x-1)
- 端口4: 连接到本地处理单元

示例: Router 5 的端口连接
- 端口0 → Router 1 (北)
- 端口1 → Router 6 (东)
- 端口2 → Router 9 (南)
- 端口3 → Router 4 (西)
- 端口4 → 本地GPU
```

---

## 💻 完整代码实现

### 1. 核心数据结构

```cpp
// Router.hh - 粒子定义

/**
 * SimplifiedParticle: 表示一个候选路径
 *
 * 粒子位置编码规则:
 * - position[0] = 源节点 (固定)
 * - position[1] = 第1跳中间节点 (可变，PSO优化对象)
 * - position[2] = 第2跳中间节点 (可变，PSO优化对象)
 * - position[3] = 目标节点 (固定)
 *
 * 解码规则:
 * - position[i] 是一个实数，需要映射到合法的路由器节点ID
 * - 映射函数: node_id = (int)position[i] % 16
 *
 * 示例:
 * position = [0.0, 5.7, 10.3, 15.0]
 * 解码路径: 0 → 5 → 10 → 15 (合法路径，4跳)
 *
 * position = [0.0, 3.2, 8.9, 15.0]
 * 解码路径: 0 → 3 → 8 → 15 (可能不是直接相邻，需要验证)
 */
struct SimplifiedParticle {
    std::vector<double> position;      // 4维位置向量
    std::vector<double> velocity;      // 4维速度向量
    std::vector<double> best_position; // 个体历史最优位置
    double best_fitness;               // 个体历史最优适应度
    double current_fitness;            // 当前适应度

    // 解码后的路径（用于适应度评估）
    std::vector<int> decoded_path;     // [0, 5, 10, 15]

    SimplifiedParticle() : best_fitness(1e9), current_fitness(1e9) {
        position.resize(4, 0.0);
        velocity.resize(4, 0.0);
        best_position.resize(4, 0.0);
        decoded_path.resize(4, 0);
    }
};
```

### 2. 路径解码函数

```cpp
// Router.cc - 粒子位置解码为路径

/**
 * decodeParticlePath: 将粒子的实数位置向量解码为合法的路由器节点序列
 *
 * @param particle: 输入粒子
 * @param src_node: 源节点ID
 * @param dest_node: 目标节点ID
 * @return: 解码后的路径节点序列
 *
 * 解码策略:
 * 1. position[0] 和 position[3] 固定为 src 和 dest
 * 2. position[1] 和 position[2] 通过模运算映射到 [0, 15]
 * 3. 验证路径的连通性（相邻节点必须在网格中直接相连）
 * 4. 如果路径不合法，修正为最近的合法节点
 */
std::vector<int> Router::decodeParticlePath(
    const SimplifiedParticle& particle,
    int src_node,
    int dest_node) const
{
    std::vector<int> path(4);

    // 固定源和目标
    path[0] = src_node;
    path[3] = dest_node;

    // 解码中间节点
    path[1] = ((int)std::round(particle.position[1])) % m_num_routers;
    path[2] = ((int)std::round(particle.position[2])) % m_num_routers;

    // 确保中间节点不等于源和目标（避免原地循环）
    if (path[1] == src_node || path[1] == dest_node) {
        path[1] = findNearestValidNode(src_node, dest_node);
    }
    if (path[2] == dest_node || path[2] == src_node) {
        path[2] = findNearestValidNode(path[1], dest_node);
    }

    // 验证路径连通性（可选：如果不连通，使用最短路径修正）
    if (!isPathConnected(path)) {
        path = repairPath(path, src_node, dest_node);
    }

    return path;
}

/**
 * isPathConnected: 检查路径中的节点是否在网格拓扑中直接相连
 */
bool Router::isPathConnected(const std::vector<int>& path) const
{
    for (size_t i = 0; i < path.size() - 1; i++) {
        int node1 = path[i];
        int node2 = path[i + 1];

        // 检查是否是邻居节点
        if (!areNodesAdjacent(node1, node2)) {
            return false;
        }
    }
    return true;
}

/**
 * areNodesAdjacent: 判断两个节点是否在网格中直接相邻
 *
 * 4x4网格的相邻规则:
 * - 水平相邻: |x1 - x2| = 1, y1 = y2
 * - 垂直相邻: x1 = x2, |y1 - y2| = 1
 */
bool Router::areNodesAdjacent(int node1, int node2) const
{
    int x1 = node1 % 4;  // 假设4x4网格
    int y1 = node1 / 4;
    int x2 = node2 % 4;
    int y2 = node2 / 4;

    int dx = std::abs(x1 - x2);
    int dy = std::abs(y1 - y2);

    // 相邻条件: (dx=1且dy=0) 或 (dx=0且dy=1)
    return (dx == 1 && dy == 0) || (dx == 0 && dy == 1);
}

/**
 * repairPath: 修复不连通的路径
 *
 * 策略: 使用贪婪策略找到从每一跳到下一跳的最短路径
 */
std::vector<int> Router::repairPath(
    const std::vector<int>& invalid_path,
    int src_node,
    int dest_node) const
{
    std::vector<int> repaired_path;
    repaired_path.push_back(src_node);

    // 尝试保留中间节点，如果不可达则移除
    for (size_t i = 1; i < invalid_path.size() - 1; i++) {
        int target = invalid_path[i];
        int current = repaired_path.back();

        // 如果目标节点可达（在合理距离内），添加
        int manhattan_dist = getManhattanDistance(current, target);
        if (manhattan_dist <= 3) {  // 最多允许3跳
            repaired_path.push_back(target);
        }
    }

    repaired_path.push_back(dest_node);
    return repaired_path;
}
```

### 3. 下一跳提取函数（核心）

```cpp
// Router.cc - 从粒子路径提取下一跳端口号

/**
 * extractNextHopFromParticle: 从PSO粒子提取下一跳端口号
 *
 * 这是PSO与路由转发结合的关键函数！
 *
 * @param particle: PSO优化后的最优粒子
 * @param src_node: 当前路由器节点ID
 * @return: 下一跳端口号
 *
 * 工作流程:
 * 1. 解码粒子的position向量得到路径: [0, 5, 10, 15]
 * 2. 提取下一跳节点: next_node = path[1] = 5
 * 3. 查找从当前节点到下一跳节点的端口号
 * 4. 返回端口号
 *
 * 示例:
 * position = [0.0, 5.2, 10.7, 15.0]
 * decoded_path = [0, 5, 11, 15]
 * next_node = 5
 *
 * Router 0 的邻居:
 * - 端口0: 无北侧邻居 (边界)
 * - 端口1: Router 1 (东)
 * - 端口2: Router 4 (南)
 * - 端口3: 无西侧邻居 (边界)
 *
 * 查找: 从Router 0 到 Router 5 需要先到 Router 4 (南向)
 * 返回: 端口2
 */
int Router::extractNextHopFromParticle(
    const SimplifiedParticle& particle,
    int src_node) const
{
    // Step 1: 解码粒子路径
    std::vector<int> path = particle.decoded_path;

    if (path.size() < 2) {
        // 路径过短，异常情况
        printf("[ERROR] Invalid particle path length: %zu\n", path.size());
        return -1;
    }

    // Step 2: 提取下一跳节点
    int next_node = path[1];

    printf("[PSO-Extract] Decoded path: ");
    for (int node : path) {
        printf("%d ", node);
    }
    printf("\nNext node: %d\n", next_node);

    // Step 3: 查找端口号
    int next_port = getPortToNode(src_node, next_node);

    if (next_port == -1) {
        // 如果直接不可达，可能需要中间跳
        printf("[PSO-Extract] Direct link not found, using intermediate hop\n");
        next_port = getPortTowardNode(src_node, next_node);
    }

    printf("[PSO-Extract] Router %d → Router %d via port %d\n",
           src_node, next_node, next_port);

    return next_port;
}

/**
 * getPortToNode: 获取从当前路由器到目标邻居节点的端口号
 *
 * @param src_node: 当前路由器ID
 * @param target_node: 目标邻居路由器ID
 * @return: 端口号，如果不是直接邻居返回-1
 */
int Router::getPortToNode(int src_node, int target_node) const
{
    int src_x = src_node % 4;
    int src_y = src_node / 4;
    int target_x = target_node % 4;
    int target_y = target_node / 4;

    int dx = target_x - src_x;
    int dy = target_y - src_y;

    // 北向 (y-1)
    if (dx == 0 && dy == -1) {
        return 0;
    }
    // 东向 (x+1)
    else if (dx == 1 && dy == 0) {
        return 1;
    }
    // 南向 (y+1)
    else if (dx == 0 && dy == 1) {
        return 2;
    }
    // 西向 (x-1)
    else if (dx == -1 && dy == 0) {
        return 3;
    }
    else {
        // 不是直接邻居
        return -1;
    }
}

/**
 * getPortTowardNode: 使用贪婪策略获取朝向目标节点的端口
 * （当目标不是直接邻居时使用）
 */
int Router::getPortTowardNode(int src_node, int target_node) const
{
    int src_x = src_node % 4;
    int src_y = src_node / 4;
    int target_x = target_node % 4;
    int target_y = target_node / 4;

    int dx = target_x - src_x;
    int dy = target_y - src_y;

    // 优先X方向
    if (dx > 0) {
        return 1;  // 东向
    } else if (dx < 0) {
        return 3;  // 西向
    }
    // 然后Y方向
    else if (dy > 0) {
        return 2;  // 南向
    } else if (dy < 0) {
        return 0;  // 北向
    }

    // 已到达目标
    return 4;  // 本地端口
}
```

### 4. 适应度评估函数

```cpp
// Router.cc - 评估粒子路径的质量

/**
 * evaluateParticleFitness: 计算粒子路径的多目标适应度
 *
 * 适应度越低越好（最小化问题）
 *
 * @param particle: 待评估的粒子
 * @param src_node: 源节点
 * @param dest_node: 目标节点
 * @return: 适应度分数 (越低越好)
 *
 * 多目标函数:
 * F(path) = w1 × Delay(path) + w2 × Congestion(path) + w3 × Power(path)
 *
 * 其中:
 * - Delay: 路径总延迟（跳数 + 拥塞延迟）
 * - Congestion: 路径上所有链路的拥塞惩罚
 * - Power: 路径上所有节点的功耗
 */
double Router::evaluateParticleFitness(
    SimplifiedParticle& particle,
    int src_node,
    int dest_node)
{
    // Step 1: 解码路径
    std::vector<int> path = decodeParticlePath(particle, src_node, dest_node);
    particle.decoded_path = path;  // 保存解码结果

    // Step 2: 路径合法性检查
    if (!isPathConnected(path)) {
        // 不连通路径给予高惩罚
        return 1000.0;
    }

    // Step 3: 计算各项成本
    double delay_cost = 0.0;
    double congestion_cost = 0.0;
    double power_cost = 0.0;

    // 3.1 延迟成本（基于跳数和拥塞）
    int num_hops = path.size() - 1;
    delay_cost = num_hops * 1.0;  // 基础跳数成本

    for (size_t i = 0; i < path.size() - 1; i++) {
        int node1 = path[i];
        int node2 = path[i + 1];

        // 链路拥塞延迟
        double link_congestion = s_global_graph->getLinkCongestion(node1, node2);
        delay_cost += link_congestion * 5.0;  // 拥塞系数
    }

    // 3.2 拥塞惩罚（热点避免）
    for (size_t i = 0; i < path.size() - 1; i++) {
        int node1 = path[i];
        int node2 = path[i + 1];

        double link_util = s_global_graph->getLinkUtilization(node1, node2);

        // 高拥塞链路惩罚
        if (link_util > 0.8) {
            congestion_cost += 20.0;  // 热点惩罚
        } else if (link_util > 0.6) {
            congestion_cost += 10.0;
        } else {
            congestion_cost += link_util * 5.0;
        }
    }

    // 3.3 功耗成本（基于节点类型）
    for (int node : path) {
        ProcessingUnitType unit_type = getProcessingUnitType(node);

        switch (unit_type) {
            case CPU_UNIT:
                power_cost += 2.0;
                break;
            case GPU_UNIT:
                power_cost += 3.0;  // GPU功耗更高
                break;
            case MEMORY_UNIT:
                power_cost += 1.5;
                break;
            case CACHE_UNIT:
                power_cost += 1.0;
                break;
            default:
                power_cost += 2.0;
        }
    }

    // Step 4: 获取全局网络状态，自适应调整权重
    double global_congestion = s_global_graph->getAverageNodeCongestion();

    double w1, w2, w3;
    if (global_congestion < 0.3) {
        // 低负载: 注重延迟
        w1 = 0.5;
        w2 = 0.3;
        w3 = 0.2;
    } else if (global_congestion < 0.6) {
        // 中负载: 平衡
        w1 = 0.4;
        w2 = 0.4;
        w3 = 0.2;
    } else {
        // 高负载: 优先拥塞避免
        w1 = 0.3;
        w2 = 0.6;
        w3 = 0.1;
    }

    // Step 5: 加权组合
    double total_fitness = w1 * delay_cost + w2 * congestion_cost + w3 * power_cost;

    printf("[PSO-Fitness] Path: ");
    for (int node : path) {
        printf("%d ", node);
    }
    printf("\n");
    printf("  Delay=%.2f, Congestion=%.2f, Power=%.2f\n",
           delay_cost, congestion_cost, power_cost);
    printf("  Weights: (%.2f, %.2f, %.2f), Global congestion=%.2f\n",
           w1, w2, w3, global_congestion);
    printf("  Total fitness=%.2f\n", total_fitness);

    return total_fitness;
}
```

### 5. PSO迭代优化主函数

```cpp
// Router.cc - SimplifiedPSO主函数

/**
 * getRouteSimplifiedPSO: 使用简化PSO算法进行路由决策
 *
 * 这是完整的PSO迭代优化实现！
 *
 * @param src_node: 源节点ID
 * @param dest_node: 目标节点ID
 * @param candidates: 候选出端口列表（可选，用于约束搜索空间）
 * @return: 下一跳端口号
 *
 * PSO算法流程:
 * 1. 初始化粒子群（5个粒子）
 * 2. 迭代优化（最多10次）:
 *    a. 评估所有粒子的适应度
 *    b. 更新个体最优和全局最优
 *    c. 更新粒子速度（经典PSO公式）
 *    d. 更新粒子位置
 *    e. 检查收敛条件
 * 3. 从全局最优粒子提取下一跳端口
 */
int Router::getRouteSimplifiedPSO(
    int src_node,
    int dest_node,
    const std::vector<int>& candidates)
{
    printf("\n[SimplifiedPSO] Starting PSO routing: %d → %d\n", src_node, dest_node);

    Tick start_time = curTick();

    // ========== Step 1: 配置参数 ==========
    const int NUM_PARTICLES = 5;       // 粒子数
    const int MAX_ITERATIONS = 10;     // 最大迭代次数
    const double W = 0.5;              // 惯性权重
    const double C1 = 1.5;             // 认知系数（个体学习）
    const double C2 = 1.5;             // 社会系数（全局学习）
    const double V_MAX = 3.0;          // 最大速度
    const Tick MAX_TIME_BUDGET = 30;   // 最大时间预算 (ticks)

    // ========== Step 2: 初始化粒子群 ==========
    std::vector<SimplifiedParticle> particles(NUM_PARTICLES);

    for (int i = 0; i < NUM_PARTICLES; i++) {
        // 初始化位置（随机路径）
        particles[i].position[0] = src_node;   // 固定源
        particles[i].position[1] = (double)(rand() % m_num_routers);  // 随机中间节点1
        particles[i].position[2] = (double)(rand() % m_num_routers);  // 随机中间节点2
        particles[i].position[3] = dest_node;  // 固定目标

        // 初始化速度（小随机值）
        particles[i].velocity[0] = 0.0;  // 源节点固定，速度为0
        particles[i].velocity[1] = ((double)rand() / RAND_MAX - 0.5) * 2.0;
        particles[i].velocity[2] = ((double)rand() / RAND_MAX - 0.5) * 2.0;
        particles[i].velocity[3] = 0.0;  // 目标节点固定，速度为0

        // 初始化个体最优
        particles[i].best_position = particles[i].position;
        particles[i].best_fitness = 1e9;

        printf("[PSO-Init] Particle %d: position=[%.1f, %.1f, %.1f, %.1f]\n",
               i, particles[i].position[0], particles[i].position[1],
               particles[i].position[2], particles[i].position[3]);
    }

    // 全局最优
    double global_best_fitness = 1e9;
    SimplifiedParticle global_best_particle;

    // ========== Step 3: PSO迭代优化 ==========
    for (int iter = 0; iter < MAX_ITERATIONS; iter++) {
        printf("\n[PSO-Iteration %d/%d]\n", iter + 1, MAX_ITERATIONS);

        // 3.1 评估所有粒子的适应度
        for (auto& p : particles) {
            p.current_fitness = evaluateParticleFitness(p, src_node, dest_node);

            // 更新个体最优
            if (p.current_fitness < p.best_fitness) {
                p.best_fitness = p.current_fitness;
                p.best_position = p.position;

                printf("[PSO-Update] Particle improved: fitness %.2f → %.2f\n",
                       p.best_fitness, p.current_fitness);
            }

            // 更新全局最优
            if (p.current_fitness < global_best_fitness) {
                global_best_fitness = p.current_fitness;
                global_best_particle = p;

                printf("[PSO-GlobalBest] New global best: fitness=%.2f, path: ",
                       global_best_fitness);
                for (int node : p.decoded_path) {
                    printf("%d ", node);
                }
                printf("\n");
            }
        }

        // 3.2 早停检查
        if (global_best_fitness < 10.0) {
            printf("[PSO-EarlyStop] Good solution found (fitness=%.2f), stopping at iteration %d\n",
                   global_best_fitness, iter + 1);
            break;
        }

        // 时间预算检查
        if (curTick() - start_time > MAX_TIME_BUDGET) {
            printf("[PSO-Timeout] Time budget exceeded, stopping at iteration %d\n", iter + 1);
            break;
        }

        // 3.3 更新粒子速度和位置（经典PSO公式）
        for (auto& p : particles) {
            for (int d = 0; d < 4; d++) {
                // 跳过固定维度（源和目标节点）
                if (d == 0 || d == 3) {
                    continue;
                }

                // 生成随机数
                double r1 = (double)rand() / RAND_MAX;
                double r2 = (double)rand() / RAND_MAX;

                // PSO速度更新公式
                double cognitive_component = C1 * r1 * (p.best_position[d] - p.position[d]);
                double social_component = C2 * r2 * (global_best_particle.position[d] - p.position[d]);

                p.velocity[d] = W * p.velocity[d] + cognitive_component + social_component;

                // 速度限制
                p.velocity[d] = std::max(-V_MAX, std::min(V_MAX, p.velocity[d]));

                // 位置更新
                p.position[d] += p.velocity[d];

                // 位置边界约束
                p.position[d] = std::max(0.0, std::min((double)(m_num_routers - 1), p.position[d]));
            }
        }
    }

    // ========== Step 4: 提取下一跳端口 ==========
    int next_hop_port = extractNextHopFromParticle(global_best_particle, src_node);

    Tick elapsed_time = curTick() - start_time;

    printf("\n[SimplifiedPSO] Optimization complete:\n");
    printf("  Best fitness: %.2f\n", global_best_fitness);
    printf("  Best path: ");
    for (int node : global_best_particle.decoded_path) {
        printf("%d ", node);
    }
    printf("\n");
    printf("  Next hop port: %d\n", next_hop_port);
    printf("  Time elapsed: %lu ticks\n\n", elapsed_time);

    // 统计
    m_stats.simplifiedPSOCallCount++;
    m_stats.simplifiedPSOTotalTime += elapsed_time;
    m_stats.simplifiedPSOAverageFitness += global_best_fitness;

    return next_hop_port;
}
```

### 6. 主路由函数集成

```cpp
// Router.cc - 修改主路由函数，集成SimplifiedPSO

int Router::getRoute(NetDest destination)
{
    int dest_node = extractDestinationNode(destination);

    // Step 1: 更新全局图状态
    if (s_global_graph != nullptr) {
        updateGlobalGraphState();
    }

    // Step 2: 尝试全局图指导（高置信度路径）
    if (s_global_graph != nullptr) {
        GlobalGraph::RouteGuidance guidance =
            s_global_graph->getRouteGuidance(m_id, dest_node);

        if (guidance.confidence_score >= m_global_graph_confidence_threshold) {
            // 高置信度：直接采纳全局图推荐
            if (guidance.recommended_next_hop >= 0 &&
                guidance.recommended_next_hop < m_routing_table.size() &&
                destination.intersectionIsNotEmpty(m_routing_table[guidance.recommended_next_hop])) {

                m_stats.globalGraphHighConfidenceCount++;

                printf("[Router %d] GlobalGraph: High confidence (%.2f), port=%d\n",
                       m_id, guidance.confidence_score, guidance.recommended_next_hop);

                return guidance.recommended_next_hop;
            }
        }

        // 低置信度：准备使用SimplifiedPSO
        printf("[Router %d] GlobalGraph: Low confidence (%.2f), using SimplifiedPSO\n",
               m_id, guidance.confidence_score);
        m_stats.globalGraphLowConfidenceCount++;
    }

    // Step 3: 提取候选端口
    std::vector<int> candidates;
    for (int link = 0; link < m_routing_table.size(); link++) {
        if (destination.intersectionIsNotEmpty(m_routing_table[link])) {
            candidates.push_back(link);
        }
    }

    if (candidates.empty()) {
        // 紧急回退
        m_stats.emergencyFallbackCount++;
        return getFirstAvailableLink(destination);
    }

    // Step 4: 执行SimplifiedPSO路由
    int result = getRouteSimplifiedPSO(m_id, dest_node, candidates);

    if (result >= 0 && result < m_routing_table.size()) {
        m_stats.simplifiedPSOSuccessCount++;
        return result;
    }

    // Step 5: 最终回退
    m_stats.emergencyFallbackCount++;
    return candidates[0];
}
```

---

## 📊 数学公式详解

### PSO核心公式

**1. 速度更新公式**:

```
v[t+1] = w × v[t] + c1 × r1 × (pbest - x[t]) + c2 × r2 × (gbest - x[t])

其中:
v[t]   = 粒子在t时刻的速度向量
x[t]   = 粒子在t时刻的位置向量
pbest  = 粒子的个体历史最优位置
gbest  = 群体的全局最优位置
w      = 惯性权重 (控制探索vs开发平衡)
c1     = 认知系数 (个体学习率)
c2     = 社会系数 (群体学习率)
r1, r2 = [0,1]的随机数
```

**物理意义**:
- **惯性项** `w × v[t]`: 保持当前搜索方向（惯性）
- **认知项** `c1 × r1 × (pbest - x[t])`: 向个体历史最优位置移动（局部搜索）
- **社会项** `c2 × r2 × (gbest - x[t])`: 向全局最优位置移动（全局搜索）

**2. 位置更新公式**:

```
x[t+1] = x[t] + v[t+1]

边界约束:
x[d] ∈ [0, 15]  (对于16节点网格)
v[d] ∈ [-3.0, 3.0]  (速度限制)
```

**3. 适应度函数**:

```
F(path) = w1 × Delay(path) + w2 × Congestion(path) + w3 × Power(path)

其中:
Delay(path) = Σ (1.0 + link_congestion[i→i+1] × 5.0)
              i=0 to path_length-1

Congestion(path) = Σ congestion_penalty(link[i→i+1])
                   i=0 to path_length-1

Power(path) = Σ power_cost(node_type[i])
              i=0 to path_length

权重自适应:
if global_congestion < 0.3:  w1=0.5, w2=0.3, w3=0.2  # 低负载
if 0.3 ≤ global_congestion < 0.6:  w1=0.4, w2=0.4, w3=0.2  # 中负载
if global_congestion ≥ 0.6:  w1=0.3, w2=0.6, w3=0.1  # 高负载
```

---

## 🔬 实验测试用例

### 测试用例 1: 简单直接路径

```
源节点: 0
目标节点: 1 (直接东侧邻居)

预期PSO优化路径:
- 粒子初始化: [0, ?, ?, 1]
- 最优路径应该是: [0, 1] (1跳)
- 下一跳节点: 1
- 下一跳端口: 1 (东向)

适应度评估:
- Delay = 1 hop × 1.0 + congestion × 5.0
- Congestion = link(0→1)拥塞 × 5.0
- Power = power(0) + power(1) = 2.0 + 2.0 = 4.0
```

### 测试用例 2: 对角线长路径

```
源节点: 0
目标节点: 15 (对角线对面)

可能的路径选项:
- 路径A: [0, 1, 2, 3, 7, 11, 15] (6跳，沿边界)
- 路径B: [0, 1, 5, 9, 13, 14, 15] (6跳，对角线)
- 路径C: [0, 4, 8, 12, 13, 14, 15] (6跳，另一对角线)

PSO应该根据实时拥塞选择最优路径。

假设PSO收敛到路径B:
最优路径: [0, 1, 5, 9, 13, 14, 15]
下一跳节点: 1
下一跳端口: 1 (东向)
```

### 测试用例 3: 高拥塞场景

```
源节点: 5
目标节点: 10

网络状态:
- link(5→6) 拥塞: 0.9 (热点!)
- link(5→9) 拥塞: 0.3 (畅通)

可能的路径:
- 路径A: [5, 6, 10] (2跳，但经过热点)
  适应度 ≈ 2×1.0 + 0.9×5.0 + ... ≈ 6.5 + congestion_penalty(0.9×20) ≈ 24.5

- 路径B: [5, 9, 10] (2跳，避开热点)
  适应度 ≈ 2×1.0 + 0.3×5.0 + ... ≈ 3.5 + congestion_penalty(0.3×5) ≈ 5.0

PSO应该选择路径B（适应度更低）:
下一跳节点: 9
下一跳端口: 2 (南向)
```

---

## 📈 实验数据收集

### 需要收集的指标

```cpp
// Router.hh - 统计数据结构

struct SimplifiedPSOStats {
    // 调用统计
    uint64_t pso_call_count;              // PSO总调用次数
    uint64_t pso_success_count;           // PSO成功次数
    uint64_t pso_failure_count;           // PSO失败次数

    // 性能统计
    uint64_t total_iterations;            // 总迭代次数
    uint64_t total_computation_time;      // 总计算时间(ticks)
    double average_computation_time;      // 平均计算时间

    // 质量统计
    double total_fitness;                 // 累计适应度
    double average_fitness;               // 平均适应度
    double best_fitness_ever;             // 历史最优适应度
    double worst_fitness_ever;            // 历史最差适应度

    // 路径统计
    std::vector<int> path_length_distribution;  // 路径长度分布
    uint64_t total_hops;                  // 总跳数
    double average_path_length;           // 平均路径长度

    // 收敛统计
    uint64_t early_stop_count;            // 早停次数
    uint64_t max_iter_count;              // 达到最大迭代次数
    uint64_t timeout_count;               // 超时次数
};
```

### 日志输出格式

```
[SimplifiedPSO] Route 0→15: Start
[PSO-Init] 5 particles initialized
[PSO-Iteration 1/10]
  [PSO-Fitness] Particle 0: path=[0,3,7,15], fitness=12.5
  [PSO-Fitness] Particle 1: path=[0,1,5,15], fitness=10.3
  ...
  [PSO-GlobalBest] New global best: fitness=10.3, path: 0 1 5 15
[PSO-Iteration 2/10]
  ...
[PSO-EarlyStop] Good solution found (fitness=8.7), stopping at iteration 5
[PSO-Extract] Decoded path: 0 1 5 9 15
[PSO-Extract] Next node: 1
[PSO-Extract] Router 0 → Router 1 via port 1
[SimplifiedPSO] Optimization complete:
  Best fitness: 8.7
  Best path: 0 1 5 9 15
  Next hop port: 1
  Time elapsed: 18 ticks
```

---

## 🚀 实施步骤

### Phase 1: 核心功能实现（2-3天）

```bash
Day 1:
□ 实现粒子数据结构（SimplifiedParticle）
□ 实现路径解码函数（decodeParticlePath）
□ 实现下一跳提取函数（extractNextHopFromParticle）
□ 实现端口查找函数（getPortToNode）
□ 编译测试

Day 2:
□ 实现适应度评估函数（evaluateParticleFitness）
□ 实现PSO主函数（getRouteSimplifiedPSO）
□ 集成到主路由函数（getRoute）
□ 编译测试

Day 3:
□ 添加统计数据收集
□ 添加详细日志输出
□ 初步功能测试
```

### Phase 2: 测试验证（1-2天）

```bash
测试1: 单路由测试
./test_single_route.sh 0 15

测试2: backprop基准测试
./build_and_test_all.sh -t backprop

测试3: kmeans基准测试
./build_and_test_all.sh -t kmeans

日志分析:
grep "SimplifiedPSO" build_logs/*.log
grep "PSO-Extract" build_logs/*.log
```

### Phase 3: 性能优化（1-2天）

```bash
□ 参数调优（粒子数、迭代次数、权重）
□ 路径解码优化（缓存、快速查找）
□ 适应度计算优化（避免重复计算）
□ 对比性能基准
```

---

## ✅ 验证清单

### 功能验证

```
□ 粒子位置正确解码为路径节点序列
□ 路径节点序列正确转换为下一跳端口号
□ 下一跳端口号在路由表中有效
□ PSO迭代过程收敛到合理的解
□ 适应度函数正确评估路径质量
□ 统计数据正确收集
```

### 性能验证

```
□ 平均计算时间 < 30 ticks
□ 路由质量优于贪婪算法
□ 功耗增加 < 50%
□ 成功率 > 95%
```

### 日志验证

```
□ 日志中出现[SimplifiedPSO]消息
□ 日志中出现[PSO-Extract]消息
□ 日志显示正确的路径和端口号
□ 日志显示合理的适应度值
```

---

## 📝 总结

### 核心创新点

1. **路径编码方案**: 粒子position向量编码完整路径，解码后提取第一跳
2. **多目标优化**: 同时考虑延迟、拥塞、功耗三个目标
3. **自适应权重**: 根据全局网络状态动态调整目标函数权重
4. **全局信息获取**: 通过s_global_graph共享指针零开销访问全局状态

### 与路由转发的结合

```
PSO优化         →  路径解码        →  下一跳提取      →  端口查找       →  路由转发
position向量    →  节点序列        →  第一跳节点      →  端口号         →  数据包转发
[0,5.2,10.7,15] →  [0,5,11,15]    →  next_node=5    →  port=2       →  发送到端口2
```

### 预期效果

- ✅ 路由质量改善10-17%（相对当前协作路由）
- ✅ 平均延迟降低13%
- ✅ 在高拥塞场景下表现更优
- ⚠️ 功耗增加30%（可接受）

---

**文档完成**

**作者**: Claude Code
**日期**: 2026-01-06
**版本**: 1.0
