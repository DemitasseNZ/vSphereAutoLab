# Script to add add ESX servers to vCenter and do initial configuration
#
#
# Version 0.9
#
#
if (Test-Path C:\PSFunctions.ps1) {
	. "C:\PSFunctions.ps1"
} else {
	Write-BuildLog "PSFunctions.ps1 not found. Please copy all PowerShell files from B:\Automate to C:\ and rerun AddHosts.ps1"
	Read-Host "Press <Enter> to exit"	
	exit
}
#if ((Test-Administrator) -and (Test-Path "C:\Program Files\VMware\VMware Tools\VMwareToolboxCmd.exe")) {
#    Write-BuildLog " "
#    Write-BuildLog "This script should not be 'Run As Administrator'" 
#    Write-BuildLog " "
#    Write-BuildLog "Just double click the shortcut" 
#    Write-BuildLog " "
#	Read-Host "Press <Enter> to exit"	
#	exit
#}
$a = (Get-Host).UI.RawUI
$b = $a.WindowSize
$b.Height = $a.MaxWindowSize.Height -1 
$a.WindowSize = $b
# WASP is a 64bit plugin, the Guest Cust. PowerCLI commands are only 32bit
#import-module C:\windows\system32\WASP.dll
#select-window -Title "Administrator: C:\*" | set-windowposition -left 3 -top 3

$Subnet = ((Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName .).IPAddress[0]).split(".")[2]
If ($Subnet -eq "199") {
	Write-BuildLog "Building Primary Site"
	$HostPrefix = "host"
	$DCName = "Lab"
	$ClusterName = "Local"
	$SRM = $False
}
If ($Subnet -eq "201") {
	Write-BuildLog "Building SRM Site"
	$HostPrefix = "host1"
	$DCName = "SRM"
	$ClusterName = "DR"
	$SRM = $True
}

if ((Get-Service vpxd).Status -eq "Starting") {
	Write-BuildLog "The vCenter service is still starting; script will pause until service has started."
	do {
		Start-Sleep -Seconds 30
	} until ((Get-Service vpxd).Status -eq "Running")
} elseif ((Get-Service vpxd).Status -eq "Stopped") {
	Write-BuildLog "The vCenter service is stopped. Please verify the DC VM is powered on and databases have started."
	Read-Host "Press <Enter> to exit"
	exit
}

if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) {
	try {
		Write-BuildLog "Loading PowerCLI plugin, this may take a little while." 
		Add-PSSnapin VMware.VimAutomation.Core
	}
	catch {
		Write-BuildLog "Unable to load the PowerCLI plugin. Please verify installation or install VMware PowerCLI and run this script again."
		Read-Host "Press <Enter> to exit"
		exit
	}
}
for ($i=1;$i -le 4; $i++) {
    $vmhost = "$HostPrefix$i.lab.local"
    $ping = new-object System.Net.NetworkInformation.Ping
    $Reply = $ping.send($vmhost)
    if ($Reply.status –eq "Success") {
		$MaxHosts = $i
    } else {
		$i =4
	}
}
If (!($MaxHosts -ge 2)){
	Write-Host "Couldn't find first two hosts to build, need host1 & host2 built before running this script"
	Read-Host "Build the hosts & rerun this script"
	Exit
}
Write-BuildLog " "
If (!(Test-Path "B:\*")) { Net use B: \\nas\Build}
if (Test-Path "B:\Automate\automate.ini") {
	Write-BuildLog "Determining automate.ini settings."  
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
	$createds = ((Select-String -SimpleMatch "BuildDatastores=" -Path "B:\Automate\automate.ini").line).substring(16).Trim()
	$createvm = ((Select-String -SimpleMatch "BuildVM=" -Path "B:\Automate\automate.ini").line).substring(8).Trim()
	$createxp = ((Select-String -SimpleMatch "BuildViewVM=" -Path "B:\Automate\automate.ini").line).substring(12).Trim()
	if ($createds -like "true") {
		$createds = $true
		Write-BuildLog " Datastores will be built and added to vCenter." 
	} else {
		$createds = $false
	}
	if ($createvm -like "true") {
		$createvm = $true
		$ProdKey = ((Select-String -SimpleMatch "ProductKey=" -Path "B:\Automate\automate.ini" -List).line).substring(11).Trim()
		Write-BuildLog "  Windows 2003 VM for Lab will be created." 
	} else {
		$createvm = $false
	}
	if ($createxp -like "true") {
		$createxp = $true
		$XPKey = ((Select-String -SimpleMatch "ViewVMProductKey=" -Path "B:\Automate\automate.ini").line).substring(17)
		Write-BuildLog " Windows XP VM for VMware View Lab to be built." 
	} else {
		$createxp = $false
	}
} else {
	Write-BuildLog "Unable to find B:\Automate\automate.ini. Where did it go?" 
}

