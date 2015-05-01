@echo off
ver | find "6.1" > nul
if %ERRORLEVEL% == 0 goto ver_2K8
ver | find "6.2" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "6.3" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
Exit
:ver_2K8
echo **
echo * Building on Windows 2008 R2
echo * Building on Windows 2008 R2 >> c:\buildlog.txt
echo * Setup recall of build script
echo * Setup recall of build script >> c:\buildlog.txt
copy \\192.168.199.7\Build\Automate\DC\Phase2.cmd c:\ >> c:\buildlog.txt
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
echo **
echo * Install DHCP
echo * Install DHCP >> c:\buildlog.txt
start /w ocsetup DHCPServer
echo * Enable DHCP
echo * Enable DHCP >> c:\buildlog.txt
sc config dhcpserver start= auto
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\Phase2.cmd" /f  >> c:\buildlog.txt
echo **
echo * Install Active Directory and reboot
copy \\192.168.199.7\Build\Automate\DC\dcpromo.txt c:\ >> c:\buildlog.txt
dcpromo /answer:c:\dcpromo.txt  >> c:\buildlog.txt
Exit
:ver_2K12
echo **
echo * Building on Windows 2012 R2
echo * Building on Windows 2012 R2 >> c:\buildlog.txt
echo * Set IP address
echo * Set IP address >> c:\buildlog.txt
netsh interface ip set address "Ethernet" static 192.168.199.4 255.255.255.0 192.168.199.2 1
netsh interface ip set dnsservers "Ethernet" static 192.168.199.4 primary
echo **
echo * Mount Install Image
echo * Mount Install Image >> c:\buildlog.txt
mkdir c:\mountdir
If Exist D:\sources\install.wim Dism /mount-wim /WimFile:D:\sources\install.wim /Index:2 /MountDir:c:\mountdir /readonly /quiet
If Exist E:\sources\install.wim Dism /mount-wim /WimFile:E:\sources\install.wim /Index:2 /MountDir:c:\mountdir /readonly /quiet
echo * Setup recall of build script
copy \\192.168.199.7\Build\Automate\DC\Phase2.cmd c:\ >> c:\buildlog.txt
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\Phase2.cmd" /f  >> c:\buildlog.txt
echo * Install GUI onto Server Core
echo * Install GUI onto Server Core >> c:\buildlog.txt
Dism /online /enable-feature /featurename:server-gui-mgmt /all /source:c:\mountdir\windows\winsxs /quiet /norestart
Dism /online /enable-feature /featurename:server-gui-shell /all /source:c:\mountdir\windows\winsxs /quiet /norestart
Dism /online /enable-feature /featurename:servercore-fullserver /all /source:c:\mountdir\windows\winsxs /quiet
Exit