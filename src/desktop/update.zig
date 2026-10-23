//! The desktop app keeping itself current from meio.lol (J19): its statistics, lane
//! curves and its own exe. update.signed in the update directory lists each file's name,
//! SHA-256 and size, signed by the box's data key; the exe's entry also carries its
//! release version and the release key's signature (sign.zig). A file whose local copy
//! differs is downloaded beside it as .part, checked, then renamed over it. Windows can't overwrite a running exe but can rename it:
//! it becomes meiolol-desktop.old.exe (kept for a manual rollback) and the new one takes
//! its name, so the next start runs it.
//! Until the production key the directory is behind the admin login (Product rules:
//! nothing public on the personal key); the app sends the key in update.key beside it,
//! which nginx accepts for that directory only (docs/hosting.md). No update.key: no
//! updates, the app uses whatever files are beside it.

const builtin = @import("builtin");
const std = @import("std");
const Io = std.Io;
const sign = @import("sign.zig");

pub const default_base = "https://meio.lol/admin/desktop/";
pub const key_file = "update.key";
pub const old_exe = "meiolol-desktop.old.exe";
pub const exe_name = "meiolol-desktop.exe";
const key_header = "x-meiolol-desktop";

const Manifest = struct {
    patch: []const u8,
    files: []const File,

    const File = struct {
        name: []const u8,
        sha256: []const u8,
        bytes: u64,
        /// The exe's: release version and the release key's signature
        version: u64 = 0,
        sig: []const u8 = "",
    };
};

pub const Result = struct {
    /// Stats or curves replaced: load them again
    data: bool = false,
    /// A new exe is in place for the next start
    exe: bool = false,
};

pub const Options = struct {
    gpa: std.mem.Allocator,
    io: Io,
    /// Where the exe and its data files live
    dir: Io.Dir,
    /// The running exe's file name in `dir`; null leaves the exe alone
    exe: ?[]const u8,
    /// Ends in a slash
    base: []const u8 = default_base,
    key: []const u8,
    /// The running exe's release (build option desktop-version): an exe of the same or
    /// an older release is never installed, so an old signed one can't be served again.
    /// 0, unreleased builds, takes any signed exe
    version: u64 = 0,
    keys: sign.Keys = sign.shipped,
};

/// The key in update.key in `dir`, trimmed; null when there is none
pub fn readKey(arena: std.mem.Allocator, io: Io, dir: Io.Dir) ?[]const u8 {
    const raw = dir.readFileAlloc(io, key_file, arena, .limited(4096)) catch return null;
    const key = std.mem.trim(u8, raw, " \t\r\n");
    return if (key.len > 0) key else null;
}

