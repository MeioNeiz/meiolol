//! Who may do what (docs/plan/accounts.md "Roles"). Every route checks a Capability,
//! never a role name; each role has everything the ones below it have, so moving a
//! capability to another tier is one line in `lowest`

const std = @import("std");

/// In order: each holds every capability of the ones before it
pub const Role = enum(u8) {
    public,
    paid,
    private,
    admin,
    /// Jacob only
    owner,

    pub fn parse(name: []const u8) ?Role {
        return std.meta.stringToEnum(Role, name);
    }

    pub fn can(role: Role, cap: Capability) bool {
        return @backingInt(role) >= @backingInt(lowest.get(cap));
    }

    /// Accounts change only roles below their own (admins never touch admins or the
    /// owner); the owner is changed only with `meiolol account` over ssh
    pub fn canManage(actor: Role, target: Role) bool {
        if (target == .owner or @backingInt(target) >= @backingInt(actor)) return false;
        return actor.can(if (target == .admin) .manage_admins else .manage_accounts);
    }
};

pub const Capability = enum {
    view_paid,
    view_private,
    download_private_app,
    view_admin,
    /// Notes on the live site (api/notes.zig), and the marker cookie that loads the tool
    take_notes,
    manage_accounts,
    /// The admin page's controls: crawl, site build, eval, health check
    run_actions,
    manage_admins,
    manage_billing,
    delete_data,

    pub fn parse(name: []const u8) ?Capability {
        return std.meta.stringToEnum(Capability, name);
    }

    /// What a desktop app's token is good for (accounts.zig devices): the app's own
    /// downloads. Pages and controls need a browser login, so a token copied off a
    /// friend's PC opens nothing else
    pub fn forDevices(cap: Capability) bool {
        return cap == .download_private_app;
    }
};

/// The lowest role holding each capability. Jacob 23 Oct: admins see the admin pages and
/// everything private, not the controls
const lowest: std.EnumArray(Capability, Role) = .init(.{
    .view_paid = .paid,
    .view_private = .private,
    .download_private_app = .private,
    .view_admin = .admin,
    .take_notes = .admin,
    .manage_accounts = .admin,
    .run_actions = .owner,
    .manage_admins = .owner,
    .manage_billing = .owner,
    .delete_data = .owner,
});

test "admins get the private tier and the admin views, not the controls" {
    try std.testing.expect(Role.admin.can(.view_private));
    try std.testing.expect(Role.admin.can(.download_private_app));
    try std.testing.expect(Role.admin.can(.view_admin));
    try std.testing.expect(!Role.admin.can(.run_actions));
    try std.testing.expect(Role.owner.can(.run_actions));
    try std.testing.expect(!Role.private.can(.view_admin));
    try std.testing.expect(!Role.paid.can(.view_private));
    for (std.enums.values(Capability)) |cap| {
        try std.testing.expect(Role.owner.can(cap));
        try std.testing.expect(!Role.public.can(cap));
    }
}

test "canManage: only roles below one's own" {
    try std.testing.expect(Role.admin.canManage(.private));
    try std.testing.expect(Role.admin.canManage(.paid));
    try std.testing.expect(!Role.admin.canManage(.admin));
    try std.testing.expect(!Role.admin.canManage(.owner));
    try std.testing.expect(Role.owner.canManage(.admin));
    try std.testing.expect(!Role.owner.canManage(.owner));
    try std.testing.expect(!Role.private.canManage(.paid));
}
