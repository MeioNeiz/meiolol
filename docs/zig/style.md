# 3. Layout, naming, comments

## 3.1 Names follow five rules

From the langref Style Guide [[zig-langref-017-b#^f103]]:

- namespace (a struct with no fields, or a file without fields): `snake_case`
- types, and functions that return `type`: `TitleCase`
- other callables: `camelCase`
- everything else (variables, fields, constants): `snake_case`
- acronyms are words, even two-letter ones: `XmlParser`, `readU32Be`
- files with fields are `TitleCase.zig`; other files and all directories `snake_case` <!-- hygiene-ok -->

```zig
// research/raw/zig-langref-017.md:14397 (langref 0.17.0, Style Guide)
const namespace_name = @import("dir_name/file_name.zig");
const TypeName = @import("dir_name/TypeName.zig");
var global_var: i32 = undefined;
const const_name = 42;
const PrimitiveTypeAlias = f32;

const StructName = struct {
    field: i32,
};
const StructAlias = StructName;

fn functionName(param_name: TypeName) void {
    var functionPointer = functionName;
    functionPointer();
    functionPointer = otherFunction;
    functionPointer();
}
const functionAlias = functionName;
```

Casing tells the reader a function returns a type; `zig fmt` will not fix it
[[seguin-learning-zig-style-guide#^f5]]. TigerBeetle and matklad use `snake_case`
functions and suffix type functions with `Type` (`BoundedArrayType`), enforced by their
lint [[tigerbeetle-tidy#^f5]]. That is a consistent house style, not the std's. Pick one
per repo; meiolol uses the std's (1657 camelCase functions against 44 snake_case).

## 3.2 No redundant words

The Style Guide bans empty words in type names (Value, Data, Context, Manager, State,
utils, misc) and repeating the namespace path: `json.Value`, not `json.JsonValue`, and
the file counts as a path segment [[zig-langref-017-b#^f97]], [[zig-langref-017-b#^f99]].

```zig
// research/raw/zig-langref-017.md:14334 (the counter-example)
pub const json = struct {
    pub const JsonValue = union(enum) {
        number: f64,
        boolean: bool,
        // ...
    };
};
```

A `utils` module is called "a categorisation failure": put the declarations at the root
of the module that uses them [[zig-langref-017-b#^f98]]. No underscore-prefixed
"private" fields either; Zig has no private fields, so name and document fields for
their invariants [[zig-langref-017-b#^f100]].

## 3.3 TigerBeetle's naming vocabulary

Worth adopting even with camelCase functions [[tigerbeetle-tiger-style#^f28]],
[[tigerbeetle-blog-index-count-offset-size#^f1]]:

- units and qualifiers last, most significant first: `latency_ms_max`, not
  `max_latency_ms`; related names then sort and align (449 `_max`/`_min` suffixes vs 28
  prefixes in their tree)
- a fixed vocabulary: **count** of items, **index** into them, **size** and **offset**
  in bytes; never `length`, which hides the unit
- equal-length pairs line up: `source`/`target`, not `src`/`dest`
- name allocators by lifetime: `gpa` (free individually), `arena` (no per-object free)
  [[tigerbeetle-tiger-style#^f29]], [[matklad-aphorisms#^f4]]

```zig
// tigerbeetle src/lsm/compaction.zig:2111 @ 0450c32
        /// Copy values from values_source to values_target, dropping tombstones as we go.
        fn values_copy_drop_tombstones(
            values_target: []Value,
            values_source: []const Value,
        ) CopyDropTombstonesResult {
            assert(values_source.len > 0);
            assert(values_source.len <= Table.data.value_count_max);
            assert(values_target.len > 0);
            assert(values_target.len <= Table.data.value_count_max);

            var index_source: usize = 0;
            var index_target: usize = 0;
```

matklad's naming tip for user-facing numbers: `line_index` is 0-based and internal,
`line_number` is 1-based and shown [[matklad-diagnostics-factory#^f6]].

## 3.4 A file with fields is a struct; name it, don't call it Self

```zig
// ghostty src/terminal/PageList.zig:1 @ 08a9518
//! Maintains a linked list of pages to make up a terminal screen
//! and provides higher level operations on top of those pages to
//! make it slightly easier to work with.
const PageList = @This();

const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("terminal_options");
const Allocator = std.mem.Allocator;
const assert = @import("../quirks.zig").inlineAssert;
...
const log = std.log.scoped(.page_list);
```

The shape, shared by std, Ghostty, ZLS and River: `//!` module doc, `const Name =
@This();`, imports, one scoped log, then fields [[ghostty-repo#^f1]], [[river-repo#^f6]],
[[zig-langref-017-b#^f84]].

`Self` is for the anonymous struct a type function returns, where there is no name. The
0.17 std has 128 files opening with `const <Name> = @This();` and 3 with `const Self`
[[zig-compiler-dod#^f24]]; TigerBeetle's lint bans `Self = @This()`
[[tigerbeetle-tidy#^f7]]. Receivers are short names from the type, not `self`: `w:
*Writer`, `ip: *InternPool`, `tree: *const Ast` (Ast.zig: 102 `tree:` against 1 `self:`)
[[zig-compiler-dod#^f23]]. matklad: name the receiver, avoid `self`
[[matklad-look-for-bugs#^f3]].

```zig
// ziglang/zig lib/std/mem/Allocator.zig:1 @ 0.17.0
//! The standard memory allocation interface.
const Allocator = @This();
```

Struct order inside a type: fields, then nested types, then functions
[[matklad-newtype-index#^f11]]. A package root (`main.zig`, `root.zig`) re-exports and
holds the test wiring, nothing else [[ghostty-repo#^f3]].

## 3.5 Formatting

- `zig fmt` decides; steer it with trailing commas. A list of more than two items goes
  one per line with a trailing comma, and zig fmt keeps that layout
  [[zig-langref-017-b#^f102]], [[matklad-steering-zig-fmt#^f1]].
- Aim for 100 columns (std, TigerBeetle), physically two files side by side
  [[tigerbeetle-tiger-style#^f45]]; this repo uses ~90.
- 4 spaces, braces on the same line, UTF-8, LF, final newline
  [[zig-langref-017-b#^f108]].
- River's only rule beyond the Style Guide: a one-line `if` stays on one line, or gets
  braces [[river-repo#^f3]].
- Good formatting is mostly blank lines and intermediate variables
  [[matklad-steering-zig-fmt#^f2]]. TigerBeetle's lint wants a blank line after each
  `defer`, so a resource and its cleanup read as a group [[tigerbeetle-tidy#^f11]].
- `zig fmt --complexity` (0.17) measures an edit in tokens and nodes, better than lines
  [[zig-017-release-notes#^f37]].

## 3.6 Function size

Tiger Style: 70 lines, so a function fits a screen [[tigerbeetle-tiger-style#^f15]]. In
practice it is a ratchet: their lint fails only functions of 71 or 72 lines, so small
functions can't creep while old long ones stay; 10% of their functions exceed 70, the
longest is 382 [[tigerbeetle-tidy#^f6]], [[tigerbeetle-code#^f43]]. matklad's version:
make the body large relative to the interface; hourglass functions are the smell
[[matklad-size-matters#^f1]].

## 3.7 Comments and doc comments

- `///` documents the declaration or field that follows (misplaced ones are compile
  errors), `//!` the module, `//` the implementation [[zig-langref-017-a#^f7]],
  [[zig-langref-017-a#^f8]].
- Leave out what the name already says; repeating text across similar functions is fine
  because tools show each alone [[zig-langref-017-b#^f106]].
- Use **assert** for a violated precondition that is safety-checked and **assume** for
  one that is unchecked illegal behaviour, so the doc matches build-mode behaviour
  [[zig-langref-017-b#^f107]].
- The std says ownership, invalidation, complexity and assertions in fixed phrases
  [[zig-std-containers#^f8]]:

```zig
// ziglang/zig lib/std/array_list.zig:806 @ 0.17.0
        /// Insert `item` at index `index`. Moves `list[index .. list.len]` to higher indices to make room.
        /// If `index` is equal to the length of the list this operation is equivalent to append.
        /// This operation is O(N).
        /// Invalidates element pointers if additional memory is needed.
        /// Invalidates pre-existing pointers to elements at and after `index`.
        /// Asserts that the index is in bounds or equal to the length.
        pub fn insert(self: *Self, gpa: Allocator, index: usize, item: T) Allocator.Error!void {
```

- Doc comments carry the why and measured costs; Ghostty documents decisions with the
  failure that forced them (memory.md 5.11).
- Doctests: `test addOne { ... }` names the declaration and shows in docs as a checked
  example, "not a substitute for a doc comment" [[zig-langref-017-a#^f28]].
- Tiger Style wants comments as full sentences and always the why
  [[tigerbeetle-tiger-style#^f22]]. Everyone agrees on why-not-what; prose form is taste.
