#!/bin/bash

################################################################################
# compare_experiments.sh - 实验结果对比分析工具
#
# 功能：批量读取CSV文件并生成对比报告
# 作者：自动化脚本系统
# 日期：2025-11-05
################################################################################

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_header() {
    echo -e "${CYAN}[HEADER]${NC} $1"
}

# 提取CSV中的指标值
get_csv_value() {
    local csv_file=$1
    local metric_name=$2
    local value=$(grep "^${metric_name}," "$csv_file" | cut -d',' -f2)
    echo "$value"
}

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项] <CSV文件目录>

选项:
    -h, --help          显示此帮助信息
    -o, --output FILE   指定输出对比报告文件名（默认：comparison_report.txt）
    -f, --format TYPE   输出格式：text（默认）或 csv

示例:
    $0 build_logs/                          # 对比build_logs目录下的所有CSV文件
    $0 -o my_report.txt build_logs/         # 指定输出文件名
    $0 -f csv -o comparison.csv build_logs/ # 输出为CSV格式

EOF
    exit 0
}

# 生成文本格式报告
generate_text_report() {
    local csv_files=("$@")
    local output_file="${OUTPUT_FILE:-comparison_report.txt}"

    {
        echo "========================================"
        echo "gem5-gpu MVPP_MGC_PSO 实验结果对比报告"
        echo "========================================"
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "对比实验数量: ${#csv_files[@]}"
        echo ""

        # 表头
        printf "%-35s | %-15s | %-15s | %-18s | %-18s | %-20s\n" \
               "实验名称" "仿真时间(s)" "路由次数" "平均延迟(ticks)" "功耗(μW·s)" "内存带宽(B/s)"
        printf "%-35s-+-%-15s-+-%-15s-+-%-18s-+-%-18s-+-%-20s\n" \
               "-----------------------------------" \
               "---------------" \
               "---------------" \
               "------------------" \
               "------------------" \
               "--------------------"

        # 数据行
        for csv_file in "${csv_files[@]}"; do
            local base_name=$(basename "$csv_file" .csv)
            local test_name=$(get_csv_value "$csv_file" "Test Name")
            local timestamp=$(get_csv_value "$csv_file" "Timestamp")

            # 如果test_name为空，使用文件名
            if [ -z "$test_name" ] || [ "$test_name" == "N/A" ]; then
                test_name=$(echo "$base_name" | sed 's/results_//' | sed 's/_[0-9]\{8\}_[0-9]\{6\}//')
            fi

            local exp_name="${test_name}_${timestamp}"
            local sim_time=$(get_csv_value "$csv_file" "Simulation Time (seconds)")
            local routing_count=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Routing Count")
            local avg_delay=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Avg Routing Delay (ticks)")
            local power=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Power Consumption (μW·s)")
            local bandwidth=$(get_csv_value "$csv_file" "Memory Total Bandwidth (bytes/s)")

            printf "%-35s | %-15s | %-15s | %-18s | %-18s | %-20s\n" \
                   "$exp_name" "$sim_time" "$routing_count" "$avg_delay" "$power" "$bandwidth"
        done

        echo ""
        echo "========================================"
        echo "详细统计分析"
        echo "========================================"
        echo ""

        # 计算平均值和范围
        local total_sim_time=0
        local total_routing_count=0
        local total_avg_delay=0
        local total_power=0
        local count=0

        for csv_file in "${csv_files[@]}"; do
            local sim_time=$(get_csv_value "$csv_file" "Simulation Time (seconds)")
            local routing_count=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Routing Count")
            local avg_delay=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Avg Routing Delay (ticks)")
            local power=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Power Consumption (μW·s)")

            if [ -n "$sim_time" ] && [ "$sim_time" != "N/A" ] && [[ "$sim_time" =~ ^[0-9.]+$ ]]; then
                total_sim_time=$(awk "BEGIN {print $total_sim_time + $sim_time}")
            fi
            if [ -n "$routing_count" ] && [ "$routing_count" != "N/A" ] && [[ "$routing_count" =~ ^[0-9]+$ ]]; then
                total_routing_count=$((total_routing_count + routing_count))
            fi
            if [ -n "$avg_delay" ] && [ "$avg_delay" != "N/A" ] && [[ "$avg_delay" =~ ^[0-9.]+$ ]]; then
                total_avg_delay=$(awk "BEGIN {print $total_avg_delay + $avg_delay}")
            fi
            if [ -n "$power" ] && [ "$power" != "N/A" ] && [[ "$power" =~ ^[0-9.]+$ ]]; then
                total_power=$(awk "BEGIN {print $total_power + $power}")
            fi
            ((count++))
        done

        if [ $count -gt 0 ]; then
            local avg_sim_time=$(awk "BEGIN {printf \"%.6f\", $total_sim_time / $count}")
            local avg_routing_count=$((total_routing_count / count))
            local avg_avg_delay=$(awk "BEGIN {printf \"%.6f\", $total_avg_delay / $count}")
            local avg_power=$(awk "BEGIN {printf \"%.6f\", $total_power / $count}")

            echo "实验统计："
            echo "  - 总实验数量: $count"
            echo "  - 平均仿真时间: ${avg_sim_time} 秒"
            echo "  - 平均路由次数: $avg_routing_count"
            echo "  - 平均路由延迟: ${avg_avg_delay} ticks"
            echo "  - 平均功耗: ${avg_power} μW·s"
        fi

        echo ""
        echo "========================================"
        echo "报告生成完成"
        echo "========================================"

    } > "$output_file"

    log_success "对比报告已生成: $output_file"
}

