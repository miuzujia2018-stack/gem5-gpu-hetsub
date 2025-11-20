#!/bin/bash

################################################################################
# sync_and_build.sh - 跨机器代码同步和编译脚本
#
# 功能：将本地代码同步到远程机器并执行编译
# 作者：自动化脚本系统
# 日期：2025-11-04
################################################################################

# 配置参数
REMOTE_USER="siat"
REMOTE_HOST="192.168.157.128"
REMOTE_PASSWORD="123"  # 临时启用密码认证
LOCAL_PROJECT_DIR="/home/siat/gem5-gpu-bak"
REMOTE_PROJECT_DIR="/home/siat/gem5-gpu-bak"
BUILD_DIR="gem5"
LOG_DIR="${LOCAL_PROJECT_DIR}/build_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOCAL_LOG="${LOG_DIR}/sync_build_${TIMESTAMP}.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
        log_warning "建议运行 setup_ssh_key.sh 配置免密登录"
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
    log_info "开始同步代码到远程机器..."
    log_info "本地目录: ${LOCAL_PROJECT_DIR}"
    log_info "远程目录: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PROJECT_DIR}"

    # rsync参数说明：
    # -a: 归档模式，保持权限、时间戳等
    # -v: 详细输出
    # -z: 压缩传输
    # -h: 人类可读格式
    # --progress: 显示进度
    # --delete: 删除目标目录中源目录没有的文件（保持一致性）
    # --exclude: 排除不需要同步的文件/目录

    RSYNC_OPTS="-avzh --progress --delete"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='build/' --exclude='.git/' --exclude='*.pyc'"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='*.o' --exclude='*.a' --exclude='build_logs/'"
    RSYNC_OPTS="${RSYNC_OPTS} --exclude='m5out/' --exclude='*.swp' --exclude='*.bak'"

    # 关键：只同步源代码目录，不同步编译产物
    SYNC_DIRS=(
        "gem5-gpu/src"
        "gpgpu-sim"
        "gem5/src"
        "gem5/configs"
        "gem5-gpu/configs"
        "gem5/build_opts"
        "benchmarks"
    )

    log_info "同步以下目录："
    for dir in "${SYNC_DIRS[@]}"; do
        log_info "  - ${dir}"
    done

    RSYNC_CMD="rsync ${RSYNC_OPTS}"

    # 根据认证方式选择rsync命令
    if [ "$USE_SSH_KEY" = true ]; then
        for dir in "${SYNC_DIRS[@]}"; do
            if [ -d "${LOCAL_PROJECT_DIR}/${dir}" ]; then
                log_info "同步 ${dir}..."
                ${RSYNC_CMD} "${LOCAL_PROJECT_DIR}/${dir}/" \
                    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PROJECT_DIR}/${dir}/" 2>&1 | tee -a "${LOCAL_LOG}"

                if [ ${PIPESTATUS[0]} -ne 0 ]; then
                    log_error "同步 ${dir} 失败"
                    return 1
                fi
            else
                log_warning "本地目录不存在: ${LOCAL_PROJECT_DIR}/${dir}"
            fi
        done
    else
        # 使用sshpass进行密码认证
        for dir in "${SYNC_DIRS[@]}"; do
            if [ -d "${LOCAL_PROJECT_DIR}/${dir}" ]; then
                log_info "同步 ${dir}..."
                sshpass -p "${REMOTE_PASSWORD}" ${RSYNC_CMD} \
                    -e "ssh -o StrictHostKeyChecking=no" \
                    "${LOCAL_PROJECT_DIR}/${dir}/" \
                    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PROJECT_DIR}/${dir}/" 2>&1 | tee -a "${LOCAL_LOG}"

                if [ ${PIPESTATUS[0]} -ne 0 ]; then
                    log_error "同步 ${dir} 失败"
                    return 1
                fi
            else
                log_warning "本地目录不存在: ${LOCAL_PROJECT_DIR}/${dir}"
            fi
        done
    fi

    log_success "代码同步完成"
    return 0
}

