# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **gem5-gpu**, a heterogeneous CPU-GPU simulation framework that integrates three major components:
- **gem5**: A modular computer system architecture simulator
- **GPGPU-Sim**: A cycle-level GPU functional and timing simulator  
- **Ruby memory system**: Coherent cache hierarchy and interconnect

ultra think and Please implement this using state-of-the-art methods.
The project enables detailed simulation of CPU-GPU systems with accurate timing, power, and performance modeling for computer architecture research.

## Current Project Status and Primary Objective

### Core Project Mission
**THIS PROJECT IS PRIMARILY FOCUSED ON DEVELOPING THE MVPP_MGC_PSO ROUTING ALGORITHM**

The **primary objective** is to implement and refine the **MVPP_MGC_PSO (Multi-Vehicle Path Planning with Multi-Group Clustering and Particle Swarm Optimization)** routing algorithm within the gem5-gpu network-on-chip simulation framework.

### Project Context: Path Planning to Routing Algorithm Conversion
This project involves converting the MVPP_MGC_PSO path planning algorithm from `/home/siat/gem5-gpu-bak/mvpp_mgc_pso_path_planning.cpp` into a routing algorithm for the NoC (Network-on-Chip) architecture. 

**Key Mapping Concepts:**
- **Vehicles** in path planning → **Data packets** in NoC routing
- **Road networks** in path planning → **Network topology** in NoC routing  
- **Vehicle groups** in path planning → **Packet type groups** (CPU, GPU, coherence packets)
- **Traffic congestion** in path planning → **Network congestion and buffer utilization**
- **Multi-objective optimization** (travel time, fuel, smoothness) → **Multi-objective routing** (latency, power, congestion, reliability)

## Build System

### Build and Test Execution Constraint
**CRITICAL PROJECT REQUIREMENT**:

**All compilation and testing operations MUST be executed on 192.168.197.130 (remote machine), NOT on 192.168.197.138 (local development machine).**

**Machine Architecture:**

**192.168.197.138 (Development Machine):**
- Role: Code development and script execution
- Activities:
  - ✅ Code editing and modification
  - ✅ Script invocation (local execution of scripts that trigger remote operations)
  - ✅ Log analysis after operations complete
- Constraints:
  - ❌ Compilation must NOT be performed locally (only -j8, insufficient)
  - ❌ Tests must NOT run locally (binary must be on 130)

**192.168.197.130 (Build/Test Machine):**
- Role: Compilation and testing execution
- Activities:
  - ✅ Receives code via automated rsync synchronization
  - ✅ Performs compilation with high parallelism (-j64)
  - ✅ Executes benchmark tests (backprop, kmeans)
  - ✅ Generates logs and transfers them back to 138

**Why This Architecture?**
1. **Performance**: 130 has 8x more build parallelism (-j64 vs -j8)
2. **Resource Separation**: Keep development environment clean
3. **Correctness**: Tests must run where gem5.opt binary is compiled
4. **Efficiency**: Automated sync ensures code consistency

**Workflow Overview:**
```
138 Machine                          130 Machine
┌─────────────────┐                 ┌─────────────────┐
│ 1. Edit code    │                 │                 │
│ 2. Run script   │ ─SSH/rsync───>  │ 3. Sync code    │
│    (locally)    │                 │ 4. Compile      │
│                 │                 │ 5. Test         │
│ 7. Analyze logs │ <───SSH─────    │ 6. Send logs    │
└─────────────────┘                 └─────────────────┘
```

**Claude Code Capabilities:**
- ✅ **CAN**: Modify source code in flexible-pipeline directory
- ✅ **CAN**: Trigger builds/tests by having user run scripts (scripts execute on 130 via SSH)
- ✅ **CAN**: Read and analyze log files after operations complete
- ✅ **CAN**: Suggest fixes based on compilation/test results
- ⚠️ **LIMITATION**: Cannot execute scripts automatically (user must run them manually)
- ⚠️ **CONSTRAINT**: All build/test operations happen on 130, not 138

**User's Role:**
- ✅ **MUST**: Manually run build/test scripts on 138
- ✅ **AUTOMATIC**: Scripts handle SSH connection to 130 and remote execution
- ✅ **AUTOMATIC**: Logs are transferred back to 138 for analysis

