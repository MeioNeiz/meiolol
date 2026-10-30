//! Each page's Content-Security-Policy, as a meta in its head (nginx's
//! deploy/nginx/meiolol-headers.conf adds framing, base-uri and object-src, which a meta
//! can't hold). Scripts: this origin's files, wasm, and the page's own inline ones by
//! hash. Styles: this origin's sheets and the page's <style>s by hash (a per-page sheet,
//! withStyle at delivery); style attributes stay allowed (ui's h.vars). Trusted Types:
//! only the default policy, which lets same-origin script URLs through and nothing into
//! an HTML or script sink
const std = @import("std");

/// First in <head> after charset: the policy holds for what follows it only
pub fn meta(comptime scripts: []const []const u8, comptime styles: []const []const u8) []const u8 {
    return metaFetching(scripts, styles, "");
}

/// meta, and fetch from `origins` (space separated) as well as this one
pub fn metaFetching(comptime scripts: []const []const u8, comptime styles: []const []const u8, comptime origins: []const u8) []const u8 {
    const connect = comptime if (origins.len > 0) "; connect-src 'self' " ++ origins else "";
    return comptime "<meta http-equiv=\"Content-Security-Policy\" content=\"" ++ policy(scripts, styles) ++ connect ++ "\">\n" ++
        trusted_types;
}

/// For a page whose scripts and styles are all files
pub const files_only = meta(&.{}, &.{});

/// Where withStyle adds a <style>'s hash
const style_elem = "style-src-elem 'self'";

/// Browsers without style-src-elem and -attr fall back to style-src: lax there. Without
/// 'wasm-unsafe-eval' (Safari before 16) islands don't start and pages stay as served
fn policy(comptime scripts: []const []const u8, comptime styles: []const []const u8) []const u8 {
    return "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'" ++ hashes(&.{trusted_types}, "script") ++ hashes(scripts, "script") ++
        "; style-src 'self' 'unsafe-inline'; " ++ style_elem ++ hashes(styles, "style") ++
        "; style-src-attr 'unsafe-inline'; img-src 'self' data: https://ddragon.leagueoflegends.com" ++
        " https://raw.communitydragon.org; require-trusted-types-for 'script'; trusted-types default";
}

const trusted_types =
    \\<script>window.trustedTypes?.createPolicy("default",{createScriptURL:u=>{if(new URL(u,location.href).origin==location.origin)return u;throw new TypeError("script URL "+u)}})</script>
    \\
;

/// Each tag's CSP source: sha256 of its text between the tags
fn hashes(comptime tags: []const []const u8, comptime name: []const u8) []const u8 {
    comptime {
        @setEvalBranchQuota(1_000_000);
        var out: []const u8 = "";
        for (tags) |t| out = out ++ " " ++ source(body(t, name));
        return out;
    }
}

fn body(t: []const u8, comptime name: []const u8) []const u8 {
    return t[std.mem.findScalar(u8, t, '>').? + 1 .. std.mem.findLast(u8, t, "</" ++ name ++ ">").?];
}

fn source(text: []const u8) [53]u8 {
    var d: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(text, &d, .{});
    var out: [53]u8 = undefined;
    out[0..8].* = "'sha256-".*;
    _ = std.base64.standard.Encoder.encode(out[8..52], &d);
    out[52] = '\'';
    return out;
}

/// `page` with its <style> holding `css` allowed: the hash after style-src-elem in its CSP
/// meta. A page without the meta is returned as is
pub fn withStyle(a: std.mem.Allocator, page: []const u8, css: []const u8) ![]const u8 {
    const head_end = std.mem.find(u8, page, "</head>") orelse return page;
    const at = (std.mem.find(u8, page[0..head_end], style_elem) orelse return page) + style_elem.len;
    const s = source(css);
    return std.mem.concat(a, u8, &.{ page[0..at], " ", &s, page[at..] });
}

/// Every inline <script> and <style> in `page` (an HTML page) has its hash in the page's
/// CSP meta; for tests of the page writers
pub fn check(page: []const u8) !void {
    const key = "Content-Security-Policy\" content=\"";
    const start = (std.mem.find(u8, page, key) orelse return error.NoCsp) + key.len;
    const content = page[start .. std.mem.findScalarPos(u8, page, start, '"') orelse return error.NoCsp];
    inline for (.{ "script", "style" }) |name| {
        var at: usize = 0;
        while (std.mem.findPos(u8, page, at, "<" ++ name)) |open| {
            const tag_end = (std.mem.findScalarPos(u8, page, open, '>') orelse return error.BadTag) + 1;
            const close = std.mem.findPos(u8, page, tag_end, "</" ++ name ++ ">") orelse return error.BadTag;
            at = close;
            const tag = page[open..tag_end];
            if (std.mem.find(u8, tag, " src=") != null or std.mem.find(u8, tag, "application/json") != null) continue;
            if (std.mem.find(u8, content, &source(page[tag_end..close])) == null) return error.NotAllowed;
        }
    }
}

test "meta: allows its own scripts and styles; withStyle adds a page's sheet" {
    const a = std.testing.allocator;
    const m = comptime meta(&.{"<script>go()</script>"}, &.{"<style>p{}</style>"});
    const page = "<!doctype html><head>" ++ m ++ "<script>go()</script><style>p{}</style><style>b{}</style></head>";
    try std.testing.expectError(error.NotAllowed, check(page));
    const with = try withStyle(a, page, "b{}");
    defer a.free(with);
    try check(with);
    try std.testing.expectError(error.NotAllowed, check("<head>" ++ m ++ "<script>other()</script></head>"));
    try std.testing.expectError(error.NoCsp, check("<head></head>"));
}
