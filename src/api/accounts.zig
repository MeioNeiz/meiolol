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
//!   POST /auth/signup     {"link","email","password"}: a new account through a sign-up
//!                         link, whose password is the link's shared one; signs in
//!   GET  /auth/check/CAP  204 with X-Meiolol-User and X-Meiolol-Role when the session's
//!                         role has CAP (roles.zig); 401 without a session, 403 without CAP
//!   POST /auth/password   {"password","new"}: a new password for the signed-in account;
//!                         signs it out everywhere else
//!   POST /auth/device     {"username","password","name"}: {"token",...} for the
//!                         desktop app (AC4), checked and throttled as a login; needs
//!                         download_private_app. No cookie: the app sends the token as
//!                         Authorization: Bearer, which check/CAP (Capability.forDevices
//!                         only), me and logout (ends that device) accept, nothing else
//!   GET  /auth/devices    the signed-in account's:
//!                         {"devices":[{"id","name","created","last_used"}]}
//!   POST /auth/revoke     {"id"}: ends one of them
//!
//! With manage_accounts, on accounts whose role the signed-in one may manage
//! (Role.canManage), else 403:
//!
//!   GET  /auth/accounts   {"accounts":[...],"roles":[roles it may give]}
//!   POST /auth/invite     {"role"}: {"invite":TOKEN}, a one-use link for a new account
//!   POST /auth/role       {"username","role"}
//!   POST /auth/disable    {"username","disabled"}: disabling signs it out everywhere
//!   POST /auth/reset      {"username"}: {"invite":TOKEN}, a one-use link to set its password

