@echo off
chcp 1251
rem %1 Ч полный номер версии 1—:ѕредпри€ти€
rem %2 Ч первые две цифры номеров портов. ƒл€ портов 1540,1541,1560:1591 Ч это цифра 15
set CtrlPort=%240
set RASPort=%245
set SrvcName="1C:Enterprise RAS(Remote Server %1 %CtrlPort% %RASPort%)"
sc stop %SrvcName%
sc delete %SrvcName%
