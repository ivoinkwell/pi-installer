[🇨🇳 中文](./README_CN.md)

# Pi Agent & Pi-Web One-Click Installer

Automated installation script for Pi Agent and Pi-Web with autostart, password protection, and Cloudflare Tunnel configuration.

## 🚀 Usage

Regular user:

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh | sudo bash
```

Root user:

```bash
curl -fsSL https://raw.githubusercontent.com/your-username/repo-name/main/pi-installer/install-pi.sh | bash
```

## 📋 Features

- ✅ Auto-detect and install dependencies (Node.js, npm)
- ✅ Install/update latest Pi Agent and Pi-Web
- ✅ Configure systemd autostart
- ✅ Interactive setup for port, password, and domain
- ✅ Print complete configuration info

## ⚙️ Interactive Configuration

| Step | Option | Description |
|------|--------|-------------|
| ① | Port | Pi-Web listening port, default 30141 |
| ② | Password | Remote access authentication, leave empty to disable |
| ③ | Tunnel Domain | Cloudflare Tunnel domain, leave empty to skip |
| ④ | LAN Port | Password-free LAN access port, leave empty to skip |

## 🌐 Access After Installation

After installation, access Pi-Web based on your configuration:

| Scenario | Address |
|----------|--------|
| Local | `http://127.0.0.1:30141` |
| Cloudflare Tunnel | `https://your-domain.com` |
| LAN Password-free | `http://LAN-IP:8080` |

Default credentials (if password was set):
- Username: `pi`
- Password: your configured password

## 📁 Installed Files

| File | Path |
|------|------|
| Start script | `/usr/local/bin/start-pi-web` |
| Service file | `/etc/systemd/system/pi-web.service` |
| Pi config | `~/.pi/agent/` |

## 🛠️ Service Management

```bash
systemctl start pi-web      # Start
systemctl stop pi-web       # Stop
systemctl restart pi-web    # Restart
systemctl status pi-web     # Status
journalctl -u pi-web -f     # Logs
start-pi-web                # Manual start
```

## 🗑️ Uninstall

```bash
systemctl stop pi-web && systemctl disable pi-web
rm /etc/systemd/system/pi-web.service /usr/local/bin/start-pi-web
systemctl daemon-reload
npm uninstall -g @earendil-works/pi-coding-agent @agegr/pi-web
```