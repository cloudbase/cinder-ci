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

$pip_conf_content = @"
[global]
index-url = http://144.76.59.195:8099/cloudbase/CI/+simple/
[install]
trusted-host = 144.76.59.195
"@

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
}
Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

$ErrorActionPreference = "SilentlyContinue"
& easy_install -U pip
& pip install -U --pre pymi
& pip install -U virtualenv
& pip install -U setuptools
& pip install -U distribute
& pip install cffi
& pip install pymysql
& pip install amqp==1.4.9
& pip install networkx
& pip install futures
& pip install -U "Jinja2>=2.6"
