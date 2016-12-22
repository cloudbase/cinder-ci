Param(
    [Parameter(Mandatory=$true)][string]$configDir,
    [Parameter(Mandatory=$true)][string]$templatePath,
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [Parameter(Mandatory=$true)][string]$rabbitUser,
    [Parameter(Mandatory=$true)][string]$logDir,
    [Parameter(Mandatory=$true)][string]$lockPath,
    [Parameter(Mandatory=$true)][string]$username,
    [Parameter(Mandatory=$true)][string]$password,
    [Parameter(Mandatory=$true)][array]$hypervNodes
)

$volumeDriver = 'cinder.volume.drivers.windows.windows.WindowsDriver'
$configFile = "$configDir\cinder.conf"

$template = gc $templatePath
$config =  expand_template $template
Write-Host "Config file:"
Write-Host $config
Set-Content $configFile $config
