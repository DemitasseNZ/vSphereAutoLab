@echo off
echo *************************
echo *
echo * Begining Build.cmd as %userdomain%\%username%
echo * Begining Build.cmd as %userdomain%\%username% >> c:\buildlog.txt
echo * Connect to build share
echo * Connect to build share >> c:\buildlog.txt
if not exist B:\ net use B: \\192.168.199.7\Build
if not exist c:\temp\ md c:\temp
regedit -s b:\Automate\_Common\ExecuPol.reg
regedit -s b:\Automate\_Common\NoSCRNSave.reg
regedit -s B:\Automate\_Common\ExplorerView.reg
regedit -s b:\Automate\_Common\IExplorer.reg
regedit -s b:\Automate\_Common\Nested.reg
copy b:\automate\_Common\wasp.dll c:\windows\system32
copy B:\Automate\validate.ps1 C:\
copy B:\Automate\PSFunctions.ps1 C:\
copy B:\Automate\VC\Build.ps1 c:\
copy B:\Automate\VC\Derek-SSL.ps1 c:\
copy B:\automate\_Common\wasp.dll C:\windows\system32
echo * Activate Windows >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
echo * Starting PowerShell script for Build
echo * Starting PowerShell script for Build >> C:\buildlog.txt
powershell c:\Build.ps1
