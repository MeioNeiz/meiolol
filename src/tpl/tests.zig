//! The contract, through the public API only. Templates that must not compile are in
//! compile_errors.zig.

const std = @import("std");
const tpl = @import("root.zig");
const Writer = std.Io.Writer;

fn expectRender(expected: []const u8, comptime src: []const u8, args: anytype) !void {
    var buf: [1024]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try tpl.render(&w, src, args);
    try std.testing.expectEqualStrings(expected, w.buffered());
}

/// Writes `s` through `format`, so it streams through the escaping writer
const Fmt = struct {
    s: []const u8,

    pub fn format(f: Fmt, w: *Writer) Writer.Error!void {
        try w.writeAll(f.s);
    }
};

/// A component writing `s` as markup
const Comp = struct {
    s: []const u8,

    pub fn render(c: Comp, w: *Writer) Writer.Error!void {
        try w.writeAll(c.s);
    }
};

// The module doc's example
fn link(w: *Writer, name: []const u8, page: []const u8, games: u32) !void {
    try tpl.render(w,
        \\<a href="{page}" title="{name}">{name}</a> <span>{games} games</span>
    , .{ .page = page, .name = name, .games = games });
}

test "the module doc's example" {
    var buf: [256]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try link(&w, "Nunu & Willump", "javascript:alert(1)", 3);
    try std.testing.expectEqualStrings(
        "<a href=\"about:invalid#tpl\" title=\"Nunu &amp; Willump\">Nunu &amp; Willump</a> <span>3 games</span>",
        w.buffered(),
    );
}

test "holes escape by type" {
    try expectRender(
        "<a href=\"x?a=1&amp;b=2\">Nunu &amp; Willump</a> 3 1.5 euw",
        "<a href=\"{href}\">{name}</a> {n} {f:.1} {region}",
        .{ .href = "x?a=1&b=2", .name = "Nunu & Willump", .n = 3, .f = @as(f64, 1.46), .region = enum { euw }.euw },
    );
}

test "text escapes all five characters, a field fills several holes" {
    try expectRender(
        "<p title=\"a&amp;&lt;&gt;&quot;&#39;b\">a&amp;&lt;&gt;&quot;&#39;b</p><p title='&#39;'>&#39;</p>",
        "<p title=\"{s}\">{s}</p><p title='{q}'>{q}</p>",
        .{ .s = "a&<>\"'b", .q = "'" },
    );
}

test "numbers take std.fmt options" {
    try expectRender(
        "<p>07 2.50 -3 1000</p>",
        "<p>{a:0>2} {b:.2} {c} {d}</p>",
        .{ .a = @as(u8, 7), .b = @as(f32, 2.5), .c = -3, .d = @as(f64, 1000) },
    );
}

test "optionals, void, slices and arrays" {
    const names = [_][]const u8{ "a<", "b" };
    try expectRender(
        "<p>x</p><p></p><p></p><p>a&lt;b</p><p>a&lt;b</p><p>123</p>",
        "<p>{some}</p><p>{none}</p><p>{nothing}</p><p>{slice}</p><p>{ptr}</p><p>{nums}</p>",
        .{
            .some = @as(?[]const u8, "x"),
            .none = @as(?[]const u8, null),
            .nothing = {},
            .slice = @as([]const []const u8, &names),
            .ptr = &names,
            .nums = [_]u32{ 1, 2, 3 },
        },
    );
}

test "raw, optional, flag and attr" {
    const thin = true;
    try expectRender(
        "<li class=\"thin\" data-games=\"5\"><b>hi</b></li><li></li>",
        "<li{thin}{games}>{body}{none}</li><li{off}></li>",
        .{
            .thin = tpl.flag(thin, "class=\"thin\""),
            .games = tpl.attr("data-games", 5),
            .body = tpl.trusted("<b>hi</b>"),
            .none = @as(?[]const u8, null),
            .off = tpl.flag(false, "hidden"),
        },
    );
}

test "when" {
    try expectRender(
        "<p>a</p><p></p>",
        "<p>{a}</p><p>{b}</p>",
        .{ .a = tpl.when(true, "a"), .b = tpl.when(false, tpl.t("<b>{x}</b>", .{ .x = 1 })) },
    );
}

test "plain braces, {{ and script holes" {
    try expectRender(
        "<script>try{f(3)}catch(e){}</script><p>{x}</p>",
        "<script>try{f({n})}catch(e){}</script><p>{{x}</p>",
        .{ .n = 3 },
    );
    try expectRender(
        "<script>var o = { a: 1, b: {} };</script><style>p{ color: red }</style><p>{ x } {1} {x y}</p>",
        "<script>var o = { a: 1, b: {} };</script><style>p{ color: red }</style><p>{ x } {1} {x y}</p>",
        .{},
    );
}

