//! RoleIcon: Riot's position icon as a CSS-masked span in currentColor, the lane solid and
//! the rest of the map faint. A mask, not `<svg><use>`: WebKit resets the page's scroll
//! when rows holding a sprite `use` move inside a container query (stack.md gotchas).
//! Muted by default, `on` for the role in force; named for screen readers unless the
//! control around it names it
const tree = @import("tree.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "RoleIcon";
pub const scope = .{".c-role"};

pub const Role = enum {
    top,
    jungle,
    mid,
    bot,
    support,

    pub const all = [_]Role{ .top, .jungle, .mid, .bot, .support };

    pub fn label(r: Role) tree.Text {
        return switch (r) {
            .top => plain("Top"),
            .jungle => plain("Jungle"),
            .mid => plain("Mid"),
            .bot => plain("Bot"),
            .support => plain("Support"),
        };
    }
};

pub const Opts = struct {
    /// 16, 20 or 24 px
    s: enum { s, m, l } = .m,
    on: bool = false,
    /// False when the control or row around it already says the role
    named: bool = true,
};

pub fn view(h: *H, r: Role, o: Opts) N {
    return h.span(.{
        .class = "c-role",
        .data_r = r,
        .data_s = if (o.s == .m) null else o.s,
        .data_on = o.on,
        .role = if (o.named) "img" else null,
        .aria_label = if (o.named) r.label() else null,
        .aria_hidden = if (o.named) null else true,
    }, .{});
}

pub const css =
    \\@layer components {
    \\  .c-role { display: inline-block; flex: none; width: var(--icon-s); height: var(--icon-s);
    \\    vertical-align: middle; color: var(--muted); background: currentColor;
    \\    mask: var(--ri) center / contain no-repeat; }
    \\  .c-role[data-on] { color: var(--text); }
    \\  .c-role[data-s="s"] { width: 16px; height: 16px; }
    \\  .c-role[data-s="l"] { width: var(--icon); height: var(--icon); }
    \\  .c-role[data-r="top"] { --ri: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 34 34'%3E%3Cpath opacity='.35' fill-rule='evenodd' d='M21,14H14v7h7V14Zm5-3V26L11.014,26l-4,4H30V7.016Z'/%3E%3Cpolygon points='4 4 4.003 28.045 9 23 9 9 23 9 28.045 4.003 4 4'/%3E%3C/svg%3E"); }
    \\  .c-role[data-r="jungle"] { --ri: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 34 34'%3E%3Cpath fill-rule='evenodd' d='M25,3c-2.128,3.3-5.147,6.851-6.966,11.469A42.373,42.373,0,0,1,20,20a27.7,27.7,0,0,1,1-3C21,12.023,22.856,8.277,25,3ZM13,20c-1.488-4.487-4.76-6.966-9-9,3.868,3.136,4.422,7.52,5,12l3.743,3.312C14.215,27.917,16.527,30.451,17,31c4.555-9.445-3.366-20.8-8-28C11.67,9.573,13.717,13.342,13,20Zm8,5a15.271,15.271,0,0,1,0,2l4-4c0.578-4.48,1.132-8.864,5-12C24.712,13.537,22.134,18.854,21,25Z'/%3E%3C/svg%3E"); }
    \\  .c-role[data-r="mid"] { --ri: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 34 34'%3E%3Cpath opacity='.35' fill-rule='evenodd' d='M30,12.968l-4.008,4L26,26H17l-4,4H30ZM16.979,8L21,4H4V20.977L8,17,8,8h8.981Z'/%3E%3Cpolygon points='25 4 4 25 4 30 9 30 30 9 30 4 25 4'/%3E%3C/svg%3E"); }
    \\  .c-role[data-r="bot"] { --ri: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 34 34'%3E%3Cpath opacity='.35' fill-rule='evenodd' d='M13,20h7V13H13v7ZM4,4V26.984l3.955-4L8,8,22.986,8l4-4H4Z'/%3E%3Cpolygon points='29.997 5.955 25 11 25 25 11 25 5.955 29.997 30 30 29.997 5.955'/%3E%3C/svg%3E"); }
    \\  .c-role[data-r="support"] { --ri: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 34 34'%3E%3Cpath fill-rule='evenodd' d='M26,13c3.535,0,8-4,8-4H23l-3,3,2,7,5-2-3-4h2ZM22,5L20.827,3H13.062L12,5l5,6Zm-5,9-1-1L13,28l4,3,4-3L18,13ZM11,9H0s4.465,4,8,4h2L7,17l5,2,2-7Z'/%3E%3C/svg%3E"); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    var muted = h.list();
    for (Role.all) |r| muted.add(view(h, r, .{ .on = r == .mid }));
    g.add("muted, the one in force", h.div(.{ .class = "g-row" }, .{muted.done()}));
    g.add("16, 20, 24", h.div(.{ .class = "g-row" }, .{
        view(h, .bot, .{ .s = .s, .on = true }),
        view(h, .bot, .{ .on = true }),
        view(h, .bot, .{ .s = .l, .on = true }),
    }));
    g.add("beside its name", h.span(.{ .class = "g-row" }, .{ view(h, .jungle, .{ .named = false }), Role.jungle.label() }));
}
