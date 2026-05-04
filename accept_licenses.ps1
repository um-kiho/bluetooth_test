param($cmd)
$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -RedirectStandardInput "yes.txt" -PassThru -NoNewWindow -Wait
