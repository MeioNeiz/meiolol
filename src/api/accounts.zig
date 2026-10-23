//! accounts.db: logins for the private site, the admin pages and later the private app
//! (docs/plan/accounts.md). Own file beside api.db, so backups, erasure and migrations
//! stay apart from Riot data. Served by `meiolol api` under /auth/; nginx asks
//! /auth/check/CAP before /admin/ and /p/ (auth_request). Writes need the header
//! X-Meiolol-Action: 1, which a cross-site form cannot send.
//!
//!   POST /auth/login      {"username","password"}: sets the session cookie
//!   POST /auth/logout     ends this session; ?all=1 every session of the account
//!   GET  /auth/me         {"username","role","can":[...]}, or 401
//!   POST /auth/join       {"invite","username","password"}: a new account, or a new
//!                         password for a reset invite's account; signs in
//!   GET  /auth/check/CAP  204 with X-Meiolol-User and X-Meiolol-Role when the session's
//!                         role has CAP (roles.zig); 401 without a session, 403 without CAP

const std = @import("std");
const Io = std.Io;
const store = @import("store");
const core = @import("core");
const roles = @import("roles.zig");

const Allocator = std.mem.Allocator;
const Db = store.Db;
const Blob = store.Blob;
const Role = roles.Role;
const Capability = roles.Capability;
const Request = std.http.Server.Request;
const Status = std.http.Status;
const argon2 = std.crypto.pwhash.argon2;
const b64 = std.base64.url_safe_no_pad;

pub const schema =
    \\PRAGMA journal_mode = WAL;
    \\
    \\-- hash: argon2id PHC string. role: roles.Role's name. puuid: a linked Riot account
    \\-- (later, AC6)
    \\CREATE TABLE IF NOT EXISTS accounts (
    \\    id INTEGER PRIMARY KEY,
    \\    username TEXT NOT NULL UNIQUE,
    \\    hash TEXT NOT NULL,
    \\    role TEXT NOT NULL,
    \\    created INTEGER NOT NULL,
    \\    last_seen INTEGER,
    \\    disabled INTEGER NOT NULL DEFAULT 0,
    \\    puuid TEXT
    \\);
    \\
    \\-- hash: SHA-256 of the cookie's token, so a copy of the file holds no live session
    \\CREATE TABLE IF NOT EXISTS sessions (
    \\    hash BLOB PRIMARY KEY,
    \\    account INTEGER NOT NULL,
    \\    created INTEGER NOT NULL,
    \\    expires INTEGER NOT NULL
    \\) WITHOUT ROWID;
    \\CREATE INDEX IF NOT EXISTS sessions_account ON sessions(account);
    \\
    \\-- One use. account NULL: makes a new account with `role`; else sets that account's
    \\-- password (a reset). by: who made it
    \\CREATE TABLE IF NOT EXISTS invites (
    \\    hash BLOB PRIMARY KEY,
    \\    role TEXT NOT NULL,
    \\    account INTEGER,
    \\    by TEXT NOT NULL,
    \\    expires INTEGER NOT NULL
    \\) WITHOUT ROWID;
;

pub fn open(path: [:0]const u8) !Db {
    const db = try Db.open(path);
    errdefer db.close();
    try db.exec(schema);
    return db;
}

/// __Host-: the browser keeps it to this exact host, over HTTPS, for every path
pub const cookie_name = "__Host-meiolol";
const session_s: i64 = 30 * 24 * 60 * 60;
/// A session's expiry moves forward at most once a day, so a busy one writes little
const renew_after_s: i64 = 24 * 60 * 60;
const invite_s: i64 = 7 * 24 * 60 * 60;
const token_bytes = 32;
pub const token_len = b64.Encoder.calcSize(token_bytes);
pub const Token = [token_len]u8;
const max_body = 4096;
pub const password_min = 8;
pub const password_max = 256;
pub const username_max = 32;

/// Lower case letters, digits, '.', '_' and '-', 2 to 32 long, lower-cased into `buf`;
/// null otherwise
pub fn username(buf: *[username_max]u8, name: []const u8) ?[]const u8 {
    if (name.len < 2 or name.len > username_max) return null;
    for (name, 0..) |ch, i| {
        const l = std.ascii.toLower(ch);
        if (!std.ascii.isAlphanumeric(l) and l != '.' and l != '_' and l != '-') return null;
        buf[i] = l;
    }
    return buf[0..name.len];
}

pub fn passwordOk(password: []const u8) bool {
    return password.len >= password_min and password.len <= password_max;
}

fn newToken(io: Io) !Token {
    var raw: [token_bytes]u8 = undefined;
    try io.randomSecure(&raw);
    var t: Token = undefined;
    _ = b64.Encoder.encode(&t, &raw);
    return t;
}

