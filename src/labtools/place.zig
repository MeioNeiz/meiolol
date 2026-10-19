//! Run-time estimates and placement for deploy/lab-run.sh, from the runs on both hosts
//! (docs/compute.md "Placement"). Reads lab-run.sh's listing, tab-separated:
//!   HOST now TIME | HOST league LINE (watcher.log, oldest first) | HOST have PATH
//!   HOST slots RES N (lab-run.sh's locks per resource) | HOST mem KB (MemAvailable)
//!   HOST memheld KB (what the gate counts as taken: runs <15 min old growing into memneed)
//!   HOST peak DIR GB (a run's peak RSS, after its run line)
//!   HOST used DIR CORES (a run's mean busy cores, usage cpu_cores, after its run line)
//!   HOST width RES K (cores a slot pins: cpu, only where lab-run pins with taskset)
//!   HOST run DIR STATE STARTED ENDED RES BIN ARGS PAUSES PREDICTED BUILD SLOT LOGLINE
//!     [SHARE] (slots it holds at once, lab-run --share; 1 if absent)
//!
//! Run time = ended - started - paused (League); on a shared resource (`shared`) over
//! sharing, the runs holding its slots on average while it ran (itself included), and a
//! new run there is predicted at that x min(slots, live runs + 1). Estimate: median of the
//! last 5 runs that exited 0 with the same args and build, else the same command (exp:
//! action, campaign, target) and candidate (-Dcand) on the same snapshot, else any
//! candidate there, else that command on any snapshot, else the bare subcommand; past the
//! same args, times scale by flags whose work is linear (`linear`). A host with none
//! borrows the other's, scaled by the hosts' speed ratio (median over commands run on
//! both). gpu-box cpu runs from before slots (no SLOT) had every core: scaled by the
//! slot/whole-machine ratio. Width: a cpu run without SHARE holds enough slots for `wide`
//! cores, or one slot when the recent runs of its most specific key with usage kept under
//! `narrow` cores busy (18 Oct: 85 of 177 cpu runs used under 1.5 of their 4 cores).
//!
//! Output is byte for byte deploy/lab-place.pl's, which this replaced (perl.zig).

const std = @import("std");
const perl = @import("perl.zig");
const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;

const recent_n = 5;
const wide = 4;
const narrow = 1.5;
/// Hosts' speed ratio before any command has run on both: eval was 13 s on the Mac, 7 s
/// on the gpu-box (docs/compute.md "Threads")
const assumed_ratio = [_]f64{ 0.5, 2.0 };
/// A League session's length before watcher.log has seen one end
const league_default = 1800;
const hosts = [_][]const u8{ "gpu-box", "mac" };
/// Resources whose slots share one device: gpu runs slow with the runs beside them as
/// sharing^beta, beta fitted on history (log time on log sharing within each command),
/// else assumed: 0.63-0.69 over 26-34 gpu runs on 14 Oct (card 20-35% busy, the shared
/// reserved cores the limit). cpu slots are pinned to their own cores: no slowdown seen
fn shared(res: []const u8) bool {
    return std.mem.eql(u8, res, "gpu");
}
const beta_assumed = 0.7;
/// lab-run's memory gate (0723d43, edd4d90): the queue head waits while MemAvailable is
/// under its need (max peak of earlier runs with its key, else 4 GB); 20 min after it
/// first saw too little, half its need will do, or no run holding a cpu or gpu slot
const gate_default_gb = 4;
const gate_max_wait = 1200;
/// Flags whose value scales a run's work: time x new/old when history differs
/// (dp-shape-a, 13 Oct: --boot 40 ran 22 m, predicted 1.9 m from a --boot 2 smoke). A
/// list counts items
const linear = [_][]const u8{ "--boot", "--seeds" };
/// A cpu slot's run vs the same run with the whole gpu-box, before history has both:
/// meiolol-1b, 13 Oct, ~4x (5 of 20 cores)
const wide_assumed = 4;

pub const usage =
    \\  lab-place   placement and run-time estimates for deploy/lab-run.sh, from its
    \\              listing of both hosts' runs on stdin (src/labtools/place.zig)
    \\              inputs ARGS      input paths to check on each host
    \\              place HOST|auto RES|auto BIN ARGS [BUILD_ARGS [SHARE]]
    \\                               "HOST RES SECONDS SHARE" (- if unknown), then why
    \\              status HOST      status lines, predicted vs actual run time
    \\
;

/// `lab-place MODE ARGS...` with the listing on `in` (not read for inputs). Exit code:
/// 1 with the reason on `err` when there is nowhere to run, 2 on bad usage
pub fn main(arena: Allocator, args: []const []const u8, in: *std.Io.Reader, auto_mac: bool, out: *Writer, err: *Writer) !u8 {
    const mode = if (args.len > 0) args[0] else "";
    if (std.mem.eql(u8, mode, "inputs")) {
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        for (try inputs(arena, if (args.len > 1) args[1] else "")) |p| {
            if ((try seen.getOrPut(arena, p)).found_existing) continue;
            try out.print("{s}\n", .{p});
        }
        return 0;
    }
    const is_place = std.mem.eql(u8, mode, "place") and args.len >= 5 and args.len <= 7;
    const is_status = std.mem.eql(u8, mode, "status") and args.len == 2;
    if (!is_place and !is_status) {
        try err.writeAll("usage: meiolol lab-place inputs ARGS | place HOST|auto RES|auto BIN ARGS [BUILD_ARGS [SHARE]] | status HOST\n");
        return 2;
    }
    var p = try Listing.parse(arena, try in.allocRemaining(arena, .unlimited));
    try p.model();
    if (is_status) {
        try p.status(out, args[1]);
        return 0;
    }
    const opt = struct {
        fn at(a: []const []const u8, i: usize) []const u8 {
            return if (i < a.len) a[i] else "";
        }
    };
    return p.place(out, err, .{
        .host = args[1],
        .res = args[2],
        .bin = args[3],
        .args = args[4],
        .build = opt.at(args, 5),
        .share = opt.at(args, 6),
        .auto_mac = auto_mac,
    });
}

const KeyKind = enum { args, snap, cmd };

/// A history key, from most to least specific, with its label for the explanation
const Key = struct {
    key: []const u8,
    label: []const u8,
    kind: KeyKind,
};

const Pause = struct {
    t: f64,
    stop: bool,
};

const Run = struct {
    host: []const u8,
    dir: []const u8,
    state: []const u8,
    started: ?f64,
    ended: ?f64,
    res: []const u8,
    bin: []const u8,
    args: []const u8,
    /// By time
    pauses: []const Pause,
    pred: ?f64,
    build: []const u8,
    slot: []const u8,
    log: []const u8,
    /// Slots it holds at once
    held: f64,
    keys: []const Key,
    mem_key: []const u8,
    /// Seconds it ran (exit 0 only), less pauses
    ran: ?f64 = null,
    peak: ?f64 = null,
    used: ?f64 = null,
    share: f64 = 1,
    /// Its time alone on the device (and widened to a slot)
    solo: ?f64 = null,
};

const Estimate = struct {
    secs: f64,
    why: []const u8,
};

const Ratio = struct {
    x: f64,
    why: []const u8,
};

const PlaceArgs = struct {
    host: []const u8,
    res: []const u8,
    bin: []const u8,
    args: []const u8,
    build: []const u8,
    share: []const u8,
    auto_mac: bool,
};