# 生成CSV格式报告
generate_csv_report() {
    local csv_files=("$@")
    local output_file="${OUTPUT_FILE:-comparison_report.csv}"

    {
        # CSV表头
        echo "实验名称,时间戳,测试类型,仿真时间(s),路由次数,平均延迟(ticks),延迟标准差,功耗(μW·s),内存带宽(B/s),内存延迟(cycles)"

        # 数据行
        for csv_file in "${csv_files[@]}"; do
            local test_name=$(get_csv_value "$csv_file" "Test Name")
            local timestamp=$(get_csv_value "$csv_file" "Timestamp")
            local sim_time=$(get_csv_value "$csv_file" "Simulation Time (seconds)")
            local routing_count=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Routing Count")
            local avg_delay=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Avg Routing Delay (ticks)")
            local delay_stdev=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Routing Delay Std Dev (ticks)")
            local power=$(get_csv_value "$csv_file" "MVPP_MGC_PSO Power Consumption (μW·s)")
            local bandwidth=$(get_csv_value "$csv_file" "Memory Total Bandwidth (bytes/s)")
            local mem_latency=$(get_csv_value "$csv_file" "Avg Memory Access Latency (cycles)")

            echo "$test_name,$timestamp,$test_name,$sim_time,$routing_count,$avg_delay,$delay_stdev,$power,$bandwidth,$mem_latency"
        done

    } > "$output_file"

    log_success "CSV对比报告已生成: $output_file"
}

# 主函数
main() {
    local csv_dir=""
    local format="text"
    OUTPUT_FILE=""

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            *)
                csv_dir="$1"
                shift
                ;;
        esac
    done

    if [ -z "$csv_dir" ]; then
        log_info "未指定CSV目录，使用默认目录: build_logs/"
        csv_dir="build_logs"
    fi

    if [ ! -d "$csv_dir" ]; then
        echo "错误：目录不存在: $csv_dir"
        exit 1
    fi

    # 查找所有CSV文件
    log_info "正在搜索CSV文件: $csv_dir"
    mapfile -t csv_files < <(find "$csv_dir" -name "results_*.csv" -type f | sort)

    if [ ${#csv_files[@]} -eq 0 ]; then
        echo "错误：在 $csv_dir 目录下未找到CSV文件"
        exit 1
    fi

    log_success "找到 ${#csv_files[@]} 个CSV文件"

    # 生成报告
    if [ "$format" == "csv" ]; then
        generate_csv_report "${csv_files[@]}"
    else
        generate_text_report "${csv_files[@]}"
    fi
}

# 执行主函数
main "$@"
