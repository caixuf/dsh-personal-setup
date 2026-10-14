---
name: pwsh-windows-ops
description: "在本机 Windows 上用 pwsh 工具执行命令的操作手册：先确认跑的是 PS7 还是 PS 5.1、编码/中文/JSON 怎么写才不乱码、大文件下载怎么绕过代理掐断、危险命令的确认顺序。当要在本机跑 PowerShell 脚本、读写含中文的配置文件、下载大文件、或排查 pwsh 输出为空/乱码/参数报错时使用。Triggers: powershell, pwsh, 编码, 乱码, gb2312, UTF-8, ConvertFrom-Json, 中文, 下载, curl, Invoke-WebRequest, 沙箱, ExitCode, pwsh tool."
---

# Windows pwsh 操作手册

## 为什么存在

本机反复在 PowerShell 上翻车，全是**同一批坑**（均为实测，非推测）：

1. `Get-Content -Raw` 读 UTF-8 的 JSON → 中文变 `鑰佺尗浜?` → `ConvertFrom-Json` 报"传入的对象无效"。**根因：PS 5.1 的 `[System.Text.Encoding]::Default` 是 gb2312。**
2. `if (Test-Path $p -and ...)` → 报"找不到与参数名称'and'匹配的参数"。**根因：`-and` 被当成 cmdlet 参数。**
3. 大文件（>2MB）经本机代理下载 → "基础连接已经关闭: 发送时发生错误"。
4. `curl.exe -o /dev/null` → `curl: (23) client returned ERROR on write`。

**先确认版本，再写命令**，能免掉一大半。

## 第一步：永远先确认 shell 版本

```powershell
$PSVersionTable.PSVersion.ToString(); $PSVersionTable.PSEdition
[System.Text.Encoding]::Default.WebName   # ← 关键
```

| 看到 | 含义 | 对策 |
|---|---|---|
| `7.x` + `Core` + `utf-8` | PS7，正常 | 直接用 |
| `5.1` + `Desktop` + **`gb2312`** | PS 5.1 | **所有读文件必须显式指定编码** |

> **已知环境事实**：PS7 已装在 `C:\Program Files\PowerShell\7\pwsh.exe`（7.6.6）。
> DSH 的 `pwsh` 工具在**进程启动时**解析一次可执行文件并缓存；若 PS7 是在 DSH 启动**之后**才装好的，工具本轮仍会跑 5.1，**重启 DSH 后自动切到 PS7**。
> 解析优先级：显式 `pwshPath` → `%ProgramFiles%\PowerShell\7\pwsh.exe` → PATH → 5.1 兜底。

## 编码：PS 5.1 下的唯一正确写法

### 读文件（读 JSON/配置/含中文文本）

```powershell
# ✅ 正确：显式 UTF-8，绕开 gb2312 默认
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$cfg  = $text | ConvertFrom-Json

# ❌ 错误：PS 5.1 下会按 gb2312 解码 → 中文乱码 → JSON 解析失败
$cfg = Get-Content $path -Raw | ConvertFrom-Json
```

要逐行读：`Get-Content $path -Encoding UTF8`。

### 写文件

```powershell
# 无 BOM 的 UTF-8（写给程序解析的 JSON 用这个）
[System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
# 带 BOM（给人看的 .ps1 用这个，PS 5.1 也能正确读）
Set-Content -Path $path -Value $body -Encoding UTF8
```

### 判断"乱码"是文件坏了还是显示坏了

控制台报错里的中文乱码**不等于文件损坏**。必须用独立证据判定：

```powershell
$bytes = [System.IO.File]::ReadAllBytes($path)
($bytes[0..15] | ForEach-Object { $_.ToString('X2') }) -join ' '   # 看首字节 / BOM
[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) # 正确解码再判断
```

**别用 PowerShell 的控制台渲染结果当"文件已损坏"的证据。**

### 沙箱模式差异（重要）

