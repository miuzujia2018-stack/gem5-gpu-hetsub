# SimplifiedPSO路由算法 - 渐进式实现方案
# Progressive Implementation Plan for SimplifiedPSO Routing Algorithm

**创建时间**: 2026-01-06
**设计原则**: 每个阶段独立、可编译、可验证、不影响现有系统
**总工期**: 5-7天
**风险等级**: 低（每步都有回退方案）

---

## 🎯 设计原则

### 核心原则

1. **向后兼容**: 每个阶段都不破坏现有路由功能
2. **可编译性**: 每次修改后立即编译验证
3. **可测试性**: 每个函数都可以独立测试
4. **可回退性**: 出现问题可以快速回退到上一阶段
5. **开关控制**: 新功能默认关闭，稳定后再启用

### 实施策略

```
┌─────────────────────────────────────────────────────────────┐
│  现有系统                                                    │
│  ├─ GlobalGraph (70%使用率)                                │
│  ├─ Collaborative Routing (28%使用率)                      │
│  └─ Emergency Fallback (2%使用率)                          │
│                                                              │
│  保持完全不变，继续工作！                                   │
└─────────────────────────────────────────────────────────────┘
                         │
                         │ 并行开发
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  新增SimplifiedPSO模块（通过开关控制）                      │
│  ├─ Phase 1-5: 逐步构建，默认不启用                        │
│  ├─ Phase 6: 集成到主路由，默认关闭                        │
│  └─ Phase 7: 验证后启用                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 7阶段渐进式实现方案

### Phase 1: 添加SimplifiedPSO基础数据结构 ⭐ START HERE

**目标**: 添加数据结构定义，不修改任何现有逻辑

**预计时间**: 2-3小时

#### 1.1 需要添加的内容

**文件**: `Router.hh`

**位置**: 在Router类定义之前（约第50行附近）

```cpp
// ============================================================================
// SimplifiedPSO Data Structures
// ============================================================================

/**
 * SimplifiedParticle: 表示PSO算法中的一个粒子（候选路径）
 *
 * 用途: 在SimplifiedPSO路由算法中搜索最优路径
 * 状态: Phase 1 - 数据结构定义（未使用）
 */
struct SimplifiedParticle {
    std::vector<double> position;      // 粒子位置向量 [src, hop1, hop2, dest]
    std::vector<double> velocity;      // 粒子速度向量
    std::vector<double> best_position; // 个体历史最优位置
    double best_fitness;               // 个体历史最优适应度
    double current_fitness;            // 当前适应度
    std::vector<int> decoded_path;     // 解码后的路径节点序列

    SimplifiedParticle() : best_fitness(1e9), current_fitness(1e9) {
        position.resize(4, 0.0);
        velocity.resize(4, 0.0);
        best_position.resize(4, 0.0);
        decoded_path.resize(4, 0);
    }
};

/**
 * SimplifiedPSOConfig: SimplifiedPSO算法的配置参数
 */
struct SimplifiedPSOConfig {
    bool enable;                    // 是否启用SimplifiedPSO（默认false）
    int num_particles;              // 粒子数量（默认5）
    int max_iterations;             // 最大迭代次数（默认10）
    double inertia_weight;          // 惯性权重（默认0.5）
    double cognitive_coeff;         // 认知系数（默认1.5）
    double social_coeff;            // 社会系数（默认1.5）
    double max_velocity;            // 最大速度（默认3.0）
    Tick max_time_budget;           // 最大时间预算（默认30 ticks）

    SimplifiedPSOConfig()
        : enable(false),            // ← 默认关闭，关键！
          num_particles(5),
          max_iterations(10),
          inertia_weight(0.5),
          cognitive_coeff(1.5),
          social_coeff(1.5),
          max_velocity(3.0),
          max_time_budget(30) {}
};

/**
 * SimplifiedPSOStats: SimplifiedPSO运行统计
 */
struct SimplifiedPSOStats {
    uint64_t call_count;            // 调用次数
    uint64_t success_count;         // 成功次数
    uint64_t failure_count;         // 失败次数
    uint64_t total_iterations;      // 总迭代次数
    uint64_t total_time;            // 总时间(ticks)
    double total_fitness;           // 累计适应度
    uint64_t early_stop_count;      // 早停次数
    uint64_t timeout_count;         // 超时次数

    SimplifiedPSOStats() { reset(); }

    void reset() {
        call_count = 0;
        success_count = 0;
        failure_count = 0;
        total_iterations = 0;
        total_time = 0;
        total_fitness = 0.0;
        early_stop_count = 0;
        timeout_count = 0;
    }

    double getAverageTime() const {
        return (call_count > 0) ? (double)total_time / call_count : 0.0;
    }

    double getAverageFitness() const {
        return (call_count > 0) ? total_fitness / call_count : 0.0;
    }
};
```

**文件**: `Router.hh` - Router类定义中

**位置**: Router类的private成员区域（约第200行附近）

```cpp
class Router : public BasicRouter, public FlexibleConsumer {
private:
    // ... 现有成员变量 ...

    // ========== SimplifiedPSO相关成员（Phase 1）==========
    SimplifiedPSOConfig m_simplified_pso_config;  // SimplifiedPSO配置
    SimplifiedPSOStats m_simplified_pso_stats;    // SimplifiedPSO统计数据

    // 注意：这些成员变量添加后不会影响现有功能，因为默认不使用

public:
    // ... 现有公共接口 ...

    // ========== SimplifiedPSO相关接口（Phase 1）==========
    // 暂时不添加任何函数声明，只添加数据结构
};
```

#### 1.2 编译验证

```bash
# Step 1: 修改Router.hh
# Step 2: 编译测试
cd /home/siat/gem5-gpu-bak/
./build_and_test_all.sh -b

