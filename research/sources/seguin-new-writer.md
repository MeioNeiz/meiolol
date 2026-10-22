---
title: Zig's new Writer (Karl Seguin, 2025)
url: https://www.openmymind.net/Zigs-New-Writer/
kind: article
commit:
for: [zig-api-design]
looked: 2026-10-22
depth: docs (whole post)
relevance: high
grade: B/fair
description: Explains the 0.15 std.Io.Writer: buffer in the interface, drain, the interface field and @fieldParentPtr, Writer.fixed
---
# Zig's new Writer (Karl Seguin, 2025)

Why: the 0.15 Writer is now the standard interface pattern.

## Assessment

- Evidence: B. Practitioner, written on a July 2025 dev build (pre-0.15.1); flags itself
  as likely to date. Core shapes (drain, `interface` field, `fixed`) shipped in 0.15.
- Reasoning: fair; ends with a reasoned objection (buffering should compose).
- Interests: none known.
- Weigh: trust the mechanics; the `adaptToNewApi` migration shim is gone after 0.15.
  `std.fs.File` moved to `std.Io.File` in 0.16.

## Findings

- [zig/api] `std.Io.Writer` carries its buffer; implementations provide `drain(w, data, splat)`. ^f1
  > It turns out that `std.Io.Writer` has buffering built-in.
  > fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize
- [zig/api] Pass an empty buffer for unbuffered writing. ^f2
  > var writer = my_file.writer(&.{});
- [zig/api] Minimal drain: recover the implementation with `@fieldParentPtr("interface", w)` and write `data[0]`; the Writer calls again for the rest. ^f3
  > const self: *@This() = @fieldParentPtr("interface", io_w);
  > Because we return the length of bytes written, `std.Io.Writer` will know that we potentially didn't write all the data and call `drain` again
- [zig/api] Convention: a concrete writer (e.g. `File.Writer`) embeds the interface in a field named `interface`; you pass `&w.interface`, and the concrete writer must stay put in memory. ^f4
  > To get an actual `std.Io.Writer`, you need to access the `interface` field. This is merely a convention, but expect it to be used throughout the standard, and third-party, library.
  > The instance of `File.Writer` needs to exist somewhere (e.g. on the stack) since that's where the `std.Io.Writer` interface exists.
- [zig/api] `Writer.fixed(buf)` replaces functions that wrote into a `[]u8`. ^f5
  > It's easy to miss, but the `Writer.fixed([]u8) Writer` function is what you're looking for.
- [zig/api] He objects that buffering should be composition (BufferedWriter), not baked into one interface. ^f6
  > I keep thinking that adding buffering directly to the `Writer` isn't ideal.

## Read

- Whole post.
