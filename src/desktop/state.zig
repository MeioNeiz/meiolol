//! What the app shows, as the poller (poller.zig) publishes it: no drawing here, so the
//! dvui window (ui.zig) and the webview app (src/shell) read the same types

const std = @import("std");
const lanecard = @import("../lanecard.zig");
const picks = @import("../picks.zig");
const board = @import("../board.zig");
const loading = @import("../loading.zig");
const ingame = @import("../ingame.zig");
const postgame = @import("../postgame.zig");
const comp = @import("../comp.zig");

/// False in the public exe: no private-edition code is compiled into it, desktop/private/
/// above all (deploy/check-edition.sh). The shots and the dev window carry both editions
pub const private_code = !@import("build_options").public;

pub const Edition = board.Edition;

/// Champ select as shown: the lane card and the board around it
pub const Select = struct {
    card: lanecard.Card,
    board: board.Board,
    /// Once every seat is locked
    comp: ?*const comp.Comp = null,
    /// The card is another seat's lane (lane_role), not mine
    ally: bool = false,
    /// That seat is an enemy's
    enemy: bool = false,
    /// The Options panel for the card's lane; null for an ally's once they lock
    picks: ?picks.Picks = null,
    /// Stats from every region (all_regions) rather than EUW's; null without the
    /// all-regions file
    all_regions: ?bool = null,
};

pub const Status = union(enum) {
    /// No stats file found next to the program
    no_data,
    no_client,
    /// Reachable but failing (error name)
    client_error: []const u8,
    /// Client running, not in champ select (gameflow phase)
    waiting: []const u8,
    /// Champ select without assigned positions (blind pick, ARAM)
    no_role,
    select: *const Select,
    /// The game is loading: cards from the last champ select
    loading: *const loading.Loading,
    /// In a game with Live Client Data up
    in_game: *const ingame.InGame,
    /// After a game, once the client has its end of game block
    post_game: *const postgame.PostGame,
};

/// From the update thread (update.zig), under the content
pub const Note = union(enum) {
    none,
    /// First start, signed in: fetching the data
    downloading: Progress,
    failed: Failed,
    /// The update address answers 404 or moved: only a new version from meio.lol/download
    /// updates again
    moved,
    /// A new version is in place for the next start
    restart,

    /// Bytes of the files this check fetches; total 0 before it knows
    pub const Progress = struct { done: u64 = 0, total: u64 = 0 };

    pub const Failed = struct {
        /// update.why's plain words (static)
        why: []const u8,
        /// Until the next check
        minutes: u32,
    };
};

/// The window's "Count your mastery points" box; the poller reads it each tick
pub var by_mastery: std.atomic.Value(bool) = .init(true);

/// The lane the card shows, set by a seat click: an ally's role (Role's backing int), an
/// enemy's (`enemy_lanes` past it), `own_lane` mine. Back to mine when champ select ends
pub var lane_role: std.atomic.Value(u8) = .init(own_lane);
pub const own_lane = 255;
pub const enemy_lanes = 5;

/// An enemy seat dragged onto another row, for the poller's next tick: the two rows'
/// roles (backing ints) as from << 8 | to, `no_swap` none
pub var swap: std.atomic.Value(u16) = .init(no_swap);
pub const no_swap = 0xffff;

/// The Options panel's region chip: champ select's stats from every region, when the
/// app has that file (Data.all), else EUW's
pub var all_regions: std.atomic.Value(bool) = .init(false);

/// The sign-in form's, under the poller's mutex
pub const SignIn = struct {
    /// No working sign in: the form is offered
    needed: bool = false,
    /// A sign in is on its way
    busy: bool = false,
    /// Why the last try or update check failed, for the form
    message: []const u8 = "",
};
