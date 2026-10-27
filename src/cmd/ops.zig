//! `meiolol api`, `your-example`, `status`, `admin`

const std = @import("std");
const store = @import("store");
const core = @import("core");
const api = @import("../api/root.zig");
const admin = @import("../admin.zig");
const site_tester = @import("../site/tester.zig");
const status = @import("../status.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;

pub const usage_api =
    \\  api         the "Your games" service: JSON at /api/ (src/api/root.zig). Cache in
    \\              DIR/api.db. Riot calls through the crawler's proxy, else
    \\              straight to Riot with RIOT_API_KEY (testing)
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8090
    \\              --exchange DIR   shared with the box: curves/ in, forgotten
    \\                               PUUID lists both ways (docs/your-games.md)
    \\              --curves DIR     curves-<patch>.bin files (default EXCHANGE/curves,
    \\                               else DIR/export)
    \\              --riot-proxy URL the crawler's --proxy (box: http://10.0.0.3:8092)
    \\              --cors ORIGIN    allow a page on ORIGIN (local testing)
    \\              --fixture        made-up players in memory (src/api/devfixture.zig),
    \\                               no Riot call, no key; run from the repo root.
    \\                               `meiolol dev` sends /api/ here (port 8090)
    \\
;

pub fn cmdApi(c: *Cmd) !u8 {
    var o: api.Options = .{ .db_path = "", .curves_dir = "" };
    var curves_dir: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--host")) {
            o.host = try c.value();
        } else if (c.is("--port")) {
            o.port = try c.int(u16);
        } else if (c.is("--exchange")) {
            o.fetch.exchange_dir = try c.value();
        } else if (c.is("--curves")) {
            curves_dir = try c.value();
        } else if (c.is("--riot-proxy")) {
            o.fetch.proxy = try c.value();
        } else if (c.is("--cors")) {
            o.cors = try c.value();
        } else if (c.is("--fixture")) {
            o.fixture = true;
        } else return error.Usage;
    }
    const arena = c.arena;
    if (o.fixture) {
        o.curves_dir = curves_dir orelse try std.fs.path.join(arena, &.{ c.data_dir, "export" });
        try api.run(c.init.gpa, c.init.io, o);
        return 0;
    }
    if (o.fetch.proxy == null) o.fetch.key = try c.apiKey();
    o.db_path = try arena.printSentinel("{s}/api.db", .{c.data_dir}, 0);
    o.accounts_path = try arena.printSentinel("{s}/accounts.db", .{c.data_dir}, 0);
    o.curves_dir = curves_dir orelse if (o.fetch.exchange_dir) |x|
        try std.fs.path.join(arena, &.{ x, "curves" })
    else
        try std.fs.path.join(arena, &.{ c.data_dir, "export" });
    try api.run(c.init.gpa, c.init.io, o);
    return 0;
}

pub const usage_account =
    \\  account     logins in DIR/accounts.db (src/api/accounts.zig, roles.zig); on jomify
    \\              --data /var/lib/meiolol-api. Roles: public paid private admin owner.
    \\              Passwords come from stdin, e.g. read -rs P; printf %s "$P" | ...
    \\              add NAME ROLE    a new account
    \\              password NAME    a new password; signs it out everywhere, desktop apps too
    \\              role NAME ROLE
    \\              disable NAME     and signs it out everywhere; enable NAME undoes it
    \\              delete NAME      the account, its sessions, apps and invites (erasure)
    \\              invite ROLE      a one-use link for a new account (7 days)
    \\              reset NAME       a one-use link to set NAME's password (7 days)
    \\              link ROLE        a sign-up link for many: email plus the shared password
    \\                               (stdin, 10+ characters) makes an account with ROLE
    \\              links            sign-up links and how often each was used
    \\              revoke-links     every sign-up link stops working
    \\              list
    \\              devices NAME     its signed-in desktop apps (password or disable ends them)
    \\              backup           a consistent copy of accounts.db on stdout (VACUUM INTO;
    \\                               deploy/accounts-pull.sh, docs/data-safety.md)
    \\
;

