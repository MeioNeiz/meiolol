//! `meiolol desktop-sign`: signatures on what the desktop app downloads

const std = @import("std");
const sign = @import("../desktop/sign.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;

pub const usage_desktop_sign =
    \\  desktop-sign  signatures the desktop app checks (src/desktop/sign.zig); a key
    \\              whose public half the app doesn't ship is refused
    \\              manifest IN OUT  the update manifest IN (JSON) as OUT
    \\                               (update.signed), data key (box: web-loop.sh)
    \\              exe EXE          print EXE's manifest fields as JSON (version,
    \\                               sha256, bytes, sig), release key
    \\                               (deploy/desktop-release.sh)
    \\              --version N      exe: its release, as built with -Ddesktop-version
    \\              --key-file F     the key's seed in hex
    \\              --key-env NAME   or from env var NAME (vault run)
    \\
;

pub fn cmdDesktopSign(c: *Cmd) !u8 {
    const io = c.init.io;
    const cwd = std.Io.Dir.cwd();
    var key_hex: ?[]const u8 = null;
    var version: ?u64 = null;
    var args: std.ArrayList([]const u8) = .empty;
    while (c.next()) |flag| {
        if (c.is("--key-file")) {
            key_hex = try cwd.readFileAlloc(io, try c.value(), c.arena, .limited(4096));
        } else if (c.is("--key-env")) {
            const name = try c.value();
            key_hex = c.init.environ_map.get(name) orelse {
                std.log.err("{s} not set", .{name});
                return 1;
            };
        } else if (c.is("--version")) {
            version = try c.int(u64);
        } else if (std.mem.startsWith(u8, flag, "--")) {
            return error.Usage;
        } else try args.append(c.arena, flag);
    }
    const what = try c.required(if (args.items.len > 0) args.items[0] else null, "manifest|exe");
    const kp = try sign.keyPair(try c.required(key_hex, "--key-file|--key-env"));
    const public = kp.public_key.toBytes();

    var buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const out = &stdout.interface;
    if (std.mem.eql(u8, what, "manifest") and args.items.len == 3) {
        if (!std.mem.eql(u8, &public, &sign.shipped.data)) return wrongKey("data");
        const json = try cwd.readFileAlloc(io, args.items[1], c.arena, .limited(1 << 20));
        const signed = try sign.sealManifest(c.arena, kp, json);
        // Checked as the app will before it is published
        _ = try sign.openManifest(signed, sign.shipped.data);
        try cwd.writeFile(io, .{ .sub_path = args.items[2], .data = signed });
    } else if (std.mem.eql(u8, what, "exe") and args.items.len == 2) {
        if (!std.mem.eql(u8, &public, &sign.shipped.release)) return wrongKey("release");
        const v = version orelse {
            c.flag = "--version";
            return error.Usage;
        };
        const exe = try cwd.readFileAlloc(io, args.items[1], c.arena, .limited(1 << 30));
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(exe, &digest, .{});
        const sha = std.fmt.bytesToHex(digest, .lower);
        const sig = try sign.signExe(kp, v, &sha, exe.len);
        try sign.verifyExe(sign.shipped.release, &sig, v, &sha, exe.len);
        try out.print("{{\"version\":{d},\"sha256\":\"{s}\",\"bytes\":{d},\"sig\":\"{s}\"}}\n", .{
            v, &sha, exe.len, &sig,
        });
    } else return error.Usage;
    try out.flush();
    return 0;
}

fn wrongKey(which: []const u8) u8 {
    std.log.err("not the {s} key the app ships (src/desktop/sign.zig)", .{which});
    return 1;
}
