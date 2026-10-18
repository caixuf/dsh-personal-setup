# templates/dsh/lan-bridge/ — 局域网桥

> **背景**：DSH 0.2.1 起 webserver **硬拒绝 `0.0.0.0`**，而 `dsh-desktop-host`
> 又硬编码 `127.0.0.1`，桌面端因此永远只监听回环。手机 App 配对时记下的是
> `http://<lan-ip>:19387`，于是永远「重连中」。
>
> 本目录的桥在**一块具体网卡**上监听同一端口并转发到回环 —— 不违反通配禁令，
> 也不需要管理员权限（`netsh portproxy` 要提权）。

## 装什么、装到哪

| 文件 | 装到 | 作用 |
|---|---|---|
| `dsh-lan-bridge.mjs` | 任意稳定目录（建议与 `frpc.toml` 同目录） | 桥本体；自动探测局域网 IPv4 |
| `dsh-lan-bridge-guard.cmd` | 同目录 | 守护：不监听就拉起来。**纯 ASCII**，`.cmd` 中文注释会被 cmd 当命令执行 |

## 配置

`dsh-lan-bridge.mjs` 默认自动探测局域网地址；也可显式覆盖：

```powershell
$env:DSH_LAN_BRIDGE_HOST  = '192.168.31.79'   # 监听哪块网卡
$env:DSH_LAN_BRIDGE_PORT  = '19387'           # 与 DSH 同端口、不同地址，不冲突
$env:DSH_LAN_BRIDGE_TARGET= '19387'           # 转发到 DSH webserver
node dsh-lan-bridge.mjs
```

`dsh-lan-bridge-guard.cmd` **没有需要按机器改的量**（2026-10-18 起）：

| 变量 | 来源 |
|---|---|
| `DIR` | `%~dp0` 自定位，脚本放哪都行 |
| `NODE` | 默认按 `%LOCALAPPDATA%\Programs\DeepSeek Harness\...` 取；装了别处就设 `DSH_NODE` |
| `LAN` | 从桥自己写的 `LISTEN=<ip>:<port>` 读回，**不再硬编码** |

> 🔴 **为什么 `LAN` 要绕这一圈**：桥监听哪块网卡是它自己探测的（`detectLanHost`），
> 守护进程没法预先知道。早先的版本写死成某台机器的 `192.168.31.79`，换机后
> `listener` 永远起不来、守护每 2 分钟白跑一次。现在桥启动时打印
> `LISTEN=<ip>:<port>`，守护下次运行读回来做 `netstat` 校验。
>
> 想显式钉死地址仍可设 `DSH_LAN_BRIDGE_HOST` / `DSH_LAN_BRIDGE_PORT`。

## 注册守护（普通用户即可，无需管理员）

🔴 **任务动作必须是 `wscript.exe run-hidden.vbs <guard.cmd>`，不能直接写 `.cmd`。**
计划任务的 `<Hidden>true</Hidden>` 只对传统 conhost 生效；Windows 11 把 console
程序托管进 Windows Terminal（`HKCU\Console\%%Startup` 的 `DelegationTerminal`），
直连 `.cmd` 会**每次弹一个可见的 WT 窗口**。`run-hidden.vbs` 用 wscript（GUI 子系统）
加 `WshShell.Run cmd, 0, True` 才真正隐藏。

```powershell
$vbs = 'C:\path\to\run-hidden.vbs'
$cmd = 'C:\path\to\dsh-lan-bridge-guard.cmd'
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`" `"$cmd`""
Register-ScheduledTask -TaskName 'DSH-LAN-Bridge-Guard' -Action $action `
  -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Settings (...)
```

再加一个 `-Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 2)
-RepetitionDuration ([TimeSpan]::MaxValue)` 的触发器（登录即就绪，不用等 2 分钟）。
关键设置：`MultipleInstances = IgnoreNew`、`ExecutionTimeLimit = PT5M`、
`Hidden = $true`、`RestartCount = 3`。

> 与 `frpc` 守护（`templates/dsh/frpc-guard.cmd`）同款设计：**幂等**，
> 已在监听就直接 `exit 0`，重复触发不会堆出第二个进程。

## 无窗口常驻（`start-hidden.mjs`）

守护脚本内部拉起**常驻进程**时，**不能用 `start "" /min exe`** —— `/min` 只是把
子进程的控制台最小化，窗口依然存在。frpc / 本桥这类常驻进程会因此一直留一个
真窗口在任务栏（`MainWindowHandle` 非 0），这也是「弹窗」报告里最难找的一层。

正确写法（两个守护脚本都已改成这个）：

```bat
"%NODE%" "%HIDE%" --log "%BRIDGELOG%" "%NODE%" "%SCRIPT%"
```

- `start-hidden.mjs` 用 `spawn(..., { windowsHide: true })`（= `CREATE_NO_WINDOW`），
  子进程**根本不创建控制台**；`detached` + `unref` 保留「父退出、子继续跑」。
- `--log <file>` 把子进程 stdout/stderr 写进文件。**不加它子进程输出会被丢弃** ——
  曾经因此在 `.cmd` 里写 `> log 2>&1` 却拿不到 `LISTEN=` 行。

**验证判据（别只看「任务结果 0」）**：

```powershell
(Get-Process frpc).MainWindowHandle                    # 必须 0，不是 0 就有窗口
Get-CimInstance Win32_Process -Filter "Name='conhost.exe'" |
  Where-Object ParentProcessId -eq (Get-Process frpc).Id  # 必须为空（无控制台）
```

## 验证

```powershell
# 1) 局域网地址在监听
Get-NetTCPConnection -State Listen -LocalPort 19387 |
  Select-Object LocalAddress,LocalPort,OwningProcess

# 2) 从本机经局域网地址访问（-NoProxy 必须加，否则会被系统代理污染）
Invoke-WebRequest -Uri 'http://192.168.31.79:19387/mobile-gateway/health' `
  -UseBasicParsing -NoProxy
# 期望：HTTP 200 {"ok":true,"service":"dsh-mobile-gateway",...}
```

手机侧验证（USB 连着时）：

```powershell
adb shell curl -s -m 8 -o /dev/null -w 'HTTP:%{http_code}\n' `
  http://192.168.31.79:19387/mobile-gateway/health
```

## 踩过的坑

- **别改 DSH 的 `host` 配置**去绕过：`dsh-desktop-host` 会用自己的 `--host 127.0.0.1`
  覆盖，改成局域网 IP 的结果是**本机自己也连不上**（ECONNREFUSED）。
- **判断可达性必须 `-NoProxy` / `--noproxy '*'`**：本机全局代理（127.0.0.1:7897）
  会把「连不上」伪装成 502，或把失败掩盖成超时，两个方向都会失真。
- **`.cmd` 必须纯 ASCII**：中文注释被 cmd.exe 按 ANSI 读会**当命令执行**。
