//! ui-home.wasm: the home page's islands (ui.homepage): the lookup with this device's
//! recent Riot IDs; the Daily Draft card with this device's answers; the champions card's
//! role switch; and the loader of ui-homegame.wasm for the game. zjb's generated loader
//! (ui-home.js, `<script src data-wasm>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const hp = ui.homepage;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var look: ui.idlookup.IdLookup = .{ .to = "" };
var look0: ui.idlookup.IdLookup = undefined;
var recent: [5]ui.idlookup.Id = undefined;
var look_i: ?*ui.island.Island(ui.idlookup.IdLookup, dom.Dom) = null;

var daily_d: hp.Daily = undefined;
var daily: hp.HomeDaily = undefined;
var daily0: hp.HomeDaily = undefined;
var daily_i: ?*ui.island.Island(hp.HomeDaily, dom.Dom) = null;

var champs_d: hp.Champs = undefined;
var champs: hp.HomeChamps = undefined;
var champs0: hp.HomeChamps = undefined;

/// The island of the page's other file (dom.lazyLoad): on the first screen, so loaded
/// right after this one's work
const lazy = [_][]const u8{"[data-island=home]"};

export fn main() void {
    dom.start();
    dom.lazyLoad(&lazy);
    lookup();
    today();
    champions();
    dom.lazyLater();
    // Last: blocked storage throws
    stored();
}

fn query(comptime sel: []const u8) ?zjb.Handle {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    return if (el == .null) null else el;
}

fn lookup() void {
    const sel = "[data-island=lookup]";
    const el = query(sel) orelse return;
    defer el.release();
    look0 = .{ .to = dom.attrOf(el, "data-to") };
    look = look0;
    look.live = true;
    look_i = dom.rt.add(ui.idlookup.IdLookup, &look, &look0, sel) catch return dom.dom.warn("lookup: out of memory");
}

fn today() void {
    const sel = "[data-island=homedaily]";
    const el = query(sel) orelse return;
    defer el.release();
    const b = dom.binOf(el, "data-bin") orelse return dom.dom.warn("daily: no data");
    daily_d = ui.data.decode(gpa, hp.Daily, b) catch return dom.dom.warn("daily: bad data");
    daily0 = .{ .data = &daily_d };
    daily = daily0;
    daily_i = dom.rt.add(hp.HomeDaily, &daily, &daily0, sel) catch return dom.dom.warn("daily: out of memory");
}

fn champions() void {
    const sel = "[data-island=homechamps]";
    const el = query(sel) orelse return;
    defer el.release();
    const b = dom.binOf(el, "data-bin") orelse return dom.dom.warn("champions: no data");
    champs_d = ui.data.decode(gpa, hp.Champs, b) catch return dom.dom.warn("champions: bad data");
    champs0 = .{ .data = &champs_d };
    champs = champs0;
    _ = dom.rt.add(hp.HomeChamps, &champs, &champs0, sel) catch return dom.dom.warn("champions: out of memory");
}

fn stored() void {
    if (dom.stored("your-recent")) |s| {
        look.recent = hp.recentIds(s, &recent);
        if (look_i) |i| if (look.recent.len > 0) i.render();
    }
    if (daily_i) |i| if (dom.stored("meiolol.daily.v1")) |s| {
        daily.marks = hp.dailyMarks(s, daily_d.n);
        if (daily.marks != null) i.render();
    };
}
