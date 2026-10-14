#!/bin/bash
# apply.sh — 在新机上按 intent/ 落地个性化配置
#
# ⚠️ 这是**辅助脚本**，不是全自动安装器。它只做安全、幂等的部分，
#    需要判断或含密钥的部分会打印提示，交由人工或 AI 处理。
#
# 用法：
#   bash scripts/apply.sh --check     # 只做体检，不改任何东西（默认）
#   bash scripts/apply.sh --dsh       # 落地 DSH profile 配置（复制三件 + 体检）
#   bash scripts/apply.sh --dotfiles  # 落地 dotfile 片段（追加式，幂等）
#   bash scripts/apply.sh --systemd   # 落地 systemd 单元
#   bash scripts/apply.sh --all       # 上述全部
#
# 设计原则：
#   1. **追加而非覆盖** dotfile（新机已有内容必须保留）
#   2. **幂等** —— 重复运行不产生重复内容（靠标记检测）
#   3. **不碰密钥** —— 遇到需要密钥的地方停下并提示
#   4. **DSH 侧只复制配置，不代跑 install** —— 桌面版 install 必须走
#      plugin_manager 工具（见 intent/dsh.md），脚本代跑会绕过
#      「假失败」判定逻辑，反而更难排查

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARK_BEGIN="# >>> dsh-personal-setup >>>"
MARK_END="# <<< dsh-personal-setup <<<"

MODE="${1:---check}"

say()  { printf '  %s\n' "$*"; }
hr()   { printf '\n===== %s =====\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }

# 把一段内容幂等地追加到目标文件（用标记包裹，重复运行则替换）
append_block() {
    local target="$1" blockfile="$2" name="$3"
    [ -f "$blockfile" ] || { warn "模板缺失: $blockfile"; return 1; }
    touch "$target"
    if grep -qF "$MARK_BEGIN $name" "$target" 2>/dev/null; then
        say "已存在（跳过）: $name  ->  $target"
        return 0
    fi
    {
        printf '\n%s %s\n' "$MARK_BEGIN" "$name"
        printf '# 来源: %s\n' "${blockfile#$REPO/}"
        cat "$blockfile"
        printf '%s %s\n' "$MARK_END" "$name"
    } >> "$target"
    say "已追加: $name  ->  $target"
}

check() {
    hr "前置检查"
    say "repo 路径: $REPO"

    if grep -qi microsoft /proc/version 2>/dev/null; then
        say "环境: WSL ✓"
    else
        warn "不在 WSL 内 —— 本仓库的 dotfile 片段假定 WSL2 环境"
    fi

    hr "PATH 关键项（登录式 shell）"
    bash -lc 'for d in "$HOME/.npm-global/bin" "$HOME/.local/bin"; do
        printf "  %-28s " "$d"
        case ":$PATH:" in *":$d:"*) echo "在 PATH";; *) echo "缺失 <- 需加 templates/profile.d/";; esac
    done'

    hr "dotfile 是否已有本仓库的块"
    for f in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$f" ] || continue
        # 注意：grep -c 无匹配时返回 0 且退出码 1，故用 ; 而非 || ，避免多打印一行
        n=$(grep -cF "$MARK_BEGIN" "$f" 2>/dev/null); n=${n:-0}
        say "$f : $n 个块"
    done

    hr "WSL 网络拓扑 + 代理真实可达性"
    WINUSER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
    CFG="/mnt/c/Users/$WINUSER/.wslconfig"
    GW=$(ip route show default 2>/dev/null | awk '/^default/{print $3; exit}')
    if [ -f "$CFG" ]; then
        if grep -q 'networkingMode\s*=\s*mirrored' "$CFG"; then
            say "networkingMode=mirrored —— WSL 内 127.0.0.1 直通宿主"
        else
            say "未设 networkingMode → NAT 模式（本机网关 ${GW:-未知}）"
            say "  代理须监听在宿主的 portproxy/全接口上，WSL 侧经网关 IP 访问。"
            say "  ⚠️ 这**不是**故障 —— 以下面的实测出网为准，不要仅凭此项去改 .wslconfig。"
        fi
    else
        warn "未找到 $CFG"
    fi

    # 真探活：候选端口 × {127.0.0.1, 默认网关}
    # 只看配置、或只看「端口开着」都会被误导（端口可能被别的程序占着，NAT 下 localhost 也不通）
    _cands=$(grep -oE '_wsl_candidates=\([^)]*\)' "$HOME/.proxy.sh" 2>/dev/null | sed 's/.*(\(.*\))/\1/')
    [ -n "$_cands" ] || _cands="7897 7898 7899 7892"
    say "候选端口（取自 ~/.proxy.sh，缺省 7897 7898 7899 7892）: $_cands"
    _hit=""
    for _h in 127.0.0.1 "$GW"; do
        [ -n "$_h" ] || continue
        for _p in $_cands; do
            _code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 \
                    -x "http://$_h:$_p" https://www.gstatic.com/generate_204 2>/dev/null)
            case "$_code" in
                200|204|301|302) say "  ✓ $_h:$_p 出网正常 (HTTP $_code)"; [ -n "$_hit" ] || _hit="$_h:$_p" ;;
            esac
        done
    done
    if [ -n "$_hit" ]; then
        say "代理可用 ✓（首个命中 $_hit）"
    else
        warn "所有候选端口都不通 —— 检查宿主代理软件是否已启动、端口是否与 ~/.proxy.sh 一致"
    fi

    hr "systemd 是否有阻塞任务"
    j=$(systemctl list-jobs --no-pager 2>/dev/null | tail -n +2 | wc -l)
    [ "$j" -eq 0 ] && say "无进行中任务 ✓" || { warn "$j 个任务进行中"; systemctl list-jobs --no-pager | sed 's/^/    /'; }

    hr "需要的密钥（人工处理，见 intent/secrets.md）"
    for f in "$HOME/.config/litellm/proxy.env" "$HOME/.ccp/secrets.env"; do
        [ -f "$f" ] && say "$f 存在 ✓" || warn "$f 缺失 —— 需按 intent/secrets.md 手工创建"
    done

    hr "下一步建议"
    say "1. 先跑 scripts/audit.sh，把输出与 intent/packages.md 对比，补齐 apt/npm/pip 包"
    say "2. 再跑 scripts/apply.sh --dotfiles 落地 dotfile 片段"
    say "3. 手工处理密钥与服务（intent/secrets.md、intent/services.md）"
    say "4. DSH 插件侧见 intent/dsh.md（含 free-model 的 npm 取法、plugin_manager 假失败的判定与修复）"
    say "5. 最后跑 scripts/apply.sh --check 复查"
}

