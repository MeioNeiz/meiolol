//! Model file: champion, synergy and matchup counts for one patch (or patch range).
//!
//! Format v1, little-endian:
//!   magic "MEIOSTAT", version u32, n_champs u32, games u32, patch [16]u8 zero padded
//!   champ ids u32[n]; names n x (u8 len, utf-8 bytes)
//!   champ_role [5][n] Counts
//!   ally [5][5][n][n] Counts: c1 in r1 with c2 in r2 on the same team; wins = c1's team
//!     won. Both orderings stored; r1 == r2 is unused (zero)
//!   enemy [5][5][n][n] Counts: c1 in r1 against c2 in r2; wins = c1's side won.
//!     Includes r1 == r2, the lane opponents
//! Roles in core.Role order. Counts is (games u32, wins u32).
//!
//! Version 2 adds a fitted draft model after the counts (Builder.fitted; the backend's
//! fitted.zig, additive v2): f16 logits, strength [5][n], then ally [5][5][n][n] and enemy
//! [5][5][n][n] laid out as the counts. Ally both orderings; enemy from c1's side, both
//! orderings, so a pair's term is one read. f16 (error ~1e-4 logit) halves what the
//! draft helper downloads. Files without one stay version 1

const std = @import("std");
const Role = @import("roles.zig").Role;

pub const magic = "MEIOSTAT";
pub const version: u32 = 1;
pub const version_fitted: u32 = 2;
pub const patch_len = 16;
const header_len = magic.len + 4 + 4 + 4 + patch_len;
const n_roles = Role.count;
const counts_len = @sizeOf(Counts);
/// Far above the ~170 champions; bounds allocations from a corrupt header
const max_champs = 1024;

pub const Champion = struct { id: u32, name: []const u8 };
pub const Counts = extern struct { games: u32, wins: u32 };

