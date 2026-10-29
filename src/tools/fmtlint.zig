//! fmtlint: number formatting through std.fmt in code that can compile to ui.wasm. Each
//! call site is code of its own in every family that reaches it, and each int type
//! printed adds std's formatter for that type (printValue + printIntAny, ~170 B gz):
//! d803924c put three families over their budget with two `{d}`s in a shared component.
//! Text through {s} and {t} is cheap; numbers go through phrase.num / fmt.write
//! (src/site/ui/fmt.zig). src/tools/wasmsize --numbers shows what a family carries.
//!
//! Flags, outside tests, comptimePrint and @compileError, string literals with such a
//! placeholder and calls of std's number formatters (printIntAny, printFloat, ...),
//! unless the line says `fmt-ok` in a comment. The allow file holds the old ones, the
//! follow-up list: path, tab, count, tab, the literal or call as written. A file with
//! more copies than its count fails.
//!
//! Scans every file in each DIR and what they import from other modules: with --module
//! NAME=ROOT, `@import("NAME").decl` leads to the file ROOT's decl imports (all of
//! ROOT's imports when it is anything else), then on through those files' imports.
//! Whole files, as wasm builds take only what they call: a file reached by import
//! marks its lines that wasm never calls.
//!
//! usage: fmtlint [--allow FILE] [--write-allow] [--module NAME=ROOT]... DIR...
//! --write-allow rewrites FILE with every hit found (after a deliberate review)

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const usage = "usage: fmtlint [--allow FILE] [--write-allow] [--module NAME=ROOT]... DIR...\n";

/// Test-only files: their code never reaches a wasm build
const test_files = [_][]const u8{ "tests.zig", "compile_errors.zig" };

fn testFile(path: []const u8) bool {
    const base = std.fs.path.basename(path);
    if (std.mem.endsWith(u8, base, "_test.zig")) return true;
    for (test_files) |t| if (std.mem.eql(u8, base, t)) return true;
    return false;
}

const Hit = struct { path: []const u8, line: usize, literal: []const u8 };

