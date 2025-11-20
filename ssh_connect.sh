#!/bin/bash

# SSH连接工具脚本
# 使用方法: ./ssh_connect.sh [选项] [服务器名]

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_USER=""
DEFAULT_PORT="22"
SSH_CONFIG_FILE="$HOME/.ssh/config"

# 显示帮助信息
show_help() {
    echo -e "${BLUE}SSH连接工具${NC}"
    echo "使用方法: $0 [选项] [服务器名]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -u, --user USER     指定用户名"
    echo "  -p, --port PORT     指定端口号"
    echo "  -i, --identity FILE 指定SSH密钥文件"
    echo "  -v, --verbose       详细输出"
    echo "  -X, --x11           启用X11转发"
    echo "  -D, --dynamic PORT  启用动态端口转发"
    echo "  -L, --local PORT    启用本地端口转发"
    echo "  -R, --remote PORT   启用远程端口转发"
    echo "  -l, --list          列出可用的服务器"
    echo "  -c, --config        编辑SSH配置文件"
    echo ""
    echo "示例:"
    echo "  $0 myserver                    # 连接到myserver"
    echo "  $0 -u admin -p 2222 server1    # 使用指定用户和端口"
    echo "  $0 -i ~/.ssh/custom_key prod   # 使用指定密钥"
    echo "  $0 -D 1080 proxy               # 创建SOCKS代理"
    echo "  $0 -L 8080:localhost:80 web    # 本地端口转发"
}

# 列出可用的服务器
list_servers() {
    if [ -f "$SSH_CONFIG_FILE" ]; then
        echo -e "${GREEN}可用的服务器配置:${NC}"
        echo ""
        grep -E "^Host " "$SSH_CONFIG_FILE" | sed 's/Host //' | while read -r host; do
            echo -e "  ${YELLOW}$host${NC}"
        done
    else
        echo -e "${RED}SSH配置文件不存在: $SSH_CONFIG_FILE${NC}"
        echo "请先创建SSH配置文件"
    fi
}

# 编辑SSH配置文件
edit_config() {
    if command -v nano >/dev/null 2>&1; then
        nano "$SSH_CONFIG_FILE"
    elif command -v vim >/dev/null 2>&1; then
        vim "$SSH_CONFIG_FILE"
    elif command -v vi >/dev/null 2>&1; then
        vi "$SSH_CONFIG_FILE"
    else
        echo -e "${RED}未找到可用的文本编辑器${NC}"
        exit 1
    fi
}

# 测试连接
test_connection() {
    local host="$1"
    local user="$2"
    local port="$3"
    
    echo -e "${BLUE}测试连接到 $host...${NC}"
    
    # 检查主机是否可达
    if ping -c 1 "$host" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 主机可达${NC}"
    else
        echo -e "${RED}✗ 主机不可达${NC}"
        return 1
    fi
    
    # 检查端口是否开放
    if nc -z "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}✓ 端口 $port 开放${NC}"
    else
        echo -e "${RED}✗ 端口 $port 关闭${NC}"
        return 1
    fi
    
    return 0
}

# 生成SSH密钥
generate_key() {
    local key_type="$1"
    local email="$2"
    local key_file="$3"
    
    echo -e "${BLUE}生成SSH密钥...${NC}"
    
    if [ -z "$key_file" ]; then
        key_file="$HOME/.ssh/id_ed25519"
    fi
    
    if [ -z "$email" ]; then
        email="$(whoami)@$(hostname)"
    fi
    
    ssh-keygen -t "${key_type:-ed25519}" -C "$email" -f "$key_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSH密钥生成成功${NC}"
        echo "私钥: $key_file"
        echo "公钥: $key_file.pub"
    else
        echo -e "${RED}✗ SSH密钥生成失败${NC}"
    fi
}

# 复制SSH密钥到服务器
copy_key() {
    local server="$1"
    local user="$2"
    local key_file="$3"
    
    if [ -z "$key_file" ]; then
        key_file="$HOME/.ssh/id_ed25519.pub"
    fi
    
    if [ ! -f "$key_file" ]; then
        echo -e "${RED}公钥文件不存在: $key_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}复制SSH密钥到服务器...${NC}"
    
    if command -v ssh-copy-id >/dev/null 2>&1; then
        ssh-copy-id -i "$key_file" "$user@$server"
    else
        cat "$key_file" | ssh "$user@$server" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSH密钥复制成功${NC}"
    else
        echo -e "${RED}✗ SSH密钥复制失败${NC}"
    fi
}

# 主函数
main() {
    local user="$DEFAULT_USER"
    local port="$DEFAULT_PORT"
    local identity_file=""
    local verbose=""
    local x11_forward=""
    local dynamic_port=""
    local local_port=""
    local remote_port=""
    local server=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--user)
                user="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -i|--identity)
                identity_file="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="-v"
                shift
                ;;
            -X|--x11)
                x11_forward="-X"
                shift
                ;;
            -D|--dynamic)
                dynamic_port="$2"
                shift 2
                ;;
            -L|--local)
                local_port="$2"
                shift 2
                ;;
            -R|--remote)
                remote_port="$2"
                shift 2
                ;;
            -l|--list)
                list_servers
                exit 0
                ;;
            -c|--config)
                edit_config
                exit 0
                ;;
            -g|--generate-key)
                generate_key "$2" "$3" "$4"
                exit 0
                ;;
            -k|--copy-key)
                copy_key "$2" "$3" "$4"
                exit 0
                ;;
            -t|--test)
                test_connection "$2" "$3" "$4"
                exit 0
                ;;
            -*)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                server="$1"
                shift
                ;;
        esac
    done
    
    # 检查是否提供了服务器名
    if [ -z "$server" ]; then
        echo -e "${RED}请指定服务器名${NC}"
        show_help
        exit 1
    fi
    
    # 构建SSH命令
    local ssh_cmd="ssh"
    
    if [ -n "$user" ]; then
        ssh_cmd="$ssh_cmd -l $user"
    fi
    
    if [ -n "$port" ] && [ "$port" != "22" ]; then
        ssh_cmd="$ssh_cmd -p $port"
    fi
    
    if [ -n "$identity_file" ]; then
        ssh_cmd="$ssh_cmd -i $identity_file"
    fi
    
    if [ -n "$verbose" ]; then
        ssh_cmd="$ssh_cmd $verbose"
    fi
    
    if [ -n "$x11_forward" ]; then
        ssh_cmd="$ssh_cmd $x11_forward"
    fi
    
    if [ -n "$dynamic_port" ]; then
        ssh_cmd="$ssh_cmd -D $dynamic_port"
    fi
    
    if [ -n "$local_port" ]; then
        ssh_cmd="$ssh_cmd -L $local_port"
    fi
    
    if [ -n "$remote_port" ]; then
        ssh_cmd="$ssh_cmd -R $remote_port"
    fi
    
    ssh_cmd="$ssh_cmd $server"
    
    echo -e "${BLUE}执行命令: $ssh_cmd${NC}"
    echo ""
    
    # 执行SSH连接
    eval "$ssh_cmd"
}

# 如果脚本被直接执行，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 