//! AdminPage: /admin/ (private) as one island. The server renders it empty ("Loading");
//! wasm/admin.zig fetches admin.bin (the box's snapshot each web round), api/live.bin
//! (the last 3 h, polled) and /auth/me.bin, sets `now` from the clock before each draw,
//! and does what `want` asks after an update (an action, an account change). Tabs in the
//! URL (#tab=ops); the chart, traffic, ops and models tabs are islands of their own
const std = @import("std");
const tree = @import("tree.zig");
const url = @import("url.zig");
const fmt = @import("fmt.zig");
const phrase = @import("phrase.zig");
const card = @import("card.zig");
const tabs = @import("tabs.zig");
const strip = @import("strip.zig");
const badge = @import("badge.zig");
const button = @import("button.zig");
const alertband = @import("alertband.zig");
const actionbutton = @import("actionbutton.zig");
const segmented = @import("segmented.zig");
const timechart = @import("timechart.zig");
const charts = @import("admincharts.zig");
const ad = @import("admindata.zig");
const ac = @import("accountsdata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const Phrase = phrase.Phrase;
const H = tree.H;
const N = tree.N;
const Text = tree.Text;

pub const name = "AdminPage";
pub const scope = .{".c-admin"};
pub const sel = "[data-island=admin]";
/// An invite or reset token's link
pub const join_link = "https://meio.lol/join#{s}";

/// Keys as the old page's (admin.js), so its links carry over
pub const Tab = enum { overview, crawler, riot, storage, ingest, models, traffic, deploys, logs, accounts, ops };

/// The old page's links ("#crawler", "#models/win", "#training") in this page's form
/// ("#tab=crawler", "#tab=models&cat=win"); null when `h` is no such link
pub fn legacyHash(buf: []u8, h: []const u8) ?[]const u8 {
    if (h.len < 2 or h[0] != '#' or std.mem.findScalar(u8, h, '=') != null) return null;
    const slash = std.mem.findScalar(u8, h, '/');
    const key = h[1 .. slash orelse h.len];
    const tab = if (std.mem.eql(u8, key, "model") or std.mem.eql(u8, key, "training")) "models" else key;
    _ = std.meta.stringToEnum(Tab, tab) orelse return null;
    const cat = if (slash) |i| h[i + 1 ..] else "";
    return (if (cat.len > 0)
        std.fmt.bufPrint(buf, "#tab={s}&cat={s}", .{ tab, cat })
    else
        std.fmt.bufPrint(buf, "#tab={s}", .{tab})) catch null;
}

/// The box's admin actions (admin_api.zig `actions`)
pub const Act = enum {
    crawl_restart,
    crawl_stop,
    crawl_start,
    site_build,
    eval_run,
    health_check,

    pub fn path(a: Act) []const u8 {
        return switch (a) {
            inline else => |x| comptime blk: {
                var s: [@tagName(x).len]u8 = @tagName(x)[0..].*;
                std.mem.replaceScalar(u8, &s, '_', '-');
                const out = s;
                break :blk &out;
            },
        };
    }
};

/// What the page asks of the wasm after an update
pub const Want = union(enum) {
    none,
    /// Every source again
    refresh,
    run: Act,
    logout,
    accounts,
    invite: u8,
    /// Account row, role index into `accounts.roles`
    role: [2]u16,
    disable: u16,
    reset: u16,
    copy,
};

/// A one-use link just made: shown once
pub const Link = struct { reset: ?u16 = null, role: u8 = 0, token: []const u8 };

pub const Page = struct {
    tab: Tab = .overview,
    snap: ?*const ad.Snapshot = null,
    live: ?*const ad.Live = null,
    me: ?*const ac.Me = null,
    accounts: ?*const ac.Accounts = null,
    /// The clock, unix s (the wasm's, before each draw)
    now: i64 = 0,
    /// When live.bin last answered; down: the last try failed
    live_at: i64 = 0,
    live_down: bool = false,
    /// The snapshot didn't load
    snap_failed: bool = false,
    want: Want = .none,
    /// The action this page started, until live.bin shows its result
    running: ?Act = null,
    /// The last run from here: ok, and its output
    ran: ?struct { act: Act, ok: bool, output: []const u8 } = null,
    /// Invite: role index into `accounts.roles`; null: giveOf's default
    give: ?u8 = null,
    /// A role picked in a row, waiting for Make or Cancel
    pending: ?[2]u16 = null,
    link: ?Link = null,
    /// An account change failed
    acct_failed: bool = false,
    copied: bool = false,
    /// AdminCharts' (the chart tabs), kept so this island's URL writes keep it
    range: charts.Range = .day,

    pub const Url = struct { tab: Tab = .overview, range: charts.Range = .day };

    pub const Msg = union(enum) {
        tab: Tab,
        refresh,
        run: Act,
        logout,
        give: u8,
        invite,
        /// A row's role select changed: the new role is the event's value
        pick: u16,
        make,
        cancel,
        disable: u16,
        reset: u16,
        copy,
        done,
    };

    pub fn toUrl(p: *const Page) Url {
        return .{ .tab = p.tab, .range = p.range };
    }

    pub fn fromUrl(p: *Page, u: Url) void {
        p.tab = u.tab;
        p.range = u.range;
    }

    pub fn update(p: *Page, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .tab => |t| {
                p.tab = t;
                ev.push = true;
                if (t == .accounts and p.accounts == null) p.want = .accounts;
            },
            .refresh => p.want = .refresh,
            .run => |a| {
                p.running = a;
                p.ran = null;
                p.want = .{ .run = a };
            },
            .logout => p.want = .logout,
            .give => |i| p.give = i,
            .invite => p.want = .{ .invite = p.giveOf() orelse return },
            .pick => |row| {
                const l = p.accounts orelse return;
                for (l.roles, 0..) |r, i| if (std.mem.eql(u8, r, ev.text)) {
                    p.pending = .{ row, @intCast(i) };
                };
            },
            .make => if (p.pending) |x| {
                p.pending = null;
                p.want = .{ .role = x };
            },
            .cancel => p.pending = null,
            .disable => |row| p.want = .{ .disable = row },
            .reset => |row| p.want = .{ .reset = row },
            .copy => p.want = .copy,
            .done => {
                p.link = null;
                p.copied = false;
            },
        }
    }

    /// The signed-in role has `cap` (roles.zig Capability's name)
    pub fn can(p: *const Page, cap: []const u8) bool {
        const me = p.me orelse return false;
        for (me.can) |c| if (std.mem.eql(u8, c, cap)) return true;
        return false;
    }

    /// The invite's role: the one chosen, else private (the old page's default), else the
    /// lowest; never public
    pub fn giveOf(p: *const Page) ?u8 {
        const l = p.accounts orelse return null;
        if (p.give) |g| if (g < l.roles.len and !std.mem.eql(u8, l.roles[g], "public")) return g;
        var first: ?u8 = null;
        for (l.roles, 0..) |r, i| {
            if (std.mem.eql(u8, r, "private")) return @intCast(i);
            if (first == null and !std.mem.eql(u8, r, "public")) first = @intCast(i);
        }
        return first;
    }

    pub fn view(p: *Page, h: *H) N {
        return h.div(.{ .class = "c-admin", .data_island = "admin" }, .{
            head(p, h),
            if (p.snap) |s| body(p, h, s) else h.p(.{ .class = "wait", .role = "status" }, .{if (p.snap_failed) W.no_snap else W.loading}),
        });
    }
};

