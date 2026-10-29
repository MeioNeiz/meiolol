//! /auth/ (src/api/accounts.zig) in ui.data: a path ending .bin takes and answers these
//! instead of JSON; errors stay JSON. Fields as the JSON's, so one struct serves both
pub const Me = struct { username: []const u8, role: []const u8, can: []const []const u8 };

pub const Account = struct {
    username: []const u8,
    role: []const u8,
    created: i64,
    last_seen: ?i64,
    disabled: bool,
    /// The signed-in role may manage it
    manage: bool,
};

/// `roles`: those the signed-in role may give, lowest first
pub const Accounts = struct { accounts: []const Account, roles: []const []const u8 };

/// POST invite
pub const NewInvite = struct { role: []const u8 };

/// POST role, disable and reset: the fields each uses
pub const Manage = struct { username: []const u8, role: []const u8 = "", disabled: bool = false };

/// invite's and reset's answer: the token for {origin}/join#TOKEN
pub const Invite = struct { invite: []const u8 };
