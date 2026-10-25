//! ChampSearch: a box that finds a champion as you type, the way the header search does
//! (search.js): whole name or alias (mf, j4), a prefix of the name or one of its words,
//! part of it, then a typo (one, two from 7 letters); case and punctuation ignored. The
//! list under it is an ARIA combobox: arrows move, Enter takes, Escape closes then
//! clears, focus leaving the box closes it. Modes: link (each option is a link: the
//! champion page's "matchup with..."), pick (the choice stays as a chip with a clear
//! button: the draft tester) and filter (no list: a host reads `q`, e.g. a table)
const std = @import("std");
const tree = @import("tree.zig");
const url = @import("url.zig");
const role = @import("role.zig");
const champ = @import("champ.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const Allocator = std.mem.Allocator;
const H = tree.H;
const N = tree.N;

pub const name = "ChampSearch";
pub const scope = .{ ".c-search", ".c-chosen" };

pub const Entry = struct {
    name: []const u8,
    /// The portrait's URL
    src: []const u8,
    /// Link mode: where taking it goes
    href: ?[]const u8 = null,
    roles: []const role.Role = &.{},
};

/// Nicknames, folded, to the folded name
const aliases = [_]struct { []const u8, []const u8 }{
    .{ "mf", "missfortune" },    .{ "tf", "twistedfate" },      .{ "j4", "jarvaniv" },
    .{ "jarvan", "jarvaniv" },   .{ "asol", "aurelionsol" },    .{ "lb", "leblanc" },
    .{ "ww", "warwick" },        .{ "tk", "tahmkench" },        .{ "gp", "gangplank" },
    .{ "monkeyking", "wukong" }, .{ "nunu", "nunuwillump" },    .{ "kog", "kogmaw" },
    .{ "cass", "cassiopeia" },   .{ "heimer", "heimerdinger" }, .{ "xin", "xinzhao" },
};

/// A match: the entry, its score and the part of the folded name that matched
pub const Hit = struct { e: u16, score: u8, at: u8 = 0, len: u8 = 0 };

/// The options shown at most
pub const max_hits = 8;

/// The entries folded once for matching
pub const Index = struct {
    entries: []const Entry,
    keys: []const Key,

    const Word = struct { at: u8, len: u8 };
    const Key = struct {
        /// Lower-case letters and digits
        n: []const u8,
        /// Slices of `n` split where the name has a space . ' or &
        words: []const Word,
        aliases: []const []const u8,
    };

    pub fn init(a: Allocator, entries: []const Entry) !Index {
        const keys = try a.alloc(Key, entries.len);
        for (entries, keys) |e, *k| {
            var n: std.ArrayList(u8) = .empty;
            var words: std.ArrayList(Word) = .empty;
            var start: ?usize = null;
            for (e.name) |ch| {
                if (ch == ' ' or ch == '.' or ch == '\'' or ch == '&') {
                    if (start) |s| try words.append(a, .{ .at = @intCast(s), .len = @intCast(n.items.len - s) });
                    start = null;
                    continue;
                }
                if (!isFolded(ch)) continue;
                if (start == null) start = n.items.len;
                try n.append(a, std.ascii.toLower(ch));
            }
            if (start) |s| try words.append(a, .{ .at = @intCast(s), .len = @intCast(n.items.len - s) });
            var al: std.ArrayList([]const u8) = .empty;
            for (aliases) |x| if (std.mem.eql(u8, x[1], n.items)) try al.append(a, x[0]);
            k.* = .{ .n = n.items, .words = words.items, .aliases = al.items };
        }
        return .{ .entries = entries, .keys = keys };
    }

    /// The best matches for `q`, best first, at most out.len
    pub fn match(ix: *const Index, q: []const u8, out: []Hit) []Hit {
        var buf: [32]u8 = undefined;
        const f = fold(&buf, q);
        if (f.len == 0) return out[0..0];
        var n: usize = 0;
        for (ix.keys, 0..) |*k, i| {
            var hit = score(f, k);
            if (hit.score == 0) continue;
            hit.e = @intCast(i);
            var pos = n;
            while (pos > 0 and ix.before(hit, out[pos - 1])) pos -= 1;
            if (pos >= out.len) continue;
            if (n == out.len) n -= 1;
            @memmove(out[pos + 1 .. n + 1], out[pos..n]);
            out[pos] = hit;
            n += 1;
        }
        return out[0..n];
    }

    /// Higher score, then the shorter name, then A to Z
    fn before(ix: *const Index, x: Hit, y: Hit) bool {
        if (x.score != y.score) return x.score > y.score;
        const a = ix.entries[x.e].name;
        const b = ix.entries[y.e].name;
        if (a.len != b.len) return a.len < b.len;
        return std.ascii.orderIgnoreCase(a, b) == .lt;
    }
};

fn isFolded(ch: u8) bool {
    return ch < 0x80 and std.ascii.isAlphanumeric(ch);
}

fn fold(buf: []u8, s: []const u8) []const u8 {
    var n: usize = 0;
    for (s) |ch| if (isFolded(ch) and n < buf.len) {
        buf[n] = std.ascii.toLower(ch);
        n += 1;
    };
    return buf[0..n];
}

fn score(q: []const u8, k: *const Index.Key) Hit {
    const n = k.n;
    const len: u8 = @intCast(q.len);
    if (std.mem.eql(u8, n, q)) return .{ .e = 0, .score = 100, .len = len };
    for (k.aliases) |a| if (std.mem.eql(u8, a, q)) return .{ .e = 0, .score = 100 };
    if (std.mem.startsWith(u8, n, q)) return .{ .e = 0, .score = 80, .len = len };
    for (k.words) |w| if (std.mem.startsWith(u8, n[w.at..][0..w.len], q)) return .{ .e = 0, .score = 70, .at = w.at, .len = len };
    if (q.len >= 2) for (k.aliases) |a| if (std.mem.startsWith(u8, a, q)) return .{ .e = 0, .score = 65 };
    if (q.len >= 3) if (std.mem.find(u8, n, q)) |at| return .{ .e = 0, .score = 50, .at = @intCast(at), .len = len };
    if (q.len < 4) return .{ .e = 0, .score = 0 };
    const max: u8 = if (q.len >= 7) 2 else 1;
    var d = @min(distance(q, n, max), distance(q, n[0..@min(q.len, n.len)], max), distance(q, n[0..@min(q.len + 1, n.len)], max));
    for (k.words) |w| if (w.len >= 4) {
        d = @min(d, distance(q, n[w.at..][0..w.len], max));
    };
    return .{ .e = 0, .score = if (d <= max) 40 - 10 * d else 0 };
}

/// Optimal string alignment distance, stopping early above `max`
fn distance(a: []const u8, b: []const u8, max: u8) u8 {
    const far = max + 1;
    if (a.len > 32 or b.len > 32) return far;
    if (@max(a.len, b.len) - @min(a.len, b.len) > max) return far;
    var rows: [3][33]u8 = undefined;
    var prev2 = &rows[0];
    var prev = &rows[1];
    var row = &rows[2];
    for (0..b.len + 1) |j| prev[j] = @intCast(j);
    for (1..a.len + 1) |i| {
        row[0] = @intCast(i);
        var low = row[0];
        for (1..b.len + 1) |j| {
            const cost: u8 = @intFromBool(a[i - 1] != b[j - 1]);
            var d = @min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost);
            if (i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]) d = @min(d, prev2[j - 2] + 1);
            row[j] = d;
            low = @min(low, d);
        }
        if (low > max) return far;
        const t = prev2;
        prev2 = prev;
        prev = row;
        row = t;
    }
    return prev[b.len];
}

