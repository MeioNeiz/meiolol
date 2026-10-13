# Lab constraints: known traps, fixes and facts

Read this before your first lab run (shared bug registry: research/questions/
agent-ml-practice.md C16, C17). Append-only: never edit or delete a line; when one is
wrong or outdated, add a new line that supersedes it ("supersedes <date> <symptom>").

Add a line when you hit an error or silent wrong result whose cause wasn't obvious, or
fix the same thing twice. One line per entry, no wrapping:
`date | area | symptom (what you saw) | cause | fix, banned call or rule (commit)`.
Areas: data, harness, nets, gpu-box, mac, zig, build, process. A failed lab-run may add
a stub line (command, exit, last error line): complete its cause and fix.
Same error twice on one line of work: restore the last good state, don't try a third fix.

## Incidents

2026-10-13 | data | win-comp scored exactly like ratings on the Mac, no error | snapshot without seat_stats.tsv: Row.stats all NaN, profiles silently empty | candidates declare needs_stats; harness.fit fails with error.NoSeatStats; check inputs aren't all NaN before trusting a run (9b2d122)
2026-10-13 | data | every Data Dragon value (armour, MR, resists) NaN in seat stats | snapshot.sh opened the db with ?mode=ro while the WAL had no -shm: open failed with 14, patch loop ran empty | plain sqlite3 open; snapshot.sh dies when no patches are found (30450b4)
2026-10-13 | nets | seed 3 gave the same results as seed 1 | netcheck small/resid with --threads < --seeds refitted seeds[0..] in the second batch | fixed in 9ace58d; check different seeds give different preds (9ace58d)
2026-10-13 | process | gold14-a's "whole model" and confound readings were wrong | compared against 3c-team, not the intended team2 | name the reference model and its run in every comparison; both sides from the same build and snapshot (afb4a4e)
2026-10-13 | nets | resid net looked better than it was | offsets on training games came from a candidate fitted on those same games (leak, L1) | any per-row input built from outcomes is cross-fitted: from a fit without that row's fold (22adcde)
2026-10-13 | data | lab commands slow (rows from SQLite, 15-37 s) after copying a snapshot to the Mac | pack manifest stamped mtime in nanoseconds; rsync (openrsync) drops them, so the pack never matched | stamp mtime in whole seconds (meiolol-4a, src/lab/pack.zig); a "from SQLite" note on load means the pack was ignored
2026-10-13 | gpu-box | --no-build run used a different binary than intended | a later build on the gpu-box replaced the binary the queued run pointed at | per-run immutable binaries (meiolol-16); until then don't rely on --no-build while others build
2026-10-13 | gpu-box | mastery-pre failed with FileNotFound over ssh | a plain ssh's PATH lacks ~/bin (zstd lives there) | put ~/bin on PATH in remote commands (4447cdb)
2026-10-12 | build | launchd's snapshot job built with zig 0.16 | login bash under launchd had Homebrew first on PATH | ~/.local/bin first on PATH in scripts run by launchd (ef54335)
2026-10-12 | process | a commit restored an old model.md section | a stale staged copy went into an unrelated commit | commit by explicit path only, never plain git commit after git add (36b326e)
2026-10-13 | build | lab-run start failed "pinned to Zig 0.17.x, found 0.16.0" in a resumed Claude session | the new shell had Homebrew's zig first on PATH | export PATH=$HOME/.local/zig/zig-aarch64-macos-0.17.0:$PATH (or ~/.local/bin first) before lab-run or zig build
2026-10-13 | process | pretrain variant runs vanished, no exit file | started as plain background shells from a Claude pane, killed when the pane closed | long runs only through deploy/lab-run.sh (own process group, survives the session)

## Zig 0.17 (docs/zig-0.17.md; check APIs with LSP hover, std moved a lot)

2026-10-12 | zig | Allocator.dupeZ / fmt.bufPrintZ not found | removed in 0.17 | dupeSentinel(.., 0), mem.printSentinel(.., 0)
2026-10-12 | zig | fmt.allocPrint / bufPrint deprecated | moved | a.print(...) / mem.print(...)
2026-10-12 | zig | std.builtin deprecated | renamed | std.lang
2026-10-12 | zig | panic on `.?` after assigning undefined to an optional | 0.17 safe builds read undefined optional as null | assign the payload type's undefined, not the optional's
2026-10-12 | zig | @intFromEnum / @enumFromInt rewritten by zig fmt | renamed builtins | @backingInt / @fromBackingInt (zig fmt your own files only)
2026-10-12 | zig | `.initEmpty()`, `**` on strings, @typeInfo(T).@"struct".fields fail | 0.17 changes | `.empty`; comptime loop; `.field_names` / `.field_types`
2026-10-12 | zig | std.mem.containsAtLeastScalar gives wrong answers, still compiles | element and minimum arguments swapped in 0.17 | check argument order with LSP before use
2026-10-12 | zig | StaticBitSet, ArrayList getLast deprecated | renamed, break in 0.18 | std.bit_set.Static, last().?

## gpu-box and CUDA (docs/compute.md)

2026-10-12 | gpu-box | runs stop for hours | the watcher pauses every run while League is up | CPU work: lab-run start with no HOST (placement picks the Mac); queue only real GPU work on the gpu-box
2026-10-12 | gpu-box | running jobs die | WSL restart or reboot kills them (back in under ~2 min) | tell the sessions using the gpu-box before restarting WSL; lab-watch reruns live runs at most twice
2026-10-12 | gpu-box | CUDA command refused on the Mac | no CUDA there; libcuda.so.1 is WSL's (/usr/lib/wsl/lib) | --res gpu jobs only on the gpu-box; kernels are PTX for sm_86, JIT-compiled at load
2026-10-12 | nets | @exp in a kernel fails to compile | nvptx has no libcall for exp | use kernels.zig's exp (ex2.approx)
2026-10-12 | nets | kernel gets garbage struct arguments | kernels take pointers and scalars only | shared layout structs live in device memory (extern), not by value
2026-10-13 | build | zig build ci slow (a minute in LLVM type-checking meiolol-lab) | ReleaseFast for a check | ci checks meiolol-lab in Debug (b55c0cb)

## Mac

2026-10-13 | mac | lab-run placement skips the Mac for a snapshot | no ~/ml/snaps/<snap> link on the Mac | snapshot.sh push makes the link to data/<snap>; make it by hand for older snapshots (1108c38)

## Typical times (to judge whether a run is stuck)

2026-10-13 | times | lab-exp run ~2 min: ~80 s build, ~16 s scoring (gpu-box) | rows load: 0.14 s packed, 15-17 s gpu-box / 31-37 s Mac from SQLite | eval 26.6k games: 7 s gpu-box, 13 s Mac | pack write 17-34 s | pre-push ci ~30 s
2026-10-13 | times | draft net epoch at 175k games: 0.52 s on the 3080, 2.02 s on 20 threads, 11.9 s one core | netcheck big trial ~2 s (fit 0.6 s), +250 MiB GPU memory | 40 trials x 20 epochs at 16x data ~40 min on the 3080
