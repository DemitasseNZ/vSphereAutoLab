# Creates vCenter 5.5 certificates and related files
# Do not use with vCenter 5.1. Run on the vCenter 5.5 server. 
# 
# Derek Seaman, VCDX #125, www.derekseaman.com
# vSphere 5.5 Install series: vexpert.me/Derek55
# For full instructions see Part 8 & 9 in the vSphere 5.5 install series
# Download the latest version from: vexpert.me/toolkit55
#
# v1.59 August 9, 2014
# Updated OpenSSL download to 0.9.8.zb
# Added check for PowerShell 3.0 (minimum requirement)
#
# v1.58 July 12, 2014
# Updated OpenSSL download to 0.9.8za
# Removed SQL 2012 SP1 client download (link broken)
# Fixed Database creation script bug
# Added additional error handling and Powershell-ized more commands
# Changed the sts.properties file to use sts in the URI per KB2058519
#
# v1.57 February 14, 2014
# More robust handling of non-internet connected systems
# Removed line continuation characters
#
# v1.56 January 19, 2014
# Fixed bug when no subordinate CA was present (Thanks Troy)
# Changed Microsoft "renewal" default to 0 for root/subordinate
#
# v1.55 January 12, 2014
# Added additional CA/subordinate error checking
#
# v1.50 December 22, 2013
# Added ESXi host support
#
# v1.42 December 3, 2013
# Modified how the certificate hash files are created
# Added Authentication Proxy certificate generation
# Changed MS CA download parameter to Renewal=1
#
# v1.41 November 14, 2013
# Changed the root/intermediate CA download order and added more error checking
#
# v1.40 November 10, 2013
# Added Auto Deploy, Dump Collector and Syslog collector SSL certs for Windows
# Added support for CA approval of submitted requests (Thanks Ryan Bolger)
# Added SHA512 request in CSR creation
# Ask for vCenter name when selecting Option 3
#
# v1.31 Octover 29, 2013
# Bugfix in option #2 where CSRs would fail to create
#
# v1.3 October 22, 2013
# Added basic support for vCenter Server Appliance cert minting/CSR
# Added support for manually entering vCenter FQDN
# Changed method of building the automatic vCenter FQDN 
#
# v1.2 October 19, 2013
# Added SQL database script creation
# Added vCenter/VUM DSN creation
#
# v1.1 October 10, 2013 Changes:
# Added IP address support for SAN field
# Added configurable CA download method (HTTP or HTTPS)
# Skips Root/subordinate certificate download if files already exist
#
#
[CmdletBinding()]
param()

# Directory where the certificate folders will be created. Does not need to exist.
$Cert_Dir = "C:\Certs"

# Path to your existing Open SSL directory. It may be c:\OpenSSL-Win32, too
# If OpenSSL is not located in this directory it will be downloaded and installed
$openssldir = "C:\OpenSSL"

# Modify these Certificate Details for your environment
$Country="NZ"
$State="BoP"
$City="Tauranga"
$org="AutoLab"

# If you want the vCenter server IP address included in the certificate set
# the value to the appropriate IP. If you don't want an IP, comment out the line.
# This applies to Windows vCenter and the vCenter Appliance.
$vCenterIP="192.168.199.5"

# The URLs where your Root and Subordinate CA certificates can be downloaded.
# If your CA certificates are not available online or you don't have a subordinate
# CA, just comment out the associated lines with a hash.  
#
# If you have an online Microsoft CA running the Web Enrollment role service,
# the CA certificate should be downloadable using the following URL:
# http(s)://YourCA.domain/certsrv/certnew.cer?ReqID=CACert&Renewal=0&Enc=b64
#
# If your have issues with the root certificate downloading, change Renewal=0
# in the body of the code. Or if the tool is downloading an expired certificate,
# increase the renewal number until it pulls the current certificate. 
#
# If you CA doesn't have web services or enabled or it's offline, you can download
# the root and intermediate CA certs manually and place them in the $Cert_Dir.
# Please see Part 9 of my vexpert.me\Derek55 series for details on how to create
# the root/intermediate files in the proper format. 
#
$rootCA = "dc.lab.local"
#$SubCA = "subca01.contoso.local"

# If your CA web enrollment site is not SSL enabled change to HTTP (insecure)
# Ignore if you don't have online Microsoft CAs.
$CADownload = "http"

# Online Microsoft CA name that will issue the certificates.
# Ignore if you don't have online Microsoft CAs.  
$ISSUING_CA = "dc\LabCA"

# Your VMware CA certificate template name (not the display name; no spaces)
# Ignore if you don't have online Microsoft CAs. 
$Template = "CertificateTemplate:VMware-SSL"

#######
# The magic happens here...don't modify
#######

# SSO and vCenter administrator usernames. Should not need to change these.
$sso_admin = "administrator@vsphere.local"
$vc_admin = "administrator@vsphere.local"

$rootcer = "$Cert_Dir\root64.cer"
$intermcer = "$Cert_Dir\interm64.cer" 
$openssl = $openssldir+"\bin\openssl.exe"
$ESXUser = "root"
$wc = New-Object System.Net.WebClient
$wc.UseDefaultCredentials = $true
New-Alias -Name OpenSSL $openssl

$Script:CertsWaitingForApproval = $false

$WServices = @("vCenterServer","vCenterInventoryService","vCenterSSO","VMwareUpdateManager","vCenterWebClient","vCenterLogBrowser","VMwareOrchestrator","AutoDeploy","DumpCollector","SysLogCollector", "AuthenticationProxy")

