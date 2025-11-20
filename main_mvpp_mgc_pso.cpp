#include "mvpp_mgc_pso_path_planning.hpp"
#include <iostream>
#include <random>
#include <iomanip>

using namespace sko;

void run_mvpp_mgc_pso() {
    std::cout << "Starting MVPP-MGC-PSO algorithm..." << std::endl;
    
    auto network = create_sample_network();
    std::vector<std::shared_ptr<Vehicle>> vehicles;
    
    // 创建随机数生成器
    std::mt19937 rng(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    std::uniform_int_distribution<int> node_dist(1, 16);
    
    // 创建12辆车
    for (int i = 0; i < 12; ++i) {
        int start_node = node_dist(rng);
        int end_node = node_dist(rng);
        while (end_node == start_node) {
            end_node = node_dist(rng);
        }
        auto vehicle = std::make_shared<Vehicle>(i, start_node, end_node);
        vehicles.push_back(vehicle);
    }
    
    auto mgc_pso = std::make_shared<MVPPMGCPSO>(network, vehicles, 200, 3);
    auto optimal_paths = mgc_pso->optimize();
    
    // 计算MVPP-MGC-PSO总旅行时间
    double mgc_pso_total_time = 0;
    std::cout << "Optimization Results (MVPP-MGC-PSO):" << std::endl;
    for (const auto& path_pair : optimal_paths) {
        std::cout << "Vehicle " << path_pair.first << ": [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
        mgc_pso_total_time += calculate_path_travel_time(network, path_pair.second);
    }
    std::cout << "Total travel time (MVPP-MGC-PSO): " << std::fixed << std::setprecision(2) 
              << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "MVPP-MGC-PSO execution time: " << std::fixed << std::setprecision(2) 
              << mgc_pso->get_execution_time() << " seconds" << std::endl;
    
    // 基线比较
    std::cout << "\nBaseline XY Algorithm Results:" << std::endl;
    auto xy_result = run_xy_baseline(network, vehicles);
    auto xy_paths = xy_result.first;
    auto xy_total_time = xy_result.second;
    for (const auto& path_pair : xy_paths) {
        std::cout << "Vehicle " << path_pair.first << ": [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    std::cout << "Total travel time (XY baseline): " << std::fixed << std::setprecision(2) 
              << xy_total_time << " seconds" << std::endl;
    
    // 打印比较摘要
    std::cout << "\nComparison of Total Travel Times:" << std::endl;
    std::cout << "---------------------------------" << std::endl;
    std::cout << "MVPP-MGC-PSO: " << std::fixed << std::setprecision(2) << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "XY Baseline: " << std::fixed << std::setprecision(2) << xy_total_time << " seconds" << std::endl;
    if (xy_total_time > 0) {
        double improvement = ((xy_total_time - mgc_pso_total_time) / xy_total_time * 100);
        std::cout << "Improvement: " << std::fixed << std::setprecision(2) << improvement << "%" << std::endl;
    }
    std::cout << "---------------------------------" << std::endl;
}

void case_study_1() {
    std::cout << "\nStarting Case Study 1..." << std::endl;
    
    auto network = create_sample_network();
    std::vector<std::shared_ptr<Vehicle>> vehicles;
    
    // 所有车辆从节点1出发，目的地分别为10, 13, 16
    std::vector<int> destinations = {10, 13, 16};
    for (size_t i = 0; i < destinations.size(); ++i) {
        auto vehicle = std::make_shared<Vehicle>(i, 1, destinations[i]);
        vehicles.push_back(vehicle);
    }
    
    auto mgc_pso = std::make_shared<MVPPMGCPSO>(network, vehicles, 200, 3);
    auto optimal_paths = mgc_pso->optimize();
    
    std::cout << "Case Study 1 - Path Planning Results for Vehicles with Same Start Point (MVPP-MGC-PSO):" << std::endl;
    for (const auto& path_pair : optimal_paths) {
        auto vehicle = vehicles[path_pair.first];
        std::cout << "Vehicle " << path_pair.first << " (" << vehicle->start_node << "->" << vehicle->end_node << "): [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    
    double mgc_pso_total_time = 0;
    for (const auto& path_pair : optimal_paths) {
        double travel_time = calculate_path_travel_time(network, path_pair.second);
        mgc_pso_total_time += travel_time;
        std::cout << "Vehicle " << path_pair.first << " travel time: " << std::fixed << std::setprecision(2) 
                  << travel_time << " seconds" << std::endl;
    }
    std::cout << "Total travel time (MVPP-MGC-PSO): " << std::fixed << std::setprecision(2) 
              << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "MVPP-MGC-PSO execution time: " << std::fixed << std::setprecision(2) 
              << mgc_pso->get_execution_time() << " seconds" << std::endl;
    
    // 基线比较
    std::cout << "\nCase Study 1 - Baseline XY Algorithm Results:" << std::endl;
    auto xy_result = run_xy_baseline(network, vehicles);
    auto xy_paths = xy_result.first;
    auto xy_total_time = xy_result.second;
    for (const auto& path_pair : xy_paths) {
        std::cout << "Vehicle " << path_pair.first << ": [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    std::cout << "Total travel time (XY baseline): " << std::fixed << std::setprecision(2) 
              << xy_total_time << " seconds" << std::endl;
    
    // 打印比较摘要
    std::cout << "\nCase Study 1 - Comparison of Total Travel Times:" << std::endl;
    std::cout << "---------------------------------" << std::endl;
    std::cout << "MVPP-MGC-PSO: " << std::fixed << std::setprecision(2) << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "XY Baseline: " << std::fixed << std::setprecision(2) << xy_total_time << " seconds" << std::endl;
    if (xy_total_time > 0) {
        double improvement = ((xy_total_time - mgc_pso_total_time) / xy_total_time * 100);
        std::cout << "Improvement: " << std::fixed << std::setprecision(2) << improvement << "%" << std::endl;
    }
    std::cout << "---------------------------------" << std::endl;
}

void case_study_2() {
    std::cout << "\nStarting Case Study 2..." << std::endl;
    
    auto network = create_sample_network();
    std::vector<std::shared_ptr<Vehicle>> vehicles;
    
    // 所有车辆前往节点12，起点分别为2, 7, 15
    std::vector<int> start_points = {2, 7, 15};
    int destination = 12;
    for (size_t i = 0; i < start_points.size(); ++i) {
        auto vehicle = std::make_shared<Vehicle>(i, start_points[i], destination);
        vehicles.push_back(vehicle);
    }
    
    auto mgc_pso = std::make_shared<MVPPMGCPSO>(network, vehicles, 200, 3);
    auto optimal_paths = mgc_pso->optimize();
    
    std::cout << "Case Study 2 - Path Planning Results for Vehicles with Same Destination (MVPP-MGC-PSO):" << std::endl;
    for (const auto& path_pair : optimal_paths) {
        auto vehicle = vehicles[path_pair.first];
        std::cout << "Vehicle " << path_pair.first << " (" << vehicle->start_node << "->" << vehicle->end_node << "): [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    
    double mgc_pso_total_time = 0;
    double max_time = 0;
    for (const auto& path_pair : optimal_paths) {
        double travel_time = calculate_path_travel_time(network, path_pair.second);
        mgc_pso_total_time += travel_time;
        max_time = std::max(max_time, travel_time);
        std::cout << "Vehicle " << path_pair.first << " travel time: " << std::fixed << std::setprecision(2) 
                  << travel_time << " seconds" << std::endl;
    }
    std::cout << "Total travel time (MVPP-MGC-PSO): " << std::fixed << std::setprecision(2) 
              << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "Maximum travel time: " << std::fixed << std::setprecision(2) << max_time << " seconds" << std::endl;
    std::cout << "MVPP-MGC-PSO execution time: " << std::fixed << std::setprecision(2) 
              << mgc_pso->get_execution_time() << " seconds" << std::endl;
    
    // 基线比较
    std::cout << "\nCase Study 2 - Baseline XY Algorithm Results:" << std::endl;
    auto xy_result = run_xy_baseline(network, vehicles);
    auto xy_paths = xy_result.first;
    auto xy_total_time = xy_result.second;
    for (const auto& path_pair : xy_paths) {
        std::cout << "Vehicle " << path_pair.first << ": [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    std::cout << "Total travel time (XY baseline): " << std::fixed << std::setprecision(2) 
              << xy_total_time << " seconds" << std::endl;
    
    // 打印比较摘要
    std::cout << "\nCase Study 2 - Comparison of Total Travel Times:" << std::endl;
    std::cout << "---------------------------------" << std::endl;
    std::cout << "MVPP-MGC-PSO: " << std::fixed << std::setprecision(2) << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "XY Baseline: " << std::fixed << std::setprecision(2) << xy_total_time << " seconds" << std::endl;
    if (xy_total_time > 0) {
        double improvement = ((xy_total_time - mgc_pso_total_time) / xy_total_time * 100);
        std::cout << "Improvement: " << std::fixed << std::setprecision(2) << improvement << "%" << std::endl;
    }
    std::cout << "---------------------------------" << std::endl;
}

void final_comparison_test() {
    std::cout << "\nStarting Final Comparison Test..." << std::endl;
    
    auto network = create_sample_network();
    std::vector<std::shared_ptr<Vehicle>> vehicles;
    
    // 创建随机数生成器
    std::mt19937 rng(std::chrono::high_resolution_clock::now().time_since_epoch().count());
    std::uniform_int_distribution<int> node_dist(1, 16);
    
    // 创建12辆车
    for (int i = 0; i < 12; ++i) {
        int start_node = node_dist(rng);
        int end_node = node_dist(rng);
        while (end_node == start_node) {
            end_node = node_dist(rng);
        }
        auto vehicle = std::make_shared<Vehicle>(i, start_node, end_node);
        vehicles.push_back(vehicle);
    }
    
    // 先运行XY基线
    auto xy_result = run_xy_baseline(network, vehicles);
    auto xy_paths = xy_result.first;
    auto xy_total_time = xy_result.second;
    
    // 运行MVPP-MGC-PSO
    auto mgc_pso = std::make_shared<MVPPMGCPSO>(network, vehicles, 200, 3);
    auto optimal_paths = mgc_pso->optimize();
    
    // 计算MVPP-MGC-PSO总旅行时间
    double mgc_pso_total_time = 0;
    for (const auto& path_pair : optimal_paths) {
        mgc_pso_total_time += calculate_path_travel_time(network, path_pair.second);
    }
    
    std::cout << "Final Comparison Results:" << std::endl;
    std::cout << "XY Baseline Results:" << std::endl;
    for (const auto& path_pair : xy_paths) {
        std::cout << "Vehicle " << path_pair.first << ": [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    std::cout << "XY Baseline Total Travel Time: " << std::fixed << std::setprecision(2) 
              << xy_total_time << " seconds" << std::endl;
    
    std::cout << "\nMVPP-MGC-PSO Results:" << std::endl;
    for (const auto& path_pair : optimal_paths) {
        std::cout << "Vehicle " << path_pair.first << ": [";
        for (size_t i = 0; i < path_pair.second.size(); ++i) {
            std::cout << path_pair.second[i];
            if (i < path_pair.second.size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
    }
    std::cout << "MVPP-MGC-PSO Total Travel Time: " << std::fixed << std::setprecision(2) 
              << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "MVPP-MGC-PSO Execution Time: " << std::fixed << std::setprecision(2) 
              << mgc_pso->get_execution_time() << " seconds" << std::endl;
    
    std::cout << "\nFinal Comparison Summary:" << std::endl;
    std::cout << "-------------------" << std::endl;
    std::cout << "MVPP-MGC-PSO Total Travel Time: " << std::fixed << std::setprecision(2) 
              << mgc_pso_total_time << " seconds" << std::endl;
    std::cout << "XY Baseline Total Travel Time: " << std::fixed << std::setprecision(2) 
              << xy_total_time << " seconds" << std::endl;
    if (xy_total_time > 0) {
        double improvement = ((xy_total_time - mgc_pso_total_time) / xy_total_time * 100);
        std::cout << "Improvement: " << std::fixed << std::setprecision(2) << improvement << "%" << std::endl;
    }
    std::cout << "-------------------" << std::endl;
    std::cout << "(Note: congestion distribution and other metrics can be computed similarly.)" << std::endl;
}

int main() {
    std::cout << "MVPP-MGC-PSO Path Planning Algorithm (C++11 Version)" << std::endl;
    std::cout << "==================================================" << std::endl;
    
    try {
        run_mvpp_mgc_pso();
        case_study_1();
        case_study_2();
        final_comparison_test();
        
        std::cout << "\nAll tests completed successfully!" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
} 