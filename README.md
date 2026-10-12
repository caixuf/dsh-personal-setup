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
  ecosystem.md          生态调研结论（哪些插件是什么、值不值得装、调研方法）
                        含**浏览器能力**与**壁纸**的选型与实测结果
templates/              ← 【是什么】可直接复制、不含密钥
  bashrc.d/*.sh         .bashrc 的片段（拆开，不整份覆盖）
  profile.d/*.sh        .profile 的片段
  systemd/*.service     systemd 单元
  litellm/config.yaml   本地模型网关配置（已剔除密钥）
  dsh/                  DSH profile 配置（package.json / cordis.patch.yml / pnpm-workspace.yaml）
  proxy.sh              代理垫片（部署件，见 intent/wsl.md）
  skills/               自建 skill（当前：evidence-boundary，见 intent/dsh.md）
forks/                  ← 【例外】本机 fork 的第三方源码（仅源码，不含构建产物）
  dsh-wsl-workspace/    WSL 用户级 skill 补丁（基线 0.7.5）；说明见其 README.fork.md
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
| Windows 用户名 | `20247` | 出现在 DSH 的 `link:` 依赖（`templates/dsh/package.json` 的 `dsh-wsl-workspace`）、`.wslconfig` 路径中 |
| WSL 用户 | `caixuf` | 出现在 dotfile 路径、`.npmrc` 的 prefix |
| 宿主名 | `caixuf2` | 出现在 `intent/wsl.md` 的机器标注；`.gitconfig` 里只有 `[credential] helper = store`，**不含宿主名** |
| 代理端口 | **`7897`** ＝ 真实代理（singcore，只绑 `127.0.0.1`）；`7898`/`7899`/`7892` ＝ netsh portproxy 转发到 7897 的垫片 | ⚠️ **不是并列的多个代理**。`7899` 是 `intent/wsl.md` 指定的**推荐同名转发**口，别漏。改候选端口见 `intent/wsl.md`（模板用 `CANDIDATE_PORTS`） |
| WSL 网络模式 | 旧机 `mirrored`；**本机必须 NAT + 宿主 portproxy** | 🔴 本机 **开 mirrored 总是失败**，**不要**加 `networkingMode=mirrored`（那些 portproxy 垫片就是为此存在的正式设计）。判据只有一条：代理**实测能出网** |
| free-model 包 | 旧机 `file:` tgz（`dsh-plugin-packages/*.tgz`） | ✅ **npm 上也有 `dsh-our-free-model@^2.1.0`，新机优先用 npm 版**，无需 tgz（本机 2026-10-12 已切） |
| **WSL fork 运行副本** | `<Windows 工作目录>\dsh-wsl-workspace-fork` | ⚠️ **该目录不受版本控制**（所在目录不是 git 仓）。DSH 用 `link:` 指向它，删了就装不上 |

### WSL fork：改动已存进本仓

改动源码现保存在 **`forks/dsh-wsl-workspace/`**（MIT 许可，保留上游版权声明）。
只含源码与测试，**不含 `lib/` 构建产物** —— 重建时跑 `npm run build` 生成。

| 位置 | 角色 | 受版本控制 |
|---|---|---|
| `forks/dsh-wsl-workspace/`（本仓） | **改动源码** + `README.fork.md`（改动说明、哨兵、构建/测试/同步命令） | ✅ |
| `<Windows 工作目录>\dsh-wsl-workspace-fork`（本机） | **运行副本**，DSH 的 `node_modules` 用 junction 指向它 | ❌ |
| `~/code/dsh-wsl-workspace`（本机 WSL） | 开发用 git 仓，分支 `feat/wsl-user-skills-075` @ `f1f30d2` | ✅（仅本机） |

> ✅ **单点风险已解除。** 此前那 176 行改动只存在于本机 WSL 的 `~/code/`，
> WSL 一重装就没了。现在它们在本仓里，跟着仓库走。

新机上复现：从 `forks/dsh-wsl-workspace/` 出发 → `npm install && npm run build`（需 node ≥24）
→ 查哨兵 `grep -c variantGeneration lib/index.js`（**必须为 0**）
→ 复制到 Windows 可访问路径 → `link:` 装进 DSH。详见该目录的 `README.fork.md`。

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
| **dsh-wsl-workspace** | 上游 https://github.com/dsh-wsl-workspace-maintainers/dsh-wsl-workspace | 本机装的是**本地 fork**（分支 `feat/wsl-user-skills-075` @ `f1f30d2`），源码已随本仓 `forks/dsh-wsl-workspace/` 入库（见下「fork 例外」）。⚠️ 上游 `0.7.7` **重写了 preset 派生机制**，装上会让所有 WSL 会话报 `Unknown agent preset: wsl-standard` |
| DSH 本体 | https://github.com/deepseek-ai/deepseek-harness | 官方 |
| `dsh-our-free-model` | **npm：`dsh-our-free-model`**（另有旧机 `file:` tgz 私存副本） | ✅ 作者**已正式发布到 npm**（`^2.1.0`，peer `^0.2.0-rc.1` 匹配 `0.2.0-rc.2`），直接装即可；旧机那条 `file:` 依赖**不必**带到新机 |

**原则**：仓库**只存"如何获取"与"配置意图"**，不存第三方源码。
这样上游更新时，新机 `git pull` 即可，不必从本仓库同步过期副本。

> **例外：`forks/`。** 若某个第三方组件**本机改了源码、且改动无法靠配置表达**，
> 就把它作为 fork 存进 `forks/<name>/`（仅源码 + 保留上游 LICENSE）。
> 目前只有 `dsh-wsl-workspace` 一个 —— 理由见 `intent/dsh.md` 的「WSL 用户级 skill fork」节。
> **新增 fork 前先问：能不能用配置解决？** 能就别 fork。

详见 `intent/services.md` 的「ccp」小节。
