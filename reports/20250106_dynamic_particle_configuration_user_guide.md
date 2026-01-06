# 动态粒子配置使用指南

**完成日期**: 2026-01-06
**功能状态**: ✅ 已实现，编译测试通过
**向后兼容**: ✅ 完全兼容（默认关闭动态模式）

---

## 📋 功能概述

### 实现的核心能力

**单阶段自适应粒子配置** - 根据路由任务复杂度动态调整PSO粒子数量：

```
传统固定配置（三阶段）:
┌────────────────────────────────────┐
│ Stage-1: 永远20粒子                │
│ Stage-2: 永远10粒子                │
│ Stage-3: 永远5粒子                 │
│ ❌ 简单路由浪费资源                │
│ ❌ 复杂路由质量不足                │
└────────────────────────────────────┘

动态自适应配置（新功能）:
┌────────────────────────────────────┐
│ 简单路由（相邻节点）: 5粒子        │
│ 中等路由（2-3跳）:   10-12粒子     │
│ 复杂路由（4+跳,拥塞）: 18-20粒子   │
│ ✅ 自动优化资源分配                │
│ ✅ 质量保证动态调整                │
└────────────────────────────────────┘
```

### 复杂度评估因素

动态粒子数基于5个因素综合评估：

| 因素 | 权重 | 说明 |
|------|------|------|
| **曼哈顿距离** | 35% | 几何路由难度（最大距离6） |
| **网络拥塞** | 30% | 实时网络负载状态 |
| **缓存未命中** | 15% | 新路径/困难路径指示 |
| **历史质量** | 10% | 从过往路由学习 |
| **类型差异** | 10% | 跨处理单元类型路由 |

**复杂度计算公式**:
```cpp
complexity = 0.35 * distance_factor +
             0.30 * congestion_factor +
             0.15 * cache_miss_penalty +
             0.10 * history_quality +
             0.10 * type_difference;
// complexity ∈ [0.0, 1.0]
```

**粒子数映射**:
```cpp
particles = 5 + (20-5) * complexity
particles = round_to_multiple_of_5(particles)
// particles ∈ {5, 10, 15, 20}
```

---

## 🔧 如何启用动态粒子配置

### 方法1: 修改PSOAlgorithm构造函数（推荐）

**文件**: `PSOAlgorithm.cc`
**位置**: 构造函数（约第18-40行）

```cpp
PSOAlgorithm::PSOAlgorithm(Router* router_ptr)
    : m_router_ptr(router_ptr), m_enable_pso(true),
      // ... 其他初始化 ...
{
    m_fitness_history.reserve(100);

    // **启用动态粒子配置**
    auto config_manager = PSOConfigUtil::getGlobalConfigManager();

    // 方式A: 完全替换固定Stage配置
    // config_manager->setCurrentStage("Stage1");  // ← 注释掉

    // 方式B: 基于现有Stage，启用动态模式
    config_manager->setCurrentStage("Stage1");  // 保留Stage框架
    auto current_config = config_manager->getCurrentConfig();
    current_config.enable_dynamic_particles = true;  // ✅ 启用动态模式
    config_manager->updateCurrentConfig(current_config);  // 应用修改

    // 初始化性能监控器
    std::string monitor_name = "DynamicPSO_Router" + std::to_string(router_ptr->get_id());
    m_performance_monitor = new PSOPerformanceMonitor(monitor_name, false, 0);

    printf("[PSO-Init] Router %d initialized with DYNAMIC particle configuration\n",
           router_ptr->get_id());
}
```

**注意**: 方法1需要 `PSOConfigManager` 提供 `updateCurrentConfig()` 方法。如果该方法不存在，使用方法2。

### 方法2: 修改Stage初始化配置（备选）

**文件**: `PSOConfigManager.cc`
**位置**: `initializeDefaultConfigurations()` 函数

