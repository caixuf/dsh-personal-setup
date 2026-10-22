#!/bin/bash
# 代理快捷开关 v7 —— 多候选端口自动探测
# 2026-09-26：宿主代理从 Clash Verge 切到 星连 SingLink
# 2026-10-22：⭐ 又切回 **Clash Verge**（星连已弃用/退场），真身端口随之变回 7899
#
# 端口约定（各占各的，不许互相改）：
#   7899  ★真正的代理：**Clash Verge 的 verge-mihomo**（**只绑 127.0.0.1**）
#   7898  netsh portproxy 主入口 0.0.0.0:7898 → 127.0.0.1:<当前代理端口>
#         **NAT 模式下 WSL 唯一稳的路** —— 内核只绑回环，WSL 够不着它
#   7892  netsh portproxy 兼容层 → 同一个当前代理端口
#         （修历史遗留写死 7892 的配置；它和 7898 是同一目标，不是死口）
#   7897  历史遗留：星连 singcore 专用口，**星连已退场 → 死口**
#
# ⚠️ 候选顺序必须 **7898 打头**（2026-10-22 实测修正）：
#   portproxy 的目标每次跑 `启用WSL代理-SingLink.cmd` 都会重新对齐到当前代理，
#   所以 7898 / 7892 **换代理软件也不用改，而且命中最快**；
#   7899 是内核原始口，只有 mirrored 或 Clash 开了「局域网连接」时 WSL 才直连得上；
#   7897 基本是死口，留作回退。
#   本机实机顺序：`CANDIDATE_PORTS="7898 7892 7899 7897"`。
#
#   ❌ 别退回到 `"7899 7897 7892"`：本机 NAT 拓扑下 7899 连不上（只绑回环）、
#      7897 星连已退场，两个都要白等一轮超时，第三个才通。
#
# ⚠️ **换代理软件时，四处都要同步**（只有 WinINET 会跟着代理软件自动变）：
#   ① 用户环境变量 HTTP_PROXY/HTTPS_PROXY/NO_PROXY  ← **CLI 工具(node/npm/python/git)唯一读这层**
#   ② WinHTTP（netsh winhttp，服务/底层组件读）
#   ③ WinINET 系统代理（浏览器/Electron 读，**会跟着代理软件自动变**）
#   ④ 本文件的 PROXY_BYPASS（WSL 侧）
#   本机已有 `C:\Users\20247\code\workbuddy\sync-proxy.ps1` 一次同步 ①②③。
#   ⚠️ 改了环境变量要**重启**用到它的应用（Windows 机制：进程启动时继承）。
#
# 宿主地址**自动探测**，两种 WSL 拓扑都能用：
#   mirrored → 127.0.0.1 直通 Windows，直接用 7899
#   NAT      → 127.0.0.1 是 WSL 自己的，必须走默认网关 IP（如 172.18.80.1），
#              再经 portproxy 垫片回到真身
#
# 🔴 「不是 mirrored」**不代表**代理不可用，别据此去改 .wslconfig：
#    有些机器**开 mirrored 总是失败**，那些 portproxy 垫片就是为此存在的正式设计。
#
# 怀疑端口归属时先看规则（Windows 侧）：netsh interface portproxy show all
#
# 判定标准不是「端口开着」，而是真发一次请求拿到 204/200 ——
# 端口被别的程序占着时也算"开着"，只有真请求能拆穿。
#
# 用法：
#   proxy_on          # 自动探测并开启（宿主×端口 逐个试，取第一个真通的）
#   proxy_on 7899     # 强制指定端口
#   proxy_off         # 关闭（同时清掉 git 的 http.proxy）
#   proxy_test        # 状态自检
#   proxy_doctor      # WSL 网络体检
#
# 注意：这里看不到 Windows 的监听列表，必须用真实 TCP 建连 + 真实 HTTP 请求判断。

PROXY_HOST="127.0.0.1"          # 由探测结果覆盖（NAT 下会变成网关 IP）
CANDIDATE_PORTS="7898 7892 7899 7897"

# 候选宿主地址：先 127.0.0.1（mirrored），再默认网关（NAT）。每次现算，避免网络变化后过期。
_proxy_hosts() {
    printf '127.0.0.1 %s' "$(ip route show default 2>/dev/null | awk '/^default/{print $3; exit}')"
}
PROXY_PORT=""          # 由探测结果填充，初始为空

