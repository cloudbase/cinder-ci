Param(
    [Parameter(Mandatory=$true)][string]$configDir,
    [Parameter(Mandatory=$true)][string]$templatePath,
    [Parameter(Mandatory=$true)][string]$serverIP,
    [Parameter(Mandatory=$true)][string]$rabbitUser,
    [Parameter(Mandatory=$true)][string]$logDir,
    [Parameter(Mandatory=$true)][string]$lockPath,
    [Parameter(Mandatory=$true)][string]$username,
    [Parameter(Mandatory=$true)][string]$password,
    [Parameter(Mandatory=$true)][string]$hypervNodes
)

function unzip($src, $dest) {

	$shell = new-object -com shell.application
	$zip = $shell.NameSpace($src)
	foreach($item in $zip.items())
	{
		$shell.Namespace($dest).copyhere($item)
	}

}
$serverIP = (Get-NetIPAddress | Where-Object {$_.IPAddress -like "10.250*" -and $_.AddressFamily -like "IPv4"}).IPAddress
if (!$serverIP) {
    Throw "Could not get windows machine dataplane IP"
}
$volumeDriver = 'cinder.volume.drivers.windows.smbfs.WindowsSmbfsDriver'
$smbSharesConfigPath = "$configDir\smbfs_shares_config.txt"
$configFile = "$configDir\cinder.conf"


$sharePath = "//$serverIP/SMBShare -o username=$username,password=$password"
sc $smbSharesConfigPath $sharePath

$template = gc $templatePath
$config = expand_template $template
Write-Host "Config file:"
Write-Host $config
sc $configFile $config

# FIX FOR qmeu-img - fetch locally compiled one
Invoke-WebRequest -Uri http://10.20.1.14:8080/qemu-img-cbsl-build.zip -OutFile c:\qemu-img-cbsl-build.zip
if (Test-Path -Path c:\qemu-img){
	Remove-Item -Force -Recurse c:\qemu-img
}
unzip c:\qemu-img-cbsl-build.zip c:\

# Ensure Windows Share is available
if (! (Test-Path -Path C:\SMBShare))
{
    mkdir c:\SMBShare
}

if ((Get-WMIObject -namespace "root\cimv2" -class Win32_ComputerSystem).partofdomain -eq $true) 
{
    $hostname = (Get-WmiObject Win32_ComputerSystem).Domain
} else {
    $hostname = hostname
}

if (!(Get-SMBShare -Name SMBShare))
{
    New-SMBShare -Name SMBShare -Path C:\SMBShare -FullAccess "$hostname\Administrator"
}

$hypervNodes.split(",") | foreach {
    Grant-SmbShareAccess -Name SMBShare -AccountName "$hostname\$_$" -AccessRight Full -Force
}