fn tokenHash(token: []const u8) [32]u8 {
    var h: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(token, &h, .{});
    return h;
}

/// A token as the cookie or an invite link carries it; null for anything else
fn parseToken(s: []const u8) ?[]const u8 {
    if (s.len != token_len) return null;
    for (s) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '-' and ch != '_') return null;
    return s;
}

/// Password hashing, one at a time: jomify's api unit has a 400 MB cap
pub const Hasher = struct {
    mutex: Io.Mutex = .init,
    /// OWASP's argon2id minimum (19 MiB, 2 passes); tests use less. The PHC string
    /// stores them, so verify follows whatever a hash was made with
    params: argon2.Params = .owasp_2id,

    pub fn hash(h: *Hasher, gpa: Allocator, io: Io, password: []const u8, out: *[128]u8) ![]const u8 {
        h.mutex.lockUncancelable(io);
        defer h.mutex.unlock(io);
        return argon2.strHash(password, .{ .allocator = gpa, .params = h.params }, out, io);
    }

    pub fn verify(h: *Hasher, gpa: Allocator, io: Io, phc: []const u8, password: []const u8) !bool {
        h.mutex.lockUncancelable(io);
        defer h.mutex.unlock(io);
        argon2.strVerify(phc, password, .{ .allocator = gpa }, io) catch |err| switch (err) {
            error.PasswordVerificationFailed => return false,
            else => return err,
        };
        return true;
    }
};

pub const Account = struct { id: i64, username: []const u8, role: Role };

pub const Error = error{ Taken, OwnerExists, BadRole } || store.sqlite.Error;

/// Exactly one owner: a second is refused
pub fn create(db: Db, name: []const u8, phc: []const u8, role: Role, now: i64) Error!i64 {
    if (role == .owner and try ownerCount(db) > 0) return error.OwnerExists;
    if (try db.scalar("SELECT id FROM accounts WHERE username = ?", .{name}) != null) return error.Taken;
    try db.run("INSERT INTO accounts (username, hash, role, created) VALUES (?, ?, ?, ?)", .{ name, phc, @tagName(role), now });
    return (try db.scalar("SELECT id FROM accounts WHERE username = ?", .{name})).?;
}

fn ownerCount(db: Db) !i64 {
    return try db.scalar("SELECT count(*) FROM accounts WHERE role = 'owner'", .{}) orelse 0;
}

/// Also signs the account out everywhere
pub fn setPassword(db: Db, id: i64, phc: []const u8) !void {
    try db.run("UPDATE accounts SET hash = ? WHERE id = ?", .{ phc, id });
    try endAll(db, id);
}

pub fn setRole(db: Db, id: i64, role: Role) Error!void {
    if (role == .owner and try ownerCount(db) > 0) return error.OwnerExists;
    try db.run("UPDATE accounts SET role = ? WHERE id = ?", .{ @tagName(role), id });
}

/// Disabling also signs the account out everywhere
pub fn setDisabled(db: Db, id: i64, disabled: bool) !void {
    try db.run("UPDATE accounts SET disabled = ? WHERE id = ?", .{ disabled, id });
    if (disabled) try endAll(db, id);
}

/// The account, its sessions and its reset invites: nothing of it stays (a friend's erasure)
pub fn remove(db: Db, id: i64) !void {
    try db.begin();
    errdefer db.rollback();
    try endAll(db, id);
    try db.run("DELETE FROM invites WHERE account = ?", .{id});
    try db.run("DELETE FROM accounts WHERE id = ?", .{id});
    try db.commit();
}

pub const Stored = struct { id: i64, username: []const u8, hash: []const u8, role: Role, disabled: bool };

/// Strings in `arena`
pub fn find(db: Db, arena: Allocator, name: []const u8) !?Stored {
    var q = try db.prepare("SELECT id, username, hash, role, disabled FROM accounts WHERE username = ?");
    defer q.deinit();
    try q.bind(.{name});
    if (!try q.step()) return null;
    const r = q.row(struct { id: i64, username: []const u8, hash: []const u8, role: []const u8, disabled: bool });
    return .{
        .id = r.id,
        .username = try arena.dupe(u8, r.username),
        .hash = try arena.dupe(u8, r.hash),
        .role = Role.parse(r.role) orelse return error.BadRole,
        .disabled = r.disabled,
    };
}

pub fn startSession(db: Db, io: Io, account: i64, now: i64) !Token {
    const t = try newToken(io);
    const h = tokenHash(&t);
    try db.run("INSERT INTO sessions VALUES (?, ?, ?, ?)", .{ Blob{ .bytes = &h }, account, now, now + session_s });
    try db.run("UPDATE accounts SET last_seen = ? WHERE id = ?", .{ now, account });
    return t;
}

