if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun Build.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}

if (Test-Path "B:\Automate\automate.ini") {
	Write-BuildLog "Determining automate.ini settings."
	$viewinstall = ((Select-String -SimpleMatch "ViewInstall=" -Path "B:\Automate\automate.ini").line).substring(12)
	Write-BuildLog "  VMware View install set to $viewinstall."
	$timezone = ((Select-String -SimpleMatch "TZ=" -Path "B:\Automate\automate.ini").line).substring(3)
	Write-BuildLog "  Timezone set to $timezone."
	tzutil /s "$timezone"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
}
If (([System.Environment]::OSVersion.Version.Major -eq 6) -and ([System.Environment]::OSVersion.Version.Minor -ge 2)) {
	Write-BuildLog "Disabling autorun of ServerManager at logon."
	Start-Process schtasks -ArgumentList ' /Change /TN "\Microsoft\Windows\Server Manager\ServerManager" /DISABLE'  -Wait -Verb RunAs
	Write-BuildLog "Disabling screen saver"
	set-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name ScreenSaveActive -value 0
}
$Files = get-childitem "b:\view$viewinstall"
for ($i=0; $i -lt $files.Count; $i++) {
	If ($Files[$i].Name -like "VMware-viewconnectionserver*") {$Installer = $Files[$i].FullName}
}
Switch ($ViewInstall) {
	50 {
		Write-BuildLog "Install View 5.0 Security Server"	
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	}	
	51 {
		Write-BuildLog "Install View 5.1 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	}
	52 {
		Write-BuildLog "Install View 5.2 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	}
	53 {
		Write-BuildLog "Install View 5.3 Security Server"	
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	}
	60 {
		Write-BuildLog "Install View 6.0 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe  -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=https://SS.lab.local:443 VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.199.35 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	}
}
Write-BuildLog "Install Flash Player"
Start-Process msiexec -wait -ArgumentList " /i b:\Automate\_Common\install_flash_player_11_active_x.msi /qn"
Write-BuildLog "Setup Firewall"
netsh advfirewall firewall add rule name="All ICMP V4" dir=in action=allow protocol=icmpv4
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
Write-BuildLog "Setup persistet route to other subnet for SRM and View"
route add 192.168.201.0 mask 255.255.255.0 192.168.199.254 -p
Write-BuildLog "Cleanup"
regedit /s b:\Automate\_Common\ExecuPol.reg
regedit -s b:\Automate\_Common\NoSCRNSave.reg
Write-BuildLog "Change default local administrator password"
net user administrator $AdminPWD
B:\automate\_Common\Autologon vi-admin lab $AdminPWD
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /f
Write-BuildLog "Install VMware Tools"
b:\VMTools\Setup64.exe /s /v "/qn"
Read-Host "Rebooting after VMTools Install"
