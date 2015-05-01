if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun Build.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}

# Start VC2 configuration process
if (Test-Path "B:\Automate\automate.ini") {
	Write-BuildLog "Determining automate.ini settings."
	$vcinstall = "55"
	$vcinstall = ((Select-String -SimpleMatch "VCInstall=" -Path "B:\Automate\automate.ini").line).substring(10)
	If ($vcinstall -eq "50") {$vcinstall = "5"}
	Write-BuildLog "  VMware vCenter install set to $vcinstall."
	$viewinstall = "None"
	$buildvm = "false"
	$buildviewvm = "false"
	$timezone = "New Zealand Standard Time"
	$timezone = ((Select-String -SimpleMatch "TZ=" -Path "B:\Automate\automate.ini").line).substring(3)
	Write-BuildLog "  Timezone set to $timezone."
	$DeployVUM = $false
	$AutoAddHosts = "false"
	$AutoAddHosts = ((Select-String -SimpleMatch "AutoAddHosts=" -Path "B:\Automate\automate.ini").line).substring(13)
	if ($AutoAddHosts -like "true") {
		$AutoAddHosts = $true
		Write-BuildLog "  Hosts will be automatically added to vCenter after build completes."
	} else {
		$AutoAddHosts = $false
	}
	$AutoVCNS = "false"
	$AdminPWD = "VMware1!"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
} else {
	Write-BuidLog "Unable to find B:\Automate\automate.ini. Where did it go?"
}
Write-BuildLog "Change default local administrator password"
net user administrator $AdminPWD
B:\automate\_Common\Autologon administrator vc2 $AdminPWD

Write-BuildLog "Installing 7-zip."
try {
	Start-Process msiexec -ArgumentList '/qb /i B:\Automate\_Common\7z920-x64.msi' -Wait 
}
catch {
	Write-BuildLog "7-zip installation failed."
}
Write-BuildLog "Installing PuTTy."
$null = New-Item -Path "C:\Program Files (x86)\PuTTY" -ItemType Directory -Force
xcopy B:\Automate\VC2\PuTTY\*.* "C:\Program Files (x86)\PuTTY" /s /c /y /q
regedit -s B:\Automate\VC2\PuTTY.reg
try {
	Write-BuildLog "Installing Adobe Flash Player."
	Start-Process msiexec -ArgumentList '/i b:\Automate\_Common\install_flash_player_11_active_x.msi /qb' -Wait
}
catch {
	Write-BuildLog "Adobe Flash Player installation failed."
}

Write-BuildLog ""
if (Test-Path "b:\VMware-PowerCLI*.exe") {
	if (Test-Path "b:\VMware-PowerCLI.exe") {
		$PowCLIver = (Get-ChildItem B:\VMware-PowerCLI.exe).VersionInfo.ProductVersion.trim()
		If ($PowCLIver -eq "5.0.0.3501") {$PowCLIver = "5.0.0-3501"}
		Rename-Item B:\VMware-PowerCLI.exe B:\VMware-PowerCLI-$PowCLIver.exe
	}
	#Start-Process b:\VMware-PowerCLI.exe -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
	$null = New-Item -Path "C:\Users\vi-admin\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -ItemType File -Force
	$null = Add-Content -Path "C:\Users\vi-admin\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Value @"
if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq `$null) {
	try {
		Write-Host "Loading PowerCLI plugin, this may take a little while" -foregroundcolor "cyan"
		Add-PSSnapin VMware.VimAutomation.Core
		`$PCLIVer = Get-PowerCLIVersion
		if (((`$PCLIVer.Major * 10 ) + `$PCLIVer.Minor) -ge 51) {
			`$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:`$false -Scope "Session"
		}
	}
	catch {
		Write-Host "Unable to load the PowerCLI plugin. Please verify installation or install VMware PowerCLI and run this script again."
		Read-Host "Press <Enter> to exit"
		exit
	}
}
"@	
} else {
	Write-BuildLog "VMware PowerCLI installer not found. This will need to be installing before running any AutoLab PowerShell post-install scripts."
}