/// The signed-in account, its session renewed; null for a missing, expired or disabled
/// one. Strings in `arena`
pub fn session(db: Db, arena: Allocator, token: []const u8, now: i64) !?Account {
    const h = tokenHash(token);
    var q = try db.prepare(
        \\SELECT a.id, a.username, a.role, s.expires FROM sessions s JOIN accounts a ON a.id = s.account
        \\WHERE s.hash = ? AND s.expires > ? AND a.disabled = 0
    );
    defer q.deinit();
    try q.bind(.{ Blob{ .bytes = &h }, now });
    if (!try q.step()) return null;
    const r = q.row(struct { id: i64, username: []const u8, role: []const u8, expires: i64 });
    const a: Account = .{ .id = r.id, .username = try arena.dupe(u8, r.username), .role = Role.parse(r.role) orelse return error.BadRole };
    const expires = r.expires;
    q.reset();
    if (now + session_s - expires >= renew_after_s) {
        try db.run("UPDATE sessions SET expires = ? WHERE hash = ?", .{ now + session_s, Blob{ .bytes = &h } });
        try db.run("UPDATE accounts SET last_seen = ? WHERE id = ?", .{ now, a.id });
    }
    return a;
}

pub fn endSession(db: Db, token: []const u8) !void {
    const h = tokenHash(token);
    try db.run("DELETE FROM sessions WHERE hash = ?", .{Blob{ .bytes = &h }});
}

pub fn endAll(db: Db, account: i64) !void {
    try db.run("DELETE FROM sessions WHERE account = ?", .{account});
}

/// account null: an invite for a new account with `role`; else a reset of that
/// account's password (role unused)
pub fn makeInvite(db: Db, io: Io, role: Role, account: ?i64, by: []const u8, now: i64) !Token {
    const t = try newToken(io);
    const h = tokenHash(&t);
    try db.run("DELETE FROM invites WHERE expires <= ?", .{now});
    try db.run("INSERT INTO invites VALUES (?, ?, ?, ?, ?)", .{ Blob{ .bytes = &h }, @tagName(role), account, by, now + invite_s });
    return t;
}

pub const Invite = struct { role: Role, account: ?i64 };

/// A live invite; `take` also uses it up
fn invite(db: Db, token: []const u8, now: i64, take: bool) !?Invite {
    const h = tokenHash(token);
    var q = try db.prepare("SELECT role, account FROM invites WHERE hash = ? AND expires > ?");
    defer q.deinit();
    try q.bind(.{ Blob{ .bytes = &h }, now });
    if (!try q.step()) return null;
    const r = q.row(struct { role: []const u8, account: ?i64 });
    const inv: Invite = .{ .role = Role.parse(r.role) orelse return error.BadRole, .account = r.account };
    q.reset();
    if (take) try db.run("DELETE FROM invites WHERE hash = ?", .{Blob{ .bytes = &h }});
    return inv;
}

/// Failed logins, in memory (no IPs kept). After `free_fails` for a username each try
/// waits a minute, doubling to an hour, until one succeeds; past `max_per_minute` fails
/// across all usernames, everyone waits for the next minute
pub const Throttle = struct {
    mutex: Io.Mutex = .init,
    /// Keys gpa-owned
    users: std.StringHashMapUnmanaged(Fails) = .empty,
    minute: i64 = 0,
    minute_fails: u32 = 0,

    const Fails = struct { count: u32, last: i64 };
    pub const free_fails = 5;
    pub const max_per_minute = 30;
    const max_users = 10_000;
    const max_wait_s = 60 * 60;

    pub fn deinit(t: *Throttle, gpa: Allocator) void {
        var it = t.users.keyIterator();
        while (it.next()) |k| gpa.free(k.*);
        t.users.deinit(gpa);
    }

    /// Seconds until `name` may try again; 0 now
    pub fn wait(t: *Throttle, io: Io, name: []const u8, now: i64) i64 {
        t.mutex.lockUncancelable(io);
        defer t.mutex.unlock(io);
        if (t.minute == @divFloor(now, 60) and t.minute_fails >= max_per_minute) return 60 - @mod(now, 60);
        const f = t.users.get(name) orelse return if (t.users.count() >= max_users) 60 else 0;
        if (f.count < free_fails) return 0;
        const lock = @min(@as(i64, 60) << @intCast(@min(f.count - free_fails, 6)), max_wait_s);
        return @max(f.last + lock - now, 0);
    }

    pub fn failed(t: *Throttle, gpa: Allocator, io: Io, name: []const u8, now: i64) !void {
        t.mutex.lockUncancelable(io);
        defer t.mutex.unlock(io);
        if (t.minute != @divFloor(now, 60)) {
            t.minute = @divFloor(now, 60);
            t.minute_fails = 0;
        }
        t.minute_fails += 1;
        if (t.users.getPtr(name)) |f| {
            f.count += 1;
            f.last = now;
            return;
        }
        if (t.users.count() >= max_users) t.forget(gpa, now - max_wait_s);
        if (t.users.count() >= max_users) return;
        const key = try gpa.dupe(u8, name);
        errdefer gpa.free(key);
        try t.users.put(gpa, key, .{ .count = 1, .last = now });
    }

    pub fn succeeded(t: *Throttle, gpa: Allocator, io: Io, name: []const u8) void {
        t.mutex.lockUncancelable(io);
        defer t.mutex.unlock(io);
        if (t.users.fetchRemove(name)) |kv| gpa.free(kv.key);
    }

    /// Drops usernames whose last fail is before `before`
    fn forget(t: *Throttle, gpa: Allocator, before: i64) void {
        var stale: std.ArrayList([]const u8) = .empty;
        defer stale.deinit(gpa);
        var it = t.users.iterator();
        while (it.next()) |e| if (e.value_ptr.last < before) stale.append(gpa, e.key_ptr.*) catch break;
        for (stale.items) |k| {
            _ = t.users.remove(k);
            gpa.free(k);
        }
    }
};

