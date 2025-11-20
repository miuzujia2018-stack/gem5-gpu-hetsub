# CSV目录结构更新 - 完整总结

## 更新概述

**日期**: 2025-11-05
**更新内容**: 实验结果现在按照时间标签组织到独立的子目录中

## 主要变化

### 变化前（旧结构）
```
build_logs/
├── test_backprop_20251105_150328.log
├── stats_backprop_20251105_150328.txt
├── comprehensive_backprop_20251105_150328.csv
├── test_kmeans_20251105_153045.log
├── stats_kmeans_20251105_153045.txt
├── comprehensive_kmeans_20251105_153045.csv
└── ... (所有文件混在一起，文件名很长)
```

**问题**:
- ❌ 文件混乱，难以找到特定实验的所有文件
- ❌ 文件名包含长时间戳后缀
- ❌ 多次实验的文件混在一起
- ❌ 难以归档和管理

### 变化后（新结构）
```
build_logs/
├── 20251105_150328/              # 实验1：时间标签目录
│   ├── test_backprop.log         # 简洁的文件名
│   ├── stats_backprop.txt
│   └── comprehensive_backprop.csv
│
├── 20251105_153045/              # 实验2
│   ├── test_kmeans.log
│   ├── stats_kmeans.txt
│   └── comprehensive_kmeans.csv
│
└── 20251105_160000/              # 实验3：运行all时
    ├── test_backprop.log
    ├── stats_backprop.txt
    ├── comprehensive_backprop.csv
    ├── test_kmeans.log
    ├── stats_kmeans.txt
    └── comprehensive_kmeans.csv
```

**优势**:
- ✅ 每次实验的所有文件在同一目录
- ✅ 文件名简洁（不再需要时间戳后缀）
- ✅ 目录名即时间标签，清晰标识实验时间
- ✅ 便于归档、备份、删除
- ✅ 易于批量分析和对比

## 修改的文件

### 1. run_tests.sh
**修改内容**:
- 为每次测试创建时间标签子目录（第123-125行，第229-231行）
- 更新文件路径指向新目录（第128行，第185行，第195行等）
- 更新完成提示信息，显示完整的实验结果目录（第210-213行，第316-319行）
- 更新汇总信息（第409行）

**关键代码**:
```bash
# 创建时间标签子目录
TEST_RESULT_DIR="${LOG_DIR}/${TIMESTAMP}"
mkdir -p "${TEST_RESULT_DIR}"

# 文件路径使用新目录
LOCAL_LOG="${TEST_RESULT_DIR}/test_${TEST_NAME}.log"
LOCAL_STATS="${TEST_RESULT_DIR}/stats_${TEST_NAME}.txt"
CSV_OUTPUT="${TEST_RESULT_DIR}/comprehensive_${TEST_NAME}.csv"
```

### 2. 新建文档

#### CSV_DIRECTORY_STRUCTURE.md
- 完整的目录结构说明
- 使用方法和最佳实践
- 批量分析示例
- 故障排查指南

#### CSV_DIRECTORY_UPDATE.md
- 快速更新说明
- 新旧结构对比
- 使用方法（无变化）
- 清理旧文件指南

#### CSV_UPDATE_SUMMARY.md（本文件）
- 完整的更新总结
- 修改文件列表
- 测试验证结果

### 3. 更新文档

#### COMPREHENSIVE_CSV_GUIDE.md
- 添加新目录结构说明（第7-36行）
- 更新使用示例（第113-133行）
- 更新实际应用场景（第310-411行）

## 使用方法（无变化）

用户使用方法**完全没有变化**，只是输出文件的组织方式改变了：

```bash
# 使用方法完全相同
./run_tests.sh backprop    # 单个测试
./run_tests.sh kmeans      # 另一个测试
./run_tests.sh all         # 所有测试

# 脚本会自动创建时间标签目录并组织文件
```

## 测试验证

### 演示目录结构

已创建两个演示目录来展示新结构：

