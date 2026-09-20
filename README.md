[🇨🇳 中文](./README_CN.md)

# Pi Agent & Pi-Web One-Click Installer

Automated installation script for Pi Agent and Pi-Web with autostart, password protection, and Cloudflare Tunnel configuration.

> **Requirements:** a Linux distribution with **systemd**, plus root access. The script is **interactive**.

## 🚀 Usage

Download first — recommended, so you can read the script before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh -o install-pi.sh
sudo bash install-pi.sh
```

If you are already root, run `bash install-pi.sh` without `sudo`.

Piping works too, because the script reads all prompts from `/dev/tty`:

```bash
curl -fsSL https://raw.githubusercontent.com/ivoinkwell/pi-installer/main/install-pi.sh | sudo bash
```

## 📋 Features

- ✅ Auto-detect and install dependencies (Node.js 22+, npm)
- ✅ Install/update the latest Pi Agent and Pi-Web
- ✅ Configure systemd autostart
- ✅ Interactive setup for port, password, and domain
- ✅ Credentials stored in a root-only config file (`600`), not in the start script
- ✅ Password-free LAN instance binds to a **private** IP only, never `0.0.0.0`
- ✅ Print complete configuration info

## ⚙️ Interactive Configuration

| Step | Option | Description |
|------|--------|-------------|
| ① | Port | Pi-Web listening port, default 30141 |
| ② | Password | Remote access authentication, leave empty to disable |
| ③ | Tunnel Domain | Cloudflare Tunnel domain, leave empty to skip |
| ④ | LAN Port | Password-free LAN access. Binds to the detected **private** IP only and asks for confirmation. Leave empty to skip |

## 🌐 Access After Installation

| Scenario | Address |
|----------|---------|
| Local | `http://127.0.0.1:30141` |
| Cloudflare Tunnel | `https://your-domain.com` |
| LAN Password-free | `http://<private-IP>:8080` |

Default credentials (if a password was set):
- Username: `pi`
- Password: the password you configured

## 📁 Installed Files

| File | Path | Mode |
|------|------|------|
| Start script | `/usr/local/bin/start-pi-web` | `700` |
| Config & credentials | `/etc/pi-web/pi-web.env` | `600` |
| Service file | `/etc/systemd/system/pi-web.service` | `644` |
| Pi config | `~/.pi/agent/` | — |

## 🛠️ Service Management

```bash
systemctl start pi-web      # Start
systemctl stop pi-web       # Stop
systemctl restart pi-web    # Restart
systemctl status pi-web     # Status
journalctl -u pi-web -f     # Logs
start-pi-web                # Manual start
```

## 🔐 Security Notes

- Credentials live in `/etc/pi-web/pi-web.env`, readable by root only (`600`). The start script contains no secrets.
- The password-free LAN instance is bound to a private IP (`10.x` / `172.16-31.x` / `192.168.x`). The script refuses to start it on a public IP.
- That instance has **no password**. Make sure your firewall or cloud security group never exposes its port to the internet — anyone who reaches it gets full access to the Pi Agent.
- If Pi-Web is reachable from the internet, always set a password, preferably fronted by Cloudflare Tunnel.
- Both instances share `~/.pi/agent`. Running the password-free instance is a deliberate trade-off, not a default.

## 🗑️ Uninstall

```bash
systemctl stop pi-web && systemctl disable pi-web
rm -f /etc/systemd/system/pi-web.service /usr/local/bin/start-pi-web
rm -rf /etc/pi-web
systemctl daemon-reload
npm uninstall -g @earendil-works/pi-coding-agent @agegr/pi-web
```
