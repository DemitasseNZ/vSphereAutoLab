@echo off
echo **
echo * Install dotnet 3.5
if exist \\192.168.199.7\build\VIM_60\redist\dotnet\dotnetfx35.exe (
start /wait \\192.168.199.7\build\VIM_60\redist\dotnet\dotnetfx35.exe /qb /norestart
)
if exist \\192.168.199.7\build\VIM_50\redist\dotnet\dotnetfx35.exe (
start /wait \\192.168.199.7\build\VIM_50\redist\dotnet\dotnetfx35.exe /qb /norestart
)
if exist \\192.168.199.7\build\VIM_51\redist\dotnet\dotnetfx35.exe (
start /wait \\192.168.199.7\build\VIM_51\redist\dotnet\dotnetfx35.exe /qb /norestart
)
echo **
echo * Install Load Storm by Andrew Mitchel
start /wait msiexec /i "\\192.168.199.7\build\Automate\VC\Floppy\Load Storm.msi" /q
echo **
echo * Disable screen lock
regedit /s \\192.168.199.7\build\Automate\_Common\NoSCRNSave.reg
echo **
echo * Install VMware Tools and reboot
start /wait \\192.168.199.7\build\VMTools\Setup.exe /s /v "/qn"
timeout 60
