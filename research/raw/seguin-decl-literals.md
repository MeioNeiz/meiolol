# Zig's new declaration literals

<https://www.openmymind.net/Zigs-New-Declaration-Literals/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zigs-New-Declaration-Literals/#)

# Zig's new declaration literals

Nov 14, 2024

In the last post, we looked at some of [Zig' weirder syntax](https://www.openmymind.net/Zigs-weird-syntax/). Specifically, this line of code:

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
```

Some people pointed out that the code could be improved by doing:

```zig
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
```

While this may be an improvement, i think it's rarely used. That is, until now. With the introduction of declaration literals, you can expect to see something _similar_ to the above more often.

### [Enum Literals](https://www.openmymind.net/Zigs-New-Declaration-Literals/#enum_literals)

Zig has a feature called "enum literals", which allows you to use the enum value without specifying the enum type. The type is inferred based on the context. Consider this code:

```zig
const Operation = enum {
    add,
    sub,
    mul,
    div,
};

fn calc(a: i32, b: i32, op: Operation) i32 {
    switch (op) {
        .add => return a + b,
        .sub => return a - b,
        .mul => return a * b,
        .div => return @divTrunc(a, b),
    }
}
```

The cases for our `switch` statement is leveraging enum literals, allowing us to specify `.add` instead of `Operation.add` (which is also valid). This also works when calling the function. These are both valid and equivalent:

```zig
_ = calc(100, 20, .div);

_ = calc(100, 20, Operation.div);
```

The other place you'll commonly see this is when assigning a value:

```zig
user.state = .disabled;
```

There's probably an argument to be made that enum literals hurt readability. In my experience it's generally an improvement. First of all, it's always optional. Secondly, if the meaning of the enum value (i.e. `disabled` above) isn't clear, it _could_ be an indication that other parts of the statement aren't well named.

### [Declaration Literals](https://www.openmymind.net/Zigs-New-Declaration-Literals/#declarion_literals)

A month or two ago, declaration literals were added to Zig. This is a generalization of what enum literals are. Using the new declaration literal syntax, our above `GeneralPurposeAllocator` initialization becomes:

```zig
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
```

Notice that instead of initializing the value to `.{}`, we're using `.init`. What's `.init`? It's a declaration defined within `GeneralPurposeAllocator(T)`. Let's build our own trivial example. Previously, we might have done something like:

```zig
const User = struct {
    id: u32 = 0,
};
```

Which could have then been initialized with:

```zig
const user: User = .{};
// or, equivalent
const user = User{};
```

We can now add a declaration to `User` like so:

```zig
const User = struct {
    id: u32,

    pub const init = User{
        .id = 0,
    };
};
```

Allowing us to initialize a `User` with:

```zig
const user: User = .init;
```

One benefit of this approach is that we can have multiple declarations. This allows us to have groups of default values behind a meaningful label

```zig
const User = struct {
    pub const init = User{
        .id = 0,
    };

    // This entire User example isn't very "meaningful"
    // It's meant to showcase the behavior without any
    // distraction.
    pub const super = User{
        .id = 9001,
    };
};
```

Finally, just like with enum declarations, we can opt to be explicit and use:

```zig
const user: User = User.super;
```

But that's a lot more messy with generics, which is one area where declarations literals really shines:

```zig
// this is good
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;

// this is bad
var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}).init;
```

### [Conclusion](https://www.openmymind.net/Zigs-New-Declaration-Literals/#conclusion)

Declaration literals should make variable initialization a little more clear. I'm particularly interested in having different groups of default values under a meaningful label. But, as far as I can tell, the old pattern isn't going away. If you already know Zig, you won't have problems reading / writing code that makes use of both techniques. But for newcomers, I think it's just another (small) difficulty in picking up the language.

Furthermore, using the `.{}` syntax gives the caller the flexibility to override a default value:

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){
    .requested_memory_limit = 1_048_576;
};
```

Whereas declaration literals requires setting the field explicitly:

```zig
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
gpa.requested_memory_limit = 1_048_576;
```

Decl literals can also be used to ensure data [invariants are not violated](https://ziglang.org/download/0.14.0/release-notes.html#Decl-Literals) by overriding single fields.

I think it's still a nice addition to the language, but one of Zig's zen is "Only one obvious way to do things" and, at this point, for me, "obvious" this is not. It isn't obvious which approach I should use in my own structs and which is being used by other structs, including the standard library.
