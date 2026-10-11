# meiolol trial port to Zig 0.17.0 (2026-10-11)

Base: meiolol commit 1149c0b (git archive, scratch copy). Toolchain: zig-aarch64-macos-0.17.0 from ziglang.org, sha256 b607e9b9234790a008116ae5bdb71c6243b84b9fb42a53a9e70fde41c06c536a verified. Host macOS aarch64.

## Errors in order (each round fixed, then rebuilt)

Round 1, zig build:
build.zig:81:15: error: no field named 'args' in struct 'Build'

Round 2:
error: 1 compilation errors
error: 2 compilation errors
src/core/score.zig:91:30: error: struct 'bit_set.Integer(5)' has no member named 'initEmpty'
src/lcu/https.zig:168:32: error: root source file struct 'ascii' has no member named 'indexOfIgnoreCase'

Round 3:
error: 2 compilation errors
src/store/raw.zig:43:60: error: binary operator '*' has whitespace on one side, but not the other
src/store/sqlite.zig:4:15: error: invalid builtin function: '@cImport'

Round 4:
error: 1 compilation errors
src/riot/timeline.zig:37:48: error: no field named 'fields' in struct 'lang.Type.Enum'

Round 5: zig build exit 0, no errors

## After the fixes

zig build test --summary all:
Build Summary: 11/11 steps succeeded

zig build -Dtarget=x86_64-windows --summary all:
Build Summary: 7/7 steps succeeded
zig-out/bin: meiolol.exe 16380416 bytes, meiolol-app.exe 5210624 bytes

zig build -Dtarget=x86_64-linux: exit 0

## Diff (pristine vs ported; build.zig version pin changed to 17)

