//! SiteSearch: the header's search. Finds a champion (ChampSearch's matching), a matchup
//! ("Ahri vs Zed", "ahri zed", "ahri/zed") or a Riot ID (Name#TAG, and the ones looked up
//! on this device); every option is a link. An ARIA combobox as ChampSearch: arrows move,
//! Enter takes the active option, Escape closes. Before the island runs, and before its
//! index is in for a Riot ID, the form is a plain lookup (GET /your?id=)
const std = @import("std");
const tree = @import("tree.zig");
const url = @import("url.zig");
const role = @import("role.zig");
const champ = @import("champ.zig");
const champsearch = @import("champsearch.zig");
const idlookup = @import("idlookup.zig");
const urls = @import("urls.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const Allocator = std.mem.Allocator;
const H = tree.H;
const N = tree.N;

pub const name = "SiteSearch";
pub const scope = .{".c-sitesearch"};
pub const sel = "[data-island=search]";

/// data/search.bin in each view's tree
pub const Data = struct {
    ddragon: []const u8,
    champs: []const Champ,
    /// One per pair i < j of `champs`, at i * (2n - i - 1) / 2 + j - i - 1: the Role of
    /// their matchup page with the most games, `no_page` for none
    pairs: []const u8,

    pub const Champ = struct { name: []const u8, slug: []const u8, key: []const u8 };
    pub const no_page = 255;
};

pub const Index = struct {
    data: Data,
    m: champsearch.Index,

    pub fn init(a: Allocator, d: Data) !Index {
        const entries = try a.alloc(champsearch.Entry, d.champs.len);
        for (d.champs, entries) |c, *e| e.* = .{ .name = c.name, .src = try std.fmt.allocPrint(a, "/icon/{s}/{s}.jpg", .{ d.ddragon, c.key }) };
        return .{ .data = d, .m = try .init(a, entries) };
    }

    /// The role of x against y's matchup page, if there is one
    fn pair(ix: *const Index, x: u16, y: u16) ?role.Role {
        if (x == y) return null;
        const n = ix.data.champs.len;
        const i: usize = @min(x, y);
        const j: usize = @max(x, y);
        const at = i * (2 * n - i - 1) / 2 + j - i - 1;
        if (at >= ix.data.pairs.len or ix.data.pairs[at] >= role.Role.all.len) return null;
        return @fromBackingInt(@intCast(ix.data.pairs[at]));
    }
};

pub const Opt = union(enum) {
    champ: champsearch.Hit,
    pair: struct { a: u16, b: u16, r: role.Role },
    /// The typed Riot ID
    lookup,
    /// recent[i]
    id: u8,
};

pub const max_opts = champsearch.max_hits + 2;

const W = struct {
    pub const label = plain("Champion, matchup or Riot ID");
    pub const aria = plain("Search a champion, a matchup (Ahri vs Zed) or a Riot ID (Name#TAG)");
    pub const suggestions = plain("Suggestions");
    pub const champion = plain("Champion");
    pub const yours = plain("Your games");
    pub const riot_id = plain("Riot ID");
    pub const look_up = phrase.Phrase("Look up {id:text}");
    pub const vs = phrase.Phrase("{a:text} vs {b:text}");
    pub const id_form = plain("A Riot ID is Name#TAG, for example Faker#KR1.");
    pub const none = plain("No champion or matchup by that name. A Riot ID needs its tag: Name#TAG.");
};

pub const SiteSearch = struct {
    /// Null until the island loads the view's search.bin
    index: ?*const Index = null,
    /// The view's query, on every champion and matchup link ("" the default view)
    query: []const u8 = "",
    /// Newest first (your-recent on this device)
    recent: []const idlookup.Id = &.{},
    q: idlookup.Id = .{},
    open: bool = false,
    /// The option the arrows are on; null: none (the empty box's recent IDs)
    active: ?u8 = null,
    /// Asks the host for the index (focus or typing before it is in)
    want: bool = false,
    /// Enter came before the index: the host follows the first option once it is in
    go: bool = false,
    /// The list in the page's flow, not over it (the gallery)
    in_flow: bool = false,

    const S = @This();

    pub const Msg = union(enum) { input, key, focus, blur };

    pub fn update(s: *S, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .input => {
                s.q.set(ev.text);
                s.open = true;
                s.active = if (s.text().len > 0) 0 else null;
                s.want = s.index == null;
            },
            .focus => {
                s.open = true;
                s.active = if (s.text().len > 0) 0 else null;
                s.want = s.index == null;
            },
            .blur => s.open = false,
            .key => s.key(ev),
        }
    }

    fn key(s: *S, ev: *tree.Event) void {
        const k = ev.text;
        if (std.mem.eql(u8, k, "Escape")) {
            if (!s.open) return;
            s.open = false;
            ev.handled = true;
            return;
        }
        var buf: [max_opts]Opt = undefined;
        const shown = s.options(&buf);
        const down = std.mem.eql(u8, k, "ArrowDown");
        if (down or std.mem.eql(u8, k, "ArrowUp")) {
            ev.handled = true;
            s.open = true;
            if (shown.len == 0) return;
            const n: u8 = @intCast(shown.len);
            s.active = if (s.active) |at| (if (down) (at + 1) % n else (at + n - 1) % n) else if (down) 0 else n - 1;
            ev.after = .{ .op = .scroll, .ref = "active" };
        } else if (std.mem.eql(u8, k, "Enter")) {
            if (s.text().len == 0) {
                ev.handled = true;
                return;
            }
            if (shown.len > 0) {
                if (s.active == null) s.active = 0;
                s.open = true;
                ev.handled = true;
                ev.after = .{ .op = .click, .ref = "active" };
            } else if (s.index == null and std.mem.findScalar(u8, s.text(), '#') == null) {
                // A champion or matchup: wait for the index; a Riot ID submits the form
                ev.handled = true;
                s.go = true;
                s.want = true;
            }
        }
    }

    fn text(s: *const S) []const u8 {
        return std.mem.trim(u8, s.q.slice(), " \t");
    }

    /// The options for the text, best first: as search.js was
    pub fn options(s: *const S, out: *[max_opts]Opt) []Opt {
        const t = s.text();
        var n: usize = 0;
        if (t.len == 0) {
            for (s.recent[0..@min(s.recent.len, 5)], 0..) |_, i| {
                out[n] = .{ .id = @intCast(i) };
                n += 1;
            }
            return out[0..n];
        }
        var known: [max_opts]u8 = undefined;
        var nk: usize = 0;
        var exact = false;
        for (s.recent, 0..) |*r, i| {
            const id = r.slice();
            if (id.len < t.len or !std.ascii.eqlIgnoreCase(id[0..t.len], t)) continue;
            exact = exact or id.len == t.len;
            if (nk < known.len) {
                known[nk] = @intCast(i);
                nk += 1;
            }
        }
        if (std.mem.findScalar(u8, t, '#')) |hash| {
            if (hash > 0 and hash + 1 < t.len and std.mem.findScalarPos(u8, t, hash + 1, '#') == null and !exact) {
                out[n] = .lookup;
                n += 1;
            }
            for (known[0..nk]) |i| if (n < out.len) {
                out[n] = .{ .id = i };
                n += 1;
            };
            return out[0..n];
        }
        const ix = s.index orelse return out[0..0];
        var found: Found = .{};
        if (separated(t)) |sp| {
            found.pairs(ix, sp[0], sp[1], 0);
        } else {
            var hits: [6]champsearch.Hit = undefined;
            for (ix.m.match(t, &hits)) |hit| found.add(.{ .s = (@as(u32, hit.score) + 5) * 1000, .o = .{ .champ = hit } });
            // Without "vs" a pair needs both names clear ("lee sin" is not Nidalee vs Singed)
            const floor: u32 = if (found.n > 0) 65 else 30;
            var it = std.mem.tokenizeAny(u8, t, " \t");
            while (it.next()) |_| {
                const cut = it.index;
                if (cut >= t.len) break;
                found.pairs(ix, t[0..cut], t[cut..], floor);
            }
        }
        const sorted = found.items[0..found.n];
        std.mem.sort(Scored, sorted, ix, Scored.before);
        for (sorted) |f| {
            if (n == champsearch.max_hits) break;
            const dup = for (out[0..n]) |o| {
                if (same(o, f.o)) break true;
            } else false;
            if (dup) continue;
            out[n] = f.o;
            n += 1;
        }
        for (known[0..@min(nk, 2)]) |i| {
            out[n] = .{ .id = i };
            n += 1;
        }
        return out[0..n];
    }

    /// Where an option goes
    pub fn href(s: *const S, h: *H, o: Opt) []const u8 {
        const look: idlookup.IdLookup = .{ .to = "/your" };
        return switch (o) {
            .champ => |hit| h.fmt("{f}{s}", .{ urls.Page{ .champion = .{ .slug = s.index.?.data.champs[hit.e].slug } }, s.query }),
            .pair => |p| h.fmt("{f}{s}", .{ urls.Page{ .matchup = .{ .role = p.r, .a = s.index.?.data.champs[p.a].slug, .b = s.index.?.data.champs[p.b].slug } }, s.query }),
            .lookup => look.href(h, s.text()),
            .id => |i| look.href(h, s.recent[i].slice()),
        };
    }

    pub fn view(s: *S, h: *H) N {
        var buf: [max_opts]Opt = undefined;
        const shown = s.options(&buf);
        const t = s.text();
        const hint: ?tree.Text = if (shown.len > 0 or t.len == 0) null else if (std.mem.findScalar(u8, t, '#') != null) W.id_form else if (s.index != null) W.none else null;
        const open = s.open and (shown.len > 0 or hint != null);
        const active: ?usize = if (open) if (s.active) |a| @min(a, shown.len -| 1) else null else null;
        var lis = h.list();
        for (shown, 0..) |o, k| {
            const here = active == k and shown.len > 0;
            lis.add(h.li(.{ .key = k, .id = h.fmt("look-opt-{d}", .{k}), .role = "option", .aria_selected = here }, .{
                h.a(.{ .href = s.href(h, o), .tabindex = -1, .data_ref = if (here) "active" else null }, .{s.option(h, o)}),
            }));
        }
        if (open) if (hint) |x| lis.add(h.li(.{ .class = "none", .role = "option", .aria_disabled = true }, .{x}));
        return h.el(.form, .{
            .class = "c-search c-sitesearch",
            .data_island = "search",
            .action = "/your",
            .method = "get",
            .role = "search",
            .data_flow = s.in_flow,
            .on_focusout = h.on(s, .blur),
        }, .{
            h.input(.{
                .name = "id",
                .type = "search",
                .role = "combobox",
                .placeholder = W.label,
                .aria_label = W.aria,
                .aria_autocomplete = "list",
                .aria_controls = "look-list",
                .aria_expanded = open,
                .aria_activedescendant = if (active != null and shown.len > 0) h.fmt("look-opt-{d}", .{active.?}) else null,
                .autocomplete = "off",
                .spellcheck = "false",
                .enterkeyhint = "go",
                .required = true,
                .value = s.q.slice(),
                .data_ref = "input",
                .on_input = h.on(s, .input),
                .on_keydown = h.on(s, .key),
                .on_focusin = h.on(s, .focus),
            }),
            h.ul(.{ .id = "look-list", .role = "listbox", .aria_label = W.suggestions, .hidden = !open }, .{lis.done()}),
        });
    }

    fn option(s: *const S, h: *H, o: Opt) []const N {
        const champs = if (s.index) |ix| ix.m.entries else &.{};
        var l = h.list();
        switch (o) {
            .champ => |hit| {
                l.add(pic(h, champs[hit.e]));
                l.add(h.span(.{ .class = "nm" }, .{champs[hit.e].name}));
                l.add(h.small(.{}, .{W.champion}));
            },
            .pair => |p| {
                l.add(h.span(.{ .class = "pics" }, .{ pic(h, champs[p.a]), pic(h, champs[p.b]) }));
                l.add(h.span(.{ .class = "nm" }, .{W.vs.with(h, .{ .a = champs[p.a].name, .b = champs[p.b].name })}));
                l.add(h.small(.{}, .{p.r.label()}));
            },
            .lookup => {
                l.add(h.span(.{ .class = "nm" }, .{W.look_up.with(h, .{ .id = s.text() })}));
                l.add(h.small(.{}, .{W.riot_id}));
            },
            .id => |i| {
                l.add(h.span(.{ .class = "nm" }, .{s.recent[i].slice()}));
                l.add(h.small(.{}, .{W.yours}));
            },
        }
        return l.done();
    }
};

