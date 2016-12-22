# Loading config


$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"
. "$scriptLocation\utils.ps1"
. "$scriptLocation\iscsi_utils.ps1"

# end Loading config

$ErrorActionPreference = "SilentlyContinue"

Write-Host "Stopping cinder service"
Stop-Service -Name cinder-volume -Force

Write-Host "Stopping any python processes that might have been left running"
Stop-Process -Name python -Force
Stop-Process -Name cinder-volume -Force


Write-Host "Checking that services and processes have been succesfully stopped"
if (Get-Process -Name cinder-volume){
    Throw "cinder is still running on this host"
}else {
    Write-Host "No cinder process running."
}


if (Get-Process -Name python){
    Throw "Python processes still running on this host"
}else {
    Write-Host "No python processes left running"
}



#Write-Host "Clearing any VMs that might have been left."
#Get-VM | where {$_.State -eq 'Running' -or $_.State -eq 'Paused'} | Stop-Vm -Force
#Remove-VM * -Force

#destroy_planned_vms
cleanup_iscsi_targets

Write-Host "Cleaning the build folder."
Remove-Item -Recurse -Force $buildDir\*
#Write-Host "Cleaning the virtualenv folder."
#Remove-Item -Recurse -Force $virtualenv
Write-Host "Cleaning the logs folder."
Remove-Item -Recurse -Force $openstackDir\Log\*
Write-Host "Cleaning the config folder."
Remove-Item -Recurse -Force $openstackDir\etc\*
Write-Host "Cleaning the Instances folder."
Remove-Item -Recurse -Force $openstackDir\Instances\*
Write-Host "Cleaning eventlog"
cleareventlog
Write-Host "Removing SMBShare"
Remove-SmbShare -name smbshare -force
# iscsi cleanup
get-iscsivirtualdisksnapshot | Remove-IscsiVirtualDiskSnapshot
get-iscsivirtualdisk | remove-iscsivirtualdisk
Get-IscsiServerTarget | remove-IscsiServerTarget
Write-Host "Cleaning up process finished."
