' ============================================================
' Hidden launcher for the DSH guard scripts.
'
' Why this exists: Windows 11 hosts a console-subsystem command
' started by Task Scheduler inside Windows Terminal, and the
' task's <Hidden> flag only hides a legacy conhost window - the
' Windows Terminal window still flashes on screen. wscript.exe is
' a GUI-subsystem host, so launching the .cmd through this script
' keeps the console window at SW_HIDE and nothing appears.
'
' Usage: wscript.exe run-hidden.vbs "C:\path\to\script.cmd"
' Pure ASCII only.
' ============================================================
Option Explicit
Dim shell, target, cmd
If WScript.Arguments.Count < 1 Then WScript.Quit 2
target = WScript.Arguments(0)
Set shell = CreateObject("WScript.Shell")
cmd = "cmd.exe /d /c """ & target & """"
shell.Run cmd, 0, True
' ============================================================
' End.
' ============================================================