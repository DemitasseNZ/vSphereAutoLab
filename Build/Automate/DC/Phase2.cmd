@echo off
net use B: \\192.168.199.7\Build
ver | find "6.1" > nul
if %ERRORLEVEL% == 0 goto ver_2K8
ver | find "6.2" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "6.3" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
Exit
:ver_2K12
If Exist C:\Windows\SYSVOL\* Goto ver_2K8
echo * Install DHCP and DNS
echo * Install DHCP and DNS >> c:\buildlog.txt
Dism /online /enable-feature /featurename:DHCPServer /quiet
Dism /online /enable-feature /featurename:DHCPServer-Tools /all /quiet
Dism /online /enable-feature /featurename:DNS-Server-Full-Role /quiet
Dism /online /enable-feature /featurename:DNS-Server-Tools /all /quiet
echo * Install AD DC Role
echo * Install AD DC Role >> c:\buildlog.txt
Dism /online /enable-feature /featurename:DirectoryServices-DomainController /all /quiet
Dism /online /enable-feature /featurename:DirectoryServices-AdministrativeCenter /all /quiet
Dism /online /enable-feature /featurename:ActiveDirectory-PowerShell /all /quiet
sc config dhcpserver start= auto
regedit -s B:\Automate\_Common\ExecuPol.reg
regedit -s B:\Automate\_Common\NoSCRNSave.reg
regedit -s B:\Automate\_Common\ExplorerView.reg
regedit -s b:\Automate\_Common\Nested.reg
echo * Promote to DC
echo * Promote to DC >> c:\buildlog.txt
copy \\192.168.199.7\Build\Automate\DC\dcpromo.ps1 c:\
powershell c:\dcpromo.ps1
pause
:ver_2K8
echo **
echo * Connect to build share 
echo * Connect to build share >> c:\buildlog.txt
net use B: \\192.168.199.7\Build 
type B:\automate\version.txt >> C:\buildlog.txt
echo **
echo * Copy PowerShell files
echo * Copy PowerShell files  >> c:\buildlog.txt
copy B:\Automate\validate.ps1 C:\
copy B:\Automate\PSFunctions.ps1 C:\
copy B:\Automate\PXEMenuConfig.ps1 C:\
copy B:\Automate\DC\Phase2.ps1 C:\
regedit -s B:\Automate\_Common\ExecuPol.reg
regedit -s B:\Automate\_Common\NoSCRNSave.reg
regedit -s B:\Automate\_Common\ExplorerView.reg
regedit -s b:\Automate\_Common\Nested.reg
copy B:\automate\_Common\wasp.dll C:\windows\system32
echo * Activate Windows >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
echo * Starting PowerShell script for Phase 2 completion
echo * Starting PowerShell script for Phase 2 completion >> C:\buildlog.txt
powershell c:\Phase2.ps1
if exist C:\phase2.ps1 del c:\phase2.ps1
if exist c:\phase2.cmd del c:\phase2.cmd