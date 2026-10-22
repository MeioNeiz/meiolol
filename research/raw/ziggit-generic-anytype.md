AndrewCodeDev | 2024-03-01 23:25:11 UTC | #1

# What is anytype?

Zig enables users to parameterize functions with the use of the keyword `anytype`. This keyword, like its name suggests, allows the user to pass *any type* as a parameter that will then be deduced at comptime.

---
# Using anytype

We'll begin by making a function that can take `anytype` as a parameter.

```
pub fn foo(arg: anytype) void {
    // implementation details
}

// later ...

const bar: usize = 42;

foo(bar); // arg gets deduced as usize

const baz: isize = 42;

foo(baz); // arg gets deduced as isize
```
Due to type deduction, there will now be two separate versions of `foo` that get created - one for `arg: usize` and `arg: isize`.

The keyword `anytype` can also be used in interesting ways with member functions:

```
const MyType = struct {
    pub fn foo(_: anytype) void {
        std.debug.print("\nCalled Foo\n", .{});
    }
};

pub fn main() !void {

    // foo's first argument is deduced as opaque.
    // We're calling it directly against the class. 
    MyType.foo(opaque{});

    // the instance x of MyType calls foo as a member
    // function. This is equivalent to calling foo(&x).
    // anytype is deduced as `*const @This()`
    const x: MyType = .{};

    x.foo();
}
```
As we can see, `anytype` is a very powerful utility that acts as a catch-all for types provided to it.

---

# Considerations when using anytype


Like most powerful things, it can be abused. Heavy reliance on `anytype` can make function declarations difficult to read, requiring the user to dig into function implementations to understand how a type is used. This is often referred to as `duck typing`. According to Wikipedia:

```Text
In computer programming, duck typing is an application of the 
duck test—"If it walks like a duck and it quacks like a duck, then
it must be a duck"—to determine whether an object can be used
for a particular purpose. 
```
So what does this teach us about `anytype`? To answer this, we'll summon the duck. Imagine you have a function that tries to *save* an object at some point. It accomplishes this by calling a `save` function on the object instance:

```
fn doStuffAndSave(obj: anytype) void {

    // do some stuff... important stuff probably...

   obj.save(); // a wild duck appears!
}
```
Here we can see that `doStuffAndSave` assumes that `obj` has a `save` function. Fundamentally, `doStuffAndSave` treats `obj` like it's a saveable object. Like most things, this has a cost and a benefit. The benefit is it allows us to quickly create types that need little to no introduction to be used. This comes at a cost of readability.

However, this does not imply that `anytype` should not be used - rather, it should be used strategically.

# Alternatives to anytype

### Partial Specialization

To understand our options better, let's look at the declaration of the `eql` function in the standard library:

```
pub fn eql(comptime T: type, a: []const T, b: []const T) bool
```
Here, we can see that equal takes a parameter `T` that denotes a type. Then, `T` is propogated to the arguments `a` and `b`. Suppose we pass `u8` as the first argument. This implies:

```
T -> u8
a: []const T -> a: []const u8 
b: []const T -> b: []const u8
```
This clarifies the fact that `eql` expects two slices of some type `T`. In the example of `eql`, it is relatively painless to specify what `T` is and since it always expects slices, there's no need to specify that `a` or `b` could be *any type*.

### Interface Types

Let's build an interface type that can act as an intermediary for our savable object using function pointers and `*anyopaque`.

```
const SaveInterface = struct {
    // pointer to the saveable object
    obj_ptr: *anyopaque,

    // pointer to the object's save function
    func_ptr: *const fn (ptr: *anyopaque) void,
    
    // member function that calls the func_ptr on the obj_ptr
    pub fn save(self: SaveInterface) void {
        self.func_ptr(self.obj_ptr);
    }
};

const MyObject = struct {
    // probably a lot of data members...
    // ...

    // our save function takes in an anyopaque pointer
    // and casts it back to our MyObject type
    pub fn saveMyObject(ptr: *anyopaque) void {
        const self: *MyObject = @ptrCast(@alignCast(ptr));

        // implementation of our save function...
    }

    pub fn saveable(self: *MyObject) SaveInterface {
        return SaveInterface{
            // our self pointer
            .obj_ptr = self,
            // pointer to our save function
            .func_ptr = saveMyObject,
        };
    }
};
```
Now, let's modify our `doStuffAndSave` function to take in a `SaveInterface`:

```
pub fn doStuffAndSave(obj: SaveInterface) void {
 
    // really important stuff... I swear...

    obj.save();
}
```
And now it can be used like this:

```
var obj: MyObject = .{};

doStuffAndSave(obj.saveable());
```
This pattern is quite common in Zig - in fact, this technique is used in the `Allocator` interface.

---

# Best practices with anytype

The examples provided above give us alternatives to `anytype`, but are they strictly better? As all things go, everything has its tradeoffs. We can see the boilerplate that `anytype` saves us from having to write. At the same time, what might be called boilerplate by some can also be called specificity by others. Here's a few tips to use `anytype` wisely:

- Always use good variable names. Our example of `obj` was meant to demonstrate how much information can get lost when going off of type deduction alone.

- Prefer to use `anytype` where functions can be assessed quickly and the type requirements are not hard to find. Avoid making long chains of `anytype` that requires one to dig through many layers to assess what kind of duck we're dealing with.

- Consider the alternatives. For a single type, an interface can be annoying but it can scale well and reduce the amount of comptime deduction that's necessary. Likewise, if your function genuinely expects types of a specific character (like `eql`), then consider partial specialization instead.

-------------------------

mperillo | 2024-02-13 06:28:03 UTC | #2

[quote="AndrewCodeDev, post:1, topic:3228, full:true"]
> ...
### Interface Types

Let's build an interface type that can act as an intermediary for our savable object using function pointers and `*anyopaque`.

```
const SaveInterface = struct {
    // pointer to the saveable object
    obj_ptr: *anyopaque,

    // pointer to the object's save function
    func_ptr: *const fn (ptr: *anyopaque),
    
    // member function that calls the func_ptr on the obj_ptr
    pub fn save(self: @This()) void {
        self.func_ptr(self.obj_ptr);
    }
};

const MyObject = struct {
    // probably a lot of data members...
    // ...

    // our save function takes in an anyopaque pointer
    // and casts it back to our MyObject type
    pub fn saveMyObject(ptr: *anyopaque) void {
        const self: *MyObject = @ptrCast(@alignCast(ptr));

        // implementation of our save function...
    }

    pub fn saveable(self: *@This()) SaveInterface {
        return SaveInterface{
            // our self pointer
            .obj_ptr = self,
            // pointer to our save function
            .func_ptr = saveMyObject,
        };
    }
};
```
[/quote]

Use of `@This` is not necessary; use `SaveInterface` and `MyObject` instead.

I remember reading a document stating that this use of `@This` is discouraged.

-------------------------

AndrewCodeDev | 2024-02-13 06:50:03 UTC | #3

In this context, we don't need to use the builtin. No objection - feel free to edit the article (if you can't, I can adjust it) :)

A couple caveats...

I will say that the use of `@This()` is not a hard-and-fast rule. Take a look at the `std.mem.Allocator` file. It's not a generic type, but it's a file struct that defines `const Allocator = @This()`. For that sort of struct, you can't name the struct because it is the file itself so `@This()` is helpful.


Also, for types that are being returned from functions (such as `ArrayList`), `@This()` is used. It is used to declare `const Self = @This()` as the struct is being returned directly.

In the case you're presenting, I have no objection. But the `@This()` builtin is not discouraged in general. I just don't want people to read that and think they have to avoid the builtin.

-------------------------

mperillo | 2024-02-13 07:11:53 UTC | #4

[quote="AndrewCodeDev, post:3, topic:3228, full:true"]
A couple caveats...

I will say that the use of `@This()` is not a hard-and-fast rule. Take a look at the `std.mem.Allocator` file. It's not a generic type, but it's a file struct that defines `const Allocator = @This()`. For that sort of struct, you can't name the struct because it is the file itself so `@This()` is helpful.
[/quote]

Indeed I should have added `in this context`, since the current text is misleading.

Thanks for the clarification.

And for the edit, IMHO it is better if you update it.  What happens if two people concurrently edit the same post?

-------------------------

AndrewCodeDev | 2024-02-13 07:58:03 UTC | #5

Great question - and I appreciate your suggestion and effort to help our `Docs` be the best that they can be.

We tested simultaneous edits it and it just produces a user error on one of the two ends. It's relatively safe tbh.

If you want me to edit it, I can, but I encourage community members to throw in their own two cents - either way, I'll get that put in tomorrow when I'm at my main computer. :slight_smile: 

That said, I encourage you to edit it! You'll make @dude_the_builder happy because he put in a lot of work getting the community wiki stuff figured out :laughing:

-------------------------

mperillo | 2024-02-13 07:59:22 UTC | #6

> Great question - and I appreciate your suggestion and effort to help our `Docs` be the best that they can be.
>
> We tested simultaneous edits it and it just produces a user error on one of the two ends. It's relatively safe tbh.

Good to know.  I will update the code.