- `read-only` 模式 = **ConstrainedLanguage**：`[System.IO.*]::`、`[math]::`、`Add-Type`、COM、反射**全部失败**（报 "only core types"）。此时只用 cmdlet 和核心类型（`[string]`、`[datetime]`、`[regex]`、`[guid]`）。
- `workspace-write` / `danger-full-access` = FullLanguage，上述都能用。

## 语法坑（PS 5.1 特有）

```powershell
# ❌ -and 被解析成 Test-Path 的参数
if (Test-Path $p -and $q) { }

# ✅ 拆开
if ((Test-Path $p) -and (Test-Path $q)) { }
```

- 不能用自动变量名（大小写不敏感）：`$home`、`$pid`、`$host`、`$error` 等都是只读的。要自定义就换名。
- 本机把 Windows 强杀报告为**退出码 1 且无信号标记**；看到裸 exit 1 在中断之后，按"被终止"理解，不要当成命令逻辑失败。

## 调外部程序：一律落盘再读

**不要用管道捕获外部 exe 的输出**——本机实测 `curl.exe -o /dev/null` 直接报错，嵌套 `-Command` 的回显也会丢。

```powershell
$out = "$env:TEMP\out.txt"
& some.exe args > $out 2>&1
Write-Host "exit=$LASTEXITCODE"
Get-Content $out -Encoding UTF8
```

## 大文件下载：必须分片（本机环境硬约束）

**本机活动代理（SingLink 7897）会掐断持续性大传输**（>2MB 大概率 "基础连接已经关闭"）。全量下载 20MB+ 必然失败。

```powershell
$proxy = 'http://127.0.0.1:7897'
$url   = '<直链>'
$total = 67644330          # 从 release API 的 size 字段拿
$chunk = 2MB
$scratch = "$env:TEMP\dl"
New-Item -ItemType Directory -Force -Path $scratch | Out-Null

$n = [math]::Ceiling($total / $chunk)
for ($i = 0; $i -lt $n; $i++) {
  $start = $i * $chunk
  $end   = [math]::Min($start + $chunk - 1, $total - 1)
  $part  = "$scratch\part_{0:D3}.bin" -f $i
  & curl.exe -sS -L --max-time 60 -x $proxy -r "${start}-${end}" -o $part $url 2>&1 | Out-Null
}

# 用 FileStream 字节级拼接（不要用 Get-Content -AsByteStream）
$fs = [System.IO.File]::Create("$scratch\final.zip")
try {
  for ($i = 0; $i -lt $n; $i++) {
    $b = [System.IO.File]::ReadAllBytes(("{0}\part_{1:D3}.bin" -f $scratch, $i))
    $fs.Write($b, 0, $b.Length)
  }
} finally { $fs.Close() }

# 必须校验：大小 + SHA-256（哈希从 GitHub release API 的 digest 字段拿）
(Get-Item "$scratch\final.zip").Length -eq $total
(Get-FileHash -Algorithm SHA256 "$scratch\final.zip").Hash.ToLower()
```

- **只校验大小不够**，必须比对 SHA-256。
- 查 GitHub release 用 API，别去抓网页；`/releases/latest` 对 **pre-release 返回 404**，要用 `/releases?per_page=5`。

## 动手前

- **改前先备份**：把目标文件复制到 `_backup_<时间戳>\`，不要直接覆盖。
- **删除/移动前**先打印解析后的绝对路径并确认，再执行。
- **改动系统级状态后做闭环验证**：例如改代理设置后，用与浏览器同源的路径实测（`.NET` 的 `[System.Net.WebRequest]::GetSystemWebProxy()` 读的就是注册表系统代理，比 `curl` 更接近浏览器行为；`curl` 会读 `http_proxy` 环境变量，**测"真直连"必须加 `--noproxy '*'`**）。
- 用户说"能跑的配置别动"时：**只改需要改的那一个字段**，其余原样保留，并在汇报里明确列出"改了哪个、没动哪些"。

## 汇报模板

```
结论：<VERIFIED | FIX_READY | NEEDS_MORE_EVIDENCE | BLOCKED_BY_ENVIRONMENT | DISPROVEN>
observed: <命令> → <原始输出>
改动范围：<只改了 X；未动 Y、Z>
未验证：<明确列出>
```
