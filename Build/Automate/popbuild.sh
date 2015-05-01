#!/bin/sh

mkdir /mnt/cd0
mkdir /mnt/cd1
mount /dev/sr0 /mnt/cd0
mount /dev/sr1 /mnt/cd1

if [ -f "/mnt/LABVOL/Build/ESXi60/vmware-esx-base-readme" ]
then
	echo "Already have ESXi 6.0 installer"
else
	if [ -f "/mnt/cd0/vmware-esx-base-readme" ]
	then
		echo "Found ESXi installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/ESXi60
	fi
	if [ -f "/mnt/cd1/vmware-esx-base-readme" ]
	then
		echo "Found ESXi installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/ESXi60		
	fi
fi

if [ -f "/mnt/LABVOL/Build/VIM_60/autorun.exe" ]
then
	echo "Already have vCentre 6.0 installer"
else
	if [ -f "/mnt/cd0/autorun.exe" ]
	then
		echo "Found vCentre installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/VIM_60	
	fi
	if [ -f "/mnt/cd1/autorun.exe" ]
	then
		echo "Found vCentre installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/VIM_60	
	fi
fi
umount -f /dev/sr0
umount -f /dev/sr1


