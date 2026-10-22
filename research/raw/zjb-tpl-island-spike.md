# zjb on Zig 0.17 and a tpl island spike (our run, 2026-10-22)

zjb eecd2de patched; spike built with ReleaseSmall, run in headless Chrome via Playwright.

## Patch to zjb (src/zjb.zig)

```diff
diff --git a/src/zjb.zig b/src/zjb.zig
index 53eb934..8f17c9d 100644
--- a/src/zjb.zig
+++ b/src/zjb.zig
@@ -62,9 +62,9 @@ pub fn exportFn(comptime name: []const u8, comptime f: anytype) void {
     comptime var export_name: []const u8 = "zjb_fn_";
     const type_info = @typeInfo(@typeInfo(@TypeOf(f)).pointer.child).@"fn";
     validateToJavascriptReturnType(type_info.return_type orelse void);
-    inline for (type_info.params) |param| {
-        validateFromJavascriptArgumentType(param.type orelse void);
-        export_name = export_name ++ comptime shortTypeName(param.type orelse @compileError("zjb exported functions need specified types."));
+    inline for (type_info.param_types) |param_type| {
+        validateFromJavascriptArgumentType(param_type orelse void);
+        export_name = export_name ++ comptime shortTypeName(param_type orelse @compileError("zjb exported functions need specified types."));
     }
     export_name = export_name ++ "_" ++ comptime shortTypeName(type_info.return_type orelse null) ++ "_" ++ name;
 
@@ -229,14 +229,14 @@ pub const Handle = enum(i32) {
         validateFromJavascriptReturnType(RetType);
         comptime var extern_name: []const u8 = prefix;
         const F = comptime blk: {
-            const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
+            const fields = @typeInfo(@TypeOf(args)).@"struct".field_types;
             var param_types: [fields.len + 1]type = undefined;
-            var param_attributes: [fields.len + 1]std.builtin.Type.Fn.Param.Attributes = @splat(.{});
+            var param_attributes: [fields.len + 1]std.builtin.Type.Fn.ParamAttributes = @splat(.{});
 
-            for (fields, (&param_types)[0..fields.len]) |field, *T| {
-                validateToJavascriptArgumentType(field.type);
-                T.* = mapType(field.type);
-                extern_name = extern_name ++ shortTypeName(field.type);
+            for (fields, (&param_types)[0..fields.len]) |field_type, *T| {
+                validateToJavascriptArgumentType(field_type);
+                T.* = mapType(field_type);
+                extern_name = extern_name ++ shortTypeName(field_type);
             }
 
             param_attributes[fields.len] = .{};
```

## zjb example after the patch

zjb example builds and runs in Chrome: console shows Hello from Zig
example.wasm ReleaseSmall 12257 bytes, gzip 6048; zjb_extract.js gzip 1169

## Spike run output

```
first render ms 89
plat+ : Garen | 51.0% | 810 / Nunu & Willump <script> | 47.0% | 610 / Mordekaiser | 50.9% | 800
diamond+: Garen | 51.9% | 160 / Nunu & Willump <script> | 44.5% | 110 / Mordekaiser | 50.5% | 190
after reload pressed: Diamond+
script tags in table: 0
handles left: 18
island.wasm ReleaseSmall 11433 bytes, gzip 6004; zjb.js 4446 bytes, gzip 870
load.js 174 bytes (5 lines, the only hand-written JS)
```

## Spike source (src/main.zig)

