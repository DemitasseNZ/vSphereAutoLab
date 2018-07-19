if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun Build.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}

if((get-process "dcpromo" -ea SilentlyContinue) -ne $Null){
	write-buildlog "DCPromo still in progress, closing"
 	exit 
}
Try {
	Get-ADDomainController -Discover -ea SilentlyContinue
} catch { 
	write-buildlog "Not yet a domain controller, DCPromo"
	#Install-Windowsfeature AD-Domain-Services,DNS -IncludeManagementTools
	$null = Add-WindowsFeature -name ad-domain-services -IncludeManagementTools
	$safemodeadminpwd = ConvertTo-SecureString -String "VMware1!" -asplaintext -force 
	Write-buildlog "Install-ADDSForest"
	$null = Install-ADDSForest -DomainName "lab.local" -ForestMode Win2008R2 -DomainMode Win2008R2  -SafeModeAdministratorPassword $safemodeadminpwd -Force 
	exit 
} 
write-buildlog "Starting Phase2.ps1"

$a = (Get-Host).UI.RawUI
$a.WindowTitle = "DC Build Automation"
$b = $a.WindowSize
$b.Height = $a.MaxWindowSize.Height - 1
$a.WindowSize = $b
Import-Module C:\windows\system32\WASP.dll
Select-Window -Title "DC Build Automation" | set-windowposition -left 75 -top 3

# Start DC configuration process
if (Test-Path B:\Automate\automate.ini) {
	$KMSIP = "0.0.0.0"
	$KMSIP = ((Select-String -SimpleMatch "KMSIP=" -Path "B:\Automate\automate.ini").line).substring(6)
	$AdminPWD = "VMware1!"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
	Write-BuildLog "Setup Users"
	NET ACCOUNTS /MAXPWAGE:UNLIMITED >> C:\AD-Users.log 2>> C:\Error.log
	net group "Domain Admins" vi-admin /add >> C:\AD-Users.log 2>> C:\Error.log
	net user  SVC_SRM $AdminPWD /add /Domain >> C:\AD-Users.log 2>> C:\Error.log
	net group "Domain Admins" SVC_SRM /add >> C:\AD-Users.log 2>> C:\Error.log
	net group "ESX Admins" /add >> C:\AD-Users.log 2>> C:\Error.log
	net group "ESX Admins" vi-admin /add >> C:\AD-Users.log 2>> C:\Error.log
	net user DomUser $AdminPWD /add /domain >> C:\AD-Users.log 2>> C:\Error.log 
	net user vi-admin $AdminPWD >> C:\AD-Users.log 2>> C:\Error.log
	net user JoinUser VMware1! /add /domain >> C:\AD-Users.log 2>> C:\Error.log 
	net group "DHCP Administrators" /add >> C:\AD-Users.log 2>> C:\Error.log
	net group "DHCP Users" /add >> C:\AD-Users.log 2>> C:\Error.log
	dsadd OU "ou=LAB,DC=lab,DC=local"
	dsadd OU "ou=Users,ou=LAB,DC=lab,DC=local"
	dsadd OU "ou=Groups,ou=LAB,DC=lab,DC=local"
	dsadd Group "cn=Lab Staff,ou=Groups,ou=LAB,DC=lab,DC=local" -desc "All staff of the LAB"
	dsadd OU "ou=Servers,ou=LAB,DC=lab,DC=local"
	dsadd OU "ou=Workstationsou=LAB,DC=lab,DC=local"
	dsadd user "cn=grace,ou=Users,ou=LAB,DC=lab,DC=local" -disabled no -pwd $AdminPWD -upn grace@lab.local -fn Grace -ln Hopper -display "Grace Hopper" -email grace@lab.local -memberof "cn=Lab Staff,ou=Groups,ou=LAB,DC=lab,DC=local"
	dsadd user "cn=ada,ou=Users,ou=LAB,DC=lab,DC=local" -disabled no -pwd $AdminPWD -upn ada@lab.local -fn Ada -ln Lovelace -display "Ada Lovelace" -email ada@lab.local -memberof "cn=Lab Staff,ou=Groups,ou=LAB,DC=lab,DC=local"
	dsadd user "cn=alan,ou=Users,ou=LAB,DC=lab,DC=local" -disabled no -pwd $AdminPWD -upn alan@lab.local -fn Alan -ln Turing -display "Alan Turing" -email alan@lab.local -memberof "cn=Lab Staff,ou=Groups,ou=LAB,DC=lab,DC=local"
	dsadd user "cn=charles,ou=Users,ou=LAB,DC=lab,DC=local" -disabled no -pwd $AdminPWD -upn charles@lab.local -fn Charles -ln Babbage -display "Charles Babbage" -email charles@lab.local -memberof "cn=Lab Staff,ou=Groups,ou=LAB,DC=lab,DC=local"
	Write-BuildLog "Change default local administrator password"
	net user administrator $AdminPWD
	B:\automate\_Common\Autologon administrator lab $AdminPWD
	$emailto = ((Select-String -SimpleMatch "emailto=" -Path "B:\Automate\automate.ini").line).substring(8)
	$SmtpServer = ((Select-String -SimpleMatch "SmtpServer=" -Path "B:\Automate\automate.ini").line).substring(11)
} Else {
	Write-BuildLog "Cannot find Automate.ini, this isn't a good sign"
}

Write-BuildLog "Installing 7-zip."
try {
	msiexec /qb /i B:\Automate\_Common\7z1805-x64.msi
	Write-BuildLog "Installation of 7-zip completed."
}
catch {
	Write-BuildLog "7-zip installation failed."
}
if (Test-Path "b:\VMware-PowerCLI.exe") {
	$PowCLIver = (Get-ChildItem B:\VMware-PowerCLI.exe).VersionInfo.ProductVersion.trim()
	if ($PowCLIver -eq "5.0.0.3501") {$PowCLIver = "5.0.0-3501"}
	Rename-Item B:\VMware-PowerCLI.exe B:\VMware-PowerCLI-$PowCLIver.exe
}

