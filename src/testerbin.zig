//! The Draft tester's model files as the page's wasm reads them (ui/testerdata.zig,
//! ui/testerlane.zig): DIR/draft-model.json and lane-model.json with their -ref.json, the
//! box's or the lab's export, to DIR/draft-model.bin and lane-model.bin, and the lab's
//! draft-setnet.json to draft-setnet.bin (ui/testersetnet.zig). One converter for both
//! sources, so a lab export pushed as JSON gets the same file
const std = @import("std");
const ui = @import("ui");
const df = @import("draftfile.zig");
const lf = @import("lanefile.zig");
const Date = @import("date.zig").Date;
const tsn = ui.testersetnet;

const Io = std.Io;
const Model = ui.testerdata.Model;

pub fn model(arena: std.mem.Allocator, json: []const u8, ref_json: []const u8) !Model {
    const f = try std.json.parseFromSliceLeaky(df.ModelFile, arena, json, .{ .ignore_unknown_fields = true });
    const ref = try std.json.parseFromSliceLeaky(df.RefFile, arena, ref_json, .{ .ignore_unknown_fields = true });
    const refs = try arena.alloc(ui.testerdata.Ref, ref.drafts.len);
    for (refs, ref.drafts) |*o, r| o.* = .{ .label = r.label, .teams = r.teams, .blue = r.blue };
    if (!std.mem.eql(u8, f.format, "meiolol-draft-model") or f.version != 4) return error.NotDraftModel;
    const champions = try arena.alloc(ui.testerdata.Champion, f.champions.len);
    for (champions, f.champions) |*o, c| o.* = .{ .id = c.id, .name = c.name };
    const cells = try arena.alloc(ui.testerdata.Cell, f.cells.len);
    for (cells, f.cells) |*o, c| o.* = .{ .champion = c.champion, .role = c.role, .games = c.games, .patch_share = c.patch_share };
    const m = f.meta;
    const e = f.model;
    return .{
        .meta = .{
            .name = m.name,
            .run = m.run,
            .snapshot = m.snapshot,
            .newest_game = m.newest_game,
            .training_games = @intCast(m.training_games),
            .patch = m.patch,
            .patch_games = m.patch_games,
            .oldest_patch = m.oldest_patch,
            .newest_patch = m.newest_patch,
            .platform = m.platform,
            .dev = .{ .games = @intCast(m.dev.games), .log_loss = m.dev.log_loss, .baseline_log_loss = m.dev.baseline_log_loss, .accuracy = m.dev.accuracy, .auc = m.dev.auc },
        },
        .min_games = f.min_games,
        .champions = champions,
        .cells = cells,
        .params = .{
            .kind = e.kind,
            .dim = e.dim,
            .intercept = try arena.dupe(f32, &.{@floatCast(e.intercept)}),
            .w = e.w,
            .z = e.z,
            .terms = e.terms,
            .comp = e.comp,
            .pairs = e.pairs,
            .temperature = e.temperature,
        },
        .refs = refs,
    };
}

