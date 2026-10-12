# Holds off Windows sleep while the gpu-box is busy (Jacob: awake while busy, sleep
# otherwise). deploy/lab-watch.sh starts it and touches the flag file every few seconds;
# it ends once the flag is gone or stale (the watcher stopped), and the request with it.

param([string]$flag)

Add-Type -Namespace Meiolol -Name Power -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
'@
# ES_CONTINUOUS | ES_SYSTEM_REQUIRED: system sleep only, the screen may still turn off
[Meiolol.Power]::SetThreadExecutionState(0x80000001) | Out-Null

function Fresh {
    if (-not (Test-Path $flag)) { return $false }
    ((Get-Date) - (Get-Item $flag).LastWriteTime).TotalSeconds -lt 120
}
while (Fresh) { Start-Sleep -Seconds 20 }
