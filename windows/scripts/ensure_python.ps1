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
. "$scriptdir\windows\scripts\utils.ps1"

Add-Type -AssemblyName System.IO.Compression.FileSystem

pushd C:\

if (Test-Path $pythonDir)
{
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $pythonDir
}

ExecRetry {
    Invoke-WebRequest -Uri http://10.20.1.14:8080/python.zip -OutFile $pythonArchive
    if ($LastExitCode) { Throw "Failed fetching python27.tar.gz" }
}
Write-Host "Ensure Python folder is up to date"
Write-Host "Extracting archive.."
[System.IO.Compression.ZipFile]::ExtractToDirectory("C:\$pythonArchive", "C:\")
Write-Host "Removing the python archive.."
Remove-Item -Force -Recurse $pythonArchive

popd
