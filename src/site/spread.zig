//! Players' win rates on a champion (src/spread.zig) on its page: bars of players by
//! win rate, the middle half marked under them.

const std = @import("std");
const root = @import("root.zig");
const html = @import("html.zig");
const tpl = html.tpl;
const spread = @import("../spread.zig");
const scope = @import("scope.zig");

const Writer = std.Io.Writer;
const Champ = root.Champ;

/// SVG units: one bin's slot, the tallest bar, and where bars stand
const slot = 20;
const bar_h = 44;
const base = 48;

/// Centre of `pct`% on the x axis: bins centre on multiples of 10%
fn x(pct: u32) f64 {
    return slot / 2 + slot * @as(f64, @floatFromInt(pct)) / 10;
}

/// `period`: "last 30 days", "patch 16.21"
pub fn section(w: *Writer, s: *const spread.Spread, ch: Champ, region: html.Region, period: []const u8, chip: scope.Chip) !void {
    if (s.min_players == 0) return;
    const c = s.get(ch.id) orelse spread.Champion{ .id = ch.id, .players = 0, .bins = @splat(0), .p25 = 0, .p50 = 0, .p75 = 0, .shape = @splat(0), .luck_bins = @splat(0), .luck_p25 = 0, .luck_p75 = 0 };
    if (c.players < s.min_players) {
        try tpl.render(w,
            \\<p class="muted small">Players' win rates on {name}: more data needed ({players} {noun} {in} with {min}+ games on it, {period}; {need} needed). {chip}</p>
            \\
        , .{
            .chip = chip,
            .name = ch.name,
            .players = root.Thousands{ .n = c.players },
            .noun = if (c.players == 1) "player" else "players",
            .in = region.in(),
            .min = s.min_games,
            .period = period,
            .need = s.min_players,
        });
        return;
    }
    var tallest: u32 = 1;
    for (c.bins) |n| tallest = @max(tallest, n);
    try tpl.renderPart(w,
        \\<div class="spread"><span>Players' win rates on {name} {chip}</span>
        \\<svg viewBox="0 0 {width} 62" role="img" aria-label="Players by win rate: middle half {p25}% to {p75}%">
        \\<line class="mid" x1="{fifty}" x2="{fifty}" y1="0" y2="{base}"></line>
        \\
    , .{ .name = ch.name, .chip = chip, .width = slot * spread.bin_count, .p25 = c.p25, .p75 = c.p75, .fifty = x(50), .base = base });
    for (c.bins, 0..) |n, i| {
        const pct: u32 = @intCast(10 * i);
        const h = bar_h * @as(f64, @floatFromInt(n)) / @as(f64, @floatFromInt(tallest));
        try tpl.render(w,
            \\<rect class="{side}" x="{left}" y="{top:.1}" width="{bw}" height="{h:.1}" rx="2"><title>{pct}%: {n} players</title></rect>
            \\
        , .{
            .side = if (pct > 50) "up" else if (pct < 50) "down" else "even",
            .left = slot * i + 2,
            .top = base - h,
            .bw = slot - 4,
            .h = h,
            .pct = pct,
            .n = n,
        });
    }
    try tpl.renderPart(w,
        \\<line class="half" x1="{lo}" x2="{hi}" y1="52" y2="52"></line><circle cx="{med}" cy="52" r="2.5"></circle>
        \\<text x="{zero}" y="61">0%</text><text x="{fifty}" y="61">50%</text><text x="{hundred}" y="61">100%</text>
        \\</svg>
        \\<small>Middle half of players: {p25}% to {p75}%. {players} players {in} with {min}+ games on {name}, {period}; if every one played it equally well, luck alone would give {lp25}% to {lp75}%.</small></div>
        \\
    , .{
        .lo = x(c.p25),
        .hi = x(c.p75),
        .med = x(c.p50),
        .zero = x(0),
        .fifty = x(50),
        .hundred = x(100),
        .p25 = c.p25,
        .p75 = c.p75,
        .lp25 = c.luck_p25,
        .lp75 = c.luck_p75,
        .players = c.players,
        .in = region.in(),
        .min = s.min_games,
        .name = ch.name,
        .period = period,
    });
}
