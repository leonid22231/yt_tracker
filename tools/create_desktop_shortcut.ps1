param(
    [string]$InstallDir = "$env:LOCALAppData\Programs\YouTrack Timer",
    [string]$ShortcutName = 'YouTrack Timer.lnk'
)

$ErrorActionPreference = 'Stop'
$exe = Join-Path $InstallDir 'youtrack_timer.exe'
if (-not (Test-Path $exe)) {
    Write-Error "Not found: $exe. Run tools\install_windows.ps1 first."
}

$desktop = [Environment]::GetFolderPath('Desktop')
$lnk = Join-Path $desktop $ShortcutName
$icon = Join-Path $InstallDir 'app_icon.ico'
if (-not (Test-Path $icon)) {
    $icon = $exe
}

$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($lnk)
$sc.TargetPath = $exe
$sc.WorkingDirectory = $InstallDir
$sc.Description = 'YouTrack Timer'
$sc.IconLocation = "$icon,0"
$sc.Save()
Write-Host "Shortcut: $lnk"
