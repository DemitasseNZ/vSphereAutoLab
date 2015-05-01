set WshShell = WScript.CreateObject("WScript.Shell")

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\BuildLog.lnk")
oShortCutLink.TargetPath = "c:\BuildLog.txt"
oShortCutLink.Save

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\Validate.lnk")
oShortCutLink.TargetPath = "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe"
oShortCutLink.Arguments = " c:\validate.ps1"
oShortCutLink.Save

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\Upgrade.lnk")
oShortCutLink.TargetPath = "\\nas\Build\Automate\DC2\Upgrade.cmd"
oShortCutLink.Save
