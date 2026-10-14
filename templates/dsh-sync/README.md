# dsh-sync 私有仓模板

> 这个目录放**私有同步仓 `caixuf/dsh-sync` 的部署件**。
> 私有仓本身不在本仓库（不能入库），这里只存「重建它需要什么」。

## 为什么单独一个目录

`dsh-sync` 插件每次同步往远端推一个 `sync/<实例ID>/<时间戳>` 分支。
**它不碰本仓库** —— 本仓是「怎么重建」，那个仓是「机器自己的状态」。

## 目录内容

```
.github/workflows/
  merge-sync-branches.yml     ★ 每天自动把各机器最新 sync 分支并进 main
```

## 为什么需要这个 workflow（不装会怎样）

dsh-sync 在 GitHub 托管下是**「只推分支」降级模式**：

| | GitCode（默认） | GitHub |
|---|---|---|
| 推 sync 分支 | ✅ | ✅ |
| 自动开 PR | ✅ | ❌ 走 `prSkipped` |
| 自动合并进 main | ✅ | ❌ **main 永不前进** |

**后果**：`main` 冻结在某一刻，插件 `branch: main` 的 **pull 侧永远拉不到别人的新备份**
（本机 `state.json` 长期报 `pullError: couldn't find remote ref main`）。

**这个 workflow 补上那一半**：每天把**每台机器最新那个** sync 分支并进 main。

## 三个设计取舍（别改坏）

1. **只并「每台最新」，不全量并**
   实测远端已有 17 个 sync 分支，其中 16 个是老快照。全量并只会把 main 灌满历史垃圾。

2. **冲突跳过，不强推**
   `git merge` 失败就 `git merge --abort` 跳过那一台。
   **宁可不并，也不让定时任务造出坏历史。**

3. **用内置 `GITHUB_TOKEN`，不配额外 PAT**
   `permissions: contents: write` 就够 —— **不新增需要人工保管的凭据**。

## 新建私有仓时怎么部署

```bash
# 1. 在 GitHub 上建私有仓 caixuf/dsh-sync（必须私有，见下）
# 2. 把 workflow 放进去
gh api -X PUT "repos/caixuf/dsh-sync/contents/.github/workflows/merge-sync-branches.yml" \
  -f message="ci: 每天自动把各机器最新 sync 分支并进 main" \
  -f content="$(base64 -w0 templates/dsh-sync/.github/workflows/merge-sync-branches.yml)" \
  -f branch=main
# 3. 验证
gh api repos/caixuf/dsh-sync/actions/workflows --jq '.workflows[].state'   # 期望 active
gh workflow run merge-sync-branches --repo caixuf/dsh-sync                 # 手动跑一次
```

⚠️ **步骤 1 必须在 main 分支存在后才能做** —— 见下。

## `main` 分支必须先手工建一次

插件每次推的都是**新分支**，远端**最初没有任何 main**。
不建 main 的话 `branch: main` 永远 404，workflow 也没有基线可合。

**建法（取两台机器的并集，不要只取一台）**：

```bash
git clone https://github.com/caixuf/dsh-sync.git && cd dsh-sync
git checkout -b main origin/sync/<这台机器的实例ID>/<最新时间戳>
git remote set-url origin "https://x-access-token:$(gh auth token)@github.com/caixuf/dsh-sync.git"
# 把另一台机器最新的 sync 分支也并进来
git merge --no-ff origin/sync/<另一台实例ID>/<最新时间戳> -m "union"
git push -u origin main
gh api -X PATCH repos/caixuf/dsh-sync -f default_branch=main
```

2026-10-14 实际这么建的，两台都在、skills 完整：
```
main  "create main: union of caixuf-e81809d4 + caixuf2-edcc4bfe"
      backup/caixuf-e81809d4/…  backup/caixuf2-edcc4bfe/…  skills/…
```

## 🔴 仓库必须保持私有

dsh-sync 的 `plugins` 组 `includeFiles` 含 `cordis.patch.yml`，
而面板保存会把 **`config.sync.token` 写进那个文件**，随快照一起推上远端。

**实测：17 个远端分支全部含同一枚明文 `ghp_` token**
（路径 `backup/<实例ID>/plugins/desktop/cordis.patch.yml`）。

私有库可接受；**改成公开 = 泄露**。而且 **token 进过提交历史就删不掉，只能吊销重发**。

## 定时与调参

| 项 | 值 | 说明 |
|---|---|---|
| cron | `17 4 * * *` | UTC 04:17 = 北京 12:17，避开整点高峰 |
| 手动触发 | `gh workflow run merge-sync-branches` | 改完配置想立刻验证时用 |
| 插件侧频率 | `intervalMinutes: 1440` | **一天一次**（见 `intent/dsh-sync-配置清单.md`） |

两边频率要匹配：**插件一天推一次，CI 一天合一次**，中间最多差 24 小时。