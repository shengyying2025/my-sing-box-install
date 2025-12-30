#!/bin/bash

# sing-box 一键安装脚本
# 支持 VLESS-Reality, Hysteria2, TUIC, VMess
# 作者: Your Name
# 项目地址: https://github.com/yourusername/sing-box-install

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
INSTALL_DIR="/usr/local/etc/sing-box"
CONFIG_FILE="${INSTALL_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
CERT_DIR="${INSTALL_DIR}/certs"
WEB_DIR="/var/www/html"

# 用户输入变量
DOMAIN=""
EMAIL=""
PORT_VLESS=443
PORT_HYSTERIA2=8443
PORT_TUIC=9443
PORT_VMESS=10443
UUID=""
PASSWORD=""
REALITY_PUBLIC_KEY=""
REALITY_PRIVATE_KEY=""
REALITY_SHORT_ID=""

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以 root 权限运行！"
        exit 1
    fi
}

# 检查系统是否为 Ubuntu
check_system() {
    print_info "检查操作系统..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "无法确定操作系统类型"
        exit 1
    fi
    
    if [[ "$OS" != "ubuntu" ]]; then
        print_error "此脚本仅支持 Ubuntu 系统！"
        print_error "检测到的系统: $OS"
        exit 1
    fi
    
    # 检查 Ubuntu 版本
    MAJOR_VERSION=$(echo $VERSION | cut -d. -f1)
    if [[ $MAJOR_VERSION -lt 20 ]]; then
        print_warning "建议使用 Ubuntu 20.04 或更高版本"
        read -p "是否继续安装？(y/n): " continue_install
        if [[ "$continue_install" != "y" ]]; then
            exit 0
        fi
    fi
    
    print_success "系统检查通过: Ubuntu $VERSION"
}

# 清理旧的代理程序
cleanup_old_proxies() {
    print_info "清理旧的代理程序..."
    
    # 停止并删除服务
    local services=("xray" "v2ray" "trojan" "sing-box" "hysteria" "naive")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            print_info "停止 $service 服务..."
            systemctl stop "$service"
            systemctl disable "$service"
        fi
        
        if [[ -f "/etc/systemd/system/${service}.service" ]]; then
            rm -f "/etc/systemd/system/${service}.service"
        fi
    done
    
    # 删除程序文件
    local programs=("/usr/local/bin/xray" "/usr/bin/xray" 
                   "/usr/local/bin/v2ray" "/usr/bin/v2ray"
                   "/usr/local/bin/trojan" "/usr/bin/trojan"
                   "/usr/local/bin/sing-box" "/usr/bin/sing-box"
                   "/usr/local/bin/hysteria" "/usr/bin/hysteria"
                   "/usr/local/bin/naive" "/usr/bin/naive")
    
    for program in "${programs[@]}"; do
        if [[ -f "$program" ]]; then
            print_info "删除 $program"
            rm -f "$program"
        fi
    done
    
    # 删除配置目录
    local configs=("/usr/local/etc/xray" "/etc/xray"
                  "/usr/local/etc/v2ray" "/etc/v2ray"
                  "/usr/local/etc/trojan" "/etc/trojan"
                  "/usr/local/etc/hysteria" "/etc/hysteria"
                  "/usr/local/etc/naive" "/etc/naive")
    
    for config in "${configs[@]}"; do
        if [[ -d "$config" ]]; then
            print_info "删除配置目录 $config"
            rm -rf "$config"
        fi
    done
    
    systemctl daemon-reload
    print_success "旧程序清理完成"
}

# 安装依赖
install_dependencies() {
    print_info "更新系统并安装依赖..."
    
    apt update
    apt install -y curl wget tar gzip openssl qrencode jq nginx certbot python3-certbot-nginx
    
    if [[ $? -ne 0 ]]; then
        print_error "依赖安装失败"
        exit 1
    fi
    
    print_success "依赖安装完成"
}

# 安装 sing-box
install_singbox() {
    print_info "安装 sing-box..."
    
    # 获取最新版本
    LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r '.tag_name' | sed 's/v//')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        print_error "无法获取 sing-box 最新版本"
        exit 1
    fi
    
    print_info "最新版本: $LATEST_VERSION"
    
    # 下载
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${LATEST_VERSION}/sing-box-${LATEST_VERSION}-linux-amd64.tar.gz"
    
    wget -O /tmp/sing-box.tar.gz "$DOWNLOAD_URL"
    
    if [[ $? -ne 0 ]]; then
        print_error "下载 sing-box 失败"
        exit 1
    fi
    
    # 解压安装
    tar -xzf /tmp/sing-box.tar.gz -C /tmp
    mv /tmp/sing-box-${LATEST_VERSION}-linux-amd64/sing-box /usr/local/bin/
    chmod +x /usr/local/bin/sing-box
    
    # 创建配置目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CERT_DIR"
    
    rm -rf /tmp/sing-box.tar.gz /tmp/sing-box-${LATEST_VERSION}-linux-amd64
    
    print_success "sing-box 安装完成 (版本: $LATEST_VERSION)"
}

