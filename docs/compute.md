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
  it alone. Snapshots go in ~/ml/snaps/<stamp>/ (meiolol-2a: anonymised, salted PUUID
  hashes), runs in ~/ml/runs/

## Runs (deploy/lab-run.sh)

```
deploy/lab-run.sh start [HOST] NAME [--meiolol] [--head | --no-build]
    [--res cpu|gpu|none|auto] [--dry-run] -- ARGS...
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

### Placement (deploy/lab-place.pl)

Without HOST (or HOST auto) a run goes where it should finish first: for each feasible
(host, resource), predicted wait for the lock + predicted run time, printed on one line
before the build (`--dry-run` stops there). A named HOST without --res is cpu, as
before; --res auto picks the resource on that host. Every start writes the prediction to
the run dir (`predicted`: seconds, then why) and `status` shows it beside the actual
run time.

- Run time = ended - started - time paused for League (pauses.log), runs that exited 0.
  Estimate: median of the last 5 on that host with the same args and build, else the
  same command (exp: action, campaign, target) and candidate (-Dcand) on the same
  snapshot, else any candidate there, else that command on any snapshot, else the bare
  subcommand. A new campaign with no runs falls back to other campaigns' times
- A host with none borrows the other host's, times their speed ratio: median over
  commands on the same snapshot run on both (5 s or more). None yet: the Mac assumed 2x
  slower (eval 13 vs 7 s). No history anywhere: gpu-box cpu, as before, and it says so
- Wait = what the live runs on that lock have left: queued ones their prediction,
  running ones prediction minus time so far (overdue: a fifth of their time so far)
- Feasible: the GPU only for CUDA commands (gpu-smoke; bench and draftbench when
  --devices has gpu; with CPU devices too they take the cpu lock, as their timings need
  it); the Mac never for CUDA; a host only if the args' snapshot paths (any `~/...snap-X`
  or absolute path) exist there. The Mac keeps snapshots in ~/personal/meiolol/data, the
  gpu-box in ~/ml/snaps, so a snapshot path pins its host today; an unreachable host
  drops out
- League up (or unknown) on the gpu-box: + the median pause so far (30 min with none)
- Lab agents (lab-exp.sh) keep LAB_HOST: their ladder lives on the host

## Lab agent limits

A lab agent (docs/lab-agent.md) writes candidate code we build and run on the gpu-box as
Jacob. What holds it, outermost first:

- Its session (deploy/lab-agent.sh): reads the repo minus .env and data/, writes only its
  campaign dir, runs only deploy/lab-exp.sh (not final or preds); no user settings, so
  none of Jacob's own allow rules; dontAsk, so anything else is refused, not asked
- lab-exp.sh: every word it gets is checked (plain names, the target list, numbers) and
  meiolol-lab's args reach the host's shell as quoted words (lab-run.sh --literal), so
  `lab-exp.sh *` can't become a shell on the gpu-box. Builds use committed HEAD plus the
  candidate dir only
- The candidate check (deploy/lab-guard.pl) is a tripwire, not a sandbox. It refuses
  std's file, process, network, OS and global-Io namespaces, std aliases and
  @import("std") outside the one import line, @import("root"), extern, export, asm,
  @cImport and @ptrFromInt; Zig's module rules keep imports inside the candidate dir. It
  can't stop code that misuses pointers it was given (a many-pointer read past
  train.rows reaches the rest of the process's memory, test labels included) or that
  hides a syscall in a construct it doesn't know. It catches honest mistakes and casual
  shortcuts, not a determined adversary

### The real boundary (designed, not built)

Not built yet: it changes every scored run, needs a Linux kernel to test on (the gpu-box)
and src/lab is busy. Design:

- Fork per `score` (src/lab/harness.zig), after buildTrain, Baseline.fit and the query
  rows are ready, before `C.fit`. The child: overwrites `y` of every scored row with NaN
  in its copy of rows.Data (copy on write; the parent keeps the labels), drops its
  rights (below), fits, predicts every scored row into a MAP_SHARED buffer the parent
  mapped before the fork (n x outcome_count f32), writes effect tables as text after
  them, and exits. The parent waits, checks exit status and a length header, and scores
  as now. Fork, not a thread: Landlock binds a thread and those it creates later, and the
  Io pool's threads already exist; a forked child has one thread, so all it spawns
  inherits the limits
- Dropping rights in the child, in order: prctl(PR_SET_NO_NEW_PRIVS, 1); Landlock: ask
  the ABI with landlock_create_ruleset(NULL, 0, LANDLOCK_CREATE_RULESET_VERSION) (x86_64
  syscalls 444-446), handle every fs right that ABI knows (v1 the 13 base rights, v2
  REFER, v3 TRUNCATE, v5 IOCTL_DEV), TCP bind and connect from v4, and abstract unix
  sockets and signals scoping from v6, add no rules, landlock_restrict_self; then a
  seccomp filter (SECCOMP_SET_MODE_FILTER) allowing only memory (mmap, munmap, mremap,
  madvise, brk), threads (clone and clone3 with thread flags only, futex, set_robust_list,
  rseq, sched_yield, exit), time (clock_gettime, nanosleep), getrandom, write to stderr,
  rt_sigreturn and exit_group; anything else kills the process (SECCOMP_RET_KILL_PROCESS).
  Seccomp alone already blocks files, sockets and exec; Landlock adds the fs and TCP
  limits in case the filter is ever widened
- WSL: check `cat /sys/kernel/security/lsm` on the gpu-box; Microsoft's kernel may not
  list landlock. ABI < 1 (ENOSYS or EOPNOTSUPP): seccomp alone. Seccomp is in every WSL2
  kernel. On the Mac neither exists: the run says `sandbox none` in meta and RESULT, and
  lab-exp.sh refuses an agent's run there unless LAB_UNSANDBOXED=1
- Test: a candidate in src/lab/cand that tries openat, socket, execve and a read past
  train.rows' end; a harness test (Linux only) asserts the child is killed or the call
  fails, and that scores match an unsandboxed run bit for bit

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
  still to be seen. 2026-10-13: split into wsl-mount (elevated, from ProgramData) and an
  unelevated keepalive, since WSL could rewrite the elevated script (Rules above)
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

- Snapshot cadence (done, 2026-10-13): `deploy/snapshot.sh make` on the Mac (box
  VACUUM INTO, anonymise, checks, split, legendaries, pack, to the gpu-box; ~30 min),
  weekly via an hourly launchd tick (due Sundays from 04:00; pushes to the gpu-box wait
  until it's awake, then mastery-pre runs there); `prune KEEP` once LAB_SNAP
  moves. Still from the live DB: meiolol.db and timeline.db need the box anyway, so
  the archive would only save the raw step
- Packed rows (done, 2026-10-12): `meiolol-lab pack SNAP` writes rows.Data as
  fixed-width column files in SNAP/pack/ (docs/architecture.md "Packed rows"); rows.load
  reads them when they match the snapshot, else SQLite, so every lab command gets it.
  snap-20261012T2055Z (185k games, 1.85M rows): pack 79 MB, written in ~17-34 s; `rows`
  31-37 s from SQLite on the Mac, 15-17 s on the gpu-box, 0.14 s packed on both (RSS
  1.1-2.4 GB down to 150 MB). Still open: eval (experience.load, the scan) and
  timeline frames, which aren't in the pack
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
  atomics) and fm_adam (one thread per parameter). Host: src/lab/bench.zig uploads rows
  once as fm_layout.Example (72 bytes); the host shuffles each epoch so CPU and GPU see
  identical batches; memset + fm_grad + fm_adam per batch
- Draft net kernels (3829314): a tiled GEMM (64x64 tiles in shared memory, 4x4 outputs
  per thread, FMA; strides give every transpose) and dn_* elementwise kernels; host
  src/lab/draftnet.zig. Dropout masks are a hash of (seed, step, layer, row, unit), so
  CPU and GPU train the same function
- `@exp` has no nvptx libcall: kernels.zig's exp uses ex2.approx

## GPU vs CPU (meiolol-6f, 2026-10-13)

Jacob: "test it, don't just assume". `meiolol-lab bench SNAP` (fm models, gold14) and
`meiolol-lab draftbench SNAP` (meiolol-88's planned deep draft model: champion-role +
role embeddings, 10 x 32 into an MLP 320-512-256-1, ReLU, dropout 0.1, antisymmetric,
AdamW, batch 1024 games) on snap-20261012T2055Z, gpu-box. Same seed, shuffles and init
on every device. Scale = train rows replicated (1x: 1.18M fm rows, 175k draft games);
the models overfit replicated data, so only the times mean anything at 4x+.

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
- The gpu-box meiolol-lab was built for baseline x86-64 (no AVX2, no FMA). x86_64_v3
  makes the draft net 1.4x faster on one core (17.1 to 11.9 s). meiolol-11 is setting it
  in build.zig's gpu_box query
- Denormals: Adam's decaying moments for rarely seen parameters sit in denormal floats,
  which SSE runs ~100x slower. fm fits at 16x were 3.5-4.4x slower than they should be
  (lane dim 32 on one core: 17.5 vs 4.0 s per epoch), with identical results. meiolol-lab
  flushes them to zero at startup on x86 (252066d). The meiolol binary does not yet
