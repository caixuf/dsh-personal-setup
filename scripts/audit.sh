#!/bin/bash
# audit.sh — 盘点【当前机】的实际状态，供 AI 与本仓库的 intent/ 对比
#
# 用法：
#   bash scripts/audit.sh              # 打印到 stdout
#   bash scripts/audit.sh > audit.txt  # 存文件，交给 AI 对比
#
# 设计意图：输出**结构化、可 diff** 的事实，不要解读、不要建议。
# AI 会拿它与 intent/*.md 的期望值对比，决定装什么、改什么。

set -u

hr() { printf '\n===== %s =====\n' "$1"; }

hr "环境基本信息"
echo "hostname   : $(hostname)"
echo "user       : $(whoami)  (uid=$(id -u))"
echo "home       : $HOME"
echo "distro     : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")"
echo "kernel     : $(uname -r)"
echo "arch       : $(uname -m)"
echo "wsl        : $(grep -qi microsoft /proc/version 2>/dev/null && echo yes || echo no)"
echo "systemd    : $(systemctl is-system-running 2>/dev/null || echo unknown)"
echo "sudo免密   : $(sudo -n true 2>/dev/null && echo yes || echo no)"

hr "关键命令可用性"
for c in node npm pnpm python3 pip3 git gh jq rg docker bwrap ffmpeg cloc cmake gcc make \
         curl wget rsync tar unzip sshpass lsof ss nc dig telnet; do
    if command -v "$c" >/dev/null 2>&1; then
        printf '  %-10s OK      %s\n' "$c" "$(command -v "$c")"
    else
        printf '  %-10s MISSING\n' "$c"
    fi
done

hr "版本"
echo "node   : $(node -v 2>/dev/null || echo -)"
echo "npm    : $(npm -v 2>/dev/null || echo -)"
echo "pnpm   : $(pnpm -v 2>/dev/null || echo -)"
echo "python : $(python3 -V 2>&1 || echo -)"
echo "git    : $(git --version 2>/dev/null || echo -)"
echo "docker : $(docker --version 2>/dev/null || echo -)"
echo "corepack: $(corepack --version 2>/dev/null || echo -)"

hr "WSL 配置（Windows 侧）"
WSL_CFG="/mnt/c/Users/$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')/.wslconfig"
if [ -f "$WSL_CFG" ]; then
    echo "路径: $WSL_CFG"
    grep -vE '^\s*#|^\s*$' "$WSL_CFG"
    echo "--- 关键项检查 ---"
    grep -q 'networkingMode\s*=\s*mirrored' "$WSL_CFG" \
        && echo "  networkingMode=mirrored  OK（代理机制的前提）" \
        || echo "  ⚠️ networkingMode 不是 mirrored —— 代理会失效"
else
    echo "⚠️ 未找到 .wslconfig（路径探测: $WSL_CFG）"
fi

hr "网络与代理"
echo "--- 默认路由 ---"
ip route show default 2>/dev/null | sed 's/^/  /'
echo "--- 候选代理端口 ---"
for p in 7897 7899 7892; do
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/$p" 2>/dev/null; then
        echo "  $p  TCP可达"
    else
        echo "  $p  不通"
    fi
done
echo "--- 代理环境变量 ---"
for v in http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
    eval "val=\${$v:-}"
    [ -n "$val" ] && echo "  $v = $val"
done
echo "--- DNS ---"
grep nameserver /etc/resolv.conf 2>/dev/null | sed 's/^/  /'
echo "--- 内网 GitLab hosts 条目 ---"
grep -q 'gitlab-ap-office.immotors.com' /etc/hosts 2>/dev/null \
    && echo "  存在 OK" || echo "  缺失（fix-wsl-net.service 会在开机补）"

hr "dotfile 自定义块"
for f in ~/.bashrc ~/.profile; do
    echo "--- $f ($(wc -l < "$f" 2>/dev/null || echo 0) 行) ---"
    grep -nE '^# (-{2,}|>{3,}|<{3,}|Added by|=====)' "$f" 2>/dev/null | sed 's/^/  /'
done
echo "--- 独立文件 ---"
for f in ~/.proxy.sh ~/.ccp/env.sh ~/.npmrc ~/.gitconfig; do
    [ -f "$f" ] && echo "  $f  存在 ($(wc -l < "$f") 行)" || echo "  $f  缺失"
done

hr "PATH 中用户级目录可解析性（登录式 shell）"
# 这是踩坑点：非交互登录 shell 读 .profile，不读 .bashrc
bash -lc 'for d in "$HOME/.npm-global/bin" "$HOME/.local/bin"; do printf "  %-28s " "$d"; case ":$PATH:" in *":$d:"*) echo "在 PATH";; *) echo "不在 PATH";; esac; done'
bash -lc 'echo "  pnpm (登录式 shell): $(command -v pnpm || echo 找不到)"'

hr "本地服务端口"
ss -tlnp 2>/dev/null | grep -E ':(4000|4001|8118|9900|22|631)\b' | sed 's/^/  /' || echo "  (无匹配)"