/// One /auth/ request, read off the wire: what route() needs
pub const In = struct {
    method: std.http.Method,
    /// After /auth/
    path: []const u8,
    query: []const u8 = "",
    /// The session cookie's token, when it is well formed
    token: ?[]const u8 = null,
    /// X-Meiolol-Action: 1
    action: bool = false,
    body: []const u8 = "",
};

pub const Out = struct {
    status: Status,
    body: []const u8 = "",
    set_cookie: ?[]const u8 = null,
    user: ?[]const u8 = null,
    role: ?Role = null,
};

pub const Service = struct {
    gpa: Allocator,
    io: Io,
    db_path: [:0]const u8,
    hasher: Hasher = .{},
    throttle: Throttle = .{},

    pub fn deinit(s: *Service) void {
        s.throttle.deinit(s.gpa);
    }

    /// Answers a request whose path starts /auth/
    pub fn handle(s: *Service, request: *Request) !void {
        var arena_state: std.heap.ArenaAllocator = .init(s.gpa);
        defer arena_state.deinit();
        const arena = arena_state.allocator();
        // Reading the body invalidates the head's strings: copy what route() needs first
        const target = try arena.dupe(u8, request.head.target);
        const q = std.mem.findScalar(u8, target, '?') orelse target.len;
        var in: In = .{
            .method = request.head.method,
            .path = target["/auth/".len..q],
            .query = if (q < target.len) target[q + 1 ..] else "",
            .token = if (cookieToken(request)) |t| try arena.dupe(u8, t) else null,
            .action = if (header(request, "x-meiolol-action")) |v| std.mem.eql(u8, v, "1") else false,
        };
        if (in.method == .POST and in.action) {
            var body_buf: [1024]u8 = undefined;
            const r = try request.readerExpectContinue(&body_buf);
            in.body = r.allocRemaining(arena, .limited(max_body)) catch |err| switch (err) {
                error.StreamTooLong => return respond(request, .{ .status = .payload_too_large, .body = errorJson("too long") }, false),
                else => return err,
            };
        }
        const now = Io.Clock.real.now(s.io).toSeconds();
        const out = try s.route(arena, in, now);
        try respond(request, out, true);
    }

    pub fn route(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const post = in.method == .POST;
        const Route = enum { login, logout, me, join };
        const not_found: Out = .{ .status = .not_found, .body = errorJson("not found") };
        if (std.mem.startsWith(u8, in.path, "check/")) {
            if (in.method != .GET) return notAllowed();
            const cap = Capability.parse(in.path["check/".len..]) orelse return .{ .status = .not_found, .body = errorJson("no such capability") };
            const a = try s.signedIn(arena, in, now) orelse return .{ .status = .unauthorized };
            if (!a.role.can(cap)) return .{ .status = .forbidden };
            return .{ .status = .no_content, .user = a.username, .role = a.role };
        }
        const r = std.meta.stringToEnum(Route, in.path) orelse return not_found;
        if (post != (r != .me)) return notAllowed();
        if (post and !in.action) return .{ .status = .forbidden, .body = errorJson("missing X-Meiolol-Action") };
        return switch (r) {
            .login => s.login(arena, in, now),
            .logout => s.logout(arena, in, now),
            .me => {
                const a = try s.signedIn(arena, in, now) orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
                return .{ .status = .ok, .body = try accountJson(arena, a) };
            },
            .join => s.join(arena, in, now),
        };
    }

    fn signedIn(s: *Service, arena: Allocator, in: In, now: i64) !?Account {
        const token = in.token orelse return null;
        const db = try open(s.db_path);
        defer db.close();
        return session(db, arena, token, now);
    }

    fn login(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const Body = struct { username: []const u8, password: []const u8 };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with username and password") };
        const wrong: Out = .{ .status = .unauthorized, .body = errorJson("wrong username or password") };
        var name_buf: [username_max]u8 = undefined;
        const name = username(&name_buf, b.username) orelse return wrong;
        const wait = s.throttle.wait(s.io, name, now);
        if (wait > 0) return .{ .status = .too_many_requests, .body = try std.json.Stringify.valueAlloc(arena, .{ .@"error" = "too many tries", .retry_s = wait }, .{}) };

        const db = try open(s.db_path);
        defer db.close();
        const stored = try find(db, arena, name);
        const ok = if (stored) |a|
            !a.disabled and try s.hasher.verify(s.gpa, s.io, a.hash, b.password)
        else blk: {
            // As long as a real check, so timing doesn't tell which usernames exist
            var out: [128]u8 = undefined;
            _ = try s.hasher.hash(s.gpa, s.io, b.password, &out);
            break :blk false;
        };
        if (!ok) {
            try s.throttle.failed(s.gpa, s.io, name, now);
            return wrong;
        }
        s.throttle.succeeded(s.gpa, s.io, name);
        const a = stored.?;
        const t = try startSession(db, s.io, a.id, now);
        return .{ .status = .ok, .body = try accountJson(arena, .{ .id = a.id, .username = a.username, .role = a.role }), .set_cookie = try sessionCookie(arena, &t) };
    }

    fn logout(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const out: Out = .{ .status = .ok, .body = "{\"ok\":true}", .set_cookie = cookie_name ++ "=; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Lax" };
        const token = in.token orelse return out;
        const db = try open(s.db_path);
        defer db.close();
        const all = std.mem.eql(u8, in.query, "all=1");
        if (all) if (try session(db, arena, token, now)) |a| try endAll(db, a.id);
        try endSession(db, token);
        return out;
    }

    fn join(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const Body = struct { invite: []const u8, username: []const u8 = "", password: []const u8 };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with invite, username and password") };
        const bad_invite: Out = .{ .status = .bad_request, .body = errorJson("this invite link has been used or has expired") };
        const token = parseToken(b.invite) orelse return bad_invite;
        if (!passwordOk(b.password)) return .{ .status = .bad_request, .body = errorJson("password must be 8 to 256 characters") };

        const db = try open(s.db_path);
        defer db.close();
        const peek = try invite(db, token, now, false) orelse return bad_invite;
        var name_buf: [username_max]u8 = undefined;
        const name: ?[]const u8 = if (peek.account == null)
            username(&name_buf, b.username) orelse return .{ .status = .bad_request, .body = errorJson("username: 2 to 32 letters, digits, dots, dashes or underscores") }
        else
            null;
        // Before the transaction: argon2 takes a while
        var phc_buf: [128]u8 = undefined;
        const phc = try s.hasher.hash(s.gpa, s.io, b.password, &phc_buf);

        try db.begin();
        errdefer db.rollback();
        // Used up meanwhile by another request
        const inv = try invite(db, token, now, true) orelse {
            db.rollback();
            return bad_invite;
        };
        const id = if (inv.account) |id| id: {
            try setPassword(db, id, phc);
            break :id id;
        } else create(db, name.?, phc, inv.role, now) catch |err| switch (err) {
            error.Taken => {
                db.rollback();
                return .{ .status = .conflict, .body = errorJson("that username is taken") };
            },
            else => return err,
        };
        try db.commit();
        const t = try startSession(db, s.io, id, now);
        const a = try session(db, arena, &t, now) orelse return error.Unexpected;
        return .{ .status = .ok, .body = try accountJson(arena, a), .set_cookie = try sessionCookie(arena, &t) };
    }
};

