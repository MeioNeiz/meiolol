//! MeionotesList: /admin/meionotes, every note on the site grouped by page or by component,
//! by status; Done, Reopen, a reply and Delete (asked twice; the owner's, delete_meionotes) per
//! note, Looks good or Not yet on one a session fixed, and the tool
//! on or off in this browser. ui-meionotes.wasm's list mode fetches (again every 20 s while
//! shown) and saves; the reply's input is uncontrolled and keyed, read by the glue at Save
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const segmented = @import("segmented.zig");
const nd = @import("meionotesdata.zig");
const fmt = @import("fmt.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = @import("phrase.zig").plain;
const H = tree.H;
const N = tree.N;

pub const name = "MeionotesList";
pub const scope = .{".c-meionoteslist"};
pub const sel = "[data-island=meionoteslist]";

pub const Group = enum { page, component };
/// check: fixed, waiting for Jacob; done: done or kept
pub const Filter = enum { open, check, done, any };

/// What the glue does after an event, then clears
pub const Want = union(enum) {
    none,
    status: struct { id: u32, status: nd.Status },
    reply: u32,
    /// Open again, the reply input's words as the reply
    reopen: u32,
    delete: u32,
    tool: bool,
};

pub const List = struct {
    notes: []const nd.Note = &.{},
    group: Group = .page,
    filter: Filter = .open,
    loading: bool = true,
    failed: bool = false,
    /// The note whose reply is being written
    replying: ?u32 = null,
    /// That reply reopens it (Not yet)
    reopening: bool = false,
    /// The note whose Delete waits for "Yes, delete"
    deleting: ?u32 = null,
    /// A Delete came back 403: shown to every admin, the owner's only, each try recorded
    denied: bool = false,
    /// What the last tool press did, for the line under it
    tool: ?bool = null,
    want: Want = .none,

    pub const Msg = union(enum) { group: Group, filter: Filter, done: u32, reopen: u32, reply: u32, not_yet: u32, send: u32, cancel, delete: u32, confirm: u32, tool: bool };

    pub fn update(l: *List, m: Msg, _: *tree.Event) void {
        switch (m) {
            .group => |g| l.group = g,
            .filter => |f| l.filter = f,
            .done => |id| l.want = .{ .status = .{ .id = id, .status = .done } },
            .reopen => |id| l.want = .{ .status = .{ .id = id, .status = .open } },
            .reply => |id| {
                l.replying = id;
                l.reopening = false;
            },
            .not_yet => |id| {
                l.replying = id;
                l.reopening = true;
            },
            .send => |id| l.want = if (l.reopening) .{ .reopen = id } else .{ .reply = id },
            .cancel => {
                l.replying = null;
                l.reopening = false;
                l.deleting = null;
            },
            .delete => |id| {
                l.replying = null;
                l.deleting = id;
            },
            .confirm => |id| {
                l.deleting = null;
                l.want = .{ .delete = id };
            },
            .tool => |on| l.want = .{ .tool = on },
        }
    }

    fn shown(l: *const List, n: nd.Note) bool {
        return switch (l.filter) {
            .open => n.status == .open,
            .check => n.status == .fixed,
            .done => n.status == .done or n.status == .kept,
            .any => true,
        };
    }

    /// The note's group heading
    fn key(l: *const List, n: nd.Note) []const u8 {
        return switch (l.group) {
            .page => n.path,
            .component => if (n.target.component().len > 0) n.target.component() else "(no component)",
        };
    }

    pub fn view(l: *List, h: *H) N {
        var open: u32 = 0;
        var check: u32 = 0;
        for (l.notes) |n| {
            open += @intFromBool(n.status == .open);
            check += @intFromBool(n.status == .fixed);
        }
        return h.div(.{ .class = "c-meionoteslist", .data_island = "meionoteslist" }, .{
            h.el(.header, .{ .class = "top" }, .{
                h.el(.h1, .{}, .{"meionotes"}),
                h.a(.{ .href = "/admin" }, .{"Admin"}),
                h.a(.{ .href = "/" }, .{"Site"}),
            }),
            h.div(.{ .class = "bar" }, .{
                segmented.view(h, .{ .s = .s, .label = plain("Group") }, &.{
                    .{ .label = plain("By page"), .selected = l.group == .page, .on = h.on(l, .{ .group = .page }) },
                    .{ .label = plain("By component"), .selected = l.group == .component, .on = h.on(l, .{ .group = .component }) },
                }),
                segmented.view(h, .{ .s = .s, .label = plain("Show") }, &.{
                    .{ .label = plain("Open"), .n = open, .selected = l.filter == .open, .on = h.on(l, .{ .filter = .open }) },
                    .{ .label = plain("To check"), .n = check, .selected = l.filter == .check, .on = h.on(l, .{ .filter = .check }) },
                    .{ .label = plain("Done"), .selected = l.filter == .done, .on = h.on(l, .{ .filter = .done }) },
                    .{ .label = plain("All"), .selected = l.filter == .any, .on = h.on(l, .{ .filter = .any }) },
                }),
                h.span(.{ .class = "tool" }, .{
                    button.view(h, .{ .s = .s, .on = h.on(l, .{ .tool = true }) }, .{"Tool on"}),
                    button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(l, .{ .tool = false }) }, .{"Tool off"}),
                    if (l.tool) |on| h.span(.{ .class = "meta" }, .{if (on) "On in this browser" else "Off in this browser"}) else null,
                }),
            }),
            if (l.loading) h.p(.{ .class = "meta" }, .{"Loading"}) else null,
            if (l.failed) h.p(.{ .class = "err" }, .{"Not loaded or not saved. Tries again in a moment."}) else null,
            if (l.denied) h.p(.{ .class = "denied", .role = "alert" }, .{"Not allowed: only the owner deletes meionotes. Your try was logged."}) else null,
            groups(l, h),
        });
    }

    fn groups(l: *List, h: *H) N {
        // Headings in order of first appearance after sorting by heading
        var keys: std.ArrayList([]const u8) = .empty;
        for (l.notes) |n| {
            if (!l.shown(n)) continue;
            const k = l.key(n);
            for (keys.items) |x| {
                if (tree.eql(x, k)) break;
            } else keys.append(h.mem, k) catch {
                h.oom = true;
                return .none;
            };
        }
        std.mem.sort([]const u8, keys.items, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lt);
        var secs = h.list();
        for (keys.items) |k| {
            var rows = h.list();
            for (l.notes) |n| if (l.shown(n) and tree.eql(l.key(n), k)) rows.add(row(l, h, n));
            secs.add(h.section(.{ .key = k }, .{ h.h2(.{}, .{k}), h.ul(.{}, .{rows.done()}) }));
        }
        if (keys.items.len == 0 and !l.loading) secs.add(h.p(.{ .class = "meta" }, .{"No meionotes."}));
        return h.div(.{ .class = "groups" }, .{secs.done()});
    }

    fn row(l: *List, h: *H, n: nd.Note) N {
        const c = fmt.civil(@intCast(@divFloor(n.created, 86400)));
        const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
        const target = if (n.target.kind == .page and n.target.steps.len == 0) "whole page" else n.target.snippet;
        return h.li(.{ .key = n.id, .data_status = n.status }, .{
            h.p(.{ .class = "text" }, .{n.text}),
            h.p(.{ .class = "meta" }, .{h.fmt("#{d}{s} · {s} · {d} {s} · {s}{s} · {s} · {d}×{d} {t}", .{
                n.id,
                switch (n.status) {
                    .open => "",
                    .fixed => " · fixed, to check",
                    .kept => " · kept",
                    .done => " · done",
                },
                n.author,
                c.day,
                months[(c.month -| 1) % 12],
                n.path,
                n.hash,
                if (n.scope == .everywhere) "everywhere" else target,
                n.vw,
                n.vh,
                n.theme,
            })}),
            if (n.reply.len > 0) h.p(.{ .class = "reply" }, .{n.reply}) else null,
            if (l.replying == n.id) h.div(.{ .class = "edit" }, .{
                h.input(.{
                    .key = "reply",
                    .data_ref = "reply",
                    .type = "text",
                    .maxlength = nd.max_reply / 3,
                    .aria_label = if (l.reopening) "What is still wrong" else "Reply",
                    .placeholder = if (l.reopening) "What is still wrong" else "e.g. the commit",
                }),
                button.view(h, .{ .s = .s, .v = .primary, .on = h.on(l, .{ .send = n.id }) }, .{if (l.reopening) "Reopen" else "Save"}),
                button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(l, .cancel) }, .{"Cancel"}),
            }) else if (l.deleting == n.id) h.div(.{ .class = "acts" }, .{
                h.span(.{ .class = "meta" }, .{"Gone for good, no undo."}),
                button.view(h, .{ .s = .s, .v = .primary, .on = h.on(l, .{ .confirm = n.id }) }, .{"Yes, delete"}),
                button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(l, .cancel) }, .{"Cancel"}),
            }) else h.div(.{ .class = "acts" }, .{
                switch (n.status) {
                    .open => button.view(h, .{ .s = .s, .on = h.on(l, .{ .done = n.id }) }, .{"Done"}),
                    .fixed => button.view(h, .{ .s = .s, .v = .primary, .on = h.on(l, .{ .done = n.id }) }, .{"Looks good"}),
                    .kept, .done => button.view(h, .{ .s = .s, .on = h.on(l, .{ .reopen = n.id }) }, .{"Reopen"}),
                },
                if (n.status == .fixed) button.view(h, .{ .s = .s, .on = h.on(l, .{ .not_yet = n.id }) }, .{"Not yet"}) else null,
                button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(l, .{ .reply = n.id }) }, .{"Reply"}),
                button.view(h, .{ .s = .s, .v = .quiet, .href = h.fmt("{s}{s}", .{ n.path, n.hash }) }, .{"Open"}),
                button.view(h, .{ .s = .s, .v = .quiet, .on = h.on(l, .{ .delete = n.id }) }, .{"Delete"}),
            }),
        });
    }
};