Write-BuildLog "Connect to vCenter; this takes a while and may show a warning in yellow"  

try {
	If ($SRM -eq $True) {$Connect = "vc2.lab.local"}
	Else {$VCServer = "vc.lab.local"}
	$Connect = Connect-VIServer $VCServer 
}
catch {
	Write-BuildLog "Unable to connect to vCenter. Exiting."  
	Read-Host "Press <Enter> to exit" 
	exit
}
Write-BuildLog "Create datacenter and cluster" 
if ((Get-DataCenter | where {$_.Name -eq $DCName}) -eq $null) {
    $newDC = New-DataCenter -Location (Get-Folder -NoRecursion) -Name $DCName
	$dc = $newDC.ExtensionData.MoRef  
	$pool = New-Object VMware.Vim.IpPool  
	$pool.name = "MyIPPool"  
	$pool.ipv4Config = New-Object VMware.Vim.IpPoolIpPoolConfigInfo  
	$pool.ipv4Config.subnetAddress = "192.168.$Subnet.0"  
	$pool.ipv4Config.netmask = "255.255.255.0"  
	$pool.ipv4Config.gateway = "192.168.$Subnet.2"  
	$pool.ipv4Config.range = "192.168.$Subnet.200#16"  
	$pool.ipv4Config.dns = New-Object System.String[] (1)  
	$pool.ipv4Config.dns[0] = "192.168.$Subnet.4"  
	$pool.ipv4Config.dhcpServerAvailable = $false  
	$pool.ipv4Config.ipPoolEnabled = $true  
	$pool.ipv6Config = New-Object VMware.Vim.IpPoolIpPoolConfigInfo  
	$pool.ipv6Config.subnetAddress = ""  
	$pool.ipv6Config.netmask = "ffff:ffff:ffff:ffff:ffff:ffff::"  
	$pool.ipv6Config.gateway = ""  
	$pool.ipv6Config.dns = New-Object System.String[] (1)  
	$pool.ipv6Config.dns[0] = ""  
	$pool.ipv6Config.dhcpServerAvailable = $false  
	$pool.ipv6Config.ipPoolEnabled = $false  
	$pool.dnsDomain = ""  
	$pool.dnsSearchPath = ""  
	$pool.hostPrefix = ""  
	$pool.httpProxy = ""  
	$pool.networkAssociation = New-Object VMware.Vim.IpPoolAssociation[] (1)  
	$pool.networkAssociation[0] = New-Object VMware.Vim.IpPoolAssociation  
	$pool.networkAssociation[0].network = New-Object VMware.Vim.ManagedObjectReference  
	$pool.networkAssociation[0].network.type = "DistributedVirtualPortgroup"  
	$pool.networkAssociation[0].network.Value = "dvportgroup-178"  
	$pool.networkAssociation[0].networkName = ""  
	$PoolManager = Get-View -Id 'IpPoolManager-IpPoolManager'  
	$Nul = $PoolManager.CreateIpPool($dc, $pool)  
}
if ((Get-Cluster | where {$_.Name -eq $ClusterName}) -eq $null) {
    $Cluster = New-Cluster $ClusterName -DRSEnabled -Location $DCName -DRSAutomationLevel FullyAutomated
}

