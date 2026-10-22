# Zig defer Patterns

<https://matklad.github.io/2024/03/21/defer-patterns.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Zig defer Patterns

Mar 21, 2024

A short note about some unexpected usages of Zig’s `defer` statement.

This post assumes that you already know the basics about RAII, `defer` and `errdefer`. While discussing the differences between them is not the point, I will allow myself one high level comment. I don’t like `defer` as a replacement for RAII: after writing Zig for some time, I am relatively confident that humans are just not good at not forgetting defers, especially when “optional” ownership transfer is at play (i.e, this function takes ownership of an argument, unless an error is returned). But defer is good at discouraging RAII oriented programming. RAII encourages binding lifetime of resources (such as memory) with lifetimes of individual domain objects (such as a `String`). But often, in pursuit of performance and small code size, you want to separate the two concerns, and let many domain objects to share the single pool of resources. Instead of each individual string managing its own allocation, you might want to store the contents of all related strings into a single continuously allocated buffer. Because RAII with defer is painful, Zig naturally pushes you towards batching your resource acquisition and release calls, such that you have far fewer resources than objects in your program.

But, as I’ve said, this post isn’t about all that. This post is about non-resource-oriented usages of `defer`. There’s more to defer than just RAII, it’s a nice little powerful construct! This is way to much ado already, so here come the patterns:

## [Asserting Post Conditions](https://matklad.github.io/2024/03/21/defer-patterns.html#Asserting-Post-Conditions)

`defer` gives you poor man’s contract programming in the form of

```
assert(precondition)
defer assert(postcondition)
```

Real life [example](https://github.com/tigerbeetle/tigerbeetle/blob/73bbc1a32ba2513e369764680350c099fe302285/src/vsr/grid.zig#L298-L309):

```
{
  assert(!grid.free_set.opened);
  defer assert(grid.free_set.opened);

  // Code to open the free set
}
```

## [Statically Enforcing Absence of Errors](https://matklad.github.io/2024/03/21/defer-patterns.html#Statically-Enforcing-Absence-of-Errors)

This is basically peak Zig:

```
errdefer comptime unreachable
```

`errdefer` runs when a function returns an error (e.g., when a `try` fails). `unreachable` crashes the program (in `ReleaseSafe`). But `comptime unreachable` straight up fails compilation if the compiler tries to generate the corresponding runtime code. The three together ensure the absence of error-returning paths.

Here’s [an example](https://github.com/ziglang/zig/blob/1d82d7987acf7f020bcc6a976f9887a3556ef79c/lib/std/hash_map.zig#L1561-L1584) from the standard library, the function to grow a hash map:

```
// The function as a whole can fail...
fn grow(
  self: *Self,
  allocator: Allocator,
  new_capacity: Size,
) Allocator.Error!void {
  @setCold(true);
  var map: Self = .{};
  try map.allocate(allocator, new_capacity);

  // ...but from this point on, failure is impossible
  errdefer comptime unreachable;

  // Code to rehash&copy self to map
  std.mem.swap(Self, self, &map);
  map.deinit(allocator);
}
```

## [Logging Errors](https://matklad.github.io/2024/03/21/defer-patterns.html#Logging-Errors)

Zig’s error handling mechanism provides only error code (a number) and an error trace. This is usually plenty to programmatically handle the error in an application and for the operator to debug a failure, but this is decidedly not enough to provide a nice report for the end user. However, if you are in a business of reporting errors to users, you are likely writing an application, and application might get away without propagating extra information about the error to the caller. Often, there’s enough context at the point where the error originates in the first place to produce a user-facing report right there.

[Example:](https://github.com/tigerbeetle/tigerbeetle/blob/73bbc1a32ba2513e369764680350c099fe302285/src/tigerbeetle/benchmark_driver.zig#L158-L163)

```
const port = port: {
  errdefer |err| log.err("failed to read the port number: {}", .{err});

  var buf: [fmt.count("{}\n", .{maxInt(u16)})]u8 = undefined;
  const len = try process.stdout.?.readAll(&buf);
  break :port try fmt.parseInt(u16, buf[0 .. len -| 1], 10);
};
```

## [Post Increment](https://matklad.github.io/2024/03/21/defer-patterns.html#Post-Increment)

Finally, `defer` can be used as an `i++` of sorts. [For example](https://github.com/tigerbeetle/tigerbeetle/blob/0.15.3/src/lsm/scan_buffer.zig#L97-L102), here’s how you can pop an item off a free list:

```
pub fn acquire(self: *ScanBufferPool) Error!*const ScanBuffer {
  if (self.scan_buffer_used == constants.lsm_scans_max) {
    return Error.ScansMaxExceeded;
  }

  defer self.scan_buffer_used += 1;
  return &self.scan_buffers[self.scan_buffer_used];
}
```

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2024-03-21-defer-patterns.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)
