//! fmtlint: number formatting through std.fmt in code that can compile to ui.wasm. Each
//! call site is code of its own in every family that reaches it, and each int type
//! printed adds std's formatter for that type (printValue + printIntAny, ~170 B gz):
//! d803924c put three families over their budget with two `{d}`s in a shared component.
//! Text through {s} and {t} is cheap; numbers go through phrase.num / fmt.write
//! (src/site/ui/fmt.zig). src/tools/wasmsize --numbers shows what a family carries.
//!
//! Flags string literals with such a placeholder outside tests, comptimePrint and
//! @compileError, unless the line says `fmt-ok` in a comment or the literal is in the
//! allow file (path, a tab, the literal as written: the follow-up list of old ones).
//!
//! usage: fmtlint [--allow FILE] [--write-allow] DIR...
//! --write-allow rewrites FILE with every literal found (after a deliberate review)

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const usage = "usage: fmtlint [--allow FILE] [--write-allow] DIR...\n";

/// Test-only files: their code never reaches a wasm build
const test_files = [_][]const u8{ "tests.zig", "compile_errors.zig" };

const Hit = struct { path: []const u8, line: usize, literal: []const u8 };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    var allow_path: []const u8 = "src/tools/fmtlint-allow.txt";
    var write_allow = false;
    var dirs: std.ArrayList([]const u8) = .empty;
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--write-allow")) {
            write_allow = true;
        } else if (std.mem.eql(u8, a, "--allow")) {
            i += 1;
            if (i == argv.len) fail("--allow needs a file", .{});
            allow_path = argv[i];
        } else if (std.mem.startsWith(u8, a, "--")) {
            fail("unknown option {s}", .{a});
        } else try dirs.append(arena, a);
    }
    if (dirs.items.len == 0) fail("", .{});

    var hits: std.ArrayList(Hit) = .empty;
    for (dirs.items) |d| try scanDir(io, arena, d, &hits);

    if (write_allow) {
        var text: Io.Writer.Allocating = .init(arena);
        try text.writer.writeAll("# fmtlint's allowed literals (src/tools/fmtlint.zig): path, tab, literal. The " ++
            "follow-up list: each costs wasm bytes where it reaches an island\n");
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        for (hits.items) |h| {
            const line = try std.fmt.allocPrint(arena, "{s}\t{s}\n", .{ h.path, h.literal });
            if ((try seen.getOrPut(arena, line)).found_existing) continue;
            try text.writer.writeAll(line);
        }
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = allow_path, .data = text.written() });
        std.debug.print("fmtlint: wrote {d} literals to {s}\n", .{ seen.count(), allow_path });
        return;
    }

    var allowed: std.StringHashMapUnmanaged(void) = .empty;
    const allow_text = Io.Dir.cwd().readFileAlloc(io, allow_path, arena, .limited(16 << 20)) catch "";
    var lines = std.mem.tokenizeScalar(u8, allow_text, '\n');
    while (lines.next()) |l| if (l.len > 0 and l[0] != '#') try allowed.put(arena, l, {});

    var bad: usize = 0;
    var used: std.StringHashMapUnmanaged(void) = .empty;
    for (hits.items) |h| {
        const key = try std.fmt.allocPrint(arena, "{s}\t{s}", .{ h.path, h.literal });
        if (allowed.contains(key)) {
            try used.put(arena, key, {});
            continue;
        }
        bad += 1;
        std.debug.print("{s}:{d}: {s} formats a number with std.fmt in code that can reach " ++
            "ui.wasm\n", .{ h.path, h.line, h.literal });
    }
    if (bad > 0) {
        std.debug.print(
            \\fmtlint: {d} new number format string(s): code in every family that reaches them,
            \\and std's formatter (~170 B gz) for each new int type. Use phrase.num(h, .int, v)
            \\or fmt.write(w, .int, v) (src/site/ui/fmt.zig), shared by all of ui; where the
            \\code never reaches a wasm island, mark the line `// fmt-ok: <why>`
            \\
        , .{bad});
        std.process.exit(1);
    }
    var stale: usize = 0;
    var it = allowed.keyIterator();
    while (it.next()) |k| if (!used.contains(k.*)) {
        stale += 1;
    };
    if (stale > 0) std.debug.print("fmtlint: {d} allowed literals no longer found: " ++
        "`zig build fmtlint -- --write-allow` to drop them\n", .{stale});
}

fn fail(comptime f: []const u8, args: anytype) noreturn {
    std.debug.print("fmtlint: " ++ f ++ "\n" ++ usage, args);
    std.process.exit(2);
}

fn scanDir(io: Io, arena: Allocator, path: []const u8, hits: *std.ArrayList(Hit)) !void {
    var dir = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err| fail("{s}: {t}", .{ path, err });
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    var files: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |e| {
        if (e.kind != .file or !std.mem.endsWith(u8, e.basename, ".zig")) continue;
        if (std.mem.endsWith(u8, e.basename, "_test.zig")) continue;
        if (for (test_files) |t| {
            if (std.mem.eql(u8, e.basename, t)) break true;
        } else false) continue;
        try files.append(arena, try std.fs.path.join(arena, &.{ path, e.path }));
    }
    std.mem.sort([]const u8, files.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lt);
    for (files.items) |f| {
        const src = try Io.Dir.cwd().readFileAllocOptions(io, f, arena, .limited(16 << 20), .of(u8), 0);
        try scan(arena, f, src, hits);
    }
}

/// Calls whose string arguments are never runtime code
const comptime_calls = [_][]const u8{ "comptimePrint", "@compileError", "@compileLog", "@embedFile", "@import" };