fn notAllowed() Out {
    return .{ .status = .method_not_allowed, .body = errorJson("method not allowed") };
}

/// Messages hold no characters JSON would escape
fn errorJson(comptime message: []const u8) []const u8 {
    return "{\"error\":\"" ++ message ++ "\"}";
}

/// null for anything but a JSON object with string fields T names
fn parseBody(comptime T: type, arena: Allocator, body: []const u8) ?T {
    return std.json.parseFromSliceLeaky(T, arena, body, .{ .ignore_unknown_fields = true }) catch null;
}

fn accountJson(arena: Allocator, a: Account) ![]const u8 {
    var can: std.ArrayList([]const u8) = .empty;
    for (std.enums.values(Capability)) |cap| if (a.role.can(cap)) try can.append(arena, @tagName(cap));
    return std.json.Stringify.valueAlloc(arena, .{ .username = a.username, .role = @tagName(a.role), .can = can.items }, .{});
}

fn sessionCookie(arena: Allocator, token: []const u8) ![]const u8 {
    return arena.print(cookie_name ++ "={s}; Path=/; Max-Age={d}; Secure; HttpOnly; SameSite=Lax", .{ token, session_s });
}

fn respond(request: *Request, out: Out, keep_alive: bool) !void {
    var headers: [5]std.http.Header = undefined;
    var n: usize = 0;
    headers[n] = .{ .name = "cache-control", .value = "no-store" };
    n += 1;
    if (out.body.len > 0) {
        headers[n] = .{ .name = "content-type", .value = "application/json" };
        n += 1;
    }
    if (out.set_cookie) |c| {
        headers[n] = .{ .name = "set-cookie", .value = c };
        n += 1;
    }
    if (out.user) |u| {
        headers[n] = .{ .name = "x-meiolol-user", .value = u };
        n += 1;
    }
    if (out.role) |r| {
        headers[n] = .{ .name = "x-meiolol-role", .value = @tagName(r) };
        n += 1;
    }
    try request.respond(out.body, .{ .status = out.status, .keep_alive = keep_alive, .extra_headers = headers[0..n] });
}