pub const W = struct {
    pub const title = plain("Admin");
    pub const loading = plain("Loading");
    pub const no_snap = plain("The snapshot (admin.bin) didn't load: Refresh to try again");
    pub const live = Phrase("Live, updated {t:text}");
    pub const snapshot = Phrase("Snapshot from {t:text}");
    pub const live_down = plain(" (live API unavailable)");
    pub const notes = plain("Notes");
    pub const desktop = plain("Desktop app");
    pub const refresh = plain("Refresh");
    pub const log_out = plain("Log out");
    pub const tabs_label = plain("Admin sections");

    pub const mins = Phrase("{n:count} min ago");
    pub const hours = Phrase("{n:count} h ago");
    pub const days = Phrase("{n:count} d ago");
    pub const just = plain("just now");
    pub const never = plain("never");
    pub const when = Phrase("{d:int} {m:text} {hh:text}:{mm:text}");

    pub const all_pass = plain("All checks pass");
    pub const spike = Phrase("Warnings: {k:text} {n:count} in the last hour, usually ~{u:count}");
    pub const see_log = plain("Logs");

    pub const crawler = plain("Crawler");
    pub const running = plain("running");
    pub const silent = plain("silent");
    pub const reporting = plain("reporting");
    pub const last_report = Phrase("last report {t:text}");
    pub const matches_day = plain("Matches / day");
    pub const timelines_day = plain("Timelines / day");
    pub const last_hour = plain("rate over the last hour");
    pub const stored = plain("Stored, 24 h");
    pub const matches = plain("matches");
    pub const key_use = plain("Riot key use");
    pub const per_min = Phrase("{n:count} requests / min");
    pub const queues = plain("Queues");
    pub const pending = Phrase("{a:count} matches, {b:count} timelines");
    pub const disk = plain("Disk");
    pub const used = Phrase("{n:pct} used");
    pub const free = Phrase("{n:dec} GB free");
    pub const deploy = plain("Last deploy");
    pub const deploy_ctx = Phrase("{s:text} {st:text}, {t:text}");
    pub const upload = plain("Site upload");
    pub const uploads_day = Phrase("{n:count} in the last 24 h");
    pub const recent = plain("Recent actions");

    pub const box = plain("Box");
    pub const services = plain("Services");
    pub const actions = plain("Actions");
    pub const busy = Phrase("Busy: {a:text} since {t:text}");
    pub const no_live = plain("The live API is unavailable: actions are off");
    pub const history = Phrase("Action history ({n:count})");
    pub const c_when = plain("When");
    pub const c_action = plain("Action");
    pub const c_result = plain("Result");
    pub const c_output = plain("Output");
    pub const deploys = plain("Deploys");
    pub const c_commit = plain("Commit");
    pub const unknown = plain("unknown");

    pub const accounts = plain("Accounts");
    pub const accounts_lead = plain("You can change accounts below your own role. The owner, and deleting an account: meiolol account over ssh.");
    pub const cannot = plain("Your role cannot manage accounts.");
    pub const acct_failed = plain("That change didn't go through: Refresh and try again.");
    pub const invite = plain("Invite link");
    pub const invite_hint = plain("One use, 7 days: they pick a username and password.");
    pub const role_label = plain("Role");
    pub const new_link = Phrase("New {r:text} account: send this link by chat. It is shown only now.");
    pub const reset_link = Phrase("Password reset for {u:text}: send this link by chat. It is shown only now.");
    pub const copy = plain("Copy");
    pub const copied = plain("Copied");
    pub const done = plain("Done");
    pub const c_login = plain("Login");
    pub const c_status = plain("Status");
    pub const c_seen = plain("Last seen");
    pub const c_made = plain("Made");
    pub const active = plain("active");
    pub const disabled = plain("disabled");
    pub const make_q = Phrase("Make {u:text} {r:text}?");
    pub const make = plain("Make");
    pub const cancel = plain("Cancel");
    pub const disable = plain("Disable");
    pub const enable = plain("Enable");
    pub const disable_q = Phrase("Disable {u:text}? It is signed out everywhere and can't log in until enabled.");
    pub const reset = plain("Reset link");
    pub const role_of = Phrase("Role of {u:text}");
};

const tab_names = std.enums.EnumArray(Tab, Text).init(.{
    .overview = plain("Overview"),
    .crawler = plain("Crawler"),
    .riot = plain("Riot API"),
    .storage = plain("Storage"),
    .ingest = plain("Ingest"),
    .models = plain("Models"),
    .traffic = plain("Traffic"),
    .deploys = plain("Deploys"),
    .logs = plain("Logs"),
    .accounts = plain("Accounts"),
    .ops = plain("Controls"),
});

const act_names = std.enums.EnumArray(Act, Text).init(.{
    .crawl_restart = plain("Restart crawler"),
    .crawl_stop = plain("Stop crawler"),
    .crawl_start = plain("Start crawler"),
    .site_build = plain("Build site"),
    .eval_run = plain("Run eval"),
    .health_check = plain("Health check"),
});

const act_confirm = std.enums.EnumArray(Act, ?Text).init(.{
    .crawl_restart = plain("Restart the crawler? It resumes from its queues."),
    .crawl_stop = plain("Stop and disable the crawler? No new games until it is started again."),
    .crawl_start = plain("Start (and enable) the crawler?"),
    .site_build = plain("Build and upload the site now?"),
    .eval_run = plain("Run meiolol eval now? About 10 minutes at low priority."),
    .health_check = null,
});

pub const kind_names = std.enums.EnumArray(ad.Kind, Text).init(.{
    .rate_limit = plain("our key's 429s"),
    .riot_busy = plain("Riot busy (429 server)"),
    .riot_server = plain("Riot 5xx"),
    .riot_blocked = plain("Riot refused"),
    .db_busy = plain("database busy"),
    .network = plain("network"),
    .other = plain("other"),
});

