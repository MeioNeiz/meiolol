//! Arrays derived from a snapshot that cost minutes to rebuild (champcomp's ratings
//! offsets, comp_stats.tsv by row), kept in DIR/.cache/SNAP/NAME beside SNAP: hidden, so
//! snapshot listings and lab-run's snapshot hash don't see it. One file per NAME, its key
//! in the header: a different key is a miss, and the next save replaces it. Saved
//! through a temp file (readers see none or a whole one); a save that fails only logs

const std = @import("std");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.snapcache);

const magic = "meiolol-lab snapcache 1\n";

fn path(gpa: Allocator, snap: []const u8, name: []const u8) ![]u8 {
    const parent = std.fs.path.dirname(snap) orelse ".";
    return std.fs.path.join(gpa, &.{ parent, ".cache", std.fs.path.basename(snap), name });
}

/// Wyhash of this executable: a key part for anything any of the code can change
pub fn exeHash(gpa: Allocator, io: Io) !u64 {
    const exe = try std.process.executablePathAlloc(io, gpa);
    defer gpa.free(exe);
    const bytes = try Io.Dir.cwd().readFileAlloc(io, exe, gpa, .unlimited);
    defer gpa.free(bytes);
    return std.hash.Wyhash.hash(0, bytes);
}

/// SNAP/NAME's size and mtime into h (zeros when it's missing)
pub fn stamp(gpa: Allocator, io: Io, h: *std.hash.Wyhash, snap: []const u8, name: []const u8) !void {
    const p = try std.fs.path.join(gpa, &.{ snap, name });
    defer gpa.free(p);
    var size: u64 = 0;
    var mtime: i64 = 0;
    if (Io.Dir.cwd().statFile(io, p, .{})) |st| {
        size = st.size;
        mtime = @intCast(st.mtime.toSeconds());
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    h.update(std.mem.asBytes(&size));
    h.update(std.mem.asBytes(&mtime));
}

/// Calls body(ctx, reader) on NAME's bytes when its key is KEY; false when missing, keyed
/// otherwise or short (body's EndOfStream)
pub fn load(gpa: Allocator, io: Io, snap: []const u8, name: []const u8, key: u64, ctx: anytype, comptime body: anytype) !bool {
    const p = try path(gpa, snap, name);
    defer gpa.free(p);
    var file = Io.Dir.cwd().openFile(io, p, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close(io);
    var buf: [256 * 1024]u8 = undefined;
    var fr = file.reader(io, &buf);
    const r = &fr.interface;
    var head: [magic.len + 8]u8 = undefined;
    r.readSliceAll(&head) catch |err| switch (err) {
        error.EndOfStream => return false,
        error.ReadFailed => return fr.err.?,
    };
    if (!std.mem.eql(u8, head[0..magic.len], magic)) return false;
    if (std.mem.readInt(u64, head[magic.len..], .little) != key) {
        log.info("{s}: another key; rebuilding", .{p});
        return false;
    }
    body(ctx, r) catch |err| switch (err) {
        error.EndOfStream => {
            log.info("{s}: short; rebuilding", .{p});
            return false;
        },
        error.ReadFailed => return fr.err.?,
        else => |e| return e,
    };
    return true;
}

/// Writes NAME with KEY and body(ctx, writer)'s bytes; a failure is logged, not returned
pub fn save(gpa: Allocator, io: Io, snap: []const u8, name: []const u8, key: u64, ctx: anytype, comptime body: anytype) void {
    saveOrFail(gpa, io, snap, name, key, ctx, body) catch |err|
        log.info("{s}/{s}: not cached ({t})", .{ snap, name, err });
}

fn saveOrFail(gpa: Allocator, io: Io, snap: []const u8, name: []const u8, key: u64, ctx: anytype, comptime body: anytype) !void {
    const p = try path(gpa, snap, name);
    defer gpa.free(p);
    var af = try Io.Dir.cwd().createFileAtomic(io, p, .{ .make_path = true, .replace = true });
    defer af.deinit(io);
    var buf: [256 * 1024]u8 = undefined;
    var fw = af.file.writer(io, &buf);
    const w = &fw.interface;
    var k: [8]u8 = undefined;
    std.mem.writeInt(u64, &k, key, .little);
    w.writeAll(magic) catch return fw.err.?;
    w.writeAll(&k) catch return fw.err.?;
    body(ctx, w) catch |err| switch (err) {
        error.WriteFailed => return fw.err.?,
        else => |e| return e,
    };
    w.flush() catch return fw.err.?;
    try af.replace(io);
}

test "saved bytes load under their key only" {
    const testing = std.testing;
    const io = testing.io;
    const gpa = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const snap = try std.fmt.allocPrint(gpa, ".zig-cache/tmp/{s}/snap-x", .{&tmp.sub_path});
    defer gpa.free(snap);
    const xs = [_]f64{ 1.5, -2, std.math.nan(f64) };
    const Put = struct {
        fn f(v: []const f64, w: *Io.Writer) !void {
            try w.writeAll(std.mem.sliceAsBytes(v));
        }
    };
    const Get = struct {
        fn f(v: []f64, r: *Io.Reader) !void {
            try r.readSliceAll(std.mem.sliceAsBytes(v));
        }
    };
    var got: [3]f64 = undefined;
    try testing.expect(!try load(gpa, io, snap, "o", 7, got[0..], Get.f));
    save(gpa, io, snap, "o", 7, xs[0..], Put.f);
    try testing.expect(try load(gpa, io, snap, "o", 7, got[0..], Get.f));
    try testing.expectEqualSlices(u8, std.mem.sliceAsBytes(xs[0..]), std.mem.sliceAsBytes(got[0..]));
    try testing.expect(!try load(gpa, io, snap, "o", 8, got[0..], Get.f));
    var more: [4]f64 = undefined;
    try testing.expect(!try load(gpa, io, snap, "o", 7, more[0..], Get.f));
}
