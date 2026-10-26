//! The desktop app's page as one island (ui-app.wasm). The shell (src/shell/screens.zig)
//! renders it from the poller's state and keeps the same Data encoded (data.zig) at
//! app.bin; on a change it sends `{"app": seq}` and the island fetches the file and
//! patches. A screen per client state: a note while there is nothing to show, champ
//! select's board and options
const tree = @import("tree.zig");
const badge = @import("badge.zig");
const champselect = @import("champselect.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const Screen = union(enum) {
    /// Nothing to show yet: what the app waits for
    note: Note,
    select: champselect.Screen,
};

pub const Note = struct {
    title: []const u8,
    text: []const u8 = "",
};

pub const Data = struct {
    /// The shell's count of changes: a page and a file from different moments differ here
    seq: u32,
    private: bool,
    /// Where the client is ("Lobby", "Champ select · Picks")
    where: []const u8,
    screen: Screen,
};

pub const sel = "[data-island=app]";

pub const App = struct {
    data: Data,

    pub const Msg = enum { none };

    pub fn update(_: *App, _: Msg, _: *tree.Event) void {}

    pub fn view(a: *App, h: *H) N {
        return page(h, a.data);
    }
};

pub fn page(h: *H, d: Data) N {
    return h.div(.{ .class = "c-app", .data_island = "app", .data_seq = d.seq }, .{
        h.el(.header, .{}, .{
            h.b(.{}, .{"meiolol"}),
            if (d.private) badge.view(h, .accent, .{W.private}) else null,
            h.span(.{ .class = "where" }, .{d.where}),
        }),
        switch (d.screen) {
            .note => |n| h.div(.{ .class = "note" }, .{
                h.el(.h1, .{}, .{n.title}),
                if (n.text.len > 0) h.p(.{}, .{n.text}) else null,
            }),
            .select => |s| champselect.view(h, s),
        },
    });
}

const W = struct {
    const private = plain("private");
};

pub const name = "App";
pub const scope = .{".c-app"};

pub const css =
    \\@layer components {
    \\  .c-app { display: flex; flex-direction: column; gap: var(--sp-4); padding: var(--sp-3) var(--sp-4) var(--sp-5);
    \\    min-width: 0; }
    \\  .c-app > header { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-app > header .where { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-app .note { display: flex; flex-direction: column; gap: var(--sp-1); padding: var(--sp-6) 0; text-align: center; }
    \\  .c-app .note h1 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-app .note p { margin: 0; color: var(--muted); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    g.addFill("waiting", page(h, .{ .seq = 1, .private = false, .where = "Lobby", .screen = .{ .note = .{
        .title = "The board shows in champ select",
        .text = "Both teams, your lane, options and bans.",
    } } }));
    g.addFill("champ select, private", page(h, .{
        .seq = 2,
        .private = true,
        .where = "Champ select · Picks",
        .screen = .{ .select = champselect.sample },
    }));
}