/// systemd units, as the old page names them
const units = [_]struct { []const u8, Text }{
    .{ "meiolol-crawl", plain("Crawler") },
    .{ "meiolol-web", plain("Web loop") },
    .{ "meiolol-render@a", plain("Renderer a") },
    .{ "meiolol-render@b", plain("Renderer b") },
    .{ "meiolol-backup", plain("Backups") },
    .{ "meiolol-health", plain("Health") },
};

/// A crawler with no report line this long is silent
const silent_s = 900;
/// Riot's per-region app limit we run at, per minute
pub const per_region_min = 50;

fn head(p: *Page, h: *H) N {
    const live = p.live != null and !p.live_down;
    return h.div(.{ .class = "top" }, .{
        h.el(.h1, .{}, .{W.title}),
        h.span(.{ .class = "status", .role = "status" }, .{
            if (live) W.live.with(h, .{ .t = ago(h, p.now - p.live_at).s }) else null,
            if (!live) if (p.snap) |s| W.snapshot.with(h, .{ .t = ago(h, p.now - s.now).s }) else null else null,
            if (!live and p.live_down) W.live_down else null,
        }),
        card.spacer(h),
        button.view(h, .{ .v = .quiet, .s = .s, .href = "/admin/notes" }, .{W.notes}),
        button.view(h, .{ .v = .quiet, .s = .s, .href = "/admin/desktop/meiolol-desktop.zip" }, .{W.desktop}),
        button.view(h, .{ .s = .s, .on = h.on(p, .refresh) }, .{W.refresh}),
        if (p.me) |me| h.span(.{ .class = "me" }, .{
            h.a(.{ .href = "/account" }, .{me.username}),
            button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .logout) }, .{W.log_out}),
        }) else null,
    });
}

fn body(p: *Page, h: *H, s: *const ad.Snapshot) N {
    var items: [tab_names.values.len]tabs.Item = undefined;
    for (&items, 0..) |*it, i| {
        const t: Tab = @fromBackingInt(@intCast(i));
        it.* = .{ .label = tab_names.get(t), .selected = p.tab == t, .on = h.on(p, .{ .tab = t }) };
    }
    return h.div(.{ .class = "body" }, .{
        tabs.view(h, W.tabs_label, &items, &.{}),
        switch (p.tab) {
            .overview => overview(p, h, s),
            .ops => controls(p, h, s),
            .accounts => accountsTab(p, h),
            // AdminCharts, AdminTraffic, AdminOps and AdminModels, the islands below
            .crawler, .riot, .storage, .ingest, .traffic, .deploys, .logs, .models => .none,
        },
    });
}

// Data the tabs share

/// Live's when it has buckets (fresher), else the snapshot's
fn crawlOf(p: *const Page, s: *const ad.Snapshot) ad.Crawl {
    if (p.live) |l| if (l.crawl.buckets.len > 0) return l.crawl;
    return s.crawl;
}

/// Sums over the buckets that start in the last `span` s
fn sumSince(c: ad.Crawl, now: i64, span: i64, comptime f: fn (ad.Bucket) u64) u64 {
    var n: u64 = 0;
    for (c.buckets, 0..) |b, i| {
        if (c.start + @as(i64, @intCast(i)) * c.step >= now - span) n += f(b);
    }
    return n;
}

fn sumRegions(x: [ad.regions]u32) u64 {
    var n: u64 = 0;
    for (x) |v| n += v;
    return n;
}

fn bm(b: ad.Bucket) u64 {
    return sumRegions(b.m);
}
fn bt(b: ad.Bucket) u64 {
    return sumRegions(b.t);
}
fn breq(b: ad.Bucket) u64 {
    return sumRegions(b.req);
}

fn healthOf(p: *const Page, s: *const ad.Snapshot) []const u8 {
    if (p.live) |l| if (!p.live_down) return l.health;
    return s.health;
}

fn pending(gs: []const ad.Group) i64 {
    var n: i64 = 0;
    for (gs) |g| if (std.mem.endsWith(u8, g.key, "pending")) {
        n += g.n;
    };
    return n;
}

fn serviceState(p: *const Page, unit: []const u8) ?[]const u8 {
    const l = p.live orelse return null;
    for (l.services) |sv| if (std.mem.eql(u8, sv.unit, unit)) return sv.state;
    return null;
}

/// The banner: health's problem lines, then warning spikes (a kind's last hour 30+ and
/// over 3x its usual hourly rate in the snapshot's window)
fn health(p: *const Page, h: *H, s: *const ad.Snapshot) N {
    var lines: std.ArrayList(Text) = .empty;
    var it = std.mem.tokenizeScalar(u8, healthOf(p, s), '\n');
    while (it.next()) |l| lines.append(h.mem, .{ .s = l }) catch {
        h.oom = true;
    };
    const problems = lines.items.len;
    const c = crawlOf(p, s);
    const hours = @max(@as(f64, @floatFromInt(s.crawl.buckets.len)) * @as(f64, @floatFromInt(s.crawl.step)) / 3600, 1);
    for (std.enums.values(ad.Kind)) |k| {
        const i = @backingInt(k);
        var last: u64 = 0;
        for (c.buckets, 0..) |b, j| {
            if (c.start + @as(i64, @intCast(j)) * c.step >= p.now - 3600) last += b.warnings[i];
        }
        var all: u64 = 0;
        for (s.crawl.buckets) |b| all += b.warnings[i];
        const usual = @as(f64, @floatFromInt(all)) / hours;
        if (last >= 30 and @as(f64, @floatFromInt(last)) > 3 * usual) lines.append(h.mem, W.spike.with(h, .{ .k = kind_names.get(k).s, .n = last, .u = @as(u64, @intFromFloat(@round(usual))) })) catch {
            h.oom = true;
        };
    }
    if (lines.items.len == 0) return alertband.view(h, .{ .state = .ok, .text = W.all_pass });
    return alertband.view(h, .{
        .state = if (problems > 0) .down else .warn,
        .text = lines.items[0],
        .more = @intCast(lines.items.len - 1),
        .link = .{ .href = "#tab=logs", .label = W.see_log },
    });
}

