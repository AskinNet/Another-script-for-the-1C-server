chcp 1251
@echo off
rem %1 — полный номер версии 1С:Предприятия
rem %2 — первые две цифры номеров портов. Для портов 1540,1541,1560:1591 — это цифра 15
rem %3 — каталог с данными реестра кластера
set SrvUserName=1CServer1@aks.ru
set SrvUserPwd="3JtY97SnCNG5"
set RangePort=%260:%291
set BasePort=%241
set CtrlPort=%240
set SrvcName="1C:Enterprise %CtrlPort% %1"
set BinPath="\"C:\Program Files\1cv8\%1\bin\ragent.exe\" -srvc -agent -regport %BasePort% -port %CtrlPort% -range %RangePort% -d \"%~3\" -debug"
set Desctiption="1С:Сервер 1С:Предприятия. Параметры: %1, %CtrlPort%, %BasePort%, %RangePort%"
if not exist "%~3" mkdir "%~3"
sc stop %SrvcName%
sc delete %SrvcName%
sc create %SrvcName% binPath= %BinPath% start= auto obj= %SrvUserName% password= %SrvUserPwd% displayname= %Desctiption% depend= Dnscache/Tcpip/lanmanworkstation/lanmanserver