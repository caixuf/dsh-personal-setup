@echo off
REM ============================================================
REM DSH LAN bridge guard
REM Pure ASCII only (cmd.exe reads ANSI).
REM DSH 0.2.1 binds the webserver to loopback only, so the phone
REM app (paired to http://<lan-ip>:19387) cannot reach it.
REM This guard keeps a TCP bridge alive on the LAN address.
REM ============================================================
setlocal

REM Self-locating: %~dp0 is this script's own directory (trailing backslash).
set "DIR=%~dp0"
if "%DIR:~-1%"=="\" set "DIR=%DIR:~0,-1%"
REM Node comes from whichever DSH install is present; DSH_NODE overrides.
set "NODE=%DSH_NODE%"
if not defined NODE set "NODE=%LOCALAPPDATA%\Programs\DeepSeek Harness\resources\runtime\primary-runtime\dependencies\node\bin\node.exe"
set "SCRIPT=%DIR%\dsh-lan-bridge.mjs"
set "LOG=%DIR%\lan-bridge-guard.log"
set "BRIDGELOG=%DIR%\lan-bridge.log"
set "HIDE=%DIR%\start-hidden.mjs"

REM Which LAN address is this machine on? The bridge derives it (see
REM detectLanHost in dsh-lan-bridge.mjs) and prints "LISTEN=<ip>:<port>";
REM we read the last one it wrote instead of hardcoding another machine's IP.
set "LAN="
if exist "%BRIDGELOG%" for /f "tokens=2 delims==" %%A in ('findstr /C:"LISTEN=" "%BRIDGELOG%" 2^>NUL') do set "LAN=%%A"
if defined DSH_LAN_BRIDGE_HOST set "LAN=%DSH_LAN_BRIDGE_HOST%:%DSH_LAN_BRIDGE_PORT%"


if not exist "%NODE%" (
  echo [%DATE% %TIME%] ERROR node.exe missing >> "%LOG%"
  exit /b 1
)
if not exist "%SCRIPT%" (
  echo [%DATE% %TIME%] ERROR bridge script missing >> "%LOG%"
  exit /b 1
)

REM Already listening on the LAN address? nothing to do.
REM Guard the empty case: `findstr /C:""` matches everything, which would make
REM this check always "pass" and the bridge never start.
if defined LAN (
  netstat -ano | findstr /C:"%LAN%" | findstr /C:"LISTENING" >NUL
  if not errorlevel 1 exit /b 0
)

echo [%DATE% %TIME%] bridge not listening, starting >> "%LOG%"
cd /d "%DIR%"
REM Launch with CREATE_NO_WINDOW (windowsHide) so the bridge gets NO console at all.
REM `start "" /min` left a real (minimised) console window behind.
REM --log is what actually captures the bridge's stdout here: this launcher
REM spawns with stdio 'ignore' by default, so a > redirect in this .cmd would
REM have nowhere to go (that was the bug: LISTEN= was thrown away).
"%NODE%" "%HIDE%" --log "%BRIDGELOG%" "%NODE%" "%SCRIPT%"

ping -n 4 127.0.0.1 >NUL
REM Re-derive the address from the fresh bridge log, then confirm it listens.
set "LAN="
for /f "tokens=2 delims==" %%A in ('findstr /C:"LISTEN=" "%BRIDGELOG%" 2^>NUL') do set "LAN=%%A"
if defined DSH_LAN_BRIDGE_HOST set "LAN=%DSH_LAN_BRIDGE_HOST%:%DSH_LAN_BRIDGE_PORT%"
if not defined LAN (
  echo [%DATE% %TIME%] WARN bridge printed no LISTEN= address >> "%LOG%"
  exit /b 1
)
netstat -ano | findstr /C:"%LAN%" | findstr /C:"LISTENING" >NUL
if errorlevel 1 (
  echo [%DATE% %TIME%] WARN bridge did not start on %LAN% >> "%LOG%"
  exit /b 1
)
echo [%DATE% %TIME%] bridge started OK on %LAN% >> "%LOG%"
exit /b 0
