//! `meiolol-lab draft`: the compiled-in candidate's win model as a draft tester. Fits once
//! on every game in the snapshot, then ranks the champions for an open slot, one draft per
//! line: from the command line, or typed at the prompt. Slots left open count as an
//! unseen champion (neutral), so their absolute chance is rough; the ranking is not.

const std = @import("std");
const api = @import("api");
const core = @import("core");
const cand = @import("cand");
const store = @import("store");
const rows = @import("rows.zig");
const harness = @import("harness.zig");
const protocol = @import("protocol.zig");

const Io = std.Io;

pub const usage =
    \\  draft SNAP [DRAFT]              rank champions for an open slot with the compiled-in
    \\                                  candidate's win model (-Dcand); without DRAFT, reads
    \\                                  drafts line by line. DRAFT: --role mid [--side red]
    \\                                  [--ally top=Darius,jungle=Lee Sin] [--enemy mid=Ahri,
    \\                                  Jinx] [--ban Yasuo] [--top 10] [--min-games 100]
    \\
;

const n_role = 5;

const Champions = struct {
    names: std.AutoHashMapUnmanaged(u32, []const u8) = .empty,
    /// Training games per champion and role
    games: std.AutoHashMapUnmanaged(u64, u32) = .empty,

    fn key(champion: u32, role: usize) u64 {
        return (@as(u64, champion) << 3) | role;
    }

    fn gamesIn(c: *const Champions, champion: u32, role: usize) u32 {
        return c.games.get(key(champion, role)) orelse 0;
    }

    fn name(c: *const Champions, champion: u32) []const u8 {
        return c.names.get(champion) orelse "?";
    }

    /// Case, spaces and punctuation ignored; a unique prefix will do
    fn find(c: *const Champions, text: []const u8) ?u32 {
        var want_buf: [32]u8 = undefined;
        const want = fold(&want_buf, text);
        if (want.len == 0) return null;
        var found: ?u32 = null;
        var it = c.names.iterator();
        while (it.next()) |e| {
            var buf: [32]u8 = undefined;
            const have = fold(&buf, e.value_ptr.*);
            if (std.mem.eql(u8, have, want)) return e.key_ptr.*;
            if (std.mem.startsWith(u8, have, want)) {
                if (found != null) return null;
                found = e.key_ptr.*;
            }
        }
        return found;
    }

    fn fold(buf: []u8, s: []const u8) []const u8 {
        var n: usize = 0;
        for (s) |ch| if (std.ascii.isAlphanumeric(ch) and n < buf.len) {
            buf[n] = std.ascii.toLower(ch);
            n += 1;
        };
        return buf[0..n];
    }
};

const Draft = struct {
    role: usize,
    side: u1 = 0,
    /// By side (0 the user's) and role; 0 open
    teams: [2][n_role]u32 = @splat(@splat(0)),
    bans: std.ArrayList(u32) = .empty,
    top: usize = 10,
    min_games: u32 = 100,
};

pub fn main(gpa: std.mem.Allocator, arena: std.mem.Allocator, io: Io, argv: []const []const u8) !u8 {
    if (argv.len < 1) {
        std.debug.print("usage:\n{s}", .{usage});
        return 2;
    }
    const snap = argv[0];
    var out_buf: [16 * 1024]u8 = undefined;
    var out_file = Io.File.stdout().writer(io, &out_buf);
    const w = &out_file.interface;

    // Unused here, but the packed rows only load when they match
    var legendaries = try rows.loadLegendaries(gpa, io, snap);
    defer legendaries.deinit(gpa);
    var data = try rows.load(gpa, snap, &legendaries);
    defer data.deinit();
    var champs = try loadChampions(gpa, arena, snap, &data);
    var m = try fitAll(gpa, &data);
    defer cand.deinit(&m, gpa);
    const newest = newestGame(&data);
    try w.print("win model fitted on {d} games; --min-games guards against thin samples\n", .{data.games.len});

    if (argv.len > 1) {
        try run(arena, &m, &champs, newest, argv[1..], w);
        try w.flush();
        return 0;
    }
    var in_buf: [4096]u8 = undefined;
    var in_file = Io.File.stdin().reader(io, &in_buf);
    while (true) {
        try w.writeAll("draft> ");
        try w.flush();
        const line = try in_file.interface.takeDelimiter('\n') orelse break;
        const args = try splitFlags(arena, line);
        if (args.len == 0) continue;
        run(arena, &m, &champs, newest, args, w) catch |err| try w.print("{t}\n", .{err});
        try w.flush();
    }
    return 0;
}

