# Script to add add ESX servers to vCenter and do initial configuration
#
#
# Version 0.8
#
#
. "C:\PSFunctions.ps1"
If (Test-Administrator){ 
    Write-host " "
    Write-Host "This script should not be 'Run As Administrator'" -foregroundcolor "Red"
    Write-host " "
    Write-Host "Just double click the shortcut" -foregroundcolor "Red"
    Write-host " "
    Exit    
}
if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
	try {
		Write-Host "Loading PowerCLI plugin, this will take a little while"  -foregroundcolor "cyan"
		Add-PsSnapin VMware.VimAutomation.Core
	}
	catch {
		Write-Host "Unable to load the PowerCLI plugin. Please verify installation and run this script again."
		exit
}
for ($i=1;$i -le 2; $i++){
    $vmhost = "host$i.lab.local"
    $ping = new-object System.Net.NetworkInformation.Ping
    $Reply = $ping.send($vmhost)
    if ($Reply.status –ne "Success") {
        Write-Host $vmhost " not responding to ping, exiting"  -foregroundcolor "red"
        Write-Host "Re-run this script when both ESXi hosts are running"  -foregroundcolor "red"
        Read-Host "Press <ENTER> to exit."
		exit
    }
}
Write-Host " "
$Null = connect-viserver vc.lab.local
Write-Host "Create Datacenter and Cluster"  -foregroundcolor "green"
if ((Get-DataCenter | where {$_.Name -eq "Lab"}) -eq $Null) {
    $Null = New-DataCenter -Location (Get-Folder -NoRecursion) -Name Lab
}    
if ((Get-Cluster | where {$_.Name -eq "local"}) -eq $Null) {
    $Cluster = New-Cluster Local -DRSEnabled -Location Lab -DRSAutomationLevel PartiallyAutomated 
}

for ($i=1;$i -le 2; $i++){
    $Num = $i +10
    $VMHost = "host"
    $VMHost += $i
    $VMHost += ".lab.local"
    $VMotionIP = "172.16.199."
    $VMotionIP += $Num
    $IPStoreIP1 = "172.17.199."
    $IPStoreIP1 += $Num
    $IPStoreIP2 = "172.17.199."
    $Num = $i +20
    $IPStoreIP2 += $Num
    $FTIP = "172.16.199."
    $FTIP += $Num
    $Num = $i +40
    $vHeartBeatIP = "172.16.199."
    $vHeartBeatIP += $Num
    Write-Host $VMHost -foregroundcolor "cyan"
    if ((Get-VMHost | where {$_.Name -eq $VMHost}) -eq $Null) {
        $VMHostObj = add-vmhost $VMhost -user root -password VMware1! -Location Lab -force:$true
        If ($VMHostObj.ConnectionState -ne "Connected"){
            Write-Host " "
            Write-Host "Connecting " $VMHost " has failed, is the ESXi server built?"  -foregroundcolor "red"
            Write-Host " "
            exit
        }
		$Null = Move-VMhost $VMHost -Destination Local
	}
}

Write-Host "Setup HA on Cluster, now that we have shared storage" -foregroundcolor "Green"
$Cluster = Get-Cluster -Name "Local"
$null = set-cluster -cluster $Cluster -HAEnabled:$True -HAAdmissionControlEnabled:$True -confirm:$False
$null = New-AdvancedSetting -Entity $cluster -Type ClusterHA -Name 'das.isolationaddress1' -Value "192.168.199.4" -confirm:$False -force
$null = New-AdvancedSetting -Entity $cluster -Type ClusterHA -Name 'das.usedefaultisolationaddress' -Value false -confirm:$False -force
$spec = New-Object VMware.Vim.ClusterConfigSpecEx
$Null = $spec.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
$Null = $spec.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
$Null = $spec.dasConfig.admissionControlPolicy.cpuFailoverResourcesPercent = 50
$Null = $spec.dasConfig.admissionControlPolicy.memoryFailoverResourcesPercent = 50
$Cluster = Get-View $Cluster
$Null = $Cluster.ReconfigureComputeResource_Task($spec, $true)
Write-Host " "
$Null = Disconnect-VIServer -Server * -confirm:$False
