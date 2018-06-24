. "C:\PSFunctions.ps1"
Write-BuildLog "Phase2.ps1 waiting ten more minutes for vCentre services to finish starting"
start-sleep 600
Write-BuildLog "Determining automate.ini settings."
$viewinstall = ((Select-String -SimpleMatch "ViewInstall=" -Path "B:\Automate\automate.ini").line).substring(12)
Write-BuildLog "  VMware View install set to $viewinstall."
$vcinstall = "55"
$vcinstall = ((Select-String -SimpleMatch "VCInstall=" -Path "B:\Automate\automate.ini").line).substring(10)
If ($vcinstall -eq "50") {$vcinstall = "5"}
$AutoAddHosts = ((Select-String -SimpleMatch "AutoAddHosts=" -Path "B:\Automate\automate.ini").line).substring(13)
if ($AutoAddHosts -like "true") {
	$AutoAddHosts = $true
	Write-BuildLog "  Hosts will be automatically added to vCenter after build completes."
} else {
	$AutoAddHosts = $false
}
$DeployVUM = $false
if ((((Select-String -SimpleMatch "DeployVUM=" -Path "B:\Automate\automate.ini").line).substring(10)) -like "true") {
	$DeployVUM = $true
	Write-BuildLog "  VUM will be installed."
} else {
	$DeployVUM = $false
	Write-BuildLog "  No VUM."
}
$AdminPWD = "VMware1!"
$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
$emailto = ((Select-String -SimpleMatch "emailto=" -Path "B:\Automate\automate.ini").line).substring(8)
$SmtpServer = ((Select-String -SimpleMatch "SmtpServer=" -Path "B:\Automate\automate.ini").line).substring(11)
$PCLIVernum = "Now PowerCLI"
$PCLIVernum = Get-PowerCLIVersion
Write-BuildLog "Adding Domain Admins to vCenter administrators role and setting PowerCLI $PCLIVernum certificate warning."
If (($vcinstall -eq "67") -or ($vcinstall -eq "65")) {
	$null = connect-viserver vc.lab.local -user administrator@vsphere.local -password VMware1!
	$null = New-VIPermission -Role Admin -Principal 'Administrator' -Entity Datacenters
	$null = Disconnect-VIServer -Server * -confirm:$false
} elseif ($vcinstall -eq "60") {
	$null = connect-viserver vc.lab.local -user administrator@vsphere.local -password VMware1!
	$null = New-VIPermission -Role Admin -Principal 'Administrator' -Entity Datacenters
	$null = Disconnect-VIServer -Server * -confirm:$false
} ElseIf (($vcinstall -eq "55") -or ($vcinstall -eq "51")) {
	$null = connect-viserver vc.lab.local -user vc\administrator -password $AdminPWD
	$null = New-VIPermission -Role Admin -Principal 'Administrators' -Entity Datacenters
	$null = Disconnect-VIServer -Server * -confirm:$false
} Else {
	$null = connect-viserver vc.lab.local -user vc\administrator -password $AdminPWD
	$null = New-VIPermission -Role Admin -Principal 'lab\Domain Admins' -Entity Datacenters
	$null = New-VIPermission -Role Admin -Principal 'Administrator' -Entity Datacenters
	$null = Disconnect-VIServer -Server * -confirm:$false
}
If (($AutoAddHosts -eq "True") -and (Test-Path "c:\Addhosts.ps1")){
	Write-BuildLog "Automatically running AddHosts script."
	Start-Process c:\windows\syswow64\WindowsPowerShell\v1.0\powershell.exe -ArgumentList " C:\AddHosts.ps1" -wait
}
if (Test-Path "C:\VMware-viewcomposer*") {
	$Files = get-childitem "C:\"
	for ($i=0; $i -lt $files.Count; $i++) {
		If ($Files[$i].Name -like "VMware-viewcomposer*") {$Installer = $Files[$i].FullName}
	}
	switch ($viewinstall) {
		75 {
			Write-BuildLog "Installing VMware View 7.5 Composer"
			Start-Process $Installer -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
		} 70 {
			Write-BuildLog "Installing VMware View 7.0 Composer"
			Start-Process $Installer -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
		} 60 {
			Write-BuildLog "Installing VMware View 6.0 Composer"
			Start-Process $Installer -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
		} 53 {
			Write-BuildLog "Installing VMware View 5.3 Composer"
			Start-Process $Installer -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
		} 52 {
			Write-BuildLog "Installing VMware View 5.2 Composer"
			Start-Process $Installer -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
		}
	}
}

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