# 预期结果:
# ✅ 编译成功（没有错误）
# ✅ 没有警告（新增的数据结构未使用）
# ✅ 现有系统完全不受影响
```

#### 1.3 验证清单

```
□ Router.hh成功添加SimplifiedParticle结构体
□ Router.hh成功添加SimplifiedPSOConfig结构体
□ Router.hh成功添加SimplifiedPSOStats结构体
□ Router类成功添加两个成员变量
□ 编译成功，无错误
□ 编译无警告（或只有未使用变量警告，可忽略）
```

#### 1.4 回退方案

如果出现问题，直接删除添加的代码即可：
```bash
git checkout Router.hh  # 回退到修改前
```

---

### Phase 2: 实现路径解码和验证函数

**目标**: 实现工具函数，可以独立测试，不影响路由决策

**预计时间**: 3-4小时

#### 2.1 需要添加的函数声明

**文件**: `Router.hh` - Router类private区域

```cpp
class Router : public BasicRouter, public FlexibleConsumer {
private:
    // ... Phase 1的成员变量 ...

    // ========== SimplifiedPSO工具函数声明（Phase 2）==========

    /**
     * 路径解码和验证函数（不影响路由决策，纯工具函数）
     */
    std::vector<int> decodeParticlePath(
        const SimplifiedParticle& particle,
        int src_node,
        int dest_node) const;

    bool isPathConnected(const std::vector<int>& path) const;

    bool areNodesAdjacent(int node1, int node2) const;

    std::vector<int> repairPath(
        const std::vector<int>& invalid_path,
        int src_node,
        int dest_node) const;

    int findNearestValidNode(int from_node, int avoid_node) const;

    int getManhattanDistance(int node1, int node2) const;
};
```

#### 2.2 需要添加的函数实现

**文件**: `Router.cc` - 文件末尾添加新section

```cpp
// ============================================================================
// SimplifiedPSO Implementation - Phase 2: Path Decoding and Validation
// ============================================================================

/**
 * decodeParticlePath: 将粒子的实数位置向量解码为合法的路由器节点序列
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

    // 解码中间节点（使用模运算映射到合法范围）
    path[1] = ((int)std::round(particle.position[1])) % m_num_routers;
    path[2] = ((int)std::round(particle.position[2])) % m_num_routers;

    // 确保中间节点不等于源和目标
    if (path[1] == src_node || path[1] == dest_node) {
        path[1] = findNearestValidNode(src_node, dest_node);
    }
    if (path[2] == dest_node || path[2] == src_node) {
        path[2] = findNearestValidNode(path[1], dest_node);
    }

    // 验证路径连通性
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

        if (!areNodesAdjacent(node1, node2)) {
            return false;
        }
    }
    return true;
}

/**
 * areNodesAdjacent: 判断两个节点是否在网格中直接相邻
 */
bool Router::areNodesAdjacent(int node1, int node2) const
{
    // 假设4x4网格拓扑
    int x1 = node1 % 4;
    int y1 = node1 / 4;
    int x2 = node2 % 4;
    int y2 = node2 / 4;

    int dx = std::abs(x1 - x2);
    int dy = std::abs(y1 - y2);

    // 相邻条件: (dx=1且dy=0) 或 (dx=0且dy=1)
    return (dx == 1 && dy == 0) || (dx == 0 && dy == 1);
}

/**
 * repairPath: 修复不连通的路径（使用贪婪策略）
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

        int manhattan_dist = getManhattanDistance(current, target);
        if (manhattan_dist <= 3) {  // 最多允许3跳
            repaired_path.push_back(target);
        }
    }

    repaired_path.push_back(dest_node);
    return repaired_path;
}

/**
 * findNearestValidNode: 找到距离from_node最近且不是avoid_node的节点
 */
int Router::findNearestValidNode(int from_node, int avoid_node) const
{
    int best_node = from_node;
    int min_distance = 1000;

    for (int node = 0; node < m_num_routers; node++) {
        if (node == from_node || node == avoid_node) {
            continue;
        }

        int dist = getManhattanDistance(from_node, node);
        if (dist < min_distance) {
            min_distance = dist;
            best_node = node;
        }
    }

    return best_node;
}

/**
 * getManhattanDistance: 计算两个节点的曼哈顿距离
 */
int Router::getManhattanDistance(int node1, int node2) const
{
    int x1 = node1 % 4;
    int y1 = node1 / 4;
    int x2 = node2 % 4;
    int y2 = node2 / 4;

    return std::abs(x1 - x2) + std::abs(y1 - y2);
}
```

#### 2.3 编译和单元测试

**编译验证**:
```bash
./build_and_test_all.sh -b

