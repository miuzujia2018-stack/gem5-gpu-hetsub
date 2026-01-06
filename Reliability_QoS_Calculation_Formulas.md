# 可靠性(Reliability)和QoS计算公式详解

**项目**: gem5-gpu MVPP_MGC_PSO路由算法
**分析日期**: 2025-12-03
**代码路径**: `/home/siat/gem5-gpu-bak/gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc`

---

## 1. 可靠性 (Reliability) 指标详解

### 1.1 定义

**可靠性 (Reliability)** 表示数据包在NoC网络中成功传输的可能性，受以下因素影响：
- **网络拥塞程度**: 拥塞越高，丢包/重传概率越高，可靠性越低
- **路径跳数**: 跳数越多，累积失败概率越高，可靠性越低
- **基准可靠性**: 假设理想条件下的基础可靠性水平

**值域**: [0.5, 1.0]
- `1.0` = 完美可靠性 (无拥塞、最短路径)
- `0.5` = 最低可靠性阈值 (高拥塞、长路径)

---

### 1.2 计算公式

#### 1.2.1 原始可靠性因子计算

**函数**: `Router::getCurrentReliabilityFactor(int src, int dest)`
**位置**: Router.cc:2723-2733

```cpp
double Router::getCurrentReliabilityFactor(int src, int dest) const {
    // [1] 基准可靠性 (理想条件)
    double base_reliability = 0.95;  // 95%基础可靠性

    // [2] 拥塞惩罚
    double congestion_penalty = getCurrentCongestionFactor(src, dest) * 0.1;

    // [3] 计算曼哈顿距离 (跳数)
    int src_x = src % 4, src_y = src / 4;
    int dest_x = dest % 4, dest_y = dest / 4;
    int hop_count = abs(src_x - dest_x) + abs(src_y - dest_y);

    // [4] 跳数惩罚
    double hop_penalty = hop_count * 0.02;

    // [5] 综合可靠性计算
    double reliability = base_reliability - congestion_penalty - hop_penalty;

    // [6] 限制在合理范围
    return std::max(0.5, std::min(1.0, reliability));
}
```

**数学公式**:

```
Reliability = clamp(R_base - P_congestion - P_hop, 0.5, 1.0)

其中:
  R_base = 0.95                                    (基准可靠性)
  P_congestion = CongestionFactor(src,dest) × 0.1  (拥塞惩罚)
  P_hop = HopCount(src,dest) × 0.02                (跳数惩罚)
  HopCount = |src_x - dest_x| + |src_y - dest_y|   (曼哈顿距离)
```

**示例计算**:

| 场景 | src→dest | 跳数 | 拥塞因子 | 拥塞惩罚 | 跳数惩罚 | 可靠性 |
|-----|---------|------|---------|---------|---------|-------|
| **最佳情况** | 0→1 | 1 | 0.0 | 0.0 | 0.02 | **0.93** |
| **中等情况** | 0→5 | 2 | 0.3 | 0.03 | 0.04 | **0.88** |
| **较差情况** | 0→15 | 6 | 0.8 | 0.08 | 0.12 | **0.75** |
| **最差情况** | 0→15 | 6 | 1.0 | 0.10 | 0.12 | **0.73** |

---

#### 1.2.2 拥塞因子计算 (CongestionFactor)

**函数**: `Router::getCurrentCongestionFactor(int src, int dest)`
**位置**: Router.cc:837-851

```cpp
double Router::getCurrentCongestionFactor(int src, int dest) const {
    double total_congestion = 0.0;
    int valid_links = 0;

    // 遍历所有出链路，计算平均拥塞度
    for (int i = 0; i < m_out_link.size(); i++) {
        if (i < m_link_congestion[m_id].size()) {
            total_congestion += m_link_congestion[m_id][i];
            valid_links++;
        }
    }

    if (valid_links > 0) {
        return total_congestion / valid_links;  // 平均拥塞度
    }
    return 0.0;
}
```

**数学公式**:

```
CongestionFactor = (Σ LinkCongestion_i) / NumValidLinks

其中:
  LinkCongestion_i = 第i条出链路的拥塞级别 [0.0, 1.0+]
  NumValidLinks = 有效出链路数量
```

---

