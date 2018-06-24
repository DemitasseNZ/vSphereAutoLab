if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun Build.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}
$a = (Get-Host).UI.RawUI
$a.WindowTitle = "SS Build Automation"
$b = $a.WindowSize
$b.Height = $a.MaxWindowSize.Height - 1
$a.WindowSize = $b
Import-Module C:\windows\system32\WASP.dll
Select-Window -Title "SS Build Automation" | set-windowposition -left 75 -top 3

if (Test-Path "B:\Automate\automate.ini") {
	Write-BuildLog "Determining automate.ini settings."
	$viewinstall = ((Select-String -SimpleMatch "ViewInstall=" -Path "B:\Automate\automate.ini").line).substring(12)
	Write-BuildLog "  VMware View install set to $viewinstall."
	$timezone = ((Select-String -SimpleMatch "TZ=" -Path "B:\Automate\automate.ini").line).substring(3)
	Write-BuildLog "  Timezone set to $timezone."
	tzutil /s "$timezone"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
	$emailto = ((Select-String -SimpleMatch "emailto=" -Path "B:\Automate\automate.ini").line).substring(8)
	$SmtpServer = ((Select-String -SimpleMatch "SmtpServer=" -Path "B:\Automate\automate.ini").line).substring(11)
}
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $False) {
	Write-BuildLog "Joining domain"
	B:\automate\_Common\Autologon administrator lab $AdminPWD
	reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\Build.cmd" /f 
	$password = $AdminPWD | ConvertTo-SecureString -asPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential("administrator",$password)
	$null = Add-Computer -DomainName "lab.local" -Credential $credential -restart
	read-host "Wait for restart"
} else {
	regedit /s b:\Automate\_Common\ExecuPol.reg
	regedit -s b:\Automate\_Common\NoSCRNSave.reg
	Write-BuildLog "Change default local administrator password"
	net user administrator $AdminPWD
	B:\automate\_Common\Autologon administrator lab $AdminPWD
	reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /f
	Write-BuildLog "Setup Firewall"
	netsh advfirewall firewall add rule name="All ICMP V4" dir=in action=allow protocol=icmpv4
	netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
	netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
}
If (([System.Environment]::OSVersion.Version.Major -eq 6) -and ([System.Environment]::OSVersion.Version.Minor -ge 2)) {
	Write-BuildLog "Disabling autorun of ServerManager at logon."
	Start-Process schtasks -ArgumentList ' /Change /TN "\Microsoft\Windows\Server Manager\ServerManager" /DISABLE'  -Wait -Verb RunAs
	Write-BuildLog "Disabling screen saver"
	set-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name ScreenSaveActive -value 0
	Write-BuildLog "Install admin tools"
	Add-WindowsFeature RSAT-Feature-Tools,RSAT-DHCP,RSAT-DNS-Server,RSAT-AD-AdminCenter
	Write-BuildLog "Enable remote management through firewall"
	Netsh firewall set service RemoteAdmin
	Netsh advfirewall set currentprofile settings remotemanagement enable
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
	} 51 {
		Write-BuildLog "Install View 5.1 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	} 52 {
		Write-BuildLog "Install View 5.2 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	} 53 {
		Write-BuildLog "Install View 5.3 Security Server"	
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=SS.external.com VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.20.199 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	} 60 {
		Write-BuildLog "Install View 6.0 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe  -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=https://SS.lab.local:443 VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.199.35 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"'
	} 70 {
		Write-BuildLog "Install View 7.0 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe  -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=https://SS.lab.local:443 VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.199.35 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172"' -verb RunAs
	} 75 {
		Write-BuildLog "Install View 7.5 Security Server"
		copy $Installer C:\ViewInstaller.exe
		Start-Process C:\ViewInstaller.exe  -wait -ArgumentList '/s /v"/qn VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_NAME=cs1.lab.local VDM_SERVER_SS_EXTURL=https://SS.lab.local:443 VDM_SERVER_SS_PWD=VMware1! VDM_SERVER_SS_PCOIP_IPADDR=192.168.199.35 VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172 VDM_IP_PROTOCOL_USAG=IPv4"' -verb RunAs
	}
}

browserAndFlash

Write-BuildLog "Cleanup"
regedit /s b:\Automate\_Common\ExecuPol.reg
regedit -s b:\Automate\_Common\NoSCRNSave.reg
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /f
Write-BuildLog "Install VMware Tools"
b:\VMTools\Setup64.exe /s /v "/qn"
if (([bool]($emailto -as [Net.Mail.MailAddress])) -and ($SmtpServer -ne "none")){
	Write-BuildLog "Emailing log"
	$mailmessage = New-Object system.net.mail.mailmessage
	$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 25) 
	$mailmessage.from = "AutoLab<autolab@labguides.com>"
	$mailmessage.To.add($emailto)
	$Summary = "Completed AutoLab VM build.`r`n"
	$Summary += "The build of $env:computername has finished, installing VMware Tools and rebooting`r`n"
	$Summary += "The build log is attached`r`n"
	$mailmessage.Subject = "$env:computername VM build finished"
	$mailmessage.Body = $Summary
	$attach = new-object Net.Mail.Attachment("C:\buildlog.txt") 
	$mailmessage.Attachments.Add($attach) 
	$SMTPClient.Send($mailmessage)
	$mailmessage.dispose()
	$SMTPClient.dispose()
}
Read-Host "Rebooting after VMTools Install"