if (Test-Path "C:\Program Files\Tftpd64_SE\Tftpd64_SVC.exe") {
	Write-BuildLog "Found TFTP, not installing."
}Else {
	Write-BuildLog "Installing TFTP."
	Write-BuildLog "Creating C:\TFTP-Root directory."
	$null = $null = New-Item -Path C:\TFTP-Root -ItemType Directory -Force -Confirm:$false
	Write-BuildLog "Creating C:\Program Files\Tftpd64_SE directory."
	$null = $null = New-Item -Path "C:\Program Files\Tftpd64_SE" -ItemType Directory -Force -Confirm:$false
	xcopy B:\Automate\DC\Tftpd64_SE\*.* "C:\Program Files\Tftpd64_SE\" /s /c /y /q
	Start-Sleep -Seconds 30
	Start-Process "C:\Program Files\Tftpd64_SE\Tftpd64_SVC.exe" -ArgumentList "-install" -Wait
	Write-BuildLog "Setting TFTP service startup type and starting it."
	$null = Set-Service -Name "Tftpd32_svc" -StartupType "Automatic"
	$null = Start-Service -Name "Tftpd32_svc"
	Write-BuildLog "Copying B:\Automate\DC\TFTP-Root\ contents to C:\TFTP-Root."
	xcopy B:\Automate\DC\TFTP-Root\*.* C:\TFTP-Root\ /s /c /y /q
	Write-BuildLog "Installation of TFTP completed."
}

Write-BuildLog "Set root password for ESXi builds"
$TempContent = Get-Content B:\Automate\Hosts\esx1-4.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx1-4.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx1-5.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx1-5.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx2-4.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx2-4.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx2-4c.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx2-4c.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx2-5.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx2-5.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx3-5.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx3-5.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx4-5.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx4-5.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx11-5.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx11-5.cfg
$TempContent = Get-Content B:\Automate\Hosts\esx12-5.cfg |%{$_ -replace "VMware1!",$AdminPWD}
$TempContent | Set-Content B:\Automate\Hosts\esx12-5.cfg
 
Write-BuildLog "Checking for vSphere files..."
if (Test-Path "B:\ESXi67\*") {
	if ((Test-Path "B:\ESXi67\*.iso") -and !(Test-Path "B:\ESXi67\BOOT.CFG") ){
		Write-BuildLog "Extracting ESXi 6.7 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi67\ B:\ESXi67\*.iso >> C:\ExtractLog.txt
	}  
	Write-BuildLog "ESXi 6.7 found; creating C:\TFTP-Root\ESXi67 and copying ESXi 67 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi67 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi67\*.* C:\TFTP-Root\ESXi67\ /s /c /y /q
	xcopy b:\automate\DC\mboot.c32 C:\TFTP-Root\ESXi67\ /y /q
	Get-Content C:\TFTP-Root\ESXi67\BOOT.CFG | %{$_ -replace "/","/ESXi67/"} | Set-Content C:\TFTP-Root\ESXi67\Besx1-67.cfg
	Add-Content C:\TFTP-Root\ESXi67\Besx1-67.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-5.cfg"
	Get-Content C:\TFTP-Root\ESXi67\BOOT.CFG | %{$_ -replace "/","/ESXi67/"} | Set-Content C:\TFTP-Root\ESXi67\Besx2-67.cfg
	Add-Content C:\TFTP-Root\ESXi67\Besx2-67.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-5.cfg"
	Get-Content C:\TFTP-Root\ESXi67\BOOT.CFG | %{$_ -replace "/","/ESXi67/"} | Set-Content C:\TFTP-Root\ESXi67\Besx3-67.cfg
	Add-Content C:\TFTP-Root\ESXi67\Besx3-67.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx3-5.cfg"
	Get-Content C:\TFTP-Root\ESXi67\BOOT.CFG | %{$_ -replace "/","/ESXi67/"} | Set-Content C:\TFTP-Root\ESXi67\Besx4-67.cfg
	Add-Content C:\TFTP-Root\ESXi67\Besx4-67.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx4-5.cfg"
	Get-Content C:\TFTP-Root\ESXi67\BOOT.CFG | %{$_ -replace "/","/ESXi67/"} | Set-Content C:\TFTP-Root\ESXi67\BOOTM.CFG
	powershell C:\PXEMenuConfig.ps1 ESXi67
	Write-BuildLog "ESXi 6.7 added to TFTP and PXE menu."
	$esxi67 = $true
} else {
	$esxi67 = $false
}

if (Test-Path "B:\ESXi65\*") {
	if ((Test-Path "B:\ESXi65\*.iso") -and !(Test-Path "B:\ESXi65\BOOT.CFG") ){
		Write-BuildLog "Extracting ESXi 6.5 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi65\ B:\ESXi65\*.iso >> C:\ExtractLog.txt
	}  
	Write-BuildLog "ESXi 6.5 found; creating C:\TFTP-Root\ESXi65 and copying ESXi 65 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi65 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi65\*.* C:\TFTP-Root\ESXi65\ /s /c /y /q
	xcopy b:\automate\DC\mboot.c32 C:\TFTP-Root\ESXi65\ /y /q
	Get-Content C:\TFTP-Root\ESXi65\BOOT.CFG | %{$_ -replace "/","/ESXi65/"} | Set-Content C:\TFTP-Root\ESXi65\Besx1-65.cfg
	Add-Content C:\TFTP-Root\ESXi65\Besx1-65.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-5.cfg"
	Get-Content C:\TFTP-Root\ESXi65\BOOT.CFG | %{$_ -replace "/","/ESXi65/"} | Set-Content C:\TFTP-Root\ESXi65\Besx2-65.cfg
	Add-Content C:\TFTP-Root\ESXi65\Besx2-65.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-5.cfg"
	Get-Content C:\TFTP-Root\ESXi65\BOOT.CFG | %{$_ -replace "/","/ESXi65/"} | Set-Content C:\TFTP-Root\ESXi65\Besx3-65.cfg
	Add-Content C:\TFTP-Root\ESXi65\Besx3-65.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx3-5.cfg"
	Get-Content C:\TFTP-Root\ESXi65\BOOT.CFG | %{$_ -replace "/","/ESXi65/"} | Set-Content C:\TFTP-Root\ESXi65\Besx4-65.cfg
	Add-Content C:\TFTP-Root\ESXi65\Besx4-65.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx4-5.cfg"
	Get-Content C:\TFTP-Root\ESXi65\BOOT.CFG | %{$_ -replace "/","/ESXi65/"} | Set-Content C:\TFTP-Root\ESXi65\BOOTM.CFG
	powershell C:\PXEMenuConfig.ps1 ESXi65
	Write-BuildLog "ESXi 6.5 added to TFTP and PXE menu."
	$esxi65 = $true
} else {
	$esxi65 = $false
}

