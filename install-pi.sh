#!/bin/bash
# Pi Agent & Pi-Web 一键安装脚本
# 适用: 使用 systemd 的 Linux 发行版 (Ubuntu/Debian/CentOS/RHEL/Fedora/Arch/openSUSE)
# 用法: sudo bash install-pi.sh
#
# 本脚本是交互式的。推荐先下载再执行:
#   curl -fsSL <url> -o install-pi.sh && sudo bash install-pi.sh
# 也兼容 `curl -fsSL <url> | sudo bash`（脚本会从 /dev/tty 读取输入）

set -euo pipefail

# ─────────────── 颜色 ───────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
die()   { echo -e "${RED}[FAIL]${NC}  $1" >&2; exit 1; }

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

# ─────────────── 交互输入初始化 ───────────────
# 关键: `read` 默认从 stdin 读取。当脚本以 `curl | bash` 方式执行时，stdin 就是
# 脚本自身，read 会把脚本后续的行当作输入吞掉，导致脚本被破坏（后续命令丢失）。
# 因此这里把交互输入固定到终端 /dev/tty，避免触碰 bash 自身的脚本读取句柄。
HAS_TTY=0
if [ -t 0 ]; then
    HAS_TTY=1
elif [ -c /dev/tty ] && { true < /dev/tty; } 2>/dev/null; then
    HAS_TTY=1
fi

if [ "$HAS_TTY" -eq 0 ]; then
    die "无法获取交互终端（stdin 不是终端，且 /dev/tty 不可用）。
       本脚本需要交互输入，请改用:
         curl -fsSL <脚本地址> -o install-pi.sh && sudo bash install-pi.sh"
fi

# 读取一行输入: $1=变量名, $2=1 表示静默(密码)
# 始终返回 0，兼容 set -e / set -u
read_line() {
    local __var="$1" __silent="${2:-0}" __val=""
    if [ -t 0 ]; then
        if [ "$__silent" -eq 1 ]; then IFS= read -r -s __val || true
        else IFS= read -r __val || true; fi
    else
        if [ "$__silent" -eq 1 ]; then IFS= read -r -s __val < /dev/tty || true
        else IFS= read -r __val < /dev/tty || true; fi
    fi
    printf -v "$__var" '%s' "$__val"
}

# ─────────────── 询问是否安装 ───────────────
ask_install() {
    local name="$1" answer=""
    echo ""
    echo -e "${YELLOW}  $name 未安装，是否自动安装？${NC}"
    echo -ne "  输入 y 安装，输入 n 退出安装脚本: "
    read_line answer
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
    case "$(detect_pkg_manager)" in
        apt)     apt-get update -qq && apt-get install -y "$pkg" ;;
        dnf)     dnf install -y "$pkg" ;;
        yum)     yum install -y "$pkg" ;;
        pacman)  pacman -S --noconfirm "$pkg" ;;
        zypper)  zypper install -y "$pkg" ;;
        *)       return 1 ;;
    esac
}

# ─────────────── 内网 IP 检测 ───────────────
detect_lan_ip() {
    local ip=""
    if command -v ip &>/dev/null; then
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null \
              | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}' || true)"
    fi
    if [ -z "$ip" ] && command -v hostname &>/dev/null; then
        ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    fi
    printf '%s' "$ip"
}

# 仅接受 RFC1918 / 回环地址，避免把免密实例绑到公网 IP
is_private_ip() {
    case "$1" in
        10.*|192.168.*|127.*)                      return 0 ;;
        172.1[6-9].*|172.2[0-9].*|172.3[01].*)     return 0 ;;
        *)                                          return 1 ;;
    esac
}

is_valid_port() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) [ "$1" -ge 1 ] && [ "$1" -le 65535 ] ;;
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
MISSING_CA=0
if command -v dpkg &>/dev/null; then
    dpkg -s ca-certificates &>/dev/null || MISSING_CA=1
elif command -v rpm &>/dev/null; then
    rpm -q ca-certificates &>/dev/null || MISSING_CA=1
elif command -v pacman &>/dev/null; then
    pacman -Q ca-certificates &>/dev/null || MISSING_CA=1
fi

