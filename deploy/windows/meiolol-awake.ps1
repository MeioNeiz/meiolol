# Holds off Windows sleep while the gpu-box is busy (Jacob: awake while busy, sleep
# otherwise). deploy/lab-watch.sh starts it and touches the flag file every few seconds;
# it ends once the flag is gone or stale (the watcher stopped), and the request with it.
# Logs to awake.log beside the flag (the watcher copies it into watcher.log): the request
# taken, the system's execution state every 10 min, and why it let go

param([string]$flag)

# The flags live in C#: Windows PowerShell reads 0x80000001 as a negative Int32, which
# no uint parameter takes, so the call never ran and the PC slept mid-run (2026-10-13)
Add-Type -Namespace Meiolol -Name Power -MemberDefinition @'
[DllImport("kernel32.dll")] static extern uint SetThreadExecutionState(uint flags);
[DllImport("powrprof.dll")]
static extern uint CallNtPowerInformation(int level, System.IntPtr inb, uint inl, out uint state, uint outl);
// ES_CONTINUOUS | ES_SYSTEM_REQUIRED: system sleep only, the screen may still turn off.
// 0 if it failed
public static uint Hold() { return SetThreadExecutionState(0x80000001); }
// SystemExecutionState: ES_SYSTEM_REQUIRED (0x1) set while any process holds it
public static uint State() {
    uint s; CallNtPowerInformation(16, System.IntPtr.Zero, 0, out s, 4); return s;
}
'@

$log = Join-Path (Split-Path $flag) 'awake.log'
function Log([string]$m) {
    Add-Content $log ("{0:yyyy-MM-ddTHH:mm:ssZ} {1}" -f (Get-Date).ToUniversalTime(), $m)
}

# Long enough to ride out the watcher's slow ticks on a loaded box (tasklist.exe under
# load 60) and a WSL clock behind Windows'; short enough to sleep soon after it stops
$stale = 300
function Age {
    if (-not (Test-Path $flag)) { return -1 }
    ((Get-Date) - (Get-Item $flag).LastWriteTime).TotalSeconds
}

if ([Meiolol.Power]::Hold() -eq 0) { Log "awake FAIL: SetThreadExecutionState refused"; exit 1 }
Log ("awake held (pid {0}, system state 0x{1:x})" -f $PID, [Meiolol.Power]::State())
$ticks = 0
while ($true) {
    $age = Age
    if ($age -lt 0) { Log "awake released: flag gone"; break }
    if ($age -ge $stale) { Log ("awake released: flag {0:N0} s old" -f $age); break }
    Start-Sleep -Seconds 20
    # Again each tick: cheap, and a request lost any way is back within 20 s
    [Meiolol.Power]::Hold() | Out-Null
    if ((++$ticks % 30) -eq 0) { Log ("awake holding, system state 0x{0:x}" -f [Meiolol.Power]::State()) }
}
