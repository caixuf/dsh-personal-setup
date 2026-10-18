@echo off
REM ============================================================
REM DSH LAN bridge guard  (pure ASCII -- cmd.exe reads ANSI)
REM
REM DSH 0.2.1 binds its webserver to loopback only, so the phone
REM app (paired to http://<lan-ip>:19387) cannot reach it. This
REM guard keeps a TCP bridge alive on the LAN address.
REM
REM Install: copy next to dsh-lan-bridge.mjs, then register with
REM   schtasks /create /tn "DSH-LAN-Bridge-Guard" /tr "<this.cmd>" ^
REM     /sc minute /mo 2 /f /rl LIMITED
REM (a logon trigger is added via Register-ScheduledTask in the
REM  install notes; /sc minute keeps it recovering after a crash)
REM ============================================================
setlocal

set "DIR=%~dp0"
set "DIR=%DIR:~0,-1%"
set "NODE=C:\Users\20247\AppData\Local\Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
set "SCRIPT=%DIR%\dsh-lan-bridge.mjs"
set "LOG=%DIR%\lan-bridge-guard.log"
set "LAN=192.168.31.79:19387"

if not exist "%NODE%" (
  echo [%DATE% %TIME%] ERROR node.exe missing >> "%LOG%"
  exit /b 1
)
if not exist "%SCRIPT%" (
  echo [%DATE% %TIME%] ERROR bridge script missing >> "%LOG%"
  exit /b 1
)

REM Already listening on the LAN address? nothing to do.
netstat -ano | findstr /C:"%LAN%" | findstr /C:"LISTENING" >NUL
if not errorlevel 1 exit /b 0

echo [%DATE% %TIME%] bridge not listening, starting >> "%LOG%"
cd /d "%DIR%"
start "" /min "%NODE%" "%SCRIPT%"

ping -n 4 127.0.0.1 >NUL
netstat -ano | findstr /C:"%LAN%" | findstr /C:"LISTENING" >NUL
if errorlevel 1 (
  echo [%DATE% %TIME%] WARN bridge did not start >> "%LOG%"
  exit /b 1
)
echo [%DATE% %TIME%] bridge started OK >> "%LOG%"
exit /b 0
