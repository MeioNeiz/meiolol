//! A mock League client for testing without League: plays a scenario (JSON timeline,
//! testdata/lcu/scenarios) and serves what the client would at each step, the LCU paths
//! the app reads plus the in-game Live Client Data API and the end of game stats.
//! Plain HTTP: the app reaches it only through an override lockfile ending `:http`
//! (lockfile.Credentials.plain). Shapes follow the community LCU schema as
//! session-synthetic.json does; none is checked against a real client yet.
//!
//! Scenario keys: queue (420 ranked solo/duo, 430 blind, 450 ARAM), local_cell (0-4),
//! positions (10 cells, "" hidden), pick_order (cell groups), mastery {name: points},
//! tier, pickable and owned (names; default every champion), steps. A step: wait
//! (seconds before it), note, phase (gameflow), timer (champ select phase), session
//! (false: champ select without a session, as between phases), positions, intent,
//! hover, lock, ban ({cell: name}), swap ([cell, cell]: a trade), game ({time, gold,
//! scores {cell: {k, d, a, cs, level, items (their price)}}, events [Live Client
//! events]}), win, expect
//! (what `zig build test` checks the watch saw, see mock_test in this file).

const std = @import("std");
const httpd = @import("net").server;
const Io = std.Io;
const Value = std.json.Value;

pub const champions_file = "champions.json";

pub const Cell = struct {
    position: []const u8 = "",
    intent: u32 = 0,
    /// Hovered during the cell's turn, or locked
    champion: u32 = 0,
    locked: bool = false,
    /// The champion the pick action completed with: a trade changes `champion` only,
    /// as in the client, where actions keep the history
    locked_with: u32 = 0,
    ban: u32 = 0,
    banned: bool = false,
    kills: i64 = 0,
    deaths: i64 = 0,
    assists: i64 = 0,
    cs: i64 = 0,
    level: i64 = 1,
    /// Price of the items held, served as one made-up item
    items: i64 = 0,
};

pub const Scenario = struct {
    name: []const u8,
    queue: i64,
    local_cell: u8,
    positions: [10][]const u8,
    pick_order: []const []const u8,
    mastery: []const [2]u32,
    tier: []const u8,
    pickable: []const u32,
    owned: []const u32,
    steps: []const Value,
    names: std.StringHashMapUnmanaged(u32),
    ids: std.AutoHashMapUnmanaged(u32, []const u8),

    /// `path` and champions.json beside it; allocates in `arena`. Every step is applied
    /// once to check its names and keys
    pub fn load(arena: std.mem.Allocator, io: Io, path: []const u8) !Scenario {
        const cwd = Io.Dir.cwd();
        const dir = std.fs.path.dirname(path) orelse ".";
        const table_path = try std.fs.path.join(arena, &.{ dir, champions_file });
        const table_bytes = try cwd.readFileAlloc(io, table_path, arena, .limited(1 << 20));
        const bytes = try cwd.readFileAlloc(io, path, arena, .limited(1 << 20));
        return parse(arena, std.fs.path.stem(path), bytes, table_bytes);
    }

    /// load's from the files' bytes (embedded ones: src/site/appreview.zig)
    pub fn parse(arena: std.mem.Allocator, name: []const u8, bytes: []const u8, table_bytes: []const u8) !Scenario {
        const table = try std.json.parseFromSliceLeaky(Value, arena, table_bytes, .{});
        var s: Scenario = .{
            .name = name,
            .queue = 420,
            .local_cell = 2,
            .positions = .{ "top", "jungle", "middle", "bottom", "utility", "", "", "", "", "" },
            .pick_order = &.{ &.{0}, &.{ 5, 6 }, &.{ 1, 2 }, &.{ 7, 8 }, &.{ 3, 4 }, &.{9} },
            .mastery = &.{},
            .tier = "",
            .pickable = &.{},
            .owned = &.{},
            .steps = &.{},
            .names = .empty,
            .ids = .empty,
        };
        var it = table.object.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.* != .integer) continue;
            const id: u32 = @intCast(e.value_ptr.integer);
            try s.names.put(arena, e.key_ptr.*, id);
            try s.ids.put(arena, id, e.key_ptr.*);
        }

        const root = try std.json.parseFromSliceLeaky(Value, arena, bytes, .{});
        const o = root.object;
        if (o.get("queue")) |v| s.queue = v.integer;
        if (o.get("local_cell")) |v| s.local_cell = std.math.cast(u8, v.integer) orelse return error.BadCell;
        if (s.local_cell > 4) return error.BadCell;
        if (o.get("positions")) |v| s.positions = try positions(v);
        if (o.get("pick_order")) |v| {
            const groups = try arena.alloc([]u8, v.array.items.len);
            for (groups, v.array.items) |*g, item| {
                g.* = try arena.alloc(u8, item.array.items.len);
                for (g.*, item.array.items) |*c, cell| c.* = try cellOf(cell);
            }
            s.pick_order = groups;
        }
        if (o.get("mastery")) |v| {
            var rows: std.ArrayList([2]u32) = .empty;
            var m = v.object.iterator();
            while (m.next()) |e| try rows.append(arena, .{ try s.champion(e.key_ptr.*), @intCast(e.value_ptr.integer) });
            s.mastery = rows.items;
        }
        if (o.get("tier")) |v| s.tier = v.string;
        s.pickable = if (o.get("pickable")) |v| try s.championList(arena, v) else try s.allChampions(arena);
        s.owned = if (o.get("owned")) |v| try s.championList(arena, v) else s.pickable;
        s.steps = (o.get("steps") orelse return error.NoSteps).array.items;

        var check: State = .{};
        for (s.steps) |step| try check.apply(&s, step);
        return s;
    }

    pub fn champion(s: *const Scenario, name: []const u8) !u32 {
        return s.names.get(name) orelse {
            std.log.err("mock: no champion \"{s}\" in {s}", .{ name, champions_file });
            return error.UnknownChampion;
        };
    }

    pub fn nameOf(s: *const Scenario, id: u32) []const u8 {
        return s.ids.get(id) orelse "Unknown";
    }

    fn championList(s: *const Scenario, arena: std.mem.Allocator, v: Value) ![]u32 {
        const out = try arena.alloc(u32, v.array.items.len);
        for (out, v.array.items) |*d, n| d.* = try s.champion(n.string);
        return out;
    }

    fn allChampions(s: *const Scenario, arena: std.mem.Allocator) ![]u32 {
        var out: std.ArrayList(u32) = .empty;
        var it = s.ids.keyIterator();
        while (it.next()) |id| try out.append(arena, id.*);
        std.mem.sort(u32, out.items, {}, std.sort.asc(u32));
        return out.items;
    }

    fn mode(s: *const Scenario) struct { game: []const u8, map: i64, queue_type: []const u8 } {
        return switch (s.queue) {
            450 => .{ .game = "ARAM", .map = 12, .queue_type = "ARAM_UNRANKED_5x5" },
            420 => .{ .game = "CLASSIC", .map = 11, .queue_type = "RANKED_SOLO_5x5" },
            440 => .{ .game = "CLASSIC", .map = 11, .queue_type = "RANKED_FLEX_SR" },
            else => .{ .game = "CLASSIC", .map = 11, .queue_type = "NORMAL" },
        };
    }
};

