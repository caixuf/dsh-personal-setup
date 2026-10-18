@echo off
REM ============================================================
REM DSH FRP tunnel guard
REM Pure ASCII only (cmd.exe reads ANSI).
REM Starts frpc.exe when it is not running; exits fast otherwise.
REM Safe to run repeatedly (no duplicate instances).
REM ============================================================
setlocal

REM Self-locating: %~dp0 is this script's own directory (trailing backslash),
REM so the same file works on any machine without editing paths.
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
set "EXE=%DIR%\frpc.exe"
set "CFG=%DIR%\frpc.toml"
set "LOG=%DIR%\frpc-guard.log"
set "HIDE=%DIR%\start-hidden.mjs"
REM Node comes from whichever DSH install is present; the fallback is the
REM per-user default location, so an unedited copy still works on a fresh box.
set "NODE=%DSH_NODE%"
if not defined NODE set "NODE=%LOCALAPPDATA%\Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"

if not exist "%EXE%" (
  echo [%DATE% %TIME%] ERROR frpc.exe missing >> "%LOG%"
  exit /b 1
)
if not exist "%CFG%" (
  echo [%DATE% %TIME%] ERROR frpc.toml missing >> "%LOG%"
  exit /b 1
)
if not exist "%NODE%" (
  echo [%DATE% %TIME%] ERROR node.exe missing (set DSH_NODE) >> "%LOG%"
  exit /b 1
)
if not exist "%HIDE%" (
  echo [%DATE% %TIME%] ERROR start-hidden.mjs missing >> "%LOG%"
  exit /b 1
)

REM Already running? nothing to do.
tasklist /FI "IMAGENAME eq frpc.exe" 2>NUL | find /I "frpc.exe" >NUL
if not errorlevel 1 exit /b 0

echo [%DATE% %TIME%] frpc not running, starting >> "%LOG%"
cd /d "%DIR%"
REM Launch with CREATE_NO_WINDOW (windowsHide) so frpc gets NO console at all.
REM `start "" /min` used to leave a real (minimised) console window behind, which
REM flashed on every guard tick and kept a taskbar entry for as long as frpc ran.
"%NODE%" "%HIDE%" "%EXE%" -c "%CFG%" >> "%LOG%" 2>&1

REM Give it a moment, then confirm.
ping -n 5 127.0.0.1 >NUL
tasklist /FI "IMAGENAME eq frpc.exe" 2>NUL | find /I "frpc.exe" >NUL
if errorlevel 1 (
  echo [%DATE% %TIME%] WARN frpc did not stay up >> "%LOG%"
  exit /b 1
)
echo [%DATE% %TIME%] frpc started OK >> "%LOG%"
exit /b 0
