# MVPP_MGC_PSO 路由算法数学公式集合

**Version**: 2.0  
**Date**: August 5, 2025  
**Author**: MVPP_MGC_PSO Research Team  
**Application**: Network-on-Chip (NoC) 路由算法数学建模

---

## **1. PSO核心算法公式**

### **1.1 粒子速度更新公式**

**标准PSO速度更新方程**：
$$v_i^{t+1} = w \cdot v_i^t + c_1 \cdot r_1 \cdot (p_{best,i} - x_i^t) + c_2 \cdot r_2 \cdot (g_{best} - x_i^t)$$

其中：
- $v_i^t$ = 粒子$i$在时刻$t$的速度向量
- $x_i^t$ = 粒子$i$在时刻$t$的位置向量
- $w$ = 惯性权重
- $c_1, c_2$ = 认知系数和社会系数
- $r_1, r_2$ = $[0,1]$均匀分布随机数
- $p_{best,i}$ = 粒子$i$的个体最优位置
- $g_{best}$ = 全局最优位置

**自适应速度更新方程**：
$$v_i^{t+1} = w_{adaptive} \cdot v_i^t + c_{1,adaptive} \cdot r_1 \cdot (p_{best,i} - x_i^t) + c_{2,adaptive} \cdot r_2 \cdot (g_{best} - x_i^t)$$

**速度边界约束**：
$$v_i^{t+1} = \max(-v_{max}, \min(v_{max}, v_i^{t+1}))$$

其中：
$$v_{max} = 3.0 \times (0.5 + D_{avg})$$
$D_{avg}$ = 群体平均多样性

### **1.2 粒子位置更新公式**

**位置更新方程**：
$$x_i^{t+1} = x_i^t + v_i^{t+1}$$

**位置边界约束**：
$$x_i^{t+1} = \max(0, \min(15, x_i^{t+1}))$$

**路径约束**：
$$x_{i,0}^{t+1} = src_{node}, \quad x_{i,last}^{t+1} = dest_{node}$$

### **1.3 自适应参数公式**

**惯性权重自适应调整**：
$$w_{adaptive} = \begin{cases}
\min(0.95, w \times 1.15) & \text{if } D < D_{threshold} \\
0.9 - 0.6 \times \frac{t}{T_{max}} & \text{if } \Delta f < 0.001 \\
\max(0.35, w \times 0.98) & \text{otherwise}
\end{cases}$$

其中：
- $D$ = 当前群体多样性
- $D_{threshold}$ = 多样性阈值
- $\Delta f$ = 适应度改进率
- $t$ = 当前迭代次数
- $T_{max}$ = 最大迭代次数

**学习因子自适应调整**：
$$c_{1,adaptive} = \begin{cases}
\min(2.5, c_1 \times 1.1) & \text{if } \Delta f_{avg} > 0.05 \\
\max(1.0, c_1 \times 0.95) & \text{if } D > 0.7
\end{cases}$$

$$c_{2,adaptive} = \begin{cases}
\max(1.0, c_2 \times 0.95) & \text{if } \Delta f_{avg} > 0.05 \\
\min(2.5, c_2 \times 1.1) & \text{if } D > 0.7
\end{cases}$$

---

## **2. 多目标适应度函数公式**

### **2.1 综合适应度函数**

**6维多目标适应度函数**：
$$F_{total} = \sum_{j=1}^{6} w_j \cdot f_j^{normalized}$$

$$F_{total} = w_1 \cdot f_{delay} + w_2 \cdot f_{power} + w_3 \cdot f_{congestion} + w_4 \cdot f_{load} + w_5 \cdot f_{reliability} + w_6 \cdot f_{qos}$$

其中权重约束：
$$\sum_{j=1}^{6} w_j = 1, \quad w_j \geq 0$$

### **2.2 延迟适应度组件**

**路径传输延迟**：
$$f_{delay} = \sum_{k=1}^{L-1} \left( t_{base} + \alpha \cdot C_{link}(k) \right) + \beta \cdot I_{invalid}$$

其中：
- $L$ = 路径长度
- $t_{base}$ = 基础传输时间
- $C_{link}(k)$ = 第$k$条链路的拥塞度
- $\alpha$ = 拥塞影响因子
- $I_{invalid}$ = 无效路径指示符
- $\beta$ = 无效路径惩罚权重

