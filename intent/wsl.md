# intent/wsl.md — WSL2 环境与 dotfile

## 基线环境

| 项 | 值 |
|---|---|
| 发行版 | `Ubuntu-24.04`（Ubuntu 24.04.4 LTS） |
| **WSL 发行版名** | **`Ubuntu`** ← 命令里是 `wsl -d Ubuntu`；⚠️ **主机名才叫 `caixuf2`，别混** |
| WSL 版本 | WSL2，内核 `6.6.114.1-microsoft-standard-WSL2` |
| WSL 平台版本 | `2.7.3.0` |
| WSL 用户 | `caixuf`（uid 1000，**sudo 免密**） |
| 宿主名 | `caixuf2` |
| 内存/CPU | `.wslconfig` 限 16GB / 12 核，swap 8GB |
| GPU | NVIDIA RTX 5060 Laptop，`/dev/dxg` 直通可用 |
| Windows 防火墙 | ⚠️ **三个配置文件（域/专用/公用）全部关闭** —— 见下方「安全」 |

## ⚠️ 网络拓扑：本机用 **NAT + portproxy**，因为 mirrored 在这台机器上起不来

**先记住这条**：`singcore`（星连）只监听 `127.0.0.1:7897`。要让 WSL 用上它，
有两种办法 —— 但**本机只能用第二种**：

| 机器 | 拓扑 | 怎么访问 7897 | 备注 |
|---|---|---|---|
| 旧机（`caixuf2` 笔记本） | **mirrored** | 直接用 `127.0.0.1:7897`（直通宿主） | `.wslconfig` 里 `networkingMode=mirrored` |
| **本机（`caixuf` 台式）** | **NAT + portproxy** | 经网关 IP，如 `172.18.80.1:7898` | ⚠️ 本机 **mirrored 实测总是失败** |

### 🔴 绝对不要给本机加 `networkingMode=mirrored`

**本机开镜像模式总是起不来**（用户实测，2026-10-10 再次确认）。
那些 `netsh interface portproxy` 垫片**正是为此存在** ——
它**不是**「退而求其次的 workaround」，而是**本机的正式设计**。

曾有一轮因为「看到不是 mirrored 就想换成镜像模式、以为 7897 直连更好」差点改
`.wslconfig` —— 那会把本机网络弄坏。**看到 NAT 不要动它。**

**真正的要求只有一条**：`~/.proxy.sh` 的候选端口里，至少有一个**真能出网**。

NAT 模式下 `127.0.0.1` 是 WSL 自己的，所以**必须**经网关 IP 访问宿主端口 ——
**这不是故障**。`~/.proxy.sh` 会把「`127.0.0.1` + 默认网关」两种宿主地址都试一遍，
所以**同一份模板在两种拓扑下都能工作**。

**🔴 别把「不是 mirrored」判为故障**（`apply.sh` 早期版本就是这么误报的）。
以 `proxy_test` / `apply.sh --check` 的**实测出网**为准。
2026-10-10 实测本机：`172.18.80.1:7898` → `github.com` 得 `200`，完全正常，
**不需要**改 `.wslconfig`、更不需要 `wsl --shutdown`。

旧机（`caixuf2` 笔记本）的 `.wslconfig` 参考值 ——
⚠️ **本机不要照抄**：本机要的是**纯 NAT**（`networkingMode` 那行必须不存在）：

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

### 为什么必须做端口转发（而不是让内核自己监听 `0.0.0.0`）

**病根**：`singcore`（星连，sing-box 系）只监听 `127.0.0.1`，
而 NAT 模式下的 WSL 够不着宿主的回环地址。

**Clash 时代的三种修法现在全部失效**：

| 旧招（Clash Verge / mihomo） | 为什么现在不行 |
|---|---|
| 改 `config.yaml` 写 `allow-lan: true` | 星连配置是**加密容器**（`.slp`），改不了 |
| 走命名管道 API 热改（`\\.\pipe\verge-mihomo`） | **没有管道了**，也没有 HTTP API 端口 |
| 改 YAML 里的 `allow-lan` | **连 YAML 都没有** |

程序二进制里确实有 `allowLan` 文案，但**客户端 UI 没有露出这个开关**
（2026-09-26 与用户逐个设置项确认过）。

**⇒ 唯一可行：在 Windows 侧做 `netsh portproxy` 转发，完全不碰星连一根汗毛。**
它更新、重置、换节点、改端口都不影响这条通路。

> 🔴 **别去逆向 / 静态分析第三方软件**（读它的二进制、配置文件、字符串）。
> 用户对这条很敏感，曾当场制止：「你别乱搞啊，攻击人家会被封号的」。
> 要了解某软件行为，**优先让他在 UI 里看，或查官方文档**。

### 端口约定（`~/.proxy.sh` 顶部注释，不可互相改）