do_dsh() {
    hr "落地 DSH profile 配置"

    WINUSER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
    [ -n "$WINUSER" ] || die "取不到 Windows 用户名（cmd.exe 不可用？）"

    # WSL 下 /mnt/c/<user>；若路径形态不同（非标准挂载）则退回 C:\ 形式提示
    PROFILE_DIR="$HOME/.dsh/profiles/desktop"
    WIN_PROFILE_DIR="/mnt/c/Users/$WINUSER/.dsh/profiles/desktop"

    if [ ! -d "$PROFILE_DIR" ] && [ ! -d "$WIN_PROFILE_DIR" ]; then
        warn "两个可能的 profile 目录都不存在："
        say "  $PROFILE_DIR"
        say "  $WIN_PROFILE_DIR"
        warn "若 DSH 装在 Windows 侧，请先启动一次 DSH Desktop 让它建出 profile"
    fi

    TARGET="$PROFILE_DIR"
    [ -d "$TARGET" ] || TARGET="$WIN_PROFILE_DIR"

    hr "🚨 机器绑定项自检（在覆盖**之前**跑）=="

    # --- 1) 查【即将写入的模板】：模板里绝不能有 link: 机器路径 ---
    _tpkgs="$REPO/templates/dsh/package.json"
    _tlinks=$(grep -oE '"[^"]+": "link:[^"]*"' "$_tpkgs" 2>/dev/null || true)
    if [ -z "$_tlinks" ]; then
        say "✓ 模板无 link: 依赖 —— 通用基线，任何机器可直接 install"
    else
        warn "模板里居然有 link: 依赖（这是 bug，模板不该绑机器）："
        printf '%s\n' "$_tlinks" | while IFS= read -r l; do
            [ -n "$l" ] && warn "    $l"
        done
        warn "  👉 模板必须跨机可用；fork 之类机器增强请走 intent/dsh.md 的选装流程。"
    fi

    # --- 2) 查【目标已有配置】：即将被覆盖，别静默毁掉别人的 fork ---
    _epkgs="$TARGET/package.json"
    if [ -f "$_epkgs" ]; then
        _elinks=$(grep -oE '"[^"]+": "link:[^"]*"' "$_epkgs" 2>/dev/null || true)
        if [ -n "$_elinks" ]; then
            warn "⚠️ 目标已存在 link: 依赖，**即将被模板覆盖**："
            printf '%s\n' "$_elinks" | while IFS= read -r l; do
                [ -n "$l" ] && warn "    $l"
            done
            warn "  若那是你刻意配的（如 WSL fork），覆盖后会退回官方版。"
            warn "  备份会存为 .bak-<时间戳>，需要时从备份恢复。"
        fi
    fi

    hr "复制三件（先备份）=="
    mkdir -p "$TARGET"

    # --- 3) 查【目标 patch 里的本地密钥】：模板是不含密钥的，覆盖会把它抹掉 ---
    #     模板 templates/dsh/cordis.patch.yml 的 dsh-sync 段**只有 token 注释、没有值**
    #     （这是刻意的，仓库公开）。本机实机的 token 一旦被模板覆盖就没了，
    #     表现为 dsh-sync 下次同步鉴权失败。
    _epatch="$TARGET/cordis.patch.yml"
    if [ -f "$_epatch" ] && grep -qE '^[[:space:]]+token:[[:space:]]*["'"'"']?[A-Za-z0-9_-]{20,}' "$_epatch" 2>/dev/null; then
        warn "⚠️ 目标 cordis.patch.yml 含**明文 token**（dsh-sync 等），覆盖后会丢失："
        warn "    模板里那一行只有注释占位（仓库公开，不放密钥）。"
        warn "    处置：先备份 token，覆盖后**重新填回**，或干脆别跑本步、手工合并。"
    fi

    STAMP=$(date +%Y%m%d-%H%M%S)
    for f in package.json cordis.patch.yml pnpm-workspace.yaml; do
        src="$REPO/templates/dsh/$f"
        dst="$TARGET/$f"
        if [ ! -f "$src" ]; then warn "模板缺失，跳过: $f"; continue; fi
        if [ -f "$dst" ]; then
            cp "$dst" "$dst.bak-$STAMP"
            say "已备份 $f → $f.bak-$STAMP"
        fi
        cp "$src" "$dst"
        say "已复制 $f"
    done

    hr "下一步 = 装 bundle（一条命令）=="
    say "在 **PowerShell** 里跑（dsh 是 Windows 程序，不能在 WSL/bash 里跑）："
    say "  cd \$(cygpath -u '$REPO' 2>/dev/null || pwd)"
    say "  powershell -ExecutionPolicy Bypass -File scripts/install-dsh.ps1 -Profile desktop"
    say ""
    say "它会：备份 profile → 对模板 dependencies 逐个 dsh add"
    say "     （add 自动装包 + 自动登记 bundles）→ 报告成败 → 打印下一步。"
    say ""
    say "先看要装什么而不真装：加 -DryRun"
    say ""
    say "⚠️ 若脚本不可用，退路是在 DSH 里用 plugin_manager 逐个 install_bundle。"
    say "   判定与假失败修复见 intent/dsh.md"
    say ""
    say "⚠️ active ≠ 能用（内置 Tabbit、skin-center 都栽过），必须实测功能"
}