### **2.3 功耗适应度组件**

**路径功耗成本**：
$$f_{power} = \sum_{n \in path} P_{node}(n)$$

其中：
$$P_{node}(n) = \begin{cases}
3.0 & \text{if node type = GPU\_SM} \\
2.0 & \text{if node type = CPU\_CORE} \\
1.5 & \text{if node type = MEMORY\_CTRL} \\
1.0 & \text{otherwise}
\end{cases}$$

### **2.4 拥塞适应度组件**

**拥塞惩罚函数**：
$$f_{congestion} = \sum_{k=1}^{L-1} \gamma \cdot H(C_{link}(k) - \theta)$$

其中：
- $H(x)$ = Heaviside阶跃函数
- $\theta = 0.8$ = 拥塞阈值
- $\gamma = 20.0$ = 拥塞惩罚强度

### **2.5 路径平滑度组件**

**方向变化惩罚**：
$$f_{smoothness} = \sum_{i=1}^{L-2} \delta \cdot \left( 1 - \cos(\theta_{i,i+1}) \right)$$

其中：
$$\cos(\theta_{i,i+1}) = \frac{\vec{d}_{i} \cdot \vec{d}_{i+1}}{|\vec{d}_{i}| \cdot |\vec{d}_{i+1}|}$$

- $\vec{d}_i$ = 从节点$i$到节点$i+1$的方向向量
- $\delta = 2.0$ = 方向变化惩罚权重

### **2.6 目标匹配奖励**

**目标到达奖励函数**：
$$f_{target} = \begin{cases}
-10.0 & \text{if final\_node = dest\_node} \\
5.0 \cdot d_{Manhattan}(final\_node, dest\_node) & \text{otherwise}
\end{cases}$$

其中曼哈顿距离：
$$d_{Manhattan}(n_1, n_2) = |x_1 - x_2| + |y_1 - y_2|$$

---

## **3. 归一化公式**

### **3.1 延迟归一化**

$$f_{delay}^{normalized} = \frac{f_{delay} - f_{delay}^{min}}{f_{delay}^{max} - f_{delay}^{min}}$$

其中：$f_{delay}^{min} = 1.0$，$f_{delay}^{max} = 8.0$

### **3.2 功耗归一化**

$$f_{power}^{normalized} = \frac{f_{power} - f_{power}^{min}}{f_{power}^{max} - f_{power}^{min}}$$

其中：$f_{power}^{min} = 10.0$，$f_{power}^{max} = 100.0$

### **3.3 拥塞归一化**

$$f_{congestion}^{normalized} = \min(1.0, \max(0.0, f_{congestion}))$$

### **3.4 负载均衡归一化**

$$f_{load}^{normalized} = \frac{f_{load}}{f_{load}^{max}}$$

其中：$f_{load}^{max} = 1.0$

### **3.5 可靠性归一化**

$$f_{reliability}^{normalized} = 1.0 - f_{reliability}$$

### **3.6 QoS归一化**

$$f_{qos}^{normalized} = \min(1.0, \max(0.0, f_{qos}))$$

---

## **4. 性能评估指标公式**

### **4.1 吞吐量指标**

**饱和吞吐量**：
$$\Theta_{saturated} = \frac{N_{completed}}{T_{simulation}}$$

其中：
- $N_{completed}$ = 成功完成的包数量
- $T_{simulation}$ = 仿真总时间（ticks）

### **4.2 延迟指标**

**平均包延迟**：
$$\bar{L} = \frac{1}{N} \sum_{i=1}^{N} (T_{delivery,i} - T_{injection,i})$$

其中：
- $N$ = 包总数
- $T_{delivery,i}$ = 第$i$个包的交付时间
- $T_{injection,i}$ = 第$i$个包的注入时间

### **4.3 执行时间指标**

**算法执行时间**：
$$T_{execution} = \frac{T_{algorithm}}{10^6} \text{ (μs)}$$

其中：$T_{algorithm}$ = 算法执行的tick数

### **4.4 利用率指标**

