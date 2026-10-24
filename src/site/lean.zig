//! Champion page line: does the champion lean early or late in a role (`meiolol lean`,
//! src/lean.zig)? Facts about games in general, each number only where it is clear of
//! noise, plain wording otherwise; method page "Early or late".

const std = @import("std");
const core = @import("core");
const html = @import("html.zig");
const Thousands = @import("root.zig").Thousands;
const tpl = html.tpl;
const lean = @import("../lean.zig");
const scope = @import("scope.zig");

const Writer = std.Io.Writer;
const Role = core.Role;

/// "an average {noun}"
fn noun(r: Role) []const u8 {
    return switch (r) {
        .top => "top laner",
        .jungle => "jungler",
        .middle => "mid laner",
        .bottom => "bot laner",
        .utility => "support",
    };
}

/// 95% range of an effect, rounded as its value
const Shown = struct { v: i64, pm: i64 };

fn gold(r: lean.Row) Shown {
    return .{ .v = round(r.gold, 10), .pm = @max(10, round(1.96 * r.gold_sd, 10)) };
}

fn points(r: lean.Row) Shown {
    return .{ .v = @max(1, round(@abs(r.win), 1)), .pm = @max(1, round(1.96 * r.win_sd, 1)) };
}

fn round(x: f64, step: f64) i64 {
    return @trunc(@round(x / step) * step);
}

/// The line for `name` in role `r`; `method` links the method page
pub fn line(w: *Writer, file: *const lean.File, champion: u32, r: Role, method: []const u8, chip: ?scope.Chip) !void {
    const row = file.get(champion, r) orelse return;
    try tpl.render(w,
        \\<p class="curves-links">{chip}{text} <a href="{method}" title="Games still going at {win} min: {games} ({scope})">How this is measured</a></p>
        \\
    , .{
        .chip = if (chip) |c| tpl.t("{c} ", .{ .c = c }) else null,
        .text = tpl.call(text, .{ row, r }),
        .scope = file.scope,
        .games = Thousands{ .n = row.games },
        .win = lean.win_minute,
        .method = method,
    });
}

/// The file's scope (sitedata.zig: "every region, last 30 days", "EUW1, patch 16.21")
/// as chip region and period
pub fn scopeDims(a: std.mem.Allocator, file: *const lean.File) ![2]scope.Dim {
    const comma = std.mem.lastIndexOf(u8, file.scope, ", ") orelse return error.BadLean;
    const where = file.scope[0..comma];
    const when = file.scope[comma + 2 ..];
    const region: scope.Dim = if (std.mem.eql(u8, where, "every region"))
        .region(.all, "")
    else if (std.mem.indexOfScalar(u8, where, ',') == null)
        .{ .key = where, .text = html.platformName(where) }
    else
        .{ .key = where, .text = where };
    const period: scope.Dim = if (std.mem.startsWith(u8, when, "patch "))
        try .patch(a, when["patch ".len..])
    else if (std.mem.eql(u8, when, "last 30 days"))
        .days30
    else
        .{ .key = when, .text = when };
    return .{ region, period };
}

fn text(w: *Writer, row: lean.Row, r: Role) !void {
    if (!row.enough()) return tpl.render(w, "<b>Early or late:</b> too few games yet to tell.", .{});
    const g = gold(row);
    const p = points(row);
    const ahead = tpl.t("{sign}{gold} gold at {min} min against an average {noun} (±{pm})", .{
        .sign = if (g.v > 0) "+" else "",
        .gold = g.v,
        .min = lean.gold_minute,
        .noun = noun(r),
        .pm = g.pm,
    });
    const wins = tpl.t("won {pts} point{s} {dir} often from an even game at {min} min (±{pm})", .{
        .pts = p.v,
        .s = if (p.v == 1) "" else "s",
        .dir = if (row.win > 0) "more" else "less",
        .min = lean.win_minute,
        .pm = p.pm,
    });
    const label = switch (row.lean()) {
        .early => "Early lean",
        .late => "Late lean",
        .none => "No clear early or late lean",
    };
    const gc = row.goldClear();
    const wc = row.winClear();
    try tpl.render(w, "<b>{label}:</b> {ahead}{no_gold}; {wins}{no_wins}.", .{
        .label = label,
        .ahead = tpl.when(gc, ahead),
        .no_gold = tpl.when(!gc, tpl.t("no clear gold difference at {min} min", .{ .min = lean.gold_minute })),
        .wins = tpl.when(wc, wins),
        .no_wins = tpl.when(!wc, tpl.t("no clear difference in wins from an even game at {min} min", .{ .min = lean.win_minute })),
    });
}

