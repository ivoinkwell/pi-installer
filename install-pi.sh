#!/bin/bash
# Pi Agent & Pi-Web 一键安装脚本
# 适用于所有 Linux 发行版 (Ubuntu/Debian/CentOS/RHEL/Fedora/Arch)
# 用法: curl -fsSL https://你的地址/install-pi.sh | sudo bash

set -e

# ─────────────── 颜色 ───────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
die()   { echo -e "${RED}[FAIL]${NC}  $1"; exit 1; }

# ─────────────── Banner ───────────────
echo -e "${CYAN}"
cat << 'BANNER'
  ____  _           _           _
 |  _ \(_)_ __   __| | ___ _ __(_)_ __   __ _
 | |_) | | '_ \ / _` |/ _ \ '__| | '_ \ / _` |
 |  __/| | |_) | (_| |  __/ |  | | | | | (_| |
 |_|   |_| .__/ \__,_|\___|_|  |_|_| |_|\__, |
         |_|                              |___/
BANNER
echo -e "${NC}"

# ─────────────── Root 检查 ───────────────
[ "$(id -u)" -eq 0 ] || die "请使用 root 运行: sudo bash $0"

# ─────────────── 询问是否安装 ───────────────
ask_install() {
    local name="$1"
    echo ""
    echo -e "${YELLOW}  $name 未安装，是否自动安装？${NC}"
    echo -ne "  输入 y 安装，输入 n 退出安装脚本: "
    read -r answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# ─────────────── 包管理器检测 ───────────────
detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

install_pkg() {
    local pkg="$1"
    local mgr=$(detect_pkg_manager)
    case "$mgr" in
        apt)     apt-get update -qq && apt-get install -y "$pkg" ;;
        dnf)     dnf install -y "$pkg" ;;
        yum)     yum install -y "$pkg" ;;
        pacman)  pacman -S --noconfirm "$pkg" ;;
        zypper)  zypper install -y "$pkg" ;;
        *)       return 1 ;;
    esac
}

# ─────────────── 系统检测 ───────────────
info "检测系统环境..."

# curl 检查
if ! command -v curl &>/dev/null; then
    if ask_install "curl"; then
        install_pkg curl || die "curl 安装失败"
        ok "curl 已安装"
    else
        die "curl 是必需组件，无法继续安装"
    fi
else
    ok "curl $(curl --version 2>/dev/null | head -1 | awk '{print $2}')"
fi

# ca-certificates 检查
if ! rpm -q ca-certificates &>/dev/null 2>&1 && ! dpkg -l ca-certificates &>/dev/null 2>&1; then
    if ask_install "ca-certificates"; then
        install_pkg ca-certificates 2>/dev/null || true
    else
        warn "ca-certificates 未安装，可能影响 HTTPS 连接"
    fi
fi

# ─────────────── Node.js 检查 ───────────────
NEED_NODE=0
if command -v node &>/dev/null; then
    NODE_MAJOR=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_MAJOR" -lt 22 ]; then
        warn "Node.js 版本过低: $(node -v)，需要 22+"
        NEED_NODE=1
    else
        ok "Node.js $(node -v)"
    fi
else
    warn "Node.js 未安装"
    NEED_NODE=1
fi

if [ "$NEED_NODE" -eq 1 ]; then
    if ask_install "Node.js 22+"; then
        info "正在安装 Node.js 22..."
        
        DISTRO_ID="unknown"
        [ -f /etc/os-release ] && . /etc/os-release && DISTRO_ID="${ID:-unknown}"

        case "$DISTRO_ID" in
            ubuntu|debian|linuxmint|pop)
                curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
                apt-get install -y nodejs
                ;;
            centos|rhel|fedora|rocky|alma|ol)
                curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
                if command -v dnf &>/dev/null; then
                    dnf install -y nodejs
                else
                    yum install -y nodejs
                fi
                ;;
            arch|manjaro)
                pacman -S --noconfirm nodejs npm
                ;;
            *)
                if command -v apt-get &>/dev/null; then
                    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
                    apt-get install -y nodejs
                elif command -v dnf &>/dev/null; then
                    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
                    dnf install -y nodejs
                elif command -v yum &>/dev/null; then
                    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
                    yum install -y nodejs
                else
                    die "无法自动安装 Node.js，请手动安装 22+ 版本"
                fi
                ;;
        esac

        command -v node &>/dev/null || die "Node.js 安装失败"
        NODE_MAJOR=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        [ "$NODE_MAJOR" -ge 22 ] || die "Node.js 安装后版本仍低于 22 (当前: $(node -v))"
        ok "Node.js $(node -v) 安装成功"
    else
        die "Node.js 是必需组件，无法继续安装"
    fi
fi

# npm 检查
if ! command -v npm &>/dev/null; then
    if ask_install "npm"; then
        info "npm 通常随 Node.js 一起安装，请确认 Node.js 安装正确"
        command -v npm &>/dev/null || die "npm 安装失败，请重新安装 Node.js"
    else
        die "npm 是必需组件，无法继续安装"
    fi
fi

ok "npm $(npm -v)"

# ─────────────── 安装 Pi Agent ───────────────
info "安装 Pi Agent..."
if command -v pi &>/dev/null; then
    warn "Pi Agent 已存在，正在更新..."
    npm update -g @earendil-works/pi-coding-agent 2>/dev/null || true
else
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent 2>/dev/null || \
    npm install -g @earendil-works/pi-coding-agent
fi

command -v pi &>/dev/null || die "Pi Agent 安装失败"
ok "Pi Agent $(pi --version 2>/dev/null || echo '已安装')"