fn overview(p: *Page, h: *H, s: *const ad.Snapshot) N {
    const c = crawlOf(p, s);
    const report_age: ?i64 = if (c.last_report) |r| p.now - r else null;
    const silent = report_age == null or report_age.? > silent_s;
    const crawl_state = serviceState(p, "meiolol-crawl");
    const per_min = sumSince(c, p.now, 3600, breq) / 60;
    const disk = if (p.live) |l| l.disk orelse s.disk else s.disk;
    const q = if (p.live) |l| l.queues else s.queues;
    const pm = pending(q.match);
    const pt = pending(q.timeline);
    const events = if (p.live) |l| (if (l.deploys.len > 0) l.deploys else s.deploy_events) else s.deploy_events;
    var uploads_day: u64 = 0;
    for (s.uploads) |u| uploads_day += @intFromBool(u >= p.now - 86400);

    var tiles: std.ArrayList(strip.Item) = .empty;
    const add = struct {
        fn f(hh: *H, l: *std.ArrayList(strip.Item), it: strip.Item) void {
            l.append(hh.mem, it) catch {
                hh.oom = true;
            };
        }
    }.f;
    add(h, &tiles, .{
        .label = W.crawler,
        .value = if (crawl_state) |st| (if (std.mem.eql(u8, st, "active")) W.running else Text{ .s = st }) else if (silent) W.silent else W.reporting,
        .ctx = if (report_age) |a| W.last_report.with(h, .{ .t = ago(h, a).s }) else null,
        .answer = true,
        .href = "#tab=crawler",
    });
    add(h, &tiles, .{ .label = W.matches_day, .value = count(h, sumSince(c, p.now, 3600, bm) * 24), .ctx = W.last_hour, .href = "#tab=crawler" });
    add(h, &tiles, .{ .label = W.timelines_day, .value = count(h, sumSince(c, p.now, 3600, bt) * 24), .href = "#tab=crawler" });
    add(h, &tiles, .{ .label = W.stored, .value = count(h, sumSince(s.crawl, p.now, 86400, bm)), .ctx = W.matches, .href = "#tab=crawler" });
    add(h, &tiles, .{
        .label = W.key_use,
        .value = Phrase("{n:pct}").with(h, .{ .n = per_min * 100 / (per_region_min * ad.regions) }),
        .ctx = W.per_min.with(h, .{ .n = per_min }),
        .href = "#tab=riot",
    });
    add(h, &tiles, .{ .label = W.queues, .value = count(h, @intCast(@max(pm + pt, 0))), .ctx = W.pending.with(h, .{ .a = pm, .b = pt }), .href = "#tab=crawler" });
    if (disk) |d| add(h, &tiles, .{
        .label = W.disk,
        .value = W.used.with(h, .{ .n = if (d.size > 0) d.used * 100 / d.size else 0 }),
        .ctx = W.free.with(h, .{ .n = @as(f64, @floatFromInt(d.free)) / 1e9 }),
        .href = "#tab=storage",
    });
    if (events.len > 0) {
        const e = events[events.len - 1];
        add(h, &tiles, .{
            .label = W.deploy,
            .value = .{ .s = e.sha[0..@min(e.sha.len, 7)] },
            .ctx = W.deploy_ctx.with(h, .{ .s = e.step, .st = e.status, .t = ago(h, p.now - e.time).s }),
            .href = "#tab=deploys",
        });
    }
    if (s.uploads.len > 0) add(h, &tiles, .{
        .label = W.upload,
        .value = ago(h, p.now - s.uploads[s.uploads.len - 1]),
        .ctx = W.uploads_day.with(h, .{ .n = uploads_day }),
        .href = "#tab=ops",
    });
    const acts: []const ad.Action = if (p.live) |l| l.actions else &.{};
    return h.div(.{ .class = "tab" }, .{
        health(p, h, s),
        strip.view(h, tiles.items),
        if (acts.len > 0) card.view(h, .{ .flush = true }, &.{
            card.head(h, W.recent, null, &.{}),
            actionTable(h, p.now, acts[acts.len -| 5..]),
        }) else null,
    });
}

fn controls(p: *Page, h: *H, s: *const ad.Snapshot) N {
    const live = if (p.live_down) null else p.live;
    var rows = h.list();
    for (units, 0..) |u, i| {
        const st = serviceState(p, u[0]);
        const k: badge.Kind = if (st) |x| (if (std.mem.eql(u8, x, "active")) .us else if (std.mem.eql(u8, x, "inactive") and std.mem.startsWith(u8, u[0], "meiolol-render")) .neutral else .them) else .neutral;
        rows.add(h.tr(.{}, .{
            h.th(.{ .scope = "row" }, .{u[1]}),
            h.td(.{ .data_answer = i == 0 }, .{badge.view(h, k, .{if (st) |x| Text{ .s = x } else W.unknown})}),
        }));
    }
    const crawling = if (serviceState(p, "meiolol-crawl")) |x| std.mem.eql(u8, x, "active") else false;
    const eval_on = if (live) |l| l.eval_since != null else false;
    const held = if (live) |l| l.action else null;
    var btns = h.list();
    if (p.can("run_actions")) {
        const list: []const Act = if (crawling) &.{ .crawl_restart, .crawl_stop, .site_build, .eval_run, .health_check } else &.{ .crawl_start, .site_build, .eval_run, .health_check };
        for (list) |a| {
            const mine = if (p.ran) |r| r.act == a else false;
            btns.add(actionbutton.view(h, .{
                .id = h.fmt("act-{s}", .{a.path()}),
                .label = act_names.get(a),
                .confirm = act_confirm.get(a),
                .state = if (p.running != null and p.running.? == a) .busy else if (mine) (if (p.ran.?.ok) .ok else .failed) else .idle,
                .disabled = live == null or held != null or p.running != null or (a == .eval_run and eval_on),
                .on = h.on(p, .{ .run = a }),
                .output = if (mine and p.ran.?.output.len > 0) Text{ .s = p.ran.?.output } else null,
            }));
        }
    }
    const acts: []const ad.Action = if (p.live) |l| l.actions else &.{};
    var deploys = h.list();
    var di = s.deploys.len;
    while (di > 0) {
        di -= 1;
        const d = s.deploys[di];
        deploys.add(h.tr(.{}, .{ h.td(.{ .class = "mono" }, .{d.sha[0..@min(d.sha.len, 10)]}), h.td(.{}, .{when(h, d.time)}) }));
    }
    return h.div(.{ .class = "tab" }, .{
        health(p, h, s),
        card.view(h, .{}, &.{
            card.head(h, W.services, null, &.{}),
            h.table(.{ .class = "kv" }, .{h.tbody(.{}, .{rows.done()})}),
        }),
        if (p.can("run_actions")) card.view(h, .{}, &.{
            card.head(h, W.actions, null, &.{}),
            if (live == null) h.p(.{ .class = "note" }, .{W.no_live}) else .none,
            if (held) |r| h.p(.{ .class = "note", .role = "status" }, .{W.busy.with(h, .{ .a = r.name, .t = ago(h, p.now - r.since).s })}) else .none,
            h.div(.{ .class = "acts" }, .{btns.done()}),
        }) else null,
        h.el(.details, .{ .class = "c-card", .open = true }, .{
            h.el(.summary, .{}, .{W.history.with(h, .{ .n = acts.len })}),
            actionTable(h, p.now, acts),
        }),
        card.view(h, .{ .flush = true }, &.{
            card.head(h, W.deploys, null, &.{}),
            h.table(.{}, .{
                h.thead(.{}, .{h.tr(.{}, .{ h.th(.{ .data_answer = true }, .{W.c_commit}), h.th(.{}, .{W.c_when}) })}),
                h.tbody(.{}, .{deploys.done()}),
            }),
        }),
    });
}