# 预期结果:
# ✅ 编译成功
# ⚠️ 可能有"未使用函数"警告（正常，Phase 5才会使用）
```

**单元测试**（可选，在Router.cc中临时添加测试代码）:

```cpp
// 临时测试代码（在Router构造函数中添加，测试后删除）
void Router::testPhase2Functions()
{
    printf("\n[Phase2-Test] Testing path decoding functions...\n");

    // 测试1: areNodesAdjacent
    assert(areNodesAdjacent(0, 1) == true);   // 0和1相邻（东西）
    assert(areNodesAdjacent(0, 4) == true);   // 0和4相邻（南北）
    assert(areNodesAdjacent(0, 5) == false);  // 0和5不相邻
    printf("[Phase2-Test] areNodesAdjacent: PASSED\n");

    // 测试2: getManhattanDistance
    assert(getManhattanDistance(0, 0) == 0);
    assert(getManhattanDistance(0, 1) == 1);
    assert(getManhattanDistance(0, 15) == 6);  // 对角线
    printf("[Phase2-Test] getManhattanDistance: PASSED\n");

    // 测试3: decodeParticlePath
    SimplifiedParticle test_particle;
    test_particle.position = {0.0, 5.0, 10.0, 15.0};
    std::vector<int> path = decodeParticlePath(test_particle, 0, 15);
    printf("[Phase2-Test] Decoded path: ");
    for (int node : path) {
        printf("%d ", node);
    }
    printf("\n");

    printf("[Phase2-Test] All tests PASSED!\n\n");
}
```

#### 2.4 验证清单

```
□ Router.hh成功添加6个函数声明
□ Router.cc成功实现6个函数
□ 编译成功
□ 单元测试通过（可选）
□ 现有路由功能不受影响
```

---

### Phase 3: 实现端口查找函数

**目标**: 实现从节点到端口的映射函数

**预计时间**: 2-3小时

#### 3.1 函数声明

**文件**: `Router.hh`

```cpp
class Router : public BasicRouter, public FlexibleConsumer {
private:
    // ... Phase 2的函数 ...

    // ========== SimplifiedPSO端口查找函数（Phase 3）==========

    int extractNextHopFromParticle(
        const SimplifiedParticle& particle,
        int src_node) const;

    int getPortToNode(int src_node, int target_node) const;

    int getPortTowardNode(int src_node, int target_node) const;
};
```

#### 3.2 函数实现

**文件**: `Router.cc`

```cpp
// ============================================================================
// SimplifiedPSO Implementation - Phase 3: Port Lookup Functions
// ============================================================================

/**
 * extractNextHopFromParticle: 从PSO粒子提取下一跳端口号
 *
 * 这是PSO与路由转发结合的关键函数！
 */
int Router::extractNextHopFromParticle(
    const SimplifiedParticle& particle,
    int src_node) const
{
    // Step 1: 获取解码后的路径
    const std::vector<int>& path = particle.decoded_path;

    if (path.size() < 2) {
        printf("[PSO-Extract-ERROR] Invalid path length: %zu\n", path.size());
        return -1;
    }

    // Step 2: 提取下一跳节点
    int next_node = path[1];

    printf("[PSO-Extract] Path: ");
    for (int node : path) {
        printf("%d ", node);
    }
    printf("-> Next node: %d\n", next_node);

    // Step 3: 查找端口号
    int next_port = getPortToNode(src_node, next_node);

    if (next_port == -1) {
        // 如果不是直接邻居，使用朝向策略
        printf("[PSO-Extract] Not direct neighbor, using toward strategy\n");
        next_port = getPortTowardNode(src_node, next_node);
    }

    printf("[PSO-Extract] Router %d -> Router %d via port %d\n",
           src_node, next_node, next_port);

    return next_port;
}

/**
 * getPortToNode: 获取从当前路由器到目标邻居节点的端口号
 */
int Router::getPortToNode(int src_node, int target_node) const
{
    // 假设4x4网格拓扑
    int src_x = src_node % 4;
    int src_y = src_node / 4;
    int target_x = target_node % 4;
    int target_y = target_node / 4;

    int dx = target_x - src_x;
    int dy = target_y - src_y;

    // 端口映射:
    // 端口0: 北向 (y-1)
    // 端口1: 东向 (x+1)
    // 端口2: 南向 (y+1)
    // 端口3: 西向 (x-1)

    if (dx == 0 && dy == -1) {
        return 0;  // 北向
    } else if (dx == 1 && dy == 0) {
        return 1;  // 东向
    } else if (dx == 0 && dy == 1) {
        return 2;  // 南向
    } else if (dx == -1 && dy == 0) {
        return 3;  // 西向
    } else {
        // 不是直接邻居
        return -1;
    }
}

/**
 * getPortTowardNode: 使用贪婪策略获取朝向目标节点的端口
 */
int Router::getPortTowardNode(int src_node, int target_node) const
{
    int src_x = src_node % 4;
    int src_y = src_node / 4;
    int target_x = target_node % 4;
    int target_y = target_node / 4;

    int dx = target_x - src_x;
    int dy = target_y - src_y;

    // 优先X方向（东西）
    if (dx > 0) {
        return 1;  // 东向
    } else if (dx < 0) {
        return 3;  // 西向
    }
    // 然后Y方向（南北）
    else if (dy > 0) {
        return 2;  // 南向
    } else if (dy < 0) {
        return 0;  // 北向
    }

    // 已到达目标
    return 4;  // 本地端口
}
```

#### 3.3 单元测试

```cpp
// 临时测试代码
void Router::testPhase3Functions()
{
    printf("\n[Phase3-Test] Testing port lookup functions...\n");

    // 测试1: getPortToNode（直接邻居）
    assert(getPortToNode(5, 1) == 0);  // 5->1: 北向
    assert(getPortToNode(5, 6) == 1);  // 5->6: 东向
    assert(getPortToNode(5, 9) == 2);  // 5->9: 南向
    assert(getPortToNode(5, 4) == 3);  // 5->4: 西向
    assert(getPortToNode(5, 10) == -1); // 5->10: 不相邻
    printf("[Phase3-Test] getPortToNode: PASSED\n");

    // 测试2: getPortTowardNode（贪婪方向）
    assert(getPortTowardNode(0, 15) == 1);  // 0->15: 先东向
    assert(getPortTowardNode(3, 12) == 3);  // 3->12: 先西向
    printf("[Phase3-Test] getPortTowardNode: PASSED\n");

    // 测试3: extractNextHopFromParticle
    SimplifiedParticle test_particle;
    test_particle.decoded_path = {0, 1, 6, 15};
    int port = extractNextHopFromParticle(test_particle, 0);
    assert(port == 1);  // 0->1应该是端口1（东向）
    printf("[Phase3-Test] extractNextHopFromParticle: PASSED\n");

    printf("[Phase3-Test] All tests PASSED!\n\n");
}
```

#### 3.4 编译验证

```bash
./build_and_test_all.sh -b

