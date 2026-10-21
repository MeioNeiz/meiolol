//! League Client champ select JSON into core's draft types.

const std = @import("std");
const core = @import("core");
const Role = core.Role;
const Pick = core.Pick;

pub const paths = struct {
    pub const phase = "/lol-gameflow/v1/gameflow-phase";
    pub const session = "/lol-champ-select/v1/session";
    pub const pickable = "/lol-champ-select/v1/pickable-champion-ids";
    pub const owned = "/lol-champions/v1/owned-champions-minimal";
};

/// What the client shows during champ select, without anyone's identity
pub const ChampSelect = struct {
    /// Null in modes without positions (blind pick, ARAM, customs)
    my_role: ?Role,
    /// My hovered or locked champion, 0 when none
    my_champion: u32,
    my_locked: bool,
    allies: []Pick,
    enemies: []Pick,
    bans: []u32,
    /// Timer phase: PLANNING, BAN_PICK, FINALIZATION, ...
    phase: []const u8,

    pub fn draft(cs: ChampSelect, role: Role, pool: ?[]const u32) core.Draft {
        return .{
            .role = role,
            .allies = cs.allies,
            .enemies = cs.enemies,
            .bans = cs.bans,
            .pool = pool,
        };
    }

    /// Changes whenever anything shown would
    pub fn fingerprint(cs: ChampSelect) u64 {
        var h: std.hash.Wyhash = .init(0);
        h.update(std.mem.asBytes(&roleByte(cs.my_role)));
        h.update(std.mem.asBytes(&cs.my_champion));
        h.update(std.mem.asBytes(&cs.my_locked));
        for ([_][]const Pick{ cs.allies, cs.enemies }) |picks| {
            h.update(std.mem.asBytes(&picks.len));
            for (picks) |p| {
                h.update(std.mem.asBytes(&p.champion));
                h.update(std.mem.asBytes(&roleByte(p.role)));
                h.update(std.mem.asBytes(&p.hover));
            }
        }
        h.update(std.mem.sliceAsBytes(cs.bans));
        h.update(cs.phase);
        return h.final();
    }
};

fn roleByte(role: ?Role) u8 {
    return if (role) |r| @backingInt(r) else 7;
}

const Member = struct {
    cellId: i64 = -1,
    championId: ?i64 = null,
    championPickIntent: ?i64 = null,
    assignedPosition: ?[]const u8 = null,
};

const Action = struct {
    actorCellId: i64 = -1,
    championId: ?i64 = null,
    type: []const u8 = "",
    completed: bool = false,
    isAllyAction: bool = false,
};

const Session = struct {
    localPlayerCellId: i64 = -1,
    myTeam: []const Member = &.{},
    theirTeam: []const Member = &.{},
    actions: []const []const Action = &.{},
    bans: struct {
        myTeamBans: []const i64 = &.{},
        theirTeamBans: []const i64 = &.{},
    } = .{},
    timer: struct { phase: []const u8 = "" } = .{},
};

const json_opts: std.json.ParseOptions = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

/// Allocates in `arena`
pub fn parse(arena: std.mem.Allocator, json: []const u8) !ChampSelect {
    const s = try std.json.parseFromSliceLeaky(Session, arena, json, json_opts);

    var allies: std.ArrayList(Pick) = .empty;
    var enemies: std.ArrayList(Pick) = .empty;
    var bans: std.ArrayList(u32) = .empty;
    var cs: ChampSelect = .{
        .my_role = null,
        .my_champion = 0,
        .my_locked = false,
        .allies = &.{},
        .enemies = &.{},
        .bans = &.{},
        .phase = s.timer.phase,
    };

    for (s.myTeam) |m| {
        // championId is the lock or the hover during the player's own turn; before
        // that only the pick intent shows
        const champion = id(m.championId) orelse id(m.championPickIntent);
        const locked = champion != null and lockedBy(s.actions, m.cellId);
        const role = Role.fromLcu(m.assignedPosition orelse "");
        if (m.cellId == s.localPlayerCellId) {
            cs.my_role = role;
            cs.my_champion = champion orelse 0;
            cs.my_locked = locked;
            continue;
        }
        const c = champion orelse continue;
        try allies.append(arena, .{ .champion = c, .role = role, .hover = !locked });
    }

    // Enemy champions appear once locked; their positions are usually hidden
    for (s.theirTeam) |m| {
        const c = id(m.championId) orelse continue;
        try enemies.append(arena, .{
            .champion = c,
            .role = Role.fromLcu(m.assignedPosition orelse ""),
        });
    }
    for (s.actions) |turn| for (turn) |a| {
        if (!a.completed or a.isAllyAction or !std.mem.eql(u8, a.type, "pick")) continue;
        const c = id(a.championId) orelse continue;
        if (containsPick(enemies.items, c)) continue;
        try enemies.append(arena, .{ .champion = c });
    };

    for ([_][]const i64{ s.bans.myTeamBans, s.bans.theirTeamBans }) |list| {
        for (list) |b| try addBan(arena, &bans, b);
    }
    for (s.actions) |turn| for (turn) |a| {
        if (!a.completed or !std.mem.eql(u8, a.type, "ban")) continue;
        try addBan(arena, &bans, a.championId);
    };

    cs.allies = allies.items;
    cs.enemies = enemies.items;
    cs.bans = bans.items;
    return cs;
}

