$null = Add-WindowsFeature -name ad-domain-services -IncludeManagementTools
$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
$safemodeadminpwd = ConvertTo-SecureString -String $AdminPWD -asplaintext -force 
$Cred = New-Object System.Management.Automation.PsCredential "lab\administrator", $safemodeadminpwd
Write-Host "Add to domain"
Add-Computer -DomainName "Lab.local" -Credential $Cred
Write-Host "Promote to domain controller"
Install-ADDSDomainController
