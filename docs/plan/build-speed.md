# Build speed on the Mac

Goal: sessions keep working at pace: a test after an edit in about a minute, ci and the
deploy build off the Mac when the gpu-box is free. Measurements and how they were taken:
data/team/2026-10-29-build-speed/ (notes.md, results.tsv; scratch tools there:
timereport.py reads Zig's --time-report per declaration).

What we know (29 Oct):
- Zig sema, not LLVM, was the cost: 97% of the backend's was comptime hashing and CSS
  minifying, now build tools (src/tools). Backend test compile 6 min to 42 s, dev server
  build 405 s to 80 s (loaded Mac)
- Dead ends in Zig 0.17 on the Mac: the self-hosted aarch64 backend (crashes), x86_64
  self-hosted under Rosetta (wrong code), -fincremental (MachO linker TODO panic). Zig's
  cache is path-dependent for this project, so trees don't share builds
- gpu-box (x86_64 Linux, self-hosted backend in Debug): edit and test 47 s, ci 51 s; the
  deploy build's code and data match the Mac's byte for byte

## Steps

- BS1 done: comptime asset hashing and CSS minify out of the compile
- BS2: slots mean cores: each slot holder's zig build gets -j 2 x weight (slots.sh,
  MEIOLOL_ZIG_JOBS through the ~/.local/bin/zig shim); the dev server's watch too
- BS3: ci, pre-push ci and the deploy build on the gpu-box when free, the Mac when not
  (W8, meiolol-86, owns the routing; data/team/2026-10-29-next/notes/w8.md). Needs on the
  gpu-box: zstd, shellcheck, nodejs; a .git for check-deploy.sh
- BS4: slow backend tests, 66 of ~113 s: pipeline fixture 27 s, two api.fetch refresh
  tests 20 s and 18 s (time in string compares, likely the fake), additive 11 s
- BS5: site-files.txt read at runtime, not @embedFile: each change to it (half of src
  commits) recompiles the backend test
- BS6: the ui edit path: 35 islands rebuild on any ui change (3-7 s each, ReleaseSmall);
  measure what in them costs before changing
- BS7: the per-page CSS work (sheets.zig) keeps minifying out of comptime: cssmin.zig
  writes per-component minified CSS if that lands
