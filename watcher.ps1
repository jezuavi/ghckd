$pidFile = "$env:TEMP\stage2_pid.txt"
$stage2Path = "stage2.ps1"

if (Test-Path -Path $pidFile) {
    try {
        $savedPID = Get-Content -Path $pidFile -ErrorAction Stop
        
        if (Get-Process -Id $savedPID -ErrorAction SilentlyContinue) {
            Write-Host "Stage2 is running (PID: $savedPID). Exiting."
            exit 0
        }
        else {
            Write-Host "PID $savedPID not running. Starting Stage2..."
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
            Start-Process "powershell.exe" -ArgumentList "-File `"$stage2Path`""
        }
    }
    catch {
        Write-Host "Error reading PID file: $($_.Exception.Message)"
        Write-Host "Starting Stage2 as fallback..."
        Start-Process "powershell.exe" -ArgumentList "-File `"$stage2Path`""
    }
}
else {
    Write-Host "No PID file found. Starting Stage2..."
    Start-Process "powershell.exe" -ArgumentList "-File `"$stage2Path`""
}
