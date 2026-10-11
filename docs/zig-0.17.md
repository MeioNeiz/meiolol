# Zig 0.17 migration

Assessed 2026-10-11 against commit 1149c0b. Evidence: research/questions/
zig-017-migration.md (release notes plus a trial port). The full diff and build output
are in research/raw/zig-017-trial-port.md.

## Verdict

Small: about an hour of edits plus a runtime check. On 0.17.0 the trial port hit 6
compile errors. After about 40 changed lines in 6 files, all of these passed:
- native build
- `zig build test` (11/11 steps)
- `-Dtarget=x86_64-windows`
- `-Dtarget=x86_64-linux`
- the box build (musl, ReleaseSafe)

Nothing needed changing in std.Io, the Riot or LCU http clients, the wasm module or the
site generator. Release sizes are unchanged within 5%: app exe 917 KB on 0.16, 903 KB
on 0.17; box binary 19.6 MB, 20.6 MB. Not yet run: nothing built by 0.17 has executed
on the box or on Windows.

## What breaks, and the fix

| Where | 0.16 | 0.17 |
| --- | --- | --- |
| build.zig:6 | version pin `v.minor != 16` | `!= 17`; build.zig.zon `minimum_zig_version = "0.17.0"` |
| build.zig:81 | `if (b.args) \|args\| run.addArgs(args);` | `run.addPassthruArgs();` |
| src/store/sqlite.zig:4 | `@cImport(@cInclude("sqlite3.h"))` | `@import("sqlite_c")`, module made in build.zig (below) |
| src/core/score.zig:91, 94, 559 | `.initEmpty()` | `.empty` |
| src/lcu/https.zig:168 | `std.ascii.indexOfIgnoreCase` | `std.ascii.findIgnoreCase` |
| src/store/raw.zig:43 (test) | `"..." ** 200 ++ "}"` | comptime loop concatenating 200 copies (`**` removed) |
| src/riot/timeline.zig:37, 357, 393 | `@typeInfo(T).@"struct".fields`, `f.name`, `f.type` | `.field_names` / `.field_types` (struct-of-arrays); enum `.field_names.len` |

SQLite header. Tested with the deprecated build step, in build.zig after
`store.addIncludePath`:

```zig
const sqlite_h = b.addTranslateC(.{
    .root_source_file = sqlite.path("sqlite3.h"),
    .target = target,
    .optimize = optimize,
});
store.addImport("sqlite_c", sqlite_h.createModule());
```

0.17 deprecates `addTranslateC` in favour of the external package
(`zig fetch --save git+https://codeberg.org/ziglang/translate-c`, then
`Translator.init`). Using the package now avoids a second edit for 0.18, at the cost of
one fetched dependency. Not tried here.

## Deprecated, still working: clear in the same pass

These compile on 0.17 and will break on 0.18:
- `std.builtin` becomes `std.lang`
- `std.fmt.allocPrint(a, ...)` becomes `a.print(...)` (src/daily.zig, site/root.zig,
  site/matchup.zig, main.zig, ddragon.zig, riot/client.zig, curves.zig)
- `std.StaticBitSet` becomes `std.bit_set.Static` (or `bit_set.Integer`)
- ArrayList `getLast` becomes `last().?`

Watch: `std.mem.containsAtLeastScalar` swapped its element and minimum arguments and still
compiles (not used today).

## Other 0.17 changes worth knowing

- build.zig runs in a separate configurer process; build scripts can no longer see run
  arguments. Response files for Run steps regressed (we don't use them)
- `Uri.getHost` becomes `HostName.fromUri` with a different error set (we don't use it)
- In 0.18, Windows resource files (`addWin32ResourceFile`) move to an external package:
  relevant if the desktop app ships a .rc manifest for DPI awareness
- 0.18 moves to LLVM 23

## Interaction with other work

- **GUI:** dvui, the chosen library (research: zig-gui-options), is on 0.16; its 0.17
  port is open (issue #839, updated 2026-10-10). Most other candidates already need
  0.17. Two good orders:
  - move meiolol first, then add dvui once its 0.17 support lands
  - adopt dvui on 0.16 and move both together
  Don't add dvui on 0.16 and then wait on it
- **Toolchain:** the Mac's zig comes from Homebrew (`/opt/homebrew/bin/zig`, 0.16.0) and
  every session shares it. The box needs nothing: deploy/box.sh cross-compiles on the Mac

## Order, when the sessions are quiet

1. Announce a freeze to the meiolol sessions; let the box keep crawling on its current
   binary
2. Install 0.17.0 beside 0.16 (the official tarball in ~/.local, or zvm), so a rollback
   is a PATH change, not a brew downgrade
3. On a branch: the seven fixes above, plus the deprecated APIs. `zig build`,
   `zig build test`, `-Dtarget=x86_64-windows`, the box target
4. Run on the box: `meiolol status`, one crawl cycle (deploy/box.sh run), `meiolol
   stats` and `meiolol site` against the real data; compare the site output with the
   0.16 build
5. Run the app on the Windows PC against a live client (watch, champ select read)
6. Merge, deploy the box binary, and update CLAUDE.md ("Zig 0.17, pinned in build.zig")
   and the std source pointer
7. Then the GUI (dvui on 0.17, or zgui as the fallback)

Effort:
- Steps 2 and 3: about an hour
- Steps 4 and 5: half a day, mostly waiting on a crawl cycle and a game

Everything sessions merge before the freeze needs the same mechanical fixes. The repo
greps for `b.args`, `initEmpty`, `@cImport`, `**` and `.fields` find them all.