pub const Builder = struct {
    gpa: std.mem.Allocator,
    ids: []u32,
    names: [][]u8,
    index: std.AutoHashMapUnmanaged(u32, u32),
    games: u32,
    champ_role: []Counts,
    ally: []Counts,
    enemy: []Counts,
    /// Written as version 2 when set: fittedLen(n) logits (see the format above), owned
    fitted: ?[]f32 = null,

    pub fn init(gpa: std.mem.Allocator, champions: []const Champion) !Builder {
        if (champions.len > max_champs) return error.TooManyChampions;
        const n = champions.len;
        var b: Builder = .{
            .gpa = gpa,
            .ids = try gpa.alloc(u32, n),
            .names = try gpa.alloc([]u8, n),
            .index = .empty,
            .games = 0,
            .champ_role = &.{},
            .ally = &.{},
            .enemy = &.{},
        };
        @memset(b.names, &.{});
        errdefer b.deinit();
        try b.index.ensureTotalCapacity(gpa, @intCast(n));
        for (champions, 0..) |c, i| {
            if (c.name.len > 255) return error.NameTooLong;
            const gop = b.index.getOrPutAssumeCapacity(c.id);
            if (gop.found_existing) return error.DuplicateChampion;
            gop.value_ptr.* = @intCast(i);
            b.ids[i] = c.id;
            b.names[i] = try gpa.dupe(u8, c.name);
        }
        b.champ_role = try zeroed(gpa, n_roles * n);
        b.ally = try zeroed(gpa, n_roles * n_roles * n * n);
        b.enemy = try zeroed(gpa, n_roles * n_roles * n * n);
        return b;
    }

    fn zeroed(gpa: std.mem.Allocator, len: usize) ![]Counts {
        const s = try gpa.alloc(Counts, len);
        @memset(s, .{ .games = 0, .wins = 0 });
        return s;
    }

    pub fn deinit(b: *Builder) void {
        for (b.names) |name| b.gpa.free(name);
        b.gpa.free(b.names);
        b.gpa.free(b.ids);
        b.index.deinit(b.gpa);
        b.gpa.free(b.champ_role);
        b.gpa.free(b.ally);
        b.gpa.free(b.enemy);
        if (b.fitted) |f| b.gpa.free(f);
        b.* = undefined;
    }

    /// teams[side][@intFromEnum(role)] = champion id; `winner` is the winning side index.
    /// Unknown champion ids are skipped (do not crash).
    pub fn addGame(b: *Builder, teams: [2][5]u32, winner: u1) void {
        const n = b.ids.len;
        var idx: [2][5]?u32 = undefined;
        for (teams, 0..) |team, s| {
            for (team, 0..) |id, r| idx[s][r] = b.index.get(id);
        }
        b.games += 1;
        for (0..2) |s| {
            const won: u32 = @intFromBool(s == winner);
            for (0..n_roles) |r1| {
                const c1 = idx[s][r1] orelse continue;
                bump(&b.champ_role[r1 * n + c1], won);
                for (0..n_roles) |r2| {
                    if (r2 != r1) if (idx[s][r2]) |c2| {
                        bump(&b.ally[pairIndex(n, r1, r2, c1, c2)], won);
                    };
                    if (idx[1 - s][r2]) |c2| {
                        bump(&b.enemy[pairIndex(n, r1, r2, c1, c2)], won);
                    }
                }
            }
        }
    }

    fn bump(c: *Counts, won: u32) void {
        c.games += 1;
        c.wins += won;
    }

    pub fn write(b: *const Builder, w: *std.Io.Writer, patch: []const u8) !void {
        if (patch.len > patch_len) return error.PatchTooLong;
        try w.writeAll(magic);
        try w.writeInt(u32, if (b.fitted != null) version_fitted else version, .little);
        try w.writeInt(u32, @intCast(b.ids.len), .little);
        try w.writeInt(u32, b.games, .little);
        try w.writeAll(patch);
        try w.splatByteAll(0, patch_len - patch.len);
        try w.writeSliceEndian(u32, b.ids, .little);
        for (b.names) |name| {
            try w.writeByte(@intCast(name.len));
            try w.writeAll(name);
        }
        try w.writeSliceEndian(Counts, b.champ_role, .little);
        try w.writeSliceEndian(Counts, b.ally, .little);
        try w.writeSliceEndian(Counts, b.enemy, .little);
        if (b.fitted) |f| {
            if (f.len != fittedLen(b.ids.len)) return error.FittedSize;
            for (f) |x| try w.writeInt(u16, @bitCast(@as(f16, @floatCast(x))), .little);
        }
    }
};

/// Logits in a fitted section for n champions
pub fn fittedLen(n: usize) usize {
    return n_roles * n + 2 * n_roles * n_roles * n * n;
}

/// Where a fitted section's ally and enemy blocks start, in logits
pub fn fittedAllyAt(n: usize) usize {
    return n_roles * n;
}

pub fn fittedEnemyAt(n: usize) usize {
    return n_roles * n + n_roles * n_roles * n * n;
}

pub fn fittedPair(n: usize, r1: usize, r2: usize, c1: usize, c2: usize) usize {
    return pairIndex(n, r1, r2, c1, c2);
}

fn pairIndex(n: usize, r1: usize, r2: usize, c1: usize, c2: usize) usize {
    return ((r1 * n_roles + r2) * n + c1) * n + c2;
}

