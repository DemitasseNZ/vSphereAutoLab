@echo off
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
goto RunBuild
:ver_2K12
:ver_2K16
netsh interface ip set address name="Ethernet" static 192.168.199.34 255.255.255.0 192.168.199.2 1
netsh interface ip set address name="Ethernet0" static 192.168.199.34 255.255.255.0 192.168.199.2 1
ping 192.168.199.2
netsh interface ip set dnsservers name="Ethernet" static address=192.168.199.4 primary
netsh interface ip set dnsservers name="Ethernet0" static address=192.168.199.4 primary
Dism /online /enable-feature /featurename:NetFx3ServerFeatures
Dism /online /enable-feature /featurename:NetFx3 /source:D:\Sources\sxs
copy \\192.168.199.7\Build\Automate\DC\ocsetup.exe c:\windows\system32\
goto RunBuild
:RunBuild
copy \\192.168.199.7\Build\automate\%computername%\Build.cmd c:\
c:\build.cmd