/// One check: every listed file whose local copy differs is replaced
pub fn run(o: Options) !Result {
    var arena_state: std.heap.ArenaAllocator = .init(o.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var http: std.http.Client = .{ .allocator = o.gpa, .io = o.io };
    defer http.deinit();
    const headers = [_]std.http.Header{.{ .name = key_header, .value = o.key }};
    var u: Updater = .{ .o = o, .http = &http, .headers = &headers };

    var body: Io.Writer.Allocating = .init(arena);
    try u.get(sign.manifest_name, &body.writer);
    const json = try sign.openManifest(body.written(), o.keys.data);
    const manifest = try std.json.parseFromSliceLeaky(Manifest, arena, json, .{
        .ignore_unknown_fields = true,
    });
    if (!validPatch(manifest.patch)) return error.BadManifest;

    var result: Result = .{};
    for (manifest.files) |f| {
        const kind: enum { stats, curves, exe } = if (std.mem.eql(u8, f.name, "stats.bin"))
            .stats
        else if (std.mem.eql(u8, f.name, "recent-curves.bin"))
            .curves
        else if (std.mem.eql(u8, f.name, exe_name) and o.exe != null)
            .exe
        else
            continue;
        const local = switch (kind) {
            .stats => try arena.print("stats-{s}.bin", .{manifest.patch}),
            .curves => f.name,
            .exe => o.exe.?,
        };
        if (f.sha256.len != 64) return error.BadManifest;
        if (kind == .exe) {
            if (o.version != 0 and f.version <= o.version) continue;
            try sign.verifyExe(o.keys.release, f.sig, f.version, f.sha256, f.bytes);
        }
        if (u.hash(local)) |have| {
            if (std.ascii.eqlIgnoreCase(&have.hex, f.sha256)) continue;
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        }

        // After a swap in this session the running image is old_exe, which Windows won't
        // delete or replace: the new exe waits for a restart
        if (kind == .exe) o.dir.deleteFile(o.io, old_exe) catch |err| switch (err) {
            error.FileNotFound => {},
            else => continue,
        };
        const part = try arena.print("{s}.part", .{local});
        try u.download(f.name, part);
        const got = u.hash(part) catch |err| {
            o.dir.deleteFile(o.io, part) catch {};
            return err;
        };
        if (!std.ascii.eqlIgnoreCase(&got.hex, f.sha256) or got.bytes != f.bytes) {
            o.dir.deleteFile(o.io, part) catch {};
            return error.HashMismatch;
        }
        if (kind == .exe) {
            try renameExe(arena, o.io, o.dir, local, old_exe);
            o.dir.rename(part, o.dir, local, o.io) catch |err| {
                renameExe(arena, o.io, o.dir, old_exe, local) catch {};
                return err;
            };
            result.exe = true;
        } else {
            try o.dir.rename(part, o.dir, local, o.io);
            result.data = true;
            if (kind == .stats) u.dropOtherStats(local);
        }
    }
    return result;
}

extern "kernel32" fn MoveFileExW(
    from: [*:0]const u16,
    to: [*:0]const u16,
    flags: u32,
) callconv(.winapi) std.os.windows.BOOL;

/// std's rename opens the source for writing too, which the running exe refuses
/// (FileBusy, checked on Windows 11); MoveFileExW asks for delete access only
pub fn renameExe(arena: std.mem.Allocator, io: Io, dir: Io.Dir, from: []const u8, to: []const u8) !void {
    if (builtin.target.os.tag != .windows) return dir.rename(from, dir, to, io);
    var buf: [Io.Dir.max_path_bytes]u8 = undefined;
    const path = buf[0..try dir.realPath(io, &buf)];
    const wide = std.unicode.wtf8ToWtf16LeAllocZ;
    const from_w = try wide(arena, try std.fs.path.join(arena, &.{ path, from }));
    const to_w = try wide(arena, try std.fs.path.join(arena, &.{ path, to }));
    const replace_existing = 1;
    if (!MoveFileExW(from_w, to_w, replace_existing).toBool()) return error.RenameFailed;
}

/// Digits and dots only: it becomes part of a file name
fn validPatch(patch: []const u8) bool {
    if (patch.len == 0 or patch.len > 16) return false;
    for (patch) |c| if (!std.ascii.isDigit(c) and c != '.') return false;
    return true;
}

const Updater = struct {
    o: Options,
    http: *std.http.Client,
    headers: []const std.http.Header,

    fn get(u: *Updater, name: []const u8, w: *Io.Writer) !void {
        var url_buf: [512]u8 = undefined;
        const url = try std.mem.print(&url_buf, "{s}{s}", .{ u.o.base, name });
        const res = try u.http.fetch(.{
            .location = .{ .url = url },
            .response_writer = w,
            // Not privileged_headers, which std 0.17 never sends; no redirects instead, so
            // the key goes to no other host
            .extra_headers = u.headers,
            .redirect_behavior = .unhandled,
        });
        switch (res.status) {
            .ok => {},
            .unauthorized, .forbidden => return error.Unauthorized,
            .not_found => return error.NotFound,
            else => {
                std.log.warn("{s}: HTTP {d}", .{ name, @backingInt(res.status) });
                return error.HttpStatus;
            },
        }
    }

    /// Into `part`, removed again on failure
    fn download(u: *Updater, name: []const u8, part: []const u8) !void {
        const io = u.o.io;
        var file = try u.o.dir.createFile(io, part, .{});
        var buf: [64 * 1024]u8 = undefined;
        var fw = file.writer(io, &buf);
        const ok = if (u.get(name, &fw.interface)) fw.interface.flush() else |err| err;
        file.close(io);
        ok catch |err| {
            u.o.dir.deleteFile(io, part) catch {};
            return err;
        };
    }

    const Hash = struct { hex: [64]u8, bytes: u64 };

    fn hash(u: *Updater, name: []const u8) !Hash {
        const io = u.o.io;
        var file = try u.o.dir.openFile(io, name, .{});
        defer file.close(io);
        var buf: [64 * 1024]u8 = undefined;
        var r = file.reader(io, &buf);
        var h: std.crypto.hash.sha2.Sha256 = .init(.{});
        var bytes: u64 = 0;
        var chunk: [64 * 1024]u8 = undefined;
        while (true) {
            const n = try r.interface.readSliceShort(&chunk);
            if (n == 0) break;
            h.update(chunk[0..n]);
            bytes += n;
        }
        return .{ .hex = std.fmt.bytesToHex(h.finalResult(), .lower), .bytes = bytes };
    }

    /// Older patches' stats files: the app reads the newest, the rest only take space
    fn dropOtherStats(u: *Updater, keep: []const u8) void {
        const io = u.o.io;
        var dir = u.o.dir.openDir(io, ".", .{ .iterate = true }) catch return;
        defer dir.close(io);
        var it = dir.iterate();
        while (it.next(io) catch null) |entry| {
            const name = entry.name;
            if (entry.kind != .file or std.mem.eql(u8, name, keep)) continue;
            if (!std.mem.startsWith(u8, name, "stats-") or !std.mem.endsWith(u8, name, ".bin")) continue;
            dir.deleteFile(io, name) catch {};
        }
    }
};

test {
    _ = sign;
}

const httpd = @import("../httpd.zig");

/// Serves the files in `dir` under /d/ to requests carrying the key "k"
const TestServer = struct {
    dir: Io.Dir,

    fn serve(t: *TestServer, s: *Io.net.Server) void {
        httpd.accept(.update_test, std.testing.io, s, t, connection);
    }
    fn connection(t: *TestServer, stream: Io.net.Stream) void {
        httpd.requests(.update_test, std.testing.io, stream, t, handle, .path);
    }
    fn handle(t: *TestServer, r: *std.http.Server.Request) !void {
        var it = r.iterateHeaders();
        const key_ok = while (it.next()) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, key_header)) break std.mem.eql(u8, h.value, "k");
        } else false;
        if (!key_ok) return r.respond("", .{ .status = .unauthorized });
        const name = r.head.target["/d/".len..];
        var buf: [4096]u8 = undefined;
        const body = t.dir.readFile(std.testing.io, name, &buf) catch return r.respond("", .{ .status = .not_found });
        try r.respond(body, .{});
    }
};

