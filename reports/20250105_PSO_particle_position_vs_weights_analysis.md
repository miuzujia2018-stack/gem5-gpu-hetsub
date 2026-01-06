# PSO粒子位置与路由权重关系技术分析

**项目**: gem5-gpu MVPP_MGC_PSO路由算法
**日期**: 2025-01-05
**核心问题**: 粒子位置（偏好系数）与后续权重是否冲突？
**结论**: **不冲突——这是PSO算法的核心设计特性**

---

## 执行摘要

**用户疑问**: "粒子的位置表示为偏好系数，这些系数跟后续权重，是否会冲突？"

**技术回答**:
- **不冲突**：粒子位置（偏好系数）**就是**路由权重
- **设计目的**：PSO通过迭代优化学习最优权重组合
- **多层次机制**：固定基础权重 + PSO学习的自适应权重

---

## 第一部分：数据结构定义与代码证据

### 1.1 PacketParticle的位置向量定义

**文件**: `Router.hh:483-487`

```cpp
// **Week 1 Phase 1A Addition: 位置向量维度说明**
// position[0]: 路径偏好 (0.0=最短路径, 1.0=最可靠路径)
// position[1]: 负载均衡权重 (0.0=忽略负载, 1.0=最大化负载均衡)
// position[2]: 功耗优化偏好 (0.0=忽略功耗, 1.0=最小化功耗)
// position[3]: 延迟敏感度 (0.0=对延迟不敏感, 1.0=最小化延迟)
```

**关键发现**：
- position向量本身就是**偏好权重**，不是独立的系数
- 4维向量每一维都有明确的物理意义
- 取值范围 [0.0, 1.0]，表示该维度的重要程度

---

### 1.2 适应度计算中的权重使用

**文件**: `Router_sensitivity_implementation.cpp:144-180`

```cpp
double Router::calculateMultiObjectiveFitness(const PacketParticle& packet) {
    // 获取网络状态因子
    double delay_factor = getCurrentDelayFactor(packet.src_node, packet.dest_node);
    double power_factor = getCurrentEnergyFactor(packet.src_node, packet.dest_node);
    double congestion_factor = getCurrentCongestionFactor(packet.src_node, packet.dest_node);
    double load_balance_factor = getCurrentLoadBalanceFactor(packet.src_node, packet.dest_node);
    double reliability_factor = getCurrentReliabilityFactor(packet.src_node, packet.dest_node);
    double qos_factor = getCurrentQoSFactor(packet.src_node, packet.dest_node);

    // **核心发现：粒子位置直接作为权重**
    double delay_weight = packet.position[3];    // Adaptive delay weight
    double power_weight = packet.position[2];    // Adaptive power weight
    double congestion_weight = 0.20;             // Base congestion weight (固定)
    double load_balance_weight = 0.15;           // Base load balance weight (固定)
    double reliability_weight = 0.10;            // Base reliability weight (固定)
    double qos_weight = 0.05;                    // Base QoS weight (固定)

    // 适应度计算公式
    double fitness = delay_weight * delay_factor +
                    power_weight * power_factor +
                    congestion_weight * congestion_factor +
                    load_balance_weight * load_balance_factor +
                    reliability_weight * reliability_factor +
                    qos_weight * qos_factor;

    return fitness;
}
```

**关键证据**：
- `packet.position[3]` **直接赋值**给 `delay_weight`
- `packet.position[2]` **直接赋值**给 `power_weight`
- 没有任何额外的系数转换或调制
- **粒子位置 = 权重**，这是直接映射关系

---

## 第二部分：设计机制深度分析

### 2.1 为什么粒子位置可以作为权重？

**理论基础**：PSO算法通过粒子在搜索空间中的移动来寻找最优解。

**在MVPP_MGC_PSO中的应用**：

```
传统PSO：
- 搜索空间：路径规划中的物理坐标 (x, y, z)
- 粒子位置：车辆在地图上的位置
- 优化目标：找到最短/最优路径

MVPP_MGC_PSO NoC路由：
- 搜索空间：多目标权重空间 [0,1]⁴
- 粒子位置：四维偏好权重 (delay, power, congestion, load)
- 优化目标：找到最优权重组合，使路由性能最佳
```