pub const css =
    \\@layer components {
    \\  .c-meionoteslist { display: grid; gap: var(--sp-3); max-width: 880px; margin: 0 auto; padding: var(--sp-4); }
    \\  .c-meionoteslist .top { display: flex; align-items: baseline; gap: var(--sp-3); }
    \\  .c-meionoteslist .top h1 { margin: 0 auto 0 0; font-size: var(--fs-l); }
    \\  .c-meionoteslist .top a { color: var(--t2); font-size: var(--fs-s); }
    \\  .c-meionoteslist .top a:hover { color: var(--text); }
    \\  .c-meionoteslist .bar { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-meionoteslist .tool { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); margin-left: auto; }
    \\  .c-meionoteslist h2 { margin: var(--sp-3) 0 var(--sp-1); font-size: var(--fs-m); overflow-wrap: anywhere; }
    \\  .c-meionoteslist ul { list-style: none; margin: 0; padding: 0; display: grid; gap: var(--sp-2); }
    \\  .c-meionoteslist li { display: grid; gap: var(--sp-1); padding: var(--sp-3); background: var(--panel);
    \\    border: 1px solid var(--line); border-radius: var(--r-m); }
    \\  .c-meionoteslist li:is([data-status=done], [data-status=kept]) .text { color: var(--t2); }
    \\  .c-meionoteslist li[data-status=done] .text { text-decoration: line-through; }
    \\  .c-meionoteslist li[data-status=fixed] { border-color: var(--brand); }
    \\  .c-meionoteslist p { margin: 0; overflow-wrap: anywhere; }
    \\  .c-meionoteslist .text { white-space: pre-wrap; }
    \\  .c-meionoteslist .meta { color: var(--t2); font-size: var(--fs-s); }
    \\  .c-meionoteslist .reply { font-size: var(--fs-s); }
    \\  .c-meionoteslist .reply::before { content: "↳ "; color: var(--t2); }
    \\  .c-meionoteslist .err { color: var(--bad); }
    \\  .c-meionoteslist .denied { padding: var(--sp-3); border: 2px solid var(--bad); border-radius: var(--r-m);
    \\    color: var(--bad); font-size: var(--fs-l); font-weight: var(--w-b); }
    \\  .c-meionoteslist .acts, .c-meionoteslist .edit { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sp-2); }
    \\  .c-meionoteslist .edit input { flex: 1 1 160px; min-height: var(--ctl-s); padding: 0 var(--sp-2); font: inherit;
    \\    color: var(--text); background: var(--ctl-bg); border: 1px solid var(--ctl-line); border-radius: var(--r-ctl); }
    \\}
    \\
