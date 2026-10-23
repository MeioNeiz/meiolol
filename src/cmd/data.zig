//! `meiolol raw-export`, `rebuild`, `rekey`, `backup`, `restore`, `forget`: the raw archive and data safety

const std = @import("std");
const store = @import("store");
const riot = @import("../riot/root.zig");
const archive = @import("../archive.zig");
const api = @import("../api/root.zig");
const backup = @import("../backup.zig");
const forget = @import("../forget.zig");
const rekey = @import("../rekey.zig");
const partials = @import("../partials.zig");
const main = @import("../main.zig");
const Cmd = main.Cmd;

pub const usage_raw_export =
    \\  raw-export  raw archive, box side (archive.zig): write raw summaries, raw timelines
    \\              and mastery fetched since the last export (at most 2 hours of it)
    \\              to DIR/raw-FROM-TO.db and print its name, counts and 1 when more
    \\              is waiting (nothing when there is nothing new); raw timelines it
    \\              holds leave raw.db at once (the file is their copy)
    \\              --out DIR        default DATA/archive-out
    \\              --list           unacked exports: NAME SIZE|received|missing
    \\              --received NAME  the gpu-box has NAME (checksum checked): delete it
    \\              --pack NAME      NAME as NAME.zst (bodies gunzipped, zstd on PATH), what
    \\                               list, send and got then use; prints NAME, both sizes, docs
    \\              --level N        zstd level for --pack (default 9)
    \\              --ack NAME       the gpu-box archived NAME: mark it, delete it if left
    \\              --prune          drop raw documents acked and older than --keep-days
    \\              --keep-days N    acked raw kept on the box this long (default 2)
    \\              --status         seconds since the last ack, unacked exports
    \\
;