test "nested templates, calls and each" {
    const Item = struct { name: []const u8, games: u32 };
    const items = [_]Item{ .{ .name = "Ahri", .games = 2 }, .{ .name = "K'Sante", .games = 1 } };
    const row = struct {
        fn f(unit: []const u8, w: *Writer, it: Item) !void {
            try tpl.render(w, "<li>{name} {games} {unit}</li>", .{ .name = it.name, .games = it.games, .unit = unit });
        }
    }.f;
    const heading = struct {
        fn f(w: *Writer, text: []const u8, games: u32) !void {
            try tpl.render(w, "<h2>{text} <span>{games}</span></h2>", .{ .text = text, .games = games });
        }
    }.f;
    try expectRender(
        "<div><h2>Picks <span>3</span></h2><ul><li>Ahri 2 games</li><li>K&#39;Sante 1 games</li></ul><i>x</i></div>",
        "<div>{title}<ul>{rows}</ul>{note}</div>",
        .{
            .title = tpl.call(heading, .{ "Picks", @as(u32, 3) }),
            .rows = tpl.each(&items, @as([]const u8, "games"), row),
            .note = tpl.t("<i>{s}</i>", .{ .s = "x" }),
        },
    );
}

test "templates nest in templates, and a named Template type" {
    const Greeting = tpl.Template("<b>{who}</b>", struct { who: []const u8 });
    const g: Greeting = .{ .args = .{ .who = "<you>" } };
    try expectRender(
        "<div><p><b>&lt;you&gt;</b></p></div>",
        "<div>{outer}</div>",
        .{ .outer = tpl.t("<p>{inner}</p>", .{ .inner = g }) },
    );
}

test "a component's error reaches the caller" {
    const failing = struct {
        fn f(_: *Writer) error{Nope}!void {
            return error.Nope;
        }
    }.f;
    var buf: [64]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try std.testing.expectError(error.Nope, tpl.render(&w, "<p>{x}</p>", .{ .x = tpl.call(failing, .{}) }));
}

test "a full writer fails with WriteFailed" {
    var buf: [4]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try std.testing.expectError(error.WriteFailed, tpl.render(&w, "<p>{x}</p>", .{ .x = "long text" }));
}

test "format values escape as they stream" {
    try expectRender("<p>a&lt;b</p>", "<p>{v}</p>", .{ .v = Fmt{ .s = "a<b" } });
}

fn repeat(comptime s: []const u8, comptime n: usize) []const u8 {
    comptime var out: []const u8 = "";
    inline for (0..n) |_| out = out ++ s;
    return out;
}

test "streamed escaping past the buffer, and splats" {
    const Long = struct {
        pub fn format(_: @This(), w: *Writer) Writer.Error!void {
            try w.splatByteAll('<', 100);
            try w.writeAll(comptime repeat("&", 70));
        }
    };
    try expectRender(
        comptime "<p title=\"" ++ repeat("&lt;", 100) ++ repeat("&amp;", 70) ++ "\"></p>",
        "<p title=\"{v}\"></p>",
        .{ .v = Long{} },
    );
}

test "parts may leave tags open" {
    var buf: [64]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try tpl.renderPart(&w, "<main>{x}", .{ .x = 1 });
    try tpl.renderPart(&w, "<div></main>", .{});
    try tpl.renderPart(&w, "</div>", .{});
    try std.testing.expectEqualStrings("<main>1<div></main></div>", w.buffered());
}

test "void and self-closing tags, comments, doctype" {
    try expectRender(
        "<!doctype html><!-- {x} --><p><br><img src=\"a\"><svg><line x1=\"1\"/></svg></p>",
        "<!doctype html><!-- {x} --><p><br><img src=\"{src}\"><svg><line x1=\"{x}\"/></svg></p>",
        .{ .src = "a", .x = 1 },
    );
    // SVG shapes self-close without an <svg> around them; void tags may end in `/>`
    try expectRender("<path d=\"M0\"/><br/><input>", "<path d=\"M0\"/><br/><input>", .{});
}

test "comments are written as they are" {
    try expectRender("<!-- {{ <b> --><!--><p>1</p>", "<!-- {{ <b> --><!--><p>{x}</p>", .{ .x = 1 });
}

test "escaping follows the hole's position" {
    const bold = Comp{ .s = "<b>\"x\"</b>" };
    try expectRender(
        "<b>\"x\"</b><p title=\"&lt;b&gt;&quot;x&quot;&lt;/b&gt;\"></p>" ++
            "<a href=\"about:invalid#tpl\"></a><a href=\"https://x.io/?a=1&amp;b\"></a>" ++
            "<a href=\"../a.html?x=1&amp;y=2\"></a><a href=\"../javascript:x\"></a>",
        "{b}<p title=\"{b2}\"></p><a href=\"{bad}\"></a><a href=\"{good}\"></a>" ++
            "<a href=\"{link}\"></a><a href=\"../{rel}\"></a>",
        .{
            .b = bold,
            .b2 = bold,
            .bad = " JavaScript:alert(1)",
            .good = "https://x.io/?a=1&b",
            .link = Comp{ .s = "../a.html?x=1&y=2" },
            .rel = "javascript:x",
        },
    );
}

