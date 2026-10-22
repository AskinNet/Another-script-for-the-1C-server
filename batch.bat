@echo off
rem run from the script folder: oscript.cfg and oscript_modules are resolved relative to it
cd /d "%~dp0"
"C:\Program Files\OneScript\bin\oscript.exe" svc1c.os demo-server.yml batch
