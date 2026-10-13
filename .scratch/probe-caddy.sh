#!/bin/bash
# 采集 VPS 侧 Caddy 配置（只读）
echo "=== CADDY 主配置 /etc/caddy/Caddyfile ==="
cat /etc/caddy/Caddyfile 2>/dev/null || echo "(读不到)"
echo
echo "=== acli.d/sites 扩展点 ==="
ls -la /etc/caddy/acli.d/sites/ 2>/dev/null || echo "(无)"
for f in /etc/caddy/acli.d/sites/*; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  cat "$f"
  echo
done
echo "=== Caddy 版本与监听端口 ==="
caddy version 2>/dev/null
ss -tlnp 2>/dev/null | grep -E ':(80|443|2443|2444|7000)\b' || echo "(ss 无输出)"