fn testFile(dir: Io.Dir, name: []const u8, data: []const u8) !void {
    try dir.writeFile(std.testing.io, .{ .sub_path = name, .data = data });
}

/// update.signed listing `files`, signed with sign.testKeys()'s pairs; the exe as
/// release `version`
fn testManifest(dir: Io.Dir, files: []const [2][]const u8, version: u64) !void {
    var buf: [2048]u8 = undefined;
    var w: Io.Writer = .fixed(&buf);
    try w.writeAll("{\"patch\":\"16.20\",\"built\":\"x\",\"files\":[");
    for (files, 0..) |f, i| {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(f[1], &digest, .{});
        const hex = std.fmt.bytesToHex(digest, .lower);
        try w.print("{s}{{\"name\":\"{s}\",\"sha256\":\"{s}\",\"bytes\":{d}", .{
            if (i > 0) "," else "", f[0], &hex, f[1].len,
        });
        if (std.mem.eql(u8, f[0], exe_name)) {
            const sig = try sign.signExe(sign.testKeyPair(1), version, &hex, f[1].len);
            try w.print(",\"version\":{d},\"sig\":\"{s}\"", .{ version, &sig });
        }
        try w.writeAll("}");
    }
    try w.writeAll("]}");
    const signed = try sign.sealManifest(std.testing.allocator, sign.testKeyPair(2), w.buffered());
    defer std.testing.allocator.free(signed);
    try testFile(dir, sign.manifest_name, signed);
}

