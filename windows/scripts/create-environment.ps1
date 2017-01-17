Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/cinder',
    [Parameter(Mandatory=$true)][string]$testCase,
    [Parameter(Mandatory=$true)][string]$winUser,
    [Parameter(Mandatory=$true)][string]$winPasswd,
    [Parameter(Mandatory=$true)][array]$hypervNodes
)

$projectName = $buildFor.split('/')[-1]
if ($projectName -ne "cinder")
{
    Throw "Error: Incorrect project $projectName. This setup is for testing Cinder patches."
}

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"

$rabbitUser = "stackrabbit"
$hostname = hostname
Add-Type -AssemblyName System.IO.Compression.FileSystem

$pip_conf_content = @"
[global]
index-url = http://10.20.1.8:8080/cloudbase/CI/+simple/
[install]
trusted-host = 10.20.1.8
"@

# Replace Python dir with the archived template
# TODO: move this to the image instead.
pushd C:\

if (!(Test-Path -Path "$scriptdir\windows\scripts\utils.ps1"))
{
    Remove-Item -Force -Recurse "$scriptdir\* -ErrorAction SilentlyContinue"
    GitClonePull "$scriptdir" "https://github.com/cloudbase/cinder-ci" "cambridge-test"
}

. "$scriptdir\windows\scripts\utils.ps1"

ExecRetry {
    Invoke-WebRequest -Uri http://10.20.1.14:8080/python.zip -OutFile $pythonArchive
    if ($LastExitCode) { Throw "Failed fetching python27.tar.gz" }
}

ExecRetry {
    GitClonePull "$buildDir\requirements" "https://git.openstack.org/openstack/requirements.git" $branchName
}

if (Test-Path $pythonDir)
{
    Remove-Item -Recurse -Force $pythonDir
}

Write-Host "Ensure Python folder is up to date"
Write-Host "Extracting archive.."
[System.IO.Compression.ZipFile]::ExtractToDirectory("C:\$pythonArchive", "C:\")
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
& pip install pymysql
& pip install amqp==1.4.9

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

if (!(Test-Path "$buildDir\cinder\setup.py")){
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

#copy distutils.cfg
Copy-Item $scriptdir\windows\templates\distutils.cfg $pythonDir\Lib\distutils\distutils.cfg

if (!(Test-Path $lockPath)){
	mkdir $lockPath
}

ExecRetry {
    pushd "$buildDir\requirements"
    & pip install -c upper-constraints.txt -U pbr virtualenv httplib2 prettytable>=0.7 setuptools
    & pip install -c upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install openstack/requirements from repo" }
    popd
}

pip install networkx
pip install futures

pushd $buildDir\cinder
& git --no-pager log -10 --pretty=format:"%h - %an, %ae,  %ar : %s"
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

#if ($testCase -ne "iscsi"){
#
#    #git fetch https://review.openstack.org/openstack/cinder refs/changes/98/289298/5 
#    #cherry_pick 5e1af8932435d5c8a718788f0828a66f412f32e5
#
#    git remote add downstream https://github.com/petrutlucian94/cinder
#    # git remote add downstream https://github.com/alexpilotti/cinder-ci-fixes
#	
#    ExecRetry {
#       git fetch downstream
#        if ($LastExitCode) { Throw "Failed fetching remote downstream petrutlucian94" }
#    }
#
#    git checkout -b "testBranch"
#    #cherry_pick 56b1194332c29504ab96da35cf4f56143f0bd9cd
#    if ($branchName.ToLower() -in @("master", "stable/newton")) {
#        cherry_pick dcd839978ca8995cada8a62a5f19d21eaeb399df
#        cherry_pick f711195367ead9a2592402965eb7c7a73baebc9f
#    }
#    else {
#        cherry_pick 0c13ba732eb5b44e90a062a1783b29f2718f3da8
#        cherry_pick 06ee0b259daf13e8c0028a149b3882f1e3373ae1
#    }
#}
if ($branchName.ToLower() -eq "master" -or $branchName.ToLower() -eq "stable/newton"){
    ExecRetry {
        GitClonePull "$buildDir\oslo.concurrency\" "https://github.com/openstack/oslo.concurrency" "master"
        pushd $buildDir\oslo.concurrency
    	
        & pip install -U .
        if ($LastExitCode) { Throw "Failed to install oslo.concurrency from repo" }
        popd
    }

    ExecRetry {
        pushd $buildDir\cinder
        git fetch git://git.openstack.org/openstack/cinder refs/changes/41/403641/4
        cherry_pick FETCH_HEAD
        popd
    }
}

ExecRetry {
    pushd $buildDir\cinder
    & update-requirements.exe --source $buildDir\requirements .
    & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    Write-Host "After install:"
    & git --no-pager log -10 --pretty=format:"%h - %an, %ae,  %ar : %s"
    if ($LastExitCode) { Throw "Failed to install cinder from repo" }
    popd
}
popd

Copy-Item "$templateDir\policy.json" "$configDir\" 
Copy-Item "$templateDir\interfaces.template" "$configDir\"

& $scriptdir\windows\scripts\$testCase\generateConfig.ps1 $configDir $cinderTemplate $devstackIP $rabbitUser $openstackLogs $lockPath $winUser $winPasswd $hypervNodes > "$remoteLogs\generateConfig_error.txt" 2>&1
if ($LastExitCode -ne 0) {
 echo "generateConfig has failed!"
}

$hasCinderExec = Test-Path "$pythonDir\Scripts\cinder-volume.exe"
if ($hasCinderExec -eq $false){
    Throw "No cinder-volume.exe found"
}else{
    $cindesExec = "$pythonDir\Scripts\cinder-volume.exe"
}


Remove-Item -Recurse -Force "$remoteConfigs\*"
Copy-Item -Recurse $configDir "$remoteConfigs\"
Get-WMIObject Win32_LogicalDisk -filter "DriveType=3" | Select DeviceID, VolumeName, @{Name="size (GB)";Expression={"{0:N1}" -f($_.size/1gb)}}, @{Name="freespace (GB)";Expression={"{0:N1}" -f($_.freespace/1gb)}} | ft > "$remoteConfigs\disk_free.txt" 2>&1
Get-Process > "$remoteConfigs\pid_stat.txt" 2>&1

Write-Host "Service Details:"
$filter = 'Name=' + "'" + $serviceName + "'" + ''
Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter | Select *

& pip install -U "Jinja2>=2.6"

pushd C:\
ExecRetry {
    GitClonePull "$buildDir\os-win\" "https://github.com/openstack/os-win" "master"
    pushd $buildDir\os-win
    pip install .
    popd
}
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
