#!/bin/bash

################################################################################
# run_tests.sh - 远程测试执行脚本
#
# 功能：在远程机器上运行gem5-gpu基准测试
# 用法：./run_tests.sh [backprop|kmeans|all]
# 作者：自动化脚本系统
# 日期：2025-11-04
################################################################################

# 配置参数
REMOTE_USER="siat"
REMOTE_HOST="192.168.157.128"
REMOTE_PASSWORD="123"  # 临时启用密码认证
PROJECT_DIR="/home/siat/gem5-gpu-bak"
GEM5_BINARY="${PROJECT_DIR}/gem5/build/X86_VI_hammer_GPU/gem5.opt"
TEST_OUTPUT_DIR="/home/siat/test"
LOG_DIR="${PROJECT_DIR}/build_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 创建日志目录
mkdir -p "${LOG_DIR}"

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

log_test() {
    echo -e "${CYAN}[TEST]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 显示使用说明
show_usage() {
    echo "用法: $0 [backprop|kmeans|all]"
    echo ""
    echo "参数说明:"
    echo "  backprop  - 运行backprop基准测试"
    echo "  kmeans    - 运行kmeans基准测试"
    echo "  all       - 运行所有测试"
    echo ""
    echo "示例:"
    echo "  $0 backprop"
    echo "  $0 kmeans"
    echo "  $0 all"
    exit 1
}

# 检查SSH连接
check_ssh_connection() {
    log_info "检查与远程机器 ${REMOTE_HOST} 的SSH连接..."

    # 尝试使用密钥认证
    if ssh -o BatchMode=yes -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} "echo 'SSH connection successful'" &>/dev/null; then
        log_success "SSH密钥认证成功"
        USE_SSH_KEY=true
        return 0
    else
        log_warning "SSH密钥认证失败，需要使用密码认证"
        USE_SSH_KEY=false

        # 检查是否安装了sshpass
        if ! command -v sshpass &> /dev/null; then
            log_error "未安装sshpass，无法进行密码认证"
            log_error "请安装sshpass: sudo apt-get install sshpass"
            log_error "或者配置SSH密钥认证: ./setup_ssh_key.sh"
            return 1
        fi
        return 0
    fi
}

# 检查远程gem5.opt是否存在
check_gem5_binary() {
    log_info "检查远程gem5.opt二进制文件..."

    if [ "$USE_SSH_KEY" = true ]; then
        ssh ${REMOTE_USER}@${REMOTE_HOST} "test -f ${GEM5_BINARY}"
    else
        sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no \
            ${REMOTE_USER}@${REMOTE_HOST} "test -f ${GEM5_BINARY}"
    fi

    if [ $? -eq 0 ]; then
        log_success "gem5.opt二进制文件存在"
        return 0
    else
        log_error "gem5.opt二进制文件不存在: ${GEM5_BINARY}"
        log_error "请先运行编译脚本: ./sync_and_build.sh"
        return 1
    fi
}