const Listing = struct {
    arena: Allocator,
    /// host -> its clock (null: given but unreadable)
    now: std.StringHashMapUnmanaged(?f64) = .empty,
    league: std.StringHashMapUnmanaged(std.ArrayList([]const u8)) = .empty,
    /// "host\x00path"
    have: std.StringHashMapUnmanaged(void) = .empty,
    /// "host\x00res" -> N as written
    slots: std.StringHashMapUnmanaged([]const u8) = .empty,
    width: std.StringHashMapUnmanaged(f64) = .empty,
    /// GB free as the gate sees it
    mem: std.StringHashMapUnmanaged(f64) = .empty,
    held: std.StringHashMapUnmanaged(f64) = .empty,
    /// "host\x00dir"
    peak: std.StringHashMapUnmanaged(f64) = .empty,
    used: std.StringHashMapUnmanaged(f64) = .empty,
    runs: std.ArrayList(*Run) = .empty,
    beta: f64 = beta_assumed,
    beta_why: []const u8 = "assumed",
    /// [host][other]
    ratio: [2][2]Ratio = undefined,
    /// host -> key -> finished runs, oldest first
    by_key: std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(std.ArrayList(*Run))) = .empty,

    fn parse(arena: Allocator, text: []const u8) !Listing {
        var p: Listing = .{ .arena = arena };
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            var it = std.mem.splitScalar(u8, line, '\t');
            const host = it.next().?;
            const kind = it.next() orelse continue;
            var fs: std.ArrayList([]const u8) = .empty;
            while (it.next()) |f| try fs.append(arena, f);
            const f = fs.items;
            const f0 = field(f, 0);
            const f1 = field(f, 1);
            if (eql(kind, "now")) {
                try p.now.put(arena, host, perl.parseTs(f0));
            } else if (eql(kind, "league")) {
                const gop = try p.league.getOrPut(arena, host);
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                try gop.value_ptr.append(arena, f0);
            } else if (eql(kind, "have")) {
                try p.have.put(arena, try pair(arena, host, f0), {});
            } else if (eql(kind, "slots")) {
                try p.slots.put(arena, try pair(arena, host, f0), f1);
            } else if (eql(kind, "width")) {
                if (f1.len > 0 and f1[0] >= '1' and f1[0] <= '9' and allDigits(f1)) try p.width.put(arena, try pair(arena, host, f0), perl.num(f1));
            } else if (eql(kind, "mem")) {
                if (f0.len > 0 and allDigits(f0)) try p.mem.put(arena, host, perl.num(f0) / 1048576);
            } else if (eql(kind, "memheld")) {
                if (f0.len > 0 and allDigits(f0)) try p.held.put(arena, host, perl.num(f0) / 1048576);
            } else if (eql(kind, "peak")) {
                if (decimalish(f1)) try p.peak.put(arena, try pair(arena, host, f0), perl.num(f1));
            } else if (eql(kind, "used")) {
                if (decimalish(f1)) try p.used.put(arena, try pair(arena, host, f0), perl.num(f1));
            } else if (eql(kind, "run")) {
                try p.runs.append(arena, try parseRun(arena, host, f));
            }
        }
        return p;
    }

    fn parseRun(arena: Allocator, host: []const u8, f: []const []const u8) !*Run {
        const held = field(f, 12);
        const pred = field(f, 8);
        var pred_digits: usize = 0;
        while (pred_digits < pred.len and std.ascii.isDigit(pred[pred_digits])) pred_digits += 1;
        var pauses: std.ArrayList(Pause) = .empty;
        for (try perl.split(arena, field(f, 7), ',')) |p| {
            // /^(\S+) (STOP|CONT)$/
            const sp = std.mem.lastIndexOfScalar(u8, p, ' ') orelse continue;
            const what = p[sp + 1 ..];
            const t = p[0..sp];
            if (t.len == 0 or std.mem.indexOfAny(u8, t, " \t\n\r\x0b\x0c") != null) continue;
            if (!eql(what, "STOP") and !eql(what, "CONT")) continue;
            const at = perl.parseTs(t) orelse continue;
            try pauses.append(arena, .{ .t = at, .stop = eql(what, "STOP") });
        }
        std.mem.sort(Pause, pauses.items, {}, struct {
            fn lt(_: void, x: Pause, y: Pause) bool {
                return x.t < y.t;
            }
        }.lt);
        const r = try arena.create(Run);
        r.* = .{
            .host = host,
            .dir = field(f, 0),
            .state = field(f, 1),
            .started = perl.parseTs(field(f, 2)),
            .ended = perl.parseTs(field(f, 3)),
            .res = field(f, 4),
            .bin = field(f, 5),
            .args = field(f, 6),
            .pauses = pauses.items,
            .pred = if (pred_digits > 0) perl.num(pred[0..pred_digits]) else null,
            .build = field(f, 9),
            .slot = field(f, 10),
            .log = field(f, 11),
            .held = if (held.len == 1 and held[0] >= '1' and held[0] <= '9') perl.num(held) else 1,
            .keys = try keysFor(arena, field(f, 5), field(f, 6), field(f, 9)),
            .mem_key = try memKey(arena, field(f, 5), field(f, 6)),
        };
        r.ran = ran(r);
        return r;
    }

    /// Everything placing needs from history, in lab-place.pl's order: sharing, beta,
    /// each run's solo time, the slot widening, the hosts' ratios
    fn model(p: *Listing) !void {
        // Free as the gate sees it: a young run's need not yet grown into is taken
        // already, and comes back with the run's peak at its end
        var it = p.mem.iterator();
        while (it.next()) |kv| kv.value_ptr.* -= p.held.get(kv.key_ptr.*) orelse 0;
        for (p.runs.items) |r| {
            const k = try pair(p.arena, r.host, r.dir);
            r.peak = p.peak.get(k);
            r.used = p.used.get(k);
        }
        for (p.runs.items) |r| r.share = p.sharing(r);
        try p.fitBeta();
        for (p.runs.items) |r| {
            if (r.ran) |t| r.solo = t / perl.power(r.share, p.beta);
        }
        try p.indexRuns();
        try p.widen();
        try p.ratios();
    }

    fn nowOf(p: *const Listing, host: []const u8) ?f64 {
        return p.now.get(host) orelse null;
    }

    /// Sharing: time-weighted runs holding RES slots on HOST beside it, itself included;
    /// 1 on unshared resources or with no overlap known
    fn sharing(p: *const Listing, r: *const Run) f64 {
        if (r.ran == null or !shared(r.res)) return 1;
        const s = r.started.?;
        const e = r.ended.?;
        if (!(e > s)) return 1;
        var held: f64 = 0;
        for (p.runs.items) |o| {
            if (!eql(o.host, r.host)) continue;
            const os = o.started orelse continue;
            if (!eql(o.res, r.res)) continue;
            const oe = o.ended orelse (if (live(o)) p.nowOf(o.host) else null) orelse continue;
            held += clip(os, oe, s, e);
        }
        const share = held / (e - s);
        return if (share > 1) share else 1;
    }

    /// Beta: slope of log time on log sharing within each command (snapshot-level keys
    /// with 3+ runs), pooled over shared-resource runs of 20 s or more; assumed with
    /// fewer than 10. Groups in key order (lab-place.pl's were in hash order)
    fn fitBeta(p: *Listing) !void {
        var by: std.StringArrayHashMapUnmanaged(std.ArrayList([2]f64)) = .empty;
        for (p.runs.items) |r| {
            const t = r.ran orelse continue;
            if (t < 20 or !shared(r.res)) continue;
            const k = for (r.keys) |k| {
                if (k.kind == .snap) break k;
            } else continue;
            const gop = try by.getOrPut(p.arena, try std.fmt.allocPrint(p.arena, "{s} {s}", .{ r.host, k.key }));
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(p.arena, .{ perl.ln(t), perl.ln(r.share) });
        }
        by.sort(struct {
            keys: []const []const u8,
            pub fn lessThan(c: @This(), a: usize, b: usize) bool {
                return std.mem.lessThan(u8, c.keys[a], c.keys[b]);
            }
        }{ .keys = by.keys() });
        var sxy: f64 = 0;
        var sxx: f64 = 0;
        var n: usize = 0;
        for (by.values()) |rs| {
            if (rs.items.len < 3) continue;
            const len: f64 = @floatFromInt(rs.items.len);
            var my: f64 = 0;
            var mx: f64 = 0;
            for (rs.items) |v| {
                my += v[0] / len;
                mx += v[1] / len;
            }
            for (rs.items) |v| {
                sxy += (v[1] - mx) * (v[0] - my);
                sxx += perl.power(v[1] - mx, 2);
                n += 1;
            }
        }
        if (n < 10 or sxx < 1e-9) return;
        p.beta = std.math.clamp(sxy / sxx, 0, 1);
        p.beta_why = try std.fmt.allocPrint(p.arena, "{d} runs", .{n});
    }

    /// Finished runs by host and key, oldest first
    fn indexRuns(p: *Listing) !void {
        var done: std.ArrayList(*Run) = .empty;
        for (p.runs.items) |r| if (r.ran != null) try done.append(p.arena, r);
        std.mem.sort(*Run, done.items, {}, struct {
            fn lt(_: void, a: *Run, b: *Run) bool {
                return a.started.? < b.started.?;
            }
        }.lt);
        for (done.items) |r| {
            const h = try p.by_key.getOrPut(p.arena, r.host);
            if (!h.found_existing) h.value_ptr.* = .empty;
            for (r.keys) |k| {
                const gop = try h.value_ptr.getOrPut(p.arena, k.key);
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                try gop.value_ptr.append(p.arena, r);
            }
        }
    }

    fn runsFor(p: *const Listing, host: []const u8, key: []const u8) []const *Run {
        const h = p.by_key.get(host) orelse return &.{};
        return if (h.get(key)) |l| l.items else &.{};
    }

    fn solos(p: *const Listing, rs: []const *Run) ![]f64 {
        const out = try p.arena.alloc(f64, rs.len);
        for (rs, out) |r, *o| o.* = r.solo.?;
        return out;
    }

    /// Scales gpu-box cpu runs from before slots (no SLOT: every core) to a slot's width,
    /// by the median over commands with both kinds of run of slot / whole machine. --res
    /// none and gpu runs keep theirs: no way to tell when their width changed (lab-run
    /// 8bf0e69)
    fn widen(p: *Listing) !void {
        const Both = struct { slot: std.ArrayList(f64) = .empty, all: std.ArrayList(f64) = .empty };
        var by: std.StringHashMapUnmanaged(Both) = .empty;
        var keys: std.ArrayList([]const u8) = .empty;
        for (p.runs.items) |r| {
            if (r.ran == null or !narrowed(r)) continue;
            for (r.keys) |k| {
                if (k.kind == .cmd) continue;
                const gop = try by.getOrPut(p.arena, k.key);
                if (!gop.found_existing) {
                    gop.value_ptr.* = .{};
                    try keys.append(p.arena, k.key);
                }
                const l = if (perl.truthy(r.slot)) &gop.value_ptr.slot else &gop.value_ptr.all;
                try l.append(p.arena, r.solo.?);
            }
        }
        sortStrings(keys.items);
        var rs: std.ArrayList(f64) = .empty;
        for (keys.items) |k| {
            const b = by.getPtr(k).?;
            const s = perl.median(b.slot.items) orelse continue;
            const w = perl.median(b.all.items) orelse continue;
            if (s >= 5 and w >= 5) try rs.append(p.arena, s / w);
        }
        const x = perl.median(rs.items) orelse wide_assumed;
        for (p.runs.items) |r| {
            if (r.ran != null and narrowed(r) and !perl.truthy(r.slot)) r.solo.? *= x;
        }
    }

    fn narrowed(r: *const Run) bool {
        return eql(r.host, "gpu-box") and (r.res.len == 0 or eql(r.res, "cpu"));
    }

    /// ratio[a][b]: a run on a takes ratio times as long as on b. Over the same command
    /// on the same snapshot, runs of 5 s or more (shorter ones are mostly startup and
    /// rounding)
    fn ratios(p: *Listing) !void {
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        var keys: std.ArrayList([]const u8) = .empty;
        for (p.runs.items) |r| {
            if (r.ran == null) continue;
            for (r.keys) |k| {
                if (k.kind != .snap) continue;
                if (!(try seen.getOrPut(p.arena, k.key)).found_existing) try keys.append(p.arena, k.key);
            }
        }
        sortStrings(keys.items);
        for (hosts, 0..) |h, hi| for (hosts, 0..) |o, oi| {
            if (hi == oi) continue;
            var rs: std.ArrayList(f64) = .empty;
            for (keys.items) |k| {
                const mh = perl.median(try p.solos(recent(p.runsFor(h, k)))) orelse continue;
                const mo = perl.median(try p.solos(recent(p.runsFor(o, k)))) orelse continue;
                if (mh >= 5 and mo >= 5) try rs.append(p.arena, mh / mo);
            }
            const n = rs.items.len;
            p.ratio[hi][oi] = if (perl.median(rs.items)) |m| .{
                .x = m,
                .why = try std.fmt.allocPrint(p.arena, "{d} {s} on both", .{ n, if (n == 1) "command" else "commands" }),
            } else .{ .x = assumed_ratio[hi], .why = "assumed" };
        };
    }

    /// RUNS' times, each scaled to ARGS's work, and the flags that scaled any
    fn scaled(p: *const Listing, args: []const u8, rs: []const *Run) !struct { []f64, []const u8 } {
        const want = try work(p.arena, args);
        var t = try p.arena.alloc(f64, rs.len);
        var used: [3]bool = @splat(false);
        for (rs, 0..) |r, i| {
            const have = try work(p.arena, r.args);
            var x: f64 = 1;
            for (want, have, 0..) |wv, hv, j| {
                const a = wv orelse continue;
                const b = hv orelse continue;
                if (a == b) continue;
                x *= a / b;
                used[j] = true;
            }
            t[i] = r.solo.? * x;
        }
        // work's order: trials, --boot, --seeds; sorted as text: --boot --seeds trials
        var by: std.ArrayList(u8) = .empty;
        for ([_]usize{ 1, 2, 0 }) |j| {
            if (!used[j]) continue;
            if (by.items.len > 0) try by.append(p.arena, ' ');
            try by.appendSlice(p.arena, work_names[j]);
        }
        return .{ t, by.items };
    }

    /// (seconds, why) for BIN ARGS BUILD on HOST, or null with no history anywhere
    fn estimate(p: *const Listing, host: []const u8, keys: []const Key, args: []const u8) !?Estimate {
        for (keys) |k| {
            const t, const by = try p.scaled(args, recent(p.runsFor(host, k.key)));
            if (t.len > 0) {
                return .{
                    .secs = perl.median(t).?,
                    .why = try std.fmt.allocPrint(p.arena, "median of {d} here, {s}{s}{s}", .{ t.len, k.label, if (by.len > 0) ", scaled by " else "", by }),
                };
            }
            const hi = hostIndex(host) orelse continue;
            for (hosts, 0..) |o, oi| {
                if (oi == hi) continue;
                const to, const oby = try p.scaled(args, recent(p.runsFor(o, k.key)));
                if (to.len == 0) continue;
                const r = p.ratio[hi][oi];
                var b: [64]u8 = undefined;
                return .{
                    .secs = perl.median(to).? * r.x,
                    .why = try std.fmt.allocPrint(p.arena, "{s} median of {d} x {s} ({s}), {s}{s}{s}", .{ o, to.len, perl.fmtFloat(&b, "%.2f", r.x), r.why, k.label, if (oby.len > 0) ", scaled by " else "", oby }),
                };
            }
        }
        return null;
    }

    fn need(p: *const Listing, host: []const u8, bin: []const u8, args: []const u8) !f64 {
        const k = try memKey(p.arena, bin, args);
        var max: ?f64 = null;
        for (p.runs.items) |r| {
            if (!eql(r.host, host)) continue;
            const pk = r.peak orelse continue;
            if (!eql(r.mem_key, k)) continue;
            if (max == null or pk > max.?) max = pk;
        }
        return max orelse gate_default_gb;
    }

    /// A live run's time: the longer of its start's prediction (with sharing in it) and
    /// one from today's history, as the start's may predate most of it (st1, 14 Oct: 71
    /// s written from one run, 15 m once more had ended). The ticket's fast lane uses the
    /// written one
    fn longer(p: *const Listing, r: *const Run) !?f64 {
        const now = if (try p.estimate(r.host, r.keys, r.args)) |e| e.secs else null;
        if (r.pred) |a| return if (now) |b| (if (b > a) b else a) else a;
        return now;
    }

    fn doneSoFar(p: *const Listing, r: *const Run) f64 {
        const now = p.nowOf(r.host) orelse 0;
        return now - r.started.? - paused(r, r.started.?, now);
    }

    const Wait = struct {
        at: f64,
        live: usize,
        slots: usize,
        mem_wait: f64,
    };

    /// Seconds until one of RES's N slots on HOST is free for a new run: running runs
    /// hold a slot for what they have left (overdue: a fifth of their time so far),
    /// queued ones take the first slot to free up in lab-run's ticket order (a0,
    /// 94068f0): fast ones (predicted <= 60 s) first, then the rest, each oldest first. A
    /// FAST new run waits only for queued fast ones, the rest for every queued run.
    ///
    /// With the host's MemAvailable known, memory is a second resource: a run starts once
    /// a slot is free and memory covers its need (the gate's late rule past its 20 min),
    /// takes its need and gives it back when it ends; running runs give back theirs (peak,
    /// else need) as they end. Upper bounds both ways (peaks count shared pages per
    /// process). Queued runs of other resources are left out: they take memory and slots
    /// this can't see
    fn waitFor(p: *const Listing, host: []const u8, res: []const u8, fast_only: bool, need_new: f64, share_new: f64) !Wait {
        const a = p.arena;
        const n_slots: usize = blk: {
            const s = p.slots.get(try pair(a, host, res)) orelse break :blk 1;
            if (s.len == 0 or !allDigits(s)) break :blk 1;
            const v = perl.num(s);
            break :blk if (v > 0) @intFromFloat(@min(v, 1 << 20)) else 1;
        };
        const nf: f64 = @floatFromInt(n_slots);
        // A share-N run holds N slots, at most all of them (lab-run caps it the same way)
        const Width = struct {
            n: f64,
            fn of(w: @This(), k: f64) usize {
                return @intFromFloat(if (k < w.n) k else w.n);
            }
        };
        // $free[K - 1]: K is at least 1 but for a 0 slots line, where Perl took the last
        const kth = struct {
            fn at(xs: []const f64, k: usize) f64 {
                return xs[if (k == 0) xs.len - 1 else k - 1];
            }
        }.at;
        const width: Width = .{ .n = nf };
        const gate = Gate{ .mem = p.mem.get(host), .arena = a };
        var g = gate;
        var free: std.ArrayList(f64) = .empty;
        const Queued = struct { lane: u1, pred: f64, need: f64, k: usize };
        var queued: std.ArrayList(Queued) = .empty;
        var n: usize = 0;
        var mine: std.ArrayList(*Run) = .empty;
        for (p.runs.items) |r| {
            if (eql(r.host, host) and eql(r.res, res) and live(r)) try mine.append(a, r);
        }
        std.mem.sort(*Run, mine.items, {}, byDir);
        for (mine.items) |r| {
            const pred = try p.longer(r) orelse p.medianRan(host) orelse 60;
            n += 1;
            const need_r = r.peak orelse try p.need(host, r.bin, r.args);
            if (r.started != null and !std.mem.startsWith(u8, r.state, "queued")) {
                const done = p.doneSoFar(r);
                const left = if (pred - done > done / 5) pred - done else done / 5;
                try free.appendNTimes(a, left, width.of(r.held));
                try g.ev.append(a, .{ left, need_r });
                if (eql(res, "cpu") or eql(res, "gpu")) try g.hold.append(a, .{ 0, left });
            } else {
                // A start without a prediction is normal, whatever we estimate for it
                try queued.append(a, .{ .lane = if (fast(r.pred)) 0 else 1, .pred = pred, .need = need_r, .k = width.of(r.held) });
            }
        }
        // Running runs of the other resources give their memory back too
        for (p.runs.items) |r| {
            if (!eql(r.host, host) or eql(r.res, res) or !live(r) or r.started == null or std.mem.startsWith(u8, r.state, "queued")) continue;
            const pred = try p.longer(r) orelse 60;
            const done = p.doneSoFar(r);
            const left = if (pred - done > done / 5) pred - done else done / 5;
            try g.ev.append(a, .{ left, r.peak orelse try p.need(host, r.bin, r.args) });
            if (eql(r.res, "cpu") or eql(r.res, "gpu")) try g.hold.append(a, .{ 0, left });
        }
        while (free.items.len < n_slots) try free.append(a, 0);
        perl.sortAsc(free.items);
        free.shrinkRetainingCapacity(n_slots);
        // The head holds the queue until K slots are free at once (all or none)
        std.mem.sort(Queued, queued.items, {}, struct {
            fn lt(_: void, x: Queued, y: Queued) bool {
                return x.lane < y.lane;
            }
        }.lt);
        var prev: f64 = 0;
        for (queued.items) |q| {
            if (fast_only and q.lane != 0) continue;
            const t0 = @max(kth(free.items, q.k), prev);
            const at = try g.start(prev, t0, q.need);
            std.mem.copyForwards(f64, free.items, free.items[q.k..]);
            free.shrinkRetainingCapacity(free.items.len - q.k);
            try free.appendNTimes(a, at + q.pred, q.k);
            perl.sortAsc(free.items);
            try g.ev.append(a, .{ at, -q.need });
            try g.ev.append(a, .{ at + q.pred, q.need });
            try g.hold.append(a, .{ at, at + q.pred });
            prev = at;
        }
        const k = width.of(share_new);
        const t0 = @max(kth(free.items, k), prev);
        const at = try g.start(prev, t0, need_new);
        return .{ .at = at, .live = n, .slots = n_slots, .mem_wait = at - t0 };
    }

    fn medianRan(p: *const Listing, host: []const u8) ?f64 {
        var ts: std.ArrayList(f64) = .empty;
        for (p.runs.items) |r| {
            if (!eql(r.host, host)) continue;
            ts.append(p.arena, r.ran orelse continue) catch return null;
        }
        return perl.median(ts.items);
    }

    /// What League costs a gpu-box run now: nothing while it's down. While it's up (or
    /// the watcher can't tell): the median past session (watcher.log's up/down lines)
    /// less the time it has been up, but at least that time again (a long session tends
    /// to run long)
    fn leaguePenalty(p: *const Listing, host: []const u8) !struct { f64, []const u8 } {
        const lines = if (p.league.get(host)) |l| l.items else &.{};
        if (lines.len == 0) return .{ 0, "" };
        const state = leagueUp(lines[lines.len - 1]) orelse return .{ 0, "" };
        var lens: std.ArrayList(f64) = .empty;
        var since: ?f64 = null;
        for (lines) |line| {
            const first = (try perl.words(p.arena, line));
            const t = perl.parseTs(if (first.len > 0) first[0] else "") orelse continue;
            if (leagueUp(line) != null) {
                if (since == null) since = t;
            } else if (std.mem.indexOf(u8, line, "League down") != null) {
                if (since) |s| {
                    try lens.append(p.arena, t - s);
                    since = null;
                }
            }
        }
        const up = if (since) |s| (p.nowOf(host) orelse 0) - s else 0;
        const n = lens.items.len;
        const m = perl.median(lens.items);
        const typical = m orelse league_default;
        const pen = if (typical - up > up) typical - up else up;
        var b1: [32]u8 = undefined;
        var b2: [32]u8 = undefined;
        const past = if (m) |v|
            try std.fmt.allocPrint(p.arena, "median session {s} of {d}", .{ fmtSecs(&b1, v), n })
        else
            try std.fmt.allocPrint(p.arena, "no past session, {s} assumed", .{fmtSecs(&b1, league_default)});
        return .{ pen, try std.fmt.allocPrint(p.arena, "League {s} {s} ({s}): +", .{ state, fmtSecs(&b2, up), past }) };
    }

    /// Slots a new run of RES on HOST holds when the caller gave no SHARE, and why
    fn widthFor(p: *const Listing, host: []const u8, res: []const u8, keys: []const Key) !struct { f64, []const u8 } {
        const k = p.width.get(try pair(p.arena, host, res)) orelse return .{ 1, "" };
        const n = perl.num(p.slots.get(try pair(p.arena, host, res)) orelse "1");
        for (keys) |key| {
            var u: std.ArrayList(f64) = .empty;
            for (p.runsFor(host, key.key)) |r| try u.append(p.arena, r.used orelse continue);
            const m = perl.median(@constCast(recent(u.items))) orelse continue;
            if (m >= narrow) break;
            var b: [32]u8 = undefined;
            return .{ 1, try std.fmt.allocPrint(p.arena, ", 1 slot: {s} of its cores busy before", .{perl.fmtFloat(&b, "%.1f", m)}) };
        }
        var w: f64 = @trunc((wide + k - 1) / k);
        if (w > n) w = n;
        var b1: [32]u8 = undefined;
        var b2: [32]u8 = undefined;
        return .{ w, if (w > 1) try std.fmt.allocPrint(p.arena, ", {s} slots ({s} cores)", .{ perl.fmtInt(&b1, w), perl.fmtInt(&b2, w * k) }) else "" };
    }

    const Cand = struct {
        host: []const u8,
        res: []const u8,
        run: ?f64,
        wait: f64,
        total: ?f64,
        share: f64,
        say: []const u8,
    };

    fn place(p: *const Listing, out: *Writer, err: *Writer, q: PlaceArgs) !u8 {
        const a = p.arena;
        const given: ?f64 = if (q.share.len == 1 and q.share[0] >= '1' and q.share[0] <= '9') perl.num(q.share) else null;
        const cuda = try cudaUse(a, q.bin, q.args);
        const keys = try keysFor(a, q.bin, q.args, q.build);
        const want_inputs = try inputs(a, q.args);
        var cands: std.ArrayList(Cand) = .empty;
        var notes: std.ArrayList([]const u8) = .empty;
        const auto = eql(q.host, "auto");
        const candidates: []const []const u8 = if (!auto) &.{q.host} else if (q.auto_mac) &hosts else hosts[0..1];
        for (candidates) |h| {
            const res = if (!eql(q.res, "auto")) q.res else if (eql(cuda, "gpu")) "gpu" else "cpu";
            const name = try std.fmt.allocPrint(a, "{s}/{s}", .{ h, res });
            var why_not: []const u8 = "";
            if (p.nowOf(h) == null) {
                why_not = "unreachable";
            } else if (eql(h, "mac") and !eql(cuda, "none")) {
                why_not = "no CUDA";
            } else {
                var missing: std.ArrayList(u8) = .empty;
                for (want_inputs) |in| {
                    if (p.have.contains(try pair(a, h, in))) continue;
                    try missing.appendSlice(a, if (missing.items.len == 0) "no " else " ");
                    try missing.appendSlice(a, in);
                }
                why_not = missing.items;
            }
            // Explicit choices are the caller's: only report what we'd predict
            if (!auto and !eql(why_not, "unreachable")) why_not = "";
            if (why_not.len > 0) {
                try notes.append(a, try std.fmt.allocPrint(a, "{s}: {s}", .{ name, why_not }));
                continue;
            }
            const est = try p.estimate(h, keys, q.args);
            var run: ?f64 = if (est) |e| e.secs else null;
            var why: ?[]const u8 = if (est) |e| e.why else null;
            const share: f64, const wide_why: []const u8 = if (given) |g| .{ g, "" } else if (eql(res, "cpu")) try p.widthFor(h, res, keys) else .{ 1, "" };
            const need_new = try p.need(h, q.bin, q.args);
            var w: Wait = if (eql(res, "none")) .{ .at = 0, .live = 0, .slots = 0, .mem_wait = 0 } else try p.waitFor(h, res, false, need_new, share);
            if (run != null and shared(res)) {
                const beside = if (w.live + 1 < w.slots) w.live + 1 else w.slots;
                run.? *= perl.power(@floatFromInt(beside), p.beta);
                var b: [32]u8 = undefined;
                if (beside > 1) why = try std.fmt.allocPrint(a, "{s}, x {d} sharing {s} ^{s} ({s})", .{ why.?, beside, res, perl.fmtFloat(&b, "%.2f", p.beta), p.beta_why });
            }
            if (!eql(res, "none") and fast(run)) {
                const f = try p.waitFor(h, res, true, need_new, share);
                w.at = f.at;
                w.mem_wait = f.mem_wait;
                why = try std.fmt.allocPrint(a, "{s}, fast lane", .{why.?});
            }
            if (w.mem_wait > 0) {
                var b1: [32]u8 = undefined;
                var b2: [32]u8 = undefined;
                var b3: [32]u8 = undefined;
                why = try std.fmt.allocPrint(a, "{s}, {s} of it for memory (needs {s} GB, {s} free)", .{
                    why orelse "no history",
                    fmtSecs(&b1, w.mem_wait),
                    perl.fmtFloat(&b2, "%.1f", need_new),
                    perl.fmtFloat(&b3, "%.1f", p.mem.get(h) orelse 0),
                });
            }
            const pen, const pen_why = try p.leaguePenalty(h);
            if (wide_why.len > 0) why = try std.fmt.allocPrint(a, "{s}{s}", .{ why orelse "no history", wide_why });
            var b1: [32]u8 = undefined;
            var b2: [32]u8 = undefined;
            var b3: [32]u8 = undefined;
            const pen_say = if (pen != 0) try std.fmt.allocPrint(a, "{s}{s}, ", .{ pen_why, fmtSecs(&b1, pen) }) else "";
            try cands.append(a, .{
                .host = h,
                .res = res,
                .run = run,
                .wait = w.at + pen,
                .total = if (run) |r| w.at + pen + r else null,
                .share = share,
                .say = try std.fmt.allocPrint(a, "{s}: {s}wait {s} ({d} live, {d} slots) + run {s} ({s})", .{
                    name, pen_say, fmtSecs(&b2, w.at), w.live, w.slots, fmtOpt(&b3, run), why orelse "no history",
                }),
            });
        }
        if (cands.items.len == 0) {
            try err.writeAll("nowhere to run");
            for (notes.items) |n| try err.print(" | {s}", .{n});
            try err.writeAll("\n");
            return 1;
        }
        var pick: ?usize = null;
        var known = false;
        for (cands.items, 0..) |c, i| {
            const t = c.total orelse continue;
            known = true;
            if (pick == null or t < cands.items[pick.?].total.?) pick = i;
        }
        if (!known) {
            for (cands.items, 0..) |c, i| {
                if (eql(c.host, "gpu-box") and eql(c.res, "cpu")) {
                    pick = i;
                    break;
                }
            } else pick = 0;
        }
        const c = cands.items[pick.?];
        var b1: [32]u8 = undefined;
        var b2: [32]u8 = undefined;
        try out.print("{s} {s} {s} {s}\n", .{
            c.host,
            c.res,
            if (c.run) |r| perl.intStr(&b1, r + 0.5) else "-",
            perl.fmtInt(&b2, c.share),
        });
        if (!known) try out.writeAll("no history anywhere: the default | ");
        try out.print("{s}, finish in {s}", .{ c.say, fmtSecs(&b1, c.total orelse c.wait) });
        for (cands.items, 0..) |o, i| if (i != pick.?) try out.print(" | {s}", .{o.say});
        for (notes.items) |n| try out.print(" | {s}", .{n});
        try out.writeAll("\n");
        return 0;
    }

    fn status(p: *const Listing, out: *Writer, host: []const u8) !void {
        var mine: std.ArrayList(*Run) = .empty;
        for (p.runs.items) |r| if (eql(r.host, host)) try mine.append(p.arena, r);
        std.mem.sort(*Run, mine.items, {}, byDir);
        for (mine.items) |r| {
            var b1: [32]u8 = undefined;
            var b2: [32]u8 = undefined;
            var b3: [32]u8 = undefined;
            const pred = if (r.pred) |v| try std.fmt.allocPrint(p.arena, "predicted {s}", .{fmtSecs(&b1, v)}) else "";
            const sep = if (pred.len > 0) ", " else "";
            var t: []const u8 = pred;
            if (r.ran) |v| {
                t = try std.fmt.allocPrint(p.arena, "ran {s}{s}{s}", .{ fmtSecs(&b2, v), sep, pred });
                // Runs of seconds are mostly startup and rounding: no percentage
                if (r.pred) |pv| if (pv >= 30) {
                    t = try std.fmt.allocPrint(p.arena, "{s} ({s}%)", .{ t, perl.fmtFloat(&b3, "%+.0f", 100 * (v / pv - 1)) });
                };
            } else if (r.started != null and (std.mem.startsWith(u8, r.state, "running") or std.mem.startsWith(u8, r.state, "paused"))) {
                t = try std.fmt.allocPrint(p.arena, "so far {s}{s}{s}", .{ fmtSecs(&b2, p.doneSoFar(r)), sep, pred });
            }
            var b4: [32]u8 = undefined;
            const started = if (r.started) |s| perl.iso(&b4, s) else "";
            const slot = if (perl.truthy(r.slot)) try std.fmt.allocPrint(p.arena, " ({s})", .{r.slot}) else "";
            try out.print("{s} | {s}{s} | {s} | {s} | {s}\n", .{ r.dir, r.state, slot, started, t, r.log });
        }
    }
};

