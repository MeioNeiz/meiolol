---
title: 'River (codeberg river/river): CONTRIBUTING, build.zig, main, object files, common/'
url: https://codeberg.org/river/river
kind: project
commit: 137524036de508090141c18f1d72b9737013646f
for: [zig-good-practice, zig-style, zig-memory, zig-errors-safety, zig-comptime, zig-testing, zig-build]
looked: 2026-10-22
depth: code (CONTRIBUTING.md, ARCHITECTURE.md, build.zig, river/main.zig, util.zig, XdgPopup.zig, Server.zig init, Window.zig and Seat.zig greps, common/flags.zig, common/slotmap.zig)
relevance: high
grade: A/strong
description: Wayland compositor by Isaac Freund (Zig core team) over wlroots; 15k lines of Zig 0.16 with C interop, a short explicit style guide and a simplicity-first rule
---
# River (codeberg river/river): CONTRIBUTING, build.zig, main, object files, common/

Why: how does a Zig core contributor write an application over a big C library: style
rules, allocator use, error handling at C callbacks, C interop and build.zig, on 0.16?

## Assessment

- Evidence: A. Created 2020-03 (GitHub mirror riverwm/river: 4327 stars, 170 forks, 70
  contributors; primary repo is Codeberg), pushed 2026-10-14, release v0.3.0 (2024; 0.6.0-dev
  now). Packaged by major distros. Author maintains zig-wayland, zig-wlroots and is on the
  Zig core team.
- Reasoning: strong. CONTRIBUTING states the style rules and the priority (simplicity over
  performance without profiles); comments explain workarounds with issue links.
- Interests: none known. Strict no-LLM contribution policy.
- Weigh: trust its idioms as idiomatic Zig from the core team; on Zig 0.16 (one behind
  0.17), so check renamed builtins. Very few unit tests: an app tested by use, not a model.

## Findings

- [toolchain] Builds with Zig 0.16 (README); depends on the translate-c package pinned to
  its 0.16.x branch. `README.md`, `build.zig.zon` ^f1
  > .url = "git+https://codeberg.org/ifreund/translate-c?ref=0.16.x#64570104eeed461dc221e77574cd3f1c5b7eb974",
- [zig/style] Style: follow the Zig Style Guide and run `zig fmt` before every commit;
  lines under 100 columns in general, readability first; use trailing commas to make
  zig fmt wrap. `CONTRIBUTING.md` ^f2
  > Please follow the
  > With regards to line length, keep it
  > under 100 columns in general but prioritize readability over adhering to a
- [zig/style] The one extra rule: no multi-line `if` without braces; a one-line `if (foo)
  bar();` or a braced block. `CONTRIBUTING.md` ^f3
  > The single additional style rule is to avoid writing `if` statements and
  > similar across multiple lines without braces:
- [zig/perf] [zig/style] Simplicity over nearly everything; performance justifies
  complexity only with profiling results showing a significant benefit. `CONTRIBUTING.md` ^f4
  > On a higher level, prioritize simplicity of code over nearly everything else.
  > Performance is only a valid reason for code complexity if there are profiling
- [zig/style] Commit messages prefixed by the affected part (`build:`, `Keyboard:`).
  `CONTRIBUTING.md` ^f5
  > Commit messages
  > should start with a prefix indicating what part of river is affected by the
- [zig/style] Almost every file is a TitleCase struct (Window.zig, Seat.zig, XdgPopup.zig)
  opening with `const X = @This();`, then imports, then `const log = std.log.scoped(...)`,
  then fields; one file per object type; ARCHITECTURE.md maps the objects. `river/XdgPopup.zig`,
  `ARCHITECTURE.md` ^f6
  > const XdgPopup = @This();
  > const log = std.log.scoped(.xdg_popup);
- [zig/memory] One global allocator: `util.gpa = std.heap.c_allocator`, used everywhere
  (120 uses) rather than threading an allocator parameter; the binary links libc anyway. `river/util.zig` ^f7
  > /// The global general-purpose allocator used throughout river's code
  > pub const gpa = std.heap.c_allocator;
- [zig/memory] main still makes a short-lived arena on top of gpa for argument parsing. `river/main.zig` ^f8
  > var arena_alloc = std.heap.ArenaAllocator.init(util.gpa);
- [zig/memory] [zig/errors] Deliberately no leak cleanup on error in startup init, since
  the process exits anyway: simpler code. `river/Server.zig` ^f9
  > // We intentionally don't try to prevent memory leaks on error in this function
  > // since river will exit during initialization anyway if there is an error.
- [zig/api] [zig/memory] Heap objects: `create()` allocates with `util.gpa.create`,
  `errdefer destroy`, fills `x.* = .{...}`, then registers listeners; the destroy listener
  frees itself. `river/XdgPopup.zig` ^f10
  > const xdg_popup = try util.gpa.create(XdgPopup);
  > errdefer util.gpa.destroy(xdg_popup);
- [zig/api] Intrusive C callbacks: a `wl.Listener(T)` field with a decl-literal default
  `.init(handler)`; the handler recovers its object with `@fieldParentPtr` (158 uses). `river/XdgPopup.zig` ^f11
  > destroy: wl.Listener(void) = .init(handleDestroy),
  > const xdg_popup: *XdgPopup = @fieldParentPtr("destroy", listener);
