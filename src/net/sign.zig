//! Ed25519 signatures on what a program downloads, in text: a signature is 128 hex
//! characters, a key file holds the 32-byte seed as 64. Every signature covers a context
//! string before the message, so one key may sign several kinds of thing and a signature
//! for one never passes for another (what minisign and self_update's verification give).
//!
//!     // The publisher, with the key file only it holds
//!     const kp = try sign.keyPair(key_file_text);
//!     const signed = try sign.seal(gpa, kp, "myapp manifest v1\n", manifest_json);
//!     // The program, with the public key built into it
//!     const json = try sign.open(signed, shipped_public_key, "myapp manifest v1\n");
//!
//! `seal` writes "signature\npayload"; `open` returns the payload only if it is signed by
//! that key in that context. For a file too large to hold twice, sign a short message
//! naming it (its version, SHA-256 and size) with `sign` and check it with `verify`.
//! Every failure to verify is error.BadSignature: the caller only needs to know it was
//! refused.

const std = @import("std");
const Ed25519 = std.crypto.sign.Ed25519;

/// A signature in hex, as `sign` writes it
pub const Hex = [2 * Ed25519.Signature.encoded_length]u8;

/// From a key file's text: 64 hex characters, surrounding whitespace ignored
pub fn keyPair(seed_hex: []const u8) !Ed25519.KeyPair {
    const hex = std.mem.trim(u8, seed_hex, " \t\r\n");
    var seed: [Ed25519.KeyPair.seed_length]u8 = undefined;
    if (hex.len != 2 * seed.len) return error.BadKey;
    _ = std.fmt.hexToBytes(&seed, hex) catch return error.BadKey;
    return Ed25519.KeyPair.generateDeterministic(seed);
}

/// A public key from 64 hex characters at compile time, for the keys a program trusts
pub fn publicKey(comptime hex: []const u8) [32]u8 {
    var key: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&key, hex) catch @compileError("bad key: " ++ hex);
    return key;
}

/// The signature over `context` then each of `parts`, deterministic (RFC 8032: the
/// same key and message give the same signature). The message is joined in `gpa`
pub fn sign(gpa: std.mem.Allocator, kp: Ed25519.KeyPair, context: []const u8, parts: []const []const u8) !Hex {
    var msg: std.ArrayList(u8) = .empty;
    defer msg.deinit(gpa);
    try msg.appendSlice(gpa, context);
    for (parts) |p| try msg.appendSlice(gpa, p);
    return std.fmt.bytesToHex((try kp.sign(msg.items, null)).toBytes(), .lower);
}

/// That `sig_hex` is `public`'s signature over `context` then each of `parts`
pub fn verify(public: [32]u8, sig_hex: []const u8, context: []const u8, parts: []const []const u8) error{BadSignature}!void {
    var sig_bytes: [Ed25519.Signature.encoded_length]u8 = undefined;
    if (sig_hex.len != 2 * sig_bytes.len) return error.BadSignature;
    _ = std.fmt.hexToBytes(&sig_bytes, sig_hex) catch return error.BadSignature;
    const pk = Ed25519.PublicKey.fromBytes(public) catch return error.BadSignature;
    var v = Ed25519.Signature.fromBytes(sig_bytes).verifier(pk) catch return error.BadSignature;
    v.update(context);
    for (parts) |p| v.update(p);
    v.verify() catch return error.BadSignature;
}

/// `payload` signed in `context`, as "signature\npayload"; owned by the caller
pub fn seal(gpa: std.mem.Allocator, kp: Ed25519.KeyPair, context: []const u8, payload: []const u8) ![]u8 {
    const sig = try sign(gpa, kp, context, &.{payload});
    return std.mem.concat(gpa, u8, &.{ &sig, "\n", payload });
}

/// The payload inside what `seal` wrote, once its signature checks out; a slice of
/// `signed`
pub fn open(signed: []const u8, public: [32]u8, context: []const u8) error{BadSignature}![]const u8 {
    const nl = std.mem.findScalar(u8, signed, '\n') orelse return error.BadSignature;
    const payload = signed[nl + 1 ..];
    try verify(public, signed[0..nl], context, &.{payload});
    return payload;
}

const testing = std.testing;

fn testKeyPair(n: u8) Ed25519.KeyPair {
    return Ed25519.KeyPair.generateDeterministic(@splat(n)) catch unreachable;
}

test "sealed opens; a changed byte, another key or another context doesn't" {
    const gpa = testing.allocator;
    const kp = testKeyPair(2);
    const pk = kp.public_key.toBytes();
    const signed = try seal(gpa, kp, "a v1\n", "{\"patch\":\"16.21\"}");
    defer gpa.free(signed);
    try testing.expectEqualStrings("{\"patch\":\"16.21\"}", try open(signed, pk, "a v1\n"));
    try testing.expectError(error.BadSignature, open(signed, testKeyPair(1).public_key.toBytes(), "a v1\n"));
    try testing.expectError(error.BadSignature, open(signed, pk, "b v1\n"));
    signed[signed.len - 3] = '0';
    try testing.expectError(error.BadSignature, open(signed, pk, "a v1\n"));
    try testing.expectError(error.BadSignature, open("{}", pk, "a v1\n"));
}

test "a signature covers the parts' bytes in order, not where they split" {
    const gpa = testing.allocator;
    const kp = testKeyPair(1);
    const pk = kp.public_key.toBytes();
    const sig = try sign(gpa, kp, "c\n", &.{ "ab", "cd" });
    try testing.expectEqual(sig, try sign(gpa, kp, "", &.{"c\nabcd"}));
    try verify(pk, &sig, "c\n", &.{"abcd"});
    try verify(pk, &sig, "", &.{"c\nabcd"});
    try testing.expectError(error.BadSignature, verify(pk, &sig, "c\n", &.{ "cd", "ab" }));
    try testing.expectError(error.BadSignature, verify(pk, sig[0..64], "c\n", &.{"abcd"}));
    var upper = sig;
    for (&upper) |*ch| ch.* = std.ascii.toUpper(ch.*);
    try verify(pk, &upper, "c\n", &.{"abcd"});
}

test "key file: 64 hex, whitespace trimmed" {
    const ones: [64]u8 = @splat('1');
    const kp = try keyPair(&ones ++ "\n");
    try testing.expectEqual(testKeyPair(0x11).public_key.toBytes(), kp.public_key.toBytes());
    try testing.expectError(error.BadKey, keyPair("11"));
    const bad: [64]u8 = @splat('z');
    try testing.expectError(error.BadKey, keyPair(&bad));
    const hex = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";
    try testing.expectEqualStrings(hex, &std.fmt.bytesToHex(comptime publicKey(hex), .lower));
}

fn fuzzOpen(_: void, s: *testing.Smith) !void {
    var buf: [512]u8 = undefined;
    const n = s.slice(&buf);
    _ = open(buf[0..n], testKeyPair(2).public_key.toBytes(), "a v1\n") catch return;
    return error.Forged;
}

test "fuzz: no input opens without the key" {
    try testing.fuzz({}, fuzzOpen, .{});
}
