# Keeps WSL (Ubuntu) running on the gpu-box PC, logged in or not. Task Scheduler task
# wsl-watchdog runs it at boot and every 2 min as Jacob, least privilege, one instance at
# a time: it blocks in a keepalive until WSL stops (wsl --shutdown, a crash), and the next
# trigger starts it again. Never elevated: WSL can write this file (deploy/lab-run.sh
# watch-install puts it in %USERPROFILE%\.meiolol). The archive mount, which needs admin,
# is task wsl-mount from C:\ProgramData\meiolol (install-watchdog.ps1). docs/compute.md

$log = Join-Path $PSScriptRoot watchdog.log
function Log($msg) {
    $now = (Get-Date).ToUniversalTime().ToString('s')
    Add-Content $log "${now}Z $msg"
}

Log 'keepalive start'
wsl.exe -d Ubuntu --exec sleep infinity
Log "keepalive ended ($LASTEXITCODE)"
