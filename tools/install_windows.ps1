# Установка YouTrack Timer (Windows release) в %LocalAppData%\Programs
param(
    [string]$InstallDir = "$env:LOCALAppData\Programs\YouTrack Timer"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\youtrack_timer.exe")) {
    Write-Error "Сначала соберите: fvm flutter build windows --release"
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -Path "$release\*" -Destination $InstallDir -Recurse -Force
$iconSrc = Join-Path $root 'windows\runner\resources\app_icon.ico'
if (Test-Path $iconSrc) {
    Copy-Item $iconSrc (Join-Path $InstallDir 'app_icon.ico') -Force
}
$envExample = Join-Path $root '.env.example'
if (Test-Path $envExample) {
    Copy-Item $envExample (Join-Path $InstallDir '.env.example') -Force
}
$envPath = Join-Path $InstallDir '.env'
if (-not (Test-Path $envPath) -and (Test-Path (Join-Path $root '.env'))) {
    Copy-Item (Join-Path $root '.env') $envPath -Force
    Write-Host "Скопирован .env из проекта."
}

Write-Host "Установлено: $InstallDir"