**平均链路利用率**：
$$U_{avg} = \frac{1}{M} \sum_{j=1}^{M} \frac{B_{used,j}}{B_{total,j}} \times 100\%$$

其中：
- $M$ = 链路总数
- $B_{used,j}$ = 第$j$条链路的已用带宽
- $B_{total,j}$ = 第$j$条链路的总带宽

### **4.5 能耗指标**

**静态能耗**：
$$E_{static} = P_{static} \times T_{simulation} \times 10^6 \text{ (μW·s)}$$

**动态能耗**：
$$E_{dynamic} = P_{dynamic} \times T_{active} \times 10^6 \text{ (μW·s)}$$

**总能耗**：
$$E_{total} = E_{static} + E_{dynamic}$$

### **4.6 跳数指标**

**平均跳数**：
$$\bar{H} = \frac{1}{N} \sum_{i=1}^{N} H_i$$

其中：$H_i$ = 第$i$个包的跳数

**理论最小跳数（曼哈顿距离）**：
$$H_{min}(src, dest) = |x_{src} - x_{dest}| + |y_{src} - y_{dest}|$$

### **4.7 注入率指标**

**全局包注入率**：
$$R_{injection} = \frac{N_{injected}}{T_{cycles} \times N_{nodes}}$$

**节点平均注入率**：
$$\bar{R}_{node} = \frac{1}{N_{nodes}} \sum_{i=1}^{N_{nodes}} \frac{N_{injected,i}}{T_{cycles}}$$

---

## **5. 群体多样性与收敛分析公式**

### **5.1 群体多样性计算**

**欧几里得多样性**：
$$D_{swarm} = \frac{2}{P(P-1)} \sum_{i=1}^{P-1} \sum_{j=i+1}^{P} \sqrt{\sum_{k=1}^{d} (x_{i,k} - x_{j,k})^2}$$

**归一化多样性**：
$$D_{normalized} = \min\left(1.0, \frac{D_{swarm}}{D_{max}}\right)$$

其中：$D_{max} = 10.0$（假设最大距离）

### **5.2 收敛梯度分析**

**线性回归梯度**：
$$\nabla_{convergence} = \frac{n \sum_{i=1}^{n} i \cdot f_i - \sum_{i=1}^{n} i \sum_{i=1}^{n} f_i}{n \sum_{i=1}^{n} i^2 - \left(\sum_{i=1}^{n} i\right)^2}$$

其中：
- $n = 4$ = 用于计算的历史点数
- $f_i$ = 第$i$个历史适应度值

### **5.3 改进率计算**

**适应度改进率**：
$$\Delta f = \frac{f_{best}^{t-1} - f_{best}^{t}}{\max(1.0, f_{best}^{t-1})}$$

**平均改进率**：
$$\bar{\Delta f} = \frac{1}{k} \sum_{i=1}^{k} \Delta f_i$$

其中：$k$ = 历史窗口大小

---

## **6. 网络拓扑分析公式**

### **6.1 节点坐标映射**

**4×4网格坐标转换**：
$$x_{coord} = node\_id \bmod 4$$
$$y_{coord} = \lfloor \frac{node\_id}{4} \rfloor$$

### **6.2 邻接关系判断**

**邻接条件**：
$$Adjacent(n_1, n_2) = \begin{cases}
true & \text{if } |x_1 - x_2| + |y_1 - y_2| = 1 \\
false & \text{otherwise}
\end{cases}$$

### **6.3 链路ID映射**

**链路标识计算**：
$$link\_id = (node_1 \times 16 + node_2) \bmod 24$$

### **6.4 端口方向映射**

**方向端口映射**：
$$port = \begin{cases}
0 & \text{if } y_{next} < y_{src} \text{ (North)} \\
1 & \text{if } x_{next} > x_{src} \text{ (East)} \\
2 & \text{if } y_{next} > y_{src} \text{ (South)} \\
3 & \text{if } x_{next} < x_{src} \text{ (West)}
\end{cases}$$

---

## **7. 自适应权重管理公式**

### **7.1 网络状态向量**

**网络效率计算**：
$$E_{network} = 1.0 - (0.4 \cdot C_{avg} + 0.3 \cdot U_{peak} + 0.2 \cdot V_{load} + 0.1 \cdot P_{usage})$$

