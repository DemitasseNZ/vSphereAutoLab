<#
.SYNOPSIS
	Customizes AutoLab PXE boot menu based on the vSphere and vCloud source files added to TFTP.
.DESCRIPTION
	Customizes AutoLab PXE boot menu based on the vSphere and vCloud source files added to TFTP.
.PARAMETER Version
	The Version parameter tells the script which PXE boot options to add to the PXE default menu.
.EXAMPLE
	C:\PS> PXEMenuConfig.ps1 ESXi51
.EXAMPLE
	C:\PS> PXEMenuConfig.ps1 ESXi50
.EXAMPLE
	C:\PS> PXEMenuConfig.ps1 ESXi41
.EXAMPLE
	C:\PS> PXEMenuConfig.ps1 ESX41
.EXAMPLE
	C:\PS> PXEMenuConfig.ps1 vCloud
#>

param($version)

. "C:\PSFunctions.ps1"

switch ($version) {
	ESXi67 {
		if ((Test-Path "C:\TFTP-Root\ESXi67\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "ESXi 6.7"))) {
		Write-BuildLog "Adding ESXi 6.7 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 67
  MENU LABEL ESXi 6.7 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi67.menu
"@
		} else {
			Write-BuildLog "ESXi 6.7 already in PXE Menu"
		}
	}
	ESXi65 {
		if ((Test-Path "C:\TFTP-Root\ESXi65\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "ESXi 6.5"))) {
		Write-BuildLog "Adding ESXi 6.5 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 65
  MENU LABEL ESXi 6.5 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi65.menu
"@
		} else {
			Write-BuildLog "ESXi 6.5 already in PXE Menu"
		}
	}
	ESXi60 {
		if ((Test-Path "C:\TFTP-Root\ESXi60\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "ESXi 6.0"))) {
		Write-BuildLog "Adding ESXi 6.0 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 60
  MENU LABEL ESXi 6.0 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi60.menu
"@
		} else {
			Write-BuildLog "ESXi 6.0 already in PXE Menu"
		}
	}
	ESXi55 {
		if ((Test-Path "C:\TFTP-Root\ESXi55\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "ESXi 5.5"))) {
		Write-BuildLog "Adding ESXi 5.5 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 5.5
  MENU LABEL ESXi 5.5 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi55.menu
"@
		} else {
			Write-BuildLog "ESXi 5.5 already in PXE Menu"
		}
	}
	ESXi51 {
		if ((Test-Path "C:\TFTP-Root\ESXi51\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "ESXi 5.1"))) {
		Write-BuildLog "Adding ESXi 5.1 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 5.1
  MENU LABEL ESXi 5.1 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi51.menu
"@
		} else {
			Write-BuildLog "ESXi 5.1 already in PXE Menu"
		}
	}
	ESXi50 {
		if ((Test-Path "C:\TFTP-Root\ESXi50\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "ESXi 5.0"))) {
		Write-BuildLog "Adding ESXi 5.0 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 5.0
  MENU LABEL ESXi 5.0 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi50.menu
"@
		}
	}
	ESXi41 {
		if (Test-Path "C:\TFTP-Root\ESXi41\*") {
		Write-BuildLog "Adding ESXi 4.1 option to PXE menu"
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL ESXi 4.1
  MENU LABEL ESXi 4.1 automated builds
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/ESXi41.menu
"@
		Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\ESXi41.menu" -Value @"

label esxi1-4
	kernel /ESXi41/mboot.c32
	append /ESXi41/vmkboot.gz ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx1-4.cfg --- /ESXi41/vmkernel.gz --- /ESXi41/sys.vgz --- /ESXi41/cim.vgz --- /ESXi41/ienviron.vgz --- /ESXi41/install.vgz 
	menu Label -- Host1 Automated

label esxi2-4
	kernel /ESXi41/mboot.c32
	append /ESXi41/vmkboot.gz ks=nfs://192.168.199.7/mnt/LABVOL/Build/Automate/Hosts/esx2-4.cfg --- /ESXi41/vmkernel.gz --- /ESXi41/sys.vgz --- /ESXi41/cim.vgz --- /ESXi41/ienviron.vgz --- /ESXi41/install.vgz 
	menu Label -- Host2 ESXi Automated
"@
		}
	}
	ESX41 {
		if ((Test-Path "C:\TFTP-Root\ESX41\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\ESXi41.menu" | Select-String -Pattern "ESX classic"))) {
			Write-BuildLog "Adding ESX 4.1 option to PXE menu"
			Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\ESXi41.menu" -Value @"

label esx2-4
	kernel /ESX41/vmlinuz
	append initrd=/ESX41/initrd.img debugLogToSerial=1 mem=512M ks=nfs:192.168.199.7:/mnt/LABVOL/Build/Automate/Hosts/esx2-4c.cfg 
	menu Label -- Host2 ESX classic Automated
"@
		}
	}
	vCloud {
		if (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\default" | Select-String -Pattern "vCloud") ) {
			Write-BuildLog "Adding vCloud option to PXE menu"
			Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\default" -Value @"

LABEL vCloud
  MENU LABEL vCloud Director automated build
  KERNEL pxelinux.cfg/menu.c32
  APPEND pxelinux.cfg/vCloud.menu
"@
		}
	}
	vCD51 {
		if ((Test-Path "B:\vCD_51\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\vCloud.menu" | Select-String -Pattern "vCloud Director 5.1"))){
			Write-BuildLog "Adding vCloud 5.1 option to PXE menu"
			Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\vCloud.menu" -Value @"
		
label vCloud51
	kernel /vCloud/vmlinuz
    append ksdevice=eth0 load_ramdisk=1 initrd=/vCloud/initrd.img network ks=nfs:nfsvers=3:192.168.199.7:/mnt/LABVOL/Build/Automate/vCloud/vcd51-ks.cfg
	menu Label vCloud Director 5.1 automated build (DVD iso)
	
label vCloud51
	kernel /vCloud/vmlinuz
    append ksdevice=eth0 load_ramdisk=1 initrd=/vCloud/initrd.img network ks=nfs:nfsvers=3:192.168.199.7:/mnt/LABVOL/Build/Automate/vCloud/vcd51-ks-min.cfg
	menu Label vCloud Director 5.1 automated build (minimal ISO)
"@
		}
	}
	vCD15 {
		if ((Test-Path "B:\vCD_15\*") -and (!(Get-Content "C:\TFTP-Root\pxelinux.cfg\vCloud.menu" | Select-String -Pattern "vCloud Director 1.5"))){
			Write-BuildLog "Adding vCloud 1.5 option to PXE menu"
			Add-Content -Path "C:\TFTP-Root\pxelinux.cfg\vCloud.menu" -Value @"

label vCloud15
	kernel /vCloud/vmlinuz
    append ksdevice=eth0 load_ramdisk=1 initrd=/vCloud/initrd.img network ks=nfs:nfsvers=3:192.168.199.7:/mnt/LABVOL/Build/Automate/vCloud/vcd15-ks.cfg
	menu Label vCloud Director 1.5 automated build (DVD iso)
	
label vCloud15
	kernel /vCloud/vmlinuz
    append ksdevice=eth0 load_ramdisk=1 initrd=/vCloud/initrd.img network ks=nfs:nfsvers=3:192.168.199.7:/mnt/LABVOL/Build/Automate/vCloud/vcd15-ks-min.cfg
	menu Label vCloud Director 1.5 automated build (minimal iso)
"@
		}
	}
}