/// `@import(name)`, with the decl taken from it right away (`@import("core").score`)
const Import = struct { name: []const u8, decl: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    var allow_path: []const u8 = "src/tools/fmtlint-allow.txt";
    var write_allow = false;
    var dirs: std.ArrayList([]const u8) = .empty;
    var l: Lint = .{ .io = io, .arena = arena };
    var i: usize = 1;
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--write-allow")) {
            write_allow = true;
        } else if (std.mem.eql(u8, a, "--allow") or std.mem.eql(u8, a, "--module")) {
            i += 1;
            if (i == argv.len) fail("{s} needs a value", .{a});
            if (a[2] == 'a') {
                allow_path = argv[i];
            } else {
                const name, const root = std.mem.cutScalar(u8, argv[i], '=') orelse fail("--module: NAME=ROOT", .{});
                try l.modules.put(arena, name, root);
            }
        } else if (std.mem.startsWith(u8, a, "--")) {
            fail("unknown option {s}", .{a});
        } else try dirs.append(arena, a);
    }
    if (dirs.items.len == 0) fail("", .{});

    for (dirs.items) |d| try l.addDir(d);
    try l.run();
    const hits = l.hits.items;
    std.mem.sort(Hit, hits, {}, struct {
        fn lt(_: void, a: Hit, b: Hit) bool {
            return switch (std.mem.order(u8, a.path, b.path)) {
                .lt => true,
                .gt => false,
                .eq => a.line < b.line,
            };
        }
    }.lt);
    // Path, tab, literal to its count, in order of the first hit
    var found: std.StringArrayHashMapUnmanaged(u32) = .empty;
    for (hits) |h| {
        const key = try std.fmt.allocPrint(arena, "{s}\t{s}", .{ h.path, h.literal });
        (try found.getOrPutValue(arena, key, 0)).value_ptr.* += 1;
    }

    if (write_allow) {
        var text: Io.Writer.Allocating = .init(arena);
        try text.writer.writeAll("# fmtlint's allowed hits (src/tools/fmtlint.zig): path, tab, count, tab, literal " ++
            "or call. The follow-up list: each costs wasm bytes where it reaches an island\n");
        for (found.keys(), found.values()) |key, n| {
            const path, const lit = std.mem.cutScalar(u8, key, '\t').?;
            try text.writer.print("{s}\t{d}\t{s}\n", .{ path, n, lit });
        }
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = allow_path, .data = text.written() });
        std.debug.print("fmtlint: wrote {d} hits ({d} lines) to {s}\n", .{ hits.len, found.count(), allow_path });
        return;
    }

    var allowed: std.StringHashMapUnmanaged(u32) = .empty;
    const allow_text = Io.Dir.cwd().readFileAlloc(io, allow_path, arena, .limited(16 << 20)) catch "";
    var lines = std.mem.tokenizeScalar(u8, allow_text, '\n');
    while (lines.next()) |line| {
        if (line[0] == '#') continue;
        const path, const rest = std.mem.cutScalar(u8, line, '\t') orelse badAllow(allow_path, line);
        const count, const lit = std.mem.cutScalar(u8, rest, '\t') orelse badAllow(allow_path, line);
        const n = std.fmt.parseInt(u32, count, 10) catch badAllow(allow_path, line);
        try allowed.put(arena, try std.fmt.allocPrint(arena, "{s}\t{s}", .{ path, lit }), n);
    }

    var bad: usize = 0;
    for (found.keys(), found.values()) |key, n| {
        const ok = allowed.get(key) orelse 0;
        if (n <= ok) continue;
        bad += n - ok;
        const path, const lit = std.mem.cutScalar(u8, key, '\t').?;
        for (hits) |h| if (std.mem.eql(u8, h.path, path) and std.mem.eql(u8, h.literal, lit)) {
            std.debug.print("{s}:{d}: {s} formats a number with std.fmt in code that can reach " ++
                "ui.wasm", .{ h.path, h.line, h.literal });
            if (ok > 0) std.debug.print(" ({d} in the file, {d} allowed)", .{ n, ok });
            std.debug.print("\n", .{});
        };
    }
    if (bad > 0) {
        std.debug.print(
            \\fmtlint: {d} new number format(s): code in every family that reaches them, and
            \\std's formatter (~170 B gz) for each new int type. Use phrase.num(h, .int, v) or
            \\fmt.write(w, .int, v) (src/site/ui/fmt.zig), shared by all of ui; where the code
            \\never reaches a wasm island, mark the line `// fmt-ok: <why>`
            \\
        , .{bad});
        std.process.exit(1);
    }
    var stale: usize = 0;
    var it = allowed.iterator();
    while (it.next()) |e| stale += e.value_ptr.* -| (found.get(e.key_ptr.*) orelse 0);
    if (stale > 0) std.debug.print("fmtlint: {d} allowed hits no longer found: " ++
        "`zig build fmtlint -- --write-allow` to drop them\n", .{stale});
}

fn badAllow(path: []const u8, line: []const u8) noreturn {
    fail("{s}: not path, tab, count, tab, literal: {s}", .{ path, line });
}

fn fail(comptime f: []const u8, args: anytype) noreturn {
    std.debug.print("fmtlint: " ++ f ++ "\n" ++ usage, args);
    std.process.exit(2);
}