if [ "$MISSING_CA" -eq 1 ]; then
    if ask_install "ca-certificates"; then
        install_pkg ca-certificates || warn "ca-certificates 安装失败，可能影响 HTTPS 连接"
    else
        warn "ca-certificates 未安装，可能影响 HTTPS 连接"
    fi
fi

# ─────────────── Node.js 检查 ───────────────
NEED_NODE=0
if command -v node &>/dev/null; then
    NODE_MAJOR="$(node -v | cut -d'v' -f2 | cut -d'.' -f1)"
    case "$NODE_MAJOR" in
        ''|*[!0-9]*) warn "无法识别 Node.js 版本: $(node -v)"; NEED_NODE=1 ;;
        *) if [ "$NODE_MAJOR" -lt 22 ]; then
               warn "Node.js 版本过低: $(node -v)，需要 22+"
               NEED_NODE=1
           else
               ok "Node.js $(node -v)"
           fi ;;
    esac
else
    warn "Node.js 未安装"
    NEED_NODE=1
fi

if [ "$NEED_NODE" -eq 1 ]; then
    if ask_install "Node.js 22+"; then
        info "正在安装 Node.js 22..."

        DISTRO_ID="unknown"
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            DISTRO_ID="${ID:-unknown}"
        fi

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
        NODE_MAJOR="$(node -v | cut -d'v' -f2 | cut -d'.' -f1)"
        case "$NODE_MAJOR" in
            ''|*[!0-9]*) die "无法识别 Node.js 版本: $(node -v)" ;;
        esac
        [ "$NODE_MAJOR" -ge 22 ] || die "Node.js 安装后版本仍低于 22 (当前: $(node -v))"
        ok "Node.js $(node -v) 安装成功"
    else
        die "Node.js 是必需组件，无法继续安装"
    fi
fi

# npm 检查（真正尝试安装，而不是只打印一句提示）
if ! command -v npm &>/dev/null; then
    warn "npm 未安装"
    if ask_install "npm"; then
        install_pkg npm || warn "通过包管理器安装 npm 失败"
    fi
    command -v npm &>/dev/null || die "npm 是必需组件，请手动安装后重试"
fi

ok "npm $(npm -v)"

# ─────────────── 安装 Pi Agent ───────────────
info "安装/更新 Pi Agent..."
# 始终安装 latest，确保能跨大版本升级；不使用 --ignore-scripts（会跳过 postinstall，
# 可能留下缺少原生依赖但仍然"安装成功"的残废版本）
npm install -g --no-fund --no-audit @earendil-works/pi-coding-agent@latest \
    || die "Pi Agent 安装失败"

command -v pi &>/dev/null || die "Pi Agent 安装完成但未找到 pi 命令"
PI_AGENT_VER="$(pi --version 2>/dev/null || echo '已安装')"
ok "Pi Agent $PI_AGENT_VER"

# ─────────────── 安装 Pi-Web ───────────────
info "安装/更新 Pi-Web..."
npm install -g --no-fund --no-audit @agegr/pi-web@latest \
    || die "Pi-Web 安装失败"

command -v pi-web &>/dev/null || die "Pi-Web 安装完成但未找到 pi-web 命令"

# 版本号解析: npm list 输出形如 "`-- @agegr/pi-web@0.9.1"
PI_WEB_VER="$(npm list -g @agegr/pi-web --depth=0 2>/dev/null \
    | grep -oE '@agegr/pi-web@[^[:space:]]+' | head -1 \
    | sed 's#^@agegr/pi-web@##' || true)"
[ -n "$PI_WEB_VER" ] || PI_WEB_VER="已安装"
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

# ① 端口
echo -ne "${CYAN}① Pi-Web 端口号 [默认 30141]: ${NC}"
read_line PI_PORT
PI_PORT="${PI_PORT:-30141}"
if ! is_valid_port "$PI_PORT"; then
    warn "端口号 '$PI_PORT' 无效，回退到默认值 30141"
    PI_PORT=30141
fi

# ② 密码
echo ""
echo -ne "${CYAN}② 访问密码（留空不设密码）: ${NC}"
read_line PI_PASSWORD 1
echo ""

# ③ 域名
echo ""
echo -e "${CYAN}③ Cloudflare Tunnel 域名（留空不配置）:${NC}"
echo -ne "   示例: pi.example.com → "
read_line CF_DOMAIN

