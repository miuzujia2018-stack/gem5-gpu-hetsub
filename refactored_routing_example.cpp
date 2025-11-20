// **重构后的路由算法实现示例**
// 展示正确的GlobalGraph与MVPP_MGC_PSO集成方式

#include "Router.hh"

// **主路由入口点：统一使用MVPP_MGC_PSO**
int Router::getRoute(NetDest destination) {
    // 所有路由请求统一使用MVPP_MGC_PSO算法
    // 不再有并行竞争的路由选择逻辑
    return getRouteMVPP_MGC_PSO(destination);
}

// **重构后的MVPP_MGC_PSO：正确集成GlobalGraph数据**
int Router::getRouteMVPP_MGC_PSO(NetDest destination) {
    Tick start_time = curTick();
    
    // === 第1步：提取基本路由信息 ===
    int src_node = m_id;
    int dest_node = extractDestinationNode(destination);
    
    if (dest_node == -1) {
        return getTraditionalRoute(destination);
    }
    
    // === 第2步：从GlobalGraph获取网络状态 ===
    // 这是关键！PSO算法基于全局状态进行优化
    GlobalGraph::NetworkState network_state = queryGlobalNetworkState();
    GlobalGraph::NodeCongestionInfo src_node_info = s_global_graph->getNodeCongestion(src_node);
    GlobalGraph::NodeCongestionInfo dest_node_info = s_global_graph->getNodeCongestion(dest_node);
    GlobalGraph::TopologyInfo topology = s_global_graph->getTopology();
    
    printf("MVPP_PSO: Router %d using global state - global_congestion=%.3f, src_load=%.3f, dest_load=%.3f\n",
           m_id, network_state.global_congestion_level, 
           src_node_info.processing_load, dest_node_info.processing_load);
    
    // === 第3步：基于全局状态生成可行路径 ===
    // 路径生成考虑全局拥塞和链路状态
    std::vector<std::vector<int>> feasible_paths = 
        generateFeasiblePathsWithGlobalState(src_node, dest_node, network_state);
    
    if (feasible_paths.empty()) {
        printf("MVPP_PSO: No feasible paths with global state, falling back\n");
        return getTraditionalRoute(destination);
    }
    
    // === 第4步：运行MVPP-MGC-PSO优化（使用全局状态） ===
    PSOResult result = runMVPP_MGC_PSO_WithGlobalState(feasible_paths, network_state, 
                                                       src_node, dest_node);
    
    // === 第5步：更新GlobalGraph状态 ===
    // 告知GlobalGraph我们的路由决策，用于后续优化
    updateGlobalStateAfterRouting(src_node, dest_node, result.next_hop);
    
    // === 第6步：统计和返回 ===
    Tick total_time = curTick() - start_time;
    psoRoutingTime += total_time;
    psoRoutingCount++;
    
    printf("MVPP_PSO: Router %d optimal route %d->%d: next_hop=%d, fitness=%.3f\n",
           m_id, src_node, dest_node, result.next_hop, result.fitness);
    
    return result.next_hop;
}

// **新增：基于全局状态的PSO优化**
Router::PSOResult Router::runMVPP_MGC_PSO_WithGlobalState(
    const std::vector<std::vector<int>>& feasible_paths,
    const GlobalGraph::NetworkState& network_state,
    int src_node, int dest_node) {
    
    PSOResult result;
    result.next_hop = -1;
    result.fitness = 1e9;
    
    // PSO参数
    const int NUM_PARTICLES = 8;
    const int MAX_ITERATIONS = 10;
    const double W = 0.7, C1 = 1.5, C2 = 1.5;
    
    // 初始化粒子群
    std::vector<PacketParticle> particles(NUM_PARTICLES);
    for (int i = 0; i < NUM_PARTICLES; i++) {
        // 根据网络状态调整初始位置
        particles[i].position[0] = (network_state.global_congestion_level > 0.7) ? 0.8 : 0.5; // 高拥塞时偏向可靠路径
        particles[i].position[1] = network_state.load_balance_factor; // 负载均衡权重
        particles[i].position[2] = 0.5; // 功耗权重
        particles[i].position[3] = (src_node_info.processing_load > 0.8) ? 0.9 : 0.6; // CPU负载高时对延迟敏感
        
        particles[i].best_fitness = 1e9;
        particles[i].src_node = src_node;
        particles[i].dest_node = dest_node;
    }
    
    double global_best_fitness = 1e9;
    std::vector<double> global_best_position(4, 0.5);
    
    // PSO迭代优化
    for (int iter = 0; iter < MAX_ITERATIONS; iter++) {
        for (auto& particle : particles) {
            // **关键：适应度评估使用全局网络状态**
            double fitness = evaluatePositionMVPP(particle, feasible_paths, 
                                                 src_node, dest_node, network_state);
            
            // 更新个体最优
            if (fitness < particle.best_fitness) {
                particle.best_fitness = fitness;
                particle.best_position = particle.position;
                
                // 更新全局最优
                if (fitness < global_best_fitness) {
                    global_best_fitness = fitness;
                    global_best_position = particle.position;
                }
            }
            
            // 更新粒子速度和位置
            updateParticleWithGlobalState(particle, global_best_position, W, C1, C2, network_state);
        }
        
        // 早期收敛检测
        if (global_best_fitness < 10.0) break;
    }
    
    // 从最优解提取下一跳
    if (global_best_fitness < 1e8) {
        result.next_hop = extractNextHopFromPosition(global_best_position, feasible_paths, 
                                                   src_node, dest_node);
        result.fitness = global_best_fitness;
    }
    
    return result;
}

