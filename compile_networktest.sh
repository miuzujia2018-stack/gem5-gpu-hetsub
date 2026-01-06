#!/bin/bash

################################################################################
# compile_networktest.sh - Network_test 协议编译脚本（支持跨机器编译）
#
# 功能：编译gem5 Network_test协议（用于综合流量测试）
# 支持：本地编译 和 远程编译（192.168.157.128）
# 作者：Phase 4 验证自动化系统
# 日期：2025-12-18
################################################################################

# 配置参数
REMOTE_USER="siat"
REMOTE_HOST="192.168.157.128"
REMOTE_PASSWORD="123"
LOCAL_PROJECT_DIR="/home/siat/gem5-gpu-bak"
REMOTE_PROJECT_DIR="/home/siat/gem5-gpu-bak"
LOG_DIR="${LOCAL_PROJECT_DIR}/build_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOCAL_LOG="${LOG_DIR}/networktest_build_${TIMESTAMP}.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# 创建日志目录
mkdir -p "${LOG_DIR}"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOCAL_LOG}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOCAL_LOG}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOCAL_LOG}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOCAL_LOG}"
}

log_step() {
    echo -e "${MAGENTA}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "${LOCAL_LOG}"
}

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 [选项]

选项:
    -l, --local         本地编译（在当前机器上编译，-j8）
    -r, --remote        远程编译（在192.168.157.128上编译，-j64，默认）
    -h, --help          显示此帮助信息

示例:
    $0                  # 远程编译（默认，推荐）
    $0 -r               # 远程编译（-j64，更快）
    $0 -l               # 本地编译（-j8，较慢）

说明:
    远程编译优势：
    - 8倍编译并行度（-j64 vs -j8）
    - 3-5分钟编译时间 vs 15-25分钟
    - 分离开发和编译环境

EOF
    exit 0
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
        log_warning "SSH密钥认证失败，尝试使用密码认证"
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

# 同步代码到远程机器
sync_code() {
    log_step "步骤 1/2: 同步代码到远程机器"
    log_info "本地目录: ${LOCAL_PROJECT_DIR}"
    log_info "远程目录: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PROJECT_DIR}"

    # rsync参数
    RSYNC_OPTS="-avzh --progress"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='build/' --exclude='.git/' --exclude='*.pyc'"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='*.o' --exclude='*.a' --exclude='build_logs/'"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='m5out/' --exclude='*.swp'"

    # 只同步必要的源代码文件
    SYNC_FILES=(
        "gem5/src/cpu/testers/networktest/"
        "gem5/src/mem/ruby/network/garnet/flexible-pipeline/"
        "gem5/configs/example/ruby_network_test.py"
        "gem5/configs/ruby/Network_test.py"
        "gem5/SConstruct"
        "gem5/build_opts/"
        "gpgpu-sim/SConscript"
        "gpgpu-sim/cuda-sim/SConscript"
        "gpgpu-sim/gpgpu-sim/SConscript"
        "gpgpu-sim/intersim2/SConscript"
        "gem5-gpu/src/gpu/SConscript"
        "gem5-gpu/src/api/SConscript"
        "gem5-gpu/src/gpu/gpgpu-sim/SConscript"
    )

    if [ "$USE_SSH_KEY" = true ]; then
        for file in "${SYNC_FILES[@]}"; do
            rsync ${RSYNC_OPTS} "${LOCAL_PROJECT_DIR}/${file}" \
                ${REMOTE_USER}@${REMOTE_HOST}:"${REMOTE_PROJECT_DIR}/${file}" 2>&1 | tee -a "${LOCAL_LOG}"
        done
    else
        for file in "${SYNC_FILES[@]}"; do
            sshpass -p "${REMOTE_PASSWORD}" rsync ${RSYNC_OPTS} "${LOCAL_PROJECT_DIR}/${file}" \
                ${REMOTE_USER}@${REMOTE_HOST}:"${REMOTE_PROJECT_DIR}/${file}" 2>&1 | tee -a "${LOCAL_LOG}"
        done
    fi

    if [ $? -eq 0 ]; then
        log_success "代码同步完成"
        return 0
    else
        log_error "代码同步失败"
        return 1
    fi
}

# 远程编译
remote_compile() {
    log_step "步骤 2/2: 在远程机器上编译 Network_test 协议"
    log_info "编译并行度: -j64"
    log_info "预计时间: 3-5分钟"

    # 构建远程编译命令
    # 注意: 设置 CUDAHOME 为虚拟路径，避免 gpgpu-sim/SConscript 报错
    # Network_test 协议不需要 GPU，但构建系统会扫描 gpgpu-sim 目录
    # 清理构建目录以移除之前构建遗留的 gpgpu-sim 符号链接
    # 同时清理可能存在的 src/gpgpu-sim 符号链接
    REMOTE_COMPILE_CMD="cd ${REMOTE_PROJECT_DIR}/gem5 && rm -rf build/X86_Network_test/ && rm -f src/gpgpu-sim && export CUDAHOME=/usr/local/cuda && python \`which scons\` build/X86_Network_test/gem5.opt --default=X86 PROTOCOL=Network_test -j64"

    log_info "执行远程编译命令..."
    echo "----------------------------------------" | tee -a "${LOCAL_LOG}"

    if [ "$USE_SSH_KEY" = true ]; then
        ssh ${REMOTE_USER}@${REMOTE_HOST} "${REMOTE_COMPILE_CMD}" 2>&1 | tee -a "${LOCAL_LOG}"
        BUILD_RESULT=${PIPESTATUS[0]}
    else
        sshpass -p "${REMOTE_PASSWORD}" ssh ${REMOTE_USER}@${REMOTE_HOST} "${REMOTE_COMPILE_CMD}" 2>&1 | tee -a "${LOCAL_LOG}"
        BUILD_RESULT=${PIPESTATUS[0]}
    fi

    echo "----------------------------------------" | tee -a "${LOCAL_LOG}"

    if [ $BUILD_RESULT -eq 0 ]; then
        log_success "远程编译完成"
        return 0
    else
        log_error "远程编译失败，退出码: ${BUILD_RESULT}"
        return 1
    fi
}

