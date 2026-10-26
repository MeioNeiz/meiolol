//! The desktop app's page as one island (ui-app.wasm). The shell (src/shell/screens.zig)
//! renders it from the poller's state and keeps the same Data encoded (data.zig) at
//! app.bin; on a change it sends `{"app": seq}` and the island fetches the file and
//! patches. A screen per client state: a note while there is nothing to show, champ
//! select's board and options, the loading cards, the in-game panel, the post game; the
//! sign-in under it, or in its place before there is data. The charts' own state (a
//! tapped minute, a dragged range) and what's typed live in App, past patches
const tree = @import("tree.zig");
const badge = @import("badge.zig");
const champselect = @import("champselect.zig");
const loadscreen = @import("loadscreen.zig");
const gamescreen = @import("gamescreen.zig");
const postgame = @import("postgame.zig");
const lane = @import("lane.zig");
const signin = @import("signin.zig");
const toshell = @import("toshell.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const Screen = union(enum) {
    /// Nothing to show yet: what the app waits for
    note: Note,
    select: champselect.Screen,
    loading: loadscreen.Screen,
    game: gamescreen.Screen,
    post: postgame.Screen,
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
    /// No working sign-in: the form, or a line that opens it
    signin: ?signin.SignIn = null,
    /// A new version is in place for the next start
    restart: bool = false,
};

pub const sel = "[data-island=app]";

pub const App = struct {
    data: Data,
    lane: lane.Held = .{},
    team: lane.Held = .{},
    form: signin.Form = .{},

    pub const Msg = enum { mastery };

    pub fn update(a: *App, m: Msg, _: *tree.Event) void {
        switch (m) {
            .mastery => if (a.data.screen == .select) if (a.data.screen.select.lane.mastery) |on| toshell.send(.{ .mastery = !on }),
        }
    }

    pub fn view(a: *App, h: *H) N {
        const d = a.data;
        const head = h.el(.header, .{}, .{
            h.b(.{}, .{"meiolol"}),
            if (d.private) badge.view(h, .accent, .{W.private}) else null,
            h.span(.{ .class = "where" }, .{d.where}),
        });
        const attrs = .{ .class = "c-app", .data_island = "app", .data_seq = d.seq };
        if (d.signin) |s| if (s.full) return h.div(attrs, .{ head, signin.view(h, s, &a.form) });
        return h.div(attrs, .{
            head,
            switch (d.screen) {
                .note => |n| h.div(.{ .class = "note" }, .{
                    h.el(.h1, .{}, .{n.title}),
                    if (n.text.len > 0) h.p(.{}, .{n.text}) else null,
                }),
                .select => |s| champselect.view(h, s, &a.lane, h.on(a, .mastery)),
                .loading => |s| loadscreen.view(h, s),
                .game => |s| gamescreen.view(h, s, .{ .lane = &a.lane, .team = &a.team }),
                .post => |s| postgame.view(h, s, &a.team),
            },
            if (d.restart) h.p(.{ .class = "restart" }, .{W.restart}) else null,
            if (d.signin) |s| signin.view(h, s, &a.form) else null,
        });
    }
};

/// A fresh App's render (the gallery's states)
pub fn page(h: *H, d: Data) N {
    const a = h.mem.create(App) catch {
        h.oom = true;
        return .none;
    };
    a.* = .{ .data = d };
    return a.view(h);
}

const W = struct {
    const private = plain("private");
    const restart = plain("A new version of meiolol is downloaded: it starts the next time you open the app.");
};

pub const name = "App";
pub const scope = .{".c-app"};

pub const css =
    \\@layer components {
    \\  .c-app { container-type: inline-size; display: flex; flex-direction: column; gap: var(--sp-4);
    \\    padding: var(--sp-3) var(--sp-4) var(--sp-5); min-width: 0; }
    \\  .c-app > header { display: flex; align-items: center; gap: var(--sp-2); }
    \\  .c-app > header .where { margin-left: auto; font-size: var(--fs-s); color: var(--muted); }
    \\  .c-app > .note { display: flex; flex-direction: column; gap: var(--sp-1); padding: var(--sp-6) 0; text-align: center; }
    \\  .c-app > .note h1 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-app > .note p { margin: 0; color: var(--muted); }
    \\  .c-app > .restart { margin: 0; color: var(--muted); font-size: var(--fs-s); }
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
    g.addFill("in game", page(h, .{ .seq = 3, .private = true, .where = "In game · 14:05", .screen = .{ .game = gamescreen.sample } }));
    g.addFill("first start, sign in", page(h, .{ .seq = 4, .private = false, .where = "No data", .screen = .{ .note = .{
        .title = "No stats file found",
    } }, .signin = .{ .full = true } }));
    g.addFill("waiting, sign in and restart lines", page(h, .{ .seq = 5, .private = false, .where = "Lobby", .screen = .{ .note = .{
        .title = "The board shows in champ select",
    } }, .signin = .{ .message = "Your sign-in was removed: sign in again." }, .restart = true }));
}
