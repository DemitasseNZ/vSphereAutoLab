@echo off
echo **
echo * Building on Windows 7
echo * Building on Windows 7 >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
\\192.168.199.7\build\VMTools\setup64.exe /s /v "/qn"
pause
Exit