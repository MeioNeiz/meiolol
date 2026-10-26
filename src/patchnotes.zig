//! What Riot changed between two patches, from Data Dragon (championFull, item and
//! runesReforged JSON): champion base stats and spell cooldown, cost, range and effect
//! numbers, item gold and description numbers, rune description numbers. Data Dragon
//! is the CDN, not the Riot API; each version's files are immutable, so they are cached
//! on disk and a web round fetches once per patch.
//!
//! Gotchas in the data: Data Dragon sometimes blanks a spell's effect numbers to 0
//! (Orianna Q, Varus Q on 16.21) and writes 0 or 25000 into item texts (Hubris,
//! Bastionbreaker): those are `blanked` lines, never a buff or nerf. Spell tooltips are
//! templates ({{ totaldamage }}), so a tooltip edit is only "text changed".

const std = @import("std");
const ddragon = @import("ddragon.zig");
const Allocator = std.mem.Allocator;
const Value = std.json.Value;
const ObjectMap = std.json.ObjectMap;

pub const Slot = enum { stats, p, q, w, e, r, gold, text };

pub const Dir = enum {
    buff,
    nerf,
    /// Mixed, or a number with no known good side (effect N, item passive numbers)
    adjusted,
    /// Words changed, no number to show
    text,
    /// Data Dragon lost the number (0 or 25000 in place of one)
    blanked,
};

pub const Line = struct {
    slot: Slot,
    /// The spell's name for P Q W E R, else ""
    spell: []const u8 = "",
    /// "Cooldown", "Health per level", "Effect 2", "Gold"; "" for a text hunk
    field: []const u8 = "",
    /// For a text hunk: up to `context` words either side of the changed words
    before: []const u8 = "",
    /// Per rank "9/8/7/6/5", one number when all ranks agree, or the changed words
    old: []const u8 = "",
    new: []const u8 = "",
    after: []const u8 = "",
    dir: Dir,
};

pub const Status = enum { changed, new, gone };

pub const Change = struct {
    /// Champion key (266), item or rune id
    id: u32,
    /// Data Dragon id for a champion ("MonkeyKing"), else ""
    key: []const u8 = "",
    name: []const u8,
    status: Status = .changed,
    lines: []const Line = &.{},
    /// A rune's image under Data Dragon's cdn/img/, else ""
    icon: []const u8 = "",

    /// The badge's tone: buff or nerf when every numbered line agrees, else adjusted
    pub fn dir(c: Change) Dir {
        var buffs = false;
        var nerfs = false;
        for (c.lines) |l| switch (l.dir) {
            .buff => buffs = true,
            .nerf => nerfs = true,
            .adjusted => return .adjusted,
            .text, .blanked => {},
        };
        if (buffs != nerfs) return if (buffs) .buff else .nerf;
        return .adjusted;
    }

    /// The badge's text: changed slots in kit order, "Q, W, stats"
    pub fn slots(c: Change, arena: Allocator) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        for ([_]Slot{ .p, .q, .w, .e, .r, .stats }) |s| {
            for (c.lines) |l| if (l.slot == s) {
                if (out.items.len > 0) try out.appendSlice(arena, ", ");
                try out.appendSlice(arena, if (s == .stats) "stats" else &.{std.ascii.toUpper(@tagName(s)[0])});
                break;
            };
        }
        return out.items;
    }
};

pub const Notes = struct {
    /// Data Dragon versions, "16.20.1"
    old: []const u8,
    new: []const u8,
    /// By name; only those that changed, came or went
    champions: []const Change,
    items: []const Change,
    runes: []const Change,
};

/// One version's three files, raw JSON
pub const Files = struct { champions: []const u8, items: []const u8, runes: []const u8 };

const file_names = [_][]const u8{ "championFull", "item", "runesReforged" };

/// Words kept either side of a text hunk
const context = 2;
/// A description with more hunks than this was rewritten: one "text changed" line
const max_hunks = 4;

/// Notes from `old_patch` to `new_patch` ("16.20", "16.21"); files cached under
/// `cache_dir`/<version>/, a patch's version from there when it has one (no network:
/// the renderer and tests). error.NoVersion when Data Dragon has no version of a patch
pub fn load(gpa: Allocator, arena: Allocator, io: std.Io, cache_dir: []const u8, old_patch: []const u8, new_patch: []const u8) !Notes {
    var http: std.http.Client = .{ .allocator = gpa, .io = io };
    defer http.deinit();
    var versions: [2][]const u8 = undefined;
    var files: [2]Files = undefined;
    for ([_][]const u8{ old_patch, new_patch }, &versions, &files) |patch, *v, *f| {
        v.* = try cachedVersion(arena, io, cache_dir, patch) orelse try ddragon.versionFor(&http, arena, patch);
        if (!isVersionOf(v.*, patch)) return error.NoVersion;
        var bodies: [3][]const u8 = undefined;
        for (file_names, &bodies) |name, *body| body.* = try cached(&http, arena, io, cache_dir, v.*, name);
        f.* = .{ .champions = bodies[0], .items = bodies[1], .runes = bodies[2] };
    }
    return diff(arena, versions[0], files[0], versions[1], files[1]);
}