$LServices = @("VMware vCenter Service Certificate","VMware Inventory Service Certificate","VMware LDAP Service Certificate","VMware vCenter VAMI Certificate","vCenter Web Client Service Certificate","VMware Logbrowser Service Certificate","VMware vSphere Autodeploy Service Certificate")

# Check for PowerShell 3.0 and higher (required)

$PSpath = "HKLM:\SOFTWARE\Microsoft\PowerShell\3"

if(!(Test-Path $PSpath)) {
 write-host "PowerShell 3.0 or higher required. Please install"; exit 
 }
 
# Download OpenSSL if it's not already installed

if (!(Test-Path($openssl))) {
	Write-Host -Foreground "DarkBlue" -Background "White" "Downloading OpenSSL.."
	$null = New-Item -Type Directory $openssldir -erroraction silentlycontinue
	$sslurl = "http://slproweb.com/download/Win32OpenSSL-0_9_8zb.exe"
	$sslexe = "$env:temp\openssl.exe"
	$wc.DownloadFile($sslurl,$sslexe)
	$env:path = $env:path + ";$openssldir"
    if (!(test-Path($sslexe))) { write-host -Foreground "red" -Background "white" "Could not download or find OpenSSL. Please install OpenSSL 0.9.8y manually."; exit}
	Write-Host -Foreground "DarkBlue" -Background "White" "Installing OpenSSL.."
    cmd /c $sslexe /silent /verysilent /sp- /suppressmsgboxes
	Remove-Item $sslexe
}

# Create certificate directory if it does not exist

if(!(Test-Path $Cert_Dir)) { New-Item $Cert_Dir -Type Directory }

#
# Functions Begin Here
#

Function CheckOpenSSL {
   if (!(Test-Path $openssl)) {throw "Openssl required, unable to download, please install."}
}

Function WinVCCheck {

# Validates Windows vCenter SSO is installed

# Sets SSO filesystem path if SSO is installed
$ssoregpath = "HKLM:\SOFTWARE\VMware, Inc.\VMware Identity Services"

if(!(Test-Path $ssoregpath)) {
 write-host "SSO 5.5 not installed. Please install it first."; exit 
 }
 Else {
   $ssoreg = (Get-ItemProperty -Path $ssoregpath)
   $Script:ssodir = $ssoreg.InstallPath ; $ssodir= $ssodir -replace ".$"
}

# Configures JRE keytool alias with path if SSO is installed
$JREregpath = "HKLM:\SOFTWARE\VMware, Inc.\VMware Infrastructure\vJRE"

if(!(Test-Path $JREregpath)) {
 write-host "JRE not installed. Please install SSO 5.5 first."; exit 
 }
 Else {
   $JREreg = (Get-ItemProperty -Path $JREregpath)
   $JREBinDir = $JREreg.InstallPath ; $JREBinDir= $JREBinDir -replace ".$"
   $keytool = $JREBinDir+"\bin\keytool.exe"
   New-Alias -Name keytool $keytool -Scope script
  }
}

Function VCFQDN {

# Construct vCenter server hostname (localhost) and ask for input

$Computername = get-wmiobject win32_computersystem
$DEFFQDN = "$($computername.name).$($computername.domain)".ToLower() 

$Script:FQDN = $(
Write-Host "Is the vCenter FQDN $DEFFQDN ?"
$Input = Read-Host "Press ENTER to accept or input a new vCenter FQDN"
If ($input) {$input} else {$DEFFQDN}
)

$POS = $FQDN.IndexOf(".")
$Script:Shortname = $FQDN.Substring(0, $POS) 

}

Function DownloadRoot
{

# Download Root CA public certificate, if defined
# If the certificate exists (root64.cer) then it won't attempt to download

if ($RootCA) {

 If (!(test-path -Path $rootcer)){
   write-host "Downloading root certificate from $rootca ..."
   $url = "$CADownload"+"://$rootCA/certsrv/certnew.cer?ReqID=CACert&Renewal=0&Enc=b64"
   $wc.DownloadFile($url,$rootcer)
   If (!(test-path -Path $rootcer)) {write-host "Root64.cer did not download. Check Root CA variable, CA web services, or manually download root cert and copy to $Cert_Dir\root64.cer. See vExpert.me/Derek55 Part 9 for more details." -foregroundcolor red;exit}
   Write-host "Root CA download successful." -foregroundcolor yellow
   }
 Else { Write-host "Root CA file found, will not download." -ForegroundColor yellow} 
  }
 $Validation = select-string -simple CERTIFICATE----- $rootcer
 If (!$Validation) {write-host "Invalid Root certificate format. Validate BASE64 encoding and try again." -foregroundcolor red; exit}
}

Function DownloadSub
{
# Download Subordinate CA public certificate, if defined
# If the certificate exists (interm64.cer) then it won't attempt to download

if ($SubCA) {
  
  If (!(test-path -Path $intermcer)){
   write-host "Downloading subordinate certificate from $subca ..."
   $url = "$CADownload"+"://$SubCA/certsrv/certnew.cer?ReqID=CACert&Renewal=1&Enc=b64"
   $wc.DownloadFile($url,$intermcer)
   If (!(test-path -Path $intermcer)) {write-host "Interm64.cer did not download. Check Intermediate CA variable, CA web services, or manually download intermediate cert and copy to $Cert_Dir\interm64.cer. See vExpert.me/Derek55 Part 9 for more details." -foregroundcolor red;exit}
   Write-host "Intermediate CA download successful." -foregroundcolor yellow
   }
  Else { Write-host "Intermediate CA file found, will not download." -ForegroundColor yellow} 
  
 $Validation = select-string -simple CERTIFICATE----- $intermcer
 If (!$Validation) {write-host "Invalid subordinate certificate format. Validate BASE64 encoding and try again." -foregroundcolor red; exit}
}
}

