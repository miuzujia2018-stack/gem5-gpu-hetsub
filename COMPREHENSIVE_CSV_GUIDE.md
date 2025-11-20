# 全面CSV实验结果导出系统 - 功能说明

## 系统概述

全面CSV导出系统可以生成包含**完整配置信息**和**所有性能指标**的综合实验报告，一个CSV文件即可了解实验的所有关键信息。

**重要更新：** 从现在开始，所有实验结果将按照**时间标签**组织到独立的子目录中，便于管理和归档。详细说明请参考 `CSV_DIRECTORY_STRUCTURE.md`。

## 新的目录结构

```
build_logs/
├── 20251105_150000/           # 实验时间标签目录
│   ├── test_backprop.log      # 测试日志
│   ├── stats_backprop.txt     # 统计数据
│   └── comprehensive_backprop.csv  # 综合CSV报告
│
├── 20251105_153000/           # 另一次实验
│   ├── test_kmeans.log
│   ├── stats_kmeans.txt
│   └── comprehensive_kmeans.csv
│
└── 20251105_160000/           # 运行all时的结果
    ├── test_backprop.log
    ├── stats_backprop.txt
    ├── comprehensive_backprop.csv
    ├── test_kmeans.log
    ├── stats_kmeans.txt
    └── comprehensive_kmeans.csv
```

**优势：**
- ✅ 每次实验的所有文件都在同一个目录中
- ✅ 文件命名更简洁（不再需要时间戳后缀）
- ✅ 便于批量分析和对比实验
- ✅ 清晰的实验归档和备份

## 主要特性

### 1. 配置信息自动提取

CSV文件开头包含完整的实验配置：

```csv
========== 配置信息 ==========
报告生成时间,20251105_153705
测试名称,backprop

--- 系统配置 ---
仿真频率 (Hz),1000000000000
Ruby时钟周期 (ps),500
系统时钟周期 (ps),1000
电压 (V),1

--- 网络拓扑配置 ---
路由器节点数量,16
拓扑类型,Mesh 4x4 或更大
路由算法,MVPP_MGC_PSO (Multi-Vehicle Path Planning with Multi-Group Clustering PSO)
```

### 2. 全部链路利用率统计

不再只显示Top 10，而是**所有链路**的利用率：

```csv
========== 网络链路利用率（全部链路） ==========
路由器: system.ruby.network.ext_links00.int_node
  链路 0,18682
  链路 1,2096
  链路 2,21
  链路 3,0
  ... (所有24个链路)

路由器: system.ruby.network.ext_links01.int_node
  链路 0,924
  链路 1,808
  ... (所有24个链路)

... (所有16个路由器节点)
```

### 3. 完整的性能指标

包含7大类指标：

1. **配置信息** - 拓扑、规模、算法参数
2. **总体性能** - 仿真时间、指令数、执行速率
3. **路由算法性能** - MVPP_MGC_PSO详细统计
4. **网络链路** - 所有链路利用率
5. **内存系统** - 带宽、延迟、请求数
6. **功耗统计** - 各组件功耗
7. **Ruby内存** - CPU/GPU内存访问

### 4. 时间标签组织

实验结果按照时间标签组织到独立子目录，便于管理：

```
build_logs/
├── 20251105_150328/
│   └── comprehensive_backprop.csv
└── 20251105_153045/
    └── comprehensive_kmeans.csv
```

## 使用方法

### 自动生成（推荐）

运行测试时自动生成全面CSV，并组织到时间标签目录：

```bash
# 运行测试（自动生成综合CSV）
./run_tests.sh backprop

# 输出结构
build_logs/20251105_150328/
├── test_backprop.log
├── stats_backprop.txt
└── comprehensive_backprop.csv

# 运行所有测试
./run_tests.sh all

# 输出结构
build_logs/20251105_153045/
├── test_backprop.log
├── stats_backprop.txt
├── comprehensive_backprop.csv
├── test_kmeans.log
├── stats_kmeans.txt
└── comprehensive_kmeans.csv
```

### 手动生成

处理历史数据：

```bash
# 基本用法
python3 generate_comprehensive_csv.py <stats.txt> [output.csv] [test_name]

# 示例1：自动命名（生成到当前目录）
python3 generate_comprehensive_csv.py /home/siat/test/stats.txt

# 示例2：指定输出到时间标签目录
mkdir -p build_logs/20251105_150328
python3 generate_comprehensive_csv.py stats.txt \
    build_logs/20251105_150328/comprehensive_backprop.csv backprop

# 示例3：批量处理历史stats文件到新目录结构
for stats in build_logs/stats_*.txt; do
    # 从文件名提取测试名和时间戳（如果有）
    basename=$(basename "$stats" .txt)
    test_name=$(echo "$basename" | sed 's/stats_//' | sed 's/_[0-9]*$//')

    # 创建时间标签目录
    timestamp=$(date +"%Y%m%d_%H%M%S")
    result_dir="build_logs/${timestamp}"
    mkdir -p "$result_dir"

    # 生成CSV
    python3 generate_comprehensive_csv.py "$stats" \
        "$result_dir/comprehensive_${test_name}.csv" "$test_name"
done
```

