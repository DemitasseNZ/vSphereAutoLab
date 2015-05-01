@echo off
echo **
echo * Building on Windows 2012 R2
echo * Building on Windows 2012 R2 >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
\\nas\build\VMTools\setup64.exe /s /v "/qn"
pause
Exit