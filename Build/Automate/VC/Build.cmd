@echo off
echo *************************
echo *
echo **
echo * Connect to build share
echo * Connect to build share >> c:\buildlog.txt
net use B: \\192.168.199.7\Build >> c:\buildlog.txt
md c:\temp
type b:\automate\version.txt >> c:\buildlog.txt
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
echo * Activate Windows >> c:\buildlog.txt
cscript //B "%windir%\system32\slmgr.vbs" /ato
echo * Starting PowerShell script for Build
echo * Starting PowerShell script for Build >> C:\buildlog.txt
powershell c:\Build.ps1
if exist C:\Build.ps1 del c:\Build.ps1
if exist C:\Build.cmd del c:\Build.cmd