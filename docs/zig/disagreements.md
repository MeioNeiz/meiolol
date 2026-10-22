# 16. Where respected sources disagree

| Topic | One side | Other side | Recommendation |
| --- | --- | --- | --- |
| Function casing | std camelCase (langref, std, Ghostty, ZLS, River) | snake_case (TigerBeetle, matklad) | std camelCase; meiolol already uses it |
| `Self` | `const Self = @This()` everywhere (Seguin) | type name in file-structs, `Self` only in type functions (std 128 vs 3 files, Ghostty, TigerBeetle bans it) | type name |
| Allocator passing | passed everywhere (ZLS, zig-clap, SuperHTML) | one global over libc (River, Bun) | pass it: keeps testing.allocator leak checks |
| OOM | recoverable, propagate (langref, std) | abort in applications (matklad); panic in build scripts (std Build.zig) | propagate in reusable code; panic acceptable in one-shot tools; reserve-first either way |
| Shipping mode | ReleaseSafe (TigerBeetle, ZLS, River, Loris Cro) | ReleaseFast plus debug safety and Valgrind (Ghostty) | safe, unless a profile says otherwise; Bun's hidden off-by-one is the cautionary tale |
| Assert density | two per function (Tiger Style) | measured 3.7 overall but 35% of functions none; ZLS 6, River 12 per 1000 lines | assert where state is subtle, not as a quota |
| Function length | 70 lines hard limit (Tiger Style) | ratchet in practice, 10% over | ratchet: stop growth, don't rewrite |
| anytype | avoid, use `comptime T` (ziggit doc) | free for comptime duck typing (matklad) | concrete types on public runtime APIs; anytype in obvious internal helpers |
| Reflection | wide config surface (Ghostty) | avoid if possible (matklad) | only for wide repetitive surfaces |
| Static allocation | everything at startup (TigerBeetle) | needs bounded inputs (matklad) | named maxima and an init phase per job |
| defer as RAII | defer right after acquire (everyone) | humans forget defers; prefer few owners (matklad) | both: defer next to acquire, and design for few owners |
| Inline asserts and `inline fn` | forced inline after measuring 15-20% (Ghostty, 0.15.2) | `inline` is not a hint and can hurt (langref) | only with a benchmark, re-measured on 0.17 |
| Fuzzer | built-in `std.testing.fuzz` + Smith (core team, SuperHTML) | own seeded programs (TigerBeetle), AFL++ (Ghostty) | built-in, but check the log: `--fuzz` has exited 0 on a crash |
| Release allocator | libc malloc (Ghostty, Seguin) | smp_allocator (std, ziggit) | `init.gpa` decides |
| Tests vs asserts | many unit tests (ZLS, Roc) | asserts plus fuzzing over unit tests (Loris Cro), River almost none | behaviour-level data-driven tests, asserts, fuzz |
| Import placement | top (ZLS, River, Ghostty, std) | bottom (zig-clap, Bun) | top, the majority |
| Docs on every pub decl | Roc lints it | others document non-obvious contracts only | non-obvious only |
| `.imports` vs `addImport` | template uses the field | addImport for conditional or circular (Loris Cro) | no rule; one style per file |
