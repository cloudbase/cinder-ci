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
