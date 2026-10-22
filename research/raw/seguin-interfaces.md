# Zig Interfaces

<https://www.openmymind.net/Zig-Interfaces/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zig-Interfaces/#)

# Zig Interfaces

Oct 08, 2023

If you're picking up Zig, it won't be long before you realize there's no syntactical sugar for creating interfaces. But you'll probably notice interface-like things, such as `std.mem.Allocator`. This is because Zig doesn't have a simple mechanism for creating interfaces (e.g. `interface` and `implements` keywords), but the language itself can be used to achieve the same goal.

There are existing articles that I've been able to copy and paste to get this working, but none really clicked with me. It wasn't until I broke the code down into two parts: making it work and then making it pretty, that I finally understood. So, first, let's make something that works.

### A Simple Interface Implementation

We're going to create a `Writer` interface; it's something simple to understand that won't get in our way. We'll stick with a single function; once we know how to do this with one function, it's easy to repeat the pattern for more. First, the interface itself:

```zig
const Writer = struct {
  ptr: *anyopaque,
  writeAllFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,

  fn writeAll(self: Writer, data: []const u8) !void {
    return self.writeAllFn(self.ptr, data);
  }
};
```

This is our complete interface. Depending on your knowledge of Zig, there might be some things you aren't sure about. Our interface has two fields. The first, `ptr`, is a pointer to the actual implementation. We'll talk about `*anyopaque` in a bit. The second, `writeAllFn`, is a function pointer to the function of the actual implementation.

Notice that the interface's `writeAll` implementation just calls our function pointer and passes it the `ptr` field as well as any other arguments. Here's a skeleton implementation:

```zig
const File = struct {
  fd: os.fd_t,

  fn writeAll(ptr: *anyopaque, data: []const u8) !void {
    // What to do with ptr?!
  }

  fn writer(self: *File) Writer {
    return .{
      .ptr = self,
      .writeAllFn = writeAll,
    };
  }
};
```

First, the `writer` function is how we get a `Writer` from a `*File`. This is like calling `gpa.allocator()` on a GeneralPurposeAllocator to get an `std.mem.Allocator`. Aside from the fact that we're able to assign `self` to `ptr` (a `*File` to `*anyopaque`), there's nothing special here. We're just creating a `Writer` struct. And even this assignment isn't too special, Zig's automatic type coercion requires guaranteed safety and no ambiguity, two properties that are always true when assigning to an `*anyopaque`.

The part that glues everything together, the part that we've left out, is: what do we do with the `ptr: *anyopaque` passed back into `writeAll`? First,`*anyopaque` is a pointer to something of unknown type and unknown size. Hopefully it's clear why `Writer.ptr` has to be of this type. It can't be a `*File`, else it wouldn't be usable for other implementations. The nature of interfaces means that, at compile time, we don't know what the implementation will be and thus `*anyopaque` is the only possible choice.

It's important to know that when we create a `Writer` via `file.writer()`, `ptr` _is_ the file because we assign it to `self`. But because `ptr` is of type `*anyopaque`, the assignment erases its true type. The memory pointed to by `ptr` _does_ represent a `*File`, the compiler just doesn't know that. We need a way to inject this information into the compiler. We can do this with a combination of `ptrCast` and `alignCast`:

```zig
fn writeAll(ptr: *anyopaque, data: []const u8) !void {
  const self: *File = @ptrCast(@alignCast(ptr));
  _ = try std.os.write(self.fd, data);
}
```

`@ptrCast` converts a pointer from one type to another. The type to convert to is inferred by the value the result is assigned to. In the above case, we're telling the compiler: _give me a variable pointing to the same thing as `ptr` but treat that like a `*File`, trust me, I know what I'm doing._ `@ptrCast` is powerful as it allows us to force the type associated with specific memory. If we're wrong and use `@ptrCast` to convert a pointer into a type incompatible with the underlying memory, we'll have serious runtime issues, with a crash being the best possible outcome.

`@alignCast` is more complicated. There are CPU-specific rules for how data must be arranged in memory. This is called data alignment and it deals with how fields in a structure are aligned in memory. `anyopaque` always has an alignment of 1. But our `File` has a different alignment (4). If you want, you can see this by printing `@alignOf(File)` and `@alignOf(anyopaque)`. Just like we need `@ptrCast` to tell the compiler what the type is, we need `@alignCast` to tell the compiler what the alignment is. And, just like `@ptrCast`, `@alignCast` infers this based on what it's being assigned to.

Our complete solution is:

