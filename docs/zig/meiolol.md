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