pub fn cmdAccount(c: *Cmd) !u8 {
    const accounts = api.accounts;
    const io = c.init.io;
    const arena = c.arena;
    const verb = c.next() orelse return error.Usage;
    const Verb = enum { add, password, role, disable, enable, delete, invite, reset, list, devices, link, links, @"revoke-links", backup };
    const v = std.meta.stringToEnum(Verb, verb) orelse return error.Usage;
    var name_buf: [accounts.username_max]u8 = undefined;
    const name: []const u8 = switch (v) {
        .invite, .list, .link, .links, .@"revoke-links", .backup => "",
        else => accounts.username(&name_buf, c.next() orelse return error.Usage) orelse {
            std.log.err("username: 2 to 64 letters, digits and . _ - @ +", .{});
            return 2;
        },
    };
    const role: ?api.roles.Role = switch (v) {
        .add, .role, .invite, .link => api.roles.Role.parse(c.next() orelse return error.Usage) orelse return error.Usage,
        else => null,
    };
    try c.noFlags();

    const path = try arena.printSentinel("{s}/accounts.db", .{c.data_dir}, 0);
    const db = try accounts.open(path);
    defer db.close();
    const now = std.Io.Clock.real.now(io).toSeconds();
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const out = &stdout.interface;
    defer out.flush() catch {};

    const found = if (name.len > 0) try accounts.find(db, arena, name) else null;
    if (v != .add and name.len > 0 and found == null) {
        std.log.err("no account {s}", .{name});
        return 1;
    }
    var hasher: accounts.Hasher = .{};
    switch (v) {
        .add, .password, .link => {
            var in_buf: [1024]u8 = undefined;
            var stdin = std.Io.File.stdin().reader(io, &in_buf);
            const pw = std.mem.trimEnd(u8, try stdin.interface.allocRemaining(arena, .limited(1024)), "\r\n");
            const min: usize = if (v == .link) accounts.secret_min else accounts.password_min;
            if (pw.len < min or pw.len > accounts.password_max) {
                std.log.err("password on stdin: {d} to {d} characters", .{ min, accounts.password_max });
                return 1;
            }
            var phc_buf: [128]u8 = undefined;
            const phc = try hasher.hash(c.init.gpa, io, pw, &phc_buf);
            if (v == .link) {
                const t = accounts.makeLink(db, io, role.?, phc, "cli", now) catch |err| switch (err) {
                    error.BadRole => {
                        std.log.err("no sign-up link for the owner", .{});
                        return 1;
                    },
                    else => return err,
                };
                try out.print("https://meio.lol/signup.html#{s}\n", .{&t});
            } else if (v == .add) {
                _ = accounts.create(db, name, phc, role.?, now) catch |err| switch (err) {
                    error.Taken, error.OwnerExists => {
                        std.log.err("{s}: {t}", .{ name, err });
                        return 1;
                    },
                    else => return err,
                };
            } else try accounts.setPassword(db, found.?.id, phc);
        },
        .role => accounts.setRole(db, found.?.id, role.?) catch |err| switch (err) {
            error.OwnerExists => {
                std.log.err("there is an owner already", .{});
                return 1;
            },
            else => return err,
        },
        .disable, .enable => try accounts.setDisabled(db, found.?.id, v == .disable),
        .delete => try accounts.remove(db, found.?.id),
        .invite, .reset => {
            const t = if (v == .invite)
                try accounts.makeInvite(db, io, role.?, null, "cli", now)
            else
                try accounts.makeInvite(db, io, found.?.role, found.?.id, "cli", now);
            try out.print("https://meio.lol/join.html#{s}\n", .{&t});
        },
        .list => {
            var q = try db.prepare("SELECT username, role, disabled, created, last_seen FROM accounts ORDER BY id");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const r = q.row(struct { username: []const u8, role: []const u8, disabled: bool, created: i64, last_seen: ?i64 });
                try out.print("{s}\t{s}\t{s}\tcreated {d}\tlast seen {?d}\n", .{ r.username, r.role, if (r.disabled) "disabled" else "active", r.created, r.last_seen });
            }
        },
        .devices => {
            var q = try db.prepare("SELECT id, name, created, expires FROM devices WHERE account = ? ORDER BY id");
            defer q.deinit();
            try q.bind(.{found.?.id});
            while (try q.step()) {
                const r = q.row(struct { id: i64, name: []const u8, created: i64, expires: i64 });
                try out.print("{d}\t{s}\tcreated {d}\texpires {d}{s}\n", .{ r.id, r.name, r.created, r.expires, if (r.expires <= now) " (expired)" else "" });
            }
        },
        .links => {
            var q = try db.prepare("SELECT role, by, created, uses, revoked FROM signup_links ORDER BY created");
            defer q.deinit();
            try q.bind(.{});
            while (try q.step()) {
                const r = q.row(struct { role: []const u8, by: []const u8, created: i64, uses: i64, revoked: bool });
                try out.print("{s}\tby {s}\tcreated {d}\tused {d}\t{s}\n", .{ r.role, r.by, r.created, r.uses, if (r.revoked) "revoked" else "live" });
            }
        },
        .@"revoke-links" => try accounts.revokeLinks(db),
        .backup => {
            const tmp = try arena.printSentinel("{s}/accounts.db.backup", .{c.data_dir}, 0);
            const cwd = std.Io.Dir.cwd();
            cwd.deleteFile(io, tmp) catch |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            };
            try db.run("VACUUM INTO ?", .{tmp});
            defer cwd.deleteFile(io, tmp) catch {};
            try out.writeAll(try cwd.readFileAlloc(io, tmp, arena, .limited(1 << 30)));
        },
    }
    return 0;
}