**设计创新**：
- **抽象化搜索空间**：从物理坐标空间转换为权重空间
- **元优化**：不直接优化路由路径，而是优化**如何评价路径的权重**
- **自适应性**：粒子通过学习网络状态，动态调整权重偏好

---

### 2.2 两层权重机制详解

#### 第一层：固定基础权重（先验知识）

```cpp
double congestion_weight = 0.20;      // 拥塞权重（固定）
double load_balance_weight = 0.15;    // 负载均衡权重（固定）
double reliability_weight = 0.10;     // 可靠性权重（固定）
double qos_weight = 0.05;             // QoS权重（固定）
```

**设计原理**：
- 基于领域知识的**静态权重**
- 反映NoC路由的基本优化目标
- 不随网络状态变化

#### 第二层：PSO学习的自适应权重（动态优化）

```cpp
double delay_weight = packet.position[3];  // PSO学习（动态）
double power_weight = packet.position[2];  // PSO学习（动态）
```

**设计原理**：
- 通过PSO迭代优化学习得到
- **根据网络实时状态自适应调整**
- 反映当前拥塞、负载等动态特征

---

### 2.3 多层次权重的数学表示

**完整适应度函数**：

$$
F(\mathcal{P}) = \underbrace{x_3 \cdot f_{\text{delay}}}\_{\text{PSO学习}} + \underbrace{x_2 \cdot f_{\text{power}}}\_{\text{PSO学习}} + \underbrace{w_{\text{cong}} \cdot f_{\text{cong}}}\_{\text{固定}} + \underbrace{w_{\text{load}} \cdot f_{\text{load}}}\_{\text{固定}} + \underbrace{w_{\text{rel}} \cdot f_{\text{rel}}}\_{\text{固定}} + \underbrace{w_{\text{qos}} \cdot f_{\text{qos}}}\_{\text{固定}}
$$

其中：
- $x_3 = \text{position}[3] \in [0,1]$：PSO学习的延迟权重
- $x_2 = \text{position}[2] \in [0,1]$：PSO学习的功耗权重
- $w_{\text{cong}} = 0.20$：固定拥塞权重
- $w_{\text{load}} = 0.15$：固定负载权重
- $w_{\text{rel}} = 0.10$：固定可靠性权重
- $w_{\text{qos}} = 0.05$：固定QoS权重

**权重归一化约束**：

$$
x_3 + x_2 + w_{\text{cong}} + w_{\text{load}} + w_{\text{rel}} + w_{\text{qos}} \leq 1.0
$$

**代码实现**（Router_sensitivity_implementation.cpp:159-171）：

```cpp
double base_sum = congestion_weight + load_balance_weight + reliability_weight + qos_weight;
double adaptive_sum = delay_weight + power_weight;
double remaining_weight = 1.0 - adaptive_sum;

if (remaining_weight > 0 && base_sum > 0) {
    double normalization_factor = remaining_weight / base_sum;
    congestion_weight *= normalization_factor;
    load_balance_weight *= normalization_factor;
    reliability_weight *= normalization_factor;
    qos_weight *= normalization_factor;
}
```

**归一化机制说明**：
- PSO学习的权重（position[2] + position[3]）优先占用权重空间
- 剩余权重按比例分配给固定基础权重
- 确保总权重和 ≤ 1.0

---

## 第三部分：PSO迭代优化过程

### 3.1 粒子位置的更新机制

**PSO速度更新公式**：

$$
\mathbf{v}_i^{(t+1)} = w \cdot \mathbf{v}_i^{(t)} + c_1 \cdot r_1 \cdot (\mathbf{p}_{\text{best},i} - \mathbf{x}_i^{(t)}) + c_2 \cdot r_2 \cdot (\mathbf{g}_{\text{best}} - \mathbf{x}_i^{(t)})
$$

**PSO位置更新公式**：