pub fn scan(arena: Allocator, path: []const u8, src: [:0]const u8, hits: *std.ArrayList(Hit)) !void {
    var t: std.zig.Tokenizer = .init(src);
    // Per open paren: whether it opens a comptime-only call
    var parens: std.ArrayList(bool) = .empty;
    var in_comptime_call: usize = 0;
    var prev: std.zig.Token = .{ .tag = .invalid, .loc = .{ .start = 0, .end = 0 } };
    // Brace depth where a test block opened, null outside one
    var test_depth: ?usize = null;
    var pending_test = false;
    var depth: usize = 0;
    while (true) {
        const tok = t.next();
        switch (tok.tag) {
            .eof => break,
            .keyword_test => pending_test = true,
            .l_brace => {
                if (pending_test and test_depth == null) test_depth = depth;
                pending_test = false;
                depth += 1;
            },
            .r_brace => {
                depth -|= 1;
                if (test_depth == depth) test_depth = null;
            },
            .l_paren => {
                const name = src[prev.loc.start..prev.loc.end];
                const ct = (prev.tag == .identifier or prev.tag == .builtin) and for (comptime_calls) |c| {
                    if (std.mem.eql(u8, name, c)) break true;
                } else false;
                try parens.append(arena, ct);
                if (ct) in_comptime_call += 1;
            },
            .r_paren => if (parens.pop()) |ct| {
                if (ct) in_comptime_call -= 1;
            },
            .string_literal, .multiline_string_literal_line => if (test_depth == null and in_comptime_call == 0) {
                const lit = std.mem.trimEnd(u8, src[tok.loc.start..tok.loc.end], "\r\n");
                if (numeric(lit) and !marked(src, tok.loc.start)) try hits.append(arena, .{
                    .path = path,
                    .line = std.mem.countScalar(u8, src[0..tok.loc.start], '\n') + 1,
                    .literal = lit,
                });
            },
            else => {},
        }
        prev = tok;
    }
}

/// src/site/ui/fmt.zig's Kind
const phrase_kinds = [_][]const u8{ "rate", "pct", "count", "points", "signed", "time", "int", "dec", "kilo", "text" };

/// A placeholder that prints a number: any but {s}, {t} (a tag's name), {c} (a byte),
/// {f} (a format method) and {*}, with an optional ? (optional) or [name] before the
/// specifier
pub fn numeric(lit: []const u8) bool {
    var k: usize = 0;
    while (std.mem.findScalarPos(u8, lit, k, '{')) |open| {
        if (open + 1 < lit.len and lit[open + 1] == '{') {
            k = open + 2;
            continue;
        }
        const close = std.mem.findScalarPos(u8, lit, open, '}') orelse return false;
        var spec = lit[open + 1 .. close];
        k = close + 1;
        if (open >= 2 and std.mem.eql(u8, lit[open - 2 .. open], "\\u")) continue;
        if (std.mem.startsWith(u8, spec, "[")) spec = spec[(std.mem.findScalar(u8, spec, ']') orelse continue) + 1 ..];
        if (std.mem.findScalar(u8, spec, ':')) |c| {
            // A phrase's typed hole ({n:count}, phrase.zig), formatted by fmt.write
            if (for (phrase_kinds) |kind| {
                if (std.mem.eql(u8, spec[c + 1 ..], kind)) break true;
            } else false) continue;
            spec = spec[0..c];
        }
        // Not a Zig placeholder: a JS or CSS brace pair, or text in braces
        if (std.mem.findAny(u8, spec, " ;,\"'(=") != null) continue;
        if (std.mem.startsWith(u8, spec, "?")) spec = spec[1..];
        if (spec.len == 1 and std.mem.findScalar(u8, "stcf*", spec[0]) != null) continue;
        return true;
    }
    return false;
}

/// `fmt-ok` in a comment on the literal's line
fn marked(src: []const u8, at: usize) bool {
    const end = std.mem.findScalarPos(u8, src, at, '\n') orelse src.len;
    const start = if (std.mem.findScalarLast(u8, src[0..at], '\n')) |n| n + 1 else 0;
    const line = src[start..end];
    const c = std.mem.find(u8, line, "//") orelse return false;
    return std.mem.find(u8, line[c..], "fmt-ok") != null;
}

test numeric {
    try std.testing.expect(numeric("\"{d}px\""));
    try std.testing.expect(numeric("\"{}\""));
    try std.testing.expect(numeric("\"{x:0>2}\""));
    try std.testing.expect(numeric("\"{[n]d}\""));
    try std.testing.expect(numeric("\"{?d}\""));
    try std.testing.expect(!numeric("\"{s} and {t}\""));
    try std.testing.expect(!numeric("\"{{d}}\""));
    try std.testing.expect(!numeric("\"a {s}{{x}}\""));
    try std.testing.expect(!numeric("\".a { color: red }\""));
    try std.testing.expect(!numeric("\"{n:count} games, {p:pct}\""));
    try std.testing.expect(numeric("\"{d:0>2}\""));
    try std.testing.expect(!numeric("\"\\u{2212}\""));
}

test scan {
    const src =
        \\const a = h.fmt("{d}px", .{n});
        \\const b = h.fmt("{s}", .{s});
        \\const c = std.fmt.comptimePrint("{d}", .{3});
        \\const d = h.fmt("{d}", .{n}); // fmt-ok: server only
        \\test "x" { _ = h.fmt("{d}", .{n}); }
        \\const e =
        \\    \\{d} games
        \\;
        \\fn f() void { @compileError("bad {d}"); }
    ;
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var hits: std.ArrayList(Hit) = .empty;
    try scan(arena.allocator(), "x.zig", src, &hits);
    try std.testing.expectEqual(2, hits.items.len);
    try std.testing.expectEqual(1, hits.items[0].line);
    try std.testing.expectEqual(7, hits.items[1].line);
}