/// The memory gate's view while placing: memory now, what comes back or goes when, and
/// when runs hold a cpu or gpu slot
const Gate = struct {
    arena: Allocator,
    /// null: no MemAvailable, so no gate
    mem: ?f64,
    /// [time, GB given back (taken: negative)]
    ev: std.ArrayList([2]f64) = .empty,
    /// [start, end] of runs holding a cpu or gpu slot, for the gate's late rule
    hold: std.ArrayList([2]f64) = .empty,

    /// Memory at T: now's, plus what has come back by then, less what has been taken
    fn memAt(g: *const Gate, t: f64) f64 {
        var m = g.mem.?;
        for (g.ev.items) |e| if (e[0] <= t) {
            m += e[1];
        };
        return m;
    }

    fn held(g: *const Gate, t: f64) bool {
        for (g.hold.items) |h| if (h[0] <= t and t < h[1]) return true;
        return false;
    }

    /// When a run needing NEED can start, at the queue's head from HEAD and a slot free
    /// at T0. The gate's clock starts the first time the head sees too little memory,
    /// slot or not; memory and holds change only at events, so those (and clock + 20
    /// min) suffice. Times pass through Perl's number-as-text (%.15g), as lab-place.pl's
    /// hash keys did
    fn start(g: *const Gate, head: f64, t0: f64, need: f64) !f64 {
        if (g.mem == null) return t0;
        var seen: std.StringHashMapUnmanaged(void) = .empty;
        var ts: std.ArrayList(f64) = .empty;
        const Add = struct {
            fn add(gg: *const Gate, s: *std.StringHashMapUnmanaged(void), l: *std.ArrayList(f64), from: f64, v: f64) !void {
                if (!(v >= from)) return;
                var b: [64]u8 = undefined;
                const text = perl.fmtFloat(&b, "%.15g", v);
                const gop = try s.getOrPut(gg.arena, text);
                if (gop.found_existing) return;
                gop.key_ptr.* = try gg.arena.dupe(u8, text);
                try l.append(gg.arena, perl.num(text));
            }
        }.add;
        try Add(g, &seen, &ts, head, head);
        try Add(g, &seen, &ts, head, t0);
        for (g.ev.items) |e| try Add(g, &seen, &ts, head, e[0]);
        for (g.hold.items) |h| try Add(g, &seen, &ts, head, h[1]);
        perl.sortAsc(ts.items);
        var since: ?f64 = null;
        var i: usize = 0;
        while (i < ts.items.len) : (i += 1) {
            const t = ts.items[i];
            const m = g.memAt(t);
            if (m < need and since == null) {
                since = t;
                try ts.append(g.arena, t + gate_max_wait);
                perl.sortAsc(ts.items[i + 1 ..]);
            }
            if (t < t0) continue;
            if (m >= need) return t;
            if (t < since.? + gate_max_wait) continue;
            if (m >= need / 2 or !g.held(t)) return t;
        }
        // Every run has ended by the last event, so no slot is held
        const late = if (since) |s| s + gate_max_wait else t0;
        return if (late > t0) late else t0;
    }
};

