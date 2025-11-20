# SSH 快速参考卡片

## 🔑 基本连接

```bash
# 基本连接
ssh user@192.168.1.100

# 指定端口
ssh -p 2222 user@192.168.1.100

# 使用密钥
ssh -i ~/.ssh/my_key user@192.168.1.100

# 详细输出（调试）
ssh -v user@192.168.1.100
```

## 📁 文件传输

```bash
# 上传文件
scp file.txt user@192.168.1.100:/remote/path/

# 下载文件
scp user@192.168.1.100:/remote/path/file.txt ./

# 传输目录
scp -r local_dir/ user@192.168.1.100:/remote/path/

# 使用rsync同步
rsync -avz local_dir/ user@192.168.1.100:/remote/path/
```

## 🔄 端口转发

```bash
# 本地端口转发
ssh -L 8080:localhost:80 user@192.168.1.100

# 远程端口转发
ssh -R 8080:localhost:80 user@192.168.1.100

# SOCKS代理
ssh -D 1080 user@192.168.1.100

# 后台运行
ssh -f -N -L 8080:localhost:80 user@192.168.1.100
```

## 🎯 执行远程命令

```bash
# 执行单个命令
ssh user@192.168.1.100 "ls -la"

# 执行脚本
ssh user@192.168.1.100 "bash -s" < script.sh

# 执行多个命令
ssh user@192.168.1.100 "cd /tmp && ls -la && pwd"
```

## 🔧 密钥管理

```bash
# 生成密钥
ssh-keygen -t ed25519 -C "your_email@example.com"

# 复制密钥到服务器
ssh-copy-id user@192.168.1.100

# 手动复制密钥
cat ~/.ssh/id_ed25519.pub | ssh user@192.168.1.100 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

## 📋 配置文件 (~/.ssh/config)

```bash
# 基本配置
Host myserver
    HostName 192.168.1.100
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519

# 跳板机配置
Host internal
    HostName 10.0.0.100
    User internal-user
    ProxyJump jump-server

# 高级配置
Host production
    HostName prod.example.com
    User deploy
    Port 2222
    IdentityFile ~/.ssh/prod_key
    ServerAliveInterval 60
    ForwardAgent yes
```

## 🛠️ 实用脚本

### 批量连接
```bash
#!/bin/bash
servers=("user1@192.168.1.101" "user2@192.168.1.102")
for server in "${servers[@]}"; do
    ssh "$server" "echo 'Connected to $server'"
done
```

### 自动备份
```bash
#!/bin/bash
rsync -avz --delete /source/ user@192.168.1.100:/backup/
```

## 🔍 故障排除

```bash
# 测试连接
ssh -v user@192.168.1.100

# 检查端口
nc -zv 192.168.1.100 22

# 检查SSH服务
sudo systemctl status sshd

# 查看日志
sudo journalctl -u sshd
```

## ⚡ 常用别名

```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
alias ssh-prod='ssh user@prod.example.com'
alias ssh-dev='ssh user@dev.example.com'
alias scp-prod='scp user@prod.example.com:'
alias rsync-prod='rsync -avz user@prod.example.com:'
```

## 🎨 图形界面

```bash
# X11转发
ssh -X user@192.168.1.100

# 可信X11转发
ssh -Y user@192.168.1.100
```

## 🔒 安全设置

```bash
# 禁用密码认证（服务器端）
sudo nano /etc/ssh/sshd_config
# 添加: PasswordAuthentication no

# 更改默认端口
# 添加: Port 2222

# 重启SSH服务
sudo systemctl restart sshd
```

## 📊 性能优化

```bash
# 在 ~/.ssh/config 中添加
Host *
    Compression yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/control-%h-%p-%r
    ControlPersist 10m
```

## 🚀 快速设置

使用提供的脚本：
```bash
# 完整设置
./setup_ssh.sh -s

# 只生成密钥
./setup_ssh.sh -k

# 只创建配置
./setup_ssh.sh -c

# 测试配置
./setup_ssh.sh -t
```

---

**提示**: 
- 使用 `ssh -h` 查看所有选项
- 使用 `man ssh` 查看详细手册
- 配置文件可以大大简化连接过程
- 密钥认证比密码认证更安全 