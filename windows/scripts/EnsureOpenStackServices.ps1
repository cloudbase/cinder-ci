Param(
    [Parameter(Mandatory=$True)]
    [string]$serviceUsername,
    [Parameter(Mandatory=$True)]
    [string]$servicePassword
)

$openstackDir = "C:\OpenStack"
$pythonDir = "C:\Python27"
$configDir = "$openstackDir\etc\cinder"
$downloadLocation = "http://dl.openstack.tld/"
$scriptdir = "C:\cinder-ci"

. "$scriptdir\windows\scripts\utils.ps1"

$cinderServiceName = "cinder-volume"
$cinderServiceDescription = "OpenStack Cinder Volume Service"
$cinderServiceExecutable = "$pythonDir\python $pythonDir\Scripts\cinder-volume-script.py"
$cinderServiceConfig = "$configDir\cinder.conf"

Check-Service $cinderServiceName $cinderServiceDescription $cinderServiceExecutable $cinderServiceConfig