### Development Modes

This project supports **two development modes**, but **Mode 2 is mandatory for this project**:

#### Mode 1: Local Single-Machine Development (NOT RECOMMENDED - Legacy Only)
⚠️ **WARNING**: This mode is discouraged and only kept for backward compatibility.

**Limitations:**
- Insufficient build capacity (only -j8)
- Slower compilation times
- Tests on less powerful hardware
- Not suitable for complex simulations

```bash
# Legacy mode - ONLY use if 130 machine is unavailable
./build_gem5.sh
```

**This mode compiles and tests on 138, which violates the project's performance requirements.**

#### Mode 2: Cross-Machine Development (MANDATORY - Recommended)
✅ **THIS IS THE REQUIRED MODE FOR THIS PROJECT**

**Develop on 192.168.197.138, compile and test on 192.168.197.130.**

**Architecture:**
```
192.168.197.138 (Development)    →  SSH/rsync  →    192.168.197.130 (Build/Test)
├─ Code editing (Claude Code)                       ├─ Compilation (-j64)
├─ Script execution (User)                          ├─ Benchmark testing
└─ Log analysis (Claude Code)                       └─ Result generation
```

**Available Scripts:**

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup_ssh_key.sh` | Configure SSH key authentication (first-time only) | `./setup_ssh_key.sh` |
| `sync_and_build.sh` | Sync code to 130 and compile | `./sync_and_build.sh` |
| `run_tests.sh` | Run benchmark tests on 130 | `./run_tests.sh [backprop\|kmeans\|all]` |
| `build_and_test_all.sh` | One-command build and test | `./build_and_test_all.sh` |

**Quick Start (Cross-Machine Mode):**
```bash
# Step 1: Configure SSH (first-time only)
./setup_ssh_key.sh

# Step 2: Build and test
./build_and_test_all.sh              # Compile + run all tests
./build_and_test_all.sh -b           # Compile only
./build_and_test_all.sh -t backprop  # Run backprop test only
./build_and_test_all.sh -t all       # Run all tests only

# Step 3: Analyze results (Claude Code can do this)
cat build_logs/remote_build_*.log    # Compilation log
cat build_logs/test_*.log            # Test results
```

**Cross-Machine Workflow:**
1. **Claude Code**: Modifies code in flexible-pipeline directory on 138
2. **User**: Runs `./build_and_test_all.sh` on 138
3. **Automation**: Code syncs to 130, compiles, tests, logs return to 138
4. **Claude Code**: Analyzes logs in `build_logs/` directory on 138
5. **Iterative**: Repeat until objectives achieved

**Advantages of Cross-Machine Mode:**
- ✅ Leverages 130's powerful build capacity (-j64 vs -j8)
- ✅ Separates development and build environments
- ✅ Automatic code synchronization (rsync incremental sync)
- ✅ Comprehensive logging system
- ✅ Supports both SSH key and password authentication

### Build and Testing Workflow

**Cross-Machine Mode (MANDATORY - Standard Workflow):**
1. **User**: Run `./build_and_test_all.sh` on 138
2. **System**: Automatically sync code to 130 via rsync
3. **System**: Compile on 130 with `-j64`
4. **System**: Run tests on 130
5. **System**: Transfer logs back to 138
6. **Claude Code**: Analyze logs in `build_logs/` directory

**Single-Machine Mode (Legacy - NOT RECOMMENDED):**
1. **User**: Run `./build_gem5.sh` on 138
2. **System**: Compile and test locally (⚠️ Slow, not recommended)
3. **Claude Code**: Analyze log file

### Build Configuration Details

**Compilation Target:**
- **Working Directory**: `/home/siat/gem5-gpu-bak/gem5/`
- **Build Target**: `X86_VI_hammer_GPU/gem5.opt`
- **Protocol**: `VI_hammer` with GPU simulation enabled
- **Parallel Build**: `-j8` (local) or `-j64` (remote)

**Test Configuration:**
- **Output Directory**: `/home/siat/test/` (on build machine)
- **Network Type**: `--garnet-network=flexible` (MVPP_MGC_PSO routing)
- **Benchmarks**: backprop, kmeans (rodinia suite)

**Log Management:**
- **Local Logs**: `build_logs/` directory on 138
- **Log Patterns**:
  - `sync_build_YYYYMMDD_HHMMSS.log` - Sync and build log
  - `remote_build_YYYYMMDD_HHMMSS.log` - Detailed compilation log
  - `test_backprop_YYYYMMDD_HHMMSS.log` - backprop test log
  - `test_kmeans_YYYYMMDD_HHMMSS.log` - kmeans test log

### Log Analysis Capability
Claude Code can analyze build and test results by reading log files:
```bash
# Claude Code can read logs to:
# - Identify compilation errors and warnings
# - Analyze build performance and timing
# - Review test results and statistics
# - Suggest fixes for build or test failures
# - Extract performance metrics from test outputs
```

### Manual Build Commands (For Reference Only)
```bash
# These commands are embedded in build scripts - DO NOT RUN MANUALLY

