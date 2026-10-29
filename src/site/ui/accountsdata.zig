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

/// POST login; login, join, signup and password answer a Me
pub const Login = struct { username: []const u8, password: []const u8 };

/// POST join: `username` is ignored by a reset invite
pub const Join = struct { invite: []const u8, username: []const u8 = "", password: []const u8 };

/// POST signup: `password` is the link's shared one
pub const Signup = struct { link: []const u8, email: []const u8, password: []const u8 };

/// POST password
pub const Password = struct { password: []const u8, new: []const u8 };

/// A desktop app signed in to the account; times in unix seconds
pub const Device = struct { id: i64, name: []const u8, created: i64, last_used: i64 };

/// GET devices: live ones, oldest first
pub const Devices = struct { devices: []const Device };

/// POST revoke
pub const Revoke = struct { id: i64 };
