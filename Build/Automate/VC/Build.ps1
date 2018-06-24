if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-Host "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun Build.ps1"
	Read-Host "Press <Enter> to exit"
	exit
}
write-buildlog "Starting Build.ps1"
$a = (Get-Host).UI.RawUI
$a.WindowTitle = "VC Build Automation"
$b = $a.WindowSize
$b.Height = $a.MaxWindowSize.Height - 1
$a.WindowSize = $b
Import-Module C:\windows\system32\WASP.dll
Select-Window -Title "VC Build Automation" | set-windowposition -left 75 -top 3

# Start VC configuration process
if (Test-Path "B:\Automate\automate.ini") {
	Write-BuildLog "Determining automate.ini settings."
	$vcinstall = "55"
	$vcinstall = ((Select-String -SimpleMatch "VCInstall=" -Path "B:\Automate\automate.ini").line).substring(10)
	If ($vcinstall -eq "50") {$vcinstall = "5"}
	Write-BuildLog "  VMware vCenter install set to $vcinstall."
	$viewinstall = "None"
	$viewinstall = ((Select-String -SimpleMatch "ViewInstall=" -Path "B:\Automate\automate.ini").line).substring(12)
	Write-BuildLog "  VMware View install set to $viewinstall."
	$buildvm = "false"
	$buildvm = ((Select-String -SimpleMatch "BuildVM=" -Path "B:\Automate\automate.ini").line).substring(8)
	if ($buildvm -like "true") {
		$buildvm = $true
		Write-BuildLog "  vCenter Lab VM to be built."
	} else {
		$buildvm = $false
	}
	$win2k3key = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
	$win2k3key = ((Select-String -SimpleMatch "ProductKey=" -Path "B:\Automate\automate.ini" -List).line).substring(11)
	if ($win2k3key -and !($win2k3key -like "*XXXX*")) {
		Write-BuildLog "    Windows 2003 product key for vCenter Lab VM found."
		$fileoriginal = Get-Content B:\Automate\_Common\Lab2K3.sif
		[String[]] $filemodified = @() 
		foreach ($line in $fileoriginal) {    
			if ($line -match "ProductID=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX") {
				$line = "ProductID=$win2k3key"
			}
			$filemodified += $line
		}
		$null = New-Item -Path C:\temp\Lab2K3.sif -ItemType File -Force
		Set-Content C:\temp\Lab2k3.sif $filemodified
		$fileoriginal = Get-Content B:\Automate\_Common\Auto2K3.sif
		[String[]] $filemodified = @() 
		foreach ($line in $fileoriginal) {    
			if ($line -match "ProductID=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX") {
				$line = "ProductID=$win2k3key"
			}
			$filemodified += $line
		}
		$null = New-Item -Path C:\temp\Auto2K3.sif -ItemType File -Force
		Set-Content C:\temp\Auto2K3.sif $filemodified
	}
	$buildviewvm = "false"
	$buildviewvm = ((Select-String -SimpleMatch "BuildViewVM=" -Path "B:\Automate\automate.ini").line).substring(12)
	if ($buildviewvm -like "true") {
		$buildviewvm = $true
		Write-BuildLog "  View Lab VM to be built."
	} else {
		$buildviewvm = $false
	}
	$viewvmproductkey = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
	$viewvmproductkey = ((Select-String -SimpleMatch "ViewVMProductKey=" -Path "B:\Automate\automate.ini").line).substring(17)
	if ($viewvmproductkey -and !($viewvmproductkey -like "*XXXX*")) {
		Write-BuildLog "    Windows XP product key found for View Lab VM found."
		$fileoriginal = Get-Content B:\Automate\_Common\AutoXP.sif
		[String[]] $filemodified = @() 
		foreach ($line in $fileoriginal) {    
			if ($line -match "ProductID=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX") {
				$line = "ProductID=$viewvmproductkey"
			}
			$filemodified += $line
		}
		$null = New-Item -Path C:\temp\AutoXP.sif -ItemType File -Force
		Set-Content C:\temp\AutoXP.sif $filemodified
	}
	$timezone = "New Zealand Standard Time"
	$timezone = ((Select-String -SimpleMatch "TZ=" -Path "B:\Automate\automate.ini").line).substring(3)
	Write-BuildLog "  Set timezone to $timezone."
	tzutil /s "$timezone"
	$DeployVUM = $false
	if ((((Select-String -SimpleMatch "DeployVUM=" -Path "B:\Automate\automate.ini").line).substring(10)) -like "true") {
		$DeployVUM = $true
		Write-BuildLog "  VUM will be installed."
	} else {
		$DeployVUM = $false
		Write-BuildLog "  No VUM."
	}
	$AutoAddHosts = "false"
	$AutoAddHosts = ((Select-String -SimpleMatch "AutoAddHosts=" -Path "B:\Automate\automate.ini").line).substring(13)
	if ($AutoAddHosts -like "true") {
		$AutoAddHosts = $true
		Write-BuildLog "  Hosts will be automatically added to vCenter after build completes."
	} else {
		$AutoAddHosts = $false
	}
	$AdminPWD = "VMware1!"
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
	$emailto = ((Select-String -SimpleMatch "emailto=" -Path "B:\Automate\automate.ini").line).substring(8)
	$SmtpServer = ((Select-String -SimpleMatch "SmtpServer=" -Path "B:\Automate\automate.ini").line).substring(11)
} else {
	Write-BuidLog "Unable to find B:\Automate\automate.ini. Where did it go?"
}
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain -eq $False) {
	Write-BuildLog "Joining domain"
	reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /t REG_SZ /d "cmd /c c:\Build.cmd" /f 
	$password = $AdminPWD | ConvertTo-SecureString -asPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential("administrator",$password)
	$null = Add-Computer -DomainName "lab.local" -Credential $credential -restart
	read-host "Waiting for restart"
} else {
	reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v Build /f
}

