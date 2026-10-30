//! Squads (/squad, your-games.md "Squads"): friends who each joined by the profile icon
//! check, and the games they played together. #s=TOKEN is a squad (the invite link):
//! its name, members, record together and those games, each opening a member's review;
//! Join, Leave and the link to share. Without a token: start one. Island Squad
//! (ui-squad.wasm); /api/squad answers Data in ui.data's binary, /api/squad/check the
//! check's small JSON (api/squads.zig)
const std = @import("std");
const tree = @import("tree.zig");
const phrase = @import("phrase.zig");
const button = @import("button.zig");
const champ = @import("champ.zig");
const role = @import("role.zig");
const kda = @import("kda.zig");
const gamerow = @import("gamerow.zig");
const idlookup = @import("idlookup.zig");
const homepage = @import("homepage.zig");
const forget = @import("forget.zig");
const yl = @import("yourlist.zig");
const url = @import("url.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Squad";
pub const scope = .{".c-squad"};
pub const sel = "[data-island=squad]";

/// While members' games or a check are still coming: ask again this often
pub const poll_ms = 5000;
pub const token_len = 22;

pub const Member = struct {
    riot_id: []const u8,
    /// Cached games
    games: u32 = 0,
    /// A refresh queued or running
    waiting: bool = false,
};

/// `Data.champs` and `Data.members` indices
pub const Seat = struct { member: u8, champ: u16, role: ?role.Role = null, k: u16 = 0, d: u16 = 0, a: u16 = 0 };

pub const Game = struct {
    start_ms: i64,
    queue: yl.Queue,
    duration_s: u32,
    win: bool,
    seats: []const Seat,
};

/// /api/squad's answer
pub const Data = struct {
    pub const State = enum { none, ready };
    state: State,
    name: []const u8 = "",
    members: []const Member = &.{},
    champs: []const champ.Champ = &.{},
    /// Newest first
    games: []const Game = &.{},

    pub fn waiting(d: *const Data) bool {
        for (d.members) |m| if (m.waiting) return true;
        return false;
    }
};

const W = struct {
    pub const title = plain("Squads");
    pub const lead = plain("Friends who join a squad see the games they played together. Each member joins with their own Riot ID.");
    pub const squad_name = plain("Squad name");
    pub const id = plain("Your Riot ID");
    pub const hint = plain("Name#TAG");
    pub const start = plain("Start");
    pub const new = plain("New squad");
    pub const join = plain("Join");
    pub const leave = plain("Leave");
    pub const next = plain("Next");
    pub const cancel = plain("Cancel");
    pub const check = plain("Check");
    pub const copy = plain("Copy link");
    pub const copied = plain("Copied");
    pub const invite = plain("Invite link");
    pub const members = plain("Members");
    pub const together = phrase.Phrase("{n:count} games together");
    pub const record = phrase.Phrase("{w:int}W {l:int}L");
    pub const win = plain("Win");
    pub const loss = plain("Loss");
    pub const mins = phrase.Phrase("{n:int} min");
    pub const none_yet = plain("No games together in the last 60 days yet.");
    pub const fetching = plain("Fetching members' games…");
    pub const loading = plain("Loading…");
    pub const no_squad = plain("No squad at this link. It may have been left by everyone.");
    pub const contacting = plain("Contacting Riot…");
    pub const checking = plain("Checking your icon with Riot…");
    pub const issued = phrase.Phrase("Set this profile icon on {id:text} in the League client before {at:time}, then press Check. You can change it back after.");
    pub const mismatch = phrase.Phrase("Riot doesn't show this icon on {id:text} yet; it can take a minute. Set it before {at:time}, then press Check.");
    pub const joined = plain("You're in. Your games are on their way.");
    pub const left = plain("You've left the squad.");
    pub const full = plain("This squad is full (10 members).");
    pub const gone = plain("This squad no longer exists.");
    pub const not_found = plain("No Riot account with that name and tag.");
    pub const opted_out = plain("This Riot ID asked us not to keep its data.");
    pub const expired = plain("That check expired. Start again for a new icon.");
    pub const down = plain("Couldn't reach the service. Try again in a minute.");
    pub const icon = plain("Profile icon to set");
    pub const why = plain("What we keep");
    pub const open_game = plain("Open the review");
};

pub const CheckState = enum { none, pending, checking, issued, mismatch, done, full, gone, not_found, opted_out, failed, expired };

/// /api/squad/check's answer: forget.Answer's fields, `k` once a check starts, `s` once
/// a start is done
pub const Answer = struct {
    state: CheckState,
    icon: ?u32 = null,
    expires: i64 = 0,
    k: ?[]const u8 = null,
    s: ?[]const u8 = null,
};

pub fn answer(json: []const u8) ?Answer {
    const s = str(json, "state") orelse return null;
    return .{
        .state = std.meta.stringToEnum(CheckState, s) orelse return null,
        .icon = if (field(json, "icon")) |v| std.fmt.parseInt(u32, number(v), 10) catch null else null,
        .expires = if (field(json, "expires")) |v| std.fmt.parseInt(i64, number(v), 10) catch 0 else 0,
        .k = str(json, "k"),
        .s = str(json, "s"),
    };
}

fn field(json: []const u8, comptime key: []const u8) ?[]const u8 {
    const k = "\"" ++ key ++ "\":";
    const at = std.mem.find(u8, json, k) orelse return null;
    return json[at + k.len ..];
}

/// A string value without escapes (states, tokens)
fn str(json: []const u8, comptime key: []const u8) ?[]const u8 {
    const v = field(json, key) orelse return null;
    if (v.len < 2 or v[0] != '"') return null;
    const end = std.mem.findScalar(u8, v[1..], '"') orelse return null;
    return v[1 .. 1 + end];
}

fn number(s: []const u8) []const u8 {
    var n: usize = 0;
    while (n < s.len and std.ascii.isDigit(s[n])) n += 1;
    return s[0..n];
}

pub const Token = url.Str(token_len);
/// The page's fragment
pub const Frag = struct { s: Token = .{} };

pub const Squad = struct {
    /// The squad shown; empty: the start form
    token: Token = .{},
    data: ?*const Data = null,
    load: Load = .idle,
    /// The check under way
    action: Action = .none,
    q: idlookup.Id = .{},
    sname: idlookup.Id = .{},
    id: idlookup.Id = .{},
    /// The check's key from the API, sent back with each ask
    key: Token = .{},
    at: At = .idle,
    icon: ?u32 = null,
    expires: i64 = 0,
    /// For the wasm after an event
    want: Want = .none,
    gen: u32 = 0,
    copied: bool = false,
    /// Set when a start is done: the wasm opens it
    started: Token = .{},
    now_ms: ?i64 = null,
    ddragon: []const u8 = "",
    tz_min: i32 = 0,
    /// The site's origin, for the invite link
    origin: []const u8 = "",
    js: []const u8 = "",
    wasm: []const u8 = "",

    const P = @This();

    pub const Load = enum { idle, loading, ready, down };
    pub const Action = enum { none, create, join, leave };
    pub const At = enum { idle, waiting, issued, mismatch, done, full, gone, not_found, opted_out, expired, down };
    pub const Want = enum { none, start, check, copy };

    pub const Msg = union(enum) { join, leave, cancel, input, name_input, key, start, check, copy };

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .join => p.choose(.join),
            .leave => p.choose(.leave),
            .cancel => {
                p.action = if (p.token.len == 0) .create else .none;
                p.at = .idle;
                p.gen +%= 1;
            },
            .input => p.q.set(ev.text),
            .name_input => p.sname.set(ev.text),
            .key => if (std.mem.eql(u8, ev.text, "Enter")) {
                ev.handled = true;
                p.begin();
            },
            .start => p.begin(),
            .check => if (p.at == .issued or p.at == .mismatch) {
                p.at = .waiting;
                p.want = .check;
            },
            .copy => {
                p.copied = true;
                p.want = .copy;
            },
        }
    }

    fn choose(p: *P, a: Action) void {
        p.action = a;
        p.at = .idle;
        p.gen +%= 1;
    }

    fn ready(p: *const P) bool {
        if (!valid(trim(p.q.slice()))) return false;
        return p.action != .create or trim(p.sname.slice()).len > 0;
    }

    fn begin(p: *P) void {
        if (p.at == .waiting or !p.ready()) return;
        p.id.set(trim(p.q.slice()));
        p.icon = null;
        p.key = .{};
        p.gen +%= 1;
        p.at = .waiting;
        p.want = .start;
    }

    /// The check's answer (null: the fetch failed); true while the API is still at it
    pub fn answered(p: *P, a: ?Answer) bool {
        const x = a orelse {
            p.at = .down;
            return false;
        };
        if (x.k) |k| p.key.set(k);
        if (x.icon) |i| p.icon = i;
        if (x.expires != 0) p.expires = x.expires;
        p.at = switch (x.state) {
            .pending, .checking => return true,
            .issued => .issued,
            .mismatch => .mismatch,
            .done => .done,
            .full => .full,
            .gone => .gone,
            .not_found => .not_found,
            .opted_out => .opted_out,
            .failed => .down,
            .expired, .none => .expired,
        };
        if (p.at == .done and p.action == .create) if (x.s) |s| p.started.set(s);
        return false;
    }

    /// /api/squad's answer (null: the fetch failed); true while members' games are coming
    pub fn loaded(p: *P, d: ?*const Data) bool {
        const x = d orelse {
            p.load = .down;
            return false;
        };
        p.data = x;
        p.load = .ready;
        return x.waiting();
    }

    /// The API path for the next ask about the check (the wasm adds nothing)
    pub fn checkPath(p: *const P, a: std.mem.Allocator, w: Want) ![]const u8 {
        const q = try homepage.idQuery(a, p.id.slice());
        defer a.free(q);
        var out: std.Io.Writer.Allocating = .init(a);
        errdefer out.deinit();
        try out.writer.print("/api/squad/check?{s}", .{q});
        if (w == .start) {
            try out.writer.print("&do={t}", .{p.action});
            if (p.action == .create) {
                var f: struct { name: idlookup.Id = .{} } = .{};
                f.name.set(trim(p.sname.slice()));
                try out.writer.writeByte('&');
                try url.write(@TypeOf(f), f, &out.writer);
            } else try out.writer.print("&s={s}", .{p.token.slice()});
        } else try out.writer.print("&k={s}", .{p.key.slice()});
        if (w == .check) try out.writer.writeAll("&check=1");
        return out.toOwnedSlice();
    }

    pub fn view(p: *P, h: *H) N {
        return h.div(.{
            .class = "c-squad",
            .data_island = "squad",
            .data_js = if (p.js.len > 0) p.js else null,
            .data_wasm = if (p.wasm.len > 0) p.wasm else null,
            .data_ddragon = if (p.ddragon.len > 0) p.ddragon else null,
        }, .{if (p.token.len == 0) p.startView(h) else p.squadView(h)});
    }

    fn startView(p: *P, h: *H) N {
        return h.div(.{ .class = "start" }, .{
            h.el(.h1, .{}, .{W.title}),
            h.p(.{ .class = "lead" }, .{W.lead}),
            p.form(h, .create),
            h.a(.{ .href = "/privacy#squads", .class = "why" }, .{W.why}),
        });
    }

    fn squadView(p: *P, h: *H) N {
        const d = p.data orelse return h.div(.{ .class = "head" }, .{
            h.el(.h1, .{}, .{W.title}),
            h.p(.{ .role = "status" }, .{switch (p.load) {
                .down => W.down,
                else => W.loading,
            }}),
        });
        if (d.state == .none) return h.div(.{ .class = "head" }, .{
            h.el(.h1, .{}, .{W.title}),
            h.p(.{ .role = "status" }, .{W.no_squad}),
            h.a(.{ .href = "/squad" }, .{W.new}),
        });
        var wins: i64 = 0;
        for (d.games) |g| wins += @intFromBool(g.win);
        const losses: i64 = @as(i64, @intCast(d.games.len)) - wins;
        var ms = h.list();
        for (d.members) |m| ms.add(h.a(.{ .class = "member", .href = h.fmt("/your#{s}", .{homepage.idQuery(h.mem, m.riot_id) catch ""}) }, .{m.riot_id}));
        var gs = h.list();
        for (d.games) |g| gs.add(p.gameView(h, d, g));
        return h.div(.{}, .{
            h.div(.{ .class = "head" }, .{
                h.el(.h1, .{}, .{d.name}),
                h.div(.{ .class = "members", .role = "list", .aria_label = W.members }, .{ms.done()}),
                h.div(.{ .class = "rec" }, .{
                    h.el(.b, .{}, .{W.together.with(h, .{ .n = d.games.len })}),
                    if (d.games.len > 0) h.span(.{ .class = "wl" }, .{W.record.with(h, .{ .w = wins, .l = losses })}) else null,
                }),
                if (d.waiting()) h.p(.{ .class = "msg", .role = "status" }, .{W.fetching}) else if (d.games.len == 0) h.p(.{ .class = "msg" }, .{W.none_yet}) else null,
            }),
            h.div(.{ .class = "games" }, .{gs.done()}),
            p.actions(h),
        });
    }

    fn gameView(p: *const P, h: *H, d: *const Data, g: Game) N {
        var seats = h.list();
        for (g.seats) |s| {
            const c: ?champ.Champ = if (s.champ < d.champs.len) d.champs[s.champ] else null;
            const who = if (s.member < d.members.len) d.members[s.member].riot_id else "";
            seats.add(h.div(.{ .class = "seat" }, .{
                champ.view(h, c, .{ .px = .@"32" }),
                h.span(.{ .class = "who" }, .{ who, if (s.role) |r| role.view(h, r, .{ .s = .s }) else null }),
                kda.view(h, .{ .k = s.k, .d = s.d, .a = s.a }, .{}),
            }));
        }
        const first = if (g.seats.len > 0 and g.seats[0].member < d.members.len) d.members[g.seats[0].member].riot_id else "";
        return h.a(.{ .class = "game", .href = gameHref(h.mem, first, g.start_ms) catch "", .data_win = g.win, .aria_label = W.open_game }, .{
            h.div(.{ .class = "meta" }, .{
                h.el(.b, .{}, .{if (g.win) W.win else W.loss}),
                h.span(.{}, .{gamerow.queueName(g.queue)}),
                h.span(.{}, .{W.mins.with(h, .{ .n = @divFloor(g.duration_s, 60) })}),
                if (p.now_ms) |now| h.span(.{}, .{gamerow.ago(h, now - g.start_ms)}) else null,
            }),
            h.div(.{ .class = "seats" }, .{seats.done()}),
        });
    }

    fn actions(p: *P, h: *H) N {
        if (p.action != .none) return h.div(.{ .class = "act" }, .{p.form(h, p.action)});
        const link = h.fmt("{s}/squad#s={s}", .{ p.origin, p.token.slice() });
        return h.div(.{ .class = "act" }, .{
            h.div(.{ .class = "invite" }, .{
                h.input(.{ .type = "text", .readonly = true, .value = link, .aria_label = W.invite }),
                button.view(h, .{ .v = .primary, .s = .s, .on = h.on(p, .copy) }, .{if (p.copied) W.copied else W.copy}),
            }),
            h.div(.{ .class = "row" }, .{
                button.view(h, .{ .s = .s, .on = h.on(p, .join) }, .{W.join}),
                button.view(h, .{ .s = .s, .on = h.on(p, .leave) }, .{W.leave}),
                h.a(.{ .href = "/privacy#squads", .class = "why" }, .{W.why}),
            }),
        });
    }

    fn form(p: *P, h: *H, a: Action) N {
        const asking = p.at == .issued or p.at == .mismatch;
        const settled = p.at == .done or p.at == .full or p.at == .gone;
        const show_icon = asking and p.icon != null and p.ddragon.len > 0;
        return h.div(.{ .class = "form" }, .{
            if (asking or settled) null else h.div(.{ .class = "box" }, .{
                if (a == .create) h.input(.{
                    .type = "text",
                    .placeholder = W.squad_name,
                    .aria_label = W.squad_name,
                    .autocomplete = "off",
                    .maxlength = "32",
                    .value = p.sname.slice(),
                    .on_input = h.on(p, .name_input),
                }) else null,
                h.input(.{
                    .type = "text",
                    .placeholder = W.hint,
                    .aria_label = W.id,
                    .autocomplete = "off",
                    .spellcheck = "false",
                    .value = p.q.slice(),
                    .on_input = h.on(p, .input),
                    .on_keydown = h.on(p, .key),
                }),
                button.view(h, .{ .v = .primary, .s = .s, .disabled = p.at == .waiting or !p.ready(), .on = h.on(p, .start) }, .{switch (a) {
                    .create => W.start,
                    .join => W.join,
                    else => W.leave,
                }}),
                if (a != .create) button.view(h, .{ .s = .s, .on = h.on(p, .cancel) }, .{W.cancel}) else null,
            }),
            if (show_icon) forget.iconImg(h, p.ddragon, p.icon.?, W.icon) else null,
            h.p(.{ .role = "status" }, .{p.line(h)}),
            if (asking) button.view(h, .{ .v = .primary, .s = .s, .on = h.on(p, .check) }, .{W.check}) else null,
        });
    }

    fn line(p: *const P, h: *H) ?tree.Text {
        const id = p.id.slice();
        const at: i64 = @divFloor(@mod(p.expires + @as(i64, p.tz_min) * 60, std.time.s_per_day), 60);
        return switch (p.at) {
            .idle => null,
            .waiting => if (p.icon != null) W.checking else W.contacting,
            .issued => W.issued.with(h, .{ .id = id, .at = at }),
            .mismatch => W.mismatch.with(h, .{ .id = id, .at = at }),
            .done => if (p.action == .leave) W.left else W.joined,
            .full => W.full,
            .gone => W.gone,
            .not_found => W.not_found,
            .opted_out => W.opted_out,
            .expired => W.expired,
            .down => W.down,
        };
    }
};

