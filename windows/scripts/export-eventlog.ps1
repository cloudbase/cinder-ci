function exporteventlog(){
	$path = "C:\OpenStack\Logs\Eventlog"
	mkdir $path
	rm $path\*.txt
	get-eventlog -list | ForEach-Object {
		$logname = $_.LogDisplayName
		$logfilename = $_.LogDisplayName + ".txt"
		Get-EventLog -Logname $logname | fl | out-file $path\$logfilename
	}
}
exporteventlog