pub fn cmdRawExport(c: *Cmd) !u8 {
    var dir: []const u8 = try std.fs.path.join(c.arena, &.{ c.data_dir, "archive-out" });
    var ack_name: ?[]const u8 = null;
    var received_name: ?[]const u8 = null;
    var pack_name: ?[]const u8 = null;
    var level: u8 = 9;
    var keep_days: u32 = 2;
    var show_status = false;
    var show_list = false;
    var prune = false;
    while (c.next()) |_| {
        if (c.is("--out")) {
            dir = try c.value();
        } else if (c.is("--ack")) {
            ack_name = try c.value();
        } else if (c.is("--received")) {
            received_name = try c.value();
        } else if (c.is("--pack")) {
            pack_name = try c.value();
        } else if (c.is("--level")) {
            level = try c.int(u8);
        } else if (c.is("--list")) {
            show_list = true;
        } else if (c.is("--prune")) {
            prune = true;
        } else if (c.is("--keep-days")) {
            keep_days = try c.int(u32);
        } else if (c.is("--status")) {
            show_status = true;
        } else return error.Usage;
    }
    const io = c.init.io;
    const now = std.Io.Clock.real.now(io).toSeconds();
    var buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const w = &stdout.interface;
    // The export file only: raw.db stays closed
    if (pack_name) |name| {
        if (try archive.pack(c.init.gpa, io, dir, name, level)) |p| {
            try w.print("{s}\t{d}\t{d}\t{d}\n", .{ name, p.db_bytes, p.zst_bytes, p.docs });
        } else try w.print("{s}\tpacked already\n", .{name});
        try w.flush();
        return 0;
    }
    // Status for the health check: read-only, so it never waits on an ack or the crawler
    const db = if (show_status) try store.schema.openReadOnly(c.init.gpa, c.data_dir) else try c.open();
    defer db.close();
    if (show_status) {
        const s = try archive.status(db, now);
        try w.print("since_ack_s {?d}\nunacked {d}\noldest_unacked_s {?d}\nsince_drop_s {?d}\ndrops_24h {d}\n", .{
            s.since_ack_s, s.unacked, s.oldest_unacked_s, s.since_drop_s, s.drops_24h,
        });
    } else if (show_list) {
        try archive.list(c.arena, io, db, dir, w);
    } else if (received_name) |name| {
        try archive.received(io, db, dir, name, now);
    } else if (ack_name) |name| {
        try archive.ack(io, db, dir, name, now);
        try w.print("acked {s}\n", .{name});
    } else if (prune) {
        const p = try archive.pruneAcked(db, keep_days, now);
        try w.print("dropped {d} raw summaries, {d} raw timelines, acked and {d} days old\n", .{ p.summaries, p.timelines, keep_days });
    } else if (try archive.exportNew(c.arena, io, db, dir, now)) |e| {
        try w.print("{s}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{ e.name, e.summaries, e.timelines, e.mastery, e.pruned, @intFromBool(e.more) });
    }
    try w.flush();
    return 0;
}

pub const usage_rebuild =
    \\  rebuild     re-parse kept raw match JSON into the normalised tables, and
    \\              refill participants columns taken from timelines
    \\
;

pub fn cmdRebuild(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    std.log.info("{d} matches rebuilt", .{try riot.match.rebuild(c.init.gpa, db)});
    std.log.info("{d} timelines gave gold columns", .{try riot.crawl.rebuildGold(c.init.gpa, db)});
    try partials.drop(c.init.gpa, c.init.io, try partials.dirIn(c.arena, c.data_dir));
    return 0;
}

pub const usage_rekey =
    \\  rekey       after switching to another app's key (new PUUIDs): carry the
    \\              erasure lists over (forgotten, Your games blocked) by Riot ID,
    \\              then forget players, ladder and mastery, keep matches; run
    \\              rebuild first. New key RIOT_API_KEY, old RIOT_API_KEY_OLD (env
    \\              or .env); stops if the keys share PUUIDs (docs/data-safety.md)
    \\              --dry-run        translate and report, write nothing
    \\              --fake-api       fake account-v1 instead of Riot, both keys
    \\
;

pub fn cmdRekey(c: *Cmd) !u8 {
    const io = c.init.io;
    const gpa = c.init.gpa;
    var dry_run = false;
    var fake_api = false;
    while (c.next()) |_| {
        if (c.is("--dry-run")) {
            dry_run = true;
        } else if (c.is("--fake-api")) {
            fake_api = true;
        } else return error.Usage;
    }
    const dbs: Dbs = try .open(c);
    defer dbs.close();
    const db = dbs.crawl;
    const api_db = dbs.api;
    if (db == null and api_db == null) return 1;
    var listed: std.ArrayList([]const u8) = .empty;
    var probes: []const []const u8 = &.{};
    if (db) |d| {
        try forget.ensure(d);
        try listed.appendSlice(c.arena, try rekey.readList(c.arena, d, "SELECT puuid FROM forgotten"));
        probes = try rekey.readList(c.arena, d, "SELECT puuid FROM players LIMIT 3");
    }
    if (api_db) |d| {
        try listed.appendSlice(c.arena, try rekey.readList(c.arena, d, "SELECT puuid FROM blocked"));
        if (probes.len == 0) probes = try rekey.readList(c.arena, d, "SELECT puuid FROM players LIMIT 3");
    }

    var fakes: [2]riot.fake.Fake = undefined;
    var keys: [2]?[]const u8 = .{ "fake", "fake" };
    if (fake_api) {
        for (&fakes, 0..) |*f, e| {
            f.* = try .init(gpa, io, 0);
            f.encryption = @intCast(e);
        }
    } else keys = .{ try c.envKey("RIOT_API_KEY_OLD"), try c.envKey("RIOT_API_KEY") };
    defer if (fake_api) for (&fakes) |*f| f.deinit(gpa);
    const new_key = keys[1] orelse {
        std.log.err("RIOT_API_KEY (the new key) not set (env or .env)", .{});
        return 1;
    };
    const old_key = keys[0] orelse {
        if (listed.items.len > 0) {
            std.log.err("RIOT_API_KEY_OLD not set: {d} erased players need it to carry over", .{listed.items.len});
            return 1;
        }
        std.log.warn("RIOT_API_KEY_OLD not set and nothing erased: not checking the keys", .{});
        return try rekeyApply(c, db, api_db, &.{}, dry_run);
    };
    var old_limiter: riot.ratelimit.Limiter = try .init(gpa, io);
    defer old_limiter.deinit();
    var old: riot.client.Client = .init(gpa, io, old_key, &old_limiter);
    defer old.deinit();
    var new_limiter: riot.ratelimit.Limiter = try .init(gpa, io);
    defer new_limiter.deinit();
    var new: riot.client.Client = .init(gpa, io, new_key, &new_limiter);
    defer new.deinit();
    if (fake_api) {
        old.fake = &fakes[0];
        new.fake = &fakes[1];
    }
    // Nothing is written before the plan is complete
    const plan = rekey.Plan.build(c.arena, &old, &new, listed.items, probes) catch |err| {
        switch (err) {
            error.UnexpectedStatus => std.log.err("the old key cannot read a listed PUUID " ++
                "(already rekeyed, or RIOT_API_KEY_OLD is not the old app's key)", .{}),
            error.RiotIdNotFound => std.log.err("a Riot ID changed during the translation: run again", .{}),
            error.MixedEncryption => std.log.err("some PUUIDs change and some don't: " ++
                "the lists mix both apps' PUUIDs", .{}),
            else => return err,
        }
        return 1;
    };
    if (plan.linked()) {
        std.log.info("both keys give the same PUUIDs (encryption linked): nothing to rekey", .{});
        return 0;
    }
    std.log.info("{d} erased players carried over, {d} accounts gone (dropped)", .{ plan.moved, plan.gone });
    return try rekeyApply(c, db, api_db, &plan, dry_run);
}

fn rekeyApply(c: *Cmd, db: ?store.Db, api_db: ?store.Db, plan: *const rekey.Plan, dry_run: bool) !u8 {
    if (dry_run) {
        std.log.info("dry run: nothing written", .{});
        return 0;
    }
    if (db) |d| {
        rekey.applyCrawl(c.init.gpa, d, plan) catch |err| switch (err) {
            error.ListChanged => {
                std.log.err("forgotten changed during the translation: stop the loops, run again", .{});
                return 1;
            },
            else => return err,
        };
        std.log.info("forgotten carried over; players, ladder and mastery cleared; matches kept", .{});
        try partials.drop(c.init.gpa, c.init.io, try partials.dirIn(c.arena, c.data_dir));
    }
    if (api_db) |d| {
        rekey.applyApi(c.init.gpa, d, plan) catch |err| switch (err) {
            error.ListChanged => {
                std.log.err("blocked changed during the translation: stop the service, run again", .{});
                return 1;
            },
            else => return err,
        };
        std.log.info("Your games: blocked carried over, cached players cleared", .{});
    }
    return 0;
}

/// What `forget` and `rekey` work on: the box holds the crawler databases, the web server
/// the Your games cache. Whichever this data directory has, never creating the other;
/// neither is logged
const Dbs = struct {
    crawl: ?store.Db,
    api: ?store.Db,

    fn open(c: *Cmd) !Dbs {
        const io = c.init.io;
        const cwd = std.Io.Dir.cwd();
        const crawl_path = try std.fs.path.join(c.arena, &.{ c.data_dir, "meiolol.db" });
        const api_path = try std.fs.path.joinZ(c.arena, &.{ c.data_dir, "api.db" });
        const crawl: ?store.Db = if (cwd.access(io, crawl_path, .{})) |_| try c.open() else |_| null;
        errdefer if (crawl) |d| d.close();
        const api_db: ?store.Db = if (cwd.access(io, api_path, .{})) |_| try api.cache.open(api_path) else |_| null;
        if (crawl == null and api_db == null) std.log.err("{s} holds neither meiolol.db nor api.db", .{c.data_dir});
        return .{ .crawl = crawl, .api = api_db };
    }

    fn close(d: Dbs) void {
        if (d.crawl) |x| x.close();
        if (d.api) |x| x.close();
    }
};

pub const usage_backup =
    \\  backup      consistent copy of tables and compact timelines (docs/data-safety.md)
    \\              --out DIR        default $MEIOLOL_BACKUPS or ./backups
    \\              --keep-daily N   state snapshots kept (default 7)
    \\              --keep-weekly N  plus the newest of N weeks (default 4)
    \\              --full           one segment with every match, replacing the rest
    \\
;

pub fn cmdBackup(c: *Cmd) !u8 {
    var o: backup.Options = .{
        .data_dir = c.data_dir,
        .out_dir = c.init.environ_map.get("MEIOLOL_BACKUPS") orelse "backups",
        .now = std.Io.Clock.real.now(c.init.io).toSeconds(),
    };
    // --mirror DIR --forgotten FILE: tend a mirror instead (backup.tendMirror)
    var mirror: ?[]const u8 = null;
    var forgotten: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            o.out_dir = try c.value();
        } else if (c.is("--keep-daily")) {
            o.keep_daily = try c.int(usize);
        } else if (c.is("--keep-weekly")) {
            o.keep_weekly = try c.int(usize);
        } else if (c.is("--full")) {
            o.full = true;
        } else if (c.is("--mirror")) {
            mirror = try c.value();
        } else if (c.is("--forgotten")) {
            forgotten = try c.value();
        } else return error.Usage;
    }
    if (mirror) |dir| {
        const t = try backup.tendMirror(c.arena, c.init.io, dir, try c.required(forgotten, "--forgotten"), o.keep_daily, o.keep_weekly, o.now);
        std.log.info("{s}: {d} newly forgotten scrubbed ({d} rows), {d} old state snapshots removed", .{
            dir, t.new_forgotten, t.removed.total(), t.rotated,
        });
        return 0;
    }
    const r = try backup.run(c.arena, c.init.io, o);
    std.log.info("{s}; segment {s}: {d} matches, {d} timelines, {d} drafts, {d} rank changes; " ++
        "{d} old files removed", .{
        r.state, r.segment orelse "none (nothing new)", r.matches, r.timelines, r.drafts, r.rank_history, r.removed,
    });
    return 0;
}