const testing = std.testing;

fn render(row: lean.Row) ![]const u8 {
    const rows = [_]lean.Row{row};
    const file: lean.File = .{ .games = 1, .from_ms = 0, .to_ms = 0, .scope = "every region, last 30 days", .rows = &rows };
    var aw: Writer.Allocating = .init(testing.allocator);
    errdefer aw.deinit();
    try line(&aw.writer, &file, row.champion, row.role, "../method.html#lean", null);
    return aw.toOwnedSlice();
}

test scopeDims {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const cases = [_]struct { []const u8, [4][]const u8 }{
        .{ "every region, last 30 days", .{ "all", "All regions", "days30", "30 days" } },
        .{ "EUW1, patch 16.21", .{ "EUW1", "EUW", "patch:16.21", "Patch 16.21" } },
        .{ "EUW1, KR, last 14 days", .{ "EUW1, KR", "EUW1, KR", "last 14 days", "last 14 days" } },
    };
    for (cases) |c| {
        const file: lean.File = .{ .games = 1, .from_ms = 0, .to_ms = 0, .scope = c[0], .rows = &.{} };
        const d = try scopeDims(arena.allocator(), &file);
        for ([_][]const u8{ d[0].key, d[0].text, d[1].key, d[1].text }, c[1]) |got, want| try testing.expectEqualStrings(want, got);
    }
}

test "early, late, one part clear, none, too few" {
    const cases = [_]struct { lean.Row, []const u8 }{
        .{ .{ .champion = 1, .role = .top, .games = 14204, .gold = -842, .gold_sd = 52, .win = 13.8, .win_sd = 0.97 }, "<b>Late lean:</b> -840 gold at 14 min against an average top laner (±100); won 14 points more often from an even game at 20 min (±2). <a href=\"../method.html#lean\" title=\"Games still going at 20 min: 14,204 (every region, last 30 days)\">" },
        .{ .{ .champion = 1, .role = .utility, .games = 11387, .gold = 749, .gold_sd = 31, .win = -11.4, .win_sd = 0.6 }, "<b>Early lean:</b> +750 gold at 14 min against an average support (±60); won 11 points less often from an even game at 20 min (±1)." },
        .{ .{ .champion = 1, .role = .jungle, .games = 900, .gold = 300, .gold_sd = 50, .win = 0.5, .win_sd = 1 }, "<b>No clear early or late lean:</b> +300 gold at 14 min against an average jungler (±100); no clear difference in wins from an even game at 20 min." },
        .{ .{ .champion = 1, .role = .middle, .games = 900, .gold = 30, .gold_sd = 50, .win = -4, .win_sd = 1 }, "<b>No clear early or late lean:</b> no clear gold difference at 14 min; won 4 points less often from an even game at 20 min (±2)." },
        .{ .{ .champion = 1, .role = .middle, .games = 900, .gold = 300, .gold_sd = 50, .win = 4, .win_sd = 1 }, "<b>No clear early or late lean:</b> +300 gold at 14 min against an average mid laner (±100); won 4 points more often" },
        .{ .{ .champion = 1, .role = .bottom, .games = 900, .gold = 30, .gold_sd = 50, .win = 0, .win_sd = 0 }, "no clear gold difference at 14 min; no clear difference in wins from an even game at 20 min." },
        .{ .{ .champion = 1, .role = .bottom, .games = 150, .gold = 900, .gold_sd = 50, .win = -9, .win_sd = 1 }, "<b>Early or late:</b> too few games yet to tell." },
    };
    for (cases) |c| {
        const got = try render(c[0]);
        defer testing.allocator.free(got);
        if (std.mem.find(u8, got, c[1]) == null) {
            std.debug.print("got {s}\n", .{got});
            return error.TestUnexpectedResult;
        }
        try testing.expect(std.mem.find(u8, got, "(every region, last 30 days)") != null);
    }
}
