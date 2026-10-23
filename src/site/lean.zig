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
pub fn line(w: *Writer, file: *const lean.File, champion: u32, name: []const u8, r: Role, method: []const u8, chip: ?scope.Chip) !void {
    const row = file.get(champion, r) orelse return;
    try tpl.render(w,
        \\<p class="curves-links">{chip}{text} <span class="muted">Games still going at {win} min: {games} ({scope}). <a href="{method}">How this is measured</a></span></p>
        \\
    , .{
        .chip = if (chip) |c| tpl.t("{c} ", .{ .c = c }) else null,
        .text = tpl.call(text, .{ row, name, r }),
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

fn text(w: *Writer, row: lean.Row, name: []const u8, r: Role) !void {
    if (!row.enough()) return tpl.render(w, "<b>Early or late:</b> too few games yet to tell.", .{});
    const g = gold(row);
    const p = points(row);
    const ahead = tpl.t("on average {side} at {min} min: {sign}{gold} gold (±{pm}) against an average {noun}", .{
        .side = if (row.gold > 0) "ahead" else "behind",
        .min = lean.gold_minute,
        .sign = if (g.v > 0) "+" else "",
        .gold = g.v,
        .pm = g.pm,
        .noun = noun(r),
    });
    const wins = tpl.t("from an even game at {min} min (same gold, XP and objectives) they win {pts} percentage point{s} {dir} often (±{pm})", .{
        .min = lean.win_minute,
        .pts = p.v,
        .s = if (p.v == 1) "" else "s",
        .dir = if (row.win > 0) "more" else "less",
        .pm = p.pm,
    });
    switch (row.lean()) {
        .early, .late => |l| try tpl.render(w, "<b>{label} lean.</b> Teams with {name} are {ahead}; {wins}.", .{
            .label = if (l == .early) "Early" else "Late",
            .name = name,
            .ahead = ahead,
            .wins = wins,
        }),
        .none => {
            const gc = row.goldClear();
            const wc = row.winClear();
            if (gc and wc) return tpl.render(w, "<b>No clear early or late lean.</b> Teams with {name} are {ahead}, and {wins}.", .{
                .name = name,
                .ahead = ahead,
                .wins = wins,
            });
            if (gc) return tpl.render(w, "<b>No clear early or late lean.</b> Teams with {name} are {ahead}; from an even game at {min} min they show no clear difference.", .{
                .name = name,
                .ahead = ahead,
                .min = lean.win_minute,
            });
            if (wc) return tpl.render(w, "<b>No clear early or late lean.</b> At {min} min teams with {name} show no clear gold difference; {wins}.", .{
                .min = lean.gold_minute,
                .name = name,
                .wins = wins,
            });
            try tpl.render(w, "<b>No clear early or late lean:</b> neither the gold at {gm} min nor the wins from an even game at {wm} min differ clearly from an average {noun}.", .{
                .gm = lean.gold_minute,
                .wm = lean.win_minute,
                .noun = noun(r),
            });
        },
    }
}

const testing = std.testing;

fn render(row: lean.Row) ![]const u8 {
    const rows = [_]lean.Row{row};
    const file: lean.File = .{ .games = 1, .from_ms = 0, .to_ms = 0, .scope = "every region, last 30 days", .rows = &rows };
    var aw: Writer.Allocating = .init(testing.allocator);
    errdefer aw.deinit();
    try line(&aw.writer, &file, row.champion, "Kayle", row.role, "../method.html#lean", null);
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
        .{ .{ .champion = 1, .role = .top, .games = 14204, .gold = -842, .gold_sd = 52, .win = 13.8, .win_sd = 0.97 }, "<b>Late lean.</b> Teams with Kayle are on average behind at 14 min: -840 gold (±100) against an average top laner; from an even game at 20 min (same gold, XP and objectives) they win 14 percentage points more often (±2). <span class=\"muted\">Games still going at 20 min: 14,204 (every region, last 30 days)." },
        .{ .{ .champion = 1, .role = .utility, .games = 11387, .gold = 749, .gold_sd = 31, .win = -11.4, .win_sd = 0.6 }, "<b>Early lean.</b> Teams with Kayle are on average ahead at 14 min: +750 gold (±60) against an average support; from an even game at 20 min (same gold, XP and objectives) they win 11 percentage points less often (±1)." },
        .{ .{ .champion = 1, .role = .jungle, .games = 900, .gold = 300, .gold_sd = 50, .win = 0.5, .win_sd = 1 }, "Teams with Kayle are on average ahead at 14 min: +300 gold (±100) against an average jungler; from an even game at 20 min they show no clear difference." },
        .{ .{ .champion = 1, .role = .middle, .games = 900, .gold = 30, .gold_sd = 50, .win = -4, .win_sd = 1 }, "At 14 min teams with Kayle show no clear gold difference; from an even game at 20 min (same gold, XP and objectives) they win 4 percentage points less often (±2)." },
        .{ .{ .champion = 1, .role = .middle, .games = 900, .gold = 300, .gold_sd = 50, .win = 4, .win_sd = 1 }, "<b>No clear early or late lean.</b> Teams with Kayle are on average ahead at 14 min: +300 gold (±100) against an average mid laner, and from an even game" },
        .{ .{ .champion = 1, .role = .bottom, .games = 900, .gold = 30, .gold_sd = 50, .win = 0, .win_sd = 0 }, "neither the gold at 14 min nor the wins from an even game at 20 min differ clearly from an average bot laner." },
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