**真身只有一个：`7897`。** 其余是 `netsh interface portproxy` 转发到它的**垫片**，
目的是让 **NAT 拓扑**的 WSL 能访问一个只绑 `127.0.0.1` 的代理。

| 端口 | 谁在听 | 用途 | 设计评价 |
|---|---|---|---|
| **7897** | `singcore`（星连 SingLink），**仅 `127.0.0.1`** | **真正的代理** | 真身 |
| 7898 | `svchost`＝portproxy `0.0.0.0:7898 → 127.0.0.1:7897` | NAT 下 WSL 的主入口 | ⚠️ **历史包袱**（见下） |
| 7892 | `svchost`＝portproxy `0.0.0.0:7892 → 127.0.0.1:7897` | 兼容层，兜住写死 7892 的旧配置 | 保留，别删 |
| 7899 | `svchost`＝portproxy `0.0.0.0:7899 → 127.0.0.1:7899` | Clash 的入口（**同名转发**） | ✅ **这才是推荐模式** |

所以「WSL 里该用哪个口」取决于拓扑，**但不是两个并列的代理**：

- **mirrored**：`127.0.0.1` 直通宿主 → 直接用 **`7897`**
- **NAT**：WSL 的 `127.0.0.1` 是自己 → 必须走网关 IP + portproxy 垫片
  （`172.18.80.1:7898` 或 `:7892`，两者最终都到 7897）

**实测（2026-10-10）**：`172.18.80.1:7898` 与 `:7892` 各测 8 轮 204 + github 3 轮 200，
**两个口同样稳定**，不存在「哪个更好」，选哪个都行。
⚠️ 但**不要**因为某次探到 000 就断定某个口坏了 —— 先确认代理软件本身在跑
（曾遇到 singcore 整个没起，四个口同时全 000）。

#### ★ 7899 是「同名转发」，而且它才是**推荐模式**（2026-09-26 实测验证）

Windows 的 portproxy **允许 `0.0.0.0:P` 与 `127.0.0.1:P` 共存** ——
Clash 绑着 `127.0.0.1:7899` 的同时，portproxy 照样能绑上 `0.0.0.0:7899`，
**两条路都通**。所以 `0.0.0.0:7899 → 127.0.0.1:7899` **不是自环 bug**，
而是**故意**做的暴露垫片，端口与软件一一对应。

**⇒ 给代理做对外入口时，优先用同名转发**，不必错开端口。

#### ⚠️ 7898 是历史包袱，不是正统方案

当年因为**凭空推断**「同端口会冲突」，才白白引入了 `7898` 这个错开一位的跳板端口。
**这个推断已被 7899 的实测量推翻**（见上）。

7898 之所以今天还在，是因为现役 `~/.proxy.sh` 的候选列表与环境里写死 7892 的配置
都在用它 —— **别为了「回归正统」去删或改它**，那会打断现役通路。

> 教训：**能实测的结论就别靠推断**，尤其别用推断去给用户增加记忆负担。

#### 7899 的注意事项

它有个副作用：**Clash 没跑时会自环**（connect 目标落在自己的监听范围内，
而 portproxy 本身就在听 `0.0.0.0:7899`），表现为 TCP 能连上、HTTP 挂住。

所以它在候选列表里**排在最后**，免得挡在能用的端口前面白等超时。
`~/.proxy.sh` 的 `_wsl_note` 标它 "Clash"，实测当前该口只有 portproxy 自己在听。

**核验命令**（Windows 侧，怀疑端口归属时先跑这个）：

```powershell
netsh interface portproxy show all
Get-NetTCPConnection -State Listen |
  Where-Object LocalPort -in 7897,7898,7899,7892 |
  ForEach-Object { $p = Get-Process -Id $_.OwningProcess -EA SilentlyContinue
                   "{0}:{1}  {2}" -f $_.LocalAddress, $_.LocalPort, $p.ProcessName }
```

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
4. **清理 Clash 时代遗留**：指向**确实废弃**的端口（`:8118`）的 git URL 分节会被自动清掉。
   ⚠️ 但 `:7892` **不是废弃端口** —— 它是兜住历史配置的**兼容层**（见下条），别一起清掉。
5. **🔴 宿主地址只能用「全局副作用」传出，不能用 `$(...)`**：
   `PROXY_HOST` 是探测函数设置的全局变量。若调用方写成 `chosen="$(detect_port)"`，
   **命令替换会开子 shell，赋值直接丢** → NAT 下得到「端口对了、地址仍是
   `127.0.0.1`」的死 URL（实测过这个 bug）。模板里用 `_proxy_detect`
   直接设置 `PROXY_HOST`/`PROXY_PORT` 来规避。
