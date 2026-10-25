//! The champions table (champions.html, role/<slug>.html) as an island: every champion's
//! win rate by role, sorted by any column, searched, rare picks under the player's
//! minimums hidden until asked for. Writes the markup and classes tierlist.zig wrote
//! before it, so the legacy CSS styles it until the visual pass rebuilds the page.
//!
//! The server renders the default state from the same Data the page's data file
//! (data/tiers.bin) carries; ui-stats.wasm decodes that file and adopts the table. Only
//! the default state's rows are on the page: rare ones come with the data
const std = @import("std");
const tree = @import("tree.zig");
const fmt = @import("fmt.zig");
const url = @import("url.zig");
const H = tree.H;
const N = tree.N;

/// core.Role's order (tierlist.zig checks it)
pub const Role = enum(u8) {
    top,
    jungle,
    middle,
    bottom,
    utility,

    pub const names = [_][]const u8{ "Top", "Jungle", "Mid", "Bot", "Support" };
    pub const slugs = [_][]const u8{ "top", "jungle", "mid", "bot", "support" };
    const icons = [_][]const u8{ "#ri-top", "#ri-jungle", "#ri-mid", "#ri-bot", "#ri-support" };

    pub fn name(r: Role) []const u8 {
        return names[@backingInt(r)];
    }
};

/// spread.zig's shape: players near each point, every shape_step points from
/// -shape_reach to +shape_reach (tierlist.zig checks they match)
pub const shape_reach = 36;
pub const shape_step = 2;
pub const shape_points = 2 * shape_reach / shape_step + 1;

/// A data file's stamp: the page carries its file's, so ui.wasm adopts a page only with
/// the data it was rendered from (a cached page and a newer file would not match)
pub fn stamp(bytes: []const u8) u32 {
    return std.hash.Fnv1a_32.hash(bytes);
}

/// One view's champions table, all roles
pub const Data = struct {
    /// The view's games
    games: u32,
    /// Default minimums: games in the role, and the role's share of the champion's games
    min_games: u32,
    min_share: u8,
    /// Players with this many games on a champion count in its spread
    spread_min_games: u32,
    /// The patch change under each rate: "" without one
    cur_patch: []const u8,
    prev_patch: []const u8,
    /// "in EUW"
    region_in: []const u8,
    ddragon: []const u8,
    /// The view's query, for links to champion pages (html.View.query)
    query: []const u8,
    champs: []const Champ,
    /// By win rate pulled toward the role's average, ties most played first
    rows: []const Row,
};

pub const Champ = struct {
    name: []const u8,
    /// Data Dragon's
    key: []const u8,
    slug: []const u8,
    banned: u32,
};

pub const Row = struct {
    champ: u16,
    role: Role,
    games: u32,
    wins: u32,
    /// Of the champion's games, the share in this role
    share: f32,
    /// Ban impact (core.banimpact), and its pulled edge as a share
    impact: f32,
    edge: f32,
    /// Opacity of the rate: fainter with fewer games (curvesfile.fade)
    fade: f32,
    spread: ?Spread,
    patch: ?Patch,
};

pub const Spread = struct {
    players: u32,
    p25: u8,
    p75: u8,
    shape: [shape_points]u8,
};

pub const Patch = struct {
    /// Games and wins
    prev: [2]u32,
    cur: [2]u32,
    /// patchday.Rate.clear with the site's options
    clear: bool,
};

pub const Key = enum {
    name,
    role,
    win,
    pick,
    ban,
    impact,
    games,

    /// Numbers start high first, names A to Z
    fn numeric(k: Key) bool {
        return k != .name and k != .role;
    }
};

const W = struct {
    const key = "Sorted by win rate pulled toward the role's average, the more the fewer the games, so a few lucky games can't top it; the rate shown is raw.";
    const share_title = "Share of the champion's games played in the role";
    const search = "Search champion";
    const impact_title = "Wins above the role's average per 10,000 games it was not banned";
    const rare = " rare picks (under the minimum games, or a role the champion seldom plays) hidden. ";
};

