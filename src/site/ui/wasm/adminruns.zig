//! ui-adminruns.wasm: the Models tab's runs, nets and campaigns (ui.adminruns.Runs).
//! ui-admin.wasm adds its loader (ui-adminruns.js), which calls `main`. Fetches
//! training/training.bin once the island shows, again each minute while a run is live
//! and the browser tab is in view; the shown run's metrics.bin and log.txt when it
//! changes, or when its state or last line does
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const Held = @import("held.zig").Held;
const ar = ui.adminruns;
const md = ui.modelsdata;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;

var state: ar.Runs = .{};
var server: ar.Runs = .{};
var island: ?*ui.island.Island(ar.Runs, dom.Dom) = null;

var training: Held(md.Training) = .{};
var metrics: Held(md.Metrics) = .{};
var log_bytes: []u8 = &.{};
var asked = false;
var training_flight = false;
var training_at: i64 = 0;
/// state.run and state.files point here: training.bin's memory goes when the next lands
var run_buf: [128]u8 = undefined;
var files_buf: [128]u8 = undefined;
/// What the files fetched were for (the run's state and last line), to fetch again when
/// they change
var files_key: u64 = 0;
/// Answers of an older pick are dropped
var gen: i32 = 0;
var waiting: u2 = 0;

const Call = enum(i32) { training, metrics, log };

const poll_ms = 60_000;
const poll_s = 60;
const base = "/admin/training/";

export fn main() void {
    dom.start();
    const root = zjb.global("document").call("querySelector", .{zjb.constString(ar.sel)}, zjb.Handle);
    if (root == .null) return;
    defer root.release();
    // As the server rendered them, so hydration matches
    server.js = dom.attrOf(root, "data-js");
    server.wasm = dom.attrOf(root, "data-wasm");
    state.js = server.js;
    state.wasm = server.wasm;
    island = dom.rt.add(ar.Runs, &state, &server, ar.sel) catch return dom.dom.warn("adminruns: out of memory");
    dom.rt.changed = changed;
    changed();
    zjb.global("window").call("setInterval", .{ zjb.fnHandle("runsTick", &onTick), @as(i32, poll_ms) }, void);
}

fn now() i64 {
    return @intFromFloat(@divFloor(zjb.global("Date").call("now", .{}, f64), 1000));
}

fn render() void {
    state.now = now();
    if (island) |i| i.render();
}

fn getTraining() void {
    if (training_flight) return;
    training_flight = true;
    dom.fetchFresh(base ++ "training.bin", @backingInt(Call.training), done);
}

/// The URL changed (tab, category) or a card was picked
fn changed() void {
    keep(&state.run, &run_buf);
    if (!state.shows()) return;
    if (!asked) {
        asked = true;
        getTraining();
    }
    state.now = now();
    files();
}

/// `s` copied into `buf` unless it is there already (too long: dropped)
fn keep(s: *[]const u8, buf: *[128]u8) void {
    if (s.len == 0 or s.ptr == buf) return;
    if (s.len > buf.len) {
        s.* = "";
        return;
    }
    @memcpy(buf[0..s.len], s.*);
    s.* = buf[0..s.len];
}

fn keyOf(r: *const md.Run) u64 {
    var h = std.hash.Wyhash.init(0);
    h.update(r.run);
    h.update(r.last);
    h.update(&.{@backingInt(r.state)});
    return h.final();
}

/// The shown run's files, when they are another run's or the run moved on
fn files() void {
    const r = state.shown() orelse return;
    const k = keyOf(r);
    if (std.mem.eql(u8, state.files, r.run) and files_key == k) return;
    files_key = k;
    gen += 1;
    state.files = "";
    state.metrics = null;
    state.log = null;
    state.files_failed = false;
    var path: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&path);
    w.writeAll(base ++ "runs/") catch return;
    // Run names are [A-Za-z0-9._-] (deploy/lab-run.sh)
    w.writeAll(r.run) catch return;
    const dir = w.buffered();
    keepFiles(r.run);
    waiting = 0;
    var full: [272]u8 = undefined;
    if (r.metrics) {
        waiting += 1;
        dom.fetchFresh(std.fmt.bufPrint(&full, "{s}/metrics.bin", .{dir}) catch return, ctx(.metrics), done);
    }
    waiting += 1;
    dom.fetchFresh(std.fmt.bufPrint(&full, "{s}/log.txt", .{dir}) catch return, ctx(.log), done);
}

/// The name the files are for, set once both answered (detail shows Loading till then)
var pending_name: []const u8 = "";

fn keepFiles(name: []const u8) void {
    const n = @min(name.len, files_buf.len);
    @memcpy(files_buf[0..n], name[0..n]);
    pending_name = files_buf[0..n];
}

fn ctx(c: Call) i32 {
    return gen * 4 + @backingInt(c);
}

fn onTick() callconv(.c) void {
    if (!state.shows() or zjb.global("document").get("hidden", bool)) return;
    const t = state.training orelse return;
    for (t.runs) |r| if (r.state == .running or r.state == .paused) {
        if (now() - training_at >= poll_s) getTraining();
        return;
    };
}

fn done(c: i32, bytes: ?[]u8) void {
    defer render();
    const call = std.enums.fromInt(Call, @mod(c, 4)) orelse return;
    if (call == .training) {
        training_flight = false;
        training_at = now();
        const t = if (bytes) |b| training.set(b) else null;
        if (t) |x| state.training = x;
        state.failed = state.training == null;
        // Training's memory moved: state.run is the wasm's own copy already
        files();
        return;
    }
    if (@divFloor(c, 4) != gen) {
        if (bytes) |b| gpa.free(b);
        return;
    }
    switch (call) {
        .metrics => state.metrics = if (bytes) |b| metrics.set(b) else null,
        .log => {
            if (log_bytes.len > 0) gpa.free(log_bytes);
            log_bytes = bytes orelse &.{};
            state.log = if (bytes != null) log_bytes else null;
            if (bytes == null) state.files_failed = true;
        },
        .training => unreachable,
    }
    waiting -|= 1;
    if (waiting == 0) state.files = pending_name;
}
