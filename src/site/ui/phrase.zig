//! Words beside each component: every visible string is a `plain` text or a `Phrase`
//! whose holes are typed by the formatter kind they name (`{an:count}`), checked against
//! the args at compile time and written by fmt.write, so "8,068 games" comes out one way
//! everywhere. Not one global strings file: it would be the most conflicted file in the
//! tree.
//!
//!     const W = struct {
//!         pub const title = plain("Champions");
//!         pub const games = Phrase("{n:count} games");
//!     };
//!     h.span(.{}, .{W.games.with(h, .{ .n = x.games })})
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");

pub fn Phrase(comptime src: []const u8) type {
    const segs = comptime parse(src);
    return struct {
        pub const source = src;

        pub fn with(h: *tree.H, args: anytype) tree.Text {
            const A = @TypeOf(args);
            comptime {
                for (@typeInfo(A).@"struct".field_names) |f| {
                    for (segs) |s| {
                        if (s.hole and std.mem.eql(u8, s.text, f)) break;
                    } else @compileError("phrase \"" ++ src ++ "\" has no hole {" ++ f ++ "}");
                }
            }
            var out: std.Io.Writer.Allocating = .init(h.mem);
            inline for (segs) |s| {
                if (!s.hole) {
                    out.writer.writeAll(s.text) catch {
                        h.oom = true;
                    };
                } else {
                    if (!@hasField(A, s.text)) @compileError("phrase \"" ++ src ++ "\": no value for {" ++ s.text ++ "}");
                    const v = @field(args, s.text);
                    if (comptime !fmt.accepts(s.kind, @TypeOf(v))) {
                        @compileError("phrase {" ++ s.text ++ ":" ++ @tagName(s.kind) ++ "} can't take " ++ @typeName(@TypeOf(v)));
                    }
                    fmt.write(&out.writer, s.kind, v) catch {
                        h.oom = true;
                    };
                }
            }
            return .{ .s = out.written() };
        }
    };
}

const Seg = struct { text: []const u8, hole: bool, kind: fmt.Kind = .text };

fn parse(comptime src: []const u8) []const Seg {
    comptime {
        var segs: []const Seg = &.{};
        var i: usize = 0;
        var lit: usize = 0;
        while (i < src.len) : (i += 1) {
            if (src[i] != '{') continue;
            const close = std.mem.findScalarPos(u8, src, i, '}') orelse @compileError("unclosed { in \"" ++ src ++ "\"");
            const colon = std.mem.findScalarPos(u8, src[0..close], i, ':') orelse @compileError("{" ++ src[i + 1 .. close] ++ "} needs a kind: {name:count}");
            if (i > lit) segs = segs ++ [_]Seg{.{ .text = src[lit..i], .hole = false }};
            const kind = std.meta.stringToEnum(fmt.Kind, src[colon + 1 .. close]) orelse @compileError("no kind " ++ src[colon + 1 .. close]);
            segs = segs ++ [_]Seg{.{ .text = src[i + 1 .. colon], .hole = true, .kind = kind }};
            i = close;
            lit = close + 1;
        }
        if (lit < src.len) segs = segs ++ [_]Seg{.{ .text = src[lit..], .hole = false }};
        return segs;
    }
}

/// A bare number as text, through the one formatter
pub fn num(h: *tree.H, comptime k: fmt.Kind, v: anytype) tree.Text {
    var out: std.Io.Writer.Allocating = .init(h.mem);
    fmt.write(&out.writer, k, v) catch {
        h.oom = true;
    };
    return .{ .s = out.written() };
}

/// A fixed catalogue word or label: `pub const title = plain("Champions");`
pub fn plain(comptime s: []const u8) tree.Text {
    return .{ .s = s };
}

test "a phrase formats its typed holes" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: tree.H = .init(arena.allocator(), &t);
    const line = Phrase("16.20 {a:rate} of {an:count} → 16.21 {c:rate} of {cn:count}");
    const s = line.with(&h, .{ .a = @as(f32, 53.4), .an = @as(u32, 8068), .c = @as(f32, 50.5), .cn = @as(u32, 1617) });
    try std.testing.expectEqualStrings("16.20 53.4% of 8,068 → 16.21 50.5% of 1,617", s.s);
    try std.testing.expectEqualStrings("{n:count} games", Phrase("{n:count} games").source);
}
