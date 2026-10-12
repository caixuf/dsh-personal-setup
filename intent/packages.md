# intent/packages.md — 软件包清单

## ⚠️ 使用方式

**不要整份安装。** 先跑 `scripts/audit.sh` 看新机已有多少，**只补缺失的**。
下面的「用途」列是让 AI 判断**新机是否真的需要**（例如无 GPU 的机器不需要 CUDA 栈）。

## 1. apt 手动安装包（79 个）

### 1.1 基础工具（几乎所有机器都要）

```bash
sudo apt install -y \
  build-essential gcc g++ make cmake ninja-build pkg-config \
  git curl wget unzip tar rsync jq lsof net-tools \
  openssh-client openssh-server sshpass \
  python3-dev python3-pip python3.12-venv pipx \
  libffi-dev libsqlite3-dev libcjson-dev libdbus-1-dev
```

| 包 | 用途 |
|---|---|
| `build-essential` / `gcc` / `g++` / `make` / `cmake` / `ninja-build` | C/C++ 编译（含 conan、sumo 依赖） |
| `git` / `gh` | 版本控制 / GitHub CLI（`.gitconfig` 的 credential helper 依赖 `gh`） |
| `jq` | JSON 处理（脚本与调试常用） |
| `ripgrep` | ⚠️ **DSH 的 `grep` 工具依赖它** |
| `lsof` | 排查文件占用（本项目的桌宠 EPERM 问题用它查过） |
| `rsync` | 同步（迁移用） |

### 1.2 容器与沙箱

```bash
sudo apt install -y docker.io docker-compose-v2 bubblewrap iptables
```

| 包 | 用途 |
|---|---|
| `docker.io` / `docker-compose-v2` | 容器（`imfl-autotest.service` 依赖） |
| **`bubblewrap`** | ⚠️ **DSH 的 `dsh-wsl-workspace` / `dsh-plugin-wsl-env` 用它做沙箱隔离** |
| `iptables` | 网络规则 |

### 1.3 媒体与图形

```bash
sudo apt install -y ffmpeg imagemagick chromium-browser
```

| 包 | 用途 |
|---|---|
| `ffmpeg` | 音视频处理（DSH 语音插件、webm 动画处理） |
| `imagemagick` | 图片处理 |
| `chromium-browser` | 无头浏览器（`dsh-vault` 等插件的 playwright 依赖） |

### 1.4 网络与文件共享

```bash
sudo apt install -y cifs-utils privoxy dnsutils inetutils-telnet iputils-ping
```

| 包 | 用途 |
|---|---|
| `cifs-utils` | ⚠️ Samba 挂载（`mnt-bh.mount` 需要；**注意挂载陷阱**，见 `wsl.md`） |
| `privoxy` | HTTP 代理（8118，遗留） |
| `dnsutils` / `inetutils-telnet` / `iputils-ping` | 网络排查 |

### 1.5 交叉编译与科学计算

```bash
sudo apt install -y g++-mingw-w64-x86-64 valgrind \
  python3-pyproj libeigen3-dev \
  qt6-base-dev qt6-declarative-dev \
  qml6-module-qtqml qml6-module-qtqml-workerscript qml6-module-qtquick \
  qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtquick-templates qml6-module-qtquick-window \
  sumo sumo-tools
```

| 包 | 用途 | 新机是否需要 |
|---|---|---|
| `g++-mingw-w64-x86-64` | Windows 交叉编译 | 仅当要编 Windows 程序 |
| `valgrind` | 内存调试 | 仅当 C/C++ 开发 |
| `python3-pyproj` / `libeigen3-dev` | 地理投影 / 线性代数 | 仅当相关项目 |
| `qt6-*` / `qml6-*` | Qt6 GUI 开发 | 仅当 Qt 项目 |
| **`sumo` / `sumo-tools`** | 交通仿真 | ⚠️ 仅当做交通仿真，**体积很大** |

### 1.6 其他

```bash
sudo apt install -y cloc ffmpeg libattr1 ncurses-base ncurses-bin
```

| 包 | 用途 |
|---|---|
| `cloc` | 代码行数统计 |

## 2. npm 全局包（13 个）

```bash
npm i -g \
  @anthropic-ai/claude-code @openai/codex @github/copilot copilot-api command-code \
  @tencent-ai/codebuddy-code cline opencode-ai \
  @larksuite/cli @lark-project/meegle \
  harness-agent antigravity-claude-proxy \
  pnpm
```

