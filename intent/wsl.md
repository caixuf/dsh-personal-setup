# intent/wsl.md — WSL2 环境与 dotfile

## 基线环境

| 项 | 值 |
|---|---|
| 发行版 | `Ubuntu-24.04`（Ubuntu 24.04.4 LTS） |
| WSL 版本 | WSL2，内核 `6.6.114.1-microsoft-standard-WSL2` |
| WSL 平台版本 | `2.7.3.0` |
| WSL 用户 | `caixuf`（uid 1000，**sudo 免密**） |
| 宿主名 | `caixuf2` |
| 内存/CPU | `.wslconfig` 限 16GB / 12 核，swap 8GB |
| GPU | NVIDIA RTX 5060 Laptop，`/dev/dxg` 直通可用 |

## ⚠️ 网络拓扑：mirrored 或 NAT+portproxy **都可行**（别只看配置就下结论）

**真正的要求只有一条**：`~/.proxy.sh` 的候选端口里，至少有一个**真能出网**。
用哪种 WSL 网络模式都可以：

| 拓扑 | `.wslconfig` | 代理该怎么监听 | WSL 侧访问地址 |
|---|---|---|---|
| **mirrored** | `networkingMode=mirrored` | `127.0.0.1:7897` 即可 | `127.0.0.1:7897`（直通宿主） |
| **NAT + portproxy** | 不设 `networkingMode`（默认 NAT） | 宿主全接口 / portproxy | 默认网关 IP，如 `172.18.80.1:7898` |

NAT 模式下 `127.0.0.1` 是 WSL 自己的，所以**必须**经网关 IP 访问宿主端口 ——
**这不是故障**，`~/.proxy.sh` v6 会把两种地址都试一遍。

**🔴 别把「不是 mirrored」直接判为故障**（`apply.sh` 早期版本就是这么误报的）。
以 `proxy_test` 或 `apply.sh --check` 的**实测出网**为准。
2026-10-10 实测一台 NAT+portproxy 的机器：`github.com → 200`、`registry.npmjs.org → 200`，
完全正常，**不需要**改 `.wslconfig`、更不需要 `wsl --shutdown`。

旧机 `.wslconfig` 参考值（改用 NAT+portproxy 时删掉 `networkingMode` 那行即可）：

```ini
[wsl2]
networkingMode=mirrored
memory=16GB
swap=8GB
processors=12

[experimental]
autoMemoryReclaim=dropcache
sparseVhd=true
```

**改 `.wslconfig` 后需 `wsl --shutdown` 生效** —— 它会杀掉 WSL 内所有进程
（含 IDE remote server、litellm 等），**非必要不要动**。

## 代理机制（本项目最精妙的部分）

### 端口约定（`~/.proxy.sh` 顶部注释，不可互相改）

| 端口 | 用途 |
|---|---|
| **7897** | 星连 SingLink 内核 singcore 的 mixed 端口（**mirrored 拓扑**下的首选） |
| **7898** | 星连 portproxy 口（**NAT 拓扑**下的首选，v4 起 7892→7898） |
| 7899 | Clash Verge 备胎（已从 7892 挪开，避免和星连打架） |
| 7892 | 历史遗留位（超实惠 sing-box 时代）—— 仅兜底 |

**若新机代理软件端口不同**，改候选端口列表 —— ⚠️ **两代文件变量名不同，别 grep 错**：

| 文件 | 变量名 | 值 |
|---|---|---|
| 本仓库模板 `templates/proxy.sh`（**部署用这个**） | `CANDIDATE_PORTS` | `"7897 7898 7899 7892"` |
| 旧机在跑的 v6 版（244 行） | `_wsl_candidates` | `(7898 7899 7892 7897)` |

### 设计要点（不要简化掉）

