function Show-ErrorNotification {
    param([string]$Title, [string]$Message)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Error
        $notify.BalloonTipIcon = "Error"
        $notify.BalloonTipTitle = $Title
        $notify.BalloonTipText = $Message
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000)
        Start-Sleep -Milliseconds 500
        $notify.Dispose()
    } catch {}
}

$domains = @("gew1-spclient.spotify.com", "api.spotify.com", "api-partner.spotify.com")
$targetHost = "eu.geohide.ru"
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$spotifyPath = "$env:APPDATA\Spotify\Spotify.exe"

try {
    $ips = [System.Net.Dns]::GetHostAddresses($targetHost) | Select-Object -ExpandProperty IPAddressToString
} catch {
    Show-ErrorNotification "Ошибка сети" "Не удалось получить IP от $targetHost. Проверьте интернет."
    exit
}

$foundWorkingIp = $null

foreach ($ip in $ips) {
    $test = Test-NetConnection -ComputerName $ip -Port 443 -WarningAction SilentlyContinue
    if ($test.TcpTestSucceeded) {
        $foundWorkingIp = $ip
        break
    }
}

if ($foundWorkingIp) {
    try {
        $backupPath = "$hostsPath.bak"
        if (Test-Path $hostsPath) {
            Copy-Item $hostsPath $backupPath -Force
        }

        $lines = [System.IO.File]::ReadAllLines($hostsPath, [System.Text.Encoding]::UTF8)
        
        $newLines = [System.Collections.ArrayList]::new()
        $replacedDomains = @{}
        
        $domainPattern = ($domains -join "|")
        $regexPattern = "^\s*\d+\.\d+\.\d+\.\d+\s+($domainPattern)(\s*#.*)?$"
        
        foreach ($line in $lines) {
            if ($line -match $regexPattern) {
                $matchedDomain = $matches[1]
                if (-not $replacedDomains.ContainsKey($matchedDomain)) {
                    $newLines.Add("$foundWorkingIp $matchedDomain") | Out-Null
                    $replacedDomains[$matchedDomain] = $true
                }
            } else {
                $newLines.Add($line) | Out-Null
            }
        }
        
        foreach ($domain in $domains) {
            if (-not $replacedDomains.ContainsKey($domain)) {
                $newLines.Add("$foundWorkingIp $domain") | Out-Null
            }
        }
        
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($hostsPath, $newLines.ToArray(), $utf8NoBom)
        
        Start-Process $spotifyPath
    } catch {
        Show-ErrorNotification "Ошибка записи" "Не удалось обновить hosts: $($_.Exception.Message)"
    }
} else {
    Show-ErrorNotification "Ошибка подключения" "Ни один IP от $targetHost не отвечает. Возможно, провайдер их заблокировал."
}