## CSV结构说明

### 第一部分：配置信息 (15-20行)

- 报告生成时间
- 测试程序名称
- 系统配置（频率、时钟、电压）
- 网络拓扑（节点数、拓扑类型）
- 路由算法信息

### 第二部分：总体性能指标 (10行)

- 仿真时间和时钟周期
- 主机执行时间
- 指令/操作数统计
- 执行速率指标

### 第三部分：路由算法性能 (30行)

- 路由决策统计（MVPP vs 传统）
- 路由时间性能
- 延迟统计（平均值、标准差、几何平均）
- 功耗统计

### 第四部分：网络链路利用率 (380+行)

- **所有路由器节点**的链路利用率
- 每个节点24个链路
- 16个节点 × 24个链路 = 384行统计数据
- 可以看到每个链路的确切利用率

### 第五部分：内存系统性能 (20行)

- Memory Controller 0/1统计
- 读写字节数和请求数
- 带宽统计（读/写/总）
- 延迟统计

### 第六部分：功耗统计 (4-6行)

- 各Memory Controller Rank功耗

### 第七部分：Ruby内存系统 (8行)

- CPU/GPU内存访问统计

## 输出示例

```
正在解析统计文件: build_logs/stats_backprop_20251105_153705.txt
✅ 成功解析 10125 条统计数据
✅ 综合CSV报告生成成功: build_logs/comprehensive_backprop_20251105_153705.csv
   - 配置信息: 已包含
   - 路由器节点数: 16
   - 链路统计数: 384
   - 总行数: 504

结果摘要:
  - 仿真时间: 0.000573 秒
  - 测试程序: backprop
  - CSV输出: build_logs/comprehensive_backprop_20251105_153705.csv
```

## Excel分析建议

### 1. 打开CSV文件

直接在Excel中打开，数据会自动按两列显示：
- 列A：指标名称
- 列B：指标值

### 2. 链路利用率分析

```excel
# 筛选出链路利用率数据
1. 使用Excel筛选功能
2. 筛选包含"链路"的行
3. 创建柱状图查看利用率分布

# 计算统计量
=AVERAGE(B100:B484)  # 平均链路利用率
=MAX(B100:B484)      # 最大链路利用率
=COUNTIF(B100:B484,">1000")  # 高利用率链路数量
```

### 3. 多实验对比

```python
# Python pandas示例
import pandas as pd

# 读取多个CSV文件
df_backprop = pd.read_csv('comprehensive_backprop.csv', header=None)
df_kmeans = pd.read_csv('comprehensive_kmeans.csv', header=None)

# 提取特定指标对比
metrics = ['仿真时间', 'MVPP_MGC_PSO路由次数', '平均延迟']
comparison = {}
for metric in metrics:
    comparison[metric] = {
        'backprop': df_backprop[df_backprop[0]==metric][1].values[0],
        'kmeans': df_kmeans[df_kmeans[0]==metric][1].values[0]
    }

# 可视化对比
import matplotlib.pyplot as plt
# ... 绘图代码
```

### 4. 链路热力图

```python
# 提取所有链路利用率
import seaborn as sns

# 解析链路数据
link_utils = []
for router in range(16):
    router_links = []
    for link in range(24):
        # 从CSV提取数据
        router_links.append(utilization)
    link_utils.append(router_links)

# 绘制热力图
sns.heatmap(link_utils, annot=True, cmap='YlOrRd')
plt.title('Network Link Utilization Heatmap')
plt.xlabel('Link ID')
plt.ylabel('Router ID')
plt.show()
```

## 与原版CSV的对比

| 特性 | 原版CSV | 全面CSV |
|------|---------|---------|
| 配置信息 | ❌ 无 | ✅ 完整包含 |
| 链路统计 | ⚠️ Top 10 | ✅ 所有384个链路 |
| 总行数 | ~42行 | ~504行 |
| 文件大小 | ~1.4KB | ~25KB |
| 适用场景 | 快速查看 | 详细分析 |

## 实际应用场景

### 场景1：配置对比实验

```bash
# 实验1：默认配置
./run_tests.sh backprop
# 输出：build_logs/20251105_150328/comprehensive_backprop.csv

# 实验2：修改路由参数
# [修改配置文件...]
./run_tests.sh backprop
# 输出：build_logs/20251105_153045/comprehensive_backprop.csv

# 对比两个实验
cd build_logs

# 方法1：直接查看CSV
diff -u 20251105_150328/comprehensive_backprop.csv \
        20251105_153045/comprehensive_backprop.csv | less

# 方法2：提取关键指标对比
for dir in 20251105_*/; do
    echo "实验: $dir"
    grep "MVPP_MGC_PSO路由次数" "$dir/comprehensive_backprop.csv"
    grep "平均延迟" "$dir/comprehensive_backprop.csv"
    echo ""
done
```