/// The member's review of the game: /game#id=Name%23TAG&game=MS
fn gameHref(a: std.mem.Allocator, id: []const u8, start_ms: i64) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    try out.writer.print("/game#{s}&game=", .{try homepage.idQuery(a, id)});
    try fmt.write(&out.writer, .int, start_ms);
    return out.written();
}

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t");
}

/// Name#TAG: something either side of one #
fn valid(id: []const u8) bool {
    const at = std.mem.findScalar(u8, id, '#') orelse return false;
    return at > 0 and at + 1 < id.len and std.mem.findScalar(u8, id[at + 1 ..], '#') == null;
}

pub const css =
    \\@layer components {
    \\  .c-squad { display: grid; gap: var(--sp-4); padding: var(--sp-4) 0; }
    \\  .c-squad h1 { margin: 0; }
    \\  .c-squad .start, .c-squad .head, .c-squad .act, .c-squad .form { display: grid; justify-items: start; gap: var(--sp-2); }
    \\  .c-squad .lead, .c-squad .msg, .c-squad p { margin: 0; color: var(--t2); max-width: 36rem; }
    \\  .c-squad p:empty { display: none; }
    \\  .c-squad .members { display: flex; flex-wrap: wrap; gap: var(--sp-1) var(--sp-3); }
    \\  .c-squad .rec { display: flex; align-items: baseline; gap: var(--sp-2); }
    \\  .c-squad .rec b { font-size: var(--fs-l); }
    \\  .c-squad .wl { color: var(--muted); font-variant-numeric: tabular-nums; }
    \\  .c-squad .games { display: grid; gap: var(--sp-2); padding: var(--sp-3) 0; }
    \\  .c-squad .game { display: grid; gap: var(--sp-2); padding: var(--sp-2) var(--sp-3); border-radius: var(--r-s); background: var(--s1); color: inherit; text-decoration: none; border-left: 3px solid var(--loss); }
    \\  .c-squad .game[data-win] { border-left-color: var(--win); }
    \\  .c-squad .meta { display: flex; flex-wrap: wrap; gap: var(--sp-3); color: var(--t2); font-size: var(--fs-s); }
    \\  .c-squad .meta b { color: var(--t1); }
    \\  .c-squad .seats { display: flex; flex-wrap: wrap; gap: var(--sp-2) var(--sp-5); }
    \\  .c-squad .seat { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-squad .who { display: inline-flex; align-items: center; gap: var(--sp-1); }
    \\  .c-squad .box, .c-squad .invite, .c-squad .row { display: flex; flex-wrap: wrap; gap: var(--sp-1); width: 100%; max-width: 36rem; align-items: center; }
    \\  .c-squad .box input, .c-squad .invite input { flex: 1; min-width: 10rem; }
    \\  .c-squad .why { color: var(--t2); font-size: var(--fs-s); }
    \\  .c-squad img { border-radius: var(--r-s); }
    \\}
    \\
;

pub const demo_data: Data = .{
    .state = .ready,
    .name = "Thursday flex",
    .members = &.{ .{ .riot_id = "MeioNeiz#EUW", .games = 60 }, .{ .riot_id = "Duo Partner#EUW", .games = 48 }, .{ .riot_id = "Third#EUW", .games = 12, .waiting = true } },
    .champs = &.{ .{ .name = "Ahri", .src = "" }, .{ .name = "Leona", .src = "" }, .{ .name = "Jinx", .src = "" } },
    .games = &.{
        .{ .start_ms = 1_793_000_000_000, .queue = .flex, .duration_s = 1834, .win = true, .seats = &.{ .{ .member = 0, .champ = 0, .role = .mid, .k = 8, .d = 2, .a = 7 }, .{ .member = 1, .champ = 1, .role = .support, .k = 1, .d = 4, .a = 15 } } },
        .{ .start_ms = 1_792_900_000_000, .queue = .draft, .duration_s = 1512, .win = false, .seats = &.{ .{ .member = 0, .champ = 2, .role = .bot, .k = 3, .d = 6, .a = 4 }, .{ .member = 1, .champ = 1, .role = .support, .k = 0, .d = 5, .a = 9 }, .{ .member = 2, .champ = 0, .role = .mid, .k = 4, .d = 4, .a = 2 } } },
    },
};

fn demoSquad(token: bool, data: ?*const Data, action: Squad.Action, at: Squad.At) Squad {
    var p: Squad = .{ .data = data, .load = if (data != null) .ready else .loading, .action = action, .at = at, .icon = 7, .expires = 1_793_050_439, .ddragon = "16.21.1", .now_ms = 1_793_010_000_000, .origin = "https://meio.lol" };
    if (token) p.token.set("AbCdEfGhIjKlMnOpQrStUv");
    p.q.set("MeioNeiz#EUW");
    p.id.set("MeioNeiz#EUW");
    return p;
}

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const none: Data = .{ .state = .none };
    const empty: Data = .{ .state = .ready, .name = "New squad", .members = &.{.{ .riot_id = "MeioNeiz#EUW" }} };
    const states = .{
        .{ "start", Squad{ .action = .create } },
        .{ "start, icon issued", demoSquad(false, null, .create, .issued) },
        .{ "loading", demoSquad(true, null, .none, .idle) },
        .{ "no squad", demoSquad(true, &none, .none, .idle) },
        .{ "new, no games", demoSquad(true, &empty, .none, .idle) },
        .{ "squad", demoSquad(true, &demo_data, .none, .idle) },
        .{ "joining", demoSquad(true, &demo_data, .join, .idle) },
        .{ "leave, icon not set yet", demoSquad(true, &demo_data, .leave, .mismatch) },
        .{ "joined", demoSquad(true, &demo_data, .join, .done) },
        .{ "full", demoSquad(true, &demo_data, .join, .full) },
    };
    inline for (states) |s| {
        const p = h.mem.create(Squad) catch {
            h.oom = true;
            return;
        };
        p.* = s[1];
        g.add(s[0], p.view(h));
    }
}