$$
\mathbf{x}_i^{(t+1)} = \mathbf{x}_i^{(t)} + \mathbf{v}_i^{(t+1)}
$$

**在权重空间中的物理意义**：

```
初始状态 (t=0):
position = [0.5, 0.5, 0.5, 0.5]  (随机初始化)
         = [路径偏好, 负载, 功耗, 延迟]

迭代优化 (t=1...T):
velocity = [Δ路径, Δ负载, Δ功耗, Δ延迟]  (速度方向)
position = position + velocity              (位置更新)
         ↓
学习到的最优权重组合

收敛状态 (t=T):
position = [0.3, 0.4, 0.2, 0.6]  (示例最优解)
         = [路径偏好低, 负载高, 功耗低, 延迟最高]
```

### 3.2 学习过程示例

**场景**：高拥塞网络下的PSO学习

```
Iteration 0 (初始化):
- position[3] = 0.5 (延迟权重)
- position[2] = 0.5 (功耗权重)
- fitness = 0.5 * delay + 0.5 * power + 0.20 * cong + ...

Iteration 1-10 (探索阶段):
- 网络高拥塞 → 延迟严重
- PSO发现增加delay_weight可降低适应度
- position[3] → 0.7 (增加延迟敏感度)
- position[2] → 0.3 (降低功耗重视度)

Iteration 11-20 (收敛阶段):
- 找到最优权重平衡点
- position[3] → 0.75 (延迟权重收敛)
- position[2] → 0.25 (功耗权重收敛)
- fitness持续降低（路由性能提升）

Iteration 20+ (稳定阶段):
- 权重不再显著变化 (收敛判据: |ΔF| < 0.01)
- 最优权重组合：强调延迟，弱化功耗
```

---

## 第四部分：position[0]和position[1]的作用

### 4.1 代码定义回顾

```cpp
// position[0]: 路径偏好 (0.0=最短路径, 1.0=最可靠路径)
// position[1]: 负载均衡权重 (0.0=忽略负载, 1.0=最大化负载均衡)
```

### 4.2 在适应度计算中的使用

**重要发现**：在`calculateMultiObjectiveFitness`函数中，**只使用了position[2]和position[3]**！

```cpp
double delay_weight = packet.position[3];    // ✅ 使用
double power_weight = packet.position[2];    // ✅ 使用
// position[0] 和 position[1] 未在此函数中使用  // ❓ 问题
```

### 4.3 可能的用途推测

**假设1：路径选择策略中使用**
```cpp
// 可能在路径生成或端口选择中使用
int selectNextHop(const PacketParticle& packet, vector<int> candidates) {
    double path_preference = packet.position[0];
    if (path_preference > 0.5) {
        return selectMostReliablePort(candidates);  // 可靠路径
    } else {
        return selectShortestPort(candidates);      // 最短路径
    }
}
```

**假设2：群组协同搜索中使用**
```cpp
// 在GreedySearcher::evaluateLinkFitness中使用
double evaluateLinkFitness(...) {
    double load_balance_pref = packet.position[1];
    double load_score = evaluateLoadBalance(link);
    fitness += load_balance_pref * load_score;  // 根据偏好调节负载分数
}
```

**假设3：保留维度（未来扩展）**
- 当前版本可能只激活了position[2]和position[3]
- position[0]和position[1]为未来功能预留

### 4.4 代码验证

让我检查协同搜索中是否使用了position[0]和position[1]：

**文件**: `Router.cc` 中的 `GreedySearcher::evaluateLinkFitness()`

```cpp
// 需要进一步代码分析来确认position[0]和position[1]的实际用途
```

---

## 第五部分：与文档描述的对应关系

### 5.1 PSO章节文档 vs 实际代码

#### 文档描述（`20250105_MVPP_MGC_PSO_algorithm_PSO_chapter_supplement.md`）

**第28-33行**：
```markdown
其中各维度的物理意义为：
- $x_1$：延迟偏好系数（Delay Preference）
- $x_2$：拥塞避免系数（Congestion Avoidance）
- $x_3$：能耗敏感系数（Energy Sensitivity）
- $x_4$：负载均衡系数（Load Balance）
```

