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

function unzip($src, $dest) {

        $shell = new-object -com shell.application
        $zip = $shell.NameSpace($src)
        foreach($item in $zip.items())
        {
                $shell.Namespace($dest).copyhere($item)
        }

}

Invoke-WebRequest -Uri http://144.76.59.195:8088/qemu-img-cbsl-build.zip -OutFile c:\qemu-img-cbsl-build.zip
if (Test-Path -Path c:\qemu-img){
	Remove-Item -Force -Recurse c:\qemu-img
}
unzip c:\qemu-img-cbsl-build.zip c:\

$volumeDriver = 'cinder.volume.drivers.windows.windows.WindowsDriver'
$configFile = "$configDir\cinder.conf"

$template = gc $templatePath
$config =  expand_template $template
Write-Host "Config file:"
Write-Host $config
Set-Content $configFile $config