/// Newest first
fn actionTable(h: *H, now: i64, acts: []const ad.Action) N {
    var rows = h.list();
    var i = acts.len;
    while (i > 0) {
        i -= 1;
        const a = acts[i];
        const k: badge.Kind = if (std.mem.eql(u8, a.result, "ok")) .us else if (std.mem.eql(u8, a.result, "refused")) .neutral else .them;
        rows.add(h.tr(.{}, .{
            h.td(.{ .class = "nw" }, .{ when(h, a.time), " ", h.small(.{}, .{ago(h, now - a.time)}) }),
            h.td(.{}, .{actLabel(a.name)}),
            h.td(.{}, .{badge.view(h, k, .{a.result})}),
            h.td(.{ .class = "out" }, .{if (a.output.len > 0) h.el(.details, .{}, .{ h.el(.summary, .{}, .{W.c_output}), h.div(.{ .class = "pre" }, .{a.output}) }) else null}),
        }));
    }
    return h.div(.{ .class = "tw" }, .{h.table(.{}, .{
        h.thead(.{}, .{h.tr(.{}, .{ h.th(.{}, .{W.c_when}), h.th(.{}, .{W.c_action}), h.th(.{ .data_answer = true }, .{W.c_result}), h.th(.{}, .{W.c_output}) })}),
        h.tbody(.{}, .{rows.done()}),
    })});
}

fn actLabel(path: []const u8) Text {
    for (std.enums.values(Act)) |a| if (std.mem.eql(u8, a.path(), path)) return act_names.get(a);
    return .{ .s = path };
}

fn accountsTab(p: *Page, h: *H) N {
    if (!p.can("manage_accounts")) return card.view(h, .{}, &.{ card.head(h, W.accounts, null, &.{}), h.p(.{}, .{if (p.me == null) W.loading else W.cannot}) });
    const l = p.accounts orelse return card.view(h, .{}, &.{ card.head(h, W.accounts, null, &.{}), h.p(.{ .role = "status" }, .{W.loading}) });
    var give: std.ArrayList(segmented.Item) = .empty;
    const chosen = p.giveOf();
    for (l.roles, 0..) |r, i| {
        if (std.mem.eql(u8, r, "public")) continue;
        give.append(h.mem, .{ .label = .{ .s = r }, .selected = chosen != null and chosen.? == i, .on = h.on(p, .{ .give = @intCast(i) }) }) catch {
            h.oom = true;
        };
    }
    var rows = h.list();
    for (l.accounts, 0..) |a, i| {
        const row: u16 = @intCast(i);
        var opts = h.list();
        if (a.manage) for (l.roles) |r| opts.add(h.el(.option, .{ .value = r, .selected = std.mem.eql(u8, r, a.role) }, .{r}));
        const asked = if (p.pending) |x| x[0] == row else false;
        rows.add(h.tr(.{ .key = a.username }, .{
            h.th(.{ .scope = "row" }, .{a.username}),
            h.td(.{}, .{if (a.manage)
                h.el(.select, .{ .aria_label = W.role_of.with(h, .{ .u = a.username }), .on_change = h.on(p, .{ .pick = row }) }, .{opts.done()})
            else
                h.text(a.role)}),
            h.td(.{}, .{badge.view(h, if (a.disabled) .them else .us, .{if (a.disabled) W.disabled else W.active})}),
            h.td(.{}, .{if (a.last_seen) |t| ago(h, p.now - t) else W.never}),
            h.td(.{ .class = "nw" }, .{day(h, a.created)}),
            h.td(.{ .class = "row-acts" }, .{if (a.manage and asked) h.span(.{ .class = "pick", .role = "status" }, .{
                W.make_q.with(h, .{ .u = a.username, .r = l.roles[p.pending.?[1]] }),
                button.view(h, .{ .v = .primary, .s = .s, .on = h.on(p, .make) }, .{W.make}),
                button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .cancel) }, .{W.cancel}),
            }) else if (a.manage) h.span(.{ .class = "pick" }, .{
                actionbutton.view(h, .{
                    .id = h.fmt("dis-{d}", .{i}),
                    .label = if (a.disabled) W.enable else W.disable,
                    .confirm = if (a.disabled) null else W.disable_q.with(h, .{ .u = a.username }),
                    .on = h.on(p, .{ .disable = row }),
                }),
                button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .{ .reset = row }) }, .{W.reset}),
            }) else null}),
        }));
    }
    return card.view(h, .{}, &.{
        card.head(h, W.accounts, null, &.{}),
        h.p(.{ .class = "note" }, .{W.accounts_lead}),
        if (p.acct_failed) h.p(.{ .class = "note bad", .role = "alert" }, .{W.acct_failed}) else .none,
        h.div(.{ .class = "invite" }, .{
            segmented.view(h, .{ .s = .s, .label = W.role_label }, give.items),
            button.view(h, .{ .s = .s, .on = h.on(p, .invite) }, .{W.invite}),
            h.small(.{}, .{W.invite_hint}),
        }),
        if (p.link) |k| h.div(.{ .class = "link", .role = "status" }, .{
            h.p(.{}, .{if (k.reset) |r| W.reset_link.with(h, .{ .u = l.accounts[r].username }) else W.new_link.with(h, .{ .r = l.roles[k.role] })}),
            h.el(.input, .{ .readonly = true, .value = h.fmt(join_link, .{k.token}), .aria_label = W.copy }, .{}),
            button.view(h, .{ .s = .s, .on = h.on(p, .copy) }, .{if (p.copied) W.copied else W.copy}),
            button.view(h, .{ .v = .quiet, .s = .s, .on = h.on(p, .done) }, .{W.done}),
        }) else .none,
        h.div(.{ .class = "tw" }, .{h.table(.{}, .{
            h.thead(.{}, .{h.tr(.{}, .{
                h.th(.{}, .{W.c_login}),
                h.th(.{}, .{W.role_label}),
                h.th(.{ .data_answer = true }, .{W.c_status}),
                h.th(.{}, .{W.c_seen}),
                h.th(.{}, .{W.c_made}),
                h.th(.{}, .{}),
            })}),
            h.tbody(.{}, .{rows.done()}),
        })}),
    });
}