1. **真请求探活**，不是「端口开着」：
   端口被别的程序占着也算开着，只有真发一次请求拿到 204/200 才能拆穿。
   ```bash
   # 本仓库模板 templates/proxy.sh 的实现（推荐部署这个）
   _wsl_tcp_ok()   { ... }   # 第一层：TCP 预检，快速排除死端口（省掉逐个 HTTP 白等）
   _host_port_ok() { ... }   # 第二层：真发请求，200/204/301/302 才算通
   _port_ok()      { ... }   # 跨「候选宿主地址」探测，命中即定 PROXY_HOST
   ```
   ⚠️ 旧机在跑的 v6 版函数名是 `_wsl_tcp_ok` / `_wsl_http_ok`，且宿主写死
   `127.0.0.1`（只支持 mirrored）。两代并存，grep 时注意。
2. **优雅降级**：代理没启动时直连，而不是所有请求一起断。
3. **git 代理同步 + 内网例外**：`gitlab-ap-office.immotors.com` 必须直连
   （走代理会把域名丢给上游解析 → 超时）。
4. **清理 Clash 时代遗留**：指向废弃端口（`:7892` / `:8118`）的 git URL 分节会被自动清掉。
5. **🔴 宿主地址只能用「全局副作用」传出，不能用 `$(...)`**：
   `PROXY_HOST` 是探测函数设置的全局变量。若调用方写成 `chosen="$(detect_port)"`，
   **命令替换会开子 shell，赋值直接丢** → NAT 下得到「端口对了、地址仍是
   `127.0.0.1`」的死 URL（实测过这个 bug）。模板里用 `_proxy_detect`
   直接设置 `PROXY_HOST`/`PROXY_PORT` 来规避。

### ⚠️ 幽灵代理陷阱（`wsl-proxy-autofix v7`，勿删）

**问题**：VS Code / Cursor / Antigravity 的 remote server 会在启动时 source
`~/.vscode-server/server-env-setup`（或 `~/.cursor-server/`、`~/.antigravity-ide-server/`），
把里面**写死的小写 `http_proxy`** 注入终端子进程。

**为什么危险**：Go 程序（`agy` / `opencode`）只读**小写**代理变量，且小写优先级更高。
换代理软件后那个端口变成死地址 → 这些程序**静默卡死**（不报错，就是不动）。

**对策**（`.bashrc` 中 `# >>> wsl-proxy-autofix v7 >>>` 块）：
- 未设置代理 → 开启
- 已设置但指向本地端口且该端口不活（幽灵）→ 用 `proxy_on` 覆盖
- 已设置且是**非本地地址**（公司代理）→ **不动它**

**这个块必须放在 `.bashrc` 的交互守卫之后**（因为它依赖 `proxy_port_alive`）。

## dotfile 结构

`.bashrc` 里的自定义块（按行号，新机应**追加**而非覆盖）：

| 块 | 位置 | 作用 |
|---|---|---|
| CodeBuddy sandbox | 第 5-10 行 | `export CODEBUDDY_IS_SANDBOX=1`（**在交互守卫之前**，交互+登录 shell 都命中） |
| ccp 统一管理 | 第 12-17 行 | source `~/.ccp/env.sh`，**禁止**在此硬编码 LLM 密钥 |
| 代理快捷开关 | 第 140-152 行 | source `~/.proxy.sh` |
| wsl-proxy-autofix v7 | 第 153-175 行 | 幽灵代理纠正（见上） |
| npm-global PATH | 第 177 行 | `export PATH=~/.npm-global/bin:$PATH` |
| MiniMax CN 备用 | 第 179-200 行 | **全部注释掉**，启用需手动 |
| 各 CLI 安装器 | 202+ | Antigravity / grok / MiniMax Code / CodeM 追加的 PATH |

`.profile` 里的自定义块：

| 块 | 作用 |
|---|---|
| Antigravity CLI installer | PATH |
| **`# dsh: npm global bin`** | ⚠️ **必须加**：`.bashrc` 的 PATH 只在交互 shell 生效，`wsl.exe` 走登录式 shell 读不到 |

**最后一项是踩坑得来的**：DSH 的 `wsl` 工具用登录式 shell，曾因 `.profile` 缺这段导致 `pnpm` 找不到。

## 自定义 systemd 单元