if (Test-Path "B:\ESXi60\*") {
	if ((Test-Path "B:\ESXi60\*.iso") -and !(Test-Path "B:\ESXi60\BOOT.CFG") ){
		Write-BuildLog "Extracting ESXi 6.0 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi60\ B:\ESXi60\*.iso >> C:\ExtractLog.txt
	}  
	Write-BuildLog "ESXi 6.0 found; creating C:\TFTP-Root\ESXi60 and copying ESXi 6.0 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi60 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi60\*.* C:\TFTP-Root\ESXi60 /s /c /y /q
	Get-Content C:\TFTP-Root\ESXi60\BOOT.CFG | %{$_ -replace "/","/ESXi60/"} | Set-Content C:\TFTP-Root\ESXi60\Besx1-60.cfg
	Add-Content C:\TFTP-Root\ESXi60\\Besx1-60.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-5.cfg"
	Get-Content C:\TFTP-Root\ESXi60\BOOT.CFG | %{$_ -replace "/","/ESXi60/"} | Set-Content C:\TFTP-Root\ESXi60\Besx2-60.cfg
	Add-Content C:\TFTP-Root\ESXi60\\Besx2-60.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-5.cfg"
	Get-Content C:\TFTP-Root\ESXi60\BOOT.CFG | %{$_ -replace "/","/ESXi60/"} | Set-Content C:\TFTP-Root\ESXi60\Besx3-60.cfg
	Add-Content C:\TFTP-Root\ESXi60\Besx3-60.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx3-5.cfg"
	Get-Content C:\TFTP-Root\ESXi60\BOOT.CFG | %{$_ -replace "/","/ESXi60/"} | Set-Content C:\TFTP-Root\ESXi60\Besx4-60.cfg
	Add-Content C:\TFTP-Root\ESXi60\\Besx4-60.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx4-5.cfg"
	Get-Content C:\TFTP-Root\ESXi60\BOOT.CFG | %{$_ -replace "/","/ESXi60/"} | Set-Content C:\TFTP-Root\ESXi60\BOOTM.CFG
	powershell C:\PXEMenuConfig.ps1 ESXi60
	Write-BuildLog "ESXi 6.0 added to TFTP and PXE menu."
	$esxi60 = $true
} else {
	$esxi60 = $false
}