# Single-machine compilation (on 138)
cd /home/siat/gem5-gpu-bak/gem5/
python `which scons` build/X86_VI_hammer_GPU/gem5.opt \
    --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \
    PROTOCOL=VI_hammer \
    GPGPU_SIM=True \
    -j8

# Cross-machine compilation (on 130)
cd /home/siat/gem5-gpu-bak/gem5/
python `which scons` build/X86_VI_hammer_GPU/gem5.opt \
    --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \
    PROTOCOL=VI_hammer \
    GPGPU_SIM=True \
    -j64

# Test commands (backprop)
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /home/siat/test/ \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"

# Test commands (kmeans)
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /home/siat/test/ \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c benchmarks/rodinia/kmeans/gem5_fusion_kmeans \
    -o "-i /home/siat/Downloads/kmeans_input.txt"
```

### Remote Build System Details
**IMPORTANT**: For comprehensive documentation on the cross-machine development system, refer to:
- `REMOTE_BUILD_README.md` - Complete guide with troubleshooting and advanced usage

### Build Configurations

Available build targets in `gem5-gpu/build_opts/`:
- `X86_VI_hammer_GPU`: X86 CPU with VI_hammer coherence protocol and GPU
- `X86_MESI_Two_Level_GPU`: X86 CPU with MESI protocol and GPU
- `ARM_VI_hammer_GPU`: ARM CPU with VI_hammer protocol and GPU

### Testing/Verification

```bash
# Run a simple GPU benchmark test
cd /home/siat/
./gem5-gpu/gem5/build/X86_VI_hammer_GPU/gem5.opt \
    -d /path/to/output \
    gem5-gpu/configs/se_fusion.py \
    -c benchmarks/rodinia/backprop/gem5_fusion_backprop \
    -o "16"
```

## Key Architecture Components

### Main Integration Layer (`gem5-gpu/src/`)

- **`api/`**: CUDA runtime API implementation and GPU system calls
- **`gpu/gpgpu-sim/`**: Core GPU simulation integration
  - `CudaGPU`: Main GPU device abstraction class
  - `GPGPUSimComponentWrapper`: Bridges gem5 timing with GPGPU-Sim
- **`gpu/copy_engine.*`**: GPU memory transfer operations
- **`gpu/shader_*`**: GPU memory management (LSQ, MMU, TLB)
- **`mem/protocol/`**: Ruby coherence protocols for CPU-GPU systems

### Configuration System (`gem5-gpu/configs/`)

- **`se_fusion.py`**: Primary simulation script for unified CPU-GPU execution
- **`GPUConfig.py`**: GPU parameter setup and GPGPU-Sim integration
- **`GPUMemConfig.py`**: GPU memory system configuration

### GPU Simulation Engine (`gpgpu-sim/`)

- **`cuda-sim/`**: CUDA functional simulation and PTX instruction handling
- **`gpgpu-sim/`**: GPU timing models (shader cores, caches, DRAM controllers)
- **`intersim2/`**: GPU interconnection network simulation
- **`gpuwattch/`**: GPU power consumption modeling

## High-Level System Architecture

```
CPU Application (CUDA Runtime)
        ↓
   CudaGPU Interface
        ↓
   GPGPU-Sim Engine ←→ Ruby Memory System
        ↓                     ↓
   GPU Cores/Shaders     Cache Hierarchy
        ↓                     ↓
   GPU Memory System ←→ CPU Memory System
