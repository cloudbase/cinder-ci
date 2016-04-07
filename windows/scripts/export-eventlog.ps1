. "C:\cinder-ci\windows\scripts\config.ps1"
. "$scriptdir\windows\scripts\utils.ps1"

if (Test-Path $eventlogPath){
	Remove-Item $eventlogPath -recurse -force
}

New-Item -ItemType Directory -Force -Path $eventlogPath

dumpeventlog $eventlogPath
exporthtmleventlog $eventlogPath