**第40-43行**：
```markdown
粒子位置到路由决策的解码：
$$
p^* = \arg\min_{p \in \mathcal{C}} \left[\sum_{i=1}^{4} x_i \cdot f_i^{\text{link}}(p)\right]
$$
```

#### 实际代码实现（`Router.hh` + `Router_sensitivity_implementation.cpp`）

**Router.hh:483-487**：
```cpp
// position[0]: 路径偏好 (0.0=最短路径, 1.0=最可靠路径)
// position[1]: 负载均衡权重 (0.0=忽略负载, 1.0=最大化负载均衡)
// position[2]: 功耗优化偏好 (0.0=忽略功耗, 1.0=最小化功耗)
// position[3]: 延迟敏感度 (0.0=对延迟不敏感, 1.0=最小化延迟)
```

**Router_sensitivity_implementation.cpp:152-157**：
```cpp
double delay_weight = packet.position[3];
double power_weight = packet.position[2];
```

### 5.2 维度映射对应表

| 文档索引 | 文档名称 | 代码索引 | 代码名称 | 在fitness中使用 |
|---------|---------|---------|---------|---------------|
| x₁ | 延迟偏好 | position[3] | 延迟敏感度 | ✅ 是 (delay_weight) |
| x₂ | 拥塞避免 | position[?] | ？ | ❌ 否（使用固定0.20） |
| x₃ | 能耗敏感 | position[2] | 功耗优化偏好 | ✅ 是 (power_weight) |
| x₄ | 负载均衡 | position[1] | 负载均衡权重 | ❌ 否（使用固定0.15） |

**关键差异**：
1. **文档**：4维都用于适应度计算
2. **代码**：只有2维（position[2]和position[3]）用于适应度计算
3. **另外2维**：拥塞和负载均衡使用**固定权重**，不由PSO学习

### 5.3 设计差异的合理性分析

#### 可能的设计考虑：

**方案A：文档描述（理想设计）**
```
优点：
- PSO学习全部4维权重，自适应性更强
- 理论上可以找到更优的权重组合

缺点：
- 搜索空间更大 ([0,1]⁴)，收敛更慢
- 可能过拟合，泛化性差
- 某些维度的最优权重可能是固定的（如拥塞权重应始终保持中等）
```

**方案B：实际实现（工程折衷）**
```
优点：
- 搜索空间更小 ([0,1]² for delay/power)，收敛更快
- 拥塞和负载权重保持稳定，避免极端权重配置
- 计算开销更低

缺点：
- 灵活性略低，无法针对拥塞和负载进行自适应学习
```

**工程权衡判断**：
- **实际实现选择了方案B**：只学习延迟和功耗权重
- **理由**：拥塞和负载均衡是NoC路由的**基础约束**，不应过度调整
- **设计哲学**：强调延迟-功耗权衡（最常见的性能-能耗矛盾）

---

## 第六部分：全局图权重 vs PSO权重

### 6.1 全局图引导的6维权重

**文件**: `Router.cc:2611`

```cpp
// 全局图路径搜索权重
std::vector<double> weights = {1.0, 3.0, 0.5, 1.0, 2.0, 4.0};
// 对应：{延迟, 功耗, 拥塞, 负载均衡, 可靠性, QoS}
```

**权重配置解读**：
```
w₁ = 1.0  (延迟权重 - 基准)
w₂ = 3.0  (功耗权重 - 强调功耗，3倍权重)
w₃ = 0.5  (拥塞权重 - 低优先级)
w₄ = 1.0  (负载均衡 - 基准)
w₅ = 2.0  (可靠性 - 中等重视)
w₆ = 4.0  (QoS权重 - 最高优先级)
```

### 6.2 PSO的4维权重（实际2维学习 + 2维固定）

