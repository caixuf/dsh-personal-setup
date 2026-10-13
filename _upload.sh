#!/usr/bin/env bash
#
# provision-vps.sh —— 在一台**全新的 VPS** 上架设「DSH 移动端网关」的公网入口
#
#   它做的事（幂等，重复跑安全）：
#     1. 装 frps（frp server）
#     2. 写 /etc/frp/frps.toml（令牌从参数或环境变量来）
#     3. 注册 + 启动 systemd 服务
#     4. 装 Caddy 站点配置，做路径白名单（含**封死管理面**）
#     5. 配 ufw：放行 7000/2444/80/443，**不放行 2443**
#     6. 自检
#
# 用法（在 VPS 上以 root 跑）：
#     FRP_TOKEN='<你的令牌>' \
#     VPS_IP='<VPS公网IP>' \
#     bash provision-vps.sh
#
# 只检查不改动：
#     bash provision-vps.sh --verify
#
# ⚠️ 两个必须自己决定的值：
#   - FRP_TOKEN：与家里 frpc.toml 的 auth.token 必须一致。
#     生成：openssl rand -base64 32
#   - VPS_IP：Caddy 站点块的地址；证书走 ACME HTTP-01（IP 证书，
#     无法用 tls-alpn 挑战，所以主 Caddyfile 里要留一个按 IP 匹配的 :80 块）。
#
set -euo pipefail

