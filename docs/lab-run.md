# Lab runs: deploy/lab-run.sh, placement, sweeps

How model work is started, queued and placed on the gpu-box and the Mac. The hosts,
their limits and benchmarks: docs/compute.md. Traps: docs/lab-constraints.md.

## Runs

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
- Binary store: KEY hashes every build input (files under src, build.zig, build.zig.zon,
  build args and the files of a -D arg naming an absolute path; gpu-box builds refuse
  those). Built once per KEY and never replaced, so a second start of the same inputs is
  instant and two sessions starting the same commit share one build. gpu-box binaries
  are built on the gpu-box (lab builds load the Mac to 20-38): the inputs are copied to
  a stage on the Mac and keyed there (an edit landing mid-build can't produce a binary
  under the wrong key), rsynced to the fixed mirror ~/ml/lab-build/tree.SLOT (its
  zig-pkg stays, zig cache ~/ml/lab-build/cache), built at nice 0 (ahead of runs) into
  ~/ml/lab-store/KEY and copied into the run dir there. Pinned zig 0.17.0 in the
  gpu-box's ~/.local/bin. A key only in the Mac's store is copied across instead of
  rebuilt. Mac builds (LAB_ALLOW_MAC=1) keep zig-out/lab-run/KEY and the mirror
  zig-out/lab-run/tree, zig-pkg linked to the checkout's (a fresh tree per build would
  unpack ~560 MB each time). Locks on this Mac: gpu-box 2 build slots (one at a time
  held starts up for many minutes; a build there takes 2-3 min beside a full run queue)
  plus a lock per key, so one key is built once; Mac one. Copying a Mac key takes no
  lock. Every start prints `binary KEY`: --bin KEY starts that binary whatever the tree
  holds now (lab-sweep's jobs after the first), --no-build the current inputs' binary if
  built, never a build. Newest 40 keys kept in each store, plus any used in the last 3
  days
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
  safe (uncapped, --procs 6 on a 5-core slot runs ~30 threads there, 3x slower)
- Cores: ~/ml/locks/reserve = r keeps the top r cores for gpu-slot jobs and --res none
  runs (taskset, OMP_NUM_THREADS r/N), so their host threads don't float over the cpu
  slots' cores; cpu slots split the other c - r. Tuned from the usage files (gpu jobs use
  1-1.5 cores and 20-35% of the card; most cpu runs keep under 1.5 cores busy): r 2,
  cpu.slots 9 (2 cores: one physical P or E core each), gpu.slots 3. The files are read
  when a job takes its slot, so tuning needs no code change; read them for the current
  values
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
  share can't fit; `slot` reads "gpu.A of S (share A B)" State jobs peak at 9.5-15.8 GB
  of the gpu-box's 23. listing() gives `mem KB` (MemAvailable) and `peak DIR GB` lines
  for lab-place
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
  ~/ml/runs/.bin/SHA256, one copy per build; one no run links to goes at the next start
  an hour on), job.sh,
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

`meiolol lab-place` (src/labtools/place.zig, std only) reads lab-run.sh's listing of
both hosts. lab-run.sh and lab-sweep.sh run a `meiolol` built from committed HEAD
(deploy/lib.sh lab_tools, zig-out/lab-tools), rebuilt (~30 s) only when src/labtools,
src/cmd/lab.zig or src/main.zig change, so an edit is live once committed.

Jacob: model runs on the gpu-box only, never the Mac (they slow it down).
Auto places on the gpu-box only (LAB_AUTO_MAC=1 lets it consider the Mac again); don't
`start mac` for model work. What follows about the Mac applies once that's lifted.

Without HOST (or HOST auto) a run goes where it should finish first: for each feasible
(host, resource), predicted wait for the lock + predicted run time, printed on one line
before the build (`--dry-run` stops there). A named HOST without --res is cpu;
--res auto picks the resource on that host. Every start writes the prediction to
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
  BETA is fitted on history, log time on log sharing within each command (~0.69; 0.7
  assumed with under 10 runs). Sublinear: the card is 20-35% busy, the
  shared cores are the limit. cpu slots are pinned to their own cores: not scaled
