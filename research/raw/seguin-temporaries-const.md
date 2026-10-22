# Zig's Temporary Variable are Const

<https://www.openmymind.net/Zigs-Temporary-Variables-are-Const/>

[home](https://www.openmymind.net/)[dark](https://www.openmymind.net/Zigs-Temporary-Variables-are-Const/#)

# Zig's Temporary Variable are Const

Jul 23, 2024

I frequently run into a silly compilation error which, embarrassingly, always takes me a couple of seconds to decipher. This most commonly happens when I'm writing tests. Here's a simple example:

```zig
fn add(values: []i64) i64 {
  var total: i64 = 0;
  for (values) |v| {
    total += v;
  }
  return total;
}

test "add" {
  const actual = add(&.{1, 2, 3, 4, 5});
  try std.testing.expectEqual(15, actual);
}
```

Which gives you this error:

```bash
error: expected type '[]i64', found '*const [5]i64'
const actual = add(&.{1, 2, 3, 4, 5});
                   ^~~~~~~~~~~~~~~~~
```

I think part of my problem stems from the `&.{...}` syntax - so cryptic. Also, the error mentions a `*const [5]i64`, which my brain always takes a few seconds to place.

The issue is trivial and silly. Let's solve it so we can talk about the more interesting parts. We're passing a `const` to a function that doesn't take a `const`. In this case, our function _should_ take a `const` since it doesn't mutate `values`. In this specific case, we can solve the issue by changing `values` to a `const`:

```zig
// const added
fn add(values: []const i64) i64 {
  ...
}
```

That fixes the code, but there might be cases where we need to mutate the input. Take this contrived example:

```zig
fn addX(values: []i64, x: i64) void {
  for (values) |*v| {
    v.* += x;
  }
}
```

`values` can't be a `const` because we're mutating it. If we try to call `addX` with our fancy array literal (`addX(&.{1, 2, 3, 4, 5}, 2);`), we'll get the original error. Instead, what we need an explicit assignment to a `var`:

```zig
test "addX" {
  var input = [5]i64{1, 2, 3, 4, 5};
  addX(&input, 2);
  try std.testing.expectEqualSlices(i64, &.{3, 4, 5, 6, 7}, &input);
}
```

This works, but things are looking quite different. We've gone from being able to use Zig's array literal to having to declare an explicit `var input` with an explicit type. It seems like we're throwing around a lot of different syntax for something so simple. Let's break it down.

I don't know what the official name for it is, but I call Zig's `.{...}` the "figure what I want" operator. Consider this code to initializing a `User`:

```zig
var user = User{.name = "Goku", .power = 9001};
```

In cases where the type is known, we can always replace the type (`User`) with a dot. You see this often with return values:

```zig
fn empty() User {
  return .{
    .name = "",
    .power = 0,
  };
}
```

It's the same syntax, but when the type can be inferred, it can be replaced with a dot. This works for any type, like arrays. These are equivalent:

```zig
const a = [5]i64{1, 2, 3, 4, 5};
const b: [5]i64 = .{1, 2, 3, 4, 5};
```

In this example the second form is ugly/silly. But the "figure what I want" operator only works when Zig can automatically infer the type. In simple one-line assignments, we can only showcase the operator by also specifying the type, which defeats the purpose. However, if we go back to our corrected `add` function, we see how useful it can be:

```zig
fn add(values: []const i64) i64 {
  var total: i64 = 0;
  for (values) |v| {
    total += v;
  }
  return total;
}

test "add" {
  const actual = add(&.{1, 2, 3, 4, 5});
  try std.testing.expectEqual(15, actual);
}
```

For the writer of the code the short form of the input is nice. (I'm not sure it's great for readers of the code, but that's another story). You've probably noticed the ampersand - we're not just using `.{...}`, we're using `&.{...}`. It looks special, but if you keep thinking of that leading dot as an inferred type, then there's no difference between `&.{.name = "goku"}` and `&User{.name = "goku"}`. We're just taking the address of the value.

Let's re-examine the original error by reverting `values` and removing the `const`:

```bash
error: expected type '[]i64', found '*const [5]i64'
const actual = add(&.{1, 2, 3, 4, 5});
                   ^~~~~~~~~~~~~~~~~
```

I **still** seems weird to me. I guess the issue is that I expect the "figure what I want" operator to either succeed or tell me that it can't figure what I want. Instead it has decided that the type should be `*const [5]i64` which then causes an error because it cannot be coerced into a `[]i64`. The "figure what I want" operator seems to have made a bad guess! We can mimic what's happening:

```zig
test "add" {
  const input = [5]i64{1, 2, 3, 4, 5};
  const actual = add(&input);
  try std.testing.expectEqual(15, actual);
}
```

`input` is a `[]const i64`. We pass its address to `add`, turning the type into the `*const [5]i64` that we keep running into. Assuming we can't change `add` to take a `const`, we can fix this test by changing `input` to a `var`:

```zig
test "add" {
  var input = [5]i64{1, 2, 3, 4, 5};
  const actual = add(&input);
  try std.testing.expectEqual(15, actual);
}
```

And this works. This begs the question, why is the type of `&.{1, 2, 3, 4, 5}` a `const` even though Zig knows the target type isn't? This isn't specific to the "figure what I want" operator. We can make a slight change to the above to initialize `var input` using `.{...}` and everything will still work:

```zig
test "add" {
  var input: [5]i64 = .{1, 2, 3, 4, 5};
  const actual = add(&input);
  try std.testing.expectEqual(15, actual);
}
```

I believe what's going on here is that, in Zig, temporary/implicit variables are **always** `const`. This code doesn't compile:

```zig
pub fn main() !void {
  const r = std.Random.DefaultPrng.init(0).random();
  std.debug.print("{d}\n", .{r.uintAtMost(u16, 1000)});
}
```

You'll get this error:

```bash
error: expected type '*Random.Xoshiro256', found '*const Random.Xoshiro256'
const r = std.Random.DefaultPrng.init(0).random();
          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~
```

It _seems_ unrelated to what we've been talking about, but the only thing that's changed are the types. The code is expecting a `*Random.Xoshiro256` but was given a `*const Random.Xoshiro256`. The issue is that `init` returns a variable which is never stored explicitly in a local variable. Zig always makes these temporaries `const` to protect against mutating data that you might not even realize exists. We can fix this code just like we can fix our test: by explicitly introducing the variable:

```zig
pub fn main() !void {
  var random = std.Random.DefaultPrng.init(0);
  const r = random.random();
  std.debug.print("{d}\n", .{r.uintAtMost(u16, 1000)});
}
```

This is the same solution we used to fix our `addX` test. It comes down to the same thing: if we want data to be mutable, it needs to be explicitly assigned to a variable.

This is a good argument for, whenever possible, making things `const`. Certainly the `values` parameter of our `add` function should have been. But in cases where you can't, Zig forces you to be explicit. Error messages could always be better and this is no exception. On the one hand, the error message is perfectly accurate. On the other hand, a hint to help resolve the the conflict between the inferred type and no-implicit-var would probably be welcomed.
