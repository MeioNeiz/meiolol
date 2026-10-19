//! Perl's semantics where the lab tools' output depends on them: they replaced Perl
//! scripts (deploy/lab-place.pl, lab-sweep.pl) and print byte for byte what those did.
//! Floats go through the C library as Perl's do: printf formatting (Perl's sprintf hands
//! %f/%g to it), pow, log and exp from libm; rand is Perl's own drand48.

const std = @import("std");
const builtin = @import("builtin");

extern "c" fn snprintf(buf: [*]u8, size: usize, format: [*:0]const u8, ...) c_int;
extern "c" fn pow(x: f64, y: f64) f64;
extern "c" fn log(x: f64) f64;
extern "c" fn exp(x: f64) f64;

const MathFn = *const fn (f64) callconv(.c) f64;

/// The C library's log and exp. Linking binds `log` and `exp` to compiler_rt's copies
/// (pow it leaves to libm), which can round the last bit differently from the Mac's
/// libm, where Perl's come from; dlsym finds libm's, as compiler_rt's aren't exported
const libm = struct {
    var log_fn: ?MathFn = null;
    var exp_fn: ?MathFn = null;

    fn get(cache: *?MathFn, comptime name: [:0]const u8, fallback: MathFn) MathFn {
        if (cache.*) |f| return f;
        const f: MathFn = if (builtin.os.tag.isDarwin()) blk: {
            const default: *anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));
            break :blk @ptrCast(@alignCast(std.c.dlsym(default, name) orelse break :blk fallback));
        } else fallback;
        cache.* = f;
        return f;
    }
};

/// `x ** y`
pub fn power(x: f64, y: f64) f64 {
    return pow(x, y);
}

pub fn ln(x: f64) f64 {
    return libm.get(&libm.log_fn, "log", &log)(x);
}

pub fn e(x: f64) f64 {
    return libm.get(&libm.exp_fn, "exp", &exp)(x);
}

/// sprintf(spec, v) for one float conversion (%.2f, %+.0f, %.4g, %.15g ...). Perl
/// writes Inf and NaN itself: "Inf", "-Inf", "+Inf" with %+, "NaN"
pub fn fmtFloat(buf: []u8, comptime spec: [:0]const u8, v: f64) []const u8 {
    if (std.math.isNan(v)) return "NaN";
    if (std.math.isInf(v)) return if (v < 0) "-Inf" else if (comptime std.mem.indexOfScalar(u8, spec, '+') != null) "+Inf" else "Inf";
    const n = snprintf(buf.ptr, buf.len, spec, v);
    return buf[0..@min(@as(usize, @intCast(n)), buf.len - 1)];
}

/// sprintf('%d', v): truncated toward zero
pub fn fmtInt(buf: []u8, v: f64) []const u8 {
    if (std.math.isNan(v)) return "NaN";
    if (std.math.isInf(v)) return if (v < 0) "-Inf" else "Inf";
    const i: i64 = if (v >= 9.2e18) std.math.maxInt(i64) else if (v <= -9.2e18) std.math.minInt(i64) else @intFromFloat(v);
    return std.fmt.bufPrint(buf, "{d}", .{i}) catch unreachable;
}

/// int(v) as Perl prints it: the integer, or past 64 bits the float as %.15g
pub fn intStr(buf: []u8, v: f64) []const u8 {
    const t = @trunc(v);
    if (@abs(t) < 9.2e18) return std.fmt.bufPrint(buf, "{d}", .{@as(i64, @intFromFloat(t))}) catch unreachable;
    return fmtFloat(buf, "%.15g", t);
}

/// A string used as a number: its longest numeric prefix after leading space, else 0
/// ("1.5x" 1.5, "1e" 1, "0x10" 0, "inf" and "nan" any case)
pub fn num(s: []const u8) f64 {
    var i: usize = 0;
    while (i < s.len and isSpace(s[i])) i += 1;
    const start = i;
    if (i < s.len and (s[i] == '+' or s[i] == '-')) i += 1;
    const rest = s[i..];
    const neg = i > start and s[start] == '-';
    if (startsWithIgnoreCase(rest, "inf")) return if (neg) -std.math.inf(f64) else std.math.inf(f64);
    if (startsWithIgnoreCase(rest, "nan")) return std.math.nan(f64);
    const digits_from = i;
    while (i < s.len and std.ascii.isDigit(s[i])) i += 1;
    var any = i > digits_from;
    if (i < s.len and s[i] == '.') {
        const frac_from = i + 1;
        var j = frac_from;
        while (j < s.len and std.ascii.isDigit(s[j])) j += 1;
        if (any or j > frac_from) {
            any = true;
            i = j;
        }
    }
    if (!any) return 0;
    if (i < s.len and (s[i] == 'e' or s[i] == 'E')) {
        var j = i + 1;
        if (j < s.len and (s[j] == '+' or s[j] == '-')) j += 1;
        const exp_from = j;
        while (j < s.len and std.ascii.isDigit(s[j])) j += 1;
        if (j > exp_from) i = j;
    }
    return std.fmt.parseFloat(f64, s[start..i]) catch 0;
}

