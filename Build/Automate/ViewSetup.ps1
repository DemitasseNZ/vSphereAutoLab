#
Write-Host "Loading View Powershell Plugin"
Add-PSSnapin VMware.View.Broker
Write-Host "Add VC as vCenter and View Composer server"
$VC = add-viewvc -serverName "vc.lab.local" -user "lab\VI-Admin" -Password "VMware1!" -useSSL $True -port 443 -useComposer $True -useComposerSSL $True -composerPort 18443 
# $CS1 = Get-ConnectionBroker -broker_ID "CS1"
# Want to set View Composer credentials & configure EventsDB connection
# Update-ConnectionBroker $CS1 
Write-Host "Done with View setup"
