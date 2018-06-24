@echo off
echo * Starting build.cmd
echo * Starting build.cmd >> c:\buildlog.txt
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
ver | find "6.1" > nul
if %ERRORLEVEL% == 0 goto ver_2K8
ver | find "6.2" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "6.3" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "10.0" > nul
if %ERRORLEVEL% == 0 goto ver_2K16
goto RunBuild
:ver_2K8
echo **
echo * Building on Windows 2008 core
echo * Building on Windows 2008 core >> c:\buildlog.txt
DISM.exe /online /enable-feature /featurename:NetFx2-ServerCore >> c:\buildlog.txt
DISM.exe /online /enable-feature /featurename:NetFx3-ServerCore >> c:\buildlog.txt
DISM.exe /online /enable-feature /featurename:NetFx2-ServerCore-WOW64 >> c:\buildlog.txt
DISM.exe /online /enable-feature /featurename:NetFx3-ServerCore-WOW64 >> c:\buildlog.txt
DISM.exe /online /enable-feature /featurename:MicrosoftWindowsPowerShell >> c:\buildlog.txt
DISM.exe /online /enable-feature /featurename:MicrosoftWindowsPowerShell-WOW64 >> c:\buildlog.txt
echo * Set IP address
echo * Set IP address >> c:\buildlog.txt
netsh interface ip set address "Ethernet" static 192.168.199.5 255.255.255.0 192.168.199.2 1
netsh interface ip set address "Ethernet0" static 192.168.199.5 255.255.255.0 192.168.199.2 1
ping 192.168.199.2
netsh interface ip set dnsservers "Ethernet" static 192.168.199.4 primary
netsh interface ip set dnsservers "Ethernet0" static 192.168.199.4 primary
echo * Install .Net 3
echo * Install .Net 3 >> c:\buildlog.txt
Dism /online /enable-feature /featurename:NetFx3ServerFeatures /quiet
Dism /online /enable-feature /featurename:NetFx3 /source:D:\Sources\sxs /quiet
copy \\192.168.199.7\Build\Automate\DC\ocsetup.exe c:\windows\system32\
echo * Install Setup recall of build script
echo * Install Setup recall of build script >> c:\buildlog.txt
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /v Build /t REG_SZ /d "cmd /c c:\Build.cmd" /f  >> c:\buildlog.txt
shutdown -r -t 1
exit
:ver_2K12
echo **
echo * Building on Windows 2012
echo * Building on Windows 2012 >> c:\buildlog.txt
goto StartBuild
:ver_2K16
echo **
echo * Building on Windows 2012
echo * Building on Windows 2012 >> c:\buildlog.txt
goto StartBuild
:StartBuild
echo * Set IP address
echo * Set IP address >> c:\buildlog.txt
netsh interface ip set address "Ethernet" static 192.168.199.5 255.255.255.0 192.168.199.2 1
netsh interface ip set address "Ethernet0" static 192.168.199.5 255.255.255.0 192.168.199.2 1
ping 192.168.199.2
netsh interface ip set dnsservers "Ethernet" static 192.168.199.4 primary
netsh interface ip set dnsservers "Ethernet0" static 192.168.199.4 primary
echo * Install .Net 3
echo * Install .Net 3 >> c:\buildlog.txt
Dism /online /enable-feature /featurename:NetFx3ServerFeatures /quiet
Dism /online /enable-feature /featurename:NetFx3 /source:D:\Sources\sxs /quiet
copy \\192.168.199.7\Build\Automate\DC\ocsetup.exe c:\windows\system32\
echo * Install Setup recall of build script
echo * Install Setup recall of build script >> c:\buildlog.txt
goto RunBuild
:RunBuild
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
c:\build.cmd
Exit