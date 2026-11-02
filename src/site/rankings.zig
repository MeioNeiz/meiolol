//! Rankings (docs/plan/ui/rankings.md): /rankings/<stat>[/<role>], every champion ranked
//! by one stat (ui.ranking), each view. All: each champion in its main role

const std = @import("std");
const core = @import("core");
const ui = @import("ui");
const root = @import("root.zig");
const html = @import("html.zig");
const shell = @import("shell.zig");
const assets = @import("assets.zig");
const champion = @import("champion.zig");
const tpl = html.tpl;

const Writer = std.Io.Writer;
const Site = root.Site;
const Champ = root.Champ;
const Role = core.Role;
const rk = ui.ranking;
const Counts = core.statsfile.Counts;

/// Every stat, All then each role, when the view has lane curves
pub fn paths(site: *const Site, list: *std.ArrayList(ui.urls.Page)) !void {
    if (site.curves == null) return;
    for (std.enums.values(rk.Stat)) |s| {
        try list.append(site.arena, .{ .ranking = .{ .stat = s } });
        for (Role.all) |r| try list.append(site.arena, .{ .ranking = .{ .stat = s, .role = champion.uiRole(r) } });
    }
}

pub fn writePage(site: *const Site, w: *Writer, at: ui.urls.Ranking) !bool {
    if (site.curves == null) return false;
    const a = site.arena;
    const sp = rk.spec(at.stat);
    const r: ?Role = if (at.role) |x| root.coreRole(x) else null;
    const pg = try site.page(
        try a.print("{s}, {s} | meiolol", .{ sp.title, if (r) |x| root.roleName(x) else "all roles" }),
        try a.print("Every champion ranked: {s}", .{sp.lead}),
        .{ .ranking = at },
        .champions,
    );
    try shell.open(w, pg);
    try tpl.renderPart(w, "<h1>{title} ", .{ .title = sp.title });
    try site.writeChip(w, site.regionDim(site.view.region), site.periodDim(site.view.period), .plat);
    try w.writeAll("</h1>\n");

    const d = try a.create(rk.Data);
    d.* = try data(site, at.stat, r);
    var p: rk.Ranking = try .init(a, d);
    p.bin = try bin(a, d.*);
    var tree: ui.Tree = .{};
    var h: ui.H = .init(a, &tree);
    const lead: ui.Text = .{ .s = if (r) |x| try a.print("{s} {s}: {d:.1}%.", .{ sp.lead, root.roleName(x), usualOf(site, at.stat, x) orelse 0 }) else sp.lead };
    tree.root = h.div(.{}, .{ try head(site, &h, at, r, lead), p.view(&h) });
    if (h.oom) return error.OutOfMemory;
    try ui.html.write(&tree, tree.root, w);
    try tpl.render(w, "\n<script src=\"{js}\" data-wasm=\"{wasm}\" defer></script>\n", .{
        .js = html.Link{ .path = assets.rankings_js.path },
        .wasm = assets.rankings_wasm.path,
    });
    try shell.close(w, pg);
    return true;
}

/// ui.ranking.head: the sibling stats' switch and the roles'
fn head(site: *const Site, h: *ui.H, at: ui.urls.Ranking, r: ?Role, lead: ui.Text) !ui.N {
    const a = site.arena;
    const sibs = rk.siblingsOf(at.stat);
    const stats = try a.alloc(ui.segmented.Item, sibs.len);
    for (stats, sibs) |*s, x| s.* = .{
        .label = .{ .s = rk.spec(x).short },
        .selected = x == at.stat,
        .href = try site.href(.{ .ranking = .{ .stat = x, .role = at.role } }),
    };
    const roles = try a.alloc(ui.segmented.Item, 1 + Role.all.len);
    roles[0] = .{ .label = ui.plain("All"), .selected = r == null, .href = try site.href(.{ .ranking = .{ .stat = at.stat } }) };
    for (Role.all, roles[1..]) |x, *s| s.* = .{
        .label = champion.uiRole(x).label(),
        .selected = r == x,
        .href = try site.href(.{ .ranking = .{ .stat = at.stat, .role = champion.uiRole(x) } }),
    };
    return rk.head(h, stats, roles, lead);
}

/// Which of the comeback counts a stat reads: [minute][bucket]
fn cell(s: rk.Stat) struct { usize, usize } {
    return switch (s) {
        .ahead => .{ 1, 4 },
        .behind => .{ 1, 0 },
    };
}

fn usualOf(site: *const Site, s: rk.Stat, r: Role) ?f32 {
    const c = &(site.curves orelse return null);
    const base = c.baseline(r, .all) orelse return null;
    const at = cell(s);
    const k = base.comeback(std.enums.values(core.curvesfile.Comeback)[at[0]], at[1]);
    return if (k.games == 0) null else rate(k.wins, k.games);
}

fn rate(wins: u32, games: u32) f32 {
    return @floatCast(100 * @as(f64, @floatFromInt(wins)) / @as(f64, @floatFromInt(games)));
}

/// Per role, every champion that plays it (on All: its main role) with games in the
/// stat's spot; pulled toward the role by k from how much champions differ there
pub fn data(site: *const Site, s: rk.Stat, only: ?Role) !rk.Data {
    const a = site.arena;
    const at = cell(s);
    var rows: std.ArrayList(rk.Row) = .empty;
    for (Role.all) |r| {
        if (only) |x| if (x != r) continue;
        const usual = usualOf(site, s, r) orelse continue;
        var cells: std.ArrayList(Counts) = .empty;
        var chs: std.ArrayList(Champ) = .empty;
        for (site.champs) |ch| {
            const in = if (only != null) champion.plays(site, ch, r) else root.mainRole(site, ch) == r;
            if (!in) continue;
            const cb = try champion.comebackSums(site, ch, r) orelse continue;
            const k = cb.at[at[0]][at[1]];
            if (k.games == 0) continue;
            try cells.append(a, .{ .games = k.games, .wins = k.wins });
            try chs.append(a, ch);
        }
        const prior: core.banimpact.Prior = .ofCounts(cells.items);
        for (cells.items, chs.items) |k, ch| {
            const cr = site.stats.champRole(r, ch.c);
            try rows.append(a, .{
                .name = ch.name,
                .key = ch.key,
                .href = try site.href(.{ .champion = .{ .slug = ch.slug, .role = champion.uiRole(r) } }),
                .role = champion.uiRole(r),
                .value = rate(k.wins, k.games),
                .usual = usual,
                .pulled = @floatCast(100 * prior.edge(k.wins, k.games)),
                .n = k.games,
                .overall = if (cr.games == 0) 0 else rate(cr.wins, cr.games),
            });
        }
    }
    std.mem.sort(rk.Row, rows.items, {}, struct {
        fn f(_: void, x: rk.Row, y: rk.Row) bool {
            return x.pulled > y.pulled;
        }
    }.f);
    return .{ .stat = s, .role = if (only) |x| champion.uiRole(x) else null, .ddragon = site.ddragon_version, .rows = rows.items };
}

/// `v` as ui.data, base64: the island root's data-bin
fn bin(a: std.mem.Allocator, v: rk.Data) ![]const u8 {
    var raw: std.ArrayList(u8) = .empty;
    try ui.data.encode(a, rk.Data, v, &raw);
    const e = std.base64.standard.Encoder;
    const out = try a.alloc(u8, e.calcSize(raw.items.len));
    return e.encode(out, raw.items);
}
