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
- Derived arrays that cost minutes go in ~/ml/snaps/.cache/<snap>/ (src/lab/snapcache.zig;
  hidden, outside the snapshot's hash): comps.loadExtra's comp_stats by row
  (`compstats`, 1.4 GB, keyed by the tsv stamps, row order and compstats.zig) and
  champcomp's ratings offsets per window (`offsets-BEFORE-HI`, keyed by the binary),
  which champgroups shares (fold 3's). Safe to delete: the next run rebuilds them

## Runs (deploy/lab-run.sh)

```
deploy/lab-run.sh start [HOST] NAME [--meiolol] [--head | --commit SHA | --bin KEY]
    [--no-build] [--res cpu|gpu|none|auto] [--dry-run] -- ARGS...
deploy/lab-run.sh wait RUN... [--timeout S]
deploy/lab-run.sh status [HOST] | logs HOST RUN [N] | stop HOST RUN | restart HOST RUN
deploy/lab-run.sh pull HOST RUN
deploy/lab-run.sh watch-install    # = deploy/gpu-box.sh install
deploy/gpu-box.sh drift | install  # watcher, archive pull, backup mirror, Windows side
```

- Builds from the working tree (experiments are often uncommitted), --head from
  committed HEAD, --commit SHA from that commit; a failed build never starts. Only the
  target host's binary: `zig build lab-gpu-box` (x86_64-linux-gnu, CUDA) or lab-native,
  or meiolol with --meiolol (musl, x86_64_v3 on the gpu-box)
- Binary store: KEY hashes every build input (files under src, build.zig,
  build.zig.zon, build args and the files of a -D arg naming an absolute path; gpu-box
  builds refuse those). Built once per KEY and never replaced, so a second start of the
  same inputs is instant and two sessions starting the same commit share one build.
  gpu-box binaries are built on the gpu-box (Mac load 20-38 from lab builds,
  2026-10-13): the inputs are copied to a stage on the Mac and keyed there (an edit
  landing mid-build can't produce a binary under the wrong key), rsynced to the fixed
  mirror ~/ml/lab-build/tree.SLOT (its zig-pkg stays, zig cache ~/ml/lab-build/cache),
  built at nice 0 (ahead of runs) into ~/ml/lab-store/KEY and copied into the run dir there. Pinned zig
  0.17.0 in the gpu-box's ~/.local/bin. A key built before then, only in the Mac's
  store, is copied across instead of rebuilt. Mac builds (LAB_ALLOW_MAC=1) keep
  zig-out/lab-run/KEY and the mirror zig-out/lab-run/tree, zig-pkg linked to the
  checkout's (a fresh temp tree per build unpacked ~560 MB again, the 5-13 min --head
  builds of 2026-10-13). Locks on this Mac: gpu-box 2 build slots (one at a time held
  starts up for many minutes; a build there takes 2-3 min beside a full run queue) plus a
  lock per key, so one key is built once; Mac one. Copying a Mac key takes no lock. Every start prints
  `binary KEY`: --bin KEY starts that binary whatever the tree holds now (lab-sweep's
  jobs after the first), --no-build the current inputs' binary if built, never a build.
  Newest 40 keys kept in each store, plus any used in the last 3 days
- Python (cross-checks of Zig models; nothing shipped): `start [gpu-box] NAME --python
  SCRIPT [--res cpu|gpu] -- ARGS`, never plain python on the box. No build; SCRIPT and
  the other *.py in its directory, plus py/labpy.py, py/pyproject.toml and py/uv.lock,
  go into the run dir, the cwd; ARGS as for any run (~ and ~/ml/snaps/SNAP expand
  there). One env per uv.lock hash, ~/ml/pyenv/HASH/venv (torch cu128, numpy, scipy,
  pandas, scikit-learn, lightgbm), made on the first start that needs it (uv sync
  --frozen); change deps in py/pyproject.toml and `uv lock` on the gpu-box. Slots, League
  pauses, meta (`bin python HASH` of the *.py, `pyenv HASH`) and status as for any run.
  OMP_NUM_THREADS is the slot's share of the cores; on a gpu slot labpy.py caps torch at
  LAB_GPU_FRACTION = 0.95/N of the card (N gpu slots). Process pools (ProcessPoolExecutor,
  multiprocessing Pool) are capped by labpy.py to the slot: workers <= its cores, each
  worker's BLAS/OpenMP/torch threads cores / workers (threadpoolctl), so any --procs is
  safe; uncapped, --procs 6 on a 5-core slot ran ~30 threads there, 3x slower
- Cores (2026-10-14, load 40-80 on 20 threads): ~/ml/locks/reserve = r keeps the top r
  cores for gpu-slot jobs and --res none runs (taskset, OMP_NUM_THREADS r/N), whose host
  threads floated over the cpu slots' cores; cpu slots split the other c - r. Set
  (2026-10-14, from usage files: half the cpu runs used ~1 of 5 cores, gpu runs 1-1.5
  cores and 20-35% of the card): r 4, cpu.slots 4 (4 cores each), gpu.slots 3. The files
  are read when a job takes its slot, so tuning needs no code change. 18 Oct (gpu jobs
  used 6.3 of 23.5 reserved core-hours; 85 of 177 cpu runs under 1.5 of their 4 cores;
  ~85 h queued 13-14 Oct): r 2, cpu.slots 9 (2 cores: one physical P or E core each)
- cpu width: without --share a cpu run holds enough slots for ~4 cores (2), or one
  when its most specific history key's recent runs kept under 1.5 cores busy (usage
  cpu_cores; champcomp, champgroups, netcheck small: 1.0). lab-place decides (listing
  `width cpu K` and `used DIR CORES` lines, place's 4th field); job.sh pins to all its
  slots' cores and sets OMP_NUM_THREADS to them. No prediction: ~4 cores
- Memory gate: the queue head also waits while MemAvailable is below its kind's peak
  (max usage peak_rss_gb over earlier runs of its meta bin, plus first arg for Zig
  bins; 4 GB if none). After 20 min it goes with half that free (peaks are upper
  bounds) or once no run holds a slot, never on time alone: an OOM kill takes a
  neighbour down. Waits are logged in the run's log and watcher.log. A run that took
  its slot in the last 15 min counts its need (run dir `memneed`) less its RSS now as
  taken, so a second head can't pass before the first has grown (st1 j03 OOM-killed)
- `--share N` (alias --gpu-share; gpu or cpu): the run holds N slots at once (all or
  none, as queue head); on gpu torch gets 0.95 N/slots of the card, for jobs one slot's
  share can't fit; `slot` reads "gpu.A of S (share A B)"
  State jobs peak at 6-8 GB of the gpu-box's 23. listing() gives `mem KB` (MemAvailable)
  and `peak DIR GB` lines for lab-place
- Slot queue: tickets in ~/ml/locks/RES.q, only the oldest live one tries the slots
  (first come, first served; polling let newcomers win); runs predicted <= 60 s sort
  ahead (fast lane); a dead waiter's ticket is dropped
- Usage (deploy/lab-usage.sh, as usage.sh): every 5 s the job's runnable threads and
  the card's busy % and the group's RSS; after it, `usage` in the run dir (cores,
  active_s with League pauses out, cpu_s, cpu_cores, runnable_per_core, gpu_pct, samples,
  peak_rss_gb) and a USAGE line in
  the log. runnable_per_core over 1.5 says oversubscribed; gpu_pct is the whole card
- Prediction gates (deploy/lab-gates.sh, run by job.sh after the program, before
  `exit`): every preds*.tsv, dev.tsv and test.tsv in the run dir (two levels down) must
  have no NaN or inf and no constant prediction column; `GATE ok|FAIL` lines in the log,
  FAILs in `gates`, shown by `wait`, with the program's own GATE FAIL lines from the log
  (src/lab/gates.zig: a fresh net's held-out loss more than 0.01 from the base rate's,
  or the offset's for resid; draftnet's fits, i.e. netcheck and winnet big). The exit
  code is the program's. Failed runs:
  ~/ml/runs/failures.tsv, `lab-run.sh failures [N]`
- `wait RUN...` blocks until each run has ended on whichever host has it, then prints
  its state and RESULT lines: exit 0 when all exited 0, 3 on --timeout, else 1. Use it
  instead of until-loops over status
- Run dir ~/ml/runs/<UTC stamp>-<name> on the host: the binary (gpu-box: a hardlink to
  ~/ml/runs/.bin/SHA256, one copy per build, a copy each was 14 GB, 18 Oct; one no run
  links to goes at the next start an hour on), job.sh,
  log, meta (host, binary hash, src KEY, harness (KEY without the candidate:
  src/lab/cand and -Dcand),
  snap PATH HASH per snapshot dir in the args (input files' names and sizes, equal on
  both hosts' copies), HEAD, dirty count, args, runkey), src.diff (src and build.zig vs
  HEAD), started, ended, exit, pauses.log
- runkey: hash of meta's bin, cpu, snap, args and pyenv lines and the --with files'
  contents, i.e. what decides the results (seeds are args; thread counts don't change
  them). A start prints `same as RUN (exit N), ...` for earlier runs with its key: look
  there before rerunning; it still starts (timings, flakiness)
- ARGS are joined and run by bash in the run dir on the host: ~ and globs expand there,
  relative outputs land in the run dir, `pull` copies it (minus the binary) to
  data/runs/RUN here
- Jobs run under nice 10 in their own process group (`stop` sends TERM to the group)
- Queue: a run waits for a slot of its resource on the host before `started`; status
  shows it "queued". A resource has N slots (locks ~/ml/locks/RES.0..N-1, N in
  ~/ml/locks/RES.slots, default 4), so N runs of it share the PC; the run dir's `slot`
  says which ("cpu.2 of 4"). A cpu slot pins its run to nproc/N cores (taskset: Zig's
  thread pool and par.zig size themselves from the affinity mask, and par.zig's loops
  give the same results whatever the count). cpu by default, --res gpu for GPU work
  (it shares the PC with cpu runs; the 3080's 10 GiB holds several of our nets), none
  to skip. lab-exp.sh counts only running time toward its budget, so queued runs aren't
  killed
- WSL restarts: lab-watch.sh, starting with WSL, runs again (twice at most) any run that
  was live when WSL went down; `restart` does it by hand. A run over ~1 h should keep
  checkpoints in its run dir and resume from them (none does yet: runs take minutes)

### Placement (meiolol lab-place)

`meiolol lab-place` (src/labtools/place.zig, std only; deploy/lab-place.pl until 19 Oct,
whose output it keeps byte for byte) reads lab-run.sh's listing of both hosts. lab-run.sh
and lab-sweep.sh run a `meiolol` built from committed HEAD (deploy/lib.sh lab_tools,
zig-out/lab-tools), rebuilt (~30 s) only when src/labtools, src/cmd/lab.zig or
src/main.zig change, so an edit is live once committed.

Jacob, 2026-10-13: model runs on the gpu-box only, never the Mac (they slow it down).
Auto places on the gpu-box only (LAB_AUTO_MAC=1 lets it consider the Mac again); don't
`start mac` for model work. What follows about the Mac applies once that's lifted.

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
- gpu slots share one card (and the reserved cores): a gpu run's time counts over
  sharing^BETA (sharing = the gpu runs holding slots on average while it ran, itself
  included), and a new one is predicted at that x min(slots, live gpu runs + 1)^BETA.
  BETA is fitted on history, log time on log sharing within each command: 0.69 over 34
  runs (14 Oct; 0.7 assumed with under 10). Sublinear: the card is 20-35% busy, the
  shared cores are the limit. cpu slots are pinned to their own cores: not scaled
- Past the same args, history scales by flags whose work is linear (`--boot N`, the
  `--seeds` count, a --serial sweep job's trials; not `&` packs, which share the slot's
  cores): time x new/old. python runs are keyed by script once the listing
  carries it (BIN python/SCRIPT); until then all scripts on a snapshot share a key
- gpu-box cpu runs from before slots (no slot) had all 20 cores: their times count x the
  median slot / whole-machine ratio over commands run both ways (3.7 over 17 commands,
  14 Oct; 4 assumed without any). --res none and gpu runs aren't rescaled
- A host with none borrows the other host's, times their speed ratio: median over
  commands on the same snapshot run on both (5 s or more). None yet: the Mac assumed 2x
  slower (eval 13 vs 7 s). No history anywhere: gpu-box cpu, as before, and it says so
- Wait = until one of the resource's N slots (~/ml/locks/RES.slots, default 4) is free
  for the new run: running runs hold theirs for prediction minus time so far (overdue: a
  fifth of their time so far), queued ones take the first slot to free up in lab-run's
  ticket order: fast ones (predicted <= 60 s) first, then the rest, each oldest first. A
  fast new run waits only for queued fast ones. Whole-machine history: see the ratio above
  A --share N run holds N slots and, as queue head, waits until N are free at once
  (listing field SHARE after LOGLINE; place's optional SHARE argument)
- Memory (lab-run's gate, 0723d43 and edd4d90; the listing's mem and peak lines): each
  run starts once a slot is free and MemAvailable covers its need (max peak of earlier
  runs with the same bin and first arg, python by script; 4 GB with none); 20 min after
  it first saw too little as queue head, half its need will do, or no run holding a cpu
  or gpu slot. Free starts at MemAvailable less the listing's memheld (young runs' need not
  yet grown into, 7376f22). It takes its need and gives it back at its end; running runs
  give back their peak. A live run's time is the longer of its start's prediction and
  today's history. Queued runs of the other resource are not simulated. The why says how much
  of the wait is memory
- Feasible: the GPU only for CUDA commands (gpu-smoke; bench and draftbench when
  --devices has gpu; with CPU devices too they take the cpu lock, as their timings need
  it); the Mac never for CUDA; a host only if the args' snapshot paths (any `~/...snap-X`
  or absolute path) exist there; an unreachable host drops out. The Mac keeps snapshots
  in ~/personal/meiolol/data with ~/ml/snaps/<snap> symlinks to them (made by hand
  2026-10-13; a new snapshot needs its link), so `~/ml/snaps/X` works on both hosts
- League up (or unknown) on the gpu-box: + the median past League session
  (watcher.log's up/down lines; 30 min before any) less the time it has been up, but at
  least that time again: a session already 3 h old costs 3 h, so runs go to the Mac
- netcheck is keyed by its --net too (big on the GPU, small and resid on CPU threads)
- Lab agents (lab-exp.sh) keep LAB_HOST: their ladder lives on the host

### Sweeps (deploy/lab-sweep.sh)

Random search over one model family (30-64 trials beat picking among families, research
C19) on the 3080, one lab-run job per trial on the gpu lock, so sweeps and other GPU work
take turns. `start SWEEP SPACE [--trials N] [--pack K] [--head] [--build-arg A]... --
CMD ARGS` samples the trials (SPACE: `--flag DIST ARGS` lines, `meiolol lab-sweep`),
builds once and queues the jobs; `status`, `table`, `stop`. State in data/sweeps/SWEEP.

- Contract (meiolol-f1's `netcheck`): the sweeper appends the sampled `--flag value`
  pairs and `--out tNN`; the command writes tNN/folds.tsv, one row per seed and block
  (folds 1-5 and dev): seed fold fit_games scored_games logloss ratings_logloss gain
  gain_se epochs seconds val_logloss auc
- `table` ranks by val_logloss (inner validation on fit games), never by the fold gain,
  which is the honest score: picking on it would select on the scored blocks. Columns:
  fold gain vs ratings (pooled by games, mean over seeds, paired 95%), folds better (of
  5, mean over seeds: the sign consistency the reliability rules ask for), seed sd,
  ensemble gain, dev gain, epochs, GPU seconds, config
- --pack K runs K trials at once in one job, for when one trial leaves the GPU idle.
  Measured 2026-10-13 (netcheck --net big, one seed, one block): +250 MiB of the 3080's
  10 GB for ~1 s of a 2 s trial (fit 0.6 s; loading and the candidate are CPU), so 4
  at once fit easily; check utilisation in the first packed sweep
- --res cpu for nets on CPU threads (netcheck small, resid, playernet). --serial runs a
  job's K trials one after another, so a long CPU sweep holds few cpu slots; packed
  trials after the first get job.sh's `$pin`, so they stay on their slot's cores.
  `--commit SHA` builds that commit once (as --head does HEAD); the rest reuse its key
- `--python SCRIPT [--with PATH]...` sweeps a python net (lab-run's --python): one trial a
  job, no build; SCRIPT is copied at each start, so leave it alone until all are queued
  (or point SCRIPT and --with at a frozen copy elsewhere: the run hash is the *.py contents)
- `--gpu-share N` passes to lab-run: each job holds N gpu slots and 0.95 N/slots of the
  card (st1: statenet needed more than one slot's 3.16 GiB)
- `--live N`: at most N of the sweep's jobs queued or running at once; start waits (one
  status poll a minute) before queuing the next, so run it in the background. For jobs
  the slot count doesn't cap well (st1, 14 Oct: state nets take 6-8 GB, 2 of 3 gpu slots)
- netcheck's `ens` rows (the seeds' averaged predictions) get their own column
- A SPACE line `ref --flag V ...` (every flag) adds trial `ref`, run first with the same
  seeds: the table shows it on top as the bar, unnumbered and never the pick
- Sweep jobs are lab-run runs, so their GPU times feed placement's history
- Stopping rule (`--stop-after K`, default 8; `--no-stop` off): start leaves `watch SWEEP
  K` running (log watch.log): each minute, lab-sweep verdict on the trials of jobs that
  exited 0; once K are scored, if every one's pooled fold gain is below -2 se the sweep
  stops (queued and running jobs; reason in `stopped`), else the rest run. On big1,
  big1b, big1c (8 + 32 + 19 trials, all losing) it would have stopped each at 8

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

## gpu-box storage (Jacob's steps, chosen 2026-10-18)

C: was 89% full (alert at 85%): the WSL disk on C: is 159 GB, of it ~/ml/snaps and
~/ml/runs. Snapshots 2351Z, 1954Z and 2137Z were deleted on 18 Oct (~36 GB inside WSL;
C: gets it back only at step 4). Lab data moves to a new ext4 partition in the ~673 GB
unallocated on the 2 TB P3, not the 1 TB Pop!_OS one (kept untouched).

1. Partition (done 18 Oct): sde6, 673 GB ext4, label meiolol-lab, made with sgdisk from
   sector 2495612928 (after sde5)
2. Mount (done 18 Oct): `wsl --mount --partition 6` fails (ERROR_FILE_NOT_FOUND: the P3
   is already attached for the archive, and WSL sees all its partitions), so
   wsl-mount.ps1 runs `mount -L meiolol-lab /mnt/wsl/lab` inside WSL as root when not
   mounted (deploy/windows/install-watchdog.ps1). The fs root is owned by jmu
3. Move (done 18 Oct): rsync -aH, checksum check, then ~/ml/snaps and ~/ml/runs became
   symlinks to /mnt/wsl/lab/snaps and runs (84 GB, 16637 files); old copies deleted.
   Uncached read of a 3.5 GB snapshot db 2.6 GB/s before, 2.4 after. Paths unchanged.
   lab-run.sh gets a `mountpoint -q /mnt/wsl/lab` check (meiolol-b5's team)
4. Compact the WSL disk (warn the sessions using the gpu-box first; this stops WSL):
   `wsl --shutdown`, then `wsl --manage <distro from wsl -l -v> --set-sparse true` (or diskpart `select
   vdisk file=<ext4.vhdx>`, `compact vdisk`). Expect ~120 GB back, C: to ~77%

## Mac build cache

The repo's .zig-cache (shared by the working tree and the ci and box build trees) grows
~17 GB a day (126 GB on 18 Oct). on-push.sh empties it after a deploy once past 40 GB and
no zig runs (deploy/zig-cache-prune.sh); the next builds start cold.

## WSL memory

WSL2 takes half the PC's memory by default (15 GB). C:\Users\jacob\.wslconfig sets
`memory=24GB` (8 GB left for Windows and League) and `autoMemoryReclaim=gradual` (idle
Linux cache goes back to Windows). Before: .wslconfig.bak-2026-10-12. Takes effect after
`wsl --shutdown` and a restart.

## Disk resets

The lab disk (Crucial P3 2 TB, CT2000P3PSSD8, firmware P9CR40A: QLC, no DRAM; Windows
disk 2, RaidPort2) holds /mnt/wsl/archive and /mnt/wsl/lab, so snapshots, runs, the
backup mirror and the raw archive all write to it. Under heavy writes it stops answering
and Windows resets it (System log, stornvme 129 "Reset to device, \Device\RaidPort2"):
~45 resets 17-23 Oct, all during snapshot builds or archive and lab work. Most pass; some
hang the PC, which then reboots with no bugcheck (Kernel-Power 41, EventLog 6008):
snapshot builds at 07:39 and 19:50 on 23 Oct (4 min into the restore), 20 Oct 23:15, and
19 Oct 21:21 (bugcheck 0x139 after resets). Not memory: WSL is capped at 24 GB, the
pagefile peaked at 67 MB, no resource exhaustion events.

Limits since 23 Oct (deploy/wsl, installed by deploy/gpu-box.sh install as root):
- at most 32 commands of 512 KB in flight to the disk (were 1584 of 1.25 MB), so none
  waits long behind the queue
- writeback at 128 MB, writers blocked past 512 MB unwritten (were 10% and 20% of 24 GB,
  ~4.6 GB flushed in bursts)
- Windows: PCIe Link State Power Management off on AC (was Moderate; `powercfg
  /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 1` to undo)

Tested 23 Oct (the limits on, no resets during the tests):
- Not heat or wear: NVMe health log 0 minutes above warning temperature, never
  throttled, 0 media errors, spare 100%, 4% used, 24 TB written. Not the connection:
  PCIe 4.0 x4 as rated, no WHEA errors in 30 days
- Not TRIM, though none reaches it (`wsl --mount` passes no discard: discard_max_bytes
  0, fstrim never ran): 32 GB of sequential direct writes held 2.3 GB/s, so it has fast
  space to spare, with two ~15 s dips to 80 MB/s
- Random writes are the weak spot: 16 KB at 8 deep, 110-700 MB/s and every op under 25
  ms; 128 KB at 32 deep (the new limit full), 20-50 MB/s for ~40 s with single ops up
  to 4.7 s. At the old 1584 deep of 1.25 MB, ~2 GB queued at 20-50 MB/s puts the last
  command 40-100 s back, past Windows' timeout: the reset. SQLite loads and index
  builds are such writes. So the queue limit is the fix; first resets 18 Oct, when the
  lab partition took snapshots and runs onto this disk
- The drive's error log count (4,267) has no entries to read

Still worth doing at the PC: Crucial Storage Executive for newer firmware. Check resets
since: System log, stornvme 129, Kernel-Power 41.

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
gpu-box also holds the raw archive the box can no longer keep (backlog.md "Retention").
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

- Snapshot cadence (done, 2026-10-13; built on the gpu-box since 18 Oct): `deploy/
  snapshot.sh make` on the Mac, daily via an hourly launchd tick (due from 07:00 once
  the newest predates the 04:00 UTC backup, so a snapshot holds games to that morning;
  weekly until 23 Oct; skipped while the gpu-box is asleep or League is open), runs
  deploy/snapshot-gpu.sh there: restore from the backup mirror plus what backups leave
  out from the box (backup-serve.sh snapshot-extra: 4.3 GB sent, ~5 GB box temp, 34
  min), checks, anonymise, split,
  legendaries, pack, mastery-pre, then rsync to the Mac over the LAN. 18 Oct run
  (snap-20261018T1007Z): 78 min end to end, 70 on the gpu-box. Before: box VACUUM INTO
  ~23 GB streamed to the Mac, ~21 GB rsynced on to the gpu-box. Each fetch prunes
  older snapshots on both hosts, but docs/golden.tsv's and any a run that hasn't ended
  names; LAB_SNAP defaults to the newest
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

- Measure first: eval and 2a's models on the full snapshot on the gpu-box
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
  identical batches; memset + fm_grad + fm_adam per batch. `bench --profile 1` (ef4f611)
  times each kernel: fm_grad was 26-31% of a step (additive), 39-73% (lane), 44-89%
  (pairwise, dim 8-128) on 1320Z, 18 Oct. Pairwise now sums the row's own embedding
  gradient over its five enemies before one atomic per k (9d3bd5d): fm_grad 744 -> 537
  us a step at dim 128 (fit 1.89 -> 1.48 s 1x, 7.95 -> 5.98 s 4x), 213 -> 165 at dim 32,
  test MSE equal to 8 digits; lane and additive unchanged. A per-block reduction was not
  tried: only bench fits fm on the GPU (no lab job does; CPU ties, above)
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
