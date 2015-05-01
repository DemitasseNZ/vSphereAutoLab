@echo off
echo *************************
echo *
echo **
echo * Connect to build share
net use B: \\192.168.199.7\Build >> c:\buildlog.txt
type b:\automate\version.txt  >> c:\buildlog.txt
echo **
echo * Setup persistent route to other subnet for SRM and View
echo * Setup persistent route to other subnet for SRM and View  >> c:\buildLog.txt
route add 192.168.201.0 mask 255.255.255.0 192.168.199.254 -p
echo **
echo * Install reqired Windows compnents
echo * Install reqired Windows compnents  >> c:\buildLog.txt
Start /wait pkgmgr /l:C:\IIS_Install_Log.txt /iu:NetFx3;IIS-WebServerRole;IIS-WebServer;IIS-ApplicationDevelopment;IIS-ASP;IIS-ISAPIFilter;ADFS-WebAgentToken;IIS-ASPNET;IIS-Security;IIS-BasicAuthentication;IIS-DigestAuthentication;IIS-RequestFiltering;IIS-WindowsAuthentication;IIS-WebServerManagementTools;IIS-ManagementConsole;IIS-NetFxExtensibility;IIS-ISAPIExtensions
echo **
echo * Install VMware Tools  
echo * Install VMware Tools  >> c:\buildLog.txt
b:\VMTools\Setup64.exe /s /v "/qn"
timeout 60
