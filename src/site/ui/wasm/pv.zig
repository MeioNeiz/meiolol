//! ui-pv.wasm: Meio's preview (ui.pv) on public champion pages, loaded from /private/ only
//! by browsers that opened /admin or /private (site/shell.zig admin_link); nginx's login
//! gate covers it and its data. Its box goes after the page's head island, outside every
//! island so no diff meets it. Not an island: nothing in it takes input. It follows the
//! shown role, region, rank and locks (the fragment), which the islands change with no
//! event of their own: a MutationObserver redraws, and only a change of what's asked for
//! fetches. Two files per draw, one per period: Meio's number is the same in both, each
//! carries its window's raw games. Matchup pages get nothing
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");
const pv = ui.pv;
const pd = ui.pvdata;
const Role = ui.role.Role;
const cp = ui.champpage;

pub const panic = zjb.panic;
/// The fragment with the path's role: dom.hash
pub const url_map: dom.UrlMap = .champion;

const gpa = std.heap.wasm_allocator;

var page: zjb.Handle = .null;
var box: zjb.Handle = .null;
var champ_id: u32 = 0;

/// One period's Meio file (cp.Period's order): the path asked for last, and its answer
/// once in. Answers to an older path are dropped by their generation
const Slot = struct {
    want: [320]u8 = undefined,
    want_len: usize = 0,
    gen: i32 = 0,
    bytes: ?[]u8 = null,
    shown: ?pd.Meio = null,
    arena: std.heap.ArenaAllocator = .init(gpa),
};
var slots: [2]Slot = .{ .{}, .{} };

/// The champion page's pick and locks, as its islands read them from the fragment
const Url = struct {
    role: ?Role = null,
    region: cp.Region = .euw,
    period: cp.Period = .days30,
    rank: cp.Rank = .plat,
    lk: ui.url.Str(200) = .{},
};

export fn main() void {
    const doc = zjb.global("document");
    // Its script is added by another, so it runs as soon as it loads, maybe mid-parse
    const state = doc.get("readyState", zjb.Handle);
    defer state.release();
    var buf: [16]u8 = undefined;
    if (std.mem.eql(u8, state.readString(&buf) catch "", "loading")) {
        doc.call("addEventListener", .{ zjb.constString("DOMContentLoaded"), zjb.fnHandle("pvStart", &onReady) }, void);
        return;
    }
    start();
}

fn onReady(e: zjb.Handle) callconv(.c) void {
    e.release();
    start();
}

fn start() void {
    const doc = zjb.global("document");
    page = doc.call("querySelector", .{zjb.constString(".c-cpage[data-id]")}, zjb.Handle).kept();
    if (page == .null) return;
    const vs = dom.attrOf(page, "data-vs");
    defer gpa.free(vs);
    if (vs.len > 0) return;
    const id = dom.attrOf(page, "data-id");
    defer gpa.free(id);
    champ_id = std.fmt.parseInt(u32, id, 10) catch return;
    const anchor = page.call("querySelector", .{zjb.constString("[data-island=champion]")}, zjb.Handle);
    defer anchor.release();
    if (anchor == .null) return;
    box = doc.call("createElement", .{zjb.constString("div")}, zjb.Handle).kept();
    anchor.call("after", .{box}, void);
    draw();
    const o = zjb.global("MutationObserver").new(.{zjb.fnHandle("pvChanged", &onChanged)});
    defer o.release();
    const opts = zjb.global("Object").new(.{});
    defer opts.release();
    opts.set("childList", true);
    opts.set("subtree", true);
    opts.set("characterData", true);
    o.call("observe", .{ page, opts }, void);
}

fn onChanged(records: zjb.Handle, observer: zjb.Handle) callconv(.c) void {
    records.release();
    observer.release();
    draw();
}

/// Asks for both periods' files under the fragment's pick; draws once an answer is in.
/// Our own redraw is a mutation too: nothing asked anew, nothing drawn
fn draw() void {
    const r = shownRole();
    var fresh = false;
    for (&slots, 0..) |*s, i| {
        const want = meioWant(r, @fromBackingInt(@intCast(i))) orelse continue;
        if (std.mem.eql(u8, want, s.want[0..s.want_len])) continue;
        ask(s, @intCast(i), want);
        fresh = true;
    }
    if (fresh) render();
}

fn render() void {
    var a: std.heap.ArenaAllocator = .init(gpa);
    defer a.deinit();
    var t: ui.Tree = .{};
    var h: ui.H = .init(a.allocator(), &t);
    const d = if (slots[0].shown) |*m| m else null;
    const p = if (slots[1].shown) |*m| m else null;
    const n = if (pv.Preview.of(d, p)) |v| pv.view(&h, v) else h.div(.{}, .{});
    if (h.oom) return;
    const el = dom.nodes(&t, n);
    box.call("replaceWith", .{el}, void);
    box.release();
    box = el.kept();
}

var want_buf: [512]u8 = undefined;

/// Meio's path for the shown role in `period` under the fragment's region, rank and locks
fn meioWant(r: Role, period: cp.Period) ?[]const u8 {
    var frag: [1024]u8 = undefined;
    const u = ui.url.read(Url, dom.dom.hash(&frag));
    var fba: std.heap.FixedBufferAllocator = .init(&want_buf);
    const view: u8 = 2 * @as(u8, @backingInt(u.region)) + @backingInt(period);
    const p = pd.meioPath(fba.allocator(), view, champ_id, r, @tagName(u.rank), u.lk.slice()) catch return null;
    return if (p.len > slots[0].want.len) null else p;
}

/// Slot `i` fetches `want`; its old answer stops showing
fn ask(s: *Slot, i: i32, want: []const u8) void {
    @memcpy(s.want[0..want.len], want);
    s.want_len = want.len;
    s.gen += 1;
    s.shown = null;
    dom.fetch(want, 2 * s.gen + i, loaded);
}

fn loaded(tag: i32, bytes: ?[]u8) void {
    const s = &slots[@intCast(@mod(tag, 2))];
    if (@divFloor(tag, 2) != s.gen) {
        if (bytes) |b| gpa.free(b);
        return;
    }
    s.shown = null;
    _ = s.arena.reset(.retain_capacity);
    if (s.bytes) |old| gpa.free(old);
    s.bytes = bytes;
    if (bytes) |b| s.shown = ui.data.decode(s.arena.allocator(), pd.Meio, b) catch null;
    render();
}

/// The fragment's role (the path's, mapped in), else the one the page was rendered for, else
/// its most played
fn shownRole() Role {
    var buf: [512]u8 = undefined;
    const frag = dom.dom.hash(&buf);
    var it = std.mem.tokenizeAny(u8, frag, "#&");
    while (it.next()) |kv| {
        if (std.mem.startsWith(u8, kv, "role=")) if (std.meta.stringToEnum(Role, kv["role=".len..])) |r| return r;
    }
    if (dom.pageRole()) |r| return r;
    const roles = dom.attrOf(page, "data-roles");
    defer gpa.free(roles);
    var words = std.mem.tokenizeScalar(u8, roles, ' ');
    return std.meta.stringToEnum(Role, words.next() orelse "") orelse .top;
}
