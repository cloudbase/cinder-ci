Param(
    [Parameter(Mandatory=$True)]
    [string]$serviceUsername,
    [Parameter(Mandatory=$True)]
    [string]$servicePassword
)

$openstackDir = "C:\OpenStack"
$pythonDir = "C:\Python27"
$configDir = "$openstackDir\etc"
$downloadLocation = "http://dl.openstack.tld/"
$scriptdir = "C:\cinder-ci"

. "$scriptdir\windows\scripts\utils.ps1"

$cinderServiceName = "cinder-volume"
$cinderServiceDescription = "OpenStack Cinder Volume Service"
$cinderServiceExecutable = "$pythonDir\Scripts\cinder-volume.exe"
$cinderServiceConfig = "$configDir\cinder.conf"

Check-Service $cinderServiceName $cinderServiceDescription $cinderServiceExecutable $cinderServiceConfig