for ($i=1;$i -le $MaxHosts; $i++) {
    $Num = $i +10
    $VMHost = $HostPrefix
    $VMHost += $i
    $VMHost += ".lab.local"
    $VMotionIP = "172.16.$SubNet."
    $VMotionIP += $Num
    $IPStoreIP1 = "172.17.$SubNet."
    $IPStoreIP1 += $Num
    $IPStoreIP2 = "172.17.$SubNet."
    $Num = $i +20
    $IPStoreIP2 += $Num
    $FTIP = "172.16.$SubNet."
    $FTIP += $Num
    $Num = $i +40
    $vHeartBeatIP = "172.16.$SubNet."
    $vHeartBeatIP += $Num
    Write-BuildLog $VMHost 
    if ((Get-VMHost | where {$_.Name -eq $VMHost}) -eq $null) {
        $Null = Add-VMHost $VMhost -user root -password $AdminPWD -Location $ClusterName -force:$true
		Start-Sleep -Seconds 30
		try {
			$null = Get-VMHost $VMHost
		}
		catch {
			Write-BuildLog "Unable to find " $VMHost "; please verify the host is built and rerun the AddHosts script."
			Read-Host "Press <Enter> to exit"
			exit
		}			
        Start-Sleep 5
		While ((Get-VMHost $VMHost).ConnectionState -ne "Connected"){
            Write-BuildLog " "
            Write-BuildLog $VMHost " is not yet connected. Pausing for 5 seconds."
            Write-BuildLog " "
			Start-Sleep 5
			}
		$VMHostObj = Get-VMHost $VMHost
        if (($vmhostObj.ExtensionData.Config.Product.FullName.Contains("ESXi")) -and ((get-VmHostNtpServer $VMhostobj) -ne "192.168.199.4")) {
            # These services aren't relevant on ESX Classic, only ESXi
            $null = Add-VMHostNtpServer -NtpServer "192.168.199.4" -VMHost $VMhost
            $ntp = Get-VMHostService -VMHost $VMhost | Where {$_.Key -eq "ntpd"}
            $null = Set-VMHostService $ntp -Policy "On"
            $SSH = Get-VMHostService -VMHost $VMhost | Where {$_.Key -eq "TSM-SSH"}
            $null = Set-VMHostService $SSH -Policy "On"
            $TSM = Get-VMHostService -VMHost $VMhost | Where {$_.Key -eq "TSM"}
            $null = Set-VMHostService $TSM -Policy "On"
            if ($vmhostObj.version.split(".")[0] -ne "4") {
                if ($PCLIVerNum -ge 51) {
					$null = Get-AdvancedSetting -Entity $VMHostObj -Name "UserVars.SuppressShellWarning" | Set-AdvancedSetting -Value "1" -confirm:$false
				} else {
					$null = Set-VMHostAdvancedConfiguration -vmhost $VMhost -Name "UserVars.SuppressShellWarning" -Value 1
				}
            }
        }
        $DSName = $VMHost.split('.')[0]
        $DSName += "_Local"
        $sharableIds = Get-ShareableDatastore | Foreach {$_.ID } 
        $null = Get-Datastore -vmhost $vmhost | Where {$sharableIds -notcontains $_.ID } | Set-DataStore -Name $DSName
        $switch = Get-VirtualSwitch -vmHost $vmHostobj 
		if($switch -isnot [system.array]) {
			Write-BuildLog " Configuring network." 
			$null = set-VirtualSwitch $switch -Nic vmnic0,vmnic1 -confirm:$false
			$pg = New-VirtualPortGroup -Name vMotion -VirtualSwitch $switch 
			if ($vmhostObj.ExtensionData.Config.Product.FullName.Contains("ESXi")) {
				$null = New-VMHostNetworkAdapter -VMHost $vmhost -Portgroup $pg -VirtualSwitch $switch -IP $VMotionIP -SubnetMask "255.255.255.0" -vMotionEnabled:$true -ManagementTrafficEnabled:$True
			} else {
				$null = New-VMHostNetworkAdapter -VMHost $vmhost -Portgroup $pg -VirtualSwitch $switch -IP $VMotionIP -SubnetMask "255.255.255.0" -vMotionEnabled:$true 
				$pg = New-VirtualPortGroup -Name vHeartBeat -VirtualSwitch $switch 
				$null = New-VMHostNetworkAdapter -VMHost $vmhost -Portgroup $pg -VirtualSwitch $switch -IP $vHeartBeatIP -SubnetMask "255.255.255.0" -ConsoleNIC 
			}
			$pg = New-VirtualPortGroup -Name FT -VirtualSwitch $switch 
			$null = New-VMHostNetworkAdapter -VMHost $vmhost -Portgroup $pg -VirtualSwitch $switch -IP $FTIP -SubnetMask "255.255.255.0" -FaultToleranceLoggingEnabled:$true
			$pg = New-VirtualPortGroup -Name IPStore1 -VirtualSwitch $switch 
			$null = New-VMHostNetworkAdapter -VMHost $vmhost -Portgroup $pg -VirtualSwitch $switch -IP $IPStoreIP1 -SubnetMask "255.255.255.0" 
			$pg = New-VirtualPortGroup -Name IPStore2 -VirtualSwitch $switch 
			$null = New-VMHostNetworkAdapter -VMHost $vmhost -Portgroup $pg -VirtualSwitch $switch -IP $IPStoreIP2 -SubnetMask "255.255.255.0" 
			$null = Get-VMHostStorage $VMHost | Set-VMHostStorage -SoftwareIScsiEnabled $true
			$null = get-virtualportgroup -name vMotion | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicActive vmnic1
			$null = get-virtualportgroup -name vMotion | Get-NicTeamingPolicy | Set-NicTeamingPolicy -MakeNicStandby vmnic0
			$pnic = (Get-VMhostNetworkAdapter -VMHost $VMHost -Physical)[2]
			$switch = New-VirtualSwitch -VMhost $vmHost -Nic $pnic.DeviceName -NumPorts 128 -Name vSwitch1
			$null = New-VirtualPortGroup -Name Servers -VirtualSwitch $switch
			$null = New-VirtualPortGroup -Name Workstations -VirtualSwitch $switch
			$null = set-VirtualSwitch $switch -Nic vmnic2,vmnic3 -confirm:$false
			Start-Sleep -Seconds 30
			If ($SRM -ne $True) {
				Write-BuildLog " Add NFS datastores" 
				# Build datastore now added in unattend script
				#$null = New-Datastore -nfs -VMhost $vmhost -Name Build -NFSHost "172.17.199.7" -Path "/mnt/LABVOL/Build" -readonly
				$null = New-Datastore -nfs -VMhost $vmhost -Name NFS01 -NFSHost "172.17.199.7" -Path "/mnt/LABVOL/NFS01"
				$null = New-Datastore -nfs -VMhost $vmhost -Name NFS02 -NFSHost "172.17.199.7" -Path "/mnt/LABVOL/NFS02"
			}
			if ($vmhostObj.version.split(".")[0] -ne "4") {
				$null = remove-datastore -VMhost $vmhost -datastore remote-install-location -confirm:$false
			}
			Write-BuildLog " Configuring iSCSI" 
			$MyIQN = "iqn.1998-01.com.vmware:" + $VMHost.split('.')[0]
			$null = Get-VMHostHba -VMhost $vmhost -Type iScsi | Set-VMHostHBA -IScsiName $MyIQN 
			If ($SRM -ne $True) {
				$null = Get-VMHostHba -VMhost $vmhost -Type iScsi | New-IScsiHbaTarget -Address 172.17.199.7 -Type Send
				$null = Get-VMHostStorage $VMHost -RescanAllHba
			}
		}
		$null = Move-VMhost $VMHost -Destination $ClusterName
		}
}