/// /League (up|unknown)/: what the line says League is, when up or unknown
fn leagueUp(line: []const u8) ?[]const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, line, from, "League ")) |i| : (from = i + 1) {
        const rest = line[i + "League ".len ..];
        if (std.mem.startsWith(u8, rest, "up")) return "up";
        if (std.mem.startsWith(u8, rest, "unknown")) return "unknown";
    }
    return null;
}

fn byDir(_: void, a: *Run, b: *Run) bool {
    return std.mem.lessThan(u8, a.dir, b.dir);
}

fn hostIndex(h: []const u8) ?usize {
    for (hosts, 0..) |x, i| if (eql(x, h)) return i;
    return null;
}

fn recent(rs: anytype) @TypeOf(rs) {
    return if (rs.len > recent_n) rs[rs.len - recent_n ..] else rs;
}

fn live(r: *const Run) bool {
    return std.mem.startsWith(u8, r.state, "running") or std.mem.startsWith(u8, r.state, "paused") or std.mem.startsWith(u8, r.state, "queued");
}

fn fast(t: ?f64) bool {
    return if (t) |v| @trunc(v) <= 60 else false;
}

/// Seconds of [from, to] the run spent stopped by the League watcher
fn paused(r: *const Run, from: f64, to: f64) f64 {
    var total: f64 = 0;
    var since: ?f64 = null;
    for (r.pauses) |p| {
        if (p.stop) {
            if (since == null) since = p.t;
        } else if (since) |s| {
            total += clip(s, p.t, from, to);
            since = null;
        }
    }
    if (since) |s| total += clip(s, to, from, to);
    return total;
}

