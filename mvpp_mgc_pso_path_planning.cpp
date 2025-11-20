#include "mvpp_mgc_pso_path_planning.hpp"
#include <chrono>
#include <queue>
#include <set>

namespace sko {

// RoadNetwork 实现
void RoadNetwork::add_node(std::shared_ptr<Node> node) {
    nodes[node->id] = node;
}

void RoadNetwork::add_road(std::shared_ptr<Road> road) {
    roads[road->id] = road;
    adjacency_list[road->start_node].push_back(road->end_node);
}

std::shared_ptr<Node> RoadNetwork::get_node(int node_id) {
    auto it = nodes.find(node_id);
    return (it != nodes.end()) ? it->second : nullptr;
}

std::shared_ptr<Road> RoadNetwork::get_road(int road_id) {
    auto it = roads.find(road_id);
    return (it != roads.end()) ? it->second : nullptr;
}

std::shared_ptr<Road> RoadNetwork::get_road_between_nodes(int start_node, int end_node) {
    for (const auto& road_pair : roads) {
        auto road = road_pair.second;
        if (road->start_node == start_node && road->end_node == end_node) {
            return road;
        }
    }
    return nullptr;
}

// MVPPMGCPSO 实现
MVPPMGCPSO::MVPPMGCPSO(std::shared_ptr<RoadNetwork> network, 
                       std::vector<std::shared_ptr<Vehicle>> vehicles,
                       int max_iterations, int num_feasible_paths)
    : road_network_(network), vehicles_(vehicles), max_iterations_(max_iterations),
      num_feasible_paths_(num_feasible_paths), convergence_threshold_(0.001),
      w_start_(0.9), w_end_(0.4), c1_(1.5), c2_(1.5), c3_(1.0),
      current_iteration_(0), convergence_counter_(0),
      prev_global_best_fitness_(-std::numeric_limits<double>::infinity()),
      congestion_window_(10), hotspot_threshold_(0.8), execution_time_(0.0) {
    
    // 初始化随机数生成器
    auto seed = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    rng_.seed(static_cast<unsigned int>(seed));
    rand_ = std::uniform_real_distribution<double>(0.0, 1.0);
}

void MVPPMGCPSO::initialize() {
    // 创建群体
    create_swarms();
    
    // 初始化每个车辆的位置和速度
    for (auto& vehicle : vehicles_) {
        // 将车辆位置映射到2D空间
        auto start_node = road_network_->get_node(vehicle->start_node);
        auto end_node = road_network_->get_node(vehicle->end_node);
        
        if (start_node && end_node) {
            // 初始化位置为起点和终点之间的随机点
            vehicle->position[0] = start_node->x + rand_(rng_) * (end_node->x - start_node->x);
            vehicle->position[1] = start_node->y + rand_(rng_) * (end_node->y - start_node->y);
            vehicle->best_position = vehicle->position;
            
            // 初始化速度为随机值
            vehicle->velocity[0] = (rand_(rng_) - 0.5) * 2.0;
            vehicle->velocity[1] = (rand_(rng_) - 0.5) * 2.0;
            
            // 生成可行路径
            vehicle->feasible_paths = generate_feasible_paths(vehicle);
            
            // 检查是否生成了可行路径
            if (vehicle->feasible_paths.empty()) {
                std::cout << "Warning: Vehicle " << vehicle->id 
                          << " from " << vehicle->start_node 
                          << " to " << vehicle->end_node 
                          << " has no feasible paths" << std::endl;
                // 创建默认路径以防止除零错误
                vehicle->feasible_paths = {{vehicle->start_node, vehicle->end_node}};
            }
            
            // 评估初始位置适应度
            double fitness = evaluate_position(vehicle->position, vehicle);
            vehicle->best_fitness = fitness;
        }
    }
    
    // 初始化群体全局最优
    for (auto& swarm : swarms_) {
        if (!swarm->vehicles.empty()) {
            auto best_vehicle = *std::max_element(swarm->vehicles.begin(), swarm->vehicles.end(),
                [](const std::shared_ptr<Vehicle>& a, const std::shared_ptr<Vehicle>& b) {
                    return a->best_fitness < b->best_fitness;
                });
            swarm->global_best = best_vehicle->best_position;
            swarm->global_best_fitness = best_vehicle->best_fitness;
        }
    }
}

void MVPPMGCPSO::create_swarms() {
    // 检查是否有足够的车辆
    if (vehicles_.size() < 4) {
        // 如果车辆数量不足，创建一个包含所有车辆的主群体
        auto master_swarm = std::make_shared<Swarm>(0);
        master_swarm->vehicles = vehicles_;
        swarms_.push_back(master_swarm);
        return;
    }
    
    // 创建主群体
    int master_size = std::max(1, static_cast<int>(vehicles_.size() / 3));
    auto master_swarm = std::make_shared<Swarm>(0);
    master_swarm->vehicles.assign(vehicles_.begin(), vehicles_.begin() + master_size);
    swarms_.push_back(master_swarm);
    
    // 创建从属群体
    std::vector<std::shared_ptr<Vehicle>> remaining_vehicles(vehicles_.begin() + master_size, vehicles_.end());
    if (remaining_vehicles.empty()) {
        return;
    }
    
    int num_slave_swarms = std::min(3, static_cast<int>(remaining_vehicles.size()));
    int vehicles_per_swarm = std::max(1, static_cast<int>(remaining_vehicles.size() / num_slave_swarms));
    
    for (int i = 0; i < num_slave_swarms; ++i) {
        int start_idx = i * vehicles_per_swarm;
        int end_idx = (i == num_slave_swarms - 1) ? remaining_vehicles.size() : (i + 1) * vehicles_per_swarm;
        
        if (start_idx < remaining_vehicles.size()) {
            auto slave_swarm = std::make_shared<Swarm>(i + 1);
            slave_swarm->vehicles.assign(remaining_vehicles.begin() + start_idx, 
                                       remaining_vehicles.begin() + end_idx);
            swarms_.push_back(slave_swarm);
        }
    }
}

std::vector<std::vector<int>> MVPPMGCPSO::generate_feasible_paths(std::shared_ptr<Vehicle> vehicle, int k) {
    std::vector<std::vector<int>> paths;
    int start_node = vehicle->start_node;
    int end_node = vehicle->end_node;
    
    // 使用Dijkstra算法找到最短路径
    std::vector<int> shortest_path = find_shortest_path(start_node, end_node);
    if (!shortest_path.empty()) {
        paths.push_back(shortest_path);
    }
    
    // 生成额外的可行路径
    for (int i = 1; i < k; ++i) {
        // 临时增加选定路径道路的权重
        auto temp_network = std::make_shared<RoadNetwork>(*road_network_);
        for (const auto& path : paths) {
            for (size_t j = 0; j < path.size() - 1; ++j) {
                auto road = temp_network->get_road_between_nodes(path[j], path[j+1]);
                if (road) {
                    road->travel_time *= (1.0 + 0.5 * i);
                }
            }
        }
        
        // 在修改后的网络中寻找新路径
        std::vector<int> new_path = find_shortest_path(start_node, end_node, temp_network);
        if (!new_path.empty() && std::find(paths.begin(), paths.end(), new_path) == paths.end()) {
            paths.push_back(new_path);
        }
    }
    
    return paths;
}

std::vector<int> MVPPMGCPSO::find_shortest_path(int start_node, int end_node, std::shared_ptr<RoadNetwork> custom_network) {
    auto network = custom_network ? custom_network : road_network_;
    
    // 初始化距离表和前驱表
    std::map<int, double> distances;
    std::map<int, int> predecessors;
    std::set<int> visited;
    
    for (const auto& node_pair : network->nodes) {
        distances[node_pair.first] = std::numeric_limits<double>::infinity();
        predecessors[node_pair.first] = -1;
    }
    distances[start_node] = 0;
    
    // 优先队列
    std::priority_queue<std::pair<double, int>, 
                       std::vector<std::pair<double, int>>, 
                       std::greater<std::pair<double, int>>> pq;
    pq.push({0, start_node});
    
    while (!pq.empty()) {
        double current_distance = pq.top().first;
        int current_node = pq.top().second;
        pq.pop();
        
        if (visited.find(current_node) != visited.end()) {
            continue;
        }
        
        visited.insert(current_node);
        
        if (current_node == end_node) {
            break;
        }
        
        // 检查相邻节点
        auto it = network->adjacency_list.find(current_node);
        if (it != network->adjacency_list.end()) {
            for (int neighbor : it->second) {
                auto road = network->get_road_between_nodes(current_node, neighbor);
                if (road && visited.find(neighbor) == visited.end()) {
                    double distance = current_distance + road->travel_time;
                    
                    if (distance < distances[neighbor]) {
                        distances[neighbor] = distance;
                        predecessors[neighbor] = current_node;
                        pq.push({distance, neighbor});
                    }
                }
            }
        }
    }
    
    // 重建路径
    if (distances[end_node] == std::numeric_limits<double>::infinity()) {
        return std::vector<int>();  // 未找到路径
    }
    
    std::vector<int> path;
    int current = end_node;
    
    while (current != -1) {
        path.push_back(current);
        current = predecessors[current];
    }
    
    std::reverse(path.begin(), path.end());
    return path;
}

double MVPPMGCPSO::evaluate_position(const std::vector<double>& position, std::shared_ptr<Vehicle> vehicle) {
    if (vehicle->feasible_paths.empty()) {
        return -std::numeric_limits<double>::infinity();
    }
    
    int path_idx = static_cast<int>(position[0]) % vehicle->feasible_paths.size();
    if (path_idx < 0) path_idx += vehicle->feasible_paths.size();
    const std::vector<int>& path = vehicle->feasible_paths[path_idx];
    
    // 计算旅行时间成本
    double travel_time = calculate_path_travel_time(path);
    
    // 计算燃油消耗（基于路径长度和拥堵）
    double fuel_consumption = 0.0;
    for (size_t i = 0; i < path.size() - 1; ++i) {
        int current_node = path[i];
        int next_node = path[i+1];
        auto road = road_network_->get_road_between_nodes(current_node, next_node);
        if (road) {
            double base_fuel = road->length * 0.1;
            double congestion_fuel = base_fuel * (1 + road->congestion_prob);
            fuel_consumption += congestion_fuel;
        }
    }
    
    // 计算路径平滑度
    double smoothness_cost = 0.0;
    if (path.size() >= 3) {
        for (size_t i = 0; i < path.size() - 2; ++i) {
            auto node1 = road_network_->get_node(path[i]);
            auto node2 = road_network_->get_node(path[i+1]);
            auto node3 = road_network_->get_node(path[i+2]);
            if (node1 && node2 && node3) {
                double vec1_x = node2->x - node1->x;
                double vec1_y = node2->y - node1->y;
                double vec2_x = node3->x - node2->x;
                double vec2_y = node3->y - node2->y;
                
                double dot_product = vec1_x * vec2_x + vec1_y * vec2_y;
                double norm1 = std::sqrt(vec1_x * vec1_x + vec1_y * vec1_y);
                double norm2 = std::sqrt(vec2_x * vec2_x + vec2_y * vec2_y);
                
                if (norm1 > 0 && norm2 > 0) {
                    double cos_angle = dot_product / (norm1 * norm2);
                    cos_angle = std::max(-1.0, std::min(1.0, cos_angle));
                    double angle = std::acos(cos_angle);
                    if (angle > M_PI / 4) {
                        smoothness_cost += (angle - M_PI / 4) * 10;
                    }
                }
            }
        }
    }
    
    // 计算拥堵惩罚
    double congestion_penalty = 0.0;
    for (size_t i = 0; i < path.size() - 1; ++i) {
        int current_node = path[i];
        int next_node = path[i+1];
        auto road = road_network_->get_road_between_nodes(current_node, next_node);
        if (road && hotspot_segments_.find(road->id) != hotspot_segments_.end()) {
            congestion_penalty += 50;
        }
    }
    
    // 调整权重
    double total_cost = (0.6 * travel_time + 
                         0.2 * fuel_consumption + 
                         0.15 * congestion_penalty + 
                         0.05 * smoothness_cost);
    
    return -total_cost;
}

double MVPPMGCPSO::calculate_path_travel_time(const std::vector<int>& path) {
    double total_time = 0.0;
    
    for (size_t i = 0; i < path.size() - 1; ++i) {
        int current_node = path[i];
        int next_node = path[i+1];
        
        auto road = road_network_->get_road_between_nodes(current_node, next_node);
        if (road) {
            total_time += road->travel_time;
        }
        
        // 考虑交通灯等待时间
        if (i < path.size() - 2) {
            auto node = road_network_->get_node(next_node);
            if (node) {
                // 简化模型：假设50%概率需要红灯
                if (rand_(rng_) < 0.5) {
                    total_time += node->red_light_time / 2;
                }
            }
        }
    }
    
    return total_time;
}

void MVPPMGCPSO::update_slave_swarm(std::shared_ptr<Swarm> swarm) {
    if (swarm->vehicles.empty()) {
        return;
    }
    
    for (auto& vehicle : swarm->vehicles) {
        if (vehicle->feasible_paths.empty()) {
            continue;
        }
        
        // 计算当前迭代惯性权重
        double w = w_start_ - (w_start_ - w_end_) * (static_cast<double>(current_iteration_) / max_iterations_);
        
        // 更新速度
        double r1 = rand_(rng_);
        double r2 = rand_(rng_);
        
        for (int j = 0; j < 2; ++j) {
            vehicle->velocity[j] = w * vehicle->velocity[j] + 
                                  c1_ * r1 * (vehicle->best_position[j] - vehicle->position[j]) + 
                                  c2_ * r2 * (swarm->global_best[j] - vehicle->position[j]);
        }
        
        // 更新位置
        for (int j = 0; j < 2; ++j) {
            vehicle->position[j] += vehicle->velocity[j];
        }
        
        // 评估新位置
        double fitness = evaluate_position(vehicle->position, vehicle);
        
        // 更新个体最优位置
        if (fitness > vehicle->best_fitness) {
            vehicle->best_position = vehicle->position;
            vehicle->best_fitness = fitness;
            
            // 更新群体全局最优位置
            if (fitness > swarm->global_best_fitness) {
                swarm->global_best = vehicle->position;
                swarm->global_best_fitness = fitness;
            }
        }
    }
}

void MVPPMGCPSO::update_master_swarm() {
    auto master_swarm = swarms_[0];
    if (master_swarm->vehicles.empty()) {
        return;
    }
    
    // 获取所有从属群体的全局最优位置
    std::vector<std::vector<double>> slave_global_bests;
    std::vector<double> slave_global_best_fitnesses;
    
    for (size_t i = 1; i < swarms_.size(); ++i) {
        if (!swarms_[i]->vehicles.empty()) {
            slave_global_bests.push_back(swarms_[i]->global_best);
            slave_global_best_fitnesses.push_back(swarms_[i]->global_best_fitness);
        }
    }
    
    if (slave_global_bests.empty()) {
        return;
    }
    
    // 找到最佳从属群体最优解
    auto best_slave_idx = std::max_element(slave_global_best_fitnesses.begin(), 
                                          slave_global_best_fitnesses.end()) - slave_global_best_fitnesses.begin();
    const std::vector<double>& best_slave_global_best = slave_global_bests[best_slave_idx];
    
    for (auto& vehicle : master_swarm->vehicles) {
        if (vehicle->feasible_paths.empty()) {
            continue;
        }
        
        // 计算当前迭代惯性权重
        double w = w_start_ - (w_start_ - w_end_) * (static_cast<double>(current_iteration_) / max_iterations_);
        
        // 更新速度
        double r1 = rand_(rng_);
        double r2 = rand_(rng_);
        double r3 = rand_(rng_);
        
        for (int j = 0; j < 2; ++j) {
            vehicle->velocity[j] = w * vehicle->velocity[j] + 
                                  c1_ * r1 * (vehicle->best_position[j] - vehicle->position[j]) + 
                                  c2_ * r2 * (master_swarm->global_best[j] - vehicle->position[j]) + 
                                  c3_ * r3 * (best_slave_global_best[j] - vehicle->position[j]);
        }
        
        // 更新位置
        for (int j = 0; j < 2; ++j) {
            vehicle->position[j] += vehicle->velocity[j];
        }
        
        // 评估新位置
        double fitness = evaluate_position(vehicle->position, vehicle);
        
        // 更新个体最优位置
        if (fitness > vehicle->best_fitness) {
            vehicle->best_position = vehicle->position;
            vehicle->best_fitness = fitness;
            
            // 更新群体全局最优位置
            if (fitness > master_swarm->global_best_fitness) {
                master_swarm->global_best = vehicle->position;
                master_swarm->global_best_fitness = fitness;
            }
        }
    }
}

void MVPPMGCPSO::update_congestion_probability() {
    std::map<int, int> road_vehicle_counts;
    
    // 统计每条道路上的车辆数量
    for (const auto& vehicle : vehicles_) {
        if (!vehicle->feasible_paths.empty()) {
            int path_idx = static_cast<int>(vehicle->position[0]) % vehicle->feasible_paths.size();
            if (path_idx < 0) path_idx += vehicle->feasible_paths.size();
            const std::vector<int>& path = vehicle->feasible_paths[path_idx];
            
            for (size_t i = 0; i < path.size() - 1; ++i) {
                int start_node = path[i];
                int end_node = path[i+1];
                auto road = road_network_->get_road_between_nodes(start_node, end_node);
                if (road) {
                    road_vehicle_counts[road->id]++;
                }
            }
        }
    }
    
    // 更新拥堵概率
    for (const auto& count_pair : road_vehicle_counts) {
        int road_id = count_pair.first;
        int count = count_pair.second;
        auto road = road_network_->get_road(road_id);
        
        if (road) {
            // 计算当前拥堵比例
            double current_ratio = std::min(1.0, static_cast<double>(count) / std::max(1.0, road->capacity));
            
            // 更新历史数据
            historical_congestion_[road_id].push_back(current_ratio);
            if (historical_congestion_[road_id].size() > congestion_window_) {
                historical_congestion_[road_id].erase(historical_congestion_[road_id].begin());
            }
            
            // 计算加权拥堵概率
            double historical_weight = 0.3;
            double current_weight = 0.7;
            double historical_avg = 0.0;
            
            if (!historical_congestion_[road_id].empty()) {
                for (double val : historical_congestion_[road_id]) {
                    historical_avg += val;
                }
                historical_avg /= historical_congestion_[road_id].size();
            }
            
            road->congestion_prob = historical_weight * historical_avg + current_weight * current_ratio;
            
            // 识别热点路段
            if (road->congestion_prob > hotspot_threshold_) {
                hotspot_segments_.insert(road_id);
            } else {
                hotspot_segments_.erase(road_id);
            }
            
            // 更新旅行时间
            double base_travel_time = road->length / road->speed_limit;
            double congestion_factor = 1.0 + 5.0 * (road->congestion_prob * road->congestion_prob);
            if (hotspot_segments_.find(road_id) != hotspot_segments_.end()) {
                congestion_factor *= 1.5;
            }
            road->travel_time = base_travel_time * congestion_factor;
        }
    }
}

bool MVPPMGCPSO::check_convergence() {
    if (swarms_.empty() || swarms_[0]->vehicles.empty()) {
        return false;
    }
    
    double change = std::abs(swarms_[0]->global_best_fitness - prev_global_best_fitness_);
    if (change < convergence_threshold_) {
        convergence_counter_++;
        if (convergence_counter_ >= 10) {
            return true;
        }
    } else {
        convergence_counter_ = 0;
    }
    
    prev_global_best_fitness_ = swarms_[0]->global_best_fitness;
    return false;
}

std::map<int, std::vector<int>> MVPPMGCPSO::extract_optimal_paths() {
    std::map<int, std::vector<int>> optimal_paths;
    
    for (const auto& vehicle : vehicles_) {
        if (!vehicle->feasible_paths.empty()) {
            int path_idx = static_cast<int>(vehicle->best_position[0]) % vehicle->feasible_paths.size();
            if (path_idx < 0) path_idx += vehicle->feasible_paths.size();
            optimal_paths[vehicle->id] = vehicle->feasible_paths[path_idx];
        }
    }
    
    return optimal_paths;
}

bool MVPPMGCPSO::check_replanning_needed(std::shared_ptr<Vehicle> vehicle) {
    if (vehicle->feasible_paths.empty()) {
        return true;
    }
    
    int path_idx = static_cast<int>(vehicle->position[0]) % vehicle->feasible_paths.size();
    if (path_idx < 0) path_idx += vehicle->feasible_paths.size();
    const std::vector<int>& current_path = vehicle->feasible_paths[path_idx];
    
    // 检查当前路径是否经过任何热点
    for (size_t i = 0; i < current_path.size() - 1; ++i) {
        int current_node = current_path[i];
        int next_node = current_path[i+1];
        auto road = road_network_->get_road_between_nodes(current_node, next_node);
        if (road && hotspot_segments_.find(road->id) != hotspot_segments_.end()) {
            return true;
        }
    }
    
    // 检查是否有显著的拥堵变化
    double total_congestion_change = 0;
    for (size_t i = 0; i < current_path.size() - 1; ++i) {
        int current_node = current_path[i];
        int next_node = current_path[i+1];
        auto road = road_network_->get_road_between_nodes(current_node, next_node);
        if (road && historical_congestion_[road->id].size() >= 2) {
            double recent_change = std::abs(historical_congestion_[road->id].back() - 
                                          historical_congestion_[road->id][historical_congestion_[road->id].size() - 2]);
            total_congestion_change += recent_change;
        }
    }
    
    if (total_congestion_change > 0.7) {
        return true;
    }
    
    return false;
}

std::map<int, std::vector<int>> MVPPMGCPSO::optimize() {
    auto start_time = std::chrono::high_resolution_clock::now();
    
    // 初始化
    initialize();
    
    // 迭代优化
    for (int iteration = 0; iteration < max_iterations_; ++iteration) {
        current_iteration_ = iteration;
        
        // 更新从属群体
        for (size_t i = 1; i < swarms_.size(); ++i) {
            update_slave_swarm(swarms_[i]);
        }
        
        // 更新主群体
        update_master_swarm();
        
        // 更新拥堵概率
        update_congestion_probability();
        
        // 检查重新规划
        for (auto& vehicle : vehicles_) {
            if (check_replanning_needed(vehicle)) {
                vehicle->feasible_paths = generate_feasible_paths(vehicle);
                if (!vehicle->feasible_paths.empty()) {
                    vehicle->position[0] = rand_(rng_);
                    vehicle->position[1] = rand_(rng_);
                    vehicle->velocity[0] = (rand_(rng_) - 0.5) * 0.2;
                    vehicle->velocity[1] = (rand_(rng_) - 0.5) * 0.2;
                    vehicle->best_position = vehicle->position;
                    vehicle->best_fitness = evaluate_position(vehicle->position, vehicle);
                }
            }
        }
        
        // 检查收敛条件
        if (check_convergence()) {
            std::cout << "Algorithm converged at iteration " << iteration << std::endl;
            break;
        }
    }
    
    auto end_time = std::chrono::high_resolution_clock::now();
    execution_time_ = std::chrono::duration<double>(end_time - start_time).count();
    std::cout << "MVPP-MGC-PSO execution time: " << execution_time_ << " seconds" << std::endl;
    
    // 提取最优路径
    return extract_optimal_paths();
}

// 辅助函数实现
double calculate_path_travel_time(std::shared_ptr<RoadNetwork> network, const std::vector<int>& path) {
    double total_time = 0.0;
    
    for (size_t i = 0; i < path.size() - 1; ++i) {
        int current_node = path[i];
        int next_node = path[i+1];
        
        auto road = network->get_road_between_nodes(current_node, next_node);
        if (road) {
            total_time += road->travel_time;
        }
        
        // 考虑交通灯等待时间
        if (i < path.size() - 2) {
            auto node = network->get_node(next_node);
            if (node) {
                // 简化模型：假设50%概率需要红灯
                static std::mt19937 rng(std::chrono::high_resolution_clock::now().time_since_epoch().count());
                static std::uniform_real_distribution<double> rand(0.0, 1.0);
                if (rand(rng) < 0.5) {
                    total_time += node->red_light_time / 2;
                }
            }
        }
    }
    
    return total_time;
}

std::shared_ptr<RoadNetwork> create_sample_network() {
    auto network = std::make_shared<RoadNetwork>();
    
    // 创建节点（4x4网格）
    for (int i = 1; i <= 16; ++i) {
        double x = ((i-1) % 4) * 100.0;
        double y = ((i-1) / 4) * 100.0;
        auto node = std::make_shared<Node>(i, x, y);
        node->red_light_time = 30;
        node->green_light_time = 30;
        node->straight_time = 5;
        node->left_turn_time = 8;
        node->right_turn_time = 3;
        network->add_node(node);
    }
    
    int road_id = 1;
    // 水平道路
    for (int i = 1; i <= 4; ++i) {  // 1~4行
        for (int j = 1; j <= 3; ++j) {  // 1~3列
            int node_id = (i-1) * 4 + j;
            int next_node_id = node_id + 1;
            // 正向道路
            auto road = std::make_shared<Road>(road_id, node_id, next_node_id, 100, 2, 60);
            network->add_road(road);
            road_id++;
            // 反向道路
            road = std::make_shared<Road>(road_id, next_node_id, node_id, 100, 2, 60);
            network->add_road(road);
            road_id++;
        }
    }
    
    // 垂直道路
    for (int i = 1; i <= 3; ++i) {  // 1~3行
        for (int j = 1; j <= 4; ++j) {  // 1~4列
            int node_id = (i-1) * 4 + j;
            int next_node_id = i * 4 + j;
            // 正向道路
            auto road = std::make_shared<Road>(road_id, node_id, next_node_id, 100, 2, 60);
            network->add_road(road);
            road_id++;
            // 反向道路
            road = std::make_shared<Road>(road_id, next_node_id, node_id, 100, 2, 60);
            network->add_road(road);
            road_id++;
        }
    }
    
    return network;
}

std::pair<std::map<int, std::vector<int>>, double> run_xy_baseline(std::shared_ptr<RoadNetwork> network, 
                                                                   std::vector<std::shared_ptr<Vehicle>> vehicles) {
    std::map<int, std::vector<int>> paths;
    double total_time = 0.0;
    
    for (const auto& vehicle : vehicles) {
        int start = vehicle->start_node;
        int end = vehicle->end_node;
        auto start_node = network->get_node(start);
        auto end_node = network->get_node(end);
        
        if (!start_node || !end_node) {
            paths[vehicle->id] = {start, end};
            continue;
        }
        
        // 获取网格坐标
        int num_cols = 4;
        int sx = static_cast<int>(start_node->x / 100);
        int sy = static_cast<int>(start_node->y / 100);
        int ex = static_cast<int>(end_node->x / 100);
        int ey = static_cast<int>(end_node->y / 100);
        
        // 先移动x，再移动y
        std::vector<int> path = {start};
        int cur_x = sx, cur_y = sy;
        int cur_id = start;
        
        // 水平移动
        while (cur_x != ex) {
            int next_x = (ex > cur_x) ? cur_x + 1 : cur_x - 1;
            int next_id = next_x + cur_y * num_cols + 1;
            path.push_back(next_id);
            cur_x = next_x;
            cur_id = next_id;
        }
        
        // 垂直移动
        while (cur_y != ey) {
            int next_y = (ey > cur_y) ? cur_y + 1 : cur_y - 1;
            int next_id = cur_x + next_y * num_cols + 1;
            path.push_back(next_id);
            cur_y = next_y;
            cur_id = next_id;
        }
        
        paths[vehicle->id] = path;
        total_time += calculate_path_travel_time(network, path);
    }
    
    return {paths, total_time};
}

} // namespace sko 