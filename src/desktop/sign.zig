//! Ed25519 signatures on what the desktop app downloads (update.zig). Two keys: the
//! release key, never on a server (vault meiolol/desktop on the Mac), signs each exe in
//! deploy/desktop-release.sh; the data key, on the box (ml/meiolol/desktop-data.key, a
//! copy in the same vault group), signs the manifest each web round. So whoever holds
//! meio.lol can serve neither data nor an exe, and the box alone no exe.
//! Key files hold the 32-byte seed as 64 hex characters.

const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;

pub const Keys = struct {
    release: [32]u8,
    data: [32]u8,
};

/// The public halves the app trusts, as `meiolol desktop-keygen` printed them. A new
/// key means a new app download: installed apps reject anything else
pub const shipped: Keys = .{
    .release = hexKey("e29a11fc9185f6c58cb23762904e43115a22e7e474abc2292780a1f025e93d45"),
    .data = hexKey("15aa533cbdc529a47efc1fbf3f5eb173a1987c533b0bbf5a53501fb8842acdc9"),
};

/// The signature in hex, a newline, then the manifest JSON
pub const manifest_name = "update.signed";

const manifest_context = "meiolol desktop manifest v1\n";
const exe_context = "meiolol desktop exe v1\n";

fn hexKey(comptime hex: []const u8) [32]u8 {
    var key: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&key, hex) catch @compileError("bad key: " ++ hex);
    return key;
}

/// From a key file's text
pub fn keyPair(seed_hex: []const u8) !Ed25519.KeyPair {
    const hex = std.mem.trim(u8, seed_hex, " \t\r\n");
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    if (hex.len != 2 * seed.len) return error.BadKey;
    _ = std.fmt.hexToBytes(&seed, hex) catch return error.BadKey;
    return Ed25519.KeyPair.generateDeterministic(seed);
}

/// `json` as update.signed
pub fn sealManifest(gpa: std.mem.Allocator, kp: Ed25519.KeyPair, json: []const u8) ![]u8 {
    const msg = try std.mem.concat(gpa, u8, &.{ manifest_context, json });
    defer gpa.free(msg);
    const sig = try kp.sign(msg, null);
    return std.mem.concat(gpa, u8, &.{ &std.fmt.bytesToHex(sig.toBytes(), .lower), "\n", json });
}

/// The JSON inside update.signed once its signature checks out
pub fn openManifest(signed: []const u8, public: [32]u8) ![]const u8 {
    const nl = std.mem.findScalar(u8, signed, '\n') orelse return error.BadSignature;
    const json = signed[nl + 1 ..];
    try verify(public, signed[0..nl], &.{ manifest_context, json });
    return json;
}

/// An exe's signature covers its release version, SHA-256 (hex as in the manifest) and
/// size, so an older signed exe can't pass for a newer one
pub fn signExe(kp: Ed25519.KeyPair, version: u64, sha256_hex: []const u8, bytes: u64) ![128]u8 {
    var buf: [256]u8 = undefined;
    const sig = try kp.sign(try exeMessage(&buf, version, sha256_hex, bytes), null);
    return std.fmt.bytesToHex(sig.toBytes(), .lower);
}

pub fn verifyExe(public: [32]u8, sig_hex: []const u8, version: u64, sha256_hex: []const u8, bytes: u64) !void {
    var buf: [256]u8 = undefined;
    try verify(public, sig_hex, &.{try exeMessage(&buf, version, sha256_hex, bytes)});
}

fn exeMessage(buf: []u8, version: u64, sha256_hex: []const u8, bytes: u64) ![]const u8 {
    if (sha256_hex.len != 64) return error.BadSignature;
    return std.fmt.bufPrint(buf, exe_context ++ "{d} {s} {d}", .{ version, sha256_hex, bytes });
}

/// Every failure is error.BadSignature: the app only needs to know it was refused
fn verify(public: [32]u8, sig_hex: []const u8, parts: []const []const u8) !void {
    var sig_bytes: [Ed25519.Signature.encoded_length]u8 = undefined;
    if (sig_hex.len != 2 * sig_bytes.len) return error.BadSignature;
    _ = std.fmt.hexToBytes(&sig_bytes, sig_hex) catch return error.BadSignature;
    const pk = Ed25519.PublicKey.fromBytes(public) catch return error.BadSignature;
    var v = Ed25519.Signature.fromBytes(sig_bytes).verifier(pk) catch return error.BadSignature;
    for (parts) |p| v.update(p);
    v.verify() catch return error.BadSignature;
}

/// Fixed keys for tests
pub fn testKeyPair(n: u8) Ed25519.KeyPair {
    return Ed25519.KeyPair.generateDeterministic(@splat(n)) catch unreachable;
}

pub fn testKeys() Keys {
    return .{ .release = testKeyPair(1).public_key.toBytes(), .data = testKeyPair(2).public_key.toBytes() };
}

const testing = std.testing;

test "manifest: sealed opens, a changed byte or another key doesn't" {
    const gpa = testing.allocator;
    const kp = testKeyPair(2);
    const signed = try sealManifest(gpa, kp, "{\"patch\":\"16.21\"}");
    defer gpa.free(signed);
    try testing.expectEqualStrings("{\"patch\":\"16.21\"}", try openManifest(signed, kp.public_key.toBytes()));
    try testing.expectError(error.BadSignature, openManifest(signed, testKeyPair(1).public_key.toBytes()));
    signed[signed.len - 3] = '0';
    try testing.expectError(error.BadSignature, openManifest(signed, kp.public_key.toBytes()));
    try testing.expectError(error.BadSignature, openManifest("{}", kp.public_key.toBytes()));
}

test "exe: signature binds version, hash and size" {
    const kp = testKeyPair(1);
    const pk = kp.public_key.toBytes();
    const sha: [64]u8 = @splat('a');
    const other: [64]u8 = @splat('b');
    const sig = try signExe(kp, 7, &sha, 100);
    try verifyExe(pk, &sig, 7, &sha, 100);
    try testing.expectError(error.BadSignature, verifyExe(pk, &sig, 8, &sha, 100));
    try testing.expectError(error.BadSignature, verifyExe(pk, &sig, 7, &other, 100));
    try testing.expectError(error.BadSignature, verifyExe(pk, &sig, 7, &sha, 101));
    try testing.expectError(error.BadSignature, verifyExe(pk, sig[0..64], 7, &sha, 100));
    try testing.expectError(error.BadSignature, verifyExe(testKeyPair(2).public_key.toBytes(), &sig, 7, &sha, 100));
}

test "key file: 64 hex, whitespace trimmed" {
    const ones: [64]u8 = @splat('1');
    const kp = try keyPair(&ones ++ "\n");
    try testing.expectEqual(testKeyPair(0x11).public_key.toBytes(), kp.public_key.toBytes());
    try testing.expectError(error.BadKey, keyPair("11"));
    const bad: [64]u8 = @splat('z');
    try testing.expectError(error.BadKey, keyPair(&bad));
}

fn fuzzOpen(_: void, s: *testing.Smith) !void {
    var buf: [512]u8 = undefined;
    const n = s.slice(&buf);
    _ = openManifest(buf[0..n], testKeyPair(2).public_key.toBytes()) catch return;
    return error.ForgedManifest;
}

test "fuzz: no input opens without the key" {
    try testing.fuzz({}, fuzzOpen, .{});
}
