@echo off
echo *************************
echo *
echo **
echo * Connect to build share
net use B: \\192.168.199.7\Build >> c:\buildlog.txt
md c:\temp
type b:\automate\version.txt >> c:\buildlog.txt
regedit -s b:\Automate\_Common\ExecuPol.reg
regedit -s b:\Automate\_Common\NoSCRNSave.reg
regedit -s B:\Automate\_Common\ExplorerView.reg
regedit -s b:\Automate\_Common\IExplorer.reg
regedit -s b:\Automate\VC2\vCenterDB.reg
copy b:\automate\_Common\wasp.dll c:\windows\system32
copy B:\Automate\validate.ps1 C:\
copy B:\Automate\PSFunctions.ps1 C:\
copy B:\Automate\VC2\Build.ps1 c:\
echo * Starting PowerShell script for Phase 2 completion
echo * Starting PowerShell script for Phase 2 completion >> C:\buildlog.txt
powershell c:\Build.ps1
rem if exist C:\Build.ps1 del c:\Build.ps1
rem if exist c:\Build.cmd del c:\Build.cmd