// Words for times and figures

fn count(h: *H, n: u64) Text {
    return Phrase("{n:count}").with(h, .{ .n = n });
}

pub fn ago(h: *H, s: i64) Text {
    if (s < 60) return W.just;
    const m = @divFloor(s, 60);
    if (m < 60) return W.mins.with(h, .{ .n = m });
    if (m < 48 * 60) return W.hours.with(h, .{ .n = @divFloor(m, 60) });
    return W.days.with(h, .{ .n = @divFloor(m, 24 * 60) });
}

const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

/// UK time ("28 Oct 14:05")
pub fn when(h: *H, at: i64) Text {
    const t = at + timechart.ukOffset(at);
    const c = fmt.civil(@intCast(@divFloor(t, 86400)));
    const sec = @mod(t, 86400);
    return W.when.with(h, .{ .d = c.day, .m = months[c.month - 1], .hh = h.fmt("{d:0>2}", .{@as(u32, @intCast(@divFloor(sec, 3600)))}), .mm = h.fmt("{d:0>2}", .{@as(u32, @intCast(@divFloor(@mod(sec, 3600), 60)))}) });
}

pub fn day(h: *H, at: i64) Text {
    const c = fmt.civil(@intCast(@divFloor(at + timechart.ukOffset(at), 86400)));
    return Phrase("{d:int} {m:text} {y:int}").with(h, .{ .d = c.day, .m = months[c.month - 1], .y = c.year });
}