Function CAHashes{
# Computes CA hash file(s)

# Skip if we have pending cert requests
if ($Script:CertsWaitingForApproval) { return }

# Prompt for Root cert if it's not there yet
While (!(Test-Path $rootcer)) {
   read-host "Please copy the Root CA certificate root64.cer (Base64 encoded) to $rootcer and press Enter to continue"
   }

$roothash = & OpenSSL x509 -subject_hash -noout -in $rootcer
$hashdest = $roothash + '.0' 
copy-item -path $rootcer -Destination $Cert_Dir\$hashdest

If (Test-Path $intermcer) {
   $intermhash = & OpenSSL x509 -subject_hash -noout -in $intermcer
   $interdest = $intermhash + '.0' 
   Copy-Item -Path $intermcer -Destination $Cert_Dir\$interdest
   cmd /c copy $intermcer+$rootcer $Cert_Dir\chain.cer
   }

write-host "Root CA hash is $roothash" -foregroundcolor yellow
If ($intermhash) { write-host "Intermediate CA hash is $intermhash" -foregroundcolor yellow }
}

Function CreateCSR {
# Create RSA private keys and CSRs

# If IP address is defined, add it to the SAN field
If ($vCenterIP) { $IP = " IP:$vCenterIP, DNS:$vCenterIP," }

$RequestTemplate = "[ req ]
default_md = sha512
default_bits = 2048
default_keyfile = rui.key
distinguished_name = req_distinguished_name
encrypt_key = no
prompt = no
string_mask = nombstr
req_extensions = v3_req
 
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$ShortName,$IP DNS:$FQDN
 
[ req_distinguished_name ]
countryName = $Country
stateOrProvinceName = $State
localityName = $City
0.organizationName = $Org
organizationalUnitName = SVCREPLACE
commonName = $FQDN
"

ForEach ($Service in $Services) {
	Set-Location $Cert_Dir
    if(!(Test-Path $Service)) { new-Item $Service -Type Directory }
	Set-Location $Service

	# Create CSR and private key
	$Out = $RequestTemplate -replace "SVCREPLACE", $Service | Out-File "$Cert_Dir\$Service\$Service.cfg" -Encoding Default -Force
        OpenSSL req -new -nodes -out "$Cert_Dir\$Service\$Service.csr" -keyout "$Cert_Dir\$Service\rui-orig.key" -config "$Cert_Dir\$Service\$Service.cfg"
	    OpenSSL rsa -in "$Cert_Dir\$Service\rui-orig.key" -out "$Cert_Dir\$Service\rui.key"
        Remove-Item rui-orig.key
  }
}

Function CreateESXCSR {
# Create RSA private keys and CSR

ForEach ($Service in $Services) {

$POS = $Service.IndexOf(".")
$Script:Shortname = $Service.Substring(0, $POS) 

$RequestTemplate = "[ req ]
default_md = sha512
default_bits = 2048
default_keyfile = rui.key
distinguished_name = req_distinguished_name
encrypt_key = no
prompt = no
string_mask = nombstr
req_extensions = v3_req
 
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$ShortName, DNS:$Service
 
[ req_distinguished_name ]
countryName = $Country
stateOrProvinceName = $State
localityName = $City
0.organizationName = $Org
commonName = $Service
"

	Set-Location $Cert_Dir
    if(!(Test-Path $Service)) { new-Item $Service -Type Directory }
	Set-Location $Service

	# Create CSR and private key
	$Out = $RequestTemplate -replace "SVCREPLACE", $Service | Out-File "$Cert_Dir\$Service\$Service.cfg" -Encoding Default -Force
        OpenSSL req -new -nodes -out "$Cert_Dir\$Service\$Service.csr" -keyout "$Cert_Dir\$Service\rui-orig.key" -config "$Cert_Dir\$Service\$Service.cfg"
	    OpenSSL rsa -in "$Cert_Dir\$Service\rui-orig.key" -out "$Cert_Dir\$Service\rui.key"
        Remove-Item rui-orig.key
  }
}


