//! Where Learn's hand-typed figures come from: a row per fixed puzzle (learnfixed.zig)
//! naming the doc that holds the finding and each figure twice, as the card shows it and
//! as the doc writes it. The test below finds both, so a rerun that changes the doc's
//! number fails until the card is retyped, and a new card needs a row here.
//! docs/learned.md rows must sit in one finding (one bullet), so a figure can't be backed
//! by an unrelated line that happens to hold the same number
const std = @import("std");
const ld = @import("ui").learndata;
const fixed = @import("learnfixed.zig");

pub const Doc = enum { learned, fed, deficit, kill_gold, split_push };

pub const Figure = struct {
    /// As the card holds it: text in any field, or a number as typed (47.3, 59796)
    card: []const u8,
    /// As the doc writes it, whitespace collapsed
    doc: []const u8,
};

pub const Row = struct {
    id: []const u8,
    doc: Doc,
    figures: []const Figure,
};

pub const rows = [_]Row{
    .{ .id = "know", .doc = .learned, .figures = &.{
        .{ .card = "47.7", .doc = "under 10k mastery points win 47.7%" },
        .{ .card = "51.7", .doc = "300k+ 51.7%" },
    } },
    .{ .id = "practice", .doc = .learned, .figures = &.{
        .{ .card = "+3.7 points, same player", .doc = "about 3.7 points more from 10k to 300k points on a champion" },
        .{ .card = "944k player-games", .doc = "944k held-out player-games" },
    } },
    // The doc rounds: the card's 39.4% and 50.7%
    .{ .id = "newcomer", .doc = .learned, .figures = &.{
        .{ .card = "39.4% new, 50.7% practised", .doc = "New Rengar players win 39% against 51% practised" },
    } },
    .{ .id = "fed", .doc = .fed, .figures = &.{
        .{ .card = "47.3", .doc = "| 59796 | 47.3% |" },
        .{ .card = "59796", .doc = "| 59796 | 47.3% |" },
        .{ .card = "68.6%", .doc = "| 142734 | 68.6% |" },
        .{ .card = "27.6", .doc = "| 16328 | 27.6% |" },
        .{ .card = "89.1", .doc = "| 56450 | 89.1% |" },
    } },
    .{ .id = "fed-role", .doc = .fed, .figures = &.{
        .{ .card = "50.4%", .doc = "50.4% | 14808 |" },
        .{ .card = "44.6%", .doc = "44.6% | 17476 |" },
    } },
    .{ .id = "lead-worth", .doc = .learned, .figures = &.{
        .{ .card = "about 8 points on bot", .doc = "about 8 points for the bot laner" },
    } },
    .{ .id = "ff15", .doc = .deficit, .figures = &.{
        .{ .card = "13", .doc = "13.0% (20888)" },
        .{ .card = "20888", .doc = "13.0% (20888)" },
        .{ .card = "7.2", .doc = "7.2% (6217)" },
        .{ .card = "17.4", .doc = "17.4% (10267)" },
        .{ .card = "239,629 games", .doc = "239629" },
    } },
    .{ .id = "bounty", .doc = .kill_gold, .figures = &.{
        .{ .card = "481", .doc = "| 481 | 37.3% |" },
        .{ .card = "37% of kills", .doc = "| 481 | 37.3% |" },
        .{ .card = "290,807 games", .doc = "290,807 ranked solo games" },
    } },
    .{ .id = "gold-nudge", .doc = .learned, .figures = &.{
        .{ .card = "270-360 gold", .doc = "by a typical 270-360" },
        .{ .card = "by 75 to 200", .doc = "your lane opponent 75-200" },
        .{ .card = "by 20 to 65", .doc = "a jungler 20-65" },
    } },
    .{ .id = "counter-role", .doc = .learned, .figures = &.{
        .{ .card = "2.2-2.5 points", .doc = "top 2.2-2.5 points" },
        .{ .card = "1.2-1.5 points", .doc = "support 1.2-1.5" },
        .{ .card = "1.0-1.4 points", .doc = "jungle 1.0-1.4" },
        .{ .card = "134,375 games", .doc = "134,375 held-out games" },
    } },
    .{ .id = "team-counter", .doc = .learned, .figures = &.{
        .{ .card = "Their team", .doc = "good against this enemy team doesn't show beyond your lane" },
        .{ .card = "Gold at 14", .doc = "at most 35-45 gold at 14 per pairing" },
    } },
    .{ .id = "splitpush", .doc = .split_push, .figures = &.{
        .{ .card = "49.9%", .doc = "| all | 75481 | 49.9% |" },
        .{ .card = "75481", .doc = "| all | 75481 | 49.9% |" },
        .{ .card = "363,927 games", .doc = "363,927 games" },
    } },
    .{ .id = "wincon", .doc = .learned, .figures = &.{
        .{ .card = "244", .doc = "among 244 traits" },
        .{ .card = "89,584", .doc = "89,584 sealed games" },
    } },
    .{ .id = "matchup-n", .doc = .learned, .figures = &.{
        .{ .card = "80 games", .doc = "~80 games is about a third real" },
        .{ .card = "33", .doc = "about a third real and two thirds luck" },
        .{ .card = "about 300 to be half", .doc = "~300 games to be half real" },
    } },
    .{ .id = "thin-matchups", .doc = .learned, .figures = &.{
        .{ .card = "31.5k", .doc = "of 31.5k (role and champion pair) on EUW 16.21" },
        .{ .card = "19", .doc = "only 19% 50+" },
        .{ .card = "46% had under 5", .doc = "46% had under 5 games" },
        .{ .card = "428616", .doc = "428,616 ranked solo games" },
    } },
    .{ .id = "rare-pick", .doc = .learned, .figures = &.{
        .{ .card = "39", .doc = "won about 39% of its next week's games" },
        .{ .card = "147 champion-roles", .doc = "147 champion-roles" },
        .{ .card = "Under 100", .doc = "under 100 games in 30 days" },
    } },
    .{ .id = "item-wr", .doc = .learned, .figures = &.{
        .{ .card = "2.9M", .doc = "2.9M purchases" },
    } },
    .{ .id = "support-gold", .doc = .learned, .figures = &.{
        .{ .card = "1-3 points", .doc = "worth 1-3 points on the support" },
        .{ .card = "6-12 points", .doc = "6-12 on the bot laner" },
        .{ .card = "4-8 points", .doc = "4-8 on top" },
    } },
    .{ .id = "scaling", .doc = .learned, .figures = &.{
        .{ .card = "2900", .doc = "about 2,900 gold further ahead" },
        .{ .card = "2,600 behind", .doc = "about 2,600 further behind" },
        .{ .card = "at 25 min", .doc = "at 25 minutes a team with Kayle top" },
    } },
    .{ .id = "comeback", .doc = .learned, .figures = &.{
        .{ .card = "at most 2-3.5 points per 1,000 gold", .doc = "at most 2-3.5 points per 1,000 gold at 15:00" },
    } },
    .{ .id = "runes", .doc = .learned, .figures = &.{
        .{ .card = "120 more gold at 14", .doc = "First Strike about 120 more gold at 14" },
        .{ .card = "10604", .doc = "10,604 held-out games" },
    } },
    // The doc gives the range over skillshots, spells and crowd control; 82% is its top
    .{ .id = "skillshots", .doc = .learned, .figures = &.{
        .{ .card = "82%", .doc = "(70-82%)" },
        .{ .card = "a third of those you dodge", .doc = "your lane opponent about a third of how many skillshots you dodge" },
    } },
    .{ .id = "style-types", .doc = .learned, .figures = &.{
        .{ .card = "About 0.7 points", .doc = "about 0.7 points of win chance on average" },
        .{ .card = "no player types", .doc = "no distinct playstyle types" },
    } },
    .{ .id = "luck", .doc = .learned, .figures = &.{
        .{ .card = "46% to 64%", .doc = "46% to 64% for the middle half with 10+ games" },
        .{ .card = "6952", .doc = "6,952 player-champion pairs" },
    } },
};