hr "systemd 自定义单元"
for u in fix-wsl-net.service imfl-autotest.service mnt-bh.mount mnt-xw.mount mnt-ql.mount mnt-zq.mount; do
    if [ -f "/etc/systemd/system/$u" ]; then
        st=$(systemctl is-enabled "$u" 2>/dev/null || echo '?')
        act=$(systemctl is-active "$u" 2>/dev/null || echo '?')
        printf '  %-24s enabled=%-10s active=%s\n' "$u" "$st" "$act"
    else
        printf '  %-24s (不存在)\n' "$u"
    fi
done
echo "--- 卡住的 systemd 任务（>0 会导致 WSL 挂死）---"
n=$(systemctl list-jobs --no-pager 2>/dev/null | grep -c 'running\|waiting' || echo 0)
echo "  进行中任务数: $n"
systemctl list-jobs --no-pager 2>/dev/null | tail -n +2 | sed 's/^/  /'

hr "apt 手动安装包（$(apt-mark showmanual 2>/dev/null | wc -l) 个）"
apt-mark showmanual 2>/dev/null | sort | tr '\n' ' ' | fold -s -w 100 | sed 's/^/  /'

hr "npm 全局包"
npm ls -g --depth=0 2>/dev/null | tail -n +2 | sed 's/^/  /'

hr "pip 用户级包（$(pip3 list --user --format=freeze 2>/dev/null | wc -l) 个，仅列前 40）"
pip3 list --user --format=freeze 2>/dev/null | head -40 | sed 's/^/  /'

hr "~/.local/bin 自定义脚本"
ls -1 ~/.local/bin 2>/dev/null | grep -v '__pycache__' | head -50 | sed 's/^/  /'

hr "DSH 状态"
# ⚠️ 分两部分报告：**Windows 侧才是主 DSH**（Desktop 版，profile 名 desktop）。
#    WSL 内的 ~/.dsh 通常是残留或别的 profile，不要混淆（曾因此查错地方）。
WINUSER=$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')
WINHOME="/mnt/c/Users/$WINUSER"
WINDSH="$WINHOME/.dsh"

echo "########## 主 DSH（Windows 侧）##########"
echo "路径: $WINDSH"
if [ -d "$WINDSH" ]; then
    echo "--- 顶层内容 ---"
    ls -1 "$WINDSH" 2>/dev/null | sed 's/^/  /'
    echo "--- profile 列表与 bundle 数 ---"
    for pdir in "$WINDSH"/profiles/*/; do
        [ -d "$pdir" ] || continue
        pj="$pdir/package.json"
        [ -f "$pj" ] || continue
        cnt=$(python3 -c "
import json
try:
    d = json.load(open('$pj', encoding='utf-8'))
    print(len(d.get('dsh', {}).get('profile', {}).get('bundles', [])))
except Exception:
    print('?')
" 2>/dev/null)
        echo "  $(basename "$pdir"): ${cnt} bundles"
    done
    echo "--- 桌宠完整性（期望 70 文件 / 51 动画 / 4 预览）---"
    PET="$WINDSH/profiles/desktop/node_modules/dsh-whale-girl-pet"
    if [ -d "$PET" ]; then
        echo "  文件: $(find "$PET" -type f 2>/dev/null | wc -l)/70"
        echo "  动画: $(find "$PET/assets/thumb" -type f 2>/dev/null | wc -l)/51"
        echo "  预览: $(find "$PET/assets/preview" -type f 2>/dev/null | wc -l)/4"
    else
        echo "  （未找到桌宠目录）"
    fi
    echo "--- 皮肤状态 ---"
    [ -f "$WINDSH/skin-center-active.json" ] && sed 's/^/  /' "$WINDSH/skin-center-active.json"
    echo "--- 凭据库（仅行数，不显示值）---"
    [ -f "$WINDSH/.credentials.yaml" ] && echo "  行数: $(wc -l < "$WINDSH/.credentials.yaml")"
    echo "--- 机器绑定项 ---"
    echo "  Windows 用户名: ${WINUSER:-探测失败}（期望 20247）"
    grep -o 'file:[^"]*' "$WINDSH/profiles/desktop/package.json" 2>/dev/null | sed 's/^/    file依赖: /'
else
    echo "  ⚠️ Windows 侧 ~/.dsh 不可达（探测路径: $WINDSH）"
fi

echo
echo "########## WSL 内的 ~/.dsh（通常非主实例）##########"
D="$HOME/.dsh"
if [ -d "$D" ]; then
    echo "路径: $D"
    du -sh "$D"/* 2>/dev/null | sed 's/^/  /'
    echo "  profiles: $(ls -1 "$D/profiles" 2>/dev/null | tr '\n' ' ')"
    echo "  ⚠️ profile 名与 Windows 侧不同则属残留，迁移时不要当主配置"
else
    echo "  （不存在）"
fi

hr "GPU"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/  /'
    [ -e /dev/dxg ] && echo "  /dev/dxg 存在（WSL GPU 直通）" || echo "  /dev/dxg 缺失"
else
    echo "  nvidia-smi 不可用（无 NVIDIA GPU 或无驱动）"
fi

hr "audit 完成"
echo "把以上输出与 intent/ 下各文件的期望值对比，只补齐差异项。"
