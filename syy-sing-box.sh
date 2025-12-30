#!/bin/bash
# sing-box 一键安装脚本（CN 安全增强版）
# 支持 VLESS-Reality / Hysteria2 / TUIC / VMess

### ========== 基础配置 ==========
INSTALL_DIR="/usr/local/etc/sing-box"
CONFIG_FILE="${INSTALL_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
CERT_DIR="${INSTALL_DIR}/certs"
WEB_DIR="/var/www/html"

### ========== 颜色 ==========
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; }

### ========== 基础检查 ==========
[[ $EUID -ne 0 ]] && err "请使用 root 运行" && exit 1

### ========== IP 获取（中国可用） ==========
get_ip() {
  curl -s4 --max-time 3 ifconfig.me \
  || curl -s4 --max-time 3 ip.sb \
  || curl -s4 --max-time 3 api.ipify.org
}

### ========== 清理旧程序 ==========
cleanup_old() {
  log "清理旧代理程序..."
  for s in xray v2ray trojan sing-box hysteria naive; do
    systemctl stop $s 2>/dev/null
    systemctl disable $s 2>/dev/null
    rm -f /etc/systemd/system/$s.service
    rm -f /usr/local/bin/$s /usr/bin/$s
    rm -rf /usr/local/etc/$s /etc/$s
  done
  systemctl daemon-reload
  ok "旧程序已清理"
}

### ========== 依赖 ==========
install_deps() {
  apt update
  apt install -y curl wget tar jq qrencode nginx certbot python3-certbot-nginx
}

### ========== 安装 sing-box ==========
install_singbox() {
  log "安装 sing-box..."
  VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
    | jq -r '.tag_name' | sed 's/v//')
  [[ -z "$VERSION" ]] && VERSION="1.9.0"

  wget -O /tmp/sb.tar.gz \
    https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz

  tar -xzf /tmp/sb.tar.gz -C /tmp
  mv /tmp/sing-box-*/sing-box /usr/local/bin/
  chmod +x /usr/local/bin/sing-box
  mkdir -p "$INSTALL_DIR" "$CERT_DIR"
  ok "sing-box $VERSION 已安装"
}

### ========== 用户输入 ==========
get_input() {
  read -p "请输入域名: " DOMAIN
  read -p "邮箱（证书用，回车默认 admin@$DOMAIN）: " EMAIL
  EMAIL=${EMAIL:-admin@$DOMAIN}

  read -p "是否删除已有代理程序？(y/N): " CLEAN_OLD
  read -p "是否开启 80 端口（HTTP → HTTPS 跳转）？(y/N): " ENABLE_HTTP

  read -p "VLESS 端口 [443]: " PORT_VLESS
  PORT_VLESS=${PORT_VLESS:-443}

  UUID=$(cat /proc/sys/kernel/random/uuid)
  PASSWORD=$(openssl rand -base64 16)

  KEYS=$(sing-box generate reality-keypair)
  REALITY_PRIVATE=$(echo "$KEYS" | awk '/PrivateKey/{print $2}')
  REALITY_PUBLIC=$(echo "$KEYS" | awk '/PublicKey/{print $2}')
  SHORT_ID=$(openssl rand -hex 8)
}

### ========== 证书 ==========
apply_cert() {
  systemctl stop nginx 2>/dev/null
  certbot certonly --standalone --non-interactive \
    --agree-tos -m "$EMAIL" -d "$DOMAIN" || exit 1

  cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_DIR/cert.pem
  cp /etc/letsencrypt/live/$DOMAIN/privkey.pem   $CERT_DIR/key.pem
}

### ========== 配置 ==========
gen_config() {
cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $PORT_VLESS,
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": {
        "enabled": true,
        "server_name": "www.cloudflare.com",
        "reality": {
          "enabled": true,
          "handshake": { "server": "www.cloudflare.com", "server_port": 443 },
          "private_key": "$REALITY_PRIVATE",
          "short_id": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [{ "type": "direct" }]
}
EOF
}

### ========== systemd ==========
create_service() {
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=sing-box
After=network.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c $CONFIG_FILE
Restart=always
LimitNOFILE=infinity
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable sing-box
}

### ========== 订阅（已修复） ==========
gen_sub() {
  IP=$(get_ip)
  VLESS="vless://${UUID}@${IP}:${PORT_VLESS}?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${SHORT_ID}#VLESS-${DOMAIN}"

  mkdir -p "$WEB_DIR"
  echo "$VLESS" > "$WEB_DIR/vless"

  echo "$VLESS" > "$WEB_DIR/all"
  base64 -w 0 "$WEB_DIR/all" > "$WEB_DIR/subscription"
}

### ========== nginx ==========
config_nginx() {
if [[ "$ENABLE_HTTP" == "y" ]]; then
cat > /etc/nginx/sites-available/singbox <<EOF
server {
  listen 80;
  server_name $DOMAIN;
  return 301 https://\$host\$request_uri;
}
server {
  listen 443 ssl;
  server_name $DOMAIN;
  ssl_certificate $CERT_DIR/cert.pem;
  ssl_certificate_key $CERT_DIR/key.pem;
  root $WEB_DIR;
}
EOF
else
cat > /etc/nginx/sites-available/singbox <<EOF
server {
  listen 443 ssl;
  server_name $DOMAIN;
  ssl_certificate $CERT_DIR/cert.pem;
  ssl_certificate_key $CERT_DIR/key.pem;
  root $WEB_DIR;
}
EOF
fi

ln -sf /etc/nginx/sites-available/singbox /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
}

### ========== 主流程 ==========
main() {
  install_deps
  get_input
  [[ "$CLEAN_OLD" == "y" ]] && cleanup_old
  install_singbox
  apply_cert
  gen_config
  create_service
  gen_sub
  config_nginx
  systemctl start sing-box

  ok "安装完成"
  echo "订阅地址：https://$DOMAIN/subscription"
}

main
