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
. "$scriptLocation\utils.ps1"


if (!(Test-Path "$buildDir\cinder\setup.py")){
    Throw "$projectName repository was not found. Please run gerrit-git-prep for this project first"
}

pushd $buildDir\cinder
Write-Host "when install_cinder starts git log says:"
& git --no-pager log -10 --pretty=format:"%h - %an, %ae,  %ar : %s"
popd

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

ExecRetry {
    GitClonePull "$buildDir\requirements" "https://git.openstack.org/openstack/requirements.git" $branchName
}

ExecRetry {
    pushd "$buildDir\requirements"
    & pip install -c upper-constraints.txt -U pbr virtualenv httplib2 prettytable>=0.7 setuptools==33.1.1
    & pip install -c upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install openstack/requirements from repo" }
    popd
}

pushd $buildDir\cinder
Write-Host "just before installing cinder git log says:"
& git --no-pager log -10 --pretty=format:"%h - %an, %ae,  %ar : %s"
pip install -r requirements.txt

ExecRetry {
    GitClonePull "$buildDir\oslo.concurrency\" "https://github.com/openstack/oslo.concurrency" $branchName
    pushd $buildDir\oslo.concurrency
    & update-requirements.exe --source $buildDir\requirements .	
    & pip install -c $buildDir\requirements\upper-constraints.txt -U .
    if ($LastExitCode) { Throw "Failed to install oslo.concurrency from repo" }
    popd
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

ExecRetry {
    GitClonePull "$buildDir\os-win\" "https://github.com/openstack/os-win" "master"
    pushd $buildDir\os-win
    pip install .
    popd
}

popd