# 预期结果:
# ✅ 编译成功
# ✅ 单元测试通过
```

---

### Phase 4: 实现适应度评估函数

**目标**: 实现路径质量评估函数，独立于路由决策

**预计时间**: 3-4小时

#### 4.1 函数声明

**文件**: `Router.hh`

```cpp
class Router : public BasicRouter, public FlexibleConsumer {
private:
    // ... Phase 3的函数 ...

    // ========== SimplifiedPSO适应度评估（Phase 4）==========

    double evaluateParticleFitness(
        SimplifiedParticle& particle,
        int src_node,
        int dest_node);

    double calculateDelayCost(const std::vector<int>& path) const;

    double calculateCongestionCost(const std::vector<int>& path) const;

    double calculatePowerCost(const std::vector<int>& path) const;

    void getAdaptiveWeights(double global_congestion,
                           double& w1, double& w2, double& w3) const;
};
```

#### 4.2 函数实现

**文件**: `Router.cc`

```cpp
// ============================================================================
// SimplifiedPSO Implementation - Phase 4: Fitness Evaluation
// ============================================================================

/**
 * evaluateParticleFitness: 计算粒子路径的多目标适应度
 */
double Router::evaluateParticleFitness(
    SimplifiedParticle& particle,
    int src_node,
    int dest_node)
{
    // Step 1: 解码路径
    std::vector<int> path = decodeParticlePath(particle, src_node, dest_node);
    particle.decoded_path = path;

    // Step 2: 路径合法性检查
    if (!isPathConnected(path)) {
        return 1000.0;  // 不连通路径高惩罚
    }

    // Step 3: 计算各项成本
    double delay_cost = calculateDelayCost(path);
    double congestion_cost = calculateCongestionCost(path);
    double power_cost = calculatePowerCost(path);

    // Step 4: 获取全局网络状态，自适应调整权重
    double global_congestion = (s_global_graph != nullptr) ?
        s_global_graph->getAverageNodeCongestion() : 0.3;

    double w1, w2, w3;
    getAdaptiveWeights(global_congestion, w1, w2, w3);

    // Step 5: 加权组合
    double total_fitness = w1 * delay_cost +
                          w2 * congestion_cost +
                          w3 * power_cost;

    printf("[PSO-Fitness] Path: ");
    for (int node : path) {
        printf("%d ", node);
    }
    printf("\n");
    printf("  Delay=%.2f, Congestion=%.2f, Power=%.2f\n",
           delay_cost, congestion_cost, power_cost);
    printf("  Weights: (%.2f, %.2f, %.2f), Fitness=%.2f\n",
           w1, w2, w3, total_fitness);

    return total_fitness;
}

/**
 * calculateDelayCost: 计算路径延迟成本
 */
double Router::calculateDelayCost(const std::vector<int>& path) const
{
    double delay = 0.0;

    // 基础跳数成本
    int num_hops = path.size() - 1;
    delay = num_hops * 1.0;

    // 链路拥塞延迟
    if (s_global_graph != nullptr) {
        for (size_t i = 0; i < path.size() - 1; i++) {
            int node1 = path[i];
            int node2 = path[i + 1];

            double link_congestion = s_global_graph->getLinkCongestion(node1, node2);
            delay += link_congestion * 5.0;
        }
    }

    return delay;
}

/**
 * calculateCongestionCost: 计算拥塞惩罚
 */
double Router::calculateCongestionCost(const std::vector<int>& path) const
{
    double congestion = 0.0;

    if (s_global_graph != nullptr) {
        for (size_t i = 0; i < path.size() - 1; i++) {
            int node1 = path[i];
            int node2 = path[i + 1];

            double link_util = s_global_graph->getLinkUtilization(node1, node2);

            // 热点链路惩罚
            if (link_util > 0.8) {
                congestion += 20.0;
            } else if (link_util > 0.6) {
                congestion += 10.0;
            } else {
                congestion += link_util * 5.0;
            }
        }
    }

    return congestion;
}

/**
 * calculatePowerCost: 计算功耗成本
 */
double Router::calculatePowerCost(const std::vector<int>& path) const
{
    double power = 0.0;

    for (int node : path) {
        ProcessingUnitType unit_type = getProcessingUnitType(node);

        switch (unit_type) {
            case CPU_UNIT:
                power += 2.0;
                break;
            case GPU_UNIT:
                power += 3.0;
                break;
            case MEMORY_UNIT:
                power += 1.5;
                break;
            case CACHE_UNIT:
                power += 1.0;
                break;
            default:
                power += 2.0;
        }
    }

    return power;
}

/**
 * getAdaptiveWeights: 根据全局拥塞自适应调整权重
 */
void Router::getAdaptiveWeights(double global_congestion,
                               double& w1, double& w2, double& w3) const
{
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
}
```

#### 4.3 单元测试

```cpp
void Router::testPhase4Functions()
{
    printf("\n[Phase4-Test] Testing fitness evaluation...\n");

    SimplifiedParticle test_particle;
    test_particle.position = {0.0, 1.0, 5.0, 15.0};

    double fitness = evaluateParticleFitness(test_particle, 0, 15);

    printf("[Phase4-Test] Fitness: %.2f\n", fitness);
    assert(fitness > 0.0 && fitness < 1000.0);  // 合理范围

    printf("[Phase4-Test] All tests PASSED!\n\n");
}
```

#### 4.4 编译验证

```bash
./build_and_test_all.sh -b
```

---

### Phase 5: 实现PSO核心迭代函数

**目标**: 实现完整的PSO算法，但不集成到路由决策

**预计时间**: 4-5小时

#### 5.1 函数声明

**文件**: `Router.hh`

```cpp
class Router : public BasicRouter, public FlexibleConsumer {
private:
    // ... Phase 4的函数 ...