#### 1.2.3 归一化可靠性 (Normalized Reliability)

**函数**: `PSOAlgorithm::normalizeReliability(double reliability)`
**位置**: PSOAlgorithm.cc:665-668

```cpp
double PSOAlgorithm::normalizeReliability(double reliability) const {
    return std::max(0.0, std::min(1.0, 1.0 - reliability));
}
```

**数学公式**:

```
NormalizedReliability = clamp(1.0 - Reliability, 0.0, 1.0)
```

**说明**:
- **反转归一化**: 将可靠性转换为"不可靠性"成本
- 可靠性0.9 → 归一化成本0.1 (低成本，好)
- 可靠性0.5 → 归一化成本0.5 (高成本，差)

**适应度贡献**:
```
FitnessReliability = NormalizedReliability × WeightReliability
                   = (1.0 - Reliability) × 0.10
```

---

## 2. QoS (Quality of Service) 指标详解

### 2.1 定义

**QoS (服务质量)** 表示网络满足数据包服务质量需求的程度，综合考虑：
- **拥塞影响**: 拥塞导致QoS下降
- **延迟影响**: 过高延迟导致QoS下降
- **基准QoS**: 假设理想条件下的基础服务质量

**值域**: [0.0, 1.0]
- `1.0` = 完美QoS (无拥塞、低延迟)
- `0.0` = 最差QoS (严重拥塞、高延迟)

---

### 2.2 计算公式

#### 2.2.1 原始QoS因子计算

**函数**: `Router::getCurrentQoSFactor(int src, int dest)`
**位置**: Router.cc:2735-2744

```cpp
double Router::getCurrentQoSFactor(int src, int dest) const {
    // [1] 基准QoS (理想条件)
    double base_qos = 0.8;  // 80%基础QoS

    // [2] 获取拥塞因子
    double congestion_factor = getCurrentCongestionFactor(src, dest);
    double congestion_impact = congestion_factor * 0.3;

    // [3] 获取延迟因子
    double delay_factor = getCurrentDelayFactor(src, dest);
    // 延迟阈值: 4.0 (单位: hops + 拥塞延迟)
    double delay_impact = (delay_factor > 4.0) ? (delay_factor - 4.0) * 0.1 : 0.0;

    // [4] 综合QoS计算
    double qos_satisfaction = base_qos - congestion_impact - delay_impact;

    // [5] 限制在合理范围
    return std::max(0.0, std::min(1.0, qos_satisfaction));
}
```

**数学公式**:

```
QoS = clamp(QoS_base - I_congestion - I_delay, 0.0, 1.0)

其中:
  QoS_base = 0.8                                    (基准QoS)
  I_congestion = CongestionFactor(src,dest) × 0.3   (拥塞影响)
  I_delay = max(0, DelayFactor - 4.0) × 0.1         (延迟影响)
  DelayFactor = 详见下文
```

**示例计算**:

| 场景 | 拥塞因子 | 延迟因子 | 拥塞影响 | 延迟影响 | QoS |
|-----|---------|---------|---------|---------|-----|
| **最佳情况** | 0.0 | 2.0 | 0.0 | 0.0 | **0.80** |
| **中等情况** | 0.3 | 4.5 | 0.09 | 0.05 | **0.66** |
| **较差情况** | 0.6 | 6.0 | 0.18 | 0.20 | **0.42** |
| **最差情况** | 1.0 | 10.0 | 0.30 | 0.60 | **0.00** (限制在0.0) |

---

#### 2.2.2 延迟因子计算 (DelayFactor)

**函数**: `Router::getCurrentDelayFactor(int src, int dest)`
**位置**: Router.cc:823-835

```cpp
double Router::getCurrentDelayFactor(int src, int dest) const {
    // [1] 计算曼哈顿距离 (基础延迟)
    int src_x = src % 4, src_y = src / 4;
    int dest_x = dest % 4, dest_y = dest / 4;
    double base_delay = abs(src_x - dest_x) + abs(src_y - dest_y);

    // [2] 累加拥塞延迟
    double congestion_delay = 0.0;
    for (int i = 0; i < m_out_link.size(); i++) {
        if (i < m_link_congestion[m_id].size()) {
            congestion_delay += m_link_congestion[m_id][i] * 0.5;
        }
    }

    return base_delay + congestion_delay;
}
```

