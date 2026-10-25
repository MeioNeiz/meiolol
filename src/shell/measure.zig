//! `--measure`: a scripted run of about a minute and a half that writes measure.json and
//! a PNG per page beside the exe, then closes (deploy/shell.sh measure runs it on the
//! gpu-box). Per page: time to first paint, idle CPU and memory of the whole process tree
//! (labelled by WebView2's own process kinds); on the first, CPU while --demo's champ
//! select is pushed once a second and the push-to-drawn delay; then the memory knobs,
//! a topmost panel (the in-game companion's shape) and the main view suspended. League's
//! processes, when running, are sampled over the same windows, so a run says whether it
//! was beside League.

const std = @import("std");
const win = @import("win.zig");
const c = win.c;
const com = win.com;
const W = win.W;
const files = @import("files.zig");

pub const watchdog_ms = 240_000;

var served_n: u32 = 0;
var served_bytes: usize = 0;

pub fn served(bytes: usize) void {
    served_n += 1;
    served_bytes += bytes;
}

// ---------------------------------------------------------------- the channel's delay

var push_at: [64]f64 = undefined;
var ack_ms: [64]f64 = undefined;
var acks: u32 = 0;

pub fn pushed(seq: u32) void {
    push_at[seq % 64] = win.nowMs();
}

pub fn drawn(seq: u32) void {
    if (acks < ack_ms.len) {
        ack_ms[acks] = win.nowMs() - push_at[seq % 64];
        acks += 1;
    }
}

// ---------------------------------------------------------------- sampling processes

const max_procs = 64;
const Proc = struct { pid: u32, ppid: u32, name: [32]u8 = @splat(0), kind: []const u8 = "", cpu: u64 = 0, private: u64 = 0, ws: u64 = 0 };
const kinds = [_][]const u8{ "browser", "renderer", "utility", "sandbox_helper", "gpu", "ppapi_plugin", "ppapi_broker" };
const Sample = struct { at: f64 = 0, n: usize = 0, p: [max_procs]Proc = undefined };

fn nameOf(p: *const Proc) []const u8 {
    return p.name[0 .. std.mem.indexOfScalar(u8, &p.name, 0) orelse p.name.len];
}

fn isLeague(name: []const u8) bool {
    const prefixes = [_][]const u8{ "LeagueClient", "League of Legends", "RiotClient" };
    for (prefixes) |p| if (std.ascii.startsWithIgnoreCase(name, p)) return true;
    return false;
}

/// WebView2's own label for each of its processes
fn labelKinds(s: *Sample) void {
    s.p[0].kind = "host";
    if (win.env == null) return;
    const e8 = win.tryQi(win.env, "d6eb91dd-c3d2-45e5-bd29-6dc2bc4de9cf", c.ICoreWebView2Environment8) orelse return;
    defer _ = com(e8, "Release", .{});
    var coll: [*c]c.ICoreWebView2ProcessInfoCollection = null;
    if (com(e8, "GetProcessInfos", .{&coll}) < 0) return;
    defer _ = com(coll, "Release", .{});
    var n: c.UINT32 = 0;
    _ = com(coll, "get_Count", .{&n});
    for (0..n) |i| {
        var info: [*c]c.ICoreWebView2ProcessInfo = null;
        if (com(coll, "GetValueAtIndex", .{ @as(c.UINT32, @intCast(i)), &info }) < 0) continue;
        defer _ = com(info, "Release", .{});
        var pid: c.INT32 = 0;
        var kind: c.COREWEBVIEW2_PROCESS_KIND = 0;
        _ = com(info, "get_ProcessId", .{&pid});
        _ = com(info, "get_Kind", .{&kind});
        for (s.p[0..s.n]) |*p| if (p.pid == @as(u32, @bitCast(pid))) {
            p.kind = if (kind >= 0 and kind < kinds.len) kinds[@intCast(kind)] else "other";
        };
    }
}

