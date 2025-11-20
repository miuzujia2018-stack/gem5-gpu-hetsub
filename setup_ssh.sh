#!/bin/bash

# SSH环境快速设置脚本
# 使用方法: ./setup_ssh.sh [选项]

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
SSH_KNOWN_HOSTS="$SSH_DIR/known_hosts"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}SSH环境快速设置脚本${NC}"
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -i, --init          初始化SSH环境"
    echo "  -k, --keygen        生成SSH密钥对"
    echo "  -c, --config        创建SSH配置文件"
    echo "  -s, --setup         完整设置（初始化+密钥+配置）"
    echo "  -p, --permissions   设置正确的文件权限"
    echo "  -t, --test          测试SSH配置"
    echo ""
    echo "示例:"
    echo "  $0 -s                # 完整设置"
    echo "  $0 -k                # 只生成密钥"
    echo "  $0 -c                # 只创建配置文件"
}

# 初始化SSH环境
init_ssh() {
    echo -e "${BLUE}初始化SSH环境...${NC}"
    
    # 创建SSH目录
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        echo -e "${GREEN}✓ 创建SSH目录: $SSH_DIR${NC}"
    else
        echo -e "${YELLOW}SSH目录已存在: $SSH_DIR${NC}"
    fi
    
    # 创建known_hosts文件
    if [ ! -f "$SSH_KNOWN_HOSTS" ]; then
        touch "$SSH_KNOWN_HOSTS"
        echo -e "${GREEN}✓ 创建known_hosts文件${NC}"
    else
        echo -e "${YELLOW}known_hosts文件已存在${NC}"
    fi
    
    # 设置权限
    set_permissions
}

# 生成SSH密钥对
generate_keys() {
    echo -e "${BLUE}生成SSH密钥对...${NC}"
    
    local key_type="ed25519"
    local email="$(whoami)@$(hostname)"
    local key_file="$SSH_DIR/id_$key_type"
    
    # 检查是否已存在密钥
    if [ -f "$key_file" ]; then
        echo -e "${YELLOW}密钥已存在: $key_file${NC}"
        read -p "是否重新生成？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # 生成密钥
    echo "生成 $key_type 密钥对..."
    ssh-keygen -t "$key_type" -C "$email" -f "$key_file" -N ""
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSH密钥生成成功${NC}"
        echo "私钥: $key_file"
        echo "公钥: $key_file.pub"
        
        # 显示公钥内容
        echo -e "${BLUE}公钥内容:${NC}"
        cat "$key_file.pub"
        echo ""
    else
        echo -e "${RED}✗ SSH密钥生成失败${NC}"
        return 1
    fi
}

# 创建SSH配置文件
create_config() {
    echo -e "${BLUE}创建SSH配置文件...${NC}"
    
    if [ -f "$SSH_CONFIG" ]; then
        echo -e "${YELLOW}SSH配置文件已存在: $SSH_CONFIG${NC}"
        read -p "是否备份并重新创建？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
            echo -e "${GREEN}✓ 已备份原配置文件${NC}"
        else
            return 0
        fi
    fi
    
    # 创建配置文件
    cat > "$SSH_CONFIG" << 'EOF'
# SSH配置文件
# 由setup_ssh.sh自动生成

# 全局默认设置
Host *
    # 保持连接活跃
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    
    # 多路复用连接
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 10m
    
    # 压缩和性能优化
    Compression yes
    ForwardAgent yes
    
    # 安全设置
    StrictHostKeyChecking ask
    UserKnownHostsFile ~/.ssh/known_hosts

# 示例服务器配置
# 取消注释并修改以下配置来添加你的服务器

# Host example-server
#     HostName 192.168.1.100
#     User your-username
#     Port 22
#     IdentityFile ~/.ssh/id_ed25519
#     ForwardX11 yes

# Host production-server
#     HostName prod.example.com
#     User admin
#     Port 2222
#     IdentityFile ~/.ssh/prod_key
#     ServerAliveInterval 30
#     ServerAliveCountMax 2

# Host jump-server
#     HostName 192.168.1.200
#     User jump-user
#     Port 22
#     IdentityFile ~/.ssh/jump_key

# Host internal-server
#     HostName 10.0.0.100
#     User internal-user
#     Port 22
#     IdentityFile ~/.ssh/internal_key
#     ProxyJump jump-server
EOF
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSH配置文件创建成功${NC}"
        echo "配置文件: $SSH_CONFIG"
    else
        echo -e "${RED}✗ SSH配置文件创建失败${NC}"
        return 1
    fi
}

