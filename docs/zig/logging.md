# 15. Logging

- one `const log = std.log.scoped(.module_name);` per file, so output filters by
  subsystem (189 Ghostty files) [[ghostty-repo#^f7]]
- run-time log filtering needs `log_level = .debug` in `std_options`: the comptime
  level strips calls before `logFn` runs. ZLS and River both do this
  [[zls-repo#^f21]], [[river-repo#^f17]]:

```zig
// river river/main.zig:297 @ 13752403
/// Set the default log level based on the build mode.
var runtime_log_level: log.Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast, .ReleaseSmall => .info,
};

pub const std_options: std.Options = .{
    // Tell std.log to leave all log level filtering to us.
    .log_level = .debug,
    .logFn = logFn,
};
```

  (River is on 0.16; in 0.17 the mode tags are `.debug`, `.safe`, `.fast`, `.small`.)
- with no run-time control needed, keep the comptime level (SuperHTML)
- stdout is program output; diagnostics go to stderr [[zig-repo-docs#^f15]]
- tests: testing.md 11.8
