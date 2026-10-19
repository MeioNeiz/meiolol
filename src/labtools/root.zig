//! The lab runners' decisions (deploy/lab-run.sh, deploy/lab-sweep.sh): where a run goes
//! and how long it takes, and sampling and judging sweeps. `meiolol lab-place` and
//! `meiolol lab-sweep`. std only: deploy/lib.sh builds the backend from HEAD when this
//! directory changes, keyed by its tree, so nothing outside it may change their output.

pub const place = @import("place.zig");
pub const sweep = @import("sweep.zig");
pub const perl = @import("perl.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
