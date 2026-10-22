# Zig's new LinkedList API (it's time to learn @fieldParentPtr)

<https://www.openmymind.net/Zigs-New-LinkedList-API/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zigs-New-LinkedList-API/#)

# Zig's new LinkedList API (it's time to learn @fieldParentPtr)

Apr 10, 2025

In a recent, post-Zig 0.14 commit, Zig's `SinglyLinkedList` and `DoublyLinkedList` saw [significant changes](https://github.com/ziglang/zig/commit/1639fcea43549853f1fded32aa1d711d21771e1c).

The previous version was a generic and, with all the methods removed, looked like:

```zig
pub fn SinglyLinkedList(comptime T: type) type {
  return struct {
    first: ?*Node = null,

    pub const Node = struct {
      next: ?*Node = null,
      data: T,
    };
  };
}
```

The new version isn't generic. Rather, you embed the linked list node with your data. This is known as an intrusive linked list and tends to perform better and require fewer allocations. Except in trivial examples, the data that we store in a linked list is typically stored on the heap. Because an intrusive linked list has the linked list node embedded in the data, it doesn't need its own allocation. Before we jump into an example, this is what the new structure looks like, again, with all methods removed:

```zig
pub const SinglyLinkedList = struct {
  first: ?*Node = null,

  pub const Node = struct {
    next: ?*Node = null,
  };
};
```

Much simpler, and, notice that this has no link or reference to any of our data. Here's a working example that shows how you'd use it:

```zig
const std = @import("std");
const SinglyLinkedList = std.SinglyLinkedList;

pub fn main() !void {
    // GeneralPurposeAllocator is being renamed
    // to DebugAllocator. Let's get used to that name
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var list: SinglyLinkedList = .{};

    const user1 = try allocator.create(User);
    defer allocator.destroy(user1);
    user1.* = .{
        .id = 1,
        .power = 9000,
        .node = .{},
    };
    list.prepend(&user1.node);

    const user2 = try allocator.create(User);
    defer allocator.destroy(user2);
    user2.* = .{
        .id = 2,
        .power = 9001,
        .node = .{},
    };
    list.prepend(&user2.node);

    var node = list.first;
    while (node) |n| {
        std.debug.print("{any}\n", .{n});
        node = n.next;
    }
}

const User = struct {
    id: i64,
    power: u32,
    node: SinglyLinkedList.Node,
};
```

To run this code, you'll need a nightly release from within the last week. What do you think the output will be? You should see something like:

```text
SinglyLinkedList.Node{ .next = SinglyLinkedList.Node{ .next = null } }
SinglyLinkedList.Node{ .next = null }
```

We're only getting the nodes, and, as we can see here and from the above skeleton structure of the new `SinglyLinkedList`, there's nothing about our users. Users have nodes, but there's seemingly nothing that links a node back to its containing user. Or is there?

In the past, we've described how [the compiler uses the type information](https://www.openmymind.net/learning_zig/pointers/) to figure out how to access fields. For example, when we execute `user1.power`, the compiler knows that:

1.  `id` is +0 bytes from the start of the structure,
2.  `power` is +8 bytes from the start of the structure (because id is an i64), and
3.  `power` is an i32

With this information, the compiler knows how to access `power` from `user1` (i.e. jump forward 8 bytes, read 4 bytes and treat it as an i32). But if you think about it, that logic is simple to reverse. If we know the address of `power`, then the address of `user` has to be `address_of_power - 8`. We can prove this:

```zig
const std = @import("std");

pub fn main() !void {
    var user = User{
        .id = 1,
        .power = 9000,
    };
    std.debug.print("address of user: {*}\n", .{&user});

    const address_of_power = &user.power;
    std.debug.print("address of power: {*}\n", .{address_of_power});

    const power_offset = 8;
    const also_user: *User = @ptrFromInt(@intFromPtr(address_of_power) - power_offset);
    std.debug.print("address of also_user: {*}\n", .{also_user});

    std.debug.print("also_user: {}\n", .{also_user});
}

const User = struct {
    id: i64,
    power: u32,
};
```

The magic happens here:

```zig
const power_offset = 8;
const also_user: *User = @ptrFromInt(@intFromPtr(address_of_power) - power_offset);
```

We're turning the address of our user's power field, `&user.power` into an integer, subtracting 8 (8 bytes, 64 bits), and telling the compiler that it should treat that memory as a `*User`. This code will _probably_ work for you, but it isn't safe. Specifically, unless we're using a packed or extern struct, Zig makes no guarantees about the layout of a structure. It could put `power` BEFORE `id`, in which case our `power_offset` should be 0. It could add padding after every field. It can do anything it wants. To make this code safer, we use the `@offsetOf` builtin to get the actual byte-offset of a field with respect to its struct:

```zig
const power_offset = @offsetOf(User, "power");
```

Back to our linked list, given that we have the address of a `node` and we know that it is part of the `User` structure, we _are_ able to get the `User` from a node. Rather than use the above code though, we'll use the _slightly_ friendlier `@fieldParentPtr` builtin. Our `while` loop changes to:

```zig
while (node) |n| {
  const user: *User = @fieldParentPtr("node", n);
  std.debug.print("{any}\n", .{user});
  node = n.next;
}
```

We give `@fieldParentPtr` the name of the field, a pointer to that field as well as a return type (which is inferred above by the assignment to a `*User` variable), and it gives us back the instance that contains that field.

Performance aside, I have mixed feelings about the new API. My initial reaction is that I dislike exposing, what I consider, a complicated builtin like `@fieldParentPtr` for something as trivial as using a linked list. However, while `@fieldParentPtr` seems esoteric, it's quite useful and developers should be familiar with it because it can help solve problems which are otherwise problematic.
