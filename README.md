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
  remote-选型.md        ★ 手机远程方案选型：20+ 候选的 peer 兼容性对照表
  dsh-sync-配置清单.md  多机同步（dsh-sync）首次配置步骤与跨机顺序
  ecosystem.md          生态调研结论（哪些插件是什么、值不值得装、调研方法）
                        含**浏览器能力**与**壁纸**的选型与实测结果
  新机器复刻清单.md      🔴 **换机就照这份走**：clone 三仓 → 一条脚本 → 重启
templates/              ← 【是什么】可直接复制、不含密钥
  bashrc.d/*.sh         .bashrc 的片段（拆开，不整份覆盖）
  profile.d/*.sh        .profile 的片段
  systemd/*.service     systemd 单元
  litellm/config.yaml   本地模型网关配置（已剔除密钥）
  dsh/                  DSH profile 配置（package.json / cordis.patch.yml /
                        pnpm-workspace.yaml / cordis.machine-patch.yml /
                        frpc.toml / frps.toml / caddy/）
  proxy.sh              代理垫片（部署件，见 intent/wsl.md）
  skills/               自建 skill（evidence-boundary 证据边界 / ui-design 界面设计，见 intent/dsh.md）
  dsh-sync/             ★ **私有同步仓 `caixuf/dsh-sync` 的部署件**（workflow 模板 + 新建仓步骤，见其 README.md）
forks/                  ← 【例外】本机 fork 的第三方源码（仅源码，不含构建产物）
  dsh-wsl-workspace/    WSL 用户级 skill 补丁（基线 0.7.5）；说明见其 README.fork.md
                        🔴 **2026-10-14 起本机已回滚成官方版**，源码留此备重建
scripts/
  audit.sh              盘点**当前机**实际状态，供 AI 与新机对比（WSL 侧）
  audit-dsh-drift.sh    ★ 审计「仓库模板 vs 本机实机」的 DSH 配置 drift（WSL 侧）
  apply.sh              幂等落地（默认 --check；--dsh 落 DSH 配置）（WSL 侧）
  install-dsh.ps1       🔴 **一键装全部 bundle + 自研宿主插件**（PowerShell）
  proxy-fix.ps1         ★ 修「代理变量大小写重复」导致 `Start-Process` 崩溃（PowerShell）
  provision-vps.sh      VPS 侧一键装 frps + Caddy（bash，在 VPS 上跑）
  check-secrets.sh      提交前密钥扫描（⚠️ 手动跑，无 CI 强制）
```

> 🔴 **换机必须 clone 的两个自研仓** —— 放到**本仓的同级目录**，
> 否则 `install-dsh.ps1` 会跳过它们（它们**未发 npm**，`dsh plugin add`
> 必 404，这是**预期行为不是故障**）：
>
> ```
> <同一父目录>/
>   ├─ dsh-personal-setup/     ← 本仓
>   ├─ dsh-native-mobile/      ← git clone https://github.com/caixuf/dsh-native-mobile.git
>   └─ dsh-rea/                ← git clone https://github.com/caixuf/dsh-rea.git
> ```

> 🔴 **脚本分两个宿主跑**：
> - `apply.sh` / `audit.sh` / `audit-dsh-drift.sh` 在 **WSL**（管 dotfile、systemd、drift 审计）
> - `install-dsh.ps1` 在 **PowerShell**（管 DSH bundle 安装）
> 混用会炸 —— 在 bash 里调 `dsh.cmd` 会报 `@echo: command not found`。

> 🔍 **`audit-dsh-drift.sh` 是防「文档与实机脱节」的常规武器。**
> 本仓已两次出现「文档写的插件实机没有 / 实机有的文档没记」（见 `intent/dsh.md`
> 开头那张 drift 表）。改完模板或本机增删插件后跑一次：
> ```bash
> bash scripts/audit-dsh-drift.sh --profile "/mnt/c/Users/<你>/.dsh/profiles/desktop"
> ```
> 它报「本机有模板无 / 模板有本机无 / 模板残留 `link:` 机器路径 / 机器级 patch 是否入库」。

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

### 第 3 步：落地 DSH profile（`apply.sh --dsh`）

```bash
bash scripts/apply.sh --dsh
```

它会：备份旧配置 → 复制 `package.json` / `cordis.patch.yml` / `pnpm-workspace.yaml`
→ **在覆盖前**做机器绑定项自检 → 打印下一步。

> ⚠️ `apply.sh --dsh` **不管机器级 patch**（`<dsh-home>/cordis.patch.yml`）——
> 那一步连同**宿主插件安装**一起交给第 4 步的 `install-dsh.ps1` 自动化。

### 第 4 步：装全部 bundle + 宿主插件（`install-dsh.ps1`）

```powershell
# 在 PowerShell 里跑（dsh 是 Windows 程序，不能在 WSL/bash 里跑）
.\scripts\install-dsh.ps1                    # 装到 desktop
.\scripts\install-dsh.ps1 -DryRun            # 只列清单，不写任何文件
```

**这是「一键部署」的核心。** 实测 16 个公共 bundle 约十几秒装完，
`dependencies` 与 `dsh.profile.bundles` 自动对齐 —— **不需要在 DSH 里逐个点**。
它还会额外做三件事（缺一换机就坏）：

1. 从**本地源码**装 2 个自研宿主插件（`dsh-mobile-gateway`、`dsh-rea`）——
   它们**没发 npm**，直接 `dsh plugin add` 会 404；
2. 写机器级 `<dsh-home>/cordis.patch.yml`（三行宿主插件）；
3. 复制机器级 `<dsh-home>/node_modules/` 副本（浏览器半边按此路径解析）。

> 🔴 **装完必须重启 DSH**（Node ESM 不热重载；且运行中改 patch 会让设置写入的
> revision 乐观锁错位，表现为「设置保存不了」）。

> **为什么能一条命令搞定**（2026-10-12 实测）：
> `dsh plugin --profile <p> add <pkg>` 一条命令干三件事 ——
> ① profile 不存在则自动初始化 ② pnpm 装包（版本自动解析成最新版）
> ③ 自动把包名写进 `dsh.profile.bundles`。
> 所以整套装机 = 对模板 `dependencies` 里每个非 `link:`/`file:` 包跑一次 `add`。
>
> ⚠️ 早先文档写「必须用 plugin_manager 逐个 install_bundle」是**误判** ——
> 那次失败的真因是 `package.json` 里写了无效的 `link:` 路径，**不是命令选错**。

### 第 5 步：按 intent 逐项落地其余部分

按 `intent/` 各文件的「安装步骤」小节执行。关键原则：

- **追加而非覆盖**：`templates/bashrc.d/*.sh` 是片段，应 `source` 或追加到 `.bashrc` 末尾，
  **绝不要整份替换**新机的 `.bashrc`（新机可能有自己的内容）
- **路径要适配**：模板里的 `/home/caixuf/` 需替换为新机实际 `$HOME`
- **密钥要手填**：见 `intent/secrets.md`，AI **不应**尝试自动获取或生成密钥
- **free-model 走 npm**（模板已是 `^2.1.0`）；若见到 `file:` 引用那是旧机残留，别照抄
- **WSL fork 是选装**，不在模板默认清单里，且**本机当前已回滚成官方版** —— 见下方「WSL fork」节
- **`dsh-sync` 用 GitHub 托管时是"只推分支"降级模式** —— pull 侧已修好
  （`main` 已建并设为默认分支，2026-10-14），但**插件不会把改动自动合进 `main`**：
  PR 创建/合并、`conflict/run`、`prune-branches` 全是 GitCode 专属，
  每次同步只推一个 `sync/<实例ID>/<时间戳>` 分支，**要人工在网页开 PR 合并**。
  另：插件会**把 token 提交进它自己那个私有库**（`cordis.patch.yml` 在同步范围内），
  这一点用 `syncPlugins` 开关控制不了细粒度，见 `intent/dsh-sync-配置清单.md`
- 🔴 **`dsh-sync` 还需要单独配一次**（面板填 owner/repo/token），
  `install-dsh.ps1` **不管**这步 —— 见 `intent/新机器复刻清单.md` 第 2.6 步

### 第 6 步：验证

### 三条最容易踩的坑

| 坑 | 症状 | 解法 |
|---|---|---|
| **在 bash/WSL 里调 `dsh.cmd`** | `@echo: command not found`，**且退出码仍是 0** | 用 PowerShell 跑 `install-dsh.ps1`；别自己写 bash 版 |
| **`link:` 路径照抄别人的** | `cannot resolve profile bundle` → **整装失败** | 模板已不含 `link:`；脚本在覆盖前会点出来 |
| **`$ErrorActionPreference='Stop'` + dsh 写 stderr** | 初始化 profile 时的正常提示被当**致命错误**抛出，第一个包就中断 | 脚本内已把该段临时降级为 `Continue` |

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
| Windows 用户名 | `20247` | 出现在 `.wslconfig`、若干文档路径与脚本默认值中。**模板 `templates/dsh/package.json` 已不含任何 `link:`**（2026-10-14 复核），故此项不影响 `install-dsh.ps1` |
| WSL 用户 | `caixuf` | 出现在 dotfile 路径、`.npmrc` 的 prefix |
| 宿主名 | `caixuf2` | 出现在 `intent/wsl.md` 的机器标注；`.gitconfig` 里只有 `[credential] helper = store`，**不含宿主名** |
| 代理端口 | **`7897`** ＝ 真实代理（singcore，只绑 `127.0.0.1`）；`7898`/`7899`/`7892` ＝ netsh portproxy 转发到 7897 的垫片 | ⚠️ **不是并列的多个代理**。`7899` 是 `intent/wsl.md` 指定的**推荐同名转发**口，别漏。改候选端口见 `intent/wsl.md`（模板用 `CANDIDATE_PORTS`） |
| WSL 网络模式 | 旧机 `mirrored`；**本机必须 NAT + 宿主 portproxy** | 🔴 本机 **开 mirrored 总是失败**，**不要**加 `networkingMode=mirrored`（那些 portproxy 垫片就是为此存在的正式设计）。判据只有一条：代理**实测能出网** |
| free-model 包 | 旧机 `file:` tgz（`dsh-plugin-packages/*.tgz`） | ✅ **npm 上也有 `dsh-our-free-model@^2.1.0`，新机优先用 npm 版**，无需 tgz（本机 2026-10-12 已切） |
| **WSL fork 运行副本** | `<Windows 工作目录>\dsh-wsl-workspace-fork` | 🔴 **2026-10-14 实测：该目录与本机 WSL 源仓都已不存在，fork 已回滚**。新机**默认不要装** fork（用官方 `^0.7.5`）；确有需要再按下面「WSL fork」重建 |
| 主机地址 | VPS 公网 IP + frp token | 见 `templates/dsh/frpc.toml` 的三处占位符与 `intent/新机器复刻清单.md` 第 3 步 |

### WSL fork：**选装**，不在模板默认清单里

> ⚠️ **模板 `templates/dsh/package.json` 里是官方 `dsh-wsl-workspace: ^0.7.5`。**
> 这是**刻意的** —— 之前模板里写的是本机 `link:` 绝对路径，
> 别的机器没有该目录，`install` 会直接报
> `cannot resolve profile bundle "dsh-wsl-workspace"` **导致整套安装失败**。
> 反馈「照仓库同步没成功」就是这个原因。

改动源码保存在 **`forks/dsh-wsl-workspace/`**（MIT，保留上游版权声明），
只含源码与测试，**不含 `lib/` 构建产物**（`npm run build` 生成）。

> 🔴 **2026-10-14 实测：fork 已不在本机运行。**
> 实装的 `node_modules/dsh-wsl-workspace` 是**真实目录、官方 0.7.5**，
> fork 的标志符号（`discoverUserSkillRoots` / `USER_DSH_RANK` / `resolveDistributionHome`）
> 在实装 `lib/` 里**各 0 命中**；`package.json` 里是 `^0.7.5` 而非 `link:`；
> 两个运行/开发目录都不存在。
> **后果**：WSL 用户级 skill 不再被加载 —— 当前 WSL 侧带 `SKILL.md` 的 skill
> 只有 `~/.claude/skills` 7 个、`~/.agents/skills` 9 个（旧文档写的 61/62 已失效）。
> 详见 `intent/dsh.md` 的「WSL 用户级 skill fork」一节。

| 位置 | 角色 | 受版本控制 | 现状（2026-10-14） |
|---|---|---|---|
| `forks/dsh-wsl-workspace/`（本仓） | **改动源码** + `README.fork.md`（改动说明、哨兵、构建/测试/同步命令） | ✅ | ✅ 在（重建的唯一来源） |
| `<Windows 工作目录>\dsh-wsl-workspace-fork`（本机） | **运行副本**，DSH 的 `node_modules` 用 junction 指向它 | ❌ | 🔴 **不存在** |
| `~/code/dsh-wsl-workspace`（本机 WSL） | 开发用 git 仓，分支 `feat/wsl-user-skills-075` @ `f1f30d2` | ✅（仅本机） | 🔴 **不存在** |

> ✅ **有价值的部分已保住。** 此前那 176 行改动只存在于本机 WSL 的 `~/code/`，
> WSL 一重装就没了。现在它们在本仓里，跟着仓库走 ——
> **本机那份丢了，但源码在仓库里，随时能重建。**

**什么时候才需要装这个 fork？** 你在 WSL 里有用户级 skill 目录
（`~/.claude/skills` 或 `~/.agents/skills`，数一下有多少个）。
**没有的话不用装**，官方版就够 —— 少一个机器相关依赖，少一个坏点。

要装时（步骤见 `forks/dsh-wsl-workspace/README.fork.md` 与 `intent/dsh.md` 对应节）：

```
1. node >= 24，npm install && npm run build（末尾须 verify-lib OK）
2. 哨兵 grep -c variantGeneration lib/index.js   ← 必须为 0，非 0 就是炸弹
3. 复制到 Windows 可访问路径
4. 把 profile 的 package.json 那一条改成 link:<你自己的路径>，再 install
```

**第 4 步的路径必须是新机自己的** —— 照抄别人的必然失败。

### 模板与本机实机的已知差异（不是错误）

| 项 | 模板 | 本机实机 | 原因 |
|---|---|---|---|
| `dsh-wsl-workspace` | `^0.7.5` | `link:<本机路径>` | 本机装了 fork 让 61 个 WSL skill 可见 |

模板 = **通用基线**（任何机器直接可用）；实机 = 在基线上的**本机增强**。
审计时不要把这个差异当「文档与实机不符」。

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
| **dsh-native-mobile** | https://github.com/caixuf/dsh-native-mobile | 🔴 **自研**，含 `dsh-mobile-gateway`（原生移动端网关）。**未发 npm**，`dsh plugin add` 必 404 —— 只能从本地源码装。须 clone 到 **`dsh-personal-setup` 的同级目录**（`install-dsh.ps1` 靠相邻关系发现） |
| **dsh-rea** | https://github.com/caixuf/dsh-rea | 🔴 **自研**，逆向工程助手插件。**未发 npm**，同样只能从本地源码装 + 同级目录 |
| **dsh-wsl-workspace** | 上游 https://github.com/dsh-wsl-workspace-maintainers/dsh-wsl-workspace | 本机装的是**本地 fork**（分支 `feat/wsl-user-skills-075` @ `f1f30d2`），源码已随本仓 `forks/dsh-wsl-workspace/` 入库（见下「fork 例外」）。⚠️ 上游 `0.7.7` **重写了 preset 派生机制**，装上会让所有 WSL 会话报 `Unknown agent preset: wsl-standard` |
| DSH 本体 | https://github.com/deepseek-ai/deepseek-harness | 官方 |
| `dsh-our-free-model` | **npm：`dsh-our-free-model`**（另有旧机 `file:` tgz 私存副本） | ✅ 作者**已正式发布到 npm**（`^2.1.0`，peer `^0.2.0-rc.1` 匹配 `0.2.0-rc.2`），直接装即可；旧机那条 `file:` 依赖**不必**带到新机 |

> 🔴 **`dsh-mobile-gateway` / `dsh-rea` 这类自研插件没发 npm。**
> 仓库里有它们的 `dependencies` 条目，但 `dsh plugin add` 会 404 ——
> 那是**预期行为，不是故障**。`install-dsh.ps1` 会自动从同级目录的源码装。
> 换机时记得 clone（否则脚本会打印 `git clone` 提示并跳过）：
>
> ```bash
> git clone https://github.com/caixuf/dsh-native-mobile.git
> git clone https://github.com/caixuf/dsh-rea.git
> ```
>
> ⚠️ **别只查 npm 就断定「没有这个插件」** —— 自研插件只在 git 上。
> 详细步骤见 `intent/新机器复刻清单.md`（那份文件就是为此存在的）。

**原则**：仓库**只存"如何获取"与"配置意图"**，不存第三方源码。
这样上游更新时，新机 `git pull` 即可，不必从本仓库同步过期副本。

> **例外：`forks/`。** 若某个第三方组件**本机改了源码、且改动无法靠配置表达**，
> 就把它作为 fork 存进 `forks/<name>/`（仅源码 + 保留上游 LICENSE）。
> 目前只有 `dsh-wsl-workspace` 一个 —— 理由见 `intent/dsh.md` 的「WSL 用户级 skill fork」节。
> **新增 fork 前先问：能不能用配置解决？** 能就别 fork。

详见 `intent/services.md` 的「ccp」小节。
