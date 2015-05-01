@echo off
echo **
echo * Connect to build share
net use B: \\192.168.199.7\Build 
type B:\automate\version.txt >> C:\buildlog.txt
echo **
echo * Copy PowerShell files
echo * Copy PowerShell files
copy B:\Automate\validate.ps1 C:\
copy B:\Automate\PSFunctions.ps1 C:\
copy B:\Automate\PXEMenuConfig.ps1 C:\
copy B:\Automate\DC2\Phase2.ps1 C:\
regedit -s B:\Automate\_Common\ExecuPol.reg
regedit -s B:\Automate\_Common\NoSCRNSave.reg
regedit -s B:\Automate\_Common\ExplorerView.reg
regedit -s B:\Automate\_Common\Nested.reg
copy B:\automate\_Common\wasp.dll C:\windows\system32
echo * Activate Windows >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
echo * Starting PowerShell script for Phase 2 completion
echo * Starting PowerShell script for Phase 2 completion >> C:\buildlog.txt
powershell c:\Phase2.ps1
if exist C:\phase2.ps1 del c:\phase2.ps1
if exist c:\phase2.cmd del c:\phase2.cmd