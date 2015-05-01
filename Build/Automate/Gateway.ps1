$NICs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"
$Null = $NICs.SetGateways("192.168.199.2")
$NICs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"
Write-Host "Added gateway. "
Write-Host "Make sure the lab Router VM is running. "
Read-Host "Press <Enter> to exit"