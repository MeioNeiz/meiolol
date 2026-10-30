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
- BS4: slow backend tests. Backend test run 74 s CPU before (451 tests, Mac load 7), 50 s
  after the fake fix. Done: the two api.fetch refresh tests 17 s + 13.5 s to 0.2 s each
  (riot/fake.zig cut its fixtures once; it ran 11 Debug mem.replace passes over the
  725 KB timeline per game). Left: pipeline fixture 9-22 s by load, ~4 s of it Debug gzip
  of the site's .gz twins (write.zig); additive "parents" 6 s, real fitting
- BS5 done: pipeline_test.zig reads src/testdata/site-files.txt at run time, an input of
  the backend test run (build.zig siteFiles): an edit to it reruns the tests, no compile
- BS6: the ui edit path: 35 islands rebuild on any ui change (3-7 s each, ReleaseSmall);
  measure what in them costs before changing
- BS7: the per-page CSS work (sheets.zig) keeps minifying out of comptime: cssmin.zig
  writes per-component minified CSS if that lands
