#!/usr/bin/env bash
# 审计：仓库模板 vs 本机实际 profile 的差异
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# DSH Desktop 的 profile 在 Windows 侧，不一定在这台 WSL 的 $HOME 下。
# 用法：audit-dsh-drift.sh [--profile <dir>]  或设 DSH_PROFILE_DIR
if [ "${1:-}" = "--profile" ] && [ -n "${2:-}" ]; then
  PROFILE="$2"
elif [ -n "${DSH_PROFILE_DIR:-}" ]; then
  PROFILE="$DSH_PROFILE_DIR"
else
  PROFILE="/mnt/c/Users/20247/.dsh/profiles/desktop"
  [ -d "$PROFILE" ] || PROFILE="$HOME/.dsh/profiles/desktop"
fi
DSH_HOME="$(dirname "$(dirname "$PROFILE")")"
echo "profile 目录: $PROFILE"
echo "dsh home    : $DSH_HOME"
[ -d "$PROFILE" ] || echo "⚠️ 目录不存在 —— 用 --profile <dir> 指定真实位置"

echo "########## 1. 本机 profile 实际依赖 ##########"
if [ -f "$PROFILE/package.json" ]; then
  python3 - "$PROFILE/package.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
print("  dependencies:")
for k,v in sorted(d.get('dependencies',{}).items()):
    print(f"    {k} = {v}")
print("  bundles:")
for b in d.get('dsh',{}).get('profile',{}).get('bundles',[]):
    print(f"    {b}")
PY
fi

echo ""
echo "########## 2. 仓库模板依赖 ##########"
if [ -f "$REPO/templates/dsh/package.json" ]; then
  python3 - "$REPO/templates/dsh/package.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
print("  dependencies:")
for k,v in sorted(d.get('dependencies',{}).items()):
    print(f"    {k} = {v}")
print("  bundles:")
for b in d.get('dsh',{}).get('profile',{}).get('bundles',[]):
    print(f"    {b}")
PY
fi

echo ""
echo "########## 3. 差异（本机有 / 模板缺）##########"
python3 - "$PROFILE/package.json" "$REPO/templates/dsh/package.json" <<'PY'
import json,sys
def load(p):
    try:
        d=json.load(open(p,encoding='utf-8'))
        return set(d.get('dependencies',{})), set(d.get('dsh',{}).get('profile',{}).get('bundles',[]))
    except Exception as e:
        print("  读取失败:",e); return set(), set()
live_d, live_b = load(sys.argv[1])
tmpl_d, tmpl_b = load(sys.argv[2])
only_live_d = live_d - tmpl_d
only_tmpl_d = tmpl_d - live_d
only_live_b = live_b - tmpl_b
only_tmpl_b = tmpl_b - live_b
for name, s in [("依赖:本机有模板无",only_live_d),("依赖:模板有本机无",only_tmpl_d),
                ("bundle:本机有模板无",only_live_b),("bundle:模板有本机无",only_tmpl_b)]:
    if s:
        print(f"  ⚠️ {name}:")
        for x in sorted(s): print(f"      {x}")
    else:
        print(f"  ✓ {name}: 无")
PY

echo ""
echo "########## 4. 模板里残留的机器绑定项（link: / 绝对路径）##########"
if grep -rnE '"[^"]*":[[:space:]]*"(link:|file:)|C:/Users/|C:\\Users\\|/home/[a-z]+/' \
     "$REPO/templates/" --include='*.json' --include='*.yml' --include='*.yaml' 2>/dev/null; then
  echo "  ↑ 需人工确认"
else
  echo "  ✓ 无"
fi

echo ""
echo "########## 5. 机器级 patch 是否登记进仓库 ##########"
if [ -f "$DSH_HOME/cordis.patch.yml" ]; then
  echo "  本机 ~/.dsh/cordis.patch.yml 存在:"
  sed 's/^/    /' "$DSH_HOME/cordis.patch.yml"
  if ls "$REPO/templates/dsh/" | grep -q 'machine'; then
    echo "  仓库有对应模板"
  else
    echo "  ⚠️ 仓库 templates/dsh/ 下没有机器级 patch 的模板（换机会漏）"
  fi
else
  echo "  本机无机器级 patch"
fi

echo ""
echo "########## 6. 本机实际装的插件目录 ##########"
ls -1 "$PROFILE/node_modules" 2>/dev/null | grep -v '^\.' | sed 's/^/    /'