# ④ 内网免密端口
echo ""
echo -e "${CYAN}④ 内网免密访问端口（留空不开启）:${NC}"
echo -e "   ${RED}⚠ 该实例不设密码。一旦此端口可从公网访问，等于把 root 权限的${NC}"
echo -e "   ${RED}  Pi Agent 完全开放给任何人。${NC}"
echo -e "   ${YELLOW}脚本只会把它绑定到本机内网网卡（不会绑 0.0.0.0），仍需你确认。${NC}"
echo -ne "   示例: 8080 → "
read_line LAN_PORT

LAN_IP=""
if [ -n "$LAN_PORT" ]; then
    if ! is_valid_port "$LAN_PORT"; then
        warn "端口号 '$LAN_PORT' 无效，已跳过内网免密实例"
        LAN_PORT=""
    elif [ "$LAN_PORT" = "$PI_PORT" ]; then
        warn "内网免密端口与主端口相同，已跳过内网免密实例"
        LAN_PORT=""
    else
        LAN_IP="$(detect_lan_ip)"
        if [ -z "$LAN_IP" ]; then
            warn "未能检测到内网 IP，已跳过内网免密实例"
            LAN_PORT=""
        elif ! is_private_ip "$LAN_IP"; then
            warn "检测到的 IP ($LAN_IP) 不是内网地址，为安全起见已跳过内网免密实例"
            LAN_PORT=""
            LAN_IP=""
        else
            echo ""
            echo -e "   ${YELLOW}将开启免密实例:${NC} http://${LAN_IP}:${LAN_PORT}  ${RED}(无密码)${NC}"
            echo -e "   ${YELLOW}请确认防火墙 / 云安全组不会把该端口暴露到公网。${NC}"
            echo -ne "   ${YELLOW}确认开启？(y/N): ${NC}"
            read_line CONFIRM_LAN
            case "$CONFIRM_LAN" in
                [yY]|[yY][eE][sS])
                    ok "将绑定 ${LAN_IP}:${LAN_PORT}" ;;
                *)
                    LAN_PORT=""; LAN_IP=""
                    info "已取消内网免密实例" ;;
            esac
        fi
    fi
fi

# ─────────────── 生成配置文件（仅 root 可读） ───────────────
info "生成配置文件..."

PI_WEB_ENV_DIR="/etc/pi-web"
PI_WEB_ENV_FILE="$PI_WEB_ENV_DIR/pi-web.env"
mkdir -p "$PI_WEB_ENV_DIR"
chmod 700 "$PI_WEB_ENV_DIR"

# 用 printf %q 转义，确保密码含引号/$/反引号 等特殊字符时也不会破坏文件
# 用子 shell + umask 077，保证文件从创建那一刻起就是 600，不存在短暂可读窗口
(
    umask 077
    {
        printf '# Pi-Web 配置 — 由 install-pi.sh 生成。包含凭证，请勿泄漏。\n'
        printf 'PI_WEB_PORT=%q\n' "$PI_PORT"
        if [ -n "$PI_PASSWORD" ]; then
            printf 'PI_WEB_PASSWORD=%q\n' "$PI_PASSWORD"
        fi
        if [ -n "$CF_DOMAIN" ]; then
            printf 'PI_WEB_ALLOWED_HOSTS=%q\n' "$CF_DOMAIN"
        fi
        if [ -n "$LAN_PORT" ]; then
            printf 'LAN_PORT=%q\n' "$LAN_PORT"
            printf 'LAN_IP=%q\n' "$LAN_IP"
        fi
    } > "$PI_WEB_ENV_FILE"
)

chmod 600 "$PI_WEB_ENV_FILE"
ok "配置文件: $PI_WEB_ENV_FILE (权限 600)"

# ─────────────── 生成启动脚本 ───────────────
info "生成启动脚本..."

cat > /usr/local/bin/start-pi-web << 'EOF'
#!/bin/bash
# Pi-Web 启动脚本 (由 install-pi.sh 自动生成)
set -euo pipefail

