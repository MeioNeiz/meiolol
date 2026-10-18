//! `meiolol`: backend. Crawls ranked solo games and timelines from the Riot API into SQLite
//! and builds the model file the app reads. Runs on the box (deploy/box.sh).

const std = @import("std");
const store = @import("store");
const core = @import("core");
pub const riot = @import("riot/root.zig");
pub const ddragon = @import("ddragon.zig");
pub const stats = @import("stats.zig");
pub const site = @import("site/root.zig");
pub const serve = @import("serve.zig");
pub const daily = @import("daily.zig");
pub const learn = @import("learn.zig");
pub const curves = @import("curves.zig");
pub const builds = @import("builds.zig");
pub const pool = @import("pool.zig");
pub const learning = @import("learning.zig");
pub const spread = @import("spread.zig");
pub const patchday = @import("patchday.zig");
pub const eval = @import("eval.zig");
pub const outcomes = @import("outcomes.zig");
pub const objectives = @import("objectives.zig");
pub const winchance = @import("winchance.zig");
pub const items = @import("items.zig");
pub const playstyle = @import("playstyle.zig");
pub const scaling = @import("scaling.zig");
pub const carry = @import("carry.zig");
pub const lean = @import("lean.zig");
pub const draftmodel = @import("draftmodel.zig");
pub const lanemodel = @import("lanemodel.zig");
const analysis = @import("analysis.zig");
const test_looks = @import("lab/looks.zig");
pub const archive = @import("archive.zig");
pub const api = @import("api/root.zig");
pub const backup = @import("backup.zig");
pub const forget = @import("forget.zig");
pub const rekey = @import("rekey.zig");
const partials = @import("partials.zig");
pub const admin = @import("admin.zig");
pub const status = @import("status.zig");
const Date = @import("date.zig").Date;

pub const std_options: std.Options = .{ .logFn = logFn };

