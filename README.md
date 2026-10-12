# dsh-personal-setup

> **给 AI 的入口指令** —— 如果你（AI）正在读这个仓库来配置一台新机器，请先读完全部 `intent/` 再动手。

## 这个仓库是什么

一台 Windows + WSL2 开发机的**可移植个性化配置**。它不是配置文件的机械备份，
而是「**意图 + 模板 + 审计脚本**」三层结构，让 AI 能在**不同的新机器**上正确落地。

## 目录结构

```
README.md               ← 你在读的这个：入口与使用流程
intent/                 ← 【为什么】人可读的意图。AI 的核心决策依据
  conventions.md        ★ 先读这份：协作方式、他最烦什么、本机跨项目通用坑
  dsh.md                DSH 插件/主题/配置的取向与踩过的坑
  wsl.md                WSL 环境：代理机制、网络模式、dotfile 结构
  services.md           本地服务：litellm / privoxy 端口分配与用途
  packages.md           软件包清单：apt / npm / pip 分组与用途
  secrets.md            【只有变量名，没有值】密钥清单与获取方式
templates/              ← 【是什么】可直接复制、不含密钥
  bashrc.d/*.sh         .bashrc 的片段（拆开，不整份覆盖）
  profile.d/*.sh        .profile 的片段
  systemd/*.service     systemd 单元
  litellm/config.yaml   本地模型网关配置（已剔除密钥）
  dsh/                   DSH profile 的配置三件套
  skills/               自建 skill（当前：evidence-boundary，见 intent/dsh.md）
scripts/
  audit.sh              盘点**当前机**实际状态，供 AI 与新机对比
  apply.sh              幂等落地（默认 --check 只读）
  check-secrets.sh      提交前密钥扫描
```

## AI 配置新机的流程

### 第 1 步：读意图，不要直接抄文件

先读 `intent/` 全部文件。那里写明了**每一项为什么存在**。
新机器的用户名、路径、发行版、有无 GPU 都可能不同 —— 照抄会坏。

> 🔴 **`intent/conventions.md` 请第一个读。** 那份写的是**跟这台机器主人打交道的方式**
> （分工原则、他最烦的两件事、别擅自改他的系统设置），以及**跨项目通用**的环境坑。
> 不先读它，后面很容易犯「为了方案漂亮去改他已定好的东西」这类错。

### 第 2 步：审计新机现状

```bash
bash scripts/audit.sh
```

它会输出新机器已有的 apt/npm/pip 包、dotfile 现状、服务状态。
**把它与 `intent/packages.md` 对比**，只补齐缺失的，不要重装已有的。

### 第 3 步：按 intent 逐项落地

按 `intent/` 各文件的「安装步骤」小节执行。关键原则：

- **追加而非覆盖**：`templates/bashrc.d/*.sh` 是片段，应 `source` 或追加到 `.bashrc` 末尾，
  **绝不要整份替换**新机的 `.bashrc`（新机可能有自己的内容）
- **路径要适配**：模板里的 `/home/caixuf/` 需替换为新机实际 `$HOME`
- **密钥要手填**：见 `intent/secrets.md`，AI **不应**尝试自动获取或生成密钥
- **别被 `plugin_manager` 的「假失败」骗**：报 `failed` 或超时时，包往往**已完整落盘**、
  只差清单登记。判定与修复见 `intent/dsh.md` 的「两种假失败」
- **free-model 走 npm，不要照抄 `file:` tgz 路径**（新机没有那个文件，照抄会让 install 失败）

### 第 4 步：验证

每项落地后按该 intent 文件末尾的「验证」小节自检，不要一次性全做完再验证。

## ⚠️ 安全红线

1. **本仓库不放任何密钥明文**。`intent/secrets.md` 只写变量名与获取途径。
   若你在新机上发现需要密钥，**停下来问用户**，不要从旧机复制。
2. **`.npmrc` / `.gitconfig` 中的凭据 helper 与 token 不入库**。
3. **litellm 的 `proxy.env`、`~/.ccp/secrets.env` 不入库**（含 API Key）。
4. 若需加密方案，另建 `secrets.age`，并确保解密口令**不写在仓库里**。

## 已知的机器绑定项（换机必须改）

| 项 | 旧机值 | 说明 |
|---|---|---|
| Windows 用户名 | `20247` | 出现在 DSH 的 `file:` 依赖、`.wslconfig` 路径中 |
| WSL 用户 | `caixuf` | 出现在 dotfile 路径、`.npmrc` 的 prefix |
| 宿主名 | `caixuf2` | `.gitconfig` 的 credential 作用域 |
| 代理端口 | **`7897`** ＝ 真实代理（singcore，只绑 `127.0.0.1`）；`7898`/`7892` ＝ netsh portproxy 转发到 7897 的垫片 | ⚠️ **不是两个并列的代理**。改候选端口见 `intent/wsl.md`（模板用 `CANDIDATE_PORTS`，旧机 v6 用 `_wsl_candidates`） |
| WSL 网络模式 | 旧机 `mirrored`；**本机必须 NAT + 宿主 portproxy** | 🔴 本机 **开 mirrored 总是失败**，**不要**加 `networkingMode=mirrored`（那些 portproxy 垫片就是为此存在的正式设计）。判据只有一条：代理**实测能出网** |
| free-model 包 | 旧机 `file:` tgz（`dsh-plugin-packages/*.tgz`） | ✅ **npm 上也有 `dsh-our-free-model@^2.1.0`，新机优先用 npm 版**，无需 tgz（本机 2026-10-12 已切） |

## 不在本仓库范围内

以下内容**无法**靠仓库迁移，需人工处理：

- WSL 发行版本身与 `.wslconfig`（需新机自行安装 WSL2）
- Windows 侧应用（DSH Desktop 本体）
- GPU 驱动与 CUDA
- 各 AI CLI 的**登录态**（`claude` / `codex` / `agy` / `codebuddy` 等需重新登录）
- `~/.dsh/.credentials.yaml` 中的密钥值

## 🔗 外部仓库（**引用，不复制**）

以下组件**已有自己的仓库**，本仓库只记录如何获取，**不要把它们的代码复制进来**：

| 组件 | 仓库 | 说明 |
|---|---|---|
| **ccp** | https://github.com/caixuf/claude-code-providers | Claude Code Provider Switcher。一键 `bash install.sh`。**必须克隆到 `~/code/claude-code-providers`**（`ccp sync` 按此路径查找） |
| DSH 本体 | https://github.com/deepseek-ai/deepseek-harness | 官方 |
| `dsh-our-free-model` | **npm：`dsh-our-free-model`**（另有旧机 `file:` tgz 私存副本） | ✅ 作者**已正式发布到 npm**（`^2.1.0`，peer `^0.2.0-rc.1` 匹配 `0.2.0-rc.2`），直接装即可；旧机那条 `file:` 依赖**不必**带到新机 |

**原则**：仓库**只存"如何获取"与"配置意图"**，不存第三方源码。
这样上游更新时，新机 `git pull` 即可，不必从本仓库同步过期副本。

详见 `intent/services.md` 的「ccp」小节。
