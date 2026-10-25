//! ui-stats.wasm: the islands of the stats pages (champions list first). zjb's generated
//! loader (ui-stats.js, `<script src data-wasm data-main>`) calls `main`
const std = @import("std");
const zjb = @import("zjb");
const ui = @import("ui");
const dom = @import("dom.zig");

pub const panic = zjb.panic;

// The whole runtime analysed against zjb's Dom until the first island lands
const Probe = struct {
    n: u32 = 0,
    pub const Msg = union(enum) { add };
    pub const Url = struct { n: u32 = 0 };
    pub fn toUrl(p: *const Probe) Url {
        return .{ .n = p.n };
    }
    pub fn fromUrl(p: *Probe, u: Url) void {
        p.n = u.n;
    }
    pub fn update(p: *Probe, _: Msg, _: *ui.tree.Event) void {
        p.n += 1;
    }
    pub fn view(p: *Probe, h: *ui.H) ui.N {
        return h.button(.{ .on_click = h.on(p, .add) }, .{p.n});
    }
};

fn probe() void {
    var a: Probe = .{};
    var b: Probe = .{};
    _ = dom.rt.add(Probe, &a, &b, "[data-island]") catch {};
    _ = dom.rt.event(0, .{ .kind = .click, .target = 1 });
    dom.rt.popstate();
    dom.fetch("x", 0, undefined);
}

comptime {
    _ = &probe;
}

export fn main() void {
    dom.start();
}
