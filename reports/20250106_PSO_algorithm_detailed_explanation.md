# PSO粒子群优化算法 - NoC路由详细实现解析

**创建时间**: 2026-01-06  
**目的**: 详细解释如果激活PSO算法，粒子是什么、如何迭代、过程如何实现

---

## 📚 目录
1. [粒子的定义](#1-粒子的定义)
2. [PSO迭代过程](#2-pso迭代过程)
3. [数学公式详解](#3-数学公式详解)
4. [适应度评估](#4-适应度评估)
5. [完整流程图](#5-完整流程图)
6. [代码实现细节](#6-代码实现细节)
7. [动态粒子配置](#7-动态粒子配置)

---

## 1. 粒子的定义

### 什么是粒子？

在NoC路由上下文中，**粒子代表一条从源节点到目标节点的候选路径**。

### 粒子的数据结构

```cpp
struct Particle {
    int particle_id;                      // 粒子唯一标识
    std::vector<double> position;         // 粒子位置（路径编码）
    std::vector<double> velocity;         // 粒子速度（搜索方向）
    std::vector<double> best_position;    // 历史最优位置
    double best_fitness;                  // 历史最优适应度
    double current_fitness;               // 当前适应度
    int group_id;                         // 所属处理单元组（CPU/GPU/Memory/Cache/IO）
};
```

### 粒子位置的含义

位置向量是**4维向量**，表示一条路径：

```
position = [node0, node1, node2, node3]
           ⬇️       ⬇️      ⬇️      ⬇️
         源节点  第1跳  第2跳  目标节点
```

**示例** - 4x4网格拓扑：
```
源节点=0, 目标节点=15 (对角线路径)

粒子A: position = [0.0, 5.2, 10.8, 15.0]
       解码路径: 0 → 5 → 11 → 15

粒子B: position = [0.0, 1.3, 6.7, 15.0]
       解码路径: 0 → 1 → 7 → 15

粒子C: position = [0.0, 4.1, 8.6, 15.0]
       解码路径: 0 → 4 → 9 → 15
```

### 粒子速度的含义

速度向量表示**粒子在搜索空间中的移动方向和幅度**：

```
velocity = [v0, v1, v2, v3]
           ⬇️  ⬇️  ⬇️  ⬇️
每个维度的变化速率（每次迭代的位移）
```

---

## 2. PSO迭代过程

### 完整迭代流程

```
┌────────────────────────────────────────┐
│  Step 1: 初始化粒子群                   │
│  - 生成 N 个粒子（N=5~20，动态配置）     │
│  - 随机初始化位置和速度                 │
└──────────┬─────────────────────────────┘
           ↓
┌────────────────────────────────────────┐
│  Step 2: 迭代优化 (max 30 次)          │
│  ┌──────────────────────────────────┐  │
│  │  2.1 评估所有粒子的适应度        │  │
│  │  2.2 更新每个粒子的个体最优      │  │
│  │  2.3 更新全局最优解              │  │
│  │  2.4 更新粒子速度（PSO公式）     │  │
│  │  2.5 更新粒子位置                │  │
│  │  2.6 检查收敛/早停条件           │  │
│  └──────────────────────────────────┘  │
└──────────┬─────────────────────────────┘
           ↓
┌────────────────────────────────────────┐
│  Step 3: 提取最优路由                  │
│  - 全局最优粒子 → 下一跳端口            │
└────────────────────────────────────────┘
```

### 每次迭代的详细步骤

#### 迭代开始前状态示例

```
当前粒子群（3个粒子示例，实际5-20个）:
┌──────────────────────────────────────────────────┐
│ 粒子 │  位置      │ 速度       │ 当前适应度 │ 最优适应度 │
├──────┼────────────┼────────────┼───────────┼───────────┤
│  P0  │ [0,5,10,15]│ [-0.2,0.3] │  12.5     │   10.2    │
│  P1  │ [0,1,6,15] │ [0.5,-0.1] │  8.3      │   8.3     │ ← 当前最优
│  P2  │ [0,4,8,15] │ [0.1,0.4]  │  15.7     │   13.1    │
└──────────────────────────────────────────────────┘
全局最优适应度: 8.3 (来自P1)
全局最优位置: [0,1,6,15]
```

#### 步骤 2.1: 评估适应度

对每个粒子计算多目标适应度：

```cpp
fitness = w1 * 延迟成本 + 
          w2 * 功耗成本 + 
          w3 * 拥塞惩罚 + 
          w4 * 路径平滑度 + 
          w5 * 可靠性成本

// 示例计算
P1: position = [0,1,6,15]
   路径: 0→1→6→15
   
   延迟成本 = 3跳 × 1.0 = 3.0
   拥塞惩罚 = link(0→1): 0.2 + link(1→6): 0.5 + link(6→15): 0.3 = 1.0
   功耗成本 = CPU(0):2.0 + CPU(1):2.0 + GPU(6):3.0 + MEM(15):1.5 = 8.5
   平滑度 = 0转向 × 2.0 = 0.0
   
   总适应度 = 0.35×3.0 + 0.30×1.0 + 0.20×8.5 + 0.15×0.0 = 3.65
```

#### 步骤 2.2-2.3: 更新个体最优和全局最优

```
更新个体最优：
IF fitness(P0) < P0.best_fitness:
    P0.best_position = P0.position
    P0.best_fitness = fitness(P0)

更新全局最优：
best_particle = min(P0, P1, P2, by fitness)
IF best_particle.fitness < global_best_fitness:
    global_best_position = best_particle.position
    global_best_fitness = best_particle.fitness
```

#### 步骤 2.4: 更新粒子速度（核心PSO公式）

**经典PSO速度更新公式**:

```
v[i][d] = w × v[i][d] + 
          c1 × r1 × (pbest[i][d] - x[i][d]) + 
          c2 × r2 × (gbest[d] - x[i][d])

其中:
w  = 惯性权重（自适应：0.35~0.95）
c1 = 个体学习系数（1.0~2.5）
c2 = 社会学习系数（1.0~2.5）
r1, r2 = 随机数 [0,1]
pbest = 粒子个体最优位置
gbest = 全局最优位置
x = 粒子当前位置
d = 维度索引
```

**具体计算示例**（P0 的第1维）:

```cpp
// P0 当前状态
position[1] = 5.2
velocity[1] = 0.3
best_position[1] = 5.0
global_best[1] = 1.3

// 参数
w = 0.7, c1 = 1.5, c2 = 1.5
r1 = 0.8, r2 = 0.6 (随机生成)

// 计算
惯性项 = w × v[1] = 0.7 × 0.3 = 0.21
认知项 = c1 × r1 × (5.0 - 5.2) = 1.5 × 0.8 × (-0.2) = -0.24
社会项 = c2 × r2 × (1.3 - 5.2) = 1.5 × 0.6 × (-3.9) = -3.51

new_velocity[1] = 0.21 + (-0.24) + (-3.51) = -3.54

// 速度限制
if (new_velocity[1] < -3.0) new_velocity[1] = -3.0
if (new_velocity[1] > 3.0) new_velocity[1] = 3.0

最终: velocity[1] = -3.0 （限制后）
```

**速度更新的意义**：
- **惯性项**: 保持当前搜索方向（探索性）
- **认知项**: 向个体历史最优移动（局部优化）
- **社会项**: 向全局最优移动（全局优化）

#### 步骤 2.5: 更新粒子位置

```cpp
// 位置更新公式（简单）
position[d] = position[d] + velocity[d]

// 示例
P0.position[1] = 5.2 + (-3.0) = 2.2

// 边界约束
if (position[d] < 0.0) position[d] = 0.0
if (position[d] > 15.0) position[d] = 15.0

// 路径约束
position[0] = src_node  // 强制首节点
position[3] = dest_node // 强制尾节点
```

#### 步骤 2.6: 收敛检查

```cpp
bool converged = false;

// 条件1: 适应度改进停滞
if (迭代5次无改进) converged = true;

// 条件2: 适应度已足够好
if (global_best_fitness < 10.0) converged = true;

// 条件3: 时间预算耗尽
if (elapsed_time > 20 ticks) converged = true;

// 条件4: 粒子群多样性过低
diversity = 计算粒子间平均距离()
if (diversity < 0.2) converged = true;
```

---

## 3. 数学公式详解

### PSO核心公式系统

#### 1. 速度更新公式（完整版）

```
v[t+1] = w(t) × v[t] + 
         c1(t) × rand() × (pbest - x[t]) + 
         c2(t) × rand() × (gbest - x[t])

w(t) = 自适应惯性权重
     = 0.9 - 0.6 × (t / max_iterations)  // 线性递减
     或基于群体多样性自适应调整
```

#### 2. 位置更新公式

```
x[t+1] = x[t] + v[t+1]

约束:
x[0] = src_node       (固定)
x[last] = dest_node   (固定)
0 ≤ x[i] ≤ 15         (拓扑范围)
```

#### 3. 适应度函数（多目标）

```
F(x) = Σ w[i] × f[i](x)

其中:
f1(x) = 延迟成本 = Σ hop_delay + Σ congestion_delay
f2(x) = 功耗成本 = Σ node_power(type)
f3(x) = 拥塞惩罚 = Σ link_congestion × penalty
f4(x) = 平滑度 = Σ direction_changes
f5(x) = 可靠性 = 1 / path_stability

权重自适应调整:
w1 (延迟): 0.35 ~ 0.80  (高拥塞时提高)
w2 (功耗): 0.20 ~ 0.80  (功耗紧张时提高)
w3 (拥塞): 0.30 ~ 0.90  (高负载时提高)
...
```

#### 4. 群体多样性度量

```
Diversity = (1 / (N × (N-1))) × ΣΣ ||x[i] - x[j]||

其中:
N = 粒子数量
||x[i] - x[j]|| = 欧几里得距离

用途: 
- diversity < 0.2 → 增加探索（提高w）
- diversity > 0.7 → 增加开发（降低w）
```

---

## 4. 适应度评估

### 多目标评估体系

#### 评估函数代码实现

```cpp
double PSOAlgorithm::evaluateParticleFitness(const Particle& particle, 
                                            int src_node, int dest_node) const
{
    double total_fitness = 0.0;
    
    // 1. 延迟成本 (35%)
    double travel_time = 0.0;
    for (size_t i = 0; i < position.size() - 1; i++) {
        int node1 = position[i], node2 = position[i+1];
        if (!areNodesAdjacent(node1, node2)) {
            travel_time += 100.0;  // 无效路径惩罚
        } else {
            travel_time += 1.0 + getCachedLinkCongestion(node1, node2) * 5.0;
        }
    }
    
    // 2. 功耗成本 (20%)
    double power = 0.0;
    for (auto node : position) {
        int type = getProcessingUnitType(node);
        power += getPowerCost(type);  // GPU:3.0, CPU:2.0, MEM:1.5
    }
    
    // 3. 拥塞惩罚 (30%)
    double congestion = 0.0;
    for (auto link : path_links) {
        if (getLinkCongestion(link) > 0.8) {
            congestion += 20.0;  // 热点惩罚
        }
    }
    
    // 4. 平滑度成本 (10%)
    double smoothness = calculateDirectionChanges(position) * 2.0;
    
    // 5. 跨类型惩罚 (5%)
    double type_penalty = (src_type != dest_type) ? 10.0 : 0.0;
    
    // 加权组合
    total_fitness = 0.35 * travel_time + 
                   0.20 * power + 
                   0.30 * congestion + 
                   0.10 * smoothness + 
                   0.05 * type_penalty;
                   
    return total_fitness;
}
```

### 适应度计算示例

**场景**: 路由从节点0到节点15（4x4网格对角线）

**粒子路径**: `[0, 1, 5, 10, 15]`

```
拓扑可视化:
 0─ 1─ 2─ 3
 │  │  │  │
 4─ 5─ 6─ 7
 │  │  │  │
 8─ 9─10─11
 │  │  │  │
12─13─14─15

路径: 0→1→5→10→15 (4跳)
```

**详细计算**:

```
1. 延迟成本:
   hop(0→1): 1.0 + congestion(0.1) * 5.0 = 1.5
   hop(1→5): 1.0 + congestion(0.3) * 5.0 = 2.5
   hop(5→10): 1.0 + congestion(0.5) * 5.0 = 3.5
   hop(10→15): 1.0 + congestion(0.2) * 5.0 = 2.0
   小计: 9.5

2. 功耗成本:
   node(0): CPU = 2.0
   node(1): CPU = 2.0
   node(5): GPU = 3.0
   node(10): GPU = 3.0
   node(15): MEM = 1.5
   小计: 11.5

3. 拥塞惩罚:
   link(5→10)拥塞度0.5 < 0.8, 无惩罚
   小计: 0.0

4. 平滑度:
   方向变化: (0→1:东) → (1→5:南) → (5→10:南) → (10→15:南)
   共1次转向
   小计: 1 × 2.0 = 2.0

5. 类型惩罚:
   src=CPU, dest=MEM, 不同类型
   小计: 10.0

总适应度 = 0.35×9.5 + 0.20×11.5 + 0.30×0.0 + 0.10×2.0 + 0.05×10.0
         = 3.325 + 2.3 + 0 + 0.2 + 0.5
         = 6.325
```

**越小越好**: 适应度6.325表示中等质量路径

---

## 5. 完整流程图

### 视觉化PSO路由决策流程

```
┌─────────────────────────────────────────────────────────────┐
│                    路由请求到达                              │
│              src=0, dest=15, time=1000                      │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  动态粒子配置: 评估路由复杂度                                │
│  - Manhattan距离: 6跳 → 0.6                                │
│  - 网络拥塞: 40% → 0.4                                      │
│  - 缓存未命中: 是 → 0.3                                      │
│  - 历史质量: 12.5 → 0.25                                    │
│  - 类型差异: CPU→MEM → 0.2                                  │
│  复杂度 = 0.35×0.6 + 0.30×0.4 + 0.15×0.3                   │
│          + 0.10×0.25 + 0.10×0.2 = 0.448                    │
│  粒子数 = 5 + (20-5) × 0.448 = 12 个粒子                    │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  初始化12个粒子 (按处理单元类型分组)                          │
│  ┌──────┬───────────────┬──────────┬─────────┐              │
│  │ P0-2 │ CPU组 (3粒子) │ group_id=0│ [0,?,?,15] │          │
│  │ P3-7 │ GPU组 (5粒子) │ group_id=1│ [0,?,?,15] │          │
│  │ P8-9 │ MEM组 (2粒子) │ group_id=2│ [0,?,?,15] │          │
│  │ P10-11│ Cache组(2粒子)│ group_id=3│ [0,?,?,15] │          │
│  └──────┴───────────────┴──────────┴─────────┘              │
└────────────────────────┬────────────────────────────────────┘
                         ↓
          ┌──────────────────────────┐
          │   PSO迭代循环 (最多30次)  │
          └──────────┬───────────────┘
                     ↓
     ┌───────────────────────────────────────┐
     │  迭代 t=1                             │
     │  ┌─────────────────────────────────┐  │
     │  │ 评估12个粒子的适应度            │  │
     │  │ P0: 8.5, P1: 12.3, ... P11: 6.2│  │
     │  └────────────┬────────────────────┘  │
     │               ↓                       │
     │  ┌─────────────────────────────────┐  │
     │  │ 更新个体最优                    │  │
     │  │ IF fitness < pbest: pbest = pos │  │
     │  └────────────┬────────────────────┘  │
     │               ↓                       │
     │  ┌─────────────────────────────────┐  │
     │  │ 更新全局最优                    │  │
     │  │ gbest_fitness = 6.2 (来自P11)  │  │
     │  └────────────┬────────────────────┘  │
     │               ↓                       │
     │  ┌─────────────────────────────────┐  │
     │  │ 更新速度和位置 (PSO公式)        │  │
     │  │ v = w×v + c1×r1×(pbest-x)      │  │
     │  │       + c2×r2×(gbest-x)        │  │
     │  │ x = x + v                       │  │
     │  └────────────┬────────────────────┘  │
     │               ↓                       │
     │  ┌─────────────────────────────────┐  │
     │  │ 检查收敛                        │  │
     │  │ 停滞次数: 0                     │  │
     │  │ 多样性: 0.65 (继续)            │  │
     │  └─────────────────────────────────┘  │
     └───────────────┬───────────────────────┘
                     ↓
     ┌───────────────────────────────────────┐
     │  迭代 t=2                             │
     │  ... (重复上述步骤)                   │
     └───────────────┬───────────────────────┘
                     ↓
     ┌───────────────────────────────────────┐
     │  迭代 t=18                            │
     │  早停触发: fitness=5.8 < 10.0         │
     │  收敛! 停止迭代                       │
     └───────────────┬───────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│  提取最优路由                                                │
│  全局最优粒子: P11                                           │
│  最优位置: [0.0, 1.2, 5.8, 10.3, 15.0]                      │
│  解码路径: 0 → 1 → 6 → 10 → 15                              │
│  下一跳节点: 1                                               │
│  下一跳端口: getPortToNextNode(0, 1) = 端口1 (东向)         │
└────────────────────────┬────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   返回路由决策                               │
│                   next_hop = 1 (端口1)                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 代码实现细节

### 关键函数调用链

```cpp
// ============================================================================
// 主路由函数
// ============================================================================
int Router::getRoute(NetDest destination)
{
    // 当前: 调用协作路由
    result = getRouteCollaborative(destination);
    
    // 激活PSO后: 调用PSO路由
    result = m_pso_algorithm->getRoutePSO(destination);  // ← 修改这里
    
    return result;
}

// ============================================================================
// PSO核心路由函数
// ============================================================================
int PSOAlgorithm::getRoutePSO(NetDest destination)
{
    // 1. 初始化粒子群（动态粒子配置在这里）
    initializeSwarmForDestination(destination);
    
    // 2. PSO主迭代循环
    for (int iteration = 0; iteration < max_iterations; iteration++) {
        
        // 2.1 更新所有粒子
        updateAllParticles(iteration, src_node, dest_node);
        
        // 2.2 更新全局最优
        updateGlobalBestSolution();
        
        // 2.3 提取当前最优下一跳
        for (const auto& particle : m_particles) {
            if (particle.current_fitness < iteration_best_fitness) {
                int next_node = (int)particle.position[1] % 16;
                int port = getPortToNextNode(src_node, next_node);
                best_next_hop = port;
            }
        }
        
        // 2.4 早停检查
        if (checkEarlyTermination(start_time, iteration, global_best_fitness)) {
            break;
        }
        
        // 2.5 自适应参数调整
        updateAdaptiveParameters(iteration, global_best_fitness);
    }
    
    return best_next_hop;
}

// ============================================================================
// 粒子更新函数
// ============================================================================
void PSOAlgorithm::updateAllParticles(int iteration, int src, int dest)
{
    for (auto& particle : m_particles) {
        // 1. 更新速度（PSO公式）
        updateParticleVelocity(particle, w, c1, c2);
        
        // 2. 更新位置
        updateParticlePosition(particle, src, dest);
        
        // 3. 评估适应度
        double fitness = evaluateParticleFitness(particle, src, dest);
        particle.current_fitness = fitness;
        
        // 4. 更新个体最优
        if (fitness < particle.best_fitness) {
            particle.best_fitness = fitness;
            particle.best_position = particle.position;
        }
    }
}

// ============================================================================
// 速度更新（核心PSO公式）
// ============================================================================
void PSOAlgorithm::updateParticleVelocity(Particle& p, double w, double c1, double c2)
{
    // 使用自适应参数
    double adaptive_w = m_adaptive_manager.current_inertia_weight;
    double adaptive_c1 = m_adaptive_manager.current_cognitive_coeff;
    double adaptive_c2 = m_adaptive_manager.current_social_coeff;
    
    for (size_t i = 0; i < p.velocity.size(); i++) {
        double r1 = rand() / (double)RAND_MAX;  // 随机数 [0,1]
        double r2 = rand() / (double)RAND_MAX;
        
        // 获取全局最优
        std::vector<double> global_best = getGlobalBestPosition(unit_type);
        
        // PSO速度更新公式
        p.velocity[i] = adaptive_w * p.velocity[i] +                        // 惯性
                       adaptive_c1 * r1 * (p.best_position[i] - p.position[i]) + // 认知
                       adaptive_c2 * r2 * (global_best[i] - p.position[i]);      // 社会
        
        // 速度限制
        double v_max = 3.0;
        p.velocity[i] = std::max(-v_max, std::min(v_max, p.velocity[i]));
    }
}

// ============================================================================
// 位置更新
// ============================================================================
void PSOAlgorithm::updateParticlePosition(Particle& p, int src, int dest)
{
    for (size_t i = 0; i < p.position.size(); i++) {
        // 简单位移
        p.position[i] += p.velocity[i];
        
        // 边界限制 [0, 15]
        p.position[i] = std::max(0.0, std::min(15.0, p.position[i]));
    }
    
    // 路径约束
    p.position[0] = src;   // 固定源节点
    p.position[p.position.size()-1] = dest;  // 固定目标节点
}
```

---

## 7. 动态粒子配置

### 动态粒子数计算

```cpp
void PSOAlgorithm::initializeSwarmForDestination(NetDest destination)
{
    auto config = PSOConfigUtil::getGlobalConfigManager()->getCurrentConfig();
    
    int num_particles;
    
    if (config.enable_dynamic_particles) {
        // 动态模式
        double complexity = evaluateRoutingComplexity(src_node, dest_node);
        num_particles = calculateDynamicParticleCount(complexity);
        
        printf("[PSO-Dynamic] Route %d→%d: complexity=%.3f → %d particles\n",
               src_node, dest_node, complexity, num_particles);
    } else {
        // 固定模式
        num_particles = config.particle_count;
    }
    
    // 初始化粒子
    m_particles.clear();
    for (int i = 0; i < num_particles; i++) {
        Particle p(i);
        p.position = {src_node, rand()%16, rand()%16, dest_node};
        p.velocity = {0, (rand()%7-3), (rand()%7-3), 0};
        p.group_id = i % 5;  // 5个处理单元类型
        m_particles.push_back(p);
    }
}

double PSOAlgorithm::evaluateRoutingComplexity(int src, int dest) const
{
    // 5因素加权评估
    double distance_factor = manhattan_distance / 6.0;          // 35%
    double congestion_factor = getAverageNodeCongestion();      // 30%
    double cache_miss_penalty = (cache_hit ? 0.0 : 0.3);       // 15%
    double history_quality = global_best_fitness / 50.0;        // 10%
    double type_penalty = (src_type != dest_type) ? 0.2 : 0.0;  // 10%
    
    return 0.35*distance_factor + 0.30*congestion_factor + 
           0.15*cache_miss_penalty + 0.10*history_quality + 
           0.10*type_penalty;
}

int PSOAlgorithm::calculateDynamicParticleCount(double complexity) const
{
    // 线性映射: complexity [0,1] → particles [5,20]
    int count = 5 + (int)((20 - 5) * complexity);
    
    // 向5取整
    count = ((count + 2) / 5) * 5;
    
    // 边界检查
    return std::max(5, std::min(20, count));
}
```

### 动态配置示例

```
场景1: 简单路由 (邻居节点)
  complexity = 0.15
  粒子数 = 5 + (20-5) × 0.15 = 7.25 → 5个粒子

场景2: 中等复杂路由
  complexity = 0.50
  粒子数 = 5 + (20-5) × 0.50 = 12.5 → 10个粒子

场景3: 复杂路由 (远距离+高拥塞)
  complexity = 0.85
  粒子数 = 5 + (20-5) × 0.85 = 17.75 → 20个粒子
```

---

## 总结

### PSO算法的本质

1. **粒子 = 候选路径**: 每个粒子代表从源到目标的一条可能路径
2. **位置 = 路径编码**: 4维向量编码中间跳数节点
3. **速度 = 搜索方向**: 粒子在解空间的移动方向
4. **适应度 = 路径质量**: 综合延迟、功耗、拥塞等多目标评分
5. **迭代 = 优化过程**: 通过速度和位置更新逐步找到更优路径

### 激活PSO后的效果

如果激活PSO算法（修改Router.cc第1161行）：

✅ **会发生**:
- 每次路由请求执行5-20次PSO迭代
- 动态粒子配置根据复杂度自动调整
- 真正的粒子群优化搜索最优路径
- 多目标适应度评估（延迟+功耗+拥塞+...）
- 自适应参数调整（w, c1, c2）

⚠️ **代价**:
- 计算时间增加（20-50 ticks vs 2-5 ticks）
- 功耗增加（PSO迭代计算）
- 可能降低吞吐量（更复杂的路由决策）

💡 **优势**:
- 更高质量的路由决策
- 更好的多目标平衡
- 自适应网络状态
- 理论上更优的性能

---

**文档结束**