fn isVersionOf(v: []const u8, patch: []const u8) bool {
    return v.len > patch.len and std.mem.startsWith(u8, v, patch) and v[patch.len] == '.';
}

/// The newest version of `patch` with all three files in the cache
fn cachedVersion(arena: Allocator, io: std.Io, cache_dir: []const u8, patch: []const u8) !?[]const u8 {
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io, cache_dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer dir.close(io);
    var best: ?[]const u8 = null;
    var it = dir.iterate();
    next: while (try it.next(io)) |e| {
        if (e.kind != .directory or !isVersionOf(e.name, patch)) continue;
        for (file_names) |name| {
            const p = try arena.print("{s}/{s}.json", .{ e.name, name });
            dir.access(io, p, .{}) catch continue :next;
        }
        if (best == null or std.mem.order(u8, e.name, best.?) == .gt) best = try arena.dupe(u8, e.name);
    }
    return best;
}

/// Riot's own notes for `patch` ("16.21"): its page names it by year, 26.21
pub fn officialUrl(arena: Allocator, patch: []const u8) !?[]const u8 {
    const dot = std.mem.indexOfScalar(u8, patch, '.') orelse return null;
    const major = std.fmt.parseInt(u16, patch[0..dot], 10) catch return null;
    const minor = std.fmt.parseInt(u16, patch[dot + 1 ..], 10) catch return null;
    return try arena.print("https://www.leagueoflegends.com/en-gb/news/game-updates/league-of-legends-patch-{d}-{d}-notes/", .{ major + 10, minor });
}

fn cached(http: *std.http.Client, arena: Allocator, io: std.Io, cache_dir: []const u8, version: []const u8, name: []const u8) ![]const u8 {
    const cwd = std.Io.Dir.cwd();
    const dir = try std.fs.path.join(arena, &.{ cache_dir, version });
    const path = try arena.print("{s}/{s}.json", .{ dir, name });
    if (cwd.readFileAlloc(io, path, arena, .limited(64 << 20))) |body| return body else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }
    const url = try arena.print("https://ddragon.leagueoflegends.com/cdn/{s}/data/en_GB/{s}.json", .{ version, name });
    const body = try ddragon.fetch(http, arena, url);
    // The web round and `meiolol patchnotes` may fetch at once
    var file = try cwd.createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, body);
    try file.replace(io);
    return body;
}

pub fn diff(arena: Allocator, old_version: []const u8, old: Files, new_version: []const u8, new: Files) !Notes {
    return .{
        .old = old_version,
        .new = new_version,
        .champions = try champions(arena, try dataOf(arena, old.champions), try dataOf(arena, new.champions)),
        .items = try items(arena, try dataOf(arena, old.items), try dataOf(arena, new.items)),
        .runes = try runes(arena, old.runes, new.runes),
    };
}

fn dataOf(arena: Allocator, json: []const u8) !ObjectMap {
    const v = try std.json.parseFromSliceLeaky(Value, arena, json, .{});
    const data = field(v, "data") orelse return error.NotDataDragon;
    if (data != .object) return error.NotDataDragon;
    return data.object;
}

const stat_names = [_][2][]const u8{
    .{ "hp", "Health" },
    .{ "hpperlevel", "Health per level" },
    .{ "mp", "Mana" },
    .{ "mpperlevel", "Mana per level" },
    .{ "movespeed", "Move speed" },
    .{ "armor", "Armour" },
    .{ "armorperlevel", "Armour per level" },
    .{ "spellblock", "Magic resist" },
    .{ "spellblockperlevel", "Magic resist per level" },
    .{ "attackrange", "Attack range" },
    .{ "hpregen", "Health regen" },
    .{ "hpregenperlevel", "Health regen per level" },
    .{ "mpregen", "Mana regen" },
    .{ "mpregenperlevel", "Mana regen per level" },
    .{ "crit", "Crit" },
    .{ "critperlevel", "Crit per level" },
    .{ "attackdamage", "Attack damage" },
    .{ "attackdamageperlevel", "Attack damage per level" },
    .{ "attackspeedperlevel", "Attack speed per level" },
    .{ "attackspeed", "Attack speed" },
};