/// The files to scan: each DIR's, then what they import, each once
const Lint = struct {
    io: Io,
    arena: Allocator,
    modules: std.StringHashMapUnmanaged([]const u8) = .empty,
    files: std.StringArrayHashMapUnmanaged(void) = .empty,
    hits: std.ArrayList(Hit) = .empty,

    fn addDir(l: *Lint, path: []const u8) !void {
        var dir = Io.Dir.cwd().openDir(l.io, path, .{ .iterate = true }) catch |err| fail("{s}: {t}", .{ path, err });
        defer dir.close(l.io);
        var walker = try dir.walk(l.arena);
        defer walker.deinit();
        var files: std.ArrayList([]const u8) = .empty;
        while (try walker.next(l.io)) |e| {
            if (e.kind != .file or !std.mem.endsWith(u8, e.basename, ".zig") or testFile(e.basename)) continue;
            try files.append(l.arena, try std.fs.path.resolvePosix(l.arena, &.{ path, e.path }));
        }
        std.mem.sort([]const u8, files.items, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lt);
        for (files.items) |f| try l.files.put(l.arena, f, {});
    }

    fn add(l: *Lint, path: []const u8) !void {
        if (!testFile(path)) try l.files.put(l.arena, path, {});
    }

    /// Scans the files, adding what they import as it goes
    fn run(l: *Lint) !void {
        var k: usize = 0;
        while (k < l.files.count()) : (k += 1) {
            const path = l.files.keys()[k];
            const src = try l.read(path);
            var imports: std.ArrayList(Import) = .empty;
            try scan(l.arena, path, src, &l.hits, &imports);
            for (imports.items) |imp| try l.follow(path, imp);
        }
    }

    fn read(l: *Lint, path: []const u8) ![:0]const u8 {
        return Io.Dir.cwd().readFileAllocOptions(l.io, path, l.arena, .limited(16 << 20), .of(u8), 0) catch |err|
            fail("{s}: {t}", .{ path, err });
    }

    fn follow(l: *Lint, from: []const u8, imp: Import) !void {
        if (std.mem.endsWith(u8, imp.name, ".zig")) return l.add(try relative(l.arena, from, imp.name));
        const root = l.modules.get(imp.name) orelse return;
        if (imp.decl) |d| {
            if (declImport(try l.read(root), d)) |file| return l.add(try relative(l.arena, root, file));
        }
        try l.add(root);
    }
};

fn relative(arena: Allocator, from: []const u8, name: []const u8) ![]const u8 {
    return std.fs.path.resolvePosix(arena, &.{ std.fs.path.dirnamePosix(from) orelse ".", name });
}

/// The file in `pub const decl = @import(<a .zig file>);`, null when decl is anything else
fn declImport(src: [:0]const u8, decl: []const u8) ?[]const u8 {
    var t: std.zig.Tokenizer = .init(src);
    const want = [_]std.zig.Token.Tag{
        .keyword_const, .identifier, .equal, .builtin, .l_paren, .string_literal, .r_paren,
    };
    var at: usize = 0;
    var file: []const u8 = "";
    while (true) {
        const tok = t.next();
        if (tok.tag == .eof) return null;
        const text = src[tok.loc.start..tok.loc.end];
        const ok = tok.tag == want[at] and switch (at) {
            1 => std.mem.eql(u8, text, decl),
            3 => std.mem.eql(u8, text, "@import"),
            5 => blk: {
                file = text[1 .. text.len - 1];
                break :blk std.mem.endsWith(u8, file, ".zig");
            },
            else => true,
        };
        if (ok) {
            at += 1;
            if (at == want.len) return file;
        } else at = @intFromBool(tok.tag == .keyword_const);
    }
}

/// Calls whose string arguments are never runtime code
const comptime_calls = [_][]const u8{ "comptimePrint", "@compileError", "@compileLog", "@embedFile", "@import" };

/// std's number formatters called directly: Writer's and std.fmt's (`w.printIntAny(`)
const number_calls = [_][]const u8{
    "printInt", "printIntAny", "printFloat", "printFloatHex", "printFloatHexOptions", "printValue", "printByteSize",
};
/// std.fmt.float's, by their generic names only after `float.`
const float_calls = [_][]const u8{ "render", "formatDecimal", "formatScientific" };

