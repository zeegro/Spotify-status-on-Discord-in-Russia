$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$taskName = "Spotify status on Discord in Russia"
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "Spotify"
$originalSpotifyPath = "$env:APPDATA\Spotify\Spotify.exe"
$scriptPath = Join-Path $PSScriptRoot "Update-SpotifyHosts.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ОШИБКА: Файл 'Update-SpotifyHosts.ps1' не найден в папке со скриптом!" -ForegroundColor Red
    Read-Host "Нажмите Enter для выхода"
    exit
}

$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    Write-Host "Задача найдена. Удаляю и возвращаю оригинальный Spotify..." -ForegroundColor Yellow
    
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    
    Set-ItemProperty -Path $regPath -Name $regName -Value "`"$originalSpotifyPath`""
    Write-Host "Готово! Оригинальный Spotify восстановлен в автозагрузке." -ForegroundColor Green

} else {
    Write-Host "Задача не найдена. Устанавливаю автозапуск..." -ForegroundColor Cyan
    
    $currentRegValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($currentRegValue.$regName) {
        Remove-ItemProperty -Path $regPath -Name $regName
        Write-Host "Оригинальный Spotify удален из автозагрузки реестра." -ForegroundColor Green
    }

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -RunLevel Highest -Force | Out-Null
    Write-Host "Готово! Задача '$taskName' успешно создана." -ForegroundColor Green
}

Read-Host "Нажмите Enter для выхода"