fn champions(arena: Allocator, old: ObjectMap, new: ObjectMap) ![]const Change {
    var out: std.ArrayList(Change) = .empty;
    var it = new.iterator();
    while (it.next()) |e| {
        const c = e.value_ptr.*;
        const id = idOf(field(c, "key")) orelse continue;
        const name = str(field(c, "name")) orelse e.key_ptr.*;
        const o = old.get(e.key_ptr.*) orelse {
            try out.append(arena, .{ .id = id, .key = e.key_ptr.*, .name = name, .status = .new });
            continue;
        };
        var lines: std.ArrayList(Line) = .empty;
        for (stat_names) |s| {
            const x = num(field(field(o, "stats") orelse continue, s[0]) orelse continue) orelse continue;
            const y = num(field(field(c, "stats") orelse continue, s[0]) orelse continue) orelse continue;
            if (x == y) continue;
            try lines.append(arena, .{
                .slot = .stats,
                .field = s[1],
                .old = try fmtNum(arena, x),
                .new = try fmtNum(arena, y),
                .dir = if (y > x) .buff else .nerf,
            });
        }
        try passive(arena, &lines, field(o, "passive"), field(c, "passive"));
        const so = arr(field(o, "spells"));
        const sn = arr(field(c, "spells"));
        for (so[0..@min(so.len, sn.len, 4)], sn[0..@min(so.len, sn.len, 4)], 0..) |x, y, i| {
            try spell(arena, &lines, @fromBackingInt(@intCast(@backingInt(Slot.q) + i)), x, y);
        }
        if (lines.items.len > 0) try out.append(arena, .{ .id = id, .key = e.key_ptr.*, .name = name, .lines = lines.items });
    }
    it = old.iterator();
    while (it.next()) |e| if (!new.contains(e.key_ptr.*)) {
        const id = idOf(field(e.value_ptr.*, "key")) orelse continue;
        try out.append(arena, .{ .id = id, .key = e.key_ptr.*, .name = str(field(e.value_ptr.*, "name")) orelse e.key_ptr.*, .status = .gone });
    };
    sortByName(out.items);
    return out.items;
}

fn passive(arena: Allocator, lines: *std.ArrayList(Line), old: ?Value, new: ?Value) !void {
    const x = str(field(old orelse return, "description")) orelse return;
    const y = str(field(new orelse return, "description")) orelse return;
    try textLines(arena, lines, .p, str(field(new.?, "name")) orelse "", x, y, false);
}

fn spell(arena: Allocator, lines: *std.ArrayList(Line), slot: Slot, old: Value, new: Value) !void {
    const name = str(field(new, "name")) orelse "";
    const start = lines.items.len;
    for ([_]struct { []const u8, []const u8, bool }{
        .{ "cooldown", "Cooldown", false },
        .{ "cost", "Cost", false },
        .{ "range", "Range", true },
    }) |f| {
        const x = arr(field(old, f[0]));
        const y = arr(field(new, f[0]));
        if (sameNums(x, y)) continue;
        // 25000 stands for self-cast or global, not a range
        if (std.mem.eql(u8, f[0], "range") and (has(x, 25000) or has(y, 25000))) continue;
        try lines.append(arena, .{
            .slot = slot,
            .spell = name,
            .field = f[1],
            .old = try ranks(arena, x),
            .new = try ranks(arena, y),
            .dir = rankDir(x, y, f[2]),
        });
    }
    const ex = arr(field(old, "effectBurn"));
    const ey = arr(field(new, "effectBurn"));
    if (blankedEffects(ex, ey)) {
        try lines.append(arena, .{ .slot = slot, .spell = name, .field = "Numbers", .dir = .blanked });
    } else for (ex[0..@min(ex.len, ey.len)], ey[0..@min(ex.len, ey.len)], 0..) |x, y, i| {
        const a = str(x) orelse continue;
        const b = str(y) orelse continue;
        if (std.mem.eql(u8, a, b)) continue;
        try lines.append(arena, .{ .slot = slot, .spell = name, .field = try arena.print("Effect {d}", .{i}), .old = a, .new = b, .dir = .adjusted });
    }
    if (lines.items.len == start) {
        const x = str(field(old, "tooltip")) orelse "";
        const y = str(field(new, "tooltip")) orelse "";
        if (!std.mem.eql(u8, x, y)) try lines.append(arena, .{ .slot = slot, .spell = name, .field = "Text", .dir = .text });
    }
}

/// Every effect number of `new` is 0 or missing where `old` had some
fn blankedEffects(old: []const Value, new: []const Value) bool {
    var had = false;
    for (old) |v| if (str(v)) |s| if (!zeros(s)) {
        had = true;
    };
    if (!had) return false;
    for (new) |v| if (str(v)) |s| if (!zeros(s)) return false;
    return true;
}

fn zeros(s: []const u8) bool {
    var it = std.mem.tokenizeScalar(u8, s, '/');
    while (it.next()) |t| if (!std.mem.eql(u8, t, "0")) return false;
    return true;
}