    // ========== SimplifiedPSO核心算法（Phase 5）==========

    int getRouteSimplifiedPSO(
        int src_node,
        int dest_node,
        const std::vector<int>& candidates);

    void initializeParticle(SimplifiedParticle& particle,
                           int src_node,
                           int dest_node);

    void updateParticleVelocity(SimplifiedParticle& particle,
                               const SimplifiedParticle& global_best);

    void updateParticlePosition(SimplifiedParticle& particle,
                               int src_node,
                               int dest_node);

    bool checkEarlyTermination(Tick start_time,
                              int iteration,
                              double best_fitness) const;
};
```

#### 5.2 完整PSO实现

**文件**: `Router.cc`

```cpp
// ============================================================================
// SimplifiedPSO Implementation - Phase 5: Core PSO Algorithm
// ============================================================================

/**
 * getRouteSimplifiedPSO: 使用简化PSO算法进行路由决策
 *
 * 注意: Phase 5阶段此函数不会被调用，仅编译验证
 */
int Router::getRouteSimplifiedPSO(
    int src_node,
    int dest_node,
    const std::vector<int>& candidates)
{
    printf("\n[SimplifiedPSO] Starting optimization: %d -> %d\n",
           src_node, dest_node);

    Tick start_time = curTick();

    // 配置参数
    const int NUM_PARTICLES = m_simplified_pso_config.num_particles;
    const int MAX_ITERATIONS = m_simplified_pso_config.max_iterations;

    // 初始化粒子群
    std::vector<SimplifiedParticle> particles(NUM_PARTICLES);
    for (int i = 0; i < NUM_PARTICLES; i++) {
        initializeParticle(particles[i], src_node, dest_node);
    }

    // 全局最优
    double global_best_fitness = 1e9;
    SimplifiedParticle global_best_particle;

    // PSO迭代循环
    for (int iter = 0; iter < MAX_ITERATIONS; iter++) {
        printf("[PSO-Iteration %d/%d]\n", iter + 1, MAX_ITERATIONS);

        // 评估所有粒子
        for (auto& p : particles) {
            p.current_fitness = evaluateParticleFitness(p, src_node, dest_node);

            // 更新个体最优
            if (p.current_fitness < p.best_fitness) {
                p.best_fitness = p.current_fitness;
                p.best_position = p.position;
            }

            // 更新全局最优
            if (p.current_fitness < global_best_fitness) {
                global_best_fitness = p.current_fitness;
                global_best_particle = p;

                printf("[PSO-GlobalBest] New best: fitness=%.2f\n",
                       global_best_fitness);
            }
        }

        // 早停检查
        if (checkEarlyTermination(start_time, iter, global_best_fitness)) {
            m_simplified_pso_stats.early_stop_count++;
            break;
        }

        // 更新粒子速度和位置
        for (auto& p : particles) {
            updateParticleVelocity(p, global_best_particle);
            updateParticlePosition(p, src_node, dest_node);
        }
    }

    // 提取下一跳端口
    int next_hop_port = extractNextHopFromParticle(global_best_particle, src_node);

    Tick elapsed = curTick() - start_time;

    printf("[SimplifiedPSO] Complete: fitness=%.2f, port=%d, time=%lu ticks\n\n",
           global_best_fitness, next_hop_port, elapsed);

    // 统计
    m_simplified_pso_stats.call_count++;
    m_simplified_pso_stats.total_time += elapsed;
    m_simplified_pso_stats.total_fitness += global_best_fitness;

    if (next_hop_port >= 0) {
        m_simplified_pso_stats.success_count++;
    } else {
        m_simplified_pso_stats.failure_count++;
    }

    return next_hop_port;
}

/**
 * initializeParticle: 初始化粒子
 */
void Router::initializeParticle(SimplifiedParticle& particle,
                               int src_node,
                               int dest_node)
{
    // 固定源和目标
    particle.position[0] = src_node;
    particle.position[1] = (double)(rand() % m_num_routers);
    particle.position[2] = (double)(rand() % m_num_routers);
    particle.position[3] = dest_node;

    // 初始化速度
    particle.velocity[0] = 0.0;
    particle.velocity[1] = ((double)rand() / RAND_MAX - 0.5) * 2.0;
    particle.velocity[2] = ((double)rand() / RAND_MAX - 0.5) * 2.0;
    particle.velocity[3] = 0.0;

    // 初始化最优
    particle.best_position = particle.position;
    particle.best_fitness = 1e9;
}

/**
 * updateParticleVelocity: 更新粒子速度（经典PSO公式）
 */
void Router::updateParticleVelocity(SimplifiedParticle& particle,
                                   const SimplifiedParticle& global_best)
{
    const double W = m_simplified_pso_config.inertia_weight;
    const double C1 = m_simplified_pso_config.cognitive_coeff;
    const double C2 = m_simplified_pso_config.social_coeff;
    const double V_MAX = m_simplified_pso_config.max_velocity;

    for (int d = 0; d < 4; d++) {
        // 跳过固定维度
        if (d == 0 || d == 3) {
            continue;
        }

        double r1 = (double)rand() / RAND_MAX;
        double r2 = (double)rand() / RAND_MAX;

        // PSO速度更新公式
        double cognitive = C1 * r1 * (particle.best_position[d] - particle.position[d]);
        double social = C2 * r2 * (global_best.position[d] - particle.position[d]);

        particle.velocity[d] = W * particle.velocity[d] + cognitive + social;

        // 速度限制
        particle.velocity[d] = std::max(-V_MAX, std::min(V_MAX, particle.velocity[d]));
    }
}

