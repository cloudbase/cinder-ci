Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/cinder',
    [Parameter(Mandatory=$true)][string]$testCase,
    [Parameter(Mandatory=$true)][string]$winUser,
    [Parameter(Mandatory=$true)][string]$winPasswd
)

$projectName = $buildFor.split('/')[-1]
if ($projectName -ne "cinder")
{
    Throw "Error: Incorrect project $projectName. This setup is for testing Cinder patches."
}

$openstackDir = "C:\Openstack"
$scriptdir = "C:\cinder-ci"
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

# Replace Python dir with the archived template
# TODO: move this to the image instead.
Remove-Item -Force -Recurse $pythonDir
$archivePath = 'python27.tar.gz'
Invoke-WebRequest -Uri http://10.21.7.214/python27.tar.gz -OutFile "C:\$archivePath"
Write-Host "Ensure Python folder is up to date"
cmd /c cd \ `&`& C:\MinGW\msys\1.0\bin\tar.exe xvzf $archivePath
Remove-Item -Force -Recurse "c:\$archivePath"
easy_install -U pip
pip install wmi
pip install virtualenv
pip install -U setuptools
pip install -U distribute

if (!(Test-Path -Path "$scriptdir\windows\scripts\utils.ps1"))
{
    Remove-Item -Force -Recurse "$scriptdir\* -ErrorAction SilentlyContinue"
    GitClonePull "$scriptdir" "https://github.com/cloudbase/cinder-ci" "master"
}

. "$scriptdir\windows\scripts\utils.ps1"

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
if (!(Test-Path $configDir)) {
    mkdir $configDir
}else{
    Remove-Item -Recurse -Force $configDir\* -ErrorAction SilentlyContinue
}

if (!(Test-Path "$openstackDir\cinder\setup.py")){
    Throw "$projectName repository was not found. Please run gerrit-git-prep for this project first"
}

if (!(Test-Path $cinderTemplate)){
    Throw "Cinder template not found"
}

if (!(Test-Path $remoteLogs)){
    mkdir $remoteLogs
}

if (!(Test-Path $remoteConfigs)){
    mkdir $remoteConfigs
}
#!!! Binary pre-reqs????

#copy distutils.cfg
Copy-Item $scriptdir\windows\templates\distutils.cfg $pythonDir\Lib\distutils\distutils.cfg

if (!(Test-Path $lockPath)){
	mkdir $lockPath
}

pip install networkx
pip install futures

# TODO: remove this after the clone volume bug is fixed
$windows_utils = "$openstackDir\cinder\cinder\volume\drivers\windows\windows.py"
$content = gc $windows_utils
sc $windows_utils $content.Replace("self.create_volume(volume)", "self.create_volume(volume);os.unlink(self.local_path(volume))")
pushd $openstackDir\cinder

pip install -r requirements.txt

# Revert the driver disable patch
git config --global user.email "microsoft_cinder_ci@microsoft.com"
git config --global user.name "Microsoft Cinder CI"

function cherry_pick($commit){
    $ErrorActionPreference = "Continue"
    git cherry-pick $commit

    if ($LastExitCode) {
        echo "Ignoring failed git cherry-pick $commit"
        git checkout --force
    }
}

if ($testCase -ne "iscsi"){
	git remote add downstream https://github.com/petrutlucian94/cinder
	# git remote add downstream https://github.com/alexpilotti/cinder-ci-fixes
	
	ExecRetry {
	    git fetch downstream
	    if ($LastExitCode) { Throw "Failed fetching remote downstream petrutlucian94" }
	}

    git checkout -b "testBranch"

    cherry_pick 25c992c73a2e278dcbf5be5bf0c885127e5eb43c
    cherry_pick 87032e45ef3cd067120f96b5bc4cc0cb6ca23e25
    cherry_pick 54a3427c0c57efc6a9ce351b3e7889909584b6a2
    cherry_pick 171dbfcd067c79a2313da54a4bef0372606d76df
}

ExecRetry {
    cmd.exe /C "$pythonDir\$pythonExec" setup.py install
    if ($LastExitCode) { Throw "Failed to install cinder from repo" }
}
popd

