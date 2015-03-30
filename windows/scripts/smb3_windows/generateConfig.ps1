Param(
    [Parameter(Mandatory=$true)][string]$configDir,
    [Parameter(Mandatory=$true)][string]$templatePath,
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [Parameter(Mandatory=$true)][string]$rabbitUser,
    [Parameter(Mandatory=$true)][string]$logDir,
    [Parameter(Mandatory=$true)][string]$lockPath
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


$sharePath = "//$devstackIp/openstack/volumes -o noperm"
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
