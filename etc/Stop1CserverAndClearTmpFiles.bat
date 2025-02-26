set LOG_FILE="scripts.log"

set SERVICE_1C_NAME="1C:Enterprise 8.3 Server Agent (x86-64)"

set SERVICE_RAS_NAME="1C:Enterprise 8.3 Remote Server"

set CNTX_PATH="C:\server1c\reg_1541"

set PFL_PATH="C:\ProgramData\1C\1cv8"

set TEMP_PATH="C:\Windows\Temp"

echo stop %DATE% %TIME% >> %TEMP_PATH%\%LOG_FILE%

sc stop %SERVICE_1C_NAME%

sc stop %SERVICE_RAS_NAME%

timeout 5

taskkill /f /im "rphost.exe"

taskkill /f /im "rmngr.exe"

taskkill /f /im "ragent.exe"

taskkill /f /im "ras.exe"

timeout 5

echo done stop %DATE% %TIME% >> %TEMP_PATH%\%LOG_FILE%

echo clean temp %DATE% %TIME% >> %TEMP_PATH%\%LOG_FILE%

DEL /Q /F /S %CNTX_PATH%\snccntx*

DEL /Q /F %PFL_PATH%\*.pfl

DEL /Q /F /S %TEMP_PATH%\*.*

echo done clean temp %DATE% %TIME% >> %TEMP_PATH%\%LOG_FILE%