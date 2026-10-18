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

`dsh-lan-bridge-guard.cmd` 顶部有两个**必须按机器改**的量：
`NODE`（DSH 自带 node 的绝对路径）与 `LAN`（`<ip>:<port>`，与上面一致）。

## 注册守护（普通用户即可，无需管理员）

```powershell
# 每 2 分钟检查一次；崩溃后最多 2 分钟内自愈
schtasks /create /tn "DSH-LAN-Bridge-Guard" /tr "C:\path\to\dsh-lan-bridge-guard.cmd" `
  /sc minute /mo 2 /f /rl LIMITED
```

再加一个登录触发（登录即就绪，不用等 2 分钟）。用 `Register-ScheduledTask`
一次建两个触发器更省事，关键设置：`MultipleInstances = IgnoreNew`、
`ExecutionTimeLimit = PT5M`、`Hidden = $true`、`RestartCount = 3`。

> 与 `frpc` 守护（`templates/dsh/frpc-guard.cmd`）同款设计：**幂等**，
> 已在监听就直接 `exit 0`，重复触发不会堆出第二个进程。

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