# 生成 UUID
generate_uuid() {
    UUID=$(cat /proc/sys/kernel/random/uuid)
    print_success "生成 UUID: $UUID"
}

# 生成密码
generate_password() {
    PASSWORD=$(openssl rand -base64 32)
    print_success "生成密码: $PASSWORD"
}

# 生成 Reality 密钥对
generate_reality_keys() {
    print_info "生成 Reality 密钥对..."
    
    KEYS=$(sing-box generate reality-keypair)
    REALITY_PRIVATE_KEY=$(echo "$KEYS" | grep "PrivateKey" | awk '{print $2}')
    REALITY_PUBLIC_KEY=$(echo "$KEYS" | grep "PublicKey" | awk '{print $2}')
    
    print_success "Reality 私钥: $REALITY_PRIVATE_KEY"
    print_success "Reality 公钥: $REALITY_PUBLIC_KEY"
}

# 生成 Reality Short ID
generate_short_id() {
    REALITY_SHORT_ID=$(openssl rand -hex 8)
    print_success "生成 Short ID: $REALITY_SHORT_ID"
}

# 用户输入配置
get_user_input() {
    echo ""
    print_info "========================================="
    print_info "     sing-box 多协议配置向导"
    print_info "========================================="
    echo ""
    
    # 域名
    while true; do
        read -p "请输入你的域名 (例如: example.com): " DOMAIN
        if [[ -z "$DOMAIN" ]]; then
            print_error "域名不能为空！"
        else
            break
        fi
    done
    
    # 邮箱
    read -p "请输入你的邮箱 (用于申请证书，例如: admin@example.com): " EMAIL
    if [[ -z "$EMAIL" ]]; then
        EMAIL="admin@${DOMAIN}"
        print_warning "使用默认邮箱: $EMAIL"
    fi
    
    # 端口配置
    echo ""
    print_info "端口配置 (直接回车使用默认值)"
    read -p "VLESS-Reality 端口 [默认: 443]: " input_port
    PORT_VLESS=${input_port:-443}
    
    read -p "Hysteria2 端口 [默认: 8443]: " input_port
    PORT_HYSTERIA2=${input_port:-8443}
    
    read -p "TUIC 端口 [默认: 9443]: " input_port
    PORT_TUIC=${input_port:-9443}
    
    read -p "VMess 端口 [默认: 10443]: " input_port
    PORT_VMESS=${input_port:-10443}
    
    # 生成各种密钥
    echo ""
    print_info "生成配置参数..."
    generate_uuid
    generate_password
    generate_reality_keys
    generate_short_id
    
    # 确认信息
    echo ""
    print_info "========================================="
    print_info "配置信息确认"
    print_info "========================================="
    echo -e "${CYAN}域名:${NC} $DOMAIN"
    echo -e "${CYAN}邮箱:${NC} $EMAIL"
    echo -e "${CYAN}VLESS 端口:${NC} $PORT_VLESS"
    echo -e "${CYAN}Hysteria2 端口:${NC} $PORT_HYSTERIA2"
    echo -e "${CYAN}TUIC 端口:${NC} $PORT_TUIC"
    echo -e "${CYAN}VMess 端口:${NC} $PORT_VMESS"
    echo -e "${CYAN}UUID:${NC} $UUID"
    echo ""
    
    read -p "确认以上信息无误？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        print_info "已取消安装"
        exit 0
    fi
}

# 申请 SSL 证书
apply_certificate() {
    print_info "申请 SSL 证书..."
    
    # 停止可能占用 80 端口的服务
    systemctl stop nginx 2>/dev/null
    
    # 使用 standalone 模式申请证书
    certbot certonly --standalone --non-interactive --agree-tos \
        --email "$EMAIL" \
        -d "$DOMAIN"
    
    if [[ $? -ne 0 ]]; then
        print_error "证书申请失败！请检查："
        print_error "1. 域名是否正确解析到此服务器"
        print_error "2. 80 端口是否被占用"
        print_error "3. 防火墙是否开放 80 端口"
        exit 1
    fi
    
    # 复制证书到 sing-box 目录
    cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_DIR/cert.pem
    cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERT_DIR/key.pem
    
    chmod 644 $CERT_DIR/cert.pem
    chmod 600 $CERT_DIR/key.pem
    
    print_success "证书申请成功"
    
    # 设置证书自动续期
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_DIR/cert.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERT_DIR/key.pem && systemctl restart sing-box") | crontab -
    
    print_success "已设置证书自动续期"
}

