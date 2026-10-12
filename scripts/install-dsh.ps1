<#
.SYNOPSIS
    按仓库模板把 DSH profile 的 bundle 全部装上。

.DESCRIPTION
    2026-10-12 实测的关键事实 —— 一条命令干三件事：

        dsh plugin --profile <p> add <pkg>
          1) profile 不存在则自动初始化
          2) pnpm 装包（版本自动解析成实际最新版）
          3) 自动把包名写进 package.json 的 dsh.profile.bundles

    所以「整套装机」= 对模板 dependencies 里每个非 link:/file: 包跑一次 add。
    比在 DSH 里用 plugin_manager 逐个 install_bundle 快一个数量级，
    且可脚本化、可重复、跨机一致。

    ⚠️ 早先文档写「必须用 plugin_manager 逐个装」是误判：
       那次失败的真因是 package.json 里写了无效的 link: 路径，不是命令选错。

    🔴 本脚本必须是 **PowerShell**（不是 bash/WSL）：
       dsh.cmd 是 Windows 批处理，在 WSL 里直接跑会被 bash 当 shell 解析，
       炸成 `@echo: command not found`，**且退出码仍是 0**。

.EXAMPLE
    .\scripts\install-dsh.ps1                 # 装到 profile desktop
    .\scripts\install-dsh.ps1 -Profile mydsh
    .\scripts\install-dsh.ps1 -DryRun         # 只列清单，不真装
#>
[CmdletBinding()]
param(
    [string] $Profile = 'desktop',
    [switch] $DryRun,
    [switch] $SkipBackup
)

$ErrorActionPreference = 'Stop'
$Repo    = Split-Path -Parent $PSScriptRoot
$Template = Join-Path $Repo 'templates\dsh\package.json'

function Say  { param($m) Write-Host "  $m" }
function Hdr  { param($m) Write-Host "`n===== $m =====" }
function Warn { param($m) Write-Host "  ⚠️  $m" -ForegroundColor Yellow }

if (-not (Test-Path $Template)) { throw "模板缺失: $Template" }

# --- 定位 dsh CLI ---
Hdr '环境'
$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if (-not $dsh) {
    $cand = Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd'
    if (Test-Path $cand) { $dsh = $cand } else {
        Warn '找不到 dsh CLI（PATH 里没有，标准安装路径也没有）'
        Warn '请确认已安装 DSH Desktop，或手动在 DSH 里用 plugin_manager 逐个 install_bundle。'
        exit 1
    }
}
Say "dsh CLI : $dsh"
Say "profile : $Profile"
Say "模板    : templates\dsh\package.json"
if ($DryRun) { Say '模式    : -DryRun（不真装）' }

# --- 备份现有 profile ---
$profileDir = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile"
if (-not $SkipBackup -and (Test-Path $profileDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = Join-Path $env:TEMP "dsh-profile-$Profile-$stamp"
    Copy-Item $profileDir $bak -Recurse -Force
    Say "已备份现有 profile → $bak"
}

# --- 读模板 dependencies ---
$tpl = Get-Content $Template -Raw | ConvertFrom-Json
$deps = @($tpl.dependencies.PSObject.Properties)

Hdr '将安装的 bundle'
$toInstall = @(); $skip = 0
foreach ($d in $deps) {
    if ($d.Value -match '^(link|file):') {
        Say "跳过（机器相关，需人工）: $($d.Name)"
        $skip++
    } else {
        Say "  · $($d.Name)"
        $toInstall += $d.Name
    }
}
Say ''
Say "共 $($toInstall.Count) 个待装，跳过 $skip 个机器相关依赖"
if ($toInstall.Count -eq 0) { throw '没有可安装的包 —— 模板 dependencies 是空的？' }

if ($DryRun) { Hdr 'DryRun，未执行任何安装'; exit 0 }

# --- 逐个 add ---
Hdr '安装中'
$ok = 0; $failed = @()

# 🔴 两个坑（2026-10-12 实测踩到）：
#   1) dsh 初始化新 profile 时会往 **stderr** 写 "dsh: initialized profile ..."，
#      在 $ErrorActionPreference='Stop' 下会被 PowerShell 当**致命错误**抛出，
#      导致第一个包就中断。这里临时降级为 Continue 并吞掉输出。
#   2) dsh.cmd 的**退出码不可信**（WSL 场景出现过「炸了却返回 0」），
#      所以成败判定不信退出码，只信「包是否真的进了 dependencies」。
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

foreach ($pkg in $toInstall) {
    Write-Host ("  {0,-52} " -f $pkg) -NoNewline
    & $dsh plugin --profile $Profile add $pkg 2>&1 | Out-Null
    $pf = Join-Path $profileDir 'package.json'
    $landed = $false
    if (Test-Path $pf) {
        $landed = (Get-Content $pf -Raw | ConvertFrom-Json).dependencies.PSObject.Properties.Name -contains $pkg
    }
    if ($landed) { Write-Host '✓'; $ok++ }
    else        { Write-Host '✗'; $failed += $pkg }
}
$ErrorActionPreference = $prevEap

Hdr '结果'
Say "成功 $ok / 失败 $($failed.Count)"
if ($failed.Count -gt 0) {
    Say '失败项：'
    foreach ($p in $failed) { Say "  · $p" }
    Warn '逐个重试，或看 intent\dsh.md 的「两种假失败」判定'
    Warn '（报 failed / not-bundle 但包其实已落盘，只差 bundles 登记 —— 那就手动补登记）'
    exit 1
}

Hdr '下一步'
Say '1. **重启 DSH Desktop** —— 新 bundle 需重启才加载'
Say '2. 桌宠完整性自检（intent\dsh.md，期望 70/51/4）'
Say '3. plugin_manager list_plugins 确认 fiberPhase 全 active'
Say '   ⚠️ active 只代表加载成功，**不代表功能可用** —— 必须实测'
Say "4. 跳过的那 $skip 个 link:/file: 依赖按需人工处理（见 intent\dsh.md）"