### 场景2：不同测试程序分析

```bash
# 运行所有测试程序
./run_tests.sh all

# 生成目录结构：
# build_logs/20251105_153045/
#   ├── comprehensive_backprop.csv
#   └── comprehensive_kmeans.csv

# 在Excel中并排打开，对比：
cd build_logs/20251105_153045
# 1. 哪个程序链路利用率更高
# 2. 哪个程序MVPP路由次数更多
# 3. 哪个程序功耗更高

# 或使用Python分析
python3 << EOF
import pandas as pd
import glob

# 读取同一时间标签下的所有CSV
csv_files = glob.glob('*.csv')
for csv_file in csv_files:
    print(f"\\n=== {csv_file} ===")
    df = pd.read_csv(csv_file, header=None, names=['metric', 'value'])
    # 提取关键指标
    routing_count = df[df[0]=='MVPP_MGC_PSO路由次数'][1].values[0]
    print(f"路由次数: {routing_count}")
EOF
```

### 场景3：历史实验追踪

```bash
# 查看所有历史实验
ls -lt build_logs/

# 输出示例：
# drwxrwxr-x 2 siat siat 4096 Nov  5 16:05 20251105_160512/
# drwxrwxr-x 2 siat siat 4096 Nov  5 15:30 20251105_153045/
# drwxrwxr-x 2 siat siat 4096 Nov  5 15:03 20251105_150328/

# 查找特定时间范围的实验
find build_logs -type d -name "20251105_15*" | sort

# 批量提取关键指标
echo "时间标签,MVPP路由次数,平均延迟,功耗" > performance_history.csv
for dir in build_logs/202511*/; do
    if [ -f "$dir/comprehensive_backprop.csv" ]; then
        timestamp=$(basename "$dir")
        routing=$(grep "MVPP_MGC_PSO路由次数" "$dir/comprehensive_backprop.csv" | cut -d',' -f2)
        delay=$(grep "平均延迟" "$dir/comprehensive_backprop.csv" | cut -d',' -f2)
        power=$(grep "MVPP_MGC_PSO功耗" "$dir/comprehensive_backprop.csv" | cut -d',' -f2)
        echo "$timestamp,$routing,$delay,$power" >> performance_history.csv
    fi
done
```

### 场景4：拓扑规模分析

```csv
# CSV中自动显示拓扑规模
路由器节点数量,16
拓扑类型,Mesh 4x4 或更大

# 不同拓扑对比：
# - 2x2 Mesh: 4个节点, 96个链路
# - 4x4 Mesh: 16个节点, 384个链路
# - 8x8 Mesh: 64个节点, 1536个链路
```

## 性能开销

```
统计文件大小: 1.5MB
解析时间: <1秒
链路统计提取: ~16个节点 × 24个链路 = 384个链路
CSV生成时间: <0.2秒
总开销: 可忽略不计
```

## 故障排查

### 问题1：链路统计不完整

**症状**：某些路由器节点的链路统计缺失

**检查**：
```bash
# 检查stats.txt是否包含所有路由器
grep "link_utilization" /home/siat/test/stats.txt | wc -l

# 应该有多行输出（每个节点×每个链路）
```

### 问题2：CSV行数少于预期

**症状**：CSV文件只有几十行

**原因**：stats.txt文件不完整或仿真时间太短

**解决**：
```bash
# 检查stats.txt大小
ls -lh /home/siat/test/stats.txt

# 应该至少1MB以上
# 如果文件太小，可能仿真没有正常完成
```

### 问题3：配置信息显示N/A

**症状**：拓扑节点数或其他配置显示N/A

**原因**：stats.txt缺少相应统计项

**解决**：
- 确认使用正确的gem5配置
- 确认Ruby网络系统已启用
- 检查编译选项

## 总结

全面CSV导出系统提供：

✅ **配置信息自动提取** - 拓扑、规模、算法参数一目了然
✅ **所有链路统计** - 384个链路的完整利用率数据
✅ **7大类指标** - 504行详细性能数据
✅ **测试程序对比** - 不同benchmark性能一目了然
✅ **Excel友好** - 标准CSV格式，直接打开即可分析

这为MVPP_MGC_PSO路由算法的深入分析提供了完整的数据支持！

## 文件命名规则

```
comprehensive_<测试名>_<年月日>_<时分秒>.csv

示例：
comprehensive_backprop_20251105_153705.csv
comprehensive_kmeans_20251105_154200.csv
```

## 相关文档

- `QUICK_START_CSV.md` - 基础CSV功能快速入门
- `CSV_EXPORT_README.md` - 详细功能说明
- `IMPLEMENTATION_SUMMARY.md` - 系统实施总结
