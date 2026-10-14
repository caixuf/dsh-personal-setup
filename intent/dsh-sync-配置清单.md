# dsh-sync 首次配置清单（本机 caixuf 台式）

> 生成时间：2026-10-12
> 最后核对：**2026-10-14**（补入下面「🔴 实测故障」一节）
> 仓库：https://github.com/caixuf/dsh-sync（**PRIVATE**，已建，默认分支 **不是 `main`**）

## 🔴 实测故障：pull 一直失败（2026-10-14 发现，未修）

本机 `~/.dsh/dsh-sync/state.json` 里 `lastResult` 长期上报：

```json
"pullError": "git fetch: fatal: couldn't find remote ref main"
```

**真因**：仓库的**默认分支是 `sync/<实例ID>/<时间戳>`，不是 `main`**。
用带 token 的 GitHub API 回读确认：

```
caixuf/dsh-sync  private=true  default_branch=sync/caixuf-e81809d4/1791820464099
```

而本地 `settings.json` / `cordis.patch.yml` 里写的是 `"branch": "main"` ——
**远端不存在 `main`**，所以每次 pull 都 404。

**影响**：push 侧是好的（每次同步都新建一个 `sync/...` 分支推上去，远端已有 15+ 分支），
但 **pull 侧从来没有成功过** ⇒ 多机同步的「拉回来」这一半**实际是坏的**。

**修法（择一，动手前先备份）**：

1. 在 GitHub 上把默认分支显式建一个 `main`（从某个 `sync/...` 分支拉），
   再让插件保持 `branch: main`；或
2. 把 `branch` 改成**一个真实存在的分支名**（但插件每次同步都推新分支，
   写死某个 `sync/...` 会随实例 ID / 时间戳失效，**不推荐**）。

⚠️ 这属于「改配置 + 动远端仓库」的操作，**先问用户再动**。

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

## 快照

- 勾选 **「上传到云端」** → 写入 `backup/<实例ID>/snapshots/`
- 本机 `~/.dsh/dsh-sync/snapshots/` 滚动保留 30 份（实测已有 `auto-2026-10-12/13/14`）
- 本机实例 ID：`caixuf-e81809d4`

> ⚠️ **快照里也是明文的**：`snapshots/<日期>/plugins/desktop/cordis.patch.yml`
> 含 GitHub token 明文，且这些快照会被 push 进 `caixuf/dsh-sync`（私有库）。
> 私有库可接受，但**别把它改成公开**。

## token 纪律（2026-10-14 补充）

实测 token 会**同时**落在两处明文位置：

| 位置 | 说明 |
|---|---|
| `~/.dsh/dsh-sync/settings.json` | 插件的本地设置 |
| `~/.dsh/profiles/desktop/cordis.patch.yml` | profile patch 的 `dsh-sync` 段 |

**两处都不入库**。模板 `templates/dsh/cordis.patch.yml` 里那一行是**注释占位**，
`git grep ghp_` 在本仓库工作区与**全部 git 历史**里都是 0 命中（2026-10-14 复核）。

⚠️ 若 token 曾出现在对话/截图里，**视为已泄漏**（见 `secrets.md`），去 GitHub 吊销重发。

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
2. 其它 2-3 台各配同���个仓库 → 各自手动触发一次同步
3. 确认都进来了，再改成自动

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
