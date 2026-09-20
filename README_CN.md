[🇬🇧 English](./README.md)

# Pi Agent & Pi-Web 一键安装脚本

一行命令自动安装 Pi Agent 和 Pi-Web，配置自启动、访问密码和 Cloudflare Tunnel 域名。

> **前置要求：** 使用 **systemd** 的 Linux 发行版，以及 root 权限。脚本是**交互式**的。

## 🚀 使用方法

推荐先下载再执行（可以先看一眼脚本内容再运行）：

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh -o install-pi.sh
sudo bash install-pi.sh
```

如果当前已经是 root，直接 `bash install-pi.sh`，不需要 `sudo`。

管道方式同样可用，因为脚本的交互输入全部从 `/dev/tty` 读取：

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh | sudo bash
```

## 📋 脚本功能

- ✅ 自动检测并安装依赖（Node.js 22+、npm）
- ✅ 安装/更新最新版 Pi Agent 和 Pi-Web
- ✅ 配置 systemd 开机自启动
- ✅ 交互式设置端口、密码、域名
- ✅ 凭证存放在仅 root 可读的配置文件（`600`），不写进启动脚本
- ✅ 内网免密实例只绑定**内网** IP，绝不绑 `0.0.0.0`
- ✅ 打印完整配置信息

## ⚙️ 交互式配置

| 步骤 | 配置项 | 说明 |
|------|--------|------|
| ① | 端口号 | Pi-Web 监听端口，默认 30141 |
| ② | 访问密码 | 远程访问认证，留空不设密码 |
| ③ | Tunnel 域名 | Cloudflare Tunnel 域名，留空不配置 |
| ④ | 内网免密端口 | 内网免密访问。只绑定检测到的**内网** IP，且需要二次确认。留空不开启 |

## 🌐 安装后访问方式

| 场景 | 地址 |
|------|------|
| 本地访问 | `http://127.0.0.1:30141` |
| Cloudflare Tunnel | `https://你的域名` |
| 内网免密访问 | `http://内网IP:8080` |

登录凭证（如果设置了密码）：
- 用户名：`pi`
- 密码：你设置的密码

## 📁 安装后文件位置

| 文件 | 路径 | 权限 |
|------|------|------|
| 启动脚本 | `/usr/local/bin/start-pi-web` | `700` |
| 配置与凭证 | `/etc/pi-web/pi-web.env` | `600` |
| 服务文件 | `/etc/systemd/system/pi-web.service` | `644` |
| Pi 配置 | `~/.pi/agent/` | — |

## 🛠️ 服务管理

```bash
systemctl start pi-web      # 启动
systemctl stop pi-web       # 停止
systemctl restart pi-web    # 重启
systemctl status pi-web     # 状态
journalctl -u pi-web -f     # 日志
start-pi-web                # 手动启动
```

## 🔐 安全说明

- 凭证放在 `/etc/pi-web/pi-web.env`，仅 root 可读（`600`），启动脚本内不含任何密码。
- 内网免密实例会绑定到内网 IP（`10.x` / `172.16-31.x` / `192.168.x`）。如果检测到的是公网 IP，脚本会拒绝开启。
- 该实例**没有密码**。请务必确认防火墙 / 云安全组不会把该端口暴露到公网——任何能访问该端口的人都将获得 Pi Agent 的完整权限。
- 如果 Pi-Web 需要从公网访问，请务必设置密码，最好配合 Cloudflare Tunnel。
- 两个实例共用 `~/.pi/agent`。开启免密实例是有意为之的取舍，不是默认行为。

## 🗑️ 卸载

```bash
systemctl stop pi-web && systemctl disable pi-web
rm -f /etc/systemd/system/pi-web.service /usr/local/bin/start-pi-web
rm -rf /etc/pi-web
systemctl daemon-reload
npm uninstall -g @earendil-works/pi-coding-agent @agegr/pi-web
```
