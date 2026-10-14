# dsh-sync 首次配置清单（本机 caixuf 台式）

> 生成时间：2026-10-12
> 最后核对：**2026-10-14**（`main` 已建并设为默认分支；补入「GitHub 托管的功能边界」与「token 会随提交入库」两节）

> 仓库：https://github.com/caixuf/dsh-sync（**PRIVATE**，默认分支 **`main`**）

## ✅ 已修：pull 长期 404（2026-10-12 发现 → 2026-10-14 修）

**症状**：`~/.dsh/dsh-sync/state.json` 的 `lastResult` 长期上报

```json
"pullError": "git fetch: fatal: couldn't find remote ref main"
```

**真因**：远端**没有 `main` 分支**，默认分支被冻结在
`sync/caixuf-e81809d4/1791820464099`；而本地写的是 `"branch": "main"` → 每次 pull 都 404。
push 侧却是好的（每次同步新建一个 `sync/...` 分支推上去）。
⇒ 多机同步的「拉回来」这一半**从头就是坏的**。

**修法（已执行，2026-10-14）**：建 `main` 并把默认分支切过去。

`main` = **默认分支 tip ⊕ 本机已推分支**（两个根历史用 `--allow-unrelated-histories` 合并），
这样两边机器的内容都在，且本机自己的备份路径与 `main` 一致 → 下次 push 不再产生新分支。

```bash
# 在 WSL 里做（本机 Windows git 拿不到凭据，见 README；WSL 的 gh 已授权）
cd $(mktemp -d) && git clone https://github.com/caixuf/dsh-sync.git repo && cd repo
DEF=$(git rev-parse origin/sync/caixuf-e81809d4/1791820464099)   # 旧默认分支
LAP=$(git rev-parse origin/sync/caixuf2-edcc4bfe/1791961078552) # 本机已推分支
git checkout -b main "$DEF"
git -c user.name=dsh-sync -c user.email=dsh-sync@local \
    merge --no-ff --allow-unrelated-histories -m "create main: union" "$LAP"
git push origin main
gh api -X PATCH repos/caixuf/dsh-sync -f default_branch=main     # 关键：改默认分支
```

**验收判据**（必须是这条命令，不是"看着像好了"）：

```bash
git fetch <repoUrl> main   # exit=0 才算通；改前是 could not find remote ref
```

> ⚠️ **建 `main` 只修好了 pull 侧，不解决下面那节的"push 永不进 main"。**

## 🔴 GitHub 托管的功能边界（2026-10-14 读源码确认）

**结论：GitHub 上插件是"只推分支"降级模式，`main` 永远不会自动前进。**

源码 `src/index.js`：`parseRepoUrl()` **只匹配 `gitcode.com`**，GitHub 地址返回 `null` →
`runPush` 走 `prSkipped` 降级路径：只 `push` 一个 `sync/<实例ID>/<时间戳>` 分支，
然后把影子库 `reset` 回 `branch`。**PR 创建/合并、`conflict/run`、`prune-branches` 全是 GitCode 专属**
（插件 README L147 自己也承认）。

**后果**：多机"互相同步"在 GitHub 上实质退化成
**各机往远端堆自己的备份分支 + 人工在网页开 PR 合并**。
默认分支 tip 就是个 merge commit（`Merge pull request #1 from caixuf/sync/...`）—— 那是人工合出来的。

远程分支还会**线性堆叠**：因为 `fetch main` 一直失败 → `hasRemote=false` → `baseRef` 退化成 `HEAD`
→ 每个新分支都基于上一个（实测 16 个 `caixuf-e81809d4` 分支呈一条线性链）。

| 想要的能力 | GitCode | GitHub |
|---|---|---|
| push 备份分支 | ✅ | ✅ |
| **自动合并进默认分支** | ✅（PR + merge + 删分支） | ❌ 要人工开 PR |
| `conflict/run`（AI 冲突处理） | ✅ | ❌ |
| `prune-branches`（清理遗留分支） | ✅ | ❌ |

**处置建议**：要么接受"人工开 PR"（配合 `intervalMinutes: 1440`，
一天最多一个分支，见下节），要么换 GitCode 托管（功能完整，但要重建仓 + 改 `repoUrl` + 重填 token，
属于**切模式**，动手前先确认覆盖旧路径的全部副作用）。

