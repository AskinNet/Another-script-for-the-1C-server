@echo off
chcp 1251
rem %1 - полный номер версии 1С:Предприятия
rem %2 — первые две цифры номеров портов. Для портов 1540,1541,1560:1591 — это цифра 15

set SrvUserName=1CServer1@aks.ru
set SrvUserPwd="3JtY97SnCNG5"
set CtrlPort=%240
set AgentName=localhost
set RASPort=%245
set SrvcName="1C:Enterprise RAS(Remote Server %1 %CtrlPort% %RASPort%)"
set BinPath="\"C:\Program Files\1cv8\%1\bin\ras.exe\" cluster --service --port=%RASPort% %AgentName%:%CtrlPort%"
set Desctiption="1C:RAS (1C:Enterprise 8.3 Remote Server) %1 %CtrlPort% RASPort%"
sc stop %SrvcName%
sc delete %SrvcName%
sc create %SrvcName% binPath= %BinPath% start= auto obj= %SrvUserName% password= %SrvUserPwd% displayname= %Desctiption%