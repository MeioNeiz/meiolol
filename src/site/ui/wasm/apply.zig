//! ui-apply.wasm: Apply to test the app on /download (ui.apply.Apply), loaded by its own
//! script tag. On submit reads the form and POSTs a ui.applydata.New to /api/apply
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const ap = ui.apply;
const ad = ui.applydata;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var page: ap.Apply = .{};
var server: ap.Apply = .{};
var island: ?*ui.island.Island(ap.Apply, dom.Dom) = null;

export fn main() void {
    dom.start();
    island = dom.rt.add(ap.Apply, &page, &server, ap.sel) catch return dom.dom.warn("apply: out of memory");
    dom.rt.changed = changed;
}

fn changed() void {
    if (!page.want) return;
    page.want = false;
    send();
}

/// The form's fields as the browser has them
const Form = struct {
    data: zjb.Handle,
    bufs: [5][ad.max_why]u8 = undefined,
    used: usize = 0,

    fn get(f: *Form, comptime field: []const u8) []const u8 {
        const v = f.data.call("get", .{zjb.constString(field)}, zjb.Handle);
        defer v.release();
        if (v == .null) return "";
        defer f.used += 1;
        return v.readString(&f.bufs[f.used]) catch "";
    }

    fn trimmed(f: *Form, comptime field: []const u8) []const u8 {
        return std.mem.trim(u8, f.get(field), " \t");
    }
};

fn send() void {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(ap.sel ++ " form")}, zjb.Handle);
    defer el.release();
    var f: Form = .{ .data = zjb.global("FormData").new(.{el}) };
    defer f.data.release();
    const n: ad.New = .{
        .riot_id = f.trimmed("riot_id"),
        .contact = f.trimmed("contact"),
        .role = ap.enumOf(ad.Role, f.get("role")),
        .rank = ap.enumOf(ad.Rank, f.get("rank")),
        .why = f.trimmed("why"),
    };
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();
    var body: std.ArrayList(u8) = .empty;
    ui.data.encode(arena.allocator(), ad.New, n, &body) catch return answered(0, 0, null);
    dom.ask("POST", "/api/apply", body.items, 0, answered);
}

fn answered(_: i32, status: u16, bytes: ?[]u8) void {
    const none: [0]u8 = .{};
    const b = bytes orelse &none;
    defer if (b.len > 0) gpa.free(b);
    page.answered(status, b);
    if (island) |i| i.render();
}
