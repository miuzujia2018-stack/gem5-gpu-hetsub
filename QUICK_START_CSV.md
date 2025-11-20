# gem5-gpu CSV实验结果导出系统 - 快速入门指南

## 系统概述

该系统为gem5-gpu的MVPP_MGC_PSO路由算法提供了完整的实验数据收集和分析工具链。

### 核心功能

1. **自动CSV生成** - 测试完成后自动生成带时间戳的CSV报告
2. **Python解析工具** - 从stats.txt提取关键性能指标
3. **实验对比工具** - 批量对比多个实验结果

### 文件结构

```
gem5-gpu-bak/
├── generate_results_csv.py    # Python CSV生成脚本
├── compare_experiments.sh      # 实验对比工具
├── run_tests.sh                # 测试脚本（已集成CSV生成）
├── CSV_EXPORT_README.md        # 详细使用说明
└── build_logs/                 # 输出目录
    ├── results_*.csv           # CSV报告文件
    ├── stats_*.txt             # 统计数据文件
    └── test_*.log              # 测试日志文件
```

## 快速开始

### 1. 运行测试并自动生成CSV

```bash
# 方法1：运行所有测试（推荐）
./run_tests.sh all

# 方法2：运行单个测试
./run_tests.sh backprop
./run_tests.sh kmeans
```

**输出示例：**
```
[INFO] 回传统计数据文件...
stats_backprop_20251105_101723.txt            100%  1.5MB  10.0MB/s  00:00
[INFO] 生成CSV报告...
Parsing statistics file: build_logs/stats_backprop_20251105_101723.txt
Parsed 10125 statistics entries
CSV report generated successfully: build_logs/results_backprop_20251105_101723.csv

Results summary:
  - Simulation time: 0.000573 seconds
  - MVPP routing count: 13962
  - Average routing delay: 28.500573 ticks
  - CSV output: build_logs/results_backprop_20251105_101723.csv

[SUCCESS] CSV报告已生成: build_logs/results_backprop_20251105_101723.csv
```

### 2. 手动生成CSV（处理历史数据）

```bash
# 基本用法
python3 generate_results_csv.py <stats文件> [输出CSV]

# 示例
python3 generate_results_csv.py build_logs/stats_test.txt results_custom.csv
```

### 3. 对比多个实验结果

```bash
# 生成文本对比报告
./compare_experiments.sh build_logs/

# 生成CSV格式对比报告
./compare_experiments.sh -f csv -o comparison.csv build_logs/
```

**对比报告示例：**
```
========================================
gem5-gpu MVPP_MGC_PSO 实验结果对比报告
========================================
生成时间: 2025-11-05 15:27:47
对比实验数量: 2

实验名称                        | 仿真时间(s) | 路由次数    | 平均延迟(ticks) | 功耗(μW·s)     | 内存带宽(B/s)
------------------------------------+-----------------+-----------------+--------------------+--------------------+---------------------
backprop_20251105_101723          | 0.000573       | 13962          | 28.500573         | 397.925000        | 102389716
kmeans_20251105_104146            | 0.000684       | 15432          | 29.123456         | 425.678900        | 115234567
```

## CSV输出指标说明

### 通用系统指标
- **Simulation Time (seconds)** - 仿真时间（秒）
- **Simulation Ticks** - 仿真时钟周期
- **Host Execution Time (seconds)** - 实际运行时间
- **Simulated Instructions** - 仿真指令数
- **Host Instruction Rate (inst/s)** - 指令执行速率

### MVPP_MGC_PSO路由算法指标
- **MVPP_MGC_PSO Routing Count** - 路由决策次数
- **MVPP_MGC_PSO Routing Time (ticks)** - 路由计算总时间
- **MVPP_MGC_PSO Avg Routing Delay (ticks)** - 平均路由延迟
- **MVPP_MGC_PSO Routing Delay Std Dev** - 路由延迟标准差
- **MVPP_MGC_PSO Power Consumption (μW·s)** - 路由算法功耗

### 网络性能指标
- **Link Utilization** - 网络链路利用率（Top 10）

### 内存系统指标
- **Memory Bytes Read/Written** - 内存读写字节数
- **Memory Bandwidth (bytes/s)** - 内存带宽
- **Avg Memory Access Latency (cycles)** - 平均内存访问延迟

## 典型工作流程

### 场景1：单次实验数据收集

```bash
# 1. 运行测试
./run_tests.sh backprop

# 2. 查看CSV报告
cat build_logs/results_backprop_20251105_101723.csv

# 3. 导入Excel分析
# 直接在Excel中打开CSV文件
```

### 场景2：多次实验对比分析

```bash
# 1. 运行多次实验（修改参数后重复）
./run_tests.sh all    # 第一次实验
# [修改配置文件...]
./run_tests.sh all    # 第二次实验
# [修改配置文件...]
./run_tests.sh all    # 第三次实验

# 2. 生成对比报告
./compare_experiments.sh -o my_comparison.txt build_logs/

# 3. 或生成CSV格式对比
./compare_experiments.sh -f csv -o comparison_results.csv build_logs/

# 4. 分析结果
cat my_comparison.txt
```

### 场景3：历史数据批量处理