/// This process and every descendant (WebView2's browser, renderer, GPU and utility
/// processes) into `ours`, League's and Riot's into `league`, with CPU time and memory
fn sample(ours: *Sample, league: *Sample) void {
    const now = win.nowMs();
    ours.* = .{ .at = now };
    league.* = .{ .at = now };
    var all: [1024]Proc = undefined;
    var n_all: usize = 0;
    const snap = c.CreateToolhelp32Snapshot(c.TH32CS_SNAPPROCESS, 0);
    defer _ = c.CloseHandle(snap);
    var e: c.PROCESSENTRY32W = undefined;
    e.dwSize = @sizeOf(c.PROCESSENTRY32W);
    var more = c.Process32FirstW(snap, &e) != 0;
    while (more and n_all < all.len) : (more = c.Process32NextW(snap, &e) != 0) {
        all[n_all] = .{ .pid = e.th32ProcessID, .ppid = e.th32ParentProcessID };
        const len = std.mem.indexOfScalar(u16, &e.szExeFile, 0) orelse e.szExeFile.len;
        _ = std.unicode.utf16LeToUtf8(all[n_all].name[0..31], e.szExeFile[0..@min(len, 31)]) catch 0;
        if (isLeague(nameOf(&all[n_all])) and league.n < max_procs) {
            league.p[league.n] = all[n_all];
            league.n += 1;
        }
        n_all += 1;
    }
    ours.p[0] = .{ .pid = c.GetCurrentProcessId(), .ppid = 0 };
    @memcpy(ours.p[0].name[0..17], "meiolol-shell.exe");
    ours.n = 1;
    var grew = true;
    while (grew) {
        grew = false;
        for (all[0..n_all]) |p| {
            const known = for (ours.p[0..ours.n]) |q| (if (q.pid == p.pid) break true) else false;
            if (known) continue;
            const child = for (ours.p[0..ours.n]) |q| (if (q.pid == p.ppid) break true) else false;
            if (child and ours.n < max_procs) {
                ours.p[ours.n] = p;
                ours.n += 1;
                grew = true;
            }
        }
    }
    labelKinds(ours);
    for ([_]*Sample{ ours, league }) |s| for (s.p[0..s.n]) |*p| {
        const h = c.OpenProcess(c.PROCESS_QUERY_LIMITED_INFORMATION, 0, p.pid) orelse continue;
        defer _ = c.CloseHandle(h);
        var cr: c.FILETIME = undefined;
        var ex: c.FILETIME = undefined;
        var k: c.FILETIME = undefined;
        var u: c.FILETIME = undefined;
        if (c.GetProcessTimes(h, &cr, &ex, &k, &u) != 0) p.cpu = win.ft64(k) + win.ft64(u);
        var mc: c.PROCESS_MEMORY_COUNTERS_EX = undefined;
        mc.cb = @sizeOf(c.PROCESS_MEMORY_COUNTERS_EX);
        if (c.K32GetProcessMemoryInfo(h, @ptrCast(&mc), mc.cb) != 0) {
            p.private = mc.PrivateUsage;
            p.ws = mc.WorkingSetSize;
        }
    };
}

/// % of one core used between two samples by each process of b (0 before for new ones)
fn cpuPct(a: *const Sample, b: *const Sample, q: Proc) f64 {
    const before = for (a.p[0..a.n]) |p| (if (p.pid == q.pid) break p.cpu) else 0;
    return @as(f64, @floatFromInt(q.cpu -| before)) / 10_000.0 / (b.at - a.at) * 100.0;
}

fn totalCpu(a: *const Sample, b: *const Sample) f64 {
    var t: f64 = 0;
    for (b.p[0..b.n]) |q| t += cpuPct(a, b, q);
    return t;
}

// ---------------------------------------------------------------- measure.json

var json_buf: [65536]u8 = undefined;
var jw: std.Io.Writer = .fixed(&json_buf);
var first_field = true;

fn field(name: []const u8) void {
    jw.writeAll(if (first_field) "{\n" else ",\n") catch {};
    first_field = false;
    jw.print("  \"{s}\": ", .{name}) catch {};
}

fn mb(b: u64) f64 {
    return @as(f64, @floatFromInt(b)) / (1024.0 * 1024.0);
}

/// "total" plus each process's share, by WebView2's kind
fn cpuJson(name: []const u8, a: *const Sample, b: *const Sample) void {
    field(name);
    jw.print("{{\"total\": {d:.2}", .{totalCpu(a, b)}) catch {};
    for (b.p[0..b.n]) |q|
        jw.print(", \"{s}_{d}\": {d:.2}", .{ if (q.kind.len > 0) q.kind else "other", q.pid, cpuPct(a, b, q) }) catch {};
    jw.writeAll("}") catch {};
}

