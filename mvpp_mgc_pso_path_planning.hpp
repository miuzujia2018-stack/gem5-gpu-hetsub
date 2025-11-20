#ifndef MVPP_MGC_PSO_HPP
#define MVPP_MGC_PSO_HPP

#include <vector>
#include <random>
#include <functional>
#include <memory>
#include <cmath>
#include <limits>
#include <algorithm>
#include <iostream>
#include <map>
#include <set>
#include <chrono>
#include <queue>

namespace sko {

// 前向声明
class RoadNetwork;
class Node;
class Road;
class Vehicle;
class Swarm;
class MVPPMGCPSO;

// Node 类定义
class Node {
public:
    int id;
    double x, y;
    double red_light_time;
    double green_light_time;
    double straight_time;
    double left_turn_time;
    double right_turn_time;
    
    Node(int id, double x, double y) : id(id), x(x), y(y), 
        red_light_time(30), green_light_time(30), straight_time(5), 
        left_turn_time(8), right_turn_time(3) {}
};

// Road 类定义
class Road {
public:
    int id;
    int start_node;
    int end_node;
    double length;
    int lanes;
    double speed_limit;
    double travel_time;
    double congestion_prob;
    double capacity;
    
    Road(int id, int start_node, int end_node, double length, int lanes, double speed_limit)
        : id(id), start_node(start_node), end_node(end_node), length(length), 
          lanes(lanes), speed_limit(speed_limit), travel_time(length / speed_limit), 
          congestion_prob(0.0), capacity(lanes * 100) {}
};

// Vehicle 类定义
class Vehicle {
public:
    int id;
    int start_node;
    int end_node;
    std::vector<double> position;
    std::vector<double> velocity;
    std::vector<double> best_position;
    double best_fitness;
    std::vector<std::vector<int>> feasible_paths;
    
    Vehicle(int id, int start_node, int end_node) 
        : id(id), start_node(start_node), end_node(end_node), 
          position(2, 0.0), velocity(2, 0.0), best_position(2, 0.0), 
          best_fitness(-std::numeric_limits<double>::infinity()) {}
};

// Swarm 类定义
class Swarm {
public:
    int id;
    std::vector<std::shared_ptr<Vehicle>> vehicles;
    std::vector<double> global_best;
    double global_best_fitness;
    
    Swarm(int id) : id(id), global_best_fitness(-std::numeric_limits<double>::infinity()) {}
};

// RoadNetwork 类定义
class RoadNetwork {
public:
    std::map<int, std::shared_ptr<Node>> nodes;
    std::map<int, std::shared_ptr<Road>> roads;
    std::map<int, std::vector<int>> adjacency_list;
    
    void add_node(std::shared_ptr<Node> node);
    void add_road(std::shared_ptr<Road> road);
    std::shared_ptr<Node> get_node(int node_id);
    std::shared_ptr<Road> get_road(int road_id);
    std::shared_ptr<Road> get_road_between_nodes(int start_node, int end_node);
};

// MVPPMGCPSO 类定义
class MVPPMGCPSO {
public:
    MVPPMGCPSO(std::shared_ptr<RoadNetwork> network, 
               std::vector<std::shared_ptr<Vehicle>> vehicles,
               int max_iterations, int num_feasible_paths);
    
    void initialize();
    std::map<int, std::vector<int>> optimize();
    double get_execution_time() const { return execution_time_; }
    
private:
    std::shared_ptr<RoadNetwork> road_network_;
    std::vector<std::shared_ptr<Vehicle>> vehicles_;
    std::vector<std::shared_ptr<Swarm>> swarms_;
    
    int max_iterations_;
    int num_feasible_paths_;
    int current_iteration_;
    
    double convergence_threshold_;
    int convergence_counter_;
    double prev_global_best_fitness_;
    
    double w_start_, w_end_;
    double c1_, c2_, c3_;
    
    int congestion_window_;
    double hotspot_threshold_;
    double execution_time_;
    
    std::map<int, std::vector<double>> historical_congestion_;
    std::set<int> hotspot_segments_;
    
    std::mt19937 rng_;
    std::uniform_real_distribution<double> rand_;
    
    void create_swarms();
    std::vector<std::vector<int>> generate_feasible_paths(std::shared_ptr<Vehicle> vehicle, int k = 5);
    std::vector<int> find_shortest_path(int start_node, int end_node, std::shared_ptr<RoadNetwork> custom_network = nullptr);
    double evaluate_position(const std::vector<double>& position, std::shared_ptr<Vehicle> vehicle);
    double calculate_path_travel_time(const std::vector<int>& path);
    void update_slave_swarm(std::shared_ptr<Swarm> swarm);
    void update_master_swarm();
    void update_congestion_probability();
    bool check_convergence();
    std::map<int, std::vector<int>> extract_optimal_paths();
    bool check_replanning_needed(std::shared_ptr<Vehicle> vehicle);
};

// 辅助函数声明
double calculate_path_travel_time(std::shared_ptr<RoadNetwork> network, const std::vector<int>& path);
std::shared_ptr<RoadNetwork> create_sample_network();
std::pair<std::map<int, std::vector<int>>, double> run_xy_baseline(std::shared_ptr<RoadNetwork> network, 
                                                                   std::vector<std::shared_ptr<Vehicle>> vehicles);

} // namespace sko

#endif // MVPP_MGC_PSO_HPP 