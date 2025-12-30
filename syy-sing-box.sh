#!/bin/bash
# sing-box 一键安装脚本（最终稳定版 · Yahoo SNI）

### ========= 基础路径 =========
INSTALL_DIR="/usr/local/etc/sing-box"
CONFIG_FILE="$INSTALL_DIR/config.json"
CERT_DIR="$INSTALL_DIR/certs"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
WEB_DIR="/var/www/html"

### ========= 颜色 =========
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info(){ echo -e "${BLUE}[INFO]${NC} $1"; }
ok(){ echo -e "${GREEN}[OK]${NC} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
err(){ echo -e "${RED}[ERR]${NC} $1"; }

[[ $EUID -ne 0 ]] && err "请使用 root 运行" && exit 1

### ========= IP 获取（中国可用） =========
get_ip() {
  curl -s4 --max-time 3 ifconfig.me \
  || curl -s4 --max-time 3 ip.sb \
  || curl -s4 --max-time 3 api.ipify.org
}

### ========= 清理旧内核（可选） =========
cleanup_old() {
  info "清理旧代理程序..."
  for s in xray v2ray trojan sing-box hysteria naive; do
    systemctl stop $s 2>/dev/null
    systemctl disable $s 2>/dev/null
    rm -f /etc/systemd/system/$s.service
    rm -f /usr/local/bin/$s /usr/bin/$s
    rm -rf /usr/local/etc/$s /etc/$s
  done
  systemctl daemon-reload
  ok "旧代理程序已清理"
}

### ========= 依赖 =========
install_deps() {
  apt update
  apt install -y curl wget tar jq qrencode nginx certbot
}

### ========= 安装 sing-box =========
install_singbox() {
  info "安装 sing-box..."
  VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
    | jq -r '.tag_name' | sed 's/v//')
  [[ -z "$VERSION" ]] && VERSION="1.12.14"

  wget -O /tmp/sb.tar.gz \
    https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/sing-box-${VERSION}-linux-amd64.tar.gz

  tar -xzf /tmp/sb.tar.gz -C /tmp
  mv /tmp/sing-box-*/sing-box /usr/local/bin/
  chmod +x /usr/local/bin/sing-box
  mkdir -p "$INSTALL_DIR" "$CERT_DIR"
  ok "sing-box $VERSION 已安装"
}

### ========= 用户输入 =========
get_input() {
  read -p "请输入域名: " DOMAIN
  read -p "证书邮箱（回车默认 admin@$DOMAIN）: " EMAIL
  EMAIL=${EMAIL:-admin@$DOMAIN}

  read -p "是否删除已有代理程序？(y/N): " CLEAN_OLD
  read -p "是否开启 80 端口（仅 301 跳转）？(y/N): " ENABLE_HTTP

  read -p "VLESS Reality 端口 [443]: " PORT_VLESS
  PORT_VLESS=${PORT_VLESS:-443}

  UUID=$(cat /proc/sys/kernel/random/uuid)
  PASSWORD=$(openssl rand -base64 16)

  KEYS=$(sing-box generate reality-keypair)
  REALITY_PRIVATE=$(echo "$KEYS" | awk '/PrivateKey/{print $2}')
  REALITY_PUBLIC=$(echo "$KEYS" | awk '/PublicKey/{print $2}')
  SHORT_ID=$(openssl rand -hex 8)
}

### ========= 证书 =========
apply_cert() {
  systemctl stop nginx 2>/dev/null
  certbot certonly --standalone --non-interactive \
    --agree-tos -m "$EMAIL" -d "$DOMAIN" || exit 1

  cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_DIR/cert.pem
  cp /etc/letsencrypt/live/$DOMAIN/privkey.pem   $CERT_DIR/key.pem
}

### ========= sing-box 配置（Yahoo SNI） =========
gen_config() {
cat > "$CONFIG_FILE" <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $PORT_VLESS,
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": {
        "enabled": true,
        "server_name": "www.yahoo.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.yahoo.com",
            "server_port": 443
          },
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

### ========= systemd =========
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

### ========= 订阅（已修复） =========
gen_sub() {
  IP=$(get_ip)
  VLESS="vless://${UUID}@${IP}:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.yahoo.com&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${SHORT_ID}#VLESS-${DOMAIN}"

  mkdir -p "$WEB_DIR"
  echo "$VLESS" > "$WEB_DIR/vless"
  echo "$VLESS" > "$WEB_DIR/all"
  base64 -w 0 "$WEB_DIR/all" > "$WEB_DIR/subscription"
}

### ========= nginx（修复版） =========
config_nginx() {

rm -f /etc/nginx/sites-enabled/default

cat > /etc/nginx/snippets/ssl-params.conf <<EOF
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
EOF

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
  ssl_certificate     $CERT_DIR/cert.pem;
  ssl_certificate_key $CERT_DIR/key.pem;
  include snippets/ssl-params.conf;
  root $WEB_DIR;
}
EOF
else
cat > /etc/nginx/sites-available/singbox <<EOF
server {
  listen 443 ssl;
  server_name $DOMAIN;
  ssl_certificate     $CERT_DIR/cert.pem;
  ssl_certificate_key $CERT_DIR/key.pem;
  include snippets/ssl-params.conf;
  root $WEB_DIR;
}
EOF
fi

ln -sf /etc/nginx/sites-available/singbox /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
}

### ========= 主流程 =========
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