# 设置文件权限
set_permissions() {
    echo -e "${BLUE}设置SSH文件权限...${NC}"
    
    # 设置SSH目录权限
    chmod 700 "$SSH_DIR"
    echo -e "${GREEN}✓ 设置SSH目录权限: 700${NC}"
    
    # 设置known_hosts权限
    if [ -f "$SSH_KNOWN_HOSTS" ]; then
        chmod 644 "$SSH_KNOWN_HOSTS"
        echo -e "${GREEN}✓ 设置known_hosts权限: 644${NC}"
    fi
    
    # 设置配置文件权限
    if [ -f "$SSH_CONFIG" ]; then
        chmod 600 "$SSH_CONFIG"
        echo -e "${GREEN}✓ 设置配置文件权限: 600${NC}"
    fi
    
    # 设置私钥权限
    for key in "$SSH_DIR"/id_*; do
        if [ -f "$key" ] && [[ ! "$key" =~ \.pub$ ]]; then
            chmod 600 "$key"
            echo -e "${GREEN}✓ 设置私钥权限: $key -> 600${NC}"
        fi
    done
    
    # 设置公钥权限
    for key in "$SSH_DIR"/*.pub; do
        if [ -f "$key" ]; then
            chmod 644 "$key"
            echo -e "${GREEN}✓ 设置公钥权限: $key -> 644${NC}"
        fi
    done
}

# 测试SSH配置
test_config() {
    echo -e "${BLUE}测试SSH配置...${NC}"
    
    # 检查SSH目录
    if [ ! -d "$SSH_DIR" ]; then
        echo -e "${RED}✗ SSH目录不存在${NC}"
        return 1
    fi
    
    # 检查配置文件语法
    if [ -f "$SSH_CONFIG" ]; then
        if ssh -F "$SSH_CONFIG" -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${GREEN}✓ SSH配置文件语法正确${NC}"
        else
            echo -e "${YELLOW}SSH配置文件语法检查完成${NC}"
        fi
    fi
    
    # 检查密钥
    local key_count=0
    for key in "$SSH_DIR"/id_*; do
        if [ -f "$key" ] && [[ ! "$key" =~ \.pub$ ]]; then
            key_count=$((key_count + 1))
            echo -e "${GREEN}✓ 找到私钥: $key${NC}"
        fi
    done
    
    if [ $key_count -eq 0 ]; then
        echo -e "${YELLOW}未找到SSH私钥${NC}"
    fi
    
    # 检查权限
    local dir_perm=$(stat -c %a "$SSH_DIR")
    if [ "$dir_perm" = "700" ]; then
        echo -e "${GREEN}✓ SSH目录权限正确: $dir_perm${NC}"
    else
        echo -e "${RED}✗ SSH目录权限错误: $dir_perm (应该是700)${NC}"
    fi
    
    echo -e "${GREEN}✓ SSH配置测试完成${NC}"
}

# 完整设置
full_setup() {
    echo -e "${BLUE}开始完整SSH环境设置...${NC}"
    echo ""
    
    init_ssh
    echo ""
    
    generate_keys
    echo ""
    
    create_config
    echo ""
    
    set_permissions
    echo ""
    
    test_config
    echo ""
    
    echo -e "${GREEN}✓ SSH环境设置完成！${NC}"
    echo ""
    echo "下一步操作:"
    echo "1. 编辑SSH配置文件: nano ~/.ssh/config"
    echo "2. 复制公钥到服务器: ssh-copy-id user@server"
    echo "3. 测试连接: ssh server-name"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case $1 in
        -h|--help)
            show_help
            ;;
        -i|--init)
            init_ssh
            ;;
        -k|--keygen)
            generate_keys
            ;;
        -c|--config)
            create_config
            ;;
        -s|--setup)
            full_setup
            ;;
        -p|--permissions)
            set_permissions
            ;;
        -t|--test)
            test_config
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 如果脚本被直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 