fn positions(v: Value) ![10][]const u8 {
    if (v.array.items.len != 10) return error.BadPositions;
    var out: [10][]const u8 = undefined;
    for (&out, v.array.items) |*d, p| d.* = p.string;
    return out;
}

fn cellOf(v: Value) !u8 {
    const n: i64 = switch (v) {
        .integer => |i| i,
        .string => |str| std.fmt.parseInt(i64, str, 10) catch return error.BadCell,
        else => return error.BadCell,
    };
    return if (n >= 0 and n < 10) @intCast(n) else error.BadCell;
}

pub const Event = struct {
    EventID: i64,
    EventName: []const u8,
    EventTime: f64,
    /// Other keys as the scenario gives them (KillerName, DragonType, ...)
    extra: ?std.json.ObjectMap = null,

    pub fn jsonStringify(e: Event, w: *std.json.Stringify) !void {
        try w.beginObject();
        try w.objectField("EventID");
        try w.write(e.EventID);
        try w.objectField("EventName");
        try w.write(e.EventName);
        try w.objectField("EventTime");
        try w.write(e.EventTime);
        if (e.extra) |m| {
            var it = m.iterator();
            while (it.next()) |kv| {
                const own = [_][]const u8{ "EventID", "EventName", "EventTime" };
                for (own) |k| {
                    if (std.mem.eql(u8, kv.key_ptr.*, k)) break;
                } else {
                    try w.objectField(kv.key_ptr.*);
                    try w.write(kv.value_ptr.*);
                }
            }
        }
        try w.endObject();
    }
};