/// "--role mid --ally top=Lee Sin" -> ["--role", "mid", "--ally", "top=Lee Sin"]: values
/// may hold spaces, so split only before "--"
fn splitFlags(arena: std.mem.Allocator, line: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.tokenizeSequence(u8, line, "--");
    while (it.next()) |part| {
        const p = std.mem.trim(u8, part, " \t\r");
        if (p.len == 0) continue;
        const sp = std.mem.indexOfAny(u8, p, " \t") orelse p.len;
        try out.append(arena, try std.fmt.allocPrint(arena, "--{s}", .{p[0..sp]}));
        if (sp < p.len) try out.append(arena, std.mem.trim(u8, p[sp..], " \t\"'"));
    }
    return out.items;
}

fn newestGame(d: *const rows.Data) api.Game {
    var g = d.games[0];
    for (d.games) |x| if (x.start > g.start) {
        g = x;
    };
    return .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = @splat(@splat(null)) };
}

fn loadChampions(gpa: std.mem.Allocator, arena: std.mem.Allocator, snap: []const u8, d: *const rows.Data) !Champions {
    var c: Champions = .{};
    const db = try store.schema.openReadOnly(gpa, snap);
    defer db.close();
    var q = try db.prepare("SELECT id, name FROM champions");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) try c.names.put(arena, @intCast(q.int(0)), try arena.dupe(u8, q.bytes(1)));
    for (d.rows) |r| {
        const e = try c.games.getOrPut(arena, Champions.key(r.champion, @backingInt(r.role)));
        if (!e.found_existing) e.value_ptr.* = 0;
        e.value_ptr.* += 1;
    }
    return c;
}

/// A tool, not an evaluation: every game, test games included
fn fitAll(gpa: std.mem.Allocator, d: *const rows.Data) !cand.Model {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    const ranks = try harness.gameRanks(a, d);
    const games = try a.alloc(api.Game, d.games.len);
    for (games, d.games, ranks) |*o, g, rk| o.* = .{ .start = g.start, .patch = g.patch, .platform = g.platform, .teams = g.teams, .ranks = rk };
    const out = try a.alloc(api.Row, d.rows.len);
    for (out, d.rows) |*o, r| o.* = .{
        .game = r.game,
        .side = r.side,
        .role = @fromBackingInt(@backingInt(r.role)),
        .champion = r.champion,
        .rank = r.rank,
        .y = r.y,
    };
    return cand.fit(gpa, &.{ .games = games, .rows = out }, .{});
}

fn run(arena: std.mem.Allocator, m: *const cand.Model, champs: *const Champions, newest: api.Game, args: []const []const u8, w: *Io.Writer) !void {
    const d = try parseDraft(arena, champs, args, w) orelse return;
    const Option = struct { champion: u32, win: f32, games: u32 };
    var options: std.ArrayList(Option) = .empty;
    var it = champs.names.keyIterator();
    while (it.next()) |id| {
        const games = champs.gamesIn(id.*, d.role);
        if (games < d.min_games or taken(&d, id.*)) continue;
        var q = query(&d, newest);
        q.champion = id.*;
        q.teams[d.side][d.role] = id.*;
        const p = cand.predict(m, &q)[api.outcomeIndex(.win)];
        if (std.math.isNan(p)) return error.CandidateHasNoWinModel;
        try options.append(arena, .{ .champion = id.*, .win = p, .games = games });
    }
    if (options.items.len == 0) {
        try w.print("no free champion has {d}+ games in {s}\n", .{ d.min_games, roleLabel(d.role) });
        return;
    }
    // Average pick: weighted by how often each is played in the role
    var sum: f64 = 0;
    var n: f64 = 0;
    for (options.items) |o| {
        sum += o.win * @as(f64, @floatFromInt(o.games));
        n += @floatFromInt(o.games);
    }
    const avg = sum / n;
    std.mem.sort(Option, options.items, {}, struct {
        fn f(_: void, a: Option, b: Option) bool {
            return a.win > b.win;
        }
    }.f);

    try printDraft(champs, &d, w);
    try w.print("best {s} picks (your team's win chance, change vs an average pick {d:.1}%):\n", .{ roleLabel(d.role), 100 * avg });
    for (options.items[0..@min(d.top, options.items.len)], 1..) |o, i| {
        const pp = 100 * (o.win - avg);
        try w.print("{d:>3}. {s:<16} {d:>5.1}%  {s}{d:.1} pp  {d} games\n", .{ i, champs.name(o.champion), 100 * o.win, if (pp >= 0) "+" else "", pp, o.games });
    }
    try w.print("worst: ", .{});
    const tail = options.items[options.items.len - @min(3, options.items.len) ..];
    for (tail, 0..) |o, i| try w.print("{s}{s} {d:.1}%", .{ if (i > 0) ", " else "", champs.name(o.champion), 100 * o.win });
    try w.writeAll("\n\n");
}

