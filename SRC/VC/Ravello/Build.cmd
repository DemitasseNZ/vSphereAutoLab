@echo off
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
ver | find "6.1" > nul
if %ERRORLEVEL% == 0 goto ver_2K8
ver | find "6.2" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "6.3" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
goto RunBuild
:ver_2K8
goto RunBuild
:ver_2K12
echo **
echo * Building on Windows 2012
echo * Building on Windows 2012 >> c:\buildlog.txt
echo * Set IP address
echo * Set IP address >> c:\buildlog.txt
netsh interface ip set address "Ethernet" static 192.168.199.5 255.255.255.0 192.168.199.2 1
netsh interface ip set dnsservers "Ethernet" static 192.168.199.4 primary
echo * Install .Net 3
echo * Install .Net 3 >> c:\buildlog.txt
Dism /online /enable-feature /featurename:NetFx3ServerFeatures /quiet
Dism /online /enable-feature /featurename:NetFx3 /source:D:\Sources\sxs /quiet
copy \\192.168.199.7\Build\Automate\DC\ocsetup.exe c:\windows\system32\
echo * Install Setup recall of build script
echo * Install Setup recall of build script >> c:\buildlog.txt
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /v Build /t REG_SZ /d "cmd /c c:\Build.cmd" /f  >> c:\buildlog.txt
echo * Mount Install Image
echo * Mount Install Image >> c:\buildlog.txt
mkdir c:\mountdir
If Exist D:\sources\install.wim Dism /mount-wim /WimFile:D:\sources\install.wim /Index:2 /MountDir:c:\mountdir /readonly /quiet
If Exist E:\sources\install.wim Dism /mount-wim /WimFile:E:\sources\install.wim /Index:2 /MountDir:c:\mountdir /readonly /quiet
echo * Install GUI onto Server Core
echo * Install GUI onto Server Core >> c:\buildlog.txt
Dism /online /enable-feature /featurename:server-gui-mgmt /all /source:c:\mountdir\windows\winsxs /quiet /norestart
Dism /online /enable-feature /featurename:server-gui-shell /all /source:c:\mountdir\windows\winsxs /quiet /norestart
Dism /online /enable-feature /featurename:servercore-fullserver /all /source:c:\mountdir\windows\winsxs /quiet /norestart
echo * Install Media Foundation
echo * Install Media Foundation >> c:\buildlog.txt
Dism /online /enable-feature /featurename:ServerMediaFoundation /all /source:c:\mountdir\windows\winsxs /quiet /norestart
echo * Install Desktop Experience
echo * Install Desktop Experience >> c:\buildlog.txt
Dism /online /enable-feature /featurename:DesktopExperience /all /source:c:\mountdir\windows\winsxs /quiet
pause
:RunBuild
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
c:\build.cmd
Exit