## ✅ 处置：GitHub Actions 自动并 main（2026-10-14 已上线）

**采纳第三条路**：不换托管方、不人工开 PR —— **用 CI 补上自动合并那一半**。

workflow 模板在本仓 **`templates/dsh-sync/.github/workflows/merge-sync-branches.yml`**，
已部署到 `caixuf/dsh-sync` 并**实跑验证**（run 38530894006 `completed/success`）。

| 项 | 值 |
|---|---|
| 触发 | `cron: '17 4 * * *'`（UTC 04:17 = 北京 12:17，避开整点） |
| 手动 | `gh workflow run merge-sync-branches --repo caixuf/dsh-sync` |
| 凭据 | **内置 `GITHUB_TOKEN`**（`permissions: contents: write`），**不新增 PAT** |

**三个设计取舍（别改坏）**：

1. **只并「每台最新那个」，不全量并** —— 实测远端 17 个分支里 16 个是老快照，
   全量并只会把 main 灌满历史垃圾。
2. **冲突跳过，不强推** —— `git merge` 失败即 `git merge --abort` 跳过那一台。
   宁可不并，也不让定时任务造出坏历史。
3. **服务器端跑** —— 不占本机资源，机器关机也不影响。

**上线前的验证**（不是先上了再说）：在临时 clone 里本地演练过 ——
19 个分支正确挑出两台各一个最新分支、逐台合并零冲突、24 个文件。

⚠️ **它不会让 main 变得"完整历史"**，只并每台最新快照 —— main 是「当前并集」，不是全部快照的堆。

## 你要填的（设置 → 插件 → dsh-sync → Git 页签）

| 字段 | 值 |
|---|---|
| 仓库托管方 | **GitHub**（默认是 GitCode，要点按钮切过去） |
| owner | `caixuf` |
| repo | `dsh-sync` |
| access token | ⚠️ **你自己生成**，见下 |

### token 怎么生成

1. GitHub → 头像 → **Settings** → 最下面 **Developer settings**
2. **Personal access tokens** → **Tokens (classic)** → Generate new token (classic)
3. 勾选权限（**最小够用**）：
   - ✅ `repo`（读写私有仓库 —— 插件要 push/pull）
   - ✅ `workflow`（如果以后想让 CI 跑）
   - ❌ 不要勾 `delete_repo` / `admin:*`
4. **Expiration** 设个期限（别选永不）
5. 生成后**立刻复制**（只显示一次）

⚠️ **贴给我之前想清楚** —— 上次那个 Telegram token 贴进对话就等于公开了。
**建议你自己在面板里填**，我不经手。

## 同步范围（四类，各有独立开关 + 策略）

| 类别 | 开关 | 策略 | 说明 |
|---|---|---|---|
| 技能 skills | ✅ 开 | **并集** | 覆盖 `~/.dsh/skills`、`~/.agents/skills`、`~/agents/skills` 三个根 |
| 设置 settings.yaml | ✅ 开 | **备份** | ⚠️ **含本机明文密钥**，所以仓库必须私有 |
| 插件清单 | ✅ 开 | **备份** | 各机 bundle 清单互不覆盖 |
| 会话 | ❌ 关 | — | 体积大头，默认不同步 |

## 同步频率（2026-10-14 定）

| 项 | 值 |
|---|---|
| `intervalMinutes` | **1440**（一天一次） |
| `autoSync` | true |
| `syncOnStartup` | true |

**为什么从 30 改成 1440**：用户看到远端堆了十几个 `sync/...` 分支，问「怎么这么多分支」。

**根因就是这个频率。** 插件**每次同步都新建一个分支** `sync/<实例ID>/<时间戳>`：

```
30 分钟一次  →  48 个分支/天  →  一个月 1400+ 个
1440 分钟    →  1 个分支/天   →  可控
```

而同步的内容本身（skills / settings / 插件清单）**不分钟级变化** ——
一天一次足够。插件每日首个同步还会自动打本地快照（保留 30 份），
真出问题了有快照可回退。

> ⚠️ 改频率**不解决**上面那个 `branch: main` 故障 ——
> 那是 pull 侧从一开始就 404，与频率无关。两件事分开看。

### 🔴 落地要点：改频率要改**两个地方**（2026-10-14 实测）