```diff
diff -ru -x z pristine/build.zig repo/build.zig
--- pristine/build.zig	2026-10-11 03:46:41
+++ repo/build.zig	2026-10-11 03:49:36
@@ -4,7 +4,7 @@
 // 0.x releases break APIs; move versions on purpose
 comptime {
     const v = builtin.zig_version;
-    if (v.major != 0 or v.minor != 16) {
+    if (v.major != 0 or v.minor != 17) {
         @compileError(std.fmt.comptimePrint(
             "meiolol is pinned to Zig 0.16.x, found {d}.{d}.{d}",
             .{ v.major, v.minor, v.patch },
@@ -35,6 +35,12 @@
         .flags = &.{ "-DSQLITE_DQS=0", "-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1" },
     });
     store.addIncludePath(sqlite.path("."));
+    const sqlite_h = b.addTranslateC(.{
+        .root_source_file = sqlite.path("sqlite3.h"),
+        .target = target,
+        .optimize = optimize,
+    });
+    store.addImport("sqlite_c", sqlite_h.createModule());
 
     const backend = b.createModule(.{
         .root_source_file = b.path("src/main.zig"),
@@ -78,7 +84,7 @@
         const exe = b.addExecutable(.{ .name = e.name, .root_module = e.mod });
         b.installArtifact(exe);
         const run = b.addRunArtifact(exe);
-        if (b.args) |args| run.addArgs(args);
+        run.addPassthruArgs();
         b.step(e.name, b.fmt("Run {s} ({s})", .{ e.name, e.about })).dependOn(&run.step);
         test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = e.mod })).step);
     }
diff -ru -x z pristine/src/core/score.zig repo/src/core/score.zig
--- pristine/src/core/score.zig	2026-10-11 03:46:41
+++ repo/src/core/score.zig	2026-10-11 03:48:49
@@ -88,10 +88,10 @@
     out: []Suggestion,
 ) []Suggestion {
     var ctx: Context = .{ .stats = stats, .opts = opts };
-    var me_taken: RoleSet = .initEmpty();
+    var me_taken: RoleSet = .empty;
     me_taken.set(@intFromEnum(draft.role));
     const allies = ctx.resolve(draft.allies, 4, me_taken, &ctx.ally_buf);
-    const enemies = ctx.resolve(draft.enemies, 5, .initEmpty(), &ctx.enemy_buf);
+    const enemies = ctx.resolve(draft.enemies, 5, .empty, &ctx.enemy_buf);
 
     // Everything that does not involve my pick
     var fixed: f64 = 0;
@@ -556,7 +556,7 @@
         .{ .champion = 9999 },
         .{ .champion = zed },
         .{ .champion = lux, .role = .utility },
-    }, 5, .initEmpty(), &ctx.enemy_buf);
+    }, 5, .empty, &ctx.enemy_buf);
     try testing.expectEqual(4, placed.len);
     try testing.expectEqual(Role.bottom, placed[0].role);
     try testing.expectEqual(Role.jungle, placed[1].role);
diff -ru -x z pristine/src/lcu/https.zig repo/src/lcu/https.zig
--- pristine/src/lcu/https.zig	2026-10-11 03:46:41
+++ repo/src/lcu/https.zig	2026-10-11 03:48:49
@@ -165,7 +165,7 @@
             content_length = std.fmt.parseInt(usize, value, 10) catch
                 return error.BadResponse;
         } else if (std.ascii.eqlIgnoreCase(name, "transfer-encoding")) {
-            chunked = std.ascii.indexOfIgnoreCase(value, "chunked") != null;
+            chunked = std.ascii.findIgnoreCase(value, "chunked") != null;
         }
     }
 
diff -ru -x z pristine/src/riot/timeline.zig repo/src/riot/timeline.zig
--- pristine/src/riot/timeline.zig	2026-10-11 03:46:41
+++ repo/src/riot/timeline.zig	2026-10-11 03:50:14
@@ -34,7 +34,7 @@
     /// timeEnemySpentControlled: ms of crowd control dealt to enemies
     cc_dealt_ms,
 };
-pub const stat_count = @typeInfo(Stat).@"enum".fields.len;
+pub const stat_count = @typeInfo(Stat).@"enum".field_names.len;
 
 pub const Frame = struct {
     t_ms: i64,
@@ -354,8 +354,8 @@
         try w.z(e.t_ms - prev_t);
         prev_t = e.t_ms;
         switch (e.data) {
-            inline else => |payload| inline for (@typeInfo(@TypeOf(payload)).@"struct".fields) |f| {
-                try w.field(f.name, @field(payload, f.name));
+            inline else => |payload| inline for (@typeInfo(@TypeOf(payload)).@"struct".field_names) |name| {
+                try w.field(name, @field(payload, name));
             },
         }
     }
@@ -390,8 +390,9 @@
         e.* = .{ .t_ms = prev_t, .data = switch (kind) {
             inline else => |k| blk: {
                 var payload: @FieldType(Event.Data, @tagName(k)) = undefined;
-                inline for (@typeInfo(@TypeOf(payload)).@"struct".fields) |f| {
-                    @field(payload, f.name) = try r.field(arena, f.type, f.name);
+                const info = @typeInfo(@TypeOf(payload)).@"struct";
+                inline for (info.field_names, info.field_types) |name, T| {
+                    @field(payload, name) = try r.field(arena, T, name);
                 }
                 break :blk @unionInit(Event.Data, @tagName(k), payload);
             },
diff -ru -x z pristine/src/store/raw.zig repo/src/store/raw.zig
--- pristine/src/store/raw.zig	2026-10-11 03:46:41
+++ repo/src/store/raw.zig	2026-10-11 03:49:36
@@ -40,7 +40,11 @@
 
 test "gzip round trip" {
     const gpa = std.testing.allocator;
-    const text = "{\"metadata\":{\"matchId\":\"EUW1_1\"}," ** 200 ++ "}";
+    const text = comptime blk: {
+        var t: []const u8 = "";
+        for (0..200) |_| t = t ++ "{\"metadata\":{\"matchId\":\"EUW1_1\"},";
+        break :blk t ++ "}";
+    };
     const packed_ = try compress(gpa, text);
     defer gpa.free(packed_);
     try std.testing.expect(packed_.len < text.len / 10);
diff -ru -x z pristine/src/store/sqlite.zig repo/src/store/sqlite.zig
--- pristine/src/store/sqlite.zig	2026-10-11 03:46:41
+++ repo/src/store/sqlite.zig	2026-10-11 03:49:36
@@ -1,7 +1,7 @@
 //! Thin SQLite wrapper: open, exec, prepared statements with tuple binding.
 
 const std = @import("std");
-pub const c = @cImport(@cInclude("sqlite3.h"));
+pub const c = @import("sqlite_c");
 
 const log = std.log.scoped(.sqlite);
 
Only in repo: zig-pkg
```

## Release builds, 0.16.0 (pristine) vs 0.17.0 (ported)

Box target (deploy/box.sh): -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSafe, both exit 0.
meiolol: 19558256 bytes on 0.16.0, 20578512 bytes on 0.17.0.

Windows -Doptimize=ReleaseSmall, both exit 0.
meiolol-app.exe: 916992 bytes on 0.16.0, 902656 bytes on 0.17.0.
meiolol.exe: 2330624 bytes on 0.16.0, 2303488 bytes on 0.17.0.

Not run: no binary from 0.17 was executed on the box or on Windows.