/// A row's text and styles: they never change, so they are made once (prepare)
pub const Cells = struct {
    href: []const u8 = "",
    icon: []const u8 = "",
    colour: tree.Vars = .{ .css = "" },
    title: []const u8 = "",
    shape: ?[]const u8 = null,
    dot: tree.Vars = .{ .css = "" },
    fade: tree.Vars = .{ .css = "" },
    rate: []const u8 = "",
    note: ?Note = null,
    pick: []const u8 = "",
    ban: []const u8 = "",
    impact: []const u8 = "",
    impact_title: []const u8 = "",
    count: []const u8 = "",
};

pub const Note = struct {
    colour: tree.Vars,
    title: []const u8,
    text: []const u8,
    faint: bool,
};

/// Every row's Cells in `role` (all when null), by row index; `base` from the page to the
/// site root
pub fn prepare(gpa: std.mem.Allocator, d: *const Data, role: ?Role, base: []const u8) ![]const Cells {
    var t: tree.Tree = .{};
    var h: H = .init(gpa, &t);
    const cells = try gpa.alloc(Cells, d.rows.len);
    for (cells, d.rows) |*c, r| {
        c.* = .{};
        if (role != null and role.? != r.role) continue;
        const ch = d.champs[r.champ];
        const p = share(r.wins, r.games);
        c.href = h.fmt("{s}champion/{s}.html{s}", .{ base, ch.slug, d.query });
        c.icon = h.fmt("https://ddragon.leagueoflegends.com/cdn/{s}/img/champion/{s}.png", .{ d.ddragon, ch.key });
        c.colour = h.vars(.{ .c = fmt.wrColour(p, fmt.table_span) });
        c.title = if (r.spread) |s|
            h.fmt("{d} games; players with {d}+ games on {s}: middle half {d}% to {d}% ({d} players)", .{ r.games, d.spread_min_games, ch.name, s.p25, s.p75, s.players })
        else
            h.fmt("{d} games", .{r.games});
        if (r.spread) |s| c.shape = try shapePath(gpa, s.shape, 100 * p);
        // One decimal, as the dot sat before: a finer step only shifts antialiasing
        c.dot = h.vars(.{ .x = @round(10 * trackX(100 * p)) / 10 });
        c.fade = h.vars(.{ .f = r.fade });
        c.rate = try text(gpa, "{rate}", .{ .rate = .{ .rate, 100 * p } });
        if (r.patch) |pa| c.note = try note(gpa, &h, d, pa);
        c.pick = try pct(gpa, r.games, d.games);
        c.ban = try pct(gpa, ch.banned, d.games);
        const available = d.games -| ch.banned;
        const pick = if (available == 0) 0 else 100 * @as(f64, @floatFromInt(r.games)) / @as(f64, @floatFromInt(available));
        // U+2212: tabular figures space a hyphen out as if it were a digit
        c.impact = try text(gpa, "{minus}{abs}", .{ .minus = .{ .text, if (r.impact <= -0.5) "\u{2212}" else "" }, .abs = .{ .whole, @abs(r.impact) } });
        c.impact_title = try text(gpa, "Win rate {edge} points {side} the role's average once pulled toward it, picked in {pick}% of games it was not banned: {abs} {more} games won per 10,000 such games", .{
            .edge = .{ .one, 100 * @abs(r.edge) },
            .side = .{ .text, if (r.edge < 0) "under" else "over" },
            .pick = .{ .one, pick },
            .abs = .{ .whole, @abs(r.impact) },
            .more = .{ .text, if (r.impact < 0) "fewer" else "more" },
        });
        c.count = try text(gpa, "{n}", .{ .n = .{ .count, r.games } });
    }
    if (h.oom) return error.OutOfMemory;
    return cells;
}

