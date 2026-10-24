//! Ed25519 signatures on what the desktop app downloads (update.zig). Two keys: the
//! release key, never on a server (vault meiolol/desktop on the Mac), signs each exe in
//! deploy/desktop-release.sh; the data key, on the box (ml/meiolol/desktop-data.key, a
//! copy in the same vault group), signs the manifest each web round. So whoever holds
//! meio.lol can serve neither data nor an exe, and the box alone no exe.
//! Key files hold the 32-byte seed as 64 hex characters.

const std = @import("std");
const net = @import("net");
const Ed25519 = std.crypto.sign.Ed25519;

pub const keyPair = net.sign.keyPair;

pub const Keys = struct {
    release: [32]u8,
    data: [32]u8,
};

/// The public halves the app trusts, as `meiolol desktop-keygen` printed them. A new
/// key means a new app download: installed apps reject anything else
pub const shipped: Keys = .{
    .release = net.sign.publicKey("e29a11fc9185f6c58cb23762904e43115a22e7e474abc2292780a1f025e93d45"),
    .data = net.sign.publicKey("15aa533cbdc529a47efc1fbf3f5eb173a1987c533b0bbf5a53501fb8842acdc9"),
};

/// The signature in hex, a newline, then the manifest JSON
pub const manifest_name = "update.signed";

const manifest_context = "meiolol desktop manifest v1\n";
const exe_context = "meiolol desktop exe v1\n";

/// `json` as update.signed
pub fn sealManifest(gpa: std.mem.Allocator, kp: Ed25519.KeyPair, json: []const u8) ![]u8 {
    return net.sign.seal(gpa, kp, manifest_context, json);
}

/// The JSON inside update.signed once its signature checks out
pub fn openManifest(signed: []const u8, public: [32]u8) ![]const u8 {
    return net.sign.open(signed, public, manifest_context);
}

/// An exe's signature covers its release version, SHA-256 (hex as in the manifest) and
/// size, so an older signed exe can't pass for a newer one
pub fn signExe(kp: Ed25519.KeyPair, version: u64, sha256_hex: []const u8, bytes: u64) !net.sign.Hex {
    var buf: [256]u8 = undefined;
    var joined: [512]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&joined);
    return net.sign.sign(fba.allocator(), kp, exe_context, &.{try exeMessage(&buf, version, sha256_hex, bytes)});
}

pub fn verifyExe(public: [32]u8, sig_hex: []const u8, version: u64, sha256_hex: []const u8, bytes: u64) !void {
    var buf: [256]u8 = undefined;
    try net.sign.verify(public, sig_hex, exe_context, &.{try exeMessage(&buf, version, sha256_hex, bytes)});
}

fn exeMessage(buf: []u8, version: u64, sha256_hex: []const u8, bytes: u64) ![]const u8 {
    if (sha256_hex.len != 64) return error.BadSignature;
    return std.mem.print(buf, "{d} {s} {d}", .{ version, sha256_hex, bytes });
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

test "signatures are the bytes the shipped app checks" {
    const sha: [64]u8 = @splat('a');
    try testing.expectEqualStrings("2e3757958875c5bf6aa5fec8a40cefe342c27a4cf5c24f0f31fa1fad15de4664" ++
        "b7f3af91343801a1eefd33b0e110cb111e821a39758a62fadd4cec498fee220b", &try signExe(testKeyPair(1), 7, &sha, 100));
    const signed = try sealManifest(testing.allocator, testKeyPair(2), "{}");
    defer testing.allocator.free(signed);
    try testing.expectEqualStrings("59a2629876b7fde766f9f01dd0625ae1b02813f60cf334078fd503b092f99c68" ++
        "300d291a51a6f1c0553d7390949cd19ce4cd85307227857689b70527c50f9a0d\n{}", signed);
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
