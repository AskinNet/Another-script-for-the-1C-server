set LOG_FILE="scripts.log"

set SERVICE_1C_NAME="1C:Enterprise 8.3 Server Agent (x86-64)"

set SERVICE_RAS_NAME="1C:Enterprise 8.3 Remote Server"

echo start %DATE% %TIME% >> %TEMP_PATH%\%LOG_FILE%

sc start %SERVICE_1C_NAME%

sc start %SERVICE_ RAS _NAME%

echo done start %DATE% %TIME% >> %TEMP_PATH%\%LOG_FILE%