/// A parsed model file. Borrows the bytes it was parsed from.
pub const Stats = struct {
    n: usize,
    games: u32,
    /// Without the zero padding
    patch: []const u8,
    ids: []u32,
    names: [][]const u8,
    champ_role_bytes: []const u8,
    ally_bytes: []const u8,
    enemy_bytes: []const u8,
    /// Version 2's fitted section, fittedLen(n) little-endian f16
    fitted_bytes: ?[]const u8 = null,

    pub const ParseError = error{
        BadMagic,
        UnsupportedVersion,
        TooManyChampions,
        Truncated,
        SizeMismatch,
        OutOfMemory,
    };

    pub fn parse(gpa: std.mem.Allocator, bytes: []const u8) ParseError!Stats {
        if (bytes.len < header_len) return error.Truncated;
        if (!std.mem.eql(u8, bytes[0..magic.len], magic)) return error.BadMagic;
        var pos: usize = magic.len;
        const v = readU32(bytes, &pos);
        if (v != version and v != version_fitted) return error.UnsupportedVersion;
        const n: usize = readU32(bytes, &pos);
        if (n > max_champs) return error.TooManyChampions;
        const games = readU32(bytes, &pos);
        const patch_field = bytes[pos..][0..patch_len];
        pos += patch_len;
        const patch_end = std.mem.findScalar(u8, patch_field, 0) orelse patch_len;
        const patch = patch_field[0..patch_end];

        if (bytes.len - pos < 4 * n) return error.Truncated;
        const ids = try gpa.alloc(u32, n);
        errdefer gpa.free(ids);
        for (ids) |*id| id.* = readU32(bytes, &pos);

        const names = try gpa.alloc([]const u8, n);
        errdefer gpa.free(names);
        for (names) |*slot| {
            if (pos >= bytes.len) return error.Truncated;
            const len = bytes[pos];
            pos += 1;
            if (bytes.len - pos < len) return error.Truncated;
            slot.* = bytes[pos..][0..len];
            pos += len;
        }

        const role_len = n_roles * n * counts_len;
        const pair_len = n_roles * n_roles * n * n * counts_len;
        const fitted_len = if (v == version_fitted) 2 * fittedLen(n) else 0;
        const want = role_len + 2 * pair_len + fitted_len;
        if (bytes.len - pos < want) return error.Truncated;
        if (bytes.len - pos > want) return error.SizeMismatch;
        return .{
            .n = n,
            .games = games,
            .patch = patch,
            .ids = ids,
            .names = names,
            .champ_role_bytes = bytes[pos..][0..role_len],
            .ally_bytes = bytes[pos + role_len ..][0..pair_len],
            .enemy_bytes = bytes[pos + role_len + pair_len ..][0..pair_len],
            .fitted_bytes = if (fitted_len > 0) bytes[pos + role_len + 2 * pair_len ..][0..fitted_len] else null,
        };
    }

    pub fn deinit(s: *Stats, gpa: std.mem.Allocator) void {
        gpa.free(s.ids);
        gpa.free(s.names);
        s.* = undefined;
    }

    /// Champion index (0..n) for a Riot champion id
    pub fn index(s: *const Stats, id: u32) ?usize {
        return std.mem.findScalar(u32, s.ids, id);
    }

    pub fn name(s: *const Stats, i: usize) []const u8 {
        return s.names[i];
    }

    /// Display name for a champion id, or "?" when the file does not know it
    pub fn nameOf(s: *const Stats, id: u32) []const u8 {
        return if (s.index(id)) |i| s.names[i] else "?";
    }

    pub fn champRole(s: *const Stats, r: Role, c: usize) Counts {
        return readCounts(s.champ_role_bytes, @as(usize, @backingInt(r)) * s.n + c);
    }

    /// Total games for a champion over all roles
    pub fn champGames(s: *const Stats, c: usize) u64 {
        var total: u64 = 0;
        for (Role.all) |r| total += s.champRole(r, c).games;
        return total;
    }

    /// c1 in r1 and c2 in r2 on the same team; wins = their team won
    pub fn ally(s: *const Stats, r1: Role, r2: Role, c1: usize, c2: usize) Counts {
        return readCounts(s.ally_bytes, s.pair(r1, r2, c1, c2));
    }

    /// c1 in r1 against c2 in r2; wins = c1's side won
    pub fn enemy(s: *const Stats, r1: Role, r2: Role, c1: usize, c2: usize) Counts {
        return readCounts(s.enemy_bytes, s.pair(r1, r2, c1, c2));
    }

    /// The fitted model's strength of c in r (logit); null without a fitted section
    pub fn fittedBase(s: *const Stats, r: Role, c: usize) ?f32 {
        const f = s.fitted_bytes orelse return null;
        return readF16(f, @as(usize, @backingInt(r)) * s.n + c);
    }

    /// The fitted model's term for allies c1 in r1 and c2 in r2
    pub fn fittedAlly(s: *const Stats, r1: Role, r2: Role, c1: usize, c2: usize) ?f32 {
        const f = s.fitted_bytes orelse return null;
        return readF16(f, fittedAllyAt(s.n) + s.pair(r1, r2, c1, c2));
    }

    /// The fitted model's term for c1 in r1 against c2 in r2, on c1's team's logit
    pub fn fittedEnemy(s: *const Stats, r1: Role, r2: Role, c1: usize, c2: usize) ?f32 {
        const f = s.fitted_bytes orelse return null;
        return readF16(f, fittedEnemyAt(s.n) + s.pair(r1, r2, c1, c2));
    }

    fn pair(s: *const Stats, r1: Role, r2: Role, c1: usize, c2: usize) usize {
        return pairIndex(s.n, @backingInt(r1), @backingInt(r2), c1, c2);
    }

    /// Champion index by name, forgiving case, spaces and punctuation ("kaisa",
    /// "lee sin", "leesin", "wukong"). Falls back to a unique prefix, then a unique
    /// substring ("nunu", "mundo"). Null when unknown or ambiguous.
    pub fn find(s: *const Stats, query: []const u8) ?usize {
        var qbuf: [64]u8 = undefined;
        const q = normalise(&qbuf, query);
        if (q.len == 0) return null;
        var alt_buf: [64]u8 = undefined;
        const alt: ?[]const u8 = for (aliases) |a| {
            if (std.mem.eql(u8, q, a[0])) break normalise(&alt_buf, a[1]);
        } else null;

        var prefix: ?usize = null;
        var prefix_count: usize = 0;
        var sub: ?usize = null;
        var sub_count: usize = 0;
        for (s.names, 0..) |full, i| {
            var nbuf: [256]u8 = undefined;
            const n = normalise(&nbuf, full);
            if (std.mem.eql(u8, n, q)) return i;
            if (alt) |a| if (std.mem.eql(u8, n, a)) return i;
            if (std.mem.startsWith(u8, n, q)) {
                prefix = i;
                prefix_count += 1;
            } else if (std.mem.find(u8, n, q) != null) {
                sub = i;
                sub_count += 1;
            }
        }
        if (prefix_count == 1) return prefix;
        if (prefix_count == 0 and sub_count == 1) return sub;
        return null;
    }
};

