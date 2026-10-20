# win-proxy-bypass.ps1 — 体检 / 修复「Windows 系统代理绕过表缺内网网段」
#
# 用法：
#   .\scripts\win-proxy-bypass.ps1                 # 只体检，不修改（默认）
#   .\scripts\win-proxy-bypass.ps1 -Apply          # 幂等补齐缺失的内网网段
#   .\scripts\win-proxy-bypass.ps1 -ProbeUrl http://192.168.137.10:9900/   # 顺带实测
#
# ── 这是什么问题 ──────────────────────────────────────────────
# Windows 上有**三套**「代理绕过表」，各读各的，互不相通：
#   1) WinINET  HKCU\...\Internet Settings\ProxyOverride  ← Chrome / Edge 读它
#   2) WinHTTP  netsh winhttp show proxy                  ← 不少系统服务读它
#   3) 环境变量 no_proxy                                   ← curl / git / gh / node 读它
#
# 代理软件（本机是星连 SingLink）只维护第 1 套，而且它写进去的绕过表
# **只有公司域名**（*.immotors.com 等），**没有内网网段**。
# 于是浏览器把 192.168.x / 10.x 的地址也交给代理，而 sing-core 路由不到私网
# → 浏览器侧表现为 **HTTP 502** 或一直转圈；
# 命令行 curl 却完全正常，因为它读第 3 套（带 192.168.0.0/16）。
#
# 完整内网绕过表的原始出处是 RAS 连接 `fortissl`（Fortinet SSL VPN）里那份
# （localhost;127.*;192.168.*;10.*;172.16.*…172.31.*;<local>）——
# 本脚本按它的口径补齐。
#
# ── 判据（一句话）────────────────────────────────────────────
#   **命令行能通、浏览器 502/超时** → 就是这个病，不是网络坏了。
#
# ── 修法 ─────────────────────────────────────────────────────
# 只改 WinINET 的 ProxyOverride **一个字段**（其余原样保留），补上缺失的
# 内网网段；随后核对 Connections 下的两个 blob 是否被代理软件同步过去
# （实测它会在几秒内自己同步，SavedLegacySettings 是它做恢复的源）。
#
# ⚠️ 改完**必须重启 Chrome / Edge** 才生效：浏览器在启动时缓存系统代理配置。
#
# 本脚本必须存成 **带 BOM 的 UTF-8**（PS 5.1 否则按 ANSI 读中文会吞引号）。

[CmdletBinding()]
param(
    [switch] $Apply,
    [string] $ProbeUrl = ''
)

$ErrorActionPreference = 'Stop'

$IK  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$CON = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'

function Say  { param($m) Write-Host "  $m" }
function Hdr  { param($m) Write-Host "`n===== $m =====" }
function Good { param($m) Write-Host "  ✅ $m" -ForegroundColor Green }
function Bad  { param($m) Write-Host "  ❌ $m" -ForegroundColor Red }
function Warn { param($m) Write-Host "  ⚠️  $m" -ForegroundColor Yellow }

# ── 内网网段覆盖组：组内任一 pattern 出现在绕过表里就算覆盖 ──────────
# 顺序即「缺失时的补入顺序」，所以通配在前、CIDR 在后（少写一个是一个）。
$Groups = @(
    @{ Name = 'localhost';   Patterns = @('localhost', '127.*') }
    @{ Name = '127.0.0.0/8'; Patterns = @('127.*', '127.0.0.0/8') }
    @{ Name = '10.0.0.0/8';  Patterns = @('10.*', '10.0.0.0/8') }
    @{ Name = '172.16.0.0/12'; Patterns = @(
        '172.16.*','172.17.*','172.18.*','172.19.*','172.20.*','172.21.*','172.22.*','172.23.*',
        '172.24.*','172.25.*','172.26.*','172.27.*','172.28.*','172.29.*','172.30.*','172.31.*',
        '172.16.0.0/12') }
    @{ Name = '192.168.0.0/16'; Patterns = @('192.168.*', '192.168.0.0/16') }
    @{ Name = '<local>';      Patterns = @('<local>') }
)

function Get-Entries {
    $v = (Get-ItemProperty $IK -ErrorAction SilentlyContinue).ProxyOverride
    if ([string]::IsNullOrWhiteSpace($v)) { return @() }
    return @($v -split ';' | Where-Object { $_ -ne '' })
}

function Get-Missing {
    param([string[]] $Entries)
    $miss = @()
    foreach ($g in $Groups) {
        $hit = $false
        foreach ($p in $g.Patterns) {
            if ($Entries -contains $p) { $hit = $true; break }
        }
        if (-not $hit) { $miss += [pscustomobject]@{ Group = $g.Name; Add = $g.Patterns[0] } }
    }
    return $miss
}

# ── 1. 体检：三套表并排打印 ─────────────────────────────────────
Hdr '三套代理绕过表（各读各的，互不相通）'

