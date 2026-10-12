# Keeps WSL (Ubuntu) running on the gpu-box PC, logged in or not. Task Scheduler task
# wsl-watchdog runs it at boot and every 2 min as Jacob, highest privileges (wsl --mount
# needs admin), one instance at a time. docs/compute.md
#
# Each instance attaches the archive partition, then blocks in a keepalive until WSL
# stops (wsl --shutdown, a crash); the next trigger starts it all again.

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $dir watchdog.log
function Log($msg) {
    $now = (Get-Date).ToUniversalTime().ToString('s')
    Add-Content $log "${now}Z $msg"
}

# Elevated, so sleep blockers are visible here: kept for lab-watch.sh to check
powercfg /requests | Out-File (Join-Path $dir requests.txt)

# 1 TB ext4 partition on the 2 TB NVMe, at /mnt/wsl/archive. wsl --mount takes the
# whole disk from Windows; it has no Windows volumes. Fails harmlessly when attached
$disk = Get-Disk | Where-Object FriendlyName -like 'CT2000P3*'
if ($disk) {
    $drive = "\\.\PHYSICALDRIVE$($disk.Number)"
    $out = wsl.exe --mount $drive --partition 4 --name archive 2>&1
    if ($LASTEXITCODE -eq 0) { Log "archive attached ($drive)" }
} else { Log 'archive disk not found' }

Log 'keepalive start'
wsl.exe -d Ubuntu --exec sleep infinity
Log "keepalive ended ($LASTEXITCODE)"