/// Nicknames to a champion's display name (or its Data Dragon id where they differ)
const aliases = [_]struct { []const u8, []const u8 }{
    .{ "monkeyking", "wukong" },
    .{ "wukong", "monkeyking" },
    .{ "mf", "missfortune" },
    .{ "tf", "twistedfate" },
    .{ "asol", "aurelionsol" },
    .{ "j4", "jarvaniv" },
    .{ "jarvan", "jarvaniv" },
    .{ "kog", "kogmaw" },
    .{ "cass", "cassiopeia" },
    .{ "heimer", "heimerdinger" },
    .{ "ww", "warwick" },
    .{ "xin", "xinzhao" },
    .{ "nunu", "nunuwillump" },
};

/// Lower-case ASCII letters and digits; other ASCII dropped, non-ASCII bytes kept
fn normalise(buf: []u8, s: []const u8) []const u8 {
    var len: usize = 0;
    for (s) |ch| {
        if (len == buf.len) break;
        if (ch < 0x80 and !std.ascii.isAlphanumeric(ch)) continue;
        buf[len] = std.ascii.toLower(ch);
        len += 1;
    }
    return buf[0..len];
}

fn readU32(bytes: []const u8, pos: *usize) u32 {
    defer pos.* += 4;
    return std.mem.readInt(u32, bytes[pos.*..][0..4], .little);
}

fn readF16(bytes: []const u8, i: usize) f32 {
    const h: f16 = @bitCast(std.mem.readInt(u16, bytes[2 * i ..][0..2], .little));
    return h;
}

fn readCounts(bytes: []const u8, i: usize) Counts {
    const at = bytes[i * counts_len ..][0..counts_len];
    return .{
        .games = std.mem.readInt(u32, at[0..4], .little),
        .wins = std.mem.readInt(u32, at[4..8], .little),
    };
}

const testing = std.testing;