Function OnlineMint { 
#Mint certificates from online Microsoft CA

    # initialize objects to use for external processes
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $certsRequireApproval = $false

    ForEach ($Service in $Services) {

        # submit the CSR to the CA
        $psi.FileName = "certreq.exe"
        $psi.Arguments = @("-submit -attrib `"$Template`" -config `"$ISSUING_CA`" -f `"$Cert_Dir\$Service\$Service.csr`" `"$Cert_Dir\$Service\rui.crt`"")
	    write-host "Submitting certificate request for $Service"
        [void]$process.Start()

        $cmdOut = $process.StandardOutput.ReadToEnd()
        if ($cmdOut.Trim() -like "*request is pending*")
        {
            # Output indicates the request requires approval before we can download the signed cert.
            $Script:CertsWaitingForApproval = $true

            # So we need to save the request ID to use later once they're approved.
            $reqID = ([regex]"RequestId: (\d+)").Match($cmdOut).Groups[1].Value
            if ($reqID.Trim() -eq [String]::Empty)
            {
                write-error "Unable to parse RequestId from output."
                write-debug $cmdOut
                Exit
            }
            write-host "RequestId: $reqID is pending" -ForegroundColor Yellow

            # Save the request ID to a file that OnlineMintResume can read back in later
            $reqID | out-file "$Cert_Dir\$Service\requestid.txt"
        }
        else
        {
            # Output doesn't indicate a pending request, so check for a signed cert file
            if (!(Test-Path $Cert_Dir\$Service\rui.crt)) {
                Write-Error "Certificate request failed or was unable to download the signed certificate."
                Write-Error "Verify that the ISSUING_CA variable is set correctly." 
                Write-Debug $cmdOut
                Exit
            }
        }

    }

    if ($Script:CertsWaitingForApproval) {
        write-host
        write-host "One or more certificate requests require manual approval before they can be downloaded."
        Write-host "Contact your CA administrator to approve the request IDs listed above."
        write-host "To resume use Option 3 for Windows vCenter, 9 for vCenter Appliance or 13 for ESXi Hosts"
    }

}

Function OnlineMintResume {
#Resume the minting process for certificates from online Microsoft CA that required approval

    # initialize objects to use for external processes
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.CreateNoWindow = $true
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    ForEach ($Service in $Services) {

        # skip if there's no requestid.txt file
        if (!(Test-Path "$Cert_Dir\$Service\requestid.txt")) { continue }

        $reqID = Get-Content "$Cert_Dir\$Service\requestid.txt"
        write-verbose "Found RequestId: $reqID for $Service"

        # retrieve the signed certificate
        $psi.FileName = "certreq.exe"
        $psi.Arguments = @("-retrieve -f -config `"$ISSUING_CA`" $reqID `"$Cert_Dir\$Service\rui.crt`"")
        write-host "Downloading the signed $Service certificate"
        [void]$process.Start()
        $cmdOut = $process.StandardOutput.ReadToEnd()
        if (!(test-path "$Cert_Dir\$Service\rui.crt"))
        {
            # it's not there, so check if the request is still pending
            if ($cmdOut.Trim() -like "*request is pending*")
            {
                $Script:CertsWaitingForApproval = $true
                write-host "RequestId: $reqID is pending" -ForegroundColor Yellow
            }
            else
            {
                write-warning "There was a problem downloading the signed certificate"
                write-warning $cmdOut
                continue
            }
        }

    }

    if ($Script:CertsWaitingForApproval) {
        write-host
        write-host "One or more certificate requests require manual approval before they can be downloaded."
        Write-host "Contact your CA administrator to approve the request IDs listed above."
        write-host "To resume use Option 3 for Windows vCenter, 9 for vCenter Appliance or 13 for ESXi Hosts"
    }
}

Function CreatePEMFiles {
# Create PEM files and JKS keystore. Rui.crt files must exist for all services.

# Skip if we have pending cert requests
if ($Script:CertsWaitingForApproval) { return; }

if (Test-Path $Cert_Dir\chain.cer) {
 $chaincer = "$Cert_Dir\chain.cer" 
  }
 Else { 
   $chaincer = "$Cert_Dir\root64.cer"
  }

ForEach ($Service in $WServices) {

   if (!(test-path $Cert_Dir\$Service\rui.crt)) {
      Write-host "$Service rui.crt file not found. Skipping PEM creation. Please correct and re-run." -ForegroundColor Red
      continue;
   }
   elseif ($Service -eq "vCenterSSO") {
	OpenSSL pkcs12 -export -in "$Cert_Dir\$Service\rui.crt" -inkey "$Cert_Dir\$Service\rui.key" -certfile "$Chaincer" -name "ssoserver" -passout pass:changeme -out "$Cert_Dir\$Service\ssoserver.p12"
    
    if (test-path $Cert_Dir\$Service\root-trust.jks) {remove-item $Cert_Dir\$Service\root-trust.jks}
    keytool -v -importkeystore -srckeystore $Cert_Dir\$Service\ssoserver.p12 -srcstoretype pkcs12 -srcstorepass changeme -srcalias ssoserver -destkeystore $Cert_Dir\$Service\root-trust.jks -deststoretype JKS -deststorepass testpassword -destkeypass testpassword
    keytool -v -importcert -noprompt -keystore $Cert_Dir\$Service\root-trust.jks -deststoretype JKS -storepass testpassword -keypass testpassword -file $rootcer -alias root-ca
    Copy-Item -Path $Cert_Dir\$Service\rui.key -Destination $Cert_Dir\$Service\ssoserver.key
         
    if (test-path -path $intermcer){ 
       keytool -v -importcert -noprompt -trustcacerts -keystore $Cert_Dir\$Service\root-trust.jks -deststoretype JKS -storepass testpassword -keypass testpassword -file $intermcer -alias intermediate-$intermhash.0
       
       }
    Copy-Item -Path $Cert_Dir\$Service\root-trust.jks -Destination $Cert_Dir\$Service\server-identity.jks
    cmd /c copy $Cert_Dir\$Service\rui.crt+$chaincer $Cert_Dir\$Service\chain.pem
    Copy-Item -Path $Cert_Dir\$Service\chain.pem -Destination $Cert_Dir\$Service\ssoserver.crt
    }
	else {
       OpenSSL pkcs12 -export -in "$Cert_Dir\$Service\rui.crt" -inkey "$Cert_Dir\$Service\rui.key" -certfile "$Chaincer" -name "rui" -passout pass:testpassword -out "$Cert_Dir\$Service\rui.pfx"
        $RUI = get-content $Cert_Dir\$Service\rui.crt
        $ChainCont = get-content $chaincer -encoding default
        $RUI + $ChainCont | out-file  $Cert_Dir\$Service\chain.pem -Encoding default
         }
       Set-Location $Cert_Dir
   }
}

