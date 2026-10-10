#!/bin/bash
# apply.sh — 在新机上按 intent/ 落地个性化配置
#
# ⚠️ 这是**辅助脚本**，不是全自动安装器。它只做安全、幂等的部分，
#    需要判断或含密钥的部分会打印提示，交由人工或 AI 处理。
#
# 用法：
#   bash scripts/apply.sh --check     # 只做体检，不改任何东西（默认）
#   bash scripts/apply.sh --dotfiles  # 落地 dotfile 片段（追加式，幂等）
#   bash scripts/apply.sh --systemd   # 落地 systemd 单元
#   bash scripts/apply.sh --all       # 上述全部
#
# 设计原则：
#   1. **追加而非覆盖** dotfile（新机已有内容必须保留）
#   2. **幂等** —— 重复运行不产生重复内容（靠标记检测）
#   3. **不碰密钥** —— 遇到需要密钥的地方停下并提示

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

    hr "WSL 网络模式（代理机制前提）"
    WINUSER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
    CFG="/mnt/c/Users/$WINUSER/.wslconfig"
    if [ -f "$CFG" ]; then
        grep -q 'networkingMode\s*=\s*mirrored' "$CFG" \
            && say "networkingMode=mirrored ✓" \
            || warn "不是 mirrored —— 代理会失效，需改后 wsl --shutdown"
    else
        warn "未找到 $CFG"
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
    say "4. 最后跑 scripts/apply.sh --check 复查"
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
    --dotfiles)  do_dotfiles ;;
    --systemd)   do_systemd ;;
    --all)       check; do_dotfiles; do_systemd ;;
    -h|--help)
        cat <<'EOF'
用法: bash scripts/apply.sh [选项]

  --check     只做体检，不改任何东西（默认）
  --dotfiles  落地 dotfile 片段（追加式，幂等）
  --systemd   落地 systemd 单元
  --all       上述全部

先读 intent/ 目录，再读 README.md 的「AI 配置新机的流程」。
EOF
        ;;
    *) warn "未知选项: $MODE（用 --help 查看）"; exit 1 ;;
esac
