//! The recommender for the website's draft helper, built for wasm32-freestanding.
//! JS: `alloc` space, copy the model file in, `load` it; then per draft, copy a JSON
//! request in and call `suggest`, which returns a pointer to JSON (length from
//! `result_len`). Request and reply shapes: Request below and `run`.

const std = @import("std");
const core = @import("core");

const gpa = std.heap.wasm_allocator;

var stats: ?core.Stats = null;
/// What `stats` borrows from
var model: []const u8 = &.{};
var result: []u8 = &.{};

export fn alloc(len: usize) ?[*]u8 {
    const buf = gpa.alloc(u8, len) catch return null;
    return buf.ptr;
}

export fn free(ptr: [*]u8, len: usize) void {
    gpa.free(ptr[0..len]);
}

/// Takes ownership of the bytes, which must come from `alloc`. 0 on success
export fn load(ptr: [*]const u8, len: usize) i32 {
    if (stats) |*s| s.deinit(gpa);
    stats = null;
    gpa.free(model);
    model = ptr[0..len];
    stats = core.Stats.parse(gpa, model) catch return 1;
    return 0;
}

export fn result_len() usize {
    return result.len;
}

/// Null when the request is malformed or no model is loaded
export fn suggest(ptr: [*]const u8, len: usize) ?[*]const u8 {
    gpa.free(result);
    result = &.{};
    const s = &(stats orelse return null);
    result = run(s, ptr[0..len]) catch return null;
    return result.ptr;
}

const Pick = struct { id: u32, role: ?[]const u8 = null, hover: bool = false };

const Request = struct {
    role: []const u8,
    allies: []const Pick = &.{},
    enemies: []const Pick = &.{},
    bans: []const u32 = &.{},
    top: u8 = 5,
    min_games: u32 = 200,
};

fn run(s: *const core.Stats, json: []const u8) ![]u8 {
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const req = try std.json.parseFromSliceLeaky(Request, arena, json, .{});
    const role = core.Role.fromLcu(req.role) orelse return error.BadRole;

    var out: [16]core.Suggestion = undefined;
    const list = core.recommend(s, .{
        .role = role,
        .allies = try picks(arena, req.allies),
        .enemies = try picks(arena, req.enemies),
        .bans = req.bans,
    }, .{ .min_games = req.min_games }, out[0..@min(req.top, out.len)]);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    const w = &aw.writer;
    try w.writeByte('[');
    for (list, 0..) |sug, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{{\"id\":{d},\"win\":{d:.4},\"pp\":{d:.2},\"games\":{d},\"reasons\":[", .{
            sug.champion, sug.win, sug.pp, sug.games,
        });
        for (sug.reasons(), 0..) |r, j| {
            if (j > 0) try w.writeByte(',');
            try w.print(
                "{{\"kind\":\"{t}\",\"id\":{d},\"role\":\"{t}\",\"guessed\":{},\"hover\":{},\"pp\":{d:.2},\"games\":{d}}}",
                .{ r.kind, r.champion, r.role, r.role_guessed, r.hover, r.pp, r.games },
            );
        }
        try w.writeAll("]}");
    }
    try w.writeByte(']');
    return aw.toOwnedSlice();
}

fn picks(arena: std.mem.Allocator, in: []const Pick) ![]core.Pick {
    const out = try arena.alloc(core.Pick, in.len);
    for (in, out) |p, *o| o.* = .{
        .champion = p.id,
        .role = if (p.role) |r| core.Role.fromLcu(r) else null,
        .hover = p.hover,
    };
    return out;
}