Function CreateSSOFiles {

# Create the three SSO properties files, needed to replace SSO certificates

# Skip if we have pending cert requests
if ($Script:CertsWaitingForApproval) { return }

$LookupServiceURL = 'https://' + $FQDN + ':7444/lookupservice/sdk'
$SSOServices = @("gc","admin","sts")

if (Test-Path $Cert_Dir\chain.cer) {
 $SSLCert = "$Cert_Dir\chain.cer" 
  }
 Else { 
   $SSLCert = "$Cert_Dir\root64.cer"
  }

ForEach ($SSOService in $SSOServices) {

if ($SSOService -eq "gc") {
   $SSOFriendly = "The group check interface of the SSO server"
   $SSOType = "groupcheck"
   $SSODescription = "The group check interface of the SSO server"
   $SSOProtocol = "vmomi"
   $SVCURI = "sso-adminserver/sdk/vsphere.local"
   }

if ($SSOService -eq "admin") {
   $SSOFriendly = "The administrative interface of the SSO server"
   $SSOType = "admin"
   $SSODescription = "The administrative interface of the SSO server"
   $SSOProtocol = "vmomi"
   $SVCURI = "sso-adminserver/sdk/vsphere.local"
   }

if ($SSOService -eq "sts") {
   $SSOFriendly = "STS for Single Sign On"
   $SSOType = "sts"
   $SSODescription = "The Security Token Service of the Single Sign On server."
   $SSOProtocol = "wsTrust"
   $SVCURI = "sts/STSService/vsphere.local"
   }

$SSOTemplate = "[service]
friendlyName=$SSOFriendly
version=1.5
ownerId=
productId=product:sso
type=urn:sso:$SSOType
description=$SSODescription

[endpoint0]
uri=https://FQDN:7444/$SVCURI
ssl=$SSLCert
protocol=$SSOProtocol
"

$Out = $SSOTemplate -replace "FQDN", $FQDN | Out-File "$Cert_Dir\vCenterSSO\$SSOService.properties" -Encoding Default -Force
}

# Create the three SSO ID files

write-host "Connecting to Lookup Service..."
$output = &"$ssodir\ssolscli.cmd" listServices "$lookupServiceURL"

foreach ($line in $output) {
		if ($line.StartsWith("Service ")) {
			$linenum = ($output | Select-String $line).LineNumber
			if ($linenum -is [int32]) { 
			
                $serviceId = $output | Select-Object -Index ($linenum+1)
				$type = $output | Select-Object -Index ($linenum+3)

                if ($type -like '*sts*') {
                 $serviceidfilename = "$Cert_Dir\vCenterSSO\sts_id" 
                 Set-Content $serviceidfilename  $serviceid.TrimStart("serviceId=")
                 write-host "Created sts files..."
                 }
                
                elseif ($type -like '*admin*') {
                 $serviceidfilename = "$Cert_Dir\vCenterSSO\admin_id"
                 Set-Content $serviceidfilename  $serviceid.TrimStart("serviceId=")
                 write-host "Created admin files..."
                  }
                   
                elseif ($type -like '*group*') {
                 $serviceidfilename = "$Cert_Dir\vCenterSSO\gc_id"
                 Set-Content $serviceidfilename  $serviceid.TrimStart("serviceId=")
                 write-host "Created groupcheck files..." 
                 }
			
				}
			}
		}

   If(!(Test-Path "$Cert_Dir\vCenterSSO\gc_id")) {
     Write-host "Unable to connect to Lookup service at $lookupserviceurl. " -ForegroundColor Red
   } 

}

Function CreateBat {
# Create batch template file for VMware vCenter certificate automation tool

$BatchTemplate = "
@echo off
set sso_cert_chain=$Cert_Dir\vCenterSSO\chain.pem
set sso_private_key=$Cert_Dir\vCenterSSO\ssoserver.key
set sso_node_type=single
set is_cert_chain=$Cert_Dir\vCenterInventoryService\chain.pem
set is_private_key_new=$Cert_Dir\vCenterInventoryService\rui.key
set vc_cert_chain=$Cert_Dir\vCenterServer\chain.pem
set vc_private_key=$Cert_Dir\vCenterServer\rui.key
set ngc_cert_chain=$Cert_Dir\vCenterWebClient\chain.pem
set ngc_private_key=$Cert_Dir\vCenterWebClient\rui.key
set logbrowser_cert_chain=$Cert_Dir\vCenterLogBrowser\chain.pem
set logbrowser_private_key=$Cert_Dir\vCenterLogBrowser\rui.key
set vco_cert_chain=$Cert_Dir\VMwareOrchestrator\chain.pem
set vco_private_key=$Cert_Dir\VMwareOrchestrator\rui.key
set vum_cert_chain=$Cert_Dir\VMwareUpdateManager\chain.pem
set vum_private_key=$Cert_Dir\VMwareUpdateManager\rui.key
set sso_admin_user=$sso_admin
set vc_username=$vc_admin
set last_error=
set ROLLBACK_BACKUP_FOLDER=%~dp0backup
set LOGS_FOLDER=%~dp0logs
set CSR_OUTPUT_FOLDER=%~dp0requests
"
$Out = $BatchTemplate | Out-File "$Cert_Dir\ssl-environment.bat" -Encoding Default -Force
Write-host "Batch file written to $Cert_Dir. Copy over VMware tool file." -ForegroundColor Yellow
}