> I'm at my main computer. I have a new rule that I don't post things without compiling them first (made that mistake too many times, lol) :slight_smile: 

I hope in future there will be a good Zig playground, with support for multiple files (like in Go playground with txtar - https://pkg.go.dev/golang.org/x/tools/txtar).

-------------------------

dee0xeed | 2024-02-13 08:15:49 UTC | #7

[quote="AndrewCodeDev, post:1, topic:3228"]
Due to type deduction, there will now be two separate versions of `foo` that get created
[/quote]

A couple of questions:

Is it correct to call this process monomorphization? (I saw this term a long time ago in some Rust docs)
Is it correct to say that Zig has two forms of parametric polymorphism (`anytype` and `comptime T: type`)?

-------------------------

AndrewCodeDev | 2024-02-13 10:00:29 UTC | #8

For the record, my understanding of monomorphization is when a generic function gets instantiated as sepereate function instantiations of specific forms. So you go from a "polymorphic" thing to many "monomorphic" things (aka, we're monomorphiz-ing). 

Yes, that seems appropriate to me unless someone wants to object. In assembly, I can see two distinct versions of the following depending on what I call it with... in this case I'm using usize and u8:

```
pub fn foo(x: anytype) @TypeOf(x) {
    assert(0 < x); // do something
    return x;
}
```
According to godbolt, I get these two versions: 
```
example.foo__anon_860
example.foo__anon_861
```
So we're getting two monomorphic functions from the polymorphic function. Monomorphic again just means "has one form".

For your second question... I'd have to look more into how `type` is implemented on a fundamental level. It seems to me that `type` is actually a kind of "type" specifically. In otherwords, I can't say that `comptime arg: type` and pass it `42` - it only accepts types... so do we still consider that polymorphic?

Now, if you mean "it causes a function to become polymorphic" then we can do that with any comptime value, too.

```
pub fn foo(comptime i: usize, n: usize) usize {
    return if (comptime i < 42) (n + 1) else (n - 1);
}
```
If I pass `foo(0, n)` and then do `foo(60, n)`, I get two anonymous functions (named the same as above incidentally), where one has an `add` instruction and the other has a `sub` instruction. So in this case, we get the same number of functions spawned without `anytype` or similar - just using comptime integers. In fact, regardless of what happens with the `if` statement, I can pass in `foo(30, n)` and get 3 functions (even though 30 and 0 will both evaluate to true).

So I guess I need to ask what do you mean by polymorphic parameter? Do you mean it causes functions to become polymorphic or that the parameter itself is polymorphic?

-------------------------

dee0xeed | 2024-02-13 10:14:20 UTC | #9

[quote="AndrewCodeDev, post:8, topic:3228"]
so do we still consider that polymorphic?
[/quote]

Well, `T` can theoretically be any type.
GIven this generic function

```
const std = @import("std");
const log = std.debug.print;

fn add_them(comptime T: type, a: T, b: T) T {
    return a + b;
}

pub fn main() void {
    const x = add_them(u8, 4, 5);
    log("{}\n", .{x});
    const y = add_them(f64, 4.0, 5.0);
    log("{}\n", .{y});
}
```

we have same result, two monomorphic variants:

```text
$ objdump -t ct | grep add_them
0000000000234e20 l     F .text	000000000000004d ct.add_them__anon_3465
0000000000234f40 l     F .text	000000000000001c ct.add_them__anon_3468
```

-------------------------

AndrewCodeDev | 2024-02-13 10:21:57 UTC | #10

If we're saying that it causes functions to be polymorphic, then sure, I'm in agreement with you.

I'd have to dig into the implementation to have a stronger opinion, but I'm happy to pick up this conversation in a new thread after I've looked into it for a bit. I have a few reservations about that, but practically speaking I think we're on the same page.

-------------------------

dee0xeed | 2024-02-13 10:50:00 UTC | #11

> t <del>we </del><del>would </del><del>consider </del>`*anyopaque`

Some smart people say that type erase/restore with generic pointers is not (technically) (ad-hoc) polymorphysm, since the content of a pointer remains the same, we just instruct compiler to treat pointed-to data as "something".

-------------------------

mperillo | 2024-02-13 14:58:48 UTC | #12

[quote="AndrewCodeDev, post:5, topic:3228, full:true"]
That said, I encourage you to edit it! You'll make @dude_the_builder happy because he put in a lot of work getting the community wiki stuff figured out :laughing:
[/quote]

I have updated the code, and also fixed a bug with
```func_ptr: *const fn (ptr: *anyopaque)```
where the return type was missing.

-------------------------

tiawl | 2024-02-13 20:17:02 UTC | #13

EDIT: typo

-------------------------