pub const usage_restore =
    \\  restore     rebuild --data DIR (no database there yet) from a backup
    \\              --from DIR       backup directory
    \\              --state FILE     state snapshot (default the newest)
    \\
;

pub fn cmdRestore(c: *Cmd) !u8 {
    var from: ?[]const u8 = null;
    var state_file: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--from")) {
            from = try c.value();
        } else if (c.is("--state")) {
            state_file = try c.value();
        } else return error.Usage;
    }
    const from_dir = try c.required(from, "--from");
    const now = std.Io.Clock.real.now(c.init.io).toSeconds();
    const r = backup.restore(c.arena, c.init.io, from_dir, c.data_dir, state_file, now) catch |err| {
        switch (err) {
            error.TargetNotEmpty => std.log.err("{s} holds a database: restore only into an empty directory", .{c.data_dir}),
            else => {},
        }
        return err;
    };
    std.log.info("{s}: {d} files, {d} matches, {d} timelines; {d} rows re-erased", .{
        c.data_dir, r.files, r.matches, r.timelines, r.removed.total(),
    });
    try partials.drop(c.init.gpa, c.init.io, try partials.dirIn(c.arena, c.data_dir));
    return 0;
}

pub const usage_forget =
    \\  forget      erase players from every table (docs/data-safety.md)
    \\              --puuid P        repeatable
    \\              --riot-id N#T    repeatable; needs RIOT_API_KEY
    \\              --list FILE      one PUUID or Riot ID per line (erasure lists)
    \\              --backups DIR    also scrub every backup file there
    \\              --export FILE    write every forgotten PUUID there, one per line
    \\