/**
 * updateParticlePosition: 更新粒子位置
 */
void Router::updateParticlePosition(SimplifiedParticle& particle,
                                   int src_node,
                                   int dest_node)
{
    for (int d = 0; d < 4; d++) {
        if (d == 0 || d == 3) {
            continue;  // 保持源和目标固定
        }

        // 位置更新
        particle.position[d] += particle.velocity[d];

        // 边界约束
        particle.position[d] = std::max(0.0,
            std::min((double)(m_num_routers - 1), particle.position[d]));
    }
}

/**
 * checkEarlyTermination: 检查早停条件
 */
bool Router::checkEarlyTermination(Tick start_time,
                                  int iteration,
                                  double best_fitness) const
{
    // 条件1: 适应度足够好
    if (best_fitness < 10.0) {
        printf("[PSO-EarlyStop] Good solution found\n");
        return true;
    }

    // 条件2: 时间预算耗尽
    Tick elapsed = curTick() - start_time;
    if (elapsed > m_simplified_pso_config.max_time_budget) {
        printf("[PSO-Timeout] Time budget exceeded\n");
        return true;
    }

    return false;
}
```

#### 5.3 编译验证

```bash
./build_and_test_all.sh -b

# 预期结果:
# ✅ 编译成功
# ✅ 没有运行时输出（因为getRouteSimplifiedPSO未被调用）
```

#### 5.4 独立测试（可选）

可以在Router构造函数中临时添加测试：

```cpp
void Router::testPhase5PSO()
{
    printf("\n[Phase5-Test] Testing complete PSO algorithm...\n");

    std::vector<int> dummy_candidates = {0, 1, 2, 3};
    int result = getRouteSimplifiedPSO(0, 15, dummy_candidates);

    printf("[Phase5-Test] PSO returned port: %d\n", result);
    assert(result >= 0 && result <= 4);

    printf("[Phase5-Test] All tests PASSED!\n\n");
}
```

---

### Phase 6: 添加开关控制，集成到主路由函数

**目标**: 集成SimplifiedPSO到主路由，但默认关闭

**预计时间**: 2-3小时

#### 6.1 修改构造函数初始化

**文件**: `Router.cc` - Router构造函数

```cpp
Router::Router(const Params *p)
    : BasicRouter(p), FlexibleConsumer(this)
{
    // ... 现有初始化代码 ...

    // ========== SimplifiedPSO初始化（Phase 6）==========

    // 配置初始化（默认关闭）
    m_simplified_pso_config.enable = false;  // ← 关键：默认关闭！
    m_simplified_pso_config.num_particles = 5;
    m_simplified_pso_config.max_iterations = 10;
    m_simplified_pso_config.inertia_weight = 0.5;
    m_simplified_pso_config.cognitive_coeff = 1.5;
    m_simplified_pso_config.social_coeff = 1.5;
    m_simplified_pso_config.max_velocity = 3.0;
    m_simplified_pso_config.max_time_budget = 30;

    // 统计初始化
    m_simplified_pso_stats.reset();

    // 从环境变量读取开关（可选）
    const char* enable_pso_env = getenv("ENABLE_SIMPLIFIED_PSO");
    if (enable_pso_env != nullptr && std::string(enable_pso_env) == "1") {
        m_simplified_pso_config.enable = true;
        printf("[Router %d] SimplifiedPSO ENABLED via environment variable\n", m_id);
    }

    printf("[Router %d] SimplifiedPSO initialized (enable=%d)\n",
           m_id, m_simplified_pso_config.enable);
}
```

#### 6.2 集成到主路由函数

**文件**: `Router.cc` - 修改getRoute()函数

```cpp
int Router::getRoute(NetDest destination)
{
    int dest_node = extractDestinationNode(destination);

    // Step 1: 更新全局图状态
    if (s_global_graph != nullptr) {
        updateGlobalGraphState();
    }

    // Step 2: 尝试全局图指导（高置信度）
    if (s_global_graph != nullptr) {
        GlobalGraph::RouteGuidance guidance =
            s_global_graph->getRouteGuidance(m_id, dest_node);

        if (guidance.confidence_score >= m_global_graph_confidence_threshold) {
            if (guidance.recommended_next_hop >= 0 &&
                guidance.recommended_next_hop < m_routing_table.size() &&
                destination.intersectionIsNotEmpty(m_routing_table[guidance.recommended_next_hop])) {

                // 高置信度：直接采纳
                return guidance.recommended_next_hop;
            }
        }

        // ========== Phase 6: SimplifiedPSO集成点 ==========
        // 低置信度：检查是否启用SimplifiedPSO
        if (m_simplified_pso_config.enable) {
            printf("[Router %d] Low confidence (%.2f), trying SimplifiedPSO\n",
                   m_id, guidance.confidence_score);

            // 提取候选端口
            std::vector<int> candidates;
            for (int link = 0; link < m_routing_table.size(); link++) {
                if (destination.intersectionIsNotEmpty(m_routing_table[link])) {
                    candidates.push_back(link);
                }
            }

            if (!candidates.empty()) {
                int pso_result = getRouteSimplifiedPSO(m_id, dest_node, candidates);

                if (pso_result >= 0 && pso_result < m_routing_table.size()) {
                    return pso_result;
                }
            }
        }
    }

    // Step 3: 回退到原有的协作路由（保持现有逻辑完全不变）
    return getRouteCollaborative(destination);
}
```

#### 6.3 添加统计输出函数

**文件**: `Router.hh`

```cpp
class Router : public BasicRouter, public FlexibleConsumer {
public:
    // ========== SimplifiedPSO统计接口（Phase 6）==========

