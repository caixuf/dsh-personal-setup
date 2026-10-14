# intent/secrets.md — 密钥清单（**只有变量名，没有值**）

## 🔴 红线

**本仓库不放任何密钥明文。** 本文件只记录：
- 需要哪些变量
- 从哪里获取
- 存在哪个文件

**AI 在新机上遇到需要密钥时：停下来问用户，不要从旧机复制，不要尝试生成。**

## 密钥文件位置（均在旧机，不入库）

| 文件 | 内容 | 条目数（2026-10-14 实测） |
|---|---|---|
| `~/.dsh/.credentials.yaml` | DSH 凭据库 | `records` **3** + `refs` **14** |
| `~/.dsh/dsh-sync/settings.json` | 🔴 **含明文 GitHub PAT**（同步用） | 1 个 token |
| `~/.ccp/secrets.env` | ccp 密钥 | — |
| `~/.config/litellm/proxy.env` | litellm 网关密钥 | — |
| `~/.config/litellm/github_copilot/{access-token,api-key.json}` | Copilot 令牌 | 2 |
| `~/.npmrc` | npm registry token（若有） | — |
| `~/.git-credentials` | git 凭据（credential.helper=store） | — |
| `~/.claude*` / `~/.codex/` / 各 CLI 的登录态 | 各 AI CLI | — |

> 🔴 **`dsh-sync/settings.json` 是本机新增的一处明文密钥落点**（2026-10-14 审计发现）。
> 插件把 GitHub token 明文写在这个文件里，**同时**也写进 profile 的 `cordis.patch.yml`。
<<<<<<< HEAD
> 这两处**都不入库**；模板 `templates/dsh/cordis.patch.yml` 那份**只留注释、不含 token**。
=======
> 🔴 但「都不入库」**只对本仓库成立** —— 见下节：dsh-sync 仓的历史里其实已经有 token。

### 🔴 token 已被备份进 dsh-sync 仓（2026-10-14 实测；**止新增尝试失败**）

`dsh-sync` 的 `pluginsStrategy: backup` 会把 `includeFiles`（含 `cordis.patch.yml`）
**原样**写进 `~/.dsh/dsh-sync/repo/backup/<实例ID>/`，并推上 `github.com/caixuf/dsh-sync`。
源码**无任何内容脱敏**（只有 `sanitizeSnapshotName()` 清目录名）。

| 项 | 实测结论 |
|---|---|
| 历史命中 | `backup/caixuf-e81809d4/.../cordis.patch.yml` 15 次提交 + `backup/caixuf2-edcc4bfe/...` 1 次 |
| 远端可见性 | **private**（匿名 API 返回 404）⇒ **未公开泄露** |

**⚠️ 本地「止新增」尝试失败，别再白试**：dsh-sync 每次同步执行
`git reset --hard FETCH_HEAD` 并 checkout 到新的 `sync/<实例ID>/<时间戳>` 分支。
实测手工提交的 `.gitignore` 与 `git rm --cached backup/` **两个提交都被丢弃**
（`git branch --contains` 返回「不存在」），`.gitignore` 文件本身也消失。
⇒ **该仓任何手工提交都活不过下一次自动同步。**

**真正的修复点**（用户 2026-10-14 决定暂不做）：① 轮换该 PAT；② 重写 dsh-sync 历史。
在两者之一完成前，**若要把该仓转 public，必须先重写历史**，否则 token 随历史公开。

> 📌 **通用教训**：任何「把本机整个配置目录提交到 git」的自动同步工具，
> 都要先确认那些文件里有没有明文密钥。`check-secrets.sh` 已扩展为
> **跨仓扫描**（本仓 + dsh-sync / dsh-native-mobile / dsh-rea），能持续发现这类问题。
>>>>>>> f86d1df (sync: 同步 dsh-sync 实机配置 + 修模板 drift + 跨仓密钥扫描)
> 换机时**不要拷这两个文件**，在新机面板里重新填 token。
>
> 🔴🔴 **但 `dsh-sync` 自己那个私有库会收到 token**（2026-10-14 补，此前漏记）：
> 插件的 `plugins` 组把 `cordis.patch.yml` 纳入同步范围，而面板保存会把 token
> 写进该 patch 的 `config.sync.token` → **每次 push 都把明文 token 打包进提交**。
> 实测 `caixuf/dsh-sync` **18 个分支全部含同一枚 `ghp_` token**。
> 本地明文落点实为 **4 处**（另两处：影子仓库工作副本 + 每日快照）：
> `~/.dsh/dsh-sync/repo/backup/.../cordis.patch.yml`、
> `~/.dsh/dsh-sync/snapshots/<日期>/plugins/desktop/cordis.patch.yml`。
>
> ⚠️ **token 一旦进过提交历史就删不掉**（改文件 / 删分支 / force-push 都无效），
> 唯一手段是去 GitHub **吊销重发**。详见 `dsh-sync-配置清单.md` 的
> 「token 会随每次 push 进入远端提交历史」一节。

## DSH 凭据（`~/.dsh/.credentials.yaml`）

### `records` 段（3 条，服务自己的登录态）

| 键 | 用途 |
|---|---|
| `client-connection/browser-session` | 浏览器会话密钥 |
| `deepseek-account-platform/device` | 设备标识 |
| `deepseek-account-platform/default` | DeepSeek 账号令牌 |

### `refs` 段（**14 条**，按 provider 分组，实测清单）