上一版只改了模板 `templates/dsh/cordis.patch.yml`，**本机实机一直是 30**。
本次已把实机补齐，两处都要改才算生效：

| 文件 | 谁读它 | 改法 |
|---|---|---|
| `~/.dsh/dsh-sync/settings.json` | 插件自己读（`syncSettings()`） | 备份后直接改 `intervalMinutes` |
| `~/.dsh/profiles/desktop/cordis.patch.yml` | 宿主 config 层（`baseSettings()`） | 改 `dsh-sync` 段的 `intervalMinutes` |

**优先级链**（源码 `syncSettings()` 实读）：

```
baseSettings()(cordis.patch.yml) → settings.json → settingsOverrides
      ↑ 最高                      ↑ 仅当不比 host 新
```

⚠️ `pickFileSettingsLayer()` 有一句 `if (hostWriteAt > fileMtime) return {}`：
**只要 DSH 之后再写一次 `cordis.patch.yml`，settings.json 就被忽略**。
所以只改 settings.json 是**假生效**，两个都得改。

⚠️ 改 `cordis.patch.yml` 后**必须重启 DSH**，否则磁盘 revision 与内存值脱节，
后续任何设置保存都会被拒（表现：欢迎向导弹「暂时无法保存确认状态」）。

## 快照

- 勾选 **「上传到云端」** → 写入 `backup/<实例ID>/snapshots/`
- 本机 `~/.dsh/dsh-sync/snapshots/` 滚动保留 30 份（实测已有 `auto-2026-10-12/13/14`）
- 本机实例 ID：`caixuf-e81809d4`

> ⚠️ **快照里也是明文的**：`snapshots/<日期>/plugins/desktop/cordis.patch.yml`
> 含 GitHub token 明文，且这些快照会被 push 进 `caixuf/dsh-sync`（私有库）。
> 私有库可接受，但**别把它改成公开**。

## 🔴 token 会随每次 push 进入远端提交历史（2026-10-14 实测）

**先说结论**：`dsh-sync` 会**把同步用的 GitHub PAT 提交进它自己的仓库**。
下面那条"两处都不入库"**只对 `dsh-personal-setup` 成立** ——
`dsh-sync` 那个私有库会**收到** token，而且**进了提交历史就删不掉**。

**机制**：插件的 `plugins` 组 `includeFiles` 含 `cordis.patch.yml`
（`src/index.js:716`），而面板保存会把 token 写进该 patch 的 `config.sync.token`
→ 每次 push 都把带明文 token 的 patch 打包进提交。

**实测**：远端 18 个分支**全部**含同一枚明文 `ghp_` token，路径

```
backup/<实例ID>/plugins/desktop/cordis.patch.yml
```

**本地明文落点共 4 处**（不止两处）：

| 位置 | 说明 |
|---|---|
| `~/.dsh/dsh-sync/settings.json` | 插件的自持设置 |
| `~/.dsh/profiles/desktop/cordis.patch.yml` | profile patch 的 `dsh-sync` 段 |
| `~/.dsh/dsh-sync/repo/backup/.../cordis.patch.yml` | 影子仓库的工作副本 |
| `~/.dsh/dsh-sync/snapshots/<日期>/plugins/desktop/cordis.patch.yml` | 每日快照 |

**"两处都不入库"的正确范围**：模板 `templates/dsh/cordis.patch.yml` 里那一行是**注释占位**，
`git grep ghp_` 在本仓库工作区与**全部 git 历史**里都是 0 命中（2026-10-14 复核）。
—— 但这**管不到 `dsh-sync` 自己那个库**。

⚠️ **处置**：

1. **只要 `syncPlugins: true`，新 token 下次 push 还会被提交进去** ——
   这是插件设计，不是配置错误。想彻底避免只有两条路：
   关掉 `syncPlugins`（或整个 git 同步），或**接受**"私有库 + 定期轮换 token"。
2. 若 token 曾出现在对话/截图里 → **视为已泄漏**（见 `secrets.md`），去 GitHub 吊销重发。
   ⚠️ **吊销是唯一有效手段**：token 已在提交历史里，改文件 / force-push / 删分支都清不掉。
3. 吊销重发后，本机要同时更新 `settings.json` 与 profile patch（或直接在面板重填）。

### 🔴🔴 token 实际已被备份进 dsh-sync 仓（2026-10-14 实测，**止新增尝试失败**）