const test_champions = [_]Champion{
    .{ .id = 266, .name = "Aatrox" },
    .{ .id = 145, .name = "Kai'Sa" },
    .{ .id = 64, .name = "Lee Sin" },
    .{ .id = 62, .name = "Wukong" },
    .{ .id = 20, .name = "Nunu & Willump" },
    .{ .id = 36, .name = "Dr. Mundo" },
    .{ .id = 117, .name = "Lulu" },
    .{ .id = 103, .name = "Ahri" },
    .{ .id = 222, .name = "Jinx" },
    .{ .id = 122, .name = "Darius" },
};

fn writeToAlloc(gpa: std.mem.Allocator, b: *const Builder, patch: []const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    try b.write(&aw.writer, patch);
    return aw.toOwnedSlice();
}

test "round trip" {
    const gpa = testing.allocator;
    var b: Builder = try .init(gpa, &test_champions);
    defer b.deinit();
    // Darius Lee Ahri Kai'Sa Lulu beat Aatrox Wukong Nunu Jinx Mundo; 999 is unknown
    b.addGame(.{ .{ 122, 64, 103, 145, 117 }, .{ 266, 62, 20, 222, 36 } }, 0);
    b.addGame(.{ .{ 122, 64, 103, 145, 999 }, .{ 266, 62, 20, 222, 36 } }, 1);

    const bytes = try writeToAlloc(gpa, &b, "16.20");
    defer gpa.free(bytes);
    var s: Stats = try .parse(gpa, bytes);
    defer s.deinit(gpa);

    try testing.expectEqual(10, s.n);
    try testing.expectEqual(2, s.games);
    try testing.expectEqualStrings("16.20", s.patch);
    const darius = s.index(122).?;
    const aatrox = s.index(266).?;
    const lulu = s.index(117).?;
    const lee = s.index(64).?;
    try testing.expectEqualStrings("Darius", s.name(darius));
    const zero: Counts = .{ .games = 0, .wins = 0 };
    const one_one: Counts = .{ .games = 1, .wins = 1 };
    const two_one: Counts = .{ .games = 2, .wins = 1 };
    try testing.expectEqual(two_one, s.champRole(.top, darius));
    try testing.expectEqual(zero, s.champRole(.middle, darius));
    try testing.expectEqual(one_one, s.champRole(.utility, lulu));
    try testing.expectEqual(two_one, s.ally(.top, .jungle, darius, lee));
    try testing.expectEqual(two_one, s.ally(.jungle, .top, lee, darius));
    try testing.expectEqual(one_one, s.ally(.top, .utility, darius, lulu));
    try testing.expectEqual(zero, s.ally(.top, .top, darius, darius));
    try testing.expectEqual(two_one, s.enemy(.top, .top, darius, aatrox));
    try testing.expectEqual(two_one, s.enemy(.top, .top, aatrox, darius));
    const one_zero: Counts = .{ .games = 1, .wins = 0 };
    try testing.expectEqual(one_zero, s.enemy(.top, .utility, aatrox, lulu));
    try testing.expectEqual(2, s.champGames(darius));
}

test "parse rejects bad files" {
    const gpa = testing.allocator;
    var b: Builder = try .init(gpa, test_champions[0..3]);
    defer b.deinit();
    const bytes = try writeToAlloc(gpa, &b, "16.19-16.20");
    defer gpa.free(bytes);

    try testing.expectError(error.Truncated, Stats.parse(gpa, bytes[0 .. bytes.len - 1]));
    try testing.expectError(error.Truncated, Stats.parse(gpa, bytes[0..10]));
    const longer = try std.mem.concat(gpa, u8, &.{ bytes, "x" });
    defer gpa.free(longer);
    try testing.expectError(error.SizeMismatch, Stats.parse(gpa, longer));
    const copy = try gpa.dupe(u8, bytes);
    defer gpa.free(copy);
    copy[0] = 'X';
    try testing.expectError(error.BadMagic, Stats.parse(gpa, copy));
    copy[0] = 'M';
    copy[8] = 3;
    try testing.expectError(error.UnsupportedVersion, Stats.parse(gpa, copy));
    copy[8] = 2;
    try testing.expectError(error.Truncated, Stats.parse(gpa, copy));
    copy[8] = 1;
    var s: Stats = try .parse(gpa, copy);
    defer s.deinit(gpa);
    try testing.expectEqualStrings("16.19-16.20", s.patch);
    var failing: std.Io.Writer = .failing;
    try testing.expectError(error.PatchTooLong, b.write(&failing, "16.19-16.20-16.21"));
}