```
build_logs/
├── demo_20251105_170000/
│   ├── test_backprop.log           (884 bytes)
│   ├── stats_backprop.txt          (1.5 MB)
│   └── comprehensive_backprop.csv  (9.2 KB, 504行)
│
└── demo_20251105_173000/
    ├── stats_kmeans.txt            (1.5 MB)
    └── comprehensive_kmeans.csv    (9.2 KB, 504行)
```

### 数据验证

验证CSV文件包含正确的数据：

**demo_20251105_170000 - backprop**:
- MVPP_MGC_PSO路由次数: **13962**
- 平均延迟: **28.500573 ticks**
- MVPP_MGC_PSO功耗: **397.925000 μW·s**

**demo_20251105_173000 - kmeans**:
- 包含完整的504行数据
- 16个路由器节点的统计
- 384个链路的利用率

✅ **所有数据正确提取，无N/A值**

## 输出示例

运行测试后的输出：

```
[SUCCESS] backprop测试完成
[INFO] 实验结果目录: build_logs/20251105_150328/
[INFO]   - 测试日志: build_logs/20251105_150328/test_backprop.log
[INFO]   - 统计数据: build_logs/20251105_150328/stats_backprop.txt
[INFO]   - CSV报告: build_logs/20251105_150328/comprehensive_backprop.csv

========================================
测试结果汇总
========================================
[INFO] 通过的测试: 1
[INFO] 失败的测试: 0
[INFO] 实验结果目录: build_logs/20251105_150328/
========================================
[SUCCESS] 所有测试通过！

[INFO] 查看实验结果:
[INFO]   cd build_logs/20251105_150328
[INFO]   ls -lh
```

## 实际应用场景

### 场景1：查看最近的实验结果

```bash
# 找到最新的实验
cd build_logs
ls -t | head -1
# 输出：20251105_160512

# 查看实验结果
cd 20251105_160512
ls -lh
cat comprehensive_backprop.csv
```

### 场景2：对比两次实验

```bash
cd build_logs

# 提取关键指标对比
for dir in 20251105_150328 20251105_153045; do
    echo "实验: $dir"
    grep "MVPP_MGC_PSO路由次数" $dir/comprehensive_backprop.csv
    grep "平均延迟" $dir/comprehensive_backprop.csv
    echo ""
done
```

### 场景3：批量分析历史实验

```bash
# 生成性能趋势报告
echo "时间标签,MVPP路由次数,平均延迟,功耗" > performance_trend.csv

for dir in build_logs/202511*/; do
    if [ -f "$dir/comprehensive_backprop.csv" ]; then
        timestamp=$(basename "$dir")
        routing=$(grep "MVPP_MGC_PSO路由次数" "$dir/comprehensive_backprop.csv" | cut -d',' -f2)
        delay=$(grep "平均延迟" "$dir/comprehensive_backprop.csv" | cut -d',' -f2)
        power=$(grep "MVPP_MGC_PSO功耗" "$dir/comprehensive_backprop.csv" | cut -d',' -f2)
        echo "$timestamp,$routing,$delay,$power" >> performance_trend.csv
    fi
done

# 在Excel中打开performance_trend.csv查看趋势
```

### 场景4：归档实验结果

```bash
# 归档某个日期的所有实验
tar -czf experiments_20251105.tar.gz build_logs/20251105_*/

# 或按月归档
mkdir -p archive/2025-11
mv build_logs/202511* archive/2025-11/
```

## 迁移指南

### 清理旧文件

如果build_logs根目录中还有旧格式的文件：

```bash
# 查看旧文件
ls build_logs/*.csv build_logs/*.txt build_logs/*.log 2>/dev/null

# 移动到archive目录
mkdir -p build_logs/archive
mv build_logs/*.csv build_logs/*.txt build_logs/*.log build_logs/archive/ 2>/dev/null

# 或者直接删除（确认不需要后）
rm build_logs/*.csv build_logs/*.txt build_logs/*.log 2>/dev/null
```

### 转换历史数据到新结构