# 生成配置文件
generate_config() {
    print_info "生成配置文件..."
    
    cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $PORT_VLESS,
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.yahoo.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.yahoo.com",
            "server_port": 443
          },
          "private_key": "$REALITY_PRIVATE_KEY",
          "short_id": ["$REALITY_SHORT_ID"]
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $PORT_HYSTERIA2,
      "users": [
        {
          "password": "$PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "$CERT_DIR/cert.pem",
        "key_path": "$CERT_DIR/key.pem"
      }
    },
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "::",
      "listen_port": $PORT_TUIC,
      "users": [
        {
          "uuid": "$UUID",
          "password": "$PASSWORD"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "$CERT_DIR/cert.pem",
        "key_path": "$CERT_DIR/key.pem"
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-in",
      "listen": "::",
      "listen_port": $PORT_VMESS,
      "users": [
        {
          "uuid": "$UUID",
          "alterId": 0
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "$CERT_DIR/cert.pem",
        "key_path": "$CERT_DIR/key.pem"
      },
      "transport": {
        "type": "ws",
        "path": "/vmess"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}
EOF
    
    print_success "配置文件生成完成"
}

# 创建 systemd 服务
create_service() {
    print_info "创建 systemd 服务..."
    
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c $CONFIG_FILE
Restart=on-failure
RestartSec=5s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable sing-box
    
    print_success "systemd 服务创建完成"
}

# 配置防火墙
configure_firewall() {
    print_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        ufw allow $PORT_VLESS/tcp
        ufw allow $PORT_HYSTERIA2/udp
        ufw allow $PORT_TUIC/udp
        ufw allow $PORT_VMESS/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        print_success "UFW 防火墙规则已添加"
    fi
    
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$PORT_VLESS/tcp
        firewall-cmd --permanent --add-port=$PORT_HYSTERIA2/udp
        firewall-cmd --permanent --add-port=$PORT_TUIC/udp
        firewall-cmd --permanent --add-port=$PORT_VMESS/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        print_success "firewalld 防火墙规则已添加"
    fi
}

# 生成订阅链接
generate_subscription() {
    print_info "生成订阅链接..."
    
    SERVER_IP=$(curl -s4 ifconfig.me)
    
    # VLESS Reality 链接
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.yahoo.com&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp&headerType=none#VLESS-Reality-${DOMAIN}"
    
    # Hysteria2 链接
    HY2_LINK="hysteria2://${PASSWORD}@${DOMAIN}:${PORT_HYSTERIA2}?sni=${DOMAIN}&alpn=h3#Hysteria2-${DOMAIN}"
    
    # TUIC 链接
    TUIC_LINK="tuic://${UUID}:${PASSWORD}@${DOMAIN}:${PORT_TUIC}?sni=${DOMAIN}&congestion_control=bbr&udp_relay_mode=native&alpn=h3#TUIC-${DOMAIN}"
    
    # VMess 链接
    VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "VMess-${DOMAIN}",
  "add": "${DOMAIN}",
  "port": "${PORT_VMESS}",
  "id": "${UUID}",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "/vmess",
  "tls": "tls",
  "sni": "${DOMAIN}",
  "alpn": ""
}
EOF
)
    VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"
    
    # 创建订阅页面目录
    mkdir -p "$WEB_DIR"
    
    # 生成单独的订阅文件
    echo "$VLESS_LINK" | base64 -w 0 > "${WEB_DIR}/vless"
    echo "$HY2_LINK" | base64 -w 0 > "${WEB_DIR}/hysteria2"
    echo "$TUIC_LINK" | base64 -w 0 > "${WEB_DIR}/tuic"
    echo "$VMESS_LINK" | base64 -w 0 > "${WEB_DIR}/vmess"
    
    # 生成聚合订阅
    cat > "${WEB_DIR}/all" <<EOF
$VLESS_LINK
$HY2_LINK
$TUIC_LINK
$VMESS_LINK
EOF
    
    # Base64 编码聚合订阅
    base64 -w 0 "${WEB_DIR}/all" > "${WEB_DIR}/subscription"
    
    # 生成 HTML 页面
    cat > "${WEB_DIR}/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>sing-box 订阅</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 { color: #333; text-align: center; }
        .section {
            margin: 20px 0;
            padding: 15px;
            background: #f9f9f9;
            border-radius: 5px;
        }
        .link {
            word-break: break-all;
            background: #fff;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 3px;
            margin: 10px 0;
            font-family: monospace;
            font-size: 12px;
        }
        .qr {
            text-align: center;
            margin: 20px 0;
        }
        button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            cursor: pointer;
            border-radius: 5px;
            margin: 5px;
        }
        button:hover { background: #45a049; }
        .info { color: #666; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 sing-box 订阅信息</h1>
        
        <div class="section">
            <h2>聚合订阅链接</h2>
            <div class="link">https://${DOMAIN}/subscription</div>
            <button onclick="copy('https://${DOMAIN}/subscription')">复制链接</button>
            <p class="info">适用于 Clash、V2Ray、小火箭等客户端</p>
        </div>
        
        <div class="section">
            <h2>单独订阅链接</h2>
            <h3>VLESS Reality</h3>
            <div class="link">https://${DOMAIN}/vless</div>
            <button onclick="copy('https://${DOMAIN}/vless')">复制</button>
            
            <h3>Hysteria2</h3>
            <div class="link">https://${DOMAIN}/hysteria2</div>
            <button onclick="copy('https://${DOMAIN}/hysteria2')">复制</button>
            
            <h3>TUIC</h3>
            <div class="link">https://${DOMAIN}/tuic</div>
            <button onclick="copy('https://${DOMAIN}/tuic')">复制</button>
            
            <h3>VMess</h3>
            <div class="link">https://${DOMAIN}/vmess</div>
            <button onclick="copy('https://${DOMAIN}/vmess')">复制</button>
        </div>
        
        <div class="section">
            <h2>服务器信息</h2>
            <p><strong>域名:</strong> ${DOMAIN}</p>
            <p><strong>IP:</strong> ${SERVER_IP}</p>
            <p><strong>VLESS 端口:</strong> ${PORT_VLESS}</p>
            <p><strong>Hysteria2 端口:</strong> ${PORT_HYSTERIA2}</p>
            <p><strong>TUIC 端口:</strong> ${PORT_TUIC}</p>
            <p><strong>VMess 端口:</strong> ${PORT_VMESS}</p>
        </div>
    </div>
    
    <script>
        function copy(text) {
            navigator.clipboard.writeText(text).then(() => {
                alert('已复制到剪贴板！');
            });
        }
    </script>
</body>
</html>
EOF
    
    # 配置 Nginx
    cat > /etc/nginx/sites-available/singbox <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    root ${WEB_DIR};
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/singbox /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx
    
    print_success "订阅页面生成完成"
}

# 启动服务
start_service() {
    print_info "启动 sing-box 服务..."
    
    systemctl start sing-box
    
    if systemctl is-active --quiet sing-box; then
        print_success "sing-box 服务启动成功"
    else
        print_error "sing-box 服务启动失败"
        print_error "请查看日志: journalctl -u sing-box -n 50"
        exit 1
    fi
}

# 显示结果
show_result() {
    clear
    SERVER_IP=$(curl -s4 ifconfig.me)
    
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}      sing-box 安装完成！${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    
    echo -e "${CYAN}订阅页面:${NC} http://${DOMAIN}"
    echo ""
    
    echo -e "${CYAN}聚合订阅链接 (适用于所有客户端):${NC}"
    echo -e "${YELLOW}https://${DOMAIN}/subscription${NC}"
    echo ""
    
    echo -e "${CYAN}生成二维码:${NC}"
    echo ""
    
    echo -e "${PURPLE}VLESS Reality:${NC}"
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.yahoo.com&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp&headerType=none#VLESS-Reality-${DOMAIN}"
    echo "$VLESS_LINK" | qrencode -t ANSIUTF8
    echo ""
    
    echo -e "${PURPLE}配置信息:${NC}"
    echo -e "域名: ${YELLOW}${DOMAIN}${NC}"
    echo -e "服务器 IP: ${YELLOW}${SERVER_IP}${NC}"
    echo -e "UUID: ${YELLOW}${UUID}${NC}"
    echo -e "密码: ${YELLOW}${PASSWORD}${NC}"
    echo -e "Reality 公钥: ${YELLOW}${REALITY_PUBLIC_KEY}${NC}"
    echo ""
    
    echo -e "${CYAN}管理命令:${NC}"
    echo -e "启动: ${YELLOW}systemctl start sing-box${NC}"
    echo -e "停止: ${YELLOW}systemctl stop sing-box${NC}"
    echo -e "重启: ${YELLOW}systemctl restart sing-box${NC}"
    echo -e "状态: ${YELLOW}systemctl status sing-box${NC}"
    echo -e "日志: ${YELLOW}journalctl -u sing-box -f${NC}"
    echo ""
    
    echo -e "${GREEN}配置文件位置:${NC} ${CONFIG_FILE}"
    echo -e "${GREEN}证书位置:${NC} ${CERT_DIR}"
    echo ""
    
    echo -e "${RED}重要提示:${NC}"
    echo -e "1. 请保存好 UUID 和密码等信息"
    echo -e "2. 防火墙请开放相应端口"
    echo -e "3. 证书将自动续期，无需手动操作"
    echo ""
}

# 保存配置信息
save_config_info() {
    cat > "${INSTALL_DIR}/config_info.txt" <<EOF
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}
PORT_VLESS=${PORT_VLESS}
PORT_HYSTERIA2=${PORT_HYSTERIA2}
PORT_TUIC=${PORT_TUIC}
PORT_VMESS=${PORT_VMESS}
UUID=${UUID}
PASSWORD=${PASSWORD}
REALITY_PUBLIC_KEY=${REALITY_PUBLIC_KEY}
REALITY_PRIVATE_KEY=${REALITY_PRIVATE_KEY}
REALITY_SHORT_ID=${REALITY_SHORT_ID}
SERVER_IP=$(curl -s4 ifconfig.me)
EOF
    chmod 600 "${INSTALL_DIR}/config_info.txt"
}

