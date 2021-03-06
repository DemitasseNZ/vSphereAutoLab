@echo off
echo * Install vCenter 5.0
echo * Install vCenter 5.0 >> c:\buildLog.txt
start /wait B:\VIM_50\vCenter-Server\VMware-vcserver.exe /q /s /w /L1033 /v" /qr WARNING_LEVEL=0 USERNAME=\"Lab\" COMPANYNAME=\"lab.local\" DB_SERVER_TYPE=Custom DB_DSN=\"VCenterDB\" DB_USERNAME=\"vpx\" DB_PASSWORD=\"VMware1!\" VPX_USES_SYSTEM_ACCOUNT=\"1\" FORMAT_DB=1 VCS_GROUP_TYPE=Single"
echo **
echo * Install vSphere Client 5.0
echo * Install vSphere Client 5.0 >> c:\buildLog.txt
start /wait B:\VIM_50\vSphere-Client\VMware-viclient.exe /q /s /w /L1033 /v" /qr"
echo **
echo * Install vSphere Client 5.0 VUM Plugin
echo * Install vSphere Client 5.0 VUM Plugin >> c:\buildLog.txt
start /wait B:\VIM_50\updateManager\VMware-UMClient.exe /q /s /w /L1033 /v" /qr"
echo **
echo * Install vCenter Update Manager 5.0
echo * Install vCenter Update Manager 5.0 >> c:\buildLog.txt
start /wait B:\VIM_50\updateManager\VMware-UpdateManager.exe /L1033 /v" /qn VMUM_SERVER_SELECT=192.168.199.5 VC_SERVER_IP=vc.lab.local VC_SERVER_ADMIN_USER=\"administrator\" VC_SERVER_ADMIN_PASSWORD=\"VMware1!\" VCI_DB_SERVER_TYPE=Custom VCI_FORMAT_DB=1 DB_DSN=\"VUM\" DB_USERNAME=\"vpx\" DB_PASSWORD=\"VMware1lab\" "
