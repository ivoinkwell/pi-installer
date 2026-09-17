[🇬🇧 English](./README.md)

# Pi Agent & Pi-Web 一键安装脚本

一行命令自动安装 Pi Agent 和 Pi-Web，配置自启动、访问密码和 Cloudflare Tunnel 域名。

## 🚀 使用方法

普通用户：

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh | sudo bash
```

Root 用户：

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh | bash
```

## 📋 脚本功能

- ✅ 自动检测并安装依赖（Node.js、npm）
- ✅ 安装/更新最新版 Pi Agent 和 Pi-Web
- ✅ 配置 systemd 开机自启动
- ✅ 交互式设置端口、密码、域名
- ✅ 打印完整配置信息

## ⚙️ 交互式配置

| 步骤 | 配置项 | 说明 |
|------|--------|------|
| ① | 端口号 | Pi-Web 监听端口，默认 30141 |
| ② | 访问密码 | 远程访问认证，留空不设密码 |
| ③ | Tunnel 域名 | Cloudflare Tunnel 域名，留空不配置 |
| ④ | 内网免密端口 | 内网免密访问端口，留空不开启 |

## 🌐 安装后访问方式

安装完成后，根据你的配置访问 Pi-Web：

| 场景 | 地址 |
|------|------|
| 本地访问 | `http://127.0.0.1:30141` |
| Cloudflare Tunnel | `https://你的域名` |
| 内网免密访问 | `http://内网IP:8080` |

登录凭证（如果设置了密码）：
- 用户名：`pi`
- 密码：你设置的密码

## 📁 安装后文件位置

| 文件 | 路径 |
|------|------|
| 启动脚本 | `/usr/local/bin/start-pi-web` |
| 服务文件 | `/etc/systemd/system/pi-web.service` |
| Pi 配置 | `~/.pi/agent/` |

## 🛠️ 服务管理

```bash
systemctl start pi-web      # 启动
systemctl stop pi-web       # 停止
systemctl restart pi-web    # 重启
systemctl status pi-web     # 状态
journalctl -u pi-web -f     # 日志
start-pi-web                # 手动启动
```

## 🗑️ 卸载

```bash
systemctl stop pi-web && systemctl disable pi-web
rm /etc/systemd/system/pi-web.service /usr/local/bin/start-pi-web
systemctl daemon-reload
npm uninstall -g @earendil-works/pi-coding-agent @agegr/pi-web
```