# Script to add add VMware vShield Manager to the AutoLab infrastructure
# 
# Thanks to Alan Renouf (http://www.virtu-al.net/2011/09/14/powershell-automated-install-of-vshield-5/)
# Thanks to Jeff Hicks for the Test-Website Function: http://jdhitsolutions.com/blog/2010/04/hey-are-you-awake/
# Thanks to William Lam for the trick to change the Zebra file: http://www.virtuallyghetto.com/2011/09/how-to-automate-deployment.html
# AutoLab v1.1
#
#
. "C:\PSFunctions.ps1"
Function New-ZebraFile ($vShieldHostName, $vShieldIP, $vShieldID, $vShieldGW) {
$ZebraFile = @"
!
hostname $vShieldHostName
!
interface mgmt
 ip address $vShieldIP/$vShieldID
!
ip route 0.0.0.0/0 $vShieldGW
!
line vty
 no login
!
"@

$ZebraFile | Out-File $ENV:TEMP\zebra.conf -Encoding "ASCII"
}
Function Post-vShieldAPI ($URL, $Body) {
	$wc = New-Object System.Net.WebClient

	# Add Authorization headers
	$authbytes = [System.Text.Encoding]::ASCII.GetBytes($vshieldUser + ":" + $vShieldPass)
	$base64 = [System.Convert]::ToBase64String($authbytes)
	$authorization = "Authorization: Basic " + $base64
	$wc.Headers.Add($authorization)

	$response = $wc.UploadString($URL, "POST", $Body)
}
Function Set-vShieldConfiguration ($vCenter, $Username, $Password, $PrimaryDNS, $SecondaryDNS) {
	$Body = @"
<vsmGlobalConfig xmlns="vmware.vshield.edge.2.0">
<dnsInfo>
<primaryDns>$($PrimaryDNS)</primaryDns>
<secondaryDns>$($SecondaryDNS)</secondaryDns>
</dnsInfo>
</vsmGlobalConfig>
"@
	Post-vShieldAPI -URL "https://$vShieldIP/api/2.0/global/config" -Body $Body
}
Function Wait-vShieldBoot {
	do {
		$VM = Get-VM $vShieldHostName
		Sleep 5
	} until ($VM.ToolsStatus -eq "toolsOK")
}
Function Test-WebSite {
    [cmdletBinding()]
    Param (
          [Parameter(
           ValueFromPipeline=$True,Position=0,Mandatory=$True,
           HelpMessage="The URL to test. Include http:// or https://")]
           [string]$url
           )

    Begin {
        CS2 "Begin function"
        }
    Process {
        CS2 "Requesting $url"

        $wr=[system.net.webrequest]::Create($url)
        #set timeout to 7 seconds
        $wr.Timeout=7000
        $start=Get-Date

        Try {
            $response=$wr.GetResponse()
            if ($response) {
                 CS2 "Response returned"
                $Status=$response.StatusCode
                $StatusCode=($response.Statuscode -as [int])
            }
        }
        Catch  [system.net.webexception] {
            CS2 "Failed to get a response from $url"
            $status =  $_.Exception.Response.StatusCode
            $statuscode = ( $_.Exception.Response.StatusCode -as [int])
        }

        $end=Get-Date
        $timespan=$end-$start
        $ResponseMS=$timespan.TotalMilliseconds

        CS2 "status is $status"
        CS2 "statuscode is $statuscode"
        CS2 "timer is $responseMS"

        $obj=New-Object PSObject -Property @{
            DateTime=$start
            URL=$url
            Status=$status
            StatusCode=$statuscode
            ResponseMS=$ResponseMS
         }
         Write-Output $obj

      } #end Process
     End {
        CS2 "End function"
     }
}
Function Wait-vShieldWebsite {
    do {
        $web = test-website https://$vShieldIP
        Sleep 5
    } until ($Web.Status -eq "OK")
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
}
#$null = Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false -InvalidCertificateAction Ignore -Confirm:$false
for ($i=1;$i -le 2; $i++){
    $vmhost = "host$i.lab.local"
    $ping = new-object System.Net.NetworkInformation.Ping
    $Reply = $ping.send($vmhost)
    if ($Reply.status –ne "Success") {
        Write-Host $vmhost " not responding to ping, exiting"  -foregroundcolor "red"
        Write-Host "Re-run this script when both ESXi hosts are running"  -foregroundcolor "red"
        exit
    }
}
$vShieldHostName = "vShield"
$vShieldFQDN = "vshield.lab.local"
$vShieldCluster = "Local"
$vShieldIP = "192.168.199.40"
$vShieldID = "24"
$vShieldGW = "192.168.199.2"
$vShieldPrimaryDNS = "192.168.199.4"
$vShieldSecondaryDNS = "192.168.199.4"
$vShieldUser = "admin"
$vShieldPass = "default"
$vCenter = "192.168.199.5"
$vcUsername = "Lab\vi-admin"
$vcPass = "VMware1!"
$Newproperty = New-VIProperty -Name ToolsStatus -ObjectType VirtualMachine -Value {
	param($vm)
	$vm.ExtensionData.Guest.ToolsStatus
} -Force