Function SQLDB {

# Creates a generic SQL database creation script.

$VCDB = Read-Host "Enter vCenter Database Name"
$VUMDB = Read-Host "Enter VUM Database Name"
$Account = Read-Host "Enter vCenter service account (domain\account)"

$SQLTemplate = "

/* Creates vCenter server and VUM databases. */
/* Change login name to vCenter service account */
/* Modify paths, DB, log sizes as needed */

EXEC('CREATE LOGIN [$Account]FROM WINDOWS')

USE MSDB
EXEC sp_grantdbaccess ""$Account""
EXEC sp_addrolemember db_owner, ""$Account""

USE master
create database ""$VCDB""
on
( name = '$VCDB',
   filename = 'F:\SQLData1\$VCDB.mdf',
   size = 4096MB,
   filegrowth = 512MB )
   log on
( name = '$VCDB log',
   filename = 'F:\SQLLogs1\$VCDB.ldf',
   size = 384MB,
   filegrowth = 128MB )

COLLATE SQL_Latin1_General_CP1_CI_AS;

create database ""$VUMDB""
on
( name = '$VUMDB',
   filename = 'F:\SQLData1\$VUMDB.mdf',
   size = 1024MB,
   filegrowth = 128MB )
   log on
( name = '$VUMDB log',
   filename = 'F:\SQLLogs1\$VUMDB.ldf',
   size = 256MB,
   filegrowth = 64MB )

COLLATE SQL_Latin1_General_CP1_CI_AS;

EXEC('ALTER AUTHORIZATION ON DATABASE::""$VCDB"" TO [$Account]')
EXEC('ALTER AUTHORIZATION ON DATABASE::""$VUMDB"" TO [$Account]')

GO
"
$Out = $SQLTemplate | Out-File "$Cert_Dir\vCenter-VUM-DB.sql" -Encoding Default -Force
Write-host "vCenter-VUM-DB.sql written to $Cert_Dir. Modify and run in SQL Manager Studio." -ForegroundColor Yellow

}

Function VCDSN {

$SQLServer = Read-Host "Enter SQL server FQDN"
$DBName = Read-Host "Enter vCenter Database Name"
$Version = Read-Host "What version of SQL server? (2008 or 2012)"
$Encrypt = Read-Host "Do you want SQL SSL encryption? (yes or no)"

$HKLMPath1 = "HKLM:\SOFTWARE\ODBC\ODBC.INI\" + $DBName
$HKLMPath2 = "HKLM:\SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources"
md $HKLMPath1 -ErrorAction silentlycontinue

set-itemproperty -path $HKLMPath1 -name Description -value $DBName
set-itemproperty -path $HKLMPath1 -name Server -value $SQLServer
set-itemproperty -path $HKLMPath1 -name LastUser -value "Administrator"
set-itemproperty -path $HKLMPath1 -name Trusted_Connection -value "Yes"
set-itemproperty -path $HKLMPath1 -name Encrypt -value $Encrypt
set-itemproperty -path $HKLMPath1 -name Database -value $DBName

md $HKLMPath2 -ErrorAction silentlycontinue

if ($version -eq 2008) {
   set-itemproperty -path $HKLMPath2 -name "$DBName" -value "SQL Server Native Client 10.0"
   set-itemproperty -path $HKLMPath1 -name Driver -value "C:\WINDOWS\system32\sqlncli10.dll"
   If(!(test-path "C:\WINDOWS\system32\sqlncli10.dll")) {
     Write-Host -Foreground "DarkBlue" -Background "White" "Downloading SQL 2008 R2 SP2 Native Client.."
	 $SQLurl = "http://download.microsoft.com/download/F/7/B/F7B7A246-6B35-40E9-8509-72D2F8D63B80/sqlncli_amd64.msi"
	 $SQLexe = "$env:temp\sqlncli.msi"
	 $wc.DownloadFile($SQLurl,$SQLexe)
	 $env:path = $env:path + ";$SQLdir"
	 Write-Host -Foreground "DarkBlue" -Background "White" "Installing SQL 2008 R2 SP2 native client..."
     cmd /c msiexec /i $SQLexe /qn IACCEPTSQLNCLILICENSETERMS=YES
	 Remove-Item $SQLexe
   }   
 }

Else {
   set-itemproperty -path $HKLMPath2 -name "$DBName" -value "SQL Server Native Client 11.0"
   set-itemproperty -path $HKLMPath1 -name Driver -value "C:\WINDOWS\system32\sqlncli11.dll"
   If(!(test-path "C:\WINDOWS\system32\sqlncli11.dll")) {
     Write-Host -Foreground "DarkBlue" -Background "White" "Download and install ENU\x64\sqlncli.msi from http://www.microsoft.com/en-us/download/details.aspx?id=35580"
   }
 }
}