pub const css =
    \\@layer components {
    \\  .c-admin { display: grid; gap: var(--sp-4); }
    \\  .c-admin .top { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-admin .top h1 { margin: 0; font-size: var(--fs-l); }
    \\  .c-admin .top .sp { flex: 1; }
    \\  .c-admin .status, .c-admin .note, .c-admin .wait { color: var(--muted); font-size: var(--fs-s); }
    \\  .c-admin .note { margin: 0; }
    \\  .c-admin .note.bad { color: var(--them); }
    \\  .c-admin .me { display: inline-flex; align-items: center; gap: var(--sp-1); font-size: var(--fs-s); }
    \\  .c-admin .body, .c-admin .tab { display: grid; gap: var(--sp-3); }
    \\  .c-admin .acts, .c-admin .invite, .c-admin .link, .c-admin .pick { display: flex; flex-wrap: wrap;
    \\    align-items: center; gap: var(--sp-2); }
    \\  .c-admin .acts { align-items: start; }
    \\  .c-admin .link input { flex: 1 1 16rem; min-width: 0; font-family: ui-monospace, monospace; }
    \\  .c-admin .tw { overflow-x: auto; }
    \\  .c-admin table { width: 100%; border-collapse: collapse; font-size: var(--fs-s); }
    \\  .c-admin :is(th, td) { padding: var(--sp-1) var(--sp-2); border-bottom: 1px solid var(--line);
    \\    text-align: start; vertical-align: top; }
    \\  .c-admin thead th { color: var(--muted); font-weight: var(--w-m); }
    \\  .c-admin table.kv th { font-weight: var(--w-b); width: 40%; }
    \\  .c-admin .nw { white-space: nowrap; }
    \\  .c-admin .nw small { color: var(--muted); }
    \\  .c-admin .mono, .c-admin .pre { font-family: ui-monospace, monospace; font-size: var(--fs-xs); }
    \\  .c-admin .pre { white-space: pre-wrap; overflow-wrap: anywhere; max-height: 20rem; overflow-y: auto; }
    \\  .c-admin details.c-card > summary { cursor: pointer; font-weight: var(--w-b); }
    \\  .c-admin .row-acts { white-space: nowrap; }
    \\  .c-admin .row-acts .pick { flex-wrap: nowrap; }
    \\  .c-admin tbody th { font-size: inherit; color: var(--text); text-transform: none; letter-spacing: normal; }
    \\}
    \\
;

pub const Demo = struct {
    /// Tue 28 Oct 2026 14:00 UTC
    pub const now: i64 = 1_793_196_000;
    const step = 300;
    const n = 24;

    fn buckets() [n]ad.Bucket {
        var out: [n]ad.Bucket = @splat(.{});
        for (&out, 0..) |*b, i| {
            b.covered = step;
            b.m = .{ 40, 12, 95, 8 };
            b.t = .{ 38, 11, 90, 7 };
            b.req = .{ 190, 185, 195, 180 };
            b.ids = .{ 3, 2, 6, 1 };
            b.ladder = 10;
            b.mastery = 25;
            b.platform_req = 40 + @as(u32, @intCast(i));
            b.commits = 60;
            b.pages_written = 9000;
            b.pages_read = 2500;
            b.queued_max = @intCast(20 + i * 4);
            if (i >= n - 12) b.warnings[@backingInt(ad.Kind.riot_busy)] = 4;
            if (i == 7) b.warnings[@backingInt(ad.Kind.rate_limit)] = 9;
        }
        // Not running for two buckets
        out[10] = .{};
        out[11] = .{};
        return out;
    }
    const bs = buckets();
    const messages = [_]ad.Message{
        .{ .text = "429 server: retry after 2 s (europe match-v5)", .kind = .riot_busy, .count = 48, .last = now - 120 },
        .{ .text = "429 application: backing off 11 s", .kind = .rate_limit, .count = 9, .last = now - 4 * 3600 },
    };
    const crawl: ad.Crawl = .{ .start = now - n * step, .step = step, .buckets = &bs, .restarts = &.{now - 12 * step}, .messages = &messages, .last_report = now - 40 };
    fn hist() [16]ad.HistoryRow {
        var out: [16]ad.HistoryRow = undefined;
        for (&out, 0..) |*r, i| {
            const k: u64 = @intCast(i);
            r.* = .{
                .time = now - 600 - @as(i64, @intCast(15 - i)) * 900,
                .matches = 2_400_000 + k * 1300,
                .timelines = 2_100_000 + k * 1200,
                .drafts = 1_900_000 + k * 1100,
                .players = 310_000 + k * 90,
                .ranks = 820_000,
                .match_queue = 1840 + k * 30,
                .timeline_queue = 900 - k * 20,
                .mastery = 500_000 + k * 400,
                .meiolol_db = 41_000_000_000 + k * 9_000_000,
                .timeline_db = 52_000_000_000 + k * 14_000_000,
                .raw_db = 18_000_000_000 + k * 6_000_000,
                .meiolol_wal = (k % 4) * 200_000_000,
                .disk_used = 131_000_000_000 + k * 30_000_000,
            };
        }
        return out;
    }
    const history = hist();
    pub const snap: ad.Snapshot = .{
        .now = now - 600,
        .days = 7,
        .health = "",
        .disk = .{ .size = 200e9, .used = 132e9, .free = 68e9 },
        .platforms = &.{ .{ .id = "euw1", .region = .europe }, .{ .id = "eun1", .region = .europe }, .{ .id = "kr", .region = .asia }, .{ .id = "na1", .region = .americas } },
        .files = &.{ .{ .name = "meiolol.db", .bytes = 41_100_000_000 }, .{ .name = "timeline.db", .bytes = 52_200_000_000 }, .{ .name = "raw.db", .bytes = 18_100_000_000 } },
        .counts = &.{ .{ .name = "matches", .rows = 2_419_500 }, .{ .name = "timeline.timelines", .rows = 2_118_000 }, .{ .name = "ranks", .rows = 820_000 } },
        .queues = .{ .match = &.{ .{ .key = "euw1 pending", .n = 1840 }, .{ .key = "euw1 done", .n = 90000 } }, .timeline = &.{.{ .key = "pending", .n = 312 }} },
        .players = &.{ .{ .key = "europe", .n = 190_000 }, .{ .key = "asia", .n = 70_000 }, .{ .key = "americas", .n = 50_000 } },
        .ladder = &.{ .{ .key = "emerald", .n = 410_000 }, .{ .key = "diamond", .n = 120_000 }, .{ .key = "master", .n = 9_000 } },
        .by_patch = &.{ .{ .key = "16.21", .n = 1_300_000 }, .{ .key = "16.20", .n = 1_100_000 } },
        .drafts = .{
            .rows = 400_000,
            .days = &.{
                .{ .day = @divFloor(now, 86400) - 3, .region = .{ 9_000, 4_000, 30_000, 0 }, .recent = .{ 0, 0, 0, 0 } },
                .{ .day = @divFloor(now, 86400) - 2, .region = .{ 40_000, 22_000, 120_000, 0 }, .recent = .{ 2_000, 1_000, 6_000, 0 } },
                .{ .day = @divFloor(now, 86400) - 1, .region = .{ 35_000, 20_000, 100_000, 0 }, .recent = .{ 9_000, 5_000, 30_000, 0 } },
                .{ .day = @divFloor(now, 86400), .region = .{ 6_000, 3_000, 11_000, 0 }, .recent = .{ 6_000, 3_000, 11_000, 0 } },
            },
            .platforms = &.{ .{ .key = "euw1", .n = 180_000 }, .{ .key = "eun1", .n = 81_000 }, .{ .key = "kr", .n = 49_000 }, .{ .key = "na1", .n = 90_000 } },
            .patches = &.{ .{ .key = "16.21", .n = 300_000 }, .{ .key = "16.20", .n = 100_000 } },
            .tiers = &.{ .{ .key = "emerald", .n = 250_000 }, .{ .key = "diamond", .n = 120_000 }, .{ .key = "unknown", .n = 30_000 } },
            .blue_wins = 201_000,
            .minutes = .{ 0, 0, 0, 3_000, 30_000, 110_000, 130_000, 80_000, 35_000, 9_000, 2_000, 600, 100 },
        },
        .crawl = crawl,
        .history = &history,
        .eval = &.{},
        .uploads = &.{ now - 90_000, now - 5_400 },
        .deploys = &.{ .{ .sha = "13c90240aa12bb34", .time = now - 26_000 }, .{ .sha = "c9e836bf23992353", .time = now - 3_000 } },
        .deploy_events = &.{.{ .time = now - 3_000, .sha = "c9e836bf23992353", .step = "live", .status = "ok", .detail = "" }},
        .eval_report = "",
        .storage = .{ .generated = now - 30_000, .rows = &.{
            .{ .db = "timeline", .name = "timelines", .kind = "table", .bytes = 47_000_000_000, .cells = 2_100_000 },
            .{ .db = "timeline", .name = "sqlite_autoindex_timelines_1", .kind = "index", .bytes = 120_000_000, .cells = 2_100_000 },
            .{ .db = "meiolol", .name = "matches", .kind = "table", .bytes = 21_000_000_000, .cells = 2_400_000 },
            .{ .db = "meiolol", .name = "drafts", .kind = "table", .bytes = 9_000_000_000, .cells = 1_900_000 },
            .{ .db = "meiolol", .name = "drafts_day", .kind = "index", .bytes = 400_000_000, .cells = 1_900_000 },
        } },
        .backups = .{ .bytes = 61_000_000_000, .files = 14, .newest = now - 20_000 },
        .riot = .{
            .app_limit = "20:1,100:120",
            .crawl_args = "--proxy 127.0.0.1:9090 --timelines 90 --raw-match-days 14 --raw-timeline-days 3 --keep-days 0 --min-tier emerald --ladder-per-hour 60 --ladder-refresh-hours 24",
            .key_problems = &.{.{ .time = now - 50_000, .text = "403 Forbidden: key rejected (match-v5 by-puuid)" }},
        },
    };
    const services = [_]ad.Service{
        .{ .unit = "meiolol-crawl", .state = "active" },
        .{ .unit = "meiolol-web", .state = "active" },
        .{ .unit = "meiolol-render@a", .state = "active" },
        .{ .unit = "meiolol-render@b", .state = "inactive" },
        .{ .unit = "meiolol-backup", .state = "failed" },
    };
    const actions = [_]ad.Action{
        .{ .time = now - 7_200, .name = "health-check", .result = "ok", .output = "" },
        .{ .time = now - 1_800, .name = "site-build", .result = "failed", .output = "web build: upload refused (403)\nretry in 60 s" },
        .{ .time = now - 900, .name = "crawl-restart", .result = "refused", .output = "another action is running" },
    };
    pub const live: ad.Live = .{
        .now = now,
        .services = &services,
        .health = "backups: newest is 31 h old\nbox disk: 66% used",
        .crawl = crawl,
        .queues = snap.queues,
        .disk = snap.disk,
        .actions = &actions,
        .deploys = &.{},
        .eval_since = null,
        .action = null,
    };
    pub const me: ac.Me = .{ .username = "jacob", .role = "owner", .can = &.{ "view_admin", "run_actions", "manage_accounts" } };
    pub const accounts: ac.Accounts = .{
        .accounts = &.{
            .{ .username = "jacob", .role = "owner", .created = now - 40 * 86400, .last_seen = now - 60, .disabled = false, .manage = false },
            .{ .username = "ethan", .role = "admin", .created = now - 30 * 86400, .last_seen = now - 3 * 86400, .disabled = false, .manage = true },
            .{ .username = "sam", .role = "private", .created = now - 9 * 86400, .last_seen = null, .disabled = true, .manage = true },
        },
        .roles = &.{ "public", "paid", "private", "admin" },
    };

    fn page(tab: Tab) Page {
        return .{ .tab = tab, .snap = &snap, .live = &live, .me = &me, .accounts = &accounts, .now = now, .live_at = now - 20 };
    }
};

pub fn gallery(g: *Gallery) void {
    const a = g.h.mem;
    const states = [_][]const u8{ "loading", "overview: two problems", "controls: a failed build", "controls: live API down", "accounts: a role asked, a link made", "snapshot failed" };
    for (states, 0..) |caption, i| {
        const p = a.create(Page) catch return;
        p.* = switch (i) {
            0 => .{},
            1 => Demo.page(.overview),
            2 => Demo.page(.ops),
            3 => Demo.page(.ops),
            4 => Demo.page(.accounts),
            else => .{ .snap_failed = true },
        };
        switch (i) {
            2 => p.ran = .{ .act = .site_build, .ok = false, .output = "web build: upload refused (403)" },
            3 => p.live_down = true,
            4 => {
                p.pending = .{ 1, 2 };
                p.link = .{ .role = 2, .token = "q3Vt9xYbW2nA7kLmP0sR" };
                p.acct_failed = true;
            },
            else => {},
        }
        g.addFill(caption, p.view(g.h));
    }
}

const testing = std.testing;

fn render(a: std.mem.Allocator, p: *Page) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const root = p.view(&h);
    try testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, root, &out.writer);
    return out.written();
}

