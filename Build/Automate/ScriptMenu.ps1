#PowerShell menu on VC rather than lots of scripts on desktop
#
# Version 0.8
#
#
. "C:\PSFunctions.ps1"
clear-host
$choices = ("Validate this server's build","Open build log","Add ESXi Hosts to vCenter and configure cluster","Activate Windows", "Launch Derek Seamans SSL Script", "Shutdown Lab servers")
While ($True) {
	$sel = SelectFromList $choices " AutoLab script Launcher"
	clear-host
	Switch ($sel)
		{
			0 {Start-Process PowerShell.exe -Verb Runas -ArgumentList " c:\validate.ps1"}
			1 {Invoke-Expression "C:\BuildLog.txt"}
			2 {Start-Process c:\windows\syswow64\WindowsPowerShell\v1.0\powershell.exe -ArgumentList " C:\AddHosts.ps1"}
			3 {Start-Process cscript.exe -Verb Runas -ArgumentList " c:\windows\system32\slmgr.vbs  /ato"}
			4 {Start-Process c:\windows\syswow64\WindowsPowerShell\v1.0\powershell.exe -ArgumentList " -noexit c:\Derek-SSL.ps1" -Verg RunAs}
			5 {Invoke-Expression "C:\ShutLab.ps1"}
		}
	}
