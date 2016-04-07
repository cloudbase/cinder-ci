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

. "C:\cinder-ci\windows\scripts\config.ps1"

$rabbitUser = "stackrabbit"
$hostname = hostname

$pip_conf_content = @"
[global]
index-url = http://dl.openstack.tld:8080/cloudbase/CI/+simple/
[install]
trusted-host = dl.openstack.tld
"@

# Replace Python dir with the archived template
# TODO: move this to the image instead.
pushd C:\

if (!(Test-Path -Path "$scriptdir\windows\scripts\utils.ps1"))
{
    Remove-Item -Force -Recurse "$scriptdir\* -ErrorAction SilentlyContinue"
    GitClonePull "$scriptdir" "https://github.com/cloudbase/cinder-ci" "cambridge"
}

. "$scriptdir\windows\scripts\utils.ps1"

ExecRetry {
    Invoke-WebRequest -Uri http://dl.openstack.tld/python27.tar.gz -OutFile $pythonArchive
    if ($LastExitCode) { Throw "Failed fetching python27.tar.gz" }
}
if (Test-Path $pythonDir)
{
    Remove-Item -Recurse -Force $pythonDir
}

Write-Host "Ensure Python folder is up to date"
Write-Host "Extracting archive.."
& C:\MinGW\msys\1.0\bin\tar.exe -xzf "$pythonArchive"
Write-Host "Removing the python archive.."
Remove-Item -Force -Recurse $pythonArchive

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
}
Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

& easy_install -U pip
& pip install -U --pre pymi
& pip install -U virtualenv
& pip install -U setuptools
& pip install -U distribute
& pip install cffi
#& pip install oslo.messaging==4.5.0
#& pip install 'os-win==0.2.2'

popd

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
    Throw "cinder-volume service is still running"
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

function cherry_pick($commit) {
    $eapSet = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    git cherry-pick $commit

    if ($LastExitCode) {
        echo "Ignoring failed git cherry-pick $commit"
        git checkout --force
    }
    $ErrorActionPreference = $eapSet
}

if ($testCase -ne "iscsi"){

	git fetch https://review.openstack.org/openstack/cinder refs/changes/98/289298/5 
	cherry_pick 5e1af8932435d5c8a718788f0828a66f412f32e5

	git remote add downstream https://github.com/petrutlucian94/cinder
	# git remote add downstream https://github.com/alexpilotti/cinder-ci-fixes
	
	ExecRetry {
	    git fetch downstream
	    if ($LastExitCode) { Throw "Failed fetching remote downstream petrutlucian94" }
	}

    git checkout -b "testBranch"
    #cherry_pick 56b1194332c29504ab96da35cf4f56143f0bd9cd
    cherry_pick 19341815884e235704f672ec377cdef9b1b5cb73
    cherry_pick 6f2fbf3fbef0f0bc3a21a495a2e60825adf8b848
}

ExecRetry {
    pushd C:\OpenStack\cinder
    & pip install C:\OpenStack\cinder
    if ($LastExitCode) { Throw "Failed to install cinder from repo" }
    popd
}
popd

Copy-Item "$templateDir\policy.json" "$configDir\" 
Copy-Item "$templateDir\interfaces.template" "$configDir\"

if (($branchName.ToLower().CompareTo($('stable/juno').ToLower()) -eq 0) -or ($branchName.ToLower().CompareTo($('stable/icehouse').ToLower()) -eq 0)) {
    $rabbitUser = "guest"
}

& $scriptdir\windows\scripts\$testCase\generateConfig.ps1 $configDir $cinderTemplate $devstackIP $rabbitUser $remoteLogs $lockPath $winUser $winPasswd  > "$remoteLogs\generateConfig_error.txt" 2>&1
if ($LastExitCode -ne 0) {
 echo "generateConfig has failed!"
}

#$hasCinderExec = Test-Path "$pythonDir\Scripts\cinder-volume.exe"
#if ($hasCinderExec -eq $false){
#    Throw "No nova exe found"
#}else{
#    $cindesExec = "$pythonDir\Scripts\nova-compute.exe"
#}

#FixExecScript "$pythonDir\Scripts\cinder-volume.py"

Remove-Item -Recurse -Force "$remoteConfigs\*"
Copy-Item -Recurse $configDir "$remoteConfigs\"
Get-WMIObject Win32_LogicalDisk -filter "DriveType=3" | Select DeviceID, VolumeName, @{Name="size (GB)";Expression={"{0:N1}" -f($_.size/1gb)}}, @{Name="freespace (GB)";Expression={"{0:N1}" -f($_.freespace/1gb)}} | ft > "$remoteConfigs\disk_free.txt" 2>&1
Get-Process > "$remoteConfigs\pid_stat.txt" 2>&1

Write-Host "Service Details:"
$filter = 'Name=' + "'" + $serviceName + "'" + ''
Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter | Select *

& pip install -U "Jinja2>=2.6"
pip install python-novaclient==2.28.1
#Fix for bug in monotonic pip package
#(Get-Content "C:\Python27\Lib\site-packages\monotonic.py") | foreach-object {$_ -replace ">= 0", "> 0"} | Set-Content  "C:\Python27\Lib\site-packages\monotonic.py"

#pip install decorator==3.4.2
# Fix for the __qualname__ attribute issue appended to decorated methods, impacting osprofiler
# TODO(lpetrut): send a fix for the latest decorator lib

pushd C:\
GitClonePull "C:\os-win\" "https://github.com/openstack/os-win" "master"
#pushd C:\os-win\
#ExecRetry {
#    git fetch https://review.openstack.org/openstack/os-win refs/changes/72/289872/2
#    if ($LastExitCode) {throw "git fetch failed"}
#}
#cherry_pick 09bba86fae031c3750c2a8923bc280e41ed839bb
#popd
&pip install C:\os-win
popd 

Write-Host "Starting the services"
Try
{
    Start-Service cinder-volume
}
Catch
{
    $proc = Start-Process -PassThru -RedirectStandardError "$remoteLogs\process_error.txt" -RedirectStandardOutput "$remoteLogs\process_output.txt" -FilePath "$pythonDir\Scripts\cinder-volume.exe" -ArgumentList "--config-file $configDir\cinder.conf"
    Start-Sleep -s 30
    if (! $proc.HasExited) {Stop-Process -Id $proc.Id -Force}
    Throw "Can not start the cinder-volume service"
}
Start-Sleep -s 30
if ($(get-service cinder-volume).Status -eq "Stopped")
{
    Write-Host "We try to start:"
    Write-Host Start-Process -PassThru -RedirectStandardError "$remoteLogs\process_error.txt" -RedirectStandardOutput "$remoteLogs\process_output.txt" -FilePath "$pythonDir\Scripts\cinder-volume.exe" -ArgumentList "--config-file $configDir\cinder.conf"
    Try
    {
    	$proc = Start-Process -PassThru -RedirectStandardError "$remoteLogs\process_error.txt" -RedirectStandardOutput "$remoteLogs\process_output.txt" -FilePath "$pythonDir\Scripts\cinder-volume.exe" -ArgumentList "--config-file $configDir\cinder.conf"
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