;

fn fixture(id: u32, path: []const u8, text: []const u8, status: nd.Status, reply: []const u8, component: []const u8) nd.Note {
    return .{
        .id = id,
        .created = 1_793_000_000,
        .updated = 1_793_000_000,
        .author = "jacob",
        .path = path,
        .hash = if (id == 2) "?role=mid#id=3" else "",
        .scope = if (component.len > 0) .everywhere else .page,
        .target = if (component.len > 0) .{ .kind = .component, .name = component, .snippet = "Ahri 52.3%" } else .{ .kind = .page },
        .vw = 390,
        .vh = 844,
        .theme = .dark,
        .text = text,
        .status = status,
        .reply = reply,
    };
}

const gallery_notes = [_]nd.Note{
    fixture(1, "/tier/", "Row too tall on a phone", .open, "", ""),
    fixture(2, "/champion/ahri", "Every tier row: the win rate first, then the pick rate", .open, "", "c-tierrow"),
    fixture(3, "/tier/", "Header overlaps the filters at 320", .done, "fixed in 1a2b3c4d", ""),
    fixture(4, "/tier/", "Filters wrap badly", .fixed, "5e6f7a8b Tier filters: one row", ""),
    fixture(5, "/tier/", "Like these chips", .kept, "nothing to change", ""),
};

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = [_]struct { []const u8, List }{
        .{ "loading", .{} },
        .{ "by page, open", .{ .loading = false, .notes = &gallery_notes } },
        .{ "by component, all, replying", .{ .loading = false, .notes = &gallery_notes, .group = .component, .filter = .any, .replying = 3, .tool = true } },
        .{ "to check, not yet", .{ .loading = false, .notes = &gallery_notes, .filter = .check, .replying = 4, .reopening = true } },
        .{ "delete asked", .{ .loading = false, .notes = &gallery_notes, .deleting = 1 } },
        .{ "delete refused", .{ .loading = false, .notes = &gallery_notes, .denied = true } },
        .{ "none, failed", .{ .loading = false, .failed = true } },
    };
    for (states) |s| {
        const l = h.mem.create(List) catch {
            h.oom = true;
            return;
        };
        l.* = s[1];
        g.add(s[0], l.view(h));
    }
}