| 变量名 | 来源 | 获取方式 |
|---|---|---|
| `MINIMAX_CN_API_KEY` | MiniMax 中国站 | MiniMax 控制台申请 |
| `CCP_API_KEY` | ccp / commandcode | `~/.ccp` 系统配置 |
| `OPENDESIGN_API_KEY` | opendesign（`amr-link.open-design.ai`） | 🔴 **本机 `agent-default-model` 正在用它**；新机若要沿用需自备 key |
| `BUDDY_ACCOUNT_8B057D96` / `BUDDY_ACCOUNT_D97EE071` | 账号渠道（free-model 插件） | 插件内登录 |
| `WORKBUDDY_ACCOUNT_B68139B6` | 账号渠道（free-model 插件） | 插件内登录 |
| `TRAE_ACCOUNT_64EE6BA1` | Trae | 该 CLI 内登录 |
| `CLINE_ACCOUNT_024710A9` | Cline | 该 CLI 内登录 |
| `ZCODE_ACCOUNT_7A576D42` | Z.ai / 智谱 | 该 CLI 内登录 |
| `GEMINI_ACCOUNT_66EBEA9A` / `GEMINI_ACCOUNT_BC107CAF` | Gemini（两个账号） | OAuth 流程 |
| `MINIMAX_ACCOUNT_0F271DBB` | MiniMax 账号态 | OAuth 流程 |
| `QODER_ACCOUNT_6BBE5A69` / `QODERCN_ACCOUNT_F433C5E0` | Qoder（国际站 / 中国站） | 该 CLI 内登录 |

> ⚠️ 旧版本本文写「4 个 ref」并只列了 `BUDDY_ACCOUNT_41221658` /
> `WORKBUDDY_ACCOUNT_11451829` 两个**已不再存在的**账号 ID ——
> **2026-10-14 已按实机重新枚举为 14 条**。这类账号 ID 会随重新登录变化，别照抄。
> 另：`CCP_API_KEY` 本机值 `sk-cmdc-litellm-local` 是**本地网关的固定占位串**，不是真密钥。

**注意**：`*_ACCOUNT_*` 都是**账号渠道**的登录态，
由 `dsh-our-free-model` 等插件管理。新机应**通过插件重新登录**，而不是拷这个文件。

### 与 DeepSeek 账号的关系

DSH 的**账号登录**（`deepseek-account` 服务）只管模型访问与余额，
**与上述密钥无关，也不携带任何插件/主题/会话配置**。

## litellm（`~/.config/litellm/`）

`config.yaml` 的设计很干净：**用 `os.environ/VAR` 引用，无硬编码密钥**。
实测引用到的环境变量：

| 变量 | 用途 |
|---|---|
| `CMDC_API_KEY` | commandcode provider |
| `CLINE_API_KEY` | Cline provider |
| （其他） | 见 `config.yaml` 中全部 `os.environ/` 引用 |

**所以 `config.yaml` 本身可以入库**（已放 `templates/litellm/`），
但**真实值必须放 `proxy.env`**（❌ 不入库）。

### 恢复步骤

```bash
# 1. 复制配置（无密钥）
cp templates/litellm/config.yaml ~/.config/litellm/config.yaml

# 2. 【手动】创建 proxy.env 并填入真实值
#    参考 config.yaml 里所有 os.environ/XXX，逐个填
cat > ~/.config/litellm/proxy.env <<'EOF'
CMDC_API_KEY=<向用户索取>
CLINE_API_KEY=<向用户索取>
EOF
chmod 600 ~/.config/litellm/proxy.env

# 3. github_copilot 令牌【手动】通过 copilot 登录流程重新获取
```

## `.gitconfig` 中的凭据（不入库）

旧机的 `.gitconfig` 含：

```ini
[credential]
	helper = store                                    # ← 凭据存 ~/.git-credentials
[credential "https://github.com"]
	helper = !/usr/bin/gh auth git-credential          # ← 依赖 gh CLI 登录
```

**新机处理**：
1. 装 `gh` 并 `gh auth login`
2. `git config --global credential.helper store`
3. **不要**复制 `~/.git-credentials`

## `.npmrc`（不入库）

旧机内容：
```
prefix=/home/caixuf/.npm-global
@lark-codem:registry=https://registry.npmmirror.com
```

第 2 行是私有 registry 作用域。**若其中含 `//registry...:_authToken=` 则不入库**；
新机需重新 `npm login` 到该 registry。

## 各 AI CLI 的登录态（全部需重新登录）

以下工具在旧机已登录，**新机必须重新走登录流程**：

| 工具 | 登录方式 |
|---|---|
| `claude`（Claude Code） | `claude` 交互登录 |
| `codex`（OpenAI） | `codex login` |
| `agy`（Antigravity） | IDE 内登录 |
| `codebuddy` | `codebuddy` 登录流程 |
| `copilot` / `copilot-api` | `gh auth login` 后授权 |
| `cline` | `cline` 内登录 |
| `opencode-ai` | 按需 |
| `grok` | installer 后登录 |
| `codem` | 按需 |

## 检查清单（新机配置完成后）

- [ ] `~/.dsh/.credentials.yaml` 中**用到的** ref 已按需填入
- [ ] 🔴 `~/.dsh/dsh-sync/settings.json` **没有**从旧机复制（含明文 GitHub token）
- [ ] 🔴 `dsh-sync` 的 token **没有**随着同步被推进 `caixuf/dsh-sync`
      （已知会发生：`cordis.patch.yml` 在插件的同步范围内；介意就关 `syncPlugins` 或定期轮换）
- [ ] `~/.config/litellm/proxy.env` 已创建且 `chmod 600`
- [ ] `gh auth login` 完成，`git push` 可用
- [ ] 各 AI CLI 已重新登录
- [ ] **确认没有把任何密钥提交进本仓库**：
      ```bash
      git log --all -p | grep -iE "sk-[A-Za-z0-9]{20,}|api[_-]?key.*=.*[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}"
      ```
      有输出即说明泄漏，需 `git filter-repo` 清理并**轮换所有密钥**。