Write-Host "Connecting to vCenter"
try {
	$Connect = Connect-VIServer -Server $vCenter -User $vcUsername -Password $vcPass -ErrorAction Stop
	$VMhost = Get-Cluster $vShieldCluster | Get-VMHost | Select -First 1
}
catch {
	Write-Host "Unable to connect to to $vCenter. Exiting."
	exit
}
# Work out which iSCSI datastore has the most free space
$vShieldDS = Get-Datastore -name iSCSI* | Select Name, FreeSpaceGB | Sort-Object -Property FreeSpaceGB | Select-Object -First 1

if (Test-Path "\\192.168.199.7\Build\vCD_15\VMware-vShield-Manager-5.0.*.ova") {
	$vshieldOVA = (Get-ChildItem \\192.168.199.7\Build\vCD_15\VMware-vShield-Manager-5.0.*.ova).FullName
	Write-Host "Importing the vShield OVA"
	try {	
		$va = Import-VApp -Name $vShieldHostName -Datastore $vShieldDS.Name -VMHost $VMHost -Source $vshieldOVA -ErrorAction Stop
		$null = Get-VM $vShieldHostName | Set-VM -MemoryMB 512 -Confirm:$false
		$null = Get-VMResourceConfiguration -VM $vShieldHostName | Set-VMResourceConfiguration -MemReservationMB 0
		Write-Host "Starting the vShield VM"
		$Start = Start-VM $vShieldHostName -Confirm:$false
		Wait-vShieldBoot
		Write-Host "vShield Manager import complete."
	}
	catch {
		write-host "Unable to import vShield. Exiting."
		exit
	}
} else {
	Write-Host "vShield OVA not found. Please copy the file to the Build share and try again."
}

### Commented out due to issues with vShield VM authentication during Invoke-VMScript
# Write-Host "Waiting until the vShield VM has started"
# Wait-vShieldBoot
# Write-Host "Setting the initial IP address after boot"
# $Zebrafile = New-Zebrafile -vShieldHostName $vShieldFQDN -vShieldIP $vShieldIP -vShieldID $vShieldID -vShieldGW $vShieldGW
# $Password = ConvertTo-SecureString -AsPlainText $vShieldPass -Force
# $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "admin", $Password

# $invoke = Invoke-VMScript -VM vShield -ScriptText "mv /common/configs/cli/zebra.conf /common/configs/cli/zebra.conf.bak" -ScriptType Bash -GuestCredential $cred
# $ReIP = Copy-VMGuestFile -VM $vShieldHostName -Source $ENV:TEMP\zebra.conf -Destination "/common/configs/cli/" -LocalToGuest -GuestUser $vShieldUser -GuestPassword $vShieldPass

# Write-Host "Powering Off the vShield VM"
# Sleep 5
# $Stop = Stop-VM $vShieldHostName -Confirm:$false
# Write-Host "Starting the vShield VM"
# $Start = Start-VM $vShieldHostName -Confirm:$false

# Write-Host "Waiting until the vShield VM has started"
# Wait-vShieldBoot

# Write-Host "Waiting until the vShield Management site has started"
# Wait-vShieldWebsite

# Write-Host "Linking vShield to vCenter and set DNS entries"
# $SetIP = Set-vShieldConfiguration -vCenter $vCenter -Username $vcUsername -Password $vcPass -PrimaryDNS $vShieldPrimaryDNS -SecondaryDNS $vShieldSecondaryDNS
# Write-Host "Configuration Complete"