# templates/dsh/ — 使用说明

> **最后复核：2026-10-18**（DSH 升到 0.2.1-rc.2 后逐项重核；见下面的「当前实机状态」）

## 本目录内容

| 文件 | 装到哪 | 作用 |
|---|---|---|
| `package.json` | `<dsh-home>/profiles/<name>/` | 依赖清单 + bundle 名单 |
| `cordis.patch.yml` | `<dsh-home>/profiles/<name>/` | **profile 级**补丁（大部分插件配置） |
| `pnpm-workspace.yaml` | `<dsh-home>/profiles/<name>/` | pnpm 配置（`nodeLinker` / `minimumReleaseAge` / `allowBuilds`） |
| `cordis.machine-patch.yml` | **`<dsh-home>/`（上一级！）** | **机器级**补丁：三行宿主插件 |
| `frpc.toml` / `frps.toml` | 家里客户端 / VPS | FRP 隧道（脱敏模板，含占位符） |
| `frpc-guard.cmd` | 家里，与 `frpc.exe` 同目录 | **frpc 掉线自愈**（frpc 不是服务，会静默退出） |
| `caddy/dsh-mobile.caddy` | VPS | 公网入口白名单（**含封死管理面**） |
| `lan-bridge/` | 家里（见该目录 README） | **局域网桥**：让配对到 `<lan-ip>:19387` 的手机 App 连上只监听回环的 DSH |

## 当前实机状态（2026-10-18 实测，模板即按此对齐）

| 项 | 值 |
|---|---|
| DSH 内核 | **0.2.1-rc.2** |
| bundle 数 | **18**（`dsh-whale-girl-pet` 已被用户关掉、不在 bundles 里，但**模板保留它**作为默认基线） |
| 依赖条数 | **18**（含 2 个自研宿主插件：`dsh-mobile-gateway` / `dsh-rea`） |
| 机器级 patch | **3 行**：`dsh-bot-gateway` / `dsh-mobile-gateway` / `dsh-rea` |
| 机器级 `node_modules` | 同上 3 个包各一份副本 |
| `ui-theme` | `dark`，`fontSize: 17` |
| `webserver.host` | **`127.0.0.1`**（0.2.1 禁止 `0.0.0.0`，详见下面「0.2.1 适配」） |
| `remote-web-ui` | **`disabled: true`**（与 0.2.1 冲突，见下） |
| `dsh-sync.syncOnStartup` | **`false`**（启动同步 15.7s 会堵住模型插件） |

## 🔴 0.2.1 适配（2026-10-17/18 实机踩出来的四条）

1. **`webserver` 禁止 `0.0.0.0`**（`dsh-host-webserver` 的 Config 里硬拒绝通配地址）。
   它是 **required 插件**，起不来会导致 10 个依赖 `webServer` 的插件挂起 → 启动失败
   → 桌面端进 recovery → `sanitizeProfile` **把 bundles 砍到 2 个、patch 改名备份**
   （表现：插件全部消失）。所以 profile patch 里必须写 `host: '127.0.0.1'`。
   手机要连局域网/公网走**外部转发**（`lan-bridge/` + `frpc`），不改这里。
2. **`remote-web-ui` 整行禁用**：`lanBind: true` 会写 `0.0.0.0`（触发上面第 1 条），
   `lanBind: false` 又每次启动强制写回 `127.0.0.1` 覆盖手工配置。0.4.7 仍未修。
3. **插件准入规则变了**：manifest 声明 `engines.dsh` 时**该范围一票否决**、
   忽略 peerDependencies（0.2.0 是相反逻辑），不合格的 bundle 整个进 `skippedBundles`
   （插件静悄悄消失）。豁免写在 profile 下的 `compatibility.json`：
   `{"<pkg>@<ver>": ["0.2.1-rc.2"]}`（值必须是**精确版本数组**）。本机需豁免 3 个：
   `@deepseek-ai/dsh-llm-pi-ai@0.2.0-rc.2`（模型 provider！）、
   `@anionex/dsh-eye-care@0.1.2`、`dsh-browser-cdp@1.2.1`。