$ie = Get-Entries
$say = (Get-ItemProperty $IK -ErrorAction SilentlyContinue)
Say "① WinINET（Chrome/Edge 读这个）"
Say ("   ProxyEnable   = {0}" -f $say.ProxyEnable)
Say ("   ProxyServer   = {0}" -f $say.ProxyServer)
Say ("   ProxyOverride = {0}" -f $say.ProxyOverride)

Say "② WinHTTP（系统服务读这个）"
$wh = (& netsh winhttp show proxy 2>&1) -join "`n"
$wh | ForEach-Object { Say ("   {0}" -f $_) }

Say "③ 环境变量 no_proxy（curl/git/gh 读这个）"
foreach ($scope in @('User', 'Machine')) {
    $v = [Environment]::GetEnvironmentVariable('no_proxy', $scope)
    if ($v) { Say ("   [{0}] {1}" -f $scope, $v) }
}

# ── 2. 判定内网网段覆盖情况 ─────────────────────────────────────
Hdr '内网网段覆盖判定（只看 ① WinINET）'
$missing = Get-Missing -Entries $ie
if ($missing.Count -eq 0) {
    Good '内网网段全部在绕过表里 ✓'
} else {
    Bad ("缺 {0} 组：{1}" -f $missing.Count, (($missing | ForEach-Object { $_.Group }) -join ', '))
    foreach ($m in $missing) { Say ("   缺 {0,-16} → 建议补 '{1}'" -f $m.Group, $m.Add) }
}

# ── 3. 顺带实测（可选）──────────────────────────────────────────
if ($ProbeUrl) {
    Hdr "实测 $ProbeUrl"
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        & curl.exe -s -o NUL -w '直连      http_code=%{http_code} time=%{time_total}s' `
            --max-time 8 --noproxy '*' $ProbeUrl > $tmp 2>&1
        Say ((Get-Content $tmp -Raw).Trim())
        & curl.exe -s -o NUL -w '经代理    http_code=%{http_code} time=%{time_total}s' `
            --max-time 8 --noproxy '' -x $say.ProxyServer $ProbeUrl > $tmp 2>&1
        Say ((Get-Content $tmp -Raw).Trim())
        Say '判据：直连 200 + 经代理 000/502 ⇒ 浏览器必须绕过代理（就是本脚本要修的病）'
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

# ── 4. 修复 ─────────────────────────────────────────────────────
if (-not $Apply) {
    Hdr '体检模式（未做任何修改）'
    if ($missing.Count -gt 0) {
        Say '要修就在**管理员不需要的普通 PowerShell** 里跑：'
        Say '  .\scripts\win-proxy-bypass.ps1 -Apply'
        Say ''
        Warn '改完必须**重启 Chrome / Edge** 才生效（浏览器启动时缓存系统代理配置）。'
    } else {
        Say '当前无需修复。'
    }
    exit 0
}

Hdr '执行修复（只改 ProxyOverride 一个字段，其余原样保留）'
if ($missing.Count -eq 0) {
    Good '本来就齐，无需修改（幂等）'
} else {
    $add = @($missing | ForEach-Object { $_.Add })
    $new = (@($ie) + $add) -join ';'
    $bak = "$env:LOCALAPPDATA\Temp\ProxyOverride.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Set-Content -Path $bak -Value ((Get-ItemProperty $IK).ProxyOverride) -Encoding UTF8
    Say "旧值已备份: $bak"

    Set-ItemProperty -Path $IK -Name ProxyOverride -Value $new
    Good "已写入: $new"
}

# ── 5. 核对两个 blob 是否被代理软件同步 ─────────────────────────
Hdr '核对 Connections 下的两个 blob（代理软件几秒内会自己同步）'
$deadline = (Get-Date).AddSeconds(15)
$ok = $false
while ((Get-Date) -lt $deadline) {
    $cur = (Get-ItemProperty $IK).ProxyOverride
    $hit = $true
    foreach ($n in @('DefaultConnectionSettings', 'SavedLegacySettings')) {
        $blob = (Get-ItemProperty $CON -ErrorAction SilentlyContinue).$n
        if (-not $blob) { $hit = $false; break }
        $txt = [System.Text.Encoding]::ASCII.GetString($blob)
        if ($txt -notlike "*$cur*") { $hit = $false; break }
    }
    if ($hit) { $ok = $true; break }
    Start-Sleep -Seconds 2
}
if ($ok) {
    Good 'DefaultConnectionSettings / SavedLegacySettings 均已同步 ✓'
} else {
    Warn '两个 blob 尚未同步 —— 代理软件会在下次改写系统代理时带上新值。'
    Say '若要立刻强制同步：在代理软件 UI 里**关一次再开一次「系统代理」开关**。'
}

Hdr '完成'
Say '⚠️ 务必**重启 Chrome / Edge**（或新开一个浏览器进程）才生效。'
Say '   浏览器在启动时缓存系统代理配置，改注册表不会热更新。'
exit 0