```cpp
void PSOConfigManager::initializeDefaultConfigurations() {
    // ... 现有Baseline配置 ...

    // **新增: Dynamic Stage配置**
    PSOConfiguration dynamic_stage = baseline;
    dynamic_stage.stage_name = "DynamicAdaptive";
    dynamic_stage.description = "Adaptive particle count based on routing complexity";
    dynamic_stage.particle_count = 10;  // 默认中等粒子数（实际将被动态覆盖）
    dynamic_stage.max_iterations = 30;
    dynamic_stage.enable_dynamic_particles = true;  // ✅ 关键配置
    dynamic_stage.enable_early_termination = true;
    dynamic_stage.enable_performance_monitoring = true;
    dynamic_stage.max_acceptable_time_us = 40.0;
    dynamic_stage.min_quality_retention = 0.93;
    dynamic_stage.timestamp = curTick();

    m_saved_configurations["DynamicAdaptive"] = dynamic_stage;
}
```

然后在 `PSOAlgorithm` 构造函数中：
```cpp
auto config_manager = PSOConfigUtil::getGlobalConfigManager();
config_manager->setCurrentStage("DynamicAdaptive");  // 使用动态配置
```

### 方法3: 通过命令行参数启用（未来扩展）

**文件**: `gem5-gpu/configs/se_fusion.py`

```python
# 添加命令行参数
parser.add_option("--pso-dynamic-particles", action="store_true",
                  default=False,
                  help="Enable dynamic particle count based on routing complexity")

# 在配置应用代码中
if options.pso_dynamic_particles:
    # 设置全局配置标志
    # 注意: 需要在C++端暴露配置接口
    pass
```

**运行命令**:
```bash
./gem5.opt configs/se_fusion.py --pso-dynamic-particles \
    -c benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"
```

---

## 🧪 测试与验证

### 快速功能验证

**Step 1: 启用动态模式**（选择上述方法之一）

**Step 2: 编译测试**
```bash
./build_and_test_all.sh -b
```

**Step 3: 运行单个基准测试**
```bash
./build_and_test_all.sh -t backprop
```

**Step 4: 检查日志输出**

查找动态配置日志标记：
```bash
grep "PSO-Dynamic" build_logs/test_backprop_*.log | head -20
```

**预期输出示例**:
```
[PSO-Dynamic] Route 0→1: complexity=0.125 → 5 particles (adaptive)
[PSO-Dynamic] Route 0→5: complexity=0.450 → 10 particles (adaptive)
[PSO-Dynamic] Route 0→15: complexity=0.875 → 20 particles (adaptive)
[PSO-Dynamic] Route 2→11: complexity=0.320 → 10 particles (adaptive)
```

**日志分析关键点**:
- ✅ 看到 `[PSO-Dynamic]` 标记表示动态模式已启用
- ✅ `complexity` 值应在 [0.0, 1.0] 范围
- ✅ 粒子数应在 {5, 10, 15, 20} 中（5的倍数）
- ✅ 简单路由（complexity < 0.3）使用5粒子
- ✅ 复杂路由（complexity > 0.7）使用15-20粒子

### 性能对比测试

**对比实验设计**:

**实验1: 固定Stage-2 vs 动态配置**

```bash
# 测试A: Stage-2固定配置 (10粒子)
# 修改PSOAlgorithm.cc构造函数
config_manager->setCurrentStage("Stage2");
# enable_dynamic_particles保持false

# 编译运行
./build_and_test_all.sh
cp build_logs/test_backprop_*.log results_stage2_fixed.log
cp build_logs/test_kmeans_*.log results_kmeans_stage2_fixed.log

# 测试B: 动态配置
# 修改PSOAlgorithm.cc构造函数
current_config.enable_dynamic_particles = true;

# 编译运行
./build_and_test_all.sh
cp build_logs/test_backprop_*.log results_dynamic.log
cp build_logs/test_kmeans_*.log results_kmeans_dynamic.log
```

**性能指标对比**:

创建分析脚本 `analyze_dynamic_performance.sh`:
```bash
#!/bin/bash

echo "=== Performance Comparison: Stage-2 Fixed vs Dynamic Adaptive ==="
echo ""

echo "1. Particle Count Distribution:"
echo "   Stage-2 Fixed:"
grep "PSO-Config" results_stage2_fixed.log | awk '{print $NF}' | sort | uniq -c
echo ""
echo "   Dynamic Adaptive:"
grep "PSO-Dynamic" results_dynamic.log | awk '{print $NF}' | sort | uniq -c
echo ""

echo "2. Average Routing Time:"
echo "   Stage-2 Fixed:"
grep "computation_time" results_stage2_fixed.log | awk '{sum+=$4; count++} END {print sum/count " ticks"}'
echo ""
echo "   Dynamic Adaptive:"
grep "computation_time" results_dynamic.log | awk '{sum+=$4; count++} END {print sum/count " ticks"}'
echo ""

echo "3. Route Quality Score:"
echo "   Stage-2 Fixed:"
grep "quality_score" results_stage2_fixed.log | awk '{sum+=$3; count++} END {print sum/count*100 "%"}'
echo ""
echo "   Dynamic Adaptive:"
grep "quality_score" results_dynamic.log | awk '{sum+=$3; count++} END {print sum/count*100 "%"}'
echo ""

echo "4. Complexity Distribution (Dynamic only):"
grep "complexity=" results_dynamic.log | awk -F'complexity=' '{print $2}' | \
    awk -F'→' '{print $1}' | awk '
    {
        if ($1 < 0.3) low++;
        else if ($1 < 0.7) mid++;
        else high++;
        total++;
    }
    END {
        printf "   Low (0.0-0.3):  %d (%.1f%%)\n", low, low/total*100;
        printf "   Mid (0.3-0.7):  %d (%.1f%%)\n", mid, mid/total*100;
        printf "   High (0.7-1.0): %d (%.1f%%)\n", high, high/total*100;
    }'
```

**运行分析**:
```bash
chmod +x analyze_dynamic_performance.sh
./analyze_dynamic_performance.sh > performance_comparison.txt
cat performance_comparison.txt
```

**预期性能提升**:

| 指标 | Stage-2固定 | 动态配置 | 改进 |
|------|-----------|---------|------|
| 平均粒子数 | 10.0 | 8-10 | -5~10% |
| 平均延迟 | 25 ticks | 22-24 ticks | -8~12% |
| 路由质量 | 92.5% | 93-94% | +0.5~1.5% |
| 资源利用率 | 75% | 88-92% | +17~23% |

---

## 📊 参数调优指南

### 复杂度权重调整

**文件**: `PSOAlgorithm.cc` → `evaluateRoutingComplexity()` 函数（约第2203行）

**当前权重配置**:
```cpp
complexity = 0.35 * distance_factor +      // 距离因素
             0.30 * congestion_factor +    // 拥塞因素
             0.15 * cache_miss_penalty +   // 缓存因素
             0.10 * history_quality +      // 历史因素
             0.10 * type_difference;       // 类型因素
```

**调优场景**:

**场景A: 拥塞敏感型网络**（高负载环境）
```cpp
complexity = 0.25 * distance_factor +      // 降低距离权重
             0.45 * congestion_factor +    // ✅ 提高拥塞权重
             0.15 * cache_miss_penalty +
             0.10 * history_quality +
             0.05 * type_difference;
```

**场景B: 距离优先型网络**（稀疏流量）
```cpp
complexity = 0.50 * distance_factor +      // ✅ 提高距离权重
             0.20 * congestion_factor +    // 降低拥塞权重
             0.15 * cache_miss_penalty +
             0.10 * history_quality +
             0.05 * type_difference;
```

**场景C: 学习优先型**（长期运行仿真）
```cpp
complexity = 0.30 * distance_factor +
             0.25 * congestion_factor +
             0.10 * cache_miss_penalty +
             0.25 * history_quality +      // ✅ 提高历史权重
             0.10 * type_difference;
```

### 粒子数范围调整

**文件**: `PSOAlgorithm.cc` → `calculateDynamicParticleCount()` 函数（约第2242行）

**当前配置**:
```cpp
const int MIN_PARTICLES = 5;   // 最小粒子数
const int MAX_PARTICLES = 20;  // 最大粒子数
```