```zig
const Writer = struct {
  ptr: *anyopaque,
  writeAllFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,

  fn writeAll(self: Writer, data: []const u8) !void {
    return self.writeAllFn(self.ptr, data);
  }
};

const File = struct {
  fd: os.fd_t,

  fn writeAll(ptr: *anyopaque, data: []const u8) !void {
    // This re-establishs the type: *anyopaque -> *File
    const self: *File = @ptrCast(@alignCast(ptr));
    // os.write might not write all of `data`, we should really look at the
    // returned value, the number of bytes written, and handle cases where data
    // wasn't all written.
    _ = try std.os.write(self.fd, data);
  }

  fn writer(self: *File) Writer {
    return .{
      // this "erases" the type: *File -> *anyopaque
      .ptr = self,
      .writeAllFn = writeAll,
    };
  }
};
```

Hopefully, this is pretty clear to you. It comes down to two things: using `*anyopaque` to be able to store a pointer to any implementation, and then using `@ptrCast(@alignCast(ptr))` to restore the correct type information.

As an aside, the interface's `ptr` type **has** to be a pointer to `anyopaque`, i.e. `*anyopaque`, it cannot be just `anyopaque`. Do you know why? As I said, `anyopaque` is of unknown size and in Zig, like most languages, all types have to have a known size. `Writer` has a size of 16 bytes: 2 pointers with each pointer being 8 bytes on a 64 bit platform. If we were to try and use `anyopaque`, then the size of `Writer` becomes unknown, which the compiler will not allow. (pointers always have a known size which depends on the underlying architecture, e.g. 4 bytes on a 32bit CPU)

### Making it Prettier