fn items(arena: Allocator, old: ObjectMap, new: ObjectMap) ![]const Change {
    var out: std.ArrayList(Change) = .empty;
    var it = new.iterator();
    while (it.next()) |e| {
        const c = e.value_ptr.*;
        if (!onRift(c)) continue;
        const id = std.fmt.parseInt(u32, e.key_ptr.*, 10) catch continue;
        const name = str(field(c, "name")) orelse continue;
        const o = old.get(e.key_ptr.*) orelse {
            try out.append(arena, .{ .id = id, .name = name, .status = .new });
            continue;
        };
        if (!onRift(o)) {
            try out.append(arena, .{ .id = id, .name = name, .status = .new });
            continue;
        }
        var lines: std.ArrayList(Line) = .empty;
        const x = num(field(field(o, "gold") orelse .null, "total") orelse .null) orelse 0;
        const y = num(field(field(c, "gold") orelse .null, "total") orelse .null) orelse 0;
        if (x != y) try lines.append(arena, .{
            .slot = .gold,
            .field = "Gold",
            .old = try fmtNum(arena, x),
            .new = try fmtNum(arena, y),
            .dir = if (y < x) .buff else .nerf,
        });
        try textLines(arena, &lines, .text, "", str(field(o, "description")) orelse "", str(field(c, "description")) orelse "", true);
        if (lines.items.len > 0) try out.append(arena, .{ .id = id, .name = name, .lines = lines.items });
    }
    it = old.iterator();
    while (it.next()) |e| {
        if (!onRift(e.value_ptr.*)) continue;
        if (new.get(e.key_ptr.*)) |n| if (onRift(n)) continue;
        const id = std.fmt.parseInt(u32, e.key_ptr.*, 10) catch continue;
        try out.append(arena, .{ .id = id, .name = str(field(e.value_ptr.*, "name")) orelse continue, .status = .gone });
    }
    // Other modes on the Rift map copy an item under a 6-digit id (326621 Dawncore):
    // keep the shop's own, the lowest id
    std.mem.sort(Change, out.items, {}, struct {
        fn lt(_: void, a: Change, b: Change) bool {
            return switch (std.mem.order(u8, a.name, b.name)) {
                .lt => true,
                .gt => false,
                .eq => a.id < b.id,
            };
        }
    }.lt);
    var n: usize = 0;
    for (out.items) |c| {
        if (n > 0 and std.mem.eql(u8, out.items[n - 1].name, c.name)) continue;
        out.items[n] = c;
        n += 1;
    }
    return out.items[0..n];
}

/// In the Summoner's Rift shop
fn onRift(item: Value) bool {
    const maps = field(item, "maps") orelse return false;
    const rift = field(maps, "11") orelse return false;
    if (rift != .bool or !rift.bool) return false;
    if (field(item, "inStore")) |s| if (s == .bool and !s.bool) return false;
    const gold = field(item, "gold") orelse return false;
    const p = field(gold, "purchasable") orelse return false;
    return p == .bool and p.bool;
}

const Rune = struct { id: u32, name: []const u8, icon: []const u8 = "", longDesc: []const u8 };

fn runes(arena: Allocator, old_json: []const u8, new_json: []const u8) ![]const Change {
    const old = try runeList(arena, old_json);
    const new = try runeList(arena, new_json);
    var out: std.ArrayList(Change) = .empty;
    for (new) |r| {
        const o = for (old) |x| {
            if (x.id == r.id) break x;
        } else {
            try out.append(arena, .{ .id = r.id, .name = r.name, .icon = r.icon, .status = .new });
            continue;
        };
        var lines: std.ArrayList(Line) = .empty;
        try textLines(arena, &lines, .text, "", o.longDesc, r.longDesc, false);
        if (lines.items.len > 0) try out.append(arena, .{ .id = r.id, .name = r.name, .icon = r.icon, .lines = lines.items });
    }
    for (old) |r| {
        for (new) |x| {
            if (x.id == r.id) break;
        } else try out.append(arena, .{ .id = r.id, .name = r.name, .icon = r.icon, .status = .gone });
    }
    sortByName(out.items);
    return out.items;
}

fn runeList(arena: Allocator, json: []const u8) ![]const Rune {
    const Tree = struct { slots: []const struct { runes: []const Rune } };
    const trees = try std.json.parseFromSliceLeaky([]const Tree, arena, json, .{ .ignore_unknown_fields = true });
    var out: std.ArrayList(Rune) = .empty;
    for (trees) |t| for (t.slots) |s| try out.appendSlice(arena, s.runes);
    return out.items;
}

const Word = struct { text: []const u8, in_stats: bool };

/// Words of an HTML description, tags dropped; `in_stats` inside an item's <stats>
fn words(arena: Allocator, html: []const u8) ![]const Word {
    var out: std.ArrayList(Word) = .empty;
    var in_stats = false;
    var i: usize = 0;
    while (i < html.len) {
        if (html[i] == '<') {
            const end = std.mem.findScalarPos(u8, html, i, '>') orelse html.len;
            const tag = html[i..end];
            if (std.ascii.startsWithIgnoreCase(tag, "<stats")) in_stats = true;
            if (std.ascii.startsWithIgnoreCase(tag, "</stats")) in_stats = false;
            i = end + 1;
            continue;
        }
        if (std.ascii.isWhitespace(html[i])) {
            i += 1;
            continue;
        }
        const start = i;
        while (i < html.len and html[i] != '<' and !std.ascii.isWhitespace(html[i])) i += 1;
        try out.append(arena, .{ .text = html[start..i], .in_stats = in_stats });
    }
    return out.items;
}

