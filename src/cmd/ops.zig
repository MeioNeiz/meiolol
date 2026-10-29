//! `meiolol api`, `your-example`, `status`, `admin`

const std = @import("std");
const store = @import("store");
const ui = @import("ui");
const core = @import("core");
const api = @import("../api/root.zig");
const admin = @import("../admin.zig");
const adminmodels = @import("../adminmodels.zig");
const site_tester = @import("../site/tester.zig");
const site_notes = @import("../site/notes.zig");
const site_admin = @import("../site/adminpage.zig");
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
    \\              --fixture        made-up players in DIR/api-fixture.db, made afresh
    \\                               (src/api/devfixture.zig), no Riot call, no key;
    \\                               run from the repo root.
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
        o.db_path = try arena.printSentinel("{s}/api-fixture.db", .{c.data_dir}, 0);
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
                try out.print("https://meio.lol/signup#{s}\n", .{&t});
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
            try out.print("https://meio.lol/join#{s}\n", .{&t});
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

pub const usage_notes =
    \\  notes       notes on the live site (src/api/notes.zig) in DIR/api.db; on C01 --data
    \\              /var/lib/meiolol-api (deploy/notes.sh runs it there)
    \\              list             open notes, one per line: id, status, scope, page,
    \\                               component, target, viewport, text
    \\                --status S     open (default), fixed, kept, done or any
    \\                --by page|component  grouped under a heading line each
    \\              show N           every field of note N
    \\              fixed N REPLY    dealt with (REPLY: the commit or plan doc); its pin
    \\                               stays for Jacob's check. A done note stays done
    \\              kept N REPLY     nothing to change, REPLY says why
    \\              done N [REPLY]   Jacob checked it
    \\              reopen N [REPLY]
    \\              reply N TEXT
    \\              --db FILE        another notes file (the dev server's data/snap/dev-notes.db)
    \\
;

pub fn cmdNotes(c: *Cmd) !u8 {
    const notes = api.notes;
    const nd = ui.notesdata;
    const arena = c.arena;
    const io = c.init.io;
    const Verb = enum { list, show, done, fixed, kept, reopen, reply };
    const v = std.meta.stringToEnum(Verb, c.next() orelse return error.Usage) orelse return error.Usage;
    var db_path: ?[]const u8 = null;
    var status_s: []const u8 = "open";
    var by: ?enum { page, component } = null;
    var words: std.ArrayList([]const u8) = .empty;
    while (c.next()) |a| {
        if (c.is("--db")) {
            db_path = try c.value();
        } else if (c.is("--status") and v == .list) {
            status_s = try c.value();
            if (!std.mem.eql(u8, status_s, "any") and std.meta.stringToEnum(nd.Status, status_s) == null) return error.Usage;
        } else if (c.is("--by") and v == .list) {
            by = std.meta.stringToEnum(@TypeOf(by.?), try c.value()) orelse return error.Usage;
        } else if (std.mem.startsWith(u8, a, "--")) {
            return error.Usage;
        } else try words.append(arena, a);
    }
    const max_words: usize = switch (v) {
        .list => 0,
        .show => 1,
        .done, .fixed, .kept, .reopen, .reply => 2,
    };
    const needs_reply = v == .reply or v == .fixed or v == .kept;
    if (words.items.len > max_words or (v != .list and words.items.len == 0) or (needs_reply and words.items.len < 2)) return error.Usage;
    const id: u32 = if (v == .list) 0 else std.fmt.parseInt(u32, words.items[0], 10) catch return error.Usage;

    const path = if (db_path) |p| try arena.printSentinel("{s}", .{p}, 0) else try arena.printSentinel("{s}/api.db", .{c.data_dir}, 0);
    const db = try store.Db.open(path);
    defer db.close();
    try notes.setUp(db);
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buf);
    const out = &stdout.interface;
    defer out.flush() catch {};
    const now = std.Io.Clock.real.now(io).toSeconds();

    // Through the API's own handler: the same checks and queries as the site
    const r = switch (v) {
        .list => try notes.handle(arena, db, .GET, try arena.print("all=1&status={s}", .{status_s}), "", "", now),
        .show => try notes.handle(arena, db, .GET, "all=1&status=any", "", "", now),
        .done, .fixed, .kept, .reopen, .reply => blk: {
            // A deploy marks its commits' notes fixed (deploy/on-push.sh), maybe after
            // Jacob already checked one
            if (v == .fixed and (try db.scalar("SELECT status FROM notes WHERE id = ?", .{id}) orelse -1) == @backingInt(nd.Status.done)) {
                try out.print("note {d} is done already: left as it is\n", .{id});
                return 0;
            }
            const reply: ?[]const u8 = if (words.items.len == 2) words.items[1] else null;
            const change: nd.Change = switch (v) {
                .done => .{ .status = .done, .reply = reply },
                .fixed => .{ .status = .fixed, .reply = reply },
                .kept => .{ .status = .kept, .reply = reply },
                .reopen => .{ .status = .open, .reply = reply },
                else => .{ .reply = reply },
            };
            var body: std.ArrayList(u8) = .empty;
            try ui.data.encode(arena, nd.Change, change, &body);
            break :blk try notes.handle(arena, db, .PATCH, try arena.print("id={d}", .{id}), body.items, "", now);
        },
    };
    if (r.status != .ok) {
        std.log.err("{s}", .{r.body});
        return 1;
    }
    switch (v) {
        .list => {
            const l = try ui.data.decode(arena, nd.List, r.body);
            const items = try arena.dupe(nd.Note, l.notes);
            const key = struct {
                fn of(g: @TypeOf(by), n: nd.Note) []const u8 {
                    return switch (g orelse return "") {
                        .page => n.path,
                        .component => n.target.component(),
                    };
                }
            }.of;
            // Grouped: by heading, then oldest first; else oldest first
            std.mem.sort(nd.Note, items, by, struct {
                fn lt(g: @TypeOf(by), a: nd.Note, b: nd.Note) bool {
                    return switch (std.mem.order(u8, key(g, a), key(g, b))) {
                        .lt => true,
                        .gt => false,
                        .eq => a.id < b.id,
                    };
                }
            }.lt);
            var last: ?[]const u8 = null;
            for (items) |n| {
                if (by != null and (last == null or !std.mem.eql(u8, last.?, key(by, n)))) {
                    last = key(by, n);
                    try out.print("== {s}\n", .{if (last.?.len > 0) last.? else "(no component)"});
                }
                try noteLine(out, n);
            }
            if (l.more) try out.print("(more than {d}: only the newest shown)\n", .{items.len});
        },
        .show => {
            const l = try ui.data.decode(arena, nd.List, r.body);
            for (l.notes) |n| if (n.id == id) {
                try noteFull(out, n);
                return 0;
            };
            std.log.err("no note {d}", .{id});
            return 1;
        },
        .done, .fixed, .kept, .reopen, .reply => try noteLine(out, try ui.data.decode(arena, nd.Note, r.body)),
    }
    return 0;
}