ENV_FILE="/etc/pi-web/pi-web.env"
[ -r "$ENV_FILE" ] || { echo "缺少配置文件: $ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

export PI_WEB_HOSTNAME="0.0.0.0"
export PI_WEB_NO_OPEN=1
# 注意: pi-web 读取的端口环境变量名是 PORT（不是 PI_WEB_PORT）
export PORT="${PI_WEB_PORT:-30141}"

# 环境文件里是普通赋值，必须显式导出才会传给 pi-web
if [ -n "${PI_WEB_PASSWORD:-}" ]; then
    export PI_WEB_PASSWORD
fi
if [ -n "${PI_WEB_ALLOWED_HOSTS:-}" ]; then
    export PI_WEB_ALLOWED_HOSTS
fi

echo "🚀 Pi-Web 启动中... 端口: ${PORT}"
pi-web --hostname 0.0.0.0 --port "$PORT" --no-open &

# 内网免密实例: 仅在显式配置时启用，且只绑定内网网卡（不绑 0.0.0.0）
# 用 env -u 彻底移除 PI_WEB_PASSWORD（而不是设成空串），确保免密语义明确
if [ -n "${LAN_PORT:-}" ] && [ -n "${LAN_IP:-}" ]; then
    echo "🚀 Pi-Web 内网免密实例启动中... ${LAN_IP}:${LAN_PORT}"
    env -u PI_WEB_PASSWORD pi-web --hostname "$LAN_IP" --port "$LAN_PORT" --no-open &
fi

# 任一实例退出即整体退出，由 systemd 统一重启（避免某个实例挂掉后无人拉起）
if [ "${BASH_VERSINFO[0]}" -gt 4 ] || \
   { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -ge 3 ]; }; then
    wait -n || true
else
    wait || true
fi
EOF

chmod 700 /usr/local/bin/start-pi-web
ok "启动脚本: /usr/local/bin/start-pi-web (权限 700)"

# ─────────────── systemd 服务 ───────────────
HAVE_SYSTEMD=0
if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
    HAVE_SYSTEMD=1
fi

if [ "$HAVE_SYSTEMD" -eq 1 ]; then
    info "配置开机自启动..."

    cat > /etc/systemd/system/pi-web.service << 'EOF'
[Unit]
Description=Pi Web Server
After=network-online.target
Wants=network-online.target

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
    systemctl enable pi-web.service >/dev/null 2>&1 || warn "设置开机自启失败"
    systemctl restart pi-web.service || warn "服务启动失败"

    sleep 2
    if systemctl is-active --quiet pi-web.service; then
        ok "Pi-Web 服务运行正常，已设置为开机自启"
    else
        warn "Pi-Web 服务可能未正常启动，请检查: journalctl -u pi-web -n 20"
    fi
else
    warn "未检测到 systemd（容器 / WSL / 非 systemd 发行版），已跳过开机自启配置"
    warn "请手动执行启动: start-pi-web"
fi

# ─────────────── 输出结果 ───────────────
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  ✅ 安装完成！                     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Pi Agent:${NC}    $PI_AGENT_VER"
echo -e "  ${GREEN}Pi-Web:${NC}      $PI_WEB_VER"
echo ""
echo -e "  ${GREEN}访问地址:${NC}    http://127.0.0.1:${PI_PORT}"

if [ -n "$CF_DOMAIN" ]; then
    echo -e "  ${GREEN}远程地址:${NC}    https://${CF_DOMAIN}"
fi

if [ -n "$PI_PASSWORD" ]; then
    echo ""
    echo -e "  ${GREEN}用户名:${NC}      pi"
    echo -e "  ${GREEN}密  码:${NC}      $PI_PASSWORD"
fi

if [ -n "$LAN_PORT" ]; then
    echo ""
    echo -e "  ${RED}内网免密:${NC}    http://${LAN_IP}:${LAN_PORT}  (无密码，请勿暴露到公网)"
fi

echo ""
echo -e "  ${YELLOW}常用命令:${NC}"
if [ "$HAVE_SYSTEMD" -eq 1 ]; then
    echo -e "    重启服务:  systemctl restart pi-web"
    echo -e "    停止服务:  systemctl stop pi-web"
    echo -e "    查看状态:  systemctl status pi-web"
    echo -e "    查看日志:  journalctl -u pi-web -f"
fi
echo -e "    手动启动:  start-pi-web"
echo -e "    配置文件:  $PI_WEB_ENV_FILE"
echo ""
