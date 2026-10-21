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
# ⚠️ DryRun 必须是**纯只读**：之前这里没判 $DryRun，
# 于是「只想看看会装什么」也会往 TEMP 里拷一整份 profile（几十 MB），
# 跑几次就把 TEMP 塞满了。审计新机器时 DryRun 会跑很多次，这个必须改。
$profileDir = Join-Path $env:USERPROFILE ".dsh\profiles\$Profile"
if ($DryRun) {
    Say "DryRun：跳过 profile 备份（不写任何文件）"
} elseif (-not $SkipBackup -and (Test-Path $profileDir)) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bak = Join-Path $env:TEMP "dsh-profile-$Profile-$stamp"
    Copy-Item $profileDir $bak -Recurse -Force
    Say "已备份现有 profile → $bak"
}

# --- 读模板 dependencies ---
# ⚠️ 必须显式 -Encoding UTF8：PS 5.1 默认按 ANSI 读 UTF-8 文件，
# 中文会变乱码，且乱码里的替换字符会破坏 JSON 引号配对 → ConvertFrom-Json 直接报错。
$tpl = Get-Content $Template -Raw -Encoding UTF8 | ConvertFrom-Json
$deps = @($tpl.dependencies.PSObject.Properties)

# 自研宿主插件映射（未发 npm，支持同级或工作区源码自动发现与双向同步）
$localSourceMap = @{
    'dsh-mobile-gateway' = @(
        (Join-Path $Repo '..\dsh-native-mobile\packages\dsh-mobile-gateway'),
        (Join-Path $env:USERPROFILE 'Downloads\aiwork\dsh-native-mobile\packages\dsh-mobile-gateway')
    )
    'dsh-rea' = @(
        (Join-Path $Repo '..\dsh-rea'),
        (Join-Path $env:USERPROFILE 'Downloads\aiwork\dsh-rea')
    )
}

Hdr '将安装的 bundle 与插件'
$toInstall = @(); $localInstall = @(); $skip = 0
foreach ($d in $deps) {
    if ($localSourceMap.ContainsKey($d.Name)) {
        $foundSrc = $localSourceMap[$d.Name] | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($foundSrc) {
            Say "  ★ $($d.Name) (自研宿主插件，将从本地源码安装: $foundSrc)"
            $localInstall += @{ Name = $d.Name; Source = $foundSrc }
            continue
        } else {
            Warn "$($d.Name) 未在本地找到源码，若未发布 npm 可能会拉取失败"
        }
    }

    if ($d.Value -match '^(link|file):') {
        Say "跳过（机器相关，需人工）: $($d.Name)"
        $skip++
    } else {
        Say "  · $($d.Name)"
        $toInstall += $d.Name
    }
}
Say ''
Say "共 $($toInstall.Count) 个公共 npm 包待装，$($localInstall.Count) 个本地插件待装，跳过 $skip 个机器相关依赖"
if ($toInstall.Count -eq 0 -and $localInstall.Count -eq 0) { throw '没有可安装的包 —— 模板 dependencies 是空的？' }

if ($DryRun) { Hdr 'DryRun，未执行任何安装'; exit 0 }

# --- 逐个 add 公共 npm 包 ---
Hdr '安装公共 npm bundle'
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
        $landed = (Get-Content $pf -Raw -Encoding UTF8 | ConvertFrom-Json).dependencies.PSObject.Properties.Name -contains $pkg
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

# ===================================================================
# 机器级补丁层：dsh-bot-gateway 等宿主插件挂在这里，不在 profile 里
# ===================================================================
# 为什么必须单独处理（README 原文警告）：
#   DSH Desktop 后端启动失败时会把整个 profiles/ 目录隔离成
#   profiles.broken-<ts> 并重建 —— profile 级补丁会随之丢失；
#   <dsh-home>/cordis.patch.yml（机器级）不受影响，重启后始终生效。
#
# 所以宿主插件要两件事，缺一不可：
#   1) <dsh-home>/cordis.patch.yml 里要有那一行
#   2) <dsh-home>/node_modules/<包>/ 要有一份副本
#      —— 浏览器半边按 <dsh-home>/node_modules/<包>/package.json 解析，
#         只装在 profiles/<name>/node_modules/ 它找不到
Hdr '机器级补丁层（宿主插件）'

$dshHome = Split-Path (Split-Path $profileDir -Parent) -Parent
$machinePatchTpl = Join-Path $Repo 'templates/dsh/cordis.machine-patch.yml'
$machinePatchDst = Join-Path $dshHome 'cordis.patch.yml'
$stamp2 = Get-Date -Format 'yyyyMMdd-HHmmss'

if (Test-Path $machinePatchTpl) {
    if (Test-Path $machinePatchDst) {
        Copy-Item $machinePatchDst "$machinePatchDst.bak-$stamp2"
        Say "已备份现有 $machinePatchDst"
    }
    Copy-Item $machinePatchTpl $machinePatchDst
    Say "✓ 已安装 $machinePatchDst"
} else {
    Warn "模板缺失，跳过机器级 patch: $machinePatchTpl"
}

