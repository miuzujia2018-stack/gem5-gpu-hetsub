# MVPP_MGC_PSO拥塞数据结构整合方案

## 问题分析

当前代码中存在三套重复的拥塞管理数据结构，导致：
1. 内存浪费
2. 数据不一致
3. 维护困难
4. 潜在的段错误

## 重复的数据结构

### 1. Router类成员变量
```cpp
std::vector<std::vector<double>> m_link_congestion;  // 16x16矩阵
```

### 2. Router类静态成员变量  
```cpp
std::vector<std::vector<double>> Router::global_link_congestion;  // 全局16x16矩阵
std::mutex Router::global_congestion_mutex;
```

### 3. GlobalGraph类中的拥塞数据
```cpp
struct GlobalNode {
    double congestion_level;          // 节点拥塞级别
    double processing_load;           // 处理负载
    double buffer_utilization;       // 缓冲区利用率
};

struct GlobalEdge {
    double congestion;                // 拥塞度
    double utilization;               // 利用率
    double delay;                     // 传播延迟
};
```

## 整合方案

### 阶段1：统一到GlobalGraph
1. **移除重复的拥塞矩阵**
   - 删除 `m_link_congestion`
   - 删除 `global_link_congestion`
   - 删除 `global_congestion_mutex`

2. **使用GlobalGraph作为唯一数据源**
   - 所有拥塞查询通过 `s_global_graph->getNode(node_id)->congestion_level`
   - 所有边拥塞查询通过 `s_global_graph->getEdge(edge_id)->congestion`

### 阶段2：更新MVPP_MGC_PSO算法
1. **修改拥塞计算函数**
```cpp
// 旧代码
double Router::calculatePathCongestionMVPP(const std::vector<int>& path) {
    for (int i = 0; i < path.size() - 1; i++) {
        int current_router = path[i];
        if (current_router < global_link_congestion.size()) {
            for (double congestion : global_link_congestion[current_router]) {
                congestion_penalty += congestion * 15.0;
            }
        }
    }
    return congestion_penalty;
}

// 新代码
double Router::calculatePathCongestionMVPP(const std::vector<int>& path) {
    double congestion_penalty = 0.0;
    if (s_global_graph == nullptr) return 0.0;
    
    for (int i = 0; i < path.size() - 1; i++) {
        int current_router = path[i];
        int next_router = path[i + 1];
        
        GlobalEdge* edge = s_global_graph->getEdgeBetweenNodes(current_router, next_router);
        if (edge != nullptr) {
            congestion_penalty += edge->congestion * 15.0;
        }
    }
    return congestion_penalty;
}
```

2. **修改拥塞更新函数**
```cpp
// 旧代码
void Router::updateCongestionProbabilityMVPP(...) {
    if (src < global_link_congestion.size() && dest < global_link_congestion[src].size()) {
        double new_congestion = std::min(1.0, global_link_congestion[src][dest] + count * 0.1);
        global_link_congestion[src][dest] = new_congestion;
    }
}

// 新代码
void Router::updateCongestionProbabilityMVPP(...) {
    if (s_global_graph == nullptr) return;
    
    GlobalEdge* edge = s_global_graph->getEdgeBetweenNodes(src, dest);
    if (edge != nullptr) {
        double new_congestion = std::min(1.0, edge->congestion + count * 0.1);
        s_global_graph->updateEdgeState(edge->edge_id, new_congestion, edge->utilization, edge->delay);
    }
}
```

### 阶段3：内存优化
1. **减少内存分配**
   - 移除16x16的重复矩阵
   - 使用GlobalGraph的稀疏表示

2. **提高访问效率**
   - 使用GlobalGraph的索引映射
   - 缓存热点数据

## 实施步骤

### 步骤1：创建兼容性接口
```cpp
// 在GlobalGraph中添加兼容性方法
double GlobalGraph::getNodeCongestion(int node_id) {
    GlobalNode* node = getNode(node_id);
    return (node != nullptr) ? node->congestion_level : 0.0;
}

double GlobalGraph::getEdgeCongestion(int src, int dest) {
    GlobalEdge* edge = getEdgeBetweenNodes(src, dest);
    return (edge != nullptr) ? edge->congestion : 0.0;
}

void GlobalGraph::updateNodeCongestion(int node_id, double congestion) {
    updateNodeState(node_id, congestion, 0.0, 0.0);
}

void GlobalGraph::updateEdgeCongestion(int src, int dest, double congestion) {
    GlobalEdge* edge = getEdgeBetweenNodes(src, dest);
    if (edge != nullptr) {
        updateEdgeState(edge->edge_id, congestion, edge->utilization, edge->delay);
    }
}
```

### 步骤2：逐步替换
1. 先添加兼容性接口
2. 逐步替换MVPP_MGC_PSO中的拥塞访问
3. 测试确保功能正常
4. 移除旧的拥塞矩阵

### 步骤3：验证和优化
1. 验证数据一致性
2. 性能测试
3. 内存使用优化

## 预期效果

1. **减少内存使用**：移除重复的16x16矩阵
2. **提高数据一致性**：单一数据源
3. **简化维护**：统一的拥塞管理
4. **减少段错误风险**：更安全的数据访问

## 风险评估

1. **兼容性风险**：需要确保所有使用旧接口的代码都更新
2. **性能风险**：GlobalGraph访问可能比直接数组访问慢
3. **调试风险**：需要仔细测试所有拥塞相关的功能

## 建议

1. **分阶段实施**：不要一次性替换所有代码
2. **充分测试**：每个阶段都要进行完整测试
3. **保留回退机制**：如果出现问题可以快速回退
4. **性能监控**：监控整合后的性能影响 