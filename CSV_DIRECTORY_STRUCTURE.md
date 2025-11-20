# CSV实验结果目录结构说明

## 新的目录组织方式

从现在开始，所有实验结果将按照**时间标签**组织到独立的子目录中，便于管理和归档。

## 目录结构

```
build_logs/
├── 20251105_150000/           # 第一次实验（时间标签）
│   ├── test_backprop.log      # backprop测试日志
│   ├── stats_backprop.txt     # backprop统计数据（从远程机器回传）
│   └── comprehensive_backprop.csv  # backprop综合CSV报告
│
├── 20251105_153000/           # 第二次实验
│   ├── test_kmeans.log
│   ├── stats_kmeans.txt
│   └── comprehensive_kmeans.csv
│
├── 20251105_160000/           # 第三次实验（运行all，包含两个测试）
│   ├── test_backprop.log
│   ├── stats_backprop.txt
│   ├── comprehensive_backprop.csv
│   ├── test_kmeans.log
│   ├── stats_kmeans.txt
│   └── comprehensive_kmeans.csv
│
└── sync_build_YYYYMMDD_HHMMSS.log  # 编译日志（仍在build_logs根目录）
```

## 使用方法

### 1. 运行单个测试

```bash
./run_tests.sh backprop
```

**输出结构：**
```
build_logs/20251105_150328/
├── test_backprop.log
├── stats_backprop.txt
└── comprehensive_backprop.csv
```

### 2. 运行所有测试

```bash
./run_tests.sh all
```

**输出结构：**
```
build_logs/20251105_153045/
├── test_backprop.log
├── stats_backprop.txt
├── comprehensive_backprop.csv
├── test_kmeans.log
├── stats_kmeans.txt
└── comprehensive_kmeans.csv
```

### 3. 查看实验结果

测试完成后，脚本会自动提示实验结果目录：

```
[INFO] 2025-11-05 15:03:45 - 实验结果目录: build_logs/20251105_150328/
[INFO] 2025-11-05 15:03:45 -   - 测试日志: build_logs/20251105_150328/test_backprop.log
[INFO] 2025-11-05 15:03:45 -   - 统计数据: build_logs/20251105_150328/stats_backprop.txt
[INFO] 2025-11-05 15:03:45 -   - CSV报告: build_logs/20251105_150328/comprehensive_backprop.csv
```

快速查看：
```bash
cd build_logs/20251105_150328
ls -lh
```

## 优势

### 1. 清晰的实验归档
每次实验的所有相关文件都在同一个时间标签目录中，便于：
- 找到特定时间的实验结果
- 对比不同时间的实验数据
- 归档和备份实验结果

### 2. 避免文件混乱
不再是：
```
build_logs/
├── test_backprop_20251105_150328.log
├── test_backprop_20251105_153045.log
├── test_kmeans_20251105_150500.log
├── stats_backprop_20251105_150328.txt
├── comprehensive_backprop_20251105_150328.csv
├── comprehensive_kmeans_20251105_150500.csv
└── ... (文件混在一起)
```

而是：
```
build_logs/
├── 20251105_150328/  # 第一次实验的所有文件
├── 20251105_153045/  # 第二次实验的所有文件
└── 20251105_150500/  # 第三次实验的所有文件
```

### 3. 便于批量分析
对比多次实验：
```bash
# 对比两次backprop实验
python3 compare_experiments.sh \
    build_logs/20251105_150328/comprehensive_backprop.csv \
    build_logs/20251105_153045/comprehensive_backprop.csv

# 批量提取所有实验的关键指标
for dir in build_logs/202511*/; do
    echo "实验: $(basename $dir)"
    grep "MVPP_MGC_PSO路由次数" "$dir/comprehensive_*.csv"
done
```

### 4. 文件命名简化
由于目录名已包含时间标签，文件名可以更简洁：
- `test_backprop.log` 而不是 `test_backprop_20251105_150328.log`
- `comprehensive_backprop.csv` 而不是 `comprehensive_backprop_20251105_150328.csv`

## 时间标签格式

时间标签格式：`YYYYMMDD_HHMMSS`