# 运行backprop测试
run_backprop_test() {
    log_test "开始运行backprop基准测试..."

    TEST_NAME="backprop"

    # 创建时间标签子目录
    TEST_RESULT_DIR="${LOG_DIR}/${TIMESTAMP}"
    mkdir -p "${TEST_RESULT_DIR}"
    log_info "实验结果目录: ${TEST_RESULT_DIR}"

    REMOTE_LOG="/tmp/gem5_test_${TEST_NAME}_${TIMESTAMP}.log"
    LOCAL_LOG="${TEST_RESULT_DIR}/test_${TEST_NAME}.log"

    # 测试命令（设置CUDA环境变量）
    TEST_CMD="export CUDAHOME=/usr/local/cuda/cuda && export PATH=\$PATH:/usr/local/cuda/cuda/bin && ${GEM5_BINARY} -d ${TEST_OUTPUT_DIR} \
        ${PROJECT_DIR}/gem5-gpu/configs/se_fusion.py \
        --garnet-network=flexible \
        -c ${PROJECT_DIR}/benchmarks/rodinia/backprop/gem5_fusion_backprop \
        -o \"16\""

    log_info "执行命令："
    log_info "  ${TEST_CMD}"

    # 执行远程测试
    if [ "$USE_SSH_KEY" = true ]; then
        ssh ${REMOTE_USER}@${REMOTE_HOST} "
            echo '========================================' > ${REMOTE_LOG}
            echo 'gem5-gpu backprop 测试日志' >> ${REMOTE_LOG}
            echo '时间: \$(date)' >> ${REMOTE_LOG}
            echo '机器: \$(hostname)' >> ${REMOTE_LOG}
            echo '========================================' >> ${REMOTE_LOG}
            echo '' >> ${REMOTE_LOG}
            echo '清理输出目录...' >> ${REMOTE_LOG}
            rm -rf ${TEST_OUTPUT_DIR}/*
            echo '执行测试命令...' >> ${REMOTE_LOG}
            ${TEST_CMD} 2>&1 | tee -a ${REMOTE_LOG}
            exit \${PIPESTATUS[0]}
        "
        TEST_RESULT=$?
    else
        sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "
            echo '========================================' > ${REMOTE_LOG}
            echo 'gem5-gpu backprop 测试日志' >> ${REMOTE_LOG}
            echo '时间: \$(date)' >> ${REMOTE_LOG}
            echo '机器: \$(hostname)' >> ${REMOTE_LOG}
            echo '========================================' >> ${REMOTE_LOG}
            echo '' >> ${REMOTE_LOG}
            echo '清理输出目录...' >> ${REMOTE_LOG}
            rm -rf ${TEST_OUTPUT_DIR}/*
            echo '执行测试命令...' >> ${REMOTE_LOG}
            ${TEST_CMD} 2>&1 | tee -a ${REMOTE_LOG}
            exit \${PIPESTATUS[0]}
        "
        TEST_RESULT=$?
    fi

    # 回传测试日志
    log_info "回传测试日志..."
    if [ "$USE_SSH_KEY" = true ]; then
        scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_LOG} "${LOCAL_LOG}"
    else
        sshpass -p "${REMOTE_PASSWORD}" scp -o StrictHostKeyChecking=no \
            ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_LOG} "${LOCAL_LOG}"
    fi

    # 回传stats.txt文件并生成CSV报告
    if [ $TEST_RESULT -eq 0 ]; then
        log_info "回传统计数据文件..."
        LOCAL_STATS="${TEST_RESULT_DIR}/stats_${TEST_NAME}.txt"
        if [ "$USE_SSH_KEY" = true ]; then
            scp ${REMOTE_USER}@${REMOTE_HOST}:${TEST_OUTPUT_DIR}/stats.txt "${LOCAL_STATS}" 2>/dev/null
        else
            sshpass -p "${REMOTE_PASSWORD}" scp -o StrictHostKeyChecking=no \
                ${REMOTE_USER}@${REMOTE_HOST}:${TEST_OUTPUT_DIR}/stats.txt "${LOCAL_STATS}" 2>/dev/null
        fi

        if [ -f "${LOCAL_STATS}" ]; then
            log_info "生成综合CSV报告（包含配置信息和所有链路统计）..."
            CSV_OUTPUT="${TEST_RESULT_DIR}/comprehensive_${TEST_NAME}.csv"
            python3 ${PROJECT_DIR}/generate_comprehensive_csv.py "${LOCAL_STATS}" "${CSV_OUTPUT}" "${TEST_NAME}" 2>&1 | tee -a "${LOCAL_LOG}"

            if [ -f "${CSV_OUTPUT}" ]; then
                log_success "综合CSV报告已生成: ${CSV_OUTPUT}"
            else
                log_warning "综合CSV报告生成失败"
            fi
        else
            log_warning "统计数据文件不存在，跳过CSV生成"
        fi
    fi

    if [ $TEST_RESULT -eq 0 ]; then
        log_success "backprop测试完成"
        log_info "实验结果目录: ${TEST_RESULT_DIR}"
        log_info "  - 测试日志: ${LOCAL_LOG}"
        log_info "  - 统计数据: ${TEST_RESULT_DIR}/stats_${TEST_NAME}.txt"
        log_info "  - CSV报告: ${TEST_RESULT_DIR}/comprehensive_${TEST_NAME}.csv"
        return 0
    else
        log_error "backprop测试失败！退出码: ${TEST_RESULT}"
        log_error "请检查日志: ${LOCAL_LOG}"
        return 1
    fi
}

# 运行kmeans测试
run_kmeans_test() {
    log_test "开始运行kmeans基准测试..."

    TEST_NAME="kmeans"

    # 创建时间标签子目录
    TEST_RESULT_DIR="${LOG_DIR}/${TIMESTAMP}"
    mkdir -p "${TEST_RESULT_DIR}"
    log_info "实验结果目录: ${TEST_RESULT_DIR}"

    REMOTE_LOG="/tmp/gem5_test_${TEST_NAME}_${TIMESTAMP}.log"
    LOCAL_LOG="${TEST_RESULT_DIR}/test_${TEST_NAME}.log"

    # 测试命令（设置CUDA环境变量）
    TEST_CMD="export CUDAHOME=/usr/local/cuda/cuda && export PATH=\$PATH:/usr/local/cuda/cuda/bin && ${GEM5_BINARY} -d ${TEST_OUTPUT_DIR} \
        ${PROJECT_DIR}/gem5-gpu/configs/se_fusion.py \
        --garnet-network=flexible \
        -c ${PROJECT_DIR}/benchmarks/rodinia/kmeans/gem5_fusion_kmeans \
        -o \"-i /home/siat/Downloads/kmeans_input.txt\""

    log_info "执行命令："
    log_info "  ${TEST_CMD}"

    # 执行远程测试
    if [ "$USE_SSH_KEY" = true ]; then
        ssh ${REMOTE_USER}@${REMOTE_HOST} "
            echo '========================================' > ${REMOTE_LOG}
            echo 'gem5-gpu kmeans 测试日志' >> ${REMOTE_LOG}
            echo '时间: \$(date)' >> ${REMOTE_LOG}
            echo '机器: \$(hostname)' >> ${REMOTE_LOG}
            echo '========================================' >> ${REMOTE_LOG}
            echo '' >> ${REMOTE_LOG}
            echo '清理输出目录...' >> ${REMOTE_LOG}
            rm -rf ${TEST_OUTPUT_DIR}/*
            echo '执行测试命令...' >> ${REMOTE_LOG}
            ${TEST_CMD} 2>&1 | tee -a ${REMOTE_LOG}
            exit \${PIPESTATUS[0]}
        "
        TEST_RESULT=$?
    else
        sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "
            echo '========================================' > ${REMOTE_LOG}
            echo 'gem5-gpu kmeans 测试日志' >> ${REMOTE_LOG}
            echo '时间: \$(date)' >> ${REMOTE_LOG}
            echo '机器: \$(hostname)' >> ${REMOTE_LOG}
            echo '========================================' >> ${REMOTE_LOG}
            echo '' >> ${REMOTE_LOG}
            echo '清理输出目录...' >> ${REMOTE_LOG}
            rm -rf ${TEST_OUTPUT_DIR}/*
            echo '执行测试命令...' >> ${REMOTE_LOG}
            ${TEST_CMD} 2>&1 | tee -a ${REMOTE_LOG}
            exit \${PIPESTATUS[0]}
        "
        TEST_RESULT=$?
    fi

    # 回传测试日志
    log_info "回传测试日志..."
    if [ "$USE_SSH_KEY" = true ]; then
        scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_LOG} "${LOCAL_LOG}"
    else
        sshpass -p "${REMOTE_PASSWORD}" scp -o StrictHostKeyChecking=no \
            ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_LOG} "${LOCAL_LOG}"
    fi

    # 回传stats.txt文件并生成CSV报告
    if [ $TEST_RESULT -eq 0 ]; then
        log_info "回传统计数据文件..."
        LOCAL_STATS="${TEST_RESULT_DIR}/stats_${TEST_NAME}.txt"
        if [ "$USE_SSH_KEY" = true ]; then
            scp ${REMOTE_USER}@${REMOTE_HOST}:${TEST_OUTPUT_DIR}/stats.txt "${LOCAL_STATS}" 2>/dev/null
        else
            sshpass -p "${REMOTE_PASSWORD}" scp -o StrictHostKeyChecking=no \
                ${REMOTE_USER}@${REMOTE_HOST}:${TEST_OUTPUT_DIR}/stats.txt "${LOCAL_STATS}" 2>/dev/null
        fi

        if [ -f "${LOCAL_STATS}" ]; then
            log_info "生成综合CSV报告（包含配置信息和所有链路统计）..."
            CSV_OUTPUT="${TEST_RESULT_DIR}/comprehensive_${TEST_NAME}.csv"
            python3 ${PROJECT_DIR}/generate_comprehensive_csv.py "${LOCAL_STATS}" "${CSV_OUTPUT}" "${TEST_NAME}" 2>&1 | tee -a "${LOCAL_LOG}"

            if [ -f "${CSV_OUTPUT}" ]; then
                log_success "综合CSV报告已生成: ${CSV_OUTPUT}"
            else
                log_warning "综合CSV报告生成失败"
            fi
        else
            log_warning "统计数据文件不存在，跳过CSV生成"
        fi
    fi

    if [ $TEST_RESULT -eq 0 ]; then
        log_success "kmeans测试完成"
        log_info "实验结果目录: ${TEST_RESULT_DIR}"
        log_info "  - 测试日志: ${LOCAL_LOG}"
        log_info "  - 统计数据: ${TEST_RESULT_DIR}/stats_${TEST_NAME}.txt"
        log_info "  - CSV报告: ${TEST_RESULT_DIR}/comprehensive_${TEST_NAME}.csv"
        return 0
    else
        log_error "kmeans测试失败！退出码: ${TEST_RESULT}"
        log_error "请检查日志: ${LOCAL_LOG}"
        return 1
    fi
}

# 主函数
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        log_error "缺少参数"
        show_usage
    fi

    TEST_TYPE=$1

    echo "========================================"
    echo "gem5-gpu 远程测试执行脚本"
    echo "========================================"
    echo ""

    log_info "测试类型: ${TEST_TYPE}"

    # 步骤1: 检查SSH连接
    if ! check_ssh_connection; then
        log_error "SSH连接检查失败，终止执行"
        exit 1
    fi

    # 步骤2: 检查gem5.opt
    if ! check_gem5_binary; then
        log_error "gem5.opt检查失败，终止执行"
        exit 1
    fi

    # 步骤3: 根据参数运行测试
    TESTS_PASSED=0
    TESTS_FAILED=0

    case ${TEST_TYPE} in
        backprop)
            if run_backprop_test; then
                ((TESTS_PASSED++))
            else
                ((TESTS_FAILED++))
            fi
            ;;
        kmeans)
            if run_kmeans_test; then
                ((TESTS_PASSED++))
            else
                ((TESTS_FAILED++))
            fi
            ;;
        all)
            log_info "运行所有测试..."
            echo ""

            if run_backprop_test; then
                ((TESTS_PASSED++))
            else
                ((TESTS_FAILED++))
            fi

            echo ""
            echo "----------------------------------------"
            echo ""

            if run_kmeans_test; then
                ((TESTS_PASSED++))
            else
                ((TESTS_FAILED++))
            fi
            ;;
        *)
            log_error "未知的测试类型: ${TEST_TYPE}"
            show_usage
            ;;
    esac

    # 测试结果汇总
    echo ""
    echo "========================================"
    echo "测试结果汇总"
    echo "========================================"
    log_info "通过的测试: ${TESTS_PASSED}"
    log_info "失败的测试: ${TESTS_FAILED}"
    log_info "实验结果目录: ${LOG_DIR}/${TIMESTAMP}/"
    echo "========================================"

    if [ ${TESTS_FAILED} -eq 0 ]; then
        log_success "所有测试通过！"
        echo ""
        log_info "查看实验结果:"
        log_info "  cd ${LOG_DIR}/${TIMESTAMP}"
        log_info "  ls -lh"
        exit 0
    else
        log_error "部分测试失败"
        log_info "请检查实验结果目录: ${LOG_DIR}/${TIMESTAMP}/"
        exit 1
    fi
}

# 执行主函数
main "$@"