```

### Memory System Integration

- **Unified Address Space**: CPU and GPU can share the same memory space (fusion mode)
- **Coherent Memory**: Ruby-based coherence protocols ensure cache consistency
- **VI_hammer Protocol**: Extended for CPU-GPU coherent memory access
- **Cache Hierarchy**: Separate L1/L2 caches for CPU and GPU with shared memory controllers

## Development Workflow

### Key Integration Points

1. **CudaGPU Class** (`gem5-gpu/src/gpu/gpgpu-sim/cuda_gpu.hh`):
   - Main entry point for GPU operations
   - Manages GPU cores, streams, and memory transfers
   - Integrates with gem5's event system

2. **Ruby Memory Protocols** (`gem5-gpu/src/mem/protocol/`):
   - CPU-GPU coherence implementations
   - Cache controller state machines
   - Memory access coordination

3. **Configuration Scripts** (`gem5-gpu/configs/`):
   - System topology setup
   - GPU parameter configuration
   - Benchmark execution setup

### Interface Preservation Rules

**CRITICAL**: When modifying this codebase, existing interfaces MUST be preserved:
- Do NOT modify method signatures in existing classes
- Do NOT change parameter types or return types
- Create new files/classes that implement or extend existing interfaces
- Use adapter patterns to bridge implementation gaps

## Benchmark Suites

Located in `benchmarks/`:
- **`rodinia/`**: GPU computing benchmark suite (backprop, bfs, cfd, etc.)
- **`parboil/`**: Performance analysis workloads
- **`lonestar/`**: Irregular GPU applications  
- **`pannotia/`**: Graph analytics benchmarks

### Running Benchmarks

```bash
# Build a specific benchmark
cd benchmarks/rodinia/backprop/
make -f Makefile.gem5-fusion

# Run with gem5-gpu
./gem5/build/X86_VI_hammer_GPU/gem5.opt \
    gem5-gpu/configs/se_fusion.py \
    -c benchmarks/rodinia/backprop/gem5_fusion_backprop \
    -o "16"
```

# Common Operations

### Adding New GPU Features
1. Implement in `gem5-gpu/src/gpu/` following existing patterns
2. Update configuration in `gem5-gpu/configs/GPUConfig.py`
3. Extend Ruby protocols if memory system changes needed
4. User must manually test with existing benchmarks using `build_gem5.sh`

### Debugging GPU Simulations
1. Enable debug flags: `--debug-flags=GPUExec,CudaGPU`
2. User must manually run simulations and check output logs
3. Verify GPU configuration parameters
4. User must manually test with simple microbenchmarks first
5. Claude Code can analyze log files after user runs tests

### Performance Analysis
1. Use built-in statistics collection
2. Enable power modeling with GPUWattch
3. Compare against baseline configurations (user must run manually)
4. Profile using gem5's built-in profiling tools (user must execute)
5. Claude Code can analyze performance results from log files

### Workflow for Code Changes

#### Standard Development Workflow (Recommended)

**Using Cross-Machine Mode:**
1. **Claude Code**: Modifies code in `flexible-pipeline/` directory on 138
2. **User**: Runs `./build_and_test_all.sh` on 138
3. **Automation**:
   - Syncs modified code to 130 (rsync incremental)
   - Compiles on 130 with `-j64`
   - Runs benchmark tests on 130
   - Transfers logs back to 138
4. **Claude Code**: Analyzes logs in `build_logs/` directory
5. **Claude Code**: Suggests fixes or improvements based on results
6. **Iterative**: Repeat steps 1-5 until objectives achieved

**Using Single-Machine Mode:**
1. **Claude Code**: Modifies code in `flexible-pipeline/` directory
2. **User**: Runs `./build_gem5.sh`
3. **Claude Code**: Analyzes log file
4. **Iterative**: Repeat until objectives achieved

#### Quick Iteration Workflow

For rapid development and testing:

```bash
# Option 1: Full workflow
./build_and_test_all.sh              # Sync, compile, test all