上面写「两处都不入库」**只对本仓库成立**。实测发现 dsh-sync 仓里**也有**：

| 项 | 实测结论 |
|---|---|
| 机制 | `pluginsStrategy: backup` → 插件把 `includeFiles`（含 `cordis.patch.yml`）**原样**写进 `~/.dsh/dsh-sync/repo/backup/<实例ID>/`，并推上 `github.com/caixuf/dsh-sync` |
| 脱敏 | ❌ **无**。源码里只有 `sanitizeSnapshotName()` 清目录名，**内容零脱敏** |
| 历史命中 | `backup/caixuf-e81809d4/.../cordis.patch.yml` 15 次提交 + `backup/caixuf2-edcc4bfe/...` 1 次 |
| 远端可见性 | **private**（匿名 API 404）⇒ 未公开泄露 |

**为什么本地修复无效（重要，别再白试）**：
dsh-sync 每次同步会执行 `git reset --hard FETCH_HEAD` + `checkout` 到新的
`sync/<实例ID>/<时间戳>` 分支。实测：手工提交 `.gitignore` 与 `git rm --cached backup/`
后，**两个提交被完全丢弃**（`git branch --contains` 返回「不存在」），且 `.gitignore`
文件本身消失。**这个仓的任何手工提交都活不过下一次自动同步。**

⇒ 真正的修复点不在「排除文件」，而在**轮换该 PAT** 或**重写该仓历史**。
`check-secrets.sh` 已扩展为跨仓扫描（见下），能持续发现这类问题。

## 配完后的验证

```powershell
# 1. 设置是否落盘
Get-Content "$env:USERPROFILE\.dsh\dsh-sync\settings.json"

# 2. 排障端点（README L134）
#    GET /dsh-sync/api/diag  → schemaKind / schemasteryError 等
#    GET /dsh-sync/api/status → persist.fileOk 应为 true
```

**注意**：`persist.fileOk = true` 才说明设置真的写进 `settings.json` 了
（只写到宿主 `cordis.patch.yml` 是不够的）。

## 🔴 跨机第一次同步的顺序（重要）

**每台机器都要先各自配好再开同步**，否则第一台推上去的会覆盖其他机器。

推荐：
1. 这台（caixuf 台式）配好 → 测通 → **先不合**
2. 其它 2-3 台各配同一个仓库 → 各自手动触发一次同步
3. 确认都进来了，再改成自动

> ⚠️ **2026-10-14 实测补正**：上面第 3 步在 **GitHub 托管下做不到"写进共享分支"** ——
> 每台机器的 push 都只落在自己的 `sync/<实例ID>/<时间戳>` 分支上（见「GitHub 托管的功能边界」节）。
> 想让 A 机的改动被 B 机 pull 到，必须**人工在网页把这个分支 PR 合并进 `main`**。
> 换机时最容易误判成"同步坏了"，实际是模式如此。

## ⚠️ 那个 Windows 路径坑：已自动处理

README 警告过 `C:\Users\x\.dsh\dsh-sync\repo` 这种带点路径会被 MSYS2 改写成
`C:\Users\x\dsh-sync\repo`（点消失），导致 git 在不存在的目录里跑、报 `fetch failed`。

**插件 0.4.2 起自己修了** —— host 侧给 git 子进程注入
`MSYS_NO_PATHCONV=1` 与 `MSYS2_ARG_CONV_EXCL='*'`（**仅该子进程**）。

> ⚠️ **不要**把 `MSYS_NO_PATHCONV=1` 写进 `.bashrc` 或全局环境 ——
> Git for Windows 官方专门警告过（build-extra#376），全局设置会影响其它程序。
> 插件只给自己那批 git 调用加，**这是正确做法，不要动全局**。

## 🔴 与 `personal-knowledge` 的分工（别搞混）

| | `dsh-sync` | `personal-knowledge` |
|---|---|---|
| 同步什么 | **DSH 机器配置**：skills / settings / 插件清单 | **个人资料**：履历 / 环境文档 / 记忆 |
| 方向 | 多台 DSH 机器**互相同步** | 工具目录 → git **单向** |
| 凭据 | 加密同步 settings | 不入库 |
| 仓库 | `caixuf/dsh-sync`（新建，私有） | `caixuf/personal-knowledge`（已有） |

**两套不重叠，都保留。**