fn startsWithIgnoreCase(s: []const u8, prefix: []const u8) bool {
    return s.len >= prefix.len and std.ascii.eqlIgnoreCase(s[0..prefix.len], prefix);
}

/// Perl's \s
pub fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r' or c == 0x0b or c == 0x0c;
}

/// A string in boolean context: false when empty or "0"
pub fn truthy(s: []const u8) bool {
    return s.len > 0 and !std.mem.eql(u8, s, "0");
}

/// `split /\s+/` less empty words, as `split ' '` gives them
pub fn words(arena: std.mem.Allocator, s: []const u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var i: usize = 0;
    while (i < s.len) {
        while (i < s.len and isSpace(s[i])) i += 1;
        const from = i;
        while (i < s.len and !isSpace(s[i])) i += 1;
        if (i > from) try out.append(arena, s[from..i]);
    }
    return out.items;
}

/// `split /SEP/, s`: trailing empty fields dropped, as Perl's split without a limit
pub fn split(arena: std.mem.Allocator, s: []const u8, sep: u8) ![]const []const u8 {
    var out: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, s, sep);
    while (it.next()) |f| try out.append(arena, f);
    var n = out.items.len;
    while (n > 0 and out.items[n - 1].len == 0) n -= 1;
    return out.items[0..n];
}

/// srand(seed) then rand(): Perl's drand48 (x0 = seed << 16 + 0x330E, 48-bit LCG)
pub const Rand = struct {
    x: u64,

    /// Perl takes the seed as a U32
    pub fn init(seed: u64) Rand {
        return .{ .x = (@as(u64, @as(u32, @truncate(seed))) << 16) + 0x330E };
    }

    /// In [0, 1)
    pub fn next(r: *Rand) f64 {
        r.x = (r.x *% 0x5DEECE66D +% 0xB) & 0xFFFF_FFFF_FFFF;
        return @as(f64, @floatFromInt(r.x)) * 0x1p-48;
    }
};

/// Median of `xs` (sorted in place), null when empty
pub fn median(xs: []f64) ?f64 {
    if (xs.len == 0) return null;
    sortAsc(xs);
    const n = xs.len;
    return if (n % 2 == 1) xs[(n - 1) / 2] else (xs[n / 2 - 1] + xs[n / 2]) / 2;
}

/// `sort { $a <=> $b }`: stable, NaN equal to everything
pub fn sortAsc(xs: []f64) void {
    std.mem.sort(f64, xs, {}, struct {
        fn lt(_: void, a: f64, b: f64) bool {
            return a < b;
        }
    }.lt);
}

/// Time::Local's timegm of "YYYY-MM-DDTHH:MM:SSZ", null for anything else
pub fn parseTs(s: []const u8) ?f64 {
    if (s.len != 20 or s[4] != '-' or s[7] != '-' or s[10] != 'T' or s[13] != ':' or s[16] != ':' or s[19] != 'Z') return null;
    const y = digitsAt(s, 0, 4) orelse return null;
    const mo = digitsAt(s, 5, 2) orelse return null;
    const d = digitsAt(s, 8, 2) orelse return null;
    const h = digitsAt(s, 11, 2) orelse return null;
    const mi = digitsAt(s, 14, 2) orelse return null;
    const sec = digitsAt(s, 17, 2) orelse return null;
    if (mo < 1 or mo > 12 or d < 1 or d > 31 or h > 23 or mi > 59 or sec > 59) return null;
    return @floatFromInt(daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + sec);
}

fn digitsAt(s: []const u8, at: usize, n: usize) ?i64 {
    return std.fmt.parseInt(i64, s[at .. at + n], 10) catch null;
}

/// Days since 1970-01-01 (Howard Hinnant's days_from_civil)
fn daysFromCivil(y0: i64, m: i64, d: i64) i64 {
    const y = if (m <= 2) y0 - 1 else y0;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const doy = @divFloor(153 * (if (m > 2) m - 3 else m + 9) + 2, 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

/// gmtime as "YYYY-MM-DDTHH:MM:SSZ"
pub fn iso(buf: []u8, t: f64) []const u8 {
    const secs: u64 = @intFromFloat(@max(t, 0));
    const es: std.time.epoch.EpochSeconds = .{ .secs = secs };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        yd.year,              md.month.numeric(),      md.day_index + 1,
        ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute(),
    }) catch unreachable;
}

const testing = std.testing;