const testing = std.testing;

test answer {
    const a = answer("{\"state\":\"issued\",\"icon\":7,\"expires\":1793050439}").?;
    try testing.expectEqual(.issued, a.state);
    try testing.expectEqual(7, a.icon.?);
    const k = answer("{\"state\":\"pending\",\"k\":\"AbCdEfGhIjKlMnOpQrStUv\"}").?;
    try testing.expectEqualStrings("AbCdEfGhIjKlMnOpQrStUv", k.k.?);
    const d = answer("{\"state\":\"done\",\"icon\":7,\"expires\":5,\"s\":\"x_y\"}").?;
    try testing.expectEqualStrings("x_y", d.s.?);
    try testing.expectEqual(null, answer("{\"error\":\"busy\"}"));
}

test "start: name and Riot ID, the icon, check, done opens the new squad" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p: Squad = .{ .action = .create };
    var ev: tree.Event = .{ .kind = .click };
    p.q.set("A#1");
    p.update(.start, &ev);
    try testing.expectEqual(.none, p.want);
    p.sname.set(" Duo ");
    p.update(.start, &ev);
    try testing.expectEqual(.start, p.want);
    try testing.expectEqualStrings("/api/squad/check?id=A%231&do=create&name=Duo", try p.checkPath(a, .start));
    try testing.expect(p.answered(.{ .state = .pending, .k = "AbCdEfGhIjKlMnOpQrStUv" }));
    try testing.expect(!p.answered(.{ .state = .issued, .icon = 7, .expires = 100 }));
    p.want = .none;
    p.update(.check, &ev);
    try testing.expectEqual(.check, p.want);
    try testing.expectEqualStrings("/api/squad/check?id=A%231&k=AbCdEfGhIjKlMnOpQrStUv&check=1", try p.checkPath(a, .check));
    try testing.expect(!p.answered(.{ .state = .done, .s = "NewSquadTokenNewSquadT" }));
    try testing.expectEqualStrings("NewSquadTokenNewSquadT", p.started.slice());
}

test "join sends the squad's token; a failed fetch says so" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    var p: Squad = .{};
    p.token.set("AbCdEfGhIjKlMnOpQrStUv");
    var ev: tree.Event = .{ .kind = .click };
    p.update(.join, &ev);
    p.q.set("A#1");
    p.update(.start, &ev);
    try testing.expectEqualStrings("/api/squad/check?id=A%231&do=join&s=AbCdEfGhIjKlMnOpQrStUv", try p.checkPath(arena.allocator(), .start));
    try testing.expect(!p.answered(null));
    try testing.expectEqual(.down, p.at);
}

test gameHref {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    try testing.expectEqualStrings("/game#id=A%20b%231&game=1793000000000", try gameHref(arena.allocator(), "A b#1", 1_793_000_000_000));
}

test "loaded: polls while a member's games are coming" {
    var p: Squad = .{};
    try testing.expect(p.loaded(&demo_data));
    const done: Data = .{ .state = .ready, .members = &.{.{ .riot_id = "A#1" }} };
    try testing.expect(!p.loaded(&done));
    try testing.expect(!p.loaded(null));
    try testing.expectEqual(.down, p.load);
}
