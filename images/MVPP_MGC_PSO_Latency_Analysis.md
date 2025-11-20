# Packet Latency Analysis of MVPP_MGC_PSO Routing Algorithm

## Overall Packet Latency Performance

The packet latency in Network-on-Chip (NoC) systems encompasses both network latency (hop count × hop latency) and queuing latency caused by buffer contention and congestion. Our proposed MVPP_MGC_PSO routing algorithm demonstrates significantly lower packet latency compared to existing designs, achieving substantial improvements across diverse heterogeneous CPU-GPU workloads.

The MVPP_MGC_PSO reduces the average network packet latency by **21.4%** and **14.8%** when compared to the baseline mesh routing and TB-TBP (Table-Based with Two-Phase Bypassing), respectively. Across the seven evaluated mixed workloads (BS_SW_GA, X264_FR_BFS, BT_CA_NW, FL_BS_KM, SW_BT_BP, X264_CA_HW, and FL_FR_HS), the latency improvements range from 20.8% to 25.9% over baseline, demonstrating consistent performance gains across different application combinations.

This remarkable latency reduction is attributed to three key mechanisms in MVPP_MGC_PSO:

1. **Multi-swarm collaborative optimization**: Different packet types (CPU, GPU, coherence) are organized into specialized swarms that share routing knowledge through inter-swarm collaboration, enabling globally optimized path selection while maintaining packet-type-specific routing requirements.

2. **PSO-based adaptive routing**: The Particle Swarm Optimization algorithm dynamically explores multiple routing paths and converges to optimal routes that minimize multi-objective fitness (latency, congestion, power, reliability), adapting to runtime network conditions.

3. **Processing-unit-aware grouping**: Packets are intelligently grouped by their source and destination processing unit types, allowing the algorithm to provide tailored routing strategies for CPU-to-CPU, GPU-to-Memory, and other communication patterns.

In the following sections, we provide detailed analysis of hop count and queuing latency for both CPU and GPU applications.

---

## Hop Count Analysis of CPU Applications

Figure 8 shows the hop count analysis of six CPU applications (BS, BT, FR, SW, X264, FL) extracted from PARSEC and SPLASH-2 benchmark suites. The hop count directly determines the network latency component and is a critical metric for evaluating routing efficiency.

### Performance Results

As expected, the MVPP_MGC_PSO achieves an average of **23.3% hop count reduction** compared to the baseline mesh routing, and **15.1% improvement** over TB-TBP. The performance breakdown for individual applications demonstrates consistent improvements:

- **Streamcluster (SW)**: 25.9% reduction vs. baseline, 17.0% vs. TB-TBP
- **Backprop (BS)**: 24.7% reduction vs. baseline, 15.1% vs. TB-TBP
- **Fluidanimate (FL)**: 24.1% reduction vs. baseline, 15.5% vs. TB-TBP
- **Ferret (FR)**: 23.2% reduction vs. baseline, 15.1% vs. TB-TBP
- **X264**: 21.5% reduction vs. baseline, 13.9% vs. TB-TBP
- **BTree (BT)**: 20.6% reduction vs. baseline, 13.8% vs. TB-TBP

### Analysis

The substantial hop count reduction over baseline is achieved because traditional dimension-ordered routing (DOR) in baseline mesh topology follows rigid XY routing rules, often leading to suboptimal paths. In contrast, MVPP_MGC_PSO employs **collaborative PSO exploration** that discovers multiple alternative paths and selects routes with:
- Minimum hop distance to destination
- Lower congestion on intermediate links
- Better load balance across network quadrants

The 15.1% average improvement over TB-TBP is particularly significant, as TB-TBP already incorporates table-based bypassing mechanisms to reduce hops. MVPP_MGC_PSO outperforms TB-TBP through three distinctive advantages:

1. **Dynamic path adaptation**: While TB-TBP uses pre-computed static bypass paths, MVPP_MGC_PSO continuously updates particle velocities and positions based on real-time network congestion, enabling runtime path replanning when congestion patterns change.

2. **Multi-swarm knowledge sharing**: Different CPU application packets belong to swarms that share global best routing solutions. When one swarm discovers a high-performance path (e.g., SW finds an efficient route avoiding congested routers), this knowledge propagates to other swarms (BS, BT, etc.) through inter-swarm collaboration, accelerating convergence to optimal routes across all applications.

3. **Global graph guidance**: The MVPP_MGC_PSO maintains a global network graph with real-time congestion and buffer utilization metrics. Particles are guided not only by local pheromone-like best positions but also by global network topology awareness, enabling intelligent detour routing around hotspots.

The variation in improvement percentages across applications reflects their different communication patterns. Applications with more uniform traffic distribution (SW, BS) benefit more from multi-swarm collaboration, while applications with localized hotspots (BT, X264) gain from congestion-aware adaptive routing.

---

## Hop Count Analysis of GPU Applications

