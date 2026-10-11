# meiolol

League of Legends champ select pick recommender for normal ranked players, today's
patch, EUW first. All Zig (0.16, pinned in build.zig); no Python.

**Current goal: get a Riot production key** (more rate limit). Plan and next steps:
docs/plan.md. Read it first.

- Build: `zig build`, `zig build test`, `zig build -Dtarget=x86_64-windows` (app ships
  on Windows, developed on macOS; both must compile)
- Two executables: `meiolol` (backend: crawl, stats, site, status, champions; runs on
  the gpu-box PC) and `meiolol-app` (player tool: suggest, watch, session, get)
- Website: `deploy/box.sh site EMAIL` -> data/site (static, preview mode until prod key)
- Layout, modules, storage, model file format: docs/architecture.md
- Data sources and what was ruled out (and why): docs/data.md. Read before adding one
- Production key requirements and policy limits on what the app may show:
  docs/production-key.md; sources and quotes in research/ (josearch store, see
  research/README.md)
- Crawler runs 24/7 on the PC: `deploy/box.sh start|stop|status|logs|run`. Data lives
  only there (~/ml/meiolol/data). PC access: `ssh gpu-box` (see ~/personal/gpu-box)
- Riot key: RIOT_API_KEY in .env (gitignored), copied to the box by deploy/box.sh.
  Never print it. Riot portal automation: `jodrive riot ...` (~/personal/jodrive)
- Zig 0.16 std changed a lot (std.Io everywhere): read std source at
  `$(zig env | grep lib_dir)` rather than guessing APIs