**数学公式**:

```
DelayFactor = BaseDelay + CongestionDelay

其中:
  BaseDelay = |src_x - dest_x| + |src_y - dest_y|           (曼哈顿距离)
  CongestionDelay = Σ (LinkCongestion_i × 0.5)              (拥塞累积延迟)
```

**延迟因子示例**:

| src→dest | 曼哈顿距离 | 链路拥塞总和 | 拥塞延迟 | 延迟因子 |
|---------|-----------|------------|---------|---------|
| 0→1     | 1         | 0.0        | 0.0     | **1.0** |
| 0→5     | 2         | 1.2        | 0.6     | **2.6** |
| 0→10    | 4         | 2.4        | 1.2     | **5.2** |
| 0→15    | 6         | 4.0        | 2.0     | **8.0** |

---

#### 2.2.3 归一化QoS (Normalized QoS)

**函数**: `PSOAlgorithm::normalizeQoS(double qos)`
**位置**: PSOAlgorithm.cc:670-673

```cpp
double PSOAlgorithm::normalizeQoS(double qos) const {
    return std::max(0.0, std::min(1.0, qos));
}
```

**数学公式**:

```
NormalizedQoS = clamp(QoS, 0.0, 1.0)
```

**说明**:
- **直接归一化**: 不进行反转，QoS值直接作为成本
- QoS越高 → 归一化成本越高 → **适应度越差** (注意:这可能需要调整!)

**适应度贡献**:
```
FitnessQoS = NormalizedQoS × WeightQoS
           = QoS × 0.05
```

**⚠️ 潜在问题**:
当前实现中，QoS值直接作为成本项，意味着**QoS越高，适应度越差**，这与常识相悖！
建议修正为: `NormalizedQoS = 1.0 - QoS` (与Reliability保持一致)

---

## 3. QoS类别枚举 (QoSClass)

**位置**: Router.hh:376-383

```cpp
enum QoSClass {
    BEST_EFFORT = 0,     // 尽力而为服务 (无保证)
    LOW_LATENCY = 1,     // 低延迟服务 (实时流量)
    HIGH_THROUGHPUT = 2, // 高吞吐量服务 (批量数据)
    REAL_TIME = 3,       // 实时服务 (严格时延要求)
    GUARANTEED = 4       // 保证服务 (最高优先级)
};
```

**QoS类别影响**:
- 不同QoS类别的数据包在路由决策时权重不同
- `REAL_TIME`和`GUARANTEED`对延迟和可靠性要求更高

---

## 4. 多目标适应度函数中的应用

### 4.1 适应度计算流程

**函数**: `Router::calculateMultiObjectiveFitness(const PacketParticle& packet)`
**位置**: Router.cc:2576-2619

```cpp
double Router::calculateMultiObjectiveFitness(const PacketParticle& packet) {
    // [1] 计算原始因子
    double delay_factor = getCurrentDelayFactor(src, dest);
    double power_factor = getCurrentEnergyFactor(src, dest);
    double congestion_factor = getCurrentCongestionFactor(src, dest);
    double load_balance_factor = getCurrentLoadBalanceFactor(src, dest);
    double reliability_factor = getCurrentReliabilityFactor(src, dest);  // ← 这里
    double qos_factor = getCurrentQoSFactor(src, dest);                  // ← 这里

    // [2] 归一化处理
    double normalized_delay = normalizeDelay(delay_factor);
    double normalized_power = normalizePower(power_factor);
    double normalized_congestion = normalizeCongestion(congestion_factor);
    double normalized_load_balance = normalizeLoadBalance(load_balance_factor);
    double normalized_reliability = normalizeReliability(reliability_factor);  // ← 这里
    double normalized_qos = normalizeQoS(qos_factor);                          // ← 这里

    // [3] 获取路由目标权重
    std::vector<double> weights = getRoutingObjectiveWeights(packet.routing_objective);
    // weights = [delay_w, power_w, congestion_w, load_balance_w, reliability_w, qos_w]
    //         = [  0.25,    0.20,        0.20,           0.20,          0.10,    0.05]  // 默认

    // [4] 综合适应度计算
    double fitness = weights[0] * normalized_delay
                   + weights[1] * normalized_power
                   + weights[2] * normalized_congestion
                   + weights[3] * normalized_load_balance
                   + weights[4] * normalized_reliability
                   + weights[5] * normalized_qos;

    return fitness;
}
```