fn pic(h: *H, e: champsearch.Entry) N {
    return champ.view(h, .{ .name = e.name, .src = e.src }, .{ .named = false });
}

fn same(x: Opt, y: Opt) bool {
    return switch (x) {
        .champ => |a| y == .champ and y.champ.e == a.e,
        .pair => |a| y == .pair and y.pair.a == a.a and y.pair.b == a.b,
        else => false,
    };
}

/// "a vs b", "a v. b", "a versus b" (b may be empty), else "a/b" or "a,b": the two sides
fn separated(t: []const u8) ?[2][]const u8 {
    var it = std.mem.tokenizeAny(u8, t, " \t");
    var first = true;
    while (it.next()) |w| {
        defer first = false;
        if (first) continue;
        const words = [_][]const u8{ "v", "vs", "v.", "vs.", "versus" };
        for (words) |x| if (std.ascii.eqlIgnoreCase(w, x)) {
            const end = it.index;
            return .{ std.mem.trim(u8, t[0 .. end - w.len], " \t"), std.mem.trim(u8, t[end..], " \t") };
        };
    }
    const at = std.mem.findAny(u8, t, "/,") orelse return null;
    const left = std.mem.trim(u8, t[0..at], " \t");
    if (left.len == 0) return null;
    return .{ left, std.mem.trim(u8, t[at + 1 ..], " \t") };
}