pub fn lane(arena: std.mem.Allocator, json: []const u8, ref_json: []const u8) !ui.testerlane.Model {
    const f = try std.json.parseFromSliceLeaky(lf.ModelFile, arena, json, .{ .ignore_unknown_fields = true });
    const ref = try std.json.parseFromSliceLeaky(lf.RefFile, arena, ref_json, .{ .ignore_unknown_fields = true });
    if (!std.mem.eql(u8, f.format, "meiolol-lane-model") or f.version != 1) return error.NotLaneModel;
    for (f.outcomes, lf.outcomes) |x, y| if (!std.mem.eql(u8, x, y)) return error.NotLaneModel;
    const m = f.meta;
    const removed = for (m.dev) |d| {
        if (std.mem.eql(u8, d.outcome, "lanediff14")) break d.removed_pct;
    } else 0;
    // The page always scores with the other eight slots at their average
    var intercept: [lf.n_lane][lf.n_role]f32 = undefined;
    for (&intercept, f.intercept, f.others) |*o, a, b| for (o, a, b) |*x, y, z| {
        x.* = @floatCast(y + z);
    };
    const pairs = try arena.alloc(ui.testerlane.Term, f.pairs.len);
    for (pairs, f.pairs) |*o, p| o.* = .{
        .champion = p[0],
        .enemy = p[1],
        .role = p[2],
        .n = p[3],
        .b = .{ @floatCast(p[4]), @floatCast(p[5]), @floatCast(p[6]), @floatCast(p[7]) },
        .sd = .{ @floatCast(p[8]), @floatCast(p[9]), @floatCast(p[10]), @floatCast(p[11]) },
    };
    const refs = try arena.alloc(ui.testerlane.Ref, ref.refs.len);
    for (refs, ref.refs) |*o, r| o.* = .{ .role = r.role, .champion = r.champion, .enemy = r.enemy, .value = f32s(r.value), .lo = f32s(r.lo), .hi = f32s(r.hi), .champ_games = r.champ_games, .pair_games = r.pair_games };
    return .{
        .meta = .{
            .name = m.name,
            .newest_game = m.newest_game,
            .training_games = @intCast(m.training_games),
            .patch = m.patch,
            .oldest_patch = m.oldest_patch,
            .newest_patch = m.newest_patch,
            .lanediff_removed = @floatCast(removed),
        },
        .intercept = intercept,
        .champ = try terms(arena, f.champ),
        .enemy = try terms(arena, f.enemy),
        .pairs = pairs,
        .refs = refs,
    };
}

fn f32s(x: [lf.n_lane]f64) [lf.n_lane]f32 {
    var out: [lf.n_lane]f32 = undefined;
    for (&out, x) |*o, y| o.* = @floatCast(y);
    return out;
}

fn terms(arena: std.mem.Allocator, from: []const lf.Term) ![]const ui.testerlane.Term {
    const out = try arena.alloc(ui.testerlane.Term, from.len);
    for (out, from) |*o, t| o.* = .{ .champion = t.champion, .enemy = t.enemy, .role = t.role, .n = t.n, .b = f32s(t.b), .sd = f32s(t.sd) };
    return out;
}

/// DIR's draft and lane model JSON, whichever are there, each to its .bin; one whose
/// scorer misses its references is not written, after the other is tried
pub fn convert(arena: std.mem.Allocator, io: Io, dir: []const u8, w: *Io.Writer) !void {
    var refused = false;
    var any = false;
    inline for (.{ convertDraft, convertLane }, .{ "draft-model.json", "lane-model.json" }) |f, json| {
        if (try read(arena, io, dir, json, 256 << 20)) |bytes| {
            any = true;
            f(arena, io, dir, bytes, w) catch |e| switch (e) {
                error.ScorerDisagrees => refused = true,
                else => return e,
            };
        }
    }
    if (try read(arena, io, dir, "draft-setnet.json", 256 << 20)) |bytes| {
        any = true;
        convertSetNet(arena, io, dir, bytes, w) catch |e| switch (e) {
            error.ScorerDisagrees => refused = true,
            else => return e,
        };
    }
    if (!any) return error.NoModelFiles;
    if (refused) return error.ScorerDisagrees;
}

fn read(arena: std.mem.Allocator, io: Io, dir: []const u8, name: []const u8, limit: usize) !?[]const u8 {
    return Io.Dir.cwd().readFileAlloc(io, try std.fs.path.join(arena, &.{ dir, name }), arena, .limited(limit)) catch |e| switch (e) {
        error.FileNotFound => null,
        else => e,
    };
}

fn convertLane(arena: std.mem.Allocator, io: Io, dir: []const u8, json: []const u8, w: *Io.Writer) !void {
    const ref = try read(arena, io, dir, "lane-ref.json", 16 << 20) orelse return error.NoLaneRef;
    const m = try lane(arena, json, ref);
    const c = (try ui.testerlane.Scorer.init(arena, &m)).check();
    try w.print("lane-model.bin against {d} reference matchups: max |diff| {e}\n", .{ c.refs, c.worst });
    if (!c.ok()) return error.ScorerDisagrees;
    try write(arena, io, dir, "lane-model.bin", m, w);
}