# 探测靶（2026-10-22 实测补充）：**别拿 gstatic 当唯一判据**。
# gstatic 是 Google 的端点，本身会偶发挂死（20 次挂 1 次，一挂就挂满超时）。
# 它挂的时候，四个候选端口会**同时**被判死（都走同一条出网路径）→ 开终端判定
# 「没网」→ 根本不设代理 → 整个终端裸连。表现就是「代理明明开着却连不上」。
# cloudflare 的 204 端点实测 30/30 稳定，放主靶；gstatic 只做备靶。
PROBE_URLS="http://cp.cloudflare.com/generate_204 https://www.gstatic.com/generate_204"
# platform.deepseek.com 必须直连（2026-10-21 实测）：它的账号资料接口
# /auth-api/v0/users/current 经代理会被 CloudFront/WAF 拦（403 或 challenge），
# 而余额接口 /api/v0/users/get_user_summary 没有这条规则 —— 于是 DSH 账号页
# 出现「已登录 DeepSeek / 账号资料暂不可用 / 余额能显示」的怪相。
# 判据：同域名下 profile 失败而 balance 成功 = 走了代理，要加进绕过表。
PROXY_BYPASS="localhost,127.0.0.1,::1,.local,.immotors.com,.immotors.sgp1.com,10.0.0.0/8,172.16.0.0/12,172.100.0.0/16,192.168.0.0/16,platform.deepseek.com"
INTRA_GIT_HOST="gitlab-ap-office.immotors.com"

# 快速 TCP 可达性预检：先花 <2s 排除死端口，避免逐个白等 HTTP 超时。
# （NAT 拓扑下 127.0.0.1 永远不通，没有这层预检会白白多等好几秒 × 候选数）
_wsl_tcp_ok() {
    timeout 2 bash -c "cat < /dev/null > /dev/tcp/$1/$2" 2>/dev/null
}

# 真请求探活：$1=宿主地址 $2=端口
_host_port_ok() {
    _wsl_tcp_ok "$1" "$2" || return 1
    local u code
    for u in $PROBE_URLS; do
        code=$(env -u http_proxy -u https_proxy -u all_proxy \
                    -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
               curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
                    -x "http://$1:$2" "$u" 2>/dev/null)
        case "$code" in 200|204|301|302) return 0 ;; esac
    done
    return 1
}

# 端口探活：依次试候选宿主地址，命中即把 PROXY_HOST 定到该地址。$1=端口
_port_ok() {
    local h
    for h in $(_proxy_hosts); do
        [ -n "$h" ] || continue
        if _host_port_ok "$h" "$1"; then PROXY_HOST="$h"; return 0; fi
    done
    return 1
}

# 探测可用后端：成功则**直接设置** PROXY_HOST / PROXY_PORT 并返回 0。
# ⚠️ 刻意不经 `$(...)` 传值 —— 命令替换是子 shell，宿主地址的赋值会丢，
#    NAT 下会退化成「端口对了、地址仍是 127.0.0.1」的死 URL。
_proxy_detect() {
    local p
    for p in $CANDIDATE_PORTS; do
        if _port_ok "$p"; then PROXY_PORT="$p"; return 0; fi
    done
    return 1
}

# 幂等同步 git 代理；内网 GitLab 例外直连（走代理会把域名丢给上游解析 → 超时）
_sync_git() {
    [ -z "$PROXY_PORT" ] && return 0
    git config --global http.proxy "http://${PROXY_HOST}:${PROXY_PORT}" 2>/dev/null
    git config --global "http.http://${INTRA_GIT_HOST}.proxy" "" 2>/dev/null
    # 2026-09-28 补：按 URL 分节优先级高于全局，Clash 时代遗留的 github.com=7892 曾把
    # github 流量打进死端口 —— 每次同步顺手清掉指向废弃端口的 URL 分节（回落全局）
    local _k _v
    while IFS=' ' read -r _k _v; do
        [ -z "${_k:-}" ] && continue
        case "${_v:-}" in
            *:7892*|*:8118*) git config --global --unset-all "$_k" 2>/dev/null ;;
        esac
    done < <(git config --global --get-regexp '^http\.[^ ]*\.proxy$' 2>/dev/null || true)
}