/// The client at one step. Strings and events borrow from the scenario
pub const State = struct {
    phase: []const u8 = "None",
    timer: []const u8 = "",
    session: bool = true,
    cells: [10]Cell = @splat(.{}),
    /// Session counter, bumped on every change as the client's is
    counter: i64 = 0,
    game_time: f64 = 0,
    gold: f64 = 500,
    events: [64]Event = undefined,
    n_events: usize = 0,
    win: ?bool = null,

    fn reset(st: *State, s: *const Scenario) void {
        st.cells = @splat(.{});
        for (&st.cells, s.positions) |*c, p| c.position = p;
        st.timer = "";
        st.session = true;
        st.game_time = 0;
        st.gold = 500;
        st.n_events = 0;
        st.win = null;
    }

    pub fn apply(st: *State, s: *const Scenario, step: Value) !void {
        const o = step.object;
        st.counter += 1;
        if (o.get("phase")) |v| {
            const was_select = std.mem.eql(u8, st.phase, "ChampSelect");
            const to_select = std.mem.eql(u8, v.string, "ChampSelect");
            // A new champ select, or a dodge back to the lobby, starts clean
            if (to_select != was_select and (to_select or !isGame(v.string))) st.reset(s);
            st.phase = v.string;
        }
        if (o.get("timer")) |v| st.timer = v.string;
        if (o.get("session")) |v| st.session = v.bool;
        if (o.get("positions")) |v| {
            const p = try positions(v);
            for (&st.cells, p) |*c, pos| c.position = pos;
        }
        inline for (.{ "intent", "hover", "lock", "ban" }) |key| {
            if (o.get(key)) |v| {
                var it = v.object.iterator();
                while (it.next()) |e| {
                    const c = &st.cells[try cellOf(.{ .string = e.key_ptr.* })];
                    const id = try s.champion(e.value_ptr.string);
                    if (comptime std.mem.eql(u8, key, "intent")) c.intent = id;
                    if (comptime std.mem.eql(u8, key, "hover")) {
                        c.champion = id;
                        c.locked = false;
                    }
                    if (comptime std.mem.eql(u8, key, "lock")) {
                        c.champion = id;
                        c.locked = true;
                        c.locked_with = id;
                    }
                    if (comptime std.mem.eql(u8, key, "ban")) {
                        c.ban = id;
                        c.banned = true;
                    }
                }
            }
        }
        if (o.get("swap")) |v| {
            const a = try cellOf(v.array.items[0]);
            const b = try cellOf(v.array.items[1]);
            std.mem.swap(u32, &st.cells[a].champion, &st.cells[b].champion);
        }
        if (o.get("game")) |g| try st.applyGame(g.object);
        if (o.get("win")) |v| st.win = v.bool;
    }

    fn applyGame(st: *State, g: std.json.ObjectMap) !void {
        if (g.get("time")) |v| st.game_time = number(v);
        if (g.get("gold")) |v| st.gold = number(v);
        if (g.get("scores")) |v| {
            var it = v.object.iterator();
            while (it.next()) |e| {
                const c = &st.cells[try cellOf(.{ .string = e.key_ptr.* })];
                const sc = e.value_ptr.object;
                if (sc.get("k")) |x| c.kills = x.integer;
                if (sc.get("d")) |x| c.deaths = x.integer;
                if (sc.get("a")) |x| c.assists = x.integer;
                if (sc.get("cs")) |x| c.cs = x.integer;
                if (sc.get("level")) |x| c.level = x.integer;
                if (sc.get("items")) |x| c.items = x.integer;
            }
        }
        if (g.get("events")) |v| for (v.array.items) |ev| {
            if (st.n_events == st.events.len) return error.TooManyEvents;
            const eo = ev.object;
            st.events[st.n_events] = .{
                .EventID = @intCast(st.n_events),
                .EventName = (eo.get("EventName") orelse return error.EventName).string,
                .EventTime = if (eo.get("EventTime")) |t| number(t) else st.game_time,
                .extra = eo,
            };
            st.n_events += 1;
        };
    }
};

fn number(v: Value) f64 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        else => 0,
    };
}

fn isGame(phase: []const u8) bool {
    const game = [_][]const u8{ "GameStart", "InProgress", "WaitingForStats", "PreEndOfGame", "EndOfGame", "Reconnect" };
    for (game) |p| if (std.mem.eql(u8, phase, p)) return true;
    return false;
}

pub const Reply = struct { status: std.http.Status = .ok, body: []const u8 };

const not_found: Reply = .{
    .status = .not_found,
    .body = "{\"errorCode\":\"RPC_ERROR\",\"httpStatus\":404,\"message\":\"mock: not here now\"}",
};

const local_name = "MockPlayer";
const local_tag = "MOCK";