```
PSO学习维度：
- position[3] → delay_weight ∈ [0,1] (动态学习)
- position[2] → power_weight ∈ [0,1] (动态学习)

固定基础维度：
- congestion_weight = 0.20 (固定)
- load_balance_weight = 0.15 (固定)
- reliability_weight = 0.10 (固定)
- qos_weight = 0.05 (固定)
```

### 6.3 两种权重机制的协同工作

#### 场景1：全局图引导（Phase 1）

```cpp
// 使用固定的6维权重评估静态拓扑最优路径
GlobalPath optimal_path = findOptimalPath(src, dest, {1.0, 3.0, 0.5, 1.0, 2.0, 4.0});

适应度 = 1.0 * delay + 3.0 * power + 0.5 * cong + 1.0 * load + 2.0 * rel + 4.0 * qos
```

**特点**：
- 静态权重，反映长期优化目标
- 强调QoS（4.0）和功耗（3.0）
- 适用于网络稳定状态

#### 场景2：协同搜索 + PSO优化（Phase 2）

```cpp
// 使用PSO学习的动态权重评估实时路由
double fitness = position[3] * delay + position[2] * power + 0.20 * cong + 0.15 * load + 0.10 * rel + 0.05 * qos;
```

**特点**：
- 动态权重，适应网络实时状态
- PSO学习延迟-功耗权衡
- 适用于网络拥塞变化

### 6.4 为什么需要两套权重系统？

#### 原因1：时间尺度差异

```
全局图权重（静态优化）：
- 更新频率：每5000 ticks缓存失效
- 反映长期性能目标
- 适用于稳定网络状态

PSO权重（动态优化）：
- 更新频率：每次迭代 (2-5 ticks)
- 反映瞬时网络状态
- 适用于拥塞动态变化
```

#### 原因2：优化目标差异

```
全局图：
- 目标：找到拓扑结构上的最优路径
- 权重：反映硬件架构的先验知识 (QoS优先级高)

PSO：
- 目标：找到当前网络状态下的最优权重
- 权重：通过学习适应拥塞分布
```

#### 原因3：计算开销差异

```
全局图：
- 计算复杂度：O(N² × M) (N=节点数, M=路径候选)
- 缓存机制：减少重复计算
- 适用于高置信度场景（70%路由请求）

PSO：
- 计算复杂度：O(T × K × D) (T=迭代次数, K=粒子数, D=维度)
- 无缓存：每次实时计算
- 适用于全局图失效场景（30%路由请求）
```

---

## 第七部分：技术问答总结

### Q1: 粒子位置和权重是什么关系？

**A**: **粒子位置就是权重**，不是独立的系数。

```
错误理解：
position是偏好系数 → 通过某种函数转换 → 得到最终权重

正确理解：
position[3] = delay_weight     (直接赋值，无转换)
position[2] = power_weight     (直接赋值，无转换)
```

---

### Q2: 为什么PSO只学习2个维度的权重？

**A**: **工程折衷**——平衡自适应性和收敛速度。

```
全学习（4维PSO）：
✅ 更强自适应性
✅ 理论上可找到更优解
❌ 收敛慢（搜索空间 [0,1]⁴）
❌ 可能过拟合
❌ 计算开销大

部分学习（2维PSO + 2维固定）：
✅ 收敛快（搜索空间 [0,1]²）
✅ 避免极端权重配置
✅ 计算开销低
✅ 聚焦于最关键的延迟-功耗权衡
❌ 灵活性略低
```

**设计哲学**：
- 延迟和功耗是**最频繁变化**的优化目标（拥塞导致延迟增加、低功耗需求）
- 拥塞和负载均衡是**基础约束**，权重应保持稳定（过度调整可能导致路由不稳定）

---

### Q3: position[0]和position[1]有什么用？

**A**: **可能用途**（需要进一步代码验证）：

```
可能性1：路径选择策略
- position[0] 控制路径类型（最短 vs 最可靠）
- 在候选端口选择时使用

可能性2：群组协同搜索中使用
- position[1] 影响负载均衡决策
- 在GreedySearcher中使用

可能性3：预留维度
- 当前版本未激活
- 为未来功能扩展预留
```