pub const usage_your_example =
    \\  your-example  an anonymised player's recent games per role as GET /api/games
    \\              answers, for your.html's example (src/api/example.zig); read-only
    \\              --out FILE       default DIR/your-example.json
    \\              --curves DIR     curves-<patch>.bin files (default DIR/export)
    \\              --days N         recent days a player is picked from (default 7)
    \\
;

pub fn cmdYourExample(c: *Cmd) !u8 {
    var out: ?[]const u8 = null;
    var curves_dir: ?[]const u8 = null;
    var days: u32 = 7;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--curves")) {
            curves_dir = try c.value();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else return error.Usage;
    }
    const arena = c.arena;
    const io = c.init.io;
    const path = out orelse try std.fs.path.join(arena, &.{ c.data_dir, "your-example.json" });
    const dir = curves_dir orelse try std.fs.path.join(arena, &.{ c.data_dir, "export" });
    const set = try api.loadCurveSet(arena, io, dir);
    const db = try store.schema.openReadOnly(c.init.gpa, c.data_dir);
    defer db.close();
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const examples = try api.example.buildAll(arena, db, set, .{
        .since_ms = now_ms - @as(i64, days) * std.time.ms_per_day,
    }) orelse {
        std.log.err("no player with enough games of a role with timelines in the last {d} days", .{days});
        return 1;
    };
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = try api.example.json(arena, examples) });
    inline for (core.Role.all) |r| {
        if (@field(examples, r.label())) |ex| {
            std.log.info("{s} {s}: {d} games", .{ path, r.label(), ex.report.?.games.len });
        } else std.log.info("{s} {s}: nobody qualifies", .{ path, r.label() });
    }
    return 0;
}

pub const usage_status =
    \\  status      row counts and crawl queue state; read-only, estimates (~) for the
    \\              big tables (src/status.zig)
    \\              --exact          count every row (slow on the box)
    \\
;

pub fn cmdStatus(c: *Cmd) !u8 {
    var exact = false;
    while (c.next()) |_| {
        if (c.is("--exact")) exact = true else return error.Usage;
    }
    const db = try store.schema.openReadOnly(c.init.gpa, c.data_dir);
    defer db.close();
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(c.init.io, &buf);
    try status.write(c.arena, db, &stdout.interface, .{ .exact = exact });
    try stdout.interface.flush();
    return 0;
}

pub const usage_admin =
    \\  admin       private ops page (src/admin.zig): crawl rates from the crawl log,
    \\              storage growth (appends DIR/admin-history.tsv), ingest mix, queues
    \\              --out DIR        default DIR/admin
    \\              --log FILE       crawler log (default DIR/crawl.log)
    \\              --disk "S U A"   data disk size, used, available in bytes
    \\              --health TEXT    deploy/health.sh output
    \\              --private-out DIR  also the private site's Draft tester (/p/)
    \\
;

pub fn cmdAdmin(c: *Cmd) !u8 {
    const now = std.Io.Clock.real.now(c.init.io).toSeconds();
    var o: admin.Options = .{ .out_dir = "", .data_dir = c.data_dir, .crawl_log = "", .now_s = now };
    var out: ?[]const u8 = null;
    var log_path: ?[]const u8 = null;
    var private_out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--log")) {
            log_path = try c.value();
        } else if (c.is("--disk")) {
            var words = std.mem.tokenizeScalar(u8, try c.value(), ' ');
            var d: [3]u64 = undefined;
            for (&d) |*x| x.* = std.fmt.parseInt(u64, words.next() orelse return error.Usage, 10) catch return error.Usage;
            o.disk = d;
        } else if (c.is("--health")) {
            o.health = try c.value();
        } else if (c.is("--private-out")) {
            private_out = try c.value();
        } else return error.Usage;
    }
    o.out_dir = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "admin" });
    o.crawl_log = log_path orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "crawl.log" });
    const db = try store.open(c.init.gpa, c.data_dir);
    defer db.close();
    try admin.generate(c.init.gpa, c.init.io, db, o);
    if (private_out) |p| try admin.private(c.init.gpa, c.init.io, p, now);
    if (private_out) |p| try site_tester.write(c.init.gpa, c.init.io, p, db);
    return 0;
}