/// Word hunks of `old` -> `new` as lines; one "text changed" line past max_hunks.
/// `stats_dir`: a number in an item's stats block reads higher = buff
fn textLines(arena: Allocator, lines: *std.ArrayList(Line), slot: Slot, spell_name: []const u8, old: []const u8, new: []const u8, stats_dir: bool) !void {
    if (std.mem.eql(u8, old, new)) return;
    const a = try words(arena, old);
    const b = try words(arena, new);
    const hunks = try wordDiff(arena, a, b);
    if (hunks.len == 0) return;
    if (hunks.len > max_hunks) {
        try lines.append(arena, .{ .slot = slot, .spell = spell_name, .field = "Text", .dir = .text });
        return;
    }
    for (hunks) |h| {
        const ow = a[h.a0..h.a1];
        const nw = b[h.b0..h.b1];
        try lines.append(arena, .{
            .slot = if (slot == .text and stats_dir and inStats(ow) and inStats(nw)) .stats else slot,
            .spell = spell_name,
            .before = try join(arena, a[h.a0 -| context..h.a0]),
            .old = try join(arena, ow),
            .new = try join(arena, nw),
            .after = try join(arena, a[h.a1..@min(a.len, h.a1 + context)]),
            .dir = hunkDir(ow, nw, stats_dir),
        });
    }
}

fn inStats(ws: []const Word) bool {
    for (ws) |w| if (!w.in_stats) return false;
    return true;
}

fn hunkDir(old: []const Word, new: []const Word, stats_dir: bool) Dir {
    var x: [8]f64 = undefined;
    var y: [8]f64 = undefined;
    const nx = numbers(old, &x);
    const ny = numbers(new, &y);
    if (ny > 0 and nx > 0) {
        var lost = true;
        for (y[0..ny]) |v| if (v != 0 and v != 25000) {
            lost = false;
        };
        if (lost) return .blanked;
    }
    if (nx == 0 and ny == 0) return .text;
    if (stats_dir and nx == ny and nx > 0 and inStats(old) and inStats(new)) {
        return numsDir(x[0..nx], y[0..ny], true);
    }
    return .adjusted;
}

/// The numbers in `ws` ("22", "16%", "(0.5s)"), at most out.len
/// parseFloat also takes "inf", "nan" and hex
fn isNumber(t: []const u8) bool {
    var digit = false;
    for (t) |c| switch (c) {
        '0'...'9' => digit = true,
        '.', '-' => {},
        else => return false,
    };
    return digit;
}

fn numbers(ws: []const Word, out: []f64) usize {
    var n: usize = 0;
    for (ws) |w| {
        const t = std.mem.trim(u8, w.text, "()%s+,.:;");
        if (!isNumber(t)) continue;
        const v = std.fmt.parseFloat(f64, t) catch continue;
        if (n == out.len) break;
        out[n] = v;
        n += 1;
    }
    return n;
}

const Hunk = struct { a0: usize, a1: usize, b0: usize, b1: usize };

/// Changed runs between word lists, by longest common subsequence
fn wordDiff(arena: Allocator, a: []const Word, b: []const Word) ![]const Hunk {
    const w = b.len + 1;
    // lcs[i * w + j]: common words of a[i..] and b[j..]
    const lcs = try arena.alloc(u32, (a.len + 1) * w);
    @memset(lcs, 0);
    var i = a.len;
    while (i > 0) {
        i -= 1;
        var j = b.len;
        while (j > 0) {
            j -= 1;
            lcs[i * w + j] = if (std.mem.eql(u8, a[i].text, b[j].text))
                lcs[(i + 1) * w + j + 1] + 1
            else
                @max(lcs[(i + 1) * w + j], lcs[i * w + j + 1]);
        }
    }
    var out: std.ArrayList(Hunk) = .empty;
    var x: usize = 0;
    var y: usize = 0;
    var open: ?Hunk = null;
    while (x < a.len or y < b.len) {
        if (x < a.len and y < b.len and std.mem.eql(u8, a[x].text, b[y].text)) {
            if (open) |h| try out.append(arena, .{ .a0 = h.a0, .a1 = x, .b0 = h.b0, .b1 = y });
            open = null;
            x += 1;
            y += 1;
            continue;
        }
        if (open == null) open = .{ .a0 = x, .a1 = x, .b0 = y, .b1 = y };
        if (y == b.len or (x < a.len and lcs[(x + 1) * w + y] >= lcs[x * w + y + 1])) x += 1 else y += 1;
    }
    if (open) |h| try out.append(arena, .{ .a0 = h.a0, .a1 = x, .b0 = h.b0, .b1 = y });
    return out.items;
}