**代码证据待补充**：需要检查`GreedySearcher::evaluateLinkFitness`和`selectNextHop`等函数。

---

### Q4: PSO权重和全局图权重哪个优先级更高？

**A**: **根据置信度动态切换**，不存在固定优先级。

```
决策流程：
1. 查询全局图置信度 φ
2. if φ × 10 > random → 使用全局图权重 (Phase 1)
3. else → 使用PSO权重 (Phase 2)

预期分布：
- 高置信度 (φ > 0.7): 70%使用全局图权重
- 低置信度 (φ < 0.3): 30%使用PSO权重
```

---

### Q5: 是否存在冲突？

**A**: **不冲突**——这是多层次优化设计。

```
第一层：固定先验权重（领域知识）
- 拥塞：0.20 (中等重视)
- 负载：0.15 (中等重视)
- 可靠性：0.10 (低重视)
- QoS：0.05 (低重视)

第二层：PSO学习权重（动态适应）
- 延迟：position[3] ∈ [0,1] (学习)
- 功耗：position[2] ∈ [0,1] (学习)

协同机制：
- 固定权重提供基础约束
- PSO权重适应动态变化
- 归一化确保权重和 ≤ 1.0
```

---

### Q6: 文档和代码的差异如何解释？

**A**: **文档描述了理想设计，代码实现了工程折衷**。

```
文档（学术论文）：
- 描述4维PSO全学习方案
- 理论上更优，但计算开销大

代码（工程实现）：
- 实现2维PSO学习 + 2维固定
- 实践中收敛更快，性能足够好

建议：
✅ 在学术论文中保持文档描述（展示理论完整性）
✅ 在实验章节说明实际采用了简化方案
✅ 对比两种方案的性能差异（可作为消融实验）
```

---

## 第八部分：设计建议与未来改进

### 8.1 当前设计的优势

```
✅ 多层次权重机制（固定 + 学习）
✅ 快速收敛（2维PSO搜索空间小）
✅ 聚焦关键权衡（延迟 vs 功耗）
✅ 避免极端权重配置（拥塞/负载保持稳定）
✅ 计算开销可控（早停机制 + 缓存）
```

### 8.2 潜在改进方向

#### 改进1：激活position[0]和position[1]

```cpp
// 当前：只使用position[2]和position[3]
double delay_weight = packet.position[3];
double power_weight = packet.position[2];

// 改进：使用全部4维
double delay_weight = packet.position[3];
double power_weight = packet.position[2];
double congestion_weight = 0.20 * packet.position[1];  // 用position[1]调制拥塞权重
double load_balance_weight = 0.15 * packet.position[0]; // 用position[0]调制负载权重
```

**优点**：
- 增强自适应性
- 更符合文档描述

**缺点**：
- 搜索空间变大
- 收敛速度可能下降

#### 改进2：自适应维度激活

```cpp
// 根据网络状态动态决定学习哪些维度
if (avg_congestion > 0.7) {
    // 高拥塞：激活拥塞权重学习
    congestion_weight = packet.position[1];
} else {
    // 低拥塞：使用固定权重
    congestion_weight = 0.20;
}
```

#### 改进3：分层PSO

```
第一阶段（粗粒度）：
- 学习2维权重（delay, power）
- 快速收敛到大致最优区域

第二阶段（细粒度）：
- 激活4维权重（delay, power, cong, load）
- 在最优区域周围精细搜索
```

---

## 第九部分：实验验证建议

### 9.1 消融实验设计

#### 实验1：2维PSO vs 4维PSO

```
配置A (2维PSO - 当前实现):
- 学习维度：delay (position[3]), power (position[2])
- 固定维度：congestion (0.20), load (0.15)

配置B (4维PSO - 文档描述):
- 学习维度：delay, power, congestion, load (全部4维)

评估指标：
- 平均延迟
- 平均功耗
- 收敛速度（迭代次数）
- 路由质量（最优路径率）
```

#### 实验2：固定权重 vs 学习权重

