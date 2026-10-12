//! Starting candidate: champion-role mean per outcome, the win rate pulled toward the
//! role's by 1000 rows. Scores level with the harness's baseline; a campaign copies this
//! directory and changes it (docs/lab-brief.md)

const std = @import("std");
const api = @import("api");

pub const scope: api.Scope = .champ_select;

const win_prior = 1000;

const Cell = struct {
    n: [api.outcome_count]f64 = @splat(0),
    sum: [api.outcome_count]f64 = @splat(0),

    fn add(c: *Cell, y: [api.outcome_count]f32) void {
        for (y, 0..) |v, k| if (!std.math.isNan(v)) {
            c.n[k] += 1;
            c.sum[k] += v;
        };
    }
};

pub const Model = struct {
    cells: std.AutoHashMapUnmanaged(u64, Cell) = .empty,
    roles: [5]Cell = @splat(.{}),
};

fn key(champion: u32, role: api.Role) u64 {
    return (@as(u64, champion) << 3) | @backingInt(role);
}

pub fn fit(gpa: std.mem.Allocator, train: *const api.Train, _: api.Options) !Model {
    var m: Model = .{};
    errdefer m.cells.deinit(gpa);
    for (train.rows) |r| {
        const e = try m.cells.getOrPut(gpa, key(r.champion, r.role));
        if (!e.found_existing) e.value_ptr.* = .{};
        e.value_ptr.add(r.y);
        m.roles[@backingInt(r.role)].add(r.y);
    }
    return m;
}

pub fn predict(m: *const Model, q: *const api.Query) api.Prediction {
    const rc = m.roles[@backingInt(q.role)];
    const cell = m.cells.get(key(q.champion, q.role)) orelse Cell{};
    var out: api.Prediction = undefined;
    for (&out, 0..) |*o, k| {
        if (rc.n[k] == 0) {
            o.* = std.math.nan(f32);
            continue;
        }
        const role_mean = rc.sum[k] / rc.n[k];
        const prior: f64 = if (k == api.outcomeIndex(.win)) win_prior else 0;
        o.* = @floatCast(if (cell.n[k] + prior > 0)
            (cell.sum[k] + prior * role_mean) / (cell.n[k] + prior)
        else
            role_mean);
    }
    return out;
}

pub fn deinit(m: *Model, gpa: std.mem.Allocator) void {
    m.cells.deinit(gpa);
}
