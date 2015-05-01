if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun Build.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}

# Start DC configuration process

if (Test-Path B:\Automate\automate.ini) {
	$AdminPWD = "VMware1!"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
	B:\automate\_Common\Autologon administrator lab $AdminPWD
}
Write-BuildLog "Correct DNS client settings"
$wmi = Get-WmiObject win32_networkadapterconfiguration -filter "ipenabled = 'true'"
$null = $wmi.SetDNSServerSearchOrder("192.160.201.4")

Write-BuildLog "Installing 7-zip."
try {
	msiexec /qb /i B:\Automate\_Common\7z920-x64.msi
	Write-BuildLog "Installation of 7-zip completed."
}
catch {
	Write-BuildLog "7-zip installation failed."
}
Write-BuildLog ""

Write-BuildLog "Installing TFTP."
Write-BuildLog "Creating C:\TFTP-Root directory."
$null = $null = New-Item -Path C:\TFTP-Root -ItemType Directory -Force -Confirm:$false
Write-BuildLog "Creating C:\Program Files\Tftpd64_SE directory."
$null = $null = New-Item -Path "C:\Program Files\Tftpd64_SE" -ItemType Directory -Force -Confirm:$false
xcopy B:\Automate\DC2\Tftpd64_SE\*.* "C:\Program Files\Tftpd64_SE\" /s /c /y /q
Start-Sleep -Seconds 30
Start-Process "C:\Program Files\Tftpd64_SE\Tftpd64_SVC.exe" -ArgumentList "-install" -Wait
Write-BuildLog "Setting TFTP service startup type and starting it."
$null = Set-Service -Name "Tftpd32_svc" -StartupType "Automatic"
$null = Start-Service -Name "Tftpd32_svc"
Write-BuildLog "Copying B:\Automate\DC2\TFTP-Root\ contents to C:\TFTP-Root."
xcopy B:\Automate\DC2\TFTP-Root\*.* C:\TFTP-Root\ /s /c /y /q
Write-BuildLog "Installation of TFTP completed."
Write-BuildLog ""

Write-BuildLog "Checking for VMware Tools..."
if (Test-Path -Path "B:\VMTools\setup*") {
	Write-BuildLog "VMware Tools found."
	$vmtools = $true
} else {
	if (Test-Path "B:\VMTools\windows.iso") {
		Write-BuildLog "Extracting VMware Tools from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\VMtools\ B:\VMTools\windows.iso >> C:\BuildLog.txt
		$vmtools = $true
	}
	Else {Write-BuildLog "VMware Tools not found on Build share."}
	Write-BuildLog ""
}

Write-BuildLog "Checking for vSphere files..."

