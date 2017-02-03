# Configuration file
#
# Windows
#
$openstackDir = "C:\OpenStack"
$baseDir = "C:\cinder-ci\windows"
$buildDir = "$openstackDir\build"
$binDir = "$openstackDir\bin"

$scriptdir = "$baseDir\scripts"
$pythonDir = "C:\Python27"
$configDir = "$openstackDir\etc"
#$downloadLocation = "http://10.0.110.1/"
$scriptdir = "C:\openstack\cinder-ci"

$templateDir = "$scriptdir\windows\templates"
$cinderTemplate = "$templateDir\cinder.conf"
$pythonDir = "C:\Python27"
$pythonExec = "python.exe"
$pythonArchive = "python.zip"
$lockPath = "C:\Openstack\locks"
$openstackLogs="$openstackDir\Logs"

$eventlogPath= "$openstackLogs\Eventlog"
$eventlogcsspath = "$templateDir\eventlog_css.txt"
$eventlogjspath = "$templateDir\eventlog_js.txt"
