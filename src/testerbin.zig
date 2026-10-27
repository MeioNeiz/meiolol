//! The Draft tester's model files as the page's wasm reads them (ui/testerdata.zig):
//! DIR/draft-model.json and draft-ref.json, the box's or the lab's export, to
//! DIR/draft-model.bin. One converter for both, so a lab export pushed as JSON gets the
//! same file
const std = @import("std");
const ui = @import("ui");
const df = @import("draftfile.zig");

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

/// DIR/draft-model.json and draft-ref.json to DIR/draft-model.bin, refused when the
/// scorer misses the references
pub fn convert(arena: std.mem.Allocator, io: Io, dir: []const u8, w: *Io.Writer) !void {
    const cwd = Io.Dir.cwd();
    const json = try cwd.readFileAlloc(io, try std.fs.path.join(arena, &.{ dir, "draft-model.json" }), arena, .limited(256 << 20));
    const ref = try cwd.readFileAlloc(io, try std.fs.path.join(arena, &.{ dir, "draft-ref.json" }), arena, .limited(16 << 20));
    const m = try model(arena, json, ref);
    const sc = try m.scorer(arena);
    const c = m.check(&sc);
    try w.print("draft-model.bin against {d} reference drafts: max |diff| {e}\n", .{ c.drafts, c.worst });
    if (!c.ok()) return error.ScorerDisagrees;
    var out: std.ArrayList(u8) = .empty;
    try m.encode(arena, &out);
    try cwd.writeFile(io, .{ .sub_path = try std.fs.path.join(arena, &.{ dir, "draft-model.bin" }), .data = out.items });
    try w.print("wrote {s}/draft-model.bin ({d} KB)\n", .{ dir, out.items.len / 1024 });
}
