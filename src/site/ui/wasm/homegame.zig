//! ui-homegame.wasm: the home page's game (ui.homepage.HomeReview), whose role switch
//! fetches that role's file; a returning visitor's newest game in its place once ui-home
//! hands it over (hp.Mine). Loaded by ui-home.wasm (dom.lazyLoad); zjb's generated loader
//! (ui-homegame.js) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const hp = ui.homepage;
const Role = ui.role.Role;

pub const panic = zjb.panic;

const gpa = std.heap.wasm_allocator;
const sel = "[data-island=home]";

var data: ui.gamedata.Data = undefined;
var review: hp.HomeReview = undefined;
var review0: hp.HomeReview = undefined;
var review_i: *ui.island.Island(hp.HomeReview, dom.Dom) = undefined;
var want: u32 = 0;
var asked: ?Role = null;
var src: []const u8 = "";
var up: []const u8 = "";
/// The server rendered these on the root: kept, so the first render matches
var js: []const u8 = "";
var wasm: []const u8 = "";
var roles: [5]bool = @splat(false);
var default: Role = .mid;
/// Each role's game once shown, as left: a switch back needs no fetch
var pages: [5]?ui.gamepage.GamePage = @splat(null);
var ready = false;
/// The visitor's game: asked for once, and no role fetch meanwhile (dom.fetch has one
/// callback)
var mine_at: enum { none, asked, done } = .none;
var mine_you: hp.You = undefined;

export fn main() void {
    dom.start();
    zjb.global("window").call("addEventListener", .{ zjb.constString(hp.Mine.event), zjb.fnHandle("uiYou", &onYou) }, void);
    game();
}

/// The review: the server's file first (hydration), then a role's on its switch
fn game() void {
    const el = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    want = std.fmt.parseInt(u32, dom.attrOf(el, "data-stamp"), 10) catch return;
    up = dom.attrOf(el, "data-up");
    roles = hp.rolesOf(std.fmt.parseInt(u8, dom.attrOf(el, "data-roles"), 10) catch return);
    default = std.meta.stringToEnum(Role, dom.attrOf(el, "data-role")) orelse return;
    src = dom.attrOf(el, "data-src");
    js = dom.attrOf(el, "data-js");
    wasm = dom.attrOf(el, "data-wasm");
    dom.fetch(src, 0, loaded);
}

fn loaded(_: i32, bytes: ?[]u8) void {
    const b = bytes orelse return dom.dom.warn("home: no data");
    // A page cached from an older build than its data: leave it as rendered
    if (ui.gamedata.stamp(b) != want) return dom.dom.warn("home: the page and its data differ");
    data = ui.data.decode(gpa, ui.gamedata.Data, b) catch return dom.dom.warn("home: bad data");
    // Each its own prepared game: the server's stays as rendered for hydration
    review0 = init(&data) catch return dom.dom.warn("home: out of memory");
    review = init(&data) catch return dom.dom.warn("home: out of memory");
    review.live = true;
    review_i = dom.rt.add(hp.HomeReview, &review, &review0, sel) catch return dom.dom.warn("home: out of memory");
    dom.rt.changed = check;
    ready = true;
    mine();
}

fn onYou(e: zjb.Handle) callconv(.c) void {
    e.release();
    mine();
}

/// ui-home's hand-over on the root, if in yet (else its event calls again)
fn mine() void {
    if (!ready or mine_at != .none or asked != null) return;
    const el = zjb.global("document").call("querySelector", .{zjb.constString(sel)}, zjb.Handle);
    if (el == .null) return;
    defer el.release();
    const u = dom.attrOf(el, hp.Mine.game_attr);
    if (u.len == 0) return;
    mine_you = hp.You.parse(gpa, dom.attrOf(el, hp.Mine.you_attr)) catch return dom.dom.warn("home: bad visitor data");
    mine_at = .asked;
    dom.fetch(u, 2, mineIn);
}

fn mineIn(_: i32, bytes: ?[]u8) void {
    mine_at = .done;
    // A role picked meanwhile, when the example stays
    defer check();
    const s = page(bytes) catch return dom.dom.warn("home: no visitor game");
    review.s = s;
    review.you = mine_you;
    review_i.render();
}

fn init(d: *const ui.gamedata.Data) !hp.HomeReview {
    var p: hp.HomeReview = .{ .s = try .init(gpa, d), .roles = roles, .shown = default, .want = default, .up = up, .default = default, .js = js, .wasm = wasm };
    p.s.src = src;
    p.s.stamp = want;
    return p;
}

/// A role picked: its game, fetched the first time
fn check() void {
    if (review.want == review.shown or asked != null or mine_at == .asked) return;
    if (pages[@backingInt(review.want)]) |s| return show(review.want, s);
    const path = review.path(gpa, review.want) catch return dom.dom.warn("home: out of memory");
    asked = review.want;
    dom.fetch(path, 1, switched);
}

fn switched(_: i32, bytes: ?[]u8) void {
    const r = asked orelse return;
    asked = null;
    if (page(bytes)) |s| show(r, s) else |_| {
        dom.dom.warn("home: no games for the role");
        if (review.want == r) review.want = review.shown;
        review_i.render();
    }
    check();
    mine();
}

fn page(bytes: ?[]u8) !ui.gamepage.GamePage {
    const d = try gpa.create(ui.gamedata.Data);
    d.* = try ui.data.decode(gpa, ui.gamedata.Data, bytes orelse return error.NoData);
    if (d.games.len == 0) return error.NoGames;
    var s: ui.gamepage.GamePage = try .init(gpa, d);
    s.src = src;
    s.stamp = want;
    return s;
}

/// The shown role's game kept as left
fn show(r: Role, s: ui.gamepage.GamePage) void {
    pages[@backingInt(review.shown)] = review.s;
    review.s = s;
    review.shown = r;
    review_i.render();
}