const Scored = struct {
    /// Score x 1000, plus a tie-break
    s: u32,
    o: Opt,

    /// Higher score; between pairs, the opponent A to Z
    fn before(ix: *const Index, x: Scored, y: Scored) bool {
        if (x.s != y.s) return x.s > y.s;
        if (x.o != .pair or y.o != .pair) return false;
        return std.ascii.orderIgnoreCase(ix.data.champs[x.o.pair.b].name, ix.data.champs[y.o.pair.b].name) == .lt;
    }
};

const Found = struct {
    items: [640]Scored = undefined,
    n: usize = 0,

    fn add(f: *Found, x: Scored) void {
        if (f.n == f.items.len) return;
        f.items[f.n] = x;
        f.n += 1;
    }

    /// Pairs from the left and right texts: the left's best few against the right's; an
    /// empty right ("ahri vs"): every opponent with a page. Those under `floor` drop
    fn pairs(f: *Found, ix: *const Index, left: []const u8, right: []const u8, floor: u32) void {
        var lb: [3]champsearch.Hit = undefined;
        var rb: [8]champsearch.Hit = undefined;
        const ls = ix.m.match(left, &lb);
        const rs = ix.m.match(right, &rb);
        for (ls) |a| {
            if (std.mem.trim(u8, right, " \t").len > 0) {
                for (rs) |b| {
                    const r = ix.pair(a.e, b.e) orelse continue;
                    const low = @min(a.score, b.score);
                    if (low < floor) continue;
                    f.add(.{ .s = @as(u32, low) * 1000 + a.score + b.score, .o = .{ .pair = .{ .a = a.e, .b = b.e, .r = r } } });
                }
            } else if (a.score >= 70) {
                for (0..ix.data.champs.len) |b| {
                    const r = ix.pair(a.e, @intCast(b)) orelse continue;
                    f.add(.{ .s = (@as(u32, a.score) - 1) * 1000, .o = .{ .pair = .{ .a = a.e, .b = @intCast(b), .r = r } } });
                }
            }
        }
    }
};

