# NAS VM Build for AutoLab #

Using FreeNAS V 9.10

## VM Hardware Config ##
1 vCPU

512MB RAM

Boot Disk 8GB IDE

NFS Disk 80GB SCSI

iSCSI Disk 200GB SCSI

1 NIC on VMNet3

## Disk Config ##
NFS disk mounts as /mnt/LABVOL

iSCSI disk mounts as /mnt/iSCSI
## Services ##
Enabled Services

- CIFS
- iSCSI
- NFS
- SSH

## Network Config ##
**Interface Name:** Management

**IP Address:** 192.168.199.7

**Netmask:** 255.255.255.0

**Alias IP Address:** 172.17.199.7

**Alias Netmask:** 255.255.255.0

**Default Route:** 192.168.199.2

**Name Server:** Leave Blank
  
## SSH Config ##

- Allow root login with password

Open SSH connection as root

Create folders:

- /mnt/LABVOL/NFS01
- /mnt/LABVOL/NFS02
- /mnt/LABVOL/NFS03
- /mnt/LABVOL/NFS04
- /mnt/LABVOL/Build

Change permissions on Build to allow everyone RW

## NFS Config ##
**/mnt/LABVOL**

- All Dircetories Shared
- No network restrictions

**Sub Folders**

- Build
- NFS01
- NFS02
- NFS03
- NFS04

## CIFS Config ##
**/mnt/LABVOL/Build**

- Exported
- Browseable
- Allow guest access

## iSCSI Config ##

**File Extents**

**Name:** iSCSI1

- **Path:** /mnt/iSCSI/iSCSi1
- **Size:** 60GB

**Name:** iSCSI2

- **Path:** /mnt/iSCSI/iSCSi2
- **Size:** 30GB

**Name:** iSCSI3

- **Path:** /mnt/iSCSI/iSCSi3
- **Size:** 30GB

**Name:** iSCSI4

- **Path:** /mnt/iSCSI/iSCSi4
- **Size:** 30GB

**Targets**

- One Target per extent
- Target Name matches Extent name

**Portal**

- **Name: ** IP Storage
- **IP Address:** 172.17.199.7


 