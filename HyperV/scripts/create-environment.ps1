Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/cinder',
    [string]$isDebug='no'
)

if ($isDebug -eq  'yes') {
    Write-Host "Debug info:"
    Write-Host "devstackIP: $devstackIP"
    Write-Host "branchName: $branchName"
    Write-Host "buildFor: $buildFor"
}

$projectName = $buildFor.split('/')[-1]

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"
. "$scriptLocation\utils.ps1"

$hasNova = Test-Path $buildDir\nova
$hasNeutron = Test-Path $buildDir\neutron
$hasNeutronTemplate = Test-Path $neutronTemplate
$hasNovaTemplate = Test-Path $novaTemplate
$hasConfigDir = Test-Path $configDir
$hasBinDir = Test-Path $binDir
$hasBuildDir = Test-Path $buildDir
$hasMkisoFs = Test-Path $binDir\mkisofs.exe
$hasPipConf = Test-Path "$env:APPDATA\pip"
$hasLogDir = Test-Path $openstackLogs
$hasQemuImg = Test-Path $binDir\qemu-img.exe
Add-Type -AssemblyName System.IO.Compression.FileSystem

$pip_conf_content = @"
[global]
index-url = http://10.20.1.8:8080/cloudbase/CI/+simple/
[install]
trusted-host = 10.20.1.8
"@

$ErrorActionPreference = "SilentlyContinue"

# Do a selective teardown
Write-Host "Ensuring nova and neutron services are stopped."
Stop-Service -Name nova-compute -Force
Stop-Service -Name neutron-hyperv-agent -Force

Write-Host "Stopping any possible python processes left."
Stop-Process -Name python -Force

destroy_planned_vms

if (Get-Process -Name nova-compute){
    Throw "Nova is still running on this host"
}

if (Get-Process -Name neutron-hyperv-agent){
    Throw "Neutron is still running on this host"
}

if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}

$ErrorActionPreference = "Stop"

if (-not (Get-Service neutron-hyperv-agent -ErrorAction SilentlyContinue))
{
    Throw "Neutron Hyper-V Agent Service not registered"
}

if (-not (get-service nova-compute -ErrorAction SilentlyContinue))
{
    Throw "Nova Compute Service not registered"
}

if ($(Get-Service nova-compute).Status -ne "Stopped"){
    Throw "Nova service is still running"
}

if ($(Get-Service neutron-hyperv-agent).Status -ne "Stopped"){
    Throw "Neutron service is still running"
}

if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
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

if ($hasLogDir -eq $false){
    mkdir $openstackLogs
}

if ($hasBuildDir -eq $false){
    mkdir $buildDir
}

if ($hasBinDir -eq $false){
    mkdir $binDir
}

if (($hasMkisoFs -eq $false) -or ($hasQemuImg -eq $false)){
    Invoke-WebRequest -Uri "http://10.20.1.14:8080/openstack_bin.zip" -OutFile "$bindir\openstack_bin.zip"
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$bindir\openstack_bin.zip", "$bindir")
    Remove-Item -Force "$bindir\openstack_bin.zip"
}

if ($hasNovaTemplate -eq $false){
    Throw "Nova template not found"
}

if ($hasNeutronTemplate -eq $false){
    Throw "Neutron template not found"
}

git config --global user.email "hyper-v_ci@microsoft.com"
git config --global user.name "Hyper-V CI"

if ($isDebug -eq  'yes') {
    Write-Host "Status of $buildDir before GitClonePull"
    Get-ChildItem $buildDir
}

if ($buildFor -eq "openstack/cinder") {
    ExecRetry {
        GitClonePull "$buildDir\nova" "https://git.openstack.org/openstack/nova.git" $branchName
    }
    Get-ChildItem $buildDir
    ExecRetry {
        GitClonePull "$buildDir\neutron" "https://git.openstack.org/openstack/neutron.git" $branchName
    }
    Get-ChildItem $buildDir
    ExecRetry {
        GitClonePull "$buildDir\networking-hyperv" "https://git.openstack.org/openstack/networking-hyperv.git" $branchName
    }
    Get-ChildItem $buildDir
    ExecRetry {
        GitClonePull "$buildDir\compute-hyperv" "https://git.openstack.org/openstack/compute-hyperv.git" $branchName
    }
    Get-ChildItem $buildDir
    ExecRetry {
        GitClonePull "$buildDir\requirements" "https://git.openstack.org/openstack/requirements.git" $branchName
    }
    
    Get-ChildItem $buildDir
}
else {
    Throw "Cannot build for project: $buildFor"
}

