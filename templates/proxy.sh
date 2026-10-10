#!/bin/bash
# 代理快捷开关 v7 —— 多候选端口自动探测
# 2026-09-26：宿主代理从 Clash Verge 切到 星连 SingLink
#
# 端口约定（各占各的，不许互相改）：
#   7897  星连 SingLink 内核 singcore 的本地 mixed 端口  —— 首选
#   7899  Clash Verge 备胎（已从 7892 挪开，避免和星连打架）
#   7892  历史遗留位（超实惠 sing-box 时代）—— 只作兜底
#
# 判定标准不是「端口开着」，而是真发一次请求拿到 204/200 ——
# 端口被别的程序占着时也算"开着"，只有真请求能拆穿。
#
# 用法：
#   proxy_on          # 自动探测并开启（按候选顺序取第一个通的）
#   proxy_on 7897     # 强制指定端口
#   proxy_off         # 关闭（同时清掉 git 的 http.proxy）
#   proxy_test        # 状态自检
#   proxy_doctor      # WSL 网络体检
#
# WSL 是 mirrored 模式，127.0.0.1 直通 Windows，所以这里看不到 Windows 的监听，
# 必须用真实 TCP 建连 + 真实 HTTP 请求来判断。

PROXY_HOST="127.0.0.1"
CANDIDATE_PORTS="7897 7899 7892"
PROXY_PORT=""          # 由探测结果填充，初始为空

PROBE_URL="https://www.gstatic.com/generate_204"
PROXY_BYPASS="localhost,127.0.0.1,::1,.local,.immotors.com,.immotors.sgp1.com,10.0.0.0/8,172.16.0.0/12,172.100.0.0/16,192.168.0.0/16"
INTRA_GIT_HOST="gitlab-ap-office.immotors.com"

# 真请求探活：$1=端口
_port_ok() {
    local code
    code=$(env -u http_proxy -u https_proxy -u all_proxy \
                -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
           curl -s -o /dev/null -w '%{http_code}' --max-time 6 \
                -x "http://${PROXY_HOST}:$1" "$PROBE_URL" 2>/dev/null)
    [ "$code" = "204" ] || [ "$code" = "200" ]
}

detect_port() {
    local p
    for p in $CANDIDATE_PORTS; do
        if _port_ok "$p"; then echo "$p"; return 0; fi
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
    local want="$1" chosen=""
    if [ -n "$want" ]; then
        if _port_ok "$want"; then chosen="$want"; fi
    elif [ -n "$PROXY_PORT" ] && _port_ok "$PROXY_PORT"; then
        chosen="$PROXY_PORT"
    else
        chosen="$(detect_port)"
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
    local p
    if p="$(detect_port)"; then PROXY_PORT="$p"; return 0; fi
    return 1
}

proxy_test() {
    echo "--- 代理状态 ---"
    echo "  当前端口   = ${PROXY_PORT:-（未探测）}"
    echo "  http_proxy = ${http_proxy:-未设置}"
    echo "  all_proxy  = ${all_proxy:-未设置}"
    echo "  no_proxy   = ${no_proxy:-未设置}"
    echo
    echo "--- 候选端口实测（真发请求） ---"
    local p
    for p in $CANDIDATE_PORTS; do
        if _port_ok "$p"; then echo "  ${PROXY_HOST}:${p}  通 OK"; else echo "  ${PROXY_HOST}:${p}  不通"; fi
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
    echo "[4] 候选代理端口"
    local p
    for p in $CANDIDATE_PORTS; do
        if _port_ok "$p"; then echo "      ${p} 通 OK"; else echo "      ${p} 不通"; fi
    done
    echo "[5] git 代理"
    git config --global --get http.proxy 2>/dev/null | sed 's/^/      http.proxy = /'
    git config --global --get "http.http://${INTRA_GIT_HOST}.proxy" 2>/dev/null | sed 's/^/      内网例外   = /'
}
