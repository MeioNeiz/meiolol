//! Apply to test the desktop app, at /download#apply: Riot ID, a contact, role and rank
//! if they like, one line why. Island Apply (ui-apply.wasm) POSTs a ui.applydata.New to
//! /api/apply (api/applications.zig). As ui.account, the wasm reads the form once it is
//! sent: typed text stays in the inputs, the browser's checks (required, pattern) first
const std = @import("std");
const tree = @import("tree.zig");
const button = @import("button.zig");
const phrase = @import("phrase.zig");
const url = @import("url.zig");
const ad = @import("applydata.zig");
const Gallery = @import("gallery.zig").Gallery;
const plain = phrase.plain;
const H = tree.H;
const N = tree.N;

pub const name = "Apply";
pub const scope = .{".c-apply"};
pub const sel = "[data-island=apply]";
/// The section's id: links from the header and home land here
pub const anchor = "apply";

const W = struct {
    const title = plain("Apply to test the app");
    const lead = plain("Testers get the app before it is out. When there is a place, we send you a login ourselves; nothing is sent automatically.");
    const riot_id = plain("Riot ID");
    const contact = plain("Email or Discord username");
    const contact_hint = plain("Only to send you a login.");
    const role = plain("Main role");
    const rank = plain("Rank");
    const optional = plain("optional");
    const why = plain("Why you'd like to test it");
    const send = plain("Apply");
    const sent = plain("Thanks: you're on the list. If there's a place, we'll write to you.");
    const down = plain("Couldn't reach the server. Try again in a moment.");
    const busy = plain("Not taking applications right now. Try again tomorrow.");
    const failed = phrase.Phrase("Something went wrong ({n:int}).");
    const kept = plain("What we keep, and for how long");
};

const roles = std.EnumArray(ad.Role, []const u8).init(.{ .none = "Choose", .top = "Top", .jungle = "Jungle", .mid = "Mid", .bot = "Bot", .support = "Support" });
const ranks = std.EnumArray(ad.Rank, []const u8).init(.{
    .none = "Choose",
    .iron = "Iron",
    .bronze = "Bronze",
    .silver = "Silver",
    .gold = "Gold",
    .platinum = "Platinum",
    .emerald = "Emerald",
    .diamond = "Diamond",
    .master = "Master",
    .grandmaster = "Grandmaster",
    .challenger = "Challenger",
});

/// A sent form's outcome
pub const Say = enum { none, sent, down, server, busy, failed };

pub const Apply = struct {
    sending: bool = false,
    say: Say = .none,
    /// Say.server's: the API's reason, which names the field
    server: url.Str(96) = .{},
    /// Say.failed's HTTP status
    n: u16 = 0,
    /// For the wasm after an event
    want: bool = false,

    const P = @This();

    pub const Msg = enum { submit };

    pub fn update(p: *P, m: Msg, ev: *tree.Event) void {
        switch (m) {
            .submit => {
                ev.handled = true;
                if (p.sending or p.say == .sent) return;
                p.sending = true;
                p.say = .none;
                p.want = true;
            },
        }
    }

    /// /api/apply's answer: status 0 when the fetch failed
    pub fn answered(p: *P, status: u16, body: []const u8) void {
        p.sending = false;
        p.n = status;
        p.say = switch (status) {
            0 => .down,
            200 => .sent,
            429, 507 => .busy,
            400 => if (errorOf(body)) |e| blk: {
                p.server.set(e);
                break :blk .server;
            } else .failed,
            else => .failed,
        };
    }

    pub fn view(p: *P, h: *H) N {
        return h.section(.{ .class = "c-apply", .id = anchor, .data_island = "apply" }, .{
            h.h2(.{}, .{W.title}),
            h.p(.{ .class = "info" }, .{W.lead}),
            if (p.say == .sent) null else p.form(h),
            if (p.say == .none) null else h.p(.{ .class = "msg", .role = "status", .data_ok = p.say == .sent }, .{p.line(h)}),
            h.p(.{ .class = "info" }, .{h.a(.{ .href = "/privacy#testers" }, .{W.kept})}),
        });
    }

    fn form(p: *P, h: *H) N {
        return h.el(.form, .{ .method = "post", .action = "/api/apply", .on_submit = h.on(p, .submit) }, .{
            field(h, W.riot_id, null, h.input(.{
                .name = "riot_id",
                .placeholder = "Name#TAG",
                .autocomplete = "off",
                .autocapitalize = "none",
                .spellcheck = "false",
                .required = true,
                .maxlength = ad.max_riot_id,
                .pattern = "[^#]+#[^#]+",
            })),
            field(h, W.contact, W.contact_hint, h.input(.{
                .name = "contact",
                .autocomplete = "email",
                .autocapitalize = "none",
                .spellcheck = "false",
                .required = true,
                .maxlength = ad.max_contact,
            })),
            h.div(.{ .class = "pair" }, .{
                field(h, W.role, W.optional, choice(h, "role", ad.Role, roles)),
                field(h, W.rank, W.optional, choice(h, "rank", ad.Rank, ranks)),
            }),
            field(h, W.why, null, h.input(.{ .name = "why", .required = true, .maxlength = ad.max_why_chars })),
            button.view(h, .{ .v = .primary, .submit = true, .disabled = p.sending }, .{W.send}),
        });
    }

    fn line(p: *const P, h: *H) tree.Text {
        return switch (p.say) {
            .none => .{ .s = "" },
            .sent => W.sent,
            .down => W.down,
            .busy => W.busy,
            .server => .{ .s = p.server.slice() },
            .failed => W.failed.with(h, .{ .n = p.n }),
        };
    }
};