其中：
- $C_{avg}$ = 平均拥塞度
- $U_{peak}$ = 峰值利用率
- $V_{load}$ = 负载方差
- $P_{usage}$ = 功耗预算使用率

### **7.2 权重平滑过渡**

**指数加权移动平均**：
$$w_j^{t+1} = \alpha \cdot w_{j,target} + (1-\alpha) \cdot w_j^t$$

其中：
- $\alpha \in [0.1, 0.9]$ = 平滑因子
- $w_{j,target}$ = 目标权重
- $w_j^t$ = 当前权重

### **7.3 网络压力评估**

**综合压力指标**：
$$S_{network} = 0.4 \cdot S_{congestion} + 0.3 \cdot S_{utilization} + 0.2 \cdot S_{load} + 0.1 \cdot S_{power}$$

**压力趋势分析**：
$$\Delta S = \frac{1}{k-1} \sum_{i=2}^{k} (S_i - S_{i-1})$$

其中：$k$ = 历史状态数量

### **7.4 拥塞趋势预测**

**线性回归预测**：
$$\hat{C}_{t+1} = \beta_0 + \beta_1 \cdot t$$

其中：
$$\beta_1 = \frac{n \sum_{i=1}^{n} i \cdot C_i - \sum_{i=1}^{n} i \sum_{i=1}^{n} C_i}{n \sum_{i=1}^{n} i^2 - \left(\sum_{i=1}^{n} i\right)^2}$$

$$\beta_0 = \frac{\sum_{i=1}^{n} C_i - \beta_1 \sum_{i=1}^{n} i}{n}$$

---

## **8. 协作优化公式**

### **8.1 群间知识共享**

**全局最优更新**：
$$g_{best}^{k+1} = \arg \min_{i \in Swarms} \{ f_{best,i}^k \}$$

**群体最优融合**：
$$p_{shared} = \frac{1}{S} \sum_{s=1}^{S} w_s \cdot p_{best,s}$$

其中：
- $S$ = 群体总数
- $w_s$ = 第$s$个群体的权重
- $p_{best,s}$ = 第$s$个群体的最优位置

### **8.2 处理单元类型权重**

**类型特化权重**：
$$w_{type} = \begin{cases}
[0.5, 0.1, 0.2, 0.1, 0.05, 0.05] & \text{MINIMIZE\_DELAY} \\
[0.1, 0.5, 0.2, 0.1, 0.05, 0.05] & \text{MINIMIZE\_POWER} \\
[0.1, 0.1, 0.5, 0.2, 0.05, 0.05] & \text{MINIMIZE\_CONGESTION} \\
[0.1, 0.1, 0.2, 0.5, 0.05, 0.05] & \text{BALANCE\_LOAD} \\
[0.1, 0.1, 0.1, 0.1, 0.5, 0.1] & \text{MAXIMIZE\_RELIABILITY} \\
[0.1, 0.1, 0.1, 0.1, 0.1, 0.5] & \text{OPTIMIZE\_QOS} \\
[0.2, 0.2, 0.2, 0.2, 0.1, 0.1] & \text{BALANCED}
\end{cases}$$

### **8.3 QoS类别调整**

**QoS适应度调整因子**：
$$\xi_{qos} = \begin{cases}
0.7 & \text{REAL\_TIME} \\
0.8 & \text{LOW\_LATENCY} \\
0.75 & \text{GUARANTEED} \\
0.9 & \text{HIGH\_THROUGHPUT (if } C < 0.5) \\
1.0 & \text{BEST\_EFFORT}
\end{cases}$$

**调整后适应度**：
$$F_{adjusted} = \xi_{qos} \cdot F_{total}$$

---

## **9. 机器学习增强公式**

### **9.1 神经网络预测**

**隐藏层激活**：
$$h_j = \sigma\left(\sum_{i=1}^{6} w_{ij} \cdot x_i^{norm} + b_j\right)$$

其中：$\sigma(z) = \frac{1}{1 + e^{-z}}$（Sigmoid激活函数）

**输出层计算**：
$$\hat{f} = \sum_{j=1}^{4} w_{j} \cdot h_j$$

### **9.2 特征归一化**

