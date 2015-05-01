#Install-Windowsfeature AD-Domain-Services,DNS -IncludeManagementTools
Add-WindowsFeature -name ad-domain-services -IncludeManagementTools
Write-Host "Convertto-SecureString"
$safemodeadminpwd = ConvertTo-SecureString -String "VMware1!" -asplaintext -force 

Write-Host "Install-ADDSForest"
Install-ADDSForest -DomainName "lab.local" -ForestMode Win2008R2 -DomainMode Win2008R2  -SafeModeAdministratorPassword $safemodeadminpwd -Force 
