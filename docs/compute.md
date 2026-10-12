# Compute: where heavy model work runs

The box (Oracle A1, 2 cores) crawls and serves; it only exports data. Training and
experiments run on:

| host | CPU | memory | GPU | how |
|---|---|---|---|---|
| gpu-box (Jacob's Windows PC, WSL2 Ubuntu, `ssh gpu-box`) | i5-13600KF, 20 threads | 24 of 32 GB | RTX 3080 (CUDA via libcuda) | deploy/lab-run.sh |
| Mac | Apple M5, 10 cores | 24 GB | none we use (no Metal path) | deploy/lab-run.sh mac, or directly |

## Rules

- gpu-box: long runs only while League isn't running (Jacob). The watcher
  (deploy/lab-watch.sh, systemd user service meiolol-lab-watch) stops every run's process
  group while LeagueClient.exe or League of Legends.exe is up and continues it after;
  each run's pauses.log says when. If Windows can't be asked, runs stay paused
- Tell the sessions using it (cc-peers; today meiolol-2a) before restarting WSL or
  rebooting the gpu-box: it kills running jobs
- WSL comes back by itself: Windows task `wsl-watchdog` (at boot and every 2 min, as
  Jacob, logged on or not, highest privileges) runs
  %USERPROFILE%\.meiolol\wsl-watchdog.ps1
  (deploy/windows): attaches the archive partition at /mnt/wsl/archive, then blocks in a
  keepalive. `wsl.exe --shutdown` from inside WSL is a restart, back in under ~2 min.
  Its log: watchdog.log; requests.txt is `powercfg /requests` (elevated) each start
- Sleep: lab-watch.sh keeps Windows awake while a run is live or a file in ~/ml/awake.d
  was touched in the last 15 min (eg the archive pull), via deploy/windows/meiolol-awake.*
  (SetThreadExecutionState); otherwise Windows sleeps as set (3 h idle on AC)
- ~/ml/meiolol on the gpu-box is the restore point from before the move to Oracle: leave
  it alone. Snapshots go in ~/ml/snaps/<stamp>/ (meiolol-2a: anonymised, salted PUUID
  hashes), runs in ~/ml/runs/

## Runs (deploy/lab-run.sh)

```
deploy/lab-run.sh start HOST NAME [--meiolol] [--no-build] -- ARGS...
deploy/lab-run.sh status [HOST] | logs HOST RUN [N] | stop HOST RUN | pull HOST RUN
deploy/lab-run.sh watch-install
```

- Builds from the working tree (experiments are often uncommitted), or with --head
  from committed HEAD in a temp tree (the shared tree is often mid-edit); a failed build
  never starts. meiolol-lab by
  default (`zig build lab`, ReleaseFast: host build for mac, x86_64-linux-gnu for the
  gpu-box), or meiolol with --meiolol (musl, x86_64_v3 on the gpu-box)
- Run dir ~/ml/runs/<UTC stamp>-<name> on the host: the binary, job.sh, log, meta (host,
  binary hash, HEAD, dirty count, args), src.diff (src and build.zig vs HEAD), started,
  ended, exit, pauses.log
- ARGS are joined and run by bash in the run dir on the host: ~ and globs expand there,
  relative outputs land in the run dir, `pull` copies it (minus the binary) to
  data/runs/RUN here
- Jobs run under nice 10 in their own process group (`stop` sends TERM to the group)

## WSL memory

WSL2 takes half the PC's memory by default (15 GB). C:\Users\jacob\.wslconfig sets
`memory=24GB` (8 GB left for Windows and League) and `autoMemoryReclaim=gradual` (idle
Linux cache goes back to Windows). Before: .wslconfig.bak-2026-10-12. Takes effect after
`wsl --shutdown` and a restart.

## Threads in our code

src/par.zig: `par.forEach(io, n, ctx, body)` runs body once per index on the Io thread
pool (one worker per CPU). Each index writes its own slot; reduce in index order after,
so results match a serial run bit for bit (never accumulate shared floats in body).
`meiolol eval` uses it for fold models, the prior grid, joint L2 fits, out-of-fold
terms, lane gold folds and the pick metric. 26.6k games: 38 s serial, 13 s on the M5,
7 s on the gpu-box; output byte-identical. Still serial: experience.load (SQLite page
reads) and the scan.

## Plan (2026-10-12)

What we know now: model work is CPU-parallel folds and grids (par.zig, done) plus GPU
embeddings and interactions (meiolol-2a), on snapshots of ~7-9 GB that grow with the
crawl; an overnight lab agent is designed (docs/lab-agent.md); and from ~3 weeks out the
gpu-box also holds the raw archive the box can no longer keep (plan.md "Retention").
That last one turns the PC from a nice-to-have into infrastructure, so reliability comes
first.

### 1. The PC as infrastructure (before the raw archive goes live)

- Sleep (Jacob: awake while busy): done, lab-watch.sh and ~/ml/awake.d (Rules above).
  The archive pull touches a file in ~/ml/awake.d while it has work
- Reboots (Jacob: task runs logged out): wsl-watchdog.ps1 as a password-stored task,
  highest privileges. Needs Jacob once in an elevated PowerShell (password); first boot
  without login still to be seen
- Reachability alert: the box's health loop (ntfy) warns when the gpu-box has been
  unreachable over 12 h and when the archive's unacked backlog nears the box's free disk
- Archive disk (Jacob: the 1 TB Linux partition): the WSL disk (ext4 vhdx) is on C:,
  261 GB free, shared with Windows and games. The 2 TB NVMe has no Windows letter: Linux
  partitions of 128 GB, 1 TB and 32 GB (an old Linux install?) and ~700 GB unallocated.
  wsl-watchdog.ps1 attaches the 1 TB one at /mnt/wsl/archive. Look at what is on it
  before writing; the archive goes in its own directory, nothing deleted without Jacob

### 2. Data for models (with meiolol-2a, who owns snapshots)

- Snapshot cadence: box -> Mac (anonymise, salt stays off the box) -> gpu-box
  ~/ml/snaps, weekly or per patch, the older one deleted (shared protocol). Scripted
  end to end instead of by hand; from the raw archive once it exists, not the live DB
- Packed rows: one `meiolol-lab pack SNAP` writes fixed-width column files (games,
  participants, timeline frames) per snapshot. Every model, eval included, then loads in
  seconds by mmap instead of SQLite page reads (today's remaining serial part of eval:
  experience.load and the scan), and the GPU path uploads columns as they are
- Runs record the snapshot stamp and seed in meta

### 3. Running more than one thing (when the lab agent starts)

- Queue: `lab-run queue HOST NAME -- ARGS` waits for its resource (the one GPU, or a CPU
  share) via a lock in job.sh; the lab agent's harness submits through it so overnight
  campaigns run back to back without overlapping
- Progress: runs append metrics.tsv (the dashboard, deploy/lab-push.sh, already reads
  it); runs over ~1 h write checkpoints and resume after a WSL restart or reboot
- Results: the harness keeps the ladder (lab-agent.md); docs/model.md keeps the dated
  tables. Nothing new here

### 4. Speed, only when a real workload needs it

- Measure first: eval, outcomes and 2a's models on the full snapshot on the gpu-box
- Dense Newton/Cholesky (logreg.zig) is d^3: fine at d ~850 (champion x role), not for
  pair or embedding features. Then L-BFGS/CG on CPU or a Zig Cholesky kernel on the GPU
  (2a)
- Not planned: Mac GPU (Metal) or cloud GPUs. The PC answers in seconds at today's
  volume; revisit only if it is often unavailable or a model outgrows 10 GB of VRAM
