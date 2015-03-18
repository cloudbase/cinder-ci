Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/cinder'
)

$projectName = $buildFor.split('/')[-1]
if ($projectName -ne "cinder")
{
    Throw "Error: Incorrect project $projectName. This setup is for testing Cinder patches."
}

$openstackDir = "C:\Openstack"
$scriptdir = "$openstackDir\cinder-ci"
$configDir = "$openstackDir\etc"
$templateDir = "$scriptdir\windows\templates"
$cinderTemplate = "$templateDir\cinder.conf"
$pythonDir = "C:\Python27"
$pythonExec = "python.exe"
$lockPath = "C:\Openstack\locks"
$remoteLogs="\\"+$devstackIP+"\openstack\logs"
$remoteConfigs="\\"+$devstackIP+"\openstack\config"
$rabbitUser = "stackrabbit"
$hostname = hostname

git config --global user.email "hyper-v_ci@microsoft.com"
git config --global user.name "Hyper-V CI"

# Replace Python dir with the archived template
# TODO: move this to the image instead.
Remove-Item -Force -Recurse $pythonDir
$archivePath = 'C:\python27.tar.gz'
Invoke-WebRequest -Uri http://10.21.7.214/python27.tar.gz -OutFile $archivePath
tar -xvzf $archivePath -C C:\
Remove-Item -Force -Recurse $archivePath
pip install wmi
pip install virtualenv

if (! Test-Path -Path "$scriptdir\windows\scripts\utils.ps1")
{
    Remove-Item -Force -Recurse "$scriptdir\*"
    GitClonePull "$scriptdir" "https://github.com/cloudbase/cinder-ci" "master"
}

. "$scriptdir\cinder_env\Cinder\scripts\utils.ps1"

$ErrorActionPreference = "SilentlyContinue"

# Do a selective teardown
Write-Host "Ensuring cinder service is stopped."
Stop-Service -Name cinder-volume -Force
Write-Host "Stopping any possible python processes left."
Stop-Process -Name python -Force
if (Get-Process -Name cinder-volume){
    Throw "Cinder is still running on this host"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}

$ErrorActionPreference = "Stop"

if ($(Get-Service cinder-volume).Status -ne "Stopped"){
    Throw "Nova service is still running"
}

Write-Host "Cleaning up the config folder."
if ($hasConfigDir -eq $false) {
    mkdir $configDir
}else{
    Try
    {
        Remove-Item -Recurse -Force $configDir\*
    }
    Catch
    {
        Throw "Can not clean the config folder"
    }
}

if (! Test-Path "$openstackDir\cinder\setup.py"){
    Throw "$projectName repository was not found. Please run gerrit-git-prep for this project first"
}

if (! Test-Path $cinderTemplate){
    Throw "Cinder template not found"
}

if (! Test-Path $remoteLogs){
    mkdir $remoteLogs\$hostname
}

if (! Test-Path $remoteConfigs){
    mkdir $remoteConfigs\$hostname
}
#!!! Binary pre-reqs????

#copy distutils.cfg
Copy-Item $scriptdir\windows\templates\distutils.cfg $pythonDir\Lib\distutils\distutils.cfg

if (! Test-Path $lockPath){
	mkdir $lockPath
}

pip install networkx
pip install futures

pushd $openstackDir\cinder
ExecRetry {
    cmd.exe /C "$pythonDir\$pythonExec" setup.py install
    if ($LastExitCode) { Throw "Failed to install cinder from repo" }
}
popd

#Add checks and generate config for iSCSI / SMB3
#use $scriptdir\windows\scripts\$test_case\generateConfig.ps1
#where $test_case = iscsi / smb_windows

Copy-Item "$templateDir\policy.json" "$configDir\" 
Copy-Item "$templateDir\interfaces.template" "$configDir\"

if (($branchName.ToLower().CompareTo($('stable/juno').ToLower()) -eq 0) -or ($branchName.ToLower().CompareTo($('stable/icehouse').ToLower()) -eq 0)) {
    $rabbitUser = "guest"
}

& $scriptdir\windows\scripts\$test_case\generateConfig.ps1 `
    $configDir $cinderTemplate $devstackIP $rabbitUser $remoteLogs $lockPath

#$hasCinderExec = Test-Path "$pythonDir\Scripts\cinder-volume.exe"
#if ($hasCinderExec -eq $false){
#    Throw "No nova exe found"
#}else{
#    $cindesExec = "$pythonDir\Scripts\nova-compute.exe"
#}

#FixExecScript "$pythonDir\Scripts\cinder-volume.py"

Remove-Item -Recurse -Force "$remoteConfigs\*"
Copy-Item -Recurse $configDir "$remoteConfigs\"

Write-Host "Starting the services"
Try
{
    Start-Service cinder-volume
}
Catch
{
    Throw "Can not start the cinder-volume service"
}
Write-Host "Environment initialization done."

