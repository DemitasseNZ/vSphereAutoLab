set WshShell = WScript.CreateObject("WScript.Shell")
set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\vSphere.lnk")
oShortCutLink.TargetPath = "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Launcher\VpxClient.exe"
oShortCutLink.Arguments = "-s vc2.lab.local -PassthroughAuth"
oShortCutLink.Save

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\VMware vSphere Client.lnk")
oShortCutLink.TargetPath = "C:\Program Files (x86)\VMware\Infrastructure\Virtual Infrastructure Client\Launcher\VpxClient.exe"
oShortCutLink.Save
 

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\AutoLab Script Menu.lnk")
oShortCutLink.TargetPath = "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe"
oShortCutLink.Arguments = " c:\ScriptMenu.ps1"
oShortCutLink.Save

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\AutoLab Portal.lnk")
oShortCutLink.TargetPath = "C:\Program Files (x86)\Internet Explorer\iexplore.exe"
oShortCutLink.Arguments = " dc.lab.local"
oShortCutLink.Save

set oShortCutLink = WshShell.CreateShortcut("C:\Users\Public\Desktop\PuTTY.lnk")
oShortCutLink.TargetPath = "C:\Program Files (x86)\PuTTY\PuTTY.exe"
oShortCutLink.Save