/// The LCU reply for `path` (query ignored) in state `st`, allocated in `a`
pub fn lcu(a: std.mem.Allocator, s: *const Scenario, st: *const State, target: []const u8) !Reply {
    const path = target[0 .. std.mem.findScalar(u8, target, '?') orelse target.len];
    const eql = std.mem.eql;
    if (eql(u8, path, "/lol-gameflow/v1/gameflow-phase")) return json(a, st.phase);
    if (eql(u8, path, "/lol-gameflow/v1/session")) {
        const m = s.mode();
        return json(a, .{
            .phase = st.phase,
            .map = .{ .id = m.map },
            .gameData = .{ .queue = .{ .id = s.queue, .gameMode = m.game, .type = m.queue_type, .isRanked = s.queue == 420 or s.queue == 440 } },
        });
    }
    if (eql(u8, path, "/lol-summoner/v1/current-summoner")) {
        return json(a, .{ .gameName = local_name, .tagLine = local_tag, .puuid = "mock-puuid", .summonerId = 1, .summonerLevel = 100 });
    }
    if (eql(u8, path, "/lol-champ-select/v1/session")) {
        if (!eql(u8, st.phase, "ChampSelect") or !st.session) return not_found;
        return json(a, try session(a, s, st));
    }
    if (eql(u8, path, "/lol-champ-select/v1/pickable-champion-ids")) {
        if (!eql(u8, st.phase, "ChampSelect")) return not_found;
        return json(a, s.pickable);
    }
    if (eql(u8, path, "/lol-champions/v1/owned-champions-minimal")) {
        const Owned = struct { id: u32, name: []const u8, alias: []const u8, freeToPlay: bool = false };
        const out = try a.alloc(Owned, s.owned.len);
        for (out, s.owned) |*o, id| o.* = .{ .id = id, .name = s.nameOf(id), .alias = s.nameOf(id) };
        return json(a, out);
    }
    if (eql(u8, path, "/lol-champion-mastery/v1/local-player/champion-mastery")) {
        const Row = struct { championId: u32, championPoints: u32, championLevel: u32, puuid: []const u8 = "mock-puuid" };
        const out = try a.alloc(Row, s.mastery.len);
        for (out, s.mastery) |*o, m| o.* = .{ .championId = m[0], .championPoints = m[1], .championLevel = @min(50, m[1] / 12_000 + 1) };
        return json(a, out);
    }
    if (eql(u8, path, "/lol-ranked/v1/current-ranked-stats")) {
        const tier = if (s.tier.len > 0) s.tier else "NONE";
        const Queue = struct { queueType: []const u8, tier: []const u8, division: []const u8, leaguePoints: u32 };
        return json(a, .{ .queueMap = .{
            .RANKED_SOLO_5x5 = Queue{ .queueType = "RANKED_SOLO_5x5", .tier = tier, .division = "II", .leaguePoints = 40 },
            .RANKED_FLEX_SR = Queue{ .queueType = "RANKED_FLEX_SR", .tier = "NONE", .division = "NA", .leaguePoints = 0 },
        } });
    }
    if (eql(u8, path, "/lol-end-of-game/v1/eog-stats-block")) {
        if (!eql(u8, st.phase, "PreEndOfGame") and !eql(u8, st.phase, "EndOfGame")) return not_found;
        return json(a, try endOfGame(a, s, st));
    }
    return not_found;
}

const Member = struct {
    assignedPosition: []const u8,
    cellId: u8,
    championId: u32,
    championPickIntent: u32,
    gameName: []const u8,
    tagLine: []const u8,
    nameVisibilityType: []const u8,
    puuid: []const u8,
    summonerId: u32,
    obfuscatedPuuid: []const u8 = "",
    playerType: []const u8 = "PLAYER",
    isAutofilled: bool = false,
    selectedSkinId: u32 = 0,
    spell1Id: u32 = 4,
    spell2Id: u32 = 14,
    team: u8,
};

const Action = struct {
    id: u32,
    actorCellId: u8,
    championId: u32,
    completed: bool,
    isAllyAction: bool,
    isInProgress: bool,
    pickTurn: u32,
    type: []const u8,
};

fn session(a: std.mem.Allocator, s: *const Scenario, st: *const State) !struct {
    actions: []const []const Action,
    bans: struct { myTeamBans: []const u32, theirTeamBans: []const u32, numBans: u32 },
    localPlayerCellId: u8,
    myTeam: []const Member,
    theirTeam: []const Member,
    timer: struct { phase: []const u8, adjustedTimeLeftInPhase: i64, totalTimeInPhase: i64, isInfinite: bool },
    counter: i64,
    gameId: i64 = 0,
    id: []const u8 = "mock-session",
    isCustomGame: bool = false,
    isSpectating: bool = false,
    hasSimultaneousBans: bool = true,
    hasSimultaneousPicks: bool = false,
    benchEnabled: bool,
    benchChampions: []const u32 = &.{},
} {
    var my: [5]Member = undefined;
    var their: [5]Member = undefined;
    for (st.cells, 0..) |c, i| {
        const cell: u8 = @intCast(i);
        const ally = cell < 5;
        const me = cell == s.local_cell;
        // Enemy hovers and intents never show; their locks do
        const m: Member = .{
            .assignedPosition = c.position,
            .cellId = cell,
            .championId = if (ally or c.locked) c.champion else 0,
            .championPickIntent = if (ally) c.intent else 0,
            .gameName = if (me) local_name else "",
            .tagLine = if (me) local_tag else "",
            .nameVisibilityType = if (me) "VISIBLE" else "HIDDEN",
            .puuid = if (me) "mock-puuid" else "",
            .summonerId = if (me) 1 else 0,
            .obfuscatedPuuid = if (me) "" else try a.print("mock-obfuscated-{d}", .{cell}),
            .team = if (ally) 1 else 2,
        };
        if (ally) my[cell] = m else their[cell - 5] = m;
    }

    var actions: std.ArrayList([]const Action) = .empty;
    var id: u32 = 1;
    var bans: [10]Action = undefined;
    var my_bans: std.ArrayList(u32) = .empty;
    var their_bans: std.ArrayList(u32) = .empty;
    const banning = std.mem.eql(u8, st.timer, "BAN_PICK");
    var bans_done = true;
    for (&bans, st.cells, 0..) |*b, c, i| {
        b.* = .{ .id = id, .actorCellId = @intCast(i), .championId = c.ban, .completed = c.banned, .isAllyAction = i < 5, .isInProgress = banning and !c.banned, .pickTurn = 1, .type = "ban" };
        id += 1;
        bans_done = bans_done and c.banned;
        if (c.banned and c.ban != 0) try (if (i < 5) &my_bans else &their_bans).append(a, c.ban);
    }
    try actions.append(a, try a.dupe(Action, &bans));
    var current_found = !bans_done;
    for (s.pick_order, 1..) |group, turn| {
        const out = try a.alloc(Action, group.len);
        const done = for (group) |cell| {
            if (!st.cells[cell].locked) break false;
        } else true;
        const current = banning and !done and !current_found;
        if (current) current_found = true;
        for (out, group) |*o, cell| {
            const c = st.cells[cell];
            o.* = .{ .id = id, .actorCellId = cell, .championId = if (c.locked) c.locked_with else if (cell < 5) c.champion else 0, .completed = c.locked, .isAllyAction = cell < 5, .isInProgress = current and !c.locked, .pickTurn = @intCast(turn), .type = "pick" };
            id += 1;
        }
        try actions.append(a, out);
    }
    // The client reveals bans after the ban turn; until then the lists are empty
    const revealed = bans_done;
    return .{
        .actions = actions.items,
        .bans = .{ .myTeamBans = if (revealed) my_bans.items else &.{}, .theirTeamBans = if (revealed) their_bans.items else &.{}, .numBans = 10 },
        .localPlayerCellId = s.local_cell,
        .myTeam = try a.dupe(Member, &my),
        .theirTeam = try a.dupe(Member, &their),
        .timer = .{ .phase = st.timer, .adjustedTimeLeftInPhase = 30_000, .totalTimeInPhase = 30_000, .isInfinite = false },
        .counter = st.counter,
        .benchEnabled = s.queue == 450,
    };
}