// **新增：基于全局状态的适应度评估**
double Router::evaluatePositionMVPP(const PacketParticle& particle,
                                   const std::vector<std::vector<int>>& feasible_paths,
                                   int src_node, int dest_node,
                                   const GlobalGraph::NetworkState& network_state) {
    
    if (feasible_paths.empty()) return 1e9;
    
    // 根据粒子位置选择路径
    int path_idx = static_cast<int>(particle.position[0] * feasible_paths.size());
    path_idx = std::min(path_idx, static_cast<int>(feasible_paths.size() - 1));
    const auto& path = feasible_paths[path_idx];
    
    double total_fitness = 0.0;
    
    // **1. 延迟成本（基于全局状态）**
    double delay_cost = 0.0;
    for (int i = 0; i < path.size() - 1; i++) {
        int current_node = path[i];
        int next_node = path[i + 1];
        
        // 从GlobalGraph获取实时链路延迟
        GlobalGraph::LinkUtilizationInfo link_info = 
            s_global_graph->getLinkUtilization(current_node, next_node);
        delay_cost += link_info.delay * (1.0 + link_info.congestion_level);
    }
    total_fitness += particle.position[3] * delay_cost; // 延迟权重
    
    // **2. 拥塞惩罚（基于全局状态）**
    double congestion_penalty = 0.0;
    for (int node : path) {
        GlobalGraph::NodeCongestionInfo node_info = s_global_graph->getNodeCongestion(node);
        congestion_penalty += node_info.congestion_level;
    }
    total_fitness += particle.position[0] * congestion_penalty; // 拥塞权重
    
    // **3. 负载均衡因子（基于全局状态）**
    double load_balance_penalty = (1.0 - network_state.load_balance_factor) * 10.0;
    total_fitness += particle.position[1] * load_balance_penalty; // 负载均衡权重
    
    // **4. 功耗成本（基于路径长度和节点负载）**
    double power_cost = path.size() * 5.0; // 基础功耗
    for (int node : path) {
        GlobalGraph::NodeCongestionInfo node_info = s_global_graph->getNodeCongestion(node);
        power_cost += node_info.processing_load * 2.0; // 高负载节点额外功耗
    }
    total_fitness += particle.position[2] * power_cost; // 功耗权重
    
    return total_fitness;
}

// **新增：基于全局状态的可行路径生成**
std::vector<std::vector<int>> Router::generateFeasiblePathsWithGlobalState(
    int src_node, int dest_node, const GlobalGraph::NetworkState& network_state) {
    
    std::vector<std::vector<int>> paths;
    
    // 1. 标准XY路径
    std::vector<int> xy_path = generateXYPath(src_node, dest_node);
    if (!xy_path.empty()) {
        paths.push_back(xy_path);
    }
    
    // 2. 标准YX路径
    std::vector<int> yx_path = generateYXPath(src_node, dest_node);
    if (!yx_path.empty() && yx_path != xy_path) {
        paths.push_back(yx_path);
    }
    
    // 3. **基于全局状态的最小拥塞路径**
    std::vector<int> min_congestion_path = generateMinCongestionPath(src_node, dest_node, network_state);
    if (!min_congestion_path.empty()) {
        paths.push_back(min_congestion_path);
    }
    
    // 4. **根据全局拥塞级别决定是否生成额外路径**
    if (network_state.global_congestion_level > 0.6) {
        // 高拥塞时生成更多备用路径
        std::vector<int> backup_path = generateBackupPath(src_node, dest_node, network_state);
        if (!backup_path.empty()) {
            paths.push_back(backup_path);
        }
    }
    
    return paths;
}

// **新增：查询全局网络状态**
GlobalGraph::NetworkState Router::queryGlobalNetworkState() {
    if (s_global_graph == nullptr) {
        // 返回默认状态
        GlobalGraph::NetworkState default_state;
        default_state.global_congestion_level = 0.5;
        default_state.load_balance_factor = 0.5;
        default_state.timestamp = curTick();
        return default_state;
    }
    
    return s_global_graph->getNetworkState();
}

// **新增：路由后更新全局状态**
void Router::updateGlobalStateAfterRouting(int src, int dest, int chosen_port) {
    if (s_global_graph != nullptr) {
        // 记录路由决策供GlobalGraph分析
        s_global_graph->recordRoutingDecision(src, dest, chosen_port);
        
        // 更新流量矩阵
        s_global_graph->updateTrafficMatrix(src, dest, 1.0);
    }
} 