const W = struct {
    pub const champion = plain("Champion");
    pub const clear = plain("Clear");
    pub const none = plain("No champion by that name");
};

pub const ChampSearch = struct {
    index: *const Index,
    /// Unique on the page: the list's and options' ids start with it
    id: []const u8,
    mode: enum { link, pick, filter } = .link,
    label: tree.Text = W.champion,
    /// The list in the page's flow, not over it (a panel that is all search)
    in_flow: bool = false,
    q: url.Str(24) = .{},
    open: bool = false,
    /// The option the arrows are on, among those shown
    active: u8 = 0,
    /// Pick mode: the entry taken
    chosen: ?u16 = null,

    const S = @This();

    pub const Msg = union(enum) { input, key, focus, blur, pick: u16, clear };

    pub fn update(s: *S, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .input => {
                s.q.set(ev.text);
                s.open = s.mode != .filter;
                s.active = 0;
            },
            .focus => s.open = s.mode != .filter,
            .blur => s.open = false,
            .pick => |e| s.take(e, ev),
            .clear => {
                s.chosen = null;
                ev.push = true;
                ev.after = .{ .op = .focus, .ref = "input" };
            },
            .key => s.key(ev),
        }
    }

    fn take(s: *S, e: u16, ev: *tree.Event) void {
        s.chosen = e;
        s.q.set("");
        s.open = false;
        ev.push = true;
        ev.after = .{ .op = .focus, .ref = "clear" };
    }

    fn key(s: *S, ev: *tree.Event) void {
        const k = ev.text;
        if (std.mem.eql(u8, k, "Escape")) {
            if (s.open and s.q.len > 0) {
                s.open = false;
            } else if (s.q.len > 0) {
                s.q.set("");
            } else return;
            ev.handled = true;
            return;
        }
        if (s.mode == .filter) return;
        var buf: [max_hits]Hit = undefined;
        const shown = s.index.match(s.q.slice(), &buf);
        if (shown.len == 0) return;
        const down = std.mem.eql(u8, k, "ArrowDown");
        if (down or std.mem.eql(u8, k, "ArrowUp")) {
            const n: u8 = @intCast(shown.len);
            const at = @min(s.active, n - 1);
            s.active = if (!s.open) (if (down) 0 else n - 1) else if (down) (at + 1) % n else (at + n - 1) % n;
            s.open = true;
            ev.handled = true;
            ev.after = .{ .op = .scroll, .ref = "active" };
        } else if (std.mem.eql(u8, k, "Enter") and s.open) {
            const hit = shown[@min(s.active, shown.len - 1)];
            ev.handled = true;
            switch (s.mode) {
                .link => if (s.index.entries[hit.e].href != null) {
                    ev.after = .{ .op = .click, .ref = "active" };
                },
                .pick => s.take(hit.e, ev),
                .filter => unreachable,
            }
        }
    }

    pub fn view(s: *S, h: *H) N {
        if (s.chosen) |e| return h.div(.{ .class = "c-search" }, .{s.chip(h, e)});
        if (s.mode == .filter) return h.div(.{ .class = "c-search" }, .{h.input(.{
            .type = "search",
            .placeholder = s.label,
            .aria_label = s.label,
            .autocomplete = "off",
            .spellcheck = "false",
            .value = s.q.slice(),
            .data_ref = "input",
            .on_input = h.on(s, .input),
            .on_keydown = h.on(s, .key),
        })});
        var buf: [max_hits]Hit = undefined;
        const shown = s.index.match(s.q.slice(), &buf);
        var folded: [32]u8 = undefined;
        const open = s.open and fold(&folded, s.q.slice()).len > 0;
        const active: ?usize = if (open and shown.len > 0) @min(s.active, shown.len - 1) else null;
        const list_id = h.fmt("{s}-list", .{s.id});
        var opts = h.list();
        for (shown, 0..) |hit, k| {
            const e = &s.index.entries[hit.e];
            const ref: ?[]const u8 = if (active == k) "active" else null;
            const id = h.fmt("{s}-{d}", .{ s.id, hit.e });
            const pic = champ.view(h, .{ .name = e.name, .src = e.src }, .{ .named = false });
            var rs = h.list();
            for (e.roles) |r| rs.add(role.view(h, r, .{ .s = .s }));
            const roles = if (e.roles.len > 0) h.span(.{ .class = "rs" }, .{rs.done()}) else null;
            opts.add(if (s.mode == .link and e.href != null) h.li(.{
                .key = hit.e + 1,
                .id = id,
                .role = "option",
                .aria_selected = active == k,
            }, .{h.a(.{ .href = e.href, .tabindex = -1, .data_ref = ref }, .{ pic, named(h, e.name, hit), roles })}) else h.li(.{
                .key = hit.e + 1,
                .id = id,
                .role = "option",
                .tabindex = -1,
                .aria_selected = active == k,
                .data_ref = ref,
                .on_click = h.on(s, .{ .pick = hit.e }),
            }, .{ pic, named(h, e.name, hit), roles }));
        }
        if (open and shown.len == 0) opts.add(h.li(.{ .class = "none", .role = "option", .aria_disabled = true }, .{W.none}));
        return h.div(.{ .class = "c-search", .data_flow = s.in_flow, .on_focusout = h.on(s, .blur) }, .{
            h.input(.{
                .type = "search",
                .role = "combobox",
                .placeholder = s.label,
                .aria_label = s.label,
                .aria_autocomplete = "list",
                .aria_controls = list_id,
                .aria_expanded = open,
                .aria_activedescendant = if (active) |k| h.fmt("{s}-{d}", .{ s.id, shown[k].e }) else null,
                .autocomplete = "off",
                .spellcheck = "false",
                .value = s.q.slice(),
                .data_ref = "input",
                .on_input = h.on(s, .input),
                .on_keydown = h.on(s, .key),
                .on_focusin = h.on(s, .focus),
            }),
            h.ul(.{ .id = list_id, .role = "listbox", .aria_label = s.label, .hidden = !open }, .{opts.done()}),
        });
    }

    fn chip(s: *S, h: *H, e: u16) N {
        const x = &s.index.entries[e];
        return h.span(.{ .class = "c-chosen" }, .{
            champ.view(h, .{ .name = x.name, .src = x.src }, .{ .named = false }),
            x.name,
            h.button(.{ .type = "button", .aria_label = W.clear, .data_ref = "clear", .on_click = h.on(s, .clear) }, .{"×"}),
        });
    }
};

