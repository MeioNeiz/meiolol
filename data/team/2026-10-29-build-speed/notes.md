# Build speed (29 Oct), session 77536c9c

Worktrees: .claude/worktrees/speed (HEAD 8d365845, before), speed2 (the fix), speed3 (HEAD).
Scratch: /private/tmp/claude-501/-Users-jacobmaschler-personal-meiolol/77536c9c-9872-4fc0-82c5-1a9b143b8788/scratchpad
(m.sh timing wrapper, results.tsv, timereport.py = --time-report client, ab.sh).
Caches: c-base (before), c-fix (after). Mac load 10-30 during all runs: compare pairs only.

## Findings
- Backend test compile (one binary, src/main.zig): sema 226-244 s CPU, LLVM IR+codegen+link ~50 s
- time report per decl: 236 of 244 s sema is comptime: asset FNV hashes (assets.zig,
  adminpage.zig) 167 s, style.bundle comptime minify 68.5 s; real code sema 8.5 s
- Fix (speed2, uncommitted): src/tools/assetnames.zig + src/tools/cssmin.zig run in build;
  assets.built() reads names from generated asset_names.zig; style.bundle =
  @embedFile("style.min.css"); minify moved to ui/css.zig. 928/928 tests pass, site-files same
- Before/after, backend-only edit (loads 26 vs 12): test 567 s -> 133 s wall; compile step 6m -> 42s
- Dev server `zig build backend` after edit (load ~25): 405 s -> 80 s wall, 310 -> 49 s CPU
- Self-hosted aarch64 backend (0.17): hello exe 108 s, 3.6 GB, killed. Dead
- Self-hosted x86_64-macos: one-step link -> dyld rejects (__CONST_ZIG); obj + separate link runs
  under Rosetta but tests panic "incorrect alignment" in SafeAllocator. Compile 247 s CPU anyway (sema)
- -fincremental on macOS: "TODO(MachO2): load archive" panic, even check-only. Dead on Mac
- Cross-path cache: real project NOT path-independent (backend test + islands rebuilt in speed3)
- Backend test RUN ~113 s loaded: pipeline fixture 27 s, api.fetch 2 tests 20+18 s (hot:
  mem.eqlBytes/mem.replace in fake? json), additive 11 s
- dev-watch.log since 28 Oct 06:49: ~23 backend rebuilds of 3-6 min each, not slot-gated
- Peer (meiolol-4b): Jacob wants ci on gpu-box; Mac hit load 106, 15 zig compiles, 8.7 GB swap,
  slots don't cap zig -j. I took gpu-box ci (measure, propose; no main changes before Jacob ok)

## Still to do
- ui-edit before/after (ab.sh round 1 last pair), cold after
- ci on gpu-box timing (x86_64 linux: self-hosted backend default for Debug)
- report table + recommendation to Jacob

## gpu-box (20 threads, idle, x86_64 Linux: self-hosted backend for Debug), ~/ml/build-speed
| step | before | after |
|---|---|---|
| cold test | 182 s | 68 s |
| edit (views.zig) + test | 150 s | 47 s (backend test compile 10 s) |
| ci after that | 165 s (685 s CPU) | 51 s (316 s CPU) |
Failures both trees: lab.summaries test needs `zstd` (missing); ci lint: shellcheck, node missing,
check-deploy needs .git. 4 tests skip on Linux.
Mac ui edit + test (loads 17 vs 19): 477 s -> 342 s wall, 425 -> 207 s CPU
Peers: 4b coordinator (wants landing; I hold for Jacob's direct yes), W8 meiolol-86 routing layer
(asked test-ui + deploy build sha on both hosts), W7 meiolol-18 waits for build.zig all-clear
gpu-box test-ui after ui edit 3.9 s; Mac 28 s. Deploy build ReleaseSafe: gpu-box 230 s, Mac 185 s;
.text/.rodata/.data identical across hosts (only debug paths differ). Fix as patch:
comptime-fix.patch (+ untracked src/tools/*.zig in speed2). Report sent to Jacob; waiting on yes.