| 单元 | 作用 | 备注 |
|---|---|---|
| `fix-wsl-net.service` | 开机修正默认路由 + 补内网 GitLab host | 见 `templates/systemd/` |
| `imfl-autotest.service` | IMFL 自动测试云平台（端口 9900） | 依赖 docker，`WorkingDirectory=/home/caixuf/code/imfl_auto_test` |
| `mnt-bh.mount` | Samba `//172.100.100.2/bh` | 见下方「挂载陷阱」 |

### `fix-wsl-net.service` 为什么存在

**问题**：WSL 把 Windows 多块网卡镜像进来，默认路由可能命中**不可达的网卡**
（如 `192.168.137.1` 热点网卡），导致只有经宿主代理才能出网。

**做法**：动态探测「可达的默认网关」，设为最高优先级（热点网卡 `10.255.163.*` → metric 50，
其他可达 → metric 100），删除不可达的默认路由；幂等补内网 GitLab 域名到 `/etc/hosts`
（WSL 重启会重建 `/etc/hosts`）。

### ⚠️⚠️ 挂载陷阱（曾导致 WSL 完全无法启动）

**症状**：所有 `wsl.exe` 调用返回 `Wsl/Service/E_UNEXPECTED`，但 `wsl -l -v` 仍显示 Running。

**根因**：`mnt-xw.mount` / `mnt-ql.mount` / `mnt-zq.mount` 指向 **`//172.100.100.2/{xw,ql,zq}`**，
该服务器离线时，这些 `.mount` 单元（含 `Before=local-fs.target`）会**永久阻塞 systemd boot**，
`systemctl is-system-running` 卡在 `starting`。

**关键教训**：`.mount` 单元的 `nofail` 选项**不能**防止这种阻塞（因为阻塞在 `local-fs.target` 之前）。

**处置**：把指向**可能离线服务器**的 `.mount` 单元 **disable 或移走**，需要时手动 mount。
本次已移到 `/root/disabled-samba-mounts/`。

**新机建议**：若要配 Samba 挂载，先确认服务器**长期在线**，否则不要设为开机自动挂载。

## 安装步骤

```bash
# 1. apt 包（分组见 intent/packages.md）
sudo apt update
sudo apt install -y <按 packages.md 的 apt 清单>

# 2. 用户级 dotfile（追加，不要覆盖）
cp templates/bashrc.d/*.sh ~/.bashrc.d/     # 或按块追加到 ~/.bashrc
cp templates/profile.d/*.sh ~/.profile.d/   # 同上
cp templates/proxy.sh  ~/.proxy.sh          # 已在 templates/ 内，无需从旧机取

# 3. systemd 单元
sudo cp templates/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now fix-wsl-net.service

# 4. 【手动】验证代理
source ~/.proxy.sh && proxy_test
```

### ⚠️ 不在 templates/ 中的文件

| 文件 | 处理方式 |
|---|---|
| `~/.proxy.sh` | ✅ **已在 `templates/proxy.sh`**（只含端口与白名单，无密钥） |
| `~/.ccp/*` | 由 **ccp 自己的仓库**提供，见 `intent/services.md`。**不要从本仓库复制** |
| `~/.ccp/secrets.env` | ❌ **含 API Key，任何仓库都不放** |
| `~/.ccp/env.sh` | 由 `ccp <provider>` 自动生成，**不要复制** |
| `~/.claude/providers/*.json` | ❌ 含密钥，由 ccp 仓库的 `*.json.example` 初始化后**手填** |

**ccp 有独立仓库**：https://github.com/caixuf/claude-code-providers
（克隆到 `~/code/claude-code-providers` 后 `bash install.sh`）

## 验证

```bash
# 网络
systemctl is-system-running          # 期望 running（不是 starting）
ip route show default                # 期望可达网关，无 192.168.137.x
grep gitlab /etc/hosts               # 期望有条目可达

# 代理
proxy_test                           # 候选端口 + GitHub/Google/内网 连通性
proxy_doctor                         # WSL 网络体检

# 工具链
node -v && npm -v && pnpm -v         # pnpm 需在 PATH（~/.npm-global/bin）
python3 -V && git --version
```