fn query(d: *const Draft, newest: api.Game) api.Query {
    var teams: [2][n_role]u32 = undefined;
    // Query teams are by game side (0 blue); the draft's are by "mine" and "theirs"
    teams[d.side] = d.teams[0];
    teams[1 - d.side] = d.teams[1];
    return .{
        .start = newest.start,
        .patch = newest.patch,
        .platform = newest.platform,
        .side = d.side,
        .role = @fromBackingInt(@as(u3, @intCast(d.role))),
        .champion = 0,
        .rank = null,
        .teams = teams,
        .ranks = null,
    };
}

fn taken(d: *const Draft, champion: u32) bool {
    for (d.teams) |t| for (t) |c| if (c == champion) return true;
    for (d.bans.items) |b| if (b == champion) return true;
    return false;
}

fn roleLabel(r: usize) []const u8 {
    return @as(core.Role, @fromBackingInt(@as(u3, @intCast(r)))).label();
}

fn printDraft(champs: *const Champions, d: *const Draft, w: *Io.Writer) !void {
    try w.print("you: {s}, {s} side\n", .{ roleLabel(d.role), if (d.side == 0) "blue" else "red" });
    for ([_][]const u8{ "allies ", "enemies" }, d.teams) |label, t| {
        try w.print("  {s}", .{label});
        for (t, 0..) |c, r| try w.print("  {s}={s}", .{ roleLabel(r), if (c == 0) "-" else champs.name(c) });
        try w.writeAll("\n");
    }
}

fn parseDraft(arena: std.mem.Allocator, champs: *const Champions, args: []const []const u8, w: *Io.Writer) !?Draft {
    var d: Draft = .{ .role = n_role };
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const flag = args[i];
        if (i + 1 >= args.len) {
            try w.print("{s} needs a value\n", .{flag});
            return null;
        }
        i += 1;
        const v = args[i];
        if (std.mem.eql(u8, flag, "--role")) {
            const r = core.Role.parse(v) orelse {
                try w.print("unknown role {s}\n", .{v});
                return null;
            };
            d.role = @backingInt(r);
        } else if (std.mem.eql(u8, flag, "--side")) {
            d.side = if (std.mem.eql(u8, v, "red")) 1 else 0;
        } else if (std.mem.eql(u8, flag, "--top")) {
            d.top = std.fmt.parseInt(usize, v, 10) catch 10;
        } else if (std.mem.eql(u8, flag, "--min-games")) {
            d.min_games = std.fmt.parseInt(u32, v, 10) catch 100;
        } else if (std.mem.eql(u8, flag, "--ally") or std.mem.eql(u8, flag, "--enemy")) {
            const team: usize = if (std.mem.eql(u8, flag, "--ally")) 0 else 1;
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |raw| {
                var item = std.mem.trim(u8, raw, " \t\"'");
                if (item.len == 0) continue;
                var role: ?usize = null;
                if (std.mem.indexOfScalar(u8, item, '=')) |eq| {
                    const rn = std.mem.trim(u8, item[0..eq], " \t");
                    role = if (core.Role.parse(rn)) |r| @backingInt(r) else {
                        try w.print("unknown role {s}\n", .{rn});
                        return null;
                    };
                    item = std.mem.trim(u8, item[eq + 1 ..], " \t\"'");
                }
                const c = champs.find(item) orelse {
                    try w.print("no single champion matches \"{s}\"\n", .{item});
                    return null;
                };
                d.teams[team][role orelse mainRole(champs, &d, team, c)] = c;
            }
        } else if (std.mem.eql(u8, flag, "--ban")) {
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |raw| {
                const item = std.mem.trim(u8, raw, " \t\"'");
                if (item.len == 0) continue;
                const c = champs.find(item) orelse {
                    try w.print("no single champion matches \"{s}\"\n", .{item});
                    return null;
                };
                try d.bans.append(arena, c);
            }
        } else {
            try w.print("unknown option {s}\n", .{flag});
            return null;
        }
    }
    if (d.role == n_role) {
        try w.writeAll("--role is required\n");
        return null;
    }
    if (d.teams[0][d.role] != 0) {
        try w.print("your slot ({s}) is already picked\n", .{roleLabel(d.role)});
        return null;
    }
    return d;
}

/// A pick without a role goes to the open slot where that champion is played most
fn mainRole(champs: *const Champions, d: *const Draft, team: usize, c: u32) usize {
    var best: usize = 0;
    var most: i64 = -1;
    for (0..n_role) |r| {
        if (d.teams[team][r] != 0 or (team == 0 and r == d.role)) continue;
        const g: i64 = champs.gamesIn(c, r);
        if (g > most) {
            most = g;
            best = r;
        }
    }
    return best;
}

test "flags split before --, values keep spaces" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try splitFlags(arena.allocator(), "--role mid --ally top=Darius,jungle=Lee Sin --side red");
    try std.testing.expectEqual(@as(usize, 6), got.len);
    try std.testing.expectEqualStrings("top=Darius,jungle=Lee Sin", got[3]);
    try std.testing.expectEqualStrings("red", got[5]);
}
