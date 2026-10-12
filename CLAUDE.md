# meiolol

League of Legends champ select pick recommender for normal ranked players, today's
patch, EUW first. All Zig (0.17, pinned in build.zig; docs/zig-0.17.md); no Python.

**Current goal: get a Riot production key** (more rate limit). Plan and next steps:
docs/plan.md. Read it first.

- Work on main only: no branches or worktrees (one developer). Other sessions share the
  checkout, so commit by explicit path (`git commit -m ... -- <paths>`) only: never a
  plain `git commit` after `git add`, and never through a temporary index
  (`GIT_INDEX_FILE`); both can commit a stale copy of another session's file
- Build: `zig build`; `zig build test` (`-Dtest-filter=NAME`; a test that logs a
  warning fails); `zig build fmt`; `zig build ci` = fmt check, tests, Windows and Linux
  builds, shellcheck, JS syntax. Hooks in deploy/hooks (`git config core.hooksPath
  deploy/hooks`): pre-commit fmt, pre-push `zig build ci` on a clean checkout of the
  pushed commit, since every push deploys
- src/pipeline_test.zig: fixture games through stats, curves and the whole site; extend
  it when adding a pipeline step or page
- Two executables: `meiolol` (backend: crawl, stats, site, status, champions; runs on
  the box, an Oracle Cloud server) and `meiolol-app` (player tool: suggest, watch, session, get).
  `zig build lab`: `meiolol-lab`, modelling experiments on the gpu-box (CUDA via libcuda,
  kernels in src/gpu compiled to PTX)
- Heavy model work on the gpu-box (3080, 20 threads) or Mac CPU, never the box:
  deploy/lab-run.sh; League pauses gpu-box runs; warn sessions using it before restarting
  WSL. Parallel loops: src/par.zig. docs/compute.md
- Website: https://meiolol.jomify.lol, static nginx on the jomove server
  (`ssh -i ~/.ssh/oci_instance-20260714-1317 ubuntu@193.123.180.81`; jomove's own
  site runs there too, leave its config alone). Box builds and uploads on new data;
  every push to main deploys (git hook, deploy/on-push.sh, log .git/meiolol-deploy.log).
  `deploy/box.sh web start [jombirds@gmail.com]|stop|status`. Preview mode until prod key
- Layout, modules, storage, model file format: docs/architecture.md
- Draft model quality on held-out games (`meiolol eval`): docs/model.md. Measure any
  recommender change there first
- Data sources and what was ruled out (and why): docs/data.md. Read before adding one
- Production key requirements and policy limits on what the app may show:
  docs/production-key.md; sources and quotes in research/ (josearch store, see
  research/README.md)
- Backups, health alerts, disk headroom, GDPR erasure (`meiolol backup|restore|forget`):
  docs/data-safety.md
- Crawler runs 24/7 on the box: `deploy/box.sh start|stop|status|logs|run`. Data lives
  only there (~/ml/meiolol/data). `ssh meiolol-cloud`; hosts, limits: docs/hosting.md.
  The old gpu-box PC keeps a copy as a restore point
- Riot key: RIOT_API_KEY in .env (gitignored), copied to the box by deploy/box.sh.
  Never print it. Riot portal automation: `jodrive riot ...` (~/personal/jodrive)
- Zig 0.16/0.17 std changed a lot (std.Io everywhere, renames): check APIs via LSP
  hover/goToDefinition (ZLS) rather than guessing; std source at
  `$(zig env | grep lib_dir)` as fallback