if (Test-Path "B:\ESXi55\*") {
	if ((Test-Path "B:\ESXi55\*.iso")  -and !(Test-Path "B:\ESXi55\BOOT.CFG") ){
		Write-BuildLog "Extracting ESXi 5.5 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi55\ B:\ESXi55\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESXi 5.5 found; creating C:\TFTP-Root\ESXi55 and copying ESXi 5.5 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi55 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi55\*.* C:\TFTP-Root\ESXi55 /s /c /y /q
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\Besx1-55.cfg
	Add-Content C:\TFTP-Root\ESXi55\\Besx1-55.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-5.cfg"
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\Besx2-55.cfg
	Add-Content C:\TFTP-Root\ESXi55\\Besx2-55.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-5.cfg"
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\Besx3-55.cfg
	Add-Content C:\TFTP-Root\ESXi55\Besx3-55.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx3-5.cfg"
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\Besx4-55.cfg
	Add-Content C:\TFTP-Root\ESXi55\\Besx4-55.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx4-5.cfg"
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\BOOTM.CFG
	powershell C:\PXEMenuConfig.ps1 ESXi55
	Write-BuildLog "ESXi 5.5 added to TFTP and PXE menu."
	$esxi55 = $true
} else {
	$esxi55 = $false
}

if (Test-Path "B:\ESXi51\*") {
	if ((Test-Path "B:\ESXi51\*.iso")  -and !(Test-Path "B:\ESXi51\BOOT.CFG") ) {
		Write-BuildLog "Extracting ESXi 5.1 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi51\ B:\ESXi51\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESXi 5.1 found; creating C:\TFTP-Root\ESXi51 and copying ESXi 5.1 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi51 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi51\*.* C:\TFTP-Root\ESXi51 /s /c /y /q
	Get-Content C:\TFTP-Root\ESXi51\BOOT.CFG | %{$_ -replace "/","/ESXi51/"} | Set-Content C:\TFTP-Root\ESXi51\Besx1-5.cfg
	Add-Content C:\TFTP-Root\ESXi51\Besx1-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-5.cfg"
	Get-Content C:\TFTP-Root\ESXi51\BOOT.CFG | %{$_ -replace "/","/ESXi51/"} | Set-Content C:\TFTP-Root\ESXi51\Besx2-5.cfg
	Add-Content C:\TFTP-Root\ESXi51\Besx2-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-5.cfg"
	Get-Content C:\TFTP-Root\ESXi51\BOOT.CFG | %{$_ -replace "/","/ESXi51/"} | Set-Content C:\TFTP-Root\ESXi51\Besx3-5.cfg
	Add-Content C:\TFTP-Root\ESXi51\Besx3-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx3-5.cfg"
	Get-Content C:\TFTP-Root\ESXi51\BOOT.CFG | %{$_ -replace "/","/ESXi51/"} | Set-Content C:\TFTP-Root\ESXi51\Besx4-5.cfg
	Add-Content C:\TFTP-Root\ESXi51\Besx4-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx4-5.cfg"
	Get-Content C:\TFTP-Root\ESXi51\BOOT.CFG | %{$_ -replace "/","/ESXi51/"} | Set-Content C:\TFTP-Root\ESXi51\BOOTM.CFG
	powershell C:\PXEMenuConfig.ps1 ESXi51
	Write-BuildLog "ESXi 5.1 added to TFTP and PXE menu."
	$esxi51 = $true
} else {
	$esxi51 = $false
}

if (Test-Path "B:\ESXi50\*") {
	if ((Test-Path "B:\ESXi50\*.iso")  -and !(Test-Path "B:\ESXi50\BOOT.CFG") ) {
		Write-BuildLog "Extracting ESXi 5.0 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi50\ B:\ESXi50\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESXi 5.0 found; creating C:\TFTP-Root\ESXi50 and copying ESXi 5.0 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi50 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi50\*.* C:\TFTP-Root\ESXi50 /s /c /y /q
	Get-Content C:\TFTP-Root\ESXi50\BOOT.CFG | %{$_ -replace "/","/ESXi50/"} | Set-Content C:\TFTP-Root\ESXi50\Besx1-5.cfg
	Add-Content C:\TFTP-Root\ESXi50\Besx1-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-5.cfg"
	Get-Content C:\TFTP-Root\ESXi50\BOOT.CFG | %{$_ -replace "/","/ESXi50/"} | Set-Content C:\TFTP-Root\ESXi50\Besx2-5.cfg
	Add-Content C:\TFTP-Root\ESXi50\Besx2-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-5.cfg"
	Get-Content C:\TFTP-Root\ESXi50\BOOT.CFG | %{$_ -replace "/","/ESXi50/"} | Set-Content C:\TFTP-Root\ESXi50\Besx3-5.cfg
	Add-Content C:\TFTP-Root\ESXi50\Besx3-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx3-5.cfg"
	Get-Content C:\TFTP-Root\ESXi50\BOOT.CFG | %{$_ -replace "/","/ESXi50/"} | Set-Content C:\TFTP-Root\ESXi50\Besx4-5.cfg
	Add-Content C:\TFTP-Root\ESXi50\Besx4-5.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx4-5.cfg"
	Get-Content C:\TFTP-Root\ESXi50\BOOT.CFG | %{$_ -replace "/","/ESXi50/"} | Set-Content C:\TFTP-Root\ESXi50\BOOTM.CFG
	powershell C:\PXEMenuConfig.ps1 ESXi50
	Write-BuildLog "ESXi 5.0 added to TFTP and PXE menu."
	$esxi50 = $true
} else {
	$esxi50 = $false
}

if (Test-Path "B:\ESXi41\*") {
	if ((Test-Path "B:\ESXi41\*.iso")  -and !(Test-Path "B:\ESXi41\BOOT.CAT") ) {
		Write-BuildLog "Extracting ESXi 4.1 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi41\ B:\ESXi41\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESXi 4.1 found; creating C:\TFTP-Root\ESXi41 and copying ESXi 4.1 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi41 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi41\vmkboot.gz C:\TFTP-Root\ESXi41 /s /c /y /q
	xcopy B:\ESXi41\vmkernel.gz C:\TFTP-Root\ESXi41 /s /c /y /q
	xcopy B:\ESXi41\sys.vgz C:\TFTP-Root\ESXi41 /s /c /y /q
	xcopy B:\ESXi41\cim.vgz C:\TFTP-Root\ESXi41 /s /c /y /q
	xcopy B:\ESXi41\ienviron.vgz C:\TFTP-Root\ESXi41 /s /c /y /q
	xcopy B:\ESXi41\install.vgz C:\TFTP-Root\ESXi41 /s /c /y /q
	xcopy B:\ESXi41\mboot.c32 C:\TFTP-Root\ESXi41 /s /c /y /q
	powershell C:\PXEMenuConfig.ps1 ESXi41
	Write-BuildLog "ESXi 4.1 added to TFTP and PXE menu."
	$esxi41 = $true
} else {
	$esxi41 = $false
}

if (Test-Path "B:\ESX41\*") {
	if ((Test-Path "B:\ESX41\*.iso")  -and !(Test-Path "B:\ESX41\packages.xml") ) {
		Write-BuildLog "Extracting ESX 4.1 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESX41\ B:\ESX41\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESX 4.1 found; creating C:\TFTP-Root\ESX41 and copying ESX 4.1 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESX41 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESX41\isolinux\vmlinuz C:\TFTP-Root\ESX41 /s /c /y /q
	xcopy B:\ESX41\isolinux\initrd.img C:\TFTP-Root\ESX41 /s /c /y /q
	powershell C:\PXEMenuConfig.ps1 ESX41
	Write-BuildLog "ESX 4.1 added to TFTP and PXE menu."
	$esx41 = $true
} else {
	$esx41 = $false
}

if (!($esx41 -or $esxi41 -or $esxi50 -or $esxi51 -or $esxi55 -or $esxi60 -or $esxi65 -or $esxi67)) {
	Write-BuildLog "No ESX or ESXi files found."
	Write-BuildLog "Is the NAS VM running? If so, make sure the Build share is available and populated."
	Write-BuildLog "Restart this machine when Build share is available; build will proceed after restart."
	exit
}

if (Test-Path "B:\gParted\*") {
	Write-BuildLog "Adding gParted to PXE build"
	$null = $null = New-Item -Path C:\TFTP-Root\gParted -ItemType Directory -Force -Confirm:$false
	xcopy B:\gParted\*.* C:\TFTP-Root\gParted /s /c /y /q
			Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL gParted
  MENU LABEL gParted utility
  kernel gparted/vmlinuz
  append initrd=gparted/initrd.img boot=live config components union=overlay username=user noswap noeject ip= vga=788 fetch=tftp://192.168.199.4/gparted/filesystem.squashfs
"@
}

Write-BuildLog "Checking for vCenter files..."
if (Test-Path "B:\VIM_67\*") {
	if ((Test-Path "B:\VIM_67\*.iso") -and !(Test-Path "B:\VIM_67\autorun.exe")){
		Write-BuildLog "Extracting vCenter 6.7 installer from ISO."
		start-process "C:\Program Files\7-Zip\7z.exe" -ArgumentList " x -r -y -aoa -oB:\VIM_67\ B:\VIM_67\*.iso" -RedirectStandardOutput C:\ExtractLog.txt -wait
		remove-item "B:\VIM_67\*.iso"
	}
	Write-BuildLog "vCenter 6.7 found."
	$vCenter67 = $true
} else {
	$vCenter67 = $false
}
if (Test-Path "B:\VIM_65\*") {
	if ((Test-Path "B:\VIM_65\*.iso") -and !(Test-Path "B:\VIM_65\autorun.exe")){
		Write-BuildLog "Extracting vCenter 6.5 installer from ISO."
		start-process "C:\Program Files\7-Zip\7z.exe" -ArgumentList " x -r -y -aoa -oB:\VIM_65\ B:\VIM_65\*.iso" -RedirectStandardOutput C:\ExtractLog.txt -wait
		remove-item "B:\VIM_65\*.iso"
	}
	Write-BuildLog "vCenter 6.5 found."
	$vCenter65 = $true
} else {
	$vCenter65 = $false
}
if (Test-Path "B:\VIM_60\*") {
	if ((Test-Path "B:\VIM_60\*.iso") -and !(Test-Path "B:\VIM_60\autorun.exe")){
		Write-BuildLog "Extracting vCenter 6.0 installer from ISO."
		start-process "C:\Program Files\7-Zip\7z.exe" -ArgumentList " x -r -y -aoa -oB:\VIM_60\ B:\VIM_60\*.iso" -RedirectStandardOutput C:\ExtractLog.txt -wait
		remove-item "B:\VIM_60\*.iso"
		}
	Write-BuildLog "vCenter 6.0 found."
	$vCenter60 = $true
} else {
	$vCenter60 = $false
}
if (Test-Path "B:\VIM_55\*") {
	if ((Test-Path "B:\VIM_55\*.iso") -and !(Test-Path "B:\VIM_55\autorun.exe")){
		Write-BuildLog "Extracting vCenter 5.5 installer from ISO."
		start-process "C:\Program Files\7-Zip\7z.exe" -ArgumentList " x -r -y -aoa -oB:\VIM_55\ B:\VIM_55\*.iso" -RedirectStandardOutput C:\ExtractLog.txt -wait
		remove-item "B:\VIM_55\*.iso"
	}
	Write-BuildLog "vCenter 5.5 found."
	$vCenter55 = $true
} else {
	$vCenter55 = $false
}
if (Test-Path "B:\VIM_51\*") {
	if ((Test-Path "B:\VIM_51\*.iso") -and !(Test-Path "B:\VIM_51\autorun.exe")) {
		Write-BuildLog "Extracting vCenter 5.1 installer from ISO."
		start-process "C:\Program Files\7-Zip\7z.exe" -ArgumentList " x -r -y -aoa -oB:\VIM_51\ B:\VIM_51\*.iso" -RedirectStandardOutput C:\ExtractLog.txt -wait
		remove-item "B:\VIM_51\*.iso"
	}
	Write-BuildLog "vCenter 5.1 found."
	$vCenter51 = $true
} else {
	$vCenter51 = $false
}

if (Test-Path "B:\VIM_50\*") {
	if ((Test-Path "B:\VIM_50\*.iso") -and !(Test-Path "B:\VIM_50\autorun.exe")) {
		Write-BuildLog "Extracting vCenter 5.0 installer from ISO."
		start-process "C:\Program Files\7-Zip\7z.exe" -ArgumentList " x -r -y -aoa -oB:\VIM_50\ B:\VIM_50\*.iso" -RedirectStandardOutput C:\ExtractLog.txt -wait
		remove-item "B:\VIM_50\*.iso"
	}
	Write-BuildLog "vCenter 5.0 found."
	$vCenter50 = $true
} else {
	$vCenter50 = $false
}

if (Test-Path "B:\VIM_41\*") {
	if ((Test-Path "B:\VIM_41\*.iso") -and !(Test-Path "B:\VIM_41\autorun.exe")) {
		Write-BuildLog "Extracting vCenter 4.1 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VIM_41\ B:\VIM_41\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "vCenter 4.1 found."
	$vCenter41 = $true
} else {
	$vCenter41 = $false
}

if (!($vCenter41 -or $vCenter50 -or $vCenter51 -or $vCenter55 -or $vCenter60 -or $vCenter65 -or $vCenter67)) {
	Write-BuildLog "No vCenter installation files found on Build share."
	Write-BuildLog "Is the NAS VM running? If so, make sure the Build share is available and populated."
	Write-BuildLog "Restart this machine when Build share is available; build will proceed after restart."
	exit
}

if (!($vCenter67 -and $esxi67)) {
	Write-BuildLog "vSphere 6.7 installation requirements not met."
	$vSphere67 = $false
} else {
	$vSphere67 = $true
}
if (!($vCenter65 -and $esxi65)) {
	Write-BuildLog "vSphere 6.5 installation requirements not met."
	$vSphere65 = $false
} else {
	$vSphere65 = $true
}
if (!($vCenter60 -and $esxi60)) {
	Write-BuildLog "vSphere 6.0 installation requirements not met."
	$vSphere60 = $false
} else {
	$vSphere60 = $true
}
if (!($vCenter55 -and $esxi55)) {
	Write-BuildLog "vSphere 5.5 installation requirements not met."
	$vSphere55 = $false
} else {
	$vSphere55 = $true
}
if (!($vCenter51 -and $esxi51)) {
	Write-BuildLog "vSphere 5.1 installation requirements not met."
	$vSphere51 = $false
} else {
	$vSphere51 = $true
}
if (!($vCenter50 -and $esxi50)) {
	Write-BuildLog "vSphere 5.0 installation requirements not met."
	$vSphere50 = $false
} else {
	$vSphere50 = $true
}
if (!($vCenter41 -and ($esxi41 -or $esx41))) {
	Write-BuildLog "vSphere 4.1 installation requirements not met."
	$vSphere41 = $false
} else {
	$vSphere41 = $true
}

if (!($vSphere41 -or $vSphere50 -or $vSphere51 -or $vSphere55 -or $vSphere60 -or $vSphere65 -or $vSphere67)) {
	Write-BuildLog "Matching vCenter & ESXi distributions not found. Please check the Build share."
}

$PCLIver = deployPowerCLI

Write-BuildLog "Install, Authorise and configure DHCP"
If ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62) {
	$null = Add-WindowsFeature -IncludeManagementTools dhcp
}
Write-BuildLog "Create DNS Records"
dnscmd localhost /config /UpdateOptions 0x0 >> C:\DNS.log
dnscmd localhost /config lab.local /allowupdate 1 >> C:\DNS.log
dnscmd localhost /zoneadd 199.168.192.in-addr.arpa /DsPrimary >> C:\DNS.log
dnscmd localhost /zoneadd 201.168.192.in-addr.arpa /DsPrimary >> C:\DNS.log
dnscmd localhost /config 199.168.192.in-addr.arpa /allowupdate 1 >> C:\DNS.log
dnscmd localhost /config 201.168.192.in-addr.arpa /allowupdate 1 >> C:\DNS.log
dnscmd localhost /resetforwarders 192.168.199.2 /slave >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local GW A 192.168.199.2 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local VC A 192.168.199.5 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local VMA A 192.168.199.6 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local NAS A 192.168.199.7 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local Host1 A 192.168.199.11 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local Host2 A 192.168.199.12 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local Host3 A 192.168.199.13 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local Host4 A 192.168.199.14 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local CS1 A 192.168.199.33 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local CS2 A 192.168.199.34 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local SS A 192.168.199.35 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local v1 A 192.168.199.36 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local vbr A 192.168.199.37 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local DC2 A 192.168.201.4 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local VC2 A 192.168.201.5 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local Host11 A 192.168.201.11 >> C:\DNS.log
dnscmd localhost /RecordAdd lab.local Host12 A 192.168.201.12 >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 2 PTR GW.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 5 PTR VC.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 6 PTR VMA.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 7 PTR NAS.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 11 PTR Host1.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 12 PTR Host2.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 13 PTR Host3.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 14 PTR Host4.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 33 PTR cs1.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 34 PTR cs2.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 35 PTR SS.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 36 PTR v1.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 199.168.192.in-addr.arpa 37 PTR vbr.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 201.168.192.in-addr.arpa 4 PTR DC2.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 201.168.192.in-addr.arpa 5 PTR VC2.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 201.168.192.in-addr.arpa 11 PTR Host11.lab.local >> C:\DNS.log
dnscmd localhost /RecordAdd 201.168.192.in-addr.arpa 12 PTR Host12.lab.local >> C:\DNS.log
If (($KMSIP.Split("."))[0] -ne "0") {
	Write-BuildLog "Setting DNS record for external KMS server IP address to $KMSIP according to automate.ini."
	dnscmd DC /RecordAdd lab.local _vlmcs._tcp SRV 0 10 1688 $KMSIP >> C:\DNS.log
}
Write-BuildLog "Setup DHCP scope"
netsh dhcp server \\dc.lab.local set dnscredentials administrator lab.local $AdminPWD
netsh dhcp add server dc.lab.local 192.168.199.4 >> C:\DNS.log
netsh dhcp server \\dc.lab.local add scope 192.168.199.0 255.255.255.0 "Lab scope" "Scope for lab.local"  >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 add iprange 192.168.199.100 192.168.199.199 >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set optionvalue 003 IPADDRESS 192.168.199.2 >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set optionvalue 005 IPADDRESS 192.168.199.4 >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set optionvalue 006 IPADDRESS 192.168.199.4 >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set optionvalue 015 STRING lab.local >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set optionvalue 066 STRING 192.168.199.4 >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set optionvalue 067 STRING pxelinux.0 >> C:\DNS.log
netsh dhcp server \\dc.lab.local scope 192.168.199.0 set state 1 >> C:\DNS.log
Write-BuildLog "Checking available SQL Express versions."
$null = New-Item -Path C:\temp -ItemType Directory -Force -Confirm:$false
if (Test-Path "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe") {
	Write-BuildLog "SQL Server Install found, not installing"
}Else {
	if ((Test-Path "B:\VIM_67\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") -and ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62)) {
		$vc67SQL = $true
		Write-BuildLog "SQL Server 2012 Express SP2 for vCenter 6.7 found; installing."
		copy B:\VIM_67\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		do {
			start-sleep 10
		} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
		del c:\TEMP\SQLEXPR_x64_ENU.EXE 
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC\SQLTCP.reg
	} elseif ((Test-Path "B:\VIM_65\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") -and ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62)) {
		$vc65SQL = $true
		Write-BuildLog "SQL Server 2012 Express SP2 for vCenter 6.5 found; installing."
		copy B:\VIM_65\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		do {
			start-sleep 10
		} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
		del c:\TEMP\SQLEXPR_x64_ENU.EXE 
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC\SQLTCP.reg
	} elseif ((Test-Path "B:\VIM_60\redist\SQLEXPR\SQLEXPR_x64_ENU.exe")  -and ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62)) {
		$vc6SQL = $true
		Write-BuildLog "SQL Server 2012 Express SP2 for vCenter 6.0 found; installing."
		copy B:\VIM_60\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		do {
			start-sleep 10
		} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
		del c:\TEMP\SQLEXPR_x64_ENU.EXE 
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\110\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_55\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
		$vc5SQL = $true
		Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.5 found; installing."
		copy B:\VIM_55\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		do {
			start-sleep 10
		} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
		del c:\TEMP\SQLEXPR_x64_ENU.EXE 
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
		$vc5SQL = $true
		Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 found; installing."
		copy B:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
		$vc5SQL = $true
		Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
		copy B:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments =  '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE") {
		copy B:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE C:\temp
		Write-BuildLog "SQL Server 2005 Express for vCenter 4.1 found; installing."
		$Arguments = '/qb INSTANCENAME=SQLExpress ADDLOCAL=ALL SAPWD="VMware1!" SQLACCOUNT="Lab\vi-admin" SQLPASSWORD="' + $AdminPWD + '" AGTACCOUNT="Lab\vi-admin" AGTPASSWORD="' + $AdminPWD + '" SQLBROWSERACCOUNT="Lab\vi-admin" SQLBROWSERPASSWORD="' + $AdminPWD + '" DISABLENETWORKPROTOCOLS=0'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files (x86)\Microsoft SQL Server\90\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc\SQLEXPRESS -i B:\Automate\DC\MakeDB41.txt"  -RedirectStandardOutput c:\sqllog.txt -Wait; type C:\sqllog.txt  | add-content C:\buildlog.txt
		regedit -s B:\Automate\DC\SQLTCP.reg
	} else {
		$vc67SQL = $false
		$vc65SQL = $false
		$vc6SQL = $false
		$vc5SQL = $false
		$vc4SQL = $false
		Write-BuildLog "No compatible SQL Express installers found. Please verify that all contents of vCenter ISO are copied into the correct folder on the Build share."
		Read-Host "Press <ENTER> to exit"
		exit
	}
}
if (Test-Path B:\sqlmsssetup.exe) {
	Rename-Item B:\sqlmsssetup.exe SQLManagementStudio_x64_ENU.exe
}
If (((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -le 61)) {
	Write-BuildLog "Doing Windows Server 2008 specific build actions"
	if (Test-Path B:\SQLManagementStudio_x64_ENU.exe) {
		if ( (!(Get-ChildItem B:\SQLManagementStudio_x64_ENU.exe).VersionInfo.ProductVersion -like "10.50.2500*") -and ($vc67SQL -or$vc65SQL -or $vc6SQL -or $vc5SQL -or $vc4SQL)) {
			Write-BuildLog "The version of SQL Management Studio on the Build share is incompatible with SQL Server 2008 Express R2 SP1. Please see ReadMe.html on the Build share."
		} else {
			Write-BuildLog "SQL Management Studio found; installing."
			Start-Process B:\SQLManagementStudio_x64_ENU.exe -ArgumentList "/ACTION=INSTALL /IACCEPTSQLSERVERLICENSETERMS /FEATURES=Tools /q" -Wait -Verb RunAs
		}
	} else { Write-BuildLog "SQL Management Studio not found (optional)."}
	Write-BuildLog "Setup IIS on Windows 2008"
	Start-Process pkgmgr -ArgumentList '/quiet /l:C:\IIS_Install_Log.txt /iu:IIS-WebServerRole;IIS-WebServer;IIS-CommonHttpFeatures;IIS-StaticContent;IIS-DefaultDocument;IIS-DirectoryBrowsing;IIS-HttpErrors;IIS-HttpRedirect;IIS-ApplicationDevelopment;IIS-ASPNET;IIS-NetFxExtensibility;IIS-ASP;IIS-CGI;IIS-ISAPIExtensions;IIS-ISAPIFilter;IIS-ServerSideIncludes;IIS-HealthAndDiagnostics;IIS-HttpLogging;IIS-LoggingLibraries;IIS-RequestMonitor;IIS-HttpTracing;IIS-CustomLogging;IIS-ODBCLogging;IIS-Security;IIS-BasicAuthentication;IIS-WindowsAuthentication;IIS-DigestAuthentication;IIS-ClientCertificateMappingAuthentication;IIS-IISCertificateMappingAuthentication;IIS-URLAuthorization;IIS-RequestFiltering;IIS-IPSecurity;IIS-Performance;IIS-HttpCompressionStatic;IIS-HttpCompressionDynamic;IIS-WebServerManagementTools;IIS-ManagementConsole;IIS-ManagementScriptingTools;IIS-ManagementService;IIS-IIS6ManagementCompatibility;IIS-Metabase;IIS-WMICompatibility;IIS-LegacyScripts;IIS-LegacySnapIn;IIS-FTPPublishingService;IIS-FTPServer;IIS-FTPManagement;WAS-WindowsActivationService;WAS-ProcessModel;WAS-NetFxEnvironment;WAS-ConfigurationAPI' -Wait 
	Write-BuildLog "Setup Certificate Authority & web enrollment."	
	if (Test-Path B:\Automate\DC\setupca.vbs) {
		copy B:\Automate\DC\setupca.vbs C:\temp
		#Cscript C:\temp\setupca.vbs /ie /iw /sn LabCA /sk 4096 /sp "RSA#Microsoft Software Key Storage Provider" /sa SHA256 >> c:\SetupCA.log
		Cscript C:\temp\setupca.vbs /ie /sn LabCA /sk 4096 /sp "RSA#Microsoft Software Key Storage Provider" /sa SHA256 >> c:\SetupCA.log
	}
}
If (((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62)) {
	Write-BuildLog "Doing Windows Server 2012 and 2016 specific build actions"
	Write-BuildLog "Disabling autorun of ServerManager at logon."
	Start-Process schtasks -ArgumentList ' /Change /TN "\Microsoft\Windows\Server Manager\ServerManager" /DISABLE'  -Wait -Verb RunAs
	Write-BuildLog "Disabling screen saver"
	set-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name ScreenSaveActive -value 0
	Write-BuildLog "Installing.Net Framework 3.5"
	$null = Install-WindowsFeature Net-Framework-Core  -source D:\Sources\sxs
	if (Test-Path B:\SQLManagementStudio_x64_ENU.exe) {
		if ( (!(Get-ChildItem B:\SQLManagementStudio_x64_ENU.exe).VersionInfo.ProductVersion -like "10.50.2500*") -and ($vc6SQL -or $vc5SQL -or $vc4SQL)) {
			Write-BuildLog "The version of SQL Management Studio on the Build share is incompatible with SQL Server 2008 Express R2 SP1. Please see ReadMe.html on the Build share."
		} else {
			Write-BuildLog "SQL Management Studio found; installing."
			Start-Process B:\SQLManagementStudio_x64_ENU.exe -ArgumentList "/ACTION=INSTALL /IACCEPTSQLSERVERLICENSETERMS /FEATURES=Tools /q" -Wait -Verb RunAs
		}
	} else { Write-BuildLog "SQL Management Studio not found (optional)."}
	Write-BuildLog "Setup IIS on Windows 2012 or 2016"
	import-module servermanager
	If (Test-Path "D:\Sources\sxs\*") {$null = add-windowsfeature web-server -includeallsubfeature -source D:\Sources\sxs}
	If (Test-Path "E:\Sources\sxs\*") {$null = add-windowsfeature web-server -includeallsubfeature -source E:\Sources\sxs}
	Import-Module WebAdministration
	New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
	Write-BuildLog "Setup Certificate Authority & web enrollment."	
	Import-Module ServerManager
	$null = Add-WindowsFeature AD-Certificate, Adcs-Cert-Authority, Adcs-Enroll-Web-Pol, Adcs-Enroll-Web-Svc, Adcs-Web-Enrollment , Adcs-Device-Enrollment , Adcs-Online-Cert -IncludeManagementTools
	copy B:\Automate\DC\setupca.vbs C:\temp
	Cscript C:\temp\setupca.vbs /is /iw /sn LabCA /sk 4096 /sp "RSA#Microsoft Software Key Storage Provider" /sa SHA256 >> c:\SetupCA.log
	import-module webadministration
	$Thumb = (dir cert:\localmachine\my | where {$_.Subject -eq "CN=LabCA"} | Select Thumbprint).Thumbprint
	get-item cert:\localmachine\my\$Thumb | new-item IIS:\SslBindings\0.0.0.0!443	
	certutil -dsaddtemplate b:\automate\DC\VMware-SSL.txt
}
Write-BuildLog "Make Win32Time authoritative for NTP time."
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Config /v AnnounceFlags /t REG_DWORD /d 0x05 /f
w32tm /config /manualpeerlist:pool.ntp.org /syncfromflags:manual /reliable:yes /update

Write-BuildLog "Clear System eventlog, erors to here are spurious"
Clear-EventLog -LogName System -confirm:$False

Write-BuildLog "Setup Default web page."
xcopy B:\Automate\DC\WWWRoot\*.* C:\inetpub\wwwroot\ /s /c /y /q

Write-BuildLog "Cleanup and creating Desktop shortcuts."
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /f
wscript B:\Automate\DC\Shortcuts.vbs

browserAndFlash

if (Test-Path B:\Automate\automate.ini) {
	$timezone = ((Select-String -SimpleMatch "TZ=" -Path "B:\Automate\automate.ini").line).substring(3)
	Write-BuildLog "Setting time zone to $timezone according to automate.ini."
	tzutil /s "$timezone"
}
Write-BuildLog "Checking for VMware Tools..."
if (Test-Path -Path "B:\VMTools\setup*") {
	Write-BuildLog "VMware Tools found."
	$vmtools = $true
} else {
	if (Test-Path "B:\VMTools\windows.iso") {
		Write-BuildLog "Extracting VMware Tools from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ B:\VMTools\windows.iso >> C:\ExtractLog.txt
		$vmtools = $true
	}
	Else {
		cd c:\temp
		$vcinstall = ((Select-String -SimpleMatch "VCInstall=" -Path "B:\Automate\automate.ini").line).substring(10)
		switch ($vcinstall) {
			67 {
			B:\Automate\_Common\wget.exe -nd http://packages.vmware.com/tools/esx/6.0/windows/VMware-tools-windows-9.10.0-2476743.iso --no-check-certificate -awget.log
			. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ c:\temp\VMware-tools-windows-9.10.0-2476743.iso >> C:\ExtractLog.txt
			Write-BuildLog "VMware Tools V6.0 Downloaded and extracted to build share."
			}
			65 {
			B:\Automate\_Common\wget.exe -nd http://packages.vmware.com/tools/esx/6.0/windows/VMware-tools-windows-9.10.0-2476743.iso --no-check-certificate -awget.log
			. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ c:\temp\VMware-tools-windows-9.10.0-2476743.iso >> C:\ExtractLog.txt
			Write-BuildLog "VMware Tools V6.0 Downloaded and extracted to build share."
			}
			60 {
			B:\Automate\_Common\wget.exe -nd http://packages.vmware.com/tools/esx/6.0/windows/VMware-tools-windows-9.10.0-2476743.iso --no-check-certificate -awget.log
			. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ c:\temp\VMware-tools-windows-9.10.0-2476743.iso >> C:\ExtractLog.txt
			Write-BuildLog "VMware Tools V6.0 Downloaded and extracted to build share."
			} 	55 {
			B:\Automate\_Common\wget.exe -nd http://packages.vmware.com/tools/esx/5.5u2/windows/VMware-tools-windows-9.4.10-2068191.iso --no-check-certificate -awget.log
			. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ c:\temp\VMware-tools-windows-9.4.10-2068191.iso >> C:\ExtractLog.txt
			Write-BuildLog "VMware Tools V5.5u2 Downloaded and extracted to build share."
			}	51 {
			B:\Automate\_Common\wget.exe -nd http://packages.vmware.com/tools/esx/5.1u3/windows/x64/VMware-tools-windows-9.0.15-2323214.iso --no-check-certificate -awget.log
			. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ c:\temp\VMware-tools-windows-9.0.15-2323214.iso >> C:\ExtractLog.txt
			Write-BuildLog "VMware Tools V5.1u3 Downloaded and extracted to build share."
			}	50 {
			B:\Automate\_Common\wget.exe -nd http://packages.vmware.com/tools/esx/5.0u3/windows/x64/VMware-tools-windows-8.6.11-1310128.iso --no-check-certificate -awget.log
			. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ c:\temp\VMware-tools-windows-8.6.11-1310128.iso >> C:\ExtractLog.txt
			Write-BuildLog "VMware Tools V5.0u3 Downloaded and extracted to build share."
			}
		}
	}
	if (Test-Path -Path "B:\VMTools\setup*") {
		Write-BuildLog "VMware Tools found."
		$vmtools = $true
	}
}
if (($vmtools) -and (-Not (Test-Path "C:\Program Files\VMware\VMware Tools\VMwareToolboxCmd.exe"))) {
	Write-BuildLog "Installing VMware tools, build complete after reboot."
	Write-BuildLog "(Re)build vCenter next."
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
	Start-Process B:\VMTools\setup64.exe -ArgumentList '/s /v "/qn"' -verb RunAs -Wait
	Start-Sleep -Seconds 300
}
Read-Host "Press <ENTER> to exit"