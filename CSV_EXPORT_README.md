# gem5-gpu 实验结果CSV导出功能使用说明

## 功能概述

该功能可以自动从gem5仿真统计输出（stats.txt）中提取关键性能指标，并生成带时间戳的CSV报告文件，方便进行实验数据分析和对比。

## 主要特性

### 1. 自动化集成
- 测试脚本（`run_tests.sh`）在测试成功完成后自动生成CSV报告
- 无需手动操作，全自动处理
- CSV文件自动命名为 `results_<测试名>_<时间戳>.csv`

### 2. 完整的性能指标收集

CSV报告包含以下关键指标：

#### 通用系统指标
- 仿真时间（Simulation Time）
- 仿真时钟周期（Simulation Ticks）
- 实际运行时间（Host Execution Time）
- 指令数和操作数（Instructions/Ops）
- 指令执行速率（Instruction Rate）

#### MVPP_MGC_PSO路由算法指标
- **路由计数统计**：
  - MVPP_MGC_PSO路由次数
  - 传统路由次数（应该为0）
  - 总路由次数

- **时间性能**：
  - MVPP_MGC_PSO路由总时间
  - 平均路由延迟（mean）
  - 路由延迟标准差（stdev）
  - 路由延迟几何平均（geomean）

- **功耗统计**：
  - MVPP_MGC_PSO功耗（μW·s）
  - 传统路由功耗（应该为0）
  - 总功耗

#### 网络性能指标
- 链路利用率（Top 10最活跃的链路）
- 网络拓扑使用情况

#### 内存系统指标
- 内存读写字节数
- 内存带宽（读/写/总）
- 平均内存访问延迟

#### 功耗指标
- 内存各Rank的平均功耗

## 使用方法

### 方法1: 自动生成（推荐）

运行测试时，CSV会自动生成：

```bash
# 运行所有测试（自动生成CSV）
./run_tests.sh all

# 运行单个测试（自动生成CSV）
./run_tests.sh backprop
./run_tests.sh kmeans
```

**输出文件位置**：
- CSV文件：`build_logs/results_<测试名>_<时间戳>.csv`
- 统计文件：`build_logs/stats_<测试名>_<时间戳>.txt`

### 方法2: 手动生成

如果需要手动处理已有的stats.txt文件：

```bash
# 基本用法
python3 generate_results_csv.py <stats.txt路径> [输出CSV路径]

# 示例1：自动命名输出文件
python3 generate_results_csv.py /home/siat/test/stats.txt

# 示例2：指定输出文件名
python3 generate_results_csv.py /home/siat/test/stats.txt results_20251105_143000.csv

# 示例3：处理历史数据
python3 generate_results_csv.py build_logs/stats_backprop_20251105_101723.txt \
                                 results_backprop_analysis.csv
```

## 输出文件格式

CSV文件采用两列格式：

```csv
Metric,Value
=== General System Metrics ===,
Timestamp,20251105_150628
Simulation Time (seconds),0.000573
...
=== MVPP_MGC_PSO Routing Algorithm Metrics ===,
MVPP_MGC_PSO Routing Count,13962
MVPP_MGC_PSO Avg Routing Delay (ticks),28.500573
MVPP_MGC_PSO Power Consumption (μW·s),397.925000
...
```

## 典型输出示例

```
Parsing statistics file: build_logs/stats_test.txt
Parsed 10125 statistics entries
CSV report generated successfully: build_logs/results_test_20251105_150628.csv

Results summary:
  - Simulation time: 0.000573 seconds
  - MVPP routing count: 13962
  - Average routing delay: 28.500573 ticks
  - CSV output: build_logs/results_test_20251105_150628.csv
```

## 与Excel/LibreOffice集成

生成的CSV文件可以直接在Excel或LibreOffice Calc中打开：

1. **打开CSV文件**：
   - Excel：文件 → 打开 → 选择CSV文件
   - LibreOffice Calc：文件 → 打开 → 选择CSV文件

2. **数据分析**：
   - 可直接创建图表
   - 支持数据透视表
   - 支持多个实验结果对比

3. **推荐的分析操作**：
   - 绘制路由延迟趋势图
   - 对比不同配置的功耗
   - 分析链路利用率分布
   - 生成性能对比表格

## 文件命名规则