switch ($vcinstall) {
	55 {
		Write-BuildLog "Starting vCenter 5.5 automation."
		if (Test-Path "b:\VIM_55\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.5 found; installing."
			Start-Process b:\VIM_55\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} else {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.5 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing vCenter 5.5 Single Sign On."
		start-Process msiexec -argumentList '/i "B:\VIM_55\Single Sign-On\VMware-SSO-Server.msi" /qr SSO_HTTPS_PORT=7444 DEPLOYMODE=FIRSTDOMAIN ADMINPASSWORD=VMware1! SSO_SITE=Lab' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5 Web Client."
		Start-Process B:\VIM_55\vSphere-WebClient\VMware-WebClient.exe -ArgumentList '/L1033 /v" HTTP_PORT=9090 HTTPS_PORT=9443 SSO_ADMIN_USER=administrator@vsphere.local SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc2.lab.local:7444/lookupservice/sdk /qr"' -Wait  -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5 Inventory Service."
		Start-Process "B:\VIM_55\Inventory Service\VMware-inventory-service.exe" -argumentList ' /S /L1033 /v" QUERY_SERVICE_NUKE_DATABASE=1 SSO_ADMIN_USER=administrator@vsphere.local SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc2.lab.local:7444/lookupservice/sdk /qr"' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5."
		Start-Process B:\VIM_55\vCenter-Server\VMware-vcserver.exe -ArgumentList '/S /W /L1033 /v" /qr /norestart WARNING_LEVEL=0 VCS_GROUP_TYPE=Single VPX_ACCOUNT_TYPE=System DB_SERVER_TYPE=Custom DB_DSN=vCenterDB DB_USERNAME=vpx DB_PASSWORD=VMware1! FORMAT_DB=1 IS_URL="https://localhost:10443" SSO_ADMIN_USER=administrator@vsphere.local SSO_ADMIN_PASSWORD=VMware1! VC_ADMIN_USER=administrators@VC2 VC_ADMIN_IS_GROUP_VPXD_TXT=true LS_URL=https://vc2.lab.local:7444/lookupservice/sdk "' -Wait -Verb RunAs
		Write-BuildLog "Installing vSphere Client 5.5."
		Start-Process B:\VIM_55\redist\vjredist\x64\vjredist64.exe -ArgumentList '/q:a /c:"install.exe /q"' -Wait -Verb RunAs
		Start-Process B:\VIM_55\vSphere-Client\VMware-viclient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
		$null = mkdir "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		$null = copy B:\Automate\vc\SSHAutoConnect\*.* "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		If ($DeployVUM) {
			Write-BuildLog "Installing vSphere Client 5.5 VUM Plugin."
			Start-Process B:\VIM_55\updateManager\VMware-UMClient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
			Write-BuildLog "Installing vCenter Update Manager 5.5."
			$Arguments = '""/L1033 /v" /qr VMUM_SERVER_SELECT=vc2.lab.local VC_SERVER_IP=vc2.lab.local VC_SERVER_ADMIN_USER=\"VC\administrator\" VC_SERVER_ADMIN_PASSWORD=' + $AdminPWD +' VCI_DB_SERVER_TYPE=Custom VCI_FORMAT_DB=1 DB_DSN=VUM DB_USERNAME=vpx DB_PASSWORD=VMware1!"'
			Start-Process B:\VIM_55\updateManager\VMware-UpdateManager.exe -ArgumentList $Arguments -Wait -Verb RunAs
		}
		Write-BuildLog "Installing vSphere Web Client Integration plugin."
		copy "C:\Program Files\VMware\Infrastructure\vSphereWebClient\server\work\deployer\s\global\72\0\container-app-war-5.5.0.war\vmrc\VMware-ClientIntegrationPlugin-5.5.0.exe" c:\
		Start-Process C:\VMware-ClientIntegrationPlugin-5.5.0.exe -ArgumentList '/v/qn' -Wait -Verb RunAs
		if (Test-Path "b:\VMware-PowerCLI-5.5.*.exe") {
			Write-BuildLog "VMware PowerCLI installer found; installing."
			Start-Process (Get-ChildItem b:\VMware-PowerCLI-5.5.*.exe).FullName -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
		} elseif (Test-Path "b:\VMware-PowerCLI-5.0.*.exe"){
			Write-BuildLog "PowerCLI installer is out of date, installing anyway."
			Start-Process (Get-ChildItem b:\VMware-PowerCLI-5.0.*.exe).FullName -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
		} else {Write-BuildLog "PowerCLI installer not found."}
	}
	51 {
		Write-BuildLog "Starting vCenter 5.1 automation."
		if (Test-Path "b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 found; installing."
			Start-Process b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} else {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing vCenter 5.1 Single Sign On"
		Start-Process "B:\VIM_51\Single Sign On\VMware-SSO-Server.exe" -ArgumentList '/L1033 /v"/qb MASTER_PASSWORD=VMware1! CONFIRM_MASTER_PASSWORD=VMware1! CONFIG_TYPE=Setup SETUP_TYPE=Basic SSO_DB_SERVER_TYPE=\"Custom\" JDBC_DBTYPE=Mssql JDBC_DBNAME=RSA JDBC_HOSTNAME_OR_IP=DC2 JDBC_HOST_PORT=1433 JDBC_USERNAME=RSA_USER JDBC_PASSWORD=VMware1! SKIP_DB_USER_CREATION=1 DBA_JDBC_USERNAME=RSA_DBA DBA_JDBC_PASSWORD=VMware1! COMPUTER_FQDN=vc2.lab.local IS_SSPI_NETWORK_SERVICE_ACCOUNT=1 SSO_HTTPS_PORT=7444"' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.1 Web Client"
		Start-Process B:\VIM_51\vSphere-WebClient\VMware-WebClient.exe -ArgumentList '/L1033 /v" HTTP_PORT=9090 HTTPS_PORT=9443 SSO_ADMIN_USER=admin@System-Domain SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc2.lab.local:7444/lookupservice/sdk /qr"' -Wait  -Verb RunAs
		Write-BuildLog "Add AD to SSO since the installer failed to add"
		Start-Process "C:\Program Files\VMware\Infrastructure\SSOServer\utils\rsautil" -ArgumentList ' manage-identity-sources -a create -u admin -p VMware1! -r ldap://dc.lab.local --ldap-port 3268 -d lab.local -l LAB --principal-base-dn dc=lab,dc=local --group-base-dn dc=lab,dc=local -f ldap://dc2.lab.local -L administrator@lab.local -P VMware1!' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.1 Inventory Service"
		Start-Process "B:\VIM_51\Inventory Service\VMware-inventory-service.exe" -ArgumentList '/L1033 /v" HTTPS_PORT=10443 XDB_PORT=10109 FEDERATION_PORT=10111 QUERY_SERVICE_NUKE_DATABASE=1 TOMCAT_MAX_MEMORY_OPTION=S SSO_ADMIN_USER=admin@System-Domain SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc2.lab.local:7444/lookupservice/sdk /qr"' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.1"
		Start-Process B:\VIM_51\vCenter-Server\VMware-vcserver.exe -ArgumentList '/L1033 /v" /qr DB_SERVER_TYPE=Custom DB_DSN=vCenterDB DB_USERNAME=vpx DB_PASSWORD=VMware1! FORMAT_DB=1 JVM_MEMORY_OPTION=S SSO_ADMIN_USER=admin@System-Domain SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc2.lab.local:7444/lookupservice/sdk IS_URL=https://vc2.lab.local:10443 VC_ADMIN_USER=vi-admin@lab VC_ADMIN_IS_GROUP_VPXD_TXT=0 VPX_USES_SYSTEM_ACCOUNT=1 VCS_GROUP_TYPE=Single VCS_ADAM_LDAP_PORT=389 VCS_ADAM_SSL_PORT=636 VCS_HTTPS_PORT=443 VCS_HTTP_PORT=80 TC_HTTP_PORT=8080 TC_HTTPS_PORT=8443 VCS_WSCNS_PORT=60099 VCS_HEARTBEAT_PORT=902"' -Wait -Verb RunAs
		Write-BuildLog "Installing vSphere Client 5.1"
		Start-Process B:\VIM_51\redist\vjredist\x64\vjredist64.exe -ArgumentList '/q:a /c:"install.exe /q"' -Wait -Verb RunAs
		Start-Process B:\VIM_51\vSphere-Client\VMware-viclient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
		Write-BuildLog "Installing vSphere Web Client Integration plugin"
		copy "C:\Program Files\VMware\Infrastructure\vSphereWebClient\server\work\org.eclipse.virgo.kernel.deployer_3.0.3.RELEASE\staging\global\bundle\com.vmware.vsphere.client.containerapp\5.1.0\container-app-war-5.1.0.war\vmrc\VMware-ClientIntegrationPlugin-5.1.0.exe" c:\
		Start-Process C:\VMware-ClientIntegrationPlugin-5.1.0.exe -ArgumentList '/v/qn' -Wait -Verb RunAs
		if (Test-Path "b:\VMware-PowerCLI-5.1.*.exe") {
			Write-BuildLog "VMware PowerCLI installer found; installing."
			Start-Process (Get-ChildItem b:\VMware-PowerCLI-5.1.*.exe).FullName -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
		} Elseif (Test-Path "b:\VMware-PowerCLI-5.0.*.exe"){
			Write-BuildLog "PowerCLI installer is out of date, installing anyway"
			Start-Process (Get-ChildItem b:\VMware-PowerCLI-5.0.*.exe).FullName -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
		} Else {Write-BuildLog "PowerCLI installer not found."}
	}
	5 {
		Write-BuildLog "Starting vCenter 5 automation."
		if (Test-Path "b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
			Start-Process b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList ' /i C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} else {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Install vCentre and vSphere client"
		copy b:\automate\VC2\vc50.cmd c:\
		start-process c:\vc50.cmd -Wait -verb RunAs
		if (Test-Path "b:\VMware-PowerCLI-5.0.*.exe"){
			Write-BuildLog "VMware PowerCLI installer found; installing."
			Start-Process (Get-ChildItem b:\VMware-PowerCLI-5.0.*.exe).FullName -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
		} Else {Write-BuildLog "PowerCLI installer not found."}
}
	4 {
		Write-BuildLog "Starting vCenter 4.1 automation."
		if (Test-Path "b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 found; installing."
			Start-Process b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} Elseif (Test-Path "b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
			Start-Process b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList ' /i C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} else {
			Write-BuildLog "SQL Server 2008 Express not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		copy b:\automate\VC2\vc41.cmd c:\
		start-process c:\vc41.cmd -Wait -verb RunAs
			if (Test-Path "b:\VMware-PowerCLI-5.0.*.exe"){
			Write-BuildLog "VMware PowerCLI installer found; installing."
			Start-Process (Get-ChildItem b:\VMware-PowerCLI-5.0.*.exe).FullName -ArgumentList '/q /s /w /L1033 /V" /qb"' -Wait -Verb RunAs
		} Else {Write-BuildLog "PowerCLI installer not found."}
}
	Base {
		if (Test-Path "b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 found; installing."
			Start-Process b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} Elseif (Test-Path "b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
			Start-Process b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList ' /i C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} elseif (Test-Path "b:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE") {
			Write-BuildLog "SQL Server 2005 Express for vCenter 4.1 found; installing."
			Start-Process b:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path c:\temp\setup\sqlncli_x64.msi) {
				Start-Process msiexec -ArgumentList '/i C:\temp\setup\sqlncli_x64.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		}
	}
	None {}
}

if (Test-Path "b:\VMware-vSphere-CLI.exe") {
	Write-BuildLog "VMware vSphere CLI installer found; installing."
	Start-Process b:\VMware-vSphere-CLI.exe -ArgumentList '/S /v/qb' -Wait -Verb RunAs
} else {
	Write-BuildLog "VMware vSphere CLI installer not found."
}

Write-BuildLog "Adding Domain Admins to vCenter administrators role and setting PowerCLI certificate warning."
if (!(($vcinstall -eq "None") -or ($vcinstall -eq "Base"))) {
	Write-Host "Loading PowerCLI plugin, this will take a little while." -foregroundcolor "cyan"
	Add-PSSnapin VMware.VimAutomation.Core
	if ((($PCLIVer.Major * 10 ) + $PCLIVer.Minor) -ge 51) {
		$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false -Scope "AllUsers"
	}
	If ($vcinstall -eq "55") {
		Write-BuildLog "vCentre 5.5 doesn't allow us to setup security"
	} Else {
		$null = connect-viserver vc2.lab.local -user lab\Vi-Admin -password VMware1!
		$null = New-VIPermission -Role Admin -Principal 'lab\Domain Admins' -Entity Datacenters
		$null = New-VIPermission -Role Admin -Principal 'Administrator' -Entity Datacenters
		$PCLIVer = Get-PowerCLIVersion
		$null = Disconnect-VIServer -Server * -confirm:$false
	}
}

Write-BuildLog "Cleanup and creating Desktop shortcuts."
regedit -s b:\Automate\vc2\vSphereClient.reg
Remove-Item "C:\Users\Public\Desktop\*.lnk"
Remove-Item c:\eula*.*
Remove-Item c:\install*.*
Remove-Item c:\VC*
Remove-Item c:\VMware-ClientIntegrationPlugin*.exe
Remove-Item c:\temp -Force -Recurse
copy b:\Automate\vc2\Shortcuts.vbs c:\Shortcuts.vbs
wscript c:\Shortcuts.vbs
copy b:\Automate\*.ps1 c:\
If (($AutoAddHosts -eq "True") -and (Test-Path "c:\Addhosts.ps1")){
	Write-BuildLog " "
	Write-BuildLog "Automatically running AddHosts script"
	Write-BuildLog " "
	Start-Process c:\windows\syswow64\WindowsPowerShell\v1.0\powershell.exe -ArgumentList " C:\AddHosts.ps1" -wait
}
Write-BuildLog "Installing VMware tools, build complete after reboot."
if (Test-Path B:\VMTools\setup64.exe) {
	Start-Process B:\VMTools\setup64.exe -ArgumentList '/s /v "/qn"' -verb RunAs -Wait
	Start-Sleep -Seconds 30
}

Read-Host "Press <Enter> to exit"
exit