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
deploy/lab-run.sh start HOST NAME [--meiolol] [--head | --no-build] [--res cpu|gpu|none]
    -- ARGS...
deploy/lab-run.sh status [HOST] | logs HOST RUN [N] | stop HOST RUN | restart HOST RUN
deploy/lab-run.sh pull HOST RUN
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
- Queue: a run waits for its resource's lock on the host (~/ml/locks/cpu or gpu) before
  `started`; status shows it "queued". cpu by default (every run uses all cores), --res
  gpu for GPU work (it can share the PC with a cpu run), none to skip. lab-exp.sh counts
  only running time toward its budget, so queued runs aren't killed
- WSL restarts: lab-watch.sh, starting with WSL, runs again (twice at most) any run that
  was live when WSL went down; `restart` does it by hand. A run over ~1 h should keep
  checkpoints in its run dir and resume from them (none does yet: runs take minutes)

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
- Reboots (Jacob: task runs logged out): wsl-watchdog task registered 2026-10-12 (S4U,
  highest privileges), attaches the archive and keeps WSL up; first boot without login
  still to be seen
- Reachability alert (done, deploy/health.sh): the box can't reach the PC, so it warns
  when the archive has had no ack for 12 h, and when free disk is under twice the raw it
  holds
- Archive disk (Jacob: the 1 TB Linux partition): the WSL disk (ext4 vhdx) is on C:,
  261 GB free, shared with Windows and games. The 2 TB NVMe has no Windows letter: Linux
  partitions of 128 GB, 1 TB and 32 GB (an old Linux install?) and ~700 GB unallocated.
  wsl-watchdog.ps1 attaches the 1 TB one at /mnt/wsl/archive. It was the home of an old
  Pop!_OS install (jml/, 8.6 GB): Jacob keeps it, so write only in meiolol-raw/ (the
  archive, owned by jmu). Without the partition that directory is missing and the pull
  stops

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

- Queue (done, 2026-10-12): every lab-run start waits for its resource's lock, so
  lab-exp campaigns run back to back without overlapping (Runs above)
- Progress: runs append metrics.tsv (the dashboard, deploy/lab-push.sh, already reads
  it). Restart after a WSL restart: done; checkpoints inside a model once one runs ~1 h
- Results: the harness keeps the ladder (lab-agent.md); docs/model.md keeps the dated
  tables. Nothing new here

### 4. Speed, only when a real workload needs it

- Measure first: eval, outcomes and 2a's models on the full snapshot on the gpu-box
- Dense Newton/Cholesky (logreg.zig) is d^3: fine at d ~850 (champion x role), not for
  pair or embedding features. Then L-BFGS/CG on CPU or a Zig Cholesky kernel on the GPU
  (2a)
- Not planned: Mac GPU (Metal) or cloud GPUs. The PC answers in seconds at today's
  volume; revisit only if it is often unavailable or a model outgrows 10 GB of VRAM

## GPU path in meiolol-lab (meiolol-2a, 2026-10-12)

- No CUDA toolkit: src/gpu/cuda.zig dlopens libcuda.so.1 (WSL ships it as
  /usr/lib/wsl/lib/libcuda.so.1) and declares the driver API calls it needs; device code
  in src/gpu/kernels.zig compiles to PTX for sm_86 (`zig build lab` does it, embedded in
  the binary); the driver JIT-compiles it at load. Smoke: `meiolol-lab gpu-smoke`
- Kernels take pointers and scalars only (no by-value structs); a layout struct shared
  with the host lives in device memory (src/gpu/fm_layout.zig, extern). Float atomics
  (`@atomicRmw(f32, .Add)`) compile to native red.global.add.f32
- fm kernels (fe3520e): fm_grad (one thread per row, gradients into a dense buffer with
  atomics) and fm_adam (one thread per parameter). Host side (src/lab/bench.zig) not
  written yet: upload rows once as fm_layout.Example (72 bytes), host shuffles each
  epoch so CPU and GPU see identical batches, memset + fm_grad + fm_adam per batch
- CPU reference: fm.zig's fit takes 1-5 s per fit single-threaded on 1.2M rows (5
  outcomes x 4 models x grid ~5 min on one core). The GPU vs CPU timing (Jacob: measure,
  don't assume) is the benchmark in progress