系统自动生成的文件采用统一的命名规则：

```
results_<测试名>_<年月日>_<时分秒>.csv
stats_<测试名>_<年月日>_<时分秒>.txt
```

示例：
```
results_backprop_20251105_101723.csv
results_kmeans_20251105_104146.csv
stats_backprop_20251105_101723.txt
stats_kmeans_20251105_104146.txt
```

## 批量处理历史数据

如果需要为多个历史stats.txt文件生成CSV：

```bash
# 批量处理build_logs目录下的所有stats文件
for stats_file in build_logs/stats_*.txt; do
    base_name=$(basename "$stats_file" .txt)
    python3 generate_results_csv.py "$stats_file" "build_logs/results_${base_name}.csv"
done
```

## 故障排除

### 问题1：CSV生成失败
**症状**：提示"统计数据文件不存在"

**解决方法**：
```bash
# 检查stats.txt是否存在
ssh siat@192.168.197.130 "ls -lh /home/siat/test/stats.txt"

# 手动复制stats.txt
scp siat@192.168.197.130:/home/siat/test/stats.txt build_logs/
```

### 问题2：Python脚本报错
**症状**：提示Python模块缺失

**解决方法**：
```bash
# 确保Python3安装完整
python3 --version

# CSV模块是Python标准库的一部分，无需额外安装
```

### 问题3：CSV文件为空或数据不完整
**症状**：生成的CSV文件内容不完整

**解决方法**：
```bash
# 检查stats.txt文件是否完整
wc -l build_logs/stats_*.txt

# 检查stats.txt是否包含MVPP统计
grep "mvpp_mgc_pso" build_logs/stats_*.txt
```

## 高级用法

### 自定义指标提取

如果需要提取额外的指标，可以修改 `generate_results_csv.py`：

```python
# 在 ResultsCSVGenerator.generate_csv() 方法中添加新的行：
rows.append(['Your Custom Metric',
             self.parser.get_stat('system.your.custom.metric')])
```

### 批量对比分析

创建批量对比脚本：

```bash
#!/bin/bash
# compare_results.sh - 批量对比多个实验结果

echo "实验对比分析"
echo "测试名称,仿真时间,路由次数,平均延迟,功耗"

for csv_file in build_logs/results_*.csv; do
    test_name=$(grep "Test Name" "$csv_file" | cut -d',' -f2)
    sim_time=$(grep "Simulation Time" "$csv_file" | cut -d',' -f2)
    routing_count=$(grep "MVPP_MGC_PSO Routing Count" "$csv_file" | cut -d',' -f2)
    avg_delay=$(grep "MVPP_MGC_PSO Avg Routing Delay" "$csv_file" | cut -d',' -f2)
    power=$(grep "MVPP_MGC_PSO Power Consumption" "$csv_file" | cut -d',' -f2)

    echo "$test_name,$sim_time,$routing_count,$avg_delay,$power"
done
```

## 相关文件

- **Python脚本**：`/home/siat/gem5-gpu-bak/generate_results_csv.py`
- **测试脚本**：`/home/siat/gem5-gpu-bak/run_tests.sh`
- **输出目录**：`/home/siat/gem5-gpu-bak/build_logs/`

## 注意事项

1. **CSV文件会自动累积**，建议定期清理旧的CSV文件
2. **时间戳文件名**确保不会覆盖历史数据
3. **统计文件（stats.txt）也会被保存**，可用于后续详细分析
4. **只有测试成功（退出码为0）时才会生成CSV**
5. **CSV使用UTF-8编码**，支持中文注释

## 最佳实践

1. **实验命名**：在运行测试前，考虑给实验配置一个有意义的标识
2. **定期备份**：将重要的CSV文件备份到专门的结果目录
3. **数据分析**：定期汇总CSV数据，生成性能趋势报告
4. **版本控制**：CSV文件不建议提交到Git，应加入.gitignore

## 总结

通过该功能，您可以：
- ✅ 自动化收集实验性能数据
- ✅ 快速生成标准化的CSV报告
- ✅ 方便地进行多次实验对比分析
- ✅ 无需手动解析stats.txt文件
- ✅ 直接导入Excel进行可视化分析

这为MVPP_MGC_PSO路由算法的性能分析和优化提供了强大的数据支持。