fn clip(s0: f64, e0: f64, from: f64, to: f64) f64 {
    const s = if (s0 < from) from else s0;
    const e = if (e0 > to) to else e0;
    return if (e > s) e - s else 0;
}

fn ran(r: *const Run) ?f64 {
    if (!eql(r.state, "exit 0")) return null;
    const s = r.started orelse return null;
    const e = r.ended orelse return null;
    // WSL's clock can step back a second: never below 0
    const t = e - s - paused(r, s, e);
    return if (t > 0) t else 0;
}

/// The program's own words: a shell line ("uptime; ./meiolol-lab bench ...") is cut to
/// the words after the binary
fn programWords(arena: Allocator, args: []const u8) ![]const []const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, args, from, "./meiolol")) |i| : (from = i + 1) {
        var j = i + "./meiolol".len;
        if (std.mem.startsWith(u8, args[j..], "-lab") and j + 4 < args.len and perl.isSpace(args[j + 4])) {
            j += 4;
        } else if (!(j < args.len and perl.isSpace(args[j]))) continue;
        while (j < args.len and perl.isSpace(args[j])) j += 1;
        const end = std.mem.indexOfScalarPos(u8, args, j, '\n') orelse args.len;
        return perl.words(arena, args[j..end]);
    }
    return perl.words(arena, args);
}

