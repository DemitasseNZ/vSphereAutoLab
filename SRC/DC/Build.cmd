@echo off
ver | find "6.1" > nul
if %ERRORLEVEL% == 0 goto ver_2K8
ver | find "6.2" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "6.3" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "10." > nul
if %ERRORLEVEL% == 0 goto ver_2K16
Exit
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
netsh interface ip set address "Ethernet" static 192.168.199.4 255.255.255.0 192.168.199.2 1
netsh interface ip set address "Ethernet0" static 192.168.199.4 255.255.255.0 192.168.199.2 1
ping 192.168.199.2
netsh interface ip set dnsservers "Ethernet" static 192.168.199.4 primary
netsh interface ip set dnsservers "Ethernet0" static 192.168.199.4 primary
ping 192.168.199.7 >> c:\buildlog.txt
echo * Setup recall of build script
echo * Setup recall of build script >> c:\buildlog.txt
copy \\192.168.199.7\Build\Automate\DC\Phase2.cmd c:\ >> c:\buildlog.txt
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\Phase2.cmd" /f  >> c:\buildlog.txt
echo * Promote to DC
echo * Promote to DC >> c:\buildlog.txt
copy \\192.168.199.7\Build\Automate\DC\dcpromo.txt c:\dcpromo.txt >> c:\buildlog.txt
dcpromo /answer:c:\dcpromo.txt >> c:\buildlog.txt
exit
:ver_2K12
echo **
echo * Building on Windows 2012 R2
echo * Building on Windows 2012 R2 >> c:\buildlog.txt
goto startBuild
:ver_2K16
echo **
echo * Building on Windows 2016
echo * Building on Windows 2016 >> c:\buildlog.txt
goto startBuild
:startBuild
echo * Set IP address
echo * Set IP address >> c:\buildlog.txt
netsh interface ip set address "Ethernet" static 192.168.199.4 255.255.255.0 192.168.199.2 1
netsh interface ip set address "Ethernet0" static 192.168.199.4 255.255.255.0 192.168.199.2 1
ping 192.168.199.2
netsh interface ip set dnsservers "Ethernet" static 192.168.199.4 primary
netsh interface ip set dnsservers "Ethernet0" static 192.168.199.4 primary
ping 192.168.199.7 >> c:\buildlog.txt
echo * Setup recall of build script
echo * Setup recall of build script >> c:\buildlog.txt
copy \\192.168.199.7\Build\Automate\DC\Phase2.cmd c:\ >> c:\buildlog.txt
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\Phase2.cmd" /f  >> c:\buildlog.txt
#echo * Promote to DC
#echo * Promote to DC >> c:\buildlog.txt
#copy \\192.168.199.7\Build\Automate\DC\dcpromo.ps1 c:\
#pause
#powershell c:\dcpromo.ps1
#pause Installing AD, will reboot after
Exit