fn id(maybe: ?i64) ?u32 {
    const raw = maybe orelse return null;
    return if (raw > 0 and raw <= std.math.maxInt(u32)) @intCast(raw) else null;
}

/// Any completed pick: after a trade the action still holds the champion first locked
fn lockedBy(actions: []const []const Action, cell: i64) bool {
    for (actions) |turn| for (turn) |a| {
        if (a.actorCellId == cell and a.completed and std.mem.eql(u8, a.type, "pick") and
            id(a.championId) != null) return true;
    };
    return false;
}

fn containsPick(picks: []const Pick, champion: u32) bool {
    for (picks) |p| if (p.champion == champion) return true;
    return false;
}

fn addBan(arena: std.mem.Allocator, bans: *std.ArrayList(u32), raw: ?i64) !void {
    const c = id(raw) orelse return;
    if (std.mem.indexOfScalar(u32, bans.items, c) == null) try bans.append(arena, c);
}

/// "ChampSelect", "Lobby", "None", ...
pub fn parsePhase(arena: std.mem.Allocator, json: []const u8) ![]const u8 {
    return std.json.parseFromSliceLeaky([]const u8, arena, json, json_opts);
}

/// /lol-champ-select/v1/pickable-champion-ids
pub fn parseIds(arena: std.mem.Allocator, json: []const u8) ![]u32 {
    const raw = try std.json.parseFromSliceLeaky([]const i64, arena, json, json_opts);
    return toIds(arena, raw);
}

/// /lol-champions/v1/owned-champions-minimal
pub fn parseOwned(arena: std.mem.Allocator, json: []const u8) ![]u32 {
    const Champ = struct { id: i64 = 0 };
    const raw = try std.json.parseFromSliceLeaky([]const Champ, arena, json, json_opts);
    const ids = try arena.alloc(i64, raw.len);
    for (ids, raw) |*d, c| d.* = c.id;
    return toIds(arena, ids);
}

fn toIds(arena: std.mem.Allocator, raw: []const i64) ![]u32 {
    var out: std.ArrayList(u32) = .empty;
    for (raw) |r| if (id(r)) |c| try out.append(arena, c);
    return out.items;
}

/// Champions in both lists; either alone when the other failed to load
pub fn intersectPool(
    arena: std.mem.Allocator,
    pickable: ?[]const u32,
    owned: ?[]const u32,
) !?[]u32 {
    const p = pickable orelse return if (owned) |o| try arena.dupe(u32, o) else null;
    const o = owned orelse return try arena.dupe(u32, p);
    var out: std.ArrayList(u32) = .empty;
    for (p) |c| if (std.mem.indexOfScalar(u32, o, c) != null) try out.append(arena, c);
    return out.items;
}

/// Keys that identify a player or open their chat; blanked in anything printed
const identifying = [_][]const u8{
    "gameName",
    "tagLine",
    "puuid",
    "obfuscatedPuuid",
    "summonerId",
    "obfuscatedSummonerId",
    "accountId",
    "summonerName",
    "displayName",
    "internalName",
    "playerAlias",
    "jwt",
    "multiUserChatId",
    "multiUserChatPassword",
};

/// Pretty-printed JSON with player identities removed (Riot policy: champ select hides
/// other players' names; this tool never shows them). Non-JSON is returned as is.
pub fn redact(arena: std.mem.Allocator, body: []const u8) ![]const u8 {
    var value = std.json.parseFromSliceLeaky(std.json.Value, arena, body, .{}) catch
        return body;
    redactValue(&value);
    return std.json.Stringify.valueAlloc(arena, value, .{ .whitespace = .indent_2 });
}

