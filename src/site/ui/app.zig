//! The desktop app's page as one island (ui-app.wasm). The shell (src/shell/screens.zig)
//! renders it from the poller's state and keeps the same Data encoded (data.zig) at
//! app.bin; on a change it sends `{"app": seq}` and the island fetches the file and
//! patches. A screen per client state: a note while there is nothing to show, champ
//! select's board and options, the loading cards, the in-game panel, the post game; the
//! sign-in under it, or in its place before there is data. The charts' own state (a
//! tapped minute, a dragged range) and what's typed live in App, past patches
const tree = @import("tree.zig");
const champselect = @import("champselect.zig");
const loadscreen = @import("loadscreen.zig");
const gamescreen = @import("gamescreen.zig");
const postgame = @import("postgame.zig");
const lane = @import("lane.zig");
const signin = @import("signin.zig");
const compview = @import("compview.zig");
const lobby = @import("lobby.zig");
const apphome = @import("apphome.zig");
const plain = @import("phrase.zig").plain;
const Gallery = @import("gallery.zig").Gallery;
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
    /// First start: the app mark over the steps to a first board, this one lit
    step: Step = .none,
    /// The step failed (its dot red, the text says why)
    failed: bool = false,
    /// Downloading: the bar's percent, 1 to 100; 0 no bar
    bar: u8 = 0,
};

pub const Step = enum(u8) { none, sign_in, download, open_league };

pub const Data = struct {
    /// The shell's count of changes: a page and a file from different moments differ here
    seq: u32,
    private: bool,
    /// Where the client is ("Lobby", "Champ select · Picks")
    where: []const u8,
    screen: Screen,
    /// No working sign-in: the form, or a line that opens it
    signin: ?signin.SignIn = null,
    /// A line under every screen in the shell's words: a new version waiting for the next
    /// start, or this version unable to update itself; "" none
    foot: []const u8 = "",
    /// Private edition: practice is on (ui/practice.zig above the page); null shows no
    /// button. Turning it on or off reloads the page, which loads ui-practice.wasm or not
    practice: ?bool = null,
};

pub const sel = "[data-island=app]";

pub const App = struct {
    data: Data,
    lane: lane.Held = .{},
    team: lane.Held = .{},
    form: signin.Form = .{},

    pub const Msg = enum {};

    pub fn update(_: *App, m: Msg, _: *tree.Event) void {
        switch (m) {}
    }

    pub fn view(a: *App, h: *H) N {
        const d = a.data;
        const attrs = .{ .class = "c-app", .data_island = "app", .data_seq = d.seq };
        return h.div(attrs, .{
            switch (d.screen) {
                .note => |n| note(h, n),
                .select => |s| champselect.view(h, s, &a.lane),
                .loading => |s| loadscreen.view(h, s),
                .game => |s| gamescreen.view(h, s, .{ .lane = &a.lane, .team = &a.team }),
                .post => |s| postgame.view(h, s, &a.team),
            },
            if (d.foot.len > 0) h.p(.{ .class = "foot" }, .{d.foot}) else null,
            if (d.signin) |s| signin.view(h, s, &a.form) else null,
        });
    }
};

/// With a step: the app mark (CSS), pulsing while it waits, the words, then the steps
fn note(h: *H, n: Note) N {
    var l = h.list();
    const at = @backingInt(n.step);
    for (W.steps, 1..) |w, i| l.add(h.li(.{ .class = if (i < at) "done" else null, .aria_current = if (i == at) "step" else null }, .{w}));
    return h.div(.{ .class = "note", .data_first = at > 0, .data_failed = n.failed }, .{
        if (n.title.len > 0) h.el(.h1, .{}, .{n.title}) else null,
        if (n.bar > 0) h.div(.{ .class = "bar" }, .{h.el(.i, .{ .style = h.vars(.{ .w = n.bar }) }, .{})}) else null,
        if (n.text.len > 0) h.p(.{}, .{n.text}) else null,
        if (at > 0) h.ul(.{ .class = "steps" }, .{l.done()}) else null,
    });
}

