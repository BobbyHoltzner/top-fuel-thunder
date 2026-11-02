@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0NHRAX-Telemetry-Fix.ps1" %*
pause