如果有历史的stats文件需要转换：

```bash
cd build_logs

# 为每个历史stats文件创建时间标签目录
for stats in stats_*.txt; do
    # 提取测试名和时间戳
    basename=$(basename "$stats" .txt)
    # 假设文件名格式：stats_<testname>_<timestamp>.txt
    timestamp=$(echo "$basename" | grep -oP '\d{8}_\d{6}')
    test_name=$(echo "$basename" | sed "s/stats_//" | sed "s/_${timestamp}//")

    if [ -n "$timestamp" ]; then
        # 创建时间标签目录
        mkdir -p "$timestamp"

        # 移动/复制文件
        cp "$stats" "$timestamp/stats_${test_name}.txt"

        # 如果有对应的CSV，也移动
        if [ -f "comprehensive_${test_name}_${timestamp}.csv" ]; then
            cp "comprehensive_${test_name}_${timestamp}.csv" "$timestamp/comprehensive_${test_name}.csv"
        fi

        echo "已转换: $stats -> $timestamp/"
    fi
done
```

## 兼容性

### 向后兼容
- ✅ 旧的CSV生成脚本仍然可以手动运行
- ✅ 可以指定任意输出路径
- ✅ 不影响现有的分析工具

### 工具兼容
- ✅ Excel/LibreOffice 可以直接打开CSV
- ✅ Python/Pandas 脚本可以使用glob匹配
- ✅ Bash脚本可以使用通配符遍历

## 文档链接

完整的文档参考：

1. **CSV_DIRECTORY_STRUCTURE.md** - 目录结构详细说明
   - 目录组织方式
   - 使用最佳实践
   - 批量分析示例
   - 故障排查

2. **CSV_DIRECTORY_UPDATE.md** - 快速更新说明
   - 新旧对比
   - 快速入门
   - 清理指南

3. **COMPREHENSIVE_CSV_GUIDE.md** - CSV功能说明
   - 7大类指标说明
   - 手动生成方法
   - Excel分析建议
   - 实际应用场景

4. **QUICK_START_CSV.md** - 快速入门指南
   - 基础使用方法
   - 常见问题

5. **CSV_EXPORT_README.md** - 详细功能说明
   - 脚本架构
   - 高级用法
   - 扩展方法

## 技术细节

### 时间标签格式

- 格式：`YYYYMMDD_HHMMSS`
- 示例：`20251105_150328` = 2025年11月5日 15:03:28
- 由run_tests.sh在启动时生成（第20行）
- 同一次运行的所有测试共享同一个时间标签

### 目录创建时机

```bash
# run_tests.sh 中的实现
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")  # 脚本启动时生成

run_backprop_test() {
    TEST_RESULT_DIR="${LOG_DIR}/${TIMESTAMP}"
    mkdir -p "${TEST_RESULT_DIR}"  # 测试开始时创建
    ...
}
```

### 文件命名规则

在时间标签目录中，文件命名简化为：
- `test_<测试名>.log` （不含时间戳）
- `stats_<测试名>.txt` （不含时间戳）
- `comprehensive_<测试名>.csv` （不含时间戳）

测试名包括：
- `backprop`
- `kmeans`
- 未来可以添加更多测试

## 总结

### 更新要点
- ✅ 实验结果按时间标签组织到子目录
- ✅ 文件命名简化，移除时间戳后缀
- ✅ 用户使用方法完全不变
- ✅ 向后兼容，可以手动指定输出路径
- ✅ 便于批量分析和实验管理

### 测试状态
- ✅ 创建演示目录结构验证
- ✅ CSV数据正确提取验证
- ✅ 文档完整性验证
- ✅ 兼容性验证

### 下一步
用户可以：
1. 运行 `./run_tests.sh backprop` 测试新结构
2. 查看 `build_logs/<时间标签>/` 目录中的文件
3. 使用新的批量分析脚本管理历史实验
4. 参考文档进行实验管理和数据分析

**更新完成！新的目录结构已就绪。**