fn pathChar(c: u8) bool {
    return snapChar(c) or c == '/';
}

fn snapChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_' or c == '.' or c == '+' or c == '-';
}

/// Snapshot paths among ARGS's words (~/ or absolute, up to the snap-* dir)
fn inputs(arena: Allocator, args: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    for (try programWords(arena, args)) |w0| {
        const w = if (w0.len > 0 and (w0[0] == '"' or w0[0] == '\'')) w0[1..] else w0;
        var q: usize = if (std.mem.startsWith(u8, w, "~/")) 2 else if (std.mem.startsWith(u8, w, "/")) 1 else continue;
        const path = while (q < w.len) : (q += 1) {
            if (std.mem.startsWith(u8, w[q..], "snap-") and q + 5 < w.len and snapChar(w[q + 5])) {
                var e = q + 5;
                while (e < w.len and snapChar(w[e])) e += 1;
                break w[0..e];
            }
            if (!pathChar(w[q])) break null;
        } else null;
        const p = path orelse continue;
        if (std.mem.indexOf(u8, p, "..") != null) continue;
        try out.append(arena, p);
    }
    return out.items;
}

/// The first `snap-*` in ARGS
fn snapOf(args: []const u8) ?[]const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, args, from, "snap-")) |i| : (from = i + 1) {
        var e = i + 5;
        while (e < args.len and snapChar(args[e])) e += 1;
        if (e > i + 5) return args[i..e];
    }
    return null;
}

