//! Messages between the shell (win.zig, mac.zig) and its pages: Zig types both ways,
//! JSON on the wire as std.json writes a tagged union (`{"status":{...}}`). Pages see
//! them through bridge.js; ui.wasm reads the same shapes. A page that sends something
//! that doesn't parse is ignored, never trusted: the shell only serves its own pages,
//! but a page shows champion names and other text from the League client.

const std = @import("std");

/// Bumped when a message changes shape; `hello` carries it, so a page from a signed data
/// file newer or older than the exe can tell
pub const version = 1;

/// Shell to page
pub const ToPage = union(enum) {
    hello: Hello,
    status: Status,
    champ_select: ChampSelect,
    /// The app's page changed: app.bin is at this seq (ui/wasm/app.zig fetches it)
    app: u32,
};

pub const Hello = struct {
    version: u32 = version,
    /// The exe's release, 0 unreleased
    release: u64,
    public: bool,
    /// Windows or the Mac dev loop
    os: []const u8,
};

pub const Status = struct {
    /// no_data: no stats file yet (first start, before the download)
    client: enum { none, no_data, idle, champ_select, in_game, post_game },
};

pub const ChampSelect = struct {
    seq: u32,
    /// Seconds left in the current turn
    timer: u16,
    /// Blue side's draft win chance, percent (private edition only, later)
    blue: ?f32 = null,
    /// Blue 0-4, red 5-9
    seats: [10]Seat,
};

pub const Seat = struct {
    /// Data Dragon key ("LeeSin"); null while empty
    key: ?[]const u8 = null,
    name: ?[]const u8 = null,
    state: enum { empty, picking, done },
};

/// Page to shell
pub const FromPage = union(enum) {
    /// The page's first frame is on screen (two animation frames after DOMContentLoaded)
    painted: struct { page: []const u8 },
    /// The page drew champ select `seq`
    drawn: u32,
    /// Open a link in the player's browser (never inside the app)
    open: []const u8,
    /// The sign-in form (ui/signin.zig), for the poller's device.zig. Never logged
    signin: struct { username: []const u8, password: []const u8 },
    /// Options weigh the player's mastery points (champ select's toggle)
    mastery: bool,
    /// Private edition: practice on or off, or a change to its draft (practice.zig)
    practice: @import("ui").toshell.Practice,
};

/// Pages send small messages; a larger one is a bug or not ours
pub const max_from_page = 4096;

pub fn write(w: *std.Io.Writer, m: ToPage) std.Io.Writer.Error!void {
    try std.json.Stringify.value(m, .{ .emit_null_optional_fields = false }, w);
}

pub fn read(arena: std.mem.Allocator, json: []const u8) !FromPage {
    if (json.len > max_from_page) return error.TooLong;
    return std.json.parseFromSliceLeaky(FromPage, arena, json, .{});
}

/// Links a page may ask to open: our site and Riot's, over https
pub fn openable(url: []const u8) bool {
    const allowed = [_][]const u8{ "https://meio.lol/", "https://www.leagueoflegends.com/" };
    for (allowed) |a| if (std.mem.startsWith(u8, url, a)) {
        // A URL handed to ShellExecute: no quotes, spaces or controls to break out of it
        for (url) |ch| if (ch <= ' ' or ch == '"' or ch >= 0x7f) return false;
        return true;
    };
    return false;
}

test "to page: a tagged object, nulls left out" {
    var buf: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try write(&w, .{ .status = .{ .client = .champ_select } });
    try std.testing.expectEqualStrings("{\"status\":{\"client\":\"champ_select\"}}", w.buffered());

    w = .fixed(&buf);
    var seats: [10]Seat = @splat(.{ .state = .empty });
    seats[3] = .{ .key = "LeeSin", .name = "Lee Sin", .state = .done };
    try write(&w, .{ .champ_select = .{ .seq = 7, .timer = 20, .seats = seats } });
    const out = w.buffered();
    try std.testing.expect(std.mem.startsWith(u8, out, "{\"champ_select\":{\"seq\":7,\"timer\":20,\"seats\":[{\"state\":\"empty\"}"));
    try std.testing.expect(std.mem.indexOf(u8, out, "{\"key\":\"LeeSin\",\"name\":\"Lee Sin\",\"state\":\"done\"}") != null);
}

test "to page: names are escaped" {
    var buf: [512]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    var seats: [10]Seat = @splat(.{ .state = .empty });
    seats[0] = .{ .key = "Chogath", .name = "Cho'Gath \"</script>", .state = .picking };
    try write(&w, .{ .champ_select = .{ .seq = 1, .timer = 30, .seats = seats } });
    try std.testing.expect(std.mem.indexOf(u8, w.buffered(), "Cho'Gath \\\"</script>") != null);
}

test "from page: each kind parses, anything else is an error" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("draft.html", (try read(a, "{\"painted\":{\"page\":\"draft.html\"}}")).painted.page);
    try std.testing.expectEqual(@as(u32, 12), (try read(a, "{\"drawn\":12}")).drawn);
    try std.testing.expectEqualStrings("https://meio.lol/", (try read(a, "{\"open\":\"https://meio.lol/\"}")).open);
    try std.testing.expectEqualStrings("a\"b", (try read(a, "{\"signin\":{\"username\":\"ann\",\"password\":\"a\\\"b\"}}")).signin.password);
    try std.testing.expectEqual(false, (try read(a, "{\"mastery\":false}")).mastery);
    try std.testing.expectError(error.UnknownField, read(a, "{\"quit\":{}}"));
    try std.testing.expect(std.meta.isError(read(a, "{\"drawn\":-1}")));
    try std.testing.expect(std.meta.isError(read(a, "not json")));
    try std.testing.expect(std.meta.isError(read(a, "{\"drawn\":1,\"open\":\"x\"}")));
    const long = try a.alloc(u8, max_from_page + 1);
    @memset(long, ' ');
    try std.testing.expectError(error.TooLong, read(a, long));
}

test "openable: our site and Riot's, nothing that breaks out of a command line" {
    try std.testing.expect(openable("https://meio.lol/champion/ahri.html"));
    try std.testing.expect(openable("https://www.leagueoflegends.com/en-gb/"));
    try std.testing.expect(!openable("http://meio.lol/"));
    try std.testing.expect(!openable("https://meio.lol.evil.example/"));
    try std.testing.expect(!openable("file:///C:/Windows/System32/cmd.exe"));
    try std.testing.expect(!openable("https://meio.lol/\" --x"));
    try std.testing.expect(!openable("https://meio.lol/a b"));
}

test "fuzz: from page never crashes" {
    try std.testing.fuzz({}, struct {
        fn one(_: void, s: *std.testing.Smith) !void {
            var buf: [256]u8 = undefined;
            const n = s.slice(&buf);
            var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
            defer arena.deinit();
            _ = read(arena.allocator(), buf[0..n]) catch {};
        }
    }.one, .{});
}