fn field(h: *H, label: tree.Text, hint: ?tree.Text, input: N) N {
    return h.label(.{}, .{
        h.span(.{ .class = "name" }, .{ label, if (hint) |x| h.span(.{ .class = "hint" }, .{x}) else null }),
        input,
    });
}

fn choice(h: *H, comptime field_name: []const u8, comptime E: type, labels: std.EnumArray(E, []const u8)) N {
    var opts = h.list();
    for (std.enums.values(E)) |v| opts.add(h.el(.option, .{ .value = @tagName(v) }, .{labels.get(v)}));
    return h.el(.select, .{ .name = field_name }, .{opts.done()});
}

/// A form value's enum: `none` for empty or unknown
pub fn enumOf(comptime E: type, s: []const u8) E {
    return std.meta.stringToEnum(E, s) orelse .none;
}

/// {"error":"..."}'s message
fn errorOf(json: []const u8) ?[]const u8 {
    const k = "\"error\":\"";
    const at = tree.find(json, k) orelse return null;
    const rest = json[at + k.len ..];
    return rest[0 .. std.mem.findScalar(u8, rest, '"') orelse return null];
}

pub const css =
    \\@layer components {
    \\  .c-apply { display: grid; gap: var(--sp-3); max-width: 32rem; margin-top: var(--sp-6); scroll-margin-top: var(--sp-6);
    \\    background: var(--panel); border: 1px solid var(--line); border-radius: var(--r-m); padding: var(--card-pad); }
    \\  .c-apply h2 { margin: 0; font-size: var(--fs-l); }
    \\  .c-apply p { margin: 0; }
    \\  .c-apply .info { color: var(--t2); }
    \\  .c-apply form { display: grid; gap: var(--sp-3); }
    \\  .c-apply label { display: grid; gap: var(--sp-1); min-width: 0; }
    \\  .c-apply .name { font-weight: var(--w-m); }
    \\  .c-apply .hint { margin-left: var(--sp-2); color: var(--muted); font-size: var(--fs-s); font-weight: normal; }
    \\  .c-apply .pair { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
    \\  .c-apply form > .c-btn { justify-self: start; }
    \\  .c-apply .msg { padding: var(--sp-2) var(--sp-3); border-radius: var(--r-s); background: var(--ctl-bg); color: var(--turn); }
    \\  .c-apply .msg[data-ok] { color: var(--text); }
    \\}
    \\
;

pub fn gallery(g: *Gallery) void {
    const h = g.h;
    const states = .{
        .{ "empty", Apply{} },
        .{ "sending", Apply{ .sending = true } },
        .{ "sent", Apply{ .say = .sent } },
        .{ "refused", blk: {
            var p: Apply = .{ .say = .server };
            p.server.set("Contact: an email address or a Discord username.");
            break :blk p;
        } },
        .{ "busy", Apply{ .say = .busy } },
        .{ "down", Apply{ .say = .down } },
    };
    inline for (states) |s| {
        const p = h.mem.create(Apply) catch {
            h.oom = true;
            return;
        };
        p.* = s[1];
        g.add(s[0], p.view(h));
    }
}

const testing = std.testing;

test "submit once, then the answer; a sent form stays sent" {
    var p: Apply = .{};
    var ev: tree.Event = .{ .kind = .submit };
    p.update(.submit, &ev);
    try testing.expect(p.want and p.sending and ev.handled);
    p.want = false;
    p.update(.submit, &ev);
    try testing.expect(!p.want);
    p.answered(400, "{\"error\":\"Riot ID: Name#TAG\"}");
    try testing.expectEqual(.server, p.say);
    try testing.expectEqualStrings("Riot ID: Name#TAG", p.server.slice());
    p.update(.submit, &ev);
    p.answered(429, "");
    try testing.expectEqual(.busy, p.say);
    p.update(.submit, &ev);
    p.answered(0, "");
    try testing.expectEqual(.down, p.say);
    p.update(.submit, &ev);
    p.answered(200, "{\"ok\":true}");
    try testing.expectEqual(.sent, p.say);
    p.want = false;
    p.update(.submit, &ev);
    try testing.expect(!p.want);
}

test enumOf {
    try testing.expectEqual(ad.Role.mid, enumOf(ad.Role, "mid"));
    try testing.expectEqual(ad.Rank.none, enumOf(ad.Rank, ""));
    try testing.expectEqual(ad.Rank.none, enumOf(ad.Rank, "wood"));
}