I'm a fan of the above implementation. There's only a little magic to know and implement. Some of the interfaces in the standard library, like `std.mem.Allocator`, look just like it. (Because `Allocator` has a few more functions, a nested structure called `VTable` (virtual table) is used to hold the function pointers, but that's a small change.)

The major drawback is that it's only usable through the interface. We can't use `file.writeAll` directly since `writeAll` doesn't have a `*File` receiver. So it's fine if implementations are always accessed through the interface, like Zig's allocators, but it won't work if we need implementations to function on their own as well as through an interface.

In other words, we'd like `File.writeAll` to be a normal method, essentially not having to deal with `*anyopaque`:

```zig
fn writeAll(self: *File, data: []const u8) !void {
  _ = try std.os.write(self.fd, data);
}
```

This is something we can achieve, but it requires changing our `Writer` interface:

```zig
const Writer = struct {
  // These two fields are the same as before
  ptr: *anyopaque,
  writeAllFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,

  // This is new
  fn init(ptr: anytype) Writer {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    const gen = struct {
      pub fn writeAll(pointer: *anyopaque, data: []const u8) anyerror!void {
        const self: T = @ptrCast(@alignCast(pointer));
        return ptr_info.@"pointer".child.writeAll(self, data);
      }
    };

    return .{
      .ptr = ptr,
      .writeAllFn = gen.writeAll,
    };
  }

  // This is the same as before
  pub fn writeAll(self: Writer, data: []const u8) !void {
    return self.writeAllFn(self.ptr, data);
  }
};
```

What's new here is the `init` function. To me, it's pretty complicated, but it helps to think of it from the point of view of our original implementation. The point of all the code in `init` is to turn an `*anyopaque` into a concrete type, such as `*File`. This was easy to do from within `*File`, because within `File.writeAll`, `ptr` had to be a `*File`. But here, to know the type, we need to capture more information.

To better understand `init`, it might help to see how it's used. Our `File.writer`, which previous created a `Writer` directly, is now changed to:

```zig
fn writer(self: *File) Writer {
  return Writer.init(self);
}
```

So we know that the `ptr` argument to `init` is our implementation. The `@TypeOf` and `@typeInfo` builtin functions are central to most compile-time work in Zig. The first returns the type of `ptr`, in this case `*File`, and the latter returns a tagged union which fully describes the type. You can see that we create a nested structure which also has a `writeAll` implementation. This is where the `*anyopaque` is converted to the correct type and the implementation's function is invoked. The structure is needed because Zig lacks anonymous functions. We need `Writer.writeAllFn` to be this little two-line wrapper, and using a nested structure is the only way to do that.

Obviously `file.writer()` is something that'll be executed at runtime. It can be tempting to think that everything inside `Writer.init`, which `file.writer()` calls, is created at runtime. You might wonder about the lifetime of our internal `gen` structure, particularly in the face of multiple implementations. But aside from the `return` statement, `init` is all compile-time code generation. Specifically, the Zig compiler will create a version of `init` for each type of `ptr` that the program uses. The `init` function is more like a template for the compiler (all because the `ptr` argument is `anytype`). When `file.writer()` is called at runtime, the `Writer.init` function that ends up being executed is distinct from the `Writer.init` function that would be executed for a different type.

In the original version, each implementation is responsible for converting `*anyopaque` to the correct type. Essentially by including that one line of code, `@ptrCast(@alignCast(ptr))`. In this fancy version, each implementation also has its own code to do this conversion, we've just managed to embed it in the interface and leveraged Zig's comptime capabilities to generate the code for us.

The last part of this code is the function invocation, via `ptr_info.pointer.child.writeAll(self, data)`. `@typeInfo(T)` returns a `std.builtin.Type` which is a tagged union that describes a type. It can describe 24 different types, such as integers, optional, structs, pointers, etc. Each type has its own properties. For example, an integer has a `signedness` which other types don't. Here's what `@typeInfo(*File)` looks like:

```zig
builtin.Type{
  .pointer = .
    .address_space = builtin.AddressSpace.generic,
    .alignment = 4,
    .child = demo.File,
    .is_allowzero = false,
    .is_const = false,
    .is_volatile = false,
    .sentinel = null,
    .size = builtin.Type.pointer.size.one
  }
}
```

The `child` field is the actual type behind the pointer. When `init` is called with a `*File`, `ptr_info.pointer.child.writeAll(...)` translates to `File.writeAll(...)`, exactly what we want.

If you look at other implementations of this pattern, you might find their `init` function does a few more things. For example, you might find these two additional lines of code after `ptr_info` is created:

```zig
if (ptr_info != .pointer) @compileError("ptr must be a pointer");
if (ptr_info.pointer.size != .One) @compileError("ptr must be a single item pointer");
```

The purpose of these is to add additional compile-time checks on the type of value passed to `init`. Essentially making sure that we passed it a pointer to a single item.

Also, instead of calling the function via:

```zig
ptr_info.pointer.child.writeAll(self, data);
```

You might see:

```zig
@call(.always_inline, ptr_info.pointer.child.writeAll, .{self, data});
```

The `@call` builtin function, is the same as calling a function directly (as we did), but gives more flexibility by allowing us to supply a `CallModifier`. As you can see, using `@call` allows us to tell the compiler to inline the function.

Hopefully this has made the implementation of interfaces in Zig clearer and maybe exposed new capabilities of the language. However, for simple cases where all implementations are known, you might want to consider a different approach.

### Tagged Unions

As an alternative to the above solutions, tagged unions can be used to emulate interfaces. Here's a complete working example:

```zig
const Writer = union(enum) {
  file: File,

  fn writeAll(self: Writer, data: []const u8) !void {
    switch (self) {
      .file => |file| return file.writeAll(data),
    }
  }
};

const File = struct {
  fd: os.fd_t,

  fn writeAll(self: File, data: []const u8) !void {
    _ = try std.os.write(self.fd, data);
  }
};

pub fn main() !void {
  const file = File{.fd = std.io.getStdOut().handle};
  const writer = Writer{.file = file};
  try writer.writeAll("hi");
}
```

Remember that when we switch a tagged union, the captured values, e.g. `|file|`, has the correct type. `File` in this case.

The downside with this approach is that it requires all implementations to be known ahead of time. You can't use it, for example, to create an interface that third parties can create implementations for. Each possible implementation has to be baked into the union.

Within an app, there are plenty of cases where such a restriction is fine. You can build a `Cache` union with all supported caching implementations, e.g. InMemory, Redis and PostgreSQL. If your application adds a new implementation, you just update the union.

In many cases, the interface will call the underlying implementation directly. For those cases, you can use the special `inline else` syntax:

```zig
switch (self) {
  .null => {},  // do nothing
  inline else => |impl| return impl.writeAll(data),
}
```

This essentially gets expanded automatically for us, meaning that `impl` will have the correct underlying type for each case. The other thing this highlights is that the interface can inject its own logic . Above, we see it short-circuit the call when the "null" implementation is active. Exactly how much logic you want to add to the interface is up to you, but we're all adults here and I'm not going to tell you that interfaces should only do dispatching.

As far as I'm concerned, tagged unions should be your first option.

As an aside, I want to mention that there's yet another option for creating interfaces which relies on the `@fieldParentPtr` builtin. This used to be the standard way to create interfaces, but is now infrequently used. Still, you might see references to it.

If you're interested in learning Zig, consider my [Learning Zig](https://www.openmymind.net/learning_zig/) series.