6. **为什么要有 `7892` 这条兼容层**：换代理软件后，环境里残留了一批**写死旧端口**的
   配置。最典型的是 **Cursor 进程的 `HTTP_PROXY=http://127.0.0.1:7892`**
   （上一代 Clash 的端口）。它会同时搞坏两件事：

   - Cursor 里的 **git 报** `Failed to connect to 172.18.80.1 port 7892`
   - Cursor 自己**拉模型列表失败**，日志反复出现
     `Failed to establish a socket connection to proxies: PROXY 127.0.0.1:7892`

   加一条 `0.0.0.0:7892 → 127.0.0.1:7897` 转发后，这些历史遗留**全部自动复活**，
   不用去逐个挖源头。

   ⚠️ **副作用**：`7892` 转发指向的是**星连**，所以**星连关掉、只开 Clash 时，
   Cursor 会连不上**（git 和模型列表都会挂）。WSL 侧不受影响（会自动切到 7899）。
7. **换代理软件后要清「环境变量里的旧端口」**：实测 Cursor / 部分进程环境里
   残留着上一代端口，导致 git 拉不动、模型列表失败。
   排查入口：`[Environment]::GetEnvironmentVariable('HTTP_PROXY','Process'/'User'/'Machine')`

   ⚠️ **`Process` 作用域只描述当前进程，永远不能代表别的程序。**
   追查这类问题时要**按 PID 读那个进程的 PEB**（工具：`_read_process_env.py`），
   别拿当前 shell 的环境当证据 —— 这么干过一次，一路往 explorer 挖，全错。

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

### 🔴 Windows 侧同一病根：DSH 注入**大小写两套**代理变量 → `Start-Process` 崩溃

> **2026-10-14 实测。** 与上面「幽灵代理」是**同一个病根的两个方向**：
> 那边是 WSL 里写死的小写变量，这边是 **DSH 给每个 Windows 子进程注入两套**。

**现象**：在 DSH 会话里跑任何用 `Start-Process` 的 PowerShell 脚本，会直接抛：

```
已添加项。字典中的关键字:"NO_PROXY"所添加的关键字:"no_proxy"
（Add failed: key "NO_PROXY" already exists ("no_proxy")）
```

**根因（已定位到源码）**：DSH 的 `@deepseek-ai/dsh-http-proxy`（在 `app.asar` 内）
**故意**把每个代理变量**大小写各写一份**。它自己的注释写得很清楚：

> The environment names each policy field owns, **lowercase first** ——
> undici reads the lowercase name first, so **both casings are always written or cleared together**.

它这么做有正当理由：**undici 只认小写，git/curl 等更认大写**，两边都要照顾。

问题出在 **PowerShell 5.1**：它的 Environment 是**大小写不敏感**的字典，
把这两套视为**同一个键的重复项**，于是 `Start-Process` 在重建环境块时**自己撞死**。

**取证方法**（三条互相独立，都指向「DSH 注入、非系统设置」）：

| 证据 | 命令 | 结果 |
|---|---|---|
| 注册表（持久层）只有大写 | `reg query "HKCU\Environment"` | 仅 `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` **三件** |
| 全新进程（非 DSH 子进程）只有大写 | `Invoke-CimMethod Win32_Process -MethodName Create -Arguments @{CommandLine='cmd.exe /c set > out.txt'}` | 同样**只有三件大写** |
| 在 DSH 会话内 | `cmd /c set`（经 DSH 起） | **六个**：三件大写 + 三件小写，另有 `NODE_USE_ENV_PROXY=1` |

⇒ **只有 DSH 的子进程环境里有重复**，所以这不是注册表配错，**没法从系统层根治**。

**修法**（三选一，按场景）：

```powershell
# ① 一次性：把当前会话的重复归一（本仓库已提供脚本，默认只体检）
.\scripts\proxy-fix.ps1            # 体检
.\scripts\proxy-fix.ps1 -Apply     # 归一当前进程
```

> ⚠️ **只对当前进程有效**：新开的会话由 DSH 重新注入，重复会**再次出现**。

```powershell
# ② 脚本里要启动进程：绕开 Start-Process（推荐，最省事）
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe; $psi.UseShellExecute = $true
[void][System.Diagnostics.Process]::Start($psi)
```

> ✅ 实测：`[Diagnostics.Process]::Start()` **不受影响**（它不重建那个字典）。
> 已按此法修掉 `dsh-native-mobile/scripts/restart-and-verify.ps1` 的同一处。

```powershell
# ③ 无法改脚本时：先现算一遍脚本内容再执行
& ([scriptblock]::Create((Get-Content .\x.ps1 -Raw)))
```

> ⚠️ **不要**试图用 `-UseNewEnvironment` 绕过 —— 实测**照样抛同一个异常**。

**排查陷阱**：报错里点名的**不是你看到的第一个**重复对。
它会一路报到最后一个冲突变量才停（本例真凶是 `NO_PROXY`/`no_proxy`，
但删掉 `NO_PROXY` 后**换成** `https_proxy` 报错）。
**所以「删掉报错里那个变量」通常修不好** —— 必须把四族**全部**归一：
`HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY`。