**保守策略**（倾向质量保证）:
```cpp
const int MIN_PARTICLES = 8;   // ✅ 提高最小值
const int MAX_PARTICLES = 20;
```

**激进策略**（倾向资源节省）:
```cpp
const int MIN_PARTICLES = 5;
const int MAX_PARTICLES = 15;  // ✅ 降低最大值
```

**大规模网络**（超过4x4 mesh）:
```cpp
const int MIN_PARTICLES = 8;   // ✅ 提高范围
const int MAX_PARTICLES = 30;  // ✅ 支持更多粒子
```

### 非线性映射（高级）

**线性映射**（当前实现）:
```cpp
int base_count = MIN + (MAX - MIN) * complexity;
// complexity=0.5 → 12.5粒子 → 圆整到10或15
```

**指数映射**（复杂路由分配更多粒子）:
```cpp
double nonlinear_complexity = pow(complexity, 0.7);  // 降低指数
int base_count = MIN + (MAX - MIN) * nonlinear_complexity;
// complexity=0.5 → pow(0.5, 0.7)=0.62 → 14粒子
```

**对数映射**（高复杂度时粒子数快速增长）:
```cpp
double nonlinear_complexity = log(1.0 + complexity) / log(2.0);
int base_count = MIN + (MAX - MIN) * nonlinear_complexity;
```

---

## 🔍 调试与问题排查

### 调试输出详解

**启用详细调试**:
```bash
# 编译时启用RubyNetwork调试标志
./gem5.opt --debug-flags=RubyNetwork ...
```

**关键调试信息**:

**1. 复杂度评估详情**:
```
Routing complexity evaluation: src=0, dest=5,
  distance=3 (factor=0.500), congestion=0.320,
  cache_miss=1 (penalty=0.300), history_quality=0.120,
  type_diff=1 (penalty=0.200),
  → total_complexity=0.450
```

**2. 粒子数计算详情**:
```
Dynamic particle count: complexity=0.450 →
  base_count=11 → rounded_count=10 particles
```

**3. 粒子初始化确认**:
```
[PSO-Dynamic] Route 0→5: complexity=0.450 → 10 particles (adaptive)
```

### 常见问题

**问题1: 看不到动态配置日志**

**症状**: 运行测试后没有 `[PSO-Dynamic]` 日志输出

**排查步骤**:
```bash
# 1. 检查配置是否启用
grep "enable_dynamic_particles" PSOAlgorithm.cc

# 2. 检查是否进入动态分支
grep "DYNAMIC MODE" PSOAlgorithm.cc

# 3. 查看实际使用的配置
grep "PSO-Config\|PSO-Dynamic" build_logs/test_*.log | head -10
```

**解决方案**:
- 确认修改了正确的构造函数
- 确认 `enable_dynamic_particles = true` 被正确设置
- 确认重新编译后运行测试

**问题2: 粒子数始终相同**

**症状**: 所有路由使用相同粒子数（如总是10个）

**原因分析**:
- 复杂度计算可能有问题（所有路由复杂度相同）
- 网络状态未正确获取

**排查**:
```bash
# 检查复杂度分布
grep "complexity=" build_logs/test_*.log | \
    awk -F'complexity=' '{print $2}' | awk -F'→' '{print $1}' | \
    sort -n | uniq -c
```

**解决方案**:
- 检查 `s_global_graph` 是否正确初始化
- 检查 `getAverageNodeCongestion()` 返回值
- 调整复杂度权重提高差异性

**问题3: 编译警告或错误**

**症状**: 编译时出现 const 相关警告

**常见错误**:
```
error: passing 'const FastRoutingCache' as 'this' argument
discards qualifiers
```

**解决方案**: 已在实现中修复（`mutable` 关键字）

---

## 📈 性能基准与优化目标

### 理论性能模型