Write-BuildLog "Clear System eventlog, errors to here are spurious"
Clear-EventLog -LogName System -confirm:$False

If ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -ge 62) {
	Write-BuildLog "Disabling autorun of ServerManager at logon."
	Start-Process schtasks -ArgumentList ' /Change /TN "\Microsoft\Windows\Server Manager\ServerManager" /DISABLE'  -Wait -Verb RunAs
	Write-BuildLog "Disabling screen saver"
	set-ItemProperty -path 'HKCU:\Control Panel\Desktop' -name ScreenSaveActive -value 0
}

Write-BuildLog "Installing 7-zip."
Start-Process msiexec -ArgumentList '/qb /i B:\Automate\_Common\7z1805-x64.msi' -Wait 
do {
	start-sleep 10
} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)

Write-BuildLog "Installing PuTTy."
$null = New-Item -Path "C:\Program Files (x86)\PuTTY" -ItemType Directory -Force
xcopy B:\Automate\vc\PuTTY\*.* "C:\Program Files (x86)\PuTTY" /s /c /y /q
regedit -s B:\Automate\vc\PuTTY.reg

browserAndFlash

Write-BuildLog "Change default local administrator password"
net user administrator $AdminPWD
B:\automate\_Common\Autologon administrator vc $AdminPWD

