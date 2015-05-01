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
netsh interface ip set address name="Ethernet" static 192.168.199.35 255.255.255.0 192.168.199.2 1
netsh interface ip set dnsservers name="Ethernet" static address=192.168.199.4 primary
Dism /online /enable-feature /featurename:NetFx3ServerFeatures
Dism /online /enable-feature /featurename:NetFx3 /source:D:\Sources\sxs
copy \\192.168.199.7\Build\Automate\DC\ocsetup.exe c:\windows\system32\
echo * Mount Install Image
echo * Mount Install Image >> c:\buildlog.txt
mkdir c:\mountdir
Dism /mount-wim /WimFile:D:\sources\install.wim /Index:2 /MountDir:c:\mountdir /readonly /quiet
echo * Setup recall of build script
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
type \\192.168.199.7\Build\Automate\version.txt  >> c:\buildlog.txt
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\build.cmd" /f  >> c:\buildlog.txt
echo * Install GUI onto Server Core
echo * Install GUI onto Server Core >> c:\buildlog.txt
Dism /online /enable-feature /featurename:server-gui-shell /all /source:c:\mountdir\windows\winsxs /quiet
Pause
goto RunBuild
:RunBuild
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
c:\build.cmd