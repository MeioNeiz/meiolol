//! The crawler's proxy for the Your games service (docs/your-games.md, Rate limits):
//! GET /riot/<route><path>, the endpoint's rate limit name in x-meiolol-method, answered
//! as Riot would. Calls go through the crawler's limiter for that route at priority, so
//! a lookup takes the next free slot and the crawler has the whole key the rest of the
//! time. Listens on the box's private address; who may connect is the network's job.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Client = @import("client.zig").Client;
const Limiters = @import("ratelimit.zig").Limiters;
const Fake = @import("fake.zig").Fake;
const httpd = @import("../httpd.zig");

const log = std.log.scoped(.proxy);

pub const Proxy = struct {
    gpa: Allocator,
    io: Io,
    key: []const u8,
    limiters: *Limiters,
    fake: ?*const Fake = null,

    /// "10.0.0.3:8092"
    pub fn listen(p: *Proxy, address: []const u8) !Io.net.Server {
        const colon = std.mem.lastIndexOfScalar(u8, address, ':') orelse return error.BadAddress;
        const port = std.fmt.parseInt(u16, address[colon + 1 ..], 10) catch return error.BadAddress;
        const ip = try Io.net.IpAddress.parse(address[0..colon], port);
        const server = try ip.listen(p.io, .{ .reuse_address = true });
        log.info("Your games proxy on {s}", .{address});
        return server;
    }

    /// Until cancelled
    pub fn serve(p: *Proxy, server: *Io.net.Server) void {
        httpd.accept(.proxy, p.io, server, p, connection);
    }

    const Clients = [@typeInfo(@FieldType(Limiters, "all")).array.len]?Client;

    /// Per connection: a client per route, made on first use
    const Conn = struct { p: *Proxy, clients: Clients = @splat(null) };

    fn connection(p: *Proxy, stream: Io.net.Stream) void {
        var conn: Conn = .{ .p = p };
        defer for (&conn.clients) |*c| if (c.*) |*client| client.deinit();
        // The path may hold a Riot ID or PUUID: error names only
        httpd.requests(.proxy, p.io, stream, &conn, handle, .error_only);
    }

    fn handle(conn: *Conn, request: *std.http.Server.Request) !void {
        const p = conn.p;
        const clients = &conn.clients;
        const prefix = "/riot/";
        const target = request.head.target;
        if (request.head.method != .GET or !std.mem.startsWith(u8, target, prefix)) {
            return request.respond("", .{ .status = .not_found });
        }
        const rest = target[prefix.len..];
        const slash = std.mem.indexOfScalar(u8, rest, '/') orelse return request.respond("", .{ .status = .bad_request });
        const route = rest[0..slash];
        const i = Limiters.index(route) orelse return request.respond("", .{ .status = .bad_request });
        var method: ?[]const u8 = null;
        var it = request.iterateHeaders();
        while (it.next()) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, Client.method_header)) method = h.value;
        }
        if (method == null) return request.respond("", .{ .status = .bad_request });

        if (clients[i] == null) {
            var c: Client = .init(p.gpa, p.io, p.key, &p.limiters.all[i]);
            c.priority = true;
            c.fake = p.fake;
            clients[i] = c;
        }
        const got = clients[i].?.get(route, rest[slash..], method.?) catch |err| {
            const status: std.http.Status = switch (err) {
                error.OutOfMemory, error.Canceled => return err,
                error.KeyRejected => .unauthorized,
                error.RateLimited, error.GaveUp => .service_unavailable,
                else => .bad_gateway,
            };
            return request.respond("", .{ .status = status });
        };
        const body = got orelse return request.respond("", .{ .status = .not_found });
        defer p.gpa.free(body);
        try request.respond(body, .{});
    }
};

test "proxy answers as Riot would, through the route's limiter" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    var limiters = try Limiters.init(gpa, io);
    defer limiters.deinit();
    var fake = try Fake.init(gpa, io, 0);
    defer fake.deinit(gpa);
    var p: Proxy = .{ .gpa = gpa, .io = io, .key = "", .limiters = &limiters, .fake = &fake };
    var server = try p.listen("127.0.0.1:0");
    defer server.deinit(io);
    var serving = try io.concurrent(Proxy.serve, .{ &p, &server });
    defer serving.cancel(io);

    var url_buf: [64]u8 = undefined;
    const base = try std.mem.print(&url_buf, "http://127.0.0.1:{d}", .{server.socket.address.getPort()});
    var c: Client = .initProxy(gpa, io, base);
    defer c.deinit();
    const body = (try c.get("europe", "/lol/match/v5/matches/EUW1_1", "match")).?;
    defer gpa.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "EUW1_1") != null);
    try std.testing.expectEqual(null, try c.get("europe", "/nothing", "x"));
}
