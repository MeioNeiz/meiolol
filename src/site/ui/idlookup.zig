//! IdLookup: a Riot ID box and Review as one control, the Riot IDs this device looked up
//! as chips under it. Goes to the Your games page with the ID in the fragment, so it never
//! reaches a server log; before the island runs Review submits the form, which sends it
//! as ?id= instead (the page moves it to the fragment)
const std = @import("std");
const tree = @import("tree.zig");
const url = @import("url.zig");
const chip = @import("chip.zig");
const button = @import("button.zig");
const Gallery = @import("gallery.zig").Gallery;
const phrase = @import("phrase.zig");
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "IdLookup";
pub const scope = .{".c-lookup"};

const W = struct {
    pub const id = plain("Riot ID");
    pub const hint = plain("Riot ID, like Name#EUW");
    pub const review = plain("Review");
    pub const recent = plain("Looked up on this device");
};

/// Riot ID: 16 characters, #, 5; UTF-8 up to 4 bytes each
pub const Id = url.Str(96);

const Frag = struct { id: Id = .{} };

pub const IdLookup = struct {
    /// The Your games page, relative to this one
    to: []const u8,
    q: Id = .{},
    /// Newest first (your-recent on this device)
    recent: []const Id = &.{},
    /// Set by the island: Review becomes a link with the ID in the fragment
    live: bool = false,

    const L = @This();

    pub const Msg = union(enum) { input, key };

    pub fn update(l: *L, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .input => l.q.set(ev.text),
            .key => if (std.mem.eql(u8, ev.text, "Enter")) {
                if (trimmed(&l.q).len == 0) return;
                ev.handled = true;
                ev.after = .{ .op = .click, .ref = "go" };
            },
        }
    }

    pub fn view(l: *L, h: *H) N {
        var chips = h.list();
        for (l.recent, 0..) |*r, i| chips.add(h.li(.{ .key = i }, .{chip.view(h, .{ .href = l.href(h, r.slice()) }, .{r.slice()})}));
        const q = trimmed(&l.q);
        return h.div(.{ .class = "c-lookup", .data_island = "lookup", .data_to = l.to }, .{
            h.el(.form, .{ .class = "box", .action = l.to, .method = "get", .role = "search" }, .{
                h.input(.{
                    .name = "id",
                    .type = "search",
                    .placeholder = W.hint,
                    .aria_label = W.id,
                    .autocomplete = "off",
                    .spellcheck = "false",
                    .enterkeyhint = "go",
                    .value = l.q.slice(),
                    .on_input = h.on(l, .input),
                    .on_keydown = h.on(l, .key),
                }),
                if (l.live)
                    button.view(h, .{ .v = .primary, .href = if (q.len > 0) l.href(h, q) else l.to, .ref = "go" }, .{W.review})
                else
                    button.view(h, .{ .v = .primary, .submit = true, .ref = "go" }, .{W.review}),
            }),
            if (l.recent.len > 0) h.ul(.{ .class = "rec", .aria_label = W.recent }, .{chips.done()}) else null,
        });
    }

    fn href(l: *const L, h: *H, id: []const u8) []const u8 {
        var f: Frag = .{};
        f.id.set(id);
        var out: std.Io.Writer.Allocating = .init(h.mem);
        out.writer.print("{s}#", .{l.to}) catch {
            h.oom = true;
        };
        url.write(Frag, f, &out.writer) catch {
            h.oom = true;
        };
        return out.written();
    }
};

fn trimmed(q: *const Id) []const u8 {
    return std.mem.trim(u8, q.slice(), " \t");
}

pub const css =
    \\@layer components {
    \\  .c-lookup { display: grid; gap: var(--sp-2); min-width: 0; }
    \\  .c-lookup > .box { display: flex; align-items: center; gap: 4px; height: var(--ctl-l); padding: 4px;
    \\    border: 1px solid var(--ctl-line); border-radius: calc(var(--r-ctl) + 4px); background: var(--ctl-bg);
    \\    transition: background var(--dur) var(--ease); }
    \\  .c-lookup > .box:hover { background: var(--ctl-bg-2); }
    \\  .c-lookup > .box:focus-within { border-color: var(--sel-line); box-shadow: 0 0 0 3px var(--accent-bg); }
    \\  .c-lookup input { flex: 1; min-width: 0; height: 100%; min-height: 0; padding: 0 var(--sp-2); border: 0;
    \\    background: none; font-size: var(--fs-l); }
    \\  .c-lookup input:hover, .c-lookup input:focus { background: none; box-shadow: none; outline: none; }
    \\  .c-lookup .c-btn { height: 100%; min-height: 0; padding: 0 var(--sp-4); }
    \\  .c-lookup > .rec { display: flex; flex-wrap: wrap; gap: var(--sp-2); margin: 0; padding: 0; list-style: none; }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const empty = h.mem.create(IdLookup) catch return;
    empty.* = .{ .to = "your.html" };
    g.addFill("empty", empty.view(h));
    const recent = h.mem.alloc(Id, 2) catch return;
    recent[0] = .{};
    recent[0].set("Faker#KR1");
    recent[1] = .{};
    recent[1].set("Agurin#EUW");
    const typed = h.mem.create(IdLookup) catch return;
    typed.* = .{ .to = "your.html", .recent = recent };
    typed.q.set("Caps#G2");
    g.addFill("typed, recent IDs", typed.view(h));
}

test "an ID goes in the fragment, encoded" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var t: tree.Tree = .{};
    var h: H = .init(arena.allocator(), &t);
    const l: IdLookup = .{ .to = "your.html" };
    try std.testing.expectEqualStrings("your.html#id=Hide%20on%20bush%23KR1", l.href(&h, "Hide on bush#KR1"));
}
