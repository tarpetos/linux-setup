# Install the PyCharm-like Zed setup for Zed on Windows (no admin needed).
# run.sh --zed calls this from WSL; it can also be run on its own:
#   powershell -ExecutionPolicy Bypass -File install-windows.ps1
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

# Settings
$zedDir = Join-Path $env:APPDATA 'Zed'
New-Item -ItemType Directory -Force $zedDir | Out-Null
$target = Join-Path $zedDir 'settings.json'
$new = [IO.File]::ReadAllText((Join-Path $repo 'settings.json'))
$old = if (Test-Path $target) { [IO.File]::ReadAllText($target) } else { $null }
if ($old) {
    # Keep the remote connections Zed saves into settings.json
    $saved = [regex]::Matches($old, '(?ms)^  "(wsl|ssh)_connections": \[.*?^  \],?\r?\n') |
        ForEach-Object { $_.Value -replace '\],?(\r?\n)$', '],$1' }
    if ($saved) {
        $at = $new.IndexOf("`n", $new.IndexOf('{')) + 1
        $new = $new.Insert($at, ($saved -join ''))
    }
}
if ($new -eq $old) {
    Write-Host "Zed settings already up to date"
} else {
    if ($old) {
        $backup = "$target.bak_$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
        Copy-Item $target $backup
        Write-Host "Backed up old settings to $backup"
    }
    [IO.File]::WriteAllText($target, $new)
    Write-Host "Copied settings.json to $zedDir"
}

# Fonts, installed for the current user
$regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$registered = Get-ItemProperty $regKey -ErrorAction SilentlyContinue
if ($registered.'JetBrains Mono Regular (TrueType)' -and $registered.'Inter Regular (TrueType)') {
    Write-Host "JetBrains Mono and Inter already installed"
} else {
    $tmp = Join-Path $env:TEMP "zed-config-fonts"
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip -OutFile "$tmp\jbm.zip"
    Invoke-WebRequest https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip -OutFile "$tmp\inter.zip"
    Expand-Archive "$tmp\jbm.zip" "$tmp\jbm" -Force
    Expand-Archive "$tmp\inter.zip" "$tmp\inter" -Force
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    $fonts = @(Get-ChildItem "$tmp\jbm\fonts\ttf\JetBrainsMono-*.ttf") + @(Get-ChildItem "$tmp\inter\extras\ttf\Inter-*.ttf")
    foreach ($f in $fonts) {
        $dest = Join-Path $fontDir $f.Name
        # A font already installed is locked while apps use it, so leave it in place
        if (-not (Test-Path $dest)) { Copy-Item $f.FullName $dest }
        $family = if ($f.Name -like 'JetBrainsMono-*') { 'JetBrains Mono' } else { 'Inter' }
        $style = $f.BaseName.Split('-')[1]
        New-ItemProperty -Path $regKey -Name "$family $style (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
    }
    Remove-Item $tmp -Recurse -Force
    Write-Host "Installed JetBrains Mono and Inter"
}

# Git for projects opened from \\wsl.localhost
# Windows cannot see Linux exec bits, so without fileMode=false every script shows as modified.
[Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', '1', 'User')
[Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', 'core.fileMode', 'User')
[Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', 'false', 'User')
if (Get-Command git -ErrorAction SilentlyContinue) {
    $safe = '%(prefix)///wsl.localhost/*'
    if (-not (git config --global --get-all safe.directory | Where-Object { $_ -eq $safe })) {
        git config --global --add safe.directory $safe
    }
    Write-Host "Configured Windows git for WSL repositories"
} else {
    Write-Host "git not found on Windows PATH; skipped safe.directory (Zed's git panel needs git)"
}
