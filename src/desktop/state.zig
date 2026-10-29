//! What the app shows, as the poller (poller.zig) publishes it: no drawing here, so the
//! dvui window (ui.zig) and the webview app (src/shell) read the same types

const std = @import("std");
const lanecard = @import("../lanecard.zig");
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
    /// The card is an ally's lane (lane_role), not mine
    ally: bool = false,
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
    downloading,
    /// Error name of the last failed check (@errorName: static)
    failed: []const u8,
    /// A new version is in place for the next start
    restart,
};

/// The window's "Count your mastery points" box; the poller reads it each tick
pub var by_mastery: std.atomic.Value(bool) = .init(true);

/// The lane the card shows (Role's backing int), set by a click on an ally's seat;
/// `own_lane` shows mine. Back to mine when champ select ends
pub var lane_role: std.atomic.Value(u8) = .init(own_lane);
pub const own_lane = 255;

/// The sign-in form's, under the poller's mutex
pub const SignIn = struct {
    /// No working sign in: the form is offered
    needed: bool = false,
    /// A sign in is on its way
    busy: bool = false,
    /// Why the last try or update check failed, for the form
    message: []const u8 = "",
};
