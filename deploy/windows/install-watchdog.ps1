# One-time setup of the gpu-box PC's WSL tasks (docs/compute.md "WSL watchdog"). Run it
# by hand from an elevated PowerShell, after reading it: its copy in %USERPROFILE%\.meiolol
# is writable from WSL, so check it is this file before running it as admin.
#   powershell -NoProfile -ExecutionPolicy Bypass -File $env:USERPROFILE\.meiolol\install-watchdog.ps1
#
# Writes the elevated part (wsl-mount.ps1, below) to C:\ProgramData\meiolol, which only
# Administrators and SYSTEM may change (Users may read the log), and registers two tasks
# as this user, logged on or not (S4U), at boot and every 2 min, one instance at a time:
# - wsl-mount, highest privileges (wsl --mount needs admin): attaches the archive
# - wsl-watchdog, least privilege: %USERPROFILE%\.meiolol\wsl-watchdog.ps1, the keepalive
# Nothing WSL can write ever runs elevated. Re-registering replaces a running keepalive's
# task; run it while no lab run is live (a WSL stop kills them).
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$dir = Join-Path $env:ProgramData meiolol
New-Item -ItemType Directory -Force $dir | Out-Null
# Owned by Administrators (an owner may always rewrite the ACL), nothing inherited from
# ProgramData (Users may create files there)
icacls $dir /reset /T /C | Out-Null
icacls $dir /setowner '*S-1-5-32-544' /T /C | Out-Null
icacls $dir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' `
    '*S-1-5-32-545:(OI)(CI)RX' /T /C | Out-Null

$mount = @'
# Attaches the archive partition at /mnt/wsl/archive: the 1 TB ext4 one on the 2 TB NVMe
# (wsl --mount takes the whole disk from Windows; it has no Windows volumes). Task
# wsl-mount runs it elevated at boot and every 2 min; it fails harmlessly when attached.
# Installed by deploy/windows/install-watchdog.ps1, which holds the source
$log = Join-Path $PSScriptRoot mount.log
function Log($msg) {
    $now = (Get-Date).ToUniversalTime().ToString('s')
    Add-Content $log "${now}Z $msg"
}
$disk = Get-Disk | Where-Object FriendlyName -like 'CT2000P3*'
if ($disk) {
    $drive = "\\.\PHYSICALDRIVE$($disk.Number)"
    $out = wsl.exe --mount $drive --partition 4 --name archive 2>&1
    if ($LASTEXITCODE -eq 0) { Log "archive attached ($drive)" }
} else { Log 'archive disk not found' }
'@
Set-Content -Path (Join-Path $dir wsl-mount.ps1) -Value $mount -Encoding UTF8

$user = "$env:USERDOMAIN\$env:USERNAME"
$triggers = @(
    New-ScheduledTaskTrigger -AtStartup
    New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 2)
)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable

function Register-WslTask($name, $script, $level) {
    $action = New-ScheduledTaskAction -Execute powershell.exe -Argument `
        "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType S4U -RunLevel $level
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $triggers `
        -Principal $principal -Settings $settings -Force | Out-Null
    "registered $name ($level, $user): $script"
}
Register-WslTask wsl-mount (Join-Path $dir wsl-mount.ps1) Highest
Register-WslTask wsl-watchdog (Join-Path $env:USERPROFILE '.meiolol\wsl-watchdog.ps1') Limited

# Left by the old elevated watchdog; nothing reads it
Remove-Item -ErrorAction SilentlyContinue (Join-Path $env:USERPROFILE '.meiolol\requests.txt')
icacls $dir