FRP_VERSION="${FRP_VERSION:-0.71.0}"
TUNNEL_PORT="${TUNNEL_PORT:-2443}"       # 隧道端口（只绑回环）
FRP_BINDPORT="${FRP_BINDPORT:-7000}"     # frpc 连接端口
PUBLIC_PORT="${PUBLIC_PORT:-2444}"       # Caddy 对公网的端口
CADDY_SITES="/etc/caddy/acli.d/sites"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# ── verify 模式：只读自检 ──────────────────────────────────────────────────
if [[ "${1:-}" == "--verify" ]]; then
  say "自检模式（只读，不改任何东西）"
  echo
  echo "--- frps 二进制 ---"
  [[ -x /usr/local/bin/frps ]] && /usr/local/bin/frps --version || warn "frps 未安装"
  echo
  echo "--- frps 服务 ---"
  systemctl is-active frps 2>/dev/null || warn "frps.service 未运行"
  echo
  echo "--- frps 配置关键项 ---"
  if [[ -f /etc/frp/frps.toml ]]; then
    grep -E 'bindPort|allowPorts|proxyBindAddr|auth.token' /etc/frp/frps.toml \
      | sed -E 's/(auth\.token *= *").*(")/\1<hidden>\2/'
  else
    warn "/etc/frp/frps.toml 不存在"
  fi
  echo
  echo "--- Caddy 站点文件 ---"
  ls -1 "$CADDY_SITES"/*.caddy 2>/dev/null || warn "没有 .caddy 站点文件"
  echo
  echo "--- 监听端口 ---"
  ss -tlnp 2>/dev/null | grep -E ":(${FRP_BINDPORT}|${PUBLIC_PORT}|${TUNNEL_PORT})\b" \
    || warn "端口未监听"
  echo
  echo "--- ufw ---"
  ufw status 2>/dev/null | head -20 || warn "ufw 不可用"
  echo
  echo "--- 公网连通性自检 ---"
  code=$(curl -sk --max-time 8 -o /dev/null -w '%{http_code}' \
         "https://127.0.0.1:${PUBLIC_PORT}/mobile-gateway/health" 2>/dev/null || echo 000)
  if [[ "$code" == "200" ]]; then
    echo "    health → 200 ✅（但这可能来自旧配置，需确认刚改了白名单）"
  else
    echo "    health → $code （没家里电脑在线时 502/000 是正常的）"
  fi
  exit 0
fi

# ── 正常安装流程 ───────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "请以 root 运行（sudo bash provision-vps.sh）"
[[ -n "${FRP_TOKEN:-}" ]] || die "缺少 FRP_TOKEN 环境变量"
[[ -n "${VPS_IP:-}" ]]     || die "缺少 VPS_IP 环境变量"

say "参数"
echo "    frp 版本    : $FRP_VERSION"
echo "    frp bindPort: $FRP_BINDPORT   (公网放行)"
echo "    隧道端口    : $TUNNEL_PORT   (只绑 127.0.0.1，**不放行**)"
echo "    Caddy 端口  : $PUBLIC_PORT   (公网放行)"

# 1) frps 二进制
say "安装 frps"
if [[ -x /usr/local/bin/frps ]] && /usr/local/bin/frps --version 2>/dev/null | grep -q "$FRP_VERSION"; then
  echo "    已存在，跳过"
else
  tmp=$(mktemp -d)
  # GitHub release 里 amd64 的包名带 _linux_amd64
  url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
  echo "    下载 $url"
  curl -fsSL "$url" | tar -xz -C "$tmp"
  install -m 0755 "$tmp/frp_${FRP_VERSION}_linux_amd64/frps" /usr/local/bin/frps
  rm -rf "$tmp"
  echo "    已安装 $(/usr/local/bin/frps --version)"
fi

# 2) frps 配置
say "写入 /etc/frp/frps.toml"
install -d -m 0700 /etc/frp
if [[ -f /etc/frp/frps.toml ]]; then
  cp -a /etc/frp/frps.toml "/etc/frp/frps.toml.bak.$(date +%s)"
  echo "    已备份旧配置"
fi
cat > /etc/frp/frps.toml <<EOF
# frps 服务端 —— 由 provision-vps.sh 生成
# 详见 dsh-personal-setup/templates/dsh/frps.toml 里的设计说明。

bindAddr = "0.0.0.0"
bindPort = ${FRP_BINDPORT}

# 只允许这一个隧道端口，否则 VPS 会变成开放代理
allowPorts = [{ single = ${TUNNEL_PORT} }]

# 隧道端口只绑回环 —— 公网侧不可达
proxyBindAddr = "127.0.0.1"

auth.method = "token"
auth.token = "${FRP_TOKEN}"

transport.tls.force = true

log.to = "/var/log/frps.log"
log.level = "info"
EOF
chmod 600 /etc/frp/frps.toml
echo "    ✓ 已写入（权限 600）"

# 3) systemd
say "注册 frps.service"
cat > /etc/systemd/system/frps.service <<'EOF'
[Unit]
Description=frp server (DSH mobile gateway tunnel)
Documentation=https://github.com/fatedier/frp
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

# 轻量加固
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now frps >/dev/null 2>&1 || systemctl restart frps
sleep 1
systemctl is-active --quiet frps && echo "    ✓ frps 运行中" || die "frps 启动失败：journalctl -u frps -n 20"

# 4) Caddy
say "写入 Caddy 站点配置"
command -v caddy >/dev/null || die "未找到 caddy，请先安装 Caddy"
install -d -m 0755 "$CADDY_SITES"
[[ -f "$CADDY_SITES/dsh-mobile.caddy" ]] && \
  cp -a "$CADDY_SITES/dsh-mobile.caddy" "$CADDY_SITES/dsh-mobile.caddy.bak.$(date +%s)"

cat > "$CADDY_SITES/dsh-mobile.caddy" <<EOF
# DSH 移动端网关的公网入口 —— 由 provision-vps.sh 生成
#
# 安全模型：
#   公网 :${PUBLIC_PORT} ──Caddy(TLS+白名单)──▶ 127.0.0.1:${TUNNEL_PORT} ──FRP──▶ 家里 DSH
#     只放行 /mobile-gateway/{health,login,pair,api/*,remote.mux}
#     管理面 /mobile-gateway/manage* 显式 404 —— 因为经过 FRP 隧道后
#     DSH 会把公网请求误判为回环，它自己的回环闸门会失效，只能由 Caddy 挡。

https://${VPS_IP}:${PUBLIC_PORT} {
	tls {
		issuer acme {
			# IP 证书无法走 tls-alpn 挑战，只能 HTTP-01（主 Caddyfile 需留 :80 块）
			profile shortlived
			disable_tlsalpn_challenge
		}
	}

	handle /mobile-gateway/health {
		reverse_proxy 127.0.0.1:${TUNNEL_PORT}
	}
	handle /mobile-gateway/login {
		reverse_proxy 127.0.0.1:${TUNNEL_PORT}
	}
	handle /mobile-gateway/pair {
		reverse_proxy 127.0.0.1:${TUNNEL_PORT}
	}
	handle /mobile-gateway/api/* {
		reverse_proxy 127.0.0.1:${TUNNEL_PORT}
	}
	handle /mobile-gateway/remote.mux {
		reverse_proxy 127.0.0.1:${TUNNEL_PORT}
	}

	# 管理面：显式封死
	handle /mobile-gateway/manage* {
		respond "Not Found" 404
	}
	handle {
		respond "Not Found" 404
	}
}
EOF
echo "    ✓ 已写入 $CADDY_SITES/dsh-mobile.caddy"

say "校验并重载 Caddy"
# reload 而不是 restart：ACLI 托管的主 Caddyfile 有其它站点的证书在内存里，
# restart 会短暂中断全部站点。
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null \
  || die "Caddy 配置校验失败，先别 reload（已写入备份在同目录 .bak）"
systemctl reload caddy
echo "    ✓ 已重载"

# 5) 防火墙
say "配置 ufw"
if command -v ufw >/dev/null; then
  ufw allow "${FRP_BINDPORT}/tcp" comment 'frp bindPort (DSH-mobile)'  >/dev/null 2>&1 || true
  ufw allow "${PUBLIC_PORT}/tcp" comment 'DSH mobile gateway via Caddy TLS' >/dev/null 2>&1 || true
  ufw allow 80/tcp  >/dev/null 2>&1 || true   # ACME HTTP-01
  ufw allow 443/tcp >/dev/null 2>&1 || true
  # 关键：2443 不放行。它只绑回环，放行也没有意义，但显式拒绝更不容易被误解。
  ufw status | grep -q "${TUNNEL_PORT}/tcp" && warn "${TUNNEL_PORT} 居然在 ufw 里，请手工移除"
  echo "    ✓ 已放行 ${FRP_BINDPORT}/${PUBLIC_PORT}/80/443；${TUNNEL_PORT} 保持不放行"
else
  warn "ufw 不可用，请自行确认 ${FRP_BINDPORT}/${PUBLIC_PORT} 已放行、${TUNNEL_PORT} 未放行"
fi

cat <<EOF

────────────────────────────────────────────────────────────
✅ 完成。下一步：

1) 把下面三个值填进家里电脑的 frpc.toml（模板在
   dsh-personal-setup/templates/dsh/frpc.toml）：
     serverAddr = ${VPS_IP}
     serverPort = ${FRP_BINDPORT}
     auth.token = <你刚用的那个 FRP_TOKEN>
     remotePort = ${TUNNEL_PORT}

2) 家里电脑跑：frpc.exe -c frpc.toml
   看到 "start proxy success" 即隧道通了。

3) 端到端自检：
     curl -sk https://${VPS_IP}:${PUBLIC_PORT}/mobile-gateway/health

4) 云厂商**安全组**也要放行 ${FRP_BINDPORT} 和 ${PUBLIC_PORT}（VPS 内 ufw 之外还有一层）。
────────────────────────────────────────────────────────────
EOF
