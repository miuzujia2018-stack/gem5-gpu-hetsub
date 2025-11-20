# SSH 连接工具集

这个工具集提供了完整的SSH连接解决方案，包括详细指南、实用脚本和快速参考。

## 📁 文件说明

### 📖 文档文件

1. **`SSH_Connection_Guide.md`** - 完整的SSH连接指南
   - 基本连接方法
   - SSH密钥认证设置
   - 配置文件管理
   - 端口转发
   - 文件传输
   - 高级功能
   - 安全最佳实践
   - 故障排除

2. **`SSH_Quick_Reference.md`** - 快速参考卡片
   - 最常用的SSH命令
   - 实用脚本示例
   - 性能优化技巧
   - 安全设置

3. **`ssh_config_example`** - SSH配置文件示例
   - 各种服务器配置示例
   - 跳板机配置
   - 高级配置选项

### 🛠️ 实用脚本

4. **`ssh_connect.sh`** - SSH连接工具脚本
   ```bash
   # 使用方法
   ./ssh_connect.sh [选项] [服务器名]
   
   # 常用选项
   -h, --help          显示帮助信息
   -u, --user USER     指定用户名
   -p, --port PORT     指定端口号
   -i, --identity FILE 指定SSH密钥文件
   -v, --verbose       详细输出
   -X, --x11           启用X11转发
   -D, --dynamic PORT  启用动态端口转发
   -L, --local PORT    启用本地端口转发
   -R, --remote PORT   启用远程端口转发
   -l, --list          列出可用的服务器
   -c, --config        编辑SSH配置文件
   ```

5. **`setup_ssh.sh`** - SSH环境快速设置脚本
   ```bash
   # 使用方法
   ./setup_ssh.sh [选项]
   
   # 常用选项
   -h, --help          显示帮助信息
   -i, --init          初始化SSH环境
   -k, --keygen        生成SSH密钥对
   -c, --config        创建SSH配置文件
   -s, --setup         完整设置（初始化+密钥+配置）
   -p, --permissions   设置正确的文件权限
   -t, --test          测试SSH配置
   ```

## 🚀 快速开始

### 1. 完整设置（推荐）
```bash
# 运行完整设置脚本
./setup_ssh.sh -s
```

### 2. 分步设置
```bash
# 初始化SSH环境
./setup_ssh.sh -i

# 生成SSH密钥
./setup_ssh.sh -k

# 创建配置文件
./setup_ssh.sh -c

# 设置权限
./setup_ssh.sh -p

# 测试配置
./setup_ssh.sh -t
```

### 3. 使用连接工具
```bash
# 查看帮助
./ssh_connect.sh -h

# 列出可用服务器
./ssh_connect.sh -l

# 连接到服务器
./ssh_connect.sh myserver

# 使用指定用户和端口
./ssh_connect.sh -u admin -p 2222 server1

# 创建SOCKS代理
./ssh_connect.sh -D 1080 proxy-server
```

## 📋 配置SSH服务器

### 1. 编辑SSH配置文件
```bash
# 使用脚本编辑
./ssh_connect.sh -c

# 或手动编辑
nano ~/.ssh/config
```

### 2. 添加服务器配置
```bash
# 在 ~/.ssh/config 中添加
Host myserver
    HostName 192.168.1.100
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    ForwardX11 yes
```

### 3. 复制SSH密钥到服务器
```bash
# 使用ssh-copy-id
ssh-copy-id user@192.168.1.100

# 或使用脚本
./ssh_connect.sh -k user@192.168.1.100
```

## 🔧 常用操作

### 基本连接
```bash
# 使用配置文件中的别名
ssh myserver

# 直接连接
ssh user@192.168.1.100

# 指定端口
ssh -p 2222 user@192.168.1.100
```

### 文件传输
```bash
# 上传文件
scp file.txt user@192.168.1.100:/remote/path/

# 下载文件
scp user@192.168.1.100:/remote/path/file.txt ./

# 同步目录
rsync -avz local_dir/ user@192.168.1.100:/remote/path/
```

### 端口转发
```bash
# 本地端口转发
ssh -L 8080:localhost:80 user@192.168.1.100

# SOCKS代理
ssh -D 1080 user@192.168.1.100

# 后台运行
ssh -f -N -L 8080:localhost:80 user@192.168.1.100
```

## 🔒 安全建议

1. **使用密钥认证**
   - 生成强密钥：`ssh-keygen -t ed25519`
   - 禁用密码认证
   - 定期轮换密钥

2. **更改默认端口**
   - 修改SSH配置文件中的端口
   - 更新防火墙规则

3. **限制访问**
   - 使用防火墙限制IP访问
   - 只允许特定用户连接

4. **监控日志**
   - 定期检查SSH日志
   - 设置入侵检测

## 🐛 故障排除

### 常见问题

1. **连接被拒绝**
   ```bash
   # 检查SSH服务状态
   sudo systemctl status sshd
   
   # 检查端口
   nc -zv 192.168.1.100 22
   ```

2. **密钥认证失败**
   ```bash
   # 检查密钥权限
   ls -la ~/.ssh/
   
   # 测试密钥连接
   ssh -v -i ~/.ssh/id_ed25519 user@192.168.1.100
   ```

3. **配置文件问题**
   ```bash
   # 测试配置文件语法
   ssh -F ~/.ssh/config -T git@github.com
   ```

### 调试命令
```bash
# 详细输出
ssh -v user@192.168.1.100

# 查看SSH日志
sudo journalctl -u sshd

# 测试连接
./ssh_connect.sh -t
```

## 📚 学习资源

- **官方文档**: `man ssh`, `man ssh_config`
- **在线资源**: OpenSSH官方文档
- **安全指南**: SSH安全最佳实践

## 🤝 贡献

欢迎提交问题报告和改进建议！

## 📄 许可证

本工具集采用MIT许可证。

---

**提示**: 在使用这些工具之前，请确保了解SSH的基本概念和安全注意事项。 