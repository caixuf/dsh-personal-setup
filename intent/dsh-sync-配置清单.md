# dsh-sync 首次配置清单（本机 caixuf 台式）

> 生成时间：2026-10-12
> 仓库：https://github.com/caixuf/dsh-sync（**PRIVATE**，已建）

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
- 本机 `~/.dsh/dsh-sync/snapshots/` 滚动保留 30 份
- 本机实例 ID：`caixuf-e81809d4`

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