# 在远程机器上执行编译
remote_build() {
    log_info "开始在远程机器上编译项目..."
    log_info "编译目录: ${REMOTE_PROJECT_DIR}/${BUILD_DIR}"

    # 编译命令（设置CUDAHOME环境变量）
    BUILD_CMD="export CUDAHOME=/usr/local/cuda/cuda && cd ${REMOTE_PROJECT_DIR}/${BUILD_DIR} && python \$(which scons) build/X86_VI_hammer_GPU/gem5.opt --default=X86 EXTRAS=../gem5-gpu/src:../gpgpu-sim/ PROTOCOL=VI_hammer GPGPU_SIM=True -j64"

    REMOTE_LOG="/tmp/gem5_build_${TIMESTAMP}.log"

    log_info "执行编译命令:"
    log_info "  ${BUILD_CMD}"

    # 根据认证方式选择SSH命令
    if [ "$USE_SSH_KEY" = true ]; then
        ssh ${REMOTE_USER}@${REMOTE_HOST} "
            echo '========================================' > ${REMOTE_LOG}
            echo 'gem5-gpu 编译日志' >> ${REMOTE_LOG}
            echo '时间: \$(date)' >> ${REMOTE_LOG}
            echo '机器: \$(hostname)' >> ${REMOTE_LOG}
            echo '========================================' >> ${REMOTE_LOG}
            echo '' >> ${REMOTE_LOG}
            ${BUILD_CMD} 2>&1 | tee -a ${REMOTE_LOG}
            exit \${PIPESTATUS[0]}
        "
        BUILD_RESULT=$?
    else
        sshpass -p "${REMOTE_PASSWORD}" ssh -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST} "
            echo '========================================' > ${REMOTE_LOG}
            echo 'gem5-gpu 编译日志' >> ${REMOTE_LOG}
            echo '时间: \$(date)' >> ${REMOTE_LOG}
            echo '机器: \$(hostname)' >> ${REMOTE_LOG}
            echo '========================================' >> ${REMOTE_LOG}
            echo '' >> ${REMOTE_LOG}
            ${BUILD_CMD} 2>&1 | tee -a ${REMOTE_LOG}
            exit \${PIPESTATUS[0]}
        "
        BUILD_RESULT=$?
    fi

    # 回传编译日志
    log_info "回传编译日志..."
    if [ "$USE_SSH_KEY" = true ]; then
        scp ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_LOG} "${LOG_DIR}/remote_build_${TIMESTAMP}.log"
    else
        sshpass -p "${REMOTE_PASSWORD}" scp -o StrictHostKeyChecking=no \
            ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_LOG} "${LOG_DIR}/remote_build_${TIMESTAMP}.log"
    fi

    if [ $BUILD_RESULT -eq 0 ]; then
        log_success "编译成功！"
        log_info "远程日志文件: ${REMOTE_LOG}"
        log_info "本地日志文件: ${LOG_DIR}/remote_build_${TIMESTAMP}.log"
        return 0
    else
        log_error "编译失败！退出码: ${BUILD_RESULT}"
        log_error "请检查日志文件: ${LOG_DIR}/remote_build_${TIMESTAMP}.log"
        return 1
    fi
}

# 主函数
main() {
    echo "========================================"
    echo "gem5-gpu 跨机器同步和编译脚本"
    echo "========================================"
    echo ""

    log_info "开始执行同步和编译流程..."
    log_info "日志文件: ${LOCAL_LOG}"

    # 步骤1: 检查SSH连接
    if ! check_ssh_connection; then
        log_error "SSH连接检查失败，终止执行"
        exit 1
    fi

    # 步骤2: 同步代码
    if ! sync_code; then
        log_error "代码同步失败，终止执行"
        exit 1
    fi

    # 步骤3: 远程编译
    if ! remote_build; then
        log_error "编译失败，终止执行"
        exit 1
    fi

    echo ""
    echo "========================================"
    log_success "所有步骤执行完成！"
    echo "========================================"
    log_info "完整日志: ${LOCAL_LOG}"
    log_info "编译日志: ${LOG_DIR}/remote_build_${TIMESTAMP}.log"
    echo ""
    log_info "下一步: 运行测试脚本"
    log_info "  ./run_tests.sh backprop"
    log_info "  ./run_tests.sh kmeans"
    log_info "  ./run_tests.sh all"

    exit 0
}

# 执行主函数
main "$@"