test "fmtFloat matches Perl's sprintf, Inf and NaN too" {
    var buf: [64]u8 = undefined;
    // perl -e 'printf "%.4g|%.4g|%.4g|%.4g|%.4g", 1e-5, 0.0001, 123456, 0.00012345, 2.5e-5'
    try testing.expectEqualStrings("1e-05", fmtFloat(&buf, "%.4g", 1e-5));
    try testing.expectEqualStrings("0.0001", fmtFloat(&buf, "%.4g", 0.0001));
    try testing.expectEqualStrings("1.235e+05", fmtFloat(&buf, "%.4g", 123456));
    try testing.expectEqualStrings("0.0001234", fmtFloat(&buf, "%.4g", 0.00012345));
    // Ties go by the binary value: 0.125 is exact (half-even), 2.675 is below
    try testing.expectEqualStrings("0.12", fmtFloat(&buf, "%.2f", 0.125));
    try testing.expectEqualStrings("2.67", fmtFloat(&buf, "%.2f", 2.675));
    try testing.expectEqualStrings("2", fmtFloat(&buf, "%.0f", 2.5));
    try testing.expectEqualStrings("+0", fmtFloat(&buf, "%+.0f", 0.4));
    try testing.expectEqualStrings("-0", fmtFloat(&buf, "%+.0f", -0.4));
    try testing.expectEqualStrings("0.333333333333333", fmtFloat(&buf, "%.15g", 1.0 / 3.0));
    try testing.expectEqualStrings("NaN", fmtFloat(&buf, "%+.2f", std.math.nan(f64)));
    try testing.expectEqualStrings("+Inf", fmtFloat(&buf, "%+.2f", std.math.inf(f64)));
    try testing.expectEqualStrings("Inf", fmtFloat(&buf, "%.0f", std.math.inf(f64)));
    try testing.expectEqualStrings("-Inf", fmtFloat(&buf, "%.4g", -std.math.inf(f64)));
}

test "fmtInt truncates toward zero" {
    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("3", fmtInt(&buf, 3.99));
    try testing.expectEqualStrings("-2", fmtInt(&buf, -2.5));
    try testing.expectEqualStrings("0", fmtInt(&buf, -0.3));
    try testing.expectEqualStrings("NaN", fmtInt(&buf, std.math.nan(f64)));
}

test "num reads a string as Perl does" {
    try testing.expectEqual(@as(f64, 1.5), num("1.5x"));
    try testing.expectEqual(@as(f64, 2), num(" 2"));
    try testing.expectEqual(@as(f64, 1), num("1e"));
    try testing.expectEqual(@as(f64, 0), num("0x10"));
    try testing.expectEqual(@as(f64, 0.5), num(".5"));
    try testing.expectEqual(@as(f64, 5), num("5."));
    try testing.expectEqual(@as(f64, 0), num("-"));
    try testing.expectEqual(@as(f64, 0), num("+.e3"));
    try testing.expectEqual(@as(f64, 0), num(""));
    try testing.expectEqual(@as(f64, 1e-4), num("1e-4"));
    try testing.expectEqual(-std.math.inf(f64), num("-Infinity"));
    try testing.expect(std.math.isNan(num("nan")));
}

test "Rand is Perl's srand and rand" {
    // perl -e 'srand(1); print rand()' 0.0416303447718782; srand(0) 0.17082803610629
    var r = Rand.init(1);
    try testing.expectEqual(@as(f64, 0.041630344771878214), r.next());
    r = Rand.init(0);
    try testing.expectEqual(@as(f64, 0.17082803610628972), r.next());
    // A U32 seed: 2^32 + 1 is 1
    r = Rand.init((1 << 32) + 1);
    try testing.expectEqual(@as(f64, 0.041630344771878214), r.next());
}

test "ln and e are libm's: Perl's log and exp" {
    // perl -e 'printf "%.17g %.17g", log(0.0001), exp(-9.2103403719761818)'
    try testing.expectEqual(@as(f64, -9.2103403719761818), ln(0.0001));
    try testing.expectEqual(@as(f64, 0.00010000000000000009), e(-9.2103403719761818));
}

test "split drops trailing empty fields only" {
    const a = testing.allocator;
    var arena: std.heap.ArenaAllocator = .init(a);
    defer arena.deinit();
    const f = try split(arena.allocator(), ",a,,b,,", ',');
    try testing.expectEqual(@as(usize, 4), f.len);
    try testing.expectEqualStrings("", f[0]);
    try testing.expectEqualStrings("b", f[3]);
    try testing.expectEqual(@as(usize, 0), (try split(arena.allocator(), ",,", ',')).len);
}

test "median and timestamps" {
    var odd = [_]f64{ 3, 1, 2 };
    try testing.expectEqual(@as(?f64, 2), median(&odd));
    var even = [_]f64{ 4, 1, 3, 2 };
    try testing.expectEqual(@as(?f64, 2.5), median(&even));
    try testing.expectEqual(@as(?f64, null), median(&.{}));
    try testing.expectEqual(@as(?f64, 1760910000), parseTs("2025-10-19T21:40:00Z"));
    try testing.expectEqual(@as(?f64, null), parseTs("2025-10-19 21:40:00"));
    try testing.expectEqual(@as(?f64, 951782400), parseTs("2000-02-29T00:00:00Z"));
    var buf: [32]u8 = undefined;
    try testing.expectEqualStrings("2000-02-29T00:00:00Z", iso(&buf, 951782400));
}