Copy-Item "$templateDir\policy.json" "$configDir\" 
Copy-Item "$templateDir\interfaces.template" "$configDir\"

if (($branchName.ToLower().CompareTo($('stable/juno').ToLower()) -eq 0) -or ($branchName.ToLower().CompareTo($('stable/icehouse').ToLower()) -eq 0)) {
    $rabbitUser = "guest"
}

& $scriptdir\windows\scripts\$testCase\generateConfig.ps1 `
    $configDir $cinderTemplate $devstackIP $rabbitUser $remoteLogs $lockPath $winUser $winPasswd

#$hasCinderExec = Test-Path "$pythonDir\Scripts\cinder-volume.exe"
#if ($hasCinderExec -eq $false){
#    Throw "No nova exe found"
#}else{
#    $cindesExec = "$pythonDir\Scripts\nova-compute.exe"
#}

#FixExecScript "$pythonDir\Scripts\cinder-volume.py"

Remove-Item -Recurse -Force "$remoteConfigs\*"
Copy-Item -Recurse $configDir "$remoteConfigs\"
pip freeze > "$remoteConfigs\pip_freeze.txt" 2>&1
Get-WMIObject Win32_LogicalDisk -filter "DriveType=3" | Select DeviceID, VolumeName, @{Name="size (GB)";Expression={"{0:N1}" -f($_.size/1gb)}}, @{Name="freespace (GB)";Expression={"{0:N1}" -f($_.freespace/1gb)}} | ft > "$remoteConfigs\disk_free.txt" 2>&1
Get-Process > "$remoteConfigs\pid_stat.txt" 2>&1

Write-Host "Service Details:"
$filter = 'Name=' + "'" + $serviceName + "'" + ''
Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter | Select *

& pip install -U "Jinja2>=2.6"
#Fix for bug in monotonic pip package
#(Get-Content "C:\Python27\Lib\site-packages\monotonic.py") | foreach-object {$_ -replace ">= 0", "> 0"} | Set-Content  "C:\Python27\Lib\site-packages\monotonic.py"

pip install decorator==3.4.2
# Fix for the __qualname__ attribute issue appended to decorated methods, impacting osprofiler
# TODO(lpetrut): send a fix for the latest decorator lib

Write-Host "Starting the services"
Try
{
    Start-Service cinder-volume
}
Catch
{
    $proc = Start-Process -PassThru -RedirectStandardError "$remoteLogs\process_error.txt" -RedirectStandardOutput "$remoteLogs\process_output.txt" $pythonDir+'\python.exe -c "from ctypes import wintypes; from cinder.cmd import volume; volume.main()"' 
    Start-Sleep -s 30
    if (! $proc.HasExited) {Stop-Process -Id $proc.Id -Force}
    Throw "Can not start the cinder-volume service"
}
Start-Sleep -s 30
if ($(get-service cinder-volume).Status -eq "Stopped")
{
    Write-Host "We try to start:"
    Write-Host Start-Process -PassThru -RedirectStandardError "$remoteLogs\process_error.txt" -RedirectStandardOutput "$remoteLogs\process_output.txt" -FilePath "$pythonDir\python.exe" -ArgumentList '-c "from ctypes import wintypes; from cinder.cmd import volume; volume.main()"'
    Try
    {
    	$proc = Start-Process -PassThru -RedirectStandardError "$remoteLogs\process_error.txt" -RedirectStandardOutput "$remoteLogs\process_output.txt" -FilePath "$pythonDir\python.exe" -ArgumentList '-c "from ctypes import wintypes; from cinder.cmd import volume; volume.main()"'
    }
    Catch
    {
    	Throw "Could not start the process manually"
    }
    Start-Sleep -s 30
    if (! $proc.HasExited)
    {
    	Stop-Process -Id $proc.Id -Force
    	Throw "Process started fine when run manually."
    }
    else
    {
    	Throw "Can not start the cinder-volume service. The manual run failed as well."
    }
}


Write-Host "Environment initialization done."