- [zig/errors] Errors cannot cross a C callback, so handlers end the error chain: OOM is
  reported to the Wayland client with `postNoMemory()` (46 uses) and the handler returns. `river/XdgPopup.zig`,
  `river/Seat.zig` ^f12
  > wlr_popup.resource.postNoMemory();
  > seat_v1.getClient().postNoMemory();
- [zig/errors] Signatures name narrow error sets (`error{OutOfMemory}!void`); `main`
  returns `anyerror!void`. `river/XdgPopup.zig`, `river/main.zig` ^f13
  > ) error{OutOfMemory}!void {
  > pub fn main(init: std.process.Init.Minimal) anyerror!void {
- [zig/errors] User-facing fatal errors go through `std.process.fatal` with a message;
  errors switched on by name, `{t}` for the tag. `river/main.zig` ^f14
  > error.PermissionDenied, error.AccessDenied => fatal("failed to run init executable {s}: the file is not executable", .{path}),
- [zig/errors] Unsupported platform state is a `@panic` with a message (the only one in
  src); `catch unreachable` appears once, on a bufPrint into a buffer sized for it. `river/util.zig`,
  `river/TransientSeatManager.zig` ^f15
  > else => @panic("CLOCK_MONOTONIC not supported"),
- [zig/safety] Assertions document state-machine invariants (188 assert calls in 15k
  lines), e.g. a window is mapped or closing before a step runs. `river/Window.zig` ^f16
  > assert(window.impl == .destroying);
  > assert(window.state == .mapped);
- [zig/style] Logging: std.log with a closed `LogScope` enum filtered at run time by
  `-log-scopes`, and level filtering left to logFn by setting `log_level = .debug` (same
  as ZLS). `river/main.zig` ^f17
  > // Tell std.log to leave all log level filtering to us.
  > // Scopes should be added to this list sparingly.
- [zig/build] C interop on 0.16: C headers go through the translate-c package's
  `Translator` from build.zig (a module named "c" from c.h), not `@cImport`. `build.zig`, `river/c.h` ^f18
  > const translate_c: Translator = .init(b.dependency("translate_c", .{}), .{
  > .c_source_file = b.path("river/c.h"),
- [zig/build] [zig/errors] C varargs callbacks are handled by a small C shim compiled into
  the exe (`addCSourceFile`) that formats into a buffer and calls an `export fn` in Zig. `river/wlroots_log_wrapper.c`,
  `river/main.zig` ^f19
  > export fn river_wlroots_log_callback(importance: wlr.log.Importance, ptr: [*:0]const u8, len: usize) void {
  > river.root_module.addCSourceFile(.{
- [zig/build] Generated Zig bindings: the zig-wayland Scanner generates protocol code at
  build time into a module; each interface version pinned in build.zig with a comment on why
  stale versions are harmless. `build.zig` ^f20
  > const wayland = b.createModule(.{ .root_source_file = scanner.result });
  > // These versions control Zig code generation and have no effect on anything internal
- [zig/build] Version string from build.zig.zon imported as a module, plus `git describe`
  for -dev builds; build options exported with `addOptions`. `build.zig` ^f21
  > const manifest = @import("build.zig.zon");
  > options.addOption([]const u8, "version", full_version);
- [zig/comptime] Comptime API: `flags.parser(&.{...})` builds a result struct type with one
  field per declared flag using the `@Struct` builtin, and parses with `inline for` over the
  flags. `common/flags.zig` ^f22
  > pub fn parser(comptime flags: []const Flag) type {
  > break :flags_type @Struct(.auto, null, &names, &types, &attrs);
- [zig/comptime] Generic container as a type function returning `struct`, `const Map =
  @This();`, an `empty` decl for decl-literal init, allocator passed to each method. `common/slotmap.zig` ^f23
  > pub fn SlotMap(comptime T: type) type {
  > pub const empty: Map = .{
  > pub fn put(map: *Map, gpa: mem.Allocator, value: T) error{OutOfMemory}!Key {
- [zig/test] Tests: only the reusable common/slotmap.zig has unit tests (3 test blocks in
  15k lines), run by `zig build test`; the compositor itself has none. `build.zig`,
  `common/slotmap.zig` ^f24
  > const test_step = b.step("test", "Run the tests");
  > var map: SlotMap(u32) = .empty;
- [zig/comptime] Idiom counts (15k lines): 1 `anytype` (the log fn), 6 `inline for`:
  comptime kept to the flag parser and generics. ^f25
- [zig/style] Comments carry the why, often with an issue link for a workaround. `build.zig` ^f26
  > // Workaround for https://github.com/ziglang/zig/issues/16369

## Read

- `CONTRIBUTING.md`, `ARCHITECTURE.md`, `build.zig`, `build.zig.zon`: all
- `river/main.zig`, `river/util.zig`, `river/XdgPopup.zig`, `common/flags.zig`: all
- `river/Server.zig`: init and deinit; `common/slotmap.zig`: head and tests
- `river/Window.zig`, `river/Seat.zig`: grep for assert, postNoMemory, log
- grep counts over river/ and common/

## Not read

- `doc/internal/Keyboard.md`: in-depth notes on one complex corner
- `river/WindowManager.zig`: the manage/render state machine
- zig-wlroots and zig-wayland bindings repos: how the bindings wrap C types
