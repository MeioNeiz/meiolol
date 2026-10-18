//! Storage: SQLite (meiolol.db + raw.db) and raw document compression.

pub const sqlite = @import("sqlite.zig");
pub const schema = @import("schema.zig");
pub const raw = @import("raw.zig");
pub const rawpack = @import("rawpack.zig");
pub const draft = @import("draft.zig");

pub const Db = sqlite.Db;
pub const Blob = sqlite.Blob;
pub const Stmt = sqlite.Stmt;
pub const open = schema.open;

test {
    @import("std").testing.refAllDecls(@This());
}