Function VUMDSN {

$SQLServer = Read-Host "Enter SQL server FQDN"
$DBName = Read-Host "Enter VUM Database Name"
$Version = Read-Host "What version of SQL server? (2008 or 2012)"
$Encrypt = Read-Host "Do you want SQL SSL encryption? (yes or no)"

$HKLMPath1 = "HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\" + $DBName
$HKLMPath2 = "HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources"
md $HKLMPath1 -ErrorAction silentlycontinue

set-itemproperty -path $HKLMPath1 -name Description -value $DBName
set-itemproperty -path $HKLMPath1 -name Server -value $SQLServer
set-itemproperty -path $HKLMPath1 -name LastUser -value "Administrator"
set-itemproperty -path $HKLMPath1 -name Trusted_Connection -value "Yes"
set-itemproperty -path $HKLMPath1 -name Encrypt -value $Encrypt
set-itemproperty -path $HKLMPath1 -name Database -value $DBName

md $HKLMPath2 -ErrorAction silentlycontinue

if ($version -eq 2008) {
   set-itemproperty -path $HKLMPath2 -name "$DBName" -value "SQL Server Native Client 10.0"
   set-itemproperty -path $HKLMPath1 -name Driver -value "C:\WINDOWS\system32\sqlncli10.dll"
   If(!(test-path "C:\WINDOWS\system32\sqlncli10.dll")) {Write-host "Don't forget to install the SQL 2008 client." -ForegroundColor Yellow}
   }

Else {
   set-itemproperty -path $HKLMPath2 -name "$DBName" -value "SQL Server Native Client 11.0"
   set-itemproperty -path $HKLMPath1 -name Driver -value "C:\WINDOWS\system32\sqlncli11.dll"
   If(!(test-path "C:\WINDOWS\system32\sqlncli11.dll")) {Write-host "Don't forget to install the SQL 2012 client." -ForegroundColor Yellow}
   }
}

Function GetESXHost {

# Construct ESXi Hostname

[int]$xMenuChoiceA = 0
while ( $xMenuChoiceA -lt 1 -or $xMenuChoiceA -gt 3 ){
Write-host ""
Write-host "Note: If you are resuming a manual/offline request, enter the same"
Write-host "hostname(s) or CSV file as the original request."
Write-host ""
Write-host "1. Manually enter ESXi host(s)"
Write-host "2. Read ESXi hosts from CSV file"
Write-host "3. Quit"

[Int]$xMenuChoiceA = read-host "Please enter an option 1 to 3" }
Write-Host
Switch( $xMenuChoiceA ){
  1{ESXHost}
  2{ESXCSV}
  3{Exit}
default{Exit}
 }

}

Function ESXHost {

$Script:Services = (Read-Host "Enter each ESXi FQDN (separate with comma)").split(',') | % {$_.trim()}
}

Function ESXCSV {

# Reads CSV input file of ESXi FQDNs

$CSVFile = Read-Host "Full path to CSV file"; 
	If ( !(Test-Path $CSVFile) )
	{
		Write-Host "$CSVfile not found" -ForegroundColor Red
        ESXCSV
    }

    else {
    $Script:Services = get-content $CSVFile
    } 
}


Function getWebClient {

# Used for PUTing SSL Certificates on ESXi host

$Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
$Compiler=$Provider.CreateCompiler()
$Params=New-Object System.CodeDom.Compiler.CompilerParameters
$Params.GenerateExecutable=$False
$Params.GenerateInMemory=$True
$Params.IncludeDebugInformation=$False
$Params.ReferencedAssemblies.Add("System.DLL") | out-null

$TASource=@'
  namespace Com.Marchview.Net.CertificatePolicy {
    public class TrustAll : System.Net.ICertificatePolicy {
      public TrustAll() { 
      }
      public bool CheckValidationResult(System.Net.ServicePoint sp,
        System.Security.Cryptography.X509Certificates.X509Certificate cert, 
        System.Net.WebRequest req, int problem) {
        return true;
      }
    }
  }
'@ 
$TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
$TAAssembly=$TAResults.CompiledAssembly

# We now create an instance of the TrustAll and attach it to the ServicePointManager

$TrustAll=$TAAssembly.CreateInstance("Com.Marchview.Net.CertificatePolicy.TrustAll")
[System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

$WCSource=@'
  namespace Com.Marchview.Net {
    class WebClient : System.Net.WebClient {
      protected override System.Net.WebRequest GetWebRequest(System.Uri uri) {
        System.Net.WebRequest webRequest = base.GetWebRequest(uri);
        webRequest.PreAuthenticate = true;
        webRequest.Timeout = 10000;
        return webRequest;
      }
    }
  }
'@
$WCResults=$Provider.CompileAssemblyFromSource($Params,$WCSource)
$WCAssembly=$WCResults.CompiledAssembly
$WebClient=$WCAssembly.CreateInstance("Com.Marchview.Net.WebClient")

$WebClient

}

Function GetCredential {
# Used for PUTing SSL Certificates on ESXi host

param(
	  [String]$UserName,
	  $Password    
	  )

	$CredentialCache=New-Object System.Net.CredentialCache
	if ($Password.getType().FullName -eq "System.Security.SecureString") {
	  $Credential=New-Object System.Net.NetworkCredential($UserName,  
	    [System.Runtime.InteropServices.Marshal]::PtrToStringAuto( 
	    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)))
	}
	else {
	  $Credential=New-Object System.Net.NetworkCredential($UserName,$Password)
}

$Credential
}

Function getCredentialCache {
# Used for PUTing SSL Certificates on ESXi host

param(
  [String]$URIName,
  [System.Net.NetworkCredential]$Credential
  )

$CredentialCache=New-Object System.Net.CredentialCache

$URI=New-Object System.URI($URIName)
$CredentialCache.Add($URI,"Basic",$Credential)

$CredentialCache
}