const Scores = struct { assists: i64, creepScore: i64, deaths: i64, kills: i64, wardScore: f64 = 0 };

fn endOfGame(a: std.mem.Allocator, s: *const Scenario, st: *const State) !struct {
    gameId: i64 = 0,
    gameLength: i64,
    gameMode: []const u8,
    queueType: []const u8,
    localPlayer: Player,
    teams: []const Team,
} {
    const m = s.mode();
    var teams: [2]Team = undefined;
    var players: [10]Player = undefined;
    for (&players, st.cells, 0..) |*p, c, i| p.* = .{
        .championId = c.champion,
        .championName = s.nameOf(c.champion),
        .summonerName = if (i == s.local_cell) local_name else "",
        .detectedTeamPosition = try std.ascii.allocUpperString(a, c.position),
        .stats = .{
            .CHAMPIONS_KILLED = c.kills,
            .NUM_DEATHS = c.deaths,
            .ASSISTS = c.assists,
            .MINIONS_KILLED = c.cs,
            .LEVEL = c.level,
            // Made up from what the scenario gives
            .GOLD_EARNED = 500 + c.items + 300 * c.kills,
            .TOTAL_DAMAGE_DEALT_TO_CHAMPIONS = 1000 * c.level + 1500 * (c.kills + c.assists),
        },
    };
    const won = st.win orelse true;
    for (&teams, 0..) |*t, i| t.* = .{
        .teamId = if (i == 0) 100 else 200,
        .isPlayerTeam = i == 0,
        .isWinningTeam = (i == 0) == won,
        .players = try a.dupe(Player, players[i * 5 ..][0..5]),
    };
    return .{
        .gameLength = @trunc(st.game_time),
        .gameMode = m.game,
        .queueType = m.queue_type,
        .localPlayer = players[s.local_cell],
        .teams = try a.dupe(Team, &teams),
    };
}

const Player = struct {
    championId: u32,
    championName: []const u8,
    summonerName: []const u8,
    detectedTeamPosition: []const u8,
    stats: struct {
        CHAMPIONS_KILLED: i64,
        NUM_DEATHS: i64,
        ASSISTS: i64,
        MINIONS_KILLED: i64,
        LEVEL: i64,
        GOLD_EARNED: i64,
        TOTAL_DAMAGE_DEALT_TO_CHAMPIONS: i64,
    },
};
const Team = struct { teamId: u32, isPlayerTeam: bool, isWinningTeam: bool, players: []const Player };

/// The Live Client Data API (port 2999 in a real game) reply for `target`
pub fn live(a: std.mem.Allocator, s: *const Scenario, st: *const State, target: []const u8) !Reply {
    const path = target[0 .. std.mem.findScalar(u8, target, '?') orelse target.len];
    if (!std.mem.eql(u8, st.phase, "GameStart") and !std.mem.eql(u8, st.phase, "InProgress")) return not_found;
    const prefix = "/liveclientdata/";
    if (!std.mem.startsWith(u8, path, prefix)) return not_found;
    const what = path[prefix.len..];
    const eql = std.mem.eql;
    const m = s.mode();
    const game_data = .{ .gameMode = m.game, .gameTime = st.game_time, .mapName = if (m.map == 12) "Map12" else "Map11", .mapNumber = m.map, .mapTerrain = "Default" };
    const events = .{ .Events = st.events[0..st.n_events] };
    if (eql(u8, what, "gamestats")) return json(a, game_data);
    if (eql(u8, what, "eventdata")) return json(a, events);
    if (eql(u8, what, "activeplayername")) return json(a, local_name ++ "#" ++ local_tag);
    if (eql(u8, what, "activeplayer")) return json(a, activePlayer(st, s));
    if (eql(u8, what, "playerlist")) return json(a, try playerList(a, s, st));
    if (eql(u8, what, "allgamedata")) return json(a, .{
        .activePlayer = activePlayer(st, s),
        .allPlayers = try playerList(a, s, st),
        .events = events,
        .gameData = game_data,
    });
    return not_found;
}