/// -Dcand=DIR's last part
fn candOf(build: []const u8) ?[]const u8 {
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, build, from, "-Dcand=")) |i| : (from = i + 1) {
        const s = i + "-Dcand=".len;
        var e = s;
        while (e < build.len and !perl.isSpace(build[e])) e += 1;
        const tok = build[s..e];
        var k = tok.len;
        while (k > 0) {
            k -= 1;
            if (tok[k] == '/' and k + 1 < tok.len and tok[k + 1] != '/') {
                const rest = tok[k + 1 ..];
                return rest[0 .. std.mem.indexOfScalar(u8, rest, '/') orelse rest.len];
            }
        }
        if (tok.len > 0 and tok[0] != '/') return tok[0 .. std.mem.indexOfScalar(u8, tok, '/') orelse tok.len];
    }
    return null;
}

/// --name V among words (the last one given)
fn flagValue(w: []const []const u8, name: []const u8) ?[]const u8 {
    var v: ?[]const u8 = null;
    if (w.len < 2) return null;
    for (0..w.len - 1) |i| {
        if (eql(w[i], name)) v = w[i + 1];
    }
    return v;
}

/// Keys from most to least specific, with a label for the explanation
fn keysFor(arena: Allocator, bin: []const u8, args: []const u8, build: []const u8) ![]const Key {
    const w = try programWords(arena, args);
    const w0: ?[]const u8 = if (w.len > 0) w[0] else null;
    // python: the script is the command (BIN python/SCRIPT), its first arg a path
    var cmd: []const u8 = if (std.mem.startsWith(u8, bin, "python") or w0 == null) bin else try std.fmt.allocPrint(arena, "{s} {s}", .{ bin, w0.? });
    var fine = cmd;
    if (w0 != null and eql(w0.?, "exp") and w.len >= 2) {
        cmd = try std.fmt.allocPrint(arena, "{s} {s}", .{ cmd, w[1] });
        fine = cmd;
        for ([_]usize{ 3, 4 }) |i| {
            if (i < w.len) fine = try std.fmt.allocPrint(arena, "{s} {s}", .{ fine, w[i] });
        }
    }
    // netcheck's nets differ by orders of magnitude (big on the GPU, small, resid)
    if (w0 != null and eql(w0.?, "netcheck")) {
        cmd = try std.fmt.allocPrint(arena, "{s} --net {s}", .{ cmd, flagValue(w, "--net") orelse "small" });
        fine = cmd;
    }
    const with = if (candOf(build)) |c| try std.fmt.allocPrint(arena, "{s}, candidate {s}", .{ fine, c }) else fine;
    var keys: std.ArrayList(Key) = .empty;
    try keys.append(arena, .{ .key = try std.fmt.allocPrint(arena, "args {s} {s} {s}", .{ bin, build, args }), .label = "same args", .kind = .args });
    if (snapOf(args)) |snap| {
        try keys.append(arena, .{ .key = try std.fmt.allocPrint(arena, "{s} @ {s}", .{ with, snap }), .label = try std.fmt.allocPrint(arena, "{s} on {s}", .{ with, snap }), .kind = .snap });
        try keys.append(arena, .{ .key = try std.fmt.allocPrint(arena, "{s} @ {s}", .{ fine, snap }), .label = try std.fmt.allocPrint(arena, "{s} on {s}", .{ fine, snap }), .kind = .snap });
    }
    try keys.append(arena, .{ .key = fine, .label = fine, .kind = .cmd });
    try keys.append(arena, .{ .key = cmd, .label = cmd, .kind = .cmd });
    var out: std.ArrayList(Key) = .empty;
    for (keys.items) |k| {
        for (out.items) |o| {
            if (eql(o.key, k.key)) break;
        } else try out.append(arena, k);
    }
    return out.items;
}

const work_names = [_][]const u8{ "trials", "--boot", "--seeds" };

/// `linear` flags' values in ARGS (a comma list counts its items), and `trials`: a
/// --serial sweep job's trials, run one after another (lab-sweep.sh joins them by
/// ` ; `). Parallel packs (`&`) share the slot's cores: no clear scale, left out
fn work(arena: Allocator, args: []const u8) ![3]?f64 {
    var v: [3]?f64 = .{ null, null, null };
    const padded = try std.fmt.allocPrint(arena, " {s} ", .{args});
    var trials: f64 = 0;
    var seg_from: usize = 0;
    var i: usize = 0;
    while (i <= padded.len) {
        const at_sep = i + 3 <= padded.len and perl.isSpace(padded[i]) and padded[i + 1] == ';' and perl.isSpace(padded[i + 2]);
        if (at_sep or i == padded.len) {
            if (hasOut(padded[seg_from..i])) trials += 1;
            if (i == padded.len) break;
            i += 3;
            seg_from = i;
        } else i += 1;
    }
    v[0] = if (trials > 0) trials else 1;
    const w = try programWords(arena, args);
    if (w.len < 2) return v;
    for (0..w.len - 1) |j| {
        const slot: usize = for (linear, 0..) |f, k| {
            if (eql(w[j], f)) break k + 1;
        } else continue;
        const x = w[j + 1];
        // Kept when true as Perl sees it: "00" is, a count of 0 isn't
        if (isDecimal(x)) {
            if (perl.truthy(x)) v[slot] = perl.num(x);
        } else if (x[0] != '-') {
            const items = (try perl.split(arena, x, ',')).len;
            if (items > 0) v[slot] = @floatFromInt(items);
        }
    }
    return v;
}

