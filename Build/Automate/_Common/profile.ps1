Write-Host "Loading PowerCLI, this may take a little while." -foregroundcolor "cyan"
if (((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) -and ((Get-PSSnapin -Registered).name -contains "ware")) {
	Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
} else {
	$moduleList = @( "VMware.VimAutomation.Core", "VMware.VimAutomation.Vds", "VMware.VimAutomation.Cis.Core", "VMware.VimAutomation.Storage", "VMware.VimAutomation.HorizonView","VMware.VimAutomation.HA", "VMware.VimAutomation.vROps", "VMware.VumAutomation", "VMware.DeployAutomation", "VMware.ImageBuilder", "VMware.VimAutomation.License")
	$loaded = Get-Module -Name $moduleList -ErrorAction Ignore | % {$_.Name}
	$registered = Get-Module -Name $moduleList -ListAvailable -ErrorAction Ignore | % {$_.Name}
	$notLoaded = $registered | ? {$loaded -notcontains $_}
	foreach ($module in $registered) {
		if ($loaded -notcontains $module) {
			Import-Module $module
		}
	}
}
$PCLIVer = Get-PowerCLIVersion
if ((($PCLIVer.Major * 10 ) + $PCLIVer.Minor) -ge 51) {
	$null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$false -Scope "Session"
}

