# SSH 连接服务器完整指南

## 1. 基本SSH连接

### 1.1 基本语法
```bash
ssh [选项] 用户名@主机地址
```

### 1.2 常用连接示例
```bash
# 使用默认端口22连接
ssh user@192.168.1.100

# 使用指定端口连接
ssh -p 2222 user@192.168.1.100

# 使用域名连接
ssh user@example.com

# 使用SSH密钥连接
ssh -i ~/.ssh/id_rsa user@192.168.1.100
```

## 2. SSH密钥认证设置

### 2.1 生成SSH密钥对
```bash
# 生成RSA密钥对
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 生成Ed25519密钥对（推荐，更安全）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 生成带密码的密钥对
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/my_key
```

### 2.2 复制公钥到服务器
```bash
# 方法1：使用ssh-copy-id（推荐）
ssh-copy-id user@192.168.1.100

# 方法2：手动复制
cat ~/.ssh/id_ed25519.pub | ssh user@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"

# 方法3：使用scp复制
scp ~/.ssh/id_ed25519.pub user@192.168.1.100:~/.ssh/
ssh user@192.168.1.100 "cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys"
```

### 2.3 设置密钥权限
```bash
# 设置私钥权限
chmod 600 ~/.ssh/id_ed25519

# 设置公钥权限
chmod 644 ~/.ssh/id_ed25519.pub

# 设置.ssh目录权限
chmod 700 ~/.ssh

# 设置authorized_keys权限
chmod 600 ~/.ssh/authorized_keys
```

## 3. SSH配置文件

### 3.1 创建SSH配置文件
```bash
# 编辑配置文件
nano ~/.ssh/config
```

### 3.2 配置文件示例
```
# 基本配置
Host myserver
    HostName 192.168.1.100
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519

# 多密钥配置
Host server1
    HostName 192.168.1.101
    User admin
    IdentityFile ~/.ssh/server1_key

Host server2
    HostName 192.168.1.102
    User developer
    IdentityFile ~/.ssh/server2_key

# 跳板机配置
Host internal-server
    HostName 10.0.0.100
    User internal-user
    ProxyJump jump-server
    IdentityFile ~/.ssh/internal_key

Host jump-server
    HostName 192.168.1.200
    User jump-user
    IdentityFile ~/.ssh/jump_key

# 高级配置
Host production
    HostName prod.example.com
    User deploy
    Port 2222
    IdentityFile ~/.ssh/prod_key
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ForwardAgent yes
```

### 3.3 使用配置文件连接
```bash
# 使用配置的别名连接
ssh myserver

# 等同于
ssh -i ~/.ssh/id_ed25519 myuser@192.168.1.100
```

## 4. 端口转发

### 4.1 本地端口转发
```bash
# 将本地端口8080转发到远程服务器的80端口
ssh -L 8080:localhost:80 user@192.168.1.100

# 转发到远程服务器的其他地址
ssh -L 8080:192.168.1.200:80 user@192.168.1.100

# 后台运行端口转发
ssh -f -N -L 8080:localhost:80 user@192.168.1.100
```

### 4.2 远程端口转发
```bash
# 将远程端口8080转发到本地80端口
ssh -R 8080:localhost:80 user@192.168.1.100

# 后台运行
ssh -f -N -R 8080:localhost:80 user@192.168.1.100
```

### 4.3 动态端口转发（SOCKS代理）
```bash
# 创建SOCKS代理
ssh -D 1080 user@192.168.1.100

# 后台运行
ssh -f -N -D 1080 user@192.168.1.100
```

## 5. 文件传输

### 5.1 使用scp传输文件
```bash
# 上传文件到服务器
scp local_file.txt user@192.168.1.100:/remote/path/

# 下载文件从服务器
scp user@192.168.1.100:/remote/path/file.txt ./

# 传输整个目录
scp -r local_directory/ user@192.168.1.100:/remote/path/

# 使用指定端口
scp -P 2222 local_file.txt user@192.168.1.100:/remote/path/
```