# Option 2: Incremental workflow
./build_and_test_all.sh -b           # Only compile
./run_tests.sh backprop              # Quick single test

# Option 3: Test-only (after successful build)
./build_and_test_all.sh -t kmeans    # Run specific test
```

#### Development Best Practices

1. **Incremental Changes**: Make small, testable modifications
2. **Frequent Testing**: Test after each significant change
3. **Log Analysis**: Let Claude Code analyze logs before next iteration
4. **Interface Preservation**: Never modify existing method signatures
5. **Documentation**: Update comments for new functionality

## Project-Specific Constraints

### Working Directory Restrictions
- **Primary Working Directory**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- **No New Subdirectories**: Cannot create new subdirectories under flexible-pipeline
- **No Backup Files**: Do not create backup files (.bak) - work directly on original files
- **File Types**: Primarily handle .cc, .hh, .py, .v, .sv files

### Power Statistics Project Requirements
- Focus on power statistics accuracy
- Verify power calculation logic
- Ensure compatibility with existing NoC architecture
- Provide detailed power analysis reports
- Integrate DSENT power modeling tools

### Interface Preservation for Power Analysis
- **CRITICAL**: Maintain existing MVPP_MGC_PSO routing algorithm interface
- Use adapter pattern when extending power monitoring functionality
- New power statistics interface should not affect existing routing logic
- Ensure power statistics do not impact simulation performance

### Incremental Implementation Strategy
**CRITICAL**: All modifications must be incremental and avoid altering existing project mechanisms and interfaces. Changes are only permissible within the `flexible-pipeline/` directory, and any necessary additions or modifications must adhere to these guidelines:

1. **Preserve Existing Functionality**: Never break existing routing mechanisms
2. **Add, Don't Replace**: Extend existing classes rather than replacing them
3. **Maintain Interface Compatibility**: All existing method signatures must remain unchanged
4. **Incremental Enhancement**: Make small, testable improvements
5. **Comprehensive Testing**: User must run `build_gem5.sh` manually to verify all changes, then Claude Code can analyze the results from the log files

## Flexible-Pipeline Directory Architecture and Current Implementation

### Current MVPP_MGC_PSO Implementation Status
The flexible-pipeline directory **already contains a complete implementation** of the MVPP_MGC_PSO routing algorithm with the following architecture:

#### Core Components (24 files total):
1. **Router.hh/cc** - Main router with MVPP_MGC_PSO algorithm implementation
2. **PSOAlgorithm.hh/cc** - Particle Swarm Optimization core engine
3. **SwarmManager.hh/cc** - Multi-swarm collaboration and packet-particle management
4. **PerformanceAnalyzer.hh/cc** - Performance monitoring and power statistics
5. **NetworkUtilities.hh/cc** - Network topology management and utilities
6. **GarnetNetwork.hh/cc** - Network controller and topology integration
7. **[Various NoC Infrastructure Files]** - Link management, buffering, arbitration

#### Key Implementation Features:
- **Multi-level Optimization**: Global, group-level, and local PSO optimization
- **Collaborative Routing**: Inter-swarm communication and coordination
- **Power Monitoring**: Comprehensive power statistics and analysis
- **Performance Tracking**: Detailed performance metrics and analysis
- **Adaptive Algorithms**: Dynamic congestion adaptation and replanning

### Current Algorithm Architecture
```
Routing Decision Hierarchy:
1. Collaborative Routing (Primary)
   ↓ (if available)
2. Global Graph Guidance 
   ↓ (fallback)
3. PSO Algorithm
   ↓ (ultimate fallback)
4. Traditional Table Routing
```

### Coding Standards and Conventions

#### C++11 Compliance Features:
- ✅ **Smart Pointers**: `std::unique_ptr`, `std::shared_ptr`
- ✅ **Auto Keyword**: Type deduction and iterator loops
- ✅ **Range-based Loops**: Modern iteration patterns
- ✅ **Lambda Functions**: STL algorithm integration
- ✅ **Move Semantics**: Efficient resource management
- ✅ **Threading Support**: `std::mutex` and threading primitives

#### Coding Conventions:
- **Naming Convention**: `snake_case` for variables, `CamelCase` for classes
- **Member Variables**: Prefixed with `m_` (e.g., `m_router_ptr`, `m_enable_pso`)
- **Static Members**: Prefixed with `s_` (e.g., `s_global_graph`)
- **Method Naming**: Descriptive verb-noun combinations
- **Header Guards**: Traditional `#ifndef` style guards

