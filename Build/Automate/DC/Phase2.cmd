@echo off
echo * Begining Phase2.cmd as %userdomain%\%username%
echo * Begining Phase2.cmd as %userdomain%\%username% >> c:\buildlog.txt
net use B: \\192.168.199.7\Build
ver | find "6.1" > nul
if %ERRORLEVEL% == 0 goto ver_2K8
ver | find "6.2" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "6.3" > nul
if %ERRORLEVEL% == 0 goto ver_2K12
ver | find "10.0" > nul
if %ERRORLEVEL% == 0 goto ver_2K16
Exit
:ver_2K8
echo * Install services on Windows 2008
echo * Install services on Windows 2008 >> c:\buildlog.txt
Dism /online /enable-feature /featurename:DHCPServerCore >> c:\buildlog.txt
Dism /online /enable-feature /featurename:DNS-Server-Full-Role >> c:\buildlog.txt
sc config dhcpserver start= auto >> c:\buildlog.txt
:ver_2K12
:ver_2K16
echo **
echo * Connect to build share 
echo * Connect to build share >> c:\buildlog.txt
net use b: \\192.168.199.7\Build
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
exit