/// The win rate's change since the previous patch: coloured as win rates are when clear,
/// faint when not
fn note(gpa: std.mem.Allocator, h: *H, d: *const Data, pa: Patch) !Note {
    const now = share(pa.cur[1], pa.cur[0]);
    const then = share(pa.prev[1], pa.prev[0]);
    const delta = 100 * (now - then);
    return .{
        .colour = h.vars(.{ .c = fmt.wrColour(0.5 + delta / 100, fmt.table_span) }),
        .title = try text(gpa, "Patch {cur} against {prev} {in}: {now}% of {cur_n} games won against {then}% of {prev_n}; {verdict}", .{
            .cur = .{ .text, d.cur_patch },
            .prev = .{ .text, d.prev_patch },
            .in = .{ .text, d.region_in },
            .now = .{ .one, 100 * now },
            .cur_n = .{ .count, pa.cur[0] },
            .then = .{ .one, 100 * then },
            .prev_n = .{ .count, pa.prev[0] },
            .verdict = .{ .text, if (pa.clear) "a clear change" else "no clear change" },
        }),
        .text = try text(gpa, "{sign}{abs}", .{
            .sign = .{ .text, if (delta >= 0.05) "+" else if (delta <= -0.05) "\u{2212}" else "" },
            .abs = .{ .one, @abs(delta) },
        }),
        .faint = !pa.clear,
    };
}

const Fig = enum { text, count, one, whole, rate };

/// `src` with each `{name}` written by its figure: `.{ .n = .{ .count, 8068 } }`. Floats
/// by fmt.fixed, never std's float formatter (ui.wasm size)
fn text(gpa: std.mem.Allocator, comptime src: []const u8, args: anytype) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(gpa);
    const w = &out.writer;
    comptime var i: usize = 0;
    inline while (comptime i < src.len) {
        const open = comptime std.mem.findScalarPos(u8, src, i, '{') orelse src.len;
        try w.writeAll(src[i..open]);
        if (open == src.len) break;
        const close = comptime std.mem.findScalarPos(u8, src, open, '}').?;
        const v = @field(args, src[open + 1 .. close]);
        const fig: Fig = comptime v[0];
        switch (fig) {
            .text => try w.writeAll(v[1]),
            .count => try fmt.write(w, .count, v[1]),
            .one => try fmt.fixed(w, v[1], 1, false),
            .whole => try fmt.fixed(w, v[1], 0, false),
            .rate => try fmt.write(w, .rate, v[1]),
        }
        i = close + 1;
    }
    return out.toOwnedSlice();
}

/// As root.pct: "12.3%", "-" of nothing
fn pct(gpa: std.mem.Allocator, part: u64, whole: u64) ![]const u8 {
    if (whole == 0) return "-";
    return text(gpa, "{p}", .{ .p = .{ .rate, 100 * @as(f64, @floatFromInt(part)) / @as(f64, @floatFromInt(whole)) } });
}

fn share(wins: u32, games: u32) f64 {
    return @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(@max(games, 1)));
}

/// The track's scale: 25% to 75% as 0 to 100
const track_lo = 25.0;
const track_width = 50.0;

fn trackX(rate: f64) f64 {
    return 100 * (std.math.clamp(rate, track_lo, track_lo + track_width) - track_lo) / track_width;
}

/// The shape's outline centred on `centre`% in a 100 x 10 box: along the top, back
/// along the bottom, pointed at both ends; it fades out towards the track's ends
/// (#wr-edge), past them clipped
fn shapePath(gpa: std.mem.Allocator, shape: [shape_points]u8, centre: f64) ![]const u8 {
    const P = struct {
        fn x(w: *std.Io.Writer, c: f64, k: usize) !void {
            const off = @as(f64, @floatFromInt(shape_step * k)) - shape_reach;
            try fmt.fixed(w, 100 * (c + off - track_lo) / track_width, 1, false);
        }
        fn y(w: *std.Io.Writer, v: u8, side: f64) !void {
            try w.writeByte(' ');
            try fmt.fixed(w, 5 + side * 5 * @as(f64, @floatFromInt(v)) / 255, 2, false);
        }
    };
    var out: std.Io.Writer.Allocating = .init(gpa);
    const w = &out.writer;
    try w.writeByte('M');
    try P.x(w, centre, 0);
    try w.writeAll(" 5");
    for (shape, 0..) |v, k| {
        try w.writeByte('L');
        try P.x(w, centre, k);
        try P.y(w, v, -1);
    }
    try w.writeByte('L');
    try P.x(w, centre, shape_points - 1);
    try w.writeAll(" 5");
    var k: usize = shape_points;
    while (k > 0) {
        k -= 1;
        try w.writeByte('L');
        try P.x(w, centre, k);
        try P.y(w, shape[k], 1);
    }
    try w.writeByte('Z');
    return out.toOwnedSlice();
}