;

/// Logs counts only: an erasure log naming the player would defeat the erasure. PUUIDs
/// already in `forgotten` are skipped, so complete lists can be fed in again and again.
pub fn cmdForget(c: *Cmd) !u8 {
    const io = c.init.io;
    const arena = c.arena;
    var id_list: std.ArrayList([]const u8) = .empty;
    // --list given: an empty list is fine (the exchange with the Your games service)
    var listed = false;
    var backups: ?[]const u8 = null;
    var export_path: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--puuid") or c.is("--riot-id")) {
            try id_list.append(arena, try c.value());
        } else if (c.is("--list")) {
            listed = true;
            const text = try std.Io.Dir.cwd().readFileAlloc(io, try c.value(), arena, .limited(64 << 20));
            var lines = std.mem.tokenizeAny(u8, text, "\r\n");
            while (lines.next()) |line| {
                const t = std.mem.trim(u8, line, " \t");
                // Riot IDs hold '#', so only a leading one marks a comment
                if (t.len > 0 and t[0] != '#') try id_list.append(arena, t);
            }
        } else if (c.is("--backups")) {
            backups = try c.value();
        } else if (c.is("--export")) {
            export_path = try c.value();
        } else return error.Usage;
    }
    const ids = id_list.items;
    if (ids.len == 0 and !listed and export_path == null) {
        c.flag = "--puuid, --riot-id, --list or --export";
        return error.Usage;
    }
    const now = std.Io.Clock.real.now(io).toSeconds();
    var limiter: riot.ratelimit.Limiter = try .init(c.init.gpa, io);
    defer limiter.deinit();
    var client: ?riot.client.Client = null;
    defer if (client) |*cl| cl.deinit();
    const dbs: Dbs = try .open(c);
    defer dbs.close();
    const db = dbs.crawl;
    const api_db = dbs.api;
    if (db == null and api_db == null) return 1;
    var live: forget.Removed = .{};
    var scrubbed: forget.Removed = .{};
    var erased: std.ArrayList([]const u8) = .empty;
    var unresolved: usize = 0;
    var already: usize = 0;
    for (ids) |id| {
        const puuid = if (std.mem.findScalar(u8, id, '#') == null) id else blk: {
            if (client == null) client = .init(c.init.gpa, io, try c.apiKey(), &limiter);
            break :blk try forget.resolveRiotId(arena, &client.?, id) orelse {
                unresolved += 1;
                continue;
            };
        };
        if (api_db) |d| try api.cache.forget(d, puuid, now);
        const d = db orelse continue;
        if (try forget.isForgotten(d, puuid)) {
            already += 1;
            continue;
        }
        live.add(try forget.forget(d, puuid, now, .record));
        try erased.append(arena, puuid);
        if (backups) |dir| scrubbed.add(try backup.scrub(arena, io, dir, puuid, now));
    }
    if (ids.len > 0) {
        std.log.info("{d} of {d} erased, {d} already forgotten; live rows: players {d}, " ++
            "mastery {d}, participants blanked {d}, raw matches {d}, raw timelines {d}, " ++
            "rank history {d}", .{
            ids.len - unresolved - already,
            ids.len,
            already,
            live.players,
            live.mastery,
            live.participants,
            live.raw_matches,
            live.raw_timelines,
            live.rank_history,
        });
    }
    // Their PUUID hashes out of the views partials now, not at the next views write
    if (erased.items.len > 0) {
        const n = try partials.forget(c.init.gpa, io, try partials.dirIn(arena, c.data_dir), erased.items);
        std.log.info("views partials: {d} rows blanked", .{n});
    }
    if (api_db != null and ids.len > 0) std.log.info("Your games cache: erased and blocked", .{});
    if (backups != null) std.log.info("backup rows: {d}", .{scrubbed.total()});
    if (export_path) |path| {
        const d = db orelse {
            std.log.err("--export needs meiolol.db in {s}", .{c.data_dir});
            return 1;
        };
        std.log.info("{d} forgotten PUUIDs written to {s}", .{ try forget.exportList(io, d, path), path });
    }
    if (unresolved > 0) {
        std.log.warn("{d} Riot IDs have no account (renamed or deleted): resolve them by PUUID", .{unresolved});
        return 1;
    }
    return 0;
}
