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

$rabbitUser = "stackrabbit"

Copy-Item "$templateDir\policy.json" "$configDir\" 
Copy-Item "$templateDir\interfaces.template" "$configDir\"

& $scriptdir\windows\scripts\$testCase\generateConfig.ps1 $configDir $cinderTemplate $devstackIP $rabbitUser $openstackLogs $lockPath $winUser $winPasswd $hypervNodes > "$openstackLogs\generateConfig_error.txt" 2>&1
if ($LastExitCode -ne 0) {
 echo "generateConfig has failed!"
}

$hasCinderExec = Test-Path "$pythonDir\Scripts\cinder-volume.exe"
if ($hasCinderExec -eq $false){
    Throw "No cinder-volume.exe found"
}else{
    $cindesExec = "$pythonDir\Scripts\cinder-volume.exe"
}

Get-WMIObject Win32_LogicalDisk -filter "DriveType=3" | Select DeviceID, VolumeName, @{Name="size (GB)";Expression={"{0:N1}" -f($_.size/1gb)}}, @{Name="freespace (GB)";Expression={"{0:N1}" -f($_.freespace/1gb)}} | ft > "$openstackLogs\disk_free.txt" 2>&1
Get-Process > "$openstackLogs\pid_stat.txt" 2>&1

