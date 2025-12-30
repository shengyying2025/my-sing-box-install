#!/bin/bash
# sing-box VLESS Reality Only - Final Stable Script
# 无 nginx / 无订阅 / 低特征 / 中国环境可用

### ========= 基础路径 =========
INSTALL_DIR="/usr/local/etc/sing-box"
CONFIG_FILE="$INSTALL_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/sing-box.service"

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

### ========= 基础检查 =========
[[ $EUID -ne 0 ]] && err "请使用 root 运行" && exit 1

### ========= IP 获取（中国友好） =========
get_ip() {
  curl -s4 --max-time 3 ifconfig.me \
  || curl -s4 --max-time 3 ip.sb \
  || curl -s4 --max-time 3 api.ipify.org
}

### ========= 清理旧 sing-box（可选） =========
cleanup_old() {
  read -p "是否删除已有 sing-box？(y/N): " CLEAN
  if [[ "$CLEAN" == "y" ]]; then
    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null
    rm -f /usr/local/bin/sing-box
    rm -rf /usr/local/etc/sing-box
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    ok "旧 sing-box 已删除"
  fi
}

### ========= 安装依赖 =========
install_deps() {
  apt update
  apt install -y curl wget tar qrencode jq
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
  mkdir -p "$INSTALL_DIR"
  ok "sing-box $VERSION 已安装"
}

### ========= 用户输入 =========
get_input() {
  read -p "Reality 监听端口 [443]: " PORT
  PORT=${PORT:-443}

  UUID=$(cat /proc/sys/kernel/random/uuid)

  KEYS=$(sing-box generate reality-keypair)
  REALITY_PRIVATE=$(echo "$KEYS" | awk '/PrivateKey/{print $2}')
  REALITY_PUBLIC=$(echo "$KEYS" | awk '/PublicKey/{print $2}')

  SHORT_ID=$(openssl rand -hex 8)
}

### ========= 生成配置 =========
gen_config() {
cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $PORT,
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
          "private_key": "$REALITY_PRIVATE",
          "short_id": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    { "type": "direct" }
  ]
}
EOF
}

### ========= systemd =========
create_service() {
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=sing-box VLESS Reality
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

### ========= 启动 =========
start_service() {
  systemctl start sing-box
  sleep 2
  systemctl is-active --quiet sing-box && ok "sing-box 已启动" || err "sing-box 启动失败"
}

### ========= 输出节点 & 二维码 =========
show_result() {
  IP=$(get_ip)

  VLESS_LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.yahoo.com&fp=chrome&pbk=${REALITY_PUBLIC}&sid=${SHORT_ID}#VLESS-Reality-Yahoo"

  echo ""
  echo -e "${GREEN}================ 安装完成 ================${NC}"
  echo ""
  echo -e "${BLUE}节点链接：${NC}"
  echo "$VLESS_LINK"
  echo ""
  echo -e "${BLUE}二维码（手机直接扫码）：${NC}"
  echo "$VLESS_LINK" | qrencode -t ANSIUTF8
  echo ""
  echo -e "${YELLOW}管理命令：${NC}"
  echo "启动: systemctl start sing-box"
  echo "停止: systemctl stop sing-box"
  echo "状态: systemctl status sing-box"
  echo "日志: journalctl -u sing-box -f"
  echo ""
}

### ========= 主流程 =========
main() {
  cleanup_old
  install_deps
  install_singbox
  get_input
  gen_config
  create_service
  start_service
  show_result
}

main