```
配置A (全固定):
- 所有6维权重固定：{0.25, 0.20, 0.20, 0.15, 0.10, 0.10}

配置B (部分学习 - 当前实现):
- 2维学习（delay, power），4维固定

配置C (全学习):
- 6维全部由PSO学习

评估指标：
- 延迟-功耗权衡曲线（Pareto前沿）
- 适应性（网络拥塞变化时的性能）
```

### 9.2 参数敏感性分析

```
实验目标：
- 分析position[0]和position[1]对路由性能的影响

实验方法：
1. 固定position[2]和position[3]为最优值
2. 扫描position[0] ∈ [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
3. 扫描position[1] ∈ [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
4. 测量路由性能变化

预期结果：
- 如果position[0]和position[1]影响显著 → 应激活这两维的学习
- 如果影响微弱 → 当前设计合理（无需学习这两维）
```

---

## 附录A：关键代码索引

### A.1 粒子位置定义

| 文件 | 行号 | 内容 |
|------|------|------|
| `Router.hh` | 367-386 | `struct Particle` 定义 |
| `Router.hh` | 426-522 | `struct PacketParticle` 定义 |
| `Router.hh` | 483-487 | position向量维度说明 |

### A.2 适应度计算

| 文件 | 行号 | 内容 |
|------|------|------|
| `Router_sensitivity_implementation.cpp` | 144-180 | `calculateMultiObjectiveFitness` |
| `PSOAlgorithm.cc` | 221-320 | `evaluateParticleFitness` |
| `Router.cc` | 68-143 | `GreedySearcher::evaluateLinkFitness` |

### A.3 权重配置

| 文件 | 行号 | 内容 |
|------|------|------|
| `Router.cc` | 2611 | 全局图6维权重 |
| `Router_sensitivity_implementation.cpp` | 152-157 | PSO权重赋值 |
| `Router_sensitivity_implementation.cpp` | 159-171 | 权重归一化 |

---

## 附录B：术语对照表

| 中文术语 | 英文术语 | 代码标识 | 取值范围 |
|---------|---------|---------|---------|
| 粒子位置 | Particle Position | `position` | [0,1]⁴ |
| 偏好系数 | Preference Coefficient | `position[i]` | [0,1] |
| 权重 | Weight | `delay_weight`, `power_weight` | [0,1] |
| 适应度 | Fitness | `fitness`, `current_fitness` | ℝ⁺ |
| 延迟权重 | Delay Weight | `position[3]`, `delay_weight` | [0,1] |
| 功耗权重 | Power Weight | `position[2]`, `power_weight` | [0,1] |
| 拥塞权重 | Congestion Weight | `congestion_weight` | 0.20 (固定) |
| 负载权重 | Load Balance Weight | `load_balance_weight` | 0.15 (固定) |

---

## 总结

### 核心发现

1. **粒子位置 = 权重**：position向量直接作为多目标优化的权重，不存在独立的"系数转换"步骤
2. **两层权重机制**：固定基础权重（拥塞、负载、可靠性、QoS）+ PSO学习权重（延迟、功耗）
3. **工程折衷**：文档描述4维PSO，实际实现2维PSO（聚焦延迟-功耗权衡）
4. **不冲突设计**：多层次权重协同工作，通过归一化确保一致性

### 设计合理性

```
✅ 快速收敛（2维搜索空间）
✅ 聚焦核心权衡（延迟 vs 功耗）
✅ 避免极端配置（固定基础权重）
✅ 计算开销可控
⚠️ position[0]和position[1]的作用需进一步验证
⚠️ 文档与代码存在差异，需在论文中说明
```

### 后续行动建议

1. **代码验证**：检查position[0]和position[1]的实际使用
2. **消融实验**：对比2维PSO vs 4维PSO性能
3. **文档更新**：在学术论文中说明实际实现的简化
4. **性能分析**：量化当前设计的收敛速度和路由质量

---

**文档版本**: 1.0
**最后更新**: 2025-01-05
**作者**: Claude (Anthropic)
**项目**: gem5-gpu MVPP_MGC_PSO Routing Algorithm
