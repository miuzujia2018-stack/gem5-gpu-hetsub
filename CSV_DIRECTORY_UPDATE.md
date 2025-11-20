# CSV目录结构更新 - 快速说明

## 主要变化

**从现在开始，所有实验结果将按照时间标签组织到独立的子目录中。**

### 旧的目录结构（已弃用）
```
build_logs/
├── test_backprop_20251105_150328.log
├── stats_backprop_20251105_150328.txt
├── comprehensive_backprop_20251105_150328.csv
├── test_kmeans_20251105_153045.log
├── stats_kmeans_20251105_153045.txt
└── comprehensive_kmeans_20251105_153045.csv  (文件混在一起)
```

### 新的目录结构（当前）
```
build_logs/
├── 20251105_150328/           ← 时间标签目录
│   ├── test_backprop.log
│   ├── stats_backprop.txt
│   └── comprehensive_backprop.csv
└── 20251105_153045/           ← 另一次实验
    ├── test_kmeans.log
    ├── stats_kmeans.txt
    └── comprehensive_kmeans.csv
```

## 使用方法（无变化）

```bash
# 使用方法完全相同
./run_tests.sh backprop    # 单个测试
./run_tests.sh kmeans      # 另一个测试
./run_tests.sh all         # 所有测试

# 脚本会自动创建时间标签目录并组织文件
```

## 测试完成后的提示

```
[SUCCESS] backprop测试完成
[INFO] 实验结果目录: build_logs/20251105_150328/
[INFO]   - 测试日志: build_logs/20251105_150328/test_backprop.log
[INFO]   - 统计数据: build_logs/20251105_150328/stats_backprop.txt
[INFO]   - CSV报告: build_logs/20251105_150328/comprehensive_backprop.csv
```

## 查看实验结果

```bash
# 进入实验结果目录
cd build_logs/20251105_150328

# 查看所有文件
ls -lh

# 查看CSV报告
cat comprehensive_backprop.csv

# 或用Excel打开
# Windows: start comprehensive_backprop.csv
# Linux: libreoffice comprehensive_backprop.csv
```

## 批量分析实验

```bash
# 查看所有实验
ls -lt build_logs/

# 提取所有实验的关键指标
for dir in build_logs/202511*/; do
    echo "实验: $(basename $dir)"
    grep "MVPP_MGC_PSO路由次数" "$dir/comprehensive_*.csv"
done
```

## 优势

1. **清晰的实验归档** - 每次实验的所有文件都在同一个目录
2. **简洁的文件命名** - 不再需要时间戳后缀
3. **便于对比分析** - 轻松找到和对比不同时间的实验
4. **易于管理** - 归档、备份、删除都更方便

## 详细文档

- `CSV_DIRECTORY_STRUCTURE.md` - 完整的目录结构说明和最佳实践
- `COMPREHENSIVE_CSV_GUIDE.md` - CSV功能说明（已更新）
- `QUICK_START_CSV.md` - 快速入门指南

## 注意事项

- ⚠️ 如果在同一秒内运行多次测试，文件会被覆盖（正常情况下不会发生）
- ✅ 运行 `./run_tests.sh all` 时，同一个时间标签目录会包含backprop和kmeans的结果
- ✅ 旧的CSV文件（在build_logs根目录）不会被删除，可以手动清理

## 快速清理旧文件

```bash
# 查看build_logs根目录的旧文件
ls build_logs/*.csv build_logs/*.txt build_logs/*.log 2>/dev/null

# 如果确认不需要，可以删除
rm build_logs/*.csv build_logs/*.txt build_logs/*.log 2>/dev/null

# 或者移动到archive目录
mkdir -p build_logs/archive
mv build_logs/*.csv build_logs/*.txt build_logs/*.log build_logs/archive/ 2>/dev/null
```
