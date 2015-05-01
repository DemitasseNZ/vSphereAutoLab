$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "B:\Automate\automate.ini").line).substring(9)
net user administrator $AdminPWD /domain
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "Lab\Administrator", (ConvertTo-SecureString -AsPlainText $AdminPWD -Force)
invoke-command -computername DC -credential $cred {
	$AdminPWD = ((Select-String -SimpleMatch "Adminpwd=" -Path "\\192.168.199.7\Build\Automate\automate.ini").line).substring(9)
	Start-Process Regedit.exe -ArgumentList " -s \\192.168.199.7\Build\automate\_Common\ExplorerView.reg" -verb RunAs
	Start-Process \\192.168.199.7\Build\automate\_Common\Autologon.exe -ArgumentList " administrator lab $AdminPWD" -verb RunAs
}