fn activePlayer(st: *const State, s: *const Scenario) struct {
    riotId: []const u8 = local_name ++ "#" ++ local_tag,
    riotIdGameName: []const u8 = local_name,
    riotIdTagLine: []const u8 = local_tag,
    summonerName: []const u8 = local_name ++ "#" ++ local_tag,
    level: i64,
    currentGold: f64,
    teamRelativeColors: bool = true,
} {
    return .{ .level = st.cells[s.local_cell].level, .currentGold = st.gold };
}

const LivePlayer = struct {
    championName: []const u8,
    rawChampionName: []const u8,
    isBot: bool = false,
    isDead: bool = false,
    level: i64,
    position: []const u8,
    respawnTimer: f64 = 0,
    riotId: []const u8,
    riotIdGameName: []const u8,
    riotIdTagLine: []const u8 = local_tag,
    summonerName: []const u8,
    scores: Scores,
    skinID: u32 = 0,
    team: []const u8,
    items: []const LiveItem = &.{},
};

const LiveItem = struct { itemID: u32 = 0, displayName: []const u8 = "Mock items", price: i64, count: i64 = 1, slot: u32 = 0 };

fn playerList(a: std.mem.Allocator, s: *const Scenario, st: *const State) ![]LivePlayer {
    const out = try a.alloc(LivePlayer, 10);
    for (out, st.cells, 0..) |*p, c, i| {
        const name = s.nameOf(c.champion);
        const game_name = if (i == s.local_cell) local_name else try a.print("Player{d}", .{i});
        p.* = .{
            .championName = name,
            .rawChampionName = try a.print("game_character_displayname_{s}", .{name}),
            .level = c.level,
            .position = try std.ascii.allocUpperString(a, c.position),
            .riotId = try a.print("{s}#{s}", .{ game_name, local_tag }),
            .riotIdGameName = game_name,
            .summonerName = try a.print("{s}#{s}", .{ game_name, local_tag }),
            .scores = .{ .assists = c.assists, .creepScore = c.cs, .deaths = c.deaths, .kills = c.kills },
            .team = if (i < 5) "ORDER" else "CHAOS",
            .items = if (c.items > 0) try a.dupe(LiveItem, &.{.{ .price = c.items }}) else &.{},
        };
    }
    return out;
}

fn json(a: std.mem.Allocator, v: anytype) !Reply {
    return .{ .body = try std.json.Stringify.valueAlloc(a, v, .{}) };
}

/// Plays a scenario: `state` under `mutex`, the servers read it
pub const Mock = struct {
    gpa: std.mem.Allocator,
    io: Io,
    scenario: *const Scenario,
    password: []const u8 = "mock-password",
    mutex: Io.Mutex = .init,
    state: State = .{},
    next: usize = 0,

    /// Applies the next step; null after the last
    pub fn advance(m: *Mock) !?Value {
        if (m.next >= m.scenario.steps.len) return null;
        const step = m.scenario.steps[m.next];
        m.next += 1;
        m.mutex.lockUncancelable(m.io);
        defer m.mutex.unlock(m.io);
        try m.state.apply(m.scenario, step);
        return step;
    }

    /// Back to the first step, for playing the scenario again
    pub fn restart(m: *Mock) void {
        m.mutex.lockUncancelable(m.io);
        defer m.mutex.unlock(m.io);
        m.next = 0;
        m.state = .{};
    }

    /// Accept loops until cancelled, each connection on its own thread
    pub fn serveLcu(m: *Mock, server: *Io.net.Server) void {
        httpd.accept(.mock_lcu, m.io, server, .local, m, lcuConnection);
    }

    pub fn serveLive(m: *Mock, server: *Io.net.Server) void {
        httpd.accept(.mock_live, m.io, server, .local, m, liveConnection);
    }

    pub fn lcuConnection(m: *Mock, conn: httpd.Connection) void {
        httpd.requests(.mock_lcu, m.io, conn, m, handleLcu, .path);
    }

    pub fn liveConnection(m: *Mock, conn: httpd.Connection) void {
        httpd.requests(.mock_live, m.io, conn, m, handleLive, .path);
    }

    fn handleLcu(m: *Mock, r: *std.http.Server.Request) !void {
        if (!m.authorised(r)) return r.respond("{\"message\":\"mock: bad password\"}", .{ .status = .unauthorized });
        return m.reply(r, lcu);
    }

    fn handleLive(m: *Mock, r: *std.http.Server.Request) !void {
        return m.reply(r, live);
    }

    fn reply(m: *Mock, r: *std.http.Server.Request, comptime f: anytype) !void {
        var arena: std.heap.ArenaAllocator = .init(m.gpa);
        defer arena.deinit();
        const rep = blk: {
            m.mutex.lockUncancelable(m.io);
            defer m.mutex.unlock(m.io);
            break :blk try f(arena.allocator(), m.scenario, &m.state, r.head.target);
        };
        try r.respond(rep.body, .{
            .status = rep.status,
            .keep_alive = false,
            .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
        });
    }

    fn authorised(m: *Mock, r: *std.http.Server.Request) bool {
        var buf: [256]u8 = undefined;
        const plain = std.mem.print(&buf, "riot:{s}", .{m.password}) catch return false;
        var enc_buf: [400]u8 = undefined;
        const want = std.base64.standard.Encoder.encode(&enc_buf, plain);
        var it = r.iterateHeaders();
        while (it.next()) |h| {
            if (!std.ascii.eqlIgnoreCase(h.name, "authorization")) continue;
            const v = std.mem.trim(u8, h.value, " ");
            return std.mem.startsWith(u8, v, "Basic ") and std.mem.eql(u8, v["Basic ".len..], want);
        }
        return false;
    }

    /// `LeagueClient:PID:PORT:PASSWORD:http` for lockfile.discover's override
    pub fn lockfile(m: *const Mock, buf: []u8, port: u16) ![]const u8 {
        return std.mem.print(buf, "LeagueClient:0:{d}:{s}:http", .{ port, m.password });
    }
};

