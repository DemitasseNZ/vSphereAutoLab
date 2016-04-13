# Build Validation script for vSphere 6.0 AutoLab
#
# Version 2.6
#
#
# Include the functions script, this is used to keep this script clean
if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun AddHosts.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}

$Global:Pass = $true

if (Test-Administrator) {
	Write-Host "Great, script is running as administrator" -foregroundcolor "Green"
} else {
	Start-Process PowerShell.exe -Verb Runas -ArgumentList " c:\validate.ps1"
	exit
}
# make script window as tall as possible

$a = (Get-Host).UI.RawUI
$b = $a.WindowSize
$b.Height = $a.MaxWindowSize.Height - 1
$a.WindowSize = $b
Import-Module C:\windows\system32\WASP.dll
Select-Window -Title "Administrator:" | set-windowposition -left 3 -top 3
If (!(Test-Path "B:\*")) {
	net use B: \\192.168.199.7\Build
}
$CompName = gc env:computername
Write-Host "Validating" $CompName -foregroundcolor "cyan"
Write-Host "Error events from system eventlog on " $CompName -foregroundcolor "cyan"
get-eventlog -LogName System -entrytype Error  -ErrorAction SilentlyContinue | Format-table -property TimeGenerated, Message -autosize
if ($CompName -eq "DC") {
	Write-Host "Validating required Build share components." -foregroundcolor "cyan"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
	If ($AdminPWD -eq "VMware1!") {
		Write-Host "Default admin password set, this isn't safe." -foregroundcolor "Red"
		$NewPWD = Read-Host "Enter a new admin password"
		If ($NewPWD -ne "") {
			Write-Host "Setting new password" -foregroundcolor "Green"
			$OldAdminPWD = $AdminPWD
			$AdminPWD = $NewPWD
			$FileContent = get-content B:\Automate\automate.ini
			Set-Content  B:\Automate\automate.ini ""
			Foreach ($Line in $FileContent){
				If ($Line.StartsWith("Adminpwd"))  { $Line = "Adminpwd=$NewPWD"}
				Add-Content B:\Automate\automate.ini $Line
			}
			net user  SVC_Veeam $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user  SVC_SRM $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user DomUser $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log 
			net user vi-admin $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user administrator $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user ada $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user alan $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user grace $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			net user charles $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
			B:\automate\_Common\Autologon administrator lab $AdminPWD
			$TempContent = Get-Content B:\Automate\Hosts\esx1-4.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx1-4.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx1-5.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx1-5.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx2-4.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx2-4.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx2-4c.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx2-4c.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx2-5.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx2-5.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx3-5.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx3-5.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx4-5.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx4-5.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx11-5.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx11-5.cfg
			$TempContent = Get-Content B:\Automate\Hosts\esx12-5.cfg |%{$_ -replace $OldAdminPWD,$AdminPWD}
			$TempContent | Set-Content B:\Automate\Hosts\esx12-5.cfg
			$service = gwmi win32_service -filter "name='MSSQL`$SQLEXPRESS'"
			$null = $service.change($null,$null,$null,$null,$null,$null,$null,$AdminPWD)
			Write-Host "Restarting SQL Express with new password" -foregroundcolor "Green"
			$null = Restart-Service "MSSQL`$SQLEXPRESS" -force
		}
	}
	If ((Get-WmiObject Win32_BIOS).Manufacturer.Tolower() -like "bochs*") {
		Write-Host "Building on Ravello, set some build options." -foregroundcolor "green"
		$AutoAddHosts = (Read-Host "Automatically add hosts to vCentre when it builds (y/n)").ToLower()
		If ($AutoAddHosts -eq "n") {
		$TempContent = Get-Content B:\Automate\Automate.ini |%{$_ -replace "AutoAddHosts=true","AutoAddHosts=false"}
		$TempContent | Set-Content B:\Automate\Automate.ini
		}
		If ($AutoAddHosts -eq "y") {
		$TempContent = Get-Content B:\Automate\Automate.ini |%{$_ -replace "AutoAddHosts=false","AutoAddHosts=true"}
		$TempContent | Set-Content B:\Automate\Automate.ini
		Write-Host "Make sure the ESXi hosts are properly built & restart cleanly"  -foregroundcolor "cyan"
		}
	}
	$vSpherePaths = @{"ESX41"="\\192.168.199.7\Build\ESX41\*";"ESXi41"="\\192.168.199.7\Build\ESXi41\*";"vCenter41"="\\192.168.199.7\Build\VIM_41\*";"ESXi50"="\\192.168.199.7\Build\ESXi50\*";"vCenter50"="\\192.168.199.7\Build\VIM_50\*";"ESXi51"="\\192.168.199.7\Build\ESXi51\*";"vCenter51"="\\192.168.199.7\Build\VIM_51\*";"ESXi55"="\\192.168.199.7\Build\ESXi55\*";"vCenter55"="\\192.168.199.7\Build\VIM_55\*";"ESXi60"="\\192.168.199.7\Build\ESXi60\*";"vCenter60"="\\192.168.199.7\Build\VIM_60\*"}
	$vSpherePaths.GetEnumerator() | % {if (!(Test-Path $_.Value)) {New-Variable -Name $_.Name -Value $false -force} else {New-Variable -Name $_.Name -Value $true -force}}
	if ($vCenter41 -and ($ESXi41 -or $ESX41)) {
		Write-Host "vCenter 4.1 & ESXi 4.1 found." -foregroundcolor "green"
		$vSphere41 = $true
	} elseif ($vCenter41 -or ($ESXi41 -or $ESX41)) {
		Write-Host "vSphere 4.1 installation requirements not met. Please verify that both vCenter 4.1 & ESXi 4.1 exist on Build share." -foregroundcolor "red"
		$vSphere41 = $false
	} else {
		Write-Host "vCenter 4.1 & ESXi 4.1 not found." -foregroundcolor "cyan"
		$vSphere41 = $false
	}
	if ($vCenter50 -and $ESXi50) {
		Write-Host "vCenter 5.0 & ESXi 5.0 found." -foregroundcolor "green"
		$vSphere50 = $true
	} elseif ($vCenter50 -or $ESXi50) {
		Write-Host "vSphere 5.0 installation requirements not met. Please verify that both vCenter 5.0 & ESXi 5.0 exist on Build share." -foregroundcolor "red"
		$vSphere50 = $false
	} else {
		Write-Host "vCenter 5.0 & ESXi 5.0 not found." -foregroundcolor "cyan"
		$vSphere50 = $false
	}
	if ($vCenter51 -and $ESXi51) {
		Write-Host "vCenter 5.1 & ESXi 5.1 found." -foregroundcolor "green"
		$vSphere51 = $true
	} elseif ($vCenter51 -or $ESXi51) {
		Write-Host "vSphere 5.1 installation requirements not met. Please verify that both vCenter 5.1 & ESXi 5.1 exist on Build share." -foregroundcolor "red"
		$vSphere51 = $false
	} else {
		Write-Host "vCenter 5.1 & ESXi 5.1 not found." -foregroundcolor "cyan"
		$vSphere51 = $false
	}
	if ($vCenter55 -and $ESXi55) {
		Write-Host "vCenter 5.5 & ESXi 5.5 found." -foregroundcolor "green"
		$vSphere55 = $true
	} elseif ($vCenter55 -or $ESXi55) {
		Write-Host "vSphere 5.5 installation requirements not met. Please verify that both vCenter 5.5 & ESXi 5.5 exist on Build share." -foregroundcolor "red"
		$vSphere55 = $false
	} else {
		Write-Host "vCenter 5.5 & ESXi 5.5 not found." -foregroundcolor "cyan"
		$vSphere55 = $false
	}
		if ($vCenter60 -and $ESXi60) {
		Write-Host "vCenter 6.0 & ESXi 6.0 found." -foregroundcolor "green"
		$vSphere60 = $true
	} elseif ($vCenter60 -or $ESXi60) {
		Write-Host "vSphere 6.0 installation requirements not met. Please verify that both vCenter 6.0 & ESXi 6.0 exist on Build share." -foregroundcolor "red"
		$vSphere60 = $false
	} else {
		Write-Host "vCenter 6.0 & ESXi 6.0 not found." -foregroundcolor "cyan"
		$vSphere60 = $false
	}
	if (!($vSphere41 -or $vSphere50 -or $vSphere51 -or $vSphere55 -or $vSphere60)) {
		Write-Host "Matching vCenter & ESXi distributions not found. Please check the Build share." -foregroundcolor "red"
		$Global:Pass = $false
	}
	Check-File "\\192.168.199.7\Build\VMware-PowerCLI*.exe" "PowerCLI installer"
	If (!(Test-Path "\\192.168.199.7\Build\VMware-PowerCLI*.exe")) {
		If ((Read-Host "Would you like to go to the PowerCLI download site (y/n)?") -like "y") {
			$IE=new-object -com internetexplorer.application
			if ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62) {$IE.navigate2("https://my.vmware.com/group/vmware/get-download?downloadGroup=PCLI600R1")}
			if ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -le 62) {$IE.navigate2("https://my.vmware.com/group/vmware/get-download?downloadGroup=PCLI58R1")}
			$IE.visible=$true
		} Else {
			Write-Host "OK, but the VC build will not work correctly without PowerCLI"
		}
	}
	if (Test-Path "b:\VMware-PowerCLI-5*.exe") {
		If (($vSphere50 -and ((Get-ChildItem B:\VMware-PowerCLI-*.exe | where {$_.VersionInfo.ProductVersion -like "5.0*"}) -eq $Null))) {Write-Host "vSphere 5.0 found, matching PowerCLI version missing. Please check the Build share." -foregroundcolor "Yellow"}
		If (($vSphere51 -and ((Get-ChildItem B:\VMware-PowerCLI-*.exe | where {$_.VersionInfo.ProductVersion -like "5.1*"}) -eq $Null))) {Write-Host "vSphere 5.1 found, matching PowerCLI version missing. Please check the Build share." -foregroundcolor "Yellow"}
		If (($vSphere55 -and (((Get-ChildItem B:\VMware-PowerCLI-*.exe | where {$_.VersionInfo.ProductVersion -like "5.5*"}) -eq $Null) -or !((Get-ChildItem B:\VMware-PowerCLI-*.exe | where {$_.VersionInfo.ProductVersion -like "5.8*"}) -eq $Null)))) {Write-Host "vSphere 5.5 found, matching PowerCLI version missing. Please check the Build share." -foregroundcolor "Yellow"}
	} 
	Check-OptionalFile "\\192.168.199.7\Build\Win2K3.iso" "Windows Server 2003 ISO"
	Check-OptionalFile "\\192.168.199.7\Build\WinXP.iso" "Windows XP ISO"
    Write-Host "Validate SQL & TFTP Install" -foregroundcolor "cyan"
	if (Test-Path -LiteralPath "C:\Program Files\Microsoft SQL Server\MSSQL10_50.SQLEXPRESS\MSSQL\DATA\") {
		Check-File "C:\Program Files\Microsoft SQL Server\MSSQL10_50.SQLEXPRESS\MSSQL\DATA\vCenter.mdf" "vCenter Database"
		Check-File "C:\Program Files\Microsoft SQL Server\MSSQL10_50.SQLEXPRESS\MSSQL\DATA\VUM.mdf" "vCenter Update Manager Database"
	} elseif (Test-Path -LiteralPath "C:\Program Files (x86)\Microsoft SQL Server\MSSQL.1\MSSQL\Data\") {
		Check-File "C:\Program Files (x86)\Microsoft SQL Server\MSSQL.1\MSSQL\Data\vCenter.mdf" "vCenter Database"
		Check-File "C:\Program Files (x86)\Microsoft SQL Server\MSSQL.1\MSSQL\Data\VUM.mdf" "vCenter Update Manager Database"
	}	
    Check-File "C:\Program Files\Tftpd64_SE\Tftpd64_SVC.exe" "TFTP Server"
    Check-File "C:\TFTP-Root\pxelinux.0" "PXE boot file"
    Check-File "C:\TFTP-Root\pxelinux.cfg" "PXE boot configuration file"
	if ($ESX41 -and (Test-Path "C:\TFTP-Root\ESX41\*")) {
		Write-Host "ESX 4.1 TFTP files found." -foregroundcolor "green"
	} elseif ($ESX41 -and !(Test-Path "C:\TFTP-Root\ESX41\*")) {
		Write-Host "ESX 4.1 TFTP files not found on DC, but they exist on Build share." -foregroundcolor "red"
		$Global:Pass = $false
	}
	if ($ESXi41 -and (Test-Path "C:\TFTP-Root\ESXi41\*")) {
		Write-Host "ESXi 4.1 TFTP files found." -foregroundcolor "green"
	} elseif ($ESXi41 -and !(Test-Path "C:\TFTP-Root\ESXi41\*")) {
		Write-Host "ESXi 4.1 TFTP files not found on DC, but they exist on Build share." -foregroundcolor "red"
		$Global:Pass = $false
	}
	if ($ESXi50 -and (Test-Path "C:\TFTP-Root\ESXi50\*")) {
		Write-Host "ESXi 5.0 TFTP files found." -foregroundcolor "green"
	} elseif ($ESXi50 -and !(Test-Path "C:\TFTP-Root\ESXi50\*")) {
		Write-Host "ESXi 5.0 TFTP files not found on DC, but they exist on Build share." -foregroundcolor "red"
		$Global:Pass = $false
	}
	if ($ESXi51 -and (Test-Path "C:\TFTP-Root\ESXi51\*")) {
		Write-Host "ESXi 5.1 TFTP files found." -foregroundcolor "green"
	} elseif ($ESXi51 -and !(Test-Path "C:\TFTP-Root\ESXi51\*")) {
		Write-Host "ESXi 5.1 TFTP files not found on DC, but they exist on Build share." -foregroundcolor "red"
		$Global:Pass = $false
	}
	$vcinstall = ((Select-String -SimpleMatch "VCInstall=" -Path "B:\Automate\automate.ini").line).substring(10)
	If ($vcinstall -eq "50") {$vcinstall = "5"}
	If (!($vSphere50) -and ($vcinstall -eq "5")) {
		Write-Host "You wish to install vSphere 5.0 but the installers aren't on the build share"  -foregroundcolor "red"
		$Global:Pass = $false
	}
	If (!($vSphere51) -and ($vcinstall -eq "51")) {
		Write-Host "You wish to install vSphere 5.1 but the installers aren't on the build share"  -foregroundcolor "red"
		$Global:Pass = $false
	}    
	If (!($vSphere55) -and ($vcinstall -eq "55")) {
		Write-Host "You wish to install vSphere 5.5 but the installers aren't on the build share"  -foregroundcolor "red"
		$Global:Pass = $false
	}    
	Write-Host "Check Domain" -foregroundcolor "cyan"
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() 
    if ($domain.Name -eq "lab.local") {
		Write-Host ("Correct Domain") -foregroundcolor "green"
	} else {
        Write-Host ("Domain Broken") -foregroundcolor "red"
        $Global:Pass = $false
    }
    Write-Host "Check Services"  -foregroundcolor "cyan"
    Check-ServiceRunning "Active Directory Domain Services"
    Check-ServiceRunning "DHCP Server"
    Check-ServiceRunning "DNS Server"
    Check-ServiceRunning "Netlogon"
    Check-ServiceRunning "Tftpd32_svc"
    Check-ServiceRunning "SQL Server (SQLEXPRESS)"
    Check-ServiceRunning "SQLBrowser"
    If ((Get-VMPlatform) -eq "VMware") {Check-ServiceRunning "VMTools"}
    Write-Host "Check DNS"  -foregroundcolor "cyan"
    Check-DNSRecord ("dc.lab.local")
    Check-DNSRecord ("vc.lab.local")
    Check-DNSRecord ("vma.lab.local")
    Check-DNSRecord ("nas.lab.local")
    Check-DNSRecord ("host1.lab.local")
    Check-DNSRecord ("host2.lab.local")
    Check-DNSRecord ("192.168.199.4")
    Check-DNSRecord ("192.168.199.5")
    Check-DNSRecord ("192.168.199.6")
    Check-DNSRecord ("192.168.199.7")
    Check-DNSRecord ("192.168.199.11")
    Check-DNSRecord ("192.168.199.12")
	Check-DNSRecord ("192.168.199.38")
	Check-DNSRecord ("192.168.199.39")
	Check-DNSRecord ("192.168.199.40")
}
if ($CompName -eq "VC") {
	$HaveXP = test-Path("\\192.168.199.7\Build\WinXP.iso")
	$Have2K3 = test-Path("\\192.168.199.7\Build\Win2K3.iso")
    If ((Get-VMPlatform) -eq "VMware") {Check-ServiceRunning "VMTools"}
	$VCPath = "None"
	If (Test-path "C:\ProgramData\VMware\VMware VirtualCenter") {
		$VCPath = "C:\ProgramData\VMware\VMware VirtualCenter"
		$VCVer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\VMware, Inc.\VMware VirtualCenter").InstalledVersion
	}
		If (Test-path "C:\ProgramData\VMware\vCenterServer") {
		$VCPath = "C:\ProgramData\VMware\vCenterServer\cfg\vmware-vpx"
		$VCVer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\VMware, Inc.\vCenter Server").ProductVersion
	}
	Write-Host "VC version $VCVer"
	If (!($VCPath -eq "None")) {
		Write-Host "Check Files" -foregroundcolor "cyan"
		if ($Have2K3 -eq $True) {Check-File "$VCPath\sysprep\svr2003\sysprep.exe" "Windows 2003 SysPrep" }
		if ($HaveXP -eq $True) { Check-File "$VCPath\sysprep\xp\sysprep.exe" "Windows XP SysPrep" }
		if (Test-Path "B:\Automate\automate.ini") {
			if ($VCVer.StartsWith("4")) {
				if ((((Select-String -SimpleMatch "DeployVUM=" -Path "B:\Automate\automate.ini").line).substring(10)) -like "true") {Check-ServiceRunning "VMware vCenter Update Manager Service"}
				Check-ServiceRunning "ADAM_VMwareVCMSDS"
				Check-ServiceRunning "VMware VirtualCenter Management Webservices"
				Check-ServiceRunning "VMware VirtualCenter Server"
			}
			if ($VCVer.StartsWith("5")) {
				if ((((Select-String -SimpleMatch "DeployVUM=" -Path "B:\Automate\automate.ini").line).substring(10)) -like "true") {Check-ServiceRunning "VMware vSphere Update Manager Service"}
				Check-ServiceRunning "ADAM_VMwareVCMSDS"
				Check-ServiceRunning "VMware VirtualCenter Management Webservices"
				Check-ServiceRunning "VMware VirtualCenter Server"
			}
			if ($VCVer.StartsWith("6")) {
				if ((((Select-String -SimpleMatch "DeployVUM=" -Path "B:\Automate\automate.ini").line).substring(10)) -like "true") {Check-ServiceRunning "VMware vSphere Update Manager Service"}
				Check-ServiceRunning "VMware VirtualCenter Server"
			}
		}
		
	} Else {
		Write-Host "vCenter is not installed" -foregroundcolor "Yellow"
	}
	if ($Have2K3 -eq $true) {
		Check-OptionalFile "\\192.168.199.7\Build\Windows2K3.iso" "Lightly automated Windows Server 2003 ISO"
		Check-OptionalFile "\\192.168.199.7\Build\Auto2K3.iso" "Fully automated Windows Server 2003 ISO"
	}
	if ($HaveXP -eq $true) {Check-OptionalFile "\\192.168.199.7\Build\AutoXP.iso" "Fully automated Windows XP ISO"}
}
if ($CompName -eq "DC2") {
    Write-Host "Check Domain" -foregroundcolor "cyan"
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() 
    if ($domain.Name -eq "lab.local") {
		Write-Host ("Correct Domain") -foregroundcolor "green"
	} else {
        Write-Host ("Domain Broken") -foregroundcolor "red"
        $Global:Pass = $false
    }
    Write-Host "Check Services"  -foregroundcolor "cyan"
    Check-ServiceRunning "Active Directory Domain Services"
    Check-ServiceRunning "DNS Server"
    Check-ServiceRunning "Netlogon"
    Check-ServiceRunning "SQL Server (SQLEXPRESS)"
    Check-ServiceRunning "SQLBrowser"
    If ((Get-VMPlatform) -eq "VMware") {Check-ServiceRunning "VMTools"}
    Write-Host "Check DNS"  -foregroundcolor "cyan"
    Check-DNSRecord ("dc.lab.local")
    Check-DNSRecord ("vc.lab.local")
    Check-DNSRecord ("vma.lab.local")
    Check-DNSRecord ("nas.lab.local")
    Check-DNSRecord ("host1.lab.local")
    Check-DNSRecord ("host2.lab.local")
    Check-DNSRecord ("192.168.199.4")
    Check-DNSRecord ("192.168.199.5")
    Check-DNSRecord ("192.168.199.6")
    Check-DNSRecord ("192.168.199.7")
    Check-DNSRecord ("192.168.199.11")
    Check-DNSRecord ("192.168.199.12")
	Check-DNSRecord ("192.168.199.38")
	Check-DNSRecord ("192.168.199.39")
	Check-DNSRecord ("192.168.199.40")
}
if ($CompName -eq "VC2") {

    If ((Get-VMPlatform) -eq "VMware") {Check-ServiceRunning "VMTools"}
	If (Test-path "C:\ProgramData\VMware\VMware VirtualCenter") {
		Write-Host "Check Services" -foregroundcolor "cyan"
		Check-ServiceRunning "VMware VirtualCenter Management Webservices"
		Check-ServiceRunning "VMware VirtualCenter Server"
		Check-ServiceRunning "ADAM_VMwareVCMSDS"
	} Else {
		Write-Host "vCenter is not installed" -foregroundcolor "Yellow"
	}
}

Write-Host "The final result" -foregroundcolor "cyan"
if ($Global:Pass -eq $false ) {
    Write-Host ("*****************************************") -foregroundcolor "red"
    Write-Host ("*") -foregroundcolor "red"
    Write-Host ("* Oh dear, we seem to have a problem") -foregroundcolor "red"
    Write-Host ("*") -foregroundcolor "red"
    Write-Host ("* Check the build log to see what failed") -foregroundcolor "red"
    Write-Host ("*") -foregroundcolor "red"
    Write-Host ("*****************************************") -foregroundcolor "red"
} else {
    Write-Host ("**************************************") -foregroundcolor "green"
    Write-Host ("*") -foregroundcolor "green"
    Write-Host ("*   Build looks good") -foregroundcolor "green"
    Write-Host ("*") -foregroundcolor "green"
    Write-Host ("*   Move on to the next stage") -foregroundcolor "green"
    Write-Host ("*") -foregroundcolor "green"
    Write-Host ("**************************************") -foregroundcolor "green"
}
Read-host "  Press <Enter> to exit"