## Core Project Objectives and Strict Constraints

### Primary Project Goal
**THIS PROJECT IS PRIMARILY FOCUSED ON REFINING THE EXISTING MVPP_MGC_PSO ROUTING ALGORITHM**

The core objective is to enhance and optimize the **existing MVPP_MGC_PSO implementation** in the flexible-pipeline directory. All code modifications must strictly serve this objective while preserving the existing interfaces and mechanisms.

### Strict Code Modification Constraints

#### 1. Absolute Working Directory Limitation
- **ONLY ALLOWED WORKING DIRECTORY**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- **Permitted Operations**:
  - Modify existing files within this directory
  - Create new files within this directory (when absolutely necessary)
  - Direct modification without backup files
- **ABSOLUTELY PROHIBITED Operations**:
  - Modify any files outside the flexible-pipeline directory
  - Create subdirectories under flexible-pipeline
  - Modify other gem5 modules or components
  - Create backup files (.bak)

#### 2. Interface Immutability Principle
**CRITICAL EXISTING INTERFACES THAT MUST BE PRESERVED:**

```cpp
// Router Class - Core routing interface (Router.hh)
class Router : public BasicRouter, public FlexibleConsumer {
public:
    // MUST NOT MODIFY these method signatures
    int getRoute(NetDest destination);
    int getRoutePSO(NetDest destination);
    int getRouteCollaborative(NetDest destination);
    void routeCompute(flit *m_flit, int inport);
    void addInPort(NetworkLink *in_link);
    void addOutPort(NetworkLink *out_link, const NetDest& routing_table_entry, int link_weight);
    void wakeup();
    void request_vc(int in_vc, int in_port, NetDest destination, Cycles request_time);
    bool isBufferNotFull(int vc, int inport);
    uint32_t get_id() const;
    void init_net_ptr(GarnetNetwork* net_ptr);
    
    // Can add new public methods but not modify existing ones
    // PowerMetrics getPowerMetrics() const;        // OK to add
    // void enablePowerMonitoring(bool enable);     // OK to add
};

// PSOAlgorithm Class - Core PSO interface (PSOAlgorithm.hh)
class PSOAlgorithm {
public:
    // MUST NOT MODIFY these method signatures  
    void initializePSO();
    int getRoutePSO(NetDest destination);
    double calculateMultiObjectiveFitness(const PacketParticle& packet);
    void updateParticlePosition(Particle& particle, int src_node, int dest_node);
};

// Critical Data Structures - MUST NOT MODIFY EXISTING MEMBERS
struct Particle {
    std::vector<double> position;      // MUST NOT MODIFY
    std::vector<double> velocity;      // MUST NOT MODIFY
    std::vector<double> best_position; // MUST NOT MODIFY
    double best_fitness;               // MUST NOT MODIFY
    // Can add new members but NOT modify existing ones
};

struct PacketParticle {
    int packet_id, src_node, dest_node;           // MUST NOT MODIFY
    ProcessingUnitType processing_unit_type;      // MUST NOT MODIFY
    std::vector<double> position, velocity;       // MUST NOT MODIFY
    std::vector<double> best_position;            // MUST NOT MODIFY
    // ... many other existing members - ALL MUST BE PRESERVED
};
```

#### 3. Routing Mechanism Immutability Principle
- **ABSOLUTELY CANNOT MODIFY**: Existing next-hop selection mechanism
- **ABSOLUTELY CANNOT MODIFY**: Existing routing decision logic  
- **ABSOLUTELY CANNOT MODIFY**: Existing network topology handling
- **ABSOLUTELY CANNOT MODIFY**: Existing packet forwarding mechanisms
- **Permitted Operations**:
  - Enhance internal algorithm implementation (without changing external behavior)
  - Add power monitoring logic (without affecting routing decisions)
  - Add statistics collection functionality
  - Add performance analysis features