if (Test-Path "B:\ESXi55\*") {
	if (Test-Path "B:\ESXi55\*.iso") {
		Write-BuildLog "Extracting ESXi 5.5 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESXi55\ B:\ESXi55\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESXi 5.5 found; creating C:\TFTP-Root\ESXi55 and copying ESXi 5.5 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESXi55 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESXi55\*.* C:\TFTP-Root\ESXi55 /s /c /y /q
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\Besx11-55.cfg
	Add-Content C:\TFTP-Root\ESXi55\\Besx11-55.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx11-5.cfg"
	Get-Content C:\TFTP-Root\ESXi55\BOOT.CFG | %{$_ -replace "/","/ESXi55/"} | Set-Content C:\TFTP-Root\ESXi55\Besx12-55.cfg
	Add-Content C:\TFTP-Root\ESXi55\\Besx12-55.cfg "kernelopt=ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx12-5.cfg"

	powershell C:\PXEMenuConfig.ps1 ESXi55
	Write-BuildLog "ESXi 5.5 added to TFTP and PXE menu."
	Write-BuildLog ""
	$esxi55 = $true
} else {
	$esxi55 = $false
}

if (Test-Path "B:\ESXi51\*") {
	if (Test-Path "B:\ESXi51\*.iso") {
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
	powershell C:\PXEMenuConfig.ps1 ESXi51
	Write-BuildLog "ESXi 5.1 added to TFTP and PXE menu."
	Write-BuildLog ""
	$esxi51 = $true
} else {
	$esxi51 = $false
}

if (Test-Path "B:\ESXi50\*") {
	if (Test-Path "B:\ESXi50\*.iso") {
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
	powershell C:\PXEMenuConfig.ps1 ESXi50
	Write-BuildLog "ESXi 5.0 added to TFTP and PXE menu."
	Write-BuildLog ""
	$esxi50 = $true
} else {
	$esxi50 = $false
}

if (Test-Path "B:\ESXi41\*") {
	if (Test-Path "B:\ESXi41\*.iso") {
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
	Write-BuildLog ""
	$esxi41 = $true
} else {
	$esxi41 = $false
}

if (Test-Path "B:\ESX41\*") {
	if (Test-Path "B:\ESX41\*.iso") {
		Write-BuildLog "Extracting ESX 4.1 installer from ISO."
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oB:\ESX41\ B:\ESX41\*.iso >> C:\ExtractLog.txt
	}
	Write-BuildLog "ESX 4.1 found; creating C:\TFTP-Root\ESX41 and copying ESX 4.1 boot files."
	$null = $null = New-Item -Path C:\TFTP-Root\ESX41 -ItemType Directory -Force -Confirm:$false
	xcopy B:\ESX41\isolinux\vmlinuz C:\TFTP-Root\ESX41 /s /c /y /q
	xcopy B:\ESX41\isolinux\initrd.img C:\TFTP-Root\ESX41 /s /c /y /q
	powershell C:\PXEMenuConfig.ps1 ESX41
	Write-BuildLog "ESX 4.1 added to TFTP and PXE menu."
	Write-BuildLog ""
	$esx41 = $true
} else {
	$esx41 = $false
}

if (!($esx41 -or $esxi41 -or $esxi50 -or $esxi51  -or $esxi55)) {
	Write-BuildLog "No ESX or ESXi files found."
	Write-BuildLog "Is the NAS VM running? If so, make sure the Build share is available and populated."
	Write-BuildLog "Restart this machine when Build share is available; build will proceed after restart."
	exit
}

Write-BuildLog ""
Write-BuildLog "Authorise and configure DHCP"
netsh dhcp add server dc2.lab.local 192.168.201.4
netsh dhcp server 192.168.201.4 add scope 192.168.201.0 255.255.255.0 "Lab scope" "Scope for lab.local"
netsh dhcp server 192.168.201.4 scope 192.168.201.0 add iprange 192.168.201.100 192.168.201.199
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set optionvalue 003 IPADDRESS 192.168.201.2
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set optionvalue 005 IPADDRESS 192.168.201.4
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set optionvalue 006 IPADDRESS 192.168.201.4
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set optionvalue 015 STRING lab.local
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set optionvalue 066 STRING 192.168.201.4
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set optionvalue 067 STRING pxelinux.0
netsh dhcp server 192.168.201.4 scope 192.168.201.0 set state 1

Write-BuildLog ""
Write-BuildLog "Checking available SQL Express versions."
$null = $null = New-Item -Path C:\temp -ItemType Directory -Force -Confirm:$false
Write-BuildLog ""
Write-BuildLog "Checking available SQL Express versions."
$null = New-Item -Path C:\temp -ItemType Directory -Force -Confirm:$false
if (Test-Path "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe") {
	Write-BuildLog "SQL Server Install found, not installing"
}Else {
	if (Test-Path "B:\VIM_55\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
		$vc5SQL = $true
		Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.5 found; installing."
		copy B:\VIM_55\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		del c:\TEMP\SQLEXPR_x64_ENU.EXE 
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDBvCD51.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDBvCD15.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC2\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
		$vc5SQL = $true
		Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 found; installing."
		copy B:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments = '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDBvCD51.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDBvCD15.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC2\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
		$vc5SQL = $true
		Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
		copy B:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe C:\temp
		$Arguments =  '/IACCEPTSQLSERVERLICENSETERMS /action=Install /FEATURES=SQL,Tools /SQLSYSADMINACCOUNTS="Lab\Domain Admins" /SQLSVCACCOUNT="Lab\vi-admin" /SQLSVCPASSWORD="' + $AdminPWD + '" /AGTSVCACCOUNT="Lab\vi-admin" /AGTSVCPASSWORD="' + $AdminPWD + '" /ADDCURRENTUSERASSQLADMIN /SECURITYMODE=SQL /SAPWD="VMware1!" /INSTANCENAME=SQLExpress /BROWSERSVCSTARTUPTYPE="Automatic" /TCPENABLED=1 /NPENABLED=1 /SQLSVCSTARTUPTYPE=Automatic /q'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDB.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		Start-Process "C:\Program Files\Microsoft SQL Server\100\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDBvCD15.txt" -RedirectStandardOutput c:\sqllog.txt -Wait
		regedit -s B:\Automate\DC2\SQLTCP.reg
	} elseif (Test-Path "B:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE") {
		copy B:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE C:\temp
		Write-BuildLog "SQL Server 2005 Express for vCenter 4.1 found; installing."
		$Arguments = '/qb INSTANCENAME=SQLExpress ADDLOCAL=ALL SAPWD="VMware1!" SQLACCOUNT="Lab\vi-admin" SQLPASSWORD="' + $AdminPWD + '" AGTACCOUNT="Lab\vi-admin" AGTPASSWORD="' + $AdminPWD + '" SQLBROWSERACCOUNT="Lab\vi-admin" SQLBROWSERPASSWORD="' + $AdminPWD + '" DISABLENETWORKPROTOCOLS=0'
		Start-Process C:\temp\SQLEXPR_x64_ENU.exe -ArgumentList $Arguments -Wait
		Write-BuildLog "Creating Databases."
		Start-Process "C:\Program Files (x86)\Microsoft SQL Server\90\Tools\Binn\sqlcmd.exe" -ArgumentList "-S dc2\SQLEXPRESS -i B:\Automate\DC2\MakeDB41.txt"  -RedirectStandardOutput c:\sqllog.txt -Wait; type C:\sqllog.txt  | add-content C:\buildlog.txt
		regedit -s B:\Automate\DC2\SQLTCP.reg
	} else {
		$vc5SQL = $false
		$vc4SQL = $false
		Write-BuildLog "No SQL Express installers found. Please verify that all contents of vCenter ISO are copied into the correct folder on the Build share."
		Read-Host "Press <ENTER> to exit"
		exit
	}
}

If (([System.Environment]::OSVersion.Version.Major -eq 6) -and ([System.Environment]::OSVersion.Version.Minor -lt 2)) {
	Write-BuildLog "Setup IIS on Windows 2008"
	Start-Process pkgmgr -ArgumentList '/quiet /l:C:\IIS_Install_Log.txt /iu:IIS-WebServerRole;IIS-WebServer;IIS-CommonHttpFeatures;IIS-StaticContent;IIS-DefaultDocument;IIS-DirectoryBrowsing;IIS-HttpErrors;IIS-HttpRedirect;IIS-ApplicationDevelopment;IIS-ASPNET;IIS-NetFxExtensibility;IIS-ASP;IIS-CGI;IIS-ISAPIExtensions;IIS-ISAPIFilter;IIS-ServerSideIncludes;IIS-HealthAndDiagnostics;IIS-HttpLogging;IIS-LoggingLibraries;IIS-RequestMonitor;IIS-HttpTracing;IIS-CustomLogging;IIS-ODBCLogging;IIS-Security;IIS-BasicAuthentication;IIS-WindowsAuthentication;IIS-DigestAuthentication;IIS-ClientCertificateMappingAuthentication;IIS-IISCertificateMappingAuthentication;IIS-URLAuthorization;IIS-RequestFiltering;IIS-IPSecurity;IIS-Performance;IIS-HttpCompressionStatic;IIS-HttpCompressionDynamic;IIS-WebServerManagementTools;IIS-ManagementConsole;IIS-ManagementScriptingTools;IIS-ManagementService;IIS-IIS6ManagementCompatibility;IIS-Metabase;IIS-WMICompatibility;IIS-LegacyScripts;IIS-LegacySnapIn;IIS-FTPPublishingService;IIS-FTPServer;IIS-FTPManagement;WAS-WindowsActivationService;WAS-ProcessModel;WAS-NetFxEnvironment;WAS-ConfigurationAPI' -Wait 

}
If (([System.Environment]::OSVersion.Version.Major -eq 6) -and ([System.Environment]::OSVersion.Version.Minor -ge 2)) {
	Write-BuildLog "Setup IIS on Windows 2012"
	import-module servermanager
	$null = add-windowsfeature web-server -includeallsubfeature -source D:\Sources\sxs
	Import-Module WebAdministration
	New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
}
if (Test-Path B:\sqlmsssetup.exe) {
	Rename-Item B:\sqlmsssetup.exe SQLManagementStudio_x64_ENU.exe
}
if (Test-Path B:\SQLManagementStudio_x64_ENU.exe) {
	if ( (!(Get-ChildItem B:\SQLManagementStudio_x64_ENU.exe).VersionInfo.ProductVersion -like "10.50.2500*") -and ($vc5SQL -or $vc4SQL)) {
		Write-BuildLog "The version of SQL Management Studio on the Build share is incompatible with SQL Server 2008 Express R2 SP1. Please see ReadMe.html on the Build share."
	} else {
		Write-BuildLog "SQL Management Studio found; installing."
		Start-Process B:\SQLManagementStudio_x64_ENU.exe -ArgumentList "/ACTION=INSTALL /IACCEPTSQLSERVERLICENSETERMS /FEATURES=Tools /q" -Wait -Verb RunAs
	}
} else { Write-BuildLog "SQL Management Studio not found (optional)."}

Write-BuildLog "Make Win32Time authoritative for NTP time."
reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Config /v AnnounceFlags /t REG_DWORD /d 0x05 /f

Write-BuildLog "Cleanup and creating Desktop shortcuts."
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /f
wscript B:\Automate\DC2\Shortcuts.vbs

if (Test-Path B:\Automate\automate.ini) {
	$timezone = ((Select-String -SimpleMatch "TZ=" -Path "B:\Automate\automate.ini").line).substring(3)
	Write-BuildLog "Setting time zone to $timezone according to automate.ini."
	tzutil /s "$timezone"
}

Write-BuildLog "Installing VMware tools, build complete after reboot."
Write-BuildLog "(Re)build vCenter next."
if ($vmtools) {
	Start-Process B:\VMTools\setup64.exe -ArgumentList '/s /v "/qn"' -Verb RunAs -Wait
	Start-Sleep -Seconds 30
}
Read-Host "Press <ENTER> to exit"