# Be Careful When Assigning ArenaAllocators

<https://www.openmymind.net/Be-Careful-When-Assigning-ArenaAllocators/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Be-Careful-When-Assigning-ArenaAllocators/#)

# Be Careful When Assigning ArenaAllocators

Jun 26, 2024

A bug was recently reported in [pg.zig](https://github.com/karlseguin/pg.zig) which was the result of a dangling pointer to an ArenaAllocator (1). This amused me since (a) I write a lot about dangling pointers (b) I write a bit about ArenaAllocators and (c) it isn't the first time I've messed this up.

(1) Actually, multiple bugs were reported (and fixed), but lets not dwell on that.

### Overview

If we go back to basics, in [Zig dangling pointers and segfaults](https://www.openmymind.net/Zig-Dangling-Pointers/) we started off with an easy-to-understad demonstration of a dangling pointer which boiled down to this function:

```zig
fn powerLevel(over: i32) ![]u8 {
  var buf: [20]u8 = undefined;
  return std.fmt.bufPrint(&buf, "over {d}!!!", .{over});
}
```

`bufPrint` writes the formatted string into `buf` and returns a slice into `buf` containing the formatted string (or an error if `buf` isn't big enough). It might help if we imagine that `bufPrint` returns the length of the formatted string and adjust our code accordingly:

```zig
fn powerLevel(over: i32) ![]u8 {
  var buf: [20]u8 = undefined;

  // If bufPrint returned the length of the formatted string
  // rather than a slice of buf
  const n = try std.fmt.bufPrint(&buf, "over {d}!!!", .{over});

  return buf[0..n];
}
```

Now if you're new to Zig, you might be surprised to find out that, while the above is invalid, this is completely fine:

```zig
fn getRandom() [16]u8 {
  var bin: [16]u8 = undefined;
  std.crypto.random.bytes(&bin);
  return bin;
}
```

In Zig, assignments, including return values, are always copies. In the above two examples, and in the actual bug that we'll cover shortly, it all comes down to understanding what it is we are copying. In the first case, we're returning a slice and in the second case, an array. A slice is a length and pointer to an an array. It's that level of indirection that causes the issue. When you return the slice, you're returning a copy of the length (which is fine) and the pointer. That pointer is an address, but, in `powerLevel` it's an address which stops being valid when the function returns.

With the array, there is no indirection. We're not returning an address of the array, we're returning the array itself. If we changed the function return type to `[]u8` and then did `return &bin;`, we'd be in trouble again, as now we'd be returning an address which will become invalid.

What does all this have to do with ArenaAllocators?

### ArenaAllocator

The issue found in pg.zig can be simulated by a trivial example:

```zig
const User = struct{
  name: []const u8,
  arena: std.heap.ArenaAllocator,

  fn init(allocator: Allocator, name: []const u8) !User {
    var arena = ArenaAllocator.init(allocator);
    return .{
      .arena = arena,
      .name = try arena.allocator().dupe(u8, name),
    };
  }

  fn deinit(self: *const User) void {
    self.arena.deinit();
  }
};
```

Our `User` has a `name` and, reasonably, in `init` we clone the name to ensure that it lives for as long as the `user` (otherwise, the caller would need to make sure the `name` passed into `init` is valid for as long as the returned `user`). It's a bit premature, but we create an arena to manage any allocations associated with the `user`. This makes our `user.deinit` method simple: clear the arena.

Unfortunately, even if `user.deinit()` is called, this code has a memory leak. If we take the above struct and try to use it in a program, we'll be told that `user.name` is leaking despite `arena.deinint` being called:

```zig
pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  const allocator = gpa.allocator();
  defer _ = gpa.detectLeaks();

  var arena = ArenaAllocator.init(allocator);
  defer arena.deinit();

  var user = try User.init(allocator, "Teg");
  defer user.deinit();

  std.debug.print("{s}\n", .{user.name});
}
```

Can you tell what's going on? Here's a hint, if we make a small change to our `User.init`, the leak goes away:

```zig
fn init(allocator: Allocator, name: []const u8) !User {
  var arena = ArenaAllocator.init(allocator);
  return .{
    // the order has been swapped
    .name = try arena.allocator().dupe(u8, name),
    .arena = arena,
  };
}
```

I think this is the type of bug that some people will see right away and consider obvious. But for me, even looking at this code, specifically designed around the issue, I find it subtle. Why is one version right and the other one wrong? To answer that, we need to understand what an `ArenaAllocator` _is_ (not how it works).

`std.heap.ArenaAllocator` is a structure with two fields:

```zig
pub const ArenaAllocator = struct {
    child_allocator: Allocator,
    state: State,

    pub const State = struct {
        buffer_list: std.SinglyLinkedList(usize) = .{},
        end_index: usize = 0,
    };
};
```

What Zig calls the "child\_allocator", I would call the "parent\_allocator", but either way, this is the allocator passed into `init`. The structure could be simplified by directly storing the state:

```zig
pub const ArenaAllocator = struct {
    child_allocator: Allocator,
    buffer_list: std.SinglyLinkedList(usize) = .{},
    end_index: usize = 0,
};
```

But the existing design allows an optimization: we can reference the state directly. This is what it would look like with our `User`:

```zig
const User = struct{
  name: []const u8,

  // changed
  arena: ArenaAllocator.State,

  fn init(allocator: Allocator, name: []const u8) !User {
    var arena = ArenaAllocator.init(allocator);
    const owned = try arena.allocator().dupe(u8, name);
    return .{
      // changed
      .arena = arena.state,
      .name = owned,
    };
  }

  //changed
  fn deinit(self: *const User, allocator: Allocator) void {
    self.arena.promote(allocator).deinit();
  }
};
```

The main takeway is that we can "promote" our `ArenaAllocator.State` back into an `ArenaAllocator` by providing the same `allocator` passed to `init`. This should make some sense. We saw that an `ArenaAllocator` is two fields: `allocator` and `state`. Our user stores the `state` and can turn that back into a full `ArenaAllocator` by providing the missing part: the `allocator`. What does this achieve? It makes our `User` struct smaller because it \[indirectly\] has 1 less field, the `child_allocator`. If you had thousands of ArenaAllocators, that could add up.

None of that tells us why this leaks:

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
return .{
  .arena = arena,
  .name = try arena.allocator().dupe(u8, name),
};
```

The answer is: assignments are copies. When we assign the `arena` variable to our `arena` field, via `.arena = arena`, we're making a copy of our `ArenaAllocator`. At that point, it is correct to say we have two `ArenaAllocators`. One is the `arena` local variable and one belongs to the returned value. With this perspective, which arena do we `dupe` from and which do we `deinit`?

If we go back to our program and print `user.arena.state.buffer_list.first`, it'll print `null`. In short, we're duping from one arena and freeing from another. Now we can understand why re-ordering the field assignment fixes the issue.

```zig
var arena = ArenaAllocator.init(allocator);
return .{
  .name = try arena.allocator().dupe(u8, name),
  .arena = arena,
};
```

In this version, the copy that we're making happens after the allocation. There are still 2 arenas, but the mutation happens before the copy and thus the copy includes a copy of `state` which knows about the allocation made with `dupe`.

### Solution

In some cases, re-arranging the code as we did, might be suitable. But this would only work for simple cases as it doesn't seem like a particularly robust solution. It's very easy to mess up. It's tempting to think that instead of copying the `arena`, we could just get its address:

```zig
const User = struct{
  name: []const u8,
  arena: *ArenaAllocator, // changed to a pointer

  fn init(allocator: Allocator, name: []const u8) !User {
    var arena = ArenaAllocator.init(allocator);
    return .{
      .arena = &arena,   // changed to take the address
      .name = try arena.allocator().dupe(u8, name),
    };
  }

  // ...
};
```

It's true that now we only have 1 arena, because our field assignment is copying an address. But we've introduced a dangling pointer since the address that we're copying lives on the stack which will become invalid when we return.

This is a common problem, and not just with `ArenaAllocators`. We want to reference something and we need that something to outlive the current stack. That wasn't phrased as a question, but the answer is _put it on the heap_:

```zig
const User = struct{
  name: []const u8,
  arena: *ArenaAllocator,

  fn init(allocator: Allocator, name: []const u8) !User {
    const arena = try allocator.create(ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = ArenaAllocator.init(allocator);

    return .{
      .arena = arena,
      .name = try arena.allocator().dupe(u8, name),
    };
  }

  fn deinit(self: *const User) void {
    self.arena.deinit();
  }
};
```

We've actually introduced another memory leak, but we're progressing, our original issue is fixed. `allocator.create` return a `*ArenaAllocator` (a pointer to an `ArenaAllocator`). When we assign `.arena = arena`, we're still making a copy, but rather than making a copy of the `ArenaAllocator` and its `state` field, we're creating copy of the address. A copy of an address is still pointing to the same initial instance. Furthermore, our `ArenaAllocator` no longer lives on the function stack, it lives on the heap. Its outlives the function call.

However, our code is now making a new allocation. Before, we were only allocating a duplicate of `name`. Now we're also allocating an `ArenaAllocator` which we never free. That's our new leak. We need to change `user.deinit`:

```zig
fn deinit(self: *const User) void {
  const allocator = self.arena.child_allocator;
  self.arena.deinit();
  allocator.destroy(self.arena);
}
```

### Conclusion

The example we used ended up creating a memory leak, but you could get different results, including segfaults. The exact behavior is hard to reason about. In the case of pg.zig, multiple allocations were being made, across copies of the same `ArenaAllocator`, reallocations were happening, and the "child allocator" had its own complexity. The result was a bus error - something you don't see often.

The issue isn't specific to `ArenaAllocator`, but from my own experience and help channels, I know others have had the same problem. Maybe that's because `ArenaAllocators` are frequently used. For me, it highlights the need to be mindful of assignments. You need to know what's being copied and how the original and new copy are being used after the assignment takes place. Part of the subtlety comes from how simple this example is. The `return` statement both creates a copy and then mutates the original.

I somehow find this issue obvious in hindsight but also very subtle.