fn memJson(name: []const u8, s: *const Sample) void {
    var priv: u64 = 0;
    var ws: u64 = 0;
    for (s.p[0..s.n]) |p| {
        priv += p.private;
        ws += p.ws;
    }
    field(name);
    jw.print("{{\"processes\": {d}, \"private_mb\": {d:.1}, \"working_set_mb\": {d:.1}, \"each\": [", .{ s.n, mb(priv), mb(ws) }) catch {};
    for (s.p[0..s.n], 0..) |p, i| {
        jw.print("{s}{{\"pid\": {d}, \"exe\": \"{s}\", \"kind\": \"{s}\", \"private_mb\": {d:.1}, \"working_set_mb\": {d:.1}}}", .{
            if (i == 0) "" else ", ", p.pid, nameOf(&p), p.kind, mb(p.private), mb(p.ws),
        }) catch {};
    }
    jw.writeAll("]}") catch {};
}

/// League's processes over the same window: how many, their memory and CPU
fn leagueJson(name: []const u8, a: *const Sample, b: *const Sample) void {
    field(name);
    var priv: u64 = 0;
    for (b.p[0..b.n]) |p| priv += p.private;
    jw.print("{{\"processes\": {d}, \"private_mb\": {d:.1}, \"cpu_pct_of_core\": {d:.2}, \"names\": [", .{ b.n, mb(priv), totalCpu(a, b) }) catch {};
    for (b.p[0..b.n], 0..) |p, i| jw.print("{s}\"{s}\"", .{ if (i == 0) "" else ", ", nameOf(&p) }) catch {};
    jw.writeAll("]}") catch {};
}

// ---------------------------------------------------------------- the script

var phase_sec: i32 = -1; // seconds since the current page painted; -1 waiting
var page_no: usize = 0;
var t_nav: f64 = 0;
var t_page_paint: f64 = 0;
var s_a: Sample = undefined;
var s_b: Sample = undefined;
var l_a: Sample = undefined;
var l_b: Sample = undefined;
var capture_stream: [*c]c.IStream = null;
var captures: u8 = 0;
var cap_handler: win.Handler = .init("697e05e9-3d8f-45fa-96f4-8ffe1ededaf5", &captureDone);
var suspend_handler: win.Handler = .init("00f206a7-9d17-4605-91f6-4e8e4de192e3", &suspendDone);
var panel_handler: win.Handler = .init("6c4819f3-c9b7-4260-8127-c9f5bde7f68c", &panelCreated);

pub fn start() void {
    field("options");
    jw.print("{{\"page\": \"{s}\", \"also\": {d}, \"scale\": {d:.2}, \"system_dpi\": {d}}}", .{
        win.opt.page, win.opt.n_also, win.opt.scale orelse 1.0, c.GetDpiForSystem(),
    }) catch {};
}

fn pageAt(i: usize) []const u8 {
    return if (i == 0) win.opt.page else win.opt.also[i - 1];
}

pub fn painted(page: []const u8, t: f64) void {
    if (phase_sec >= 0) return;
    phase_sec = 0;
    if (page_no == 0) {
        sample(&s_a, &l_a);
        field("startup_ms");
        jw.print("{{\"window_shown\": {d:.0}, \"environment\": {d:.0}, \"controller\": {d:.0}, \"first_paint\": {d:.0}}}", .{ win.t_window, win.t_env, win.t_ctrl, t }) catch {};
        memJson("mem_at_first_paint", &s_a);
    } else t_page_paint = t - t_nav;
    win.log("measure: {s} painted", .{page});
}