fn join(arena: Allocator, ws: []const Word) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (ws, 0..) |w, k| {
        if (k > 0) try out.append(arena, ' ');
        try out.appendSlice(arena, w.text);
    }
    return out.items;
}

/// buff when every rank moved the good way, nerf when every one moved the bad way
fn rankDir(old: []const Value, new: []const Value, higher_better: bool) Dir {
    var x: [8]f64 = undefined;
    var y: [8]f64 = undefined;
    if (old.len != new.len or old.len > x.len) return .adjusted;
    for (old, new, 0..) |p, q, k| {
        x[k] = num(p) orelse return .adjusted;
        y[k] = num(q) orelse return .adjusted;
    }
    return numsDir(x[0..old.len], y[0..old.len], higher_better);
}

fn numsDir(old: []const f64, new: []const f64, higher_better: bool) Dir {
    var up = false;
    var down = false;
    for (old, new) |p, q| {
        if (q > p) up = true;
        if (q < p) down = true;
    }
    if (up == down) return .adjusted;
    return if (up == higher_better) .buff else .nerf;
}

fn ranks(arena: Allocator, vs: []const Value) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    const same = for (vs) |v| {
        if (num(v) != num(vs[0])) break false;
    } else true;
    for (vs, 0..) |v, k| {
        if (same and k > 0) break;
        if (k > 0) try out.append(arena, '/');
        try out.appendSlice(arena, try fmtNum(arena, num(v) orelse 0));
    }
    return out.items;
}

fn sameNums(a: []const Value, b: []const Value) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| if (num(x) != num(y)) return false;
    return true;
}

fn has(vs: []const Value, n: f64) bool {
    for (vs) |v| if (num(v) == n) return true;
    return false;
}

fn fmtNum(arena: Allocator, v: f64) ![]const u8 {
    return arena.print("{d}", .{v});
}

fn sortByName(cs: []Change) void {
    std.mem.sort(Change, cs, {}, struct {
        fn lt(_: void, a: Change, b: Change) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lt);
}

fn field(v: Value, name: []const u8) ?Value {
    return if (v == .object) v.object.get(name) else null;
}

fn str(v: ?Value) ?[]const u8 {
    const x = v orelse return null;
    return if (x == .string) x.string else null;
}

fn arr(v: ?Value) []const Value {
    const x = v orelse return &.{};
    return if (x == .array) x.array.items else &.{};
}

fn num(v: Value) ?f64 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        .number_string => |s| std.fmt.parseFloat(f64, s) catch null,
        else => null,
    };
}

fn idOf(v: ?Value) ?u32 {
    return std.fmt.parseInt(u32, str(v) orelse return null, 10) catch null;
}

const testing = std.testing;

fn champJson(comptime body: []const u8) []const u8 {
    return "{\"data\":{" ++ body ++ "}}";
}

const darius_old =
    \\"Darius":{"key":"122","name":"Darius","stats":{"hp":652,"armor":37},
    \\"passive":{"name":"Hemorrhage","description":"Bleeds for 5 seconds."},
    \\"spells":[{"name":"Decimate","cooldown":[9,8,7,6,5],"cost":[25,30,35,40,45],"range":[425,425,425,425,425],
    \\"effectBurn":[null,"50/80/110","0"],"tooltip":"{{ a }}"}]}
;
const darius_new =
    \\"Darius":{"key":"122","name":"Darius","stats":{"hp":652,"armor":39},
    \\"passive":{"name":"Hemorrhage","description":"Bleeds for 4 seconds."},
    \\"spells":[{"name":"Decimate","cooldown":[9,7.75,6.5,5.25,4],"cost":[25,30,35,40,45],"range":[425,425,425,425,425],
    \\"effectBurn":[null,"50/80/110","0"],"tooltip":"{{ a }}"}]}
;
const varus_old =
    \\"Varus":{"key":"110","name":"Varus","stats":{"hp":600},
    \\"spells":[{"name":"Piercing Arrow","cooldown":[16],"cost":[70],"range":[925],
    \\"effectBurn":[null,"0","0.15","4"],"tooltip":"{{ old }}"}]}
;
const varus_new =
    \\"Varus":{"key":"110","name":"Varus","stats":{"hp":600},
    \\"spells":[{"name":"Piercing Arrow","cooldown":[16],"cost":[70],"range":[925],
    \\"effectBurn":[null,"0","0","0"],"tooltip":"{{ new }}"}]}
;
const lee_old =
    \\"LeeSin":{"key":"64","name":"Lee Sin","stats":{},
    \\"spells":[{"name":"Q"},{"name":"Safeguard","cooldown":[7,7,7],"cost":[50,50,50],"range":[700,700,700],"tooltip":"x"}]}
;
const lee_new =
    \\"LeeSin":{"key":"64","name":"Lee Sin","stats":{},
    \\"spells":[{"name":"Q"},{"name":"Safeguard","cooldown":[8,8,8],"cost":[50,50,50],"range":[700,700,700],"tooltip":"y"}]}