---

### 4.2 权重配置

**位置**: Router.hh:396-407

```cpp
struct RoutingObjective {
    double weight_delay;        // 延迟权重 [0.0-1.0]
    double weight_power;        // 功耗权重 [0.0-1.0]
    double weight_congestion;   // 拥塞权重 [0.0-1.0]
    double weight_load_balance; // 负载均衡权重 [0.0-1.0]
    double weight_reliability;  // 可靠性权重 [0.0-1.0]
    double weight_qos;          // QoS权重 [0.0-1.0]

    // 默认权重配置
    RoutingObjective() :
        weight_delay(0.25),          // 25%
        weight_power(0.20),          // 20%
        weight_congestion(0.20),     // 20%
        weight_load_balance(0.20),   // 20%
        weight_reliability(0.10),    // 10%
        weight_qos(0.05) {}          // 5%
};
```

**不同路由目标的权重配置**:

**位置**: PSOAlgorithm.cc:675-690

```cpp
std::vector<double> PSOAlgorithm::getRoutingObjectiveWeights(int routing_objective) const {
    switch (routing_objective) {
        case 0: // MINIMIZE_DELAY
            return {0.5, 0.1, 0.2, 0.1, 0.05, 0.05};  // 延迟权重50%

        case 1: // MINIMIZE_POWER
            return {0.1, 0.5, 0.2, 0.1, 0.05, 0.05};  // 功耗权重50%

        case 2: // MINIMIZE_CONGESTION
            return {0.1, 0.1, 0.5, 0.2, 0.05, 0.05};  // 拥塞权重50%

        case 3: // MAXIMIZE_RELIABILITY
            return {0.1, 0.1, 0.2, 0.1, 0.45, 0.05};  // 可靠性权重45%

        case 4: // BALANCED (默认)
            return {0.25, 0.20, 0.20, 0.20, 0.10, 0.05};

        default:
            return {0.25, 0.20, 0.20, 0.20, 0.10, 0.05};
    }
}
```

---

## 5. 完整计算示例

### 5.1 场景: Router 0 → Router 15 (对角线最长路径)

**网络状态假设**:
- 平均链路拥塞: 0.4
- 链路拥塞总和: 2.0
- 路由器出链路数: 4

**步骤1: 计算原始因子**

```
[1] DelayFactor:
    BaseDelay = |0-3| + |0-3| = 6 (曼哈顿距离)
    CongestionDelay = 2.0 × 0.5 = 1.0
    DelayFactor = 6 + 1.0 = 7.0

[2] CongestionFactor:
    TotalCongestion = 2.0
    ValidLinks = 4
    CongestionFactor = 2.0 / 4 = 0.5

[3] ReliabilityFactor:
    BaseReliability = 0.95
    CongestionPenalty = 0.5 × 0.1 = 0.05
    HopPenalty = 6 × 0.02 = 0.12
    ReliabilityFactor = 0.95 - 0.05 - 0.12 = 0.78

[4] QoSFactor:
    BaseQoS = 0.8
    CongestionImpact = 0.5 × 0.3 = 0.15
    DelayImpact = (7.0 - 4.0) × 0.1 = 0.30
    QoSFactor = 0.8 - 0.15 - 0.30 = 0.35
```

**步骤2: 归一化处理**

```
NormalizedDelay = 假设normalizeDelay(7.0) = 0.7
NormalizedPower = 假设normalizePower(x) = 0.5
NormalizedCongestion = 假设normalizeCongestion(0.5) = 0.5
NormalizedLoadBalance = 假设normalizeLoadBalance(x) = 0.4
NormalizedReliability = 1.0 - 0.78 = 0.22
NormalizedQoS = 0.35  (⚠️ 可能有问题，应该是1.0-0.35=0.65)
```

**步骤3: 计算适应度 (BALANCED模式)**