fn text(doc: Doc) []const u8 {
    return switch (doc) {
        .learned => @embedFile("learned.md"),
        .fed => @embedFile("fed-player-win-rate-measured.md"),
        .deficit => @embedFile("gold-deficit-comeback-measured.md"),
        .kill_gold => @embedFile("kill-gold-by-rank-measured.md"),
        .split_push => @embedFile("split-pusher-rank-measured.md"),
    };
}

/// Runs of whitespace as one space, so a figure may straddle a wrapped line
fn collapse(a: std.mem.Allocator, s: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    var it = std.mem.tokenizeAny(u8, s, " \t\r\n");
    while (it.next()) |word| {
        if (out.items.len > 0) try out.append(a, ' ');
        try out.appendSlice(a, word);
    }
    return out.items;
}

/// The parts of `doc` a row's figures must share: learned.md's findings one by one, any
/// other doc whole
fn parts(a: std.mem.Allocator, doc: Doc) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    const whole = text(doc);
    if (doc != .learned) {
        try out.append(a, try collapse(a, whole));
        return out.items;
    }
    var start: usize = 0;
    while (std.mem.findPos(u8, whole, start + 1, "\n- ")) |next| : (start = next) {
        try out.append(a, try collapse(a, whole[start..next]));
    }
    try out.append(a, try collapse(a, whole[start..]));
    return out.items;
}