fn among(name: []const u8, list: []const []const u8) bool {
    for (list) |n| if (std.mem.eql(u8, name, n)) return true;
    return false;
}

pub fn scan(
    arena: Allocator,
    path: []const u8,
    src: [:0]const u8,
    hits: *std.ArrayList(Hit),
    imports: *std.ArrayList(Import),
) !void {
    var t: std.zig.Tokenizer = .init(src);
    // Per open paren: whether it opens a comptime-only call
    var parens: std.ArrayList(bool) = .empty;
    var in_comptime_call: usize = 0;
    const none: std.zig.Token = .{ .tag = .invalid, .loc = .{ .start = 0, .end = 0 } };
    // The last three tokens, newest first
    var back: [3]std.zig.Token = @splat(none);
    const prev = &back[0];
    // Brace depth where a test block opened, null outside one
    var test_depth: ?usize = null;
    var pending_test = false;
    var depth: usize = 0;
    // An @import seen up to: 1 the builtin, 2 its paren, 3 the name, 4 the closing paren,
    // 5 a period after it
    var imp_stage: u3 = 0;
    var imp: Import = .{ .name = "" };
    while (true) {
        const tok = t.next();
        const text = src[tok.loc.start..tok.loc.end];
        const code = test_depth == null and !pending_test;
        imp_stage = switch (imp_stage) {
            0 => 0,
            1 => if (tok.tag == .l_paren) 2 else 0,
            2 => if (tok.tag == .string_literal) blk: {
                imp = .{ .name = text[1 .. text.len - 1] };
                break :blk 3;
            } else 0,
            3 => if (tok.tag == .r_paren) 4 else 0,
            4, 5 => blk: {
                if (imp_stage == 4 and tok.tag == .period) break :blk 5;
                if (imp_stage == 5 and tok.tag == .identifier) imp.decl = text;
                if (code) try imports.append(arena, imp);
                break :blk 0;
            },
            else => unreachable,
        };
        switch (tok.tag) {
            .eof => break,
            .keyword_test => pending_test = true,
            .builtin => if (std.mem.eql(u8, text, "@import")) {
                imp_stage = 1;
            },
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
                const ct = (prev.tag == .identifier or prev.tag == .builtin) and among(name, &comptime_calls);
                if (code and in_comptime_call == 0 and prev.tag == .identifier and back[1].tag == .period and
                    !marked(src, tok.loc.start))
                {
                    const float = back[2].tag == .identifier and
                        std.mem.eql(u8, src[back[2].loc.start..back[2].loc.end], "float") and among(name, &float_calls);
                    if (float or among(name, &number_calls)) try hits.append(arena, .{
                        .path = path,
                        .line = std.mem.countScalar(u8, src[0..tok.loc.start], '\n') + 1,
                        .literal = src[(if (float) back[2] else prev.*).loc.start..tok.loc.end],
                    });
                }
                try parens.append(arena, ct);
                if (ct) in_comptime_call += 1;
            },
            .r_paren => if (parens.pop()) |ct| {
                if (ct) in_comptime_call -= 1;
            },
            // A test's name (after `test`, before its brace) is not code either
            .string_literal, .multiline_string_literal_line => if (code and in_comptime_call == 0) {
                const lit = std.mem.trimEnd(u8, text, "\r\n");
                if (numeric(lit) and !marked(src, tok.loc.start)) try hits.append(arena, .{
                    .path = path,
                    .line = std.mem.countScalar(u8, src[0..tok.loc.start], '\n') + 1,
                    .literal = lit,
                });
            },
            else => {},
        }
        back[2] = back[1];
        back[1] = back[0];
        back[0] = tok;
    }
}

/// src/site/ui/fmt.zig's Kind
const phrase_kinds = [_][]const u8{ "rate", "pct", "count", "points", "signed", "time", "int", "dec", "kilo", "text" };