Write-BuildLog "Restarting all hosts for consistency. This will take a few minutes."  
$null = Get-VMHost -location $ClusterName | Restart-VMHost -confirm:$false -Force
Write-Host "Wait until all hosts have stopped pinging"
$PingStatus = @()
for ($i=1;$i -le $MaxHosts; $i++) {$PingStatus +=$True}
do {
	Start-Sleep -Seconds 1
	$ping = new-object System.Net.NetworkInformation.Ping
	for ($i=1;$i -le $MaxHosts; $i++) {
		$VMHost = $HostPrefix
		$VMHost += $i
		$VMHost += ".lab.local"
		If ((!(($ping.send($vmhost)).status –eq "Success")) -and ($PingStatus[$I-1] -eq $True)) {$PingStatus[$I-1] = $False}
	}
	$StayHere = $False
	for ($i=1;$i -le $MaxHosts; $i++) {
		If ($PingStatus[$I-1] -eq $True) {$StayHere = $True}
	}
} while ($StayHere)
Write-Host "Wait until all hosts are pinging"
do {
	Start-Sleep -Seconds 1
	$ping = new-object System.Net.NetworkInformation.Ping
	for ($i=1;$i -le $MaxHosts; $i++) {
		$VMHost = $HostPrefix
		$VMHost += $i
		$VMHost += ".lab.local"
		If (($ping.send($vmhost)).status –eq "Success")  {$PingStatus[$I-1] = $True}
	}
	$StayHere = $False
	for ($i=1;$i -le $MaxHosts; $i++) {
		If ($PingStatus[$I-1] -eq $False) {$StayHere = $True}
	}
} while ($StayHere)
Write-Host "Wait until all hosts are Connected"
for ($i=1;$i -le $MaxHosts; $i++) {$PingStatus +=$False}
do {
	Start-Sleep -Seconds 1
	for ($i=1;$i -le $MaxHosts; $i++) {
		$VMHost = $HostPrefix
		$VMHost += $i
		$VMHost += ".lab.local"
		If ((get-vmhost -name $VMHost).ConnectionState -eq "Connected" ) {$PingStatus[$I-1] = $True}
	}
	$StayHere = $False
	for ($i=1;$i -le $MaxHosts; $i++) {
		If ($PingStatus[$I-1] -eq $False) {$StayHere = $True}
	}
} while ($StayHere)
Write-Host "Wait 2 minutes so last host is properly up"
start-sleep 120
If ($SRM -ne $True){
	if (((Get-OSCustomizationSpec | where {$_.Name -eq "Windows"}) -eq $null) -and ($ProdKey -ne $null) ){
		$null = New-OsCustomizationSpec -Name Windows -OSType Windows -FullName Lab -OrgName Lab.local -NamingScheme VM -ProductKey $ProdKey -LicenseMode PerSeat -AdminPass VMware1! -Workgroup Workgroup -ChangeSid -AutoLogonCount 999
	}
	if (((Get-OSCustomizationSpec | where {$_.Name -eq "WinXP"}) -eq $null) -and ($ProdKey -ne $null)) {
		$null = New-OsCustomizationSpec -Name WinXP -OSType Windows -FullName Lab -OrgName Lab.local -NamingScheme VM -ProductKey $XPKey -LicenseMode PerSeat -AdminPass VMware1! -Workgroup Workgroup -ChangeSid -AutoLogonCount 999
	}
	$VMHostObj = Get-VMHost $VMHost
	If (($VMHostObj.Version.Split("."))[0] -eq "6") {
		$MinVMFSVer = 5
	} Else {
		$MinVMFSVer = 3
	}
	if ($CreateDS) {
		Write-BuildLog "Creating iSCSI datastores."  
		$iSCSILUNs = get-scsilun -vmhost $VMHost -CanonicalName "t10.*"
		if ($vmhostobj.version.split(".")[0] -ne "4") {
			if (((Get-Datastore | where {$_.Name -eq "iSCSI1"}) -eq $null) ) {
				$null = New-Datastore -VMHost $VMHost -Name iSCSI1 -Path $iSCSILUNs[0].CanonicalName -Vmfs -FileSystemVersion 5
				Write-BuildLog "Created iSCSi1 Datstore"  
			} else {
				Write-BuildLog "Registering all VMs found on existing datastore iSCSI1."  
				Register-VMs ("iSCSI1")
			}
		}
		if ((Get-Datastore | where {$_.Name -eq "iSCSI2"}) -eq $null) {
			$null = New-Datastore -VMHost $VMHost -Name iSCSI2 -Path $iSCSILUNs[1].CanonicalName -Vmfs -FileSystemVersion $MinVMFSVer
			Write-BuildLog "Created iSCSi2 Datastore"  
		}  else {
			Write-BuildLog "Registering all VMs found on existing datastore iSCSI2."  
			Register-VMs ("iSCSI2")
		}
		if ((Get-Datastore | where {$_.Name -eq "iSCSI3"}) -eq $null) {
			$null = New-Datastore -VMHost $VMHost -Name iSCSI3 -Path $iSCSILUNs[2].CanonicalName -Vmfs -FileSystemVersion $MinVMFSVer
			Write-BuildLog "Created iSCSi3 datstore"  
		} else {
			Write-BuildLog "Registering all VMs found on existing datastore iSCSI3"  
			Register-VMs ("iSCSI3")
		}
	}
	Write-BuildLog "Setting up HA on cluster since shared storage is configured." 
	$Cluster = Get-Cluster -Name $ClusterName
	$null = set-cluster -cluster $Cluster -HAEnabled:$True -HAAdmissionControlEnabled:$True -confirm:$false
	$null = New-AdvancedSetting -Entity $cluster -Type ClusterHA -Name 'das.isolationaddress1' -Value "192.168.$SubNet.4" -confirm:$false -force
	$null = New-AdvancedSetting -Entity $cluster -Type ClusterHA -Name 'das.isolationaddress2' -Value "172.17.$SubNet.7" -confirm:$false -force
	$null = New-AdvancedSetting -Entity $cluster -Type ClusterHA -Name 'das.usedefaultisolationaddress' -Value false -confirm:$false -force
	$spec = New-Object VMware.Vim.ClusterConfigSpecEx
	$null = $spec.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
	$null = $spec.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
	$null = $spec.dasConfig.admissionControlPolicy.cpuFailoverResourcesPercent = 50
	$null = $spec.dasConfig.admissionControlPolicy.memoryFailoverResourcesPercent = 50
	$Cluster = Get-View $Cluster
	$null = $Cluster.ReconfigureComputeResource_Task($spec, $true)
	Write-BuildLog "Waiting two minutes for HA to complete configuration." 
	Start-Sleep -Seconds 120
	
	$VMHostObj = Get-VMHost $VMHost
	$VMName="Template2012"
	if (($CreateVM) -and ((Get-VM -name $VMName -ErrorAction "SilentlyContinue") -eq $null ) -and (test-path "\\192.168.199.7\build\Win2012.ISO")) {
		$Datastore = Get-Datastore -VMhost $vmHost -name "NFS01"	
		Start-Sleep -Seconds 2
		if (!(Get-PSDrive -Name NFS01 -ErrorAction "SilentlyContinue")) {
			$null = New-PSDrive -Name NFS01 -PSProvider ViMdatastore -Root '\' -Location $Datastore
		}
		#Create new VM if existing VM or template doesn't exist
		if (!(Test-Path NFS01:\$VMName\$VMName.vmdk)) {
			Write-BuildLog "Creating Template2012 VM as Windows Server 2012"  
			If ((Get-vmhost)[0].version -lt "5.5.0"){
				$MyVM = New-VM -Name $VMName -VMhost $vmHost -datastore $Datastore -NumCPU 1 -MemoryMB 768 -DiskMB 16384 -DiskStorageFormat Thin -GuestID windows8Server64Guest 
				get-networkadapter $MyVM |set-networkadapter -type e1000 -confirm:$false 
			} Else {
				$MyVM = New-VM -Name $VMName -VMhost $vmHost -datastore $Datastore -NumCPU 1 -MemoryMB 768 -DiskMB 16384 -DiskStorageFormat Thin -GuestID windows8Server64Guest -Version "v8"
			}
			$null = New-CDDrive -VM $MyVM -ISOPath "[Build] /Win2012.ISO" -StartConnected
			$null = New-FloppyDrive -VM $MyVM -FloppyImagePath "[Build] Automate/BootFloppies/Nested2012.flp" -StartConnected
			$strBootHDiskDeviceName = "Hard disk 1"
			$viewVM = Get-View -ViewType VirtualMachine -Property Name, Config.Hardware.Device -Filter @{"Name" = "^$VMName$"}
			## get the VirtualDisk device, then grab its Key (DeviceKey, used later)
			$intHDiskDeviceKey = ($viewVM.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $strBootHDiskDeviceName}).Key
			## bootable Disk BootOption device, for use in setting BootOrder (the corresponding VirtualDisk device is bootable, assumed)
			$oBootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $intHDiskDeviceKey}
			## bootable CDROM device (per the docs, the first CDROM with bootable media found is used)
			$oBootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice
			## create the VirtualMachineConfigSpec with which to change the VM's boot order
			$spec = New-Object VMware.Vim.VirtualMachineConfigSpec -Property @{"BootOptions" = New-Object VMware.Vim.VirtualMachineBootOptions -Property @{BootOrder = $oBootableCDRom, $oBootableHDisk}}
			$null = $viewVM.ReconfigVM_Task($spec)
			Write-BuildLog "Powering on VM and installing Windows."  
			$null = Start-VM $MyVM
		} else {
			Write-BuildLog "Found existing WinTemplate."  
			if (Test-Path NFS01:\$VMName\$VMName.vmtx) {
				Write-BuildLog "Registering existing Template2012 template."  
				$vmxFile = Get-Item NFS01:\$VMName\$VMName.vmtx
				$null = New-Template -VMHost $VMHost -TemplateFilePath $vmxFile.DatastoreFullPath
				Write-BuildLog "Existing WinTemplate Template added to inventory."  
			}
		}
		Start-Sleep -Seconds 2
		$null = Remove-PSDrive NFS01
	}
	
	
	if ($vmhostObj.version.split(".")[0] -eq "4") {
		$Datastore = Get-Datastore -VMhost $vmHost -name "iSCSI2"
		$VMName="WinTemplate4"
	} else {
		$Datastore = Get-Datastore -VMhost $vmHost -name "iSCSI1"
		$VMName="WinTemplate"
	}
	
	if (($CreateVM) -and ((Get-VM -name $VMName -ErrorAction "SilentlyContinue") -eq $null ) -and (test-path "\\192.168.199.7\build\Auto2K3.ISO")) {
		if (!(Get-PSDrive -Name iSCSI1 -ErrorAction "SilentlyContinue")) {
			$null = New-PSDrive -Name iSCSI1 -PSProvider ViMdatastore -Root '\' -Location $Datastore
		}
		Start-Sleep -Seconds 2
		#Create new VM if existing VM or template doesn't exist
		if (!(Test-Path iSCSI1:\$VMName\$VMName.vmdk)) {
			Write-BuildLog "Creating WinTemplate VM Windows Server 2003."  
			If ((Get-vmhost)[0].version -lt "5.5.0"){
				$MyVM = New-VM -Name $VMName -VMhost $vmHost -datastore $Datastore -NumCPU 1 -MemoryMB 384 -DiskMB 3072 -DiskStorageFormat Thin -GuestID winNetEnterpriseGuest
			} Else {
				$MyVM = New-VM -Name $VMName -VMhost $vmHost -datastore $Datastore -NumCPU 1 -MemoryMB 384 -DiskMB 3072 -DiskStorageFormat Thin -GuestID winNetEnterpriseGuest -Version "v8"
			}
			$null = New-CDDrive -VM $MyVM -ISOPath "[Build] /Auto2K3.iso" -StartConnected
			Write-BuildLog "Powering on VM and installing Windows."  
			$null = Start-VM $MyVM
		} else {
			Write-BuildLog "Found existing WinTemplate."  
			if (Test-Path iSCSI1:\$VMName\$VMName.vmtx) {
				Write-BuildLog "Registering existing WinTemplate template."  
				$vmxFile = Get-Item iSCSI1:\$VMName\$VMName.vmtx
				$null = New-Template -VMHost $VMHost -TemplateFilePath $vmxFile.DatastoreFullPath
				Write-BuildLog "Existing WinTemplate Template added to inventory."  
			}
		}
		Start-Sleep -Seconds 2
		$null = Remove-PSDrive iSCSI1
	}
	$VMName = "WinXP"
	$Datastore = Get-Datastore "iSCSI2"
	if (($CreateXP) -and ((Get-VM -name $VMName -ErrorAction "SilentlyContinue") -eq $null ) -and (test-path "\\192.168.199.7\build\AutoXP.iso")) {
		if (!(Get-PSDrive -Name iSCSI2 -ErrorAction "SilentlyContinue")) {
			$null = New-PSDrive -Name iSCSI2 -PSProvider ViMdatastore -Root '\' -Location $Datastore
		}
		Start-Sleep -Seconds 2
		#Create new VM if existing VM or template doesn't exist
		if (!(Test-Path iSCSI2:\$VMName\$VMName.vmdk)) {
			Write-BuildLog "Creating Windows XP VM for View."  
			If ((Get-vmhost)[0].version -lt "5.5.0"){
				$MyVM = New-VM -Name $VMName -VMhost $vmHost -datastore $Datastore -NumCPU 1 -MemoryMB 384 -GuestID winXPProGuest
			} Else {
				$MyVM = New-VM -Name $VMName -VMhost $vmHost -datastore $Datastore -NumCPU 1 -MemoryMB 384 -GuestID winXPProGuest -Version "v8"
			}
			$null = New-CDDrive -VM $MyVM -ISOPath "[Build] /AutoXP.iso" -StartConnected
			$null = New-FloppyDrive -VM $MyVM -FloppyImagePath "[Build] Automate/BootFloppies/vmscsi-1.2.0.4.flp" -StartConnected
			$strBootHDiskDeviceName = "Hard disk 1"
			$viewVM = Get-View -ViewType VirtualMachine -Property Name, Config.Hardware.Device -Filter @{"Name" = "^$VMName$"}
			## get the VirtualDisk device, then grab its Key (DeviceKey, used later)
			$intHDiskDeviceKey = ($viewVM.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $strBootHDiskDeviceName}).Key
			## bootable Disk BootOption device, for use in setting BootOrder (the corresponding VirtualDisk device is bootable, assumed)
			$oBootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $intHDiskDeviceKey}
			## bootable CDROM device (per the docs, the first CDROM with bootable media found is used)
			$oBootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice
			## create the VirtualMachineConfigSpec with which to change the VM's boot order
			$spec = New-Object VMware.Vim.VirtualMachineConfigSpec -Property @{"BootOptions" = New-Object VMware.Vim.VirtualMachineBootOptions -Property @{BootOrder = $oBootableCDRom, $oBootableHDisk}}
			$null = $viewVM.ReconfigVM_Task($spec)
			$Null = Start-VM $MyVM
		} else {
			Write-BuildLog "Found existing WinXP."  
			if (Test-Path iSCSI1:\$VMName\$VMName.vmtx) {
				Write-BuildLog "Registering existing WinTemplate template."  
				$vmxFile = Get-Item iSCSI2:\$VMName\$VMName.vmtx
				$null = New-Template -VMHost $VMHost -TemplateFilePath $vmxFile.DatastoreFullPath
				Write-BuildLog "Existing WinTemplate Template added to inventory."  
			}
		}
		Start-Sleep -Seconds 2
		$null = Remove-PSDrive iSCSI2
	}
	$VMName = "TTYLinux"
	if ((Get-VM -name $VMName -ErrorAction "SilentlyContinue") -eq $null ) {
		Write-BuildLog "Registering existing tiny TTYLinux VM."  
		$Datastore = Get-Datastore "Build"
		if (!(Get-PSDrive -Name Build -ErrorAction "SilentlyContinue")) {
			$null = New-PSDrive -Name Build -PSProvider ViMdatastore -Root '\' -Location $Datastore
		}
		$Datastore = Get-Datastore "iSCSI3"
		if (!(Get-PSDrive -Name iSCSI3 -ErrorAction "SilentlyContinue")) {
			$null = New-PSDrive -Name iSCSI3 -PSProvider ViMdatastore -Root '\' -Location $Datastore
		}
		if (!(Test-Path iSCSI3:/TTYLinux/TTYLinux.vmx)) {
			Write-BuildLog "Copying TTYLinux VM to iSCSI3 datastore."  
			$Datastore = Get-Datastore "iSCSI3"
			Copy-DatastoreItem Build:/Automate/ShellVMs/TTYLinux  iSCSI3:\ -recurse
		}
		$vmxFile = Get-Item iSCSI3:/TTYLinux/TTYLinux.vmx
		$null= New-VM -VMFilePath $VMXFile.DatastoreFullPath -VMHost $vmhost -Location "vm" -name "TTYLinux"
		Start-Sleep -Seconds 2
		$null = Remove-PSDrive Build
		$null = Remove-PSDrive iSCSI3
	}
}
Write-BuildLog " "

$null = Disconnect-VIServer -Server * -confirm:$false
if (Test-Path "C:\Program Files\VMware\VMware Tools\VMwareToolboxCmd.exe") {
	Read-Host " Configuration complete, press <Enter> to continue."
}
exit