```
Weights = [0.25, 0.20, 0.20, 0.20, 0.10, 0.05]

Fitness = 0.25 × 0.7   (delay)
        + 0.20 × 0.5   (power)
        + 0.20 × 0.5   (congestion)
        + 0.20 × 0.4   (load_balance)
        + 0.10 × 0.22  (reliability)
        + 0.05 × 0.35  (qos)

        = 0.175 + 0.10 + 0.10 + 0.08 + 0.022 + 0.0175
        = 0.4945
```

**适应度越小越好**, 这个路径适应度为0.4945，属于中等质量。

---

## 6. 关键参数汇总

### 6.1 可靠性参数

| 参数 | 值 | 说明 |
|-----|---|------|
| **基准可靠性** | 0.95 | 理想条件下的基础可靠性 |
| **拥塞惩罚系数** | 0.1 | 拥塞对可靠性的影响权重 |
| **跳数惩罚系数** | 0.02 | 每跳对可靠性的影响权重 |
| **可靠性下限** | 0.5 | 最低可靠性阈值 |
| **可靠性上限** | 1.0 | 最高可靠性阈值 |
| **默认权重** | 0.10 (10%) | 在BALANCED模式下的权重 |

### 6.2 QoS参数

| 参数 | 值 | 说明 |
|-----|---|------|
| **基准QoS** | 0.8 | 理想条件下的基础QoS |
| **拥塞影响系数** | 0.3 | 拥塞对QoS的影响权重 |
| **延迟影响系数** | 0.1 | 延迟对QoS的影响权重 |
| **延迟阈值** | 4.0 | 超过此阈值开始惩罚QoS |
| **QoS下限** | 0.0 | 最低QoS阈值 |
| **QoS上限** | 1.0 | 最高QoS阈值 |
| **默认权重** | 0.05 (5%) | 在BALANCED模式下的权重 |

---

## 7. 建议的改进方向

### 7.1 QoS归一化修正

**当前问题**: `normalizeQoS(qos) = qos` 导致QoS越高适应度越差

**建议修改**:
```cpp
double PSOAlgorithm::normalizeQoS(double qos) const {
    return std::max(0.0, std::min(1.0, 1.0 - qos));  // 反转归一化
}
```

### 7.2 可靠性与QoS权重动态调整

根据数据包的QoS类别动态调整权重:

```cpp
if (packet.qos_class == REAL_TIME || packet.qos_class == GUARANTEED) {
    weights[4] *= 2.0;  // 可靠性权重加倍
    weights[5] *= 2.0;  // QoS权重加倍
}
```

### 7.3 拥塞自适应可靠性模型

当网络拥塞严重时，降低可靠性下限:

```cpp
double min_reliability = (global_congestion > 0.8) ? 0.3 : 0.5;
return std::max(min_reliability, std::min(1.0, reliability));
```

---

## 8. 总结

### 8.1 可靠性 (Reliability)

**物理意义**: 数据包成功传输的概率
**影响因素**: 拥塞程度(-10%) + 路径跳数(-2%/hop)
**取值范围**: [0.5, 1.0]
**适应度贡献**: `(1.0 - Reliability) × 0.10`

### 8.2 QoS (Quality of Service)

**物理意义**: 网络满足服务质量需求的程度
**影响因素**: 拥塞程度(-30%) + 超额延迟(-10%)
**取值范围**: [0.0, 1.0]
**适应度贡献**: `QoS × 0.05` (⚠️ 需要修正为`(1.0-QoS)×0.05`)

### 8.3 关键代码位置

| 功能 | 函数 | 文件:行号 |
|-----|------|----------|
| 可靠性计算 | `getCurrentReliabilityFactor()` | Router.cc:2723-2733 |
| QoS计算 | `getCurrentQoSFactor()` | Router.cc:2735-2744 |
| 拥塞因子 | `getCurrentCongestionFactor()` | Router.cc:837-851 |
| 延迟因子 | `getCurrentDelayFactor()` | Router.cc:823-835 |
| 可靠性归一化 | `normalizeReliability()` | PSOAlgorithm.cc:665-668 |
| QoS归一化 | `normalizeQoS()` | PSOAlgorithm.cc:670-673 |
| 多目标适应度 | `calculateMultiObjectiveFitness()` | Router.cc:2576-2619 |

---

**文档版本**: v1.0
**最后更新**: 2025-12-03
**作者**: Claude Code Analysis Tool
