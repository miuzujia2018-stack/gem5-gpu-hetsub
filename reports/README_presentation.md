# MVPP-MGC-PSO Algorithm Presentation

## Overview
This repository contains a comprehensive Beamer-based LaTeX presentation summarizing the innovations and performance analysis of the MVPP-MGC-PSO (Multi-Vehicle Path Planning with Multi-Group Cooperative Particle Swarm Optimization) algorithm compared to traditional XY routing algorithms.

## Author
**miuzujia** - Weekly Research Report

## Presentation Structure

### 1. Introduction and Problem Statement
- Traditional XY routing limitations
- MVPP-MGC-PSO solution overview

### 2. Algorithm Architecture Overview
- System architecture diagram
- Key components explanation

### 3. Core Innovations (4 Major Innovations)

#### Innovation 1: Multi-Group Cooperative Swarm Structure
- **Traditional PSO**: Single swarm optimization
- **MVPP-MGC-PSO**: Master-slave swarm coordination
- **Key Features**:
  - Master swarm for global coordination
  - Slave swarms for local optimization
  - Cross-swarm communication
  - Hierarchical information exchange

#### Innovation 2: Real-Time Congestion-Aware Optimization
- **Traditional XY**: Static path selection, no traffic consideration
- **MVPP-MGC-PSO**: Dynamic congestion modeling
- **Key Features**:
  - Historical traffic analysis
  - Hotspot detection and avoidance
  - Adaptive travel time calculation
  - Real-time congestion probability updates

#### Innovation 3: Multi-Objective Fitness Function
- **Traditional XY**: Single objective (shortest distance)
- **MVPP-MGC-PSO**: Multi-objective optimization
- **Objectives**:
  - Travel Time (60% weight)
  - Fuel Consumption (20% weight)
  - Congestion Penalty (15% weight)
  - Path Smoothness (5% weight)

#### Innovation 4: Dynamic Path Replanning
- **Traditional XY**: Static path assignment
- **MVPP-MGC-PSO**: Adaptive path regeneration
- **Key Features**:
  - Real-time congestion monitoring
  - Hotspot avoidance strategies
  - Dynamic optimization cycles

### 4. Algorithm Implementation Details
- Feasible path generation strategy
- Master-slave swarm coordination mechanism
- Code examples and implementation details

### 5. Performance Analysis
- Experimental setup and test scenarios
- Performance comparison results
- Case study analysis

### 6. Technical Advantages
- Algorithmic advantages
- Performance advantages
- Implementation advantages
- Operational advantages

### 7. Conclusion and Future Work
- Key contributions summary
- Experimental validation results
- Future research directions

## Key Performance Improvements

| Metric | XY Baseline | MVPP-MGC-PSO | Improvement |
|--------|-------------|--------------|-------------|
| Total Travel Time | 847.3s | 623.8s | **26.4%** |
| Average Path Length | 4.2 nodes | 3.8 nodes | **9.5%** |
| Congestion Avoidance | None | 73.2% | **N/A** |
| Fuel Efficiency | Baseline | +18.7% | **18.7%** |
| Path Smoothness | Low | High | **Significant** |

## Compilation Instructions

### Prerequisites
- LaTeX distribution (TeX Live, MiKTeX, or similar)
- Beamer package
- Required packages: amsmath, amsfonts, amssymb, graphicx, listings, xcolor, tikz, pgfplots

### Compilation
```bash
# Compile the presentation
pdflatex mvpp_mgc_pso_presentation.tex

# Run twice for proper table of contents
pdflatex mvpp_mgc_pso_presentation.tex
```

### Output
The compilation will generate `mvpp_mgc_pso_presentation.pdf` containing the complete presentation.

## Algorithm Code Structure

The presentation references code from the following files:
- `mvpp_mgc_pso_path_planning.hpp` - Header file with class definitions
- `mvpp_mgc_pso_path_planning.cpp` - Implementation of the algorithm
- `main_mvpp_mgc_pso.cpp` - Main execution and testing code

## Key Algorithm Features

### Multi-Group Cooperative Structure
```cpp
// Master swarm (1/3 of vehicles)
int master_size = vehicles_.size() / 3;
auto master_swarm = std::make_shared<Swarm>(0);

// Slave swarms (remaining vehicles)
int num_slave_swarms = std::min(3, 
    static_cast<int>(remaining_vehicles.size()));
```

### Congestion-Aware Optimization
```cpp
// Update congestion probability
double current_ratio = std::min(1.0, 
    static_cast<double>(count) / road->capacity);
road->congestion_prob = 
    historical_weight * historical_avg + 
    current_weight * current_ratio;
```

### Multi-Objective Fitness Function
```cpp
// Multi-objective weighted sum
double total_cost = (0.6 * travel_time + 
                     0.2 * fuel_consumption + 
                     0.15 * congestion_penalty + 
                     0.05 * smoothness_cost);
```

## Case Studies

### Case Study 1: Common Origin
- All vehicles start from node 1
- Destinations: nodes 10, 13, 16
- **Improvement: 15.9%** over XY baseline

### Case Study 2: Common Destination
- All vehicles end at node 12
- Origins: nodes 2, 7, 15
- **Improvement: 21.6%** over XY baseline

## Future Work
- Large-scale network testing
- Real-time traffic data integration
- Machine learning enhancement
- Multi-modal transportation
- Energy-aware optimization

## Applications
- Autonomous vehicle routing
- Smart city traffic management
- Logistics optimization
- Emergency response planning

---

**Note**: This presentation is designed for academic audiences and provides a comprehensive overview of the MVPP-MGC-PSO algorithm's innovations and performance characteristics compared to traditional routing methods. 