```zig
//! Spike: a champion-filter-like island written only in Zig. Rank buttons re-sum the
//! opponents table and re-render it with meiolol's tpl; the pick is kept in
//! localStorage; opponent names come from a fetched JSON file.
const std = @import("std");
const zjb = @import("zjb");
const tpl = @import("tpl");

pub const panic = std.debug.FullPanic(zjb.panic);

const Opp = struct { name: []const u8, games: [4]u32, wins: [4]u32 };
const ranks = [_][]const u8{ "Plat+", "Emerald+", "Diamond+", "Master+" };

var opps: [8]Opp = undefined;
var n_opps: usize = 0;
var rank: usize = 0;
var name_buf: [512]u8 = undefined;
var out_buf: [16 * 1024]u8 = undefined;

fn doc() zjb.ConstHandle {
    return zjb.global("document");
}

fn byId(comptime id: []const u8) zjb.Handle {
    return doc().call("getElementById", .{zjb.constString(id)}, zjb.Handle);
}

const Row = struct {
    o: *const Opp,
    pub fn render(self: Row, w: *std.Io.Writer) !void {
        var g: u32 = 0;
        var won: u32 = 0;
        for (rank..4) |r| {
            g += self.o.games[r];
            won += self.o.wins[r];
        }
        const wr: f64 = if (g == 0) 0 else 100 * @as(f64, @floatFromInt(won)) / @as(f64, @floatFromInt(g));
        try tpl.render(w,
            \\<tr><td>{name}</td><td class="n">{wr:.1}%</td><td class="n">{g}</td></tr>
        , .{ .name = self.o.name, .wr = wr, .g = g });
    }
};

fn rowsHtml(w: *std.Io.Writer) !void {
    for (opps[0..n_opps]) |*o| try (Row{ .o = o }).render(w);
}

fn draw() void {
    var w: std.Io.Writer = .fixed(&out_buf);
    rowsHtml(&w) catch return;
    const html = zjb.string(w.buffered());
    defer html.release();
    const body = byId("rows");
    defer body.release();
    body.set("innerHTML", html);
    var bw: std.Io.Writer = .fixed(out_buf[w.end..]);
    for (ranks, 0..) |label, i| {
        tpl.render(&bw,
            \\<button data-rank="{i}" aria-pressed="{on}">{label}</button>
        , .{ .i = i, .on = if (i == rank) "true" else "false", .label = label }) catch return;
    }
    const bh = zjb.string(bw.buffered());
    defer bh.release();
    const bar = byId("ranks");
    defer bar.release();
    bar.set("innerHTML", bh);
}

fn onClick(event: zjb.Handle) callconv(.c) void {
    defer event.release();
    const target = event.get("target", zjb.Handle);
    defer target.release();
    const v = target.call("getAttribute", .{zjb.constString("data-rank")}, zjb.Handle);
    defer v.release();
    if (v.isNull()) return;
    rank = @intFromFloat(zjb.global("Number").call("call", .{ zjb.global("Number"), v }, f64));
    zjb.global("localStorage").call("setItem", .{ zjb.constString("rank"), v }, void);
    draw();
}

fn onJson(text: zjb.Handle) callconv(.c) void {
    defer text.release();
    // Copy the JS string into Zig memory, then parse it here
    const view = zjb.u8ArrayView(&name_buf);
    defer view.release();
    const enc = zjb.global("TextEncoder").new(.{});
    defer enc.release();
    const res = enc.call("encodeInto", .{ text, view }, zjb.Handle);
    defer res.release();
    const len: usize = @intFromFloat(res.get("written", f64));
    var it = std.mem.tokenizeScalar(u8, name_buf[0..len], '\n');
    var i: usize = 0;
    while (it.next()) |line| : (i += 1) {
        if (i == opps.len) break;
        var f = std.mem.tokenizeScalar(u8, line, ',');
        opps[i].name = f.next() orelse break;
        for (&opps[i].games, &opps[i].wins) |*g, *wn| {
            g.* = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
            wn.* = std.fmt.parseInt(u32, f.next() orelse "0", 10) catch 0;
        }
    }
    n_opps = i;
    draw();
}

fn onResponse(resp: zjb.Handle) callconv(.c) void {
    defer resp.release();
    const p = resp.call("text", .{}, zjb.Handle);
    defer p.release();
    p.call("then", .{zjb.fnHandle("onJson", &onJson)}, void);
}

export fn main() void {
    const saved = zjb.global("localStorage").call("getItem", .{zjb.constString("rank")}, zjb.Handle);
    defer saved.release();
    if (!saved.isNull()) rank = @intFromFloat(zjb.global("Number").call("call", .{ zjb.global("Number"), saved }, f64));
    const p = zjb.global("window").call("fetch", .{zjb.constString("opps.csv")}, zjb.Handle);
    defer p.release();
    p.call("then", .{zjb.fnHandle("onResponse", &onResponse)}, void);
    const root = byId("island");
    defer root.release();
    root.call("addEventListener", .{ zjb.constString("click"), zjb.fnHandle("onClick", &onClick) }, void);
}
```

## load.js

```js
const zjb = new Zjb();
WebAssembly.instantiateStreaming(fetch("island.wasm"), {zjb: zjb.imports}).then(r => {
  zjb.setInstance(r.instance);
  r.instance.exports.main();
});
```