# ===================================================================
# 自研宿主插件安装（本地源码，不经 npm）
# ===================================================================
# 🔴 为什么必须走这条路（2026-10-13 换机审计发现的真实阻断点）：
#
#   `dsh-mobile-gateway` 与 `dsh-rea` **都没有发布到公共 npm**。
#   如果直接 `dsh plugin add dsh-mobile-gateway`，pnpm 会去 registry 找，
#   得到 `404 Not Found` —— 换一台干净电脑就会在这里卡死。
#
#   而且它们是**宿主插件**（package.json 里没有 `dsh.bundle.patch`），
#   即使装上了，`dsh plugin add` 也会返回 `error.code: not-bundle`
#   （这是形态差异，不是失败，见 intent\dsh.md）。
#
#   所以正确做法（与 dsh-native-mobile/scripts/install-gateway.ps1 同源）：
#     1) 把源码复制到 **两个** node_modules（profile + 机器级），缺一个 fiber 就 failed；
#     2) 用 DSH 自带的 pnpm 在**机器级**那份装运行时依赖（ws / qrcode）；
#     3) 把依赖树复制到 profile 那份，避免两份 lockfile 不一致。
if ($localInstall.Count -gt 0) {
    Hdr '安装自研宿主插件（本地源码）'

    $node = $null
    $pnpm = $null
    $runtimeCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness\resources\runtime')
    )
    # 🔴 2026-10-21 实测修正：pnpm **不在** runtime\pnpm\ 下，而在
    #    runtime\primary-runtime\dependencies\pnpm\bin\pnpm.cjs。
    #    旧路径写错时，`(Test-Path $n) -and (Test-Path $p)` 恒为假 →
    #    $node/$pnpm 双双留 null → 脚本只打印一句「找不到 node/pnpm」，
    #    **运行时依赖（ws / qrcode）根本没装**，自研宿主插件下次启动就缺模块。
    #    ⇒ node 与 pnpm **分开**找，别让其中一个缺失把另一个也带走。
    foreach ($rt in $runtimeCandidates) {
        if (-not $node) {
            foreach ($c in @('primary-runtime\dependencies\node\bin\node.exe', 'node\bin\node.exe')) {
                $n = Join-Path $rt $c
                if (Test-Path $n) { $node = $n; break }
            }
        }
        if (-not $pnpm) {
            foreach ($c in @('primary-runtime\dependencies\pnpm\bin\pnpm.cjs', 'pnpm\bin\pnpm.cjs')) {
                $p = Join-Path $rt $c
                if (Test-Path $p) { $pnpm = $p; break }
            }
        }
    }
    if (-not $node) {
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCmd) { $node = $nodeCmd.Source }
    }

    foreach ($lp in $localInstall) {
        $name = $lp.Name
        $src  = $lp.Source
        $machineTarget = Join-Path $dshHome "node_modules/$name"
        $profileTarget = Join-Path $profileDir "node_modules/$name"

        Write-Host ("  {0,-22} " -f $name) -NoNewline
        foreach ($t in @($machineTarget, $profileTarget)) {
            New-Item -ItemType Directory -Path (Split-Path $t -Parent) -Force | Out-Null
            if (Test-Path $t) { Remove-Item $t -Recurse -Force }
            New-Item -ItemType Directory -Path $t -Force | Out-Null
            Copy-Item -Path (Join-Path $src '*') -Destination $t -Recurse -Force `
                -Exclude 'node_modules', 'test', '.git' -ErrorAction SilentlyContinue
        }
        Write-Host '✓'

        # 运行时依赖装在机器级那份（DSH 浏览器半边按这个路径解析）
        if ($node -and $pnpm) {
            & $node $pnpm install --dir $machineTarget --ignore-workspace `
                --node-linker=hoisted --prod --ignore-scripts 2>&1 | Out-Null
            if (Test-Path (Join-Path $machineTarget 'node_modules')) {
                Copy-Item -Path (Join-Path $machineTarget 'node_modules') `
                    -Destination $profileTarget -Recurse -Force -ErrorAction SilentlyContinue
                Say "  ✓ $name 运行时依赖已安装并同步"
            }
        } else {
            Warn "  ⚠️ 找不到 DSH 自带 node/pnpm，$name 的运行时依赖未安装（需手工处理）"
        }
    }
} else {
    Hdr '安装自研宿主插件（本地源码）'
    Warn '未找到 dsh-mobile-gateway / dsh-rea 的本地源码，跳过'
    Warn '如需这两个插件，请先 clone：'
    Warn '  git clone https://github.com/caixuf/dsh-native-mobile.git'
    Warn '  git clone https://github.com/caixuf/dsh-rea.git'
    Warn '然后重跑本脚本（源码放在同级目录或 Downloads\aiwork\ 下即可自动发现）'
}

# 宿主插件（无 dsh.bundle.patch，挂机器级而非 profile）需要机器级 node_modules 副本。
# 判据：包的 package.json 有 dsh.client 但没有 dsh.bundle。
# 挂载宿主插件：dsh-bot-gateway（npm）+ 上面已本地安装的自研插件。
$hostPlugins = @('dsh-bot-gateway')
foreach ($hp in $hostPlugins) {
    $src = Join-Path $profileDir "node_modules/$hp"
    $dst = Join-Path $dshHome "node_modules/$hp"
    if (-not (Test-Path $src)) { Warn "未装 $hp（profile node_modules 里没有），跳过副本"; continue }
    if (Test-Path $dst) { Say "已存在，保留: $dst"; continue }
    New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
    Copy-Item $src $dst -Recurse -Force
    $n = (Get-ChildItem $dst -Recurse -File -Force -EA SilentlyContinue | Measure-Object).Count
    Say "✓ 已复制 $hp → $dst（$n 个文件）"
}
if ($hostPlugins.Count -eq 0) { Say '（当前无宿主插件，无需机器级 node_modules 副本）' }

Hdr '下一步'
Say '1. **重启 DSH Desktop** —— 新 bundle 需重启才加载'
Say '2. 桌宠完整性自检（intent\dsh.md，期望 70/51/4）'
Say '3. plugin_manager list_plugins 确认 fiberPhase 全 active'
Say '   ⚠️ active 只代表加载成功，**不代表功能可用** —— 必须实测'
Say "4. 跳过的那 $skip 个 link:/file: 依赖按需人工处理（见 intent\dsh.md）"
