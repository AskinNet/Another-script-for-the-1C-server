@echo off
chcp 1251
rem %1 � ������ ����� ������ 1�:�����������
rem %2 � ������ ��� ����� ������� ������. ��� ������ 1540,1541,1560:1591 � ��� ����� 15
set SrvcName="1C:Enterprise %240 %1"
sc stop %SrvcName%
sc delete %SrvcName%