/// The header's value; null when absent or sent more than once
fn header(request: *Request, name: []const u8) ?[]const u8 {
    var found: ?[]const u8 = null;
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, name)) continue;
        if (found != null) return null;
        found = h.value;
    }
    return found;
}

/// The session cookie's token from any Cookie header; null when absent or malformed
fn cookieToken(request: *Request) ?[]const u8 {
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, "cookie")) continue;
        if (cookieValue(h.value)) |t| return t;
    }
    return null;
}

fn cookieValue(cookies: []const u8) ?[]const u8 {
    var parts = std.mem.splitScalar(u8, cookies, ';');
    while (parts.next()) |part| {
        const p = std.mem.trim(u8, part, " ");
        if (p.len > cookie_name.len and std.mem.startsWith(u8, p, cookie_name) and p[cookie_name.len] == '=') {
            return parseToken(p[cookie_name.len + 1 ..]);
        }
    }
    return null;
}

const testing = std.testing;

/// A scratch accounts.db with one account per role (password "password-<role>") and a
/// Service on it with cheap argon2 settings
const Fixture = struct {
    arena_state: std.heap.ArenaAllocator,
    tmp: testing.TmpDir,
    service: Service,
    db: Db,

    const now: i64 = 1_800_000_000;
    const cheap: argon2.Params = .{ .t = 1, .m = 64, .p = 1 };

    fn init(f: *Fixture) !void {
        f.arena_state = .init(testing.allocator);
        const a = f.arena_state.allocator();
        f.tmp = testing.tmpDir(.{});
        const path = try a.printSentinel(".zig-cache/tmp/{s}/accounts.db", .{&f.tmp.sub_path}, 0);
        f.service = .{ .gpa = testing.allocator, .io = testing.io, .db_path = path, .hasher = .{ .params = cheap } };
        f.db = try open(path);
        for (std.enums.values(Role)) |role| {
            var out: [128]u8 = undefined;
            const pw = try a.print("password-{t}", .{role});
            _ = try create(f.db, @tagName(role), try f.service.hasher.hash(testing.allocator, testing.io, pw, &out), role, now);
        }
    }

    fn deinit(f: *Fixture) void {
        f.db.close();
        f.service.deinit();
        f.tmp.cleanup();
        f.arena_state.deinit();
    }

    fn arena(f: *Fixture) Allocator {
        return f.arena_state.allocator();
    }

    fn login(f: *Fixture, name: []const u8, password: []const u8) !Out {
        const body = try std.json.Stringify.valueAlloc(f.arena(), .{ .username = name, .password = password }, .{});
        return f.service.route(f.arena(), .{ .method = .POST, .path = "login", .action = true, .body = body }, now);
    }

    /// The token a successful login's cookie carries
    fn signIn(f: *Fixture, role: Role) ![]const u8 {
        const out = try f.login(@tagName(role), try f.arena().print("password-{t}", .{role}));
        try testing.expectEqual(Status.ok, out.status);
        return cookieValue(out.set_cookie.?).?;
    }

    fn check(f: *Fixture, token: ?[]const u8, cap: []const u8) !Status {
        const path = try f.arena().print("check/{s}", .{cap});
        return (try f.service.route(f.arena(), .{ .method = .GET, .path = path, .token = token }, now)).status;
    }
};

test "check: every capability against every role, and without a session" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    for (std.enums.values(Capability)) |cap| {
        try testing.expectEqual(Status.unauthorized, try f.check(null, @tagName(cap)));
        for (std.enums.values(Role)) |role| {
            const token = try f.signIn(role);
            const want: Status = if (role.can(cap)) .no_content else .forbidden;
            try testing.expectEqual(want, try f.check(token, @tagName(cap)));
        }
    }
    const token = try f.signIn(.admin);
    try testing.expectEqual(Status.not_found, try f.check(token, "fly"));
    const out = try f.service.route(f.arena(), .{ .method = .GET, .path = "check/view_admin", .token = token }, Fixture.now);
    try testing.expectEqualStrings("admin", out.user.?);
    try testing.expectEqual(Role.admin, out.role.?);
}