const testing = std.testing;
const core = @import("core");
const Watch = @import("watch.zig").Watch;
const livedata = @import("live.zig");
const eogdata = @import("eog.zig");

// Each scenario through lcu.Watch, as `meiolol-app watch` and the window poll it,
// checking each step's `expect`: phase (the gameflow phase watch reports), between
// (true), role (my position, null when none), me, locked, allies and enemies (names,
// "?" after a hover), bans (count), pool (count); live and eog (checkServed)
test "scenarios through the watch" {
    const io = testing.io;
    const gpa = testing.allocator;
    var dir = try Io.Dir.cwd().openDir(io, "testdata/lcu/scenarios", .{ .iterate = true });
    defer dir.close(io);
    var it = dir.iterate();
    var checked: usize = 0;
    while (try it.next(io)) |e| {
        if (!std.mem.endsWith(u8, e.name, ".json") or std.mem.eql(u8, e.name, champions_file)) continue;
        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();
        const path = try arena.allocator().print("testdata/lcu/scenarios/{s}", .{e.name});
        checked += try runScenario(arena.allocator(), path);
    }
    try testing.expect(checked >= 10);
}

/// The mock's LCU and Live Client Data servers on free ports and a lockfile for them,
/// for tests; must not move after start
pub const Harness = struct {
    mock: Mock,
    lcu_server: Io.net.Server,
    live_server: Io.net.Server,
    group: Io.Group = .init,
    tmp: testing.TmpDir,
    lock_path: []const u8,

    pub fn start(h: *Harness, arena: std.mem.Allocator, s: *const Scenario) !void {
        const io = testing.io;
        h.mock = .{ .gpa = testing.allocator, .io = io, .scenario = s };
        h.group = .init;
        const address = try Io.net.IpAddress.parse("127.0.0.1", 0);
        h.lcu_server = try address.listen(io, .{ .reuse_address = true });
        errdefer h.lcu_server.deinit(io);
        h.live_server = try address.listen(io, .{ .reuse_address = true });
        errdefer h.live_server.deinit(io);
        try h.group.concurrent(io, Mock.serveLcu, .{ &h.mock, &h.lcu_server });
        errdefer h.group.cancel(io);
        try h.group.concurrent(io, Mock.serveLive, .{ &h.mock, &h.live_server });
        h.tmp = testing.tmpDir(.{});
        errdefer h.tmp.cleanup();
        var lock_buf: [128]u8 = undefined;
        const lock = try h.mock.lockfile(&lock_buf, h.lcuPort());
        try h.tmp.dir.writeFile(io, .{ .sub_path = "lockfile", .data = lock });
        h.lock_path = try std.fmt.allocPrint(arena, ".zig-cache/tmp/{s}/lockfile", .{h.tmp.sub_path});
    }

    pub fn stop(h: *Harness) void {
        const io = testing.io;
        h.group.cancel(io);
        h.tmp.cleanup();
        h.live_server.deinit(io);
        h.lcu_server.deinit(io);
    }

    pub fn lcuPort(h: *const Harness) u16 {
        return h.lcu_server.socket.address.getPort();
    }

    pub fn livePort(h: *const Harness) u16 {
        return h.live_server.socket.address.getPort();
    }
};