# 加载配置信息
load_config_info() {
    if [[ -f "${INSTALL_DIR}/config_info.txt" ]]; then
        source "${INSTALL_DIR}/config_info.txt"
        return 0
    else
        return 1
    fi
}

# 更新 sing-box
update_singbox() {
    clear
    print_info "开始更新 sing-box..."
    
    # 获取当前版本
    CURRENT_VERSION=$(/usr/local/bin/sing-box version 2>/dev/null | grep "version" | awk '{print $3}')
    print_info "当前版本: $CURRENT_VERSION"
    
    # 获取最新版本
    LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r '.tag_name' | sed 's/v//')
    print_info "最新版本: $LATEST_VERSION"
    
    if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
        print_success "已是最新版本，无需更新"
        read -p "按回车键继续..."
        return
    fi
    
    read -p "确认更新到 $LATEST_VERSION 版本？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        return
    fi
    
    # 停止服务
    systemctl stop sing-box
    
    # 下载新版本
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${LATEST_VERSION}/sing-box-${LATEST_VERSION}-linux-amd64.tar.gz"
    
    wget -O /tmp/sing-box.tar.gz "$DOWNLOAD_URL"
    
    if [[ $? -eq 0 ]]; then
        tar -xzf /tmp/sing-box.tar.gz -C /tmp
        mv /tmp/sing-box-${LATEST_VERSION}-linux-amd64/sing-box /usr/local/bin/
        chmod +x /usr/local/bin/sing-box
        rm -rf /tmp/sing-box.tar.gz /tmp/sing-box-${LATEST_VERSION}-linux-amd64
        
        # 重启服务
        systemctl start sing-box
        
        print_success "更新成功！新版本: $LATEST_VERSION"
    else
        print_error "下载失败"
        systemctl start sing-box
    fi
    
    read -p "按回车键继续..."
}