4. **`dsh-wsl-workspace` 的 `{{cwd}}` 会让 WSL 会话每轮报错**
   （`unknown prompt variable "{{cwd}}"` in section `deployment:persona-prefix`；
   0.2.1 的该段只注册 `provider`、`model`）。v0.7.5/v0.7.7 都有这个串。
   修法：把 `lib/index.js` 里 `PERSONA_APPEND` 的 `{{cwd}}` 删掉（本机已打补丁）。


## 两种插件形态，别混

| | 正常 **bundle** | **宿主插件** |
|---|---|---|
| 判据 | `package.json` 有 **`dsh.bundle`** | 有 `dsh.client` 但**无** `dsh.bundle` |
| 挂哪 | `dsh.profile.bundles` + profile patch | **机器级** patch + 机器级 `node_modules` |
| 怎么装 | `dsh plugin add <包>` 一次搞定 | 装包 **+ 两步额外操作**（见下） |
| 本仓实例 | 16 个 npm 包 | **3 个**：`dsh-bot-gateway`（npm）+ `dsh-mobile-gateway`、`dsh-rea`（**自研，未发 npm，从本地源码装**） |

> 🔴 `dsh-mobile-gateway` 与 `dsh-rea` **没发布到 npm** ——
> 直接 `dsh plugin add` 会 **404**。`install-dsh.ps1` 已改为
> 从同级目录（`../dsh-native-mobile/packages/dsh-mobile-gateway`、`../dsh-rea`）
> 或 `~/Downloads/aiwork/` 下**自动发现源码**并双位置安装。

## 万一将来要装新的宿主插件：两步缺一不可

1. **机器级 patch** —— 把 `cordis.machine-patch.yml` 复制到 `<dsh-home>/cordis.patch.yml`
   （注意是 profile 目录的**上一级**），并在 `- insert:` 段的 `$hostPlugins` 清单里加名字
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
> 自研的两个走 `$localSourceMap`（源码路径映射），不从 npm 装。

## ⚠️ `dsh-sync` 的 token 纪律（2026-10-14 补）

本目录的 `cordis.patch.yml` 里，`dsh-sync` 段的 `token` **只有注释、没有值**。
实机那份（`<dsh-home>/profiles/<name>/cordis.patch.yml`）**含明文 GitHub PAT**，
且插件还会把同一个 token 写进 `~/.dsh/dsh-sync/settings.json`。

**两者都不入库。** 换机时不要拷贝，在面板里重新填。
`git grep ghp_` 在本仓库工作区与**全部 git 历史**都应为 0 命中（2026-10-14 复核通过）。

## 审计：模板 vs 本机实机的 drift

```bash
bash scripts/audit-dsh-drift.sh --profile "/mnt/c/Users/<你>/.dsh/profiles/desktop"
```

它会报出：本机有模板无 / 模板有本机无（依赖 + bundle）、模板残留的 `link:`/`file:`
机器路径、机器级 patch 是否已登记进仓库。

> 💡 **模板领先于本机是正常的**（模板是目标态）。看到「模板有本机无」不代表模板错，
> 只说明本机还没 `apply.sh --dsh`。反过来「本机有模板无」才需要判断是不是该补进模板。

> ⚠️ **该脚本有两个已知盲区**（2026-10-14）：
> ① 它**不检查机器级** `<dsh-home>/cordis.patch.yml` 与 `<dsh-home>/node_modules/`，
> 所以 `dsh-mobile-gateway` / `dsh-rea` 会被**误报**成「模板有本机无」——
> 它们其实已装且 `active`，只是不经过 profile 的 `package.json`；
> ② 它只看集合、不比顺序，所以 `bundles` 顺序不同不算 drift。