fn runScenario(arena: std.mem.Allocator, path: []const u8) !usize {
    const io = testing.io;
    const gpa = testing.allocator;
    const s = try Scenario.load(arena, io, path);
    var h: Harness = undefined;
    try h.start(arena, &s);
    defer h.stop();
    const m = &h.mock;
    const lock_path = h.lock_path;

    var w: Watch = .init(gpa, io, lock_path);
    defer w.deinit();
    var checked: usize = 0;
    while (try m.advance()) |step| {
        const expect = step.object.get("expect") orelse continue;
        var frame: std.heap.ArenaAllocator = .init(gpa);
        defer frame.deinit();
        const got = try w.step(frame.allocator());
        checkServed(m, expect.object, h.lcuPort(), h.livePort()) catch |err| {
            std.debug.print("{s} step {d}: {t}\n", .{ s.name, m.next, err });
            return err;
        };
        checkStep(&s, expect.object, got, w.pool) catch |err| {
            std.debug.print("{s} step {d}: {t}\n", .{ s.name, m.next, err });
            return err;
        };
        checked += 1;
    }
    return checked;
}

fn checkStep(s: *const Scenario, ex: std.json.ObjectMap, got: Watch.Step, pool: ?[]u32) !void {
    if (ex.get("phase")) |want| {
        if (got != .phase) return error.WantPhase;
        try testing.expectEqualStrings(want.string, got.phase);
        return;
    }
    if (ex.get("between") != null) {
        if (got != .between) return error.WantBetween;
        return;
    }
    if (got != .select) return error.WantSelect;
    const cs = got.select;
    if (ex.get("role")) |want| {
        const role: ?core.Role = if (want == .null) null else core.Role.fromLcu(want.string) orelse return error.BadRole;
        try testing.expectEqual(role, cs.my_role);
    }
    if (ex.get("me")) |want| {
        const id = if (want.string.len == 0) 0 else try s.champion(want.string);
        try testing.expectEqual(id, cs.my_champion);
    }
    if (ex.get("locked")) |want| try testing.expectEqual(want.bool, cs.my_locked);
    if (ex.get("bans")) |want| try testing.expectEqual(@as(usize, @intCast(want.integer)), cs.bans.len);
    if (ex.get("pool")) |want| try testing.expectEqual(@as(usize, @intCast(want.integer)), (pool orelse return error.NoPool).len);
    inline for (.{ "allies", "enemies" }) |key| if (ex.get(key)) |want| {
        const picks = @field(cs, key);
        try testing.expectEqual(want.array.items.len, picks.len);
        for (want.array.items, picks) |n, p| {
            const hover = std.mem.endsWith(u8, n.string, "?");
            const name = if (hover) n.string[0 .. n.string.len - 1] else n.string;
            try testing.expectEqual(try s.champion(name), p.champion);
            try testing.expectEqual(hover, p.hover);
        }
    };
}

/// `live`: {players, events} from /liveclientdata/allgamedata; `eog`: {win} from the
/// end of game block
fn checkServed(m: *Mock, ex: std.json.ObjectMap, lcu_port: u16, live_port: u16) !void {
    const https = @import("https.zig");
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    if (ex.get("live")) |want| {
        const resp = try https.getPlain(testing.allocator, testing.io, live_port, "", "/liveclientdata/allgamedata");
        defer testing.allocator.free(resp.body);
        try testing.expectEqual(200, resp.status);
        const Game = struct {
            allPlayers: []const struct { championName: []const u8 },
            events: struct { Events: []const struct { EventName: []const u8 } },
        };
        const g = try std.json.parseFromSliceLeaky(Game, a, resp.body, .{ .ignore_unknown_fields = true });
        if (want.object.get("players")) |n| try testing.expectEqual(@as(usize, @intCast(n.integer)), g.allPlayers.len);
        if (want.object.get("events")) |n| try testing.expectEqual(@as(usize, @intCast(n.integer)), g.events.Events.len);
        // What the in-game panel reads of it
        const parsed = try livedata.parse(a, resp.body);
        if (want.object.get("me")) |n| try testing.expectEqualStrings(n.string, parsed.me().?.champion);
        if (want.object.get("item_gold")) |n| try testing.expectEqual(n.integer, parsed.me().?.item_gold);
        if (want.object.get("objectives")) |n| try testing.expectEqual(@as(usize, @intCast(n.integer)), parsed.events.len);
    }
    if (ex.get("eog")) |want| {
        const resp = try https.getPlain(testing.allocator, testing.io, lcu_port, m.password, "/lol-end-of-game/v1/eog-stats-block");
        defer testing.allocator.free(resp.body);
        try testing.expectEqual(200, resp.status);
        const Eog = struct { teams: []const struct { isPlayerTeam: bool, isWinningTeam: bool } };
        const e = try std.json.parseFromSliceLeaky(Eog, a, resp.body, .{ .ignore_unknown_fields = true });
        try testing.expectEqual(want.object.get("win").?.bool, e.teams[0].isWinningTeam);
        const parsed = try eogdata.parse(a, resp.body);
        try testing.expectEqual(want.object.get("win").?.bool, parsed.win);
        if (want.object.get("me")) |n| {
            var mine: usize = 0;
            for (parsed.players) |p| if (p.me) {
                try testing.expectEqual(m.scenario.names.get(n.string).?, p.champion);
                mine += 1;
            };
            try testing.expectEqual(1, mine);
        }
    }
}
