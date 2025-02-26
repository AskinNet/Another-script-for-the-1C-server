chcp 1251
powershell.exe -Command "Start-Process cmd \"/k cd /d %cd%\" -Verb RunAs"