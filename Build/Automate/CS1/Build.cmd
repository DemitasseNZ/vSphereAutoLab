@echo off
echo *************************
echo *
echo **
echo * Connect to build share
net use B: \\192.168.199.7\Build >> c:\buildlog.txt
type b:\automate\version.txt  >> c:\buildlog.txt
regedit -s b:\Automate\_Common\ExecuPol.reg
regedit -s b:\Automate\_Common\NoSCRNSave.reg
regedit -s B:\Automate\_Common\ExplorerView.reg
regedit -s b:\Automate\_Common\IExplorer.reg
regedit -s b:\Automate\_Common\Nested.reg
REG ADD "HKCU\Environment" /V SEE_MASK_NOZONECHECKS /T REG_SZ /D 1 /F
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /V SEE_MASK_NOZONECHECKS /T REG_SZ /D 1 /F
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments " /V SaveZoneInformation /T REG_DWORD /D 1 /F
echo * Activate Windows >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
copy B:\Automate\PSFunctions.ps1 C:\
copy B:\Automate\%computername%\Build.ps1 c:\
echo * Starting PowerShell script for Phase 2 completion
echo * Starting PowerShell script for Phase 2 completion >> C:\buildlog.txt
powershell c:\Build.ps1
if exist C:\Build.ps1 del c:\Build.ps1