fn write(arena: std.mem.Allocator, io: Io, dir: []const u8, name: []const u8, m: anytype, w: *Io.Writer) !void {
    var out: std.ArrayList(u8) = .empty;
    try m.encode(arena, &out);
    try Io.Dir.cwd().writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, name }), .data = out.items });
    try w.print("wrote {s}/{s} ({d} KB)\n", .{ dir, name, out.items.len / 1024 });
}

fn convertDraft(arena: std.mem.Allocator, io: Io, dir: []const u8, json: []const u8, w: *Io.Writer) !void {
    const ref = try read(arena, io, dir, "draft-ref.json", 16 << 20) orelse return error.NoDraftRef;
    const m = try model(arena, json, ref);
    const sc = try m.scorer(arena);
    const c = m.check(&sc);
    try w.print("draft-model.bin against {d} reference drafts: max |diff| {e}\n", .{ c.drafts, c.worst });
    if (!c.ok()) return error.ScorerDisagrees;
    try write(arena, io, dir, "draft-model.bin", m, w);
}

/// draft-setnet.json: the lab's seeds together (`meiolol-lab netcheck --export`)
const SetNetsFile = struct { format: []const u8, nets: []const df.SetNetFile };

/// The page's file, and each seed's reference forward pass (draftfile.SetNet) to hold
/// it to
pub fn setNet(arena: std.mem.Allocator, json: []const u8) !struct { m: tsn.Model, ref: []const df.SetNet } {
    const f = try std.json.parseFromSliceLeaky(SetNetsFile, arena, json, .{ .ignore_unknown_fields = true });
    if (!std.mem.eql(u8, f.format, "meiolol-setnets") or f.nets.len == 0) return error.NotSetNet;
    const nets = try arena.alloc(tsn.Net, f.nets.len);
    const ref = try arena.alloc(df.SetNet, f.nets.len);
    for (nets, ref, f.nets) |*o, *r, x| {
        r.* = try .init(arena, x);
        if (x.features.len != f.nets[0].features.len) return error.NotSetNet;
        for (x.features, f.nets[0].features) |a, b| if (!std.mem.eql(u8, a, b)) return error.NotSetNet;
        // Files without their platforms are in the lab's order (protocol.platformIds)
        const euw = r.platform("EUW1") orelse if (x.platforms.len == 0) legacy_euw else return error.NoEuw;
        if (euw >= r.n_platforms) return error.NoEuw;
        const l = x.layout;
        const ids = try arena.alloc(tsn.Id, x.ids.len);
        for (ids, x.ids) |*i, y| i.* = .{ .champion = y.champion, .role = y.role, .id = y.id };
        const profiles = try arena.alloc(tsn.Profile, x.profiles.len);
        for (profiles, x.profiles) |*i, y| i.* = .{ .champion = y.champion, .role = y.role, .z = y.z };
        const refs = try arena.alloc(tsn.Ref, x.refs.len);
        for (refs, x.refs) |*i, y| i.* = .{ .teams = y.teams, .platform = y.platform, .offset = y.offset, .logit = y.logit };
        o.* = .{
            .seed = x.seed,
            .phi = @intCast(x.phi),
            .rho = @intCast(x.rho),
            .emb = @intCast(x.emb),
            .n_prof = @intCast(x.n_prof),
            .cross = x.cross,
            .euw = euw,
            .layout = .{ .in = @intCast(l.in), .rin = @intCast(l.rin), .c = @intCast(l.c), .a = @intCast(l.a), .b1 = @intCast(l.b1), .cb = @intCast(l.cb), .e = @intCast(l.e), .w1 = @intCast(l.w1), .v = @intCast(l.v), .out = @intCast(l.out), .len = @intCast(l.len) },
            .params = x.params,
            .ids = ids,
            .profiles = profiles,
            .refs = refs,
        };
    }
    const n0 = f.nets[0];
    return .{ .m = .{
        .candidate = n0.candidate,
        .fit_games = @intCast(n0.fit_games),
        .fit_newest = if (n0.fit_newest > 0) try arena.print("{f}", .{Date.fromMs(n0.fit_newest)}) else "",
        .features = n0.features,
        .nets = nets,
    }, .ref = ref };
}