fn noteLine(out: *std.Io.Writer, n: ui.notesdata.Note) !void {
    const component = n.target.component();
    try out.print("{d}\t{t}\t{t}\t{s}{s}\t{s}\t{s}\t{d}x{d} {t}\t", .{
        n.id,                                      n.status,                                                n.scope, n.path, n.hash,
        if (component.len > 0) component else "-", if (n.target.snippet.len > 0) n.target.snippet else "-", n.vw,    n.vh,   n.theme,
    });
    // One line: the text's line breaks as spaces, cut at 160 bytes on a whole character
    const text = ui.notesdata.cut(n.text, 160);
    for (text) |ch| try out.writeByte(if (ch == '\n' or ch == '\r' or ch == '\t') ' ' else ch);
    if (text.len < n.text.len) try out.writeAll("…");
    if (n.reply.len > 0) try out.print("\t↳ {s}", .{n.reply});
    try out.writeByte('\n');
}

fn noteFull(out: *std.Io.Writer, n: ui.notesdata.Note) !void {
    const t = n.target;
    try out.print(
        \\id        {d}
        \\status    {t}
        \\scope     {t}
        \\page      {s}{s}
        \\target    {t} {s} nth {d} steps {s}
        \\snippet   {s}
        \\viewport  {d}x{d} {t}
        \\author    {s}
        \\created   {d}
        \\updated   {d}
        \\reply     {s}
        \\
        \\{s}
        \\
    , .{ n.id, n.status, n.scope, n.path, n.hash, t.kind, t.name, t.nth, t.steps, t.snippet, n.vw, n.vh, n.theme, n.author, n.created, n.updated, n.reply, n.text });
}

pub const usage_your_example =
    \\  your-example  an anonymised player's recent games per role as GET /api/games
    \\              answers, for /your's example (src/api/example.zig); read-only
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
    \\              --private-out DIR  also the private site's Draft tester and the
    \\                               notes tool's files (/private/)
    \\              --training DIR   only the Models tab's lab view: DIR/training.bin
    \\                               and runs/*/metrics.bin from the files
    \\                               deploy/lab-push.sh staged there (the Mac)
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
        } else if (c.is("--training")) {
            try adminmodels.training(c.init.gpa, c.init.io, try c.value());
            return 0;
        } else return error.Usage;
    }
    o.out_dir = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "admin" });
    o.crawl_log = log_path orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "crawl.log" });
    const db = try store.open(c.init.gpa, c.data_dir);
    defer db.close();
    try admin.generate(c.init.gpa, c.init.io, db, o);
    site_notes.writeAdmin(c.init.gpa, c.init.io, o.out_dir) catch |e| std.log.err("notes page: {t}", .{e});
    site_admin.write(c.init.gpa, c.init.io, o.out_dir) catch |e| std.log.err("new admin page: {t}", .{e});
    if (private_out) |p| {
        try admin.private(c.init.gpa, c.init.io, p, now);
        // web-loop.sh skips the admin and private uploads when this exits non-zero: the
        // new tester must not freeze the admin page
        site_tester.write(c.init.gpa, c.init.io, p, db) catch |e| std.log.err("tester page: {t}", .{e});
        site_notes.writeFiles(c.init.gpa, c.init.io, p) catch |e| std.log.err("notes files: {t}", .{e});
    }
    return 0;
}
