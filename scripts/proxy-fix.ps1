# proxy-fix.ps1 — 修「代理环境变量大小写重复」引起的 Windows 侧故障
#
# 用法：
#   .\scripts\proxy-fix.ps1            # 只体检，不修改（默认）
#   .\scripts\proxy-fix.ps1 -Apply     # 真修当前进程
#   .\scripts\proxy-fix.ps1 -Check     # 显式体检
#
# ── 这是什么问题 ─────────────────────────────────────────────
# 本机（经 DSH 注入后）进程环境里同时存在**大小写两套**代理变量：
#   HTTP_PROXY / http_proxy
#   HTTPS_PROXY / https_proxy
#   NO_PROXY / no_proxy  (+ 有的机器还有 ALL_PROXY / all_proxy)
#
# 而 **PowerShell 5.1 的 Environment 是大小写不敏感的字典**，它把这两套
# 视为**同一个键的重复项**。后果是 **`Start-Process` 直接抛异常**：
#   已添加项。字典中的关键字:"NO_PROXY"所添加的关键字:"no_proxy"
#
# 注意报错里点名的**不是**你看到的第一个重复对 —— 它会一直报到最后一个
# 冲突变量才停，所以「删掉报错里那个变量」往往修不好。
#
# ── 为什么删小写、保留大写 ────────────────────────────────────
# ① git / curl / node 三种读取方**大小写都认**（本脚本实测）；
# ② 注册表（持久层）里**只有大写**三件套，小写纯粹是运行时注入的；
# ③ 只删小写 = 回到注册表原样，重启后不会复发。
#
# ⚠️ 这是在**当前进程**内修，不写注册表、不动用户环境。要根治请见
#    intent/wsl.md 的「代理变量大小写重复」一节（写进 profile 的一段防护）。
#
# 本脚本必须存成 **带 BOM 的 UTF-8**（PS 5.1 否则按 ANSI 读中文会吞引号）。

[CmdletBinding()]
param(
    [switch] $Apply,
    [switch] $Check
)

$ErrorActionPreference = 'Stop'

# PowerShell 5.1 下 `-Check` 只是显式表达「默认行为」，两者都不给时也走体检。
$doApply = $Apply.IsPresent

function Say  { param($m) Write-Host "  $m" }
function Hdr  { param($m) Write-Host "`n===== $m =====" }
function Good { param($m) Write-Host "  ✅ $m" -ForegroundColor Green }
function Bad  { param($m) Write-Host "  ❌ $m" -ForegroundColor Red }
function Warn { param($m) Write-Host "  ⚠️  $m" -ForegroundColor Yellow }

# 我们关心的变量族（大写为准）。ALL_PROXY 一并处理，它同样会造成重复冲突。
$families = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')

# --- 1. 列出当前进程里的实际变量名（保留大小写）---------------------
Hdr '当前进程的代理环境变量'
$procNames = [Environment]::GetEnvironmentVariables('Process').Keys |
    Where-Object { $_ -match '(?i)^(http|https|all|no)_proxy$' } |
    Sort-Object

if ($procNames.Count -eq 0) {
    Warn '没有任何代理变量（可能没开代理，或本进程拿不到）'
} else {
    foreach ($n in $procNames) {
        Say ("{0,-14} = {1}" -f $n, [Environment]::GetEnvironmentVariable($n, 'Process'))
    }
}

# --- 2. 找出成对的重复（大小写只差）---------------------------------
$dupes = @()
foreach ($up in $families) {
    if ($procNames -contains $up -and $procNames -contains $up.ToLower()) {
        $dupes += $up
    }
}

Hdr '重复检测'
if ($dupes.Count -eq 0) {
    Good '没有大小写重复的代理变量'
} else {
    Bad ("发现 {0} 组重复：{1}" -f $dupes.Count, ($dupes -join ', '))
    Say '  → PowerShell 5.1 的 Start-Process 会因此抛异常（见下）'
}

