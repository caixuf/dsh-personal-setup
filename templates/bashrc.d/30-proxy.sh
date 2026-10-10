# templates/bashrc.d/30-proxy.sh
# 代理快捷开关 + 幽灵代理纠正
#
# 安装：追加到 ~/.bashrc（不要覆盖整份）
#
# ⚠️ 本块必须放在交互守卫【之后】，因为它依赖 ~/.proxy.sh 里的 proxy_port_alive 函数。
# ✅ ~/.proxy.sh 的内容就在 templates/proxy.sh —— 只含端口与白名单，**不含密钥**。
#    安装：cp templates/proxy.sh ~/.proxy.sh   （**不需要**从旧机复制）

# --- 代理快捷开关 (proxy_on / proxy_off / proxy_test) ---
# 由 ~/.proxy.sh 提供。自动开启，但仅在代理端口活着时才开 ——
# 这样代理软件没启动时会优雅降级为直连，而不是所有请求一起断。
# 如需强制关闭自动代理：export WSL_NO_AUTO_PROXY=1
[ -f ~/.proxy.sh ] && source ~/.proxy.sh

# >>> wsl-proxy-autofix v7 >>>
# 策略：未设置 -> 开启；指向本地端口但那个端口不活（幽灵）-> 覆盖；非本地代理 -> 不动。
#
# 背景：mirrored 模式会继承 Windows 的代理与 bypass 列表（10.* / *.immotors.com
# 这种通配格式比 CIDR 更好），只要端口是对的就别动它。
#
# 幽灵来源：编辑器 remote server 的 server-env-setup 会往子进程注入写死的 http_proxy，
# 换代理软件后那个端口就变成死地址。
# ⚠️ 后果：agy / opencode 这类 Go 程序只读【小写】http_proxy，会**静默卡死**（不报错）。
if [ -z "${WSL_NO_AUTO_PROXY:-}" ] && proxy_port_alive 2>/dev/null; then
    _wb_cur="${http_proxy:-}"
    if [ -z "$_wb_cur" ]; then
        proxy_on >/dev/null
    else
        case "$_wb_cur" in
            *127.0.0.1:*|*localhost:*)
                _wb_port=$(printf '%s' "$_wb_cur" | sed -n 's#.*:\([0-9][0-9]*\)/*$#\1#p')
                [ "$_wb_port" = "$PROXY_PORT" ] || proxy_on >/dev/null
                ;;
            *)
                : ;;   # 公司代理等非本地地址：不动
        esac
    fi
    unset _wb_cur _wb_port
fi
# <<< wsl-proxy-autofix v7 <<<
