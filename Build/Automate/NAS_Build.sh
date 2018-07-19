#!/bin/sh
mkdir /mnt/cd0
mkdir /mnt/cd1
mount /dev/sr0 /mnt/cd0
mount /dev/sr1 /mnt/cd1

if [ -f "/mnt/LABVOL/Build/ESXi51/vmware-esx-base-readme" ]
then
	echo "Already have ESXi 5.1 installer"
else
	if grep -q "VMware ESXi 5.1" "/mnt/cd0/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 5.1 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/ESXi51
	fi
	if grep -q "VMware ESXi 5.1" "/mnt/cd1/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 5.1 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/ESXi51		
	fi
fi
if [ -f "/mnt/LABVOL/Build/ESXi55/vmware-esx-base-readme" ]
then
	echo "Already have ESXi 5.5 installer"
else
	if grep -q "VMware ESXi 5.5" "/mnt/cd0/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 5.5 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/ESXi55
	fi
	if grep -q "VMware ESXi 5.5" "/mnt/cd1/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 5.5 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/ESXi55		
	fi
fi
if [ -f "/mnt/LABVOL/Build/ESXi60/vmware-esx-base-readme" ]
then
	echo "Already have ESXi 6.0 installer"
else
	if grep -q "VMware ESXi 6.0" "/mnt/cd0/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 6.0 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/ESXi60
	fi
	if grep -q "VMware ESXi 6.0" "/mnt/cd1/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 6.0 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/ESXi60		
	fi
fi
if [ -f "/mnt/LABVOL/Build/ESXi65/vmware-esx-base-readme" ]
then
	echo "Already have ESXi 6.5 installer"
else
	if grep -q "6.5.0" "/mnt/cd0/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 6.5 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/ESXi65
	fi
	if grep -q "6.5.0" "/mnt/cd1/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 6.5 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/ESXi65		
	fi
fi
if [ -f "/mnt/LABVOL/Build/ESXi67/vmware-esx-base-readme" ]
then
	echo "Already have ESXi 6.7 installer"
else
	if grep -q "VMware ESXi 6.7" "/mnt/cd0/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 6.7 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/ESXi67
	fi
	if grep -q "VMware ESXi 6.7" "/mnt/cd1/vmware-esx-base-osl.txt"
	then
		echo "Found ESXi 6.7 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/ESXi67		
	fi
fi

if [ -f "/mnt/LABVOL/Build/VIM_51/autorun.exe" ]
then
	echo "Already have vCentre 5.1 installer"
else
	if grep -q "VMWARE vCenter Server 5.1" "/mnt/cd0/readme.txt" 
	then
		echo "Found vCentre 5.1 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/VIM_51	
	fi
	if grep -q "VMWARE vCenter Server 5.1" "/mnt/cd1/readme.txt"
	then
		echo "Found vCentre 5.1 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/VIM_51	
	fi
fi
if [ -f "/mnt/LABVOL/Build/VIM_55/autorun.exe" ]
then
	echo "Already have vCentre 5.5 installer"
else
	if grep -q "VMWARE vCenter Server 5.5" "/mnt/cd0/readme.txt" 
	then
		echo "Found vCentre 5.5 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/VIM_55	
	fi
	if grep -q "VMWARE vCenter Server 5.5" "/mnt/cd1/readme.txt"
	then
		echo "Found vCentre 5.5 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/VIM_55	
	fi
fi
if [ -f "/mnt/LABVOL/Build/VIM_60/autorun.exe" ]
then
	echo "Already have vCentre 6.0 installer"
else
	if grep -q "VMWARE vCenter Server 6.0" "/mnt/cd0/readme.txt" 
	then
		echo "Found vCentre 6.0 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/VIM_60	
	fi
	if grep -q "VMWARE vCenter Server 6.0" "/mnt/cd1/readme.txt"
	then
		echo "Found vCentre 6.0 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/VIM_60	
	fi
fi

if [ -f "/mnt/LABVOL/Build/VIM_65/autorun.exe" ]
then
	echo "Already have vCentre 6.5 installer"
else
	if grep -q "VMWARE vCenter Server 6.5" "/mnt/cd0/readme.txt" 
	then
		echo "Found vCentre 6.5 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/VIM_65	
	fi
	if grep -q "VMWARE vCenter Server 6.5" "/mnt/cd1/readme.txt"
	then
		echo "Found vCentre 6.5 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/VIM_65	
	fi
fi
if [ -f "/mnt/LABVOL/Build/VIM_67/autorun.exe" ]
then
	echo "Already have vCentre 6.7 installer"
else
	if grep -q "VMWARE vCenter Server 6.7" "/mnt/cd0/readme.txt" 
	then
		echo "Found vCentre 6.7 installer on CD0"
		cp -r /mnt/cd0/* /mnt/LABVOL/Build/VIM_67	
	fi
	if grep -q "VMWARE vCenter Server 6.7" "/mnt/cd1/readme.txt"
	then
		echo "Found vCentre 6.7 installer on CD1"
		cp -r /mnt/cd1/* /mnt/LABVOL/Build/VIM_67	
	fi
fi
umount -f /dev/sr0
umount -f /dev/sr1
