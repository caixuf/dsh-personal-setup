# templates/dsh/ — 使用说明

## 本目录内容

| 文件 | 装到哪 | 作用 |
|---|---|---|
| `package.json` | `<dsh-home>/profiles/<name>/` | 依赖清单 + bundle 名单 |
| `cordis.patch.yml` | `<dsh-home>/profiles/<name>/` | **profile 级**补丁（大部分插件配置） |
| `pnpm-workspace.yaml` | `<dsh-home>/profiles/<name>/` | pnpm 配置（`nodeLinker` / `minimumReleaseAge`） |
| **`cordis.machine-patch.yml`** | **`<dsh-home>/`（上一级！）** | **机器级**补丁：宿主插件挂载点 |

## 🔴 机器级那两件事，缺一不可

`dsh-bot-gateway` 是**宿主插件**，不走 profile。装它需要**两个动作**：

1. **机器级 patch** —— 把 `cordis.machine-patch.yml` 复制到 `<dsh-home>/cordis.patch.yml`
   （注意是 profile 目录的**上一级**）
2. **机器级 node_modules 副本** —— 把包复制到 `<dsh-home>/node_modules/dsh-bot-gateway/`

### 为什么必须是机器级

README 原文警告：

> DSH Desktop 桌面壳在后端启动失败时会把整个 `profiles` 目录隔离为
> `profiles.broken-<时间戳>` 并重建，**profile 级补丁会随之丢失**；
> 机器级补丁不受影响，重启后始终生效。

### 为什么还要那份 node_modules 副本

浏览器半边（看板 / 设置分区）从 **`<dsh-home>/node_modules/<包>/package.json`** 定位插件，
**只装在 `profiles/<name>/node_modules/` 它找不到**。`dsh add` 只会装到后者。

### ✅ 自动做

`scripts/install-dsh.ps1` 已经把这两件事都做了（2026-10-12 补的）。
手工做的话：

```bash
# 1. 机器级 patch
cp templates/dsh/cordis.machine-patch.yml <dsh-home>/cordis.patch.yml
# 2. 机器级包副本
mkdir -p <dsh-home>/node_modules
cp -r <dsh-home>/profiles/<name>/node_modules/dsh-bot-gateway <dsh-home>/node_modules/
```

> ⚠️ 只有 `dsh-bot-gateway` 需要这一步。`packages.json` 里其余 14 个都是
> **正常 bundle**（有 `dsh.bundle.patch`），`dsh add` 一次搞定。

## 为什么不进 `bundles` 数组

它在 `dependencies` 里（保证 `pnpm install` 不清掉），但**不在** `dsh.profile.bundles` ——
因为它没有 `dsh.bundle.patch`，挂 bundle 名单里 `dsh add` 会报
`cannot resolve profile bundle`（或 `not-bundle`）。

**判定方法**：包 `package.json` 里有 `dsh.bundle` 字段 → 正常 bundle，进 `bundles`；
只有 `dsh.client` → 宿主插件，挂机器级 patch。

详见 `intent/dsh.md` 的「`dsh-bot-gateway`」专节。

## 审计：模板 vs 本机实机的 drift

```bash
bash scripts/audit-dsh-drift.sh --profile "/mnt/c/Users/<你>/.dsh/profiles/desktop"
```

它会报出：本机有模板无 / 模板有本机无（依赖 + bundle）、模板残留的 `link:`/`file:`
机器路径、机器级 patch 是否已登记进仓库。

> 💡 **模板领先于本机是正常的**（模板是目标态）。看到「模板有本机无」不代表模板错，
> 只说明本机还没 `apply.sh --dsh`。反过来「本机有模板无」才需要判断是不是该补进模板。