pub const css =
    \\@layer components {
    \\  .c-sitesearch li > a > .pics { display: flex; }
    \\  .c-sitesearch li > a > .pics > .c-champ + .c-champ { margin-left: -4px; }
    \\  .c-sitesearch li > a > small { flex: none; color: var(--muted); font-size: var(--fs-xs); }
    \\  .c-sitesearch li.none { cursor: default; white-space: normal; }
    \\}
    \\
;

/// The gallery's and the tests' index: Demo's champions, pairs where both play a role
pub fn demoIndex(a: Allocator) !*Index {
    const es = &champsearch.Demo.entries;
    const champs = try a.alloc(Data.Champ, es.len);
    for (es, champs) |e, *c| {
        const key = e.src[std.mem.findScalarLast(u8, e.src, '/').? + 1 ..];
        c.* = .{ .name = e.name, .slug = try std.ascii.allocLowerString(a, key[0 .. key.len - 4]), .key = key[0 .. key.len - 4] };
    }
    const n = es.len;
    const pairs = try a.alloc(u8, n * (n - 1) / 2);
    var at: usize = 0;
    for (0..n) |i| for (i + 1..n) |j| {
        pairs[at] = Data.no_page;
        for (es[i].roles) |r| for (es[j].roles) |q| if (r == q) {
            pairs[at] = @backingInt(r);
        };
        at += 1;
    };
    const ix = try a.create(Index);
    ix.* = .{ .data = .{ .ddragon = champ.demo_version, .champs = champs, .pairs = pairs }, .m = try .init(a, es) };
    return ix;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const ix = demoIndex(h.mem) catch {
        h.oom = true;
        return;
    };
    var recent: [2]idlookup.Id = .{ .{}, .{} };
    recent[0].set("Faker#KR1");
    recent[1].set("Agurin#EUW");
    const rec = h.mem.dupe(idlookup.Id, &recent) catch {
        h.oom = true;
        return;
    };
    const cases = [_]struct { []const u8, []const u8 }{
        .{ "a champion", "kat" },
        .{ "a matchup", "ahri vs kat" },
        .{ "every opponent", "jhin vs" },
        .{ "a Riot ID", "Caps#G2" },
        .{ "the empty box: Riot IDs looked up here", "" },
        .{ "nothing found", "zzzz" },
    };
    for (cases) |c| {
        const s = h.mem.create(SiteSearch) catch {
            h.oom = true;
            return;
        };
        s.* = .{ .index = ix, .recent = rec, .open = true, .in_flow = true, .active = if (c[1].len > 0) 0 else null };
        s.q.set(c[1]);
        g.add(c[0], s.view(h));
    }
}