```bash
# 批量转换历史stats.txt文件为CSV
for stats_file in /path/to/historical/stats*.txt; do
    python3 generate_results_csv.py "$stats_file"
done

# 生成汇总对比报告
./compare_experiments.sh -o historical_comparison.txt build_logs/
```

## Excel/数据分析集成

### 1. 打开CSV文件
- Excel: 文件 → 打开 → 选择CSV
- LibreOffice Calc: 文件 → 打开 → 选择CSV
- Python pandas: `pd.read_csv('results.csv')`

### 2. 推荐的可视化分析

```python
# Python示例：批量分析多个实验
import pandas as pd
import glob

# 读取所有CSV文件
csv_files = glob.glob('build_logs/results_*.csv')
data = []

for file in csv_files:
    df = pd.read_csv(file)
    # 提取关键指标
    metrics = df[df['Metric'].str.contains('MVPP_MGC_PSO')]
    data.append(metrics)

# 合并并可视化
combined = pd.concat(data)
combined.plot(kind='bar')
```

### 3. Excel公式示例

```excel
# 计算延迟改善百分比
=((B2-B3)/B2)*100

# 找出最优配置
=MIN(B2:B10)

# 平均性能
=AVERAGE(B2:B10)
```

## 高级功能

### 1. 自定义指标提取

编辑 `generate_results_csv.py` 添加新指标：

```python
# 在 generate_csv() 方法中添加：
rows.append(['Custom Metric Name',
             self.parser.get_stat('system.your.custom.stat.name')])
```

### 2. 自动化批量测试

创建自动化脚本：

```bash
#!/bin/bash
# auto_test_suite.sh - 自动化测试套件

configs=("config1" "config2" "config3")

for config in "${configs[@]}"; do
    echo "Running experiment with $config"

    # 修改配置
    sed -i "s/current_config/$config/" gem5/configs/my_config.py

    # 运行测试
    ./run_tests.sh all

    # 生成专门的报告
    latest_csv=$(ls -t build_logs/results_*.csv | head -1)
    cp "$latest_csv" "results_${config}.csv"
done

# 生成最终对比报告
./compare_experiments.sh -o final_comparison.txt build_logs/
```

## 文件命名约定

所有自动生成的文件使用统一的时间戳格式：

```
<类型>_<测试名>_<YYYYMMDD>_<HHMMSS>.<扩展名>

示例：
- results_backprop_20251105_101723.csv
- stats_kmeans_20251105_104146.txt
- test_backprop_20251105_101723.log
```

## 常见问题排查

### Q1: CSV文件未生成

**检查点：**
```bash
# 1. 确认测试成功完成
echo $?  # 应该返回0

# 2. 检查stats.txt是否存在
ssh siat@192.168.197.130 "ls -lh /home/siat/test/stats.txt"

# 3. 手动测试CSV生成
python3 generate_results_csv.py build_logs/stats_test.txt
```

### Q2: Python脚本报错

```bash
# 检查Python版本
python3 --version  # 应该是3.x

# 测试CSV模块
python3 -c "import csv; print('CSV module OK')"
```

### Q3: 对比报告为空

```bash
# 检查CSV文件存在
ls -lh build_logs/results_*.csv

# 确认CSV格式正确
head -5 build_logs/results_*.csv
```

## 性能优化建议

1. **定期清理旧文件** - CSV和stats文件会累积，建议定期备份并清理
2. **使用专门的结果目录** - 重要实验结果应移至专门目录保存
3. **版本控制** - CSV文件不建议提交到Git，应添加到.gitignore

## 项目集成建议

### .gitignore 配置

```gitignore
# 实验结果文件（不提交到Git）
build_logs/*.csv
build_logs/stats_*.txt
build_logs/test_*.log
comparison_report.txt
*.csv
*_autosave.dat
```

### 持续集成示例

```yaml
# .github/workflows/nightly_tests.yml
name: Nightly Performance Tests

on:
  schedule:
    - cron: '0 0 * * *'  # 每天午夜运行

jobs:
  performance_test:
    runs-on: self-hosted
    steps:
      - name: Run tests
        run: ./run_tests.sh all

      - name: Archive results
        run: |
          mkdir -p results_archive/$(date +%Y%m%d)
          cp build_logs/results_*.csv results_archive/$(date +%Y%m%d)/

      - name: Generate comparison
        run: ./compare_experiments.sh -o weekly_report.txt build_logs/
```

## 总结

通过该系统，您可以：

✅ **自动化** - 无需手动解析统计文件
✅ **标准化** - 统一的CSV格式便于对比
✅ **可视化** - 直接导入Excel进行图表分析
✅ **可追溯** - 时间戳命名保留完整历史记录
✅ **可扩展** - 易于添加自定义指标

这为MVPP_MGC_PSO路由算法的研究和优化提供了强大的数据支持系统。

## 相关文档

- `CSV_EXPORT_README.md` - 详细功能说明和API参考
- `REMOTE_BUILD_README.md` - 跨机器编译系统说明
- `CLAUDE.md` - 项目总体架构和开发指南

## 技术支持

如有问题，请检查：
1. 测试日志文件: `build_logs/test_*.log`
2. 编译日志文件: `build_logs/remote_build_*.log`
3. Python脚本输出
4. 对比工具输出

所有工具都提供详细的日志输出，便于问题诊断。
