# Script to Shutdown AutoLab
#
#
# Version 2.6
#
#
. "C:\PSFunctions.ps1"
Function ShutWinServ ($WinServ){
    $ping = new-object System.Net.NetworkInformation.Ping
    $Reply = $ping.send($WinServ) 
    if ($Reply.status –eq "Success") {
        Write-Host "Shutdown $WinServ" -foregroundcolor "Green"
		$null = stop-Computer -comp $WinServ -force
		}
	}
if (Test-Path \\nas\build\Automate\automate.ini) {
	$AdminPWD = "VMware1!"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "\\nas\build\Automate\automate.ini").line).substring(9)
} Else {
	Write-BuildLog "Cannot find Automate.ini, this isn't a good sign"
}

Write-Host " "
Write-Host "This script will shutdown your lab, enter Y to proceed"  -foregroundcolor "cyan"
$ReBuild = Read-Host 
If ([string]::Compare($ReBuild, "Y", $True) -eq "0"){
	Write-Host "Shutting down your lab" -foregroundcolor "cyan"
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
	Write-host "Connect to Linux amchiunes to cache RSA Keys, say yes to all"
	$ping = new-object System.Net.NetworkInformation.Ping
	$Reply = $ping.send("192.168.199.254") 
    if ($Reply.status –eq "Success") {
        Write-Host " WAN" -foregroundcolor "Green"
		cmd /c '"C:\Program Files (x86)\PuTTY\plink.exe" 192.168.199.254 -l root -pw VMware1! exit'
		}
    $Reply = $ping.send("gw") 
    if (($Reply.status –eq "Success") -and (!((get-vmplatform) -ne "Ravello"))) {
        Write-Host " Router" -foregroundcolor "Green"
		cmd /c '"C:\Program Files (x86)\PuTTY\plink.exe" gw -l root -pw VMware1! exit'
		}
    $Reply = $ping.send("nas") 
    if ($Reply.status –eq "Success") {
        Write-Host " NAS" -foregroundcolor "Green"
		cmd /c '"C:\Program Files (x86)\PuTTY\plink.exe" NAS -l root -pw VMware1! exit'
		}
	Write-Host "Connect to vCenter" -foregroundcolor "Green"
	$null = connect-viserver vc.lab.local  -user administrator -password $AdminPWD
	Write-Host "Shutdown any running VMs" -foregroundcolor "Green"
	$Cluster = Get-Cluster -name "Local"
	$null = get-VM -Location $Cluster | Where-Object {$_.PowerState -eq "PoweredOn"}| foreach-Object{Write-Host "Shutting down " $_.Name -foregroundcolor "Green";stop-vm $_ -Confirm:$false}
	Write-Host "Shutdown any running ESX servers" -foregroundcolor "Green"
	$null = get-VMhost -Location $Cluster | Where-Object {$_.ConnectionState -eq "Connected"}| foreach-Object{Write-Host "Shutting down " $_.Name -foregroundcolor "Green"; stop-vmhost $_ -Confirm:$false -force}
	$null = Disconnect-VIServer -Server * -confirm:$false
	ShutWinServ ("ss.lab.local")
	ShutWinServ ("cs1.lab.local")
	ShutWinServ ("cs2.lab.local")
	ShutWinServ ("v1.lab.local")
	ShutWinServ ("vbr.lab.local")
    $Reply = $ping.send("vc2.lab.local") 
    if ($Reply.status –eq "Success") {
        Write-Host "Shutdown SRM Site" -foregroundcolor "Green"
		Write-Host "Connect to vCenter" -foregroundcolor "Green"
		$null = connect-viserver vc2.lab.local  -user administrator -password $AdminPWD
		Write-Host "Shutdown any running VMs" -foregroundcolor "Green"
		$null = get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}| foreach-Object{Write-Host "Shutting down " $_.Name -foregroundcolor "Green";stop-vm $_ -Confirm:$false}
		Write-Host "Shutdown any running ESX servers" -foregroundcolor "Green"
		$null = get-VMhost | Where-Object {$_.ConnectionState -eq "Connected"}| foreach-Object{Write-Host "Shutting down " $_.Name -foregroundcolor "Green"; stop-vmhost $_ -Confirm:$false -force}
		$null = Disconnect-VIServer -Server * -confirm:$false
	}
    $Reply = $ping.send("192.168.199.254") 
    if ($Reply.status –eq "Success") {
        Write-Host "Shutdown WAN" -foregroundcolor "Green"
		cmd /c '"C:\Program Files (x86)\PuTTY\plink.exe" 192.168.199.254 -l root -pw VMware1! shutdown -h now'
		}
    $Reply = $ping.send("gw") 
    if (($Reply.status –eq "Success") -and (!((get-vmplatform) -ne "Ravello"))) {
        Write-Host "Shutdown Router" -foregroundcolor "Green"
		cmd /c '"C:\Program Files (x86)\PuTTY\plink.exe" gw -l root -pw VMware1! halt -p'
		}
    $Reply = $ping.send("nas") 
    if ($Reply.status –eq "Success") {
        Write-Host "Shutdown NAS" -foregroundcolor "Green"
		cmd /c '"C:\Program Files (x86)\PuTTY\plink.exe" NAS -l root -pw VMware1! shutdown -h now'
		}
	ShutWinServ ("dc2.lab.local")
	ShutWinServ ("dc.lab.local")
	ShutWinServ ("vc2.lab.local")
	ShutWinServ ("vc.lab.local")
	Read-Host "Exit and wait for everything to go away" -foregroundcolor "cyan"
} Else {
	Write-Host "Leaving your lab running" -foregroundcolor "cyan"
}