# 管理防火墙
manage_firewall() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}         防火墙管理${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    
    if ! load_config_info; then
        print_error "未找到配置信息"
        read -p "按回车键继续..."
        return
    fi
    
    echo "1. 查看防火墙状态"
    echo "2. 开放所有端口"
    echo "3. 关闭所有端口"
    echo "4. 自定义端口管理"
    echo "0. 返回主菜单"
    echo ""
    read -p "请选择: " choice
    
    case $choice in
        1)
            if command -v ufw &> /dev/null; then
                ufw status
            elif command -v firewall-cmd &> /dev/null; then
                firewall-cmd --list-all
            else
                print_warning "未检测到防火墙工具"
            fi
            ;;
        2)
            if command -v ufw &> /dev/null; then
                ufw allow $PORT_VLESS/tcp
                ufw allow $PORT_HYSTERIA2/udp
                ufw allow $PORT_TUIC/udp
                ufw allow $PORT_VMESS/tcp
                ufw allow 80/tcp
                ufw allow 443/tcp
                print_success "端口已全部开放"
            elif command -v firewall-cmd &> /dev/null; then
                firewall-cmd --permanent --add-port=$PORT_VLESS/tcp
                firewall-cmd --permanent --add-port=$PORT_HYSTERIA2/udp
                firewall-cmd --permanent --add-port=$PORT_TUIC/udp
                firewall-cmd --permanent --add-port=$PORT_VMESS/tcp
                firewall-cmd --permanent --add-port=80/tcp
                firewall-cmd --permanent --add-port=443/tcp
                firewall-cmd --reload
                print_success "端口已全部开放"
            fi
            ;;
        3)
            print_warning "此操作会关闭所有 sing-box 端口"
            read -p "确认关闭？(y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                if command -v ufw &> /dev/null; then
                    ufw delete allow $PORT_VLESS/tcp
                    ufw delete allow $PORT_HYSTERIA2/udp
                    ufw delete allow $PORT_TUIC/udp
                    ufw delete allow $PORT_VMESS/tcp
                    print_success "端口已关闭"
                elif command -v firewall-cmd &> /dev/null; then
                    firewall-cmd --permanent --remove-port=$PORT_VLESS/tcp
                    firewall-cmd --permanent --remove-port=$PORT_HYSTERIA2/udp
                    firewall-cmd --permanent --remove-port=$PORT_TUIC/udp
                    firewall-cmd --permanent --remove-port=$PORT_VMESS/tcp
                    firewall-cmd --reload
                    print_success "端口已关闭"
                fi
            fi
            ;;
        4)
            read -p "请输入端口号: " port
            read -p "协议 (tcp/udp): " protocol
            read -p "操作 (open/close): " action
            
            if [[ "$action" == "open" ]]; then
                if command -v ufw &> /dev/null; then
                    ufw allow $port/$protocol
                elif command -v firewall-cmd &> /dev/null; then
                    firewall-cmd --permanent --add-port=$port/$protocol
                    firewall-cmd --reload
                fi
                print_success "端口 $port/$protocol 已开放"
            elif [[ "$action" == "close" ]]; then
                if command -v ufw &> /dev/null; then
                    ufw delete allow $port/$protocol
                elif command -v firewall-cmd &> /dev/null; then
                    firewall-cmd --permanent --remove-port=$port/$protocol
                    firewall-cmd --reload
                fi
                print_success "端口 $port/$protocol 已关闭"
            fi
            ;;
        0)
            return
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 查看订阅信息
view_subscription() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}         订阅信息查询${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    
    if ! load_config_info; then
        print_error "未找到配置信息，请先完成安装"
        read -p "按回车键继续..."
        return
    fi
    
    echo -e "${GREEN}服务器信息:${NC}"
    echo -e "域名: ${YELLOW}${DOMAIN}${NC}"
    echo -e "IP: ${YELLOW}${SERVER_IP}${NC}"
    echo ""
    
    echo -e "${GREEN}端口配置:${NC}"
    echo -e "VLESS Reality: ${YELLOW}${PORT_VLESS}${NC}"
    echo -e "Hysteria2: ${YELLOW}${PORT_HYSTERIA2}${NC}"
    echo -e "TUIC: ${YELLOW}${PORT_TUIC}${NC}"
    echo -e "VMess: ${YELLOW}${PORT_VMESS}${NC}"
    echo ""
    
    echo -e "${GREEN}认证信息:${NC}"
    echo -e "UUID: ${YELLOW}${UUID}${NC}"
    echo -e "密码: ${YELLOW}${PASSWORD}${NC}"
    echo -e "Reality 公钥: ${YELLOW}${REALITY_PUBLIC_KEY}${NC}"
    echo -e "Reality Short ID: ${YELLOW}${REALITY_SHORT_ID}${NC}"
    echo ""
    
    echo -e "${GREEN}订阅链接:${NC}"
    echo -e "订阅页面: ${YELLOW}http://${DOMAIN}${NC}"
    echo -e "聚合订阅: ${YELLOW}https://${DOMAIN}/subscription${NC}"
    echo ""
    
    echo -e "${GREEN}单独订阅:${NC}"
    echo -e "VLESS: ${YELLOW}https://${DOMAIN}/vless${NC}"
    echo -e "Hysteria2: ${YELLOW}https://${DOMAIN}/hysteria2${NC}"
    echo -e "TUIC: ${YELLOW}https://${DOMAIN}/tuic${NC}"
    echo -e "VMess: ${YELLOW}https://${DOMAIN}/vmess${NC}"
    echo ""
    
    echo "1. 显示 VLESS 二维码"
    echo "2. 显示所有节点链接"
    echo "3. 复制聚合订阅到剪贴板"
    echo "0. 返回主菜单"
    echo ""
    read -p "请选择: " choice
    
    case $choice in
        1)
            VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.yahoo.com&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp&headerType=none#VLESS-Reality-${DOMAIN}"
            echo "$VLESS_LINK" | qrencode -t ANSIUTF8
            echo ""
            echo -e "${YELLOW}$VLESS_LINK${NC}"
            ;;
        2)
            echo ""
            echo -e "${PURPLE}VLESS Reality:${NC}"
            echo "vless://${UUID}@${SERVER_IP}:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.yahoo.com&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&type=tcp&headerType=none#VLESS-Reality-${DOMAIN}"
            echo ""
            echo -e "${PURPLE}Hysteria2:${NC}"
            echo "hysteria2://${PASSWORD}@${DOMAIN}:${PORT_HYSTERIA2}?sni=${DOMAIN}&alpn=h3#Hysteria2-${DOMAIN}"
            echo ""
            echo -e "${PURPLE}TUIC:${NC}"
            echo "tuic://${UUID}:${PASSWORD}@${DOMAIN}:${PORT_TUIC}?sni=${DOMAIN}&congestion_control=bbr&udp_relay_mode=native&alpn=h3#TUIC-${DOMAIN}"
            echo ""
            ;;
        3)
            echo "https://${DOMAIN}/subscription" | xclip -selection clipboard 2>/dev/null && print_success "已复制到剪贴板" || echo "https://${DOMAIN}/subscription"
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 修改配置
modify_config() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}         修改配置${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    
    if ! load_config_info; then
        print_error "未找到配置信息"
        read -p "按回车键继续..."
        return
    fi
    
    echo "1. 修改端口"
    echo "2. 重新生成 UUID"
    echo "3. 重新生成密码"
    echo "4. 重新生成 Reality 密钥"
    echo "5. 重新申请证书"
    echo "0. 返回主菜单"
    echo ""
    read -p "请选择: " choice
    
    case $choice in
        1)
            echo "当前端口配置:"
            echo "VLESS: $PORT_VLESS"
            echo "Hysteria2: $PORT_HYSTERIA2"
            echo "TUIC: $PORT_TUIC"
            echo "VMess: $PORT_VMESS"
            echo ""
            read -p "输入新的 VLESS 端口 [回车保持不变]: " new_port
            [[ -n "$new_port" ]] && PORT_VLESS=$new_port
            
            read -p "输入新的 Hysteria2 端口 [回车保持不变]: " new_port
            [[ -n "$new_port" ]] && PORT_HYSTERIA2=$new_port
            
            read -p "输入新的 TUIC 端口 [回车保持不变]: " new_port
            [[ -n "$new_port" ]] && PORT_TUIC=$new_port
            
            read -p "输入新的 VMess 端口 [回车保持不变]: " new_port
            [[ -n "$new_port" ]] && PORT_VMESS=$new_port
            
            generate_config
            save_config_info
            generate_subscription
            systemctl restart sing-box
            print_success "端口已修改并重启服务"
            ;;
        2)
            generate_uuid
            generate_config
            save_config_info
            generate_subscription
            systemctl restart sing-box
            print_success "UUID 已重新生成"
            ;;
        3)
            generate_password
            generate_config
            save_config_info
            generate_subscription
            systemctl restart sing-box
            print_success "密码已重新生成"
            ;;
        4)
            generate_reality_keys
            generate_short_id
            generate_config
            save_config_info
            generate_subscription
            systemctl restart sing-box
            print_success "Reality 密钥已重新生成"
            ;;
        5)
            systemctl stop nginx
            certbot renew --force-renewal
            cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_DIR/cert.pem
            cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERT_DIR/key.pem
            systemctl start nginx
            systemctl restart sing-box
            print_success "证书已重新申请"
            ;;
        0)
            return
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 查看服务状态
view_status() {
    clear
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}         服务状态${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    
    systemctl status sing-box --no-pager
    echo ""
    
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 重启服务"
    echo "4. 查看实时日志"
    echo "0. 返回主菜单"
    echo ""
    read -p "请选择: " choice
    
    case $choice in
        1)
            systemctl start sing-box
            print_success "服务已启动"
            ;;
        2)
            systemctl stop sing-box
            print_success "服务已停止"
            ;;
        3)
            systemctl restart sing-box
            print_success "服务已重启"
            ;;
        4)
            echo "按 Ctrl+C 退出日志查看"
            sleep 2
            journalctl -u sing-box -f
            ;;
        0)
            return
            ;;
    esac
    
    read -p "按回车键继续..."
}

