@echo off
chcp 1251
rem %1 � ������ ����� ������ 1�:�����������
rem %2 � ������ ��� ����� ������� ������. ��� ������ 1540,1541,1560:1591 � ��� ����� 15
set CtrlPort=%240
set RASPort=%245
set SrvcName="1C:Enterprise RAS(Remote Server %1 %CtrlPort% %RASPort%)"
sc stop %SrvcName%
sc delete %SrvcName%