/// Once a second
pub fn tick() void {
    if (phase_sec < 0) return;
    phase_sec += 1;
    const pages = 1 + win.opt.n_also;
    if (page_no == 0) switch (phase_sec) {
        3 => sample(&s_a, &l_a),
        18 => {
            sample(&s_b, &l_b);
            cpuJson("idle_cpu_pct_of_core", &s_a, &s_b);
            memJson("mem_idle", &s_b);
            leagueJson("league_idle", &l_a, &l_b);
            s_a = s_b;
            l_a = l_b;
            win.setPushing(true);
        },
        33 => {
            sample(&s_b, &l_b);
            win.setPushing(false);
            cpuJson("push_1hz_cpu_pct_of_core", &s_a, &s_b);
            leagueJson("league_push", &l_a, &l_b);
            var sum: f64 = 0;
            var worst: f64 = 0;
            for (ack_ms[0..acks]) |x| {
                sum += x;
                worst = @max(worst, x);
            }
            field("push_to_drawn_ms");
            jw.print("{{\"n\": {d}, \"mean\": {d:.2}, \"max\": {d:.2}}}", .{ acks, sum / @as(f64, @floatFromInt(@max(acks, 1))), worst }) catch {};
            capture(pageAt(0));
        },
        35 => nextPage(),
        else => {},
    } else if (page_no < pages) switch (phase_sec) {
        3 => sample(&s_a, &l_a),
        11 => {
            sample(&s_b, &l_b);
            const pg = pageAt(page_no);
            field(pg);
            jw.print("{{\"paint_after_navigate_ms\": {d:.0}, \"idle_cpu_pct_of_core\": {d:.2}, ", .{ t_page_paint, totalCpu(&s_a, &s_b) }) catch {};
            var priv: u64 = 0;
            for (s_b.p[0..s_b.n]) |p| priv += p.private;
            jw.print("\"private_mb\": {d:.1}, \"league_cpu_pct_of_core\": {d:.2}}}", .{ mb(priv), totalCpu(&l_a, &l_b) }) catch {};
            capture(pg);
        },
        12 => nextPage(),
        else => {},
    } else switch (phase_sec) {
        // After the pages: memory knobs, a second window, suspend
        1 => if (win.tryQi(win.webview, "6921f954-79b0-437f-a997-c85811897c68", c.ICoreWebView2_19)) |w19| {
            _ = com(w19, "put_MemoryUsageTargetLevel", .{c.COREWEBVIEW2_MEMORY_USAGE_TARGET_LEVEL_LOW});
            _ = com(w19, "Release", .{});
        },
        6 => {
            sample(&s_b, &l_b);
            memJson("mem_target_low", &s_b);
            openPanel();
        },
        12 => {
            sample(&s_b, &l_b);
            memJson("mem_with_topmost_panel", &s_b);
            _ = com(win.controller, "put_IsVisible", .{@as(c.BOOL, 0)});
            if (win.tryQi(win.webview, "a0d6df20-3b92-416d-aa0c-437a9c727857", c.ICoreWebView2_3)) |w3| {
                _ = com(w3, "TrySuspend", .{suspend_handler.as(c.ICoreWebView2TrySuspendCompletedHandler)});
                _ = com(w3, "Release", .{});
            }
            s_a = s_b;
        },
        18 => {
            sample(&s_b, &l_b);
            memJson("mem_main_suspended_panel_open", &s_b);
            cpuJson("cpu_main_suspended_panel_idle", &s_a, &s_b);
            finish();
        },
        else => {},
    }
}

fn nextPage() void {
    page_no += 1;
    phase_sec = if (page_no < 1 + win.opt.n_also) -1 else 0;
    if (phase_sec < 0) {
        t_nav = win.nowMs();
        win.navigateTo(pageAt(page_no));
    }
}

/// The page as the webview drew it, to <page>.png beside the exe
fn capture(page: []const u8) void {
    var name: [128]u8 = undefined;
    const base = if (std.mem.endsWith(u8, page, ".html")) page[0 .. page.len - 5] else page;
    const n = std.mem.print(&name, "{s}.png", .{base}) catch return;
    std.mem.replaceScalar(u8, n, '/', '-');
    var path: [400]u16 = undefined;
    if (c.SHCreateStreamOnFileEx(win.besideExe(&path, n), c.STGM_CREATE | c.STGM_WRITE, c.FILE_ATTRIBUTE_NORMAL, 1, null, &capture_stream) < 0) return;
    win.check(com(win.webview, "CapturePreview", .{ c.COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG, capture_stream, cap_handler.as(c.ICoreWebView2CapturePreviewCompletedHandler) }), "CapturePreview") catch {};
}