const std = @import("std");
const Io = std.Io;
const store = @import("store");
const core = @import("core");
const roles = @import("roles.zig");
const notes_marker = @import("ui").notesdata.marker;

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
    \\-- The desktop app's sign-ins, one per install. hash: SHA-256 of the bearer token.
    \\-- Renewed as sessions are, so last used = expires - 90 days, to the day
    \\CREATE TABLE IF NOT EXISTS devices (
    \\    id INTEGER PRIMARY KEY,
    \\    hash BLOB NOT NULL UNIQUE,
    \\    account INTEGER NOT NULL,
    \\    name TEXT NOT NULL,
    \\    created INTEGER NOT NULL,
    \\    expires INTEGER NOT NULL
    \\);
    \\CREATE INDEX IF NOT EXISTS devices_account ON devices(account);
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
    \\
    \\-- Many uses, until revoked: anyone with the link and its shared password (secret:
    \\-- argon2id PHC) makes an account with `role`, the email as username (Jacob 23 Oct, for
    \\-- admins)
    \\CREATE TABLE IF NOT EXISTS signup_links (
    \\    hash BLOB PRIMARY KEY,
    \\    role TEXT NOT NULL,
    \\    secret TEXT NOT NULL,
    \\    by TEXT NOT NULL,
    \\    created INTEGER NOT NULL,
    \\    uses INTEGER NOT NULL DEFAULT 0,
    \\    revoked INTEGER NOT NULL DEFAULT 0
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
/// The notes tool's marker, as long as a session: nginx adds the tool to pages for it.
/// HttpOnly: only nginx reads it
pub const marker_on = notes_marker ++ "=1; Path=/; Max-Age=2592000; Secure; HttpOnly; SameSite=Lax";
pub const marker_off = notes_marker ++ "=; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Lax";
const session_s: i64 = 30 * 24 * 60 * 60;
/// A session's expiry moves forward at most once a day, so a busy one writes little
const renew_after_s: i64 = 24 * 60 * 60;
const invite_s: i64 = 7 * 24 * 60 * 60;
/// A desktop app unused this long signs in again
const device_s: i64 = 90 * 24 * 60 * 60;
pub const max_devices = 10;
const device_name_max = 64;
const token_bytes = 32;
pub const token_len = b64.Encoder.calcSize(token_bytes);
pub const Token = [token_len]u8;
const max_body = 4096;
pub const password_min = 8;
pub const password_max = 256;
pub const username_max = 64;
/// A sign-up link's shared password
pub const secret_min = 10;

/// Lower case letters, digits and . _ - @ +, 2 to 64 long (an email fits), lower-cased
/// into `buf`; null otherwise
pub fn username(buf: *[username_max]u8, name: []const u8) ?[]const u8 {
    if (name.len < 2 or name.len > username_max) return null;
    for (name, 0..) |ch, i| {
        const l = std.ascii.toLower(ch);
        if (!std.ascii.isAlphanumeric(l) and std.mem.findScalar(u8, "._-@+", l) == null) return null;
        buf[i] = l;
    }
    return buf[0..name.len];
}

pub fn passwordOk(password: []const u8) bool {
    return password.len >= password_min and password.len <= password_max;
}

/// Loosely: something@something.tld, one @. The address is only a username here: nothing
/// is ever mailed to it
pub fn isEmail(name: []const u8) bool {
    const at = std.mem.findScalar(u8, name, '@') orelse return false;
    if (std.mem.findScalarLast(u8, name, '@') != at or at == 0) return false;
    const domain = name[at + 1 ..];
    const dot = std.mem.findScalarLast(u8, domain, '.') orelse return false;
    return dot > 0 and dot + 1 < domain.len;
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

/// The account, its sessions, desktop apps and reset invites: nothing of it stays (a
/// friend's erasure)
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
    return holder(db, arena, .sessions, token, now);
}

/// The account a desktop app's token signs in, renewed as a session is; null for a
/// missing, expired or revoked one, or a disabled account. Strings in `arena`
pub fn device(db: Db, arena: Allocator, token: []const u8, now: i64) !?Account {
    return holder(db, arena, .devices, token, now);
}

fn holder(db: Db, arena: Allocator, comptime table: enum { sessions, devices }, token: []const u8, now: i64) !?Account {
    const lifetime = if (table == .sessions) session_s else device_s;
    const h = tokenHash(token);
    var q = try db.prepare("SELECT a.id, a.username, a.role, s.expires FROM " ++ @tagName(table) ++
        " s JOIN accounts a ON a.id = s.account WHERE s.hash = ? AND s.expires > ? AND a.disabled = 0");
    defer q.deinit();
    try q.bind(.{ Blob{ .bytes = &h }, now });
    if (!try q.step()) return null;
    const r = q.row(struct { id: i64, username: []const u8, role: []const u8, expires: i64 });
    const a: Account = .{ .id = r.id, .username = try arena.dupe(u8, r.username), .role = Role.parse(r.role) orelse return error.BadRole };
    const expires = r.expires;
    q.reset();
    if (now + lifetime - expires >= renew_after_s) {
        try db.run("UPDATE " ++ @tagName(table) ++ " SET expires = ? WHERE hash = ?", .{ now + lifetime, Blob{ .bytes = &h } });
        try db.run("UPDATE accounts SET last_seen = ? WHERE id = ?", .{ now, a.id });
    }
    return a;
}

pub fn endSession(db: Db, token: []const u8) !void {
    const h = tokenHash(token);
    try db.run("DELETE FROM sessions WHERE hash = ?", .{Blob{ .bytes = &h }});
}

/// Sessions and desktop apps both
pub fn endAll(db: Db, account: i64) !void {
    try db.run("DELETE FROM sessions WHERE account = ?", .{account});
    try db.run("DELETE FROM devices WHERE account = ?", .{account});
}

/// error.TooManyDevices past max_devices live ones
pub fn startDevice(db: Db, io: Io, account: i64, name: []const u8, now: i64) !Token {
    try db.run("DELETE FROM devices WHERE account = ? AND expires <= ?", .{ account, now });
    const live = try db.scalar("SELECT count(*) FROM devices WHERE account = ?", .{account}) orelse 0;
    if (live >= max_devices) return error.TooManyDevices;
    const t = try newToken(io);
    const h = tokenHash(&t);
    try db.run("INSERT INTO devices (hash, account, name, created, expires) VALUES (?, ?, ?, ?, ?)", .{ Blob{ .bytes = &h }, account, name, now, now + device_s });
    try db.run("UPDATE accounts SET last_seen = ? WHERE id = ?", .{ now, account });
    return t;
}

pub fn endDevice(db: Db, token: []const u8) !void {
    const h = tokenHash(token);
    try db.run("DELETE FROM devices WHERE hash = ?", .{Blob{ .bytes = &h }});
}

/// False when the account has no device `id`
pub fn revokeDevice(db: Db, account: i64, id: i64) !bool {
    try db.run("DELETE FROM devices WHERE id = ? AND account = ?", .{ id, account });
    return db.changes() > 0;
}

/// The app's name for itself, printable ASCII only, else a stand-in
fn deviceName(name: []const u8) []const u8 {
    const n = std.mem.trim(u8, name, " ");
    if (n.len == 0 or n.len > device_name_max) return "desktop app";
    for (n) |ch| if (!std.ascii.isPrint(ch)) return "desktop app";
    return n;
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

/// `secret_phc`: the shared password's hash (Hasher.hash). Never for the owner
pub fn makeLink(db: Db, io: Io, role: Role, secret_phc: []const u8, by: []const u8, now: i64) !Token {
    if (role == .owner) return error.BadRole;
    const t = try newToken(io);
    const h = tokenHash(&t);
    try db.run("INSERT INTO signup_links (hash, role, secret, by, created) VALUES (?, ?, ?, ?, ?)", .{ Blob{ .bytes = &h }, @tagName(role), secret_phc, by, now });
    return t;
}

pub fn revokeLinks(db: Db) !void {
    try db.run("UPDATE signup_links SET revoked = 1", .{});
}

pub const Link = struct { role: Role, secret: []const u8 };

/// A live sign-up link; strings in `arena`
fn signupLink(db: Db, arena: Allocator, token: []const u8) !?Link {
    const h = tokenHash(token);
    var q = try db.prepare("SELECT role, secret FROM signup_links WHERE hash = ? AND revoked = 0");
    defer q.deinit();
    try q.bind(.{Blob{ .bytes = &h }});
    if (!try q.step()) return null;
    const r = q.row(struct { role: []const u8, secret: []const u8 });
    const role = Role.parse(r.role) orelse return error.BadRole;
    if (role == .owner) return error.BadRole;
    return .{ .role = role, .secret = try arena.dupe(u8, r.secret) };
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
    /// A desktop app's token from Authorization: Bearer, when well formed
    bearer: ?[]const u8 = null,
    /// X-Meiolol-Action: 1
    action: bool = false,
    body: []const u8 = "",
};

pub const Out = struct {
    status: Status,
    body: []const u8 = "",
    set_cookie: ?[]const u8 = null,
    /// The notes marker's Set-Cookie (marker_on or marker_off)
    marker: ?[]const u8 = null,
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
            .bearer = if (header(request, "authorization")) |v| if (bearerToken(v)) |t| try arena.dupe(u8, t) else null else null,
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
        const Route = enum { login, logout, me, join, signup, password, device, devices, revoke, accounts, invite, role, disable, reset };
        const not_found: Out = .{ .status = .not_found, .body = errorJson("not found") };
        if (std.mem.startsWith(u8, in.path, "check/")) {
            if (in.method != .GET) return notAllowed();
            const cap = Capability.parse(in.path["check/".len..]) orelse return .{ .status = .not_found, .body = errorJson("no such capability") };
            const a = try s.signedIn(arena, in, now) orelse return .{ .status = .unauthorized };
            if (!a.role.can(cap) or in.bearer != null and !cap.forDevices()) return .{ .status = .forbidden };
            return .{ .status = .no_content, .user = a.username, .role = a.role };
        }
        const r = std.meta.stringToEnum(Route, in.path) orelse return not_found;
        if (post != (r != .me and r != .accounts and r != .devices)) return notAllowed();
        if (post and !in.action) return .{ .status = .forbidden, .body = errorJson("missing X-Meiolol-Action") };
        return switch (r) {
            .login => s.login(arena, in, now),
            .logout => s.logout(arena, in, now),
            .me => {
                const a = try s.signedIn(arena, in, now) orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
                return .{ .status = .ok, .body = try accountJson(arena, a) };
            },
            .join => s.join(arena, in, now),
            .signup => s.signup(arena, in, now),
            .password => s.password(arena, in, now),
            .device => s.newDevice(arena, in, now),
            .devices, .revoke => {
                const db = try open(s.db_path);
                defer db.close();
                const token = in.token orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
                const a = try session(db, arena, token, now) orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
                if (r == .devices) return .{ .status = .ok, .body = try devicesJson(db, arena, a.id, now) };
                const b = parseBody(struct { id: i64 }, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with id") };
                if (!try revokeDevice(db, a.id, b.id)) return .{ .status = .not_found, .body = errorJson("no such device") };
                return .{ .status = .ok, .body = "{\"ok\":true}" };
            },
            .accounts, .invite, .role, .disable, .reset => {
                const db = try open(s.db_path);
                defer db.close();
                const token = in.token orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
                const actor = try session(db, arena, token, now) orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
                if (!actor.role.can(.manage_accounts)) return .{ .status = .forbidden, .body = errorJson("your role cannot manage accounts") };
                return switch (r) {
                    .accounts => .{ .status = .ok, .body = try accountsJson(db, arena, actor) },
                    .invite => s.newInvite(db, arena, in, actor, now),
                    else => s.manage(db, arena, in, actor, r == .role, r == .disable, now),
                };
            },
        };
    }

    /// By the bearer token when there is one, else the cookie
    fn signedIn(s: *Service, arena: Allocator, in: In, now: i64) !?Account {
        if (in.bearer == null and in.token == null) return null;
        const db = try open(s.db_path);
        defer db.close();
        if (in.bearer) |t| return device(db, arena, t, now);
        return session(db, arena, in.token.?, now);
    }

    const Checked = union(enum) { account: Stored, refused: Out };

    /// A login's username and password: the account, or the answer refusing it. Fails
    /// count against the username (Throttle)
    fn credentials(s: *Service, db: Db, arena: Allocator, name_in: []const u8, password_in: []const u8, now: i64) !Checked {
        const wrong: Checked = .{ .refused = .{ .status = .unauthorized, .body = errorJson("wrong username or password") } };
        var name_buf: [username_max]u8 = undefined;
        const name = username(&name_buf, name_in) orelse return wrong;
        const wait = s.throttle.wait(s.io, name, now);
        if (wait > 0) return .{ .refused = try tooMany(arena, wait) };
        const stored = try find(db, arena, name);
        const ok = if (stored) |a|
            !a.disabled and try s.hasher.verify(s.gpa, s.io, a.hash, password_in)
        else blk: {
            // As long as a real check, so timing doesn't tell which usernames exist
            var out: [128]u8 = undefined;
            _ = try s.hasher.hash(s.gpa, s.io, password_in, &out);
            break :blk false;
        };
        if (!ok) {
            try s.throttle.failed(s.gpa, s.io, name, now);
            return wrong;
        }
        s.throttle.succeeded(s.gpa, s.io, name);
        return .{ .account = stored.? };
    }

    fn login(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const Body = struct { username: []const u8, password: []const u8 };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with username and password") };
        const db = try open(s.db_path);
        defer db.close();
        const a = switch (try s.credentials(db, arena, b.username, b.password, now)) {
            .account => |a| a,
            .refused => |out| return out,
        };
        const t = try startSession(db, s.io, a.id, now);
        return .{
            .status = .ok,
            .body = try accountJson(arena, .{ .id = a.id, .username = a.username, .role = a.role }),
            .set_cookie = try sessionCookie(arena, &t),
            .marker = if (a.role.can(.take_notes)) marker_on else null,
        };
    }

    /// A login for the desktop app: its token instead of a cookie
    fn newDevice(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const Body = struct { username: []const u8, password: []const u8, name: []const u8 = "" };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with username and password") };
        const db = try open(s.db_path);
        defer db.close();
        const a = switch (try s.credentials(db, arena, b.username, b.password, now)) {
            .account => |a| a,
            .refused => |out| return out,
        };
        if (!a.role.can(.download_private_app)) return .{ .status = .forbidden, .body = errorJson("this account cannot use the desktop app yet") };
        const t = startDevice(db, s.io, a.id, deviceName(b.name), now) catch |err| switch (err) {
            error.TooManyDevices => return .{ .status = .conflict, .body = errorJson(std.fmt.comptimePrint("{d} apps are signed in already: remove one on your account page", .{max_devices})) },
            else => return err,
        };
        return .{ .status = .ok, .body = try std.json.Stringify.valueAlloc(arena, .{ .token = &t, .username = a.username, .role = @tagName(a.role) }, .{}) };
    }

    fn logout(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const out: Out = .{ .status = .ok, .body = "{\"ok\":true}", .set_cookie = cookie_name ++ "=; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Lax", .marker = marker_off };
        if (in.bearer) |t| {
            const db = try open(s.db_path);
            defer db.close();
            try endDevice(db, t);
            return .{ .status = .ok, .body = out.body };
        }
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
            username(&name_buf, b.username) orelse return .{ .status = .bad_request, .body = errorJson("username: 2 to 64 letters, digits, dots, dashes or underscores") }
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

    /// Wrong passwords count against the link (its first characters), as logins count
    /// against a username: guessing the shared password is slow, whoever holds the link
    fn signup(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const Body = struct { link: []const u8, email: []const u8, password: []const u8 };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with link, email and password") };
        const bad_link: Out = .{ .status = .bad_request, .body = errorJson("this sign-up link no longer works") };
        const token = parseToken(b.link) orelse return bad_link;
        var name_buf: [username_max]u8 = undefined;
        const name = username(&name_buf, std.mem.trim(u8, b.email, " ")) orelse "";
        if (!isEmail(name)) return .{ .status = .bad_request, .body = errorJson("enter your email address") };
        const key = try arena.print("signup:{s}", .{token[0..8]});
        const wait = s.throttle.wait(s.io, key, now);
        if (wait > 0) return tooMany(arena, wait);

        const db = try open(s.db_path);
        defer db.close();
        const link = try signupLink(db, arena, token) orelse return bad_link;
        if (!try s.hasher.verify(s.gpa, s.io, link.secret, b.password)) {
            try s.throttle.failed(s.gpa, s.io, key, now);
            return .{ .status = .unauthorized, .body = errorJson("wrong password") };
        }
        // Its own salt: the stored hash differs from the link's though the password is the same
        var phc_buf: [128]u8 = undefined;
        const phc = try s.hasher.hash(s.gpa, s.io, b.password, &phc_buf);
        const id = create(db, name, phc, link.role, now) catch |err| switch (err) {
            error.Taken => return .{ .status = .conflict, .body = errorJson("there is already an account with this email: log in instead") },
            else => return err,
        };
        const h = tokenHash(token);
        try db.run("UPDATE signup_links SET uses = uses + 1 WHERE hash = ?", .{Blob{ .bytes = &h }});
        const t = try startSession(db, s.io, id, now);
        return .{ .status = .ok, .body = try accountJson(arena, .{ .id = id, .username = name, .role = link.role }), .set_cookie = try sessionCookie(arena, &t) };
    }

    /// The old password again, counted as a login try: a borrowed session can't take
    /// the account over
    fn password(s: *Service, arena: Allocator, in: In, now: i64) !Out {
        const Body = struct { password: []const u8, new: []const u8 };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with password and new") };
        const token = in.token orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
        if (!passwordOk(b.new)) return .{ .status = .bad_request, .body = errorJson("password must be 8 to 256 characters") };
        const db = try open(s.db_path);
        defer db.close();
        const a = try session(db, arena, token, now) orelse return .{ .status = .unauthorized, .body = errorJson("not signed in") };
        const wait = s.throttle.wait(s.io, a.username, now);
        if (wait > 0) return tooMany(arena, wait);
        const stored = try find(db, arena, a.username) orelse return error.Unexpected;
        if (!try s.hasher.verify(s.gpa, s.io, stored.hash, b.password)) {
            try s.throttle.failed(s.gpa, s.io, a.username, now);
            return .{ .status = .forbidden, .body = errorJson("wrong current password") };
        }
        s.throttle.succeeded(s.gpa, s.io, a.username);
        var phc_buf: [128]u8 = undefined;
        try setPassword(db, a.id, try s.hasher.hash(s.gpa, s.io, b.new, &phc_buf));
        const t = try startSession(db, s.io, a.id, now);
        return .{ .status = .ok, .body = try accountJson(arena, a), .set_cookie = try sessionCookie(arena, &t) };
    }

    fn newInvite(s: *Service, db: Db, arena: Allocator, in: In, actor: Account, now: i64) !Out {
        const b = parseBody(struct { role: []const u8 }, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with role") };
        const role = Role.parse(b.role) orelse return .{ .status = .bad_request, .body = errorJson("no such role") };
        if (!actor.role.canManage(role)) return .{ .status = .forbidden, .body = errorJson("your role cannot give that role") };
        const t = try makeInvite(db, s.io, role, null, actor.username, now);
        return .{ .status = .ok, .body = try std.json.Stringify.valueAlloc(arena, .{ .invite = &t }, .{}) };
    }

    /// role, disable or reset on one account
    fn manage(s: *Service, db: Db, arena: Allocator, in: In, actor: Account, set_role: bool, disable: bool, now: i64) !Out {
        const Body = struct { username: []const u8, role: []const u8 = "", disabled: bool = false };
        const b = parseBody(Body, arena, in.body) orelse return .{ .status = .bad_request, .body = errorJson("expected JSON with username") };
        var name_buf: [username_max]u8 = undefined;
        const name = username(&name_buf, b.username) orelse return .{ .status = .not_found, .body = errorJson("no such account") };
        const target = try find(db, arena, name) orelse return .{ .status = .not_found, .body = errorJson("no such account") };
        const cannot: Out = .{ .status = .forbidden, .body = errorJson("your role cannot manage that account") };
        if (!actor.role.canManage(target.role)) return cannot;
        const ok: Out = .{ .status = .ok, .body = "{\"ok\":true}" };
        if (set_role) {
            const role = Role.parse(b.role) orelse return .{ .status = .bad_request, .body = errorJson("no such role") };
            if (!actor.role.canManage(role)) return .{ .status = .forbidden, .body = errorJson("your role cannot give that role") };
            try setRole(db, target.id, role);
            return ok;
        }
        if (disable) {
            try setDisabled(db, target.id, b.disabled);
            return ok;
        }
        const t = try makeInvite(db, s.io, target.role, target.id, actor.username, now);
        return .{ .status = .ok, .body = try std.json.Stringify.valueAlloc(arena, .{ .invite = &t }, .{}) };
    }
};

/// Every account, each marked with whether `actor` may manage it; and the roles it may
/// give, lowest first
fn accountsJson(db: Db, arena: Allocator, actor: Account) ![]const u8 {
    const Row = struct { username: []const u8, role: []const u8, created: i64, last_seen: ?i64, disabled: bool, manage: bool };
    var rows: std.ArrayList(Row) = .empty;
    var q = try db.prepare("SELECT username, role, created, last_seen, disabled FROM accounts ORDER BY id");
    defer q.deinit();
    try q.bind(.{});
    while (try q.step()) {
        const r = q.row(struct { username: []const u8, role: []const u8, created: i64, last_seen: ?i64, disabled: bool });
        const role = Role.parse(r.role) orelse return error.BadRole;
        try rows.append(arena, .{
            .username = try arena.dupe(u8, r.username),
            .role = @tagName(role),
            .created = r.created,
            .last_seen = r.last_seen,
            .disabled = r.disabled,
            .manage = actor.role.canManage(role),
        });
    }
    var give: std.ArrayList([]const u8) = .empty;
    for (std.enums.values(Role)) |role| if (actor.role.canManage(role)) try give.append(arena, @tagName(role));
    return std.json.Stringify.valueAlloc(arena, .{ .accounts = rows.items, .roles = give.items }, .{});
}

fn tooMany(arena: Allocator, wait: i64) !Out {
    return .{ .status = .too_many_requests, .body = try std.json.Stringify.valueAlloc(arena, .{ .@"error" = "too many tries", .retry_s = wait }, .{}) };
}

/// Live ones, oldest first
fn devicesJson(db: Db, arena: Allocator, account: i64, now: i64) ![]const u8 {
    const Row = struct { id: i64, name: []const u8, created: i64, last_used: i64 };
    var rows: std.ArrayList(Row) = .empty;
    var q = try db.prepare("SELECT id, name, created, expires FROM devices WHERE account = ? AND expires > ? ORDER BY id");
    defer q.deinit();
    try q.bind(.{ account, now });
    while (try q.step()) {
        const r = q.row(struct { id: i64, name: []const u8, created: i64, expires: i64 });
        try rows.append(arena, .{ .id = r.id, .name = try arena.dupe(u8, r.name), .created = r.created, .last_used = r.expires - device_s });
    }
    return std.json.Stringify.valueAlloc(arena, .{ .devices = rows.items }, .{});
}

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
    var headers: [6]std.http.Header = undefined;
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
    if (out.marker) |c| {
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
pub fn header(request: *Request, name: []const u8) ?[]const u8 {
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
pub fn cookieToken(request: *Request) ?[]const u8 {
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        if (!std.ascii.eqlIgnoreCase(h.name, "cookie")) continue;
        if (cookieValue(h.value)) |t| return t;
    }
    return null;
}

/// "Bearer TOKEN", the scheme in any case
fn bearerToken(value: []const u8) ?[]const u8 {
    const scheme = "bearer ";
    if (value.len < scheme.len or !std.ascii.eqlIgnoreCase(value[0..scheme.len], scheme)) return null;
    return parseToken(std.mem.trim(u8, value[scheme.len..], " "));
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

    fn device(f: *Fixture, name: []const u8, password: []const u8, at: i64) !Out {
        const body = try std.json.Stringify.valueAlloc(f.arena(), .{ .username = name, .password = password, .name = "Jacob's PC" }, .{});
        return f.service.route(f.arena(), .{ .method = .POST, .path = "device", .action = true, .body = body }, at);
    }

    /// A desktop app's token for `role`'s account
    fn pair(f: *Fixture, role: Role) ![]const u8 {
        const out = try f.device(@tagName(role), try f.arena().print("password-{t}", .{role}), now);
        try testing.expectEqual(Status.ok, out.status);
        return (try std.json.parseFromSliceLeaky(struct { token: []const u8 }, f.arena(), out.body, .{ .ignore_unknown_fields = true })).token;
    }

    fn checkDevice(f: *Fixture, bearer: []const u8, cap: []const u8, at: i64) !Status {
        const path = try f.arena().print("check/{s}", .{cap});
        return (try f.service.route(f.arena(), .{ .method = .GET, .path = path, .bearer = bearer }, at)).status;
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
    for ([_][]const u8{ "login", "logout", "join", "device", "revoke" }) |p| {
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

test "device: a desktop app's token passes the download check only, for roles that have it" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    for (std.enums.values(Role)) |role| {
        if (!role.can(.download_private_app)) {
            const out = try f.device(@tagName(role), try f.arena().print("password-{t}", .{role}), Fixture.now);
            try testing.expectEqual(Status.forbidden, out.status);
            continue;
        }
        const token = try f.pair(role);
        for (std.enums.values(Capability)) |cap| {
            const want: Status = if (role.can(cap) and cap.forDevices()) .no_content else .forbidden;
            try testing.expectEqual(want, try f.checkDevice(token, @tagName(cap), Fixture.now));
        }
        // Never as a cookie, nor on the account's own routes
        try testing.expectEqual(Status.unauthorized, try f.check(token, "download_private_app"));
        for ([_][]const u8{ "devices", "accounts" }) |p| {
            try testing.expectEqual(Status.unauthorized, (try f.service.route(f.arena(), .{ .method = .GET, .path = p, .bearer = token }, Fixture.now)).status);
        }
        try testing.expectEqual(Status.unauthorized, (try f.service.route(f.arena(), .{ .method = .POST, .path = "password", .action = true, .bearer = token, .body = "{\"password\":\"x\",\"new\":\"long enough\"}" }, Fixture.now)).status);
    }
    try testing.expectEqual(0, try f.db.scalar("SELECT count(*) FROM devices WHERE name != 'Jacob''s PC'", .{}));
}

test "device: wrong passwords throttled with logins; list, revoke, sign out, expiry, the cap" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const now = Fixture.now;
    try testing.expectEqual(Status.unauthorized, (try f.device("private", "guess", now)).status);
    for (1..Throttle.free_fails) |_| _ = try f.login("private", "guess");
    try testing.expectEqual(Status.too_many_requests, (try f.device("private", "password-private", now)).status);
    f.service.throttle.succeeded(testing.allocator, testing.io, "private");

    const app = try f.pair(.private);
    const me = try f.service.route(a, .{ .method = .GET, .path = "me", .bearer = app }, now);
    try testing.expect(std.mem.find(u8, me.body, "\"username\":\"private\"") != null);
    const cookie = try f.signIn(.private);
    const list = try f.service.route(a, .{ .method = .GET, .path = "devices", .token = cookie }, now);
    try testing.expectEqualStrings("{\"devices\":[{\"id\":1,\"name\":\"Jacob's PC\",\"created\":1800000000,\"last_used\":1800000000}]}", list.body);

    // Another account's device can't be revoked; its own can, and stops at once
    try testing.expectEqual(Status.not_found, (try postAs(&f, try f.signIn(.admin), "revoke", .{ .id = 1 })).status);
    try testing.expectEqual(Status.no_content, try f.checkDevice(app, "download_private_app", now));
    try testing.expectEqual(Status.ok, (try postAs(&f, cookie, "revoke", .{ .id = 1 })).status);
    try testing.expectEqual(Status.unauthorized, try f.checkDevice(app, "download_private_app", now));
    try testing.expectEqual(Status.not_found, (try postAs(&f, cookie, "revoke", .{ .id = 1 })).status);

    // The app signing out ends its token only, and sets no cookie
    const app2 = try f.pair(.private);
    const out = try f.service.route(a, .{ .method = .POST, .path = "logout", .action = true, .bearer = app2, .token = cookie }, now);
    try testing.expectEqual(null, out.set_cookie);
    try testing.expectEqual(Status.unauthorized, try f.checkDevice(app2, "download_private_app", now));
    try testing.expectEqual(Status.no_content, try f.check(cookie, "view_private"));

    // 90 days unused; renewed when used
    const app3 = try f.pair(.private);
    try testing.expectEqual(Status.no_content, try f.checkDevice(app3, "download_private_app", now + 60 * 86400));
    try testing.expectEqual(Status.no_content, try f.checkDevice(app3, "download_private_app", now + 140 * 86400));
    try testing.expectEqual(Status.unauthorized, try f.checkDevice(app3, "download_private_app", now + 240 * 86400));

    for (0..max_devices) |_| _ = try f.pair(.admin);
    try testing.expectEqual(Status.conflict, (try f.device("admin", "password-admin", now)).status);
    // Expired ones make room
    try testing.expectEqual(Status.ok, (try f.device("admin", "password-admin", now + device_s)).status);
}

test "device: password changes, disabling and deleting end the account's apps" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const id = (try find(f.db, f.arena(), "private")).?.id;
    const app = try f.pair(.private);
    try setDisabled(f.db, id, true);
    try testing.expectEqual(Status.unauthorized, try f.checkDevice(app, "download_private_app", Fixture.now));
    try setDisabled(f.db, id, false);
    try testing.expectEqual(Status.unauthorized, try f.checkDevice(app, "download_private_app", Fixture.now));

    const app2 = try f.pair(.private);
    try testing.expectEqual(Status.ok, (try postAs(&f, try f.signIn(.private), "password", .{ .password = "password-private", .new = "brand new one" })).status);
    try testing.expectEqual(Status.unauthorized, try f.checkDevice(app2, "download_private_app", Fixture.now));

    _ = try f.device("private", "brand new one", Fixture.now);
    try remove(f.db, id);
    try testing.expectEqual(0, try f.db.scalar("SELECT count(*) FROM devices", .{}));
}

test bearerToken {
    const t: Token = @splat('A');
    try testing.expectEqualStrings(&t, bearerToken("Bearer " ++ t).?);
    try testing.expectEqualStrings(&t, bearerToken("bearer  " ++ t ++ " ").?);
    try testing.expectEqual(null, bearerToken("Basic " ++ t));
    try testing.expectEqual(null, bearerToken("Bearer short"));
    try testing.expectEqual(null, bearerToken("Bearer"));
}

test deviceName {
    try testing.expectEqualStrings("my pc", deviceName(" my pc "));
    try testing.expectEqualStrings("desktop app", deviceName(""));
    try testing.expectEqualStrings("desktop app", deviceName("tab\there"));
    try testing.expectEqualStrings("desktop app", deviceName(&@as([device_name_max + 1]u8, @splat('x'))));
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
    try testing.expectEqualStrings("a.b+c@mail.co.uk", username(&buf, "A.B+c@Mail.co.uk").?);
    try testing.expectEqual(null, username(&buf, &@as([username_max + 1]u8, @splat('x'))));
}

test isEmail {
    try testing.expect(isEmail("a@b.co"));
    try testing.expect(isEmail("first.last+x@mail.co.uk"));
    for ([_][]const u8{ "ab", "@b.co", "a@b", "a@.co", "a@b.", "a@b@c.co" }) |s| try testing.expect(!isEmail(s));
}

test "signup: the link and its shared password make accounts; wrong ones are slowed" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const now = Fixture.now;
    var phc_buf: [128]u8 = undefined;
    const link = try makeLink(f.db, testing.io, .admin, try f.service.hasher.hash(testing.allocator, testing.io, "shared secret", &phc_buf), "owner", now);
    const T = struct {
        fn body(ar: Allocator, l: []const u8, email: []const u8, password: []const u8) ![]const u8 {
            return std.json.Stringify.valueAlloc(ar, .{ .link = l, .email = email, .password = password }, .{});
        }
        fn signup(fx: *Fixture, b: []const u8) !Out {
            return fx.service.route(fx.arena(), .{ .method = .POST, .path = "signup", .action = true, .body = b }, Fixture.now);
        }
    };
    const signup = T.signup;

    const out = try signup(&f, try T.body(a, &link, " Pal@Mail.com ", "shared secret"));
    try testing.expectEqual(Status.ok, out.status);
    try testing.expect(std.mem.find(u8, out.body, "\"username\":\"pal@mail.com\",\"role\":\"admin\"") != null);
    try testing.expectEqual(Status.no_content, try f.check(cookieValue(out.set_cookie.?).?, "view_admin"));
    try testing.expectEqual(Status.forbidden, try f.check(cookieValue(out.set_cookie.?).?, "run_actions"));
    try testing.expectEqual(Status.ok, (try f.login("pal@mail.com", "shared secret")).status);
    // Many uses
    try testing.expectEqual(Status.ok, (try signup(&f, try T.body(a, &link, "two@mail.com", "shared secret"))).status);
    try testing.expectEqual(2, try f.db.scalar("SELECT uses FROM signup_links", .{}));

    try testing.expectEqual(Status.conflict, (try signup(&f, try T.body(a, &link, "pal@mail.com", "shared secret"))).status);
    try testing.expectEqual(Status.bad_request, (try signup(&f, try T.body(a, &link, "not an email", "shared secret"))).status);
    var other = link;
    other[0] = if (other[0] == 'A') 'B' else 'A';
    try testing.expectEqual(Status.bad_request, (try signup(&f, try T.body(a, &other, "x@mail.com", "shared secret"))).status);

    for (0..Throttle.free_fails) |_| try testing.expectEqual(Status.unauthorized, (try signup(&f, try T.body(a, &link, "x@mail.com", "guess"))).status);
    try testing.expectEqual(Status.too_many_requests, (try signup(&f, try T.body(a, &link, "x@mail.com", "shared secret"))).status);
    try testing.expectEqual(null, try find(f.db, a, "x@mail.com"));

    try revokeLinks(f.db);
    f.service.throttle.succeeded(testing.allocator, testing.io, try a.print("signup:{s}", .{link[0..8]}));
    try testing.expectEqual(Status.bad_request, (try signup(&f, try T.body(a, &link, "y@mail.com", "shared secret"))).status);
    try testing.expectError(error.BadRole, makeLink(f.db, testing.io, .owner, "x", "owner", now));
}

/// A manager route's answer for the account signed in with `token`
fn postAs(f: *Fixture, token: ?[]const u8, path: []const u8, body: anytype) !Out {
    const b = try std.json.Stringify.valueAlloc(f.arena(), body, .{});
    return f.service.route(f.arena(), .{ .method = .POST, .path = path, .action = true, .token = token, .body = b }, Fixture.now);
}

test "manage: every route against every role, on every role" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    for (std.enums.values(Role)) |actor| {
        const token = try f.signIn(actor);
        const list = try f.service.route(a, .{ .method = .GET, .path = "accounts", .token = token }, Fixture.now);
        if (!actor.can(.manage_accounts)) {
            try testing.expectEqual(Status.forbidden, list.status);
            try testing.expectEqual(Status.forbidden, (try postAs(&f, token, "invite", .{ .role = "public" })).status);
            try testing.expectEqual(Status.forbidden, (try postAs(&f, token, "reset", .{ .username = "public" })).status);
            continue;
        }
        try testing.expectEqual(Status.ok, list.status);
        for (std.enums.values(Role)) |target| {
            const want: Status = if (actor.canManage(target)) .ok else .forbidden;
            try testing.expectEqual(want, (try postAs(&f, token, "invite", .{ .role = @tagName(target) })).status);
            try testing.expectEqual(want, (try postAs(&f, token, "reset", .{ .username = @tagName(target) })).status);
            try testing.expectEqual(want, (try postAs(&f, token, "disable", .{ .username = @tagName(target), .disabled = false })).status);
            // Its own role again: allowed exactly when the account is
            try testing.expectEqual(want, (try postAs(&f, token, "role", .{ .username = @tagName(target), .role = @tagName(target) })).status);
        }
    }
    for ([_][]const u8{ "invite", "role", "disable", "reset" }) |p| {
        try testing.expectEqual(Status.unauthorized, (try postAs(&f, null, p, .{ .username = "public", .role = "public" })).status);
        try testing.expectEqual(Status.forbidden, (try f.service.route(a, .{ .method = .POST, .path = p, .token = try f.signIn(.owner) }, Fixture.now)).status);
        try testing.expectEqual(Status.method_not_allowed, (try f.service.route(a, .{ .method = .GET, .path = p }, Fixture.now)).status);
    }
    try testing.expectEqual(Status.unauthorized, (try f.service.route(a, .{ .method = .GET, .path = "accounts" }, Fixture.now)).status);
    try testing.expectEqual(Status.method_not_allowed, (try f.service.route(a, .{ .method = .POST, .path = "accounts", .action = true }, Fixture.now)).status);
}

test "manage: what each change does" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const admin = try f.signIn(.admin);
    const list = try f.service.route(a, .{ .method = .GET, .path = "accounts", .token = admin }, Fixture.now);
    try testing.expect(std.mem.find(u8, list.body, "\"roles\":[\"public\",\"paid\",\"private\"]") != null);
    try testing.expect(std.mem.find(u8, list.body, "{\"username\":\"owner\",\"role\":\"owner\",\"created\":1800000000,\"last_seen\":null,\"disabled\":false,\"manage\":false}") != null);

    // An admin can't lift a friend to its own level, nor give a role it doesn't manage
    try testing.expectEqual(Status.forbidden, (try postAs(&f, admin, "role", .{ .username = "private", .role = "admin" })).status);
    try testing.expectEqual(Status.bad_request, (try postAs(&f, admin, "role", .{ .username = "private", .role = "king" })).status);
    try testing.expectEqual(Status.not_found, (try postAs(&f, admin, "role", .{ .username = "nobody", .role = "paid" })).status);
    const friend = try f.signIn(.private);
    try testing.expectEqual(Status.ok, (try postAs(&f, admin, "role", .{ .username = "private", .role = "paid" })).status);
    try testing.expectEqual(Status.forbidden, try f.check(friend, "view_private"));
    try testing.expectEqual(Status.ok, (try postAs(&f, admin, "role", .{ .username = "private", .role = "private" })).status);

    try testing.expectEqual(Status.ok, (try postAs(&f, admin, "disable", .{ .username = "private", .disabled = true })).status);
    try testing.expectEqual(Status.unauthorized, try f.check(friend, "view_private"));
    try testing.expectEqual(Status.unauthorized, (try f.login("private", "password-private")).status);
    try testing.expectEqual(Status.ok, (try postAs(&f, admin, "disable", .{ .username = "private", .disabled = false })).status);
    try testing.expectEqual(Status.ok, (try f.login("private", "password-private")).status);

    const inv = try postAs(&f, admin, "invite", .{ .role = "private" });
    const t = (try std.json.parseFromSliceLeaky(struct { invite: []const u8 }, a, inv.body, .{})).invite;
    try testing.expectEqual(1, try f.db.scalar("SELECT count(*) FROM invites WHERE by = 'admin'", .{}));
    const joined = try postAs(&f, null, "join", .{ .invite = t, .username = "pal", .password = "long enough" });
    try testing.expect(std.mem.find(u8, joined.body, "\"role\":\"private\"") != null);

    const reset = try postAs(&f, admin, "reset", .{ .username = "Pal" });
    const rt = (try std.json.parseFromSliceLeaky(struct { invite: []const u8 }, a, reset.body, .{})).invite;
    try testing.expectEqual(Status.ok, (try postAs(&f, null, "join", .{ .invite = rt, .password = "pal's new one" })).status);
    try testing.expectEqual(Status.ok, (try f.login("pal", "pal's new one")).status);
}

test "password: the old one first, then every other session ends" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const other = try f.signIn(.private);
    const here = try f.signIn(.private);
    try testing.expectEqual(Status.unauthorized, (try postAs(&f, null, "password", .{ .password = "password-private", .new = "brand new one" })).status);
    try testing.expectEqual(Status.forbidden, (try postAs(&f, here, "password", .{ .password = "wrong", .new = "brand new one" })).status);
    try testing.expectEqual(Status.bad_request, (try postAs(&f, here, "password", .{ .password = "password-private", .new = "short" })).status);
    const out = try postAs(&f, here, "password", .{ .password = "password-private", .new = "brand new one" });
    try testing.expectEqual(Status.ok, out.status);
    for ([_][]const u8{ other, here }) |old| try testing.expectEqual(Status.unauthorized, try f.check(old, "view_paid"));
    try testing.expectEqual(Status.no_content, try f.check(cookieValue(out.set_cookie.?).?, "view_private"));
    try testing.expectEqual(Status.unauthorized, (try f.login("private", "password-private")).status);
    try testing.expectEqual(Status.ok, (try f.login("private", "brand new one")).status);

    // Wrong old passwords count as failed logins
    const t = try f.signIn(.admin);
    for (0..Throttle.free_fails) |_| _ = try postAs(&f, t, "password", .{ .password = "guess", .new = "brand new one" });
    try testing.expectEqual(Status.too_many_requests, (try postAs(&f, t, "password", .{ .password = "password-admin", .new = "brand new one" })).status);
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
    // The fuzzer checks each input for leaks: fails kept for the next input would count
    f.service.throttle.deinit(testing.allocator);
    f.service.throttle = .{};
    try testing.expect(out.status == .ok or out.status == .bad_request or out.status == .unauthorized or out.status == .too_many_requests);
}

test "fuzz: a damaged login body is a 400 or 401, never a crash" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.fuzz(&f, fuzzLogin, .{});
}

test "an admin's login sets the notes marker, a lower role's doesn't; logout clears it" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = f.arena();
    const admin = try f.login("admin", "password-admin");
    try testing.expectEqualStrings(marker_on, admin.marker.?);
    try testing.expectEqual(null, (try f.login("private", "password-private")).marker);
    const out = try f.service.route(a, .{ .method = .POST, .path = "logout", .action = true, .token = cookieValue(admin.set_cookie.?).? }, Fixture.now);
    try testing.expectEqualStrings(marker_off, out.marker.?);
}
