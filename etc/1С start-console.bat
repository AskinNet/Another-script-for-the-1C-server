﻿@echo off
chcp 1251
rem %1 — полный номер версии 1С:Предприятия

regsvr32 "C:\Program Files\1cv8\%1\bin\radmin.dll" /s
start mmc "C:\Program Files\1cv8\common\1CV8 Servers (x86-64).msc