fn render(a: std.mem.Allocator, l: *List) ![]const u8 {
    var t: tree.Tree = .{};
    var h: H = .init(a, &t);
    const n = l.view(&h);
    try std.testing.expect(!h.oom);
    var out: std.Io.Writer.Allocating = .init(a);
    try @import("html.zig").write(&t, n, &out.writer);
    return out.written();
}

test "meionoteslist: groups by page or component, filters by status, asks the glue" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var l: List = .{ .loading = false, .notes = &gallery_notes };
    // Open by page: /champion/ahri before /tier/, the done one hidden
    var s = try render(a, &l);
    const ahri = tree.find(s, "<h2>/champion/ahri</h2>") orelse return error.TestUnexpectedResult;
    const tier = tree.find(s, "<h2>/tier/</h2>") orelse return error.TestUnexpectedResult;
    try std.testing.expect(ahri < tier);
    try std.testing.expect(tree.find(s, "Header overlaps") == null);
    try std.testing.expect(tree.find(s, " · jacob · ") != null);
    l.group = .component;
    l.filter = .any;
    s = try render(a, &l);
    try std.testing.expect(tree.find(s, "<h2>c-tierrow</h2>") != null);
    try std.testing.expect(tree.find(s, "<h2>(no component)</h2>") != null);
    try std.testing.expect(tree.find(s, "fixed in 1a2b3c4d") != null);
    l.filter = .check;
    s = try render(a, &l);
    try std.testing.expect(tree.find(s, "Looks good") != null);
    try std.testing.expect(tree.find(s, "Filters wrap") != null);
    try std.testing.expect(tree.find(s, "Like these chips") == null);
    l.filter = .done;
    try std.testing.expect(tree.find(try render(a, &l), "Like these chips") != null);
    l.notes = gallery_notes[0..2];
    try std.testing.expect(tree.find(try render(a, &l), "No meionotes.") != null);

    var ev: tree.Event = .{ .kind = .click };
    l.update(.{ .done = 2 }, &ev);
    try std.testing.expectEqual(Want{ .status = .{ .id = 2, .status = .done } }, l.want);
    l.update(.{ .reply = 3 }, &ev);
    try std.testing.expectEqual(@as(?u32, 3), l.replying);
    l.update(.{ .send = 3 }, &ev);
    try std.testing.expectEqual(Want{ .reply = 3 }, l.want);
    l.update(.{ .not_yet = 4 }, &ev);
    l.update(.{ .send = 4 }, &ev);
    try std.testing.expectEqual(Want{ .reopen = 4 }, l.want);
    l.update(.cancel, &ev);
    try std.testing.expectEqual(null, l.replying);
    try std.testing.expect(!l.reopening);
    l.notes = &gallery_notes;
    l.filter = .any;
    try std.testing.expect(tree.find(try render(a, &l), ">Delete<") != null);
    l.update(.{ .delete = 3 }, &ev);
    try std.testing.expect(tree.find(try render(a, &l), "Yes, delete") != null);
    l.update(.{ .confirm = 3 }, &ev);
    try std.testing.expectEqual(Want{ .delete = 3 }, l.want);
    try std.testing.expectEqual(null, l.deleting);
}
