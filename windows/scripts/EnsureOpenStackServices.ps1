Param(
    [Parameter(Mandatory=$True)]
    [string]$serviceUsername,
    [Parameter(Mandatory=$True)]
    [string]$servicePassword
)

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"
. "$scriptLocation\utils.ps1"

$cinderServiceName = "cinder-volume"
$cinderServiceDescription = "OpenStack Cinder Volume Service"
$cinderServiceExecutable = $pythonDir+'\python.exe -c "from ctypes import wintypes; from cinder.cmd import volume; volume.main()"'
$cinderServiceConfig = "$configDir\cinder.conf"

Check-Service $cinderServiceName $cinderServiceDescription $cinderServiceExecutable $cinderServiceConfig