fn captureDone(_: *win.Handler, hr: c.HRESULT) callconv(.c) c.HRESULT {
    win.log("capture done 0x{x}", .{@as(u32, @bitCast(hr))});
    if (capture_stream != null) _ = com(capture_stream, "Release", .{});
    capture_stream = null;
    captures += 1;
    return 0;
}

fn suspendDone(_: *win.Handler, hr: c.HRESULT, ok: c.BOOL) callconv(.c) c.HRESULT {
    win.log("TrySuspend 0x{x} {d}", .{ @as(u32, @bitCast(hr)), ok });
    return 0;
}

// The in-game companion's shape: a small always-on-top window that never takes focus,
// a second controller on the same environment (same browser process)
var panel_hwnd: c.HWND = null;
var panel_ctrl: [*c]c.ICoreWebView2Controller = null;
var t_panel_open: f64 = 0;

fn openPanel() void {
    const class = W("meiolol-panel");
    const inst = c.GetModuleHandleW(null);
    const wc: c.WNDCLASSEXW = .{
        .cbSize = @sizeOf(c.WNDCLASSEXW),
        .style = 0,
        .lpfnWndProc = &panelProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = inst,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = c.CreateSolidBrush(0x000a0908),
        .lpszMenuName = null,
        .lpszClassName = class,
        .hIconSm = null,
    };
    _ = c.RegisterClassExW(&wc);
    const scale = @as(f64, @floatFromInt(c.GetDpiForSystem())) / 96.0;
    const w: c_int = @intFromFloat(380 * scale);
    const h: c_int = @intFromFloat(140 * scale);
    const x = c.GetSystemMetrics(c.SM_CXSCREEN) - w - 40;
    panel_hwnd = c.CreateWindowExW(c.WS_EX_TOPMOST | c.WS_EX_TOOLWINDOW | c.WS_EX_NOACTIVATE, class, W("meiolol panel"), c.WS_POPUP | c.WS_BORDER, x, 80, w, h, null, null, inst, null);
    _ = c.ShowWindow(panel_hwnd, c.SW_SHOWNOACTIVATE);
    t_panel_open = win.nowMs();
    _ = com(win.env, "CreateCoreWebView2Controller", .{ panel_hwnd, panel_handler.as(c.ICoreWebView2CreateCoreWebView2ControllerCompletedHandler) });
}

fn panelCreated(_: *win.Handler, hr: c.HRESULT, ctrl: [*c]c.ICoreWebView2Controller) callconv(.c) c.HRESULT {
    win.check(hr, "panel controller") catch return 0;
    panel_ctrl = ctrl;
    _ = com(panel_ctrl, "AddRef", .{});
    field("panel_controller_ms");
    jw.print("{d:.0}", .{win.nowMs() - t_panel_open}) catch {};
    var r: c.RECT = undefined;
    _ = c.GetClientRect(panel_hwnd, &r);
    _ = com(panel_ctrl, "put_Bounds", .{r});
    var wv: [*c]c.ICoreWebView2 = null;
    if (com(panel_ctrl, "get_CoreWebView2", .{&wv}) < 0) return 0;
    defer _ = com(wv, "Release", .{});
    win.setUp(panel_ctrl, wv);
    _ = com(wv, "Navigate", .{W(win.origin ++ files.start_page)});
    return 0;
}

fn panelProc(h: c.HWND, msg: c.UINT, wp: c.WPARAM, lp: c.LPARAM) callconv(.c) c.LRESULT {
    if (msg == c.WM_MOUSEACTIVATE) return c.MA_NOACTIVATE;
    return c.DefWindowProcW(h, msg, wp, lp);
}

pub fn finish() void {
    field("served");
    jw.print("{{\"requests\": {d}, \"kb\": {d}}}", .{ served_n, served_bytes / 1024 }) catch {};
    field("captures");
    jw.print("{d}", .{captures}) catch {};
    jw.writeAll("\n}\n") catch {};
    var path: [400]u16 = undefined;
    _ = win.writeFile(win.besideExe(&path, "measure.json"), jw.buffered());
    win.log("measure.json written, closing", .{});
    if (panel_ctrl != null) _ = com(panel_ctrl, "Close", .{});
    if (panel_hwnd != null) _ = c.DestroyWindow(panel_hwnd);
    _ = c.DestroyWindow(win.hwnd);
}
