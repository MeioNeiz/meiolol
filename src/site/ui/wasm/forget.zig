//! ui-forget.wasm: Remove my data (ui.forget.Forget). POSTs /api/forget, then asks again
//! while the API talks to Riot; once done, the Riot ID leaves your-recent and your-last.
//! ui-yourviews.wasm adds its loader (ui-forget.js) as the page's foot nears the
//! viewport, which calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const fg = ui.forget;
const yk = ui.yourlookup;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var page: fg.Forget = undefined;
var page0: fg.Forget = undefined;
var island: ?*ui.island.Island(fg.Forget, dom.Dom) = null;

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(fg.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    page0 = .{ .js = dom.attrOf(root, "data-js"), .wasm = dom.attrOf(root, "data-wasm"), .ddragon = dom.attrOf(root, "data-ddragon") };
    page = page0;
    island = dom.rt.add(fg.Forget, &page, &page0, fg.sel) catch return dom.dom.warn("forget: out of memory");
    const d = zjb.global("Date").new(.{});
    defer d.release();
    page.tz_min = -d.call("getTimezoneOffset", .{}, i32);
    dom.rt.changed = changed;
}

fn changed() void {
    const w = page.want;
    if (w == .none) return;
    page.want = .none;
    ask(w);
}

fn ask(w: fg.Forget.Want) void {
    const q = ui.homepage.idQuery(gpa, page.id.slice()) catch return;
    defer gpa.free(q);
    const path = std.fmt.allocPrint(gpa, "/api/forget?{s}{s}", .{ q, if (w == .check) "&check=1" else "" }) catch return;
    defer gpa.free(path);
    const gen: i32 = @bitCast(page.gen);
    if (w == .none) dom.fetch(path, gen, answered) else dom.post(path, gen, answered);
}

fn answered(gen: i32, bytes: ?[]u8) void {
    defer if (bytes) |b| gpa.free(b);
    if (@as(u32, @bitCast(gen)) != page.gen) return;
    const again = page.answered(if (bytes) |b| fg.answer(b) else null);
    if (island) |i| i.render();
    if (again) {
        const f = zjb.fnHandle("forgetDue", &onDue).bind(.{gen});
        defer f.release();
        zjb.global("window").call("setTimeout", .{ f, @as(i32, fg.poll_ms) }, void);
    }
    if (page.at == .done) unstore();
}

fn onDue(gen: i32) callconv(.c) void {
    if (@as(u32, @bitCast(gen)) == page.gen) ask(.none);
}

/// The removed ID off this device's lists. Throws with storage blocked: last
fn unstore() void {
    const id = page.id.slice();
    if (dom.stored(yk.recent_key)) |s| {
        defer gpa.free(s);
        var ids: [8]ui.idlookup.Id = undefined;
        var out: std.Io.Writer.Allocating = .init(gpa);
        defer out.deinit();
        out.writer.writeByte('[') catch return;
        var n: usize = 0;
        for (ui.homepage.recentIds(s, &ids)) |*r| {
            if (std.ascii.eqlIgnoreCase(r.slice(), id)) continue;
            out.writer.print("{s}{{\"id\":\"{s}\"}}", .{ if (n > 0) "," else "", r.slice() }) catch return;
            n += 1;
        }
        out.writer.writeByte(']') catch return;
        dom.store(yk.recent_key, out.written());
    }
    if (dom.stored(yk.last_key)) |s| {
        defer gpa.free(s);
        var ids: [1]ui.idlookup.Id = undefined;
        const got = ui.homepage.recentIds(s, &ids);
        if (got.len > 0 and std.ascii.eqlIgnoreCase(got[0].slice(), id)) dom.store(yk.last_key, "");
    }
}
