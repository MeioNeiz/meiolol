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
  knows: `git add <new file>` first, then list it in `git commit -- <paths>`
- Every push to main deploys (deploy/on-push.sh, log .git/meiolol-deploy.log; docs and
  research-only pushes skip the build). Push the tested sha, `git push origin
  <sha>:main`: over HTTPS git re-reads main after the pre-push ci, so a commit another
  session made meanwhile goes out untested
- Hooks in deploy/hooks (`git config core.hooksPath deploy/hooks`): pre-commit fmt,
  pre-push `zig build ci` on a clean checkout of the pushed commit

## Build and test

- `zig build`; `zig build test` (`-Dtest-filter=NAME`; a test that logs a warning
  fails); format only your own files, `zig fmt <paths>` (`zig build fmt` rewrites the
  whole tree, other sessions' dirty files too); `zig build ci` = fmt check, tests,
  Windows and Linux builds, shellcheck, JS syntax
- src/pipeline_test.zig: fixture games through stats, curves and the whole site; extend
  it when adding a pipeline step or page. A page change moves src/testdata/site-files.txt:
  commit the change, then `deploy/site-hashes.sh` (hashes from a clean checkout of HEAD,
  never the working tree's mix of sessions), then commit the file
- Local site: `deploy/dev.sh` (data/snap; `--exports` refreshes the box's curves and
  builds when it warns the curves are an old version)
- Zig 0.16/0.17 std changed a lot (std.Io everywhere, renames): check APIs via LSP
  hover/goToDefinition (ZLS) rather than guessing; std source at
  `$(zig env | grep lib_dir)` as fallback

## Hosts

- Two executables: `meiolol` (backend: crawl, stats, site, status, champions; runs on
  the box, an Oracle Cloud server) and `meiolol-app` (player tool: suggest, watch,
  session, get). `zig build lab`: `meiolol-lab`, modelling experiments on the gpu-box
  (CUDA via libcuda, kernels in src/gpu compiled to PTX)
- The box: `ssh meiolol-cloud`. Crawler 24/7: `deploy/box.sh start|stop|status|logs|run`;
  deploys don't restart it, so restart it after a crawl change. Data lives only there
  (~/ml/meiolol/data); the gpu-box keeps a copy as a restore point. Hosts, limits:
  docs/hosting.md
- Website: https://meio.lol (DNS on Cloudflare: docs/architecture.md; mail to @meio.lol:
  deploy/mail.sh), static nginx and the Your games API on the jomove server (`ssh
  jomove`; jomove's own site runs there too, leave its config alone). The box builds
  and uploads on new data: `deploy/box.sh web start [privacy@meio.lol]|stop|status`.
  Preview mode until prod key
- Heavy model work on the gpu-box (`ssh gpu-box`; 3080, 20 threads) or Mac CPU, never
  the box: deploy/lab-run.sh; League pauses gpu-box runs; warn sessions using it before
  restarting WSL. Parallel loops: src/par.zig. docs/compute.md
- Riot key: RIOT_API_KEY in .env (gitignored), copied to the box by deploy/box.sh.
  Never print it, nor the admin password (vault meiolol/local). Riot portal automation:
  `jodrive riot ...` (~/personal/jodrive)
- Bash runs zsh: quote globs (`grep --include='*.zig'`, else "no matches found") and
  never keep a command in a variable (`J="ssh -i k host"; $J` doesn't split): use the
  ssh aliases above

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
