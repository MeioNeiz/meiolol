# meiolol

League of Legends champ select pick recommender for normal ranked players, today's
patch, EUW first. Everything shipped is Zig (0.17, pinned in build.zig;
docs/zig-0.17.md). Python only in the lab, on the gpu-box: experiments and cross-checks
that Zig models work (e.g. LightGBM, PyTorch); winners get rebuilt in Zig.

**Current goal: get a Riot production key** (more rate limit). Plan and next steps:
docs/plan.md "Now". Read it first.

## Git and deploys

- Work on main only: no branches or worktrees (one developer). Other sessions share the
  checkout, so commit by explicit path (`git commit -m ... -- <paths>`) only: never a
  plain `git commit` after `git add`, and never through a temporary index
  (`GIT_INDEX_FILE`); both can commit a stale copy of another session's file
- A new file goes in the same commit as its first use, scripts too (a deploy failed
  twice on 17 Oct: box.sh copied a script the commit lacked). Git only takes a path it
  knows: `deploy/commit.sh -m msg -- <paths>` adds new ones first, then commits by path
- Every push to main deploys (deploy/on-push.sh, log .git/meiolol-deploy.log; docs and
  research-only pushes skip the build). Push the tested sha, `git push origin
  <sha>:main`: over HTTPS git re-reads main after the pre-push ci, so a commit another
  session made meanwhile goes out untested
- Solid, tested change (a fix checked working, tests pass): commit and push it without
  asking, then `deploy/box.sh wait-deployed`. Ask first only when unfinished, risky or
  hard to undo
- Hooks in deploy/hooks (`git config core.hooksPath deploy/hooks`): pre-commit fmt,
  pre-push `zig build ci` on a clean checkout of the pushed commit

## Build and test

- `zig build`; `zig build test` (`-Dtest-filter=NAME`; a test that logs a warning
  fails); format only your own files, `zig fmt <paths>` (`zig build fmt` rewrites the
  whole tree, other sessions' dirty files too); `zig build ci` = fmt check, tests,
  Windows and Linux builds, shellcheck, JS syntax. Lab and nn tests: `zig build test-lab`
  (not in ci; deploy/lab-run.sh runs them before a new lab build), run it after a lab
  change
- src/pipeline_test.zig: fixture games through stats, curves and the whole site; extend
  it when adding a pipeline step or page. Its page hashes (src/testdata/site-files.txt)
  are rewritten and committed by deploy/commit.sh for any src/ commit; its diff shows
  which pages a change moved
- Local site: `deploy/dev.sh` (data/snap; `--exports` refreshes the box's curves and
  builds when it warns the curves are an old version)
- Zig 0.16/0.17 std changed a lot (std.Io everywhere, renames): LSP hover/goToDefinition
  (ZLS; ToolSearch "select:LSP") first; grep the std source (`$(zig env | grep
  lib_dir)`) only when LSP has no answer

## Hosts

- Two executables: `meiolol` (backend: crawl, stats, site, status, champions; runs on
  the box, an Oracle Cloud server) and `meiolol-app` (player tool: suggest, watch,
  session, get). `zig build lab`: `meiolol-lab`, modelling experiments on the gpu-box
  (CUDA via libcuda, kernels in src/gpu compiled to PTX)
- The box: `ssh meiolol-cloud`. Crawler 24/7: `deploy/box.sh start|stop|restart|status|
  logs|run`; a deploy restarts it only when src/riot or src/store changed. Data lives
  only there (~/ml/meiolol/data); the gpu-box keeps a copy as a restore point. Hosts,
  limits: docs/hosting.md
- Box jobs over a minute: `deploy/box.sh job run NAME 'CMD'` (a user unit, outlives
  ssh), `job status|wait NAME`. Waiting for a push: `deploy/box.sh wait-deployed [REV]
  [--live]` (exits 0, 1 failed, 3 timeout), not a sleep loop. Hand-edited Daily or Learn
  files: `deploy/box.sh web rebuild` (a forced round keeps the old ones)
- Website: https://meio.lol (DNS on Cloudflare: docs/architecture.md; mail to @meio.lol:
  deploy/mail.sh), static nginx and the Your games API on the jomify server (`ssh
  jomify`; it also runs jomove, an unrelated house-moving app: leave its config alone).
  The box builds and uploads on new data: `deploy/box.sh web start
  [privacy@meio.lol]|stop|status`. jomify's pieces are installed by hand:
  `deploy/jomify.sh drift`, `install api|traffic|...`. Admin pages: `deploy/admin-get.sh
  PATH` (keeps the login off screen). Preview mode until prod key
- Visiting meio.lol counts as a bot only when tagged: `browse`, persona-walk, curl,
  WebFetch and headless Chrome already are; a scripted headed browser appends
  `meiolol-agent` to its user agent (deploy/traffic.sh)
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
- Waiting: run_in_background, then wait for the notification; never re-read task output
  or sleep/poll (the sleep guard blocks it)
- Tests: `zig build test 2>&1 | tee $SCRATCH/t.log | tail -30`, then grep the log;
  re-run only after a change
- Hand over at ~200k context (fleet skill), don't run on into compaction
- Team runs: shared state in the run's common.md; messages are "done: <path>" or
  "blocked: <why>, <path>", details in the file

## Docs (read the one you need, not all)

- Layout, modules, storage, model file format: docs/architecture.md
- What we have learnt about the data (plain findings, read first): docs/learned.md. Add a
  line when a model or data check gives a final result
- Draft model quality on held-out games (`meiolol eval`): docs/model.md, the lab record
  (4.5k lines: read its Start here, then one section). Measure any recommender change
  there first
- Data sources and what was ruled out (and why): docs/data.md. Read before adding one
- Production key requirements and policy limits on what the app may show:
  docs/production-key.md; sources and quotes in research/ (josearch store, see
  research/README.md)
- Backups, health alerts, disk headroom, GDPR erasure (`meiolol backup|restore|forget`):
  docs/data-safety.md
- Older next steps by area: docs/backlog.md. Finished team runs: docs/archive/
- Team runs (a coordinator and several sessions): briefs, notes and handovers in
  data/team/<date>-<name>/ (gitignored, survives reboots), not /tmp scratchpads
