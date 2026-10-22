---
title: Using a custom test runner in Zig (Karl Seguin, 2024, gist kept current for 0.16)
url: https://www.openmymind.net/Using-A-Custom-Test-Runner-In-Zig/
kind: article
commit:
for: [zig-testing, zig-build]
looked: 2026-10-22
depth: docs (whole post)
relevance: medium
grade: B/fair
description: Writing a test runner over builtin.test_functions: timings, fail-fast, filters, setup/teardown, keeping leak detection
---
# Using a custom test runner in Zig (Karl Seguin, 2024, gist kept current for 0.16)

Why: when the default runner isn't enough.

## Assessment

- Evidence: B. Post Jul 2024; he keeps a gist current for 0.16 (stated at the top).
- Reasoning: fair.
- Interests: none known.
- Weigh: the post's code is 0.13-era; use the gist for current code.

## Findings

- [zig/test] A test runner is just a `main` that iterates `builtin.test_functions`; set it with `.test_runner` on `addTest`. ^f1
  > .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
- [zig/test] To keep leak detection, reset `std.testing.allocator_instance` before each test and check `deinit() == .leak` after. ^f2
  > To preserve the builtin test runner's memory leak detection when using `std.testing.allocator`, we need want to set `std.testing.allocator_instance` before each test, and check for leaks after each test:
- [zig/test] Test names encode the file path (`server.handshake.test.Handshake: parse`), which a runner can parse. ^f3
  > given a file "server/handshake.zig" with a `test "Handshake: parse"`, our `t.name` would be `server.handshake.test.Handshake: parse`.
- [zig/test] Global setup/teardown via naming convention (`tests:beforeAll`) is a hack he finds useful. ^f4
  > Now any tests named `tests:beforeAll` will be run first while any tests named `tests:afterAll` will be run last.
- [toolchain] He keeps the runner gist current for 0.16. ^f5
  > **Latest Version (0.16.0):** I keep a [gist](https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b) up to date.

## Read

- Whole post.
