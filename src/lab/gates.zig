//! Gates inside lab programs: cheap checks on a fit that print `GATE ok|FAIL NAME ...` to
//! stderr (the run's log). deploy/lab-gates.sh copies the FAIL lines into the run's
//! `gates`, which `lab-run.sh wait` shows. They warn, never stop a run

const std = @import("std");
const builtin = @import("builtin");

/// Mean log loss of predicting each game's base rate m: the entropy of m. 0 when one
/// class only
pub fn baseLoss(m: f64) f64 {
    if (m <= 0 or m >= 1) return 0;
    return -(m * @log(m) + (1 - m) * @log(1 - m));
}

/// Most a fresh net's held-out loss may sit from its reference's (the base rate's, or the
/// fixed offset's for a residual net). health.zig holds nets to this on synthetic games
pub const init_limit = 0.01;

var init_ok: std.atomic.Value(bool) = .init(false);

/// A fresh net, before any step: its held-out loss near the reference's. Far above, it
/// starts saturated (init scale, unscaled inputs), and what it ends at means little.
/// FAIL on every fit that misses; ok once a process
pub fn initLoss(name: []const u8, init: f64, ref: f64) void {
    if (builtin.is_test) return;
    const d = init - ref;
    if (!(@abs(d) <= init_limit)) {
        std.debug.print("GATE FAIL {s} init loss {d:.5}, reference {d:.5} ({d:.5} off, limit {d})\n", .{ name, init, ref, d, init_limit });
    } else if (!init_ok.swap(true, .monotonic)) {
        std.debug.print("GATE ok {s} init loss {d:.5}, reference {d:.5} ({d:.5} off)\n", .{ name, init, ref, d });
    }
}

test baseLoss {
    try std.testing.expectApproxEqAbs(@log(2.0), baseLoss(0.5), 1e-12);
    try std.testing.expectEqual(0, baseLoss(1));
}