> 💡 **另一个坑（本脚本作者自己踩过）**：`.NET` 的
> `[Environment]::SetEnvironmentVariable('no_proxy', $null, 'Process')`
> 是**大小写不敏感**的 —— 传小写名进去，**实际删掉的可能是大写那个**。
> 所以「删小写、留大写」这种说法**靠不住**；可靠做法是
> **把整族反复删到 .NET 报告为空，再以大写名重设一次**（`proxy-fix.ps1` 就是这么做的）。

### 🔴 git 侧代理：本次「git 代理怪毛病」的结论（**不是配置错，是瞬时的**）

> **2026-10-14 排查结论：不要再给 git 加全局 `http.proxy`。**

起因：当天一次 `git push` 报
`Failed to connect to github.com port 443 via 127.0.0.1 after 6 ms`，
加 `-c http.proxy=http://127.0.0.1:7897` 后立刻成功，表面上像「git 没读到环境变量」。

**但复测推翻了「配置坏了」这个结论**：

| 测法 | 结果 |
|---|---|
| 原样 `git ls-remote`（只靠环境变量）连打 **20 次** | **20/20 成功**，0 失败 |
| `GIT_CURL_VERBOSE=1` 看实际走哪 | `Trying 127.0.0.1:7897` → `CONNECT tunnel established, response 200` |
| **清空**全部 proxy 环境变量后直连 | 5/5 成功（本机**直连 GitHub 也通**） |
| git 自身的 `http.proxy` / `https.proxy` | **都是空** —— 完全靠环境变量，工作正常 |

⇒ **git 本来就正确地走环境变量代理，没问题**。那次失败是**瞬时的**
（`after 6 ms` = TCP 立刻被拒，与 7897 后来实测的 `118ms` 正常握手完全不同，
也不像 7899 那种「连上但挂住」）。

**因此本次的处置是「不改配置」，理由有二**：

1. **加了反而更脆**：`http.proxy` 一旦写死，**代理软件没跑时 git 不会回落直连**
   （实测：把代理指向死端口 `9999`，git 仍按配置走 → 直接失败）。
   而本机**直连 GitHub 实测可用**，不写配置反而多一条活路。
2. **环境变量是最新的**：`HTTPS_PROXY` 由系统/DSH 维护；
   写进 `.gitconfig` 等于把「当前端口」固化，换代理软件或改端口就变成死地址
   （仓库里已有先例：Clash 时代遗留的 `github.com=7892` 死分节，见 `proxy.sh` 的清理逻辑）。

**什么时候才该写 `git config`**：只有确认「**代理必需**（直连必失败）**且环境变量确实读不到**」。
判据（可复现）：

```powershell
# 1) 直连是否可行？（清掉环境变量再试）
foreach($k in 'HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy'){ Remove-Item "Env:$k" -EA SilentlyContinue }
git ls-remote origin HEAD        # 通 → 就不需要写配置
# 2) 环境变量到底有没有被 git 读到
$env:GIT_CURL_VERBOSE='1'; git ls-remote origin HEAD 2>&1 | Select-String 'CONNECT tunnel|Trying'
```

**若真要写**（注意端口要跟着代理软件走，别写死错端口）：

```powershell
git config --global http.proxy  http://127.0.0.1:7897
git config --global https.proxy http://127.0.0.1:7897
# 回滚
git config --global --unset http.proxy
git config --global --unset https.proxy
```

> 📌 本仓 `templates/proxy.sh` 的做法（在 WSL 侧 `_sync_git` 里按探测结果同步
> `http.proxy`）是**对的**：它是**动态探测后再写**，而不是写死。
> 上一条「不要写」针对的是**手工加一个固定值**。

### 🔴 安全：`0.0.0.0` 监听 + 防火墙全关 = 对同网段放开

portproxy 绑的是 `0.0.0.0`，意味着**本机所有网卡都响应**，包括局域网网卡。

而**本机 Windows 防火墙三个配置文件（域 / 专用 / 公用）全部处于关闭状态**，
所以哪怕建了「只放行 `172.16.0.0/12`」（WSL/Hyper-V 私网段）的入站规则，
**此时也不生效** —— 同网段设备理论上可以连上你的代理端口借用出网。

要收紧，二选一：

```powershell
# ① 打开防火墙（推荐，已有规则立刻生效）
netsh advfirewall set allprofiles state on

# ② 或把监听地址收窄到 WSL 网卡（WSL 重启后 IP 会变，需重跑）
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=7898
netsh interface portproxy add v4tov4 listenaddress=172.18.80.1 listenport=7898 connectaddress=127.0.0.1 connectport=7897
```

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