| 包 | 用途 |
|---|---|
| `@anthropic-ai/claude-code` | Claude Code CLI |
| `@openai/codex` | OpenAI Codex CLI |
| `@github/copilot` / `copilot-api` | GitHub Copilot |
| `command-code` | Command Code CLI（曾漏记，2026-10-12 对照 `npm ls -g` 补上） |
| `@tencent-ai/codebuddy-code` | CodeBuddy |
| `cline` | Cline |
| `opencode-ai` | opencode |
| `@larksuite/cli` / `@lark-project/meegle` | 飞书 CLI（私有 registry 作用域 `@lark-codem`） |
| `harness-agent` | DSH 相关 |
| `antigravity-claude-proxy` | ⚠️ **已禁止默认拉起**（自打 Cloud Code，封号风险）。原文档此处写「见 `wsl.md` 注释」，但 `wsl.md` 里并无该内容 —— 已改为就地说明 |
| **`pnpm`** | ⚠️ `corepack enable` 会因 `/usr/local/bin` 不可写而失败，改用 `npm i -g pnpm` |

**注意**：`~/.npmrc` 里 `prefix=/home/caixuf/.npm-global`，全局包装到**用户目录**，非 `/usr/local`。

## 3. pip 用户级包

体积很大（含 CUDA 栈）。**按需安装**，以下是分组：

### 3.1 ML / 深度学习（⚠️ 需 GPU，无 GPU 不要装）

```
torch 系: bitsandbytes accelerate datasets transformers
cuda 系: cuda-bindings cuda-pathfinder cuda-toolkit
```

### 3.2 Web / API

```
fastapi flask uvicorn httpx aiohttp starlette
```

### 3.3 数据与科学计算

```
numpy pandas matplotlib scipy contourpy cycler
```

### 3.4 其他工具

```
conan        # C++ 包管理
fonttools    # 字体
sympy        # 符号计算
```

### 3.5 ⚠️ 本仓库相关

```
deepseek-harness-sdk
```

### 完整清单导出方式

```bash
pip3 list --user --format=freeze > pip-user.txt
```

**新机建议**：不要照抄，用 `pip3 install <按项目需要>`。
CUDA 栈版本对 GPU 驱动敏感，照抄可能装不上。

## 4. WSL 内的其他工具链

这些是**通过各自 installer 装的**，不在 apt 里：

| 工具 | 位置 | 说明 |
|---|---|---|
| `grok` | `~/.grok/` | installer 装的，`.bashrc` 有 PATH |
| `agent` | `~/.grok/bin/agent` | |
| `codem` | `~/.codem/` | MiniMax Code CLI |
| `mimocode` | `~/.mimocode/bin/` | `.bashrc` 末尾有 PATH |
| `antigravity` | `~/.antigravity-ide-server/` | IDE remote server |
| `cursor-agent` | `~/.local/share/cursor-agent/` | |
| `litellm` | `~/.local/share/litellm-venv/` | 见 `services.md` |
| **`ccp`** | `~/.local/bin/ccp` | ✅ **有独立仓库**：https://github.com/caixuf/claude-code-providers<br>克隆到 `~/code/claude-code-providers` 后 `bash install.sh`。见 `services.md` |

## 5. 新机安装顺序建议

```bash
# 1. 基础（先跑 audit.sh 看缺什么）
sudo apt update
sudo apt install -y build-essential git curl wget jq ripgrep lsof rsync

# 2. 容器与沙箱（DSH 的 WSL 插件需要 bubblewrap）
sudo apt install -y docker.io docker-compose-v2 bubblewrap

# 3. Node 工具链（node 已由 WSL/apt 或 nvm 提供）
npm i -g pnpm            # 不要用 corepack enable
# 修正 ~/.profile 的 PATH（见 wsl.md）

# 4. 按需继续
```

## 6. 验证

```bash
bash scripts/audit.sh    # 会输出新旧机差异
```

关键命令自检：

```bash
for c in node npm pnpm python3 pip3 git gh jq rg docker bwrap ffmpeg cloc cmake; do
  printf "%-10s " "$c"; command -v "$c" >/dev/null 2>&1 && echo OK || echo MISSING
done
```
