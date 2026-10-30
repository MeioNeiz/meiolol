# meiolol

League of Legends champ select pick recommender for normal ranked players, today's
patch, EUW first. Everything shipped is Zig (0.17, pinned in build.zig;
docs/zig-0.17.md). Python only in the lab, on the gpu-box: experiments and cross-checks
that Zig models work (e.g. LightGBM, PyTorch); winners get rebuilt in Zig.

**Current goal: get a Riot production key** (more rate limit). Plan and next steps:
docs/plan.md "Now". Read it first.

## Git and deploys

- Work on main only (one developer); other sessions share the checkout. Commit with
  `deploy/commit.sh -m subject [-m body] -- <paths>`: by path, so others' dirty files
  stay out; adds new files and the page hashes. A new file goes in the same commit as
  its first use
- Every push to main deploys (log .git/meiolol-deploy.log). Push the tested sha with
  `deploy/push.sh <sha>` (plain push can send a commit another session made meanwhile);
  pre-push runs `zig build ci` on it (none for docs only), once for a group
- Push mode, for all sessions (`deploy/push.sh --status`; docs/dev-flow.md): fast
  pushes now; bulk queues and returns, a timer pushes the batch: don't wait-deployed,
  check pages on the dev server
- Solid, tested change: commit and push without asking, then (fast mode) `deploy/box.sh
  wait-deployed`. Ask first only when unfinished, risky or hard to undo

## Build and test

- `zig build`; `zig build test` (`-Dtest-filter=NAME`; a test that logs a warning
  fails); format only your own files, `zig fmt <paths>` (`zig build fmt` rewrites the
  whole tree, other sessions' dirty files too); `zig build ci` = fmt check, tests,
  Windows and Linux builds, shellcheck, JS syntax. Lab and nn tests: `zig build test-lab`
  (not in ci; deploy/lab-run.sh runs them before a new lab build), run it after a lab
  change
- src/pipeline_test.zig: fixture games through stats, curves and the whole site; extend
  it when adding a pipeline step or page
- Local site: `deploy/dev.sh`, one server for all sessions at localhost:8080, rebuilt
  on each edit (data/snap; `--exports` refreshes the box's curves and builds when it
  warns the curves are an old version). Page checks and screenshots: `--small`
  (docs/dev-flow.md "Seeing pages")
- Zig 0.16/0.17 std changed a lot (std.Io everywhere, renames): look it up, don't recall
  it. `deploy/zigstd.sh PATTERN [PATH under std]` greps the std source; the exact
  signature at an existing call site: LSP hover (ZLS; ToolSearch "select:LSP")

## Hosts

- Two executables: `meiolol` (backend: crawl, stats, site, status, champions; runs on
  the box, C01: a VM Ethan lent) and `meiolol-app` (player tool: suggest, watch,
  session, get). `zig build lab`: `meiolol-lab`, modelling experiments on the gpu-box
  (CUDA via libcuda, kernels in src/gpu compiled to PTX)
- The box: `ssh essex-vm` (C01; sudo password: vault meiolol/essex-vm). Crawler 24/7:
  `deploy/box.sh start|stop|restart|status|logs|run`. Data lives there
  (~/ml/meiolol/data, on Megatron); backups mirrored to Megatron, the Mac and the
  gpu-box. Hosts, data disk (deploy/c01), limits: docs/hosting.md. The old Oracle box
  (`meiolol-cloud`) is stopped and kept as is for a benchmark: don't change it
- Box jobs over a minute: `deploy/box.sh job run NAME 'CMD'` (a user unit, outlives
  ssh), `job status|wait NAME`. Waiting for a push: `deploy/box.sh wait-deployed [REV]
  [--live]` (exits 0, 1 failed, 3 timeout). Hand-edited Daily or Learn
  files: `deploy/box.sh web rebuild` (a forced round keeps the old ones)
- Website: https://meio.lol (DNS on Cloudflare: docs/arch-site.md; mail to @meio.lol:
  deploy/mail.sh), static nginx and the Your games API on C01 behind Cloudflare
  Tunnel `meiolol-c01`. The box builds and uploads on new data: `deploy/box.sh web start
  [privacy@meio.lol]|stop|status`. Pieces installed by hand (named for jomify, which ran
  them until the move; it now runs only jomove: never touch it): `deploy/jomify.sh
  drift`, `install api|traffic|...`. The Mac can't reach meio.lol (Sophos filter
  re-signs TLS): check live pages from C01. Admin pages: `deploy/admin-get.sh
  PATH` (keeps the login off screen). Preview mode until prod key
- A scripted headed browser visiting meio.lol appends `meiolol-agent` to its user agent,
  so traffic counts it as a bot (deploy/traffic.sh)
- Heavy model work on the gpu-box (`ssh gpu-box`; 3080, 20 threads) or Mac CPU, never
  the box: deploy/lab-run.sh; League pauses gpu-box runs; warn sessions using it before
  restarting WSL. Parallel loops: src/par.zig. docs/compute.md
- Riot key: RIOT_API_KEY in .env (gitignored), copied to the box by deploy/box.sh.
  Never print it, nor the admin password (vault meiolol/local). Riot portal automation:
  `jodrive riot ...` (~/personal/jodrive)
- Bash runs zsh: quote globs (`grep --include='*.zig'`, else "no matches found") and
  never keep a command in a variable (`J="ssh -i k host"; $J` doesn't split): use the
  ssh aliases above

## Working style

- Batch reads: several files or line ranges in one Bash call (`sed -n 1,40p a; sed -n
  80,120p b`), independent calls in parallel in one turn; never one read per turn
- Waiting: run_in_background, then wait for the notification
- Builds and tests through `deploy/zb.sh test|test-ui|ci|<zig build args>`: shared
  build slots (`deploy/slots.sh status`), and a run that started after your request
  answers it; other zig builds `deploy/slots.sh 1 zig build ...`. UI work: `test-ui`
  while iterating, `test` before a commit
- Tests: `deploy/zb.sh test 2>&1 | tee $SCRATCH/t.log | tail -30`, then grep the log
- Hand over at 25-33% context (a hook reminds; fleet skill); a new topic starts fresh
- Team runs: shared state in the run's common.md; messages are "done: <path>" or
  "blocked: <why>, <path>", details in the file

## Docs (read the one you need, not all)

Docs say what is true now; how it got there goes in the commit message. Budgets and
guards: .claude/doc-rules.json, skill context-review.

- Layout, modules, storage, model file format: docs/architecture.md; derived stats,
  website, app: docs/arch-stats.md, arch-site.md, arch-app.md
- What we have learnt about the data (plain findings, read first): docs/learned.md. Add a
  line when a model or data check gives a final result
- Draft model quality on held-out games (`meiolol eval`): docs/model.md, the lab record
  (read its Start here, then one section). Measure any recommender change there first
- Data sources and what was ruled out (and why): docs/data.md. Read before adding one
- Front end, site and desktop (one UI, rebuilt from the ground up): docs/frontend.md;
  read before any UI work
- Production key requirements and policy limits on what the app may show:
  docs/production-key.md; sources and quotes in research/ (josearch store, see
  research/README.md)
- Backups, health alerts, disk headroom, GDPR erasure (`meiolol backup|restore|forget`):
  docs/data-safety.md
- Builds, tests, pushes and the two push modes on the Mac: docs/dev-flow.md
- Older next steps by area: docs/backlog.md. Finished team runs: docs/archive/
- Team runs (a coordinator and several sessions): briefs, notes and handovers in
  data/team/<date>-<name>/ (gitignored, survives reboots), not /tmp scratchpads