/// /\s--out\s/
fn hasOut(s: []const u8) bool {
    var i: usize = 0;
    while (std.mem.indexOfPos(u8, s, i, "--out")) |at| : (i = at + 1) {
        if (at > 0 and perl.isSpace(s[at - 1]) and at + 5 < s.len and perl.isSpace(s[at + 5])) return true;
    }
    return false;
}

/// /^\d+(\.\d+)?$/
fn isDecimal(s: []const u8) bool {
    const dot = std.mem.indexOfScalar(u8, s, '.');
    const int_part = s[0 .. dot orelse s.len];
    if (int_part.len == 0 or !allDigits(int_part)) return false;
    if (dot) |d| return d + 1 < s.len and allDigits(s[d + 1 ..]);
    return true;
}

/// The memory gate's key: BIN and the first word less punctuation
fn memKey(arena: Allocator, bin: []const u8, args: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, bin, "python")) return bin;
    const w = try perl.words(arena, args);
    var out: std.ArrayList(u8) = .empty;
    try out.appendSlice(arena, bin);
    try out.append(arena, ' ');
    if (w.len > 0) for (w[0]) |c| {
        if (!std.ascii.isPrint(c) or std.ascii.isAlphanumeric(c) or c == ' ') try out.append(arena, c);
    };
    return out.items;
}

fn cudaUse(arena: Allocator, bin: []const u8, args: []const u8) ![]const u8 {
    if (!eql(bin, "meiolol-lab")) return "none";
    const w = try programWords(arena, args);
    const cmd = if (w.len > 0) w[0] else "";
    if (eql(cmd, "gpu-smoke")) return "gpu";
    // netcheck: only the big net is on the GPU (small and resid on CPU threads)
    if (eql(cmd, "netcheck")) return if (eql(flagValue(w, "--net") orelse "", "big")) "gpu" else "none";
    if (!eql(cmd, "bench") and !eql(cmd, "draftbench")) return "none";
    var devices: []const u8 = "cpu1,cpu,gpu";
    if (w.len >= 2) for (0..w.len - 1) |i| {
        if (eql(w[i], "--devices")) devices = w[i + 1];
    };
    var gpu = false;
    var other = false;
    for (try perl.split(arena, devices, ',')) |d| {
        if (eql(d, "gpu")) gpu = true else other = true;
    }
    if (!gpu) return "none";
    return if (other) "mixed" else "gpu";
}

/// "Ns" under 100 s, "N.Nm" under 6000 s, else hours
fn fmtSecs(buf: []u8, s: f64) []const u8 {
    var tmp: [32]u8 = undefined;
    const body, const unit: u8 = if (s < 100)
        .{ perl.fmtInt(&tmp, s + 0.5), 's' }
    else if (s < 6000)
        .{ perl.fmtFloat(&tmp, "%.1f", s / 60), 'm' }
    else
        .{ perl.fmtFloat(&tmp, "%.1f", s / 3600), 'h' };
    return std.fmt.bufPrint(buf, "{s}{c}", .{ body, unit }) catch unreachable;
}

fn fmtOpt(buf: []u8, s: ?f64) []const u8 {
    return if (s) |v| fmtSecs(buf, v) else "?";
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn field(f: []const []const u8, i: usize) []const u8 {
    return if (i < f.len) f[i] else "";
}

fn pair(arena: Allocator, a: []const u8, b: []const u8) ![]const u8 {
    return std.fmt.allocPrint(arena, "{s}\x00{s}", .{ a, b });
}

fn allDigits(s: []const u8) bool {
    for (s) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

/// /^[\d.]+$/
fn decimalish(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| if (!std.ascii.isDigit(c) and c != '.') return false;
    return true;
}

fn sortStrings(xs: [][]const u8) void {
    std.mem.sort([]const u8, xs, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);
}

const testing = std.testing;

// place-cases.txt: `$ ARGS` (tab-separated; `$+` with LAB_AUTO_MAC=1), then what
// lab-place.pl printed for them on listing.tsv (stderr when it failed), then `? EXIT`
test "lab-place answers as lab-place.pl did on a listing cut from real runs" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const listing = @embedFile("../testdata/labtools/listing.tsv");
    var cases = std.mem.splitScalar(u8, @embedFile("../testdata/labtools/place-cases.txt"), '\n');
    var n: usize = 0;
    while (cases.next()) |head| {
        if (head.len == 0) continue;
        const auto_mac = std.mem.startsWith(u8, head, "$+ ");
        try testing.expect(auto_mac or std.mem.startsWith(u8, head, "$ "));
        var args: std.ArrayList([]const u8) = .empty;
        var it = std.mem.splitScalar(u8, head[if (auto_mac) 3 else 2..], '\t');
        while (it.next()) |a| try args.append(arena, a);
        var want: std.ArrayList(u8) = .empty;
        const code = while (cases.next()) |l| {
            if (std.mem.startsWith(u8, l, "? ")) break try std.fmt.parseInt(u8, l[2..], 10);
            try want.print(arena, "{s}\n", .{l});
        } else return error.TestUnexpectedResult;
        var in: std.Io.Reader = .fixed(listing);
        var out: std.Io.Writer.Allocating = .init(arena);
        var err: std.Io.Writer.Allocating = .init(arena);
        const got = try main(arena, args.items, &in, auto_mac, &out.writer, &err.writer);
        try testing.expectEqual(code, got);
        try testing.expectEqualStrings(want.items, if (code == 0) out.written() else err.written());
        n += 1;
    }
    try testing.expectEqual(@as(usize, 26), n);
}

test "keys go from same args to the bare command" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const keys = try keysFor(arena_state.allocator(), "meiolol-lab", "uptime; ./meiolol-lab exp run ~/s/snap-1 win-x win --boot 4", "-Dcand=src/lab/cand/win-x/");
    try testing.expectEqual(@as(usize, 5), keys.len);
    try testing.expectEqualStrings("args meiolol-lab -Dcand=src/lab/cand/win-x/ uptime; ./meiolol-lab exp run ~/s/snap-1 win-x win --boot 4", keys[0].key);
    try testing.expectEqualStrings("meiolol-lab exp run win-x win, candidate win-x @ snap-1", keys[1].key);
    try testing.expectEqualStrings("meiolol-lab exp run win-x win on snap-1", keys[2].label);
    try testing.expectEqualStrings("meiolol-lab exp run win-x win", keys[3].key);
    try testing.expectEqualStrings("meiolol-lab exp run", keys[4].key);
}

test "work counts serial trials and linear flags" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const w = try work(a, "uptime; ./meiolol-lab netcheck x --seeds 1,2,3 --out t01 > t01.log ; ./meiolol-lab netcheck x --out t02 --boot 40");
    try testing.expectEqual(@as(?f64, 2), w[0]);
    try testing.expectEqual(@as(?f64, 40), w[1]);
    try testing.expectEqual(@as(?f64, 3), w[2]);
    // A pack (&) is one slot's worth of trials side by side: no scale
    const p = try work(a, "netcheck x --out t01 & ./meiolol-lab netcheck x --out t02 & wait");
    try testing.expectEqual(@as(?f64, 1), p[0]);
    try testing.expectEqual(@as(?f64, null), p[1]);
}

test "inputs: snapshot dirs under ~/ or /, not through .." {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const got = try inputs(arena_state.allocator(), "uptime; ./meiolol-lab eval \"~/ml/snaps/snap-1/x\" /abs/snap-2 ~/a/../snap-3 ~/snap- rel/snap-4");
    try testing.expectEqual(@as(usize, 2), got.len);
    try testing.expectEqualStrings("~/ml/snaps/snap-1", got[0]);
    try testing.expectEqualStrings("/abs/snap-2", got[1]);
}