    void printSimplifiedPSOStats() const;
    SimplifiedPSOStats getSimplifiedPSOStats() const { return m_simplified_pso_stats; }
};
```

**文件**: `Router.cc`

```cpp
void Router::printSimplifiedPSOStats() const
{
    if (m_simplified_pso_stats.call_count == 0) {
        printf("[Router %d] SimplifiedPSO: Not used\n", m_id);
        return;
    }

    printf("\n[Router %d] SimplifiedPSO Statistics:\n", m_id);
    printf("  Total calls: %lu\n", m_simplified_pso_stats.call_count);
    printf("  Success: %lu (%.1f%%)\n",
           m_simplified_pso_stats.success_count,
           100.0 * m_simplified_pso_stats.success_count / m_simplified_pso_stats.call_count);
    printf("  Failure: %lu\n", m_simplified_pso_stats.failure_count);
    printf("  Average time: %.2f ticks\n", m_simplified_pso_stats.getAverageTime());
    printf("  Average fitness: %.2f\n", m_simplified_pso_stats.getAverageFitness());
    printf("  Early stops: %lu\n", m_simplified_pso_stats.early_stop_count);
    printf("  Timeouts: %lu\n", m_simplified_pso_stats.timeout_count);
    printf("\n");
}
```

#### 6.4 编译和功能验证

**编译**:
```bash
./build_and_test_all.sh -b

# 预期结果:
# ✅ 编译成功
```

**运行测试（SimplifiedPSO默认关闭）**:
```bash
./build_and_test_all.sh -t backprop

# 预期结果:
# ✅ 测试通过
# ✅ 日志中显示"SimplifiedPSO initialized (enable=0)"
# ✅ 没有SimplifiedPSO相关的路由日志
# ✅ 性能与Phase 5之前完全一致
```

**临时启用SimplifiedPSO测试（可选）**:
```bash
export ENABLE_SIMPLIFIED_PSO=1
./build_and_test_all.sh -t backprop

# 预期结果:
# ✅ 日志中显示"SimplifiedPSO ENABLED"
# ✅ 出现[SimplifiedPSO]相关日志
# ✅ 可以看到PSO路由决策过程
```

#### 6.5 验证清单

```
□ 构造函数正确初始化SimplifiedPSO配置
□ m_simplified_pso_config.enable默认为false
□ getRoute()正确集成SimplifiedPSO分支
□ SimplifiedPSO关闭时完全不影响现有路由
□ 环境变量ENABLE_SIMPLIFIED_PSO=1可以启用
□ 编译成功
□ 测试通过
```

---

### Phase 7: 启用SimplifiedPSO，完整测试和性能对比

**目标**: 正式启用SimplifiedPSO，进行完整测试和性能评估

**预计时间**: 1-2天

#### 7.1 启用方式

**方式1: 环境变量（推荐用于测试）**:
```bash
export ENABLE_SIMPLIFIED_PSO=1
./build_and_test_all.sh -t backprop
./build_and_test_all.sh -t kmeans
```

**方式2: 修改代码（推荐用于生产）**:
```cpp
// Router.cc - 构造函数
m_simplified_pso_config.enable = true;  // 改为true
```

#### 7.2 完整测试方案

**测试1: backprop基准测试**:
```bash
# 关闭SimplifiedPSO（基线）
unset ENABLE_SIMPLIFIED_PSO
./build_and_test_all.sh -t backprop
cp build_logs/test_backprop_*.log baseline_backprop.log

# 启用SimplifiedPSO
export ENABLE_SIMPLIFIED_PSO=1
./build_and_test_all.sh -t backprop
cp build_logs/test_backprop_*.log pso_backprop.log

# 对比分析
diff baseline_backprop.log pso_backprop.log
grep "SimplifiedPSO" pso_backprop.log
```

**测试2: kmeans基准测试**:
```bash
unset ENABLE_SIMPLIFIED_PSO
./build_and_test_all.sh -t kmeans
cp build_logs/test_kmeans_*.log baseline_kmeans.log

export ENABLE_SIMPLIFIED_PSO=1
./build_and_test_all.sh -t kmeans
cp build_logs/test_kmeans_*.log pso_kmeans.log
```

#### 7.3 性能指标收集

创建分析脚本：

**文件**: `analyze_pso_performance.sh`

```bash
#!/bin/bash

# 分析SimplifiedPSO性能

echo "=== SimplifiedPSO Performance Analysis ==="
echo ""

# 提取统计数据
echo "1. PSO Usage Statistics:"
grep "SimplifiedPSO Statistics" $1 -A 10

echo ""
echo "2. PSO Call Count:"
grep "SimplifiedPSO] Starting" $1 | wc -l

echo ""
echo "3. Average Fitness:"
grep "fitness=" $1 | awk -F'fitness=' '{print $2}' | awk '{print $1}' | \
    awk '{sum+=$1; count++} END {print "Average: " sum/count}'

echo ""
echo "4. Average Time:"
grep "time=" $1 | awk -F'time=' '{print $2}' | awk '{print $1}' | \
    awk '{sum+=$1; count++} END {print "Average: " sum/count " ticks"}'

echo ""
echo "5. Early Stop Rate:"
early_stops=$(grep "PSO-EarlyStop" $1 | wc -l)
total_calls=$(grep "SimplifiedPSO] Starting" $1 | wc -l)
if [ $total_calls -gt 0 ]; then
    echo "Early stops: $early_stops / $total_calls = $(echo "scale=2; 100*$early_stops/$total_calls" | bc)%"
