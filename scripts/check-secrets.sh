#!/bin/bash
# check-secrets.sh — 提交前扫描：确认仓库内没有明文密钥
#
# 用法：
#   bash scripts/check-secrets.sh          # 扫描工作区
#   bash scripts/check-secrets.sh --staged # 只扫 git 暂存区（推荐做 pre-commit）
#
# 设计：**排除注释行**，避免把文档里的示例/警告误报成泄漏。
# 真实赋值形如  export FOO=sk-ant-xxxxx  或  "api_key": "sk-xxx"

set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-worktree}"

# 高置信度的密钥特征（宁可少报，也不要因误报让人忽视真警报）
PATTERNS='sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|trae-lt-[a-f0-9]{20,}|ghp_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'

found=0

scan_text() {
    # $1 = 内容, $2 = 来源标签
    # 逐行检查，跳过「以 # 开头的注释行」和「含省略号的占位」
    local src="$1" content="$2"
    local lineno=0
    while IFS= read -r line; do
        lineno=$((lineno + 1))
        # 跳过注释行（允许前置空白）
        case "${line#"${line%%[![:space:]]*}"}" in
            '#'*) continue ;;
        esac
        # 跳过明显的占位（含 ... 或 <REDACTED> 或 xxxxx）
        case "$line" in
            *'...'*|*'<REDACTED>'*|*'xxxx'*|*'YOUR_'*|*'<your'*) continue ;;
        esac
        if printf '%s' "$line" | grep -qE "$PATTERNS"; then
            printf '  ⚠️  %s:%d\n      %s\n' "$src" "$lineno" "$(printf '%s' "$line" | cut -c1-100)"
            found=1
        fi
    done <<< "$content"
}

if [ "$MODE" = "--staged" ]; then
    if ! command -v git >/dev/null 2>&1 || ! git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
        echo "  不是 git 仓库，改用工作区扫描"
        MODE=worktree
    fi
fi

if [ "$MODE" = "--staged" ]; then
    echo "=== 扫描 git 暂存区 ==="
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        # 跳过二进制与 node_modules
        case "$f" in
            *node_modules*|*.png|*.jpg|*.webp|*.gif|*.webm|*.tgz|*.zip) continue ;;
        esac
        content=$(git -C "$REPO" show ":$f" 2>/dev/null) || continue
        scan_text "$f" "$content"
    done < <(git -C "$REPO" diff --cached --name-only 2>/dev/null)
else
    echo "=== 扫描工作区（排除注释行） ==="
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        content=$(cat "$f" 2>/dev/null) || continue
        scan_text "${f#$REPO/}" "$content"
    done < <(find "$REPO" -type f \
                -not -path '*/.git/*' \
                -not -path '*/node_modules/*' \
                \( -name '*.sh' -o -name '*.md' -o -name '*.yml' -o -name '*.yaml' \
                   -o -name '*.json' -o -name '*.service' -o -name '*.mount' \
                   -o -name '*.js' -o -name '*.mjs' -o -name '*.ts' -o -name '*.env*' \) 2>/dev/null)
fi

echo
if [ "$found" -eq 0 ]; then
    echo "✅ 未发现明文密钥"
    exit 0
else
    echo "❌ 发现疑似明文密钥 —— 不要提交！"
    echo
    echo "处置："
    echo "  1. 从文件中移除密钥，改为从环境变量/密钥库读取"
    echo "  2. 若已提交过，需 git filter-repo 清理历史"
    echo "  3. **并轮换所有已泄漏的密钥**（清理历史不等于密钥安全）"
    exit 1
fi
