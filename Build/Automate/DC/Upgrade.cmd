@echo off
cls
echo *
echo * Resetting and upgrading DC configuration
echo * This is a best effort script, there will be error messages and warnings
echo *
echo * VC will require a rebuild
echo *
echo * This script must be "Run as Administrator"
echo *
pause
echo * Running AutoLab Upgrade/Reset script  >> c:\buildlog.txt
if exist C:\validate.ps1 del c:\validate.ps1
if exist C:\PSFunctions.ps1 del c:\PSFunctions.ps1
if exist C:\PXEMenuConfig.ps1 del c:\PXEMenuConfig.ps1
if exist C:\phase2.ps1 del c:\phase2.ps1
net use B: \\192.168.199.7\Build 
copy B:\Automate\validate.ps1 C:\
copy B:\Automate\PSFunctions.ps1 C:\
copy B:\Automate\PXEMenuConfig.ps1 C:\
copy B:\Automate\DC\Phase2.ps1 C:\
powershell c:\Phase2.ps1
if exist C:\phase2.ps1 del c:\phase2.ps1