fi
```

使用：
```bash
chmod +x analyze_pso_performance.sh
./analyze_pso_performance.sh pso_backprop.log
```

#### 7.4 性能对比报告

创建性能对比文档：

**文件**: `/home/siat/gem5-gpu-bak/reports/20250106_SimplifiedPSO_performance_comparison.md`

```markdown
# SimplifiedPSO性能对比报告

## 测试环境
- 拓扑: 4x4 Mesh (16路由器)
- 测试用例: backprop, kmeans
- PSO配置: 5粒子, 10迭代

## 性能指标对比

### backprop测试

| 指标 | 基线（关闭PSO） | SimplifiedPSO | 变化 |
|-----|----------------|---------------|------|
| 平均延迟 | X ticks | Y ticks | Z% |
| 总执行时间 | X cycles | Y cycles | Z% |
| 路由成功率 | X% | Y% | Z% |

### kmeans测试

| 指标 | 基线 | SimplifiedPSO | 变化 |
|-----|------|---------------|------|
| ... | ... | ... | ... |

## SimplifiedPSO统计

- PSO调用次数: XXX
- 成功率: XX%
- 平均适应度: X.XX
- 平均计算时间: X.X ticks
- 早停率: XX%

## 结论

[根据实际数据填写]
```

#### 7.5 参数调优（可选）

如果性能不理想，可以调整参数：

```cpp
// Router.cc - 构造函数中调整
m_simplified_pso_config.num_particles = 3;    // 减少粒子数
m_simplified_pso_config.max_iterations = 7;   // 减少迭代次数
m_simplified_pso_config.max_time_budget = 20; // 减少时间预算
```

#### 7.6 最终验证清单

```
□ SimplifiedPSO成功启用
□ backprop测试通过
□ kmeans测试通过
□ 日志中有详细的PSO决策过程
□ 性能指标收集完成
□ 性能对比报告编写完成
□ 参数调优（如需要）
□ 所有测试用例通过
□ 没有内存泄漏
□ 没有崩溃或异常
```

---

## 📊 总进度追踪表

| 阶段 | 任务 | 预计时间 | 文件修改 | 编译 | 测试 | 状态 |
|-----|------|---------|---------|------|------|------|
| Phase 1 | 基础数据结构 | 2-3h | Router.hh | ✓ | - | ⏸️ |
| Phase 2 | 路径解码函数 | 3-4h | Router.hh/cc | ✓ | ✓ | ⏸️ |
| Phase 3 | 端口查找函数 | 2-3h | Router.hh/cc | ✓ | ✓ | ⏸️ |
| Phase 4 | 适应度评估 | 3-4h | Router.hh/cc | ✓ | ✓ | ⏸️ |
| Phase 5 | PSO核心算法 | 4-5h | Router.hh/cc | ✓ | ✓ | ⏸️ |
| Phase 6 | 集成+开关 | 2-3h | Router.cc | ✓ | ✓ | ⏸️ |
| Phase 7 | 完整测试 | 1-2d | 无 | - | ✓ | ⏸️ |

**总工期**: 5-7天

---

## 🔄 每个阶段的通用流程

### 标准工作流程

```bash
# 1. 修改代码
vim /home/siat/gem5-gpu-bak/gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh
vim /home/siat/gem5-gpu-bak/gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc

# 2. 编译
cd /home/siat/gem5-gpu-bak/
./build_and_test_all.sh -b

# 3. 检查编译日志
tail -50 build_logs/remote_build_*.log

# 4. 如果编译成功，进行单元测试（如适用）
# （在Router构造函数中临时添加测试代码）

# 5. 如果单元测试通过，运行完整测试
./build_and_test_all.sh -t backprop

# 6. 分析结果
grep "Phase" build_logs/test_*.log
grep "ERROR" build_logs/test_*.log

# 7. 如果一切正常，提交当前阶段
git add Router.hh Router.cc
git commit -m "Phase X: [描述]"

# 8. 进入下一阶段
```

---

## ⚠️ 风险管理

### 每个阶段的回退策略

**Phase 1-5**:
```bash
git checkout Router.hh Router.cc  # 回退到修改前
./build_and_test_all.sh -b        # 验证回退成功
```

**Phase 6**:
```bash
# 方式1: 关闭SimplifiedPSO（无需回退代码）
unset ENABLE_SIMPLIFIED_PSO
./build_and_test_all.sh -t backprop

# 方式2: 修改代码关闭
m_simplified_pso_config.enable = false;
```

**Phase 7**:
```bash
# 如果性能不理想，可以：
# 1. 调整参数
# 2. 关闭SimplifiedPSO
# 3. 使用环境变量控制
```

---

## 📝 总结

### 关键成功因素

1. **每阶段独立**: 每个Phase都可以独立编译和测试
2. **向后兼容**: Phase 1-5不影响现有路由功能
3. **开关控制**: Phase 6集成时默认关闭，可随时启用/关闭
4. **渐进验证**: 每个阶段都有明确的验证清单
5. **快速回退**: 出现问题可以立即回退到上一阶段

### 实施建议

1. **按顺序实施**: 严格按Phase 1→2→3→4→5→6→7顺序
2. **充分测试**: 每个阶段都要编译+测试验证
3. **记录日志**: 保存每个阶段的测试日志
4. **Git提交**: 每个阶段完成后提交一次代码
5. **性能监控**: Phase 7要详细对比性能指标

---

**文档完成**

**作者**: Claude Code
**日期**: 2026-01-06
**版本**: 1.0
