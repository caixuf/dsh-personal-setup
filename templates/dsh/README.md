# templates/dsh/ — 使用说明

## 本目录内容

| 文件 | 装到哪 | 作用 |
|---|---|---|
| `package.json` | `<dsh-home>/profiles/<name>/` | 依赖清单 + bundle 名单 |
| `cordis.patch.yml` | `<dsh-home>/profiles/<name>/` | **profile 级**补丁（大部分插件配置） |
| `pnpm-workspace.yaml` | `<dsh-home>/profiles/<name>/` | pnpm 配置（`nodeLinker` / `minimumReleaseAge`） |
| `cordis.machine-patch.yml` | **`<dsh-home>/`（上一级！）** | **机器级**补丁：**当前只有注释**，装宿主插件时才需要 |

## 两种插件形态，别混

| | 正常 **bundle** | **宿主插件** |
|---|---|---|
| 判据 | `package.json` 有 **`dsh.bundle`** | 有 `dsh.client` 但**无** `dsh.bundle` |
| 挂哪 | `dsh.profile.bundles` + profile patch | **机器级** patch + 机器级 `node_modules` |
| 怎么装 | `dsh plugin add <包>` 一次搞定 | 装包 **+ 两步额外操作**（见下） |
| 本仓实例 | 15 个包（含 `deepseek-harness-weixin`） | **当前 0 个**（`dsh-bot-gateway` 已卸） |

`dsh-bot-gateway` 曾是宿主插件，机制记录在 `intent/dsh.md` 的专节里。
现在用的是 `deepseek-harness-weixin`（微信 iLink 官方通道）—— **正常 bundle**。

## 万一将来要装宿主插件：两步缺一不可

1. **机器级 patch** —— 把 `cordis.machine-patch.yml` 复制到 `<dsh-home>/cordis.patch.yml`
   （注意是 profile 目录的**上一级**），并取消注释里的 `- insert:` 段、改 id/name
2. **机器级 node_modules 副本** —— 把包复制到 `<dsh-home>/node_modules/<包名>/`

### 为什么必须是机器级

> DSH Desktop 桌面壳在后端启动失败时会把整个 `profiles` 目录隔离为
> `profiles.broken-<时间戳>` 并重建，**profile 级补丁会随之丢失**；
> 机器级补丁不受影响，重启后始终生效。

### 为什么还要那份 node_modules 副本

浏览器半边（看板 / 设置分区）从 **`<dsh-home>/node_modules/<包>/package.json`** 定位插件，
**只装在 `profiles/<name>/node_modules/` 它找不到**。`dsh add` 只会装到后者。

```bash
cp templates/dsh/cordis.machine-patch.yml <dsh-home>/cordis.patch.yml
mkdir -p <dsh-home>/node_modules
cp -r <dsh-home>/profiles/<name>/node_modules/<包名> <dsh-home>/node_modules/
```

> ✅ `scripts/install-dsh.ps1` 已把这两步包进去（装完包自动做，已存在则先备份），
> 且脚本里 `$hostPlugins` 数组就是宿主插件清单 —— 加新包时往里加一个名字。

## 审计：模板 vs 本机实机的 drift

```bash
bash scripts/audit-dsh-drift.sh --profile "/mnt/c/Users/<你>/.dsh/profiles/desktop"
```

它会报出：本机有模板无 / 模板有本机无（依赖 + bundle）、模板残留的 `link:`/`file:`
机器路径、机器级 patch 是否已登记进仓库。

> 💡 **模板领先于本机是正常的**（模板是目标态）。看到「模板有本机无」不代表模板错，
> 只说明本机还没 `apply.sh --dsh`。反过来「本机有模板无」才需要判断是不是该补进模板。
