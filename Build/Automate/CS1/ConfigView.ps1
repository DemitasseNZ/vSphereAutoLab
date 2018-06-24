If (-Not(Test-Path -path "b:\")) { net use B: \\192.168.199.7\Build}
. "C:\PSFunctions.ps1"

$userID = "vi-admin@lab.local"
$VCHost = 'vc.lab.local'
$url = 'https://' + $VCHost
$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
$secpasswd = ConvertTo-SecureString $AdminPWD -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($userID, $secpasswd)
$emailto = ((Select-String -SimpleMatch "emailto=" -Path "B:\Automate\automate.ini").line).substring(8)
$SmtpServer = ((Select-String -SimpleMatch "SmtpServer=" -Path "B:\Automate\automate.ini").line).substring(11)
write-BuildLog "Make sure there are no installs underway"
do {
	start-sleep 10
} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
write-BuildLog "Waiting two minutes for View services to settle"
Write-Host "You can start building CS2 at this stage"
start-sleep 120

function Get-MapEntry {
  param([Parameter(Mandatory = $true)] $Key, [Parameter(Mandatory = $true)] $Value)
  $update = New-Object VMware.Hv.MapEntry
  $update.key = $key
  $update.value = $value
  return $update
}

# This script part modified from https://www.sddcmaster.com/2018/02/horizon-view-automation-with-powershell.html

Write-BuildLog "Add VC certificates to local certificate stores"
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Uri] $u = New-Object System.Uri($url)
[Net.ServicePoint] $sp = [Net.ServicePointManager]::FindServicePoint($u);
[System.Guid] $groupName = [System.Guid]::NewGuid()
[Net.HttpWebRequest] $req = [Net.WebRequest]::create($url)
$req.Method = "GET"
$req.Timeout = 600000 # = 10 minutes
$req.ConnectionGroupName = $groupName
[Net.HttpWebResponse] $result = $req.GetResponse()
$null = $sp.CloseConnectionGroup($groupName)
$outfilename = "Export.cer"
[System.Byte[]] $data = $sp.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes($outfilename, $data)
$null = Import-Certificate -FilePath "Export.cer" -CertStoreLocation Cert:\LocalMachine\Root
$null = Import-Certificate -FilePath "Export.cer" -CertStoreLocation Cert:\LocalMachine\CA
$null = Import-Certificate -FilePath "Export.cer" -CertStoreLocation Cert:\LocalMachine\My
$null = Import-Certificate -FilePath "Export.cer" -CertStoreLocation Cert:\LocalMachine\AuthRoot
$null = Import-Certificate -FilePath "Export.cer" -CertStoreLocation Cert:\LocalMachine\TrustedDevices

Write-BuildLog "Connect to View"
Import-Module VMware.VimAutomation.HorizonView
$hvServer = Connect-HVServer -server localhost -credential $cred
$Global:hvServices = $hvServer.ExtensionData

Write-BuildLog "Add vCentre to View"
$vcService = New-Object VMware.Hv.VirtualCenterService
$certService = New-Object VMware.Hv.CertificateService
$vcSpecHelper = $vcService.getVirtualCenterSpecHelper()
$serverSpec = $vcSpecHelper.getDataObject().serverSpec
$serverSpec.serverName = $VCHost
$serverSpec.port = 443
$serverSpec.useSSL = $true
$serverSpec.userName = "administrator"
$vcPassword = New-Object VMware.Hv.SecureString
$enc = [system.Text.Encoding]::UTF8
$vcPassword.Utf8String = $enc.GetBytes($AdminPWD)
$serverSpec.password = $vcPassword
$serverSpec.serverType = $certService.getServerSpecHelper().SERVER_TYPE_VIRTUAL_CENTER
$certData = $certService.Certificate_Validate($hvServices, $serverSpec)
$certificateOverride = New-Object VMware.Hv.CertificateThumbprint
$certificateOverride.sslCertThumbprint = $certData.thumbprint.sslCertThumbprint
$certificateOverride.sslCertThumbprintAlgorithm = $certData.thumbprint.sslCertThumbprintAlgorithm
# Adding View Composer was a pain
$ViewComposerData = New-Object VMware.Hv.VirtualCenterViewComposerData
$ViewComposerData.viewComposerType = "LOCAL_TO_VC"
$ViewCompserverspec = New-Object VMware.Hv.ServerSpec
$ViewCompserverspec.port = 18443
$ViewCompserverspec.serverName = 'vc.lab.local'
$ViewCompserverspec.userName = 'administrator'
$ViewCompserverspec.password  = $vcPassword
$ViewCompserverspec.serverType = 'VIEW_COMPOSER'
$ViewCompserverspec.useSSL = $True
$ViewComposerData.ServerSpec = $ViewCompserverspec
$compCertService = New-Object VMware.Hv.CertificateService
$compCertData = $compcertService.Certificate_Validate($hvServices, $ViewCompserverspec)
$compCertificateOverride = New-Object VMware.Hv.CertificateThumbprint
$compCertificateOverride.sslCertThumbprint = $compCertData.thumbprint.sslCertThumbprint
$compCertificateOverride.sslCertThumbprintAlgorithm = $compCertData.thumbprint.sslCertThumbprintAlgorithm
$ViewComposerData.CertificateOverride = $compCertificateOverride
$vcSpecHelper.getDataObject().ViewComposerData = $ViewComposerData
$vcSpecHelper.getDataObject().CertificateOverride = $certificateOverride
$vcId = $vcService.VirtualCenter_Create($hvServices, $vcSpecHelper.getDataObject())

Write-BuildLog "Setup View composer domain"
$spec = New-Object VMware.Hv.ViewComposerDomainAdministratorSpec
$spec.Base = New-Object VMware.Hv.ViewComposerDomainAdministratorBase
$spec.Base.Domain = 'lab.local'
$spec.Base.UserName = 'vi-admin'
$ADPassword = New-Object VMware.Hv.SecureString
$ADPassword.Utf8String = $enc.GetBytes("VMware1!")
$spec.Base.Password = $ADPassword
$spec.VirtualCenter = $global:DefaultVIServer.Id

#Write-BuildLog "Set Security Server pairing password"
#Since the type doesn't appear to be in the Powershell module we cannot add the pairing password
#$pairingData = New-Object VMware.Hv.SecurityServerPairingData
#$pairingPassword = New-Object VMware.Hv.SecureString
#$pairingPassword.Utf8String = $enc.GetBytes("VMware1!")
#$pairingData.pairingPassword = $pairingPassword
#$pairingData.timeoutMinutes = 1440
#$CS1 = ($hvServices.ConnectionServer.ConnectionServer_List())[0]
#$CS1.securityServerPairing = $pairingData
 
$icausername="vi-admin"
$icadomain = "lab.local"
$icadminPassword = New-Object VMware.Hv.SecureString
$enc = [system.Text.Encoding]::UTF8
$icadminPassword.Utf8String = $enc.GetBytes($AdminPWD)
$spec=new-object vmware.hv.InstantCloneEngineDomainAdministratorSpec
$spec.base=new-object vmware.hv.InstantCloneEngineDomainAdministratorBase
$spec.base.domain=(($hvServices.ADDomain.addomain_list() | where {$_.DnsName -eq $icadomain} | select-object -first 1).id)
$spec.base.username=$icausername
$spec.base.password=$icadminpassword
$ICADM = $hvServices.InstantCloneEngineDomainAdministrator.InstantCloneEngineDomainAdministrator_Create($spec)

Write-BuildLog "Setup View eventlog"
$updates = @()
$updates += Get-MapEntry -key "database.server" -value "dc.lab.local"
$updates += Get-MapEntry -key "database.type" -value "SQLSERVER"
$updates += Get-MapEntry -key "database.name" -value "ViewEvents"
$updates += Get-MapEntry -key "database.port" -value 1433
$updates += Get-MapEntry -key "database.userName" -value "VMview"
$updates += Get-MapEntry -key "database.password" -value $ADPassword
$updates += Get-MapEntry -key "database.tablePrefix" -value "Lab_"
$Events = $hvServices.EventDatabase.EventDatabase_Update($updates)
	
Disconnect-HVServer -server localhost -Force -Confirm:$false
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Config /f
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
#read-host "Check VC was added"