fn expectHas(s: []const u8, wants: []const []const u8) !void {
    for (wants) |w| if (std.mem.find(u8, s, w) == null) {
        std.debug.print("missing {s} in {s}\n", .{ w, s });
        return error.TestExpectedEqual;
    };
}

test "admin overview: tiles from live over the snapshot, health lines then spikes" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = Demo.page(.overview);
    // Last hour 12 buckets: 155 matches each, x24
    try expectHas(try render(a, &p), &.{ "44,640", "Live, updated just now", "backups: newest is 31 h old", "+1 more", "1,840 matches, 312 timelines", "66% used", "c9e836b", "1 h ago", "Restart crawler" });
    p.live = null;
    // 48 riot_busy in the last hour against a usual 24 an hour: no spike
    try expectHas(try render(a, &p), &.{ "All checks pass", "Snapshot from 10 min ago" });
    // 10 h of window, 48 all in the last hour: usually ~5 an hour
    var big: [120]ad.Bucket = @splat(.{});
    for (big[120 - 12 ..]) |*x| x.warnings[@backingInt(ad.Kind.riot_busy)] = 4;
    var s = Demo.snap;
    s.crawl.start = Demo.now - 120 * Demo.step;
    s.crawl.buckets = &big;
    p.snap = &s;
    try expectHas(try render(a, &p), &.{ "Warnings: Riot busy (429 server) 48 in the last hour, usually ~5", "data-state=\"warn\"" });
}

test "admin controls: actions only for run_actions, off while one runs, the crawler's pair" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = Demo.page(.ops);
    var s = try render(a, &p);
    try expectHas(s, &.{ "Restart crawler", "Stop crawler", "Renderer b", "failed", "Action history (3)", "c9e836bf23" });
    try testing.expect(std.mem.find(u8, s, "Start crawler") == null);
    var ev: tree.Event = .{ .kind = .click };
    p.update(.{ .run = .site_build }, &ev);
    try testing.expectEqual(Want{ .run = .site_build }, p.want);
    s = try render(a, &p);
    try testing.expect(std.mem.count(u8, s, "disabled=\"\"") >= 4);
    const me: ac.Me = .{ .username = "pal", .role = "admin", .can = &.{"view_admin"} };
    p.me = &me;
    try testing.expect(std.mem.find(u8, try render(a, &p), "act-crawl-restart") == null);
}

test "admin accounts: pick then Make, invite with the chosen role, the URL keeps the tab" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = Demo.page(.accounts);
    var ev: tree.Event = .{ .kind = .change, .text = "paid" };
    p.update(.{ .pick = 1 }, &ev);
    try testing.expectEqual(@as(?[2]u16, .{ 1, 1 }), p.pending);
    try expectHas(try render(a, &p), &.{"Make ethan paid?"});
    p.update(.make, &ev);
    try testing.expectEqual(Want{ .role = .{ 1, 1 } }, p.want);
    try testing.expectEqual(@as(?[2]u16, null), p.pending);
    ev.text = "king";
    p.update(.{ .pick = 1 }, &ev);
    try testing.expectEqual(@as(?[2]u16, null), p.pending);
    // Nothing chosen: private, as the old page; public is never offered
    p.update(.invite, &ev);
    try testing.expectEqual(Want{ .invite = 2 }, p.want);
    p.update(.{ .give = 3 }, &ev);
    p.update(.invite, &ev);
    try testing.expectEqual(Want{ .invite = 3 }, p.want);
    try expectHas(try render(a, &p), &.{ "jacob", ">owner<", "never", "Enable", "Reset link", "Invite link" });

    var q: Page = .{};
    q.fromUrl(url.read(Page.Url, "#tab=ops"));
    try testing.expectEqual(Tab.ops, q.tab);
    q.fromUrl(url.read(Page.Url, "#ops"));
    try testing.expectEqual(Tab.overview, q.tab);
    var buf: [64]u8 = undefined;
    try testing.expectEqualStrings("#tab=ops", legacyHash(&buf, "#ops").?);
    try testing.expectEqualStrings("#tab=models&cat=draft", legacyHash(&buf, "#models/draft").?);
    try testing.expectEqualStrings("#tab=models", legacyHash(&buf, "#training").?);
    try testing.expectEqual(@as(?[]const u8, null), legacyHash(&buf, "#tab=riot"));
    try testing.expectEqual(@as(?[]const u8, null), legacyHash(&buf, "#nope"));
    q.update(.{ .tab = .accounts }, &ev);
    try testing.expectEqual(Want.accounts, q.want);
    try testing.expectEqualStrings("crawl-restart", Act.crawl_restart.path());
}

test "admin times: UK clock, ago in steps" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    // 1 Aug 2026 12:00 UTC is 13:00 BST; 28 Oct 14:00 UTC is 14:00 GMT
    try testing.expectEqualStrings("1 Aug 13:00", when(&h, 1_785_585_600).s);
    try testing.expectEqualStrings("28 Oct 14:00", when(&h, Demo.now).s);
    try testing.expectEqualStrings("just now", ago(&h, 59).s);
    try testing.expectEqualStrings("59 min ago", ago(&h, 3599).s);
    try testing.expectEqualStrings("47 h ago", ago(&h, 47 * 3600 + 59).s);
    try testing.expectEqualStrings("2 d ago", ago(&h, 48 * 3600).s);
}