# 卸载 sing-box
uninstall_singbox() {
    clear
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}         卸载 sing-box${NC}"
    echo -e "${RED}=========================================${NC}"
    echo ""
    
    print_warning "此操作将完全删除 sing-box 及所有配置！"
    read -p "确认卸载？输入 YES 继续: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        print_info "已取消卸载"
        read -p "按回车键继续..."
        return
    fi
    
    # 停止服务
    systemctl stop sing-box
    systemctl disable sing-box
    
    # 删除文件
    rm -f /usr/local/bin/sing-box
    rm -f /etc/systemd/system/sing-box.service
    rm -rf /usr/local/etc/sing-box
    rm -f /etc/nginx/sites-enabled/singbox
    rm -f /etc/nginx/sites-available/singbox
    rm -rf /var/www/html
    
    systemctl daemon-reload
    systemctl restart nginx
    
    print_success "sing-box 已完全卸载"
    
    read -p "按回车键退出..."
    exit 0
}

# 主菜单
show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
   _____ _                 ____            
  / ____(_)               |  _ \           
 | (___  _ _ __   __ _    | |_) | _____  __
  \___ \| | '_ \ / _` |   |  _ < / _ \ \/ /
  ____) | | | | | (_| |   | |_) | (_) >  < 
 |_____/|_|_| |_|\__, |   |____/ \___/_/\_\
                  __/ |                     
                 |___/                      