# --- 3. 实测 Start-Process 是否真的坏了 ------------------------------
Hdr 'Start-Process 可用性实测'
$startProcessOk = $false
$spError = $null
try {
    # 用 cmd.exe 做最小验证：不启动任何真实程序、立即退出
    $p = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
                       -ArgumentList '/c', 'exit 0' `
                       -Wait -PassThru -NoNewWindow -ErrorAction Stop
    $startProcessOk = $true
    Good "Start-Process 可用（退出码 $($p.ExitCode)）"
} catch {
    $spError = $_.Exception.Message
    Bad "Start-Process 不可用：$spError"
    Say '  → 后果：任何用 Start-Process 启动 DSH / 子进程的脚本都会中断'
    Say '    （本机 dsh-native-mobile\scripts\restart-and-verify.ps1 就是这种）'
}

# --- 4. 修：只删小写（回到注册表原样）--------------------------------
if (-not $doApply) {
    Hdr '体检模式（未做任何修改）'
    if ($dupes.Count -gt 0) {
        Say '要修就在**当前 PowerShell 会话**里跑：'
        Say '  .\scripts\proxy-fix.ps1 -Apply'
        Say ''
        Say '⚠️ 修的是「当前进程」；这个会话里之后启动的程序才继承到干净环境。'
        Say '   要根治（新开的每个终端都干净）见 intent/wsl.md 对应小节。'
    }
    exit 0
}

Hdr '执行修复（每族清空后只重设一个大写名）'
if ($dupes.Count -eq 0) {
    Good '本来就无重复，无需修改'
} else {
    # 🔴 不能用「SetEnvironmentVariable(小写名, $null)」来精确删小写 ——
    #    .NET 的 Environment 是**大小写不敏感**的字典，删掉哪一个是它自己
    #    挑的：实测传小写名时被删掉的往往是 `HTTPS_PROXY`（大写那个）。
    #    日志若写「已删除 https_proxy」就是**在骗人**，所以本脚本不留这种含糊话。
    #    可靠做法：把整族**反复删到 .NET 报告为空**，再以**大写名**重设一次。
    #    值优先取大写（注册表那套），没有才回落到小写。
    foreach ($up in $dupes) {
        $val = [Environment]::GetEnvironmentVariable($up, 'Process')
        if ([string]::IsNullOrEmpty($val)) {
            $val = [Environment]::GetEnvironmentVariable($up.ToLower(), 'Process')
        }

        $guard = 0
        while ($guard -lt 10) {
            $live = @([Environment]::GetEnvironmentVariables('Process').Keys |
                Where-Object { $_ -match ('(?i)^' + [regex]::Escape($up) + '$') })
            if ($live.Count -eq 0) { break }
            [Environment]::SetEnvironmentVariable($live[0], $null, 'Process')
            $guard++
        }

        if (-not [string]::IsNullOrEmpty($val)) {
            [Environment]::SetEnvironmentVariable($up, $val, 'Process')
        }
        Say "$up 已归一（清空 $guard 条 → 以大写名重设）"
    }
}

# --- 5. 复验 --------------------------------------------------------
Hdr '复验'
$after = [Environment]::GetEnvironmentVariables('Process').Keys |
    Where-Object { $_ -match '(?i)^(http|https|all|no)_proxy$' } |
    Sort-Object
Say ('剩余代理变量: ' + (($after) -join ', '))

$fixed = $false
try {
    $p2 = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
                        -ArgumentList '/c', 'exit 0' `
                        -Wait -PassThru -NoNewWindow -ErrorAction Stop
    $fixed = $true
    Good "Start-Process 已恢复（退出码 $($p2.ExitCode)）"
} catch {
    Bad "Start-Process 仍不可用：$($_.Exception.Message)"
    Warn '可能还有 ALL_PROXY / 其它大小写对；请把上面「剩余代理变量」贴出来'
}

# --- 6. 顺带确认 git 仍能走代理 -------------------------------------
if ($fixed) {
    Hdr 'git 连通性确认'
    $gitProxy = $env:HTTPS_PROXY
    if ([string]::IsNullOrWhiteSpace($gitProxy)) { $gitProxy = $env:HTTP_PROXY }
    if ([string]::IsNullOrWhiteSpace($gitProxy)) {
        Warn '没有 HTTPS_PROXY/HTTP_PROXY，跳过后端连通性探测'
    } else {
        Say "仍将使用代理: $gitProxy"
        Say '（git / curl / node 三种读取方大小写都认，故归一后不受影响）'
    }
}

Hdr '完成'
Say '注意：修复只作用于**当前进程**。'
Say '新开的终端由 DSH 重新注入，可能再次出现重复 —— 根治方法见 intent/wsl.md。'
exit 0