do_dotfiles() {
    hr "落地 dotfile 片段（追加式，幂等）"
    for f in "$REPO"/templates/bashrc.d/*.sh; do
        [ -f "$f" ] || continue
        append_block "$HOME/.bashrc" "$f" "$(basename "$f")"
    done
    for f in "$REPO"/templates/profile.d/*.sh; do
        [ -f "$f" ] || continue
        append_block "$HOME/.profile" "$f" "$(basename "$f")"
    done

    # ~/.proxy.sh 是独立文件（不在 templates/bashrc.d）
    if [ -f "$REPO/templates/proxy.sh" ]; then
        if [ -f "$HOME/.proxy.sh" ]; then
            say "~/.proxy.sh 已存在（保留现有，未覆盖）"
        else
            cp "$REPO/templates/proxy.sh" "$HOME/.proxy.sh"
            say "已安装 ~/.proxy.sh"
        fi
    fi

    hr "提示"
    say "dotfile 改动需新开 shell 或 source 生效："
    say "  source ~/.bashrc"
    say "验证: proxy_test"
}

do_systemd() {
    hr "落地 systemd 单元"
    if [ ! -d "$REPO/templates/systemd" ]; then
        warn "templates/systemd 不存在"; return 1
    fi
    for f in "$REPO"/templates/systemd/*.service; do
        [ -f "$f" ] || continue
        b=$(basename "$f")
        if [ -f "/etc/systemd/system/$b" ]; then
            say "已存在（保留现有）: $b"
        else
            sudo cp "$f" "/etc/systemd/system/$b" && say "已安装: $b"
        fi
    done

    # fix-wsl-net 的脚本本体
    if [ -f "$REPO/templates/systemd/fix-wsl-net.sh" ]; then
        sudo cp "$REPO/templates/systemd/fix-wsl-net.sh" /usr/local/sbin/fix-wsl-net.sh
        sudo chmod +x /usr/local/sbin/fix-wsl-net.sh
        say "已安装 /usr/local/sbin/fix-wsl-net.sh"
    fi

    sudo systemctl daemon-reload
    say "daemon-reload done"

    hr "⚠️ 未自动处理的单元"
    say "imfl-autotest.service 需先把代码 clone 到 ~/code/imfl_auto_test"
    say "  （其 WorkingDirectory / EnvironmentFile 是绝对路径，用户名不同需改）"
    say "mnt-*.mount 指向可能离线的 Samba 服务器"
    say "  ⚠️ 不要设为开机自动挂载 —— 会导致 WSL 完全无法启动（见 intent/wsl.md）"
}

case "$MODE" in
    --check|"")  check ;;
    --dsh)       do_dsh ;;
    --dotfiles)  do_dotfiles ;;
    --systemd)   do_systemd ;;
    --all)       check; do_dsh; do_dotfiles; do_systemd ;;
    -h|--help)
        cat <<'EOF'
用法: bash scripts/apply.sh [选项]

  --check     只做体检，不改任何东西（默认）
  --dsh       落地 DSH profile 配置三件（先备份）+ 机器绑定项自检
  --dotfiles  落地 dotfile 片段（追加式，幂等）
  --systemd   落地 systemd 单元
  --all       上述全部

先读 intent/ 目录，再读 README.md 的「AI 配置新机的流程」。
EOF
        ;;
    *) warn "未知选项: $MODE（用 --help 查看）"; exit 1 ;;
esac