pushd C:\
if (Test-Path $pythonArchive)
{
    Remove-Item -Force $pythonArchive
}
Invoke-WebRequest -Uri http://10.20.1.14:8080/python.zip -OutFile $pythonArchive
if (Test-Path $pythonDir)
{
    Cmd /C "rmdir /S /Q $pythonDir"
    #Remove-Item -Recurse -Force $pythonDir
}
Write-Host "Ensure Python folder is up to date"
Write-Host "Extracting archive.."
[System.IO.Compression.ZipFile]::ExtractToDirectory("C:\$pythonArchive", "C:\")

Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

$ErrorActionPreference = "Continue"
& easy_install -U pip
& pip install setuptools==26.0.0
& pip install pymi
$ErrorActionPreference = "Stop"

popd

cp $templateDir\distutils.cfg C:\Python27\Lib\distutils\distutils.cfg

if ($isDebug -eq  'yes') {
    Write-Host "BuildDir is: $buildDir"
    Write-Host "ProjectName is: $projectName"
    Write-Host "Listing $buildDir parent directory:"
    Get-ChildItem ( Get-Item $buildDir ).Parent.FullName
    Write-Host "Listing $buildDir before install"
    Get-ChildItem $buildDir
}

ExecRetry {
    pushd "$buildDir\requirements"
    Write-Host "Installing OpenStack/Requirements..."
    & pip install -c upper-constraints.txt -U pbr virtualenv httplib2 prettytable>=0.7 setuptools
    & pip install -c upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install openstack/requirements from repo" }
    popd
}  

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\$projectName"
        Get-ChildItem $buildDir\$projectName
    }
    pushd $buildDir\$projectName
    Write-Host "Installing openstack/neutron..."
    & update-requirements.exe --source $buildDir\requirements .
    & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install neutron from repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\networking-hyperv"
        Get-ChildItem $buildDir\networking-hyperv
    }
    pushd $buildDir\networking-hyperv
    git fetch https://git.openstack.org/openstack/networking-hyperv refs/changes/48/346848/1
    cherry_pick FETCH_HEAD
    Write-Host "Installing openstack/networking-hyperv..."
    & update-requirements.exe --source $buildDir\requirements .
    if (($branchName -eq 'stable/liberty') -or ($branchName -eq 'stable/mitaka')) {
        & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    } else {
        & pip install -e $buildDir\networking-hyperv
    }
    if ($LastExitCode) { Throw "Failed to install networking-hyperv from repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\nova"
        Get-ChildItem $buildDir\nova
    }
    pushd $buildDir\nova
    if ($branchName -eq 'master') {
        # This patch fixes deadlock on shelve instances
        git fetch https://git.openstack.org/openstack/nova refs/changes/37/352837/1
        cherry_pick FETCH_HEAD
    }
    Write-Host "Installing openstack/nova..."
    & update-requirements.exe --source $buildDir\requirements .
    & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install nova fom repo" }
    popd
}

ExecRetry {
    if ($isDebug -eq  'yes') {
        Write-Host "Content of $buildDir\compute-hyperv"
        Get-ChildItem $buildDir\compute-hyperv
    }
    pushd $buildDir\compute-hyperv
    if (@("stable/ocata", "master") -contains $branchName.ToLower()) {
        # This patch fixes duplicate option use_multipath_io
        git fetch https://git.openstack.org/openstack/compute-hyperv refs/changes/91/400091/1
        cherry_pick FETCH_HEAD
    }
    & update-requirements.exe --source $buildDir\requirements .
    if (@("stable/liberty", "stable/mitaka") -contains $branchName.ToLower()) {
        & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    }
    else {
        & pip install -e $buildDir\compute-hyperv
    }
    if ($LastExitCode) { Throw "Failed to install compute-hyperv from repo" }
    popd
}

if (@("stable/mitaka", "stable/newton", "stable/ocata", "master") -contains $branchName.ToLower()) {
    ExecRetry {
        # os-win only exists on stable/mitaka, stable/newton, stable/ocata and master.
        GitClonePull "$buildDir\os-win" "https://git.openstack.org/openstack/os-win.git" $branchName
        pushd $buildDir\os-win

        & update-requirements.exe --source $buildDir\requirements .
        & pip install -U $buildDir\os-win
    }
}

$cpu_array = ([array](gwmi -class Win32_Processor))
$cores_count = $cpu_array.count * $cpu_array[0].NumberOfCores
$novaConfig = (gc "$templateDir\nova.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$openstackLogs").Replace('[RABBITUSER]', $rabbitUser)
$neutronConfig = (gc "$templateDir\neutron_hyperv_agent.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "$openstackLogs").Replace('[RABBITUSER]', $rabbitUser).replace('[CORES_COUNT]', "$cores_count")

if (@("stable/mitaka", "stable/liberty") -contains $branchName.ToLower()) {
    $novaConfig = $novaConfig.replace('compute_hyperv.driver.HyperVDriver', 'hyperv.driver.HyperVDriver')
}
else {
    $novaConfig = $novaConfig.replace('network_api_class', '#network_api_class')
}

Set-Content $configDir\nova.conf $novaConfig
if ($? -eq $false){
    Throw "Error writting $configDir\nova.conf"
}

Set-Content $configDir\neutron_hyperv_agent.conf $neutronConfig
if ($? -eq $false){
    Throw "Error writting $configDir\neutron_hyperv_agent.conf"
}

cp "$templateDir\policy.json" "$configDir\"
cp "$templateDir\interfaces.template" "$configDir\"

$hasNovaExec = Test-Path "$pythonScripts\nova-compute.exe"
if ($hasNovaExec -eq $false){
    Throw "No nova-compute.exe found"
}

$hasNeutronExec = Test-Path "$pythonScripts\neutron-hyperv-agent.exe"
if ($hasNeutronExec -eq $false){
    Throw "No neutron-hyperv-agent.exe found"
}

Write-Host "Done building env"