# 本地编译
local_compile() {
    log_step "本地编译 Network_test 协议"
    log_info "编译并行度: -j8"
    log_info "预计时间: 15-25分钟"

    cd "${LOCAL_PROJECT_DIR}/gem5" || {
        log_error "无法进入gem5目录"
        return 1
    }

    # 清理构建目录以移除之前构建遗留的 gpgpu-sim 符号链接
    log_info "清理构建目录和可能的 gpgpu-sim 符号链接..."
    rm -rf build/X86_Network_test/
    rm -f src/gpgpu-sim

    echo "----------------------------------------" | tee -a "${LOCAL_LOG}"
    # 设置 CUDAHOME 避免 gpgpu-sim/SConscript 报错
    export CUDAHOME=/usr/local/cuda
    python `which scons` build/X86_Network_test/gem5.opt \
        --default=X86 \
        PROTOCOL=Network_test \
        -j8 2>&1 | tee -a "${LOCAL_LOG}"
    BUILD_RESULT=${PIPESTATUS[0]}
    echo "----------------------------------------" | tee -a "${LOCAL_LOG}"

    if [ $BUILD_RESULT -eq 0 ]; then
        log_success "本地编译完成"
        return 0
    else
        log_error "本地编译失败，退出码: ${BUILD_RESULT}"
        return 1
    fi
}

# 传输二进制文件回本地（远程编译后）
fetch_binary() {
    log_step "传输编译好的二进制文件回本地..."

    REMOTE_BINARY="${REMOTE_PROJECT_DIR}/gem5/build/X86_Network_test/gem5.opt"
    LOCAL_BINARY="${LOCAL_PROJECT_DIR}/gem5/build/X86_Network_test/"

    # 创建本地目录
    mkdir -p "${LOCAL_BINARY}"

    if [ "$USE_SSH_KEY" = true ]; then
        scp ${REMOTE_USER}@${REMOTE_HOST}:"${REMOTE_BINARY}" "${LOCAL_BINARY}/" 2>&1 | tee -a "${LOCAL_LOG}"
    else
        sshpass -p "${REMOTE_PASSWORD}" scp ${REMOTE_USER}@${REMOTE_HOST}:"${REMOTE_BINARY}" "${LOCAL_BINARY}/" 2>&1 | tee -a "${LOCAL_LOG}"
    fi

    if [ $? -eq 0 ]; then
        log_success "二进制文件传输完成"
        log_info "本地路径: ${LOCAL_BINARY}/gem5.opt"
        return 0
    else
        log_error "二进制文件传输失败"
        return 1
    fi
}

# 主函数
main() {
    local compile_mode="remote"  # 默认远程编译
    local start_time=$(date +%s)

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--local)
                compile_mode="local"
                shift
                ;;
            -r|--remote)
                compile_mode="remote"
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

    echo "=========================================="
    echo "Network_test 协议编译脚本"
    echo "=========================================="
    echo ""
    log_info "编译模式: ${compile_mode}"
    log_info "日志文件: ${LOCAL_LOG}"
    echo ""

    # 执行编译
    if [ "$compile_mode" = "remote" ]; then
        # 远程编译模式
        log_info "使用远程编译模式（推荐）"
        echo ""

        # 检查SSH连接
        if ! check_ssh_connection; then
            log_error "SSH连接检查失败"
            log_warning "尝试使用本地编译: $0 --local"
            exit 1
        fi
        echo ""

        # 同步代码
        if ! sync_code; then
            log_error "代码同步失败"
            exit 1
        fi
        echo ""

        # 远程编译
        if ! remote_compile; then
            log_error "远程编译失败"
            log_info "请检查日志: ${LOCAL_LOG}"
            exit 1
        fi
        echo ""

        # 传输二进制文件
        if ! fetch_binary; then
            log_error "二进制文件传输失败"
            exit 1
        fi

    else
        # 本地编译模式
        log_info "使用本地编译模式"
        log_warning "本地编译较慢（-j8），建议使用远程编译（-j64）"
        echo ""

        if ! local_compile; then
            log_error "本地编译失败"
            log_info "请检查日志: ${LOCAL_LOG}"
            exit 1
        fi
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "=========================================="
    log_success "编译完成！"
    echo "=========================================="
    echo ""
    log_info "总耗时: ${duration} 秒 ($(($duration / 60)) 分钟)"
    log_info "gem5 二进制: ${LOCAL_PROJECT_DIR}/gem5/build/X86_Network_test/gem5.opt"
    log_info "完整日志: ${LOCAL_LOG}"
    echo ""
    log_info "下一步:"
    echo "  ./run_phase4_traffic_verification.sh"
    echo ""

    exit 0
}

# 执行主函数
main "$@"