test "routes: methods and the action header" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const now = Fixture.now;
    for ([_][]const u8{ "login", "logout", "join" }) |p| {
        try testing.expectEqual(Status.method_not_allowed, (try f.service.route(a, .{ .method = .GET, .path = p }, now)).status);
        try testing.expectEqual(Status.forbidden, (try f.service.route(a, .{ .method = .POST, .path = p }, now)).status);
    }
    try testing.expectEqual(Status.method_not_allowed, (try f.service.route(a, .{ .method = .POST, .path = "me", .action = true }, now)).status);
    try testing.expectEqual(Status.method_not_allowed, (try f.service.route(a, .{ .method = .POST, .path = "check/view_admin", .action = true }, now)).status);
    try testing.expectEqual(Status.not_found, (try f.service.route(a, .{ .method = .GET, .path = "nope" }, now)).status);
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "me" }, now)).status);
}

test "login: the cookie, me, wrong passwords, disabled accounts, logout" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const now = Fixture.now;
    const out = try f.login("Private", "password-private");
    try testing.expectEqual(Status.ok, out.status);
    const c = out.set_cookie.?;
    try testing.expectStringStartsWith(c, cookie_name ++ "=");
    for ([_][]const u8{ "; Path=/", "; Secure", "; HttpOnly", "; SameSite=Lax", "; Max-Age=2592000" }) |attr| {
        try testing.expect(std.mem.find(u8, c, attr) != null);
    }
    const token = cookieValue(c).?;
    const me = try f.service.route(a, .{ .method = .GET, .path = "me", .token = token }, now);
    try testing.expectEqual(Status.ok, me.status);
    try testing.expectEqualStrings("{\"username\":\"private\",\"role\":\"private\",\"can\":[\"view_paid\",\"view_private\",\"download_private_app\"]}", me.body);

    try testing.expectEqual(Status.unauthorized, (try f.login("private", "password-admin")).status);
    try testing.expectEqual(Status.unauthorized, (try f.login("nobody", "password-admin")).status);
    try testing.expectEqual(Status.bad_request, (try f.service.route(a, .{ .method = .POST, .path = "login", .action = true, .body = "{\"username\":1}" }, now)).status);

    // Expired, then renewed on use
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = token }, now + session_s)).status);
    try testing.expectEqual(Status.ok, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = token }, now + 2 * renew_after_s)).status);
    try testing.expectEqual(Status.ok, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = token }, now + session_s + renew_after_s)).status);

    const id = (try find(f.db, a, "private")).?.id;
    try setDisabled(f.db, id, true);
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = token }, now)).status);
    try testing.expectEqual(Status.unauthorized, (try f.login("private", "password-private")).status);
    try setDisabled(f.db, id, false);

    const t1 = try f.signIn(.private);
    const t2 = try f.signIn(.private);
    const lo = try f.service.route(a, .{ .method = .POST, .path = "logout", .action = true, .token = t1 }, now);
    try testing.expectEqual(Status.ok, lo.status);
    try testing.expect(std.mem.find(u8, lo.set_cookie.?, "Max-Age=0") != null);
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = t1 }, now)).status);
    try testing.expectEqual(Status.ok, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = t2 }, now)).status);
    const t3 = try f.signIn(.private);
    _ = try f.service.route(a, .{ .method = .POST, .path = "logout", .query = "all=1", .action = true, .token = t3 }, now);
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = t2 }, now)).status);
}

test "login: slower after five fails for a username, and for everyone past the minute's cap" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    for (0..Throttle.free_fails) |_| try testing.expectEqual(Status.unauthorized, (try f.login("admin", "guess")).status);
    // Locked even with the right password, others unaffected
    try testing.expectEqual(Status.too_many_requests, (try f.login("admin", "password-admin")).status);
    try testing.expectEqual(Status.ok, (try f.login("owner", "password-owner")).status);
    try testing.expectEqual(60, f.service.throttle.wait(testing.io, "admin", Fixture.now));
    try testing.expectEqual(0, f.service.throttle.wait(testing.io, "admin", Fixture.now + 60));

    var t: Throttle = .{};
    defer t.deinit(testing.allocator);
    const now: i64 = 6_000;
    for (0..Throttle.max_per_minute) |i| try t.failed(testing.allocator, testing.io, try f.arena().print("u{d}", .{i}), now);
    try testing.expectEqual(60, t.wait(testing.io, "someone", now));
    try testing.expectEqual(0, t.wait(testing.io, "someone", now + 60));
}

