//! The window's building blocks: colours, champion icons, chips, paragraphs and
//! section headings, shared by the lane panel and the board

const std = @import("std");
const dvui = @import("dvui");
const core = @import("core");
const icons = @import("icons.zig");
const board = @import("../board.zig");

pub const Ctx = struct {
    stats: *const core.Stats,
    icons: *const icons.Icons,
    edition: board.Edition,
    /// Wide layout: teams beside the lane panel
    wide: bool,

    pub fn private(c: Ctx) bool {
        return c.edition == .private;
    }
};

/// Fixed colours on top of the dark theme. Team colours follow the client: blue mine,
/// red theirs, whichever side of the map
pub const palette = struct {
    pub const ally: dvui.Color = .fromHex("#4a8fe7");
    pub const enemy: dvui.Color = .fromHex("#e0565b");
    pub const ahead: dvui.Color = .fromHex("#4fb37a");
    pub const behind: dvui.Color = .fromHex("#d0605e");
    pub const turn: dvui.Color = .fromHex("#d8b25a");
    pub const private: dvui.Color = .fromHex("#7a5cc4");
    pub const bar: dvui.Color = .fromHex("#141518");
    pub const card: dvui.Color = .fromHex("#25272c");
    pub const card_border: dvui.Color = .fromHex("#383b43");
    pub const placeholder: dvui.Color = .fromHex("#34373e");
};

pub fn text() dvui.Color {
    return dvui.themeGet().color(.content, .text);
}

pub fn small() dvui.Font {
    const f = dvui.themeGet().font_body;
    return f.withSize(f.size - 2);
}

pub fn tiny() dvui.Font {
    const f = dvui.themeGet().font_body;
    return f.withSize(f.size - 3);
}

pub const IconOpts = struct {
    size: f32 = 40,
    /// Hovers and intents: not locked yet
    dim: bool = false,
    /// Bans
    crossed: bool = false,
    border: ?dvui.Color = null,
    id_extra: usize = 0,
};

/// The champion's square icon, else its initials on a tile; an empty tile for 0
pub fn champIcon(src: std.builtin.SourceLocation, ctx: Ctx, champion: u32, o: IconOpts) void {
    const opts: dvui.Options = .{
        .id_extra = o.id_extra,
        .min_size_content = .{ .w = o.size, .h = o.size },
        .max_size_content = .size(.{ .w = o.size, .h = o.size }),
        .corners = .all(o.size / 8),
        .border = if (o.border != null) .all(2) else null,
        .color_border = if (o.border) |c| .{ .color = c } else null,
        .gravity_y = 0.5,
    };
    if (champion != 0) if (ctx.icons.get(champion)) |png| {
        const wd = dvui.image(src, .{ .source = .{ .imageFile = .{ .bytes = png, .name = "champion" } } }, opts);
        const r = wd.contentRectScale().r;
        if (o.dim) r.fill(.{}, .{ .color = .{ .color = dvui.Color.black.opacity(0.5) } });
        if (o.crossed) cross(r);
        return;
    };
    var tile = dvui.box(src, .{}, opts.override(.{
        .background = true,
        .color_fill = .{ .color = palette.placeholder },
    }));
    defer tile.deinit();
    if (champion == 0) return;
    var buf: [2]u8 = undefined;
    const font = dvui.themeGet().font_heading;
    dvui.labelNoFmt(@src(), icons.initials(ctx.stats.nameOf(champion), &buf), .{}, .{
        .gravity_x = 0.5,
        .gravity_y = 0.5,
        .font = font.withSize(o.size * 0.4),
        .color_text = .{ .color = text().opacity(if (o.dim) 0.5 else 0.85) },
        .padding = .{},
    });
    if (o.crossed) cross(tile.data().contentRectScale().r);
}

fn cross(r: dvui.Rect.Physical) void {
    var path: dvui.Path.Builder = .init(dvui.currentWindow().lifo());
    defer path.deinit();
    path.addPoint(.{ .x = r.x + r.w * 0.1, .y = r.y + r.h * 0.9 });
    path.addPoint(.{ .x = r.x + r.w * 0.9, .y = r.y + r.h * 0.1 });
    path.build().stroke(.{ .thickness = @max(2, r.w / 14), .color = .{ .color = palette.enemy } });
}

/// A small rounded label: modes, the turn, the edition
pub fn chip(src: std.builtin.SourceLocation, str: []const u8, fill: dvui.Color, id_extra: usize) void {
    dvui.labelNoFmt(src, str, .{}, .{
        .id_extra = id_extra,
        .background = true,
        .color_fill = .{ .color = fill },
        .color_text = .{ .color = dvui.Color.white },
        .corners = .all(9),
        .padding = .{ .x = 8, .y = 1, .w = 8, .h = 1 },
        .margin = .{ .x = 6 },
        .font = small(),
        .gravity_y = 0.5,
    });
}

pub fn heading(src: std.builtin.SourceLocation, str: []const u8, color: ?dvui.Color) void {
    dvui.labelNoFmt(src, str, .{}, .{
        .font = dvui.themeGet().font_heading,
        .color_text = if (color) |c| .{ .color = c } else null,
        .margin = .{ .y = 12, .h = 4 },
        .padding = .{},
    });
}

/// A card's box: background, border, rounded
pub fn card(src: std.builtin.SourceLocation, id_extra: usize, border: ?dvui.Color, dir: dvui.enums.Direction) *dvui.BoxWidget {
    return dvui.box(src, .{ .dir = dir }, .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = palette.card },
        .color_border = .{ .color = border orelse palette.card_border },
        .border = .all(if (border != null) 2 else 1),
        .corners = .all(6),
        .padding = .all(8),
        .margin = .{ .y = 3, .h = 3 },
    });
}

pub const ParaOpts = struct { muted: bool = false, small: bool = false, color: ?dvui.Color = null, id_extra: usize = 0 };

pub fn para(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype, opts: ParaOpts) void {
    var tl = dvui.textLayout(src, .{}, .{
        .id_extra = opts.id_extra,
        .expand = .horizontal,
        .background = false,
        .margin = .{ .y = 2, .h = 2 },
        .padding = .{},
    });
    defer tl.deinit();
    var buf: [1024]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, fmt, args) catch fmt;
    const color = opts.color orelse text();
    tl.addText(str, .{
        .color_text = .{ .color = if (opts.muted) color.opacity(0.6) else color },
        .font = if (opts.small) small() else dvui.themeGet().font_body,
    });
}

/// 950, 12k, 1.2M
pub fn compact(buf: []u8, n: u64) []const u8 {
    const f: f64 = @floatFromInt(n);
    return (if (n < 1000)
        std.fmt.bufPrint(buf, "{d}", .{n})
    else if (n < 10_000)
        std.fmt.bufPrint(buf, "{d:.1}k", .{f / 1000})
    else if (n < 1_000_000)
        std.fmt.bufPrint(buf, "{d:.0}k", .{f / 1000})
    else
        std.fmt.bufPrint(buf, "{d:.1}M", .{f / 1e6})) catch "?";
}

pub fn roleName(r: core.Role) []const u8 {
    return switch (r) {
        .top => "Top",
        .jungle => "Jungle",
        .middle => "Mid",
        .bottom => "Bot",
        .utility => "Support",
    };
}
