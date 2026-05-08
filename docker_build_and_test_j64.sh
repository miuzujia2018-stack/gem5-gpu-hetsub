#!/bin/bash

################################################################################
# docker_build_and_test_j64.sh - Docker 一键编译和测试脚本
#
# 功能：启动 gem5gpu-dev 容器，在 Docker 中使用 -j64 编译 gem5，然后运行测试
# 用法：在 WSL 中执行 ./docker_build_and_test_j64.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="gem5gpu-dev"
CONTAINER_PROJECT_DIR="/home/siat/gem5-gpu-bak"
JOBS=64

LOG_DIR="${SCRIPT_DIR}/build_logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOG_DIR}/docker_build_and_test_j64_${TIMESTAMP}.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

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

check_container() {
    if ! sudo sudo docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
        log_error "找不到 Docker 容器：${CONTAINER_NAME}"
        log_error "请先创建/恢复容器，或确认容器名是否正确。"
        exit 1
    fi

    if [ "$(sudo docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" != "true" ]; then
        log_info "容器未运行，正在启动：${CONTAINER_NAME}"
        sudo docker start "${CONTAINER_NAME}" >/dev/null
    fi

    log_success "Docker 容器已就绪：${CONTAINER_NAME}"
}

check_jobs() {
    local host_nproc="unknown"
    local container_nproc="unknown"

    if command -v nproc >/dev/null 2>&1; then
        host_nproc="$(nproc)"
    fi

    container_nproc="$(sudo docker exec "${CONTAINER_NAME}" /bin/bash --noprofile --norc -c 'nproc')"

    log_info "WSL 可见 CPU 线程数：${host_nproc}"
    log_info "Docker 可见 CPU 线程数：${container_nproc}"
    log_info "本脚本编译参数：-j${JOBS}"

    if [ "${container_nproc}" != "${JOBS}" ]; then
        log_warning "Docker 可见线程数不是 ${JOBS}，但仍会按你的要求使用 -j${JOBS} 编译。"
    else
        log_success "已确认 Docker 可见线程数为 ${JOBS}，匹配 -j${JOBS}。"
    fi
}

run_build() {
    log_step "步骤 1/2：在 Docker 中使用 -j${JOBS} 编译 gem5.opt"

    sudo docker exec "${CONTAINER_NAME}" /bin/bash --noprofile --norc -c "
        set -e
        export CUDAHOME=/usr/local/cuda/cuda
        export PATH=/usr/local/cuda/cuda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64
        export ENABLE_SIMPLIFIED_PSO=1
        cd ${CONTAINER_PROJECT_DIR}/gem5
        scons build/X86_VI_hammer_GPU/gem5.opt \
            --default=X86 \
            EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \
            PROTOCOL=VI_hammer \
            GPGPU_SIM=True \
            -j${JOBS}
    "

    log_success "编译完成"
}

run_test() {
    log_step "步骤 2/2：在 Docker 中运行 ./run.sh 测试"

    sudo docker exec "${CONTAINER_NAME}" /bin/bash --noprofile --norc -c "
        set -e
        cd ${CONTAINER_PROJECT_DIR}
        ./run.sh
    "

    log_success "测试完成"
}

main() {
    echo "========================================"
    echo "gem5-gpu Docker 一键编译和测试脚本 (-j${JOBS})"
    echo "========================================"
    echo ""

    local start_time
    start_time="$(date +%s)"

    check_container
    check_jobs
    echo ""

    run_build
    echo ""

    run_test
    echo ""

    local end_time duration
    end_time="$(date +%s)"
    duration=$((end_time - start_time))

    echo "========================================"
    log_success "全部完成"
    log_info "总耗时：${duration} 秒 ($((${duration} / 60)) 分钟)"
    log_info "日志文件：${LOG_FILE}"
    echo "========================================"
}

main "$@" 2>&1 | tee "${LOG_FILE}"