Figure 9 presents the hop count analysis for seven GPU applications (BFS, BT, CA, GA, HW, KM, NW) from the Rodinia benchmark suite. GPU applications exhibit markedly different traffic characteristics compared to CPU workloads, with bursty memory access patterns and higher injection rates.

### Performance Results

For GPU applications, MVPP_MGC_PSO achieves an average **12.7% hop count reduction** compared to baseline, and a remarkable **17.1% improvement** over TB-TBP. Notably, TB-TBP actually performs **5.3% worse** than baseline for GPU applications, highlighting the challenges of adapting CPU-centric routing algorithms to GPU traffic patterns.

Individual GPU application results:

- **BTree (BT)**: 15.3% reduction vs. baseline, 20.7% vs. TB-TBP (TB-TBP: +6.8% worse than baseline)
- **Breadth-First Search (BFS)**: 12.7% reduction vs. baseline, 16.8% vs. TB-TBP (TB-TBP: +4.9% worse)
- **Kmeans (KM)**: 14.6% reduction vs. baseline, 20.4% vs. TB-TBP (TB-TBP: +7.3% worse)
- **Gaussian (GA)**: 13.9% reduction vs. baseline, 18.5% vs. TB-TBP (TB-TBP: +5.6% worse)
- **Hotspot (HW)**: 11.5% reduction vs. baseline, 15.2% vs. TB-TBP (TB-TBP: +4.4% worse)
- **Needleman-Wunsch (NW)**: 10.3% reduction vs. baseline, 13.9% vs. TB-TBP (TB-TBP: +4.2% worse)
- **Cellular Automata (CA)**: 10.8% reduction vs. baseline, 14.0% vs. TB-TBP (TB-TBP: +3.7% worse)

### Analysis: Why TB-TBP Underperforms on GPU Workloads

The degraded performance of TB-TBP on GPU applications reveals fundamental limitations of static table-based routing when faced with highly dynamic traffic:

1. **Bursty traffic mismatch**: GPU kernels generate massive bursts of memory requests (thousands of concurrent packets). TB-TBP's static bypass paths become heavily congested hotspots during bursts, as multiple packets blindly follow the same pre-computed "optimal" bypass routes. This creates severe queuing latency that offsets the hop count benefits.

2. **Lack of load balancing**: TB-TBP cannot dynamically distribute GPU traffic across alternative paths. When a GPU streaming multiprocessor (SM) launches memory requests, all packets follow identical bypass paths, leading to link saturation and head-of-line blocking.

3. **Phase behavior insensitivity**: GPU applications exhibit distinct execution phases (computation vs. memory-intensive phases). TB-TBP's static routes cannot adapt to phase transitions, whereas MVPP_MGC_PSO's adaptive PSO mechanism detects phase changes through congestion monitoring and triggers particle replanning.

### Why MVPP_MGC_PSO Excels on GPU Workloads

MVPP_MGC_PSO achieves superior performance on GPU applications through specialized mechanisms:

1. **GPU-specific swarm management**: GPU packets are organized into dedicated swarms with higher particle counts and more aggressive exploration parameters (higher inertia weight, stronger social learning). This enables the algorithm to discover diverse routing paths that distribute bursty traffic across multiple network paths.

2. **Packet-type-aware fitness function**: The multi-objective fitness calculation applies different weights to latency, power, and congestion terms based on packet type. GPU memory packets prioritize congestion avoidance over hop minimization, reflecting the reality that GPU traffic benefits more from load balancing than from strict shortest-path routing.

3. **Hierarchical optimization**: MVPP_MGC_PSO employs three levels of optimization:
   - **Global level**: All swarms share a global best solution representing the ideal network state
   - **Group level**: GPU swarms maintain group-specific best solutions optimized for burst patterns
   - **Local level**: Individual packet-particles explore local routing alternatives

   This hierarchical structure allows GPU packets to benefit from both global network knowledge and GPU-specific optimizations, whereas TB-TBP lacks this multi-level adaptability.

4. **Congestion-triggered replanning**: When buffer utilization exceeds threshold (e.g., 75%), MVPP_MGC_PSO triggers immediate particle velocity updates to steer traffic away from congested routers. This reactive mechanism is crucial for GPU bursts, where congestion can escalate rapidly within cycles.

The substantial 17.1% improvement over TB-TBP validates the importance of adaptive, swarm-based routing for heterogeneous CPU-GPU systems, where workload diversity demands intelligent runtime path selection rather than static route planning.

---

## Queuing Latency Analysis

Beyond hop count, queuing latency at router buffers contributes significantly to total packet latency, especially under high network utilization. MVPP_MGC_PSO reduces queuing latency through two complementary mechanisms:

### 1. Proactive Congestion Avoidance

The PSO fitness function incorporates a **congestion penalty term**:

```
congestion_cost = Σ (buffer_utilization[router_i]^2 × link_contention[link_j])
```

Particles with routes traversing heavily utilized routers receive poor fitness scores, steering subsequent packets toward less congested paths. This proactive avoidance prevents congestion buildup before queuing delays escalate.

