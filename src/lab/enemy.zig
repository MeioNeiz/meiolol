//! fm.zig's example sets on the shared split, for bench: champion-role ids and the base,
//! additive, lane and pairwise models' rows. The 12 Oct experiment that fitted them
//! (docs/model.md "Champion embeddings against the enemy team") is in git history

const std = @import("std");
const fm = @import("fm.zig");
const rows = @import("rows.zig");

/// Champion-roles with fewer train rows share their role's "other" id
const min_rows = 30;

pub const Ids = struct {
    map: std.AutoHashMapUnmanaged(u64, u16) = .empty,
    n: u16 = 5,

    fn key(champion: u32, role: u3) u64 {
        return (@as(u64, champion) << 3) | role;
    }

    fn get(ids: *const Ids, champion: u32, role: u3) u16 {
        return ids.map.get(key(champion, role)) orelse role;
    }
};

pub fn buildIds(gpa: std.mem.Allocator, d: *const rows.Data) !Ids {
    var counts: std.AutoHashMapUnmanaged(u64, u32) = .empty;
    defer counts.deinit(gpa);
    for (d.rows) |r| {
        if (d.games[r.game].is_test) continue;
        const e = try counts.getOrPutValue(gpa, Ids.key(r.champion, @backingInt(r.role)), 0);
        e.value_ptr.* += 1;
    }
    var ids: Ids = .{};
    var it = counts.iterator();
    while (it.next()) |e| if (e.value_ptr.* >= min_rows) {
        try ids.map.put(gpa, e.key_ptr.*, ids.n);
        ids.n += 1;
    };
    return ids;
}

pub const Set = struct {
    ex: std.ArrayList(fm.Example) = .empty,
    /// Row index of each example, for game clustering and the preds file
    row: std.ArrayList(u32) = .empty,

    fn deinit(s: *Set, gpa: std.mem.Allocator) void {
        s.ex.deinit(gpa);
        s.row.deinit(gpa);
    }
};

pub const Sets = struct {
    inner: Set = .{},
    val: Set = .{},
    train: Set = .{},
    tests: Set = .{},

    pub fn deinit(s: *Sets, gpa: std.mem.Allocator) void {
        inline for (.{ &s.inner, &s.val, &s.train, &s.tests }) |set| set.deinit(gpa);
    }
};

pub fn buildSets(gpa: std.mem.Allocator, d: *const rows.Data, ids: *const Ids, k: rows.Outcome, mean: *f64, sd: *f64) !Sets {
    // Games are in start order, train first; the newest 20% of train games validate
    var n_train: usize = 0;
    for (d.games) |g| n_train += @intFromBool(!g.is_test);
    const val_from = n_train * 4 / 5;

    // Members of each game by side, to read enemies and allies
    var members: std.AutoHashMapUnmanaged(u32, [2][5]u32) = .empty;
    defer members.deinit(gpa);
    for (d.rows, 0..) |r, i| {
        const e = try members.getOrPut(gpa, r.game);
        if (!e.found_existing) e.value_ptr.* = @splat(@splat(std.math.maxInt(u32)));
        e.value_ptr[r.side][@backingInt(r.role)] = @intCast(i);
    }

    var sum: f64 = 0;
    var sq: f64 = 0;
    var n: f64 = 0;
    for (d.rows) |r| {
        const y = r.y[@backingInt(k)];
        if (std.math.isNan(y) or r.game >= val_from) continue;
        sum += y;
        sq += y * y;
        n += 1;
    }
    mean.* = sum / n;
    sd.* = @sqrt(@max(sq / n - mean.* * mean.*, 1e-12));

    var s: Sets = .{};
    for (d.rows, 0..) |r, i| {
        const y = r.y[@backingInt(k)];
        if (std.math.isNan(y)) continue;
        const m = members.get(r.game).?;
        var e: fm.Example = .{
            .me = ids.get(r.champion, @backingInt(r.role)),
            .role = @backingInt(r.role),
            .platform = d.games[r.game].platform,
            .enemies = undefined,
            .enemy_roles = undefined,
            .allies = undefined,
            .ally_roles = undefined,
            .y = @floatCast((y - mean.*) / sd.*),
        };
        var complete = true;
        for (m[1 - r.side], 0..) |ri, role| {
            if (ri == std.math.maxInt(u32)) complete = false else {
                e.enemies[role] = ids.get(d.rows[ri].champion, @intCast(role));
                e.enemy_roles[role] = @intCast(role);
            }
        }
        var a: usize = 0;
        for (m[r.side], 0..) |ri, role| {
            if (role == @backingInt(r.role)) continue;
            if (ri == std.math.maxInt(u32)) complete = false else {
                e.allies[a] = ids.get(d.rows[ri].champion, @intCast(role));
                e.ally_roles[a] = @intCast(role);
            }
            a += 1;
        }
        if (!complete) continue;
        const g = d.games[r.game];
        const targets: []const *Set = if (g.is_test) &.{&s.tests} else if (r.game >= val_from)
            &.{ &s.val, &s.train }
        else
            &.{ &s.inner, &s.train };
        for (targets) |t| {
            try t.ex.append(gpa, e);
            try t.row.append(gpa, @intCast(i));
        }
    }
    return s;
}