;

const items_old =
    \\{"data":{
    \\"3008":{"name":"Gluttonous Greaves","description":"<mainText><stats><attention>25</attention> Move Speed</stats></mainText>",
    \\ "gold":{"total":1000,"purchasable":true},"maps":{"11":true}},
    \\"2520":{"name":"Bastionbreaker","description":"<mainText><stats><attention>22</attention> Lethality<br><attention>15</attention> Ability Haste</stats><br><passive>Sabotage</passive> grants Sabotage for 90 seconds.</mainText>",
    \\ "gold":{"total":3000,"purchasable":true},"maps":{"11":true}},
    \\"6697":{"name":"Hubris","description":"<mainText><stats></stats>gain 12 Attack Damage plus 3 per kill</mainText>",
    \\ "gold":{"total":3000,"purchasable":true},"maps":{"11":true}},
    \\"447100":{"name":"Mirage Blade","description":"a","gold":{"total":0,"purchasable":true},"maps":{"11":false,"30":true}},
    \\"1001":{"name":"Old Boots","description":"x","gold":{"total":300,"purchasable":true},"maps":{"11":true}}
    \\}}
;
const items_new =
    \\{"data":{
    \\"3008":{"name":"Gluttonous Greaves","description":"<mainText><stats><attention>25</attention> Move Speed</stats></mainText>",
    \\ "gold":{"total":1100,"purchasable":true},"maps":{"11":true}},
    \\"2520":{"name":"Bastionbreaker","description":"<mainText><stats><attention>18</attention> Lethality<br><attention>15</attention> Ability Haste</stats><br><passive>Sabotage</passive> grants Sabotage for 25000 seconds.</mainText>",
    \\ "gold":{"total":3000,"purchasable":true},"maps":{"11":true}},
    \\"6697":{"name":"Hubris","description":"<mainText><stats></stats>gain 0 Attack Damage plus 0 per kill</mainText>",
    \\ "gold":{"total":3000,"purchasable":true},"maps":{"11":true}},
    \\"326697":{"name":"Hubris","description":"<mainText>gain 1 Attack Damage</mainText>","gold":{"total":2900,"purchasable":true},"maps":{"11":true}},
    \\"447100":{"name":"Mirage Blade","description":"b","gold":{"total":0,"purchasable":true},"maps":{"11":false,"30":true}},
    \\"9999":{"name":"New Thing","description":"y","gold":{"total":3000,"purchasable":true},"maps":{"11":true}}
    \\}}
;
const runes_old =
    \\[{"id":8000,"slots":[{"runes":[{"id":8005,"name":"Press the Attack","longDesc":"Deals <b>40</b> damage."}]}]}]
;
const runes_new =
    \\[{"id":8000,"slots":[{"runes":[{"id":8005,"name":"Press the Attack","icon":"perk-images/Styles/Precision/PressTheAttack/PressTheAttack.png","longDesc":"Deals <b>45</b> damage."}]}]}]
;

fn testNotes(arena: Allocator) !Notes {
    return diff(arena, "16.20.1", .{
        .champions = champJson(darius_old ++ "," ++ varus_old ++ "," ++ lee_old),
        .items = items_old,
        .runes = runes_old,
    }, "16.21.1", .{
        .champions = champJson(darius_new ++ "," ++ varus_new ++ "," ++ lee_new ++
            \\,"Zaahen":{"key":"904","name":"Zaahen","stats":{}}
        ),
        .items = items_new,
        .runes = runes_new,
    });
}

fn expectLine(l: Line, slot: Slot, f: []const u8, old: []const u8, new: []const u8, dir: Dir) !void {
    try testing.expectEqual(slot, l.slot);
    try testing.expectEqualStrings(f, l.field);
    try testing.expectEqualStrings(old, l.old);
    try testing.expectEqualStrings(new, l.new);
    try testing.expectEqual(dir, l.dir);
}

test "champions: stats, per-rank cooldowns, passive words, blanked effects, new" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const n = try testNotes(arena);
    try testing.expectEqual(4, n.champions.len);

    const darius = n.champions[0];
    try testing.expectEqualStrings("Darius", darius.name);
    try testing.expectEqual(122, darius.id);
    try testing.expectEqual(3, darius.lines.len);
    try expectLine(darius.lines[0], .stats, "Armour", "37", "39", .buff);
    try expectLine(darius.lines[1], .p, "", "5", "4", .adjusted);
    try testing.expectEqualStrings("Bleeds for", darius.lines[1].before);
    try testing.expectEqualStrings("seconds.", darius.lines[1].after);
    try expectLine(darius.lines[2], .q, "Cooldown", "9/8/7/6/5", "9/7.75/6.5/5.25/4", .buff);
    try testing.expectEqualStrings("Decimate", darius.lines[2].spell);
    try testing.expectEqual(.adjusted, darius.dir());
    try testing.expectEqualStrings("P, Q, stats", try darius.slots(arena));

    const lee = n.champions[1];
    try testing.expectEqualStrings("Lee Sin", lee.name);
    try testing.expectEqual(1, lee.lines.len);
    try expectLine(lee.lines[0], .w, "Cooldown", "7", "8", .nerf);
    try testing.expectEqual(.nerf, lee.dir());

    const varus = n.champions[2];
    try testing.expectEqual(1, varus.lines.len);
    try expectLine(varus.lines[0], .q, "Numbers", "", "", .blanked);
    try testing.expectEqual(.adjusted, varus.dir());

    try testing.expectEqual(.new, n.champions[3].status);
}

