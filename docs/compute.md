# Compute: where heavy model work runs

The box (C01, docs/hosting.md) crawls and serves; it only exports data. Training and
experiments run on:

| host | CPU | memory | GPU | how |
|---|---|---|---|---|
| gpu-box (Jacob's Windows PC, WSL2 Ubuntu, `ssh gpu-box`) | i5-13600KF, 20 threads | 24 of 32 GB | RTX 3080 (CUDA via libcuda) | deploy/lab-run.sh |
| Mac | Apple M5, 10 cores | 24 GB | none we use (no Metal path) | deploy/lab-run.sh mac, or directly |

Starting, queueing and placing runs, sweeps and the lab agent's limits:
docs/lab-run.md.

## Rules

- gpu-box: nothing heavy while League runs (Jacob: no stutter). The watcher
  (deploy/lab-watch.sh, systemd user service meiolol-lab-watch, log ~/ml/runs/watcher.log)
  asks tasklist.exe every 3 s (5 while up). While LeagueClient.exe or League of
  Legends.exe is up, or Windows can't be asked, it stops every run's process group
  (each run's pauses.log says when), ends remote-build jobs, and stops the process
  groups of agents' zig compiles, headless Chromium (and the node driving it) and
  `meiolol dev` (only those processes when the group also holds Claude, ssh or a login
  shell).
  Those go in ~/.cache/meiolol-league-stopped ("quiet:" log lines) and continue when
  League closes or the watcher stops or starts. Not paused: ssh and rsync copies,
  snapshot builds, the archive pull, the backup mirror
- Builds there wait: deploy/slots.sh (zb.sh, pre-push ci, gpu-box.sh install) grants no
  slot while ~/.cache/meiolol-league, the watcher's state each tick, isn't down (a file
  over a minute old: no watcher, builds go), and runs held builds at nice 19, idle I/O.
  Lowering the WSL VM's Windows priority needs admin: not done.
  Test: deploy/lab-watch-test.sh
- Tell the sessions using it (cc-peers) before restarting WSL or
  rebooting the gpu-box: it kills running jobs
- WSL comes back by itself: two Windows tasks, at boot and every 2 min, as Jacob, logged
  on or not (S4U), one instance at a time (deploy/windows/install-watchdog.ps1 registers
  both). `wsl-watchdog`, least privilege, runs %USERPROFILE%\.meiolol\wsl-watchdog.ps1,
  a keepalive that blocks until WSL stops (log watchdog.log there). `wsl-mount`, highest
  privileges (wsl --mount needs admin), runs C:\ProgramData\meiolol\wsl-mount.ps1, which
  attaches the archive partition at /mnt/wsl/archive (log mount.log there). Nothing WSL
  can write runs elevated: .meiolol is Jacob's, so anything in WSL could change a script
  there; ProgramData\meiolol is Administrators and SYSTEM only. `wsl.exe --shutdown` from
  inside WSL is a restart, back in under ~2 min
- Sleep: lab-watch.sh keeps Windows awake while a run is live or a file in ~/ml/awake.d
  was touched in the last 15 min (eg the archive pull), via deploy/windows/meiolol-awake.*
  (SetThreadExecutionState); otherwise Windows sleeps as set (3 h idle on AC)
- ~/ml/meiolol on the gpu-box is the restore point from before the move to Oracle: leave
  it alone. Snapshots go in ~/ml/snaps/<stamp>/ (anonymised, salted PUUID hashes), runs
  in ~/ml/runs/; both are symlinks onto the lab partition (gpu-box storage)
- New snapshots: `deploy/snapshot.sh make` on the Mac from an hourly launchd tick, due
  from 07:00 once the newest predates the 04:00 UTC backup (so it holds games to that
  morning), skipped while the gpu-box is asleep or League is open; built on the gpu-box
  (docs/data-safety.md "Analysis snapshots"), ~80 min. Each fetch prunes older snapshots
  on both hosts except docs/golden.tsv's and any a live run names; LAB_SNAP defaults to
  the newest
- Derived arrays that cost minutes go in ~/ml/snaps/.cache/<snap>/ (src/lab/snapcache.zig;
  hidden, outside the snapshot's hash): comps.loadExtra's comp_stats by row
  (`compstats`, 1.4 GB, keyed by the tsv stamps, row order and compstats.zig) and
  champcomp's ratings offsets per window (`offsets-BEFORE-HI`, keyed by the binary),
  which champgroups shares (fold 3's). Safe to delete: the next run rebuilds them

## Builds on the gpu-box

Zig builds and tests can run there instead of on the Mac (29 Oct, idle gpu-box vs the
Mac): test after a backend edit 47 s vs ~150 s quiet and 440-617 s with ~10 sessions;
ci 51 s; test-ui 3.9 s vs 5-28 s. Debug x86_64 builds use Zig's self-hosted backend, no
LLVM. The deploy build (ReleaseSafe, LLVM, one long single-core step) is faster on the
M5: 185 s vs 230 s, so it stays on the Mac.

- `deploy/compute.sh` shows both hosts: the Mac's load, swap, build slots and zig
  compiles (naming those outside any slot), the gpu-box's League, load, builds and lab
  slots, and where test, ci and test-ui would go now
- `deploy/place.sh KIND` says where a build of KIND goes and why: test and ci to the
  gpu-box when builds there are on, it answers ssh in 3 s, League is down and a build
  slot is free (or none waits); test-ui only while the Mac's load is over its cores.
  `place.sh off|on` for every session (eg the gpu-box away for a while);
  MEIOLOL_WHERE=mac|gpu-box per call. ssh shares one connection (~/.ssh/cm, 10 min)
- `deploy/remote-build.sh [--commit REV] ARGS` runs `zig build ARGS` there and looks
  local: output streamed with the tree's paths turned into the checkout's, the build's
  exit code. Inputs: HEAD (git push to ~/ml/build/repo.git) plus the working tree's
  patch and untracked files, or a commit alone; ~1 s here, then the build. Exit 75: not
  built there (off, unreachable, League, no slot in 60 s, lost 30 s mid-build, the job
  died): build on the Mac
- There: deploy/build-job.sh (sent with each build) in ~/ml/build/jobs/ID, own process
  group, outlives ssh; a slot ~/ml/locks/build.K (build.slots, default 2) and its fixed
  tree ~/ml/build/tree.K (zig's cache is keyed by path: a fresh dir is a cold build),
  cache ~/ml/build/cache; nice 0, ahead of lab runs. lab-watch.sh ends builds while
  League is up (the Mac builds them again) and keeps Windows awake while one runs
- ci there needs zstd, shellcheck, jq and node 24 (Ubuntu's 18 can't `--check` ES
  modules): deploy/gpu-box.sh install; versions head the output. Not built there:
  shellMac (macOS only). Linux skips 4 tests. ui.wasm budgets are measured in-process,
  the same on every host (dev-flow.md "ui.wasm sizes")

## gpu-box storage

The lab disk is a Crucial P3 2 TB NVMe with no Windows letter (Disk resets, below):
- /mnt/wsl/archive: the 1 TB partition, attached by wsl-mount.ps1. It was an old
  Pop!_OS install (jml/, kept by Jacob), so write only in meiolol-raw/ (the raw archive),
  meiolol-backups/ and meiolol-accounts/. Without the partition those directories are
  missing and the pulls stop
- /mnt/wsl/lab: partition 6 (label meiolol-lab, 673 GB ext4), mounted by wsl-mount.ps1
  with `mount -L meiolol-lab` inside WSL as root (`wsl --mount --partition 6` fails: WSL
  already has the disk attached for the archive). ~/ml/snaps and ~/ml/runs are symlinks
  into it; lab-run.sh checks `mountpoint -q /mnt/wsl/lab`
- The WSL disk (ext4 vhdx) is on C:, shared with Windows and games (alert at 85%). Open:
  compact it once (warn the sessions using the gpu-box first; this stops WSL): `wsl
  --shutdown`, then `wsl --manage <distro from wsl -l -v> --set-sparse true` (or
  diskpart `select vdisk file=<ext4.vhdx>`, `compact vdisk`). Expect ~120 GB back

## Mac build cache

The repo's .zig-cache (shared by the working tree and the ci and box build trees) grows
~17 GB a day. on-push.sh empties it after a deploy once past 40 GB and
no zig runs (deploy/zig-cache-prune.sh); the next builds start cold.

## WSL memory

WSL2 takes half the PC's memory by default (15 GB). C:\Users\jacob\.wslconfig sets
`memory=24GB` (8 GB left for Windows and League; Windows alone used ~11.6 GB when WSL
filled it, so it pages: 20 GB if games stutter) and `autoMemoryReclaim=gradual` (idle
Linux cache goes back to Windows). Takes effect after `wsl --shutdown` and a restart.

29 Oct 22:30: five team lanes' dev servers on data/snap, their watch builds and
tests filled RAM and the 6 GB swap; the kernel's OOM kill took 4 min of thrashing and
WSL hung until `wsl --shutdown`. Since then:
- earlyoom (deploy/wsl/earlyoom, installed by deploy/gpu-box.sh) kills before that: TERM
  under 10% available, KILL under 5%, swap ignored; dev servers, tests, compiles and
  browsers first, never Claude sessions or shells. What it killed: `journalctl -u
  earlyoom`
- A dev server on data/snap holds 3+ GB (plus ~8 GB of page cache while it loads, for
  minutes): deploy/dev.sh starts at most 2 on the machine (MEIOLOL_DEV_MAX)

## Disk resets

The lab disk (Crucial P3 2 TB, CT2000P3PSSD8, firmware P9CR40A: QLC, no DRAM; Windows
disk 2, RaidPort2) holds /mnt/wsl/archive and /mnt/wsl/lab, so snapshots, runs, the
backup mirror and the raw archive all write to it. Under heavy random writes it stops
answering and Windows resets it (System log, stornvme 129 "Reset to device,
\Device\RaidPort2"); most resets pass, some hang the PC, which then reboots with no
bugcheck (Kernel-Power 41, EventLog 6008), often mid snapshot build. Not memory, heat,
wear, the PCIe link or TRIM (all checked).

Why: random writes are its weak spot (128 KB at 32 deep: 20-50 MB/s, single ops up to
4.7 s). With Linux's default queue (1584 commands of 1.25 MB), ~2 GB queued at that rate
puts the last command 40-100 s back, past Windows' timeout. SQLite loads and index
builds are such writes. The limits (deploy/wsl, installed by deploy/gpu-box.sh install
as root):
- at most 32 commands of 512 KB in flight to the disk
- writeback at 128 MB, writers blocked past 512 MB unwritten
- Windows: PCIe Link State Power Management off on AC (`powercfg /setacvalueindex
  SCHEME_CURRENT SUB_PCIEXPRESS ASPM 1` to undo)

Still worth doing at the PC: Crucial Storage Executive for newer firmware. Check for
resets: System log, stornvme 129, Kernel-Power 41.

## Threads in our code

src/par.zig: `par.forEach(io, n, ctx, body)` runs body once per index on the Io thread
pool (one worker per CPU). Each index writes its own slot; reduce in index order after,
so results match a serial run bit for bit (never accumulate shared floats in body).
`meiolol eval` uses it for fold models, the prior grid, joint L2 fits, out-of-fold
terms, lane gold folds and the pick metric. 26.6k games: 38 s serial, 13 s on the M5,
7 s on the gpu-box; output byte-identical. Still serial: experience.load (SQLite page
reads) and the scan.

## Open

- Reboots: the WSL tasks run logged out (S4U); a first boot without a login is still to
  be seen working
- Checkpoints inside a model once one runs ~1 h (runs take minutes so far)
- Not in the pack yet: eval's experience.load and scan, timeline frames
- Speed only when a real workload needs it, measured first. Dense Newton/Cholesky
  (logreg.zig) is d^3: fine at d ~850 (champion x role), not for pair or embedding
  features; then L-BFGS/CG on CPU or a Zig Cholesky kernel on the GPU. Not planned: Mac
  GPU (Metal) or cloud GPUs, unless the PC is often unavailable or a model outgrows
  10 GB of VRAM

## GPU path in meiolol-lab

- No CUDA toolkit: src/gpu/cuda.zig dlopens libcuda.so.1 (WSL ships it as
  /usr/lib/wsl/lib/libcuda.so.1) and declares the driver API calls it needs; device code
  in src/gpu/kernels.zig compiles to PTX for sm_86 (`zig build lab` does it, embedded in
  the binary); the driver JIT-compiles it at load. Smoke: `meiolol-lab gpu-smoke`
- Kernels take pointers and scalars only (no by-value structs); a layout struct shared
  with the host lives in device memory (src/gpu/fm_layout.zig, extern). Float atomics
  (`@atomicRmw(f32, .Add)`) compile to native red.global.add.f32
- fm kernels (fe3520e): fm_grad (one thread per row, gradients into a dense buffer with
  atomics) and fm_adam (one thread per parameter). Host: src/lab/bench.zig uploads rows
  once as fm_layout.Example (72 bytes); the host shuffles each epoch so CPU and GPU see
  identical batches; memset + fm_grad + fm_adam per batch. `bench --profile 1` times
  each kernel (fm_grad: 26-31% of a step additive, 39-73% lane, 44-89% pairwise).
  Pairwise sums the row's own embedding gradient over its five enemies before one
  atomic per k (~28% off fm_grad at dim 128). A per-block reduction was not tried: only
  bench fits fm on the GPU (no lab job does; CPU ties, below)
- Draft net kernels (3829314): a tiled GEMM (64x64 tiles in shared memory, 4x4 outputs
  per thread, FMA; strides give every transpose) and dn_* elementwise kernels; host
  src/lab/draftnet.zig. Dropout masks are a hash of (seed, step, layer, row, unit), so
  CPU and GPU train the same function
- `@exp` has no nvptx libcall: kernels.zig's exp uses ex2.approx

## GPU vs CPU

Jacob: "test it, don't just assume". Measured on the gpu-box with `meiolol-lab bench
SNAP` (fm models, gold14) and `meiolol-lab draftbench SNAP` (meiolol-88's planned deep
draft model: champion-role + role embeddings, 10 x 32 into an MLP 320-512-256-1, ReLU,
dropout 0.1, antisymmetric, AdamW, batch 1024 games) on snap-20261012T2055Z. Same seed,
shuffles and init on every device. Scale = train rows replicated (1x: 1.18M fm rows,
175k draft games); the models overfit replicated data, so only the times mean anything
at 4x+.

Devices: 1 core and 20 threads of the i5-13600KF, RTX 3080. CPU rows are the AVX2 +
flush-to-zero build (see the two fixes below); GPU rows from runs bench1/bench2. No
other job on the box during a timing (each held the cpu lock); League not running.

fm models, seconds per epoch (a fit is ~10 epochs):

| model | 1x: 1 core, 20 thr, 3080 | 4x | 16x | 3080 vs 20 threads at 16x |
| --- | --- | --- | --- | --- |
| additive | 0.064, 0.053, 0.021 | 0.32, 0.21, 0.054 | 1.53, 0.95, 0.28 | 3.4x |
| lane dim 8 | 0.13, 0.058, 0.039 | 0.67, 0.24, 0.097 | 3.07, 1.07, 0.32 | 3.4x |
| lane dim 32 | 0.18, 0.067, 0.072 | 0.88, 0.28, 0.15 | 3.96, 1.21, 0.38 | 3.2x |
| lane dim 128 | 0.44, 0.11, 0.087 | 1.89, 0.47, 0.25 | 8.14, 2.00, 0.77 | 2.6x |
| pairwise dim 8 | 0.17, 0.065, 0.013 | 0.79, 0.26, 0.13 | 3.68, 1.14, 0.35 | 3.2x |
| pairwise dim 32 | 0.32, 0.080, 0.039 | 1.42, 0.34, 0.22 | 6.14, 1.45, 0.70 | 2.1x |
| pairwise dim 128 | 1.09, 0.18, 0.22 | 4.50, 0.72, 0.58 | 18.7, 3.00, 1.98 | 1.5x |

fm sweep of 20 seeds (3 epochs each), seconds per fit: CPU runs one single-threaded fit
per thread at once, the GPU one fit after another. GPU vs CPU: 1x 0.8-1.2x, 4x 0.9-1.5x,
16x 0.9-1.2x (pairwise dim 128 at 16x: CPU 5.4, GPU 5.8). A tie at every size.

Draft net, seconds per epoch:

| scale (games) | 1 core | 20 threads | 3080 | 3080 vs 20 threads |
| --- | --- | --- | --- | --- |
| 1x (175k) | 11.9 | 2.02 | 0.52 | 3.9x |
| 4x (698k) | 48.7 | 8.07 | 1.06 | 7.6x |
| 16x (2.8M) | - | 32.8 | 3.08 | 10.7x |
| 64x (11.2M) | - | ~131 (4 x 16x) | 12.0 | ~11x |

Draft net sweep of 20 seeds, seconds per fit-epoch: 1x CPU 2.14 (baseline build) vs GPU
0.21; 4x CPU 6.56 vs GPU 0.76 (8.6x); GPU 3.0 at 16x, 12.0 at 64x. In practice: 40
trials x 20 epochs at 16x is ~40 min on the 3080 and ~6 h on all 20 threads; one
20-epoch fit at 64x (LoLDraftAI's scale) is 4 min on the 3080, ~45 min on 20 threads.

Agreement: fm test predictions within 0.03 gold of one core's (test MSE equal to 6-7
digits). Draft net: 4 steps 6e-8, 40 steps 1e-3 in win chance; a full epoch 1 point (4x:
up to 16 as the overfitting runs drift), the same log loss. Float sum order compounding
in a non-convex fit, not a bug.

Crossover and what moves:
- Draft net (and any MLP or embedding net): GPU at every size measured, 4x faster than
  all 20 threads at today's 175k games, ~11x from 2.8M games on, ~9x for sweeps. Move it
  to the 3080 (lab-run --res gpu)
- fm early-outcome models (and 88's FM "full", the same work per game as pairwise dim
  8): small and memory-bound. A single fit is 1.5-3.4x faster on the GPU from 4x rows,
  but a sweep with one fit per CPU thread ties the GPU at every size. Stay on CPU, or
  run a GPU sweep beside a CPU one to double throughput
- Our kernels are simple: the GEMM reaches ~1.2 TFLOP/s of the 3080's ~30 peak; the
  CPU code ~52 GFLOP/s on one core and ~300 on 20 threads (a tuned BLAS might give 2x).
  Both have headroom; tuning would favour the GPU more
- Mac M5 (ReleaseFast): draft net 17.9 s per epoch on one core, 8.2 on 10 cores (4x
  slower than the gpu-box's 20 threads); no GPU path there

Two x86 fixes found on the way:
- gpu-box builds target x86_64_v3 (build.zig's gpu_box query): AVX2 and FMA make the
  draft net 1.4x faster on one core than baseline x86-64 (17.1 to 11.9 s)
- Denormals: Adam's decaying moments for rarely seen parameters sit in denormal floats,
  which SSE runs ~100x slower. fm fits at 16x were 3.5-4.4x slower than they should be
  (lane dim 32 on one core: 17.5 vs 4.0 s per epoch), with identical results. meiolol-lab
  flushes them to zero at startup on x86 (252066d). The meiolol binary does not yet.
