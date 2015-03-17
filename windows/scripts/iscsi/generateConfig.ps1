Param(
    [Parameter(Mandatory=$true)][string]$configDir,
    [Parameter(Mandatory=$true)][string]$templatePath,
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [Parameter(Mandatory=$true)][string]$rabbitUser,
    [Parameter(Mandatory=$true)][string]$logDir,
    [Parameter(Mandatory=$true)][string]$lockPath
)

$volumeDriver = 'cinder.volume.drivers.windows.windows.WindowsDriver'
$configFile = '$configDir\cinder.conf'

$template = gc $templatePath
$config =  $ExecutionContext.InvokeCommand.ExpandString($template)
sc $configFile $config