test "champions, matchups and Riot IDs" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const ix = try demoIndex(a);
    var recent: [2]idlookup.Id = .{ .{}, .{} };
    recent[0].set("Faker#KR1");
    recent[1].set("Agurin#EUW");
    var s: SiteSearch = .{ .index = ix, .recent = &recent, .query = "?region=all" };
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    var buf: [max_opts]Opt = undefined;

    // Empty: the recent IDs
    try std.testing.expectEqual(2, s.options(&buf).len);
    try std.testing.expectEqualStrings("/your#id=Faker%23KR1", s.href(&h, s.options(&buf)[0]));

    s.q.set("kata");
    var o = s.options(&buf);
    try std.testing.expectEqualStrings("/champions/katarina?region=all", s.href(&h, o[0]));

    // "vs": the pair's page in its role; "lee sin" is one champion, not Nidalee vs Singed
    s.q.set("Ahri vs Kassadin");
    o = s.options(&buf);
    try std.testing.expectEqualStrings("/matchups/mid/ahri-vs-kassadin?region=all", s.href(&h, o[0]));
    s.q.set("ahri kassadin");
    o = s.options(&buf);
    try std.testing.expect(o.len > 0 and o[0] == .pair);
    s.q.set("lee sin");
    o = s.options(&buf);
    try std.testing.expect(o.len > 0 and o[0] == .champ);
    for (o) |x| try std.testing.expect(x != .pair);
    s.q.set("ahri/kassadin");
    try std.testing.expect(s.options(&buf)[0] == .pair);

    // "jhin vs": every opponent with a page, A to Z
    s.q.set("jhin vs");
    o = s.options(&buf);
    try std.testing.expectEqual(3, o.len);
    try std.testing.expectEqualStrings("/matchups/bot/jhin-vs-kaisa?region=all", s.href(&h, o[0]));

    // A Riot ID: look it up, then the matching recent ones; an exact recent one only once
    s.q.set("Caps#G2");
    o = s.options(&buf);
    try std.testing.expectEqual(1, o.len);
    try std.testing.expectEqualStrings("/your#id=Caps%23G2", s.href(&h, o[0]));
    s.q.set("faker#kr1");
    o = s.options(&buf);
    try std.testing.expectEqual(1, o.len);
    try std.testing.expect(o[0] == .id);
    s.q.set("fa");
    o = s.options(&buf);
    try std.testing.expect(o[o.len - 1] == .id);
}

test "Enter before the index: waits for a champion, follows a Riot ID's link" {
    var s: SiteSearch = .{};
    var ev: tree.Event = .{ .kind = .input, .text = "ahri" };
    s.update(.input, &ev);
    try std.testing.expect(s.want);
    ev = .{ .kind = .keydown, .text = "Enter" };
    s.update(.key, &ev);
    try std.testing.expect(s.go and ev.handled);
    var t: SiteSearch = .{};
    ev = .{ .kind = .input, .text = "Caps#G2" };
    t.update(.input, &ev);
    ev = .{ .kind = .keydown, .text = "Enter" };
    t.update(.key, &ev);
    try std.testing.expect(!t.go and ev.after != null);
}
