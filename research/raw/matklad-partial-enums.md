# Partially Matching Zig Enums

<https://matklad.github.io/2025/08/08/partially-matching-zig-enums.html>

[matklad](https://matklad.github.io/)[About](https://matklad.github.io/about.html)[Links](https://matklad.github.io/links.html)[Blogroll](https://matklad.github.io/blogroll.html)

# Partially Matching Zig Enums

Aug 8, 2025

A short post about a neat little Zig idiom. Consider your average {sum type, variant, tagged union, enum, alt}:

```
enum U {
    A(i32),
    B(i32),
    C,
}
```

Usually, you handle it like this:

```
match u {
    U::A(_) => handle_a(),
    U::B(_) => handle_b(),
    U::C => handle_c(),
}
```

But once in a while, there’s common handling code you want to run for several variants. The most straightforward way is to duplicate:

```
match u {
    U::A(_) => {
        handle_ab();
        handle_a();
    }
    U::B(_) => {
        handle_ab();
        handle_b();
    }
    U::C => handle_c(),
}
```

But this gets awkward if common parts are not easily extractable into function. The “proper” way to do this is to refactor the enum:

```
enum U {
    AB(AB),
    C
}

enum AB {
    A(i32),
    B(i32),
}
```

This gets _very_ awkward if there’s one hundred usages of `U`, 95 of them look better with flat structure, one needs common code for ab case, and the four remaining need common code for ac.

The universal recipe for solving the AB problem relies on a runtime panic:

```
match u {
    U::A(_) | U::B(_) => {
        handle_ab();
        match u {
            U::A(_) => handle_a(),
            U::B(_) => handle_b(),
            _ => unreachable!(),
        }
    }
    U::C => handle_c(),
}
```

And… this is fine, really! I wrote code of this shape many times, and it never failed at runtime due to a misapplied refactor later. Still, every time I write that `unreachable`, I die inside a little. Surely there should be some way to explain to the compiler that `c` is really unreachable there? Well, as I realized an hour ago, in Zig, you can!

This is the awkward runtime-panicky and theoretically brittle version:

```
switch (u) {
    .a, .b => |_, ab| {
        handle_ab();
        switch (ab) {
            .a => handle_a(),
            .b => handle_b(),
            else => unreachable,
        }
    },
    .c => handle_c(),
}
```

And here’s a bullet-proof compiler-checked one:

```
const U = union(enum) {
    a: i32,
    b: i32,
    c,
};

fn handle(u: U) void {
    switch (u) {
        inline .a, .b => |_, ab| {
            handle_ab();
            switch (ab) {
                .a => handle_a(),
                .b => handle_b(),
                else => comptime unreachable,
            }
        },
        .c => handle_c(),
    }
}

fn handle_ab() void {}
fn handle_a() void {}
fn handle_b() void {}
fn handle_c() void {}

pub fn main() void { handle(.c); }
```

There are two tricks here. `inline .a, .b` forces the compiler to generate the program twice, where `ab` is bound to _comptime_ value. The second trick is `comptime unreachable`, which instructs the compiler to fail if it gets to the else branch. But, because `ab` is known at comptime, compiler knows that `else` is in fact unreachable, and doesn’t hit the error.

Adding a bug fails compilation, as intended:

```
    switch (u) {
        inline .a, .b, .c => |_, ab| {
            handle_ab();
            switch (ab) {
                .a => handle_a(),
                .b => handle_b(),
                else => comptime unreachable,
            }
        },
    }
```

```
$ ./zig/zig build-exe partial-match.zig
partial-match.zig:14:34: error: reached unreachable code
                else => comptime unreachable,
                                 ^~~~~~~~~~~
```

[Fix typo](https://github.com/matklad/matklad.github.io/edit/master/content/posts/2025-08-08-partially-matching-zig-enums.dj)[Subscribe](https://matklad.github.io/feed.xml)[All posts](https://matklad.github.io/)[Get in touch](mailto:aleksey.kladov+blog@gmail.com)[matklad](https://github.com/matklad)