- Past the same args, history scales by flags whose work is linear (`--boot N`, the
  `--seeds` count, a --serial sweep job's trials; not `&` packs, which share the slot's
  cores): time x new/old. python runs are keyed by script once the listing
  carries it (BIN python/SCRIPT); until then all scripts on a snapshot share a key
- gpu-box cpu runs from before slots (no slot) had all 20 cores: their times count x the
  median slot / whole-machine ratio over commands run both ways (~3.7; 4 assumed without
  any). --res none and gpu runs aren't rescaled
- A host with none borrows the other host's, times their speed ratio: median over
  commands on the same snapshot run on both (5 s or more); with none, the Mac is assumed
  2x slower (eval 13 vs 7 s). No history anywhere: gpu-box cpu, and it says so
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
  or gpu slot. Free starts at MemAvailable less the listing's memheld (young runs' need
  not yet grown into, 7376f22). It takes its need and gives it back at its end; running
  runs give back their peak. A live run's time is the longer of its start's prediction
  and today's history. Queued runs of the other resource are not simulated. The why says
  how much of the wait is memory
- Feasible: the GPU only for CUDA commands (gpu-smoke; bench and draftbench when
  --devices has gpu; with CPU devices too they take the cpu lock, as their timings need
  it); the Mac never for CUDA; a host only if the args' snapshot paths (any `~/...snap-X`
  or absolute path) exist there; an unreachable host drops out. The Mac keeps snapshots
  in ~/personal/meiolol/data with ~/ml/snaps/<snap> symlinks to them (snapshot.sh push
  makes them; by hand for older snapshots), so `~/ml/snaps/X` works on both hosts
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
  netcheck --net big, one seed, one block: +250 MiB of the 3080's
  10 GB for ~1 s of a 2 s trial (fit 0.6 s; loading and the candidate are CPU), so 4
  at once fit easily; check utilisation in the first packed sweep
- --res cpu for nets on CPU threads (netcheck small, resid, playernet). --serial runs a
  job's K trials one after another, so a long CPU sweep holds few cpu slots; packed
  trials after the first get job.sh's `$pin`, so they stay on their slot's cores.
  `--commit SHA` builds that commit once (as --head does HEAD); the rest reuse its key
- `--python SCRIPT [--with PATH]...` sweeps a python net (lab-run's --python): one trial
  a job, no build; SCRIPT is copied at each start, so leave it alone until all are
  queued (or point SCRIPT and --with at a frozen copy elsewhere: the run hash is the
  *.py contents)
- `--gpu-share N` passes to lab-run: each job holds N gpu slots and 0.95 N/slots of the
  card (st1: statenet needed more than one slot's 3.16 GiB)
- `--live N`: at most N of the sweep's jobs queued or running at once; start waits (one
  status poll a minute) before queuing the next, so run it in the background. For jobs
  the slot count doesn't cap well (state nets: 9.5-15.8 GB RAM, 2 of 3 gpu slots)
- netcheck's `ens` rows (the seeds' averaged predictions) get their own column
- A SPACE line `ref --flag V ...` (every flag) adds trial `ref`, run first with the same
  seeds: the table shows it on top as the bar, unnumbered and never the pick
- Sweep jobs are lab-run runs, so their GPU times feed placement's history
- Stopping rule (`--stop-after K`, default 8; `--no-stop` off): start leaves `watch SWEEP
  K` running (log watch.log): each minute, lab-sweep verdict on the trials of jobs that
  exited 0; once K are scored, if every one's pooled fold gain is below -2 se the sweep
  stops (queued and running jobs; reason in `stopped`), else the rest run. On big1,
  big1b, big1c (8 + 32 + 19 trials, all losing) it would have stopped each at 8

## Lab agent limits (candidate code)

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