**在线均值更新**：
$$\mu_i^{t+1} = \mu_i^t + \frac{x_i - \mu_i^t}{t+1}$$

**在线标准差更新**：
$$\sigma_i^{t+1} = \max(0.1, 0.999 \cdot \sigma_i^t + 0.001 \cdot |x_i - \mu_i^t|)$$

**特征归一化**：
$$x_i^{norm} = \frac{x_i - \mu_i}{\sigma_i}$$

### **9.3 缓存有效性**

**时间衰减权重**：
$$w_{cache} = e^{-\lambda \cdot \Delta t}$$

其中：
- $\lambda$ = 衰减常数
- $\Delta t$ = 时间差

**缓存命中条件**：
$$Valid_{cache} = \begin{cases}
true & \text{if } \Delta t < T_{validity} \\
false & \text{otherwise}
\end{cases}$$

其中：$T_{validity} = 100$ ticks

---

## **10. 复杂度分析公式**

### **10.1 时间复杂度**

**PSO算法复杂度**：
$$T_{PSO} = O(P \times I \times D)$$

**多群协作复杂度**：
$$T_{Multi-Swarm} = O(S \times P \times D)$$

**全局图管理复杂度**：
$$T_{Global} = O(N^2)$$

**总体系统复杂度**：
$$T_{System} = O(S \times P \times I \times D + N^2)$$

### **10.2 空间复杂度**

**粒子存储复杂度**：
$$S_{Particles} = O(S \times P \times D)$$

**历史数据存储复杂度**：
$$S_{History} = O(M \times T)$$

**总体空间复杂度**：
$$S_{Total} = O(S \times P \times D + N^2 + M \times T)$$

其中：
- $P$ = 粒子数量
- $I$ = 迭代次数  
- $D$ = 维度数量
- $S$ = 群体数量
- $N$ = 网络节点数
- $M$ = 指标数量
- $T$ = 时间步数

---

## **11. 约束条件与边界**

### **11.1 系统约束**

**位置约束**：
$$0 \leq x_{i,j} \leq 15, \quad \forall i,j$$

**速度约束**：
$$-v_{max} \leq v_{i,j} \leq v_{max}, \quad \forall i,j$$

**权重约束**：
$$\sum_{j=1}^{6} w_j = 1, \quad w_j \geq 0$$

### **11.2 物理约束**

**功耗预算约束**：
$$\sum_{n \in network} P_n \leq P_{budget}$$

**带宽约束**：
$$\sum_{f \in flows} B_f \leq B_{link}, \quad \forall link$$

**延迟约束**：
$$L_{packet} \leq L_{deadline}, \quad \forall packet$$

---

## **12. 公式验证与测试**

### **12.1 数值稳定性检验**

**归一化有效性**：
$$0 \leq f_j^{normalized} \leq 1, \quad \forall j$$

**权重收敛性**：
$$\lim_{t \to \infty} |w_j^{t+1} - w_j^t| = 0$$

### **12.2 算法收敛性**

**Lyapunov稳定性条件**：
$$V(x^{t+1}) \leq V(x^t)$$

其中：$V(x)$ = Lyapunov函数

**收敛准则**：
$$|\nabla_{convergence}| < \epsilon_{threshold}$$

其中：$\epsilon_{threshold} = 0.001$

---

## **总结**

本文档包含了MVPP_MGC_PSO路由算法的**完整数学公式体系**，共计**78个核心数学公式**，涵盖：

1. **PSO核心算法** - 粒子动力学方程
2. **多目标优化** - 适应度函数与组件
3. **性能评估** - 标准化指标计算
4. **自适应机制** - 参数动态调整
5. **网络建模** - 拓扑分析与映射
6. **协作优化** - 多群体协调
7. **机器学习** - 智能预测与缓存
8. **复杂度分析** - 理论性能界限

这些公式构成了MVPP_MGC_PSO算法的完整数学基础，适用于学术研究、工程实现和性能分析。

---

**文档统计**：
- **数学公式总数**：78个
- **主要类别**：12个
- **复杂度级别**：从O(1)到O(S×P×I×D)
- **应用领域**：NoC路由优化、系统性能分析

**版权**：© 2025 MVPP_MGC_PSO Research Team. MIT License.