Function UploadESXCert {

   if ($Script:CertsWaitingForApproval) {EXIT}

ForEach ($Service in $Services) {

	# Get password for root account or read from file

	$ESXPassFile = $ESXUser + "-credentials"
    $ESXPassFile = "$Cert_Dir\$ESXPassFile"
	If ( !(Test-Path $ESXPassFile) )
	{
		Write-Host "No credentials found for " $ESXUser
		$Prompt = "Please enter the password for " + $ESXUser
		Read-Host -prompt $Prompt -assecurestring | ConvertFrom-SecureString | Out-File $ESXPassFile
	}
	$ESXPassword = Get-Content $ESXPassFile| ConvertTo-SecureString

	# Set directories

	$ESXCertFile = "$Cert_Dir\$Service" + "\" + "rui.crt"
	$ESXKeyFile = "$Cert_Dir\$Service" + "\" + "rui.key"
	
	# Check if SSL certificate and key exist
	If (-not (Test-Path ($ESXKeyFile))) {
	  "ERROR: Failed to locate the SSL key file at $Cert_Dir\$Service"
	  exit
	}
	If (-not (Test-Path ($ESXCertFile))) {
	  "ERROR: Failed to locate the SSL crt file at $Cert_Dir\$Service"
	  exit
	}

	# Set URLs
	
	$ESXiURL = "https://" + $Service

	# Create WebClient for uploading the SSL certificate / key
	$WebClient=getWebClient
	$HostCredential=getCredential $ESXUser $ESXPassword
	$HostCredentialCache=getCredentialCache $ESXiURL $HostCredential
	$WebClient.Credentials=$HostCredentialCache
	
	# Upload SSL keys
    Try 
    {
    	$WebClient.UploadFile(($ESXiURL + "/host/ssl_key"),"PUT",$ESXKeyFile)
	    $WebClient.UploadFile(($ESXiURL + "/host/ssl_cert"),"PUT", $ESXCertFile)
    }
    Catch
    {
        $UploadError = $_.Exception.Message  
        write-host "Upload error occurred for $Service. Check hostname and credentials." -ForegroundColor Red
        write-host $_.Exception.Message -ForegroundColor Red
    }

    if (!$UploadError) {write-host "Certificates uploaded to $Service" -ForegroundColor Yellow }
 }
}


### Main ###

[int]$xMenuChoiceA = 0
while ( $xMenuChoiceA -lt 1 -or $xMenuChoiceA -gt 14 ){
Write-host ""
Write-host "Welcome to the vCenter 5.5 Toolkit" -foregroundcolor Yellow
Write-host "Derek Seaman, VCDX #125, derekseaman.com" -ForegroundColor Yellow
Write-host "vSphere 5.5 series: vexpert.me\Derek55" -ForegroundColor Yellow
Write-host "Use at your own risk; no warranty implied or stated" -ForegroundColor Yellow
Write-host ""
Write-host "Windows vCenter only:"
Write-host ""
Write-host "1. Mint vCenter SSL certs with an online Microsoft CA"
Write-host "2. Create vCenter CSRs for an offline or non-Microsoft CA"
Write-host "3. Process manually downloaded certificates or resume a pending online request"
Write-host "4. Create vCenter Certificate Automation Batch file"
Write-host "5. Create vCenter and VUM SQL database file"
Write-host "6. Create vCenter DSN"
Write-host "7. Create VUM DSN"
write-host ""
Write-host "Linux vCenter Server Appliance (VCSA) only:"
Write-host ""
Write-host "8. Mint VCSA SSL certs with an online Microsoft CA"
Write-host "9. Resume a pending online Microsoft CA request"
Write-host "10. Create VCSA CSRs for an offline or non-Microsoft CA"
Write-host ""
Write-host "ESXi Hosts"
Write-host ""
Write-host "11. Mint ESXi SSL certificate with an online Microsoft CA"
Write-host "12. Create ESXi CSRs for an offline or non-Microsoft CA"
Write-host "13. Install manually downloaded certificates or resume a pending online request"
Write-host ""
Write-host "14. Quit"

[Int]$xMenuChoiceA = read-host "Please enter an option 1 to 14" }
Write-Host
Switch( $xMenuChoiceA ){
  1{$Script:Services = $WServices; CheckOpenSSL; WinVCCheck; DownloadRoot; DownloadSub; VCFQDN; CreateCSR; OnlineMint; CAHashes; CreatePEMFiles; CreateSSOFiles}
  2{$Script:Services = $WServices; CheckOpenSSL; WinVCCheck; VCFQDN; CreateCSR}
  3{$Script:Services = $WServices; CheckOpenSSL; WinVCCheck; DownloadRoot; DownloadSub; VCFQDN; OnlineMintResume; CAHashes; CreatePemFiles; CreateSSOFiles}
  4{CreateBat}
  5{SQLDB}
  6{VCDSN}
  7{VUMDSN}
  8{$Script:Services = $LServices; CheckOpenSSL; VCFQDN; DownloadRoot; DownloadSub; CreateCSR; OnlineMint }
  9{$Script:Services = $LServices; CheckOpenSSL; VCFQDN; DownloadRoot; DownloadSub; OnlineMintResume}
  10{$Script:Services = $LServices; CheckOpenSSL; VCFQDN; CreateCSR}
  11 {CheckOpenSSL; GetESXHost; CreateESXCSR; OnlineMint; UploadESXCert}
  12 {CheckOpenSSL; GetESXHost; CreateESXCSR}
  13 {CheckOpenSSL; GetESXHost; OnlineMintResume; UploadESXCert}
  14{Exit}
default{Exit}
}
