@echo off
REM ============================================================
REM DSH FRP tunnel guard  (pure ASCII -- cmd.exe reads ANSI)
REM
REM frpc is NOT a Windows service: it is a plain process started
REM from the Startup folder, so it dies silently. When it is down
REM the public entry (VPS Caddy:2444) has nothing behind it and the
REM phone shows "reconnecting" with no obvious cause.
REM
REM This guard starts frpc when it is not running and exits fast.
REM It is idempotent: repeated triggers never stack processes.
REM
REM Install: register with a 2-minute schedule + a logon trigger.
REM   schtasks /create /tn "DSH-FRP-Tunnel-Guard" /tr "<this.cmd>" ^
REM     /sc minute /mo 2 /f /rl LIMITED
REM ============================================================
setlocal

set "DIR=%~dp0"
set "DIR=%DIR:~0,-1%"
set "EXE=%DIR%\frpc.exe"
set "CFG=%DIR%\frpc.toml"
set "LOG=%DIR%\frpc-guard.log"

if not exist "%EXE%" (
  echo [%DATE% %TIME%] ERROR frpc.exe missing >> "%LOG%"
  exit /b 1
)
if not exist "%CFG%" (
  echo [%DATE% %TIME%] ERROR frpc.toml missing >> "%LOG%"
  exit /b 1
)

REM Already running? nothing to do.
tasklist /FI "IMAGENAME eq frpc.exe" 2>NUL | find /I "frpc.exe" >NUL
if not errorlevel 1 exit /b 0

echo [%DATE% %TIME%] frpc not running, starting >> "%LOG%"
cd /d "%DIR%"
start "" /min "%EXE%" -c "%CFG%"

REM Give it a moment, then confirm it stayed up.
ping -n 5 127.0.0.1 >NUL
tasklist /FI "IMAGENAME eq frpc.exe" 2>NUL | find /I "frpc.exe" >NUL
if errorlevel 1 (
  echo [%DATE% %TIME%] WARN frpc did not stay up >> "%LOG%"
  exit /b 1
)
echo [%DATE% %TIME%] frpc started OK >> "%LOG%"
exit /b 0