_git_unset() {
    git config --global --unset http.proxy  2>/dev/null
}

proxy_on() {
    local want="${1:-}" chosen=""
    if [ -n "$want" ]; then
        if _port_ok "$want"; then chosen="$want"; fi
    elif [ -n "$PROXY_PORT" ] && _port_ok "$PROXY_PORT"; then
        chosen="$PROXY_PORT"
    elif _proxy_detect; then
        chosen="$PROXY_PORT"
    fi

    if [ -z "$chosen" ]; then
        echo "❌ 没探测到可用代理（候选：$CANDIDATE_PORTS）"
        echo "   Windows 侧检查：星连是否已「已连接」/ Clash 是否在跑"
        return 1
    fi

    PROXY_PORT="$chosen"
    local url="http://${PROXY_HOST}:${PROXY_PORT}"
    export HTTP_PROXY="$url" HTTPS_PROXY="$url" ALL_PROXY="$url"
    export http_proxy="$url" https_proxy="$url" all_proxy="$url"
    export NO_PROXY="$PROXY_BYPASS" no_proxy="$PROXY_BYPASS"
    _sync_git
    echo "代理已开启 -> ${url}"
    echo "  no_proxy 已含内网白名单（*.immotors.com / 10.x / 172.16-31.x / 192.168.x）"
}

proxy_off() {
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    unset http_proxy https_proxy all_proxy no_proxy
    PROXY_PORT=""
    _git_unset
    echo "代理已关闭（回到直连 / 继承 Windows 代理，git 代理已清）"
}

proxy_port_alive() {
    if [ -n "$PROXY_PORT" ] && _port_ok "$PROXY_PORT"; then return 0; fi
    _proxy_detect
}

proxy_test() {
    echo "--- 代理状态 ---"
    echo "  当前端口   = ${PROXY_PORT:-（未探测）}"
    echo "  http_proxy = ${http_proxy:-未设置}"
    echo "  all_proxy  = ${all_proxy:-未设置}"
    echo "  no_proxy   = ${no_proxy:-未设置}"
    echo
    echo "--- 候选宿主×端口实测（真发请求） ---"
    local h p
    for h in $(_proxy_hosts); do
        [ -n "$h" ] || continue
        for p in $CANDIDATE_PORTS; do
            if _host_port_ok "$h" "$p"; then echo "  ${h}:${p}  通 OK"; else echo "  ${h}:${p}  不通"; fi
        done
    done
    echo
    echo "--- 连通性 ---"
    _probe() {
        printf "  %-14s " "$1"
        curl -s -o /dev/null -w "HTTP %{http_code}  (%{time_total}s)\n" --max-time 10 "$2" 2>&1
    }
    _probe "GitHub"     https://github.com
    _probe "Google"     https://www.google.com
    _probe "内网GitLab" http://gitlab-ap-office.immotors.com
    echo "  提示：内网 GitLab 必须直连，走代理会失败（已列入 no_proxy）"
}

proxy_doctor() {
    echo "--- WSL 网络体检 ---"
    echo "[1] 默认路由"
    ip route show default 2>/dev/null | sed 's/^/      /'
    echo "[2] 内网 hosts"
    if grep -q "$INTRA_GIT_HOST" /etc/hosts 2>/dev/null; then
        echo "      gitlab 条目存在 OK"
    else
        echo "      gitlab 条目缺失（执行 sudo net-doctor fix 修复）"
    fi
    echo "[3] DNS"
    grep -v '^#' /etc/resolv.conf 2>/dev/null | grep nameserver | sed 's/^/      /'
    echo "[4] 候选代理宿主×端口"
    local h p
    for h in $(_proxy_hosts); do
        [ -n "$h" ] || continue
        for p in $CANDIDATE_PORTS; do
            if _host_port_ok "$h" "$p"; then echo "      ${h}:${p} 通 OK"; else echo "      ${h}:${p} 不通"; fi
        done
    done
    echo "[5] git 代理"
    git config --global --get http.proxy 2>/dev/null | sed 's/^/      http.proxy = /'
    git config --global --get "http.http://${INTRA_GIT_HOST}.proxy" 2>/dev/null | sed 's/^/      内网例外   = /'
}