test "items: gold, stats numbers, blanked texts, off-Rift skipped, new and gone" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const n = try testNotes(arena_state.allocator());
    try testing.expectEqual(5, n.items.len);

    const bastion = n.items[0];
    try testing.expectEqualStrings("Bastionbreaker", bastion.name);
    try testing.expectEqual(2, bastion.lines.len);
    try expectLine(bastion.lines[0], .stats, "", "22", "18", .nerf);
    try testing.expectEqualStrings("Lethality 15", bastion.lines[0].after);
    try expectLine(bastion.lines[1], .text, "", "90", "25000", .blanked);
    try testing.expectEqual(.nerf, bastion.dir());

    const greaves = n.items[1];
    try testing.expectEqual(1, greaves.lines.len);
    try expectLine(greaves.lines[0], .gold, "Gold", "1000", "1100", .nerf);

    const hubris = n.items[2];
    try testing.expectEqual(6697, hubris.id);
    try testing.expectEqual(2, hubris.lines.len);
    try testing.expectEqual(.blanked, hubris.lines[0].dir);
    try testing.expectEqual(.blanked, hubris.lines[1].dir);

    try testing.expectEqual(.new, n.items[3].status);
    try testing.expectEqualStrings("New Thing", n.items[3].name);
    try testing.expectEqual(.gone, n.items[4].status);
}

test "runes: description numbers" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const n = try testNotes(arena_state.allocator());
    try testing.expectEqual(1, n.runes.len);
    try expectLine(n.runes[0].lines[0], .text, "", "40", "45", .adjusted);
    try testing.expectEqualStrings("Deals", n.runes[0].lines[0].before);
    try testing.expectEqualStrings("perk-images/Styles/Precision/PressTheAttack/PressTheAttack.png", n.runes[0].icon);
}

test "numbers: words only, not inf, nan or hex" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var lines: std.ArrayList(Line) = .empty;
    try textLines(arena, &lines, .p, "", "Lasts Infinity seconds", "Lasts 0x10 seconds", false);
    try testing.expectEqual(.text, lines.items[0].dir);
    var x: [4]f64 = undefined;
    const ws = [_]Word{ .{ .text = "nan", .in_stats = false }, .{ .text = "(-5%)", .in_stats = false }, .{ .text = "0.5,", .in_stats = false } };
    try testing.expectEqual(2, numbers(&ws, &x));
    try testing.expectEqualSlices(f64, &.{ -5, 0.5 }, x[0..2]);
}

test "wordDiff: a rewrite past max_hunks is one text line" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var lines: std.ArrayList(Line) = .empty;
    try textLines(arena, &lines, .p, "", "a 1 b 2 c 3 d 4 e 5 f", "a 9 b 8 c 7 d 6 e 0.5 f", false);
    try testing.expectEqual(1, lines.items.len);
    try testing.expectEqual(.text, lines.items[0].dir);
}

test "load: versions from the cache, no network" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const files = [_][3][]const u8{
        .{ champJson(darius_old), items_old, runes_old },
        .{ champJson(darius_new), items_new, runes_new },
    };
    for ([_][]const u8{ "16.20.1", "16.21.1" }, files) |v, f| {
        try tmp.dir.createDirPath(io, v);
        for (file_names, f) |name, body| try tmp.dir.writeFile(io, .{ .sub_path = try arena.print("{s}/{s}.json", .{ v, name }), .data = body });
    }
    // Not whole: never picked
    try tmp.dir.createDirPath(io, "16.21.2");
    const dir = try std.fs.path.join(arena, &.{ ".zig-cache", "tmp", &tmp.sub_path });
    const n = try load(testing.allocator, arena, io, dir, "16.20", "16.21");
    try testing.expectEqualStrings("16.21.1", n.new);
    try testing.expectEqualStrings("Darius", n.champions[0].name);
}

test "officialUrl: Riot names patches by year" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    try testing.expectEqualStrings(
        "https://www.leagueoflegends.com/en-gb/news/game-updates/league-of-legends-patch-26-21-notes/",
        (try officialUrl(arena_state.allocator(), "16.21")).?,
    );
    try testing.expectEqual(null, try officialUrl(arena_state.allocator(), "x"));
}
