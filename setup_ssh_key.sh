#!/bin/bash

################################################################################
# setup_ssh_key.sh - SSH密钥认证配置脚本
#
# 功能：配置SSH免密登录，避免每次输入密码
# 作者：自动化脚本系统
# 日期：2025-11-04
################################################################################

# 配置参数
REMOTE_USER="siat"
REMOTE_HOST="192.168.157.128"
REMOTE_PASSWORD="123"  # 需要密码来配置新机器的SSH密钥

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查sshpass是否安装
check_sshpass() {
    if ! command -v sshpass &> /dev/null; then
        log_error "未安装sshpass工具"
        log_info "请先安装sshpass："
        echo "  Ubuntu/Debian: sudo apt-get install sshpass"
        echo "  CentOS/RHEL:   sudo yum install sshpass"
        return 1
    fi
    log_success "sshpass已安装"
    return 0
}

# 检查是否已经有SSH密钥
check_existing_key() {
    if [ -f ~/.ssh/id_rsa.pub ]; then
        log_info "检测到已存在的SSH密钥: ~/.ssh/id_rsa.pub"
        return 0
    else
        log_warning "未检测到SSH密钥"
        return 1
    fi
}

# 生成SSH密钥
generate_ssh_key() {
    log_info "开始生成SSH密钥..."

    # 创建.ssh目录
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # 生成密钥（使用空密码）
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "${USER}@$(hostname)"

    if [ $? -eq 0 ]; then
        log_success "SSH密钥生成成功"
        log_info "公钥位置: ~/.ssh/id_rsa.pub"
        log_info "私钥位置: ~/.ssh/id_rsa"
        return 0
    else
        log_error "SSH密钥生成失败"
        return 1
    fi
}

# 复制公钥到远程机器
copy_ssh_key() {
    log_info "复制SSH公钥到远程机器..."
    log_info "目标: ${REMOTE_USER}@${REMOTE_HOST}"

    # 使用sshpass和ssh-copy-id复制公钥
    sshpass -p "${REMOTE_PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST}

    if [ $? -eq 0 ]; then
        log_success "SSH公钥复制成功"
        return 0
    else
        log_error "SSH公钥复制失败"
        return 1
    fi
}

# 测试SSH免密登录
test_ssh_connection() {
    log_info "测试SSH免密登录..."

    # 尝试不使用密码连接
    ssh -o BatchMode=yes -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} "echo 'SSH免密登录测试成功'" 2>/dev/null

    if [ $? -eq 0 ]; then
        log_success "SSH免密登录配置成功！"
        log_info "现在可以无需密码登录到 ${REMOTE_HOST}"
        return 0
    else
        log_error "SSH免密登录测试失败"
        log_warning "请检查远程机器的SSH配置"
        return 1
    fi
}

# 显示后续步骤
show_next_steps() {
    echo ""
    echo "========================================"
    log_success "SSH密钥配置完成！"
    echo "========================================"
    echo ""
    log_info "后续步骤："
    echo "  1. 编辑 sync_and_build.sh 和 run_tests.sh"
    echo "  2. 删除或注释掉 REMOTE_PASSWORD 行"
    echo "  3. 运行编译脚本: ./sync_and_build.sh"
    echo "  4. 运行测试脚本: ./run_tests.sh [backprop|kmeans|all]"
    echo ""
    log_warning "安全建议："
    echo "  • 保护好私钥文件 ~/.ssh/id_rsa"
    echo "  • 不要将私钥分享给他人"
    echo "  • 建议删除脚本中的明文密码"
}

# 主函数
main() {
    echo "========================================"
    echo "SSH免密登录配置脚本"
    echo "========================================"
    echo ""

    log_info "配置目标: ${REMOTE_USER}@${REMOTE_HOST}"
    echo ""

    # 步骤1: 检查sshpass
    if ! check_sshpass; then
        exit 1
    fi

    # 步骤2: 检查或生成SSH密钥
    if ! check_existing_key; then
        log_warning "需要生成新的SSH密钥"
        read -p "是否要生成新的SSH密钥? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! generate_ssh_key; then
                exit 1
            fi
        else
            log_error "取消操作"
            exit 1
        fi
    fi

    # 步骤3: 复制公钥到远程机器
    if ! copy_ssh_key; then
        log_error "公钥复制失败，请检查："
        echo "  1. 远程机器IP地址是否正确: ${REMOTE_HOST}"
        echo "  2. 用户名是否正确: ${REMOTE_USER}"
        echo "  3. 密码是否正确"
        echo "  4. 远程机器SSH服务是否运行"
        exit 1
    fi

    # 步骤4: 测试SSH连接
    if ! test_ssh_connection; then
        exit 1
    fi

    # 显示后续步骤
    show_next_steps

    exit 0
}

# 执行主函数
main "$@"
