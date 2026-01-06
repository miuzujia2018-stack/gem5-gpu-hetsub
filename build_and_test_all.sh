#!/bin/bash

################################################################################
# build_and_test_all.sh - 一键编译和测试脚本
#
# 功能：自动完成代码同步、编译和测试的完整流程
# 作者：自动化脚本系统
# 日期：2025-11-04
# 更新：2025-12-18 - 添加全终端输出日志功能
################################################################################

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 创建主日志文件
LOG_DIR="${SCRIPT_DIR}/build_logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
MASTER_LOG="${LOG_DIR}/master_log_${TIMESTAMP}.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${MAGENTA}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项]

选项:
    -b, --build-only        只执行编译，不运行测试
    -t, --test-only         只运行测试，不编译 [backprop|kmeans|all]
    -a, --all               编译并运行所有测试（默认）
    -h, --help              显示此帮助信息

示例:
    $0                      # 编译并运行所有测试
    $0 -b                   # 只编译
    $0 -t backprop          # 只运行backprop测试
    $0 -t all               # 只运行所有测试
    $0 -a                   # 编译并运行所有测试

EOF
    exit 0
}

# 检查脚本是否存在
check_scripts() {
    local missing_scripts=()

    if [ ! -f "${SCRIPT_DIR}/sync_and_build.sh" ]; then
        missing_scripts+=("sync_and_build.sh")
    fi

    if [ ! -f "${SCRIPT_DIR}/run_tests.sh" ]; then
        missing_scripts+=("run_tests.sh")
    fi

    if [ ${#missing_scripts[@]} -gt 0 ]; then
        log_error "缺少必需的脚本文件："
        for script in "${missing_scripts[@]}"; do
            echo "  - ${script}"
        done
        exit 1
    fi

    # 检查脚本是否可执行
    if [ ! -x "${SCRIPT_DIR}/sync_and_build.sh" ]; then
        log_warning "sync_and_build.sh 不可执行，正在添加执行权限..."
        chmod +x "${SCRIPT_DIR}/sync_and_build.sh"
    fi

    if [ ! -x "${SCRIPT_DIR}/run_tests.sh" ]; then
        log_warning "run_tests.sh 不可执行，正在添加执行权限..."
        chmod +x "${SCRIPT_DIR}/run_tests.sh"
    fi

    log_success "所有必需的脚本文件检查完成"
}

# 执行编译
run_build() {
    log_step "步骤 1/2: 执行代码同步和编译"
    echo "========================================"

    "${SCRIPT_DIR}/sync_and_build.sh"
    BUILD_RESULT=$?

    echo ""
    if [ $BUILD_RESULT -eq 0 ]; then
        log_success "编译完成"
        return 0
    else
        log_error "编译失败，退出码: ${BUILD_RESULT}"
        return 1
    fi
}

# 执行测试
run_tests() {
    local test_type=$1

    log_step "步骤 2/2: 执行测试"
    echo "========================================"

    "${SCRIPT_DIR}/run_tests.sh" "${test_type}"
    TEST_RESULT=$?

    echo ""
    if [ $TEST_RESULT -eq 0 ]; then
        log_success "测试完成"
        return 0
    else
        log_error "测试失败，退出码: ${TEST_RESULT}"
        return 1
    fi
}

# 主函数
main() {
    local build_only=false
    local test_only=false
    local test_type="all"

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--build-only)
                build_only=true
                shift
                ;;
            -t|--test-only)
                test_only=true
                test_type="${2:-all}"
                shift 2
                ;;
            -a|--all)
                build_only=false
                test_only=false
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                log_error "未知参数: $1"
                show_usage
                ;;
        esac
    done

    echo "========================================"
    echo "gem5-gpu 一键编译和测试脚本"
    echo "========================================"
    echo ""

    # 检查脚本
    check_scripts
    echo ""

    local start_time=$(date +%s)

    # 根据参数执行相应操作
    if [ "$build_only" = true ]; then
        # 只编译
        log_info "模式: 只编译"
        if ! run_build; then
            exit 1
        fi
    elif [ "$test_only" = true ]; then
        # 只测试
        log_info "模式: 只测试 (${test_type})"
        if ! run_tests "${test_type}"; then
            exit 1
        fi
    else
        # 编译并测试
        log_info "模式: 编译并测试 (all)"
        echo ""

        if ! run_build; then
            log_error "编译失败，跳过测试"
            exit 1
        fi

        echo ""
        log_info "编译成功，继续执行测试..."
        sleep 2
        echo ""

        if ! run_tests "all"; then
            exit 1
        fi
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "========================================"
    log_success "所有任务执行完成！"
    echo "========================================"
    log_info "总耗时: ${duration} 秒 ($(($duration / 60)) 分钟)"
    echo ""
    log_info "日志文件位置: ${SCRIPT_DIR}/build_logs/"
    log_info "主日志文件: ${MASTER_LOG}"
    log_info "完整终端输出已保存到主日志文件"
    echo ""

    exit 0
}

# 执行主函数并捕获所有终端输出
# 使用 tee 同时输出到终端和日志文件，同时捕获 stdout 和 stderr
{
    echo "========================================"
    echo "📝 主日志文件: ${MASTER_LOG}"
    echo "📝 所有终端输出将同时保存到此文件"
    echo "========================================"
    echo ""

    main "$@" 2>&1
} | tee "${MASTER_LOG}"

# 保存主函数的退出码
EXIT_CODE=${PIPESTATUS[0]}

# 使用主函数的退出码退出脚本
exit ${EXIT_CODE}