fn redactValue(v: *std.json.Value) void {
    switch (v.*) {
        .array => |a| for (a.items) |*item| redactValue(item),
        .object => |*o| {
            var it = o.iterator();
            while (it.next()) |entry| {
                for (identifying) |key| {
                    if (!std.mem.eql(u8, entry.key_ptr.*, key)) continue;
                    entry.value_ptr.* = switch (entry.value_ptr.*) {
                        .integer, .float, .number_string => .{ .integer = 0 },
                        else => .{ .string = "" },
                    };
                    break;
                } else redactValue(entry.value_ptr);
            }
        },
        else => {},
    }
}

const testing = std.testing;

fn readFixture(arena: std.mem.Allocator) ![]u8 {
    // `zig build test` runs from the project root
    return std.Io.Dir.cwd().readFileAlloc(
        testing.io,
        "testdata/lcu/session-synthetic.json",
        arena,
        .limited(1 << 20),
    );
}

test "synthetic session" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cs = try parse(arena, try readFixture(arena));

    try testing.expectEqual(Role.middle, cs.my_role.?);
    try testing.expectEqual(238, cs.my_champion);
    try testing.expect(!cs.my_locked);
    try testing.expectEqualStrings("BAN_PICK", cs.phase);

    // Darius locked top, Vi hovered in the jungle during her turn, Jinx intent bot
    try testing.expectEqual(3, cs.allies.len);
    const darius: Pick = .{ .champion = 122, .role = .top, .hover = false };
    const vi: Pick = .{ .champion = 254, .role = .jungle, .hover = true };
    const jinx: Pick = .{ .champion = 222, .role = .bottom, .hover = true };
    try testing.expectEqual(darius, cs.allies[0]);
    try testing.expectEqual(vi, cs.allies[1]);
    try testing.expectEqual(jinx, cs.allies[2]);

    try testing.expectEqual(2, cs.enemies.len);
    try testing.expectEqual(Pick{ .champion = 103 }, cs.enemies[0]);
    try testing.expectEqual(Pick{ .champion = 64 }, cs.enemies[1]);

    try testing.expectEqualSlices(
        u32,
        &.{ 157, 555, 875, 84, 360, 221, 147, 950, 233 },
        cs.bans,
    );

    const d = cs.draft(.middle, null);
    try testing.expectEqual(3, d.allies.len);

    var other = cs;
    try testing.expectEqual(cs.fingerprint(), other.fingerprint());
    other.my_champion = 7;
    try testing.expect(cs.fingerprint() != other.fingerprint());
}

test "redact removes identities" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const fixture = try readFixture(arena);
    try testing.expect(std.mem.indexOf(u8, fixture, "SyntheticLocal") != null);
    const out = try redact(arena, fixture);
    const gone = [_][]const u8{
        "SyntheticLocal",
        "synthetic-obfuscated",
        "synthetic-chat-password",
        "1234567",
        "synthetic.jwt",
    };
    for (gone) |needle| {
        try testing.expect(std.mem.indexOf(u8, out, needle) == null);
    }
    // Still a session
    const cs = try parse(arena, out);
    try testing.expectEqual(3, cs.allies.len);
    try testing.expectEqualStrings("plain", try redact(arena, "plain"));
}

test "phase, ids, owned, pool" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const phase = try parsePhase(arena, "\"ChampSelect\"");
    try testing.expectEqualStrings("ChampSelect", phase);
    const pickable = try parseIds(arena, "[1, 22, 103, 0, -1]");
    try testing.expectEqualSlices(u32, &.{ 1, 22, 103 }, pickable);
    const owned = try parseOwned(arena,
        \\[{"id": 103, "name": "Ahri", "alias": "Ahri", "ownership": {"owned": true}},
        \\ {"id": 1, "name": "Annie", "freeToPlay": true}]
    );
    try testing.expectEqualSlices(u32, &.{ 103, 1 }, owned);
    const both = (try intersectPool(arena, pickable, owned)).?;
    try testing.expectEqualSlices(u32, &.{ 1, 103 }, both);
    const owned_only = (try intersectPool(arena, null, owned)).?;
    try testing.expectEqualSlices(u32, &.{ 103, 1 }, owned_only);
    try testing.expectEqual(@as(?[]u32, null), try intersectPool(arena, null, null));
    const not_ids = parseIds(arena, "{\"message\": \"x\"}");
    try testing.expectError(error.UnexpectedToken, not_ids);
}

fn fuzzSession(fixture: []const u8, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const cs = parse(arena, try core.fuzz.mutate(s, arena, fixture)) catch return;
    _ = cs.fingerprint();
    _ = cs.draft(s.value(Role), null);
}

test "fuzz: a damaged session parses or fails, never crashes" {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    try testing.fuzz(@as([]const u8, try readFixture(arena_state.allocator())), fuzzSession, .{});
}