# ─────────────── 安装 Pi-Web ───────────────
info "安装 Pi-Web..."
if command -v pi-web &>/dev/null; then
    warn "Pi-Web 已存在，正在更新..."
    npm update -g @agegr/pi-web 2>/dev/null || true
else
    npm install -g @agegr/pi-web
fi

command -v pi-web &>/dev/null || die "Pi-Web 安装失败"
PI_WEB_VER=$(npm list -g @agegr/pi-web --depth=0 2>/dev/null | grep '@agegr/pi-web' | awk '{print $3}' || echo "已安装")
ok "Pi-Web $PI_WEB_VER"

# ─────────────── Pi Agent 配置目录 ───────────────
info "初始化配置目录..."
mkdir -p ~/.pi/agent
ok "配置目录 ~/.pi/agent 已就绪"

# ─────────────── 用户交互 ───────────────
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${YELLOW}接下来请输入配置信息（直接回车使用默认值）${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 端口
echo -ne "${CYAN}① Pi-Web 端口号 [默认 30141]: ${NC}"
read -r PI_PORT
PI_PORT=${PI_PORT:-30141}

# 密码
echo ""
echo -ne "${CYAN}② 访问密码（留空不设密码）: ${NC}"
read -s PI_PASSWORD
echo ""

# 域名
echo ""
echo -e "${CYAN}③ Cloudflare Tunnel 域名（留空不配置）:${NC}"
echo -ne "   示例: pi.example.com → "
read -r CF_DOMAIN

# 内网免密端口
echo ""
echo -e "${CYAN}④ 内网免密访问端口（留空不开启）:${NC}"
echo -e "   ${YELLOW}开启后可通过该端口免密码访问 Pi-Web${NC}"
echo -ne "   示例: 8080 → "
read -r LAN_PORT

# ─────────────── 生成启动脚本 ───────────────
info "生成启动脚本..."

cat > /usr/local/bin/start-pi-web << 'EOF'
#!/bin/bash
# Pi-Web 启动脚本 (自动生成)
export PI_WEB_HOSTNAME="0.0.0.0"
export PI_WEB_NO_OPEN=1
EOF

echo "export PI_WEB_PORT=\"$PI_PORT\"" >> /usr/local/bin/start-pi-web

[ -n "$PI_PASSWORD" ] && \
echo "export PI_WEB_PASSWORD=\"$PI_PASSWORD\"" >> /usr/local/bin/start-pi-web

[ -n "$CF_DOMAIN" ] && \
echo "export PI_WEB_ALLOWED_HOSTS=\"$CF_DOMAIN\"" >> /usr/local/bin/start-pi-web

# 如果设置了内网免密端口，需要在启动后额外启动一个无密码的实例
[ -n "$LAN_PORT" ] && cat >> /usr/local/bin/start-pi-web << LANEOF

# 内网免密访问实例
LAN_PORT="$LAN_PORT"
LANEOF

cat >> /usr/local/bin/start-pi-web << 'EOF'

echo "🚀 Pi-Web 启动中... 端口: $PI_WEB_PORT"
pi-web --hostname 0.0.0.0 --port "$PI_WEB_PORT" --no-open &

# 启动内网免密实例（如果配置了）
if [ -n "$LAN_PORT" ]; then
    echo "🚀 Pi-Web 内网免密实例启动中... 端口: $LAN_PORT"
    PI_WEB_PASSWORD="" pi-web --hostname 0.0.0.0 --port "$LAN_PORT" --no-open &
fi

wait
EOF

chmod +x /usr/local/bin/start-pi-web
ok "启动脚本: /usr/local/bin/start-pi-web"

# ─────────────── systemd 服务 ───────────────
info "配置开机自启动..."

cat > /etc/systemd/system/pi-web.service << 'EOF'
[Unit]
Description=Pi Web Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/start-pi-web
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pi-web.service >/dev/null 2>&1
systemctl restart pi-web.service
ok "服务已启动并设置为开机自启"

sleep 2

if systemctl is-active --quiet pi-web.service; then
    ok "Pi-Web 服务运行正常"
else
    warn "Pi-Web 服务可能未正常启动，请检查: journalctl -u pi-web -n 20"
fi

# ─────────────── 输出结果 ───────────────
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  ✅ 安装完成！                     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Pi Agent:${NC}    $(pi --version 2>/dev/null || echo '已安装')"
echo -e "  ${GREEN}Pi-Web:${NC}      $PI_WEB_VER"
echo ""
echo -e "  ${GREEN}访问地址:${NC}    http://127.0.0.1:${PI_PORT}"

[ -n "$CF_DOMAIN" ] && \
echo -e "  ${GREEN}远程地址:${NC}    https://${CF_DOMAIN}"

if [ -n "$PI_PASSWORD" ]; then
    echo ""
    echo -e "  ${GREEN}用户名:${NC}      pi"
    echo -e "  ${GREEN}密  码:${NC}      $PI_PASSWORD"
fi

if [ -n "$LAN_PORT" ]; then
    echo ""
    echo -e "  ${GREEN}内网免密:${NC}    http://内网IP:${LAN_PORT}"
fi

echo ""
echo -e "  ${YELLOW}常用命令:${NC}"
echo -e "    重启服务:  systemctl restart pi-web"
echo -e "    停止服务:  systemctl stop pi-web"
echo -e "    查看状态:  systemctl status pi-web"
echo -e "    查看日志:  journalctl -u pi-web -f"
echo -e "    手动启动:  start-pi-web"
echo ""