test "parse rejects every truncation" {
    const gpa = testing.allocator;
    var b: Builder = try .init(gpa, test_champions[0..3]);
    defer b.deinit();
    const bytes = try writeToAlloc(gpa, &b, "16.20");
    defer gpa.free(bytes);
    for (0..bytes.len) |len| {
        try testing.expectError(error.Truncated, Stats.parse(gpa, bytes[0..len]));
    }
}

test "fitted section round trip and truncation" {
    const gpa = testing.allocator;
    var b: Builder = try .init(gpa, test_champions[0..3]);
    defer b.deinit();
    b.addGame(.{ .{ 266, 145, 64, 0, 0 }, .{ 0, 0, 0, 0, 0 } }, 0);
    const f = try gpa.alloc(f32, fittedLen(3));
    for (f, 0..) |*x, i| x.* = @floatFromInt(i);
    b.fitted = f;
    const bytes = try writeToAlloc(gpa, &b, "16.20");
    defer gpa.free(bytes);
    var s: Stats = try .parse(gpa, bytes);
    defer s.deinit(gpa);
    try testing.expectEqual(1, s.champRole(.top, 0).games);
    try testing.expectEqual(@as(f32, 3 + 1), s.fittedBase(.jungle, 1).?);
    try testing.expectEqual(f[fittedAllyAt(3) + pairIndex(3, 0, 2, 1, 2)], s.fittedAlly(.top, .middle, 1, 2).?);
    try testing.expectEqual(f[fittedEnemyAt(3) + pairIndex(3, 4, 1, 2, 0)], s.fittedEnemy(.utility, .jungle, 2, 0).?);
    for (0..bytes.len) |len| {
        try testing.expectError(error.Truncated, Stats.parse(gpa, bytes[0..len]));
    }
    gpa.free(b.fitted.?);
    b.fitted = null;
    const v1 = try writeToAlloc(gpa, &b, "16.20");
    defer gpa.free(v1);
    var s1: Stats = try .parse(gpa, v1);
    defer s1.deinit(gpa);
    try testing.expectEqual(null, s1.fittedBase(.top, 0));
}

test "builder rejects duplicate ids" {
    const dup = [_]Champion{ .{ .id = 1, .name = "A" }, .{ .id = 1, .name = "B" } };
    const result = Builder.init(testing.allocator, &dup);
    try testing.expectError(error.DuplicateChampion, result);
}

test "find by forgiving name" {
    const gpa = testing.allocator;
    var b: Builder = try .init(gpa, &test_champions);
    defer b.deinit();
    const bytes = try writeToAlloc(gpa, &b, "16.20");
    defer gpa.free(bytes);
    var s: Stats = try .parse(gpa, bytes);
    defer s.deinit(gpa);

    const expectName = struct {
        fn f(st: *const Stats, query: []const u8, want: []const u8) !void {
            const i = st.find(query) orelse return error.NotFound;
            try testing.expectEqualStrings(want, st.name(i));
        }
    }.f;
    try expectName(&s, "kaisa", "Kai'Sa");
    try expectName(&s, "KAI'SA", "Kai'Sa");
    try expectName(&s, "lee sin", "Lee Sin");
    try expectName(&s, "leesin", "Lee Sin");
    try expectName(&s, "wukong", "Wukong");
    try expectName(&s, "MonkeyKing", "Wukong");
    try expectName(&s, "nunu", "Nunu & Willump");
    try expectName(&s, "mundo", "Dr. Mundo");
    try expectName(&s, "dr mundo", "Dr. Mundo");
    try expectName(&s, "aat", "Aatrox");
    try testing.expectEqual(@as(?usize, null), s.find("teemo"));
    try testing.expectEqual(@as(?usize, null), s.find(""));
    // "a" prefixes both Aatrox and Ahri
    try testing.expectEqual(@as(?usize, null), s.find("a"));
}