switch ($vcinstall) {
	67 {
		Write-BuildLog "Starting vCenter 6.7 automation."
		If ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -eq 63) {
			Write-BuildLog "Installing universal C Runtime for windows 2016"
			B:
			cd B:\VIM_67\
			b:\automate\_common\wget.exe -q --no-check-certificate https://download.microsoft.com/download/D/1/3/D13E3150-3BB2-4B22-9D8A-47EE2D609FFF/Windows8.1-KB2999226-x64.msu
			Start-Process wusa.exe  -ArgumentList "B:\VIM_67\Windows8.1-KB2999226-x64.msu /quiet"  -Wait -Verb RunAs
		} ElseIf ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -eq 62) {
			Write-BuildLog "Installing universal C Runtime for windows 2012"
			B:
			cd B:\VIM_67\
			b:\automate\_common\wget.exe -q --no-check-certificate https://download.microsoft.com/download/9/3/E/93E0745A-EAE9-4B5A-B50C-012F2D3B6659/Windows8-RT-KB2999226-x64.msu
			Start-Process wusa.exe  -ArgumentList "B:\VIM_67\Windows8-RT-KB2999226-x64.msu /quiet"  -Wait -Verb RunAs
		} ElseIf ((([System.Environment]::OSVersion.Version.Major *10) +[System.Environment]::OSVersion.Version.Minor) -eq 61) {
			Write-BuildLog "Installing universal C Runtime for windows 2008"
			B:
			cd B:\VIM_67\
			b:\automate\_common\wget.exe -q --no-check-certificate https://download.microsoft.com/download/F/1/3/F13BEC9A-8FC6-4489-9D6A-F84BDC9496FE/Windows6.1-KB2999226-x64.msu
			Start-Process wusa.exe  -ArgumentList "B:\VIM_67\Windows6.1-KB2999226-x64.msu /quiet"  -Wait -Verb RunAs
		}
		if (Test-Path "b:\VIM_67\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2012 Express SP1 for vCenter 6.7 found; installing."
			Start-Process b:\VIM_67\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/q /x:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				Start-Process regedit -ArgumentList "-s B:\Automate\vc\vCenter6DB.reg" -Wait -Verb RunAs
				do {
					start-sleep 10
				} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
			}
		} else {
			Write-BuildLog "SQL Server 2012 Express SP1 for vCenter 6.7 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		do {
			start-sleep 10
		} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
		Write-BuildLog "Installing vCentre server 6.7. with embedded PSC"
		Start-Process B:\VIM_67\vCenter-Server\VMware-vCenter-Server.exe -ArgumentList " /qr CUSTOM_SETTINGS=B:\Automate\VC\vCentre60.json" -Wait -Verb RunAs
	}
	65 {
		Write-BuildLog "Starting vCenter 6.5 automation."
		if (Test-Path "b:\VIM_65\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2012 Express SP1 for vCenter 6.5 found; installing."
			Start-Process b:\VIM_65\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/q /x:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				Start-Process regedit -ArgumentList "-s B:\Automate\vc\vCenter6DB.reg" -Wait -Verb RunAs
				do {
					start-sleep 10
				} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
			}
		} else {
			Write-BuildLog "SQL Server 2012 Express SP1 for vCenter 6.5 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing vCentre server 6.5. with embedded PSC"
		Start-Process B:\VIM_65\vCenter-Server\VMware-vCenter-Server.exe -ArgumentList " /qr CUSTOM_SETTINGS=B:\Automate\VC\vCentre60.json" -Wait -Verb RunAs
		Write-BuildLog "Installing vCentre Client Integration Plugin"
		If (!(Test-Path("c:\temp\VMware-ClientIntegrationPlugin-6.5.0.exe"))) {
			B:
			cd B:\VIM_65
			B:\Automate\_Common\wget.exe -q http://vsphereclient.vmware.com/vsphereclient/VMware-ClientIntegrationPlugin-6.5.0.exe
		}										
		. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa -oc:\temp\ B:\VIM_65\VMware-ClientIntegrationPlugin-6.5.0.exe >> C:\ExtractLog.txt
		Start-Process C:\temp\VMware-ClientIntegrationPlugin.win32.exe -ArgumentList '/s /v /qn ' -Wait -Verb RunAs
		Start-Process C:\temp\VMware-ClientIntegrationService.win32.exe -ArgumentList '/s /v /qn ' -Wait -Verb RunAs

	}
	60 {
		Write-BuildLog "Starting vCenter 6.0 automation."
		if (Test-Path "b:\VIM_60\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2012 Express SP1 for vCenter 6.0 found; installing."
			Start-Process b:\VIM_60\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/q /x:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				copy C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi c:\temp
			}
			if (Test-Path "C:\temp\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				Start-Process regedit -ArgumentList "-s B:\Automate\vc\vCenter6DB.reg" -Wait -Verb RunAs
				do {
					start-sleep 10
				} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
			}
		} else {
			Write-BuildLog "SQL Server 2012 Express SP1 for vCenter 6.0 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing vCentre server 6.0. with embedded PSC"
		Start-Process B:\VIM_60\vCenter-Server\VMware-vCenter-Server.exe -ArgumentList " /qr CUSTOM_SETTINGS=B:\Automate\VC\vCentre60.json" -Wait -Verb RunAs
		do {
			start-sleep 10
		} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
		Write-BuildLog "Installing vCentre Client Integration Plugin"
		If (!(Test-Path("c:\temp\VMware-ClientIntegrationPlugin-6.0.0.exe"))) {
			B:
			cd B:\VIM_60
			B:\Automate\_Common\wget.exe -q http://vsphereclient.vmware.com/vsphereclient/VMware-ClientIntegrationPlugin-6.0.0.exe
		}
		Start-Process  B:\VIM_60\VMware-ClientIntegrationPlugin-6.0.0.exe -ArgumentList '/v" /qb" ' -Wait -Verb RunAs
		Write-BuildLog "Installing vSphere Client 6.0."
		Start-Process B:\VIM_60\vSphere-Client\VMware-viclient.exe -ArgumentList '/qb /s /w /L1033 /v" /qb"' -Wait -Verb RunAs
		$null = mkdir "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		$null = copy B:\Automate\vc\SSHAutoConnect\*.* "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		Write-BuildLog "Installing vSphere Client 6.0 VUM Plugin."
		Start-Process B:\VIM_60\updateManager\VMware-UMClient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
		If (($DeployVUM) -and ($vcinstall -eq "60")) {
			do {
				start-sleep 10
			} until ((get-process "msiexec" -ea SilentlyContinue) -eq $Null)
			Write-BuildLog "Installing vCenter Update Manager 6.0."
			if ((([System.Environment]::OSVersion.Version.Major *10) + [System.Environment]::OSVersion.Version.Minor) -ge 62) {
				Start-Process B:\VIM_60\redist\dotnet\dotnetfx35.exe -ArgumentList " /qb /norestart" -Wait -Verb RunAs
			} Else {
				import-module ServerManager
				$null = Add-WindowsFeature AS-NET-Framework
			}
			$Arguments = '""/L1033 /v" /qr VMUM_SERVER_SELECT=vc.lab.local VC_SERVER_IP=vc.lab.local VC_SERVER_ADMIN_USER=\"administrator@vsphere.local\" VC_SERVER_ADMIN_PASSWORD=\"VMware1!\" VCI_DB_SERVER_TYPE=Custom VCI_FORMAT_DB=1 DB_DSN=VUM DB_USERNAME=vpx DB_PASSWORD=VMware1!"'
			Start-Process B:\VIM_60\updateManager\VMware-UpdateManager.exe -ArgumentList $Arguments -Wait -Verb RunAs
		}
	}
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
				regedit -s B:\Automate\vc\vCenterDB.reg
			}
		} else {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.5 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing VisalC Runtime as pre-requisite."
		start-Process "B:\VIM_55\Single Sign-On\prerequisites\vcredist_x64.exe" -argumentList " /q" -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5 Single Sign On."
		start-Process msiexec -argumentList '/i "B:\VIM_55\Single Sign-On\VMware-SSO-Server.msi" /qr SSO_HTTPS_PORT=7444 DEPLOYMODE=FIRSTDOMAIN ADMINPASSWORD=VMware1! SSO_SITE=Lab' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5 Web Client."
		Start-Process B:\VIM_55\vSphere-WebClient\VMware-WebClient.exe -ArgumentList '/L1033 /v" HTTP_PORT=9090 HTTPS_PORT=9443 SSO_ADMIN_USER=administrator@vsphere.local SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc.lab.local:7444/lookupservice/sdk /qr"' -Wait  -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5 Inventory Service."
		Start-Process "B:\VIM_55\Inventory Service\VMware-inventory-service.exe" -argumentList ' /S /L1033 /v" QUERY_SERVICE_NUKE_DATABASE=1 SSO_ADMIN_USER=administrator@vsphere.local SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc.lab.local:7444/lookupservice/sdk /qr"' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.5."
		Start-Process B:\VIM_55\vCenter-Server\VMware-vcserver.exe -ArgumentList '/S /W /L1033 /v" /qr /norestart WARNING_LEVEL=0 VCS_GROUP_TYPE=Single VPX_ACCOUNT_TYPE=System DB_SERVER_TYPE=Custom DB_DSN=vCenterDB DB_USERNAME=vpx DB_PASSWORD=VMware1! FORMAT_DB=1 IS_URL="https://localhost:10443" SSO_ADMIN_USER=administrator@vsphere.local SSO_ADMIN_PASSWORD=VMware1! VC_ADMIN_USER=administrators@VC VC_ADMIN_IS_GROUP_VPXD_TXT=true LS_URL=https://vc.lab.local:7444/lookupservice/sdk "' -Wait -Verb RunAs
		Write-BuildLog "Installing vSphere Client 5.5."
		Start-Process B:\VIM_55\redist\vjredist\x64\vjredist64.exe -ArgumentList '/q:a /c:"install.exe /q"' -Wait -Verb RunAs
		Start-Process B:\VIM_55\vSphere-Client\VMware-viclient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
		$null = mkdir "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		$null = copy B:\Automate\vc\SSHAutoConnect\*.* "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		If ($DeployVUM) {
			Write-BuildLog "Installing vSphere Client 5.5 VUM Plugin."
			Start-Process B:\VIM_55\updateManager\VMware-UMClient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
			Write-BuildLog "Installing vCenter Update Manager 5.5."
			$Arguments = '""/L1033 /v" /qr VMUM_SERVER_SELECT=vc.lab.local VC_SERVER_IP=vc.lab.local VC_SERVER_ADMIN_USER=\"VC\administrator\" VC_SERVER_ADMIN_PASSWORD=' + $AdminPWD +' VCI_DB_SERVER_TYPE=Custom VCI_FORMAT_DB=1 DB_DSN=VUM DB_USERNAME=vpx DB_PASSWORD=VMware1!"'
			Start-Process B:\VIM_55\updateManager\VMware-UpdateManager.exe -ArgumentList $Arguments -Wait -Verb RunAs
		}
		Write-BuildLog "Installing vSphere Web Client Integration plugin."
		copy "C:\Program Files\VMware\Infrastructure\vSphereWebClient\server\work\deployer\s\global\72\0\container-app-war-5.5.0.war\vmrc\VMware-ClientIntegrationPlugin-5.5.0.exe" c:\
		Start-Process C:\VMware-ClientIntegrationPlugin-5.5.0.exe -ArgumentList '/v/qn' -Wait -Verb RunAs
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
				regedit -s B:\Automate\vc\vCenterDB.reg
			}
		} else {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.1 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing vCenter 5.1 Single Sign On."
		Start-Process "B:\VIM_51\Single Sign On\VMware-SSO-Server.exe" -ArgumentList '/L1033 /v"/qb MASTER_PASSWORD=VMware1! CONFIRM_MASTER_PASSWORD=VMware1! CONFIG_TYPE=Setup SETUP_TYPE=Basic SSO_DB_SERVER_TYPE=\"Custom\" JDBC_DBTYPE=Mssql JDBC_DBNAME=RSA JDBC_HOSTNAME_OR_IP=DC JDBC_HOST_PORT=1433 JDBC_USERNAME=RSA_USER JDBC_PASSWORD=VMware1! SKIP_DB_USER_CREATION=1 DBA_JDBC_USERNAME=RSA_DBA DBA_JDBC_PASSWORD=VMware1! COMPUTER_FQDN=vc.lab.local IS_SSPI_NETWORK_SERVICE_ACCOUNT=1 SSO_HTTPS_PORT=7444"' -Wait -Verb RunAs
		Write-BuildLog "Add AD to SSO since the installer failed to add"
		Start-Process "C:\Program Files\VMware\Infrastructure\SSOServer\utils\rsautil" -ArgumentList ' manage-identity-sources -a create -u admin -p VMware1! -r ldap://dc.lab.local --ldap-port 3268 -d lab.local -l LAB --principal-base-dn dc=lab,dc=local --group-base-dn dc=lab,dc=local -f ldap://dc2.lab.local -L administrator@lab.local -P VMware1!' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.1 Web Client."
		Start-Process B:\VIM_51\vSphere-WebClient\VMware-WebClient.exe -ArgumentList '/L1033 /v" HTTP_PORT=9090 HTTPS_PORT=9443 SSO_ADMIN_USER=admin@System-Domain SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc.lab.local:7444/lookupservice/sdk /qr"' -Wait  -Verb RunAs
		Write-BuildLog "Installing vCenter 5.1 Inventory Service."
		Start-Process "B:\VIM_51\Inventory Service\VMware-inventory-service.exe" -ArgumentList '/L1033 /v" HTTPS_PORT=10443 XDB_PORT=10109 FEDERATION_PORT=10111 QUERY_SERVICE_NUKE_DATABASE=1 TOMCAT_MAX_MEMORY_OPTION=S SSO_ADMIN_USER=admin@System-Domain SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc.lab.local:7444/lookupservice/sdk /qr"' -Wait -Verb RunAs
		Write-BuildLog "Installing vCenter 5.1."
		Start-Process B:\VIM_51\vCenter-Server\VMware-vcserver.exe -ArgumentList '/L1033 /v" /qr DB_SERVER_TYPE=Custom DB_DSN=vCenterDB DB_USERNAME=vpx DB_PASSWORD=VMware1! FORMAT_DB=1 JVM_MEMORY_OPTION=S SSO_ADMIN_USER=admin@System-Domain SSO_ADMIN_PASSWORD=VMware1! LS_URL=https://vc.lab.local:7444/lookupservice/sdk IS_URL=https://vc.lab.local:10443 VC_ADMIN_USER=administrator@vc VC_ADMIN_IS_GROUP_VPXD_TXT=0 VPX_USES_SYSTEM_ACCOUNT=1 VCS_GROUP_TYPE=Single VCS_ADAM_LDAP_PORT=389 VCS_ADAM_SSL_PORT=636 VCS_HTTPS_PORT=443 VCS_HTTP_PORT=80 TC_HTTP_PORT=8080 TC_HTTPS_PORT=8443 VCS_WSCNS_PORT=60099 VCS_HEARTBEAT_PORT=902"' -Wait -Verb RunAs
		Write-BuildLog "Installing vSphere Client 5.1."
		Start-Process B:\VIM_51\redist\vjredist\x64\vjredist64.exe -ArgumentList '/q:a /c:"install.exe /q"' -Wait -Verb RunAs
		Start-Process B:\VIM_51\vSphere-Client\VMware-viclient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
		$null = mkdir "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		$null = copy B:\Automate\vc\SSHAutoConnect\*.* "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Plugins\SSHAutoConnect"
		If ($DeployVUM) {
			Write-BuildLog "Installing vSphere Client 5.1 VUM Plugin."
			Start-Process B:\VIM_51\updateManager\VMware-UMClient.exe -ArgumentList '/qb /s /w /L1033 /v" /qr"' -Wait -Verb RunAs
			Write-BuildLog "Installing vCenter Update Manager 5.1."
			$Arguments =  '/L1033 /v" /qr VMUM_SERVER_SELECT=vc.lab.local VC_SERVER_IP=vc.lab.local VC_SERVER_ADMIN_USER=\"vc\administrator\" VC_SERVER_ADMIN_PASSWORD=' + $AdminPWD +' VCI_DB_SERVER_TYPE=Custom VCI_FORMAT_DB=1 DB_DSN=VUM DB_USERNAME=vpx DB_PASSWORD=VMware1!"'
			Start-Process B:\VIM_51\updateManager\VMware-UpdateManager.exe -ArgumentList $Arguments -Wait -Verb RunAs
		}
		Write-BuildLog "Installing vSphere Web Client Integration plugin."
		copy "C:\Program Files\VMware\Infrastructure\vSphereWebClient\server\work\org.eclipse.virgo.kernel.deployer_3.0.3.RELEASE\staging\global\bundle\com.vmware.vsphere.client.containerapp\5.1.0\container-app-war-5.1.0.war\vmrc\VMware-ClientIntegrationPlugin-5.1.0.exe" c:\
		Start-Process C:\VMware-ClientIntegrationPlugin-5.1.0.exe -ArgumentList '/v/qn' -Wait -Verb RunAs
	}
	5 {
		Write-BuildLog "Starting vCenter 5 automation."
		if (Test-Path "b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
			Start-Process b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList ' /i C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				regedit -s B:\Automate\vc\vCenterDB.reg
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				regedit -s B:\Automate\vc\vCenterDB.reg
			}
		} else {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		Write-BuildLog "Installing vCenter and vSphere client."
		copy b:\automate\vc\vc50.cmd c:\
		start-process c:\vc50.cmd -Wait -verb RunAs
	}
	4 {
		Write-BuildLog "Starting vCenter 4.1 automation."
		if (Test-Path "b:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE") {
			Write-BuildLog "SQL Server 2005 Express for vCenter 4.1 found; installing."
			Start-Process b:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path c:\temp\setup\sqlncli_x64.msi) {
				Start-Process msiexec -ArgumentList '/i C:\temp\setup\sqlncli_x64.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			}
		} else {
			Write-BuildLog "SQL Server 2005 Express for vCenter 4.1 not found. Exiting."
			Read-Host "Press <Enter> to exit"
			exit
		}
		copy b:\automate\vc\vc41.cmd c:\
		start-process c:\vc41.cmd -Wait -verb RunAs
	}
	Base {
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
		} ElseIf (Test-Path "b:\VIM_51\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
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
		} elseif (Test-Path "b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe") {
			Write-BuildLog "SQL Server 2008 R2 Express SP1 for vCenter 5.0 found; installing."
			Start-Process b:\VIM_50\redist\SQLEXPR\SQLEXPR_x64_ENU.exe -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path "C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList ' /i C:\temp\pcusource\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
			} elseif (Test-Path "C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi") {
				Write-BuildLog "Installing SQL native client."
				Start-Process msiexec -ArgumentList '/i C:\temp\1033_enu_lp\x64\setup\x64\sqlncli.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				regedit -s B:\Automate\vc\vCenterDB.reg
			}
		} elseif (Test-Path "b:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE") {
			Write-BuildLog "SQL Server 2005 Express for vCenter 4.1 found; installing."
			Start-Process b:\VIM_41\redist\SQLEXPR\x64\SQLEXPR.EXE -ArgumentList '/extract:c:\temp /quiet' -Wait -Verb RunAs
			if (Test-Path c:\temp\setup\sqlncli_x64.msi) {
				Start-Process msiexec -ArgumentList '/i C:\temp\setup\sqlncli_x64.msi ADDLOCAL=ALL IACCEPTSQLNCLILICENSETERMS=YES /qb' -Wait -Verb RunAs
				regedit -s B:\Automate\vc\vCenterDB.reg
			}
		}
	}
	None {}
}