const W = struct {
    const steps = [_]tree.Text{ plain("Sign in"), plain("Download"), plain("Open League") };
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

pub const name = "App";
pub const scope = .{ ".c-app", ".c-page", ".c-live" };

pub const css =
    \\@layer components {
    \\  .c-page { --vh: 100vh; container: live / inline-size; display: flex; flex-direction: column; min-height: var(--vh); }
    \\  .c-live { flex: 1; display: flex; flex-direction: column; gap: var(--sp-4);
    \\    padding: var(--sp-3) var(--sp-4) var(--sp-5); min-width: 0; }
    \\  .c-app { display: flex; flex-direction: column; gap: var(--sp-4); min-width: 0; }
    \\  .c-app > .note { display: flex; flex-direction: column; gap: var(--sp-1); padding: var(--sp-6) 0; text-align: center; }
    \\  .c-app > .note h1 { margin: 0; font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-app > .note p { margin: 0; color: var(--muted); }
    \\  .c-app > .note[data-first]::before { content: ""; width: 56px; height: 56px; margin: 0 auto var(--sp-3); border-radius: 25%;
    \\    background: var(--brand) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cpath d='M6 21.5 11.5 14l5 4.5L26 7' fill='none' stroke='%23fff' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'/%3E%3Ccircle cx='16.5' cy='18.5' r='2.6' fill='%23f5c451'/%3E%3C/svg%3E") center / 100%;
    \\    animation: c-app-pulse 2.4s ease-in-out infinite; }
    \\  .c-app > .note[data-failed]::before { animation: none; filter: grayscale(1); opacity: 0.6; }
    \\  .c-app > .note .bar { width: min(320px, 80%); height: 6px; margin: var(--sp-2) auto var(--sp-1); border-radius: 3px;
    \\    background: var(--bar-track); overflow: hidden; }
    \\  .c-app > .note .bar i { display: block; height: 100%; width: calc(var(--w) * 1%); border-radius: 3px;
    \\    background: var(--brand); transition: width 0.4s; }
    \\  .c-app > .note:has(.bar) p { font-variant-numeric: tabular-nums; }
    \\  @keyframes c-app-pulse { 50% { transform: scale(0.92); opacity: 0.7; } }
    \\  .c-app > .note .steps { display: flex; justify-content: center; margin: var(--sp-4) 0 0; padding: 0; list-style: none;
    \\    font-size: var(--fs-s); color: var(--muted); }
    \\  .c-app > .note .steps li { display: flex; flex-direction: column; align-items: center; gap: var(--sp-1); width: 7.5em; position: relative; }
    \\  .c-app > .note .steps li::before { content: ""; width: 12px; height: 12px; border-radius: 50%; background: var(--line-2); position: relative; z-index: 1; }
    \\  .c-app > .note .steps li + li::after { content: ""; position: absolute; top: 5px; right: 50%; width: 100%; height: 2px; background: var(--line-2); }
    \\  .c-app > .note .steps .done::before, .c-app > .note .steps .done + li::after { background: var(--brand); }
    \\  .c-app > .note .steps [aria-current] { color: var(--text); font-weight: var(--w-b); }
    \\  .c-app > .note .steps [aria-current]::before { background: var(--brand); box-shadow: 0 0 0 4px var(--accent-bg); animation: c-app-pulse 2.4s ease-in-out infinite; }
    \\  .c-app > .note[data-failed] .steps [aria-current]::before { background: var(--lo3); box-shadow: none; animation: none; }
    \\  .c-app > .c-signin[data-full] { padding-top: 0; }
    \\  @media (prefers-reduced-motion: reduce) { .c-app > .note::before, .c-app > .note .steps li::before { animation: none; } }
    \\  .c-app [data-act] { cursor: pointer; }
    \\  .c-app > .foot { margin: 0; color: var(--muted); font-size: var(--fs-s); }
    \\  /* Champ select and in game: a left column (board and bans, or score and lanes, then
    \\     the panels after the island) beside a right one (lane panel, or your lane and
    \\     timers) held in view while the left scrolls; full screen a third column for the
    \\     Options panel. The island's own boxes step aside (display: contents) so its parts
    \\     and the panels share one grid. The right columns span every row: only the last,
    \\     flexible row grows with them, and no row gap, so the left column stays packed */
    \\  @container live (min-width: 820px) {
    \\    .c-live:has(.c-cs, .c-game) { display: grid; grid-template-columns: minmax(0, 5fr) minmax(0, 6fr);
    \\      grid-template-rows: repeat(8, auto) 1fr; align-items: start; gap: 0 var(--sp-4); }
    \\    .c-live:has(.c-game) { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); }
    \\    .c-live > .c-app:has(.c-cs, .c-game), .c-live .c-cs, .c-live .c-game { display: contents; }
    \\    .c-live .c-cs > .board, .c-live .c-game > .col:first-child, .c-live:has(.c-cs, .c-game) > :not(.c-app),
    \\      .c-live:has(.c-cs, .c-game) > .c-app > :not(.c-cs, .c-game) { grid-column: 1; margin-bottom: var(--sp-4); }
    \\    .c-live .c-cs > .side, .c-live .c-game > .col:last-child { grid-column: 2; grid-row: 1 / -1; position: sticky;
    \\      top: calc(var(--header) + var(--sp-3)); max-height: calc(var(--vh) - var(--header) - var(--sp-5)); overflow-y: auto;
    \\      overscroll-behavior: contain; }
    \\    /* Before champ select: the note and form panel beside the tiles */
    \\    .c-live:has(> .c-apphome) { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    \\      grid-template-rows: repeat(4, auto) 1fr; align-items: start; gap: 0 var(--sp-4); }
    \\    .c-live:has(> .c-apphome) > :not(.c-apphome) { grid-column: 1; margin-bottom: var(--sp-4); }
    \\    .c-live > .c-apphome { grid-column: 2; grid-row: 1 / -1; }
    \\  }
    \\  /* Full screen: the third column holds Options, or once all ten lock the comp view
    \\     (Options under the board then), so neither needs a scroll to be seen */
    \\  @container live (min-width: 1500px) {
    \\    .c-live:has(.c-cs):has(> .c-picks, > .c-comp) { grid-template-columns: minmax(0, 4fr) minmax(0, 5fr) minmax(0, 4fr); }
    \\    .c-live:has(.c-cs) > .c-picks, .c-live:has(.c-cs) > .c-comp { grid-column: 3; grid-row: 1 / -1; margin: 0;
    \\      position: sticky; top: calc(var(--header) + var(--sp-3)); max-height: calc(var(--vh) - var(--header) - var(--sp-5));
    \\      overflow-y: auto; }
    \\    .c-live:has(.c-cs):has(> .c-comp) > .c-picks { grid-column: 1; grid-row: auto; margin-bottom: var(--sp-4);
    \\      position: static; max-height: none; overflow-y: visible; }
    \\  }
    \\  .c-live > .c-comp { padding: 0; }
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
        .practice = false,
    }));
    // The shell's page (screens.zig renderIn; its <main> a div here) once all ten lock:
    // the Options panel and comp view after the island
    var locked = champselect.sample;
    locked.lane.mode = .locked;
    g.addFill("all locked, comp under", h.div(.{ .class = "c-page" }, .{h.div(.{ .class = "c-live" }, .{
        page(h, .{ .seq = 6, .private = false, .where = "Champ select · Finalization", .screen = .{ .select = locked } }),
        h.div(.{ .class = "c-picks" }, .{}),
        compview.view(h, compview.sample),
    })}));
    // The shell's page before champ select: the form panel and tiles after the island
    g.addFill("lobby, form and tiles", h.div(.{ .class = "c-page" }, .{h.div(.{ .class = "c-live" }, .{
        page(h, .{ .seq = 11, .private = true, .where = "Lobby", .screen = .{ .note = .{ .title = "The board shows in champ select" } } }),
        lobby.view(h, lobby.sample),
        apphome.view(h, "https://meio.lol", apphome.sample),
    })}));
    g.addFill("in game", page(h, .{ .seq = 3, .private = true, .where = "In game · 14:05", .screen = .{ .game = gamescreen.sample } }));
    g.addFill("first start, sign in", page(h, .{ .seq = 4, .private = false, .where = "No data", .screen = .{ .note = .{
        .title = "",
        .step = .sign_in,
    } }, .signin = .{ .full = true } }));
    g.addFill("first start, downloading", page(h, .{ .seq = 8, .private = false, .where = "No data", .screen = .{ .note = .{
        .title = "Downloading stats",
        .text = "12.4 / 38.1 MB",
        .step = .download,
        .bar = 33,
    } } }));
    g.addFill("first start, download failed", page(h, .{ .seq = 9, .private = false, .where = "No data", .screen = .{ .note = .{
        .title = "Download failed",
        .text = "No connection to meio.lol; trying again in 20 minutes.",
        .step = .download,
        .failed = true,
    } } }));
    g.addFill("League closed", page(h, .{ .seq = 10, .private = false, .where = "Client closed", .screen = .{ .note = .{
        .title = "Waiting for League",
        .step = .open_league,
    } } }));
    g.addFill("waiting, sign in and restart lines", page(h, .{ .seq = 5, .private = false, .where = "Lobby", .screen = .{ .note = .{
        .title = "The board shows in champ select",
    } }, .signin = .{ .message = "Your sign-in was removed: sign in again." }, .foot = "A new version of meiolol is downloaded: it starts the next time you open the app." }));
    g.addFill("waiting, update address gone", page(h, .{ .seq = 7, .private = false, .where = "Lobby", .screen = .{ .note = .{
        .title = "The board shows in champ select",
    } }, .foot = "This version of meiolol can no longer update itself: get the new one at meio.lol/download." }));
}
