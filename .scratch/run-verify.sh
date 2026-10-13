#!/bin/bash
# 在 VPS 上跑 provision-vps.sh 的只读自检
set -e
chmod +x /tmp/provision-vps.sh 2>/dev/null || true
ls -la /tmp/provision-vps.sh 2>/dev/null || echo "(脚本没在 /tmp)"
echo "===================== VERIFY ====================="
bash /tmp/provision-vps.sh --verify 2>&1 || bash /tmp/provision-vps.sh --verify