/// A placeholder that prints a number: any but {s}, {t} (a tag's name), {c} (a byte),
/// {f} (a format method) and {*}, with an optional ? (optional) or [name] before the
/// specifier. Braces around anything else (JS, CSS, `{#id}` in markdown) are text
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
        if (!specifier(spec)) continue;
        if (std.mem.startsWith(u8, spec, "?")) spec = spec[1..];
        if (spec.len == 1 and std.mem.findScalar(u8, "stcf*", spec[0]) != null) continue;
        return true;
    }
    return false;
}

/// Zig's specifiers are letters and digits (d, x, any, b64), *, and ? or ! before one
fn specifier(spec: []const u8) bool {
    for (spec) |c| if (!std.ascii.isAlphanumeric(c) and c != '*' and c != '?' and c != '!') return false;
    return true;
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
    try std.testing.expect(!numeric("\"## Early or late {#lean}\""));
    try std.testing.expect(!numeric("\"function f() {return 1}\""));
    try std.testing.expect(numeric("\"{any}\""));
    try std.testing.expect(numeric("\"{d:.3}\""));
}

test scan {
    const src =
        \\const a = h.fmt("{d}px", .{n});
        \\const b = h.fmt("{s}", .{s});
        \\const c = std.fmt.comptimePrint("{d}", .{3});
        \\const d = h.fmt("{d}", .{n}); // fmt-ok: server only
        \\test "x" { _ = h.fmt("{d}", .{n}); _ = @import(T); }
        \\const e =
        \\    \\{d} games
        \\;
        \\fn f() void { @compileError("bad {d}"); }
        \\test "heading ids: {#name} and {d} in a name" {}
        \\const g = h.fmt("{#x} {d:.2}", .{v});
        \\fn printInt(x: u8) void { try w.printIntAny(x, 10, .lower, .{}); }
        \\const n = std.fmt.float.render(&buf, v, .{}); const m = std.fmt.printInt(&buf, 1, 10, .lower, .{});
        \\const k = render(x); w.printFloat(v, .{}); // fmt-ok: server only
        \\const ds = @import("core").draftscore;
        \\const core = @import("core");
        \\
    ++ "const r = @import(\"roles.zig\").Role;\n" ++
        // The pre-commit hook reads an unescaped import as a file this commit needs
        "test \"y\" { _ = @import(\"t.zig\"); }";
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var hits: std.ArrayList(Hit) = .empty;
    var imports: std.ArrayList(Import) = .empty;
    try scan(arena.allocator(), "x.zig", src, &hits, &imports);
    const want = [_]struct { usize, []const u8 }{
        .{ 1, "\"{d}px\"" },
        .{ 7, "\\\\{d} games" },
        .{ 11, "\"{#x} {d:.2}\"" },
        .{ 12, "printIntAny(" },
        .{ 13, "float.render(" },
        .{ 13, "printInt(" },
    };
    try std.testing.expectEqual(want.len, hits.items.len);
    for (want, hits.items) |w, h| {
        try std.testing.expectEqual(w[0], h.line);
        try std.testing.expectEqualStrings(w[1], h.literal);
    }
    try std.testing.expectEqual(3, imports.items.len);
    try std.testing.expectEqualStrings("core", imports.items[0].name);
    try std.testing.expectEqualStrings("draftscore", imports.items[0].decl.?);
    try std.testing.expectEqual(null, imports.items[1].decl);
    try std.testing.expectEqualStrings("roles.zig", imports.items[2].name);
}

test declImport {
    const root =
        "pub const roles = @import(\"roles.zig\");\n" ++
        "pub const Role = roles.Role;\n" ++
        "pub const const_ = 1; pub const score = @import(\"score.zig\");\n";
    try std.testing.expectEqualStrings("roles.zig", declImport(root, "roles").?);
    try std.testing.expectEqualStrings("score.zig", declImport(root, "score").?);
    try std.testing.expectEqual(null, declImport(root, "Role"));
    try std.testing.expectEqual(null, declImport(root, "draftscore"));
}
