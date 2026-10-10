# intent/secrets.md — 密钥清单（**只有变量名，没有值**）

## 🔴 红线

**本仓库不放任何密钥明文。** 本文件只记录：
- 需要哪些变量
- 从哪里获取
- 存在哪个文件

**AI 在新机上遇到需要密钥时：停下来问用户，不要从旧机复制，不要尝试生成。**

## 密钥文件位置（均在旧机，不入库）

| 文件 | 内容 | 条目数 |
|---|---|---|
| `~/.dsh/.credentials.yaml` | DSH 凭据库 | 19 条 |
| `~/.ccp/secrets.env` | ccp 密钥 | — |
| `~/.config/litellm/proxy.env` | litellm 网关密钥 | — |
| `~/.config/litellm/github_copilot/{access-token,api-key.json}` | Copilot 令牌 | 2 |
| `~/.npmrc` | npm registry token（若有） | — |
| `~/.git-credentials` | git 凭据（credential.helper=store） | — |
| `~/.claude*` / `~/.codex/` / 各 CLI 的登录态 | 各 AI CLI | — |

## DSH 凭据（`~/.dsh/.credentials.yaml`）

实测的 **refs 段**（按 provider 分组）：

| 变量名 | 来源 | 获取方式 |
|---|---|---|
| `MINIMAX_CN_API_KEY` | MiniMax 中国站 | MiniMax 控制台申请 |
| `CCP_API_KEY` | ccp / commandcode | `~/.ccp` 系统配置 |
| `BUDDY_ACCOUNT_41221658` | 账号渠道（free-model 插件） | 插件内登录 |
| `WORKBUDDY_ACCOUNT_11451829` | 账号渠道（free-model 插件） | 插件内登录 |

**注意**：`BUDDY_ACCOUNT_*` / `WORKBUDDY_ACCOUNT_*` 是**账号渠道**的登录态，
由 `dsh-our-free-model` 插件管理。新机应**通过插件重新登录**，而不是拷这个文件。

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

- [ ] `~/.dsh/.credentials.yaml` 中 4 个 ref 已按需填入
- [ ] `~/.config/litellm/proxy.env` 已创建且 `chmod 600`
- [ ] `gh auth login` 完成，`git push` 可用
- [ ] 各 AI CLI 已重新登录
- [ ] **确认没有把任何密钥提交进本仓库**：
      ```bash
      git log --all -p | grep -iE "sk-[A-Za-z0-9]{20,}|api[_-]?key.*=.*[A-Za-z0-9]{20,}"
      ```
      有输出即说明泄漏，需 `git filter-repo` 清理并**轮换所有密钥**。