/// The colour key under the table: rates at the scale's stops, each in its colour
const legend_pts = [_]f64{ -5.5, -3.5, -2, 0, 2, 3.5, 5.5 };

pub const Tiers = struct {
    data: *const Data,
    cells: []const Cells,
    /// The page's role; null on the all-roles page
    role: ?Role = null,
    /// From the page to its view's root (role tabs) and to the site root (champions)
    root: []const u8 = "",
    base: []const u8 = "",
    /// The data file, from the page
    src: []const u8 = "",
    /// The data file's hash (stamp): ui.wasm adopts the page only with the file it came
    /// from
    stamp: u32 = 0,
    /// false: the server's render, minimums hidden (nothing sets them without ui.wasm)
    live: bool = false,
    sort: Key = .win,
    desc: bool = true,
    q: url.Str(24) = .{},
    /// As typed, so a cleared field stays clear; null: the data's default
    min: ?url.Str(7) = null,
    share: ?url.Str(3) = null,

    pub const Msg = union(enum) { sort: Key, search, min_games, min_share, show_all };
    pub const Url = struct {
        sort: Key = .win,
        desc: bool = true,
        q: url.Str(24) = .{},
        min: ?url.Str(7) = null,
        share: ?url.Str(3) = null,
    };

    pub fn toUrl(t: *const Tiers) Url {
        return .{ .sort = t.sort, .desc = t.desc, .q = t.q, .min = t.min, .share = t.share };
    }

    pub fn fromUrl(t: *Tiers, u: Url) void {
        t.sort = u.sort;
        t.desc = u.desc;
        t.q = u.q;
        t.min = u.min;
        t.share = u.share;
    }

    pub fn update(t: *Tiers, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .sort => |k| {
                if (ev.kind == .keydown) {
                    if (!std.mem.eql(u8, ev.text, "Enter") and !std.mem.eql(u8, ev.text, " ")) return;
                    ev.handled = true;
                }
                t.desc = if (t.sort == k) !t.desc else k.numeric();
                t.sort = k;
                ev.push = true;
            },
            .search => t.q.set(ev.text),
            .min_games => t.min = typed(7, ev.text),
            .min_share => t.share = typed(3, ev.text),
            .show_all => {
                t.min = typed(7, "0");
                t.share = typed(3, "0");
                ev.push = true;
            },
        }
    }

    fn typed(comptime cap: u8, s: []const u8) url.Str(cap) {
        var v: url.Str(cap) = .{};
        v.set(s);
        return v;
    }

    fn minGames(t: *const Tiers) u32 {
        const s = t.min orelse return t.data.min_games;
        return std.fmt.parseInt(u32, s.slice(), 10) catch 0;
    }

    fn minShare(t: *const Tiers) f32 {
        const s = t.share orelse return @floatFromInt(t.data.min_share);
        return @floatFromInt(std.fmt.parseInt(u8, s.slice(), 10) catch 0);
    }

    fn rare(t: *const Tiers, r: Row, min_games: u32, min_share: f32) bool {
        _ = t;
        return r.games < min_games or 100 * r.share < min_share;
    }

    /// The rows shown, in order, and how many of the role's rows are rare
    fn order(t: *const Tiers, out: []u16) struct { []u16, usize } {
        const d = t.data;
        const min_games = t.minGames();
        const min_share = t.minShare();
        const q = t.q.slice();
        var n: usize = 0;
        var rares: usize = 0;
        for (d.rows, 0..) |r, i| {
            if (t.role != null and t.role.? != r.role) continue;
            const is_rare = t.rare(r, min_games, min_share);
            rares += @intFromBool(is_rare);
            // A search finds rare rows too
            const shown = if (q.len > 0) std.ascii.findIgnoreCase(d.champs[r.champ].name, q) != null else !is_rare;
            if (!shown) continue;
            out[n] = @intCast(i);
            n += 1;
        }
        // Stable, so ties keep the data's order (most played first)
        std.sort.insertion(u16, out[0..n], t, before);
        return .{ out[0..n], rares };
    }

    fn before(t: *const Tiers, a: u16, b: u16) bool {
        const x = t.data.rows[if (t.desc) b else a];
        const y = t.data.rows[if (t.desc) a else b];
        return switch (t.sort) {
            .name => std.ascii.orderIgnoreCase(t.data.champs[x.champ].name, t.data.champs[y.champ].name) == .lt,
            .role => @backingInt(x.role) < @backingInt(y.role),
            .win => share(x.wins, x.games) < share(y.wins, y.games),
            .pick, .games => x.games < y.games,
            .ban => t.data.champs[x.champ].banned < t.data.champs[y.champ].banned,
            .impact => x.impact < y.impact,
        };
    }

    fn ariaSort(t: *const Tiers, k: Key) ?[]const u8 {
        if (t.sort != k) return null;
        return if (t.desc) "descending" else "ascending";
    }

    pub fn view(t: *Tiers, h: *H) N {
        const d = t.data;
        const buf = h.mem.alloc(u16, d.rows.len) catch {
            h.oom = true;
            return .none;
        };
        const shown, const rares = t.order(buf);
        var rows = h.list();
        for (shown, 1..) |i, rank| rows.add(t.row(h, i, rank));
        return h.div(.{
            .data_island = "tiers",
            .data_src = t.src,
            .data_root = t.root,
            .data_base = t.base,
            .data_role = if (t.role) |r| Role.slugs[@backingInt(r)] else null,
            .data_stamp = t.stamp,
        }, .{
            h.div(.{ .class = "tl-bar" }, .{
                t.tabs(h),
                h.el(.details, .{ .class = "tl-knobs", .hidden = !t.live }, .{
                    h.el(.summary, .{}, .{"Minimums"}),
                    h.span(.{ .class = "tl-mins" }, .{
                        h.label(.{}, .{
                            "Min games ",
                            h.input(.{ .type = "number", .inputmode = "numeric", .min = 0, .step = 100, .value = if (t.min) |*s| s.slice() else h.fmt("{d}", .{d.min_games}), .on_input = h.on(t, .min_games) }),
                        }),
                        h.label(.{ .title = W.share_title }, .{
                            "Min lane % ",
                            h.input(.{ .type = "number", .inputmode = "numeric", .min = 0, .max = 100, .step = 5, .value = if (t.share) |*s| s.slice() else h.fmt("{d}", .{d.min_share}), .on_input = h.on(t, .min_share) }),
                        }),
                    }),
                }),
                h.input(.{ .type = "search", .placeholder = W.search, .aria_label = W.search, .value = t.q.slice(), .on_input = h.on(t, .search) }),
            }),
            h.p(.{ .class = "tl-key" }, .{
                W.key,
                if (d.prev_patch.len > 0) h.fmt(" Under it: the change since {s}, faint when not clear.", .{d.prev_patch}) else null,
            }),
            h.div(.{ .class = "tl-wrap" }, .{h.table(.{ .class = "tl tiers", .id = "tiers" }, .{
                h.thead(.{}, .{h.tr(.{}, .{t.heads(h)})}),
                h.tbody(.{}, .{rows.done()}),
            })}),
            legend(h),
            h.p(.{ .class = "tl-more", .hidden = rares == 0 }, .{
                h.span(.{}, .{rares}),
                W.rare,
                h.button(.{ .class = "link", .on_click = h.on(t, .show_all) }, .{"Show them"}),
            }),
        });
    }

    const Head = struct { key: Key, label: []const u8, class: ?[]const u8 = null, sort: []const u8 = "num", title: ?[]const u8 = null };
    const heads_all = [_]Head{
        .{ .key = .name, .label = "Champion", .class = "l", .sort = "text" },
        .{ .key = .role, .label = "Role", .class = "role", .sort = "text" },
        .{ .key = .win, .label = "Win rate" },
        .{ .key = .pick, .label = "Pick", .class = "opt" },
        .{ .key = .ban, .label = "Ban", .class = "opt" },
        .{ .key = .impact, .label = "Influence", .title = W.impact_title },
        .{ .key = .games, .label = "Games" },
    };

    /// The column headers: a click, Enter or Space sorts by the column
    fn heads(t: *Tiers, h: *H) []const N {
        var ths = h.list();
        ths.add(h.th(.{ .class = "rank" }, .{"#"}));
        // One call site in a loop rather than one per column: ui.wasm size
        for (heads_all) |c| {
            if (c.key == .role and t.role != null) continue;
            ths.add(h.th(.{ .tabindex = 0, .class = c.class, .data_sort = c.sort, .title = c.title, .aria_sort = t.ariaSort(c.key), .on_click = h.on(t, .{ .sort = c.key }), .on_keydown = h.on(t, .{ .sort = c.key }) }, .{c.label}));
        }
        return ths.done();
    }

    fn tabs(t: *const Tiers, h: *H) N {
        var links = h.list();
        links.add(h.a(.{ .href = h.fmt("{s}champions.html", .{t.root}), .aria_current = if (t.role == null) "page" else null }, .{"All roles"}));
        for (std.enums.values(Role)) |r| {
            const i = @backingInt(r);
            links.add(h.a(.{ .href = h.fmt("{s}role/{s}.html", .{ t.root, Role.slugs[i] }), .aria_current = if (t.role == r) "page" else null }, .{
                h.svg(.{ .class = "ri", .aria_hidden = "true" }, .{h.el(.use, .{ .href = Role.icons[i] }, .{})}),
                Role.names[i],
            }));
        }
        return h.el(.nav, .{ .class = "tabs" }, .{links.done()});
    }

    fn row(t: *const Tiers, h: *H, i: u16, rank: usize) N {
        const r = t.data.rows[i];
        const c = &t.cells[i];
        const rate = h.b(.{ .style = c.fade }, .{c.rate});
        return h.tr(.{ .key = i, .class = "bx" }, .{
            h.td(.{ .class = "rank" }, .{rank}),
            h.td(.{ .class = "l" }, .{h.a(.{ .class = "champ box", .href = c.href }, .{
                h.img(.{ .src = c.icon, .alt = "", .loading = "lazy", .width = 32, .height = 32 }),
                t.data.champs[r.champ].name,
            })}),
            if (t.role == null) h.td(.{ .class = "role" }, .{roleIcon(h, r.role)}) else null,
            h.td(.{}, .{h.span(.{ .class = "wr", .style = c.colour, .title = c.title }, .{
                h.span(.{ .class = "ci" }, .{
                    if (c.shape) |s| h.svg(.{ .class = "shape", .viewBox = "0 0 100 10", .preserveAspectRatio = "none", .aria_hidden = "true" }, .{h.path(.{ .d = s }, .{})}) else null,
                    h.el(.i, .{ .class = "d", .style = c.dot }, .{}),
                }),
                if (c.note) |n| h.span(.{ .class = "wv" }, .{
                    rate,
                    h.small(.{ .class = if (n.faint) "pd faint" else "pd", .style = n.colour, .title = n.title }, .{n.text}),
                }) else rate,
            })}),
            h.td(.{ .class = "opt" }, .{c.pick}),
            h.td(.{ .class = "opt" }, .{c.ban}),
            h.td(.{ .class = if (r.impact < 0) "bi dim" else "bi", .title = c.impact_title }, .{c.impact}),
            h.td(.{ .class = "dim" }, .{c.count}),
        });
    }
};

/// The role's icon (root.roleIcons' symbols), named for screen readers and on hover
fn roleIcon(h: *H, r: Role) N {
    return h.svg(.{ .class = "ri", .role = "img", .aria_label = r.name() }, .{
        h.el(.title, .{}, .{r.name()}),
        h.el(.use, .{ .href = Role.icons[@backingInt(r)] }, .{}),
    });
}

fn legend(h: *H) N {
    var spans = h.list();
    for (legend_pts, 0..) |x, i| {
        const p = 0.5 + x / 100;
        spans.add(h.text(if (i == 0) "Win rate colour " else " "));
        spans.add(h.span(.{ .class = "wrc", .style = h.vars(.{ .c = fmt.wrColour(p, fmt.table_span) }) }, .{ @round(1000 * p) / 10, "%" }));
    }
    return h.p(.{ .class = "wr-key" }, .{spans.done()});
}