/// EUW1's index in the lab's platform list (riot/endpoints.zig)
const legacy_euw = 6;

/// Each seed against its references and the reference forward pass; then, when DIR has
/// the draft model, whether it is the base the nets were fitted on (a note: the page
/// shows the net only on its own base)
fn convertSetNet(arena: std.mem.Allocator, io: Io, dir: []const u8, json: []const u8, w: *Io.Writer) !void {
    var s = try setNet(arena, json);
    var worst: f64 = 0;
    var apart: f64 = 0;
    for (s.m.nets, s.ref) |*n, *r| {
        const sc: tsn.Scorer = try .init(n);
        worst = @max(worst, sc.check());
        for (n.refs) |x| apart = @max(apart, @abs(sc.logit(x.teams, x.platform, x.offset, .none) - r.logit(x.teams, x.platform, x.offset)));
    }
    const n0 = &s.m.nets[0];
    try w.print("draft-setnet.bin, {d} seeds against {d} reference games: max |diff| {e}, {e} from draftfile.SetNet\n", .{ s.m.nets.len, n0.refs.len, worst, apart });
    if (n0.refs.len == 0 or worst > tsn.ref_tol or apart > 1e-9) return error.ScorerDisagrees;
    if (try read(arena, io, dir, "draft-model.json", 256 << 20)) |mj| if (try read(arena, io, dir, "draft-ref.json", 16 << 20)) |rj| {
        const m = try model(arena, mj, rj);
        const sc = try m.scorer(arena);
        var base: f64 = 0;
        for (n0.refs) |r| if (r.platform == n0.euw) {
            s.m.base_games += 1;
            const d = @abs(sc.rawLogit(r.teams) - r.offset);
            if (!(d <= base)) base = if (std.math.isNan(d)) std.math.inf(f64) else d;
        };
        s.m.base_worst = @floatCast(base);
        const same = s.m.base_games > 0 and base <= tsn.base_tol;
        try w.print("draft-setnet.bin base: draft-model.json on {d} EUW1 reference games, max |diff| {d:.4}{s}\n", .{ s.m.base_games, base, if (same) "" else ": not its base, the page won't show it" });
    };
    try write(arena, io, dir, "draft-setnet.bin", s.m, w);
}

test "set net: the page's forward pass is draftfile.SetNet's" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const params = tsn.testParams();
    const n = tsn.testNet(&params, &.{});
    var json: Io.Writer.Allocating = .init(arena);
    try std.json.Stringify.value(.{ .format = "meiolol-setnets", .nets = .{.{
        .format = "meiolol-setnet",
        .version = 1,
        .fit_newest = 1792000844515,
        .platforms = .{ "NA1", "EUW1" },
        .phi = n.phi,
        .rho = n.rho,
        .emb = n.emb,
        .cross = n.cross,
        .n_prof = n.n_prof,
        .features = .{ "magic", "cc" },
        .layout = n.layout,
        .params = n.params,
        .ids = n.ids,
        .profiles = n.profiles,
        .refs = n.refs,
    }} }, .{}, &json.writer);
    const s = try setNet(arena, json.written());
    try std.testing.expectEqualStrings("2026-10-14", s.m.fit_newest);
    try std.testing.expectEqual(1, s.m.nets[0].euw);
    const sc = try tsn.Scorer.init(&s.m.nets[0]);
    const drafts = [_][2][5]u32{ .{ .{ 10, 0, 0, 0, 0 }, .{ 0, 0, 0, 20, 0 } }, .{ .{ 0, 0, 0, 20, 0 }, .{ 10, 0, 0, 0, 0 } }, @splat(@splat(0)) };
    for (drafts) |t| for ([_]u8{ 0, 1 }) |plat| {
        try std.testing.expectApproxEqAbs(s.ref[0].logit(t, plat, 0.3), sc.logit(t, plat, 0.3, .none), 1e-12);
    };
}
