param([string]$OutputPath, [string]$Mode='Success')
Start-Sleep -Milliseconds 500
if ($Mode -eq 'Failure') { exit 1 }
if ($Mode -eq 'Invalid') { [IO.File]::WriteAllText($OutputPath,'[]'); exit }
if ($Mode -eq 'Slow') { Start-Sleep -Seconds 30 }
[IO.File]::WriteAllText($OutputPath,'{"fixture-endpoint":"Fixture renamed device"}')
