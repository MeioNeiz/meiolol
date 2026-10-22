# Snapshot Testing For the Masses

<https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/>

[Docs](https://docs.tigerbeetle.com/) [Pricing](https://tigerbeetle.com/cloud#pricing) [Blog](https://tigerbeetle.com/blog) [Company](https://tigerbeetle.com/company) [Stories](https://tigerbeetle.com/stories) [ 14.8K ](https://www.youtube.com/@tigerbeetledb)[ 17.2K](https://github.com/tigerbeetle/tigerbeetle)

[Cloud](https://tigerbeetle.com/cloud)

# Snapshot Testing For the Masses

May 14, 2024

-   [
    
    matklad
    
    ](https://matklad.github.io/)

Snapshot testing is a technique for the “assert” part of an “arrange, act, assert” test, that dispenses with hand-written assertions, and instead uses comparison to a known good value, a snapshot. Crucially, in the case of a mismatch, a snapshot can update itself. A video is worth a thousand words:

That is, we start with a test with an empty expected result:

```
try check_sort(&.{3, 2, 1 }, snap(@src(),
    \\
));
```

The testing infrastructure automatically populates the value using the current code

```
try check_sort(&.{3, 2, 1 }, snap(@src(),
    \\[1, 3, 2]
));
```

After behavior change (e.g., a bug fix), the expected values are updated automatically

```
try check_sort(&.{3, 2, 1 }, snap(@src(),
    \\[1, 2, 3]
));
```

This post assumes that you are already familiar with the concept of snapshot testing (also known as testing with expectations), sold on the methodology, and don’t need further convincing that this is a good idea. You can read any of the following posts to learn about motivation behind snapshot testing:

-   [https://ianthehenry.com/posts/my-kind-of-repl](https://ianthehenry.com/posts/my-kind-of-repl)
-   [https://insta.rs](https://insta.rs/)
-   [https://blog.janestreet.com/using-ascii-waveforms-to-test-hardware-designs](https://blog.janestreet.com/using-ascii-waveforms-to-test-hardware-designs)

But, just in case, here’s a short bullet list of the most important motivations for me:

-   Snapshots require that domain objects have rich and readable textual representations. Ability to dump a domain object to string is invaluable during debugging.
    
-   Traditional tests often end up “freezing” the code, when significant behavioral changes require a lot of busy work to manually update all the tests. Snapshot tests are easily adaptable to changes in requirements.
    
-   Snapshot testing encourages a more fruitful mind state for testing focusing on comparing input and output _data_, rather than focusing on details of particular _code_ which implements data transformation.
    
-   Textual comparison with a diff subsumes various fluent assertion libraries.
    

Rather then elaborating on the above properties, we will look at how one might implement a snapshot testing library oneself. The motivation is two-fold:

-   To dispel the magic surrounding mature snapshot testing libraries — they usually make use of fancy macros, require external tools or rely on deep integration with code editors. It might not be obvious, but none of this is essential! A simple version can be implemented in a pretty spartan way.
    
-   To show one particular implementation technique, which I think leads to a more flexible API than is typically available in popular libraries.
    

We’ll be using Zig — it’s a spartan language, so it’ll work perfectly to demonstrate how little is required!

## [What Is a Snapshot?](https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/#what-is-a-snapshot)

Usually, snapshot testing libraries start with an assertion macro for comparing expected value with a snapshot:

```
assert_snapshot!(
    actual_value,
    @"expected snapshot"
);
```

I think this is suboptimal API — as soon as something is a macro, the only way to program it is with another macro. In other words, macros are an abstraction that composes poorly.

For our library, we start with a slightly different building block — a self-updating string literal, which we call a snapshot:

```
pub const Snapshot = struct {
  source_location: std.builtin.SourceLocation,
  text: []const u8
};
```

The secret sauce here is `SourceLocation`. It specifies the source file and line of the string literal that gives value to the `.text` field.

How to get a `SourceLocation` very much depends on a particular language. Often, there’s some sort of a “get current line” builtin or macro. For Zig, that would be `@src()` function.

```
pub fn snap(
  source_location: SourceLocation,
  text: []const u8,
) Snapshot {
  return .{
    .source_location = source_location,
    .text = text,
  }
}
```

to be called like

```
snap(@src(),
    \\Text of the snapshot.
)
```

In a more expressive language, you might want to abstract `snap(@src()` spell with a macro (you need a macro to make sure that the equivalent of `@src()` captures the call-site). But in Zig, the caller has to write this exact pattern, which actually isn’t all that bad!

## [Comparison Functions](https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/#comparison-functions)

Now, once you have a location-tagged string literal, you might add various comparison functions to it. The fundamental one is of course direct string comparison:

```
const Snapshot = struct {
  ...

  pub fn diff(want: Snapshot, got: []const u8) !void {
    if (!std.mem.equal(u8, want.text, got)) {
      return error.SnapshotMismatch;
    }
  }
};
```

A note about line endings: on Windows, git sometimes “helpfully” changes `\n` in the source code to `\r\n`. This of course breaks direct string comparison. You can fix this by either making the comparison line-ending agnostic, or just by telling git to not mess up with line endings using the following `.gitattributes` file:

```
* text=auto eol=lf
```

On top of this primitive string comparison, you can build higher-level utils to, e.g., compare debug string representation or JSON serialization:

```
pub fn diff_fmt(
  want: *const Snap,
  comptime fmt: []const u8,
  fmt_args: anytype,
) !void {
  const got = try std.fmt.allocPrint(std.testing.allocator, fmt, fmt_args);
  defer std.testing.allocator.free(got);
  try want.diff(got);
}

pub fn diff_json(
  want: *const Snap,
  value: anytype,
  options: std.json.StringifyOptions,
) !void {
  var got = std.ArrayList(u8).init(std.testing.allocator);
  defer got.deinit();

  try std.json.stringify(value, options, got.writer());
  try want.diff(got.items);
}
```

## [Using Snapshots](https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/#using-snapshots)

When designing an API, you should always think not about what code you, as the implementer, are writing, but rather about the user of the API. So let’s test-drive what we have so far. One example [from TigerBeetle](https://github.com/tigerbeetle/tigerbeetle/blob/588123f219f1f3e324f9293ae3975845e087d5f5/src/flags.zig#L721) where we use snapshot testing is our CLI argument parsing library. The way these tests work, is that we have a example CLI that exercises various features of the library:

```
const ExampleCli = union(enum) {
    empty,
    values: struct {
        int: u32 = 0,
        size: ByteSize = .{ .value = 0 },
        boolean: bool = false,
        path: []const u8 = "not-set",
        optional: ?[]const u8 = null,
        choice: enum { marlowe, shakespeare } = .marlowe,
    },

    // ...

    pub const help =
        \\ flags-test-program [flags]
        \\
    ;
};
```

In the tests, we want to run this cli against a specific array of arguments, and verify that it parses the arguments correctly, providing appropriate error messages. We can write a helper `check` function such that we can express these requirements directly. That is, the `check` function takes only two arguments: the input data, and the result (the error message or parsed arguments):

```
try check(&.{}, snap(@src(),
  \\status: 1
  \\stderr:
  \\error: subcommand required, expected 'empty', 'prefix', 'pos', 'required', or 'values'
  \\
));

try check(&.{"--help"}, snap(@src(),
  \\stdout:
  \\ flags-test-program [flags]
  \\
));

try check(&.{""}, snap(@src(),
  \\status: 1
  \\stderr:
  \\error: unknown subcommand: ''
  \\
));

try t.check(&.{
  "values",
  "--int=92",
  "--size=1GiB",
  "--boolean",
  "--path=/home",
  "--optional=some",
  "--choice=shakespeare",
}, snap(@src(),
  \\stdout:
  \\int: 92
  \\size: 1073741824
  \\boolean: true
  \\path: /home
  \\optional: some
  \\choice: shakespeare
  \\
));
```

Here’s how `check` can be implemented:

```
fn check(args: []const []const u8, want: Snapshot) !void {
  const got: []const u8 = {
    // Pass `args` to the `ExampleCli`, serialize the result to string.
  };

  try want.diff(got);
}
```

The high order bit: because `Snapshot` is a first-class value, we can pass it around!

## [Updating Source Code](https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/#updating-source-code)

So far, our library is just string comparison with more steps. The distinguishing features of snapshot testing is the ability to update “gold” values in place. We have already solved the hard part of this problem: our snapshots know the source file and line that need an update. Let’s do the rest!

_First_, when should the test update the gold value, instead of just failing on mismatch? One surprisingly simple approach is to just update unconditionally (still failing the test). This works great if you store the code in source control, and can always revert to an earlier version.

But a more conservative approach is to require an opt-in via an environmental variable, or even a specific builder method on the snapshot itself:

```
pub const Snapshot = struct {
  source_location: SourceLocation,
  text: []const u8
  update_this: bool = false

  pub fn update(snapshot: Snapshot) Snapshot {
    return {
      .source_location = snapshot.source_location,
      .text = snapshot.text,
      .update_this = true,
    }
  }

  fn should_update(snapshot: Snapshot) bool {
    return snapshot.update_this or
      std.process.hasEnvVarConstant("UPDATE_SNAPSHOTS");
  }
};
```

The fundamental `.diff` method then becomes:

```
pub fn diff(want: Snapshot, got: []const u8) !void {
  if (std.mem.equal(u8, want.text, got)) {
    return;
  }

  std.debug.print(
    \\Snapshot differs.
    \\Want:
    \\----
    \\{s}
    \\----
    \\Got:
    \\----
    \\{s}
    \\----
    \\
  , .{ snapshot.text, got });

  if (want.should_update()) {
    const original_text =
      try read_source_file(want.source_location.file);

    const snapshot_range =
      try extract_snapshot(original_text, want.source_location.line);

    const new_next = concat(&.{
      original_text[0..snapshot_range.start],
      format_as_string_literal(got),
      original_text[snapshot_range.end..],
    });

    try write_source_file();

    return error.SnapshotUpdated;
  } else {
    return error.SnapshotMismatch;
  }
}
```

The above snippet oversimplifies things a bit — here, one has to write some amount of messy code:

-   To extract the range of the original snapshot string literal, one might want to reach out for a real lexer for the programming language in question. However, given that you already know the start line, and that you can require that the snapshots are written in a particular consistent style, just some ad-hoc string processing works.
    
-   When splicing in the new value, it can’t be pasted as is! You need to convert it to a string literal, adding quotes around, and you also want to compute the correct indentation.
    
-   Finally, if _several_ snapshots are updated in a row, the original source lines become incorrect! So you’ll also need to keep a bit of state around to keep track how many lines were removed and added so far, and adjust `source_location.line` appropriately. Alternatively, you can require that the snapshots are updated one-at-a-time.
    

When updating a source file, there’s an important invariant to uphold: you should touch the file system only when the test would fail otherwise. It is often useful to run the test suite outside of the original repository, without access to the source code. This use case should continue to work, unless the tests are going to fail anyway.

## [Extras](https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/#extras)

In case of a mismatch, it is helpful to print a proper diff. There’s a cheat code here: leveraging git. That is, just update the snapshots in-place and use `git diff` to show a nicely colored diff to the user. But, if you want to use a real diff, it’s useful to know that a good quality one [isn’t that much code](https://github.com/dtolnay/dissimilar).

Often, the data to be snapshoted includes some volatile parts, like timestamps, which you would like to exclude from comparison. One possible approach here is to explicitly mark ignorable parts of the snapshots. This is how it could look like:

```
try check(
    \\lookup_accounts id=1
, snap(@src(),
    \\{
    \\  "id": "1",
    \\  "debits_pending": "0",
    \\  "debits_posted": "10",
    \\  "credits_pending": "0",
    \\  "credits_posted": "0",
    \\  "user_data_128": "0",
    \\  "user_data_64": "0",
    \\  "user_data_32": "0",
    \\  "ledger": "700",
    \\  "code": "10",
    \\  "flags": ["linked"],
    \\  "timestamp": "<snap:ignore>"
    \\}
    \\
));
```

The magic is `<snap:ignore>` — this is a special string recognized by the library. Specifically, the

```
fn equal_excluding_ignored(
  got: []const u8,
  snapshot: []const u8,
) bool
```

function splits the snapshot on the `<snap:ignore>` substring, and than checks that each of the remaining fragments can be found in the original string, in that order.

## [Conclusion](https://tigerbeetle.com/blog/2024-05-14-snapshot-testing-for-the-masses/#conclusion)

That’s all for today! Now you can write your very own snapshot testing library, or make a more informed choice among the existing offerings. Key points:

-   Snapshot testing is a useful technique! Keep it mind for cases where you feel like tests make the code less changeable.
-   The basic primitive of snapshot testing is a self-aware string literal, which remembers its position in the original source code and can update itself.
-   Text is a surprisingly powerful primitive, if you can compare text, you can compare complex, structured data by serializing it to text.
-   A minimalist, but useful snapshot testing library can be implemented in less than 500 lines of code! See, for example, our [TigerBeetle microlibrary](https://github.com/tigerbeetle/tigerbeetle/blob/588123f219f1f3e324f9293ae3975845e087d5f5/src/testing/snaptest.zig).

MORE POSTS

[

## It Takes Two to Contract

matklad · Dec 27, 2023

](https://tigerbeetle.com/blog/2023-12-27-it-takes-two-to-contract)

-   [View All Posts](https://tigerbeetle.com/blog)
-   [**RSS**](https://tigerbeetle.com/blog/atom.xml)

 

### Product

[

Cloud

](https://tigerbeetle.com/cloud)[

Pricing

](https://tigerbeetle.com/cloud#pricing)[

Stories

](https://tigerbeetle.com/stories)

### Developers

[

Docs

](https://docs.tigerbeetle.com/)[

GitHub

](https://github.com/tigerbeetle/tigerbeetle)[

Tutorials

](https://github.com/tigerbeetle/tigerlings)[

Releases

](https://github.com/tigerbeetle/tigerbeetle/releases)[

Jepsen

](https://jepsen.io/analyses/tigerbeetle-0.16.11)[

Blog

](https://tigerbeetle.com/blog)

### Connect

[

X

](https://x.com/TigerBeetleDB)[

LinkedIn

](https://www.linkedin.com/company/tigerbeetle/)[

YouTube

](https://www.youtube.com/@tigerbeetledb)[

Email

](mailto:hello@tigerbeetle.com)

### Company

[

About

](https://tigerbeetle.com/company)[

Privacy

](https://tigerbeetle.com/privacy)

### Newsletter

Get monthly highlights and carefully crafted updates.

[Subscribe](https://tigerbeetle.com/newsletter)[

Past Newsletters →

](https://tigerbeetle.com/newsletters)

Correct and Fast

Copyright © 2026 TigerBeetle, Inc. All Rights Reserved.
