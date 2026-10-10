#!/bin/bash
# WSL 启动网络修复：修正默认路由 + 补内网 GitLab host（幂等）
# 背景：WSL 会把 Windows 多块网卡镜像进来，默认路由可能命中不可达的网卡(如 192.168.137.1)，
# 导致只有经宿主代理才能出网。本脚本动态把"可达的默认网关"设为最高优先级，并删除不可达的错误默认路由。

# 1. 等待非 docker/link-local 的 IPv4 地址出现（最多 40s）
for _ in $(seq 1 40); do
  CAND=$(ip -4 -o addr show 2>/dev/null | awk '{print $4}' | grep -vE '^127\.|^169\.254|^172\.(1[6-9]|2[0-9]|3[01])\.')
  [ -n "$CAND" ] && break
  sleep 1
done

# 2. 逐条处理默认路由：可达网关按 metric 排序，不可达的删除
ip route show default 2>/dev/null | while read -r line; do
  dev=$(echo "$line" | awk '{print $5}')
  gw=$(echo "$line" | awk '{print $3}')
  # 网关可达则保留并设置 metric，热点网卡(10.255.163)优先
  if ping -I "$dev" -c1 -W1 -q "$gw" >/dev/null 2>&1; then
    if echo "$line" | grep -q "10.255.163"; then
      ip route replace default via "$gw" dev "$dev" proto kernel metric 50 2>/dev/null
    else
      ip route replace default via "$gw" dev "$dev" proto kernel metric 100 2>/dev/null
    fi
  else
    ip route del default via "$gw" dev "$dev" 2>/dev/null
  fi
done

# 3. 兜底：若意外没有任何默认可达路由，回到热点网关（异常时用）
if [ -z "$(ip route show default)" ]; then
  ip route add default via 10.255.163.27 dev eth0 2>/dev/null || true
fi

# 4. 幂等补内网 GitLab 域名（WSL 重启会重建 /etc/hosts）
grep -q "gitlab-ap-office.immotors.com" /etc/hosts 2>/dev/null \
  || echo "10.184.134.164  gitlab-ap-office.immotors.com" >> /etc/hosts

exit 0