/// The name with the matched part marked
fn named(h: *H, n: []const u8, hit: Hit) N {
    if (hit.len == 0) return h.span(.{ .class = "nm" }, .{n});
    var f: usize = 0;
    var from: usize = 0;
    var to: usize = n.len;
    for (n, 0..) |ch, i| {
        if (!isFolded(ch)) continue;
        if (f == hit.at) from = i;
        f += 1;
        if (f == hit.at + hit.len) {
            to = i + 1;
            break;
        }
    }
    return h.span(.{ .class = "nm" }, .{
        if (from > 0) n[0..from] else null,
        h.mark(.{}, .{n[from..to]}),
        if (to < n.len) n[to..] else null,
    });
}

pub const css =
    \\@layer components {
    \\  .c-search { position: relative; width: 100%; max-width: 320px; }
    \\  .c-search::before { content: ""; position: absolute; left: 12px; top: calc(var(--ctl) / 2); width: 15px; height: 15px;
    \\    transform: translateY(-50%); background: var(--muted); pointer-events: none; mask: var(--mag) center / contain no-repeat;
    \\    --mag: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23000' stroke-width='2.4' stroke-linecap='round'%3E%3Ccircle cx='10.5' cy='10.5' r='6.5'/%3E%3Cpath d='M15.5 15.5 21 21'/%3E%3C/svg%3E"); }
    \\  .c-search:has(> .c-chosen)::before { display: none; }
    \\  .c-search > input { width: 100%; padding-left: 34px; box-sizing: border-box; }
    \\  .c-search > ul { list-style: none; margin: 4px 0 0; padding: 4px; position: absolute; left: 0; right: 0;
    \\    z-index: var(--z-pop); background: var(--panel-2); border: 1px solid var(--line-2);
    \\    border-radius: var(--r-l); box-shadow: var(--shadow-pop); max-height: 300px; overflow-y: auto; }
    \\  .c-search[data-flow] > ul { position: static; box-shadow: none; }
    \\  .c-search li { display: flex; align-items: center; gap: var(--sp-2); min-height: var(--ctl);
    \\    padding: 2px 8px; border-radius: var(--r-ctl); cursor: pointer; }
    \\  .c-search li > a { display: flex; align-items: center; gap: var(--sp-2); flex: 1; min-width: 0; align-self: stretch;
    \\    color: inherit; text-decoration: none; outline: none; }
    \\  .c-search li:is([aria-selected="true"], :hover) { background: var(--ctl-bg-2); }
    \\  .c-search .nm { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    \\  .c-search mark { background: none; color: var(--accent); font-weight: var(--w-b); }
    \\  .c-search .rs { display: flex; gap: 2px; }
    \\  .c-search li.none { color: var(--muted); cursor: default; background: none; }
    \\  .c-chosen { display: inline-flex; align-items: center; gap: var(--sp-2); height: var(--ctl); box-sizing: border-box;
    \\    padding: 0 var(--sp-1) 0 3px; border: 1px solid var(--sel-line); border-radius: var(--r-ctl);
    \\    background: var(--sel-bg); color: var(--sel-ink); font-weight: var(--w-b); max-width: 100%; }
    \\  .c-chosen > .c-champ { --sz: calc(var(--ctl) - 8px); }
    \\  .c-chosen > button { all: unset; display: grid; place-items: center; width: 24px; height: 24px; border-radius: var(--r-ctl);
    \\    color: var(--t2); font-size: var(--fs-l); cursor: pointer; }
    \\  .c-chosen > button:hover { background: var(--ctl-bg-2); color: var(--text); }
    \\  .c-chosen > button:focus-visible { outline: 2px solid var(--focus); outline-offset: -2px; }
    \\}
    \\
;

/// The gallery's fixture, and the tests'
pub const Demo = struct {
    fn e(comptime key: []const u8, comptime shown: []const u8, comptime roles: []const role.Role) Entry {
        const c = champ.demo(key, shown);
        return .{ .name = c.name, .src = c.src, .href = "#", .roles = roles };
    }

    pub const entries = [_]Entry{
        e("Ahri", "Ahri", &.{.mid}),
        e("Akali", "Akali", &.{ .mid, .top }),
        e("AurelionSol", "Aurelion Sol", &.{.mid}),
        e("DrMundo", "Dr. Mundo", &.{ .top, .jungle }),
        e("JarvanIV", "Jarvan IV", &.{.jungle}),
        e("Jhin", "Jhin", &.{.bot}),
        e("Kaisa", "Kai'Sa", &.{.bot}),
        e("Kalista", "Kalista", &.{.bot}),
        e("Karma", "Karma", &.{ .support, .mid }),
        e("Karthus", "Karthus", &.{.jungle}),
        e("Kassadin", "Kassadin", &.{.mid}),
        e("Katarina", "Katarina", &.{.mid}),
        e("Kayle", "Kayle", &.{.top}),
        e("Kayn", "Kayn", &.{.jungle}),
        e("LeeSin", "Lee Sin", &.{.jungle}),
        e("MissFortune", "Miss Fortune", &.{.bot}),
        e("Nidalee", "Nidalee", &.{.jungle}),
        e("Nunu", "Nunu & Willump", &.{.jungle}),
        e("Singed", "Singed", &.{.top}),
        e("TwistedFate", "Twisted Fate", &.{.mid}),
    };
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ix = h.mem.create(Index) catch {
        h.oom = true;
        return;
    };
    ix.* = Index.init(h.mem, &Demo.entries) catch {
        h.oom = true;
        return;
    };
    const states = [_]struct { []const u8, ChampSearch }{
        .{ "empty", .{ .index = ix, .id = g.id("cs-a") } },
        .{ "typed: prefixes, shortest first", .{ .index = ix, .id = g.id("cs-b"), .in_flow = true, .open = true, .active = 1, .q = typed("ka") } },
        .{ "a word of the name", .{ .index = ix, .id = g.id("cs-c"), .in_flow = true, .open = true, .q = typed("mundo") } },
        .{ "a typo", .{ .index = ix, .id = g.id("cs-d"), .in_flow = true, .open = true, .q = typed("jhni") } },
        .{ "nothing found", .{ .index = ix, .id = g.id("cs-e"), .in_flow = true, .open = true, .q = typed("zzz") } },
        .{ "pick mode: the chosen one", .{ .index = ix, .id = g.id("cs-f"), .mode = .pick, .chosen = 15 } },
    };
    for (states) |st| {
        const s = h.mem.create(ChampSearch) catch {
            h.oom = true;
            return;
        };
        s.* = st[1];
        g.add(st[0], s.view(h));
    }
}

fn typed(s: []const u8) url.Str(24) {
    var x: url.Str(24) = .{};
    x.set(s);
    return x;
}

fn names(ix: *const Index, query: []const u8) ![]const u8 {
    var buf: [max_hits]Hit = undefined;
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    errdefer out.deinit();
    for (ix.match(query, &buf), 0..) |hit, i| {
        if (i > 0) try out.writer.writeByte(',');
        try out.writer.writeAll(ix.entries[hit.e].name);
    }
    return out.toOwnedSlice();
}

test "matching: whole names and aliases, prefixes shortest first, words, parts, typos" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const ix = try Index.init(arena.allocator(), &Demo.entries);
    const cases = [_][2][]const u8{
        .{ "mf", "Miss Fortune" },
        .{ "J4", "Jarvan IV" },
        .{ "lee sin", "Lee Sin" },
        .{ "kaisa", "Kai'Sa,Kassadin" },
        .{ "Kai'S", "Kai'Sa,Kalista,Kassadin" },
        .{ "ka", "Kayn,Karma,Kayle,Kai'Sa,Kalista,Karthus,Kassadin,Katarina" },
        .{ "mundo", "Dr. Mundo" },
        .{ "nunu", "Nunu & Willump" },
        .{ "will", "Nunu & Willump" },
        .{ "jhni", "Jhin" },
        .{ "kasadin", "Kassadin,Katarina" },
        .{ "fate", "Twisted Fate" },
        .{ "ari", "Katarina" },
        .{ "as", "Aurelion Sol" },
        .{ "", "" },
        .{ "zzz", "" },
    };
    for (cases) |c| {
        const got = try names(&ix, c[0]);
        defer std.testing.allocator.free(got);
        std.testing.expectEqualStrings(c[1], got) catch |err| {
            std.debug.print("query \"{s}\"\n", .{c[0]});
            return err;
        };
    }
}
