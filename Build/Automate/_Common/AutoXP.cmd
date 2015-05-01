@echo off
echo **
echo * Disable screen lock
regedit /s \\192.168.199.7\build\Automate\_Common\NoSCRNSave.reg
echo **
echo * Install VMware Tools and reboot
start /wait \\192.168.199.7\build\VMTools\Setup.exe /s /v "/qn"
timeout 60