示例：
- `20251105_150328` = 2025年11月5日 15:03:28
- `20251105_153045` = 2025年11月5日 15:30:45
- `20251105_160512` = 2025年11月5日 16:05:12

## 实验管理最佳实践

### 1. 每次重要修改后运行完整测试

```bash
# 修改代码后
./build_and_test_all.sh

# 会自动创建新的时间标签目录
# build_logs/20251105_160512/
```

### 2. 给重要实验添加说明文件

```bash
# 在实验目录中创建README
cd build_logs/20251105_160512
cat > README.txt <<EOF
实验说明:
- 修改内容: 优化PSO算法参数
- 修改文件: Router.cc, PSOAlgorithm.cc
- 预期效果: 降低路由延迟10%
- 实际结果: 延迟降低8.5%
EOF
```

### 3. 归档历史实验

```bash
# 归档旧的实验结果
mkdir -p archive/2025_Q4
mv build_logs/202511* archive/2025_Q4/

# 或者压缩归档
tar -czf experiments_202511.tar.gz build_logs/202511*
```

### 4. 快速定位最新实验

```bash
# 最新的实验目录
ls -td build_logs/202511*/ | head -1

# 查看最新实验的CSV
cat $(ls -t build_logs/202511*/comprehensive_*.csv | head -1)
```

## 与其他工具的兼容性

### Excel/LibreOffice
直接打开CSV文件：
```bash
# Windows
start build_logs/20251105_160512/comprehensive_backprop.csv

# Linux
libreoffice build_logs/20251105_160512/comprehensive_backprop.csv
```

### Python/Pandas
```python
import pandas as pd
import glob

# 读取单个实验
df = pd.read_csv('build_logs/20251105_160512/comprehensive_backprop.csv',
                 header=None, names=['metric', 'value'])

# 批量读取所有实验
csv_files = glob.glob('build_logs/202511*/comprehensive_backprop.csv')
experiments = []
for csv_file in csv_files:
    timestamp = csv_file.split('/')[1]  # 提取时间标签
    df = pd.read_csv(csv_file, header=None, names=['metric', 'value'])
    df['timestamp'] = timestamp
    experiments.append(df)

# 合并所有实验数据
all_data = pd.concat(experiments, ignore_index=True)
```

### Bash脚本
```bash
#!/bin/bash
# 自动提取所有实验的关键指标

echo "时间标签,MVPP路由次数,平均延迟,功耗"
for dir in build_logs/202511*/; do
    timestamp=$(basename "$dir")
    csv_file="$dir/comprehensive_backprop.csv"

    if [ -f "$csv_file" ]; then
        routing_count=$(grep "MVPP_MGC_PSO路由次数" "$csv_file" | cut -d',' -f2)
        avg_delay=$(grep "平均延迟" "$csv_file" | cut -d',' -f2)
        power=$(grep "MVPP_MGC_PSO功耗" "$csv_file" | cut -d',' -f2)

        echo "$timestamp,$routing_count,$avg_delay,$power"
    fi
done
```

## 故障排查

### 问题1：目录创建失败
**症状：** 提示"Permission denied"

**解决：**
```bash
chmod +w build_logs/
```

### 问题2：找不到实验结果
**症状：** 运行测试后找不到CSV文件

**检查：**
```bash
# 查看最新创建的目录
ls -lt build_logs/ | head -5

# 查看目录内容
ls -lh build_logs/$(ls -t build_logs/ | head -1)/
```

### 问题3：时间标签重复
**症状：** 同一个时间标签目录包含多次实验的文件

**原因：** 在同一秒内运行了多次测试

**解决：**
- 正常情况：如果运行 `./run_tests.sh all`，同一个目录会包含backprop和kmeans的结果
- 如果不希望覆盖，等待至少1秒后再运行下一次测试

## 总结

新的目录结构提供了：
- ✅ **清晰的实验归档** - 每个时间点的完整实验结果
- ✅ **简洁的文件命名** - 不再需要长长的时间戳后缀
- ✅ **便于批量分析** - 轻松对比多次实验
- ✅ **灵活的管理方式** - 归档、备份、分享更方便

这个结构设计符合实验室和工业界的最佳实践，让您的MVPP_MGC_PSO路由算法研究更加高效！
