#!/usr/bin/env bash
# 给 dsh-bot-gateway 的看板打补丁：修「对话框无法输入」
#
# 根因（webui-app.js）：
#   通用设置页里那三个模型下拉在 `fetchModelsCatalog().then(...)` 异步回调里
#   被无条件 `innerHTML` 重建，而保护标志 isFormPopulated 只覆盖第一批表单，
#   管不到这个异步回调 → 用户正在输入时下拉被换掉，焦点丢失、打字作废。
#   最小化再打开能好，是因为重挂载时表单是空的，没有"正在输入"这个状态。
#
# 修法：沿用作者自己给 users-table 的思路（见其 L804 注释），把焦点保护
#       扩大到整个面板。作者只保护了表格一处，其它输入框全裸。
#
# 纯 UI 层防抖：不改逻辑、不动协议、不碰适配器与安全边界。
# 幂等：已打过则跳过。
set -uo pipefail

# ⚠️ 插件在 Windows 侧（/mnt/c/...），不在 WSL 的 $HOME 下 —— 用 --dsh-home 指定
DSH_HOME="${DSH_HOME:-/mnt/c/Users/20247/.dsh}"
[ -d "$DSH_HOME" ] || { echo "找不到 DSH_HOME: $DSH_HOME"; exit 1; }

FILES=(
  "$DSH_HOME/profiles/desktop/node_modules/dsh-bot-gateway/lib/webui-app.js"
  "$DSH_HOME/node_modules/dsh-bot-gateway/lib/webui-app.js"
)

MARKER="dsh-bot-gateway-patch:guard-model-select"

for F in "${FILES[@]}"; do
  echo "--- $F"
  if [ ! -f "$F" ]; then echo "    跳过（不存在）"; continue; fi

  if grep -q "$MARKER" "$F"; then
    echo "    已打过补丁，跳过"
    continue
  fi

  [ -f "$F.bak-orig" ] || cp "$F" "$F.bak-orig"

  # 在 fetchModelsCatalog().then(...) 回调开头插入焦点保护
  python3 - "$F" "$MARKER" <<'PY'
import sys, io
path, marker = sys.argv[1], sys.argv[2]
src = io.open(path, encoding='utf-8').read()

anchor = "    fetchModelsCatalog().then(function () {\n      var box1 = $('cfg-model-box');"
if anchor not in src:
    print("    ✗ 找不到锚点，未修改（插件版本可能变了）")
    sys.exit(2)

guard = (
    "    fetchModelsCatalog().then(function () {\n"
    "      // %s\n"
    "      // 通用设置页的输入框正在被使用时不重建模型下拉，否则焦点被夺走、打字作废。\n"
    "      // 作者已在 users-table 用了同样思路（L804 domInUse），这里补齐其余输入框。\n"
    "      if (anyInputFocused()) return;\n"
    "      var box1 = $('cfg-model-box');" % marker
)

src = src.replace(anchor, guard, 1)

# 注入 anyInputFocused() 辅助函数（插在 domInUse 定义之后）
fn_anchor = "  function domInUse(rootEl) {"
if fn_anchor in src and "function anyInputFocused()" not in src:
    start = src.index(fn_anchor)
    end = src.index("\n  }\n", start) + len("\n  }\n")
    helper = (
        "\n\n"
        "  // %s\n"
        "  // 面板内任一 input/textarea/select 处于聚焦状态即视为「正在使用」。\n"
        "  function anyInputFocused() {\n"
        "    var ae = document.activeElement;\n"
        "    if (!ae) return false;\n"
        "    var t = ae.tagName;\n"
        "    return t === 'INPUT' || t === 'TEXTAREA' || t === 'SELECT';\n"
        "  }\n" % marker
    )
    src = src[:end] + helper + src[end:]

io.open(path, 'w', encoding='utf-8', newline='').write(src)
print("    ✓ 已打补丁")
PY

  # 语法校验
  node --check "$F" 2>/dev/null && echo "    ✓ 语法通过" || echo "    ✗ 语法错误！从 .bak-orig 还原"
done

echo ""
echo "验证："
for F in "${FILES[@]}"; do
  [ -f "$F" ] || continue
  printf "  %s : marker=%s  guard=%s\n" \
    "$(basename $(dirname $(dirname "$F")))" \
    "$(grep -c "$MARKER" "$F")" \
    "$(grep -c 'anyInputFocused' "$F")"
done
