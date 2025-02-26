@echo off

REM MemLimit in bytes!

REM MemLimit is 30 GB

set MemLimit=32985348000000

echo MemLimit is set %MemLimit% bytes

for /f "usebackq tokens=2" %%a in (`tasklist /FO list /FI "IMAGENAME eq rphost.exe" ^| find /i "PID:"`) do (

for /f "usebackq tokens=1" %%c in (`"wmic process where ProcessId=%%a get WorkingSetSize"`) do (

SET "var="&for /f "delims=0123456789" %%i in ("%%c") do set var=%%i

if not defined var (

if /I %%c GTR %MemLimit% (

echo Killing process rphost_%%a with Mem Usage %%c for breaking limit %MemLimit%

taskkill /F /PID %%a

)

)

)

)