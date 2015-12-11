$openstackDir = "C:\Openstack"
$scriptdir = "C:\cinder-ci"
$configDir = "$openstackDir\etc"
$templateDir = "$scriptdir\windows\templates"
$cinderTemplate = "$templateDir\cinder.conf"
$pythonDir = "C:\Python27"
$pythonExec = "python.exe"
$pythonArchive = "python27.tar.gz"
$lockPath = "C:\Openstack\locks"
$remoteLogs="\\"+$devstackIP+"\openstack\logs"
$remoteConfigs="\\"+$devstackIP+"\openstack\config"
$rabbitUser = "stackrabbit"
$hostname = hostname

. "$scriptdir\windows\scripts\utils.ps1"

Write-Host "post-build: Stoping the services!"

Stop-Service cinder-volume

Write-Host "post-build: Cleaning previous logs!"

Remove-Item -Force C:\OpenStack\logs\*

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