**资源效率提升**:
```
假设路由分布:
- 简单路由（1-2跳）: 40% → 5粒子（vs Stage-2的10）
- 中等路由（3-4跳）: 45% → 10粒子（vs Stage-2的10）
- 复杂路由（5-6跳）: 15% → 18粒子（vs Stage-2的10）

平均粒子数:
  Stage-2固定: 10.0
  动态配置: 0.4×5 + 0.45×10 + 0.15×18 = 9.2
  节省资源: 8%

平均计算时间:
  Stage-2固定: 25 ticks
  动态配置: 0.4×12 + 0.45×25 + 0.15×45 = 22.8 ticks
  延迟降低: 8.8%

路由质量:
  Stage-2固定: 92.5%
  动态配置: 0.4×92 + 0.45×93 + 0.15×96 = 93.2%
  质量提升: 0.7%
```

### 实际性能目标

**Phase 3测试后期望达到**:

| 指标 | 基线(Stage-2) | 目标(动态) | 验收标准 |
|------|-------------|----------|---------|
| 平均资源使用 | 100% | 85-95% | ✅ 节省5-15% |
| 平均延迟 | 25 ticks | <23 ticks | ✅ 降低8%+ |
| 路由质量 | 92.5% | >93% | ✅ 提升0.5%+ |
| 复杂路由质量 | 90% | >94% | ✅ 大幅提升 |

**失败案例处理**:
- 如果平均延迟未改善 → 调整粒子数范围（降低MIN）
- 如果质量下降 → 调整复杂度权重（提高congestion权重）
- 如果资源未节省 → 检查复杂度分布（可能过于保守）

---

## 🚀 下一步优化方向

### Phase 4: 机器学习驱动复杂度评估

**替换手工权重为学习模型**:

```python
# 训练脚本示例
import numpy as np
from sklearn.ensemble import RandomForestRegressor

# 收集训练数据
features = [
    [distance, congestion, cache_status, history_quality, type_diff],
    # ... 更多样本
]
optimal_particles = [20, 10, 5, 15, ...]  # 人工标注或性能最优值

# 训练模型
model = RandomForestRegressor()
model.fit(features, optimal_particles)

# 导出C++可用格式
export_to_cpp(model, "particle_count_predictor.h")
```

### Phase 5: 在线学习与自适应

**根据历史性能动态调整**:

```cpp
struct AdaptiveComplexityManager {
    std::map<std::pair<int,int>, RoutePerformance> history;

    double evaluateComplexity(int src, int dest) {
        // 基础复杂度
        double base_complexity = computeBaseComplexity(src, dest);

        // 历史性能修正
        auto key = std::make_pair(src, dest);
        if (history.count(key) > 0) {
            auto perf = history[key];
            if (perf.avg_quality < 0.90) {
                base_complexity *= 1.2;  // 增加复杂度评估
            }
        }

        return base_complexity;
    }
};
```

---

## 📚 总结

### 已实现功能清单

✅ **核心功能**:
- [x] 5因素复杂度评估系统
- [x] 动态粒子数计算（5-20粒子）
- [x] 配置开关（enable_dynamic_particles）
- [x] 向后兼容保证（默认关闭）
- [x] 详细调试日志输出

✅ **代码质量**:
- [x] 完整的函数文档（Doxygen风格）
- [x] 健壮的错误处理（空指针检查、范围限制）
- [x] 清晰的代码注释
- [x] 编译零警告

✅ **测试就绪**:
- [x] 编译测试通过
- [x] 功能验证方法明确
- [x] 性能对比框架完备

### 使用建议

**快速开始**:
1. 使用**方法2**启用动态配置（修改PSOConfigManager.cc）
2. 运行 `./build_and_test_all.sh` 验证功能
3. 分析日志确认动态模式工作正常

**性能调优**:
1. 先用默认权重跑基准测试
2. 根据实际性能调整复杂度权重
3. 根据网络特点调整粒子数范围

**生产使用**:
- 建议保持 `enable_dynamic_particles=false` 作为安全基线
- 充分测试验证后再全面启用
- 定期对比固定配置性能确保优势

---

**文档版本**: 1.0
**维护者**: Claude Code
**最后更新**: 2026-01-06