EOF
    echo -e "${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}      sing-box 管理脚本 v1.0${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    
    # 检查是否已安装
    if [[ -f "/usr/local/bin/sing-box" ]]; then
        VERSION=$(/usr/local/bin/sing-box version 2>/dev/null | grep "version" | awk '{print $3}')
        echo -e "${GREEN}状态:${NC} 已安装 (版本: $VERSION)"
        
        if systemctl is-active --quiet sing-box; then
            echo -e "${GREEN}服务:${NC} 运行中 ✓"
        else
            echo -e "${RED}服务:${NC} 已停止 ✗"
        fi
    else
        echo -e "${YELLOW}状态:${NC} 未安装"
    fi
    
    echo ""
    echo -e "${CYAN}安装管理:${NC}"
    echo "  1. 全新安装 sing-box"
    echo "  2. 更新 sing-box"
    echo "  3. 卸载 sing-box"
    echo ""
    echo -e "${CYAN}配置管理:${NC}"
    echo "  4. 查看订阅信息"
    echo "  5. 修改配置"
    echo "  6. 重新生成订阅"
    echo ""
    echo -e "${CYAN}系统管理:${NC}"
    echo "  7. 查看服务状态"
    echo "  8. 防火墙管理"
    echo "  9. 查看实时日志"
    echo ""
    echo "  0. 退出脚本"
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    read -p "请输入选项 [0-9]: " choice
    
    case $choice in
        1)
            install_full
            ;;
        2)
            update_singbox
            ;;
        3)
            uninstall_singbox
            ;;
        4)
            view_subscription
            ;;
        5)
            modify_config
            ;;
        6)
            if load_config_info; then
                generate_subscription
                print_success "订阅已重新生成"
                read -p "按回车键继续..."
            else
                print_error "未找到配置信息"
                read -p "按回车键继续..."
            fi
            ;;
        7)
            view_status
            ;;
        8)
            manage_firewall
            ;;
        9)
            echo "按 Ctrl+C 退出日志查看"
            sleep 2
            journalctl -u sing-box -f
            ;;
        0)
            echo ""
            print_info "感谢使用！"
            exit 0
            ;;
        *)
            print_error "无效选项"
            sleep 1
            ;;
    esac
}

# 完整安装流程
install_full() {
    check_root
    check_system
    cleanup_old_proxies
    install_dependencies
    install_singbox
    get_user_input
    apply_certificate
    generate_config
    save_config_info
    create_service
    configure_firewall
    generate_subscription
    start_service
    show_result
}

# 主函数
main() {
    check_root
    
    # 如果带参数 install，直接安装
    if [[ "$1" == "install" ]]; then
        install_full
    else
        # 否则显示菜单
        while true; do
            show_menu
        done
    fi
}

# 运行主函数
main "$@"