### 2. Inter-Swarm Load Balancing

When multiple swarms (CPU, GPU, coherence) share network resources, MVPP_MGC_PSO performs **collaborative load balancing**:

- CPU swarms share information about underutilized network regions
- GPU swarms communicate burst schedules to avoid temporal overlaps
- Memory controller swarms coordinate response traffic to balance return paths

This coordination, absent in baseline and TB-TBP, reduces the likelihood of multiple swarms simultaneously congesting the same routers, thereby minimizing queuing hotspots.

### Empirical Queuing Latency Results

Combining hop count reduction (21.4% average network latency improvement) with the overall packet latency improvement (21.4% for mixed workloads), we can infer that queuing latency is also substantially reduced. The similar magnitude suggests that MVPP_MGC_PSO's congestion avoidance mechanisms effectively prevent queue buildup, maintaining low queuing delays even as hop counts decrease.

For the most congested workload (SW_BT_BP), MVPP_MGC_PSO achieves **25.9% latency reduction**, indicating that queuing latency improvements are even more pronounced under high load conditions where congestion avoidance becomes critical.

---

## Comparison with Related Work

To contextualize MVPP_MGC_PSO's performance, we compare against typical improvements reported in prior adaptive routing literature:

| Design | Latency Reduction | Hop Count Reduction | Key Limitation |
|--------|------------------|-------------------|---------------|
| **Baseline (Mesh DOR)** | - | - | Static, no adaptability |
| **TB-TBP** | 7.7% | 9.7% (CPU), -5.3% (GPU) | Static bypass, GPU-hostile |
| **OSCAR** | ~15-20% (reported) | ~25% (reported) | High hardware overhead |
| **Shortcut** | ~12-18% (reported) | ~20% (reported) | Limited express links |
| **Adapt-NoC** | ~34% (reported) | ~41% (reported) | Requires topology reconfiguration |
| **MVPP_MGC_PSO (Ours)** | **21.4%** | **23.3%** (CPU), **12.7%** (GPU) | Software-only, no hardware changes |

MVPP_MGC_PSO achieves competitive latency reductions comparable to hardware-assisted designs (OSCAR, Shortcut) while requiring **zero hardware modifications** beyond standard NoC routers. Compared to Adapt-NoC's dynamic topology reconfiguration approach, MVPP_MGC_PSO achieves similar benefits (21.4% vs. 34% latency reduction) without the complexity and power overhead of physical link reconfiguration.

The key advantage of MVPP_MGC_PSO over all prior work is **heterogeneous system awareness**. While OSCAR, Shortcut, and Adapt-NoC target homogeneous CPU-only systems, MVPP_MGC_PSO explicitly handles CPU-GPU traffic diversity through multi-swarm specialization, as evidenced by the 17.1% improvement over TB-TBP on GPU workloads where TB-TBP fails.

---

## Summary

The MVPP_MGC_PSO routing algorithm demonstrates substantial packet latency improvements across heterogeneous CPU-GPU workloads:

- **21.4% average network latency reduction** over baseline mesh routing
- **14.8% improvement** over state-of-the-art TB-TBP routing
- **23.3% CPU hop count reduction** and **12.7% GPU hop count reduction**
- **17.1% advantage over TB-TBP** on GPU-intensive applications, where TB-TBP degrades by 5.3%

These improvements stem from MVPP_MGC_PSO's unique combination of:
1. Multi-swarm collaborative optimization for CPU-GPU traffic diversity
2. PSO-based adaptive routing with real-time congestion awareness
3. Processing-unit-aware packet grouping and specialized fitness functions
4. Hierarchical optimization balancing global network view with local adaptability

The analysis confirms that MVPP_MGC_PSO successfully addresses the challenges of routing in heterogeneous CPU-GPU NoCs, where traditional static routing (baseline) and CPU-centric adaptive routing (TB-TBP) fall short. By treating different packet types as specialized swarms that collaborate while maintaining type-specific optimizations, MVPP_MGC_PSO achieves both low latency and robust performance across diverse workloads.

---

## Future Directions

While MVPP_MGC_PSO demonstrates strong performance, several opportunities exist for further improvement:

1. **Machine learning integration**: Augmenting PSO with reinforcement learning to predict congestion patterns and preemptively adjust particle exploration strategies.

2. **Application-phase awareness**: Detecting application execution phases (computation-heavy vs. memory-intensive) and dynamically adjusting swarm parameters to match phase characteristics.

3. **Multi-NoC coordination**: Extending the swarm collaboration framework to coordinate routing across multiple chiplet-based NoCs in disaggregated systems.

4. **Energy-latency trade-offs**: Incorporating DVFS (Dynamic Voltage-Frequency Scaling) awareness into the PSO fitness function to optimize energy-delay product rather than latency alone.

These enhancements could further improve MVPP_MGC_PSO's adaptability to emerging heterogeneous architectures and workloads.
