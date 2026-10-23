# Applying the guide to meiolol

Counted 2026-10-22 over src/ (105k lines, 518 test blocks), for the next step:

- already in line: camelCase functions (1657 vs 44 snake_case), no `Self = @This()`,
  287 errdefers, 38 files with a scoped log, `std.process.Init` in 10 mains
- stale but compiling on 0.17 (break in 0.18): `std.fmt.allocPrint` 215,
  `std.mem.indexOf*` 261, `@intFromFloat` 87, `@intFromEnum` 3, `std.builtin` 2,
  `std.meta.fieldNames` 3
- worth a look: 67 asserts in 105k lines (TigerBeetle-style invariants would add most
  where state is subtle: stats merges, curve files, crawler state), 21 `anyerror`, 20
  `catch unreachable`, 97 `anytype`, 29 `@hasDecl`

Applied 23 Oct (data/team/2026-10-23-cleanup/: briefs, reports, scout.md's tree-wide
list): 105 commits, about 8.2k lines fewer (retired outcomes/items/scaling/carry, pool
export, lab gains/lanebuckets/enemy/comps CLI/randsplit, 8 py scripts), site byte-
identical. Left: allocPrint 12, bufPrint 26, indexOf* 23 (mostly the desktop app's new
code), 13 `anyerror` (command table, thread failure slots, vtables), 17 `catch
unreachable` (fixed buffers, labtools), 21 `.unlimited` (our own big lab files);
sqlite `Stmt.row` @intCasts db values (an out-of-range value panics every reader;
changing it touches ~100 call sites); winnet.setFlag adopted by the net family and
effects only. deploy/golden.sh after it (23 Oct): the lab didn't build at d3d7186
(champgroups' comps.cellKey went private in 2ed8baa; fe264b4), and at e0ef0f5 all four
non-test cases give the same numbers as 616e0a6, the cleanup's base: no change from the
cleanup. Both differ from golden.tsv (moved between d87d8d7 and 616e0a6, not bisected)