/// Everything a card shows, strings as typed and numbers as `{d}` prints them
fn cardText(a: std.mem.Allocator, p: ld.Puzzle) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(a);
    const w = &out.writer;
    try w.print("{s}\n{s}\n{s}\n{s}\n{s}\n{d}\n", .{ p.q, p.ctx, p.why, p.tip, p.from, p.games });
    switch (p.setup) {
        .rates => |r| for (r.rows) |row| try w.print("{s}\n{s}\n{d}\n{d}\n", .{ row.label, row.sub, row.v, row.games }),
        .facts => |facts| for (facts) |f| try w.print("{s}\n{s}\n", .{ f.v, f.label }),
        .chips => |c| for (c.chips) |chip| try w.print("{s}\n", .{chip}),
        else => {},
    }
    switch (p.answer) {
        .guess => |g| try w.print("{d}\n", .{g.real}),
        .pick => |k| for (k.choices) |c| try w.print("{s}\n{s}\n{d}\n", .{ c.text, c.shown, c.games }),
    }
    for (p.reveal) |row| try w.print("{s}\n{s}\n{d}\n{d}\n", .{ row.label, row.sub, row.v, row.games });
    return out.written();
}

fn rowOf(id: []const u8) ?Row {
    for (rows) |r| if (std.mem.eql(u8, r.id, id)) return r;
    return null;
}

test "every fixed puzzle's figures are on the card and in one finding of their doc" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const a = arena_state.allocator();
    var cards: usize = 0;
    var bad: usize = 0;
    for ([_][]const ld.Puzzle{ &fixed.chapter1, &fixed.chapter2, &fixed.chapter3, &fixed.chapter4, &fixed.chapter5 }) |chapter| for (chapter) |p| {
        cards += 1;
        const row = rowOf(p.id) orelse {
            std.debug.print("sources: no row for puzzle {s}\n", .{p.id});
            bad += 1;
            continue;
        };
        try std.testing.expect(row.figures.len > 0);
        const card = try cardText(a, p);
        for (row.figures) |f| if (std.mem.find(u8, card, f.card) == null) {
            std.debug.print("sources: {s}: the card no longer shows \"{s}\"\n", .{ p.id, f.card });
            bad += 1;
        };
        const found = for (try parts(a, row.doc)) |part| {
            for (row.figures) |f| {
                if (std.mem.find(u8, part, f.doc) == null) break;
            } else break true;
        } else false;
        if (!found) {
            for (row.figures) |f| {
                const anywhere = for (try parts(a, row.doc)) |part| {
                    if (std.mem.find(u8, part, f.doc) != null) break true;
                } else false;
                if (!anywhere) std.debug.print("sources: {s}: {t} no longer says \"{s}\"\n", .{ p.id, row.doc, f.doc });
            }
            std.debug.print("sources: {s}: its figures are not in one finding of {t}\n", .{ p.id, row.doc });
            bad += 1;
        }
    };
    // A row whose puzzle is gone
    try std.testing.expectEqual(cards, rows.len);
    try std.testing.expectEqual(@as(usize, 0), bad);
}