test "json in a script can't end it" {
    try expectRender(
        "<script type=\"application/json\">{\"name\":\"\\u003c/script\\u003e\",\"n\":2}</script>",
        "<script type=\"application/json\">{data}</script>",
        .{ .data = tpl.json(.{ .name = "</script>", .n = 2 }) },
    );
    try expectRender(
        "<script>var d = [\"\\u003c!--\",\"a\\u0026b\"];</script>",
        "<script>var d = {d};</script>",
        .{ .d = tpl.json(&[_][]const u8{ "<!--", "a&b" }) },
    );
}

test "script and style take numbers and trusted" {
    try expectRender(
        "<script>f(2.5)</script><style>p{width:3px}</style><script>g()</script>",
        "<script>f({a})</script><style>p{{width:{b}px}</style><script>{c}</script>",
        .{ .a = 2.5, .b = 3, .c = tpl.trusted("g()") },
    );
}

test "on* and style attributes take numbers, enums and format values, escaped" {
    try expectRender(
        "<p onclick=\"go(3, big)\" style=\"color:&quot;red&quot;\"></p>",
        "<p onclick=\"go({n}, {e})\" style=\"color:{c}\"></p>",
        .{ .n = 3, .e = enum { big }.big, .c = Fmt{ .s = "\"red\"" } },
    );
}

test "URL holes: the scheme is checked with the text around the hole, components too" {
    const js = Comp{ .s = "javascript:alert(1)" };
    try expectRender(
        "<a href=\"about:invalid#tpl:x\"></a><a href=\"learn.html\"></a>" ++
            "<a href=\"https://x.io/javascript:x\"></a><img src=\"about:invalid#tpl\"><a href=\"../a/x:y\"></a>",
        "<a href=\"{bad}:x\"></a><a href=\"{page}.html\"></a>" ++
            "<a href=\"https://x.io/{fixed}\"></a><img src=\"{js}\"><a href=\"{root}a/{slug}\"></a>",
        .{ .bad = "javascript", .page = "learn", .fixed = "javascript:x", .js = js, .root = "../", .slug = "x:y" },
    );
}

test "URL schemes: relative, http, https and mailto pass, others don't" {
    const ok = [_][]const u8{
        "",      "page.html", "../a",  "/a", "//host/a", "?q=1", "#top", "http://x", "HTTPS://x", "mailto:a@b.c",
        "a/b:c", "a?b:c",     "a#b:c",
    };
    const bad = [_][]const u8{
        "javascript:alert(1)", "JaVaScRiPt:x", " javascript:x", "java\tscript:x", "data:text/html,x",
        "vbscript:x",          "httpx:y",      "https2:x",      ":x",             "verylongscheme:x",
    };
    inline for (ok) |u| {
        var buf: [64]u8 = undefined;
        var w: Writer = .fixed(&buf);
        try tpl.render(&w, "<a href=\"{u}\"></a>", .{ .u = u });
        try std.testing.expect(std.mem.indexOf(u8, w.buffered(), "about:invalid") == null);
    }
    inline for (bad) |u| {
        try expectRender("<a href=\"about:invalid#tpl\"></a>", "<a href=\"{u}\"></a>", .{ .u = u });
    }
}

test "URL holes take enums, numbers and format values; every URL attribute is checked" {
    try expectRender(
        "<a href=\"euw\"></a><a href=\"7\"></a><a href=\"about:invalid#tpl\"></a>" ++
            "<form action=\"about:invalid#tpl\"></form><button formaction=\"about:invalid#tpl\"></button>" ++
            "<iframe src=\"about:invalid#tpl\"></iframe><object data=\"about:invalid#tpl\"></object>" ++
            "<svg><a xlink:href=\"about:invalid#tpl\"></a></svg><a href='about:invalid#tpl'></a>",
        "<a href=\"{e}\"></a><a href=\"{n}\"></a><a href=\"{f}\"></a>" ++
            "<form action=\"{js}\"></form><button formaction=\"{js}\"></button>" ++
            "<iframe src=\"{js}\"></iframe><object data=\"{js}\"></object>" ++
            "<svg><a xlink:href=\"{js}\"></a></svg><a href='{js}'></a>",
        .{ .e = enum { euw }.euw, .n = 7, .f = Fmt{ .s = "javascript:x" }, .js = "javascript:x" },
    );
}

test "tpl.attr escapes as a quoted hole of its attribute" {
    try expectRender(
        "<a href=\"about:invalid#tpl\" title=\"a&amp;b\"></a><i style=\"color:oklch(0.7 0.1 50)\"></i>",
        "<a{href}{title}></a><i{style}></i>",
        .{
            .href = tpl.attr("href", "javascript:x"),
            .title = tpl.attr("title", "a&b"),
            .style = tpl.attr("style", Fmt{ .s = "color:oklch(0.7 0.1 50)" }),
        },
    );
}

test "unquoted attribute values aren't names" {
    try expectRender("<input type=search name=search>", "<input type=search name=search>", .{});
}

test "esc and writeEscaped outside templates" {
    var buf: [64]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.print("<td>{f}</td>", .{tpl.esc("a<b & 'c'")});
    try tpl.writeEscaped("\"", &w);
    try std.testing.expectEqualStrings("<td>a&lt;b &amp; &#39;c&#39;</td>&quot;", w.buffered());
}