const usage =
    \\usage: meiolol <command> [options]
    \\
    \\commands:
    \\  crawl       crawl ranked solo games (needs RIOT_API_KEY in env or .env)
    \\              --hours H        stop after H hours (default: run until stopped)
    \\              --since-days N   how far back to collect match ids (default 14)
    \\              --patch-only     match ids only from each platform's newest patch;
    \\                               older patches' matches get no timeline
    \\              --no-active-first  scan stalest players first, not those the
    \\                               ladder shows played since their last scan
    \\              --no-mastery     skip champion mastery
    \\              --mastery-sweep-days N  the first participant mastery pass after
    \\                               start covers games N days back, not 7 (one-time
    \\                               sweep; refreshes stay weekly)
    \\              --ladder-refresh-days N  refetch ladder pages after N days
    \\                               (default 7)
    \\              --ladder-refresh-hours N  the same in hours
    \\              --ladder-per-hour N  ladder pages per platform per hour at most
    \\                               (default 0: no cap)
    \\              --regions R      americas,asia,europe,sea (default all)
    \\              --timelines PCT  share of non-priority matches that also get a
    \\                               timeline, the same games on a rerun (default 100)
    \\              --timelines-priority PCT  the same for --priority matches (default
    \\                               100)
    \\              --timeline-min-s S  no timeline for matches shorter than S seconds
    \\                               (default 0: every length)
    \\              --timelines-sparse N  a match the sample skips still gets a
    \\                               timeline while a lane of it has under N in its
    \\                               champion pair and rank cell this patch (default
    \\                               0: off; docs/data.md)
    \\              --timelines-sparse-from TIER  --timelines-sparse only for games of
    \\                               median rank TIER and up
    \\              --flex-calls-per-day N  ranked flex id lookups a day for --priority
    \\                               players, a test sample (default 0; queue 420 only on
    \\                               the site and in models)
    \\              --raw-timeline-days N  keep raw timeline JSON N days (default 7,
    \\                                     0 none)
    \\              --raw-match-days N     keep raw match JSON N days (default 30,
    \\                                     0 forever)
    \\              --raw-valve-free-gb N  under N GB free on the data disk, drop raw
    \\                               the archive never got, oldest first, logged in
    \\                               DATA/raw-dropped.log (default 0: never)
    \\              --keep-days N    rolling window: drop matches, their rows and
    \\                               timelines N days after game start (default 0,
    \\                               kept forever)
    \\              --no-participant-players  scan ladder players only, not every
    \\                               match participant
    \\              --cache-mb N     the writer's page cache (default 64)
    \\              --player-sample N  keep full player rows (the scan pool) for 1
    \\                               ladder player in N; ranks has everyone (default 1)
    \\              --priority P     platforms whose players and matches come first
    \\                               in their region; its region's writes go first
    \\                               when the machine falls behind (default EUW1,
    \\                               "none" for none)
    \\              --min-tier T     lowest tier walked on the ladder and scanned for
    \\                               matches (e.g. PLATINUM: Platinum IV and up;
    \\                               default IRON, everyone)
    \\              --proxy HOST:PORT  serve the Your games service's Riot calls
    \\                               through the crawler's limiters, ahead of the crawl
    \\                               (box: 10.0.0.3:8092, the private address)
    \\  stats       write the model file the app reads (ranked solo, no remakes)
    \\              --patch P        patch to include, repeatable or comma separated
    \\                               (default: the newest patch)
    \\              --out FILE       default DIR/export/stats-<patch>.bin
    \\              --platform P     Riot platform id, repeatable or comma separated
    \\                               (default EUW1; "all" for every platform in
    \\                               riot/endpoints.zig)
    \\  curves      write lane matchup curves from match timelines (curvesfile.zig)
    \\              --patch P        as for stats (default: every patch of the last
    \\                               --days, to DIR/export/recent-curves.bin)
    \\              --days N         default 30
    \\              --platform P     as for stats
    \\              --out FILE       default DIR/export/curves-<patch>.bin (all-curves-...
    \\                               and all-recent-curves.bin with --platform all)
    \\              --min-games N    leave out matchups with fewer games (default 10;
    \\                               the fit still uses every game)
    \\              --site           the files the site reads, in one pass over the
    \\                               timelines: EUW and every platform, last --days
    \\                               and (with --patch) that patch, default paths
    \\              --format-version print the file format version this binary writes
    \\                               and reads, then exit (deploy/web-loop.sh)
    \\  builds      write what players build per champion and role (builds.zig): runes,
    \\              summoner spells, starting items, boots, first items, skill order;
    \\              JSON the site reads (needs Data Dragon)
    \\              --patch P        as for stats (default: the newest patch)
    \\              --platform P     as for stats
    \\              --min-tier T     lowest rank counted, per player (default PLATINUM;
    \\                               "any" counts everyone, unranked too)
    \\              --max-keys N     distinct options held in memory (default 524288)
    \\              --out FILE       default DIR/export/builds-<patch>.json
    \\                               (all-builds-... with --platform all)
    \\              --site           the files the site reads, in one pass over the
    \\                               timelines: EUW and every platform, default paths
    \\  pool        write what players of each champion also play (pool.zig), as JSON
    \\              --patch P        as for stats (matchups); pools use every patch
    \\              --platform P     as for stats
    \\              --out FILE       default DIR/export/pool.json
    \\  eval        how well the draft model predicts held-out newer games (markdown
    \\              report on stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats
    \\              --test-share F   newest share of played games held out, one time cut
    \\                               over every platform (default 0.15)
    \\              --folds K        folds for tuning inside train (default 5)
    \\              --test-platform P  region model only (the global model is never scored
    \\                               on a region): test on P's games from the cut;
    \\                               compares training on P
    \\                               alone with every --platform pooled
    \\              --history FILE   append one TSV line (date, sizes, log loss and AUC
    \\                               per model) for the accuracy-vs-data curve
    \\  outcomes    do allies and enemies shift gold@14, lane gold, CS@10, deaths before 15
    \\              and first item beyond champion and lane? (markdown on stdout)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats (train uses every one given)
    \\              --test-platform P  region model only: test on P's games from the cut;
    \\                               the global model is never scored on a region
    \\              --test-share F   newest share of played games, every platform, held
    \\                               out (default 0.15: the protocol's cut over every
    \\                               platform's and patch's games, whatever is scanned)
    \\              --preds DIR      one TSV of test predictions per model
    \\  legendaries write DATA/legendaries.tsv, the finished items of every patch in the
    \\              data (Data Dragon; outcomes and meiolol-lab's first_item read it)
    \\              --patch P, --platform P  as for stats
    \\  winchance   fit win chance by minute from the game state (Your games' turning
    \\              minute and death cost): weights as Zig source, check on test games
    \\              (docs/model.md protocol) on stdout
    \\              --out FILE       default src/winchance_weights.zig
    \\              --dev            score every fifth train game instead (no weights
    \\                               unless --out)
    \\              --knots 1,5,...  the smooth fit's knot minutes
    \\  objectives  what is an objective worth beyond its gold? win from the state at
    \\              10-30 min (markdown on stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats (train uses every one given)
    \\              --test-platform P  region model only: test on P's games from the cut;
    \\                               the global model is never scored on a region
    \\              --test-share F   newest share of played games, every platform, held
    \\                               out (default 0.15: the protocol's cut over every
    \\                               platform's and patch's games, whatever is scanned)
    \\              --preds DIR      one TSV of test predictions per model
    \\  items       does the finished item change the win chance, given the state when it
    \\              was bought? (markdown on stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats (train uses every one given)
    \\              --test-platform P  region model only: test on P's games from the cut;
    \\                               the global model is never scored on a region
    \\              --test-share F   newest share of played games, every platform, held
    \\                               out (default 0.15: the protocol's cut over every
    \\                               platform's and patch's games, whatever is scanned)
    \\              --preds DIR      one TSV of test predictions per model
    \\  playstyle   does early style (roaming, fights, wards) change the win chance, beyond
    \\              the champion and the state at 14:00? (markdown on stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats (train uses every one given)
    \\              --test-platform P  region model only: test on P's games from the cut;
    \\                               the global model is never scored on a region
    \\              --test-share F   newest share of played games, every platform, held
    \\                               out (default 0.15: the protocol's cut over every
    \\                               platform's and patch's games, whatever is scanned)
    \\              --preds DIR      one TSV of test predictions per model
    \\  scaling     which champions win more than the gold and XP lead says, by minute
    \\              (scaling) and by the lead (converting it, coming back)? (markdown on
    \\              stdout; docs/model.md)
    \\              --patch P        as for stats (default: every patch, pooled)
    \\              --platform P     as for stats (train uses every one given)
    \\              --test-platform P  region model only: test on P's games from the cut;
    \\                               the global model is never scored on a region
    \\              --test-share F   newest share of played games, every platform, held
    \\                               out (default 0.15: the protocol's cut over every
    \\                               platform's and patch's games, whatever is scanned)
    \\              --preds DIR      one TSV of test predictions per model
    \\              --table FILE     TSV of every champion-role's effect and slope by minute
    \\              --state S        baseline: lead (team gold, XP; default), roles (gold
    \\                               by role: who holds it), objectives (+ objectives held)
    \\              --slope L        champion x lead term: team (default) or own (own gold
    \\                               minus the lane opponent's)
    \\  carry       which champions turn their own lead into wins, whose seat decides games,
    \\              which reward experience, which make games more decided? (markdown on
    \\              stdout; docs/model.md "Carry and impact")
    \\              --cuts A,B,C,D,E,DEV,TEST  ms: the lab's 5 fold block starts, dev
    \\                               and test cuts (default: eval.split's, as the lab's)
    \\              --patch P, --platform P, --test-share F  as scaling (default 0.15)
    \\              --test-platform P  region model only: dev-val and test on P's games;
    \\                               the global model is never scored on a region
    \\              --final          also score the test games (one look per model)
    \\              --table FILE     TSV of every champion-role's terms by minute
    \\              --type-table FILE  TSV of champion type x role x state terms by minute
    \\              --fold-table FILE  per fold and dev: leverage, scaling, skill per
    \\                               champion-role fitted before the block
    \\              --plant COV:SD[:SEED]  redraw winners with a planted champion slope on
    \\                               lane, kd, dmg or exp, sd SD win pp per unit
    \\  lean        early or late: each champion-role's team gold lead at 14 min and its
    \\              win from an even game at 20 min, shrunk (docs/model.md "Early and late
    \\              champions"); the champion pages' line. Writes DATA/lean.tsv
    \\              --platform P     default all; --days N  games of the last N (30)
    \\              --out FILE       instead of DATA/lean.tsv
    \\              --check          lab: folds and dev-val (markdown on stdout), no test
    \\              --cuts A,B,C,D,E,DEV,TEST  as carry's; --table FILE  dev fit's rows
    \\  draft-model the shipped draft model on every played game as the admin Draft
    \\              tester's draft-model.json and draft-ref.json (docs/model.md "Draft model
    \\              file"); daily on the box
    \\              --out DIR        default DATA/tester
    \\  lane-model  the Draft tester's lane model (lab candidate team2: gold at 14, lane gold,
    \\              CS at 10, deaths before 15 for a champion into a lane opponent) on every
    \\              played game, as lane-model.json and lane-ref.json; daily on the box
    \\              --out DIR        default DATA/tester
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
    \\  site       write the public website (static files): EUW over the last 30 days
    \\              at the root, the patch under patch/, every region under all/ and
    \\              all/patch/ (lane curves and builds: the curves and builds
    \\              commands' default files); patch.html compares the patch with
    \\              the one before (its curves too, where `curves --patch` wrote them)
    \\              --patch P        the patch views' (default: EUW's newest patch)
    \\              --out DIR        default DIR/site
    \\              --contact EMAIL  shown on the privacy and terms pages (required)
    \\              --riot-txt TEXT  served as /riot.txt (Riot's verification string)
    \\              --public         listed for search engines, no preview banner; only
    \\                               once Riot grants the production key
    \\              --euw-only       the EUW views only (root, patch/): a quick preview
    \\              --static-min-games N  leave out matchup pages under N games (for
    \\                               `render` to serve on request)
    \\              --static core    write only the home page, robots.txt, riot.txt,
    \\                               the root sitemap and the front-end files;
    \\                               `render` serves every other page and file
    \\              --origin URL     site URL for canonical links and sitemaps (public)
    \\              --index-min-games N  matchup pages under N games noindex and out of
    \\                               the sitemaps
    \\              --views FILE     load every view and write it to FILE for
    \\                               `render --views` instead of the site
    \\              --views-format   print the fingerprint a views file from this
    \\                               binary has (u64 after the 8-byte magic)
    \\              --reuse          with --views: keep the parts of the file already
    \\                               there that this binary would make the same way
    \\                               (a deploy's round), load only the rest
    \\              --no-partials    with --views: read every game from the database,
    \\                               not data/partials (docs/architecture.md "Views
    \\                               partials"), which is left alone
    \\              --patch-games    print the EUW patch the site would show and its
    \\                               game count (no site; deploy/web-loop.sh)
    \\  dev        work on the site: pages rendered on request from DIR (data loaded
    \\              once), CSS and JS from src/site/static, live reload; run by
    \\              deploy/dev.sh, which rebuilds on edits. Takes site's flags
    \\              --port P         default 8080
    \\  render     the pages `site --static` leaves out, rendered on request
    \\              for the web server's nginx (all views loaded up front). Takes
    \\              site's flags (--contact required)
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8091
    \\              --reload FILE    load the data again whenever FILE changes
    \\              --ready FILE     written once listening, holding the served
    \\                               data's version (again at each reload) for
    \\                               jomify's nginx cache key. Several may share
    \\                               the port (SO_REUSEPORT): deploy/render-swap.sh
    \\              --views FILE     load from FILE (`site --views`), at start and
    \\                               on --reload, in seconds; the database when it
    \\                               is missing or another binary's types wrote it
    \\  serve       serve the website (default DIR/site) over HTTP, for the tunnel
    \\              --host H         default 127.0.0.1 (local only)
    \\              --port P         default 8080
    \\              --out DIR        site directory to serve
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
    \\  your-example  an anonymised player's recent games per role as GET /api/games
    \\              answers, for your.html's example (src/api/example.zig); read-only
    \\              --out FILE       default DIR/your-example.json
    \\              --curves DIR     curves-<patch>.bin files (default DIR/export)
    \\              --days N         recent days a player is picked from (default 7)
    \\  status      row counts and crawl queue state; read-only, estimates (~) for the
    \\              big tables (src/status.zig)
    \\              --exact          count every row (slow on the box)
    \\  admin       private ops page (src/admin.zig): crawl rates from the crawl log,
    \\              storage growth (appends DIR/admin-history.tsv), ingest mix, queues
    \\              --out DIR        default DIR/admin
    \\              --log FILE       crawler log (default DIR/crawl.log)
    \\              --days N         history shown (default 7)
    \\              --disk "S U A"   data disk size, used, available in bytes
    \\              --health TEXT    deploy/health.sh output
    \\  rebuild     re-parse kept raw match JSON into the normalised tables, and
    \\              refill participants columns taken from timelines
    \\  rekey       after switching to another app's key (new PUUIDs): carry the
    \\              erasure lists over (forgotten, Your games blocked) by Riot ID,
    \\              then forget players, ladder and mastery, keep matches; run
    \\              rebuild first. New key RIOT_API_KEY, old RIOT_API_KEY_OLD (env
    \\              or .env); stops if the keys share PUUIDs (docs/data-safety.md)
    \\              --dry-run        translate and report, write nothing
    \\              --fake-api       fake account-v1 instead of Riot, both keys
    \\  champions   refresh champion ids and names from Data Dragon
    \\  draft-backfill  add the draft rows (kept forever) of matches stored before the
    \\              drafts table existed; once, alongside the crawler
    \\              --chunk N        matches per transaction (default 200)
    \\              --pause-ms MS    between chunks, so the crawler gets the lock
    \\                               (default 1000)
    \\  backup      consistent copy of tables and compact timelines (docs/data-safety.md)
    \\              --out DIR        default $MEIOLOL_BACKUPS or ./backups
    \\              --keep-daily N   state snapshots kept (default 7)
    \\              --keep-weekly N  plus the newest of N weeks (default 4)
    \\              --full           one segment with every match, replacing the rest
    \\  restore     rebuild --data DIR (no database there yet) from a backup
    \\              --from DIR       backup directory
    \\              --state FILE     state snapshot (default the newest)
    \\  forget      erase players from every table (docs/data-safety.md)
    \\              --puuid P        repeatable
    \\              --riot-id N#T    repeatable; needs RIOT_API_KEY
    \\              --list FILE      one PUUID or Riot ID per line (erasure lists)
    \\              --backups DIR    also scrub every backup file there
    \\              --export FILE    write every forgotten PUUID there, one per line
    \\
    \\options for all commands:
    \\  --data DIR  data directory (default $MEIOLOL_DATA or ./data)
    \\
    \\exit codes: 0 ok, 1 error, 2 bad usage, 3 Riot rejected the API key
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const argv = try init.minimal.args.toSlice(arena);
    if (argv.len < 2) return usageError(null);
    const run = commands.get(argv[1]) orelse return usageError(argv[1]);
    var c: Cmd = .{
        .init = init,
        .arena = arena,
        .data_dir = init.environ_map.get("MEIOLOL_DATA") orelse "data",
    };
    // --data is for every command; the rest are the command's own
    var flags: std.ArrayList([]const u8) = .empty;
    var i: usize = 2;
    while (i < argv.len) : (i += 1) {
        if (std.mem.eql(u8, argv[i], "--data") and i + 1 < argv.len) {
            i += 1;
            c.data_dir = argv[i];
        } else try flags.append(arena, argv[i]);
    }
    c.args = flags.items;
    try std.Io.Dir.cwd().createDirPath(init.io, c.data_dir);
    return run(&c) catch |err| switch (err) {
        error.Usage => usageError(c.flag),
        // Logged where it happened
        error.NoApiKey => 1,
        else => err,
    };
}

const commands = std.StaticStringMap(*const fn (*Cmd) anyerror!u8).initComptime(.{
    .{ "crawl", cmdCrawl },
    .{ "stats", cmdStats },
    .{ "curves", cmdCurves },
    .{ "builds", cmdBuilds },
    .{ "pool", cmdPool },
    .{ "eval", cmdEval },
    .{ "outcomes", cmdOutcomes },
    .{ "legendaries", cmdLegendaries },
    .{ "objectives", cmdObjectives },
    .{ "winchance", cmdWinchance },
    .{ "items", cmdItems },
    .{ "playstyle", cmdPlaystyle },
    .{ "scaling", cmdScaling },
    .{ "carry", cmdCarry },
    .{ "lean", cmdLean },
    .{ "draft-model", cmdDraftModel },
    .{ "lane-model", cmdLaneModel },
    .{ "raw-export", cmdRawExport },
    .{ "site", cmdSite },
    .{ "serve", cmdServe },
    .{ "dev", cmdDev },
    .{ "render", cmdRender },
    .{ "api", cmdApi },
    .{ "your-example", cmdYourExample },
    .{ "status", cmdStatus },
    .{ "admin", cmdAdmin },
    .{ "rebuild", cmdRebuild },
    .{ "rekey", cmdRekey },
    .{ "champions", cmdChampions },
    .{ "draft-backfill", cmdDraftBackfill },
    .{ "backup", cmdBackup },
    .{ "restore", cmdRestore },
    .{ "forget", cmdForget },
});

/// What a command gets: the process, the data directory and a cursor over its own
/// flags. A flag it doesn't take, or a bad value, is error.Usage (exit 2)
const Cmd = struct {
    init: std.process.Init,
    arena: std.mem.Allocator,
    data_dir: []const u8,
    args: []const []const u8 = &.{},
    i: usize = 0,
    /// The flag being read, named in the usage error
    flag: ?[]const u8 = null,

    fn next(c: *Cmd) ?[]const u8 {
        if (c.i >= c.args.len) return null;
        c.flag = c.args[c.i];
        c.i += 1;
        return c.flag;
    }

    fn is(c: *const Cmd, name: []const u8) bool {
        return std.mem.eql(u8, c.flag.?, name);
    }

    /// The current flag's value
    fn value(c: *Cmd) error{Usage}![]const u8 {
        if (c.i >= c.args.len) return error.Usage;
        c.i += 1;
        return c.args[c.i - 1];
    }

    fn int(c: *Cmd, comptime T: type) error{Usage}!T {
        return std.fmt.parseInt(T, try c.value(), 10) catch error.Usage;
    }

    fn float(c: *Cmd) error{Usage}!f64 {
        return std.fmt.parseFloat(f64, try c.value()) catch error.Usage;
    }

    /// A comma separated value, split
    fn list(c: *Cmd) ![]const []const u8 {
        var out: std.ArrayList([]const u8) = .empty;
        var it = std.mem.tokenizeScalar(u8, try c.value(), ',');
        while (it.next()) |v| try out.append(c.arena, v);
        return out.items;
    }

    fn noFlags(c: *Cmd) error{Usage}!void {
        if (c.next() != null) return error.Usage;
    }

    fn required(c: *Cmd, v: ?[]const u8, name: []const u8) error{Usage}![]const u8 {
        c.flag = name;
        return v orelse error.Usage;
    }

    fn open(c: *const Cmd) !store.Db {
        return store.open(c.init.gpa, c.data_dir);
    }

    fn apiKey(c: *const Cmd) ![]const u8 {
        return try c.envKey("RIOT_API_KEY") orelse {
            std.log.err("RIOT_API_KEY not set (env or .env)", .{});
            return error.NoApiKey;
        };
    }

    /// `name` from the environment, else from ./.env
    fn envKey(c: *const Cmd, name: []const u8) !?[]const u8 {
        if (c.init.environ_map.get(name)) |k| return k;
        const text = std.Io.Dir.cwd().readFileAlloc(c.init.io, ".env", c.arena, .limited(64 * 1024)) catch |err| switch (err) {
            error.FileNotFound => "",
            else => return err,
        };
        var lines = std.mem.tokenizeAny(u8, text, "\r\n");
        while (lines.next()) |line| {
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            if (std.mem.eql(u8, std.mem.trim(u8, line[0..eq], " "), name)) {
                return std.mem.trim(u8, line[eq + 1 ..], " \"'");
            }
        }
        return null;
    }
};

/// --patch and --platform: the games stats, curves, pool and eval read
const Games = struct {
    patches: std.ArrayList([]const u8) = .empty,
    platforms: std.ArrayList([]const u8) = .empty,
    /// --platform all: output files get the all- prefix
    every_platform: bool = false,

    /// Reads the current flag if it is one of these
    fn parse(g: *Games, c: *Cmd) !bool {
        if (c.is("--patch")) {
            try g.patches.appendSlice(c.arena, try c.list());
        } else if (c.is("--platform")) {
            for (try c.list()) |p| {
                if (std.mem.eql(u8, p, "all")) {
                    g.every_platform = true;
                    for (riot.endpoints.platforms) |pl| try g.platforms.append(c.arena, pl.id);
                } else try g.platforms.append(c.arena, p);
            }
        } else return false;
        return true;
    }

    /// EUW1 unless given: the site says EUW
    fn platformIds(g: *const Games) []const []const u8 {
        return if (g.platforms.items.len > 0) g.platforms.items else &.{"EUW1"};
    }
};

fn cmdCrawl(c: *Cmd) !u8 {
    var o: riot.crawl.Options = .{ .data_dir = c.data_dir, .key = "" };
    var regions: std.ArrayList(riot.endpoints.Region) = .empty;
    var fake_api_ms: ?u32 = null;
    while (c.next()) |_| {
        if (c.is("--no-mastery")) {
            o.mastery = false;
        } else if (c.is("--mastery-sweep-days")) {
            o.mastery_sweep_days = try c.int(u32);
        } else if (c.is("--no-participant-players")) {
            o.participant_players = false;
        } else if (c.is("--hours")) {
            o.hours = try c.float();
        } else if (c.is("--since-days")) {
            o.since_days = try c.int(i64);
        } else if (c.is("--patch-only")) {
            o.patch_only = true;
        } else if (c.is("--no-active-first")) {
            o.active_first = false;
        } else if (c.is("--ladder-refresh-hours")) {
            o.ladder_refresh_s = try c.int(i64) * 3600;
        } else if (c.is("--ladder-refresh-days")) {
            o.ladder_refresh_s = try c.int(i64) * std.time.s_per_day;
        } else if (c.is("--ladder-per-hour")) {
            o.ladder_per_hour = try c.int(u32);
        } else if (c.is("--player-sample")) {
            o.player_sample = try c.int(u32);
        } else if (c.is("--keep-days")) {
            o.keep_days = try c.int(u32);
        } else if (c.is("--cache-mb")) {
            o.cache_mb = try c.int(u32);
        } else if (c.is("--regions")) {
            for (try c.list()) |r| {
                const region = std.meta.stringToEnum(riot.endpoints.Region, r) orelse return error.Usage;
                try regions.append(c.arena, region);
            }
        } else if (c.is("--timelines")) {
            o.timeline_percent = try c.int(u8);
            if (o.timeline_percent > 100) return error.Usage;
        } else if (c.is("--timelines-priority")) {
            o.timeline_priority_percent = try c.int(u8);
            if (o.timeline_priority_percent > 100) return error.Usage;
        } else if (c.is("--timeline-min-s")) {
            o.timeline_min_s = try c.int(u32);
        } else if (c.is("--timelines-sparse")) {
            o.timeline_sparse = try c.int(u32);
        } else if (c.is("--timelines-sparse-from")) {
            o.timeline_sparse_min_rank = riot.sparse.rankOf(try c.value()) orelse return error.Usage;
        } else if (c.is("--flex-calls-per-day")) {
            o.flex_calls_per_day = try c.int(u32);
        } else if (c.is("--raw-timeline-days")) {
            o.raw_timeline_days = try c.int(u32);
        } else if (c.is("--raw-match-days")) {
            o.raw_match_days = try c.int(u32);
        } else if (c.is("--raw-valve-free-gb")) {
            o.raw_valve_free_mb = try c.int(u64) * 1024;
        } else if (c.is("--priority")) {
            var priority: std.ArrayList([]const u8) = .empty;
            for (try c.list()) |p| {
                if (std.mem.eql(u8, p, "none")) continue;
                if (riot.endpoints.platform(p) == null) return error.Usage;
                try priority.append(c.arena, p);
            }
            o.priority = priority.items;
        } else if (c.is("--min-tier")) {
            const tier = try c.value();
            o.min_tier = for (store.schema.tiers, 0..) |t, i| {
                if (std.ascii.eqlIgnoreCase(t, tier)) break i;
            } else return error.Usage;
        } else if (c.is("--proxy")) {
            o.proxy = try c.value();
        } else if (c.is("--fake-api")) {
            // Benchmark only, not in usage: canned answers after MS ms (deploy/bench-crawl.sh)
            fake_api_ms = try c.int(u32);
        } else return error.Usage;
    }
    if (regions.items.len > 0) o.regions = regions.items;
    var fake: ?riot.fake.Fake = if (fake_api_ms) |ms| try .init(c.init.gpa, c.init.io, ms) else null;
    defer if (fake) |*f| f.deinit(c.init.gpa);
    if (fake) |*f| {
        o.fake = f;
        o.key = "fake";
    } else o.key = try c.apiKey();
    var crawler: riot.crawl.Crawler = .{ .gpa = c.init.gpa, .io = c.init.io, .opts = o };
    crawler.run() catch |err| switch (err) {
        error.KeyRejected => return 3,
        else => return err,
    };
    return 0;
}

fn cmdStats(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) out = try c.value() else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try newestPatch(c.arena, db, platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    const path = out orelse
        try c.arena.print("{s}/export/stats-{s}.bin", .{ c.data_dir, label });

    var r = try stats.build(c.init.gpa, db, chosen, platforms);
    defer r.builder.deinit();
    if (r.summary.games == 0) {
        std.log.err("no complete ranked solo games on patch {s}", .{label});
        return error.NoMatches;
    }
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try r.builder.write(&w.interface, label);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: patch {s}, {d} games ({d} skipped), {d} champions", .{
        path, label, r.summary.games, r.summary.skipped, r.builder.ids.len,
    });
    return 0;
}

fn cmdCurves(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var days: u32 = 30;
    // Thinner curves were 71% of the file (16.20) and their spreads are noise; readers
    // need 10 games at a minute anyway, and fall back to all ranks or the plain average
    var min_games: u32 = 10;
    var site_files = false;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--min-games")) {
            min_games = try c.int(u32);
        } else if (c.is("--site")) {
            site_files = true;
        } else if (c.is("--format-version")) {
            var buf: [16]u8 = undefined;
            var stdout = std.Io.File.stdout().writer(c.init.io, &buf);
            try stdout.interface.print("{d}\n", .{core.curvesfile.version});
            try stdout.interface.flush();
            return 0;
        } else return error.Usage;
    }
    if (site_files and (out != null or g.platforms.items.len > 0)) return error.Usage;
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const db = try c.open();
    defer db.close();
    const wanted = g.patches.items;
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const recent_ms = now_ms - @as(i64, days) * std.time.ms_per_day;
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const recent_label = try arena.print("last {d} days", .{days});
    const patch_label = if (wanted.len > 0) try arena.dupe(u8, try stats.label(&label_buf, wanted)) else "";

    const File = struct { spec: curves.Spec, label: []const u8, path: []const u8 };
    var files: std.ArrayList(File) = .empty;
    if (site_files) {
        var every: std.ArrayList([]const u8) = .empty;
        for (riot.endpoints.platforms) |pl| try every.append(arena, pl.id);
        for ([_]bool{ false, true }) |all| {
            const platforms: []const []const u8 = if (all) every.items else &.{"EUW1"};
            try files.append(arena, .{
                .spec = .{ .chosen = &.{}, .since_ms = recent_ms, .platforms = platforms },
                .label = recent_label,
                .path = try recentCurvesPath(arena, c.data_dir, all),
            });
            if (wanted.len > 0) try files.append(arena, .{
                .spec = .{ .chosen = wanted, .since_ms = 0, .platforms = platforms },
                .label = patch_label,
                .path = try curvesPath(arena, c.data_dir, wanted, all),
            });
        }
    } else {
        const path = out orelse if (wanted.len > 0)
            try curvesPath(arena, c.data_dir, wanted, g.every_platform)
        else
            try recentCurvesPath(arena, c.data_dir, g.every_platform);
        try files.append(arena, .{
            .spec = .{
                .chosen = wanted,
                .since_ms = if (wanted.len > 0) 0 else recent_ms,
                .platforms = g.platformIds(),
            },
            .label = if (wanted.len > 0) patch_label else recent_label,
            .path = path,
        });
    }
    // --site: EUW's patch for every file, so EUW's files match a run of their own
    const item_patch = if (wanted.len > 0)
        wanted[0]
    else
        (try newestPatch(arena, db, if (site_files) &.{"EUW1"} else g.platformIds()))[0];

    const legendaries = ddragon.legendaries(gpa, io, item_patch) catch |err| blk: {
        std.log.warn("no item list from Data Dragon ({t}): curves without first items", .{err});
        break :blk &.{};
    };
    defer gpa.free(legendaries);
    const specs = try arena.alloc(curves.Spec, files.items.len);
    for (files.items, specs) |f, *s| s.* = f.spec;
    const builders = try arena.alloc(core.curvesfile.Builder, files.items.len);
    @memset(builders, .{ .gpa = gpa });
    defer for (builders) |*b| b.deinit();
    const summaries = try arena.alloc(curves.Summary, files.items.len);
    try curves.buildMany(gpa, db, specs, legendaries, builders, summaries);

    var missing = false;
    for (files.items, builders, summaries) |f, *b, sum| {
        if (sum.games == 0) {
            std.log.err("no ranked solo games with timelines for {s}: {s}", .{ f.label, f.path });
            missing = true;
            continue;
        }
        var file = try std.Io.Dir.cwd().createFileAtomic(io, f.path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var w = file.file.writer(io, &buf);
        try b.write(&w.interface, f.label, min_games);
        try w.interface.flush();
        try file.replace(io);
        std.log.info("{s}: {s}, {d} games ({d} skipped)", .{ f.path, f.label, sum.games, sum.skipped });
        // Freed as it goes: the next file's fit needs the room
        b.deinit();
        b.* = .{ .gpa = gpa };
    }
    if (missing) return error.NoMatches;
    return 0;
}

fn cmdBuilds(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var site_files = false;
    var o: builds.Options = .{ .patches = &.{}, .platforms = &.{} };
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--min-tier")) {
            const t = try c.value();
            o.min_tier = if (std.mem.eql(u8, t, "any")) null else t;
        } else if (c.is("--max-keys")) {
            o.max_keys = try c.int(usize);
        } else if (c.is("--site")) {
            site_files = true;
        } else return error.Usage;
    }
    if (site_files and (out != null or g.platforms.items.len > 0)) return error.Usage;
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var every: std.ArrayList([]const u8) = .empty;
    for (riot.endpoints.platforms) |pl| try every.append(c.arena, pl.id);
    o.platforms = if (site_files) every.items else g.platformIds();
    o.patches = if (g.patches.items.len > 0) g.patches.items else try newestPatch(c.arena, db, if (site_files) &.{"EUW1"} else o.platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, o.patches);
    const Target = struct { platforms: []const []const u8, path: []const u8 };
    const targets: []const Target = if (site_files) &.{
        .{ .platforms = &.{"EUW1"}, .path = try buildsPath(c.arena, c.data_dir, o.patches, false) },
        .{ .platforms = every.items, .path = try buildsPath(c.arena, c.data_dir, o.patches, true) },
    } else &.{
        .{ .platforms = o.platforms, .path = out orelse try buildsPath(c.arena, c.data_dir, o.patches, g.every_platform) },
    };
    const data = try ddragon.buildData(gpa, c.arena, io, o.patches[0]);

    var sets: [2][]const []const u8 = undefined;
    for (targets, 0..) |t, i| sets[i] = t.platforms;
    var bs: [2]builds.Builder = undefined;
    try builds.buildEach(gpa, db, &data, o, sets[0..targets.len], bs[0..targets.len]);
    defer for (bs[0..targets.len]) |*b| b.deinit();
    for (targets, bs[0..targets.len]) |t, *b| {
        if (b.games == 0) {
            std.log.err("{s}: no ranked solo games on patch {s}", .{ t.path, label });
            return error.NoMatches;
        }
        const f = try b.file(c.arena, &data, label, o.min_tier orelse "", o.rows);
        var file = try std.Io.Dir.cwd().createFileAtomic(io, t.path, .{ .make_path = true, .replace = true });
        defer file.deinit(io);
        var buf: [64 * 1024]u8 = undefined;
        var w = file.file.writer(io, &buf);
        try std.json.Stringify.value(f, .{}, &w.interface);
        try w.interface.flush();
        try file.replace(io);
        std.log.info("{s}: patch {s}, {d} games ({d} with timelines), {d} champion roles, {d} options held", .{
            t.path, label, b.games, b.timelines, f.builds.len, b.options.count(),
        });
    }
    return 0;
}

fn cmdPool(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) out = try c.value() else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const arena = c.arena;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try newestPatch(arena, db, platforms);
    var r = try stats.build(gpa, db, chosen, platforms);
    defer r.builder.deinit();
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    var model: std.Io.Writer.Allocating = .init(arena);
    try r.builder.write(&model.writer, try stats.label(&label_buf, chosen));
    const st: core.Stats = try .parse(arena, model.written());
    var t = try pool.tally(gpa, db, &st, &.{platforms});
    defer t.deinit(gpa);
    const p = try pool.make(arena, &t, 0, &st, .{});

    const path = out orelse try std.fs.path.join(arena, &.{ c.data_dir, "export", "pool.json" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    try pool.writeJson(&w.interface, p);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}", .{path});
    return 0;
}

fn cmdEval(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: eval.Options = .{};
    var history: ?[]const u8 = null;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--folds")) {
            o.folds = try c.int(u32);
            if (o.folds < 2) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--history")) {
            history = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    const line = try eval.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    if (history) |path| {
        const today: Date = .fromMs(std.Io.Clock.real.now(io).toMilliseconds());
        try eval.appendHistory(io, path, line, try c.arena.print("{f}", .{today}));
    }
    return 0;
}

fn cmdLegendaries(c: *Cmd) !u8 {
    var g: Games = .{};
    while (c.next()) |_| {
        if (!try g.parse(c)) return error.Usage;
    }
    const db = try c.open();
    defer db.close();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, g.platformIds());
    const path = try std.fs.path.join(c.arena, &.{ c.data_dir, "legendaries.tsv" });
    const legendaries = try outcomes.loadLegendaries(c.init.gpa, c.arena, c.init.io, path, chosen);
    std.debug.print("{s}: {d} patches\n", .{ path, legendaries.count() });
    return 0;
}

fn cmdOutcomes(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: outcomes.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--preds")) {
            o.preds_dir = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    const legendaries = try outcomes.loadLegendaries(
        c.init.gpa,
        c.arena,
        io,
        try std.fs.path.join(c.arena, &.{ c.data_dir, "legendaries.tsv" }),
        chosen,
    );
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try outcomes.run(c.init.gpa, io, db, chosen, platforms, &legendaries, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn cmdObjectives(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: objectives.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--preds")) {
            o.preds_dir = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try objectives.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn cmdWinchance(c: *Cmd) !u8 {
    var out: ?[]const u8 = null;
    var o: winchance.Options = .{};
    var knots: std.ArrayList(u8) = .empty;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--dev")) {
            o.dev = true;
        } else if (c.is("--knots")) {
            var it = std.mem.splitScalar(u8, try c.value(), ',');
            while (it.next()) |k| try knots.append(c.arena, std.fmt.parseInt(u8, k, 10) catch return error.Usage);
            o.knots = knots.items;
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var src: std.Io.Writer.Allocating = .init(c.arena);
    var buf: [16 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    if (out == null and !o.dev) out = "src/winchance_weights.zig";
    try winchance.fitWith(c.init.gpa, db, o, if (out != null) &src.writer else null, &stdout.interface);
    try stdout.interface.flush();
    if (out) |path| try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = src.written() });
    return 0;
}

fn cmdItems(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: items.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--preds")) {
            o.preds_dir = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    const legendaries = try outcomes.loadLegendaries(
        c.init.gpa,
        c.arena,
        io,
        try std.fs.path.join(c.arena, &.{ c.data_dir, "legendaries.tsv" }),
        chosen,
    );
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try items.run(c.init.gpa, io, db, chosen, platforms, &legendaries, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn cmdPlaystyle(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: playstyle.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--preds")) {
            o.preds_dir = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try playstyle.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn cmdCarry(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: carry.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--cuts")) {
            var it = std.mem.splitScalar(u8, try c.value(), ',');
            for (&o.cuts) |*x| x.* = std.fmt.parseInt(i64, it.next() orelse return error.Usage, 10) catch return error.Usage;
            if (it.next() != null) return error.Usage;
        } else if (c.is("--final")) {
            o.final = true;
        } else if (c.is("--table")) {
            o.table = try c.value();
        } else if (c.is("--fold-table")) {
            o.fold_table = try c.value();
        } else if (c.is("--type-table")) {
            o.type_table = try c.value();
        } else if (c.is("--plant")) {
            var it = std.mem.splitScalar(u8, try c.value(), ':');
            const cov = std.meta.stringToEnum(carry.Cov, it.next().?) orelse return error.Usage;
            const sd = std.fmt.parseFloat(f64, it.next() orelse return error.Usage) catch return error.Usage;
            const seed = if (it.next()) |x| std.fmt.parseInt(u64, x, 10) catch return error.Usage else 1;
            if (cov == .one) return error.Usage;
            o.plant = .{ .cov = cov, .sd = sd, .seed = seed };
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    if (o.final) _ = try test_looks.record(c.init.gpa, io, std.Io.Dir.cwd(), c.data_dir, "meiolol carry", c.args, &stdout.interface);
    var exclude = if (o.final) try test_looks.Exclude.load(c.init.gpa, io, std.Io.Dir.cwd(), c.data_dir) else null;
    defer if (exclude) |*e| e.deinit(c.init.gpa);
    if (exclude) |*e| o.exclude = &e.keys;
    try carry.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn cmdLean(c: *Cmd) !u8 {
    var g: Games = .{};
    var out: ?[]const u8 = null;
    var days: u32 = 30;
    var check = false;
    var cuts: ?lean.Cuts = null;
    var table: ?[]const u8 = null;
    var prior_rows: f64 = lean.default_prior_rows;
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--prior-rows")) {
            prior_rows = try c.float();
        } else if (c.is("--days")) {
            days = try c.int(u32);
        } else if (c.is("--check")) {
            check = true;
        } else if (c.is("--cuts")) {
            var x: lean.Cuts = undefined;
            var it = std.mem.splitScalar(u8, try c.value(), ',');
            for (&x) |*v| v.* = std.fmt.parseInt(i64, it.next() orelse return error.Usage, 10) catch return error.Usage;
            if (it.next() != null) return error.Usage;
            cuts = x;
        } else if (c.is("--table")) {
            table = try c.value();
        } else return error.Usage;
    }
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var every: std.ArrayList([]const u8) = .empty;
    for (riot.endpoints.platforms) |pl| try every.append(c.arena, pl.id);
    const platforms = if (g.platforms.items.len > 0) g.platforms.items else every.items;
    const all_regions = g.platforms.items.len == 0 or g.every_platform;
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    if (check) {
        const x = cuts orelse lean.labCuts(try analysis.protocolCuts(gpa, db));
        var buf: [64 * 1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(io, &buf);
        try lean.check(gpa, io, db, chosen, platforms, x, table, prior_rows, &stdout.interface);
        try stdout.interface.flush();
        return 0;
    }
    const now_ms = std.Io.Clock.real.now(io).toMilliseconds();
    const since_ms = if (g.patches.items.len > 0) 0 else now_ms - @as(i64, days) * std.time.ms_per_day;
    var games = try lean.load(gpa, db, chosen, platforms, since_ms, std.math.maxInt(i64));
    defer games.deinit(gpa);
    if (games.list.items.len == 0) {
        std.log.err("lean: no games with a timeline", .{});
        return error.NoMatches;
    }
    var f = try lean.fit(gpa, games.list.items, games.champs.ids.items.len);
    defer f.deinit(gpa);
    const path = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "lean.tsv" });
    var file = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer file.deinit(io);
    var buf: [64 * 1024]u8 = undefined;
    var w = file.file.writer(io, &buf);
    const where = if (all_regions) "every region" else try std.mem.join(c.arena, ", ", platforms);
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const scope = if (g.patches.items.len > 0)
        try c.arena.print("{s}, patch {s}", .{ where, try stats.label(&label_buf, chosen) })
    else
        try c.arena.print("{s}, last {d} days", .{ where, days });
    try lean.write(&w.interface, &f, games.champs.ids.items, games.list.items, scope);
    try w.interface.flush();
    try file.replace(io);
    std.log.info("{s}: {d} games, {s}", .{ path, games.list.items.len, scope });
    return 0;
}

fn cmdDraftModel(c: *Cmd) !u8 {
    return testerModel(c, draftmodel.run);
}

fn cmdLaneModel(c: *Cmd) !u8 {
    return testerModel(c, lanemodel.run);
}

/// `draft-model` and `lane-model`: --out DIR (default DATA/tester), a log on stdout
fn testerModel(c: *Cmd, comptime run: anytype) !u8 {
    var out: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var buf: [4096]u8 = undefined;
    // Streaming: the web loop logs both commands to one file, which positional writes
    // would overwrite from the start
    var stdout = std.Io.File.stdout().writerStreaming(io, &buf);
    defer stdout.interface.flush() catch {};
    try run(c.init.gpa, io, db, out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "tester" }), &stdout.interface);
    return 0;
}

fn cmdScaling(c: *Cmd) !u8 {
    var g: Games = .{};
    var o: scaling.Options = .{};
    while (c.next()) |_| {
        if (try g.parse(c)) continue;
        if (c.is("--test-share")) {
            o.test_share = try c.float();
            if (!(o.test_share > 0 and o.test_share < 1)) return error.Usage;
        } else if (c.is("--test-platform")) {
            o.test_platform = try c.value();
        } else if (c.is("--preds")) {
            o.preds_dir = try c.value();
        } else if (c.is("--table")) {
            o.table = try c.value();
        } else if (c.is("--state")) {
            o.state = std.meta.stringToEnum(scaling.State, try c.value()) orelse return error.Usage;
        } else if (c.is("--slope")) {
            o.slope = std.meta.stringToEnum(scaling.Slope, try c.value()) orelse return error.Usage;
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const platforms = g.platformIds();
    const chosen = if (g.patches.items.len > 0) g.patches.items else try stats.patches(c.arena, db, platforms);
    var buf: [64 * 1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(io, &buf);
    try scaling.run(c.init.gpa, io, db, chosen, platforms, o, &stdout.interface);
    try stdout.interface.flush();
    return 0;
}

fn cmdRawExport(c: *Cmd) !u8 {
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

/// Flags `site` and `dev` share
const SiteFlags = struct {
    patches: std.ArrayList([]const u8) = .empty,
    out: ?[]const u8 = null,
    contact: ?[]const u8 = null,
    riot_txt: ?[]const u8 = null,
    public: bool = false,
    euw_only: bool = false,
    static: site.Static = .all,
    static_min_games: u32 = 0,
    origin: ?[]const u8 = null,
    index_min_games: u32 = 0,
    views: ?[]const u8 = null,
    views_format: bool = false,
    reuse: bool = false,
    no_partials: bool = false,
    /// The views partials, for `site --views` only: the renderer never writes them
    partials_dir: ?[]const u8 = null,

    /// False for a flag that isn't one of these
    fn parse(f: *SiteFlags, c: *Cmd) !bool {
        if (c.is("--patch")) {
            try f.patches.appendSlice(c.arena, try c.list());
        } else if (c.is("--out")) {
            f.out = try c.value();
        } else if (c.is("--contact")) {
            f.contact = try c.value();
        } else if (c.is("--riot-txt")) {
            f.riot_txt = try c.value();
        } else if (c.is("--public")) {
            f.public = true;
        } else if (c.is("--euw-only")) {
            f.euw_only = true;
        } else if (c.is("--static")) {
            f.static = std.meta.stringToEnum(site.Static, try c.value()) orelse return error.Usage;
        } else if (c.is("--static-min-games")) {
            f.static_min_games = try c.int(u32);
        } else if (c.is("--origin")) {
            f.origin = std.mem.trimEnd(u8, try c.value(), "/");
        } else if (c.is("--index-min-games")) {
            f.index_min_games = try c.int(u32);
        } else if (c.is("--views")) {
            f.views = try c.value();
        } else if (c.is("--views-format")) {
            f.views_format = true;
        } else if (c.is("--reuse")) {
            f.reuse = true;
        } else if (c.is("--no-partials")) {
            f.no_partials = true;
        } else return false;
        return true;
    }

    /// Allocated in `arena`, which must outlive the options
    fn options(f: *const SiteFlags, c: *Cmd, arena: std.mem.Allocator, db: store.Db, contact: []const u8) !site.Options {
        const chosen = if (f.patches.items.len > 0) f.patches.items else try newestPatch(arena, db, &.{"EUW1"});
        const prev = try previousPatch(arena, db, chosen);
        var every: std.ArrayList([]const u8) = .empty;
        for (riot.endpoints.platforms) |pl| try every.append(arena, pl.id);
        const now_ms = std.Io.Clock.real.now(c.init.io).toMilliseconds();
        return .{
            .out_dir = f.out orelse try std.fs.path.join(arena, &.{ c.data_dir, "site" }),
            .patches = chosen,
            .since_ms = now_ms - 30 * std.time.ms_per_day,
            .all_platforms = every.items,
            .contact = contact,
            .riot_txt = f.riot_txt,
            .updated = try arena.print("{f}", .{Date.fromMs(now_ms).long()}),
            .public = f.public,
            .euw_only = f.euw_only,
            .static = f.static,
            .static_min_games = f.static_min_games,
            .origin = f.origin,
            .eval_history = try std.fs.path.join(arena, &.{ c.data_dir, "eval-history.tsv" }),
            .lean = try std.fs.path.join(arena, &.{ c.data_dir, "lean.tsv" }),
            .your_example = try std.fs.path.join(arena, &.{ c.data_dir, "your-example.json" }),
            .index_min_games = f.index_min_games,
            .daily_dir = try std.fs.path.join(arena, &.{ c.data_dir, "daily" }),
            // Indexed by site.html.View.index: EUW 30 days, EUW patch, all 30 days, all patch
            .curves = .{
                try recentCurvesPath(arena, c.data_dir, false),
                try curvesPath(arena, c.data_dir, chosen, false),
                try recentCurvesPath(arena, c.data_dir, true),
                try curvesPath(arena, c.data_dir, chosen, true),
            },
            .builds = .{
                null,
                try buildsPath(arena, c.data_dir, chosen, false),
                null,
                try buildsPath(arena, c.data_dir, chosen, true),
            },
            .prev_patch = if (prev) |p| p[0] else null,
            .curves_prev = if (prev) |p| .{
                null,
                try curvesPath(arena, c.data_dir, p, false),
                null,
                try curvesPath(arena, c.data_dir, p, true),
            } else @splat(null),
        };
    }
};

fn cmdSite(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var patch_games = false;
    while (c.next()) |_| {
        if (c.is("--patch-games")) {
            patch_games = true;
        } else if (!try f.parse(c)) return error.Usage;
    }
    // A fraction of a second: the web loop asks every round whether to build and upload
    if (patch_games) {
        const db = try c.open();
        defer db.close();
        const chosen = if (f.patches.items.len > 0) f.patches.items else try newestPatch(c.arena, db, &.{"EUW1"});
        var label_buf: [core.statsfile.patch_len]u8 = undefined;
        var buf: [64]u8 = undefined;
        var w = std.Io.File.stdout().writer(c.init.io, &buf);
        try w.interface.print("{s} {d}\n", .{ try stats.label(&label_buf, chosen), try stats.countGames(db, chosen, &.{"EUW1"}) });
        try w.interface.flush();
        return 0;
    }
    if (f.views_format) {
        var buf: [32]u8 = undefined;
        var w = std.Io.File.stdout().writer(c.init.io, &buf);
        try w.interface.print("{d}\n", .{site.Loaded.viewsFormat()});
        try w.interface.flush();
        return 0;
    }
    const email = try c.required(f.contact, "--contact");
    const db = try c.open();
    defer db.close();
    if (f.views) |path| {
        if (!f.no_partials) f.partials_dir = try partials.dirIn(c.arena, c.data_dir);
        const l = try loadAll(c, &f, db, email);
        defer l.free(c.init.gpa);
        try l.loaded.writeViews(path);
        std.log.info("views: {s}", .{path});
        return 0;
    }
    try site.generate(c.init.gpa, c.init.io, db, try f.options(c, c.arena, db, email));
    return 0;
}

/// Pages rendered on request from data loaded once, CSS and JS from src/site/static, and
/// the browser reloading after an edit (deploy/dev.sh rebuilds the binary)
fn cmdDev(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var port: u16 = 8080;
    while (c.next()) |_| {
        if (c.is("--port")) {
            port = try c.int(u16);
        } else if (!try f.parse(c)) return error.Usage;
    }
    const static_dir = "src/site/static";
    const dev: serve.Dev = try .init(c.arena, c.init.io, try c.init.minimal.args.toSlice(c.arena), static_dir);
    const db = try c.open();
    defer db.close();
    var opts = try f.options(c, c.arena, db, f.contact orelse "dev@example.com");
    opts.static_dir = static_dir;
    const loaded = try site.Loaded.init(c.init.gpa, c.init.io, db, opts);
    const rendered = serve.Rendered.init(c.init.gpa, c.init.io, loaded, null) catch |err| {
        loaded.deinit();
        return err;
    };
    defer rendered.deinit();
    // Before listening, so the browser reloads once it is ready; the others on request
    _ = try loaded.site(site.html.View.all[0]);
    try serve.run(c.init.gpa, c.init.io, .{
        .port = port,
        .render = rendered,
        .dev = dev,
    });
    return 0;
}

/// The pages and files the static build leaves out (--static, --static-min-games),
/// rendered on request for the web server's nginx (docs/hosting.md "Rendering on
/// request"), loaded again whenever the --reload file changes. From the --views file
/// when this binary reads it: listening and --ready in seconds. Otherwise from the
/// database: beside a running instance (a deploy: deploy/render-swap.sh) it loads every
/// view, then listens too (SO_REUSEPORT) and is --ready for the old one to stop; alone
/// (a boot) it listens at once and serves each view as it loads, the rest answering 503
fn cmdRender(c: *Cmd) !u8 {
    var f: SiteFlags = .{};
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8091;
    var reload: ?[]const u8 = null;
    var ready: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--host")) {
            host = try c.value();
        } else if (c.is("--port")) {
            port = try c.int(u16);
        } else if (c.is("--reload")) {
            reload = try c.value();
        } else if (c.is("--ready")) {
            ready = try c.value();
        } else if (!try f.parse(c)) return error.Usage;
    }
    const email = try c.required(f.contact, "--contact");
    const gpa = c.init.gpa;
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    const alone = !listening(io, host, port);
    const from_file = fromViewsFile(c, &f, db);
    if (from_file == null and f.views != null) std.log.info("render: loading from the database", .{});
    const first = from_file orelse try prepare(c, &f, db, email);
    first.loaded.lazy = false;
    // From the database in the background once listening (alone), else before
    const background_load = from_file == null and alone;
    if (from_file == null and !alone) loadViews(first.loaded) catch |err| {
        first.free(gpa);
        return err;
    };
    const rendered = serve.Rendered.init(gpa, io, first.loaded, first.arena) catch |err| {
        first.free(gpa);
        return err;
    };
    defer rendered.deinit();
    var group: std.Io.Group = .init;
    defer group.cancel(io);
    group.async(io, background, .{ c, &f, db, email, rendered, if (background_load) first.loaded else null, ready, reload });
    var admin_api: serve.admin_api.Api = .{ .gpa = gpa, .io = io, .data_dir = c.data_dir };
    defer admin_api.deinit();
    try serve.run(gpa, io, .{ .host = host, .port = port, .render = rendered, .ready = if (background_load) null else ready, .admin = &admin_api });
    return 0;
}

/// Whether something already listens at host:port: an older renderer
fn listening(io: std.Io, host: []const u8, port: u16) bool {
    const address = std.Io.net.IpAddress.parse(host, port) catch return false;
    const stream = address.connect(io, .{ .mode = .stream }) catch return false;
    stream.close(io);
    return true;
}

/// The database's only user once the server runs: the first load when serving early
/// (exiting on failure, for systemd to start again; `ready` after it), then reloads
fn background(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8, rendered: *serve.Rendered, first: ?*site.Loaded, ready: ?[]const u8, reload: ?[]const u8) void {
    if (first) |l| {
        loadViews(l) catch |err| {
            std.log.err("render load: {t}", .{err});
            std.process.exit(1);
        };
        if (ready) |path| rendered.writeReady(path) catch |err| {
            std.log.warn("render ready file: {t}", .{err});
        };
    }
    if (reload) |path| reloadOnChange(c, f, db, contact, rendered, path, ready);
}

const LoadedAll = struct {
    loaded: *site.Loaded,
    /// The options' strings
    arena: *std.heap.ArenaAllocator,

    fn free(l: LoadedAll, gpa: std.mem.Allocator) void {
        l.loaded.deinit();
        l.arena.deinit();
        gpa.destroy(l.arena);
    }
};

/// Options as of now (patch, 30-day window), no view loaded yet
fn prepare(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8) !LoadedAll {
    const gpa = c.init.gpa;
    const arena = try gpa.create(std.heap.ArenaAllocator);
    arena.* = .init(gpa);
    errdefer {
        arena.deinit();
        gpa.destroy(arena);
    }
    const opts = try f.options(c, arena.allocator(), db, contact);
    return .{ .loaded = try site.Loaded.init(gpa, c.init.io, db, opts), .arena = arena };
}

/// Every view, the root (most visited) and the shared one first
fn loadViews(loaded: *site.Loaded) !void {
    for (site.html.View.all) |v| {
        if (loaded.opts.euw_only and v.region != .euw) continue;
        try loaded.loadView(v);
    }
}

/// Every view from the --views file; null without one, or when it can't be read
/// (missing, or another binary's types wrote it: a deploy that changed them)
fn fromViewsFile(c: *Cmd, f: *const SiteFlags, db: store.Db) ?LoadedAll {
    const path = f.views orelse return null;
    const gpa = c.init.gpa;
    const io = c.init.io;
    const start = std.Io.Clock.real.now(io).toMilliseconds();
    const arena = gpa.create(std.heap.ArenaAllocator) catch return null;
    arena.* = .init(gpa);
    const loaded = site.Loaded.readViews(gpa, io, db, path, arena.allocator()) catch |err| {
        std.log.warn("render: views file {s}: {t}", .{ path, err });
        arena.deinit();
        gpa.destroy(arena);
        return null;
    };
    const age_s = @divTrunc(std.Io.Clock.real.now(io).toNanoseconds() - fileMtime(io, path), std.time.ns_per_s);
    std.log.info("render: views file read in {d} ms, written {d} min ago", .{
        std.Io.Clock.real.now(io).toMilliseconds() - start, @divTrunc(age_s, 60),
    });
    return .{ .loaded = loaded, .arena = arena };
}

/// prepare and loadViews: every view loaded, not on its first request
fn loadAll(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8) !LoadedAll {
    const l = try prepare(c, f, db, contact);
    errdefer l.free(c.init.gpa);
    if (f.reuse) if (f.views) |path| try l.loaded.reuseViews(path);
    l.loaded.extras.partials_dir = f.partials_dir;
    l.loaded.lazy = false;
    try loadViews(l.loaded);
    return l;
}

/// Swaps in freshly loaded data whenever `path`'s mtime moves (deploy/web-loop.sh touches
/// it after each upload); on a failed load the old data stays. With --views only from
/// that file: a database load here would run beside the web loop's (an old renderer
/// seeing a newer binary's file during a swap). `ready` gets the new data's version
fn reloadOnChange(c: *Cmd, f: *const SiteFlags, db: store.Db, contact: []const u8, rendered: *serve.Rendered, path: []const u8, ready: ?[]const u8) void {
    const io = c.init.io;
    var seen = fileMtime(io, path);
    while (true) {
        io.sleep(.fromMilliseconds(10_000), .awake) catch return;
        const now = fileMtime(io, path);
        if (now == seen) continue;
        seen = now;
        const start = std.Io.Clock.real.now(io).toMilliseconds();
        // A newer binary's file (a deploy, before the swap): the current data stays
        const next = (if (f.views != null) fromViewsFile(c, f, db) orelse continue else loadAll(c, f, db, contact)) catch |err| {
            std.log.warn("render reload: {t}", .{err});
            continue;
        };
        rendered.swap(next.loaded, next.arena) catch |err| {
            next.free(c.init.gpa);
            std.log.warn("render reload: {t}", .{err});
            continue;
        };
        std.log.info("render: reloaded in {d} s", .{@divTrunc(std.Io.Clock.real.now(io).toMilliseconds() - start, 1000)});
        if (ready) |p| rendered.writeReady(p) catch |err| std.log.warn("render ready file: {t}", .{err});
    }
}

fn fileMtime(io: std.Io, path: []const u8) i96 {
    const st = std.Io.Dir.cwd().statFile(io, path, .{}) catch return 0;
    return st.mtime.toNanoseconds();
}

fn cmdServe(c: *Cmd) !u8 {
    var dir: ?[]const u8 = null;
    var host: []const u8 = "127.0.0.1";
    var port: u16 = 8080;
    while (c.next()) |_| {
        if (c.is("--out")) {
            dir = try c.value();
        } else if (c.is("--host")) {
            host = try c.value();
        } else if (c.is("--port")) {
            port = try c.int(u16);
        } else return error.Usage;
    }
    const root = dir orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "site" });
    try serve.run(c.init.gpa, c.init.io, .{ .root = root, .host = host, .port = port });
    return 0;
}

fn cmdApi(c: *Cmd) !u8 {
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
        } else return error.Usage;
    }
    const arena = c.arena;
    if (o.fetch.proxy == null) o.fetch.key = try c.apiKey();
    o.db_path = try arena.printSentinel("{s}/api.db", .{c.data_dir}, 0);
    o.curves_dir = curves_dir orelse if (o.fetch.exchange_dir) |x|
        try std.fs.path.join(arena, &.{ x, "curves" })
    else
        try std.fs.path.join(arena, &.{ c.data_dir, "export" });
    try api.run(c.init.gpa, c.init.io, o);
    return 0;
}

fn cmdYourExample(c: *Cmd) !u8 {
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

fn cmdStatus(c: *Cmd) !u8 {
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

fn cmdAdmin(c: *Cmd) !u8 {
    const now = std.Io.Clock.real.now(c.init.io).toSeconds();
    var o: admin.Options = .{ .out_dir = "", .data_dir = c.data_dir, .crawl_log = "", .now_s = now };
    var out: ?[]const u8 = null;
    var log_path: ?[]const u8 = null;
    while (c.next()) |_| {
        if (c.is("--out")) {
            out = try c.value();
        } else if (c.is("--log")) {
            log_path = try c.value();
        } else if (c.is("--days")) {
            o.days = try c.int(u32);
        } else if (c.is("--disk")) {
            var words = std.mem.tokenizeScalar(u8, try c.value(), ' ');
            var d: [3]u64 = undefined;
            for (&d) |*x| x.* = std.fmt.parseInt(u64, words.next() orelse return error.Usage, 10) catch return error.Usage;
            o.disk = d;
        } else if (c.is("--health")) {
            o.health = try c.value();
        } else return error.Usage;
    }
    o.out_dir = out orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "admin" });
    o.crawl_log = log_path orelse try std.fs.path.join(c.arena, &.{ c.data_dir, "crawl.log" });
    const db = try store.open(c.init.gpa, c.data_dir);
    defer db.close();
    try admin.generate(c.init.gpa, c.init.io, db, o);
    return 0;
}

fn cmdRebuild(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    std.log.info("{d} matches rebuilt", .{try riot.match.rebuild(c.init.gpa, db)});
    std.log.info("{d} timelines gave gold columns", .{try riot.crawl.rebuildGold(c.init.gpa, db)});
    try partials.drop(c.init.gpa, c.init.io, try partials.dirIn(c.arena, c.data_dir));
    return 0;
}

fn cmdRekey(c: *Cmd) !u8 {
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
    // As forget: the box holds meiolol.db, the web server api.db
    const cwd = std.Io.Dir.cwd();
    const crawl_path = try std.fs.path.join(c.arena, &.{ c.data_dir, "meiolol.db" });
    const api_path = try std.fs.path.joinZ(c.arena, &.{ c.data_dir, "api.db" });
    const db: ?store.Db = if (cwd.access(io, crawl_path, .{})) |_| try c.open() else |_| null;
    defer if (db) |d| d.close();
    const api_db: ?store.Db = if (cwd.access(io, api_path, .{})) |_| try api.cache.open(api_path) else |_| null;
    defer if (api_db) |d| d.close();
    if (db == null and api_db == null) {
        std.log.err("{s} holds neither meiolol.db nor api.db", .{c.data_dir});
        return 1;
    }
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

fn cmdChampions(c: *Cmd) !u8 {
    try c.noFlags();
    const db = try c.open();
    defer db.close();
    std.log.info("{d} champions", .{try ddragon.refresh(c.init.gpa, c.init.io, db)});
    return 0;
}

/// Resumable: the list shrinks as chunks commit
fn cmdDraftBackfill(c: *Cmd) !u8 {
    var chunk: usize = 200;
    var pause_ms: u32 = 1000;
    while (c.next()) |_| {
        if (c.is("--chunk")) {
            chunk = try c.int(usize);
            if (chunk == 0) return error.Usage;
        } else if (c.is("--pause-ms")) {
            pause_ms = try c.int(u32);
        } else return error.Usage;
    }
    const io = c.init.io;
    const db = try c.open();
    defer db.close();
    var b: store.draft.Builder = try .init(db);
    defer b.deinit();
    const left = try db.scalar("SELECT count(*) FROM draft_backfill", .{}) orelse 0;
    std.log.info("{d} matches to read", .{left});
    var taken: usize = 0;
    var written: usize = 0;
    var chunks: usize = 0;
    while (true) {
        const r = store.draft.backfillChunk(c.init.gpa, db, &b, chunk) catch |err| switch (err) {
            // The crawler's writer or a backup held the lock past the busy timeout
            error.Busy => {
                try io.sleep(.fromMilliseconds(pause_ms), .awake);
                continue;
            },
            else => return err,
        };
        if (r.taken == 0) break;
        taken += r.taken;
        written += r.written;
        chunks += 1;
        if (chunks % 50 == 0) std.log.info("{d} of {d} read, {d} rows", .{ taken, left, written });
        try io.sleep(.fromMilliseconds(pause_ms), .awake);
    }
    std.log.info("done: {d} matches read, {d} draft rows (the rest not complete ranked games)", .{
        taken, written,
    });
    return 0;
}

fn cmdBackup(c: *Cmd) !u8 {
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

fn cmdRestore(c: *Cmd) !u8 {
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
        if (err == error.TargetNotEmpty) std.log.err("{s} holds a database: restore only into an empty directory", .{c.data_dir});
        return err;
    };
    std.log.info("{s}: {d} files, {d} matches, {d} timelines; {d} rows re-erased", .{
        c.data_dir, r.files, r.matches, r.timelines, r.removed.total(),
    });
    try partials.drop(c.init.gpa, c.init.io, try partials.dirIn(c.arena, c.data_dir));
    return 0;
}

/// Logs counts only: an erasure log naming the player would defeat the erasure. PUUIDs
/// already in `forgotten` are skipped, so complete lists can be fed in again and again.
fn cmdForget(c: *Cmd) !u8 {
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
    // The box holds the crawler databases, the web server the Your games cache; open
    // whichever this data directory has, never creating the other
    const cwd = std.Io.Dir.cwd();
    const crawl_path = try std.fs.path.join(arena, &.{ c.data_dir, "meiolol.db" });
    const api_path = try std.fs.path.joinZ(arena, &.{ c.data_dir, "api.db" });
    const db: ?store.Db = if (cwd.access(io, crawl_path, .{})) |_| try c.open() else |_| null;
    defer if (db) |d| d.close();
    const api_db: ?store.Db = if (cwd.access(io, api_path, .{})) |_| try api.cache.open(api_path) else |_| null;
    defer if (api_db) |d| d.close();
    if (db == null and api_db == null) {
        std.log.err("{s} holds neither meiolol.db nor api.db", .{c.data_dir});
        return 1;
    }
    var live: forget.Removed = .{};
    var scrubbed: forget.Removed = .{};
    var erased: std.ArrayList([]const u8) = .empty;
    var unresolved: usize = 0;
    var already: usize = 0;
    for (ids) |id| {
        const puuid = if (std.mem.indexOfScalar(u8, id, '#') == null) id else blk: {
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

fn usageError(arg: ?[]const u8) u8 {
    if (arg) |a| std.log.err("unknown, incomplete or missing for this command: {s}", .{a});
    std.debug.print("{s}", .{usage});
    return 2;
}

/// Where `meiolol curves` writes by default for these patches. Every platform's files
/// start all-, out of the curves-*.bin the Your games service reads (EUW, per patch)
fn curvesPath(arena: std.mem.Allocator, data_dir: []const u8, chosen: []const []const u8, every: bool) ![]const u8 {
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    return arena.print("{s}/export/{s}curves-{s}.bin", .{ data_dir, allPrefix(every), label });
}

/// Where `meiolol curves` writes by default: every patch of the last --days. Not
/// curves-*.bin, which the Your games service reads as one file per patch
fn recentCurvesPath(arena: std.mem.Allocator, data_dir: []const u8, every: bool) ![]const u8 {
    return arena.print("{s}/export/{s}recent-curves.bin", .{ data_dir, allPrefix(every) });
}

/// Where `meiolol builds` writes by default; the site reads the newest patch's
fn buildsPath(arena: std.mem.Allocator, data_dir: []const u8, chosen: []const []const u8, every: bool) ![]const u8 {
    var label_buf: [core.statsfile.patch_len]u8 = undefined;
    const label = try stats.label(&label_buf, chosen);
    return arena.print("{s}/export/{s}builds-{s}.json", .{ data_dir, allPrefix(every), label });
}

fn allPrefix(every: bool) []const u8 {
    return if (every) "all-" else "";
}

fn newestPatch(arena: std.mem.Allocator, db: store.Db, platforms: []const []const u8) ![]const []const u8 {
    const all = try stats.patches(arena, db, platforms);
    if (all.len == 0) return error.NoMatches;
    return all[0..1];
}

/// The EUW patch before `chosen` when it is one patch, for the site's patch day
fn previousPatch(arena: std.mem.Allocator, db: store.Db, chosen: []const []const u8) !?[]const []const u8 {
    if (chosen.len != 1) return null;
    const all = try stats.patches(arena, db, &.{"EUW1"});
    for (all, 0..) |p, i| {
        if (std.mem.eql(u8, p, chosen[0])) return if (i + 1 < all.len) all[i + 1 .. i + 2] else null;
    }
    return null;
}

/// Default log format plus a UTC timestamp, for the crawl log on the box
fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    const io = std.Options.debug_io;
    const secs: u64 = @intCast(std.Io.Clock.real.now(io).toSeconds());
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const day = epoch.getEpochDay().calculateYearDay();
    const md = day.calculateMonthDay();
    const ds = epoch.getDaySeconds();
    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderr(&buffer).terminal();
    defer std.debug.unlockStderr();
    stderr.writer.print("{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} ", .{
        day.year,             md.month.numeric(),      md.day_index + 1,
        ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch {};
    std.log.defaultLogFileTerminal(level, scope, format, args, stderr) catch {};
}

test {
    std.testing.refAllDecls(@This());
    _ = @import("pipeline_test.zig");
}