### Code Modification Guidelines

#### Extension Rather Than Modification
```cpp  
// Correct Approach: Extend existing functionality  
class Router : public BasicRouter, public FlexibleConsumer {  
private:  
    // Can add new private member variables
    PowerStatistics* m_power_stats;  
    DSENTIntegrator* m_dsent_integrator;  
    
    // Can add new private methods  
    void updatePowerStatistics();  
    void collectRoutingMetrics();  
    
public:  
    // MUST keep existing interface unchanged  
    int getRoute(NetDest destination);  // DO NOT MODIFY
    void routeCompute(flit *m_flit, int inport);  // DO NOT MODIFY
    
    // Can add new public methods  
    PowerMetrics getPowerMetrics() const;  // OK to add
    void enablePowerMonitoring(bool enable);  // OK to add
};

// Incremental Enhancement Example - Correct Approach
class Router : public BasicRouter, public FlexibleConsumer {
private:
    // Existing members - NEVER MODIFY
    PSOAlgorithm* m_pso_algorithm;        // PRESERVE
    SwarmManager* m_swarm_manager;        // PRESERVE
    PerformanceAnalyzer* m_perf_analyzer; // PRESERVE
    
    // NEW members can be added
    PowerStatistics* m_enhanced_power_stats;  // OK to add
    AdaptiveAlgorithm* m_adaptive_algorithm;  // OK to add
    
public:
    // Existing interface - NEVER MODIFY
    int getRoute(NetDest destination);            // PRESERVE EXACTLY
    int getRoutePSO(NetDest destination);         // PRESERVE EXACTLY
    void routeCompute(flit *m_flit, int inport);  // PRESERVE EXACTLY
    
    // NEW methods can be added
    void enableAdaptiveRouting(bool enable);      // OK to add
    Statistics getEnhancedStatistics();           // OK to add
};
```

## Path Planning Algorithm Analysis and Mapping

### Source Algorithm Structure (`mvpp_mgc_pso_path_planning.cpp`)
The source algorithm implements the following key components:

#### Key Classes and Their NoC Mapping:
```cpp
// PATH PLANNING DOMAIN          →  NoC ROUTING DOMAIN
class Vehicle {                 →  class PacketParticle {
    int id;                     →      int packet_id;
    int start_node;             →      int src_node;
    int end_node;               →      int dest_node;
    vector<double> position;    →      vector<double> position;
    vector<double> velocity;    →      vector<double> velocity;
    vector<vector<int>> paths;  →      vector<RouteOption> route_options;
}

class RoadNetwork {             →  class NetworkTopology {
    map<int, Node*> nodes;      →      map<int, RouterNode*> routers;
    map<int, Road*> roads;      →      map<int, NetworkLink*> links;
    map<int, vector<int>> adj;  →      map<int, vector<int>> topology;
}

class Swarm {                   →  class PacketGroup {
    vector<Vehicle*> vehicles;  →      vector<PacketParticle*> packets;
    vector<double> global_best; →      vector<double> group_best_route;
    double global_best_fitness; →      double group_best_performance;
}
```

#### Algorithm Flow Mapping:
```cpp
// PATH PLANNING FLOW                    →  NoC ROUTING FLOW
1. Vehicle grouping by destinations      →  Packet grouping by processing unit type
2. Multi-swarm PSO for path planning    →  Multi-group PSO for route optimization  
3. Congestion-aware path selection      →  Buffer-aware route selection
4. Multi-objective optimization:         →  Multi-objective optimization:
   - Travel time minimization            →    - Latency minimization
   - Fuel consumption reduction          →    - Power consumption reduction  
   - Path smoothness                     →    - Route stability
   - Congestion avoidance               →    - Congestion avoidance
```

### Functional Relationships Between Algorithms
The conversion maintains the core algorithmic principles while adapting to the NoC context:

1. **Particle Swarm Optimization**: Same mathematical foundation, different search space
2. **Multi-objective Fitness**: Same optimization principles, different objective functions
3. **Collaborative Optimization**: Same multi-group coordination, different group definitions
4. **Adaptive Replanning**: Same congestion response, different congestion metrics
5. **Global Best Sharing**: Same information exchange, different information types