test "update fetches changed files, swaps the exe, then has nothing to do" {
    const io = std.testing.io;
    var server_dir = std.testing.tmpDir(.{});
    defer server_dir.cleanup();
    var app_dir = std.testing.tmpDir(.{ .iterate = true });
    defer app_dir.cleanup();
    const srv = server_dir.dir;
    const app = app_dir.dir;
    const files = [_][2][]const u8{
        .{ "stats.bin", "new stats" },
        .{ "recent-curves.bin", "curves" },
        .{ exe_name, "new exe" },
        .{ "later.bin", "ignored" },
    };
    for (files) |f| try testFile(srv, f[0], f[1]);
    try testManifest(srv, &files, 5);
    try testFile(app, "app.exe", "old exe");
    try testFile(app, "stats-16.19.bin", "old stats");
    try testFile(app, "recent-curves.bin", "curves");

    const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    var ts: TestServer = .{ .dir = srv };
    var serving = try io.concurrent(TestServer.serve, .{ &ts, &server });
    defer serving.cancel(io);
    var base_buf: [64]u8 = undefined;
    const base = try std.mem.print(&base_buf, "http://127.0.0.1:{d}/d/", .{server.socket.address.getPort()});
    var o: Options = .{
        .gpa = std.testing.allocator,
        .io = io,
        .dir = app,
        .exe = "app.exe",
        .base = base,
        .key = "k",
        .version = 4,
        .keys = sign.testKeys(),
    };

    try std.testing.expectEqual(Result{ .data = true, .exe = true }, try run(o));
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("new stats", try app.readFile(io, "stats-16.20.bin", &buf));
    try std.testing.expectEqualStrings("new exe", try app.readFile(io, "app.exe", &buf));
    try std.testing.expectEqualStrings("old exe", try app.readFile(io, old_exe, &buf));
    try std.testing.expectError(error.FileNotFound, app.access(io, "stats-16.19.bin", .{}));
    try std.testing.expectError(error.FileNotFound, app.access(io, "later.bin", .{}));
    try std.testing.expectEqual(Result{}, try run(o));

    o.key = "wrong";
    try std.testing.expectError(error.Unauthorized, run(o));

    o.key = "k";
    try testManifest(srv, &.{.{ "stats.bin", "other stats" }}, 0);
    try std.testing.expectError(error.HashMismatch, run(o));
    try std.testing.expectEqualStrings("new stats", try app.readFile(io, "stats-16.20.bin", &buf));
    try std.testing.expectError(error.FileNotFound, app.access(io, "stats-16.20.bin.part", .{}));

    // Signed by the release key but not newer than the running exe: left alone
    try testFile(srv, exe_name, "older exe");
    try testManifest(srv, &.{.{ exe_name, "older exe" }}, 4);
    try std.testing.expectEqual(Result{}, try run(o));
    try std.testing.expectEqualStrings("new exe", try app.readFile(io, "app.exe", &buf));

    // Any other key, on the manifest or the exe, is refused before a download
    o.keys.data = sign.testKeyPair(3).public_key.toBytes();
    try std.testing.expectError(error.BadSignature, run(o));
    o.keys = .{ .release = sign.testKeyPair(3).public_key.toBytes(), .data = sign.testKeys().data };
    try testManifest(srv, &.{.{ exe_name, "older exe" }}, 6);
    try std.testing.expectError(error.BadSignature, run(o));
    try std.testing.expectError(error.FileNotFound, app.access(io, "app.exe.part", .{}));
}