### 5.2 使用rsync同步文件
```bash
# 同步目录到服务器
rsync -avz local_directory/ user@192.168.1.100:/remote/path/

# 从服务器同步目录
rsync -avz user@192.168.1.100:/remote/path/ local_directory/

# 排除某些文件
rsync -avz --exclude='*.log' --exclude='tmp/' local_directory/ user@192.168.1.100:/remote/path/

# 使用SSH端口
rsync -avz -e "ssh -p 2222" local_directory/ user@192.168.1.100:/remote/path/
```

### 5.3 使用sftp交互式传输
```bash
# 连接SFTP
sftp user@192.168.1.100

# SFTP常用命令
sftp> ls                    # 列出远程文件
sftp> lls                   # 列出本地文件
sftp> put local_file.txt    # 上传文件
sftp> get remote_file.txt   # 下载文件
sftp> mkdir new_dir         # 创建远程目录
sftp> rmdir old_dir         # 删除远程目录
sftp> exit                  # 退出
```

## 6. 高级功能

### 6.1 保持连接
```bash
# 在SSH配置文件中添加
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

### 6.2 多路复用连接
```bash
# 在SSH配置文件中添加
Host *
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 10m
```

### 6.3 执行远程命令
```bash
# 执行单个命令
ssh user@192.168.1.100 "ls -la"

# 执行脚本
ssh user@192.168.1.100 "bash -s" < local_script.sh

# 执行多个命令
ssh user@192.168.1.100 "cd /tmp && ls -la && pwd"
```

### 6.4 图形界面转发
```bash
# 启用X11转发
ssh -X user@192.168.1.100

# 启用可信X11转发
ssh -Y user@192.168.1.100
```

## 7. 安全最佳实践

### 7.1 禁用密码认证
```bash
# 在服务器上编辑SSH配置
sudo nano /etc/ssh/sshd_config

# 添加或修改以下行
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
```

### 7.2 更改默认端口
```bash
# 在服务器SSH配置中
Port 2222
```

### 7.3 限制用户访问
```bash
# 只允许特定用户
AllowUsers user1 user2

# 只允许特定组
AllowGroups ssh-users
```

### 7.4 使用防火墙
```bash
# 使用ufw限制SSH访问
sudo ufw allow from 192.168.1.0/24 to any port 22
sudo ufw deny 22
```

## 8. 故障排除

### 8.1 常见问题解决
```bash
# 检查SSH连接
ssh -v user@192.168.1.100

# 检查SSH服务状态
sudo systemctl status sshd

# 查看SSH日志
sudo journalctl -u sshd

# 测试端口连通性
telnet 192.168.1.100 22
nc -zv 192.168.1.100 22
```

### 8.2 密钥问题
```bash
# 检查密钥权限
ls -la ~/.ssh/

# 重新生成密钥
ssh-keygen -R 192.168.1.100

# 测试密钥连接
ssh -i ~/.ssh/id_ed25519 -v user@192.168.1.100
```

## 9. 实用脚本

### 9.1 批量连接脚本
```bash
#!/bin/bash
# 批量SSH连接脚本

servers=(
    "user1@192.168.1.101"
    "user2@192.168.1.102"
    "user3@192.168.1.103"
)

for server in "${servers[@]}"; do
    echo "Connecting to $server..."
    ssh -o ConnectTimeout=10 "$server" "echo 'Connected successfully'"
done
```

### 9.2 自动备份脚本
```bash
#!/bin/bash
# 自动备份脚本

SOURCE_DIR="/path/to/source"
BACKUP_SERVER="user@192.168.1.100"
BACKUP_DIR="/path/to/backup"

rsync -avz --delete "$SOURCE_DIR/" "$BACKUP_SERVER:$BACKUP_DIR/"
```

## 10. 常用别名

在 `~/.bashrc` 或 `~/.zshrc` 中添加：
```bash
# SSH别名
alias ssh-prod='ssh user@prod.example.com'
alias ssh-dev='ssh user@dev.example.com'
alias ssh-test='ssh user@test.example.com'

# 快速文件传输
alias scp-prod='scp user@prod.example.com:'
alias rsync-prod='rsync -avz user@prod.example.com:'
```

这个指南涵盖了SSH连接的所有主要方面，从基本连接到高级配置。根据你的具体需求，可以选择相应的部分进行学习和使用。 