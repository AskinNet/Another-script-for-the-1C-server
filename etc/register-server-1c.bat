chcp 1251
@echo off
rem %1 � ������ ����� ������ 1�:�����������
rem %2 � ������ ��� ����� ������� ������. ��� ������ 1540,1541,1560:1591 � ��� ����� 15
rem %3 � ������� � ������� ������� ��������
set SrvUserName=1CServer1@aks.ru
set SrvUserPwd="3JtY97SnCNG5"
set RangePort=%260:%291
set BasePort=%241
set CtrlPort=%240
set SrvcName="1C:Enterprise %CtrlPort% %1"
set BinPath="\"C:\Program Files\1cv8\%1\bin\ragent.exe\" -srvc -agent -regport %BasePort% -port %CtrlPort% -range %RangePort% -d \"%~3\" -debug"
set Desctiption="1�:������ 1�:�����������. ���������: %1, %CtrlPort%, %BasePort%, %RangePort%"
if not exist "%~3" mkdir "%~3"
sc stop %SrvcName%
sc delete %SrvcName%
sc create %SrvcName% binPath= %BinPath% start= auto obj= %SrvUserName% password= %SrvUserPwd% displayname= %Desctiption% depend= Dnscache/Tcpip/lanmanworkstation/lanmanserver