test "join: an invite makes one account, once; a reset invite sets a password" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const now = Fixture.now;
    const inv = try makeInvite(f.db, testing.io, .private, null, "owner", now);
    const body = try std.json.Stringify.valueAlloc(a, .{ .invite = &inv, .username = "Friend", .password = "long enough" }, .{});
    const out = try f.service.route(a, .{ .method = .POST, .path = "join", .action = true, .body = body }, now);
    try testing.expectEqual(Status.ok, out.status);
    try testing.expect(std.mem.find(u8, out.body, "\"role\":\"private\"") != null);
    try testing.expectEqual(Status.ok, (try f.login("friend", "long enough")).status);
    // Used up
    try testing.expectEqual(Status.bad_request, (try f.service.route(a, .{ .method = .POST, .path = "join", .action = true, .body = body }, now)).status);

    const late = try makeInvite(f.db, testing.io, .private, null, "owner", now);
    const late_body = try std.json.Stringify.valueAlloc(a, .{ .invite = &late, .username = "other", .password = "long enough" }, .{});
    try testing.expectEqual(Status.bad_request, (try f.service.route(a, .{ .method = .POST, .path = "join", .action = true, .body = late_body }, now + invite_s)).status);

    const taken = try makeInvite(f.db, testing.io, .private, null, "owner", now);
    const taken_body = try std.json.Stringify.valueAlloc(a, .{ .invite = &taken, .username = "friend", .password = "long enough" }, .{});
    try testing.expectEqual(Status.conflict, (try f.service.route(a, .{ .method = .POST, .path = "join", .action = true, .body = taken_body }, now)).status);
    // Not used up by the clash
    try testing.expect(try invite(f.db, &taken, now, false) != null);

    const old = try f.signIn(.admin);
    const reset = try makeInvite(f.db, testing.io, .public, (try find(f.db, a, "admin")).?.id, "owner", now);
    const reset_body = try std.json.Stringify.valueAlloc(a, .{ .invite = &reset, .password = "a new one!" }, .{});
    const r = try f.service.route(a, .{ .method = .POST, .path = "join", .action = true, .body = reset_body }, now);
    try testing.expectEqual(Status.ok, r.status);
    try testing.expect(std.mem.find(u8, r.body, "\"role\":\"admin\"") != null);
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "me", .token = old }, now)).status);
    try testing.expectEqual(Status.ok, (try f.login("admin", "a new one!")).status);
}

test "one owner" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.expectError(error.OwnerExists, create(f.db, "second", "x", .owner, 0));
    try testing.expectError(error.OwnerExists, setRole(f.db, 1, .owner));
    try testing.expectError(error.Taken, create(f.db, "admin", "x", .admin, 0));
}

test remove {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const token = try f.signIn(.private);
    const id = (try find(f.db, f.arena(), "private")).?.id;
    _ = try makeInvite(f.db, testing.io, .private, id, "owner", Fixture.now);
    try remove(f.db, id);
    try testing.expectEqual(null, try find(f.db, f.arena(), "private"));
    try testing.expectEqual(0, try f.db.scalar("SELECT count(*) FROM invites", .{}));
    try testing.expectEqual(Status.unauthorized, try f.check(token, "view_paid"));
}

test username {
    var buf: [username_max]u8 = undefined;
    try testing.expectEqualStrings("jacob.m_1-x", username(&buf, "Jacob.M_1-x").?);
    try testing.expectEqual(null, username(&buf, "a"));
    try testing.expectEqual(null, username(&buf, "has space"));
    try testing.expectEqual(null, username(&buf, &@as([33]u8, @splat('x'))));
}

test cookieValue {
    const t: Token = @splat('A');
    try testing.expectEqualStrings(&t, cookieValue("a=b; " ++ cookie_name ++ "=" ++ t ++ "; c=d").?);
    try testing.expectEqual(null, cookieValue(cookie_name ++ "=short"));
    try testing.expectEqual(null, cookieValue(cookie_name ++ "x=" ++ t));
    try testing.expectEqual(null, cookieValue(cookie_name ++ "=" ++ t[1..] ++ "!"));
}

fn fuzzLogin(f: *Fixture, s: *testing.Smith) !void {
    var arena_state: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const body = try core.fuzz.mutate(s, arena, "{\"username\":\"owner\",\"password\":\"password-owner\",\"x\":[1]}");
    const out = try f.service.route(arena, .{ .method = .POST, .path = "login", .action = true, .body = body }, Fixture.now);
    try testing.expect(out.status == .ok or out.status == .bad_request or out.status == .unauthorized or out.status == .too_many_requests);
}

test "fuzz: a damaged login body is a 400 or 401, never a crash" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.fuzz(&f, fuzzLogin, .{});
}
