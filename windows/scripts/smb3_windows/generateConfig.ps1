Param(
    [Parameter(Mandatory=$true)][string]$configDir,
    [Parameter(Mandatory=$true)][string]$templatePath,
    [Parameter(Mandatory=$true)][string]$serverIP,
    [Parameter(Mandatory=$true)][string]$rabbitUser,
    [Parameter(Mandatory=$true)][string]$logDir,
    [Parameter(Mandatory=$true)][string]$lockPath,
    [Parameter(Mandatory=$true)][string]$username,
    [Parameter(Mandatory=$true)][string]$password
)

function unzip($src, $dest) {

	$shell = new-object -com shell.application
	$zip = $shell.NameSpace($src)
	foreach($item in $zip.items())
	{
		$shell.Namespace($dest).copyhere($item)
	}

}

$volumeDriver = 'cinder.volume.drivers.windows.smbfs.WindowsSmbfsDriver'
$smbSharesConfigPath = "$configDir\smbfs_shares_config.txt"
$configFile = "$configDir\cinder.conf"


$sharePath = "//$serverIP/SMBShare -o username=$username,password=$username"
sc $smbSharesConfigPath $sharePath

$template = gc $templatePath
$config = expand_template $template
Write-Host "Config file:"
Write-Host $config
sc $configFile $config

# FIX FOR qmeu-img - fetch locally compiled one
Invoke-WebRequest -Uri http://dl.openstack.tld/qemu-img-cbsl-build.zip -OutFile c:\qemu-img\qemu-img-cbsl-build.zip
mkdir c:\qemu2
unzip c:\qemu-img\qemu-img-cbsl-build.zip c:\qemu2

# Ensure Windows Share is available
if (! (Test-Path -Path C:\SMBShare))
{
    mkdir c:\SMBShare
}

if (!(Get-SMBShare -Name SMBShare))
{
    $hostname=hostname
    New-SMBShare -Name SMBShare -Path C:\SMBShare -FullAccess "$hostname\Admin"
}
Grant-SmbShareAccess -Name SMBShare -AccountName Admin -AccessRight Full -Force