If ($viewinstall -ne "None") {
	$Files = get-childitem "b:\view$viewinstall"
	for ($i=0; $i -lt $files.Count; $i++) {
		If ($Files[$i].Name -like "VMware-viewcomposer*") {$Installer = $Files[$i].FullName}
	}
}
switch ($viewinstall) {
	75 {
		if (Test-Path "B:\View75\VMware-viewcomposer-*.exe") {
			Write-BuildLog "Setup install VMware View 7.5 Composer, reboot required before install"
			copy-item $Installer C:\
		}
	} 70 {
		if (Test-Path "B:\View70\VMware-viewcomposer-*.exe") {
			Write-BuildLog "Setup install VMware View 7.0 Composer, reboot required before install"
			copy-item $Installer C:\
		}
	}	60 {
		if (Test-Path "B:\View60\VMware-viewcomposer-*.exe") {
			Write-BuildLog "Setup install VMware View 6.0 Composer, reboot required before install"
			copy-item $Installer C:\
		}
	}	53 {
		if (Test-Path "B:\View53\VMware-viewcomposer-5.3*.exe") {
			Write-BuildLog "Setup install VMware View 5.3 Composer, reboot required before install"
			copy-item $Installer C:\
		}
	}	52 {
		if (Test-Path "B:\View52\VMware-viewcomposer-5.2*.exe") {
			Write-BuildLog "Setup install VMware View 5.2 Composer, reboot required before install"
			copy-item $Installer C:\
		}
	}
	51 {
		if (Test-Path "B:\View51\VMware-viewcomposer-3.0*.exe") {
			Write-BuildLog "Installing VMware View 5.1 Composer"
			Start-Process B:\View51\VMware-viewcomposer-3.0.0-691993.exe -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
		}
	}
	50 {
		if (Test-Path "B:\View50\VMware-viewcomposer-2.7*.exe") {
			Write-BuildLog "Installing VMware View 5.0 Composer"
			Start-Process B:\View50\VMware-viewcomposer-2.7.0-481620.exe -ArgumentList '/s /v" /qn AgreeToLicense="Yes" DB_USERNAME="VMview" DB_PASSWORD="VMware1!" DB_DSN="ViewComposer" REBOOT="ReallySuppress" "' -Wait -Verb RunAs
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

if ($buildvm -and (Test-Path B:\Win2k3.iso)) {
	Write-BuildLog "Creating fully automated Windows 2003 install ISO."
	$null = New-Item -Path c:\temp\Win2K3 -ItemType Directory -Force
	cd c:\temp\Win2K3
	. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa b:\win2k3.iso >> c:\temp\Extractlog.txt
	cmd /c copy C:\temp\Win2K3\[BOOT]\Boot-NoEmul.img C:\temp\Win2K3\Win2K3.img
	if (!(Test-Path b:\Auto2K3.iso)) {
		Copy-Item -Path C:\temp\Auto2K3.sif -Destination c:\temp\Win2K3\i386\winnt.sif -Force
		Copy-Item B:\Automate\_Common\Auto2K3.cmd c:\temp\Win2k3
		b:\automate\vc\mkisofs -b Win2K3.img -c boot.catalog -hide boot.catalog -no-emul-boot -boot-load-seg 1984 -boot-load-size 4 -iso-level 2 -J -l -D -N -joliet-long -quiet -relaxed-filenames -V "WIN2K3" -o b:\Auto2K3.iso . 
	}
	if (!(Test-Path b:\Windows2K3.iso)) {
		Write-BuildLog "Creating Lab Windows 2003 install ISO"
		Copy-Item -Path C:\temp\Lab2K3.sif -Destination c:\temp\Win2K3\i386\winnt.sif -Force		
		Copy-Item -Path B:\Automate\_Common\extpart.exe -Destination c:\temp\Win2K3\ -Force		
		Copy-Item -Path B:\Automate\_Common\cpubusy.vbs -Destination c:\temp\Win2K3\ -Force		
		Copy-Item -Path B:\Automate\_Common\iometer.exe -Destination c:\temp\Win2K3\ -Force		
		Copy-Item -Path B:\Automate\_Common\Nested.reg -Destination c:\temp\Win2K3\ -Force		
		b:\automate\vc\mkisofs -b win2k3.img -c boot.catalog -hide boot.catalog -no-emul-boot -boot-load-seg 1984 -boot-load-size 4 -iso-level 2 -J -l -D -N -joliet-long -quiet -relaxed-filenames -V "WIN2K3" -o b:\Windows2K3.iso . 
	}
	if (Test-Path "C:\ProgramData\VMware\VMware VirtualCenter\sysprep\svr2003") {
		Write-BuildLog "Setting up sysprep for Windows 2003."
		expand -r c:\temp\Win2K3\Support\Tools\deploy.cab -f:* "C:\ProgramData\VMware\VMware VirtualCenter\sysprep\svr2003" >> c:\temp\Extractlog.txt
	} elseif (Test-Path "C:\ProgramData\VMware\vCenterServer\cfg\vmware-vpx\sysprep\svr2003") {
		Write-BuildLog "Setting up sysprep for Windows 2003."
		expand -r c:\temp\Win2K3\Support\Tools\deploy.cab -f:* "C:\ProgramData\VMware\vCenterServer\cfg\vmware-vpx\sysprep\svr2003" >> c:\temp\Extractlog.txt
	} else {
		copy c:\temp\Win2K3\Support\Tools\deploy.cab c:\
	}
}
if ($buildviewvm -and (Test-Path B:\WinXP.iso)) {
	$null = New-Item -Path c:\temp\WinXP -ItemType Directory -Force
	cd c:\temp\WinXP
	. "C:\Program Files\7-Zip\7z.exe" x -r -y -aoa b:\winXP.iso >> c:\temp\Extractlog.txt
	if (Test-Path "C:\ProgramData\VMware\VMware VirtualCenter\sysprep\xp") {
		Write-BuildLog "Setting up sysprep for Windows XP."
		expand -r c:\temp\WinXP\Support\Tools\deploy.cab -f:* "C:\ProgramData\VMware\VMware VirtualCenter\sysprep\xp" >> c:\temp\Extractlog.txt
	} elseif (Test-Path "C:\ProgramData\VMware\vCenterServer\cfg\vmware-vpx\sysprep\xp") {
		Write-BuildLog "Setting up sysprep for Windows XP."
		expand -r c:\temp\WinXP\Support\Tools\deploy.cab -f:* "C:\ProgramData\VMware\vCenterServer\cfg\vmware-vpx\sysprep\xp" >> c:\temp\Extractlog.txt
	}
	if (!(Test-Path b:\AutoXP.iso)){
		Write-BuildLog "Creating fully automated Windows XP install ISO for VMware View"
		cmd /c copy c:\temp\WinXP\[BOOT]\Boot-NoEmul.img c:\temp\WinXP\winXP.img
		rd c:\temp\WinXP\[BOOT]
		Move-Item -Path C:\temp\AutoXP.sif -Destination c:\temp\WinXP\i386\winnt.sif
		$null = New-Item -Path  C:\temp\WinXP\$OEM$ -ItemType Directory -Force
		$null = New-Item -Path  C:\temp\WinXP\$OEM$\TEXTMODE -ItemType Directory -Force
		copy B:\Automate\_Common\XPDrivers\*.* C:\temp\WinXP\$OEM$\TEXTMODE\
		copy B:\Automate\_Common\AutoXP.cmd C:\temp\WinXP\
		cd c:\temp\WinXP
		b:\automate\vc\mkisofs -b winXP.img -c boot.catalog -hide boot.catalog -no-emul-boot -boot-load-seg 1984 -boot-load-size 4 -iso-level 2 -J -l -D -N -joliet-long -quiet -relaxed-filenames -V "WINXP" -o b:\AutoXP.iso .
	}
	cd c:\
}

if (!(($vcinstall -eq "None") -or ($vcinstall -eq "Base"))) {
	$PCLIVernum = deployPowerCLI
	Copy-Item -Path "b:\automate\vc\Phase2.ps1" "c:\Phase2.ps1" -force
	reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /v Build /t REG_SZ /d "c:\windows\syswow64\WindowsPowerShell\v1.0\powershell.exe c:\Phase2.ps1" /f
}
Write-BuildLog "Cleanup and creating Desktop shortcuts."
regedit -s b:\Automate\vc\vSphereClient.reg
Remove-Item "C:\Users\Public\Desktop\*.lnk"
Remove-Item c:\eula*.*
Remove-Item c:\install*.*
Remove-Item c:\VC*
Remove-Item c:\VMware-ClientIntegrationPlugin*.exe
Remove-Item c:\temp\* -Force -Recurse
copy b:\Automate\vc\Shortcuts.vbs c:\Shortcuts.vbs
wscript c:\Shortcuts.vbs
copy b:\Automate\*.ps1 c:\
If ((([System.Environment]::OSVersion.Version.Major *10) + [System.Environment]::OSVersion.Version.Minor) -ge 62) {
	Write-BuildLog "Disable Internet Explorer Enhanced Security to allow access to Web Client"
	$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
	$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
	Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
	Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
}
Write-BuildLog "Installing VMware tools, build complete after reboot."
if (Test-Path B:\VMTools\setup64.exe) {
	#Read-Host "End of install checkpoint, before VMTools"
	if (([bool]($emailto -as [Net.Mail.MailAddress])) -and ($SmtpServer -ne "none") -and (($vcinstall -eq "None") -or ($vcinstall -eq "Base"))){
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
}

Read-Host "Computer will restart when VMware Tools is installed"
exit